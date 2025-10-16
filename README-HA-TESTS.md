# High Availability Validation & Failure Test Guide

Comprehensive, repeatable test scenarios to validate the HA posture of the Keycloak + Patroni (PostgreSQL) + etcd + Nginx + Monitoring stack.

---

## 1. Scope & Principles

These tests cover:

- Control plane quorum (etcd, Patroni leadership)
- Data plane continuity (PostgreSQL leader failover, replication health)
- Identity service resilience (Keycloak cluster continuity & session behavior)
- Edge / access layer failover (Nginx on bastions + VIP / DNS)
- Observability integrity (Prometheus & Grafana during failures)

General principles:

- Run destructive tests in a staging environment first.
- Only one major failure injection at a time unless explicitly stated.
- Record timestamps (UTC) to correlate with monitoring & logs.
- After each test, perform a recovery verification section.

---

## 2. Reference Inventory & Groups

See `ansible/inventory/hosts` (bastion1/2, backend1/2/3). Commands below assume execution from the repo root within WSL using Ansible ad‑hoc shell tasks.

Shortcut environment:

```bash
INV=ansible/inventory/hosts
ANS_BASE="ansible -i $INV --become"
```

### 2.1 Remote Utility Prerequisites

Some commands rely on `jq` and optionally `watch`. Install them once on targets (Debian/Ubuntu hosts):

```bash
ansible postgres_cluster -i $INV --become -m apt -a "name=jq,watch state=present update_cache=yes"
ansible bastion          -i $INV --become -m apt -a "name=jq,watch state=present update_cache=yes"
```

If you cannot install `jq`, use the provided "no jq" fallback commands (they print raw JSON). If `watch` is absent, run the inner command in a loop manually.

---

## 3. Pre‑Test Baseline Checklist

INV=ansible/inventory/hosts
ansible postgres_cluster -i $INV --become -m apt -a "name=jq,watch state=present update_cache=yes"
ansible bastion -i $INV --become -m apt -a "name=jq,watch state=present update_cache=yes"

Run before any failure injection:

```bash
# 3.1 Cluster process presence
# Escape Go template braces so Ansible Jinja parser doesn't treat them:
$ANS_BASE bastion   -m shell -a "docker ps --format '{% raw %}{{.Names}}{% endraw %}'"
$ANS_BASE postgres_cluster -m shell -a "docker ps --format '{% raw %}{{.Names}}{% endraw %}'"

# 3.2 Patroni cluster state (leader + replicas)
$ANS_BASE postgres_cluster -m shell -a "curl -s http://127.0.0.1:8008/cluster | jq '.members[] | {name,role,api_url}'"
# Fallback (no jq):
# $ANS_BASE postgres_cluster -m shell -a "curl -s http://127.0.0.1:8008/cluster"

# 3.3 etcd member list
ansible backend1 -i ansible/inventory/hosts --become -m shell -a \
"docker exec -e ETCDCTL_API=3 etcd-backend1 etcdctl member list"


# 3.5 HTTP external login page reachability (via bastions / DNS)
curl -sk -o /dev/null -w "%{http_code}\n" https://keycloak.ipb.pt/realms/master/.well-known/openid-configuration

# 3.6 Prometheus target health
$ANS_BASE bastion -m shell -a "curl -s 'http://127.0.0.1:9091/api/v1/targets' | jq '.data.activeTargets[] | select(.labels.job==\"keycloak\") | {instance, health}'"
# Fallback (no jq – crude filter):
# $ANS_BASE bastion -m shell -a "curl -s 'http://127.0.0.1:9091/api/v1/targets' | grep -A3 keycloak"

# 3.7 Capture baseline metrics (optional archive)
$ANS_BASE postgres_cluster -m shell -a "curl -s http://127.0.0.1:9000/metrics | wc -l"  # lines per node
```

Confirm: All Keycloak nodes healthy, one Patroni leader, etcd members all available.

---

## 4. Test Scenarios

Each scenario lists: Goal → Injection → Expected Outcome → Validation → Recovery.

### 4.1 PostgreSQL Leader Failure (Container Kill)

Goal: Patroni elects a new leader; Keycloak continues issuing tokens.

Injection:

```bash
# Check keepalived version
ansible -i ansible/inventory/hosts postgres_cluster -m shell -a "/usr/sbin/keepalived --version"

# Check which node has the VIP (should follow Patroni leader automatically)
ansible -i ansible/inventory/hosts postgres_cluster -m shell -a "hostname -s && ip -4 -br addr show | grep -w 172.29.65.100 || echo 'NO_VIP'"

# Verify VIP follows leader - both should show the same node
echo "=== Patroni Leader ==="
$ANS_BASE postgres_cluster -m shell -a "curl -s http://127.0.0.1:8008/cluster | jq -r '.members[] | select(.role==\"leader\") | .name'"
echo "=== VIP Location ==="
#
ansible -i ansible/inventory/hosts postgres_cluster -m shell -a "hostname -s && ip -4 -br addr show | grep -w 172.29.65.100 || echo 'NO_VIP'"

# Identify leader
$ANS_BASE postgres_cluster -m shell -a "curl -s http://127.0.0.1:8008/cluster | jq -r '.members[] | select(.role==\"leader\") | .name'"
# Assume leader is patroni-1 (backend1). Kill container:
ansible backend1 -i $INV --become -m shell -a "docker stop patroni-backend1"
```

