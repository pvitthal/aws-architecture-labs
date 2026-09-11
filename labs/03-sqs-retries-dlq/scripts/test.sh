#!/usr/bin/env bash
set -euo pipefail
tofu_dir="$(cd "$(dirname "$0")/../infra/tofu" && pwd)"
lab_dir="$(cd "$(dirname "$0")/.." && pwd)"
API_URL="$(cd "$tofu_dir" && tofu output -raw api_url)" \
TABLE_NAME="$(cd "$tofu_dir" && tofu output -raw table_name)" \
DLQ_URL="$(cd "$tofu_dir" && tofu output -raw dlq_url)" \
node "$lab_dir/tests/integration/api.test.mjs"
