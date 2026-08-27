# OpenTofu for ecr-cleanup function and associated infra

This service sets up the infrastructure for the `ecr-cleanup` Lambda function, which runs nightly to delete old ECR images while protecting any image referenced by an active ECS task definition.

Repositories are discovered automatically at runtime based on a naming prefix — there is no manual repo list to maintain in Tofu. Deletion is opt-in per repository; anything not explicitly opted in runs in log-only mode.

## How it works

On each invocation, the Lambda:

1. Builds a set of "protected references" — every image tag and digest currently referenced by a running ECS task, across all clusters in the account.
2. Discovers ECR repositories whose name matches this app's prefix (e.g. `dpc-*`).
3. For each discovered repo, applies its configured cleanup strategies in order — either an explicit override or a shared default — to decide which images are eligible for deletion.
4. Skips any image that's in the protected-reference set, no matter what a strategy says.
5. For repos with `opt_in: true`, deletes the remaining eligible images. For everything else, it logs what *would* have been deleted and takes no action.

Strategies run in the order they're configured, and once a strategy marks an image `PROTECT` or `DELETE`, no later strategy can change that status. This means ordering strategies matters — put your most conservative protections first if you want them to win.

## What this guarantees

The sweeper is built around one hard rule: **an image is only deletable if it is both stale (or excess) and provably inactive.** Neither condition alone is enough.

**Active images are always safe.** If an image is referenced by any currently running ECS task, in any cluster, it will never be deleted — regardless of its age, its tag, or what any strategy says about it. This protection is checked before any deletion strategy runs, and it can't be overridden by strategy configuration. If ECS discovery itself fails (the account's running tasks can't be determined), the sweeper fails closed: no images are deleted at all for that run, rather than proceeding with a possibly-incomplete protected set.
**Explicitly protected tags and digests are always safe.** Beyond ECS-derived protection, any image whose tag or digest is directly passed in as a protected reference is excluded from deletion, independent of strategy logic.
**Deletion requires both staleness and non-redundancy.** The two built-in strategies — `days_older_than` (age-based) and `count_image` (keep only the N most recent matching a tag prefix) — only mark an image `DELETE` if it fails their specific check. An image within the retention window, or within the "keep N" count, is explicitly marked `PROTECT`, and that protection sticks even if a later strategy would otherwise flag it. In other words, an image needs an unprotected path all the way through every configured strategy before it's eligible for removal.
**Nothing is deleted unless a repo has explicitly opted in.** By default, every discovered repository runs in log-only mode: eligible images are identified and logged, but `batch_delete_image` is never called. A repo only has images actually removed once its config explicitly sets `opt_in: true`. This means turning on real deletion for a new repo is a deliberate, visible configuration change — never an accidental side effect of the repo simply matching the naming prefix.
**Partial failures are visible, not silent.** If AWS reports that some images in a delete batch failed (e.g. because ECS temporarily still references them), those failures are logged individually rather than swallowed. The same applies to ECS `describe_tasks` failures during protected-reference discovery — a partial failure is surfaced in the logs, not hidden behind an apparently successful run.
**A broken deploy fails loudly, not quietly.** The function module invokes the Lambda with a liveness-check payload immediately after every deploy. That check does a lightweight ECR call and nothing else — it never touches image state — and if that call fails, the function raises, which fails the Tofu apply. A misconfigured IAM policy or broken deploy is caught immediately, not discovered days later when the nightly run silently does nothing.

## Configuring repositories

There's no per-repo list to maintain in Tofu. Any ECR repository whose name starts with this app's prefix is discovered automatically and evaluated on every run.

Two environment variables, both set from Tofu locals, control behavior:
- `DEFAULT_STRATEGIES` — the strategy list applied to any discovered repo that doesn't have an explicit override. Repos falling back to this default always run with `opt_in: false` (log-only) until someone deliberately configures otherwise.
- `REPO_OVERRIDES` — a map of repo name to `{ strategies, opt_in }`, for any repo that needs custom strategies, or that should have real deletion turned on.

To onboard a repo with default behavior, do nothing — as long as its name matches the prefix, it's already being evaluated in log-only mode.
To give a repo custom strategies, or to turn on real deletion, add an entry for it under `repo_overrides` in `main.tf`:

```hcl
locals {
  repo_overrides = {
    "dpc-web" = {
      strategies = local.default_strategies
      opt_in     = true
    }
  }
}
```

## Lifecycle strategies

A strategy function takes images as its first argument, followed by whatever arguments narrow down which images it applies to. For example, count_image_strategy(images, prefix, count) only considers images whose tag starts with prefix, and keeps at most count of the most recent matches.

Strategy functions mark each image's status as either PROTECT or DELETE. They must never overwrite a status that's already been set — this is what makes strategy order matter, and what lets an earlier, more conservative strategy override a later one.

To configure lifecycles for a repo, list its strategies as an array of [strategy_name, tag_prefix, argument] tuples. They run in the order listed:

```hcl
strategies = [
["count_image", "rls-r", 5],
["days_older_than", "", 14],
["days_older_than", null, 14]
]
```

Use "" as the tag prefix to match all tagged images, and null to match only untagged images.

## Opting in

By default, every discovered repository runs in log-only mode — eligible images are identified and logged, but nothing is deleted. To let a repository actually delete images, add it to repo_overrides in main.tf with opt_in = true, as shown above, and apply.

Treat flipping opt_in to true as a real production change: review the strategies configured for that repo first, and confirm with the owning team that the retention window and count are what they expect.


# Local development

All local commands run from lambda_src/. A Makefile wraps the common workflows:

```bash
cd lambda_src
make install    # creates a venv and installs runtime + dev dependencies
make test       # runs the unit test suite (fully mocked, no AWS credentials needed)
make test-cov   # runs tests with a coverage report
make lint       # runs pylint against the shipped code
make dry-run    # runs dry_run.py against real AWS (requires an active AWS session)
make clean      # removes the venv and generated test/coverage artifacts

make test and make test-cov never touch AWS — test_lambda_function.py and test_strategies.py mock both the ECS and ECR clients directly, so the full suite runs offline.
```

## Dry run against real AWS

dry_run.py is the one local entry point that calls real AWS APIs, so it needs live credentials. 
This repo uses Kion for AWS access — log in and select your target account in the same terminal session you'll run make from, since the Makefile relies on whatever credentials are already in your shell environment. 
make dry-run checks for a valid session first and gives you a clear error if one isn't active, rather than failing deep inside a boto3 call.

Set up a JSON config describing the repos and strategies you want to test — dry_run_config.json in this directory is a working example — then run:

``` bash 
cd lambda_src
# using the default dry_run_config.json
make dry-run
# using a different config file
make install
./.venv/bin/python dry_run.py --config-path path/to/your_config.json
```
Output lists every image that would be deleted per repo, using its tags if it has any, or its digest if it's untagged. Nothing is actually deleted by a dry run.

# Manual deploy
Pass in a backend file when running tofu init. Example:


``` bash
export AWS_REGION=us-east-1
tofu init -backend-config=../../backends/cdap-test.s3.tfbackend
tofu apply -var app=cdap -var env=test
```

# Manually invoking

```bash
aws lambda invoke --function-name cdap-test-ecr-cleanup --region us-east-1 response.json
```

To run a liveness check, not a full pass of the function: 
``` bash
aws lambda invoke \
  --function-name cdap-test-ecr-cleanup \
  --region us-east-1 \
  --payload '{"RequestType": "LivenessCheck"}' \
  --cli-binary-format raw-in-base64-out \
  response.json
```
