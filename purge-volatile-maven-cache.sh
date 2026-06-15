#!/usr/bin/env sh
set -eu

M2_REPO="${M2_REPO:-${HOME}/.m2/repository}"

# SNAPSHOT artifacts from distro/pom.xml that must be re-resolved on every build.
for artifact_path in \
  org/ethiopiaemr/content/ethiopiaemr-package \
  org/openmrs/module/ethiopiaemr-custom-module-omod \
  org/openmrs/module/kenyaemr.cashier-omod
do
  target="${M2_REPO}/${artifact_path}"
  if [ -d "$target" ]; then
    rm -rf "$target"
    echo "Purged volatile Maven cache: $target"
  fi
done
