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

module "service" {
  cluster = module.cluster.this.id
  container_definitions_filename = "container_definitions.json" # See file description above.
  cpu = 1048
  desired_count = 1  # Optional - how many instances to keep running after task is complete.  Default is 0.
  family_name_override = "microservice" # Optional - The family name for the ECS task definition.  If null will default to: {var.platform.env}-{var.platform.app}-{var.platform.service}
  force_new_deployment = true #Optional - Set to true to delete a service even if it wasn't scaled down to zero tasks. Default is false.
  load_balancers = [{
    target_group_arn = "this is an arn"
    container_name = "this is the container name"
    container_port = 3000
  },
    {
      target_group_arn = "this is another arn"
      container_name = "this is the other container name"
      container_port = 3001
    }]
  memory = 2048
  network_configurations = [{
    subnets = ["subnet-a", "subnet-b"]
    assign_public_ip = false
    security_groups = ["sg-a", "sg-b"]
  }]
  propagate_tags = "SERVICE"
  # SERVICE: Tags defined on the aws_ecs_service resource itself will be propagated to the tasks. Default value.
  # TASK_DEFINITION: Tags defined on the aws_ecs_task_definition resource will be propagated to the tasks.
  service_name_override = "my_test_service" # Optional - Desired service name for the service tag on the aws ecs service.  Defaults to platform.service.
  task_execution_role_arn = "this_is_an_iam_role_arn" #Optional - ARN of the task execution role that the Amazon ECS container agent and the Docker daemon can assume.  Defaults to creation of a new role.
  task_app_role_arn = "this_is_an_iam_role_arn"  # ARN of IAM role that allows your Amazon ECS container task to make calls to other AWS services.
  volumes = ["/tmp", "/log"] # List of EBS volume names to create for the ecs task definition.
} 
```

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_ecs_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name_override"></a> [cluster\_name\_override](#input\_cluster\_name\_override) | Name of the ecs cluster. | `string` | `null` | no |
| <a name="input_platform"></a> [platform](#input\_platform) | Object that describes standardized platform values. | `any` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_this"></a> [this](#output\_this) | The ecs cluster for the given inputs. |
<!-- END_TF_DOCS -->