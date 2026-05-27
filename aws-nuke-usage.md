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

## References

- [ekristen/aws-nuke releases](https://github.com/ekristen/aws-nuke/releases)
- [Debian package aws-nuke](https://packages.debian.org/STABLE/aws-nuke)
- [AWS Lambda layers documentation](https://docs.aws.amazon.com/lambda/latest/dg/adding-layers.html)
