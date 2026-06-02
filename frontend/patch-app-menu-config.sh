#!/bin/sh
# Removes "Reports" from the @kenyaemr/esm-patient-flags-app excludeLinks array so the Reports
# tile (repointed to EthiopiaEMR by patch-app-menu.sh) is not filtered out of the app menu.
#
# kenyaemr.config.json is produced by the backend distro build and copied into the image from
# spa-configs, so it is not available at dev-build time. This runs in the runtime stage against
# the deployed config locations.
#
# Idempotent: removing an absent value is a no-op.

set -e

# kenyaemr.config.json is copied to several locations by the Dockerfile; patch every copy.
for cfg in $(find /usr/share/nginx/html -name "kenyaemr.config.json" 2>/dev/null); do
  if grep -q '"Reports"' "$cfg" 2>/dev/null; then
    # Remove the "Reports" entry from the excludeLinks array, handling it whether it is
    # followed by a comma (mid-array) or preceded by one (end-of-array).
    sed -i \
      -e 's/"Reports", *//g' \
      -e 's/, *"Reports"//g' \
      "$cfg"
    echo "patch-app-menu-config: removed Reports from excludeLinks in $cfg"
  else
    echo "patch-app-menu-config: $cfg has no Reports in excludeLinks, skipping"
  fi
done
