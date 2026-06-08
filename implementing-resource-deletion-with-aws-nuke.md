# Implementing Resource Deletion with aws-nuke

## Parallel Multi-Region Execution Strategy

aws-nuke processes regions **sequentially** by default. To speed up multi-region account cleanup, use a Step Function that fans out to region-specific Lambdas in parallel. Each Lambda runs aws-nuke with a single-region config, so they all execute simultaneously.

## Key Considerations

### 15-Minute Lambda Timeout

Even with a single region, if an account has many resources (especially things like non-empty S3 buckets, EKS clusters, or CloudFormation stacks with nested resources), one region can exceed 15 minutes. Have a retry/re-invoke strategy or consider the Lambda calling itself again for unfinished work.

### Multiple Passes Needed

aws-nuke often needs 2-3+ passes per region because of resource dependencies (e.g., can't delete a subnet until the ENI is gone, can't delete a security group until the instance is terminated). A single Lambda invocation may not be enough.

### Global Resources

IAM roles, Route 53 hosted zones, S3 buckets, CloudFront distributions, etc. are global or `us-east-1`-specific. Make sure only ONE Lambda handles those (typically the `us-east-1` one), otherwise you'll get conflicts or duplicate attempts.

### Step Function Design

Consider a pattern like:

- Fan out all regional Lambdas in parallel (Map state)
- Collect results
- If any region reports "resources still remaining," loop and re-invoke those Lambdas
- Exit when all report clean

### Concurrency/Throttling

Multiple Lambdas hitting different regional APIs simultaneously is fine (different regional endpoints), so you shouldn't hit cross-region throttling issues.

## Summary

This architecture trades the simplicity of a single aws-nuke run for parallelism, which is the correct tradeoff when Lambda's time constraint is a factor.
