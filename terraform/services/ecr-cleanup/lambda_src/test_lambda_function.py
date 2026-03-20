"""
Unit tests for ECR cleanup Lambda.
"""

import json
import os
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch

import pytest
from botocore.exceptions import ClientError

import lambda_function
import strategies

# pytest fixtures are referenced by parameter name, which pylint flags as redefining outer scope
# pylint: disable=redefined-outer-name

ECR_REGISTRY = '123456789.dkr.ecr.us-east-1.amazonaws.com'
CLUSTER_ARN = 'arn:aws:ecs:us-east-1:123456789:cluster/my-cluster'
EXPIRED_DATETIME = datetime.now(timezone.utc) - timedelta(days=200)

@pytest.mark.parametrize("uri,expected_repo,expected_ref", [
    (
        f"{ECR_REGISTRY}/dpc-attribution@sha256:87654321",
        "dpc-attribution",
        "sha256:87654321",
    ),
    (
        f"{ECR_REGISTRY}/dpc-attribution:my-tag",
        "dpc-attribution",
        "my-tag",
    ),
    (
        "dpc-attribution",
        "dpc-attribution",
        None,
    ),
])
def test_parse_image_ref(uri, expected_repo, expected_ref):
    """Tests that digest URIs and plain repo names are parsed correctly."""
    repo, ref = lambda_function.parse_image_ref(uri)
    assert repo == expected_repo
    assert ref == expected_ref

def make_image(digest, tags, pushed_at):
    """Builds an Image with the given digest, tags, and push timestamp."""
    data = {
        'imageDigest': digest,
        'imagePushedAt': pushed_at,
    }
    if tags:
        data['imageTags'] = tags

    return lambda_function.Image(data)

def _make_ecr_client_mock(images):
    """Creates a mock ECR client that returns the given image data from describe_images."""
    mock_ecr = MagicMock()
    mock_paginator = MagicMock()
    image_data = [image.data for image in images]
    mock_paginator.paginate.return_value = iter([{'imageDetails': image_data}])
    mock_ecr.get_paginator.return_value = mock_paginator
    return mock_ecr

def make_test_images():
    """ Creates six Images:
          3 that match the default 'v' prefix, ordered newest to oldest, one day apart
          3 that do not match the default 'v' prefix, ordered newest to oldest, one day apart
    """
    images = []
    for i in range(3):
        pushed_at = datetime.now(timezone.utc) - timedelta(days=i, minutes=15)
        images.append(make_image(f'sha256:{i}', [f'v{i}'], pushed_at))
        images.append(make_image(f'sha256:{i + 3}', [f'not_v{i}'], pushed_at))
    return sorted(images, key=lambda x: x.digest)

def test_get_images_to_delete_from_repo():
    """ Tests base functionality of get images to delete. """
    pb_tag_digest = 'sha256:protected_by_tag'
    pb_digest_digest = 'sha256:protected_by_digest'
    pb_tag_image = make_image(pb_tag_digest, ['vpbtag'], EXPIRED_DATETIME)
    pb_digest_image = make_image(pb_digest_digest, ['vpbdigest'], EXPIRED_DATETIME)
    images = make_test_images()
    images.append(pb_tag_image)
    images.append(pb_digest_image)
    strategy_list = (
        (strategies.days_older_than_strategy, 'not_v', 2),
        (strategies.count_image_strategy, 'v', 2),
    )

    result = lambda_function.get_images_to_delete_from_repo(
        _make_ecr_client_mock(images),
        'some-repo',
        strategy_list,
        pb_tag_image.tags + [pb_digest_image.digest,],
    )
    assert len(result) == 2
    result_digests = { image.digest for image in result }
    assert images[2].digest in result_digests
    assert images[5].digest in result_digests
    assert pb_tag_digest not in result_digests
    assert pb_digest_digest not in result_digests

def test_get_images_to_delete_from_repo_none_prefix():
    """ Make sure get_images_to_delete_from_repo can handle untagged image. """
    image_digest = 'sha256:image'
    image = make_image(image_digest, None, EXPIRED_DATETIME)
    strategy = (strategies.days_older_than_strategy, None, 14,)

    result = lambda_function.get_images_to_delete_from_repo(
        _make_ecr_client_mock((image,)), 'some-repo', (strategy,), (),
    )
    assert len(result) == 1
    assert result[0].digest == image_digest

