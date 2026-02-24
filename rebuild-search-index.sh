#!/bin/sh
set -e

# =============================================================================
# rebuild-search-index.sh
#
# Detects if the backend Docker image has changed since the last run and
# triggers an OpenMRS search index rebuild if it has.
#
# Detection strategy: Combines IMAGE_TAG + DEPLOY_ID (git SHA or timestamp)
# into a digest, stores it in the persistent openmrs-data volume, and compares
# on every run. If the digest has changed or no previous record exists, the
# search index is rebuilt.
# =============================================================================

# --- Configuration -----------------------------------------------------------

OMRS_URL="${OMRS_BASE_URL:-http://backend:8080/openmrs}"
OMRS_USER="${OMRS_DB_USER:-openmrs}"
OMRS_PASS="${OMRS_DB_PASSWORD:-openmrs}"

# IMAGE_TAG comes from the TAG variable used in docker-compose (e.g. qa, v1.2.0)
IMAGE_TAG="${TAG:-qa}"

# DEPLOY_ID should be a git commit SHA or build timestamp injected at build/deploy
# time. This catches cases where the image is rebuilt with the same tag.
# Falls back to IMAGE_TAG alone if not provided (less precise).
DEPLOY_ID="${DEPLOY_ID:-none}"

# File stored in the openmrs-data volume to persist the last known digest
DIGEST_STORE="/openmrs/data/.last-image-digest"

# How long to wait between readiness retries (seconds)
RETRY_INTERVAL=15

# Maximum number of readiness retries before giving up (~25 mins total)
MAX_RETRIES=100

# --- Helpers -----------------------------------------------------------------

log()  { echo "[search-index-init] $*"; }
warn() { echo "[search-index-init] WARNING: $*" >&2; }
fail() { echo "[search-index-init] ERROR: $*" >&2; exit 1; }

# Compute a digest string representing the current image version
compute_digest() {
  echo "${IMAGE_TAG}::${DEPLOY_ID}"
}

# Read the previously stored digest; returns empty string if not found
read_stored_digest() {
  if [ -f "$DIGEST_STORE" ]; then
    cat "$DIGEST_STORE"
  else
    echo ""
  fi
}

# Persist the current digest to the volume
write_digest() {
  # Ensure the directory exists (it should, being a named volume mount)
  mkdir -p "$(dirname "$DIGEST_STORE")"
  echo "$1" > "$DIGEST_STORE"
  log "Digest saved: $1"
}

# Returns 0 (true) if the image has changed since the last run
image_has_changed() {
  CURRENT="$(compute_digest)"
  PREVIOUS="$(read_stored_digest)"

  log "Current image digest  : $CURRENT"
  log "Previously stored digest: ${PREVIOUS:-<none — first run>}"

  if [ "$CURRENT" != "$PREVIOUS" ]; then
    return 0   # changed
  else
    return 1   # unchanged
  fi
}

# Poll OpenMRS until it responds or we hit MAX_RETRIES
wait_for_backend() {
  log "Waiting for OpenMRS at $OMRS_URL ..."
  ATTEMPT=0

  until curl -sf \
        --max-time 10 \
        -u "$OMRS_USER:$OMRS_PASS" \
        "$OMRS_URL/ws/rest/v1/info" > /dev/null 2>&1; do

    ATTEMPT=$((ATTEMPT + 1))

    if [ "$ATTEMPT" -ge "$MAX_RETRIES" ]; then
      fail "Backend did not become ready after $MAX_RETRIES attempts. Giving up."
    fi

    log "  Backend not ready yet (attempt $ATTEMPT/$MAX_RETRIES). Retrying in ${RETRY_INTERVAL}s..."
    sleep "$RETRY_INTERVAL"
  done

  log "Backend is ready."
}

# Call the OpenMRS REST API to trigger a full search index rebuild
trigger_search_index_rebuild() {
  log "Triggering search index rebuild..."

  HTTP_STATUS=$(curl -s -o /tmp/omrs_response.txt -w "%{http_code}" \
    -X POST \
    --max-time 30 \
    -u "$OMRS_USER:$OMRS_PASS" \
    -H "Content-Type: application/json" \
    "$OMRS_URL/ws/rest/v1/searchindexupdate" \
    -d '{}')

  RESPONSE_BODY=$(cat /tmp/omrs_response.txt)

  log "HTTP status : $HTTP_STATUS"
  log "Response    : $RESPONSE_BODY"

  # 2xx = success
  case "$HTTP_STATUS" in
    2*)
      log "Search index rebuild triggered successfully."
      ;;
    401|403)
      fail "Authentication failed (HTTP $HTTP_STATUS). Check OMRS_DB_USER and OMRS_DB_PASSWORD."
      ;;
    404)
      fail "Search index endpoint not found (HTTP 404). Verify the OpenMRS version supports /ws/rest/v1/searchindexupdate."
      ;;
    *)
      fail "Unexpected HTTP status $HTTP_STATUS. Response: $RESPONSE_BODY"
      ;;
  esac
}

# --- Main --------------------------------------------------------------------

log "============================================================"
log "  OpenMRS Search Index Init"
log "  Image tag  : $IMAGE_TAG"
log "  Deploy ID  : $DEPLOY_ID"
log "  Backend URL: $OMRS_URL"
log "============================================================"

# Step 1: Detect whether the image has changed
if image_has_changed; then
  log "Image change detected. Proceeding with search index rebuild."

  # Step 2: Wait for the backend to be fully ready
  wait_for_backend

  # Step 3: Rebuild the search index
  trigger_search_index_rebuild

  # Step 4: Persist the new digest so the next run can compare against it
  write_digest "$(compute_digest)"

  log "Done."
else
  log "Image has not changed. Skipping search index rebuild."
fi