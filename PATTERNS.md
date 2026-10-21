# Adding a script, Lambda function, or GitHub Action

Any new code under `terraform/services/**/lambda_src/`, `scripts/*/`, or `actions/*/`
is automatically picked up by `code-checks.yml` and scanned/tested on every pull
request. Nothing needs to be registered manually — detection is based on marker
files:

| Marker file       | Language detected |
|--------------------|--------------------|
| `go.mod`           | Go                 |
| `package.json`     | Node / TypeScript  |
| `requirements.txt` | Python             |

To be considered "check-ready," a directory should have:

1. **A Makefile** with at minimum `install`, `test`, and `lint` targets, so a
   developer can validate changes locally with the same commands CI uses.
   Add a `dry-run` or `plan` target if the code talks to AWS, so local usage
   is self-documenting about needing active credentials.
2. **A `sonar-project.properties` file** covering settings intrinsic to the
   code itself — test directory location, TypeScript config paths, coverage
   report paths. Do not duplicate `sonar.sources` or `sonar.exclusions` here;
   those are set centrally in `checks-reusable.yml` for every caller.
3. **A test suite** with a real `test_command` wired into a `checks.yml`
   file in the same directory (see below). Until this exists, the directory
   still gets a static Sonar scan on every PR, but with no coverage data —
   that's a valid but temporary state, not a passing bar.

## Overriding CI behavior — `checks.yml`

Drop a `checks.yml` next to the code if defaults need overriding:

```yaml
enabled: true                # set false to exclude from checks entirely
test_command: "..."          # overrides the language default
language_version: "3.13"     # overrides the language default
sonar_extra_args: "..."      # rarely needed — prefer sonar-project.properties
```

# Adding a module that calls AWS APIs or other AWS services

If your module's resource makes any AWS API call from inside the VPC (directly, through the AWS provider itself, through a local-exec/data lookup, or through application code at runtime), it needs explicit sec group rules to reach our interface/gateway endpoints. There is no default path anymore; egress is intentionally not open by default.

1. Does your resource have its own security group?

If yes: 
a. Add a data lookup for the shared endpoint-clients SG: 
```
data "aws_security_group" "endpoint_clients" {
  name   = "${var.platform.vpc_name}-vpce-clients"
  vpc_id = var.platform.vpc_id
}
```

b. Attach data.aws_security_group.endpoint_clients.id to your resource's security group list, alongside whatever else it already has. This is what grants your resource ingress on the endpoints SG. It is not optional and there is no CIDR fallback.

c. If your resource also talks to S3, add the S3 prefix-list egress rule, gated behind a needs_s3_access variable so teams can opt out when it doesn't apply. S3 is a gateway endpoint, not an interface endpoint: it has no ENI and no security group of its own, as such, we reference the prefix list and use the bool variable:

```
data "aws_ec2_managed_prefix_list" "s3" {
  count = var.needs_s3_access ? 1 : 0
  name  = "com.amazonaws.${var.platform.primary_region.name}.s3"
}

resource "aws_vpc_security_group_egress_rule" "to_s3" {
  count             = var.needs_s3_access ? 1 : 0
  security_group_id = <your resource's SG id>
  prefix_list_id    = data.aws_ec2_managed_prefix_list.s3[0].id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}
```

If no (your resource has no SG of its own, e.g., SNS, SQS, CloudWatch Log Groups as managed services): no networking change is needed. These are reached by other resources' egress rules, not by anything of their own. You may still need an IAM permission to gain access to those resources, even if the network was successfully traversed.

2. Does your resource make calls indirectly?
For a local-exec provisioner, a CLI call shelled out from a build step, or application code calling the SDK at runtime all count, the module author is responsible for identifying these. Tofu plan won't surface them. Note any such calls in your PR description so reviewers can check the service against the endpoint list.

