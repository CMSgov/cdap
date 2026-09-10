# ecs-stack-public

Integration test terraservice for a public (internet-facing) ALB and
ECS Fargate service with mTLS sidecar. Validates the two-cert method:
a CMS-signed public cert on the ALB listener and a PACE private
cert on the mTLS proxy sidecar. Also validates the service connect 
connection between two services, one acting as the external entrypoint.

## What This Tests

| Component | Configuration |
|---|---|
| `acm_certificate` (public) | CMS-signed public cert for `*.cms.gov` ALB listener |
| `acm_certificate` (private) | PCA-backed private cert for mTLS sidecar |
| `alb` | Internet-facing ALB, public subnets, public cert on HTTPS listener |
| `ecs_service` | mTLS sidecar, proxy port, task role ACM export permission |

## Architecture

```
Internet
  ↓
Public ALB (HTTPS:443 — CMS-signed public cert)
  ↓  terminates outer TLS
mTLS proxy sidecar (PCA-backed private cert — exported at startup)
  ↓  terminates mTLS
App container (plain HTTP on localhost)
```

## Two Certificate Instances

This stack requires **two separate `acm_certificate` module instances**
because the ALB cert and the mTLS sidecar cert have different issuers,
domains, and lifecycle concerns:

| Instance | Cert Type | Domain | Consumer |
|---|---|---|---|
| `module.acm_public` | CMS-signed | `<svc>.cms.gov` | ALB HTTPS listener |
| `module.acm_private` | PCA-backed | `<svc>.<env>.<app>.internal.cms.gov` | mTLS sidecar |

## Prerequisites

- ECS cluster deployed in the target environment
- PCA RAM resource share (`pace-ca-g1`) accessible from this account
- `internal.cms.gov` private hosted zone exists for this env/app
- CMS-signed public certificate obtained and encrypted via SOPS:
    - `certificate` — PEM-encoded signed cert
    - `private_key` — PEM-encoded private key
    - `certificate_chain` — PEM-encoded cert chain (optional)
- `tftesting-service` ECR repo exists with at least one pushed image tag
- SSM parameter exists at:
  `/cdap/<account_env_suffix>/nonsensitive/mtls-sidecar/image-tag`

## Public Certificate Process

If the public cert has not yet been obtained from CMS:

1. Apply with `acm_public` but without `public_certificate` or
   `public_private_key` — the module will generate a CSR.
2. Retrieve the CSR from SSM:
   `/<app>/<env>/<service>/tls/v1/csr`
3. Submit to CMS for signing.
4. Encrypt the returned cert and key via SOPS.
5. Re-apply with the SOPS values populated.
