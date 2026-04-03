"""
Cleans up old ECR images while protecting images referenced by currently running ECS tasks.
"""

from argparse import ArgumentParser
from datetime import datetime, timezone
import json
import os
import sys

import boto3
from botocore.exceptions import ClientError

from strategies import DELETE, PROTECT, STRATEGIES

AWS_BATCH_SIZE = 100

ssm_client = boto3.client('ssm')
ecs_client = boto3.client('ecs')
ecr_client = boto3.client('ecr')

class Image:
    """
    Utility class for holding relevant information about an image.
    """
    def __init__(self, data):
        self.data = data
        self.digest = data['imageDigest']
        self.tags = data.get('imageTags')
        self.pushed_at = data['imagePushedAt']
        self._status = None

    @property
    def status(self):
        """ The current status of the image. """
        return self._status

    def set_status(self, status):
        """ Sets the status to a valid value unless status has already been set. """
        if self._status:
            log({'msg': f"Attempt to set non-null status '{self._status}' to '{status}'"})
        elif status not in (DELETE, PROTECT,):
            log({'msg': f"Attempt to set status to invalid value '{status}'"})
        else:
            self._status = status

    def __lt__(self, other):
        return self.pushed_at < other.pushed_at

    def __repr__(self):
        return f'{self.tags}, {self.pushed_at}, {self.status}'

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


def get_images_to_delete_from_repo(client, repo_name, strategies, protected_refs):
    """
    Fetches all images for repo_name and returns those eligible for deletion:
    1. Not referenced in protected_refs
    2. Marked for deletion by a strategy

    Arguments:
    client         -- an ecr client
    repo_name      -- name of repository to check
    strategies     -- sequence of strategies for protecting/deleting images
    protected_refs -- sequence of image references that should not be deleted
    """
    images = []
    paginator = client.get_paginator('describe_images')
    for page in paginator.paginate(repositoryName=repo_name):
        for image in page['imageDetails']:
            images.append(Image(image))

    for img in images:
        if img.digest in protected_refs or \
           img.tags and any(tag in protected_refs for tag in img.tags):
            img.set_status(PROTECT)

    for strategy, *args in strategies:
        STRATEGIES[strategy](images, *args)

    return [img for img in images if img.status == DELETE]

def get_images_to_delete(repo_config) -> dict[str, list[Image]]:
    """
    Returns images to delete from either a single repository or all repositories
    in strategies.REPO_STRATEGIES.

    Arguments:
    repo -- the specifc repository to fetch images from or 'all' for all
    """
    try:
        protected_refs = get_protected_image_refs(ecs_client)
    except ClientError as e:
        log({'msg': f'Unable to retrieve protected_refs: {e}'})
        return []

    log({'msg': 'Built protected image set from running ECS tasks',
         'repos': list(protected_refs)})

    to_delete = {}
    for repo_name, config in repo_config.items():
        try:
            to_delete[repo_name] = get_images_to_delete_from_repo(ecr_client,
                                                                  repo_name,
                                                                  config['strategies'],
                                                                  protected_refs)
        except ClientError as e:
            log({'msg': f'Error retrieving images from repo {repo_name}: {e}',
                 'repo': repo_name})
    return to_delete

def get_repo_list(client, ssm_param_name):
    """
    Read an SSM SecureString parameter and return a list of ECR repository names.
    Note: this uses SecureString to maintain compatibility with the existing SOPS mechanism.
    """
    try:
        response = client.get_parameter(Name=ssm_param_name, WithDecryption=True)
        value = response['Parameter']['Value']
    except ClientError as e:
        value = "[]"
        log({'msg': f'Failed to retrieve parameter {ssm_param_name}: {e}'})
    return json.loads(value)


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
            resp = client.describe_tasks(cluster=cluster_arn, tasks=batch)

            if resp.get('failures'):
                log({'msg': 'describe_tasks error, protected refs may be incomplete',
                     'cluster': cluster_arn,
                     'failures': resp['failures']})

            for task in resp['tasks']:
                for container in task.get('containers', []):
                    _, ref = parse_image_ref(container.get('image', ''))
                    refs.add(ref)
    return refs


def delete_images(client, repo_name, images):
    """Deletes the given images from the ECR repository in batches."""
    image_ids = [{'imageDigest': img.digest} for img in images]
    for i in range(0, len(image_ids), AWS_BATCH_SIZE):
        batch = image_ids[i:i + AWS_BATCH_SIZE]
        resp = client.batch_delete_image(repositoryName=repo_name, imageIds=batch)

        if resp.get('failures'):
            log({'msg': 'Batch image deletion error',
                 'repo': repo_name,
                 'failures': resp['failures']})

def log_images_for_deletion(repo, images):
    """Logs images that would be deleted if the repo were opted in."""
    for img in images:
        log({'msg': 'Would delete image (not opted in)', 'repo': repo,
             'digest': img.digest})

def lambda_handler(_, __):
    """
    Main entry point for lambda function.
    Reads configured repos from SSM, which are opted in for lambda to clean up.
    Reviews active ECS task definitions, then deletes eligible images that
    are old enough and no longer running.
    For repos associated with the app but not opted in, logs images that would
    be deleted without taking action.
    """
    env = os.environ['ENV']
    ssm_param = f"/{os.environ['APP']}/{env}/ecr-cleanup/repos"

    repo_config: dict[str, list[str]] = json.loads(get_repo_list(ssm_client, ssm_param))[env]

    for repo_name, to_delete in get_images_to_delete(repo_config).items():
        if repo_config[repo_name]['opt_in']:
            try:
                delete_images(ecr_client, repo_name, to_delete)
            except ClientError as e:
                log({'msg': f'Error deleting images from repo {repo_name}: {e}', 'repo': repo_name})
        else:
            log_images_for_deletion(repo_name, to_delete)
        log({'msg': f'Cleanup complete for repo: {repo_name}', 'repo': repo_name})
    log({
        'msg': 'ECR cleanup lambda completed',
        'app': os.environ['APP'],
        'env': os.environ['ENV'],
    })

def run(args):
    """ Prints tags of (or digest of untagged) images that would be deleted. """
    repo = args.repo
    ssm_param = f"/{args.app}/{args.env}/ecr-cleanup/repos"

    repo_config: dict[str, list[str]] = json.loads(get_repo_list(ssm_client, ssm_param))[args.env]
    if repo == 'all':
        to_delete = get_images_to_delete(repo_config)
    elif repo in repo_config:
        to_delete = get_images_to_delete({repo: repo_config[repo]})
    else:
        print(f'{repo} not configured')
        sys.exit(1)
    for repo_name, deleteable in to_delete.items():
        print(repo_name)
        for image in deleteable:
            print(f'  {image.tags or image.digest}')

if __name__ == '__main__':
    parser = ArgumentParser(description='Prints tags of images that would be deleted')
    parser.add_argument('repo', help='repository to analyze')
    parser.add_argument('app', help='application to check')
    parser.add_argument('env', choices=['test', 'prod',], help='environment to check')
    run(parser.parse_args())
