#!/bin/bash
# Mock script that produces fast chunked output
# Usage: fast_output.sh <lines>

lines=${1:-100}

for i in $(seq 1 $lines); do
  echo "Fast line $i"
done
