# AWS CodeBuild with Managed Images

## How It Works

CodeBuild provides **managed build images** (Amazon Linux, Ubuntu) that come pre-installed with common runtimes and tools. You define what to run in a `buildspec.yml` file placed in your source root.

## Basic Example

```yaml
version: 0.2

phases:
  install:
    runtime-versions:
      python: 3.12
    commands:
      - echo "Installing additional tools..."
      - yum install -y jq  # Amazon Linux
      # - apt-get install -y jq  # Ubuntu image

  pre_build:
    commands:
      - echo "Running pre-build commands"
      - aws --version
      - python --version

  build:
    commands:
      - echo "Running your CLI tools here"
      - aws s3 ls
      - ./my-script.sh
      - make build

  post_build:
    commands:
      - echo "Build complete"

artifacts:
  files:
    - '**/*'
  base-directory: output
```

## Available Tools in Managed Images

- AWS CLI (pre-installed)
- Docker, git, curl, wget
- Language runtimes (Python, Node.js, Java, Go, Ruby, .NET, PHP)
- Build tools (make, gcc, etc.)

## Installing Additional CLI Tools

Use the `install` phase:

```yaml
phases:
  install:
    commands:
      - pip install awscli-local
      - npm install -g serverless
      - curl -LO https://example.com/some-tool && chmod +x some-tool
```

## Running Arbitrary Commands

Each `commands` entry is a shell command run as root (by default):

```yaml
phases:
  build:
    commands:
      - bash my-script.sh
      - terraform plan
      - kubectl apply -f deployment.yaml
```

## Creating the Project (CLI)

```bash
aws codebuild create-project \
  --name my-project \
  --source type=CODECOMMIT,location=https://git-codecommit.us-east-1.amazonaws.com/v1/repos/my-repo \
  --environment type=LINUX_CONTAINER,computeType=BUILD_GENERAL1_SMALL,image=aws/codebuild/amazonlinux2-x86_64-standard:5.0 \
  --service-role arn:aws:iam::123456789012:role/codebuild-role
```

## Common Managed Images

| Image | OS |
|-------|-----|
| `aws/codebuild/amazonlinux2-x86_64-standard:5.0` | Amazon Linux 2 |
| `aws/codebuild/standard:7.0` | Ubuntu 22.04 |
| `aws/codebuild/amazonlinux2-aarch64-standard:3.0` | Amazon Linux 2 (ARM) |

## Installing Additional Tools (e.g., aws-nuke)

You can install additional tools like `aws-nuke` on CodeBuild managed images. Just download and install in the `install` phase:

```yaml
version: 0.2

phases:
  install:
    commands:
      - wget -q https://github.com/rebuy-de/aws-nuke/releases/download/v2.25.0/aws-nuke-v2.25.0-linux-amd64.tar.gz
      - tar -xzf aws-nuke-v2.25.0-linux-amd64.tar.gz
      - mv aws-nuke-v2.25.0-linux-amd64 /usr/local/bin/aws-nuke
      - chmod +x /usr/local/bin/aws-nuke
      - aws-nuke version

  build:
    commands:
      - aws-nuke -c nuke-config.yml --no-dry-run
```

The managed images run as root and have internet access by default, so you can install anything you'd install on a regular Linux box — download binaries, use `yum`/`apt-get`, `pip`, `npm`, `go install`, etc.

## Tips

- The CodeBuild service role's IAM permissions determine what AWS CLI commands succeed (e.g., needs `s3:ListBucket` for `aws s3 ls`).
- Use `env` section to pass secrets from Parameter Store or Secrets Manager without hardcoding.
- If the managed image doesn't have what you need, you can use a **custom Docker image** from ECR instead.
- Tools are installed fresh on every build (no persistence between builds). Use CodeBuild's **cache** feature to speed up repeated builds.
