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
RUN --mount=type=secret,id=m2settings,target=/root/.m2/settings.xml,required=false \
    mvn -U -ntp dependency:unpack \
        -Dartifact=org.ethiopiaemr.content:ethiopiaemr-package:1.0.0-SNAPSHOT:zip \
        -DoutputDirectory=/content/extracted || \
    (echo "ERROR: content-package download failed. Ensure MAVEN_SETTINGS_XML secret is set and Nexus is reachable." && exit 1)

# Arrange into the SPA layout expected by the nginx stage:
#   assets/ethiopiaemr-package/  <- branding assets (logos, favicon)
#   configs/                     <- frontend JSON config files
#   overrides/                   <- dist-* dirs for SPA overrides
RUN FC=/content/extracted/configuration/frontend_configuration && \
    mkdir -p /content/spa-content/assets/ethiopiaemr-package \
             /content/spa-content/configs \
             /content/spa-content/overrides && \
    ([ -d "$FC/assets" ] && cp -r "$FC/assets/." /content/spa-content/assets/ethiopiaemr-package/ || true) && \
    ([ -d "$FC/configs" ] && cp -r "$FC/configs/." /content/spa-content/configs/ || true) && \
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
