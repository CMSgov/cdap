TF_DIR   ?= .

FUNCTION_ADDR   := module.tftesting_function.aws_lambda_function.this
INVOCATION_ADDR := module.tftesting_function.aws_lambda_invocation.liveness_check[0]

.PHONY: plan deploy test-invocation test-redeploy

plan:
	cd $(TF_DIR) && tofu plan

deploy:
	cd $(TF_DIR) && tofu apply

# Re-run the liveness check only. Function code/zip is untouched.
# Use this after changing infra OUTSIDE this module to confirm the Lambda can still reach its dependencies.
test-invocation:
	cd $(TF_DIR) && tofu apply -replace='$(INVOCATION_ADDR)'

# Force a full destroy/recreate of the Lambda function itself, with no
# code change, then run the liveness check against the fresh function.
test-redeploy:
	cd $(TF_DIR) && tofu apply -replace='$(FUNCTION_ADDR)' -replace='$(INVOCATION_ADDR)'
