"""
Script for testing config changes locally and preview images that would be deleted. Not used for production code.
Useful for previewing cleanup behavior before updating repo_config in main.tf
"""

import json
from argparse import ArgumentParser

from lambda_function import get_images_to_delete


def run(config_path):
    """
    Prints tags of (or digest of untagged) images that would be deleted for each repo in config.
    """
    with open(config_path, encoding='utf-8') as f:
        repo_config = json.load(f)

    for repo_name, deleteable in get_images_to_delete(repo_config).items():
        print(f'{repo_name} images to delete')
        print('============================================')
        if len(deleteable):
            for image in deleteable:
                print(f'  {image.tags or image.digest}')
        else:
            print(f'No images eligible for deletion for {repo_name}')


if __name__ == '__main__':
    parser = ArgumentParser(description='Prints tags of images that would be deleted')
    parser.add_argument('--config-path', default='dry_run_config.json',
                        help='path to repo config JSON file (default: dry_run_config.json)')
    args = parser.parse_args()
    run(args.config_path)
