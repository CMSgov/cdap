"""
Cleans up old ECR images while protecting images referenced by currently running ECS tasks.
"""

from argparse import ArgumentParser
from collections import defaultdict
from datetime import datetime, timedelta, timezone
import json
import os
import sys

import boto3
from botocore.exceptions import ClientError

AWS_BATCH_SIZE = 100

ssm_client = boto3.client('ssm')
ecs_client = boto3.client('ecs')
ecr_client = boto3.client('ecr')

DELETE = 'to_delete'
PROTECT = 'to_protect'


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
    return last_component, None


def get_images_to_delete(client, repo_name, strategies, protected_refs):
    """
    Fetches all images for repo_name and returns those eligible for deletion:
    1. Not referenced in protected_refs,
    2. Outside the KEEP_COUNT newest
    3. Older than MAX_AGE_DAYS.
    """
    images = []
    paginator = client.get_paginator('describe_images')
    for page in paginator.paginate(repositoryName=repo_name):
        for image in page['imageDetails']:
            images.append(Image(image))

    if not images:
        return images

    # Protext running images
    for img in images:
        if img.digest in protected_refs or \
           img.tags and any(tag in protected_refs for tag in img.tags):
            img.set_status(PROTECT)
    if None in protected_refs:
        latest = sorted(images, reverse=True)[0]
        latest.set_status(PROTECT)

    # Apply lifecycle strategies
    for strategy, *args in strategies:
        strategy(images, *args)

    return [img for img in images if img.status == DELETE]


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
    refs = defaultdict(set)

    cluster_arns = []
    for page in client.get_paginator('list_clusters').paginate():
        cluster_arns.extend(page['clusterArns'])

    for cluster_arn in cluster_arns:
        add_protected_image_refs_in_cluster(client, cluster_arn, refs)
    return refs


def add_protected_image_refs_in_cluster(client, cluster_arn, refs):
    """ Add the image refs running in a cluster. """
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
                try:
                    for container in task['containers']:
                        repo, ref = parse_image_ref(container['image'])
                        refs[repo].add(ref)
                except KeyError:
                    pass # Nothing to do if no containers or no image
        except ClientError as e:
            log({'msg': f'Error describing tasks in cluster {cluster_arn}: {e}'})


def delete_images(client, repo_name, images):
    """Deletes the given images from the ECR repository in batches."""
    image_ids = [{'imageDigest': img.digest} for img in images]
    for i in range(0, len(image_ids), AWS_BATCH_SIZE):
        batch = image_ids[i:i + AWS_BATCH_SIZE]
        client.batch_delete_image(repositoryName=repo_name, imageIds=batch)

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
    ssm_param = f"/{os.environ['APP']}/{os.environ['ENV']}/ecr-cleanup/repos"

    opted_in = set(get_repo_list(ssm_client, ssm_param))

    protected_refs = get_protected_image_refs(ecs_client)
    log({'msg': 'Built protected image set from running ECS tasks',
         'repos': list(protected_refs)})

    for repo_name, strategies in REPO_STRATEGIES.items():
        try:
            to_delete = get_images_to_delete(ecr_client,
                                             repo_name,
                                             strategies,
                                             protected_refs[repo_name])

            if to_delete:
                if repo_name in opted_in:
                    delete_images(ecr_client, repo_name, to_delete)
                else:
                    log_images_for_deletion(repo_name, to_delete)
            log({'msg': f'Cleanup complete for repo: {repo_name}'})
        except ClientError as e:
            log({'msg': f'Error processing repo {repo_name}: {e}', 'repo': repo_name})

class Image:
    """
    Data class for holding relevant information about an image.
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

def images_matching_prefix(images, prefix):
    """ Returns images whose status has not been set and have a tag that starts with prefix. """
    matching_images = []
    for image in images:
        if image.status:
            continue
        if prefix is None or image.tags is None:
            if prefix == image.tags:
                matching_images.append(image)
            continue
        for tag in image.tags:
            if tag.startswith(prefix):
                matching_images.append(image)
                break
    return matching_images

def count_image_strategy(images, prefix, count):
    """ Marks images to delete or protect based on pushed date and count. """
    matching_images = images_matching_prefix(images, prefix)
    for index, image in enumerate(sorted(matching_images, reverse=True)):
        if index < count:
            image.set_status(PROTECT)
        else:
            image.set_status(DELETE)

def days_older_than_strategy(images, prefix, days):
    """ Marks images to delete or protect based on cutoff date. """
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    matching_images = images_matching_prefix(images, prefix)
    for image in matching_images:
        if image.pushed_at > cutoff:
            image.set_status(PROTECT)
        else:
            image.set_status(DELETE)

DPC_STRATEGIES = (
    (count_image_strategy, 'rls-r', 5,),
    (days_older_than_strategy, '', 14,),
    (days_older_than_strategy, None, 14,),
)

REPO_STRATEGIES = {
    'dpc-aggregation': DPC_STRATEGIES,
    'dpc-api': DPC_STRATEGIES,
    'dpc-attribution': DPC_STRATEGIES,
    'dpc-web': DPC_STRATEGIES,
    'dpc-web-admin': DPC_STRATEGIES,
    'dpc-web-portal': DPC_STRATEGIES,
}

def run(args):
    """ Prints tags of (or digest of untagged) images that would be deleted. """
    repo = args.repo
    if repo != 'all' and repo not in REPO_STRATEGIES:
        print(f'{repo} not configured')
        sys.exit(1)
    protected = get_protected_image_refs(ecs_client)
    for repo_name, strategies in REPO_STRATEGIES.items():
        if repo in ('all', repo_name):
            print(repo_name)
            for image in get_images_to_delete(ecr_client, repo_name, strategies, protected):
                print(f'  {image.tags or image.digest}')


if __name__ == '__main__':
    parser = ArgumentParser(description='Prints tags of images that would be deleted')
    parser.add_argument('repo', help='repository to analyze')
    run(parser.parse_args())
