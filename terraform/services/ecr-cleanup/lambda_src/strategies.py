"""
Strategies to use for marking images for deletion.
"""

from datetime import datetime, timedelta, timezone

DELETE = 'to_delete'
PROTECT = 'to_protect'


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

def count_image_strategy(images, tag_prefix, count):
    """
    Marks images to delete or protect based on pushed date and count.
    Only applies to images with a tag that starts with 'tag_prefix'.
    Will not apply to any images that have been marked for deletion or
    protection by another strategy.

    Arguments:
    images     -- a sequence of all images in a given repository
    tag_prefix -- matcher for images that should be affected by this strategy
                  use '' to match all tagged images
                  use None to match untagged images
    count      -- maximum number of images to protect from deletion
    """
    matching_images = images_matching_prefix(images, tag_prefix)
    for index, image in enumerate(sorted(matching_images, reverse=True)):
        if index < count:
            image.set_status(PROTECT)
        else:
            image.set_status(DELETE)

def days_older_than_strategy(images, tag_prefix, days):
    """
    Marks images to delete or protect based on cutoff date.
    Only applies to images with a tag that starts with 'tag_prefix'.
    Will not apply to any images that have been marked for deletion or
    protection by another strategy.

    Arguments:
    images     -- a sequence of all images in a given repository
    tag_prefix -- matcher for images that should be affected by this strategy
                  use '' to match all tagged images
                  use None to match untagged images
    count      -- number of days ago, after which images will be deleted
    """
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    matching_images = images_matching_prefix(images, tag_prefix)
    for image in matching_images:
        if image.pushed_at > cutoff:
            image.set_status(PROTECT)
        else:
            image.set_status(DELETE)

STRATEGIES = {
    'count_image': count_image_strategy,
    'days_older_than': days_older_than_strategy,
}
