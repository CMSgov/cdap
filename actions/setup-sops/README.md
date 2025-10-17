# setup-sops

This GitHub action installs sops.

## Usage

Install cosign in a prior step to enable signature verification on the sops download.

```yaml
steps:
  - name: Install Cosign to verify sops and tofu installs
    uses: sigstore/cosign-installer@d58896d6a1865668819e1d91763c7751a165e159 # v3.9.2
  - name: Install sops
    uses: cmsgov/cdap/actions/setup-sops
  - name: Call SOPS
    run: |
     sops --version --check-for-updates
```
