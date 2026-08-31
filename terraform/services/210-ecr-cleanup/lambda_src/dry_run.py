"""
Not used for production code.
Runs the exact same discovery and strategy logic as the deployed Lambda,
reading directly from config/default.yml and config/<env>.yml, the same
files Tofu uses to configure the real deployment, so dry run always
reflects what would happen if you applied right now.

Unlike the deployed Lambda, this script ignores each repo's opt_in flag:
every discovered repo's eligible-for-deletion images are printed, so you
can preview the impact of turning opt_in on *before* you turn it on.

Nothing should be deleted by this script.
"""

import os
from argparse import ArgumentParser

import boto3
import yaml

from lambda_function import get_images_to_delete, discover_repos, build_repo_config

DEFAULT_CONFIG_DIR = os.path.join(os.path.dirname(__file__), '..', 'config')

def _load_yaml(path):
    """Loads a YAML file's 'cleanup' block, or {} if the file doesn't exist."""
    if not os.path.exists(path):
        return {}
    with open(path, encoding='utf-8') as f:
        data = yaml.safe_load(f) or {}
    return data.get('cleanup', {})


def load_cleanup_config(config_dir, env):
    """
    Merges config/default.yml and config/<env>.yml the same way main.tf does.
    """
    default_cfg = _load_yaml(os.path.join(config_dir, 'default.yml'))
    env_cfg = _load_yaml(os.path.join(config_dir, f'{env}.yml'))

    default_strategies = env_cfg.get(
        'default_strategies',
        default_cfg.get('default_strategies', [])
    )

    exclusion_list = list(dict.fromkeys(
        default_cfg.get('exclusion_list', []) + env_cfg.get('exclusion_list', [])
    ))

    repo_overrides = {
        **default_cfg.get('repo_overrides', {}),
        **env_cfg.get('repo_overrides', {}),
    }

    return {
        'default_strategies': default_strategies,
        'exclusion_list': exclusion_list,
        'repo_overrides': repo_overrides,
    }


def run(env, config_dir):
    """
    Discovers every ECR repo in the account except exclusions, applies
    overrides from config/default.yml and config/<env>.yml, and prints every
    image that would be eligible for deletion in EVERY discovered repo,
    regardless of that repo's opt_in setting.
    """
    cleanup_cfg = load_cleanup_config(config_dir, env)
    exclusions = set(cleanup_cfg['exclusion_list'])

    ecr_client = boto3.client('ecr')
    discovered = discover_repos(ecr_client, exclusions)
    print(f'Discovered {len(discovered)} repo(s) account-wide '
          f'(excluding {len(exclusions)}): {discovered}\n')

    repo_config = build_repo_config(
        discovered, cleanup_cfg['repo_overrides'], cleanup_cfg['default_strategies']
    )

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
        description='Previews exactly what the ecr-cleanup Lambda would find and act on, '
                     'using the real config/default.yml and config/<env>.yml settings. '
                     'Should not perform deletions.'
    )
    parser.add_argument('--env', default='test',
                        help='Environment to simulate (matches config/<env>.yml), default: test')
    parser.add_argument('--config-dir', default=DEFAULT_CONFIG_DIR,
                        help='Path to the directory containing default.yml and <env>.yml '
                             '(default: ../config, relative to this script)')
    args = parser.parse_args()
    run(args.env, args.config_dir)
