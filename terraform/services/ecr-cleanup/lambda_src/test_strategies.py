"""
Unit tests for ECR cleanup Lambda strategies.
"""


import pytest

import test_lambda_function
import strategies

# pytest fixtures are referenced by parameter name, which pylint flags as redefining outer scope
# pylint: disable=redefined-outer-name

@pytest.mark.parametrize("tags,prefix,matches", [
    (('v1',), 'v', True,),
    (('a', 'b', 'c',), 'b', True,),
    (('anything',), '', True,),
    (None, None, True,),
    (('not_v',), 'v', False,),
    (('a', 'b', 'c',), 'd', False,),
    (('',), None, False,),
    (None, '', False,),
])
def test_images_matching_prefix(tags, prefix, matches):
    """ Make sure images_matching_prefix follows expectations. """
    image = test_lambda_function.make_image('sha256:1', tags, test_lambda_function.EXPIRED_DATETIME)
    if matches:
        assert image in strategies.images_matching_prefix((image,), prefix)
    else:
        assert image not in strategies.images_matching_prefix((image,), prefix)

def test_count_image_strategy():
    """ Make sure count image strategy correctly marks images for matching prefixes. """
    images = test_lambda_function.make_test_images()

    strategies.count_image_strategy(images, 'v', 1)
    for index, image in enumerate(images):
        if index == 0:
            assert image.status == strategies.PROTECT
        elif 1 <= index <= 2:
            assert image.status == strategies.DELETE
        else:
            assert image.status is None

def test_days_older_than_strategy():
    """ Make sure count image strategy correctly marks images for matching prefixes. """
    images = test_lambda_function.make_test_images()

    strategies.days_older_than_strategy(images, 'v', 2)
    for index, image in enumerate(images):
        if index < 2:
            assert image.status == strategies.PROTECT
        elif index == 2:
            assert image.status == strategies.DELETE
        else:
            assert image.status is None
