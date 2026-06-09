# AWS Nuke Resource Deletion Architecture

## Overview

Use aws-nuke from Lambda containers in all regions, orchestrated by Step Functions, triggered by EventBridge for a specific target account. The state machine fans out regional Lambdas in parallel, retries until all resources are deleted, and sends SNS notifications on completion.

---

## Design Review

### What's Good

1. **Container Lambda** — correct choice since aws-nuke binary exceeds layer limits
2. **Parallel regional execution** — avoids sequential bottleneck of native aws-nuke
3. **Step Functions retry loop** — handles dependency chains that require multiple passes
4. **SSM Parameter for config** — enables per-region configuration without redeploying containers
5. **SNS notification** — provides completion feedback

---

## What's Missing or Needs Attention

### 1. Global Resources Conflict

IAM, Route 53, S3 buckets, CloudFront are global or us-east-1-specific. If all regional Lambdas try to delete IAM roles simultaneously, you'll get conflicts.

**Fix:** Designate `us-east-1` Lambda as the global resource handler. Other regional Lambdas should use a config with `resource-types.excludes` for global resources.

### 2. Lambda 15-Minute Timeout

A single region with many resources (non-empty S3 buckets, EKS clusters, CloudFormation stacks) can exceed 15 minutes. The retry loop helps, but:

**Fix:** The bootstrap script should capture aws-nuke's exit status and return structured JSON (not raw stdout) indicating:
- `status`: `complete` | `resources_remaining` | `error`
- `remaining_count`: number of resources still pending
- `region`: which region this Lambda handled

### 3. Cross-Account Role Assumption

Step Functions assumes a role in the target account, but the Lambdas run in the service catalog account. The Lambdas themselves need to assume a role in the target account to actually delete resources there.

**Fix:** Pass the target account's role ARN in the Lambda event payload. The bootstrap/aws-nuke config should use that role via `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` (from STS assume-role) or configure aws-nuke's built-in account credential support.

### 4. ECR Replication Timing

Clarify the deployment model:

- **Option A:** Lambdas in service catalog account, assume role into target account → no ECR replication needed to member accounts, just replicate across regions in the service catalog account.
- **Option B:** Lambdas deployed in each member account → needs ECR replication to member accounts + Lambda deployment in each account.

Option A is simpler for a centralized orchestration model.

### 5. 3-Retry Limit May Not Be Enough

Some resources take 30+ minutes to delete (CloudFront, RDS, KMS pending deletion). With 30-minute intervals and only 3 retries, you cover 90 minutes total.

**Fix:** Consider:
- 5 retries as the default
- Distinguish between "resources actively deleting" (keep retrying) vs "nothing changed between runs" (likely stuck, fail early)
- Differentiate resources in pending-deletion state (KMS, Secrets Manager) — these can't be fixed by retrying

### 6. No DynamoDB/State Tracking

If the Step Function fails mid-execution (service issue, timeout), you have no record of what was attempted.

**Fix:** Consider a DynamoDB table tracking:
- Target account ID
- Execution timestamp
- Per-region status
- Final outcome

### 7. EventBridge Event Schema

Define what triggers the nuke:
- A custom event from a self-service portal?
- An AWS Organizations event (account moved to a "decommission" OU)?
- A scheduled rule?

This affects how you pass the target account ID and role ARN to the state machine.

### 8. Settings for Protected Resources

Make sure your nuke-config.yaml in SSM includes settings to auto-disable protections:

```yaml
settings:
  EC2Instance:
    DisableDeletionProtection: true
    DisableStopProtection: true
  RDSInstance:
    DisableDeletionProtection: true
  ELBv2:
    DisableDeletionProtection: true
  CloudFormationStack:
    DisableDeletionProtection: true
```

Otherwise these resources will fail on every retry.

---

## Improved Architecture

```
EventBridge (target account event)
    → Step Functions (service catalog account)
        → Step 1: Validate target account (is it in the OU? not in blocklist?)
        → Step 2: Assume role in target account, discover active regions
        → Step 3: Map state — fan out Lambda per active region
            - us-east-1 Lambda: handles global + regional resources
            - Other Lambdas: regional resources only
        → Step 4: Collect results
        → Step 5: Choice state
            - All complete → SNS success
            - Resources remaining + retries < max → Wait 30 min → Go to Step 3
            - Resources remaining + retries >= max → SNS failure (with details)
```

### Key Additions

- **Account validation step** — prevents nuking the wrong account
- **Active region discovery** — only invoke Lambdas in regions that have resources
- **Structured Lambda response** — enables intelligent retry decisions
- **Separate global vs regional config** — avoids conflicts

---

## Alternative Options

| Approach | Pros | Cons |
|----------|------|------|
| **Lambda + Step Functions** | Serverless, cost-efficient, parallel | 15-min timeout, complex retry logic |
| **Fargate + Step Functions** | No timeout limit, same orchestration | Higher cost if idle, slower cold start |
| **Hybrid: Lambda first pass, Fargate for stragglers** | Best of both — fast for most, patient for slow resources | More complex deployment |
| **AWS Organizations SCP + Lambda** | Apply deny-all SCP first to prevent new resource creation during cleanup | Adds safety but doesn't help with deletion speed |

### Recommendation

Stick with Lambda + Step Functions design but add:
1. An SCP applied to the target account during nuke (prevent new resource creation)
2. Global resource isolation to us-east-1
3. Structured Lambda responses
4. 5 retries with "no progress" early termination
5. Account validation as the first step
