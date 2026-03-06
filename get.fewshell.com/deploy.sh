#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="get-fewshell-com"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cp "$SCRIPT_DIR/index.html.sh" "$tmpdir/index.html"
cp "$SCRIPT_DIR/explain.html" "$tmpdir/"
cp "$SCRIPT_DIR/_headers" "$tmpdir/"

wrangler pages deploy "$tmpdir" --project-name="$PROJECT_NAME" --commit-dirty=true
