# OpenTofu for ecr-cleanup function and associated infra

This service sets up the infrastructure for the ecr-cleanup lambda function, which runs nightly to delete old ECR images while protecting any image referenced by an active ECS task definition.

## Updating the lambda code

The executable for this lambda is in lambda_src. It must pass both pylint and pytest checks.

### Run the tests
```bash
cd lambda_src
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
pip install pylint pytest
pylint lambda_function.py
pytest .
```

## Configuring repositories

### Lifecycle functions
A lifecycle function should have `images` as the first argument. Additional arguments should be added to determine which images apply to this function. For example, the `count_image_strategy` function takes images, prefix, and count as its arguments. The `prefix` argument ensures that the strategy applies only to images that match the prefix.
Lifecycle functions should mark image `status` with either `PROTECT` or `DELETE`. They should not overwrite an existing status.

### To set up lifecycles for a given repository
 - Add the repository name as a key in the REPO_STRATEGIES dictionary
 - Add a tuple as the value for this key
 - For each lifecycle, add the function (along with additional arguments) to the tuple. These functions will run in order.

## Dry Run
Dry runs are available locally via the command line. 
- First, set your AWS credentials for the environment you want to invoke (e.g. `kion stak`). 
- Then set up a .json file to reflect repositories you want to test (e.g. `terraform/services/ecr-cleanup/lambda_src/dry_run_config.json`)
- Output will be all images that would be deleted in a deployed environment.

#### Example
```bash
cd lambda_src
python3 -m venv venv && source venv/bin/activate
# Testing new config file
python3 dry_run.py --config-path path/to/new_config.json
# Defaults to existing dry_run_config.json with DPC strategies
python3 dry_run.py
```

## Opting In
By default, the lambda operates in 'dry-run' mode, in which images it would delete are simply logged. To opt-in a repository for a given AWS account, so it actually deletes images, add its name to the `locals.repo_list_by_env` list in `./main.tf` for the appropriate account.

## Manual deploy

Pass in a backend file when running tofu init. Example:

```bash
export AWS_REGION=us-east-1
tofu init -backend-config=../../backends/cdap-test.s3.tfbackend
tofu apply -var app=cdap -var env=test 
```


## Manually invoking
```bash
aws lambda invoke --function-name dpc-test-ecr-cleanup --region us-east-1 response.json
```