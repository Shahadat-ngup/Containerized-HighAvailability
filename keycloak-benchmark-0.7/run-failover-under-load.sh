#!/bin/bash
# Failover Under Load Test: Database failure during sustained authentication traffic
# Purpose: Measure transient errors, latency spikes, and recovery time during failover

cd /mnt/c/Users/Shaha/Documents/Containerized-HighAvailability/keycloak-benchmark-0.7

CLIENT_ID="gatling-benchmark"
CLIENT_SECRET="X6n8cDMI5vZ2qUYC10daxbrNzQUKOhIY"
SERVER_URL="https://keycloak.ipb.pt"
REALM="master"

echo "=========================================="
echo "Failover Under Load Test - AUTOMATED"
echo "=========================================="
echo ""
echo "Test Plan:"
echo "1. Detect current Patroni leader"
echo "2. Start sustained 200 req/s load for 5 minutes"
echo "3. After 2 minutes, automatically kill current leader"
echo "4. Monitor error rates and latency during failover"
echo ""

# Auto-detect current Patroni leader
cd /mnt/c/Users/Shaha/Documents/Containerized-HighAvailability
INV=ansible/inventory/hosts

echo "Detecting current Patroni leader..."
LEADER_INFO=$(ansible backend1 -i $INV --become -m shell -a "curl -s http://127.0.0.1:8008/cluster | jq -r '.members[] | select(.role==\"leader\") | \"\(.name)|\(.api_url)\"'" 2>/dev/null | grep -E "patroni-[0-9]" | head -1)

if [ -z "$LEADER_INFO" ]; then
    echo "ERROR: Could not detect Patroni leader!"
    exit 1
fi

LEADER_NAME=$(echo "$LEADER_INFO" | cut -d'|' -f1)
LEADER_IP=$(echo "$LEADER_INFO" | cut -d'|' -f2 | grep -oP '(?<=http://)[0-9.]+')

# Map IP to backend node
case "$LEADER_IP" in
    "172.29.65.52") LEADER_NODE="backend1"; LEADER_CONTAINER="patroni-backend1" ;;
    "172.29.65.53") LEADER_NODE="backend2"; LEADER_CONTAINER="patroni-backend2" ;;
    "172.29.65.54") LEADER_NODE="backend3"; LEADER_CONTAINER="patroni-backend3" ;;
    *) echo "ERROR: Unknown leader IP: $LEADER_IP"; exit 1 ;;
esac

echo "✓ Current leader: $LEADER_NAME ($LEADER_IP)"
echo "✓ Target node: $LEADER_NODE"
echo "✓ Container: $LEADER_CONTAINER"
echo ""
echo "=========================================="
echo ""

read -p "Press Enter to start the automated failover test..."

cd /mnt/c/Users/Shaha/Documents/Containerized-HighAvailability/keycloak-benchmark-0.7

echo ""
echo "Starting 200 req/s load for 5 minutes..."
echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo ">>> AUTO-FAILOVER SCHEDULED IN 2 MINUTES (at $(date -d '+2 minutes' '+%H:%M:%S')) <<<"
echo ""

# Start benchmark in background
./bin/kcb.sh \
  --scenario=keycloak.scenario.authentication.ClientSecret \
  --server-url=$SERVER_URL \
  --realm-name=$REALM \
  --client-id=$CLIENT_ID \
  --client-secret=$CLIENT_SECRET \
  --users-per-sec=200 \
  --measurement=300 &

BENCHMARK_PID=$!

# Wait 2 minutes, then trigger failover
sleep 120

echo ""
echo "=========================================="
echo ">>> TRIGGERING FAILOVER NOW <<<"
echo "Stopping $LEADER_CONTAINER on $LEADER_NODE..."
echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

ansible $LEADER_NODE -i /mnt/c/Users/Shaha/Documents/Containerized-HighAvailability/ansible/inventory/hosts --become -m shell -a "docker stop $LEADER_CONTAINER" 2>&1 | grep -E "CHANGED|FAILED" || echo "Failover command executed"

echo ""
echo "Failover triggered! Benchmark continuing..."
echo ""

# Wait for benchmark to complete
wait $BENCHMARK_PID

echo ""
echo "=========================================="
echo "Failover test completed!"
echo ""
echo "Analysis checklist:"
echo "✓ Check error rate in results (should be <1%)"
echo "✓ Compare P99 latency: before failover vs during vs after"
echo "✓ Note recovery time (when latency returns to baseline)"
echo "✓ Verify zero permanent failures (all retries succeeded)"
echo "=========================================="
