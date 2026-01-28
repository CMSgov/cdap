# OpenTofu for Service Connect namespaces for each ECS Cluster

This OpenTofu code creates aws_service_discovery_http_namespace for each ECS Cluster.

## Instructions

Pass in a backend file when running tofu init. Example:

```bash
tofu init -reconfigure -backend-config=../../backends/cdap-test.s3.tfbackend
tofu plan
```
