# setup-tenv

This GitHub action installs [yq](https://github.com/mikefarah/yq), a yaml parser. YQ is a dependency for the setup-sops action.

## Usage

```yaml
steps:
  - name: Install YQ
    uses: cmsgov/cdap/actions/setup-yq@<hash>
```
