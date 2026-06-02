#!/bin/sh
# Adds an "ETL Administration" tile to the KenyaEMR app-menu (the @kenyaemr/esm-patient-flags-app
# "Search for a module" overlay) and repoints the "Reports" tile to the EthiopiaEMR reports page.
#
# The menu is a hardcoded array baked into the patient-flags bundle, consumed from npm, so it
# cannot be extended via OpenMRS config. This script patches the built bundle in place.
#
# Runs in the dev build stage against /app/spa (same convention as rename-packages.sh).
# Idempotent: re-running is a no-op once the bundle already contains the ETL tile.

set -e

SPA_DIR="${1:-/app/spa}"

ETL_URL="/openmrs/ethiopiaemretl/etl/sync.page"
REPORTS_URL_OLD="/openmrs/kenyaemr/reports/reportsHome.page"
REPORTS_URL_NEW="/openmrs/spa/reports"

# The Reports entry is the anchor we splice around. It is emitted minified as a single object
# literal. We locate it by its url and insert an ETL tile before it, then repoint Reports.
ANCHOR="url:\"${REPORTS_URL_OLD}\""

patched=0
# busybox grep (Alpine) does not support --include; discover .js files with find instead.
for f in $(find "$SPA_DIR" -name "*.js" -type f -exec grep -l "$ANCHOR" {} + 2>/dev/null); do
  if grep -q "ETL Administration" "$f" 2>/dev/null; then
    echo "patch-app-menu: $f already patched, skipping"
    patched=1
    continue
  fi

  # Pick an icon ref that exists in this exact entry's createElement call (e.g. q.yG) so the
  # injected ETL tile reuses a real, imported icon binding rather than a guessed one.
  ICON_REF=$(sed -n "s/.*\"reports\",\"Reports\")[^}]*icon:o()\.createElement(\([A-Za-z_$][A-Za-z0-9_$]*\.[A-Za-z0-9_$]*\),{size:24}).*/\1/p" "$f" | head -n 1)
  if [ -z "$ICON_REF" ]; then
    echo "patch-app-menu: WARNING could not resolve icon ref in $f, falling back to no icon"
    ETL_TILE="{label:e(\"etlAdmin\",\"ETL Administration\"),url:\"${ETL_URL}\"},"
  else
    ETL_TILE="{label:e(\"etlAdmin\",\"ETL Administration\"),url:\"${ETL_URL}\",icon:o().createElement(${ICON_REF},{size:24})},"
  fi

  # 1) Insert the ETL tile immediately before the Reports tile object.
  #    The Reports tile object starts at: {label:e("reports","Reports")
  # 2) Repoint the Reports url to the EthiopiaEMR reports page.
  sed -i \
    -e "s#{label:e(\"reports\",\"Reports\")#${ETL_TILE}{label:e(\"reports\",\"Reports\")#" \
    -e "s#${REPORTS_URL_OLD}#${REPORTS_URL_NEW}#g" \
    "$f"

  if grep -q "ETL Administration" "$f" && grep -q "$REPORTS_URL_NEW" "$f"; then
    echo "patch-app-menu: patched $f (added ETL Administration, repointed Reports)"
    patched=1
  else
    echo "patch-app-menu: ERROR patch verification failed for $f"
    exit 1
  fi
done

if [ "$patched" -eq 0 ]; then
  # The anchor is consumed by the repoint step, so on an already-patched tree no file matches
  # the anchor anymore. Treat an existing ETL tile as success rather than a missing-menu warning.
  if find "$SPA_DIR" -name "*.js" -type f -exec grep -l "ETL Administration" {} + >/dev/null 2>&1; then
    echo "patch-app-menu: bundle already patched (ETL Administration tile present)."
  else
    echo "patch-app-menu: WARNING no patient-flags bundle containing the Reports anchor was found."
    echo "patch-app-menu: the @kenyaemr/esm-patient-flags-app menu may have changed; review this script."
  fi
fi
