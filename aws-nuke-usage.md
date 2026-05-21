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

## References

- [ekristen/aws-nuke releases](https://github.com/ekristen/aws-nuke/releases)
- [Debian package aws-nuke](https://packages.debian.org/STABLE/aws-nuke)
- [AWS Lambda layers documentation](https://docs.aws.amazon.com/lambda/latest/dg/adding-layers.html)