@pytest.mark.parametrize("strategy_list, expected_count", [
    (
        ((strategies.count_image_strategy, 'v', 2),
         (strategies.days_older_than_strategy, 'v', 2),),
        0,
    ),
    (
        ((strategies.days_older_than_strategy, 'v', 2),
         (strategies.count_image_strategy, 'v', 2),),
        1,
    ),
])
def test_get_images_to_delete_from_repo_strategy_order(strategy_list, expected_count):
    """
    Tests that images protected by an early strategy are not deleted by a later strategy,
    and that images deleted by an early strategy are not protected by a later strategy.
    """
    image_digest = 'sha256:image'
    image = make_image(image_digest, ['v1'], EXPIRED_DATETIME)

    result = lambda_function.get_images_to_delete_from_repo(
        _make_ecr_client_mock((image,)), 'some-repo', strategy_list, (),
    )
    assert len(result) == expected_count

def test_get_images_to_delete_protect_untagged_task_definition():
    """ Make sure to protect the 'latest' image if running task definition not have tag. """
    image_count = 4
    images = [ make_image(f'sha265:{i}', f'v{i}',datetime.now(timezone.utc) - timedelta(days=i))
                           for i in range(image_count) ]
    def delete_all_strategy(images):
        for image in images:
            if image.status:
                continue
            image.set_status(strategies.DELETE)

    result = lambda_function.get_images_to_delete_from_repo(
        _make_ecr_client_mock(images), 'some-repo', ((delete_all_strategy,),), (None,),
    )
    assert len(result) == image_count - 1
    assert images[0].digest not in [image.digest for image in result]

def test_get_images_to_delete_from_repo_no_images_for_repo():
    """Returns an empty list when the repo has no images."""
    result = lambda_function.get_images_to_delete_from_repo(
        _make_ecr_client_mock([]), 'dpc-attribution', set(), set()
    )
    assert result == []

def test_get_images_to_delete_all():
    """
    Make sure all repos are hit.
    """
    with patch('lambda_function.get_images_to_delete_from_repo') as mock_from_repo:
        lambda_function.get_images_to_delete(strategies.REPO_STRATEGIES)
    assert mock_from_repo.call_count == len(strategies.REPO_STRATEGIES)

def test_get_images_to_delete_single(mock_boto3_clients):
    """
    Make sure only single repo is hit.
    """
    repo_name = 'test-repo'
    strategy_list = (
        (strategies.days_older_than_strategy, 'not_v', 2),
        (strategies.count_image_strategy, 'v', 2),
    )

    strategy_dict = {repo_name: strategy_list}
    with patch('lambda_function.get_images_to_delete_from_repo') as mock_from_repo:
        lambda_function.get_images_to_delete(strategy_dict)
    assert mock_from_repo.call_count == 1
    mock_from_repo.assert_called_once_with(
        mock_boto3_clients[-1],
        repo_name,
        strategy_list,
        set(),
    )

def test_get_images_to_delete_on_error():
    """
    Make sure get_images_to_delete_from_repo does not call get_images_to_delete_from_repo
    if error getting protected images.
    """
    with patch('lambda_function.get_images_to_delete_from_repo') as mock_from_repo, \
         patch('lambda_function.get_protected_image_refs',
               side_effect=ClientError({}, 'get_paginator')):
        lambda_function.get_images_to_delete(strategies.REPO_STRATEGIES)
    assert mock_from_repo.call_count == 0

def test_delete_images_single_image():
    """A single image is deleted with one batch_delete_image call."""
    mock_ecr = MagicMock()
    one_old_image = [make_image('sha256:abc', [], None)]
    lambda_function.delete_images(mock_ecr, 'dpc-attribution', one_old_image)
    mock_ecr.batch_delete_image.assert_called_once_with(
        repositoryName='dpc-attribution',
        imageIds=[{'imageDigest': 'sha256:abc'}],
    )

