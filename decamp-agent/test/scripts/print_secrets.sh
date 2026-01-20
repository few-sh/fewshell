#!/bin/bash
# Mock script that prints environment variables (for secret testing)
# Usage: print_secrets.sh <var1> <var2> ...

for var_name in "$@"; do
  if [ -n "${!var_name}" ]; then
    echo "$var_name=${!var_name}"
  else
    echo "$var_name is not set"
  fi
done
