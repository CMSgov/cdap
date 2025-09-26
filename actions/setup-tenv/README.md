# setup-tenv

This GitHub action installs [tenv](https://github.com/tofuutils/tenv) for the management of tofu versions.

## Usage

In calling workflows, set TENV_GITHUB_TOKEN to avoid rate limiting by the GitHub API. This environment variable must be available to all steps running tofu commands.

```yaml
env:
  TENV_GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Install cosign in a prior step to enable signature verification on tenv and tofu downloads.

```yaml
steps:
  - name: Install Cosign to verify tenv and tofu installs
    uses: sigstore/cosign-installer@d58896d6a1865668819e1d91763c7751a165e159 # v3.9.2
  - name: Install tenv
    uses: cmsgov/cdap/actions/setup-tenv@<hash>
  - name: Run OpenTofu plan
    run: tofu init && tofu plan
```