def test_delete_images_multiple_batches():
    """Images exceeding AWS_BATCH_SIZE are sent in multiple batch_delete_image calls."""
    mock_ecr = MagicMock()
    num_ecr_images = lambda_function.AWS_BATCH_SIZE + 1
    old_images = [make_image(f'sha256:{i}', [], None) for i in range(num_ecr_images)]
    lambda_function.delete_images(mock_ecr, 'dpc-attribution', old_images)
    assert mock_ecr.batch_delete_image.call_count == 2
    first_call_ids = mock_ecr.batch_delete_image.call_args_list[0].kwargs['imageIds']
    second_call_ids = mock_ecr.batch_delete_image.call_args_list[1].kwargs['imageIds']
    assert len(first_call_ids) == lambda_function.AWS_BATCH_SIZE
    assert len(second_call_ids) == 1

def test_delete_images_empty_list():
    """ Makes sure delete_images does not throw error on empty list. """
    mock_ecr = MagicMock()
    lambda_function.delete_images(mock_ecr, 'some-repo', [])
    mock_ecr.batch_delete_image.assert_not_called()

def test_get_repo_list():
    """SSM parameter value is parsed as a JSON list of repo names."""
    mock_ssm = MagicMock()
    mock_ssm.get_parameter.return_value = {'Parameter': {'Value': '["dpc-attribution", "dpc-api"]'}}
    assert lambda_function.get_repo_list(mock_ssm, '/test/param') == ['dpc-attribution', 'dpc-api']
    mock_ssm.get_parameter.assert_called_once_with(Name='/test/param', WithDecryption=True)

def test_get_repo_list_parameter_not_found():
    """Returns an empty list when the SSM parameter does not exist."""
    mock_ssm = MagicMock()
    failed_to_find_message = {
        "Error": {
            "Code": "ParameterNotFound",
            "Message": "Parameter not found",
        }
    }
    mock_ssm.get_parameter.side_effect = ClientError(failed_to_find_message, "get_parameter")
    assert lambda_function.get_repo_list(mock_ssm, '/param/not/found') == []

def _make_ecs_mock(cluster_arns, task_arns, task_definitions):
    """Creates a mock ECS client returning the given clusters, tasks, and task definitions."""
    mock_ecs = MagicMock()

    def paginator_side_effect(operation):
        pager = MagicMock()
        if operation == 'list_clusters':
            pager.paginate.return_value = iter([{'clusterArns': cluster_arns}])
        elif operation == 'list_tasks':
            pager.paginate.return_value = iter([{'taskArns': task_arns}])
        return pager

    mock_ecs.get_paginator.side_effect = paginator_side_effect
    mock_ecs.describe_tasks.return_value = {
        'tasks': task_definitions
    }
    return mock_ecs

@pytest.mark.parametrize("task_definitions, expected", [
    ([{'containers': [{'image': f'{ECR_REGISTRY}/dpc-attribution:v1.0'}]},
      {'containers': [{'image': f'{ECR_REGISTRY}/dpc-attribution:v2.0'}]},],
     {'dpc-attribution': {'v1.0', 'v2.0'},},),
    ([{'containers': [{'image': f'{ECR_REGISTRY}/dpc-attribution'},],},],
     {'dpc-attribution': {None},},),
    ([{'containers': [{'not_image_key': 'not_image',},],},],
     {},),
    ([{'containers': [{'not_image_key': 'not_image'}]},
      {'containers': [{'image': f'{ECR_REGISTRY}/dpc-attribution:v1.0'}]},],
     {'dpc-attribution': {'v1.0'},},),
    ([{'not_containers': 'not_container'},],
     {},),
])
def test_get_protected_image_refs(task_definitions, expected):
    """Tags from running task containers are returned as protected refs."""
    mock_ecs = _make_ecs_mock(
        cluster_arns=[CLUSTER_ARN],
        task_arns=[f'{CLUSTER_ARN}/task1', f'{CLUSTER_ARN}/task2'],
        task_definitions=task_definitions
    )
    assert lambda_function.get_protected_image_refs(mock_ecs) == expected

def test_get_protected_image_refs_on_error():
    """Tags from running task containers are returned as protected refs."""
    mock_ecs = MagicMock()
    mock_ecs.get_paginator.side_effect = ClientError({}, 'get_paginator')
    with pytest.raises(ClientError):
        lambda_function.get_protected_image_refs(mock_ecs)

