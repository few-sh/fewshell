#!/bin/bash
# Mock script that streams output line by line with delays
# Usage: stream_output.sh <count> <delay_ms>

count=${1:-5}
delay=${2:-100}

for i in $(seq 1 $count); do
  echo "Line $i"
  sleep $(echo "scale=3; $delay/1000" | bc)
done
