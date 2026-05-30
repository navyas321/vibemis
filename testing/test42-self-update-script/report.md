# Test42 Report — Self-update helper `scripts/vibemis-update.sh` (P3.10)

**Artifact tested:** `scripts/vibemis-update.sh` (script-only test, no AppImage)
**Branch:** `test42-self-update-script` (FETCH_HEAD)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.6, Mesa 25.3.0
**Test date:** 2026-05-30
**Prior report:** N/A

---

## 1. TL;DR

| # | Check | Status | Notes |
|---|-------|--------|-------|
| 1 | `--check` prints latest tag + AppImage URL | PASS | Tag `0.6.7-beta.20260530.1227+2c77f44`, URL correct |
| 2 | Download writes executable `~/Applications/Vibemis.AppImage` | PASS | 87 MB, mode `rwx--x--x` |
| 3 | No sudo used | PASS | Comment in script confirms; grep finds no `sudo`/`pkexec` |
| 4 | Error handling in source | PASS | `curl -fsSL` fail → `ERROR: failed to query … (network/offline?)`, exit 1; partial-download aborted |

---

## 2. Tier 1 — Check (no download)

```
$ ./scripts/vibemis-update.sh --check
Querying latest Vibemis release...
Latest release: 0.6.7-beta.20260530.1227+2c77f44
AppImage:       https://github.com/navyas321/vibemis/releases/download/0.6.7-beta.20260530.1227%2B2c77f44/Vibemis-0.6.7-beta.20260530.1227%2B2c77f44-x86_64.AppImage
```

Latest release tag and URL printed; no download initiated. **PASS**.

---

## 3. Tier 2 — Download

```
$ ./scripts/vibemis-update.sh
Querying latest Vibemis release...
Latest release: 0.6.7-beta.20260530.1227+2c77f44
AppImage:       https://...
Downloading to /home/deck/Applications/Vibemis.AppImage ...
###########...############ 100.0%
Done. Updated /home/deck/Applications/Vibemis.AppImage to 0.6.7-beta.20260530.1227+2c77f44.
(If you added Vibemis to Steam via ~/Applications/Vibemis.AppImage, the shortcut now uses the new build.)
```

Result: `~/Applications/Vibemis.AppImage` exists, `rwx--x--x`, 87 MB. **PASS**.

---

## 4. Tier 3 — Error handling (source audit)

Script uses `set -euo pipefail`. Relevant lines:
```bash
JSON=$(curl -fsSL -H "Accept: application/vnd.github+json" "$API") || {
    echo "ERROR: failed to query $API (network/offline?)." >&2; exit 1; }
```
and:
```bash
if curl -fL --progress-bar -o "$TMP" "$URL"; then
  ...
else
  echo "ERROR: download failed." >&2; exit 1
fi
```

Partial-file cleanup: script downloads to a temp path before moving, so no partial file is left on
failure. Error messages go to stderr. **PASS** (source audit; live offline test skipped on SteamOS
since disabling network would break other services).

---

## 5. Recommendation

**MERGE** — `vibemis-update.sh` queries the GitHub Releases API, reports the latest tag and URL,
downloads with a progress bar, writes an executable AppImage to `~/Applications/`, and handles
errors cleanly. No sudo. No system modification.
