#!/usr/bin/env bash
set -euo pipefail
tofu_dir="$(cd "$(dirname "$0")/../infra/tofu" && pwd)"
lab_dir="$(cd "$(dirname "$0")/.." && pwd)"
API_URL="$(cd "$tofu_dir" && tofu output -raw api_url)" \
EMAIL_TABLE_NAME="$(cd "$tofu_dir" && tofu output -raw email_table_name)" \
AUDIT_TABLE_NAME="$(cd "$tofu_dir" && tofu output -raw audit_table_name)" \
node "$lab_dir/tests/integration/api.test.mjs"
