# CDAP ECS Cluster Module 

## Usage
```hcl
module "platform" {
  source    = "github.com/CMSgov/cdap//terraform/modules/platform?ref=ff2ef539fb06f2c98f0e3ce0c8f922bdacb96d66"
  providers = { aws = aws, aws.secondary = aws.secondary }

  app         = "ab2d"
  env         = "dev"
  root_module = "https://github.com/CMSgov/ab2d/tree/main/ops/services/20-microservices"
  service     = "contracts"
  ssm_root_map = {
    common = "/ab2d/${local.env}/common"
    core   = "/ab2d/${local.env}/core"
  }
}

module "cluster" {
  source   = "github.com/CMSgov/cdap//terraform/modules/cluster?ref=<hash>"
  platform = module.platform
}

```

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_ecs_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_service_discovery_http_namespace.cluster_service_connect_namespace](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_http_namespace) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name_override"></a> [cluster\_name\_override](#input\_cluster\_name\_override) | Name of the ecs cluster. | `string` | `null` | no |
| <a name="input_platform"></a> [platform](#input\_platform) | Object that describes standardized platform values. | <pre>object({<br/>    app = string,<br/>    env = string,<br/>    kms_alias_primary = object({<br/>      target_key_arn = string<br/>    }),<br/>    service          = string,<br/>    is_ephemeral_env = string<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_this"></a> [this](#output\_this) | The ecs cluster for the given inputs. |
<!-- END_TF_DOCS -->