# Terraform module for function resources

This is a generic module for creating lambda function resources in CMS Cloud. Use it in terraform services where a lambda function is needed.

This module provisions:

    An AWS Lambda function deployed from S3 (managed or externally supplied zip)
    A dedicated S3 bucket for the function zip artifact
    VPC placement using shared VPC and subnet modules
    A security group (rules managed externally by the caller)
    A CloudWatch Log Group with KMS encryption and configurable retention
    An IAM role with least-privilege defaults (VPC ENI, CloudWatch Logs, KMS, optional SSM)
    An optional CloudWatch Events schedule trigger
    An optional deploy-time liveness check
    A live alias for stable invocation ARNs and rollback support
    If dd_enabled is set to true, appropriate Datadog lambda layers are included

### Cloudwatch Events 
    Pass a schedule_expression to enable a CloudWatch Events rule that invokes the function on a schedule. 
    The module creates the rule, target, and Lambda permission automatically.
    
## Security groups 
    This module creates a security group for the Lambda function and outputs its ID. 
    All ingress rules are managed by the caller, to avoid circular dependencies when the SG is referenced alongside other resources.
    Required egress rules should also be managed by the caller, as the existing broad egress rule will be removed in 
    favor of VPC endpoints.

### SQS
    No ingress security group rules are needed for SQS. 
    Lambda polls SQS outbound — SQS does not make inbound network connections to your function.

## CI/CD Enablement via GitHub Actions

    This module supports GitHub Actions OIDC-based deployments. When
    `github_actions_repos` is set, the Lambda zip bucket policy is extended
    to allow the specified repositories to upload new function zips directly
    from a GitHub Actions workflow.

### How to use

1. Pass the repo(s) that should have deploy access:

```hcl
module "my_lambda" {
  source = "../lambda"

  app         = "bcda"
  env         = "dev"
  name        = "my-function"
  description = "Some descriptive message"
  handler     = "handler.main"
  runtime     = "python3.11"
  source_dir  = "${path.module}/lambda_src"
}
```

2. In your GitHub Actions workflow, authenticate using OIDC:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: us-east-1
```

3. Upload the zip to the bucket:

```yaml
- name: Upload Lambda zip
  run: |
    aws s3 cp function.zip s3:///function.zip
```

4. Update the Lambda to use the new zip version:

```yaml
- name: Update Lambda function code
  run: |
    aws lambda update-function-code \
      --function-name  \
      --s3-bucket  \
      --s3-key function.zip
