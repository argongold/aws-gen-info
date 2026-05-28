# Using aws-nuke with AWS Lambda

## aws-nuke Binary Sizes (v3.64.4)

| Platform | Compressed (tar.gz) | Uncompressed (estimated) |
|----------|---------------------|--------------------------|
| Linux amd64 | **56.5 MB** | ~125-130 MB |
| Linux arm64 | **50.2 MB** | ~120+ MB |

## Can You Use It in a Lambda Layer?

**No — it won't fit.**

- **Lambda layer zip limit:** 50 MB (zipped)
- **aws-nuke compressed size:** 56.5 MB (already exceeds the zip limit)
- **Combined unzipped limit:** 250 MB total (function code + all layers) — the ~125 MB uncompressed binary alone would consume half of this

## Alternatives

1. **Container-based Lambda** — Lambda supports container images up to **10 GB**. Package aws-nuke in a Docker image and deploy it as a container Lambda function. This is the most practical approach.

2. **ECS/Fargate or EC2** — If your use case involves long-running cleanup (aws-nuke can take a while), Lambda's 15-minute timeout may also be a constraint. A Fargate task or Step Functions orchestration might be more appropriate.

3. **Download at runtime from S3** — Store the binary in S3 and download it to `/tmp` (10 GB available) at invocation time. This adds latency but `/tmp` doesn't count toward the 250 MB unzipped deployment limit, so it *could* work — though it's fragile and slow.

## Recommendation

Use a **container-based Lambda** or a **Fargate task** for running aws-nuke.

## Running aws-nuke in Automation

```bash
aws-nuke run --config /var/task/nuke-config.yaml --no-prompt 2>&1 || true
```

| Part | Purpose |
|------|---------|
| `aws-nuke run` | Executes aws-nuke to delete all resources in the target AWS account |
| `--config /var/task/nuke-config.yaml` | Path to the config file defining target accounts, regions, resource types, and filters |
| `--no-prompt` | Skips interactive confirmation prompts for unattended execution (Lambda, CI/CD) |
| `2>&1` | Redirects stderr to stdout, combining all output into a single stream for logging |
| `|| true` | Ensures exit code 0 even if aws-nuke fails, preventing pipeline/script abort on partial failures |

The `|| true` is useful because some resources may fail to delete due to dependencies or permissions, and you typically don't want that to halt the entire workflow.

## `--no-dry-run` Flag

By default, `--no-dry-run` is **`false`** (dry-run mode is ON). This means aws-nuke will only **list** resources it would delete without actually removing anything. You must explicitly pass `--no-dry-run` to perform actual deletions.

```bash
# Dry run (default) — just lists resources
aws-nuke run --config nuke-config.yaml

# Actually delete resources
aws-nuke run --config nuke-config.yaml --no-dry-run
```

This is a safety mechanism to prevent accidental resource deletion.

## Resource Discovery Process

aws-nuke discovers resources through a built-in registry of resource types, each with a "lister" that calls the corresponding AWS API.

**How it works:**

1. **Loads registered resource types** — aws-nuke has ~300+ resource types (e.g., `EC2Instance`, `S3Bucket`, `IAMRole`). List them with `aws-nuke resource-types`.
2. **Iterates through configured regions** — only regions in your `regions:` config are scanned.
3. **Calls List/Describe APIs for each type** — e.g., `ec2:DescribeInstances`, `s3:ListBuckets`, `iam:ListRoles`.
4. **Applies filters** — resources matching `filters:` or `presets:` are marked as protected and skipped.
5. **Deletes remaining resources** — calls the appropriate Delete/Terminate API for each unfiltered resource.

**Controlling what gets scanned:**

| Config key | Purpose |
|------------|---------|
| `regions:` | Limit which regions are scanned |
| `resource-types.includes:` | Only scan these specific types |
| `resource-types.excludes:` | Skip these types entirely |
| `filters:` | Protect specific resources by property, tag, or regex |
| `presets:` | Reusable filter sets applied to accounts |

**Example — only scan EC2 and S3 resources:**

```yaml
resource-types:
  includes:
    - EC2Instance
    - EC2SecurityGroup
    - S3Bucket
    - S3Object
```

> **Note:** The Lambda execution role needs broad permissions because aws-nuke calls List/Describe and Delete APIs across many services. This is why `Action: "*"` is used for the nuke role.

## References

- [ekristen/aws-nuke releases](https://github.com/ekristen/aws-nuke/releases)
- [Debian package aws-nuke](https://packages.debian.org/STABLE/aws-nuke)
- [AWS Lambda layers documentation](https://docs.aws.amazon.com/lambda/latest/dg/adding-layers.html)
