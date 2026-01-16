#!/bin/bash
# Mock script that runs for a specified duration
# Usage: long_running.sh <seconds>

duration=${1:-10}

trap 'echo "Caught signal, exiting..."; exit 143' SIGTERM SIGINT

echo "Starting long running task for $duration seconds"

for i in $(seq 1 $duration); do
  echo "Second $i of $duration"
  sleep 1
done

echo "Completed successfully"
