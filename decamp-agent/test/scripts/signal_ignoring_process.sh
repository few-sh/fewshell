#!/bin/bash
# A test process that ignores SIGINT, SIGTERM, SIGHUP, and SIGQUIT signals.
# Only SIGKILL can terminate it.

# Trap signals and print a message instead of terminating
trap 'echo "Received SIGINT, ignoring it"' INT
trap 'echo "Received SIGTERM, ignoring it"' TERM
trap 'echo "Received SIGHUP, ignoring it"' HUP
trap 'echo "Received SIGQUIT, ignoring it"' QUIT

echo "Signal-ignoring process started"
echo "PID: $$"

counter=0
while true; do
    counter=$((counter + 1))
    echo "Iteration $counter"
    sleep 0.5
done