@pytest.fixture(autouse=True)
def mock_boto3_clients():
    """Patches the module-level boto3 clients used by the lambda handler."""
    with patch('lambda_function.ssm_client') as mock_ssm, \
         patch('lambda_function.ecs_client') as mock_ecs, \
         patch('lambda_function.ecr_client') as mock_ecr:
        yield mock_ssm, mock_ecs, mock_ecr

def _setup_handler_mocks(  # pylint: disable=too-many-arguments,too-many-positional-arguments
        mock_ssm, mock_ecs, mock_ecr, opted_in_repos=None,
        cluster_arns=None, task_arns=None, task_images=None, ecr_images=None):
    """Configures SSM, ECS, and ECR client mocks for lambda_handler integration tests."""
    if opted_in_repos is None:
        opted_in_repos = ['dpc-attribution']
    mock_ssm.get_parameter.return_value = {
        'Parameter': {'Value': json.dumps(opted_in_repos)}
    }

    def ecs_paginator_side_effect(operation):
        pager = MagicMock()
        if operation == 'list_clusters':
            pager.paginate.return_value = iter([{'clusterArns': cluster_arns or []}])
        elif operation == 'list_tasks':
            pager.paginate.return_value = iter([{'taskArns': task_arns or []}])
        return pager

    mock_ecs.get_paginator.side_effect = ecs_paginator_side_effect
    if task_arns and task_images:
        mock_ecs.describe_tasks.return_value = {
            'tasks': [{'containers': [{'image': img}]} for img in task_images]
        }

    repos_page = [{'repositoryName': r} for r in opted_in_repos]

    def ecr_paginator_side_effect(operation):
        pager = MagicMock()
        if operation == 'describe_repositories':
            pager.paginate.return_value = iter([{'repositories': repos_page}])
        else:
            pager.paginate.return_value = iter([{'imageDetails': ecr_images or []}])
        return pager

    mock_ecr.get_paginator.side_effect = ecr_paginator_side_effect

def test_lambda_handler_deletes_old_unprotected_images(mock_boto3_clients):
    """ Old image is deleted; recent images are kept."""
    mock_ssm, mock_ecs, mock_ecr = mock_boto3_clients
    old_image = make_image('sha256:old', ['unprotected-tag'], EXPIRED_DATETIME).data
    new_image = make_image('sha256:old', ['unprotected-tag'], datetime.now(timezone.utc)).data
    _setup_handler_mocks(
        mock_ssm, mock_ecs, mock_ecr,
        ecr_images=[old_image, new_image],
    )
    with patch.dict(os.environ, {'APP': 'cdap', 'ENV': 'test'}):
        lambda_function.lambda_handler({}, None)
    mock_ecr.batch_delete_image.assert_called_once_with(
        repositoryName='dpc-attribution',
        imageIds=[{'imageDigest': 'sha256:old'}]
    )

def test_lambda_handler_protects_images_in_running_tasks(mock_boto3_clients):
    """Image referenced by a running ECS task is never deleted even if old."""
    mock_ssm, mock_ecs, mock_ecr = mock_boto3_clients
    old_image = make_image('sha256:old', ['protected-tag'], EXPIRED_DATETIME).data
    _setup_handler_mocks(
        mock_ssm, mock_ecs, mock_ecr,
        cluster_arns=[CLUSTER_ARN],
        task_arns=[f'{CLUSTER_ARN}/task1'],
        task_images=[f'{ECR_REGISTRY}/dpc-attribution:protected-tag'],
        ecr_images=[old_image],
    )
    with patch.dict(os.environ, {'APP': 'cdap', 'ENV': 'test'}):
        lambda_function.lambda_handler({}, None)
    mock_ecr.batch_delete_image.assert_not_called()

@pytest.mark.parametrize("existing,new,expected", [
    ( None, None, None,),
    ( None, strategies.PROTECT, strategies.PROTECT,),
    ( None, strategies.DELETE, strategies.DELETE,),
    ( None, 'invalid', None,),
    ( strategies.PROTECT, strategies.DELETE, strategies.PROTECT,),
])
def test_image_set_status(existing, new, expected):
    """ Test iamge status not overwritten or set to invalid value. """
    image = make_image(None, None, None)
    if existing:
        image.set_status(existing)
    image.set_status(new)
    assert image.status == expected
