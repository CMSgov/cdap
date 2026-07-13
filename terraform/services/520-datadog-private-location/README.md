## Using CDAP's Datadog Private Location for Synthetic API Tests

### Overview

CDAP runs a Datadog private location (PL) worker as an ECS Fargate service in cdap-test and cdap-prod VPCs. It polls Datadog for synthetic test jobs and executes them against internal APIs that are not internet-accessible. Your team's responsibility is two things: **open your service to receive traffic from the PL**, and **write the synthetic test in Terraform**.

---

### Step 1 — Enable Synthetics Ingress on Your ECS Service Module

In your service's `module "service"` block, set the flag:

```hcl
module "your_api" {
  source = "../../modules/service"
  ...
  enable_datadog_synthetics_ingress = true
}
```

**What this does under the hood:**
- The service module reads the PL worker's security group ID from SSM at `/cdap/${env}/datadog/nonsensitive/private_location_task_security_group_id`
- It creates an `aws_vpc_security_group_ingress_rule` on your task's SG that references the PL's SG, allowing all inbound traffic from the PL runner

> **Prerequisite:** Your service must be in a VPC already listed in the PL's config file (terraform/services/520-datadog-private-location/config/). If your VPC is not listed, open a PR to add it.

---

### Step 2 — Write the Synthetic Test in Terraform

Use the `datadog_synthetics_test` resource. Look up the private location ID by name using `data.datadog_synthetics_locations`:

```hcl
data "datadog_synthetics_locations" "all" {}

resource "datadog_synthetics_test" "your_api_health" {
  name    = "your-app-${var.env}-api-health"
  type    = "api"
  subtype = "http"
  status  = "live"

  request_definition {
    method = "GET"
    url    = "http://your-internal-alb-dns/health"
  }

  assertion {
    type     = "statusCode"
    operator = "is"
    target   = "200"
  }

  # Resolve the private location ID by display name
  locations = [
    one([
      for id, name in data.datadog_synthetics_locations.all.locations :
      id
      if startswith(lower(name), "cdap-non-prod")  # use "cdap-prod" for prod
    ])
  ]

  options_list {
    tick_every = 60  # seconds between runs
  }

  tags = ["environment:${var.env}", "app:your-app", "managed-by:tofu"]
}
```

The display name prefix for each environment:
| Environment | Name filter |
|---|---|
| `test` | `cdap-non-prod` |
| `prod` | `cdap-prod` |

---

### Step 3 — Wire it to a Monitor (Optional but Recommended)

Once the synthetic test is created, attach a `datadog_monitor` of type `"synthetics alert"` referencing the test's ID to get alerting via the existing Datadog → Slack pipeline.

---

### Summary of What Each Team Owns

| Responsibility | Owner |
|---|---|
| Running the PL worker | CDAP (520-datadog-private-location) |
| PL egress rules to app VPCs | CDAP (add your VPC to the config yml) |
| `enable_datadog_synthetics_ingress = true` on your service | **Your team** |
| `datadog_synthetics_test` resource | **Your team** |
| Datadog API/App keys for the provider | CDAP (via `501-datadog-cicd-keys`) |

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_datadog"></a> [datadog](#requirement\_datadog) | ~>4.4 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.52.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_cdap_cluster"></a> [cdap\_cluster](#module\_cdap\_cluster) | ../../modules/cluster | n/a |
| <a name="module_ecs_datadog_synthetics"></a> [ecs\_datadog\_synthetics](#module\_ecs\_datadog\_synthetics) | ../../modules/service | n/a |
| <a name="module_platform"></a> [platform](#module\_platform) | ../../modules/platform | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_vpc_security_group_egress_rule.private_location_app_vpcs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_env"></a> [env](#input\_env) | The application environment (test, prod) | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
