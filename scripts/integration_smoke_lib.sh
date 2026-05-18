#!/usr/bin/env bash

set -euo pipefail

WAREHOUSE_DB_CONTAINER="${WAREHOUSE_DB_CONTAINER:-warehouse-db}"
WAREHOUSECORE_CONTAINER="${WAREHOUSECORE_CONTAINER:-warehousecore}"
WAREHOUSE_DB_USER="${WAREHOUSE_DB_USER:-warehouse}"
WAREHOUSE_DB_NAME="${WAREHOUSE_DB_NAME:-warehousecore_dev}"
INTEGRATION_ENDPOINT="${INTEGRATION_ENDPOINT:-http://localhost:8081/api/v1/integrations/twenty/events}"

TEMP_KEY_NAME=""
RAW_API_KEY=""

json_string() {
  local json="$1"
  local key="$2"
  printf '%s' "$json" | sed -n "s/.*\"${key}\":\"\([^\"]*\)\".*/\1/p"
}

post_event() {
  local payload="$1"
  local response
  response=$(curl -sS -w "\n%{http_code}" -X POST "$INTEGRATION_ENDPOINT" \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $RAW_API_KEY" \
    -d "$payload")

  POST_CODE="${response##*$'\n'}"
  POST_BODY="${response%$'\n'*}"
}

assert_applied_reason() {
  local expected_reason="$1"
  local status reason

  status=$(json_string "$POST_BODY" "status")
  reason=$(json_string "$POST_BODY" "reason")

  if [[ "$POST_CODE" != "202" ]]; then
    echo "Expected HTTP 202 but got $POST_CODE"
    echo "Response: $POST_BODY"
    return 1
  fi

  if [[ "$status" != "applied" ]]; then
    echo "Expected status=applied but got status=$status"
    echo "Response: $POST_BODY"
    return 1
  fi

  if [[ "$reason" != "$expected_reason" ]]; then
    echo "Expected reason=$expected_reason but got reason=$reason"
    echo "Response: $POST_BODY"
    return 1
  fi
}

random_suffix() {
  printf '%s' "$(date +%s)-$$"
}

cleanup_temp_admin_key() {
  if [[ -n "$TEMP_KEY_NAME" ]]; then
    docker exec "$WAREHOUSE_DB_CONTAINER" psql -U "$WAREHOUSE_DB_USER" -d "$WAREHOUSE_DB_NAME" -c \
      "DELETE FROM api_keys WHERE name = '$TEMP_KEY_NAME';" >/dev/null
  fi
}

setup_temp_admin_key() {
  local suffix pepper key_hash
  suffix=$(random_suffix)
  TEMP_KEY_NAME="temp-smoke-admin-${suffix}"
  RAW_API_KEY="temp-admin-sync-test-key-${suffix}"

  pepper=$(docker exec "$WAREHOUSECORE_CONTAINER" sh -lc 'printf "%s" "${API_KEY_PEPPER:-warehousecore-default-api-key-pepper}"')
  key_hash=$(printf '%s' "$RAW_API_KEY" | openssl dgst -sha256 -hmac "$pepper" | awk '{print $2}')

  docker exec "$WAREHOUSE_DB_CONTAINER" psql -U "$WAREHOUSE_DB_USER" -d "$WAREHOUSE_DB_NAME" -c \
    "SELECT setval('api_keys_id_seq', (SELECT COALESCE(MAX(id), 0) + 1 FROM api_keys), false);" >/dev/null

  docker exec "$WAREHOUSE_DB_CONTAINER" psql -U "$WAREHOUSE_DB_USER" -d "$WAREHOUSE_DB_NAME" -c \
    "INSERT INTO api_keys (name, api_key_hash, is_active, is_admin) VALUES ('$TEMP_KEY_NAME', '$key_hash', TRUE, TRUE);" >/dev/null

  trap cleanup_temp_admin_key EXIT
}

create_customer_and_get_id() {
  local suffix payload customer_id
  suffix=$(random_suffix)
  payload=$(cat <<JSON
{"eventId":"evt-customer-${suffix}","schemaVersion":1,"source":"twenty","entityType":"customer","action":"upsert","occurredAt":"2026-01-01T00:00:00Z","correlationId":"corr-customer-${suffix}","idempotencyKey":"idem-customer-${suffix}","entity":{"externalId":"twenty-customer-${suffix}","warehouseId":null,"version":1,"fields":{"name":"Smoke Customer ${suffix}","email":"smoke-customer-${suffix}@example.com","phone":"+49123456789"}}}
JSON
)
  post_event "$payload"
  if ! assert_applied_reason "customer_upserted"; then
    return 1
  fi
  customer_id=$(json_string "$POST_BODY" "warehouseId")
  printf '%s' "$customer_id"
}
