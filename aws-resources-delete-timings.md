# AWS Resources Deletion Timings

## Days/Weeks

| Resource | Deletion Time | Reason |
|----------|--------------|--------|
| **KMS Keys** | 7–30 days | Mandatory waiting period (configurable, default 30 days) before permanent deletion |
| **Secrets Manager Secrets** | 7–30 days | Recovery window (configurable, default 30 days); can force immediate delete with `--force-delete-without-recovery` |
| **RDS Final Snapshots / Backups** | Up to 35 days | Automated backups retained per retention window after instance deletion |
| **S3 Buckets (with Object Lock)** | Days to years | Objects with legal hold or retention lock cannot be deleted until retention expires |

## Minutes to Hours

| Resource | Deletion Time | Reason |
|----------|--------------|--------|
| **CloudFront Distributions** | 15–30 minutes | Must disable first (takes ~15 min), then delete (another ~15 min for edge propagation) |
| **RDS Instances** | 5–30 minutes | Final snapshot creation + instance teardown |
| **Transit Gateway (TGW)** | 10–20 minutes | Must delete all attachments first; each attachment takes several minutes |
| **NAT Gateways** | 5–15 minutes | Releases ENIs and EIPs |
| **EKS Clusters** | 10–20 minutes | Must delete node groups/Fargate profiles first |
| **ElastiCache Clusters** | 5–15 minutes | Snapshot creation + node teardown |
| **Elastic Load Balancers** | 5–10 minutes | Draining connections + deregistering targets |
| **VPCs** (with dependencies) | Variable | Must delete all dependent resources (subnets, IGWs, endpoints, etc.) first |

## Notable Mentions

- **Amazon Redshift clusters** — 5–20 min (longer with final snapshot)
- **AWS Directory Service** — 10–30 min
- **Amazon OpenSearch domains** — 10–20 min
- **ECS/Fargate tasks** — resources can remain queryable for up to 30 minutes post-deletion

## Key Takeaway

KMS keys are by far the longest at up to 30 days. For most other resources, the delay is operational (minutes/hours) or caused by dependency chains rather than built-in waiting periods.

## Handling Long-Delete Resources with Custom Lambda Container (15 min timeout)

Since Lambda has a hard 15-minute timeout, use one of these strategies when running aws-nuke from a custom container Lambda:

### Option 1: Scheduled Re-Invocations (Simplest)

Run the Lambda on a recurring schedule. aws-nuke is idempotent — it skips already-deleted resources and retries pending ones.

```
EventBridge Rule (every 15 min) → Lambda (aws-nuke)
```

This works because aws-nuke issues delete API calls, AWS processes them in the background, and the next invocation cleans up whatever's left.

### Option 2: Step Functions Loop

Use a Step Functions state machine that re-invokes until no resources remain:

```
Start → Lambda (aws-nuke) → Check output → [resources remain?]
                                              ├─ Yes → Wait 5 min → Lambda again
                                              └─ No  → Done
```

Gives you built-in retry logic with configurable waits.

### Option 3: Offload to Fargate

For accounts with many slow-delete resources, trigger a Fargate task with no timeout limit:

```
Lambda (trigger) → ECS Fargate Task (aws-nuke, runs as long as needed)
```

### Which to Choose?

| Option | Best For |
|--------|----------|
| Scheduled re-invocations | Simple setups, most use cases |
| Step Functions | When you need completion confirmation or error handling |
| Fargate | Accounts with many slow resources (KMS, CloudFront, TGW, RDS) |
