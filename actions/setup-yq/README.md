# setup-tenv

This GitHub action installs [yq](https://github.com/mikefarah/yq), a yaml parser. YQ is a dependency for the setup-sops action.

## Usage

In calling workflows, set TENV_GITHUB_TOKEN to avoid rate limiting by the GitHub API. This environment variable must be available to all steps running tofu commands.

```yaml
steps:
  - name: Install YQ
    uses: cmsgov/cdap/actions/setup-yq@<hash>
```
