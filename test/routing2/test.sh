#!/bin/bash

. $(dirname $0)/../shared/check.sh

set -eux

SCRIPT_DIR=$(cd $(dirname $0); pwd)
cd $SCRIPT_DIR
MONITOR_FILE=/tmp/routing2-monitor

# Cleanup function to ensure containers are stopped
cleanup() {
    echo "Cleaning up..."
    docker compose down -v 2>/dev/null || true
    [ -f $MONITOR_FILE ] && rm -f $MONITOR_FILE
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Remove old monitor file if it exists
if [ -f $MONITOR_FILE ]; then
    rm $MONITOR_FILE
fi

# Stop any existing containers
echo "Stopping any existing containers..."
docker compose down -v

# Build images
echo "Building Docker images..."
docker compose build

# Start containers
echo "Starting containers..."
docker compose up -d

# Wait for services to be fully ready
echo "Waiting for services to start..."
sleep 5

# Verify containers are running
echo "Verifying containers..."
docker compose ps

# Start monitoring MPTCP events
echo "Starting MPTCP monitor..."
docker compose exec -T client ip mptcp monitor > $MONITOR_FILE &
MONITOR_PID=$!

# Wait a bit for monitor to start
sleep 1

# Run iperf3 test
echo "Running iperf3 test..."
docker compose exec client iperf3 -c localhost -p 5555 -t 5 -4

# Stop monitor
kill $MONITOR_PID 2>/dev/null || true
wait $MONITOR_PID 2>/dev/null || true

# Stop containers
echo "Stopping containers..."
docker compose down

# Verify results
echo "Verifying test results..."
check $MONITOR_FILE 'CREATED' 2
check $MONITOR_FILE ' ESTABLISHED' 2
check $MONITOR_FILE 'ANNOUNCED' 0
check $MONITOR_FILE 'SF_ESTABLISHED' 2
check $MONITOR_FILE 'CLOSED' 2

echo "All tests passed successfully!"

