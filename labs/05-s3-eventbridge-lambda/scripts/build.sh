#!/usr/bin/env bash
set -euo pipefail

lab_dir="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$lab_dir/dist"
rm -f "$lab_dir/dist/processor.zip"
(
  cd "$lab_dir/src"
  zip -X -q -j ../dist/processor.zip index.mjs
)
