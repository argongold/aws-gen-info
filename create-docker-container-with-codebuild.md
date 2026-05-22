# Build Lambda Custom Container Image with CodeBuild (aws-nuke)

Use CodeBuild to build a Docker image that includes `aws-nuke`, push it to ECR, then deploy it as a Lambda function.

## 1. Dockerfile

```dockerfile
FROM public.ecr.aws/lambda/provided:al2023

# Install aws-nuke
RUN curl -sL https://github.com/ekristen/aws-nuke/releases/download/v3.64.4/aws-nuke-v3.64.4-linux-amd64.tar.gz | tar xz -C /usr/local/bin aws-nuke

# Copy your Lambda handler (bootstrap script)
COPY bootstrap ${LAMBDA_RUNTIME_DIR}/bootstrap
RUN chmod 755 ${LAMBDA_RUNTIME_DIR}/bootstrap

CMD ["handler"]
```

## 2. bootstrap (Custom Runtime Entry Point)

The `bootstrap` script is executed when the Lambda execution environment starts. It runs a loop that polls the Lambda Runtime API for invocations:

```bash
#!/bin/bash
set -euo pipefail

# Lambda custom runtime loop
while true; do
  # Get next invocation
  HEADERS="$(mktemp)"
  EVENT_DATA=$(curl -sS -LD "$HEADERS" "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/next")
  REQUEST_ID=$(grep -Fi Lambda-Runtime-Aws-Request-Id "$HEADERS" | tr -d '[:space:]' | cut -d: -f2)

  # Run aws-nuke (customize as needed)
  RESPONSE=$(aws-nuke run --config /var/task/nuke-config.yaml --no-prompt 2>&1 || true)

  # Send response
  curl -sS -X POST "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/$REQUEST_ID/response" -d "$RESPONSE"
done
```

## 3. File Placement

Since we are not using a source repository, all files (Dockerfile, bootstrap) are created inline during the build. There are two options:

### Option A: Use a source repository

Place the `Dockerfile`, `bootstrap`, and `buildspec.yml` in the **root of your source repository**:

```
/
├── Dockerfile
├── bootstrap
└── buildspec.yml
```

The buildspec references the Dockerfile via `docker build .` which uses the current directory as build context.

### Option B: No source repository (inline buildspec with `NO_SOURCE`)

Use CodeBuild's `NO_SOURCE` type and create all files inline within the buildspec using heredocs:

```yaml
version: 0.2

env:
  variables:
    ECR_REPO: <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/aws-nuke-lambda
    IMAGE_TAG: latest

phases:
  pre_build:
    commands:
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $ECR_REPO
  build:
    commands:
      # Create Dockerfile inline
      - |
        cat > Dockerfile <<'EOF'
        FROM public.ecr.aws/lambda/provided:al2023
        RUN curl -sL https://github.com/ekristen/aws-nuke/releases/download/v3.64.4/aws-nuke-v3.64.4-linux-amd64.tar.gz | tar xz -C /usr/local/bin aws-nuke
        COPY bootstrap ${LAMBDA_RUNTIME_DIR}/bootstrap
        RUN chmod 755 ${LAMBDA_RUNTIME_DIR}/bootstrap
        CMD ["handler"]
        EOF
      # Create bootstrap inline
      - |
        cat > bootstrap <<'EOF'
        #!/bin/bash
        set -euo pipefail
        while true; do
          HEADERS="$(mktemp)"
          EVENT_DATA=$(curl -sS -LD "$HEADERS" "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/next")
          REQUEST_ID=$(grep -Fi Lambda-Runtime-Aws-Request-Id "$HEADERS" | tr -d '[:space:]' | cut -d: -f2)
          RESPONSE=$(aws-nuke run --config /var/task/nuke-config.yaml --no-prompt 2>&1 || true)
          curl -sS -X POST "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/$REQUEST_ID/response" -d "$RESPONSE"
        done
        EOF
      - chmod +x bootstrap
      - docker build -t $ECR_REPO:$IMAGE_TAG .
  post_build:
    commands:
      - docker push $ECR_REPO:$IMAGE_TAG
```

Create the project with:

```bash
aws codebuild create-project \
  --name aws-nuke-build \
  --source '{"type": "NO_SOURCE", "buildspec": "<inline YAML as escaped string>"}' \
  --environment '{"type": "LINUX_CONTAINER", "image": "aws/codebuild/amazonlinux-x86_64-standard:5.0", "computeType": "BUILD_GENERAL1_SMALL", "privilegedMode": true}' \
  --service-role arn:aws:iam::<ACCOUNT_ID>:role/<CODEBUILD_ROLE>
```

## 4. Setup Steps

1. **Create an ECR repository:**
   ```bash
   aws ecr create-repository --repository-name aws-nuke-lambda --region <REGION>
   ```

2. **Create the CodeBuild project** with:
   - Environment: `aws/codebuild/amazonlinux-x86_64-standard:5.0` (Amazon Linux 2023)
   - **Privileged mode enabled** (required for Docker builds)
   - Source type: `NO_SOURCE` (for Option B) or your repo (for Option A)
   - IAM role with permissions (see [CodeBuild IAM Role Permissions](#codebuild-iam-role-permissions) below)

3. **Create the Lambda function from the image:**
   ```bash
   aws lambda create-function \
     --function-name aws-nuke-function \
     --package-type Image \
     --code ImageUri=<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/aws-nuke-lambda:latest \
     --role arn:aws:iam::<ACCOUNT_ID>:role/<LAMBDA_ROLE> \
     --timeout 900 \
     --memory-size 512
   ```

## CodeBuild IAM Role Permissions

The CodeBuild service role requires the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:GetAuthorizationToken",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
```

> **Note:** For least privilege, scope the ECR actions (except `ecr:GetAuthorizationToken`) to your repository ARN: `arn:aws:ecr:<REGION>:<ACCOUNT_ID>:repository/aws-nuke-lambda`. `ecr:GetAuthorizationToken` must remain `Resource: "*"`.

## Key Considerations

- **Timeout**: Set Lambda timeout to max (900s) since aws-nuke can take time.
- **Memory**: 512 MB+ recommended for aws-nuke.
- **IAM**: The Lambda execution role needs permissions for whatever resources aws-nuke will delete.
- **Image size**: The aws-nuke binary is ~275 MB uncompressed, but within the 10 GB container image limit.
- **Config**: Bundle your `nuke-config.yaml` in the image or fetch it from S3 at runtime.
