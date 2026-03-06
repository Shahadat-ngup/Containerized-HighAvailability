#!/bin/bash
# Statistical Validation: 10 Independent Trials for 400 req/s Load Test
# Purpose: Generate data for mean ± standard deviation and 95% confidence intervals

cd /mnt/c/Users/Shaha/Documents/Containerized-HighAvailability/keycloak-benchmark-0.7

CLIENT_ID="gatling-benchmark"
CLIENT_SECRET="YOUR_CLIENT_SECRET_HERE"
SERVER_URL="https://keycloak.ipb.pt"
REALM="master"

echo "=========================================="
echo "Starting 10-Trial Statistical Validation"
echo "Target: 400 users/sec, 30s measurement"
echo "Total time: ~35 minutes (with 2min waits)"
echo "=========================================="
echo ""

for i in {1..10}; do
  echo "===================="
  echo "Trial $i of 10"
  echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "===================="
  
  ./bin/kcb.sh \
    --scenario=keycloak.scenario.authentication.ClientSecret \
    --server-url=$SERVER_URL \
    --realm-name=$REALM \
    --client-id=$CLIENT_ID \
    --client-secret=$CLIENT_SECRET \
    --users-per-sec=400 \
    --measurement-time=30
  
  if [ $i -lt 10 ]; then
    echo ""
    echo "Waiting 2 minutes before next trial to allow system stabilization..."
    echo "Next trial starts at: $(date -d '+2 minutes' '+%H:%M:%S')"
    sleep 120
  fi
  
  echo ""
done

echo ""
echo "=========================================="
echo "All 10 trials completed!"
echo "Results saved in: results/"
echo ""
echo "Next step: Run calculate-statistics.sh to compute mean ± SD and 95% CI"
echo "=========================================="
