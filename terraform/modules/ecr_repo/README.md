# Elastic Container Registry (ECR) Repository Module

This module establishes an ECR repository in alignment with platform compliance and container image policy standards.

## Overview

This module provisions an AWS ECR repository and its associated lifecycle policy with secure, policy-compliant defaults. Teams can use this module with zero configuration for the standard case, or customize lifecycle behavior for more advanced tagging and retention needs.

### What This Module Enforces by Default

| Behavior | Default | Policy Basis |
|---|---|---|
| Image tag mutability | `IMMUTABLE` | Prevents tag overwriting; enforces semantic versioning discipline |
| Image retention | Last 3 images (catch-all) | Platform recommendation: keep latest 3 releases |
| Untagged image expiry | 30 days | Platform 30-60 day max retention guidance |
| Vulnerability scanning | Snyk (via platform) | Attestation ECR.1; `scan_on_push` disabled |
| Encryption | KMS | CMS encryption at rest requirement |

### Lifecycle Policy Behavior

The module generates an ECR lifecycle policy from the `tag_rules` variable. Rules are applied in the order they are defined, with the untagged expiry rule always appended last at the lowest priority.

Two count strategies are supported per rule:

- **`imageCountMoreThan`** — retains up to N images, expiring the oldest beyond that count
- **`sinceImagePushed`** — expires images older than N days regardless of count

The default policy keeps the last 3 images across all tags, which at a 15-day push cadence provides approximately 45 days of rollback coverage — within the platform's 30-60 day retention window.

### Tagging Convention

Teams should push images using explicit, immutable tags (e.g. semantic version tags or commit SHAs). The `latest` tag convention is discouraged — ECS deployments should always reference an explicit tag. `IMMUTABLE` tag mutability is enforced by this module and cannot be overridden.

<!-- BEGIN_TF_DOCS -->
<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~>6.0 |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~>6.0 |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_platform"></a> [platform](#input\_platform) | Object representing the platform module. | <pre>object({<br/>    app               = string<br/>    env               = string<br/>    service           = string<br/>    kms_alias_primary = object({ target_key_arn = string })<br/>    primary_region    = object({ name = string })<br/>    account_id        = string<br/>  })</pre> | n/a | yes |
| <a name="input_repo_name_override"></a> [repo\_name\_override](#input\_repo\_name\_override) | When possible, do not use. Override for the name of the ECR repository. | `string` | `null` | no |
| <a name="input_service"></a> [service](#input\_service) | Custom service name in case multiple ECR repos made in the same terraservice. If null, defaults to platform service value. | `string` | `null` | no |
| <a name="input_tag_rules"></a> [tag\_rules](#input\_tag\_rules) | List of lifecycle rules for images, applied in priority order.<br/>Supports both count-based and time-based expiry per rule.<br/><br/>count\_type options:<br/>  - "imageCountMoreThan" (default): retain up to `retained_images` images<br/>  - "sinceImagePushed": expire images older than `expiry_days` days<br/><br/>A null tag\_prefix produces a catch-all rule (tagStatus: any).<br/><br/>Default: keep last 3 images (all tags) per platform policy.<br/><br/>Example — multiple tag classes in one repo:<br/>  tag\_rules = [<br/>    { tag\_prefix = "rls-r", count\_type = "imageCountMoreThan", retained\_images = 5,  description = "Keep last 5 release images" },<br/>    { tag\_prefix = "temp-", count\_type = "imageCountMoreThan", retained\_images = 3,  description = "Keep last 3 temp images" },<br/>    { tag\_prefix = null,    count\_type = "sinceImagePushed",   expiry\_days     = 14, description = "Expire all other images older than 14 days" },<br/>  ] | <pre>list(object({<br/>    tag_prefix      = optional(string)<br/>    count_type      = optional(string, "imageCountMoreThan")<br/>    retained_images = optional(number)<br/>    expiry_days     = optional(number)<br/>    description     = optional(string)<br/>  }))</pre> | <pre>[<br/>  {<br/>    "count_type": "imageCountMoreThan",<br/>    "description": "Keep last 3 images (platform policy default)",<br/>    "retained_images": 3,<br/>    "tag_prefix": null<br/>  }<br/>]</pre> | no |
| <a name="input_untagged_expiry_days"></a> [untagged\_expiry\_days](#input\_untagged\_expiry\_days) | Number of days after which untagged images are expired.<br/>Defaults to 30 days per platform policy (max 30-60 day retention guidance).<br/>Untagged images are always cleaned up as the lowest priority rule. | `number` | `30` | no |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Modules

No modules.

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Resources

| Name | Type |
|------|------|
| [aws_ecr_lifecycle_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_lifecycle_policy) | resource |
| [aws_ecr_repository.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_repo"></a> [repo](#output\_repo) | The ECR Repo object generated by ToFu. |
| <a name="output_repo_lifecycle_policy"></a> [repo\_lifecycle\_policy](#output\_repo\_lifecycle\_policy) | The ECR Lifecycle policy generated by ToFu. |
<!-- END_TF_DOCS -->