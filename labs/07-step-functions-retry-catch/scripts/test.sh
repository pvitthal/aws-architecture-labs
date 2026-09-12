#!/usr/bin/env bash
set -euo pipefail
lab_dir="$(cd "$(dirname "$0")/.." && pwd)"
STATE_MACHINE_ARN="$(tofu -chdir="$lab_dir/infra/tofu" output -raw state_machine_arn)" \
node "$lab_dir/tests/integration/workflow.test.mjs"
