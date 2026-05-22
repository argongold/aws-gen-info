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

## 3. buildspec.yml (CodeBuild)

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
      - docker build -t $ECR_REPO:$IMAGE_TAG .
  post_build:
    commands:
      - docker push $ECR_REPO:$IMAGE_TAG
```

## 4. Setup Steps

1. **Create an ECR repository:**
   ```bash
   aws ecr create-repository --repository-name aws-nuke-lambda --region <REGION>
   ```

2. **Create the CodeBuild project** with:
   - Environment: `aws/codebuild/amazonlinux2-x86_64-standard:5.0`
   - **Privileged mode enabled** (required for Docker builds)
   - IAM role with permissions for ECR push (`ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:PutImage`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`)

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

## Key Considerations

- **Timeout**: Set Lambda timeout to max (900s) since aws-nuke can take time.
- **Memory**: 512 MB+ recommended for aws-nuke.
- **IAM**: The Lambda execution role needs permissions for whatever resources aws-nuke will delete.
- **Image size**: The aws-nuke binary is ~275 MB uncompressed, but within the 10 GB container image limit.
- **Config**: Bundle your `nuke-config.yaml` in the image or fetch it from S3 at runtime.
