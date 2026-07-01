# aws-nuke Timeout & Retry Behavior

## Does aws-nuke Have a Default Timeout?

**No.** aws-nuke itself does not have a built-in timeout. It runs indefinitely until all resources are deleted (or fail). It operates in a loop: scan → delete → wait → rescan, repeating until nothing is left.

## Controllable Settings

### `--max-wait-retries` (CLI flag)

If resources get stuck in a "waiting" state (e.g., pending deletion), aws-nuke keeps retrying indefinitely by default.

- Set `--max-wait-retries N` to make it exit after N iterations of stuck resources.
- **Default: `0`** (disabled — never exits early, retries indefinitely).

```bash
aws-nuke run --config nuke-config.yaml --max-wait-retries 5 --no-prompt
```

### `--force-sleep` (older rebuy-de version)

Controls the delay before starting deletions when using `--force`. Defaults to 15 seconds. This is not a timeout for the overall process, just a confirmation delay.

## Runtime Timeout Constraints

Since aws-nuke has no process-level timeout, the real constraint comes from **where you run it**:

| Runtime | Timeout |
|---------|---------|
| Lambda (container) | 15 minutes max |
| Fargate task | No hard timeout |
| CodeBuild | 8 hours max (default 60 min) |
| EC2/local machine | None |

Lambda's 15-minute limit is a real constraint for large accounts — Fargate or CodeBuild are better choices in those cases.

## Idempotent Behavior

aws-nuke is **idempotent** — you can run it multiple times safely. If it gets killed mid-run (e.g., Lambda timeout), you can re-run it. It will scan again, skip already-deleted resources, and continue deleting whatever's left. Running it twice doesn't double-delete or cause errors.

## Real-World Experience: Lambda Multi-Invocation Pattern

Running aws-nuke in Lambda against ~280 resources:

| Run | Resources Targeted | Result | Duration |
|-----|--------------------|--------|----------|
| 1st | 280 | Deleted 157, failed 123 | 6.5 minutes |
| 2nd (30 min later) | ~123 remaining | Deleted all remaining | 3 minutes |

**Total wall-clock time:** ~40 minutes (6.5 min + 30 min wait + 3 min)

### Why Resources Fail on First Run

Many AWS resources have **dependencies** — they can't be deleted until their dependents are gone:

- Can't delete a VPC until subnets, security groups, ENIs, NAT gateways are gone
- Can't delete an S3 bucket until objects are removed
- Can't delete an IAM role until policies are detached
- Some resources take time to fully terminate (e.g., RDS, NAT Gateways, EKS clusters)

aws-nuke attempts deletion but within a single Lambda run, some resources aren't ready because their dependencies are still being cleaned up by AWS in the background.

### Why the Second Run Succeeds

By the time you run it again (15-30 minutes later), AWS has finished tearing down those dependent resources, so the remaining resources are now free to delete.

### Note on `--max-wait-retries`

Without `--max-wait-retries` set, aws-nuke isn't stuck in a retry loop — it reports failures and exits because those resources genuinely can't be deleted yet (dependency ordering), not because it's endlessly retrying.

## Recommended Multi-Invocation Strategy for Lambda

1. **First run:** Deletes what it can (~50-60% of resources typically)
2. **Wait 15-30 minutes** for AWS to finish async teardowns
3. **Second run:** Cleans up the rest

## Bounding Total Runtime

If you need to enforce a hard timeout externally, wrap the command:

```bash
timeout 3600 aws-nuke run --config nuke-config.yaml --no-prompt --no-dry-run
```

Or use `--max-wait-retries` to prevent infinite loops on stuck resources.
