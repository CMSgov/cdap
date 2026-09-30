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
  `/cdap/env/nonsensitive/mtls-sidecar/image-tag`

## Image Versioning

This stack does **not** manage its own container image tag. Instead, it shares
the image tag from `611-tftesting-service` via an SSM parameter lookup.

**SSM Parameter is read at plan time, this service is not updated through deployment git workflows:**
/cdap/{env}/nonsensitive/tftesting-service/image-tag

This is controlled by `image_tag_service_name_override = "tftesting-service"` in the `ecs_service` module call.
### Deploying a New Image to This Stack

Updating the container image in this stack is a **two-step process**:

1. **Run the deploy workflow targeting `tftesting-service`**
    - This writes the new image tag to the shared SSM parameter
    - It also updates `611-tftesting-service`'s ECS service directly

2. **Re-apply Tofu for this stack (`612-tftesting-ecs-stack-internal`)**
    - Tofu reads the updated SSM parameter at plan time
    - A new task definition revision is registered with the new image
    - The ECS service is updated to use the new task definition

### Why This Design?

This stack is an internal mTLS test stack that runs the same application
container as `611-tftesting-service`. Sharing the image tag ensures both
stacks are always running the same version without needing a separate
build or deploy pipeline for this stack.

### mTLS Sidecar

The mTLS proxy sidecar image is managed separately. Its image tag lives at:

/cdap/{env}/nonsensitive/mtls-sidecar/image-tag

where `env` is `test` for non-prod and `prod` for prod/sandbox.

To update the sidecar image, run the deploy workflow with `ssm_only: true`
targeting `service_name: mtls-sidecar`. This stack will pick up the new
sidecar image on the next Tofu apply.

