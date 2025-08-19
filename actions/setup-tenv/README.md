# setup-tenv

This GitHub action installs [tenv](https://github.com/tofuutils/tenv) for the management of tofu versions.

## Usage

Install cosign in a prior step to enable signature verification on tenv and tofu downloads.

```yaml
steps:
  - uses: sigstore/cosign-installer@d58896d6a1865668819e1d91763c7751a165e159 # v3.9.2
  - uses: cmsgov/cdap/actions/setup-tenv@<hash>
  - run: tofu init
```
