"""
Cleans up old ECR images while protecting images referenced by currently running ECS tasks.
"""

from datetime import datetime, timedelta, timezone
import json
import os
import boto3
from botocore.exceptions import ClientError

KEEP_COUNT = 5
MAX_AGE_DAYS = 30
AWS_BATCH_SIZE = 100

ssm_client = boto3.client('ssm')
ecs_client = boto3.client('ecs')
ecr_client = boto3.client('ecr')


def log(data):
    """Adds a UTC timestamp to data and prints it as a JSON log line."""
    data['time'] = datetime.now(timezone.utc).isoformat()
    print(json.dumps(data, default=str))


def parse_image_ref(image_uri):
    """Parses an ECR image URI and returns a (repo_name, ref) tuple
    where ref is a digest, tag, or 'latest'."""
    if '@' in image_uri:
        repo_part, digest = image_uri.split('@', 1)
        repo_name = repo_part.split('/')[-1]
        return repo_name, digest

    last_component = image_uri.split('/')[-1]

    if ':' in last_component:
        repo_name, tag = last_component.rsplit(':', 1)
        return repo_name, tag

    return last_component, 'latest'


def get_images_to_delete(client, repo_name, protected_refs):
    """
    Fetches all images for repo_name and returns those eligible for deletion:
    1. Not referenced in protected_refs,
    2. Outside the KEEP_COUNT newest
    3. Older than MAX_AGE_DAYS.
    """
    cutoff = datetime.now(timezone.utc) - timedelta(days=MAX_AGE_DAYS)

    images = []
    paginator = client.get_paginator('describe_images')
    for page in paginator.paginate(repositoryName=repo_name):
        images.extend(page['imageDetails'])

    candidates = []
    for img in images:
        digest = img['imageDigest']
        tags = img.get('imageTags', [])
        if digest not in protected_refs and not any(tag in protected_refs for tag in tags):
            candidates.append(img)

    candidates.sort(key=lambda x: x['imagePushedAt'], reverse=True)

    remainder = candidates[KEEP_COUNT:]

    return [img for img in remainder if img['imagePushedAt'] < cutoff]


def get_repo_list(client, ssm_param_name):
    """
    Read an SSM SecureString parameter and return a list of ECR repository names.
    Note: this uses SecureString to maintain compatibility with the existing SOPS mechanism.
    """
    response = client.get_parameter(Name=ssm_param_name, WithDecryption=True)
    value = response['Parameter']['Value']
    return json.loads(value)


def get_all_repos(client, app):
    """Returns all ECR repository names that belong to the given app prefix."""
    repos = set()
    paginator = client.get_paginator('describe_repositories')
    for page in paginator.paginate():
        for repo in page['repositories']:
            name = repo['repositoryName']
            if name.startswith(f'{app}-'):
                repos.add(name)
    return repos


def get_protected_image_refs(client):
    """
    Return a set of all image tags and digests referenced by currently RUNNING ECS tasks.
    """
    refs = set()

    cluster_arns = []
    for page in client.get_paginator('list_clusters').paginate():
        cluster_arns.extend(page['clusterArns'])

    for cluster_arn in cluster_arns:
        task_arns = []
        for page in client.get_paginator('list_tasks').paginate(
            cluster=cluster_arn, desiredStatus='RUNNING'
        ):
            task_arns.extend(page['taskArns'])

        for i in range(0, len(task_arns), AWS_BATCH_SIZE):
            batch = task_arns[i:i + AWS_BATCH_SIZE]
            try:
                resp = client.describe_tasks(cluster=cluster_arn, tasks=batch)
                for task in resp['tasks']:
                    for container in task.get('containers', []):
                        _, ref = parse_image_ref(container.get('image', ''))
                        refs.add(ref)
            except ClientError as e:
                log({'msg': f'Error describing tasks in cluster {cluster_arn}: {e}'})

    return refs


def delete_images(client, repo_name, images):
    """Deletes the given images from the ECR repository in batches."""
    image_ids = [{'imageDigest': img['imageDigest']} for img in images]
    for i in range(0, len(image_ids), AWS_BATCH_SIZE):
        batch = image_ids[i:i + AWS_BATCH_SIZE]
        client.batch_delete_image(repositoryName=repo_name, imageIds=batch)

def log_images_for_deletion(repo, images):
    """Logs images that would be deleted if the repo were opted in."""
    for img in images:
        log({'msg': 'Would delete image (not opted in)', 'repo': repo,
             'digest': img['imageDigest']})

def lambda_handler(event, context):  # pylint: disable=unused-argument
    """
    Main entry point for lambda function.
    Reads configured repos from SSM, which are opted in for lambda to clean up.
    Reviews active ECS task definitions, then deletes eligible images that
    are old enough and no longer running.
    For repos associated with the app but not opted in, logs images that would
    be deleted without taking action.
    """
    ssm_param = f"/{os.environ['APP']}/{os.environ['ENV']}/ecr-cleanup/repos"

    opted_in = set(get_repo_list(ssm_client, ssm_param))
    all_repos = get_all_repos(ecr_client, os.environ['APP'])
    log({'msg': 'Collected repository list for app',
         'app': os.environ['APP'],
         'repos': list(all_repos)})

    protected_refs = get_protected_image_refs(ecs_client)
    log({'msg': 'Built protected image set from running ECS tasks',
         'repos': list(protected_refs)})

    for repo in all_repos:
        try:
            to_delete = get_images_to_delete(ecr_client, repo, protected_refs)

            if len(to_delete):
                if repo in opted_in:
                    delete_images(ecr_client, repo, to_delete)
                else:
                    log_images_for_deletion(repo, to_delete)
            log({'msg': f'Cleanup complete for repo: {repo}'})
        except ClientError as e:
            log({'msg': f'Error processing repo {repo}: {e}', 'repo': repo})
