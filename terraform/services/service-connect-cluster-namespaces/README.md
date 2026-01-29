# OpenTofu for Service Connect namespaces for each ECS Cluster

This OpenTofu code creates aws_service_discovery_http_namespace for each ECS Cluster.

## Instructions

Pass in a backend file when running tofu init. Example:

```bash
tofu init -reconfigure -backend-config=../../backends/cdap-test.s3.tfbackend
tofu plan
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.10.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_service_discovery_http_namespace.ecs_namespaces](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_http_namespace) | resource |
| [aws_ecs_cluster.clusters](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecs_cluster) | data source |
| [aws_ecs_clusters.all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecs_clusters) | data source |

## Inputs

No inputs.

## Outputs

No outputs.
<!-- END_TF_DOCS -->