# Test37 Instructions — Settings "About" section (P3.9 UI)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** Verify the new **About** section at the bottom of Settings shows the Vibemis version
and a working repo link.

**No stream/host needed** — pure launcher-UI check.

---

## Artifact

**AppImage:** `testing/test37-settings-about/Vibemis-0.6.7-vibemis-test37-settings-about-x86_64.AppImage`
**md5:** `4f876553578d3fa53be7a0922011064c`

```bash
md5sum testing/test37-settings-about/*.AppImage
```

## Setup

```bash
cd ~/vibemis
git fetch origin test37-settings-about
git checkout test37-settings-about && git pull
chmod +x testing/test37-settings-about/*.AppImage
./testing/test37-settings-about/*.AppImage --appimage-extract-and-run &
```

## Tier 1 — About section

1. Open **Settings** and scroll to the bottom of the right-hand column.
2. Confirm an **"About"** group shows:
   - **"Vibemis 0.6.7"** (the version string)
   - a one-line description
   - a link **github.com/navyas321/vibemis**
3. Clicking the link should open the repo in a browser (Desktop Mode).

## Tier 2 — No regression

1. Confirm the rest of Settings renders normally and is navigable with gamepad/keyboard.

## What to check and report

| # | Check | Expected |
|---|-------|----------|
| 1 | "About" section present at bottom of Settings | Yes |
| 2 | Shows "Vibemis 0.6.7" version | Yes |
| 3 | Repo link present (and opens in Desktop Mode) | Yes |
| 4 | No layout/navigation regression | Yes |

Report SteamOS + Mesa version; a screenshot of the About section is ideal.

## Report format
Commit `testing/test37-settings-about/report.md` on `diagnostic/test37-settings-about-report`;
PR targets the test branch.

## Safety rules (standing)
- No package installs, no `sudo` outside read-only inspection; do not modify the AppImage
- No streaming/pairing needed
