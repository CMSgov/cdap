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
| <a name="input_platform"></a> [platform](#input\_platform) | Object representing the platform module. | <pre>object({<br/>    app               = string<br/>    service           = string<br/>    kms_alias_primary = object({ target_key_arn = string })<br/>    primary_region    = object({ name = string })<br/>    account_id        = string<br/>  })</pre> | n/a | yes |
| <a name="input_repo_name_override"></a> [repo\_name\_override](#input\_repo\_name\_override) | When possible, do not use. Override for the name of the ECR repository. | `string` | `null` | no |
| <a name="input_service"></a> [service](#input\_service) | Custom service name in case multiple ECR repos made in the same terraservice. If null, defaults to platform service value. | `string` | `null` | no |
| <a name="input_tag_rules"></a> [tag\_rules](#input\_tag\_rules) | List of lifecycle rules to apply to the ECR repository, evaluated in priority order.<br/><br/>Each rule object supports the following attributes:<br/>  - priority    (required) : Rule evaluation order — lower numbers are evaluated first.<br/>  - tag\_prefix  (optional) : Image tag prefix to match (e.g. "release-", "v").<br/>                             When set, the rule targets only images whose tags start<br/>                             with this prefix (tagStatus = "tagged").<br/>                             When null, the rule targets ALL images regardless of<br/>                             tag status (tagStatus = "any") — this includes both<br/>                             tagged and untagged images not matched by earlier rules.<br/>  - keep\_count  (required) : Number of images to retain matching this rule.<br/><br/>IMPORTANT — null tag\_prefix behavior:<br/>Rules with tag\_prefix = null use tagStatus = "any", which means they act as a<br/>catch-all and will expire BOTH tagged and untagged images beyond keep\_count.<br/>Untagged image retention is NOT exclusively controlled by untagged\_expiry\_days<br/>when a null-prefix rule is present — the null-prefix rule will also affect<br/>untagged images. If you need untagged images to be retained independently,<br/>do not use a null-prefix tag\_rule; rely solely on untagged\_expiry\_days instead.<br/><br/>Example:<br/>  tag\_rules = [<br/>    {<br/>      priority   = 10<br/>      tag\_prefix = "release-"<br/>      keep\_count = 10<br/>    },<br/>    {<br/>      priority   = 20<br/>      tag\_prefix = null       # Catch-all: applies to ALL remaining images (tagged + untagged)<br/>      keep\_count = 5<br/>    }<br/>  ] | <pre>list(object({<br/>    priority   = number<br/>    tag_prefix = optional(string, null)<br/>    keep_count = number<br/>  }))</pre> | `[]` | no |
| <a name="input_untagged_expiry_days"></a> [untagged\_expiry\_days](#input\_untagged\_expiry\_days) | Number of days after which untagged images are expired.<br/><br/>NOTE: This variable only has exclusive control over untagged image retention<br/>when no tag\_rules entry has tag\_prefix = null. If a null-prefix tag\_rule exists,<br/>that rule's tagStatus = "any" will also match untagged images and may expire them<br/>before untagged\_expiry\_days is reached, depending on rule priority order.<br/><br/>Set to null to disable the untagged expiry rule entirely. | `number` | `14` | no |

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