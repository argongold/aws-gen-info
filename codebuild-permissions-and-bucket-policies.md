# CodeBuild Permissions & S3 Bucket Policies

## CodeBuild Role Permissions (IAM Policy)

```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject"
  ],
  "Resource": "arn:aws:s3:::<BUCKET_NAME>/aws-nuke/*"
}
```

> For SSE-S3 (default encryption with `AES256`), no explicit KMS permissions are needed. The AWS-managed `aws/s3` key is automatically accessible to any principal in the same account that has `s3:GetObject` permission.

### Cross-Account Note

- **Same account:** Either the IAM policy on the role OR the bucket policy is sufficient. Both together also works.
- **Different accounts:** You need **both** the IAM policy and the bucket policy.

## S3 Bucket Policy — Allow CodeBuild Role Access

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::<ACCOUNT_ID>:role/<CODEBUILD_ROLE>"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::<BUCKET_NAME>/aws-nuke/*"
    }
  ]
}
```

## S3 Bucket Policy — Enforce Secure Transport & Encryption

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": "arn:aws:s3:::<BUCKET_NAME>/*",
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    },
    {
      "Sid": "DenyUnencryptedPut",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::<BUCKET_NAME>/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": "AES256"
        }
      }
    }
  ]
}
```

### Explanation

- **DenyInsecureTransport** — Denies all S3 operations over non-HTTPS.
- **DenyUnencryptedPut** — Denies any `PutObject` that doesn't include the `x-amz-server-side-encryption: AES256` header.
