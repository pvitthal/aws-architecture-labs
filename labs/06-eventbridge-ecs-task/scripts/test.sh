#!/usr/bin/env bash
set -euo pipefail

lab_dir="$(cd "$(dirname "$0")/.." && pwd)"
tofu_dir="$lab_dir/infra/tofu"
CLUSTER_NAME="$(tofu -chdir="$tofu_dir" output -raw cluster_name)" \
node "$lab_dir/tests/integration/eventbridge-ecs.test.mjs"
