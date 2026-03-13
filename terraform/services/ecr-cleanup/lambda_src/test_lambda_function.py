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
        "latest",
    ),
])
def test_parse_image_ref(uri, expected_repo, expected_ref):
    """Tests that digest URIs and plain repo names are parsed correctly."""
    repo, ref = lambda_function.parse_image_ref(uri)
    assert repo == expected_repo
    assert ref == expected_ref

def _make_image(digest, tags, pushed_at):
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

def _test_images():
    """ Creates six Images:
          3 that match the default 'v' prefix, ordered newest to oldest, one day apart
          3 that do not match the default 'v' prefix, ordered newest to oldest, one day apart
    """
    images = []
    for i in range(3):
        pushed_at = datetime.now(timezone.utc) - timedelta(days=i, minutes=15)
        images.append(_make_image(f'sha256:{i}', [f'v{i}'], pushed_at))
        images.append(_make_image(f'sha256:{i + 3}', [f'not_v{i}'], pushed_at))
    return sorted(images, key=lambda x: x.digest)

@pytest.mark.parametrize("tags,prefix,includes", [
    (('v1',), 'v', True,),
    (('a', 'b', 'c',), 'b', True,),
    (('anything',), '', True,),
    (None, None, True,),
    (('not_v',), 'v', False,),
    (('a', 'b', 'c',), 'd', False,),
    (('',), None, False,),
    (None, '', False,),
])
def test_matching_images(tags, prefix, includes):
    """ Make sure matching_images follows expectations. """
    image = _make_image('sha256:1', tags, EXPIRED_DATETIME)
    if includes:
        assert image in lambda_function.matching_images((image,), prefix)
    else:
        assert image not in lambda_function.matching_images((image,), prefix)

def test_count_image_strategy():
    """ Make sure count image strategy correctly marks images for matching prefixes. """
    images = _test_images()

    lambda_function.count_image_strategy(images, 'v', 1)
    for index, image in enumerate(images):
        if index == 0:
            assert image.status == lambda_function.PROTECT
        elif 1 <= index <= 2:
            assert image.status == lambda_function.DELETE
        else:
            assert image.status is None

def test_days_older_than_strategy():
    """ Make sure count image strategy correctly marks images for matching prefixes. """
    images = _test_images()

    lambda_function.days_older_than_strategy(images, 'v', 2)
    for index, image in enumerate(images):
        if index < 2:
            assert image.status == lambda_function.PROTECT
        elif index == 2:
            assert image.status == lambda_function.DELETE
        else:
            assert image.status is None

def test_get_images_to_delete():
    """ Tests base functionality of get images to delete. """
    pb_tag_digest = 'sha256:protected_by_tag'
    pb_digest_digest = 'sha256:protected_by_digest'
    pb_tag_image = _make_image(pb_tag_digest, ['vpbtag'], EXPIRED_DATETIME)
    pb_digest_image = _make_image(pb_digest_digest, ['vpbdigest'], EXPIRED_DATETIME)
    images = _test_images()
    images.append(pb_tag_image)
    images.append(pb_digest_image)
    strategies = (
        ('days_older_than', 'not_v', 2),
        ('count_image', 'v', 2),
    )

    result = lambda_function.get_images_to_delete(
        _make_ecr_client_mock(images),
        'some-repo',
        strategies,
        pb_tag_image.tags + [pb_digest_image.digest,],
    )
    assert len(result) == 2
    result_digests = { image.digest for image in result }
    assert images[2].digest in result_digests
    assert images[5].digest in result_digests
    assert pb_tag_digest not in result_digests
    assert pb_digest_digest not in result_digests

def test_get_images_to_delete_none_prefix():
    """ Make sure get_images_to_delete can handle untagged image. """
    image_digest = 'sha256:image'
    image = _make_image(image_digest, None, EXPIRED_DATETIME)
    strategy = ('days_older_than', None, 14,)

    result = lambda_function.get_images_to_delete(
        _make_ecr_client_mock((image,)), 'some-repo', (strategy,), (),
    )
    assert len(result) == 1


@pytest.mark.parametrize("strategies, expected_count", [
    (
        (('count_image', 'v', 2), ('days_older_than', 'v', 2),),
        0,
    ),
    (
        (('days_older_than', 'v', 2), ('count_image', 'v', 2),),
        1,
    ),
])
def test_get_images_to_delete_strategy_order(strategies, expected_count):
    """
    Tests that images protected by an early strategy are not deleted by a later strategy,
    and that images deleted by an early strategy are not protected by a later strategy.
    """
    image_digest = 'sha256:image'
    image = _make_image(image_digest, ['v1'], EXPIRED_DATETIME)

    result = lambda_function.get_images_to_delete(
        _make_ecr_client_mock((image,)), 'some-repo', strategies, (),
    )
    assert len(result) == expected_count

def test_no_images_for_repo():
    """Returns an empty list when the repo has no images."""
    result = lambda_function.get_images_to_delete(
        _make_ecr_client_mock([]), 'dpc-attribution', set(), set()
    )
    assert result == []

def test_delete_images_single_image():
    """A single image is deleted with one batch_delete_image call."""
    mock_ecr = MagicMock()
    one_old_image = [_make_image('sha256:abc', [], None)]
    lambda_function.delete_images(mock_ecr, 'dpc-attribution', one_old_image)
    mock_ecr.batch_delete_image.assert_called_once_with(
        repositoryName='dpc-attribution',
        imageIds=[{'imageDigest': 'sha256:abc'}],
    )

def test_delete_images_multiple_batches():
    """Images exceeding AWS_BATCH_SIZE are sent in multiple batch_delete_image calls."""
    mock_ecr = MagicMock()
    num_ecr_images = lambda_function.AWS_BATCH_SIZE + 1
    old_images = [_make_image(f'sha256:{i}', [], None) for i in range(num_ecr_images)]
    lambda_function.delete_images(mock_ecr, 'dpc-attribution', old_images)
    assert mock_ecr.batch_delete_image.call_count == 2
    first_call_ids = mock_ecr.batch_delete_image.call_args_list[0].kwargs['imageIds']
    second_call_ids = mock_ecr.batch_delete_image.call_args_list[1].kwargs['imageIds']
    assert len(first_call_ids) == lambda_function.AWS_BATCH_SIZE
    assert len(second_call_ids) == 1

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

def _make_ecs_mock(cluster_arns, task_arns, container_images):
    """Creates a mock ECS client returning the given clusters, tasks, and container images."""
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
        'tasks': [{'containers': [{'image': img}]} for img in container_images]
    }
    return mock_ecs

def test_get_protected_image_refs():
    """Tags from running task containers are returned as protected refs."""
    mock_ecs = _make_ecs_mock(
        cluster_arns=[CLUSTER_ARN],
        task_arns=[f'{CLUSTER_ARN}/task1', f'{CLUSTER_ARN}/task2'],
        container_images=[f'{ECR_REGISTRY}/dpc-attribution:v1.0',
                          f'{ECR_REGISTRY}/dpc-attribution:v2.0'],
    )
    assert lambda_function.get_protected_image_refs(mock_ecs) == {'v1.0', 'v2.0'}

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
    """Happy path: old image outside KEEP_COUNT is deleted; recent images are kept."""
    mock_ssm, mock_ecs, mock_ecr = mock_boto3_clients
    old_image = _make_image('sha256:old', ['unprotected-tag'], EXPIRED_DATETIME).data
    _setup_handler_mocks(
        mock_ssm, mock_ecs, mock_ecr,
        ecr_images=[old_image],
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
    old_image = _make_image('sha256:old', ['protected-tag'], EXPIRED_DATETIME).data
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
