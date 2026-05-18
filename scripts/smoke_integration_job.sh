#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/integration_smoke_lib.sh"

echo "Running job integration smoke test against $INTEGRATION_ENDPOINT"
setup_temp_admin_key

suffix=$(random_suffix)

job_payload=$(cat <<JSON
{"eventId":"evt-job-${suffix}","schemaVersion":1,"source":"twenty","entityType":"job","action":"upsert","occurredAt":"2026-01-01T00:00:00Z","correlationId":"corr-job-${suffix}","idempotencyKey":"idem-job-${suffix}","entity":{"externalId":"twenty-job-${suffix}","warehouseId":null,"version":1,"fields":{"name":"Smoke Job ${suffix}","jobCode":"SMOKE-${suffix}","status":"open","description":"Job smoke payload"}}}
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

echo "OK job payload applied with warehouseId=$job_id"
