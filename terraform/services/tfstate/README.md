# Terraform for initializing tfstate resources

This terraform creates the S3 buckets and DynamoDB table for storing terraform state in AWS.

Do not specify a backend config for the first `terraform init` to use a local tfstate.

    terraform init
    terraform apply -var="name=bcda-mgmt-tfstate"

Once the resources have been created, uncomment the backend block in terraform.tf and reference a backend config:

    terraform init -backend-config=../../backends/bcda-mgmt.s3.tfbackend

The command should prompt to migrate the existing local state to the remote backend.
