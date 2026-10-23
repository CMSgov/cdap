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

If your module's resource makes any AWS API call from inside the VPC (directly, through the AWS provider itself, through a local-exec/data lookup, or through application code at runtime), it needs explicit security group membership to reach our interface/gateway endpoints. There is no default path anymore; egress is intentionally not open by default.

1. Does your resource have its own security group?

   If yes: 
      a. Add a data lookup for the shared endpoint-clients SG: 
            ```
            data "aws_security_group" "vpce_clients_all" {
            name   = "${var.platform.vpc_name}-vpce-clients-all"
            vpc_id = var.platform.vpc_id
            }
         ```

      b. 
         Attach data.aws_security_group.vpce_clients_all.id to your resource's security group list, alongside whatever else it already has. One attachment covers your resources acces to AWS services: SSM, KMS, Secrets Manager, CloudWatch Logs, STS, ECR, SQS, SNS, Lambda invoke, Service Connect, and S3. It is not optional and there is no CIDR fallback.

   If no (your resource has no SG of its own, e.g., SNS, SQS, CloudWatch Log Groups as managed services): no networking change is needed. These are reached by other resources' egress rules, not by anything of their own. You may still need an IAM permission to gain access to those resources, even if the network was successfully traversed.

2. Does your module run as part of a tofu apply, not just at runtime?
  
   If your module's own tofu apply calls something beyond the standard set above and provisions IAM roles, RDS/Aurora clusters, Backup plans, Route 53 zones, CloudFront distributions, EventBridge rules/schedules, Application Auto Scaling targets, or similar, that's a build-time-only call. We assume this is only through Codebuild and ZScaler. You don't need to do anything in your module for this; it's already covered as long as the service appears on our build-services list. If you're adding a genuinely new AWS service dependency that isn't on either list yet, flag it in your PR so we can confirm which list it belongs on.

3. Does your resource make calls indirectly?
   For a local-exec provisioner, a CLI call shelled out from a build step, or application code calling the SDK at runtime all count, the module author is responsible for identifying these. Tofu plan won't surface them. Note any such calls in your PR description so reviewers can check the service against the endpoint list.

