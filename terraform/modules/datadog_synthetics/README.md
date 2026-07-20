## Description

This module creates Datadog synthetic tests that run through the CDAP-managed
private Datadog location. Non-prod environments route through `cdap-non-prod`;
production routes through `cdap-prod`. Location selection happens automatically based on `var.env`.

The `synthetics_tests` output is shaped to plug directly into the
`datadog_monitors` module's `synthetics_tests` input, making it easy to pair
synthetic tests with failure monitors.

<!-- BEGIN_TF_DOCS -->
<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_datadog"></a> [datadog](#provider\_datadog) | ~>4.4 |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_datadog"></a> [datadog](#requirement\_datadog) | ~>4.4 |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_app"></a> [app](#input\_app) | Application name used in test names and tags (e.g. ab2d, bcda, dpc). | `string` | n/a | yes |
| <a name="input_env"></a> [env](#input\_env) | Deployment environment. Controls which CDAP private location is used: 'prod' and 'sandbox' use 'cdap-prod'; all other values use 'cdap-non-prod'. | `string` | n/a | yes |
| <a name="input_shadow_mode"></a> [shadow\_mode](#input\_shadow\_mode) | When true, marks tests with shadow-mode:true. Should match the shadow\_mode setting used in the companion datadog\_monitors module. | `bool` | `false` | no |
| <a name="input_tests"></a> [tests](#input\_tests) | Map of synthetic tests to create. Each test is automatically routed through the<br/>CDAP-provided Datadog private location for the given environment.<br/><br/>Supported subtypes and their required request\_definition fields:<br/>  - tcp:  host, port<br/>  - http: method, url<br/>  - ssl:  host (port optional, defaults to 443)<br/>  - dns:  host<br/><br/>Assertion operators follow Datadog conventions (e.g. "lessThan", "is", "contains"). | <pre>map(object({<br/>    name    = string<br/>    type    = optional(string, "api")<br/>    subtype = string<br/>    status  = optional(string, "live")<br/><br/>    request_definition = object({<br/>      host   = optional(string)<br/>      port   = optional(number)<br/>      method = optional(string)<br/>      url    = optional(string)<br/>    })<br/><br/>    assertions = list(object({<br/>      type     = string<br/>      operator = string<br/>      target   = string<br/>      property = optional(string)<br/>    }))<br/><br/>    tick_every = optional(number, 60)<br/>    tags       = optional(list(string), [])<br/>  }))</pre> | `{}` | no |

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
| ---- | ---- |
| [datadog_synthetics_test.this](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/synthetics_test) | resource |
| [datadog_synthetics_locations.all](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/data-sources/synthetics_locations) | data source |

<!--WARNING: GENERATED CONTENT with terraform-docs, e.g.
     'terraform-docs --config "$(git rev-parse --show-toplevel)/.terraform-docs.yml" .'
     Manually updating sections between TF_DOCS tags may be overwritten.
     See https://terraform-docs.io/user-guide/configuration/ for more information.
-->
## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_synthetics_tests"></a> [synthetics\_tests](#output\_synthetics\_tests) | List of {name, public\_id} objects formatted for the datadog\_monitors module's synthetics\_tests input. |
<!-- END_TF_DOCS -->
