# Download Latest aws-nuke (Linux amd64)

The active/maintained fork is [ekristen/aws-nuke](https://github.com/ekristen/aws-nuke/releases).

## Linux / macOS (bash)

```bash
# Get the latest version
VERSION=$(curl -s https://api.github.com/repos/ekristen/aws-nuke/releases/latest | grep '"tag_name"' | cut -d '"' -f 4)

# Download the tar.gz
curl -sL "https://github.com/ekristen/aws-nuke/releases/download/${VERSION}/aws-nuke-${VERSION}-linux-amd64.tar.gz" -o aws-nuke-linux-amd64.tar.gz
```

## Windows (batch file)

Save as `download-aws-nuke.bat` and run with `call download-aws-nuke.bat`:

```bat
@echo off
REM Download latest aws-nuke linux amd64 tar.gz

for /f "tokens=2 delims=:" %%a in ('curl -s https://api.github.com/repos/ekristen/aws-nuke/releases/latest ^| findstr "tag_name"') do (
    set "VERSION=%%~a"
)
set "VERSION=%VERSION: =%"
set "VERSION=%VERSION:,=%"
set "VERSION=%VERSION:"=%"

echo Downloading aws-nuke %VERSION%...
curl -sL "https://github.com/ekristen/aws-nuke/releases/download/%VERSION%/aws-nuke-%VERSION%-linux-amd64.tar.gz" -o aws-nuke-linux-amd64.tar.gz
echo Done.
```
