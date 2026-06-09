# aws-nuke Settings-Capable Resources

These are the resources in [ekristen/aws-nuke](https://github.com/ekristen/aws-nuke) that support `settings` in the config file. Settings modify how resources are deleted (e.g., automatically disabling protections before deletion).

## Usage in Config

```yaml
settings:
  EC2Instance:
    DisableDeletionProtection: true
    DisableStopProtection: true
  RDSInstance:
    DisableDeletionProtection: true
```

## Resources and Their Settings

| Resource | Settings | Description |
|----------|----------|-------------|
| `CloudFormationStack` | `DisableDeletionProtection`, `CreateRoleToDeleteStack`, `UseCurrentRoleToDeleteStack` | Disable stack termination protection; create/use IAM role to delete stack |
| `CloudWatchLogsLogGroup` | `DisableDeletionProtection` | Disable log group deletion protection |
| `CognitoUserPool` | `DisableDeletionProtection` | Disable user pool deletion protection |
| `DocDBCluster` | `DisableDeletionProtection` | Disable DocumentDB cluster deletion protection |
| `DSQLCluster` | `DisableDeletionProtection` | Disable DSQL cluster deletion protection |
| `DynamoDBTable` | `DisableDeletionProtection` | Disable DynamoDB table deletion protection |
| `EC2Image` | `DisableDeregistrationProtection`, `IncludeDeprecated`, `IncludeDisabled` | Disable AMI deregistration protection; include deprecated/disabled AMIs |
| `EC2Instance` | `DisableDeletionProtection`, `DisableStopProtection` | Disable termination and stop protection |
| `EKSCluster` | `DisableDeletionProtection` | Disable EKS cluster deletion protection |
| `ELBv2` | `DisableDeletionProtection` | Disable ALB/NLB deletion protection |
| `IAMRole` | `IncludeServiceLinkedRoles` | Include service-linked roles in deletion |
| `IAMUser` | `IgnorePermissionBoundary` | Ignore permission boundary during deletion |
| `LightsailInstance` | `ForceDeleteAddOns` | Force delete associated add-ons |
| `NeptuneCluster` | `DisableDeletionProtection` | Disable Neptune cluster deletion protection |
| `NeptuneGraph` | `DisableDeletionProtection` | Disable Neptune graph deletion protection |
| `NeptuneInstance` | `DisableClusterDeletionProtection`, `DisableDeletionProtection` | Disable cluster and instance deletion protection |
| `PinpointPhoneNumber` | `DisableDeletionProtection` | Disable phone number deletion protection |
| `QLDBLedger` | `DisableDeletionProtection` | Disable QLDB ledger deletion protection |
| `QuickSightSubscription` | `DisableTerminationProtection` | Disable QuickSight account termination protection |
| `RDSInstance` | `DisableDeletionProtection`, `StartClusterToDelete` | Disable deletion protection; start stopped cluster before deletion |
| `S3Bucket` | `BypassGovernanceRetention`, `RemoveObjectLegalHold` | Bypass Object Lock governance mode; remove legal holds |
| `SSMQuickSetupConfigurationManager` | `CreateRoleToDelete` | Create IAM role needed for deletion |

## Notes

- All settings are boolean (`true`/`false`).
- Settings only take effect when set to `true`.
- Without these settings, aws-nuke will fail to delete resources that have protections enabled.
- Source: [ekristen/aws-nuke](https://github.com/ekristen/aws-nuke) (extracted from source code)
