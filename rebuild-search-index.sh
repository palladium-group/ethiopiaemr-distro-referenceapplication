#!/bin/sh
set -e
# =============================================================================
# rebuild-search-index.sh (Kubernetes-Optimized)
#
# Always triggers a full OpenMRS search index rebuild when the backend pod
# starts. Designed for Kubernetes rolling deployments.
#
# Safe because:
# - Reindex is idempotent
# - Runs once per pod start
# - Waits until backend is fully ready
# =============================================================================
# --- Configuration -----------------------------------------------------------
OMRS_URL="${OMRS_BASE_URL:-http://backend:8080/openmrs}"

# FIX: Use dedicated OpenMRS web user credentials, NOT the database credentials.
# The REST API authenticates against the OpenMRS user store, not MySQL.
OMRS_USER="${OMRS_ADMIN_USER:-admin}"
OMRS_PASS="${OMRS_ADMIN_PASSWORD:-Admin123}"

RETRY_INTERVAL=15
MAX_RETRIES=100   # ~25 minutes
# --- Helpers -----------------------------------------------------------------
log()  { echo "[search-index-init] $*"; }
fail() { echo "[search-index-init] ERROR: $*" >&2; exit 1; }

wait_for_backend() {
  log "Waiting for OpenMRS at $OMRS_URL ..."
  ATTEMPT=0
  until curl -sf \
    --max-time 10 \
    -u "$OMRS_USER:$OMRS_PASS" \
    "$OMRS_URL/ws/rest/v1/info" > /dev/null 2>&1; do
    ATTEMPT=$((ATTEMPT + 1))
    if [ "$ATTEMPT" -ge "$MAX_RETRIES" ]; then
      fail "Backend did not become ready after $MAX_RETRIES attempts."
    fi
    log "  Backend not ready yet (attempt $ATTEMPT/$MAX_RETRIES). Retrying in ${RETRY_INTERVAL}s..."
    sleep "$RETRY_INTERVAL"
  done
  log "Backend is ready."
}

trigger_search_index_rebuild() {
  log "Triggering search index rebuild..."
  HTTP_STATUS=$(curl -s -o /tmp/omrs_response.txt -w "%{http_code}" \
    -X POST \
    --max-time 60 \
    -u "$OMRS_USER:$OMRS_PASS" \
    -H "Content-Type: application/json" \
    "$OMRS_URL/ws/rest/v1/searchindexupdate" \
    -d '{}')

  RESPONSE_BODY=$(cat /tmp/omrs_response.txt)
  log "HTTP status : $HTTP_STATUS"
  log "Response    : $RESPONSE_BODY"

  case "$HTTP_STATUS" in
    2*)
      log "Search index rebuild triggered successfully."
      ;;
    401|403)
      fail "Authentication failed. Check OMRS_ADMIN_USER / OMRS_ADMIN_PASSWORD."
      ;;
    404)
      fail "Search index endpoint not found. Verify OpenMRS version."
      ;;
    *)
      fail "Unexpected HTTP status $HTTP_STATUS. Response: $RESPONSE_BODY"
      ;;
  esac
}
# --- Main --------------------------------------------------------------------
log "============================================================"
log "  OpenMRS Search Index Init (K8s Mode)"
log "  Backend URL : $OMRS_URL"
log "  Auth User   : $OMRS_USER"
log "============================================================"
wait_for_backend
trigger_search_index_rebuild
log "Done."