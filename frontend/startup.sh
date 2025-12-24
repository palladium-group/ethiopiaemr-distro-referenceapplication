#!/bin/sh
set -e

# if we are using the $IMPORTMAP_URL environment variable, we have to make this useful,
# so we change "importmap.json" into "$IMPORTMAP_URL" allowing it to be changed by envsubst
SPA_PATH=${SPA_PATH:-/openmrs/spa}
SPA_CONTENT_DIR="/usr/share/nginx/html${SPA_PATH%/}"
SPA_INDEX="${SPA_CONTENT_DIR}/index.html"
SPA_SERVICE_WORKER="${SPA_CONTENT_DIR}/service-worker.js"

if [ -n "${IMPORTMAP_URL}" ]; then
  if [ -n "$SPA_PATH" ]; then
    [ -f "${SPA_INDEX}"  ] && \
      sed -i -e 's/\("|''\)$SPA_PATH\/importmap.json\("|''\)/\1$IMPORTMAP_URL\1/g' "${SPA_INDEX}"

    [ -f "${SPA_SERVICE_WORKER}" ] && \
      sed -i -e 's/\("|''\)$SPA_PATH\/importmap.json\("|''\)/\1$IMPORTMAP_URL\1/g' "${SPA_SERVICE_WORKER}"
  else
    [ -f "${SPA_INDEX}"  ] && \
      sed -i -e 's/\("|''\)importmap.json\("|''\)/\1$IMPORTMAP_URL\1/g' "${SPA_INDEX}"

    [ -f "${SPA_SERVICE_WORKER}" ] && \
      sed -i -e 's/\("|''\)importmap.json\("|''\)/\1$IMPORTMAP_URL\1/g' "${SPA_SERVICE_WORKER}"
  fi
fi

# setting the config urls to "" causes an error reported in the console, so if we aren't using
# the SPA_CONFIG_URLS, we remove it from the source, leaving config urls as []
if [ -z "$SPA_CONFIG_URLS" ]; then
  sed -i -e 's/"$SPA_CONFIG_URLS"//' "${SPA_INDEX}"
# otherwise convert the URLs into a Javascript list
# we support two formats, a comma-separated list or a space separated list
else
  old_IFS="$IFS"
  if echo "$SPA_CONFIG_URLS" | grep , >/dev/null; then
    IFS=","
  fi

  CONFIG_URLS=
  for url in $SPA_CONFIG_URLS;
  do
    if [ -z "$CONFIG_URLS" ]; then
      CONFIG_URLS="\"${url}\""
    else
      CONFIG_URLS="$CONFIG_URLS,\"${url}\""
    fi
  done

  IFS="$old_IFS"
  export SPA_CONFIG_URLS=$CONFIG_URLS
  sed -i -e 's/"$SPA_CONFIG_URLS"/$SPA_CONFIG_URLS/' "${SPA_INDEX}"
fi

SPA_DEFAULT_LOCALE=${SPA_DEFAULT_LOCALE:-en_GB}
SPA_PAGE_TITLE=${SPA_PAGE_TITLE:-"Taifa Care - KenyaEMR"}

# Substitute environment variables in the html file
# This allows us to override parts of the compiled file at runtime
if [ -f "${SPA_INDEX}" ]; then
  envsubst '${IMPORTMAP_URL} ${SPA_PATH} ${API_URL} ${SPA_CONFIG_URLS} ${SPA_DEFAULT_LOCALE} ${SPA_PAGE_TITLE}' < "${SPA_INDEX}" | sponge "${SPA_INDEX}"
fi

if [ -f "${SPA_SERVICE_WORKER}" ]; then
  envsubst '${IMPORTMAP_URL} ${SPA_PATH} ${API_URL}' < "${SPA_SERVICE_WORKER}" | sponge "${SPA_SERVICE_WORKER}"
fi

# Copy favicon.ico from assets to the html folder if it exists
if [ -f "/usr/share/nginx/html/config/assets/kenyahmis-package/favicon.ico" ]; then
  cp /usr/share/nginx/html/config/assets/kenyahmis-package/favicon.ico /usr/share/nginx/html/
fi

exec nginx -g "daemon off;"