Expected: One of backend2/backend3 becomes new leader within ~15–30s.

Validation:

```bash
# Issue token repeatedly during failover window
for i in {1..20}; do curl -sk -d 'client_id=admin-cli' -d 'username=admin' -d 'password=Passw0rd21' -d 'grant_type=password' \
  https://keycloak.ipb.pt/realms/master/protocol/openid-connect/token -o /dev/null -w "%{http_code} "; sleep 2; done
```

Success Criteria:

- HTTP 200 continues ≥90% of attempts.
- New leader visible.

Recovery:

```bash
ansible backend1 -i $INV --become -m shell -a "docker start patroni-backend1"
```

Check it rejoins as replica.

### 4.2 Complete Loss of One Replica Backend (Node Level Simulated)

Goal: Cluster tolerates losing a non-leader backend host.

Injection (simulate by stopping all containers on backend2):

```bash
ansible backend2 -i $INV --become -m shell -a "docker stop $(docker ps -q) || true"
```

Expected: Patroni shows backend2 missing; etcd still quorum (3→2 ok). Keycloak load still served by remaining nodes.

Validation:

```bash
$ANS_BASE postgres_cluster -m shell -a "curl -s http://127.0.0.1:8008/cluster | jq '.members | length'" # should be 2 available
# Fallback (no jq): manually count objects under "members"
curl -sk https://keycloak.ipb.pt/realms/master/.well-known/openid-configuration -o /dev/null -w "%{http_code}\n"
```

Recovery:

```bash
ansible backend2 -i $INV --become -m shell -a "docker start etcd-backend2 patroni-backend2 keycloak-backend2"
```

### 4.3 etcd Member Failure

Goal: etcd quorum remains; Patroni & Keycloak unaffected.

Injection:

```bash
ansible backend3 -i $INV --become -m shell -a "docker stop etcd-backend3"
```

Expected: etcd cluster size reduces to 2; health still green; no Patroni failover.

Validation:

```bash
$ANS_BASE postgres_cluster -m shell -a "ETCDCTL_API=3 etcdctl --endpoints=127.0.0.1:2379 endpoint health" | grep -v unhealthy
```

Recovery:

```bash
ansible backend3 -i $INV --become -m shell -a "docker start etcd-backend3"
```

### 4.4 Keycloak Pod/Container Crash

Goal: Session continuity through remaining nodes.

Pre-step: Create a session by logging in (admin console & maybe a test realm user).

Injection:

```bash
ansible backend1 -i $INV --become -m shell -a "docker kill keycloak-backend1"
```

Expected: User can still obtain tokens (load hits backend2/3). Cluster re-forms; JGroups rebalancing visible in metrics.

Validation:

```bash
for i in {1..10}; do curl -sk -d 'client_id=admin-cli' -d 'username=admin' -d 'password=Passw0rd21' -d 'grant_type=password' \
  https://keycloak.ipb.pt/realms/master/protocol/openid-connect/token -o /dev/null -w "%{http_code} "; sleep 2; done
```

Recovery:

```bash
ansible backend1 -i $INV --become -m shell -a "docker start keycloak-backend1"
```

### 4.5 Simultaneous Loss of Two Keycloak Nodes (Stress)

Goal: Confirm at least one node can still serve auth; understand degraded state.

Injection:

```bash
ansible backend2 -i $INV --become -m shell -a "docker stop keycloak-backend2"
ansible backend3 -i $INV --become -m shell -a "docker stop keycloak-backend3"
```

Expected: Remaining node serves requests (no horizontal failover available). Latency may increase.

Validation: Same token loop; ensure mostly 200 responses.
Recovery: Start the two stopped containers.

### 4.6 Bastion Nginx Instance Loss

Goal: External availability through alternate bastion.

Injection:

```bash
ansible bastion1 -i $INV --become -m shell -a "docker stop nginx"
```

Expected: DNS or client resolves to bastion2 (if round-robin / health). If using VIP, ensure failover (Keepalived) moves VIP.

Validation:

```bash
curl -sk -o /dev/null -w "%{http_code}\n" https://keycloak.ipb.pt/realms/master/.well-known/openid-configuration
```

Recovery:

```bash
ansible bastion1 -i $INV --become -m shell -a "docker start nginx"
```

### 4.7 Prometheus Configuration Reload During Traffic

