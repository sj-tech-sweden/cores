#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/integration_smoke_lib.sh"

echo "Running customer integration smoke test against $INTEGRATION_ENDPOINT"
setup_temp_admin_key

customer_id=$(create_customer_and_get_id)

echo "OK customer payload applied with warehouseId=$customer_id"
