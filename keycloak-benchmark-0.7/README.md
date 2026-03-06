# Keycloak Benchmark Test Suite

## Prerequisites

1. **Client created in Keycloak:**

   - Client ID: `gatling-benchmark`
   - Client authentication: ON
   - Service accounts roles: ON

2. **Environment:** Linux/WSL terminal

## Running Tests

### Option 1: Run All Tests (Automated Suite)

```bash
cd /mnt/c/Users/Shaha/Documents/Containerized-HighAvailability/keycloak-benchmark-0.7

# Make script executable
chmod +x run-benchmark-suite.sh

# Run all 4 tests
./run-benchmark-suite.sh
```

### Option 2: Run Individual Tests

```bash
# Test 1: Light Load (50 users/sec)
./bin/kcb.sh \
  --scenario=keycloak.scenario.authentication.ClientSecret \
  --server-url=https://keycloak.ipb.pt \
  --realm-name=master \
  --client-id=gatling-benchmark \
  --client-secret='YOUR_CLIENT_SECRET' \
  --users-per-sec=50 \
  --measurement-time=180

# Test 2: Medium Load (100 users/sec)
./bin/kcb.sh \
  --scenario=keycloak.scenario.authentication.ClientSecret \
  --server-url=https://keycloak.ipb.pt \
  --realm-name=master \
  --client-id=gatling-benchmark \
  --client-secret='YOUR_CLIENT_SECRET' \
  --users-per-sec=100 \
  --measurement-time=180

# Test 3: High Load (200 users/sec)
./bin/kcb.sh \
  --scenario=keycloak.scenario.authentication.ClientSecret \
  --server-url=https://keycloak.ipb.pt \
  --realm-name=master \
  --client-id=gatling-benchmark \
  --client-secret='YOUR_CLIENT_SECRET' \
  --users-per-sec=200 \
  --measurement-time=300

# Test 4: Stress Test (400 users/sec)
./bin/kcb.sh \
  --scenario=keycloak.scenario.authentication.ClientSecret \
  --server-url=https://keycloak.ipb.pt \
  --realm-name=master \
  --client-id=gatling-benchmark \
  --client-secret='YOUR_CLIENT_SECRET' \
  --users-per-sec=400 \
  --measurement-time=300
```

## View Results

### Method 1: Windows Explorer

```powershell
# In PowerShell
start C:\Users\Shaha\Documents\Containerized-HighAvailability\keycloak-benchmark-0.7\results
```

Then open any `index.html` file.

### Method 2: WSL

```bash
cd /mnt/c/Users/Shaha/Documents/Containerized-HighAvailability/keycloak-benchmark-0.7/results
explorer.exe .
```

### Method 3: Direct Open Latest Result

```bash
ls -lt results/  # List results by date
# Open the latest folder's index.html
```

## Optimizing for High-Load Tests

### Reduce Monitoring Overhead (Recommended for 400+ users/sec)

**Before running stress test:**

```bash
cd /mnt/c/Users/Shaha/Documents/Containerized-HighAvailability

# Stop monitoring services on bastion1
ansible bastion1 -i ansible/inventory/hosts -m shell -a "docker stop cadvisor prometheus promtail loki"
```

**After stress test completes:**

```bash
# Restart monitoring services
ansible bastion1 -i ansible/inventory/hosts -m shell -a "docker start cadvisor prometheus promtail loki"
```

## Monitoring During Tests

### Watch CPU Usage

```bash
# Real-time CPU monitoring (refreshes every 2 seconds)
watch -n 2 'ansible all -i ansible/inventory/hosts -m shell -a "top -bn1 | grep Cpu"'

ansible all -i ansible/inventory/hosts -m shell -a "top -bn1 | grep Cpu"
```

### Watch Container Stats on Bastion

```bash
# Check which containers are using CPU
ansible bastion1 -i ansible/inventory/hosts -m shell -a "docker stats --no-stream"
```

### Watch HAProxy Metrics

```bash
# Monitor HAProxy backend sessions
watch -n 2 'curl -s http://193.136.194.103:9101/metrics | grep haproxy_backend_current_sessions'
```

## Test Results Summary

| Test   | Target | Expected Throughput | Expected Mean RT | Status       |
| ------ | ------ | ------------------- | ---------------- | ------------ |
| Test 1 | 50/s   | ~45 req/sec         | ~85ms            | ✅ Optimal   |
| Test 2 | 100/s  | ~90 req/sec         | ~85ms            | ✅ Optimal   |
| Test 3 | 200/s  | ~180 req/sec        | ~89ms            | ✅ Good      |
| Test 4 | 400/s  | ~320 req/sec        | ~2900ms          | ⚠️ Saturated |

**Recommended production load:** 150-180 req/sec for sub-100ms response times.

## Troubleshooting

### High CPU on Bastion1

- **Cause:** HAProxy SSL + monitoring overhead
- **Solution:** Stop monitoring services before stress test (see above)

### Tests Fail with 400 Bad Request

- **Cause:** Client not configured or wrong credentials
- **Solution:** Verify client secret in Keycloak admin console

### Low Throughput

- **Cause:** Network latency or backend saturation
- **Solution:** Check backend CPU with `ansible postgres_cluster -i ../ansible/inventory/hosts -m shell -a "top -bn1"`

## References

- **Official Keycloak Benchmark:** https://github.com/keycloak/keycloak-benchmark
- **Documentation:** https://github.com/keycloak/keycloak-benchmark/tree/main/doc
