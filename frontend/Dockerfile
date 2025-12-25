# syntax=docker/dockerfile:1.3
#--------------------------------------------
# Dev Stage - Assembles and Builds Frontend
#--------------------------------------------
FROM --platform=$BUILDPLATFORM node:20-alpine AS dev

ARG APP_SHELL_VERSION=next

RUN mkdir -p /app
WORKDIR /app

COPY spa-assemble-config.json .
COPY spa-build-config.json .
COPY rename-packages.sh .
COPY favicon.ico .

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
RUN mkdir -p /usr/share/nginx/html

COPY startup.sh /usr/local/bin/startup.sh
RUN chmod +x /usr/local/bin/startup.sh

COPY nginx.conf /etc/nginx/nginx.conf

# Copy SPA files to a temporary location
COPY --from=dev /app/spa /usr/share/nginx/html/openmrs/spa

# Mount point for SPA config files
# VOLUME ["/usr/share/nginx/html"]

# Copy SPA files after volume mount
CMD ["/bin/sh", "-c", "/usr/local/bin/startup.sh"]