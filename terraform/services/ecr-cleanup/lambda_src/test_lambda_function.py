"""
Unit tests for ECR cleanup Lambda.
"""
import os
import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch
import lambda_function


@pytest.mark.parametrize("uri,expected_repo,expected_ref", [
    (
        "123456789.dkr.ecr.us-east-1.amazonaws.com/dpc-attribution@sha256:87654321",
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
    repo, ref = lambda_function.parse_image_ref(uri)
    assert repo == expected_repo
    assert ref == expected_ref


def make_image(digest, tags, days_ago):
    return {
        'imageDigest': digest,
        'imageTags': tags,
        'imagePushedAt': datetime.now(timezone.utc) - timedelta(days=days_ago),
    }


def test_protected_image_is_never_deleted():
    images = [make_image('sha256:protected', ['v1.0'], days_ago=60)]
    assert lambda_function.get_images_to_delete(images, {'v1.0'}) == []


def test_protected_by_digest():
    images = [make_image('sha256:abc', [], days_ago=60)]
    assert lambda_function.get_images_to_delete(images, {'sha256:abc'}) == []


def test_keep_count_respected():
    images = [make_image(f'sha256:{i}', [f'v{i}'], days_ago=i * 5) for i in range(1, 8)]
    assert len(lambda_function.get_images_to_delete(images, set())) <= 2


def test_recent_images_beyond_keep_count_are_skipped():
    images = [make_image(f'sha256:{i}', [f'v{i}'], days_ago=i) for i in range(1, 8)]
    assert lambda_function.get_images_to_delete(images, set()) == []


def test_old_images_beyond_keep_count_are_deleted():
    keep = [make_image(f'sha256:keep{i}', [f'new{i}'], days_ago=i) for i in range(1, 6)]
    old = [make_image('sha256:old1', ['old1'], days_ago=45)]
    to_delete = lambda_function.get_images_to_delete(keep + old, set())
    assert len(to_delete) == 1
    assert to_delete[0]['imageDigest'] == 'sha256:old1'


def test_empty_repo():
    assert lambda_function.get_images_to_delete([], set()) == []


def test_get_repo_list():
    mock_ssm = MagicMock()
    mock_ssm.get_parameter.return_value = {'Parameter': {'Value': 'dpc-attribution,dpc-api'}}
    assert lambda_function.get_repo_list(mock_ssm, '/test/param') == ['dpc-attribution', 'dpc-api']


def _make_ecs_mock(task_def_arns, container_images):
    mock_ecs = MagicMock()
    mock_paginator = MagicMock()
    mock_paginator.paginate.return_value = iter([{'taskDefinitionArns': task_def_arns}])
    mock_ecs.get_paginator.return_value = mock_paginator
    mock_ecs.describe_task_definition.side_effect = [
        {'taskDefinition': {'containerDefinitions': [{'image': img}]}}
        for img in container_images
    ]
    return mock_ecs


def test_get_protected_image_refs():
    mock_ecs = _make_ecs_mock(
        ['arn:aws:ecs:us-east-1:123:task-definition/svc:1',
         'arn:aws:ecs:us-east-1:123:task-definition/svc:2'],
        ['123.dkr.ecr.us-east-1.amazonaws.com/dpc-attribution:v1.0',
         '123.dkr.ecr.us-east-1.amazonaws.com/dpc-attribution:v2.0'],
    )
    assert lambda_function.get_protected_image_refs(mock_ecs) == {'v1.0', 'v2.0'}


@pytest.fixture(autouse=True)
def mock_boto3_clients():
    with patch('lambda_function.ssm_client') as mock_ssm, \
         patch('lambda_function.ecs_client') as mock_ecs, \
         patch('lambda_function.ecr_client') as mock_ecr:
        yield mock_ssm, mock_ecs, mock_ecr


def _setup_handler_mocks(mock_ssm, mock_ecs, mock_ecr, repo='dpc-attribution',
                         task_def_arns=None, task_images=None, ecr_images=None):
    mock_ssm.get_parameter.return_value = {'Parameter': {'Value': repo}}

    ecs_paginator = MagicMock()
    ecs_paginator.paginate.return_value = iter([{'taskDefinitionArns': task_def_arns or []}])
    mock_ecs.get_paginator.return_value = ecs_paginator
    if task_def_arns and task_images:
        mock_ecs.describe_task_definition.side_effect = [
            {'taskDefinition': {'containerDefinitions': [{'image': img}]}}
            for img in task_images
        ]

    ecr_paginator = MagicMock()
    ecr_paginator.paginate.return_value = iter([{'imageDetails': ecr_images or []}])
    mock_ecr.get_paginator.return_value = ecr_paginator


def test_lambda_handler_deletes_old_unprotected_images(mock_boto3_clients):
    """Happy path: old image outside KEEP_COUNT is deleted; recent images are kept."""
    mock_ssm, mock_ecs, mock_ecr = mock_boto3_clients
    recent = [make_image(f'sha256:new{i}', [f'new{i}'], days_ago=i) for i in range(1, 6)]
    old_image = make_image('sha256:old', ['old-tag'], days_ago=45)
    _setup_handler_mocks(mock_ssm, mock_ecs, mock_ecr, ecr_images=recent + [old_image])
    with patch.dict(os.environ, {'APP': 'dpc', 'ENV': 'test'}):
        lambda_function.lambda_handler({}, None)
    mock_ecr.batch_delete_image.assert_called_once_with(
        repositoryName='dpc-attribution',
        imageIds=[{'imageDigest': 'sha256:old'}]
    )


def test_lambda_handler_protects_images_in_task_defs(mock_boto3_clients):
    """Image referenced by an active task def is never deleted even if old."""
    mock_ssm, mock_ecs, mock_ecr = mock_boto3_clients
    old_image = make_image('sha256:old', ['protected-tag'], days_ago=45)
    _setup_handler_mocks(
        mock_ssm, mock_ecs, mock_ecr,
        task_def_arns=['arn:aws:ecs:us-east-1:123:task-definition/svc:1'],
        task_images=['123.dkr.ecr.us-east-1.amazonaws.com/dpc-attribution:protected-tag'],
        ecr_images=[old_image],
    )
    with patch.dict(os.environ, {'APP': 'dpc', 'ENV': 'test'}):
        lambda_function.lambda_handler({}, None)
    mock_ecr.batch_delete_image.assert_not_called()
