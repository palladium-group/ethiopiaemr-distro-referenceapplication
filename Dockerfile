# syntax=docker/dockerfile:1.7

### Dev Stage
# Using Temurin-based image (Ubuntu) to avoid GLIBC_2.27 issues with Amazon Linux 2
FROM openmrs/openmrs-core:dev-eclipse-temurin-21 AS dev
WORKDIR /openmrs_distro

ARG MVN_ARGS_SETTINGS="-s /usr/share/maven/ref/settings-docker.xml -U -P distro"
ARG MVN_ARGS="install"

# Copy build files
COPY pom.xml ./
COPY distro ./distro/

ARG CACHE_BUST
# Build the distro, but only deploy from the amd64 build
RUN --mount=type=secret,id=m2settings,target=/usr/share/maven/ref/settings-docker.xml \
    if [ "$MVN_ARGS" != "deploy" ] || [ "$(arch)" = "x86_64" ]; then \
        mvn $MVN_ARGS_SETTINGS $MVN_ARGS -Dskip.validation=true; \
    else \
        mvn $MVN_ARGS_SETTINGS install -Dskip.validation=true; \
    fi


RUN cp /openmrs_distro/distro/target/sdk-distro/web/openmrs_core/openmrs.war /openmrs/distribution/openmrs_core/

RUN cp /openmrs_distro/distro/target/sdk-distro/web/openmrs-distro.properties /openmrs/distribution/
RUN cp -R /openmrs_distro/distro/target/sdk-distro/web/openmrs_modules /openmrs/distribution/openmrs_modules/
RUN cp -R /openmrs_distro/distro/target/sdk-distro/web/openmrs_owas /openmrs/distribution/openmrs_owas/
RUN cp -R /openmrs_distro/distro/target/sdk-distro/web/openmrs_config /openmrs/distribution/openmrs_config/

# Move contents from any subdirectory directly under addresshierarchy
RUN AH_DIR="/openmrs/distribution/openmrs_config/addresshierarchy" && \
    if [ -d "${AH_DIR}" ]; then \
        for subdir in "${AH_DIR}"/*; do \
            if [ -d "${subdir}" ]; then \
                mv "${subdir}"/* "${AH_DIR}"/ 2>/dev/null || true; \
                rm -rf "${subdir}"; \
            fi; \
        done; \
    fi

# Copy SPA files to a shared location
RUN mkdir -p /openmrs/distribution/spa-config
RUN cp -R /openmrs_distro/distro/target/sdk-distro/web/openmrs_spa/* /openmrs/distribution/spa-config/

# Clean up after copying needed artifacts
# RUN mvn $MVN_ARGS_SETTINGS clean

### Run Stage
# Using Temurin-based image (Ubuntu) for production
FROM openmrs/openmrs-core:2.8.x

# Do not copy the war if using the correct openmrs-core image version
COPY --from=dev /openmrs/distribution/openmrs_core/openmrs.war /openmrs/distribution/openmrs_core/

COPY --from=dev /openmrs/distribution/openmrs-distro.properties /openmrs/distribution/
COPY --from=dev /openmrs/distribution/openmrs_modules /openmrs/distribution/openmrs_modules
COPY --from=dev /openmrs/distribution/openmrs_owas /openmrs/distribution/openmrs_owas
COPY --from=dev  /openmrs/distribution/openmrs_config /openmrs/distribution/openmrs_config

# Ensure contents from any subdirectory are moved directly under addresshierarchy (already done in dev stage, but verify)
RUN AH_DIR="/openmrs/distribution/openmrs_config/addresshierarchy" && \
    if [ -d "${AH_DIR}" ]; then \
        for subdir in "${AH_DIR}"/*; do \
            if [ -d "${subdir}" ]; then \
                mv "${subdir}"/* "${AH_DIR}"/ 2>/dev/null || true; \
                rm -rf "${subdir}"; \
            fi; \
        done; \
    fi

# Copy SPA files to a location that can be mounted by the frontend container
COPY --from=dev /openmrs/distribution/spa-config /openmrs/distribution/spa-config

# Copy Liquibase SQL files into image
COPY liquibase /liquibase

# Copy startup script (with executable permissions)
COPY --chmod=755 fix-liquibase-sql.sh /fix-liquibase-sql.sh

COPY rebuild-search-index.sh /usr/local/bin/rebuild-search-index.sh
RUN chmod +x /usr/local/bin/rebuild-search-index.sh

ENTRYPOINT ["/fix-liquibase-sql.sh"]
