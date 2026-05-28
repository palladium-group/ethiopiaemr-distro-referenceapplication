# Content-Package Hard Fail Design

**Date:** 2026-05-28
**Status:** Approved
**Goal:** Prevent empty/unbranded frontend images from shipping when Nexus is unreachable.

---

## Problem

The `content-package` stage in `frontend/Dockerfile` has a graceful fallback:

```dockerfile
mvn ... dependency:unpack ... || \
  (echo "WARNING: ..." && mkdir -p /content/extracted/...)
```

If Nexus is unreachable or Maven auth fails, Docker continues with empty dirs and produces a valid image — one that ships without branding assets, frontend configs, or overrides.

---

## Solution

Replace the fallback `mkdir` with a hard fail:

```dockerfile
mvn ... dependency:unpack ... || \
  (echo "ERROR: content-package download failed. Ensure MAVEN_SETTINGS_XML secret is set and Nexus is reachable." && exit 1)
```

**File changed:** `frontend/Dockerfile` — one line in the `content-package` stage.

**No other files change.** The `required=false` on the secret mount is preserved — it controls Docker's secret resolution, not Maven authentication.

---

## Behaviour After Change

| Scenario | Before | After |
|---|---|---|
| Nexus reachable, auth valid | Build succeeds, image has content | Build succeeds, image has content |
| Nexus unreachable | Build succeeds, image is empty | Build fails with actionable error |
| Auth failure (bad/missing credentials) | Build succeeds, image is empty | Build fails with actionable error |
| Local build without secret | Build succeeds, image is empty | Build fails (anonymous Nexus access fails) |

---

## Out of Scope

- Version pinning (`1.0.0-SNAPSHOT` hardcoding) — separate follow-up
- Conditional prod-vs-dev failure modes — decided against (always fail)
- Post-unpack structural validation — adds coupling to content package internals, not worth it
