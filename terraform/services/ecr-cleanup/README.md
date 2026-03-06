# OpenTofu for ecr-cleanup function and associated infra

This service sets up the infrastructure for the ecr-cleanup lambda function, which runs nightly to delete old ECR images while protecting any image referenced by an active ECS task definition.

## Updating the lambda code

The executable for this lambda is in lambda_src. It must pass both pylint and pytest checks.

### Run the tests
```bash
cd lambda_src
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
pip install pylint pytest
pylint lambda_function.py
pytest .
```

## Configuring repositories

Pass the list of ECR repositories to manage via the `repo_list` variable. Terraform will create and manage the SSM parameter.

## Manual deploy

Pass in a backend file when running terraform init. Example:

```bash
export AWS_REGION=us-east-1
tofu init -backend-config=../../backends/dpc-prod.s3.tfbackend
tofu apply -var app=dpc -var env=test -var repo_list='["dpc-web-admin", "dpc-web-portal"]'
```
