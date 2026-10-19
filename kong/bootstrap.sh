#!/usr/bin/env sh
# bootstrap.sh — configure Kong via the Admin API for the JWT auth scaffold.
#
# Idempotent: re-running is safe. Creates that already exist return HTTP 409,
# which we tolerate so `docker compose up` can be repeated without error.
#
# Flow configured here:
#   - Service auth-service  (http://auth-service:3000) + Route /auth  (no auth)
#   - Service protected     (http://httpbin:8080)      + Route /api   (jwt + rate-limiting)
#   - Consumer app-users with an RS256 jwt credential (key=auth-service)
#
# The JWT `iss` claim issued by the auth service MUST equal the credential `key`
# (both 'auth-service'); Kong looks up the public key by that iss.
set -eu

ADMIN="http://kong:8001"
PUBKEY="/keys/jwtRS256.key.pub"

echo "bootstrap: waiting for Kong Admin API at ${ADMIN} ..."
until curl -sf "${ADMIN}/status" >/dev/null 2>&1; do
  sleep 2
done
echo "bootstrap: Kong Admin API is up."

# ok2xx_or_409 PRINT_LABEL curl-args...
# Runs a curl call, succeeds on 2xx and on 409 (already exists), fails otherwise.
req() {
  label="$1"; shift
  status="$(curl -s -o /dev/null -w '%{http_code}' "$@")"
  case "${status}" in
    2*)   echo "bootstrap: ${label} -> ${status} (ok)";;
    409)  echo "bootstrap: ${label} -> 409 (already exists, ok)";;
    *)    echo "bootstrap: ${label} -> ${status} (FAILED)"; return 1;;
  esac
}

# --- Public (auth) service + route: /auth, no auth plugin ---
req "service auth-service" -X POST "${ADMIN}/services" \
  --data name=auth-service \
  --data url=http://auth-service:3000

# strip_path=false so /auth/login reaches the upstream unchanged.
req "route auth-route" -X POST "${ADMIN}/services/auth-service/routes" \
  --data name=auth-route \
  --data paths=/auth \
  --data strip_path=false

# --- Protected service + route: /api, jwt + rate-limiting ---
req "service protected" -X POST "${ADMIN}/services" \
  --data name=protected \
  --data url=http://httpbin:8080

req "route api-route" -X POST "${ADMIN}/services/protected/routes" \
  --data name=api-route \
  --data paths=/api

req "plugin jwt on api-route" -X POST "${ADMIN}/routes/api-route/plugins" \
  --data name=jwt

req "plugin rate-limiting on api-route" -X POST "${ADMIN}/routes/api-route/plugins" \
  --data name=rate-limiting \
  --data config.minute=5 \
  --data config.policy=local

# --- Consumer + RS256 jwt credential ---
req "consumer app-users" -X POST "${ADMIN}/consumers" \
  --data username=app-users

# rsa_public_key posted as the real PEM with literal newlines via --data-urlencode
# reading the file directly (@path). Do NOT inline a single-line \n string.
req "jwt credential app-users" -X POST "${ADMIN}/consumers/app-users/jwt" \
  --data key=auth-service \
  --data algorithm=RS256 \
  --data-urlencode "rsa_public_key@${PUBKEY}"

echo "bootstrap: Kong configuration complete."
