#!/usr/bin/env bash
# Demo script: login -> call protected endpoint with Authorization -> logout -> check Redis blacklist
# Usage: ./scripts/demo_jwt_redis.sh

set -euo pipefail

API_BASE="http://localhost:8080"
USER_JSON='{"username":"user1","password":"pass1"}'

echo "1) Logging in..."
LOGIN_RESP=$(curl -s -X POST "$API_BASE/api/users/login" -H 'Content-Type: application/json' -d "$USER_JSON")
echo "Login response: $LOGIN_RESP" | jq . 2>/dev/null || true

TOKEN=$(echo "$LOGIN_RESP" | jq -r .token)
if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "No token returned. Aborting. Check server logs and credentials." >&2
  exit 1
fi

echo
echo "2) Call protected endpoint /api/records with Authorization header"
curl -s "$API_BASE/api/records" -H "Authorization: Bearer $TOKEN" | jq . 2>/dev/null || true

echo
echo "3) Decode token payload to extract jti and exp"
python3 - <<PY
import sys, json, base64
t = "$TOKEN"
try:
    p = t.split('.')[1]
    p += '=' * ((4 - len(p) % 4) % 4)
    payload = json.loads(base64.urlsafe_b64decode(p))
    print(json.dumps(payload, indent=2, ensure_ascii=False))
except Exception as e:
    print('Failed to decode token payload:', e)
    sys.exit(1)
PY

JTI=$(python3 - <<PY
import sys, json, base64
t = "$TOKEN"
p = t.split('.')[1]; p += '=' * ((4 - len(p) % 4) % 4)
payload = json.loads(base64.urlsafe_b64decode(p))
print(payload.get('jti',''))
PY
)

if [ -z "$JTI" ]; then
  echo "No jti found in token payload. Cannot check Redis blacklist key." >&2
else
  echo
  echo "4) Logging out (will blacklist token jti if server sets it)..."
  curl -s -X POST "$API_BASE/api/users/logout" -H "Authorization: Bearer $TOKEN" -o /dev/null

  echo "5) Checking Redis for blacklist key 'jwt:blacklist:$JTI'"
  if command -v docker >/dev/null 2>&1 && [ -f docker-compose.yml ]; then
    echo "Using docker compose to exec redis-cli"
    docker compose exec -T redis redis-cli GET "jwt:blacklist:$JTI" || true
    docker compose exec -T redis redis-cli TTL "jwt:blacklist:$JTI" || true
  else
    echo "Using local redis-cli (127.0.0.1:6379)"
    redis-cli GET "jwt:blacklist:$JTI" || true
    redis-cli TTL "jwt:blacklist:$JTI" || true
  fi
fi

echo
echo "Demo done. If you see a value '1' and TTL > 0 for the key, blacklist was created on logout."
