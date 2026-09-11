#!/usr/bin/env bash
set -euo pipefail

lab_dir="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$lab_dir/dist"
for function in processor compensator; do
  rm -f "$lab_dir/dist/$function.zip"
  (cd "$lab_dir/src/$function" && zip -X -q -j "../../dist/$function.zip" index.mjs)
done
