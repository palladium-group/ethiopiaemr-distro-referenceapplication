# syntax=docker/dockerfile:1

#--------------------------------------------
# Content Package Stage - Downloads and extracts ethiopiaemr-package
# Provides: assets (branding), configs (JSON), overrides (dist-*)
#--------------------------------------------
FROM --platform=$BUILDPLATFORM maven:3.9-eclipse-temurin-21-alpine AS content-package

WORKDIR /content
COPY frontend/content-package-pom.xml pom.xml

# Download and unpack the content-package from Mekom Nexus.
# Build fails if download fails — never ship an empty/unbranded image.
# RUN --mount=type=secret,id=m2settings,target=/root/.m2/settings.xml,required=false \
#     mvn -U -ntp dependency:unpack \
#         -Dartifact=io.github.abdi-icap:ethiopiaemr-package:1.0.8:zip \
#         -DoutputDirectory=/content/extracted

RUN mvn -U -ntp dependency:unpack \
    -Dartifact=io.github.abdi-icap:ethiopiaemr-package:1.0.8:zip \
    -DoutputDirectory=/content/extracted || \
    (echo "ERROR: content-package download failed. Ensure MAVEN_SETTINGS_XML secret is set and Nexus is reachable." && exit 1)

# Arrange into the SPA layout expected by the nginx stage.
# Configs are placed under ethiopiaemr-package/ to mirror the artifact-ID-scoped
# structure that the old Maven OpenMRS packager plugin produced in spa-configs/.
# The ZIP root varies by how assembly.xml was configured at publish time, so we
# probe both known locations and fail loudly if neither is found.
RUN echo "=== extracted content-package layout ===" && \
    find /content/extracted -maxdepth 5 -type d | sort && \
    echo "===========================================" && \
    FC="" && \
    for candidate in \
        /content/extracted/configuration/frontend_configuration \
        /content/extracted/frontend_configuration; do \
      if [ -d "$candidate/configs" ]; then FC="$candidate"; break; fi; \
    done && \
    [ -n "$FC" ] || { echo "ERROR: frontend_configuration/configs not found in extracted ZIP"; exit 1; } && \
    echo "Using FC: $FC" && \
    mkdir -p /content/spa-content/assets/ethiopiaemr-package \
             /content/spa-content/configs/ethiopiaemr-package \
             /content/spa-content/overrides && \
    ([ -d "$FC/assets" ] && cp -r "$FC/assets/." /content/spa-content/assets/ethiopiaemr-package/ || true) && \
    cp -r "$FC/configs/." /content/spa-content/configs/ethiopiaemr-package/ && \
    ([ -d "$FC/overrides" ] && cp -r "$FC/overrides/." /content/spa-content/overrides/ || true)

#--------------------------------------------
# Dev Stage - Assembles and Builds Frontend
#--------------------------------------------
FROM --platform=$BUILDPLATFORM node:20-alpine AS dev

ARG APP_SHELL_VERSION=next

RUN mkdir -p /app
WORKDIR /app

COPY frontend/spa-assemble-config.json .
COPY frontend/spa-build-config.json .
COPY frontend/rename-packages.sh .
COPY frontend/favicon.ico .

RUN npx --legacy-peer-deps openmrs@${APP_SHELL_VERSION:-next} \
    assemble --manifest --mode config \
    --config spa-assemble-config.json \
    --target ./spa
RUN npx --legacy-peer-deps openmrs@${APP_SHELL_VERSION:-next} \
    build --build-config spa-build-config.json \
    --target ./spa
RUN if [ ! -f ./spa/index.html ]; then \
    echo 'Build failed. Please check the logs above for details. This may have happened because of an update to a library that OpenMRS depends on.'; \
    exit 1; \
    fi

# Execute the rename script
RUN chmod +x ./rename-packages.sh && ./rename-packages.sh

#--------------------------------------------
# Runtime Stage - Published Image
#--------------------------------------------
FROM nginx:1.25-alpine

RUN apk update && \
    apk upgrade && \
    apk add --no-cache moreutils

RUN mkdir -p /usr/share/nginx/html/openmrs/spa

COPY frontend/startup.sh /usr/local/bin/startup.sh
RUN chmod +x /usr/local/bin/startup.sh

COPY frontend/nginx.conf /etc/nginx/nginx.conf

COPY --from=dev /app/spa /usr/share/nginx/html/openmrs/spa

RUN mkdir -p /usr/share/nginx/html/openmrs/spa/configs \
             /usr/share/nginx/html/openmrs/spa/assets \
             /usr/share/nginx/html/openmrs/spa/overrides \
             /usr/share/nginx/html/config

# Copy content-package output (assets, configs, overrides) in place of the old
# spa-configs artifact that previously came from the backend Maven build.
COPY --from=content-package /content/spa-content /tmp/spa-configs
RUN cp -r /tmp/spa-configs/. /usr/share/nginx/html/openmrs/spa/ && \
    mkdir -p /usr/share/nginx/html/openmrs/spa/config && \
    cp -r /tmp/spa-configs/. /usr/share/nginx/html/openmrs/spa/config/ && \
    cp -r /tmp/spa-configs/. /usr/share/nginx/html/config/ && \
    rm -rf /tmp/spa-configs

CMD ["/bin/sh", "-c", "/usr/local/bin/startup.sh"]

