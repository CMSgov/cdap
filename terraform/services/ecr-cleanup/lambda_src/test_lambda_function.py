"""
Unit tests for ECR cleanup Lambda.
"""
import json
import os
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch

import pytest

import lambda_function
from lambda_function import KEEP_COUNT, MAX_AGE_DAYS

# pytest fixtures are referenced by parameter name, which pylint flags as redefining outer scope
# pylint: disable=redefined-outer-name



ECR_REGISTRY = '123456789.dkr.ecr.us-east-1.amazonaws.com'
CLUSTER_ARN = 'arn:aws:ecs:us-east-1:123456789:cluster/my-cluster'

# Datetime outside the retention window - images pushed at this datetime are eligible for deletion
EXPIRED_DATETIME = datetime.now(timezone.utc) - timedelta(days=MAX_AGE_DAYS + 15)


@pytest.mark.parametrize("uri,expected_repo,expected_ref", [
    (
        f"{ECR_REGISTRY}/dpc-attribution@sha256:87654321",
        "dpc-attribution",
        "sha256:87654321",
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
    """Builds an ECR image detail dict with the given digest, tags, and push timestamp."""
    return {
        'imageDigest': digest,
        'imageTags': tags,
        'imagePushedAt': pushed_at,
    }


def _make_ecr_client_mock(images):
    """Creates a mock ECR client that returns the given images from describe_images."""
    mock_ecr = MagicMock()
    mock_paginator = MagicMock()
    mock_paginator.paginate.return_value = iter([{'imageDetails': images}])
    mock_ecr.get_paginator.return_value = mock_paginator
    return mock_ecr


def test_protected_by_tag():
    """Image referenced by tag in protected_refs is not deleted even if old."""
    images = [_make_image('sha256:protected', ['v1.0'], EXPIRED_DATETIME)]
    result = lambda_function.get_images_to_delete(
        _make_ecr_client_mock(images), 'dpc-attribution', {'v1.0'}
    )
    assert result == []


def test_protected_by_digest():
    """Image referenced by digest in protected_refs is not deleted."""
    images = [_make_image('sha256:abc', [], EXPIRED_DATETIME)]
    result = lambda_function.get_images_to_delete(
        _make_ecr_client_mock(images), 'dpc-attribution', {'sha256:abc'}
    )
    assert result == []


def test_keep_count_respected():
    """Only images beyond KEEP_COUNT are eligible for deletion."""
    images = [_make_image(f'sha256:{i}', [f'v{i}'], EXPIRED_DATETIME)
              for i in range(KEEP_COUNT + 2)]
    result = lambda_function.get_images_to_delete(
        _make_ecr_client_mock(images), 'dpc-attribution', set()
    )
    assert len(result) == 2


def test_recent_images_still_kept():
    """Images within the retention window are never deleted regardless of count."""
    num_images_to_create = KEEP_COUNT + 3
    recent_datetime = datetime.now(timezone.utc) - timedelta(days=1)
    images = [
        _make_image(f'sha256:{i}', [f'v{i}'], recent_datetime)
        for i in range(1, num_images_to_create)
    ]
    result = lambda_function.get_images_to_delete(
        _make_ecr_client_mock(images), 'dpc-attribution', set()
    )
    assert result == []


def test_old_images_deleted():
    """Unprotected image older than MAX_AGE_DAYS and outside KEEP_COUNT is returned for deletion."""
    recent_datetime = datetime.now(timezone.utc) - timedelta(days=1)
    kept_images = [
        _make_image(f'sha256:keep{i}', [f'new{i}'], recent_datetime)
        for i in range(KEEP_COUNT)
    ]
    old = [_make_image('sha256:old1', ['old1'], EXPIRED_DATETIME)]
    to_delete = lambda_function.get_images_to_delete(
        _make_ecr_client_mock(kept_images + old), 'dpc-attribution', set()
    )
    assert len(to_delete) == 1
    assert to_delete[0]['imageDigest'] == 'sha256:old1'


def test_no_images_for_repo():
    """Returns an empty list when the repo has no images."""
    result = lambda_function.get_images_to_delete(
        _make_ecr_client_mock([]), 'dpc-attribution', set()
    )
    assert result == []


def test_get_repo_list():
    """SSM parameter value is parsed as a JSON list of repo names."""
    mock_ssm = MagicMock()
    mock_ssm.get_parameter.return_value = {'Parameter': {'Value': '["dpc-attribution", "dpc-api"]'}}
    assert lambda_function.get_repo_list(mock_ssm, '/test/param') == ['dpc-attribution', 'dpc-api']
    mock_ssm.get_parameter.assert_called_once_with(Name='/test/param', WithDecryption=True)


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
        mock_ssm, mock_ecs, mock_ecr, opted_in_repos=['dpc-attribution'],
        cluster_arns=None, task_arns=None, task_images=None, ecr_images=None):
    """Configures SSM, ECS, and ECR client mocks for lambda_handler integration tests."""
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
    recent_datetime = datetime.now(timezone.utc) - timedelta(days=1)
    recent = [
        _make_image(f'sha256:new{i}', [f'new{i}'], recent_datetime)
        for i in range(1, KEEP_COUNT + 1)
    ]
    old_image = _make_image('sha256:old', ['old-tag'], EXPIRED_DATETIME)
    _setup_handler_mocks(mock_ssm, mock_ecs, mock_ecr, ecr_images=recent + [old_image])
    with patch.dict(os.environ, {'APP': 'dpc', 'ENV': 'test'}):
        lambda_function.lambda_handler({}, None)
    mock_ecr.batch_delete_image.assert_called_once_with(
        repositoryName='dpc-attribution',
        imageIds=[{'imageDigest': 'sha256:old'}]
    )


def test_lambda_handler_protects_images_in_running_tasks(mock_boto3_clients):
    """Image referenced by a running ECS task is never deleted even if old."""
    mock_ssm, mock_ecs, mock_ecr = mock_boto3_clients
    old_image = _make_image('sha256:old', ['protected-tag'], EXPIRED_DATETIME)
    _setup_handler_mocks(
        mock_ssm, mock_ecs, mock_ecr,
        cluster_arns=[CLUSTER_ARN],
        task_arns=[f'{CLUSTER_ARN}/task1'],
        task_images=[f'{ECR_REGISTRY}/dpc-attribution:protected-tag'],
        ecr_images=[old_image],
    )
    with patch.dict(os.environ, {'APP': 'dpc', 'ENV': 'test'}):
        lambda_function.lambda_handler({}, None)
    mock_ecr.batch_delete_image.assert_not_called()
