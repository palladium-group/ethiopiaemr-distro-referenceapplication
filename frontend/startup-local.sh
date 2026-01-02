#!/bin/sh
set -e

# Set default values
SPA_DEFAULT_LOCALE="${SPA_DEFAULT_LOCALE:-en}"
SPA_PATH="${SPA_PATH:-/openmrs/spa}"
SPA_PAGE_TITLE="${SPA_PAGE_TITLE:-EthiopiaEMR}"

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
# Also set SPA_CONFIG_URLS to JSON version for backward compatibility
SPA_CONFIG_URLS="${SPA_CONFIG_URLS_JSON}"

# Export variables for envsubst
export IMPORTMAP_URL SPA_PATH API_URL SPA_DEFAULT_LOCALE SPA_CONFIG_URLS_JSON SPA_CONFIG_URLS SPA_PAGE_TITLE

# Log values for debugging
echo "DEBUG:"
echo "  SPA_PATH=${SPA_PATH}"
echo "  API_URL=${API_URL}"
echo "  IMPORTMAP_URL=${IMPORTMAP_URL}"
echo "  SPA_CONFIG_URLS=${SPA_CONFIG_URLS_JSON}"
echo "  SPA_DEFAULT_LOCALE=${SPA_DEFAULT_LOCALE}"
echo "  SPA_PAGE_TITLE=${SPA_PAGE_TITLE}"

# Replace placeholders in index.html and service-worker.js
for file in /usr/share/nginx/html/index.html /usr/share/nginx/html/service-worker.js; do
  if [ -f "$file" ]; then
    # First do envsubst replacement
    envsubst '${IMPORTMAP_URL} ${SPA_PATH} ${API_URL} ${SPA_CONFIG_URLS_JSON} ${SPA_CONFIG_URLS} ${SPA_DEFAULT_LOCALE} ${SPA_PAGE_TITLE}' < "$file" | \
    # Fix nested array issue: replace configUrls: ["["url1","url2"]"] with configUrls: ["url1","url2"]
    sed 's|configUrls: \["\[|configUrls: \[|g' | \
    sed 's|"\]"\]|"\]|g' | \
    sponge "$file"
  fi
done

# Copy favicon if it exists
FAVICON="/usr/share/nginx/html/config/assets/ethiopiaemr-package/favicon.ico"
if [ -f "$FAVICON" ]; then
  cp "$FAVICON" /usr/share/nginx/html/
fi

exec nginx -g "daemon off;"