```

### What it does under the hood

When `github_actions_repos` is non-empty, the module attaches an additional
S3 bucket policy (`cicd_manage_lambda_objects`) that grants the GitHub Actions
OIDC role permission to manage objects in the zip bucket. No access is granted
when the list is empty.

Note that a dummy function will be made if source_dir with function logic is not yet provided or github_actions_repo is not defined. 
The dummy function allows for infrastructure scaffolding before source code is written.
If source code is written and the lifecycle is managed outside of terraform, set github_actions_repo. 

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_archive"></a> [archive](#provider\_archive) | n/a |
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_subnets"></a> [subnets](#module\_subnets) | ../subnets | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ../vpc | n/a |
| <a name="module_zip_bucket"></a> [zip\_bucket](#module\_zip\_bucket) | ../bucket | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_event_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.default_function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.extra_policies](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_lambda_function.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_invocation.liveness_check](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_invocation) | resource |
| [aws_lambda_permission.cloudwatch_events](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_s3_object.empty_function_zip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_s3_object.function_zip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_security_group.function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [archive_file.function](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_openid_connect_provider.github](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_iam_policy_document.cicd_manage_lambda_objects](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.default_function](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.function_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_role.admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_role) | data source |
| [aws_iam_role.dasg_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_role) | data source |
| [aws_ssm_parameter.dd_api_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_additional_admin_role_arns"></a> [additional\_admin\_role\_arns](#input\_additional\_admin\_role\_arns) | List of additional IAM role arns to allow assume role | `list(string)` | `[]` | no |
| <a name="input_architecture"></a> [architecture](#input\_architecture) | Lambda function CPU architecture. Use arm64 for Graviton (better price/performance for most workloads). | `string` | `"x86_64"` | no |
| <a name="input_dd_enabled"></a> [dd\_enabled](#input\_dd\_enabled) | If true, enables Datadog instrumentation for enhanced metrics and APM reporting via Datadog lambda layers. If false, use the standard Lambda resource. | `bool` | `false` | no |
| <a name="input_dd_extension_layer_version"></a> [dd\_extension\_layer\_version](#input\_dd\_extension\_layer\_version) | Version number for Datadog's Lambda extension layer. Required if dd\_enabled is true. For latest versions, see https://github.com/DataDog/datadog-lambda-extension/releases. | `number` | `97` | no |
| <a name="input_dd_java_layer_version"></a> [dd\_java\_layer\_version](#input\_dd\_java\_layer\_version) | Version number for Datadog's Java Lambda layer. Required if using a Java runtime. For latest versions, see https://github.com/DataDog/datadog-lambda-java/releases. | `number` | `26` | no |
| <a name="input_dd_node_layer_version"></a> [dd\_node\_layer\_version](#input\_dd\_node\_layer\_version) | Version number for Datadog's Node.js Lambda layer. Required if using a Node.js runtime. For latest versions, see https://github.com/DataDog/datadog-lambda-js/releases. | `number` | `137` | no |
| <a name="input_dd_python_layer_version"></a> [dd\_python\_layer\_version](#input\_dd\_python\_layer\_version) | Version number for Datadog's Python Lambda layer. Required if using a python runtime. For latest versions, see https://github.com/DataDog/datadog-lambda-python/releases. | `number` | `125` | no |
| <a name="input_description"></a> [description](#input\_description) | Description of the lambda function | `string` | n/a | yes |
| <a name="input_environment_variables"></a> [environment\_variables](#input\_environment\_variables) | Map of environment variables for the function | `map(string)` | `{}` | no |
| <a name="input_extra_kms_key_arns"></a> [extra\_kms\_key\_arns](#input\_extra\_kms\_key\_arns) | Optional list of additional KMS key ARNs the Lambda can use | `list(string)` | `[]` | no |
| <a name="input_function_role_inline_policies"></a> [function\_role\_inline\_policies](#input\_function\_role\_inline\_policies) | Inline policies (in JSON) for the function IAM role | `map(string)` | `{}` | no |
| <a name="input_github_actions_repos"></a> [github\_actions\_repos](#input\_github\_actions\_repos) | List of GitHub repository paths (e.g. "org/repo") that are permitted to<br/>deploy Lambda function zips to this module's S3 bucket via GitHub Actions<br/>OIDC. When non-empty, an S3 bucket policy is added that allows the<br/>corresponding GitHub Actions IAM role to put/get objects under the<br/>function zip key.<br/><br/>Example:<br/>  github\_actions\_repos = ["CMSgov/bcda-app", "CMSgov/dpc-app"]<br/><br/>Leave empty ([]) to disable CI/CD write access to the bucket entirely. | `list(string)` | `[]` | no |
| <a name="input_handler"></a> [handler](#input\_handler) | Lambda function handler | `string` | `"function_handler"` | no |
| <a name="input_layer_arns"></a> [layer\_arns](#input\_layer\_arns) | Optional list of layer arns | `list(string)` | `[]` | no |
| <a name="input_liveness_check_enabled"></a> [liveness\_check\_enabled](#input\_liveness\_check\_enabled) | Enables a deploy-time liveness check that invokes the Lambda function<br/>immediately after deployment to verify it is healthy and correctly configured.<br/><br/>When enabled, an aws\_lambda\_invocation resource is created that sends a<br/>{ "RequestType": "LivenessCheck" } payload to the Lambda function after<br/>each deployment. The invocation is re-triggered whenever the Lambda source<br/>code changes (tracked via source\_code\_hash).<br/><br/>The Lambda function is responsible for implementing the liveness check logic<br/>in its handler. This may include verifying external dependencies, validating<br/>configuration, checking connectivity to downstream services, or any other<br/>health validation relevant to the function's purpose.<br/><br/>If the liveness check fails, the Lambda should raise an exception. This<br/>surfaces as a function error and causes the Tofu apply to fail, alerting<br/>the deploying team immediately.<br/><br/>Recommended: true in all environments to catch misconfiguration at deploy time. | `bool` | `true` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Number of days to retain Lambda function logs in CloudWatch. If null, no retention policy is set and retention is managed externally (e.g., via cdap/scripts/set\_log\_retention/). | `number` | `180` | no |
| <a name="input_memory_size"></a> [memory\_size](#input\_memory\_size) | Lambda function memory size | `number` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the lambda function | `string` | n/a | yes |
| <a name="input_platform"></a> [platform](#input\_platform) | Object representing the CDAP plaform module. | <pre>object({<br/>    app               = string<br/>    env               = string<br/>    service           = string<br/>    kms_alias_primary = object({ target_key_arn = string })<br/>    primary_region    = object({ name = string })<br/>    account_id        = string<br/>  })</pre> | n/a | yes |
| <a name="input_rollback_version"></a> [rollback\_version](#input\_rollback\_version) | S3 object version ID of a previous "function.zip" to roll back to.<br/>When null (default), Lambda uses the latest version of function.zip.<br/>When set, Lambda is pinned to that specific S3 object version.<br/><br/>To list available version IDs:<br/>  aws s3api list-object-versions \<br/>    --bucket <zip\_bucket\_name> \<br/>    --prefix function.zip \<br/>    --query 'Versions[*].{VersionId:VersionId, LastModified:LastModified}' | `string` | `null` | no |
| <a name="input_runtime"></a> [runtime](#input\_runtime) | Lambda function runtime | `string` | `"python3.11"` | no |
| <a name="input_schedule_expression"></a> [schedule\_expression](#input\_schedule\_expression) | Cron or rate expression for a scheduled function | `string` | `""` | no |
| <a name="input_source_code_version"></a> [source\_code\_version](#input\_source\_code\_version) | Optional S3 object version of function.zip uploaded to module's zip\_bucket by external sources. | `string` | `null` | no |
| <a name="input_source_dir"></a> [source\_dir](#input\_source\_dir) | Path to the Lambda source directory to zip and upload. If set, the module manages zipping and deployment. If null, an external process (or dummy zip) is used. | `string` | `null` | no |
| <a name="input_source_dir_excludes"></a> [source\_dir\_excludes](#input\_source\_dir\_excludes) | List of glob (**/*) patterns to exclude when zipping the source directory. | `list(string)` | `[]` | no |
| <a name="input_ssm_parameter_paths"></a> [ssm\_parameter\_paths](#input\_ssm\_parameter\_paths) | List of SSM parameter paths this function is permitted to read.<br/>Each entry must be a path starting with '/' (e.g., /cdap/test/lambda/secret).<br/>The module will validate that each parameter exists and construct the ARN automatically.<br/>If empty (default), the function receives no SSM access.<br/>Scope each entry to the specific parameters this function requires. | `list(string)` | `[]` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Lambda function timeout | `number` | `900` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_function_arn"></a> [function\_arn](#output\_function\_arn) | ARN of the Lambda function |
| <a name="output_function_version"></a> [function\_version](#output\_function\_version) | Active S3 object version ID used for the Lambda deployment package |
| <a name="output_name"></a> [name](#output\_name) | Name for the lambda function |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | ARN of the IAM role for the function |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | ID for the security group for the function |
| <a name="output_source_code_hash"></a> [source\_code\_hash](#output\_source\_code\_hash) | Base64-encoded SHA256 hash of the Lambda deployment package |
| <a name="output_zip_bucket"></a> [zip\_bucket](#output\_zip\_bucket) | Bucket name for the function.zip file |
<!-- END_TF_DOCS -->
