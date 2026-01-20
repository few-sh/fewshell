#!/bin/bash
# Mock script that outputs to both stdout and stderr
# Usage: mixed_output.sh

echo "stdout line 1"
echo "stderr line 1" >&2
echo "stdout line 2"
echo "stderr line 2" >&2
echo "stdout line 3"
