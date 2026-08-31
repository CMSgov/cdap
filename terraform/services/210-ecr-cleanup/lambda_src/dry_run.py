"""
Not used for production code.
Runs the exact same discovery and strategy logic as the deployed Lambda,
so you can preview what a real nightly run would find and (if opted in)
delete — without ever calling batch_delete_image.

Unlike the deployed Lambda, this script ignores each repo's opt_in flag:
every discovered repo's eligible-for-deletion images are printed, so you
can preview the impact of turning opt_in on *before* you turn it on.
"""

import json
from argparse import ArgumentParser

import boto3

from lambda_function import get_images_to_delete, discover_repos, build_repo_config

# Mirrors locals.default_strategies in main.tf — keep these in sync.
DEFAULT_STRATEGIES = [
    ["count_image", "rls-r", 5],
    ["days_older_than", "", 14],
    ["days_older_than", None, 14],
]


def run(app_prefix, overrides_path=None):
    """
    Discovers every ECR repo matching app_prefix (same as the deployed Lambda),
    applies overrides from overrides_path where present, and prints every
    image that would be eligible for deletion in EVERY discovered repo —
    regardless of that repo's opt_in setting. Does not run deletions.
    """
    overrides = {}
    if overrides_path:
        try:
            with open(overrides_path, encoding='utf-8') as f:
                overrides = json.load(f)
        except FileNotFoundError:
            print(f'No overrides file at {overrides_path} — using defaults for all repos.\n')

    ecr_client = boto3.client('ecr')
    discovered = discover_repos(ecr_client, app_prefix)
    print(f'Discovered {len(discovered)} repo(s) matching prefix "{app_prefix}-": {discovered}\n')

    repo_config = build_repo_config(discovered, overrides, DEFAULT_STRATEGIES)

    for repo_name, deleteable in get_images_to_delete(repo_config).items():
        opted_in = repo_config[repo_name].get('opt_in', False)
        status = 'WOULD DELETE (opt_in=true)' if opted_in else 'log-only (opt_in=false)'
        print(f'{repo_name} — {status}')
        print('============================================')
        if deleteable:
            for image in deleteable:
                print(f'  {image.tags or image.digest}')
        else:
            print('  No images eligible for deletion')
        print()


if __name__ == '__main__':
    parser = ArgumentParser(
        description='Previews what the nightly ecr-cleanup Lambda would find '
                     'and act on, for every repo matching --app-prefix. Does not run deletions.'
    )
    parser.add_argument('--app-prefix', required=True,
                        help='ECR repo name prefix to discover, e.g. "cdap" or "dpc".')
    parser.add_argument('--config-path', default=None,
                        help="Optional path to a REPO_OVERRIDES-style JSON file. "
                             "Repos not listed here use the Lambda's default strategies.")
    args = parser.parse_args()
    run(args.app_prefix, args.config_path)
