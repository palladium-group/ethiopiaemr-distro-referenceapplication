#!/bin/sh
set -e

# 1. Force Export
export SPA_PATH=${SPA_PATH:-/openmrs/spa}
export API_URL=${API_URL:-/openmrs}
export SPA_DEFAULT_LOCALE=${SPA_DEFAULT_LOCALE:-en_GB}
export SPA_PAGE_TITLE=${SPA_PAGE_TITLE:-"Taifa Care - KenyaEMR"}

TARGET_DIR="/usr/share/nginx/html/openmrs/spa"
TARGET_INDEX="$TARGET_DIR/index.html"

# 2. Fix the Base Path in the HTML files
# This replaces any raw "importmap.json" or "routes.registry.json" 
# with the full path including /openmrs/spa/
if [ -f "$TARGET_INDEX" ]; then
  echo "Fixing paths in $TARGET_INDEX"
  sed -i "s|importmap.json|${SPA_PATH}/importmap.json|g" "$TARGET_INDEX"
  sed -i "s|routes.registry.json|${SPA_PATH}/routes.registry.json|g" "$TARGET_INDEX"
  
  # Run envsubst
  envsubst '${IMPORTMAP_URL} ${SPA_PATH} ${API_URL} ${SPA_CONFIG_URLS} ${SPA_DEFAULT_LOCALE} ${SPA_PAGE_TITLE}' < "$TARGET_INDEX" | sponge "$TARGET_INDEX"
  
  # Copy to root so the initial load works
  cp "$TARGET_INDEX" /usr/share/nginx/html/index.html
fi

# 3. Handle JavaScript/CSS files that might have $SPA_PATH
# This fixes the PNG and JS/CSS 404s
find "$TARGET_DIR" -type f -name "*.js" -o -name "*.json" -o -name "*.css" | xargs -I {} sh -c "envsubst '\${SPA_PATH}' < {} | sponge {}"

echo "Starting Nginx..."
exec nginx -g "daemon off;"