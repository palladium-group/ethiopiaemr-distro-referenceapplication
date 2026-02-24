#!/bin/sh
set -e
trap 'kill -TERM $TOMCAT_PID' TERM INT

echo "[Liquibase fix] Starting OpenMRS with Liquibase SQL fix..."

# Start Tomcat in the background
/openmrs/startup.sh &
TOMCAT_PID=$!

echo "[Liquibase fix] Waiting for Tomcat to explode WAR file..."

# Wait for the WAR to be exploded and WEB-INF/classes to exist
TARGET="/usr/local/tomcat/webapps/openmrs/WEB-INF/classes"
MAX_WAIT=120
WAITED=0

while [ ! -d "$TARGET" ] && [ $WAITED -lt $MAX_WAIT ]; do
    sleep 2
    WAITED=$((WAITED + 2))
    echo "[Liquibase fix] Waiting for $TARGET... (${WAITED}s/${MAX_WAIT}s)"
done

if [ ! -d "$TARGET" ]; then
    echo "[ERROR] Timeout waiting for Tomcat to create $TARGET"
    kill $TOMCAT_PID 2>/dev/null || true
    exit 1
fi

echo "[Liquibase fix] Found $TARGET, copying SQL files..."

# Copy SQL files
if [ -d "/liquibase" ]; then
    if ls /liquibase/*.sql 1> /dev/null 2>&1; then
        cp -v /liquibase/*.sql "$TARGET/"
        echo "[Liquibase fix] SQL files copied successfully!"
        ls -la "$TARGET"/*.sql 2>/dev/null || true
    else
        echo "[Liquibase fix] WARNING: No SQL files found in /liquibase"
    fi
else
    echo "[Liquibase fix] WARNING: /liquibase directory not found"
fi

echo "[Search Index] Launching search index rebuild trigger in background..."
# We run this in the background (&) so it can wait for the API to come 
# alive while this script continues to the 'wait' command below.
/usr/local/bin/rebuild-search-index.sh &
# Keep the script running and forward signals to Tomcat
echo "[Liquibase fix] Setup complete. Tomcat running with PID $TOMCAT_PID"

# Wait for Tomcat process
wait $TOMCAT_PID