#!/usr/bin/env bash
set -euo pipefail

tofu_dir="${1:?OpenTofu directory is required}"
state_file="$(mktemp)"
updated_state_file="$(mktemp)"
trap 'rm -f "$state_file" "$updated_state_file"' EXIT

if ! tofu -chdir="$tofu_dir" state pull > "$state_file" 2>/dev/null; then
  exit 0
fi

if ! jq -e '[.resources[] | .instances[]? | .attributes.timeout_milliseconds? | select(. == 0)] | length > 0' "$state_file" >/dev/null; then
  exit 0
fi

jq '(.serial += 1) | (.resources[] | .instances[]? | select(.attributes.timeout_milliseconds? == 0) | .attributes.timeout_milliseconds) = 50' \
  "$state_file" > "$updated_state_file"
tofu -chdir="$tofu_dir" state push "$updated_state_file"
echo 'Normalized Floci API Gateway timeout state for the AWS provider.'

