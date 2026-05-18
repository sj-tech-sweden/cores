#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/integration_smoke_lib.sh"

echo "Running requirement integration smoke test against $INTEGRATION_ENDPOINT"
setup_temp_admin_key

suffix=$(random_suffix)

job_payload=$(cat <<JSON
{"eventId":"evt-job-for-req-${suffix}","schemaVersion":1,"source":"twenty","entityType":"job","action":"upsert","occurredAt":"2026-01-01T00:00:00Z","correlationId":"corr-job-for-req-${suffix}","idempotencyKey":"idem-job-for-req-${suffix}","entity":{"externalId":"twenty-job-for-req-${suffix}","warehouseId":null,"version":1,"fields":{"name":"Smoke Job For Requirement ${suffix}","jobCode":"SMOKE-REQ-${suffix}","status":"open","description":"Requirement smoke prerequisite"}}}
JSON
)

post_event "$job_payload"
assert_applied_reason "job_upserted"
job_id=$(json_string "$POST_BODY" "warehouseId")
if [[ -z "$job_id" ]]; then
  echo "Job warehouseId missing in response"
  echo "Response: $POST_BODY"
  exit 1
fi

product_id=$(docker exec "$WAREHOUSE_DB_CONTAINER" psql -U "$WAREHOUSE_DB_USER" -d "$WAREHOUSE_DB_NAME" -Atc "SELECT COALESCE(to_jsonb(p)->>'id', to_jsonb(p)->>'productid') FROM products p LIMIT 1;")
if [[ -z "$product_id" ]]; then
  echo "No product found in products table; requirement upsert smoke test needs at least one product"
  exit 1
fi

requirement_payload=$(cat <<JSON
{"eventId":"evt-req-${suffix}","schemaVersion":1,"source":"twenty","entityType":"requirement","action":"upsert","occurredAt":"2026-01-01T00:00:00Z","correlationId":"corr-req-${suffix}","idempotencyKey":"idem-req-${suffix}","entity":{"externalId":"twenty-requirement-${suffix}","warehouseId":"${job_id}","version":1,"fields":{"jobWarehouseId":"${job_id}","warehouseProductId":"${product_id}","quantity":"2"}}}
JSON
)

post_event "$requirement_payload"
assert_applied_reason "requirement_upserted"

echo "OK requirement payload applied for job=$job_id product=$product_id"
