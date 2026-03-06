#!/bin/bash

echo "=========================================="
echo "Optimized Capacity Test: 500 users/sec"
echo "=========================================="
echo ""
echo "Testing sweet spot between 400 and 600 req/s"
echo "Expected: 450-480 req/s with 0% errors"
echo ""
echo "=========================================="
echo ""
read -p "Press Enter to start 500 users/sec test..."

CLIENT_ID="gatling-benchmark"
CLIENT_SECRET="YOUR_CLIENT_SECRET_HERE"
SERVER_URL="https://keycloak.ipb.pt"
REALM="master"
echo ""
echo "Starting 500 users/sec load test..."
echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

./bin/kcb.sh \
  --scenario=keycloak.scenario.authentication.ClientSecret \
  --server-url=$SERVER_URL \
  --realm-name=$REALM \
  --client-id=$CLIENT_ID \
  --client-secret=$CLIENT_SECRET \
  --users-per-sec=500 \
  --measurement-time=60

echo ""
echo "=========================================="
echo "Test completed!"
echo ""
echo "Expected results at 500 users/sec:"
echo "  Actual throughput: 450-480 req/s"
echo "  Error rate: 0%"
echo "  Mean latency: 85-110ms"
echo "=========================================="
