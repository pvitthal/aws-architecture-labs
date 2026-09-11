#!/usr/bin/env bash
set -euo pipefail

lab_dir="$(cd "$(dirname "$0")/.." && pwd)"
tofu_dir="$lab_dir/infra/tofu"
API_URL="$(tofu -chdir="$tofu_dir" output -raw api_url)" \
ORDERS_TABLE_NAME="$(tofu -chdir="$tofu_dir" output -raw orders_table_name)" \
AUDIT_TABLE_NAME="$(tofu -chdir="$tofu_dir" output -raw audit_table_name)" \
node "$lab_dir/tests/integration/orders.test.mjs"
