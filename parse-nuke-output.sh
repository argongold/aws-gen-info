#!/bin/bash

FILE="fake-aws-nuke-dry-run-output.txt"

SCAN_LINE=$(grep "Scan complete:" "$FILE")

TOTAL=$(echo "$SCAN_LINE" | awk '{print $3}')
NUKEABLE=$(echo "$SCAN_LINE" | awk '{print $5}')
FILTERED=$(echo "$SCAN_LINE" | awk '{print $7}')
SKIPPED=$(echo "$SCAN_LINE" | awk '{print $9}')

RESOURCES=$(grep -E "would remove|removed" "$FILE" | awk -F" - " '{gsub(/'\''/, "", $3); print $3}' | jq -R . | jq -s .)

JSON_OUTPUT=$(echo "{\"total\": $TOTAL, \"nukeable\": $NUKEABLE, \"filtered\": $FILTERED, \"skipped\": $SKIPPED, \"resources\": $RESOURCES}" | jq .)

echo "$JSON_OUTPUT"
