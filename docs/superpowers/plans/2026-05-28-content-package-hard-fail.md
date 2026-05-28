# Content-Package Hard Fail Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the frontend Docker build fail loudly when the content-package download fails, instead of silently shipping an empty/unbranded image.

**Architecture:** Replace the graceful-fallback `|| (warn && mkdir)` in the `content-package` Docker stage with a hard `|| (echo ERROR && exit 1)`. One file, one block, one logical change.

**Tech Stack:** Docker BuildKit, shell (`/bin/sh`)

---

### Task 1: Replace fallback with hard fail in `frontend/Dockerfile`

**Files:**
- Modify: `frontend/Dockerfile:14-21`

- [ ] **Step 1: Edit the fallback block**

In `frontend/Dockerfile`, replace lines 12–21 (the download RUN step and its fallback):

```dockerfile
# Download and unpack the content-package from Mekom Nexus.
# Build fails if download fails — never ship an empty/unbranded image.
RUN --mount=type=secret,id=m2settings,target=/root/.m2/settings.xml,required=false \
    mvn -U -ntp dependency:unpack \
        -Dartifact=org.ethiopiaemr.content:ethiopiaemr-package:1.0.0-SNAPSHOT:zip \
        -DoutputDirectory=/content/extracted || \
    (echo "ERROR: content-package download failed. Ensure MAVEN_SETTINGS_XML secret is set and Nexus is reachable." && exit 1)
```

The comment on line 12-13 changes from "Falls back to empty dirs..." to "Build fails if download fails...".
The `|| (echo "WARNING: ..." && mkdir -p ...)` block becomes `|| (echo "ERROR: ..." && exit 1)`.
Everything else in the file stays unchanged.

- [ ] **Step 2: Verify the change looks correct**

Run:
```bash
grep -A8 "mvn -U -ntp" frontend/Dockerfile
```

Expected output should contain `exit 1` and NOT contain `mkdir -p` or `WARNING`:
```
    mvn -U -ntp dependency:unpack \
        -Dartifact=org.ethiopiaemr.content:ethiopiaemr-package:1.0.0-SNAPSHOT:zip \
        -DoutputDirectory=/content/extracted || \
    (echo "ERROR: content-package download failed. Ensure MAVEN_SETTINGS_XML secret is set and Nexus is reachable." && exit 1)
```

- [ ] **Step 3: Commit**

```bash
git add frontend/Dockerfile
git commit -m "build: hard-fail frontend build when content-package download fails"
```
