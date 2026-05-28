# Build & Deploy Lambda Custom Container Locally

Build the aws-nuke custom container on your laptop, push to ECR, create the Lambda function, and invoke it.

## Prerequisites

- Docker installed and running
- AWS CLI configured with appropriate permissions
- Target region: `eu-west-1` (adjust as needed)

## Step 1: Create Project Files

```bash
mkdir aws-nuke-lambda && cd aws-nuke-lambda
```

**Dockerfile:**

```bash
cat > Dockerfile <<'EOF'
FROM public.ecr.aws/lambda/provided:al2023

RUN curl -sL https://github.com/ekristen/aws-nuke/releases/download/v3.64.4/aws-nuke-v3.64.4-linux-amd64.tar.gz | tar xz -C /usr/local/bin aws-nuke

COPY bootstrap ${LAMBDA_RUNTIME_DIR}/bootstrap
RUN chmod 755 ${LAMBDA_RUNTIME_DIR}/bootstrap

COPY nuke-config.yaml /var/task/nuke-config.yaml

CMD ["handler"]
EOF
```

**bootstrap:**

```bash
cat > bootstrap <<'EOF'
#!/bin/bash
set -euo pipefail

while true; do
  HEADERS="$(mktemp)"
  EVENT_DATA=$(curl -sS -LD "$HEADERS" "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/next")
  REQUEST_ID=$(grep -Fi Lambda-Runtime-Aws-Request-Id "$HEADERS" | tr -d '[:space:]' | cut -d: -f2)

  echo "=== aws-nuke help ==="
  aws-nuke -h

  echo "=== aws-nuke resource-types ==="
  aws-nuke resource-types

  echo "=== aws-nuke run ==="
  RESPONSE=$(aws-nuke run --config /var/task/nuke-config.yaml --no-prompt --no-alias-check 2>&1 | tee /dev/stderr || true)

  curl -sS -X POST "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/$REQUEST_ID/response" -d "$RESPONSE"
done
EOF
chmod +x bootstrap
```

**nuke-config.yaml:**

```bash
cat > nuke-config.yaml <<'EOF'
blocklist:
  - "PRODUCTION_ACCOUNT_ID"

bypass-alias-check-accounts:
  - "TARGET_ACCOUNT_ID"

regions:
  - eu-west-1

resource-types:
  excludes:
    - IAMUser

accounts:
  "TARGET_ACCOUNT_ID":
    presets:
      - tagged-protection

presets:
  tagged-protection:
    filters:
      __global__:
        - property: tag:core-protection
          type: regex
          value: ".+"
EOF
```

## Step 2: Create ECR Repository

```bash
aws ecr create-repository \
  --repository-name aws-nuke-lambda \
  --region eu-west-1
```

## Step 3: Build the Docker Image

```bash
docker build -t aws-nuke-lambda .
```

## Step 4: Tag and Push to ECR

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=eu-west-1
ECR_REPO=$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/aws-nuke-lambda

# Authenticate Docker to ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Tag and push
docker tag aws-nuke-lambda:latest $ECR_REPO:latest
docker push $ECR_REPO:latest
```

## Step 5: Create Lambda Execution Role

```bash
# Create trust policy
cat > trust-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "lambda.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create role
aws iam create-role \
  --role-name aws-nuke-lambda-role \
  --assume-role-policy-document file://trust-policy.json

# Attach permissions (broad access needed for aws-nuke)
aws iam attach-role-policy \
  --role-name aws-nuke-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Attach basic Lambda logging
aws iam attach-role-policy \
  --role-name aws-nuke-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

> **Warning:** `AdministratorAccess` is required for aws-nuke but extremely dangerous. Only use in sandbox/non-production accounts.

## Step 6: Create the Lambda Function

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws lambda create-function \
  --function-name aws-nuke-function \
  --package-type Image \
  --code ImageUri=$ACCOUNT_ID.dkr.ecr.eu-west-1.amazonaws.com/aws-nuke-lambda:latest \
  --role arn:aws:iam::$ACCOUNT_ID:role/aws-nuke-lambda-role \
  --timeout 900 \
  --memory-size 512 \
  --region eu-west-1
```

> **Note:** Wait ~10 seconds after creating the role for IAM propagation before creating the function.

## Step 7: Invoke the Lambda

```bash
aws lambda invoke \
  --function-name aws-nuke-function \
  --region eu-west-1 \
  --cli-read-timeout 900 \
  output.json

# View the response
cat output.json
```

Or invoke asynchronously (returns immediately, check CloudWatch for results):

```bash
aws lambda invoke \
  --function-name aws-nuke-function \
  --region eu-west-1 \
  --invocation-type Event \
  /dev/null
```

## Step 8: Check CloudWatch Logs

```bash
aws logs tail /aws/lambda/aws-nuke-function --region eu-west-1 --follow
```

## Updating the Image

After making changes to the Dockerfile or bootstrap:

```bash
# Rebuild, tag, push
docker build -t aws-nuke-lambda .
docker tag aws-nuke-lambda:latest $ECR_REPO:latest
docker push $ECR_REPO:latest

# Update Lambda to use the new image
aws lambda update-function-code \
  --function-name aws-nuke-function \
  --image-uri $ECR_REPO:latest \
  --region eu-west-1
```
