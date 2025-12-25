#!/bin/sh
set -e

# Set default values
SPA_DEFAULT_LOCALE="${SPA_DEFAULT_LOCALE:-am}"
SPA_PATH="${SPA_PATH:-/openmrs/spa}"

# Convert SPA_CONFIG_URLS (comma-separated) to JSON array
CONFIG_LIST=""
OLD_IFS="$IFS"
IFS=','
for url in $SPA_CONFIG_URLS; do
  CONFIG_LIST="${CONFIG_LIST}\"${url}\","
done
IFS="$OLD_IFS"

# Remove trailing comma and wrap in brackets
SPA_CONFIG_URLS_JSON="[${CONFIG_LIST%,}]"

# Export variables for envsubst
export IMPORTMAP_URL SPA_PATH API_URL SPA_DEFAULT_LOCALE SPA_CONFIG_URLS_JSON

# Log values for debugging
echo "DEBUG:"
echo "  SPA_PATH=${SPA_PATH}"
echo "  API_URL=${API_URL}"
echo "  IMPORTMAP_URL=${IMPORTMAP_URL}"
echo "  SPA_CONFIG_URLS=${SPA_CONFIG_URLS_JSON}"
echo "  SPA_DEFAULT_LOCALE=${SPA_DEFAULT_LOCALE}"

# Replace placeholders in index.html and service-worker.js
for file in /usr/share/nginx/html/openmrs/spa/index.html /usr/share/nginx/html/openmrs/spa/service-worker.js; do
  if [ -f "$file" ]; then
    envsubst '${IMPORTMAP_URL} ${SPA_PATH} ${API_URL} ${SPA_CONFIG_URLS_JSON} ${SPA_DEFAULT_LOCALE}' < "$file" | sponge "$file"
  fi
done

# Copy favicon if it exists
FAVICON="/usr/share/nginx/html/openmrs/spa/config/assets/ethiopiaemr-package/favicon.ico"
if [ -f "$FAVICON" ]; then
  cp "$FAVICON" /usr/share/nginx/html/openmrs/spa/
fi

# Start nginx
exec nginx -g "daemon off;"