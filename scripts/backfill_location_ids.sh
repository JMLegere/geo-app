#!/bin/bash
# One-time backfill: enrich all cell_properties rows missing location_id.
# Calls enrich-locations-batch Edge Function in batches of 10.
#
# Usage: bash scripts/backfill_location_ids.sh
# Requires: supabase CLI linked, SUPABASE_URL + SUPABASE_ANON_KEY env vars

set -euo pipefail

SUPABASE_URL="${SUPABASE_URL:-https://bfaczcsrpfcbijoaeckb.supabase.co}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"

if [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "ERROR: SUPABASE_ANON_KEY not set"
  exit 1
fi

BATCH_SIZE=10
SLEEP_BETWEEN=2

echo "Fetching cells without location_id..."
CELLS_JSON=$(npx supabase db query --linked --output json "
  SELECT 
    cell_id,
    (SPLIT_PART(REPLACE(cell_id, 'v_', ''), '_', 1)::float + 0.5) * 0.002 as lat,
    (SPLIT_PART(REPLACE(cell_id, 'v_', ''), '_', 2)::float + 0.5) * 0.002 as lon
  FROM cell_properties 
  WHERE location_id IS NULL
  ORDER BY cell_id
")

TOTAL=$(echo "$CELLS_JSON" | jq length)
echo "Found $TOTAL cells without location_id"

OFFSET=0
ENRICHED=0

while [ $OFFSET -lt $TOTAL ]; do
  # Build batch payload
  BATCH=$(echo "$CELLS_JSON" | jq -c "[.[$OFFSET:$OFFSET+$BATCH_SIZE] | .[] | {cell_id, lat: (.lat | tonumber), lon: (.lon | tonumber)}]")
  BATCH_COUNT=$(echo "$BATCH" | jq length)
  
  echo "Batch $((OFFSET / BATCH_SIZE + 1)): enriching $BATCH_COUNT cells (offset=$OFFSET)..."
  
  PAYLOAD="{\"cells\": $BATCH}"
  
  RESPONSE=$(curl -s -X POST \
    "$SUPABASE_URL/functions/v1/enrich-locations-batch" \
    -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")
  
  # Count enriched
  BATCH_ENRICHED=$(echo "$RESPONSE" | jq '[.results[]? | select(.status == "enriched" or .status == "already_enriched")] | length' 2>/dev/null || echo "0")
  ENRICHED=$((ENRICHED + BATCH_ENRICHED))
  
  ERRORS=$(echo "$RESPONSE" | jq '.errors // [] | length' 2>/dev/null || echo "0")
  if [ "$ERRORS" -gt 0 ]; then
    echo "  ⚠ $ERRORS errors in batch"
    echo "$RESPONSE" | jq '.errors' 2>/dev/null
  fi
  
  echo "  ✓ $BATCH_ENRICHED enriched (total: $ENRICHED/$TOTAL)"
  
  OFFSET=$((OFFSET + BATCH_SIZE))
  
  if [ $OFFSET -lt $TOTAL ]; then
    sleep $SLEEP_BETWEEN
  fi
done

echo ""
echo "Done! Enriched $ENRICHED / $TOTAL cells"
