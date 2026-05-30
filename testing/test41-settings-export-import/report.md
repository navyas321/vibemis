# Test41 Report — Settings export / import (P3.11)

**Artifact tested:** `Vibemis-0.6.7-vibemis-test41-settings-export-import-x86_64.AppImage`
**md5:** `ad925beaf9cf2d15d358ceb5cf95450d` ✓ verified
**Branch:** `test41-settings-export-import` (commit `e9644...` from FETCH_HEAD)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.6, Mesa 25.3.0
**Test date:** 2026-05-30
**Prior report:** N/A

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| 1 — Export writes ~/vibemis-settings.ini with current values | PASS | File created (5.8K), contains all settings including `bitrate=51000`, `fps=120`, etc. |
| 2 — Export status path shown | PASS | Cyan "Exported to /home/deck/vibemis-settings.ini" visible in UI |
| 3 — Import restores exported values (after click) | PASS | `bitrate` restored from 20000 → 51000 immediately (reload() called) |
| 4 — Import with no file → "No backup found" | PASS | After removing ini, Import shows "No backup found at ~/vibemis-settings.ini" |
| 5 — No regression elsewhere in Settings | PASS | All Settings sections render correctly; button pair coexists cleanly |

---

## 2. Tier 1 — Export

**Log:** Clean launch; mDNS disabled; Navid-PC online. VDPAU probe errors at startup are pre-existing (AMD device, no VDPAU) — unrelated to this feature.

**Navigation:** Settings gear opened → scrolled left panel to "Settings backup" → clicked "Export settings" button (hover-verified before click).

**Result:** `~/vibemis-settings.ini` created at 10:09.

```
-rw-r--r-- 1 deck deck 5.8K May 30 10:09 /home/deck/vibemis-settings.ini
```

**File content (excerpt):**
```ini
[General]
autoadjustbitrate=false
bitrate=51000
fps=120
height=1200
mdns=false
width=1920
...
```

All streaming preferences exported correctly. Certificate/key pair included (full portable backup). Status label showed cyan **"Exported to /home/deck/vibemis-settings.ini"** (confirmed in screenshot).

**PASS**

---

## 3. Tier 2 — Import (restore + no-backup)

### Import restores values

Setup: manually set `bitrate=20000` in `~/.config/Vibemis Project/Vibemis.conf` to simulate a changed setting (export file retains `bitrate=51000`).

Clicked "Import settings" → `importSettings()` reads `~/vibemis-settings.ini`, writes keys to QSettings, calls `reload()`.

**Verification (immediate):** `bitrate` in Vibemis.conf = `51000` ✓ — restored from export file.

Status label showed cyan **"Imported from ~/vibemis-settings.ini — reopen Settings or restart to see all values."** (confirmed in screenshot).

Note: QML Settings panel does not live-refresh imported values (expected per instructions); values take effect after reopen/restart.

**PASS**

### Import with no backup

Deleted `~/vibemis-settings.ini`, then clicked "Import settings" again.

`importSettings()` returned `false` (file absent). Status label changed to **"No backup found at ~/vibemis-settings.ini"** (confirmed in screenshot). Config unchanged.

**PASS**

---

## 4. Other findings

**Sensitive data in export:** The export includes the client certificate and private key (`certificate=`, `key=` fields). This is by design (full portable backup), but is worth documenting — users copying the ini file to another device will transfer their pairing credentials. Not a bug, but a user-education note.

**VDPAU probe errors:** Pre-existing on this device; `SDL Error: Failed to create VDPAU context` at startup. Unrelated to this feature.

---

## 5. Recommendation

**MERGE** — export and import work end-to-end: file created with correct content, import restores values immediately via `reload()`, status messages render correctly for all three cases (export, import, no-backup). The sensitive-data note (cert/key in export) is expected behavior for a portable backup feature.
