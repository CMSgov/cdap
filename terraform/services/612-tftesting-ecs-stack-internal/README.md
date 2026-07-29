# ecs-stack-internal

Integration test terraservice for an internal ALB and ECS Fargate service
with mTLS sidecar. Validates the full private-cert path using a
PACE certificate for both the ALB listener and the mTLS proxy.

## What This Tests

| Component | Configuration                                                               |
|---|-----------------------------------------------------------------------------|
| `acm_certificate` | PACE backed private cert, `enable_internal_endpoint`, `enable_mtls_sidecar` |
| `alb` | Internal ALB, private subnets, private cert on HTTPS listener               |
| `ecs_service` | mTLS sidecar, proxy port, task role ACM export permission                   |

## Architecture

```
VPC / Zscaler -->
Internal ALB (HTTPS:443 — PACE backed private cert)
  -->  terminates outer TLS
mTLS proxy sidecar (PACE private cert — exported at startup)
  --> terminates mTLS
App container (plain HTTP on localhost)
```

## Prerequisites

- ECS cluster deployed in the target environment
- PCA RAM resource share (`pace-ca-g1`) accessible from this account
- `internal.cms.gov` private hosted zone exists for this env/app
- `tftesting-service` ECR repo exists with at least one pushed image tag, established by `101-ecr-repos`
- SSM parameter established by tftesting-service terraservice exists at:
  `/cdap/<account_env_suffix>/nonsensitive/mtls-sidecar/image-tag`
