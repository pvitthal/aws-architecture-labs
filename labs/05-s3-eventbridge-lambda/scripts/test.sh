#!/usr/bin/env bash
set -euo pipefail

lab_dir="$(cd "$(dirname "$0")/.." && pwd)"
tofu_dir="$lab_dir/infra/tofu"
TABLE_NAME="$(tofu -chdir="$tofu_dir" output -raw table_name)" \
BUCKET_NAME="$(tofu -chdir="$tofu_dir" output -raw bucket_name)" \
node "$lab_dir/tests/integration/eventbridge.test.mjs"
