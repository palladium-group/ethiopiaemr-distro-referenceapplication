# syntax=docker/dockerfile:1.3
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

ARG CACHE_BUST
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
    # add more utils for sponge and envsubst
    apk add --no-cache moreutils

# Create directory for SPA files
RUN mkdir -p /usr/share/nginx/html/openmrs/spa

COPY frontend/startup.sh /usr/local/bin/startup.sh
RUN chmod +x /usr/local/bin/startup.sh

COPY frontend/nginx.conf /etc/nginx/nginx.conf

# Copy SPA files to a temporary location
COPY --from=dev /app/spa /usr/share/nginx/html/openmrs/spa

# Copy SPA config files from backend build (if available)
# These configs come from the backend distro build and are placed in spa-configs during CI/CD
# The configs directory structure: spa-configs/configs/, spa-configs/assets/, spa-configs/overrides/
# Ensure directories exist first
RUN mkdir -p /usr/share/nginx/html/openmrs/spa/configs \
             /usr/share/nginx/html/openmrs/spa/assets \
             /usr/share/nginx/html/openmrs/spa/overrides \
             /usr/share/nginx/html/config

# Copy spa-configs from build context (present in CI/CD builds from backend distro build)
# This directory will contain the configs, assets, and overrides subdirectories
# Path is relative to build context (root directory)
# The files need to be accessible at /openmrs/spa/config/... URLs, so we copy to both locations
COPY frontend/spa-configs /tmp/spa-configs
RUN if [ -d /tmp/spa-configs ] && [ "$(ls -A /tmp/spa-configs 2>/dev/null)" ]; then \
        cp -r /tmp/spa-configs/* /usr/share/nginx/html/openmrs/spa/ && \
        mkdir -p /usr/share/nginx/html/openmrs/spa/config && \
        cp -r /tmp/spa-configs/* /usr/share/nginx/html/openmrs/spa/config/ && \
        cp -r /tmp/spa-configs/* /usr/share/nginx/html/config/ && \
        rm -rf /tmp/spa-configs; \
    fi

# Copy SPA files after volume mount
CMD ["/bin/sh", "-c", "/usr/local/bin/startup.sh"]