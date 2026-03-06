#!/bin/bash
# Keycloak Benchmark Test Suite
# Usage: ./run-benchmark-suite.sh

CLIENT_ID="gatling-benchmark"
CLIENT_SECRET="X6n8cDMI5vZ2qUYC10daxbrNzQUKOhIY"
SERVER_URL="https://keycloak.ipb.pt"
REALM="master"

echo "=========================================="
echo "Keycloak Benchmark Test Suite"
echo "=========================================="
echo ""

# Test 1: Light Load (50 users/sec)
echo "Test 1: Light Load (50 users/sec, 180s)"
./bin/kcb.sh \
  --scenario=keycloak.scenario.authentication.ClientSecret \
  --server-url=$SERVER_URL \
  --realm-name=$REALM \
  --client-id=$CLIENT_ID \
  --client-secret=$CLIENT_SECRET \
  --users-per-sec=50 \
  --measurement-time=180

echo ""
echo "Test 1 completed. Press Enter to continue..."
read

# Test 2: Medium Load (100 users/sec)
echo "Test 2: Medium Load (100 users/sec, 180s)"
./bin/kcb.sh \
  --scenario=keycloak.scenario.authentication.ClientSecret \
  --server-url=$SERVER_URL \
  --realm-name=$REALM \
  --client-id=$CLIENT_ID \
  --client-secret=$CLIENT_SECRET \
  --users-per-sec=100 \
  --measurement-time=180

echo ""
echo "Test 2 completed. Press Enter to continue..."
read

# Test 3: High Load (200 users/sec)
echo "Test 3: High Load (200 users/sec, 300s)"
./bin/kcb.sh \
  --scenario=keycloak.scenario.authentication.ClientSecret \
  --server-url=$SERVER_URL \
  --realm-name=$REALM \
  --client-id=$CLIENT_ID \
  --client-secret=$CLIENT_SECRET \
  --users-per-sec=200 \
  --measurement-time=300

echo ""
echo "Test 3 completed. Press Enter to continue..."
read

# Test 4: Stress Test (400 users/sec)
echo "Test 4: Stress Test (400 users/sec, 300s)"
./bin/kcb.sh \
  --scenario=keycloak.scenario.authentication.ClientSecret \
  --server-url=$SERVER_URL \
  --realm-name=$REALM \
  --client-id=$CLIENT_ID \
  --client-secret=$CLIENT_SECRET \
  --users-per-sec=400 \
  --measurement-time=300

echo ""
echo "=========================================="
echo "All tests completed!"
echo "Results are in: ./results/"
echo "=========================================="