Goal: Ensure observability continuity.

Action:

```bash
ansible bastion -i $INV --become -m shell -a "docker kill -s HUP prometheus"
```

Expected: No data loss (Prometheus keeps TSDB); short scrape gap only.

Validation:
Query rate(http_server_requests_seconds_count[5m]) — no permanent zeroing.

### 4.8 Network Partition Simulation (App from DB)

(Advanced, optional — requires firewall rule manipulation. Not automated here to prevent accidental lockout.)
Goal: Observe Patroni failover or Keycloak degraded mode.

Outline:

1. On leader backend host: temporarily block port 5432 inbound from one Keycloak node.
2. Watch Keycloak error logs + metrics (increase in http_server_requests_seconds_count with 5xx?).
3. Remove rule & confirm recovery.

### 4.9 Data Integrity – Write/Read After Failover

Goal: Confirm writes replicated across failover.

Procedure:

1. Create a new realm or client via admin REST while leader up.
2. Kill leader (Scenario 4.1 pattern).
3. After failover, GET realm/client — resource still present.

Commands (example create realm):

```bash
TOKEN=$(curl -sk -d 'client_id=admin-cli' -d 'username=admin' -d 'password=Passw0rd21' -d 'grant_type=password' \
  https://keycloak.ipb.pt/realms/master/protocol/openid-connect/token | jq -r '.access_token')

curl -sk -X POST -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  https://keycloak.ipb.pt/admin/realms -d '{"realm":"ha-test","enabled":true}'
```

After leader failover:

```bash
curl -sk -H "Authorization: Bearer $TOKEN" https://keycloak.ipb.pt/admin/realms/ha-test | jq '.realm'
```

Success: returns "ha-test".

### 4.10 Session Stickiness & Rejoin

Goal: Confirm returning node syncs cluster caches.

Procedure:

1. Kill one Keycloak node (Scenario 4.4).
2. Perform multiple login/token operations.
3. Restart node; check vendor_statistics_current_number_of_entries_in_memory for sessions tuple on restarted node eventually matches peers.

Command snippet:

```bash
# After restart (give 30–60s)
$ANS_BASE backend1 -m shell -a "curl -s http://127.0.0.1:9000/metrics | grep vendor_statistics_current_number_of_entries_in_memory | grep sessions | head"
```

---

## 5. Metrics to Watch During Tests

| Aspect            | Metric / Query                                                          | Expectation                                |
| ----------------- | ----------------------------------------------------------------------- | ------------------------------------------ | -------------------------- |
| DB Leadership     | Patroni cluster JSON (`curl -s :8008/cluster`)                          | Single leader switch per induced failure   |
| HTTP Availability | `sum(rate(http_server_requests_seconds_count{status=~"5.."}[5m]))`      | Near zero except brief failover window     |
| Cache Replication | `vendor_statistics_current_number_of_entries_in_memory{cache=~"sessions | clientSessions"}`                          | Stable / grows with logins |
| JVM Pressure      | `jvm_memory_used_bytes / jvm_memory_max_bytes`                          | < 0.8                                      |
| Cluster Size      | Distinct `process_uptime_seconds{job="keycloak"}` instances             | Drops only when nodes intentionally killed |

---

## 6. Success Criteria Summary

A test pass if:

- No prolonged ( >30s ) total outage of Keycloak endpoints for single component failures.
- Patroni always elects a new leader inside 30s (tunable).
- No lost realm/client configuration after leader failover.
- Metrics continuity preserved (Prometheus shows continuous time series except brief scrape skips).

---

## 7. Post-Test Cleanup

Ensure all containers running:

```bash
$ANS_BASE bastion -m shell -a "docker ps --format '{{.Names}}' | sort"
$ANS_BASE postgres_cluster -m shell -a "docker ps --format '{{.Names}}' | sort"
```

Restart any missing ones with docker start.

Optional: Export Prometheus snapshot & archive logs for audit.

---

## 8. Automation Ideas (Future)

- Convert scenarios into an Ansible playbook with tags (ha_test_leader_fail, ha_test_keycloak_crash, etc.).
- Integrate a chaos tool (e.g., pumba) for randomized container kills.
- Add Grafana synthetic availability panel referencing success rate queries.

---

## 9. Safety Notes

- Avoid concurrent multi-failure tests unless you are validating disaster scenarios.
- Always confirm you are in a non-production environment.
- Re-validate backups before aggressive failover simulations.

---

## 10. Appendix: Quick Token Helper

```bash
get_admin_token() {
  curl -sk -d 'client_id=admin-cli' -d "username=$1" -d "password=$2" -d 'grant_type=password' \
    https://keycloak.ipb.pt/realms/master/protocol/openid-connect/token | jq -r '.access_token'
}
```

---

Ready to execute: Start at Section 3, proceed through scenarios in Section 4, logging timestamps + outcomes.
