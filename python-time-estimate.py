import subprocess, time, sys

payload = '{"no_dry_run": true}' if "--no-dry-run" in sys.argv else '{}'

start = time.time()
result = subprocess.run(
    ["aws", "lambda", "invoke", "--function-name", "aws-nuke-function",
     "--payload", payload, "--cli-binary-format", "raw-in-base64-out", "out.json"],
    capture_output=False
)
elapsed = time.time() - start

print(f"\nElapsed: {elapsed:.2f}s ({int(elapsed//60)}m {elapsed%60:.2f}s)")
