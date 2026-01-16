#!/bin/bash
# Mock script that exits with a specific code
# Usage: exit_with_code.sh <exit_code>

exit_code=${1:-0}
echo "Exiting with code $exit_code"
exit $exit_code
