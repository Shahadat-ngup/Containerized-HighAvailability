#!/bin/bash
# Verify Keycloak Synchronization via Ansible executing on backend1

echo -n "Enter Keycloak Admin Password: "
read -s ADMIN_PASSWORD
echo ""

echo -n "Enter the Client ID you manually created in the UI: "
read CLIENT_ID

cat << 'INNER_EOF' > /tmp/sync-check.sh
#!/bin/bash
ADMIN_PW="$1"
CLIENTID="$2"

echo -e "\n1. Getting Admin Token from backend1 (172.29.65.52)..."
TOKEN=$(curl -s -m 10 -d "client_id=admin-cli" \
     -d "username=admin" \
     -d "password=${ADMIN_PW}" \
     -d "grant_type=password" \
     -X POST http://172.29.65.52:8080/realms/master/protocol/openid-connect/token | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo "❌ Failed to get token. Incorrect password or backend1 is unreachable."
    exit 1
fi
echo "✅ Token acquired!"

echo -e "\n2. Verifying Client '$CLIENTID' across all backend nodes..."
for i in 1 2 3; do
    IP="172.29.65.5$((i+1))"
    echo -n "Checking backend$i ($IP)... "
    RESULT=$(curl -s -m 10 -H "Authorization: Bearer $TOKEN" "http://$IP:8080/admin/realms/master/clients?clientId=${CLIENTID}")
    
    if echo "$RESULT" | grep -q "\"clientId\":\"$CLIENTID\""; then
        echo "✅ FOUND (Synchronized)"
    else
        echo "❌ NOT FOUND (Or API error)"
    fi
done

echo -e "\n✅ If all nodes show 'FOUND', the split-brain issue is fully resolved!"
INNER_EOF

# Copy the script to backend1 and run it
export ANSIBLE_DEPRECATION_WARNINGS=False
export ANSIBLE_HOST_KEY_CHECKING=False

ansible backend1 -i ansible/inventory/hosts -m copy -a "src=/tmp/sync-check.sh dest=/tmp/sync-check.sh mode=0755" >/dev/null 2>&1

echo -e "\n--- Test Results ---"
ansible backend1 -i ansible/inventory/hosts -m shell -a "/tmp/sync-check.sh '${ADMIN_PASSWORD}' '${CLIENT_ID}'" | grep -v 'rc=0 >>' | grep -v 'CHANGED' | grep -v 'world writable' | grep -v 'ansible.cfg'

