# Test47 Instructions — Quick Menu: Send Special Keys (P3.11)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** Verify the new Quick Menu items send Ctrl+Alt+Del / Alt+F4 / Super / Esc to the host.

> **Built on test22** (Game-Mode Quick Menu). Requires a paired host + stream. Test in Desktop
> Mode if the Game-Mode render is still under verification (test22).

---

## Artifact

**AppImage:** `testing/test47-quickmenu-special-keys/Vibemis-0.6.7-vibemis-test47-quickmenu-special-keys-x86_64.AppImage`
**md5:** `b815ce22a8dd6d9f56ece3adb8279b72`

## Setup

```bash
cd ~/vibemis
git fetch origin test47-quickmenu-special-keys
git checkout test47-quickmenu-special-keys && git pull
chmod +x testing/test47-quickmenu-special-keys/*.AppImage
./testing/test47-quickmenu-special-keys/*.AppImage --appimage-extract-and-run > ~/test47.log 2>&1 &
```

## Tier 1 — Special keys

1. Stream to the paired host (a **desktop** session on the host is best for observing these).
2. Open the Quick Menu; confirm new items: **Send Ctrl+Alt+Del**, **Send Alt+F4**,
   **Send Super (Win) key**, **Send Esc**.
3. Select **Send Super** → the host's Start menu / launcher opens.
4. Select **Send Alt+F4** with a window focused → that window closes on the host.
5. Select **Send Ctrl+Alt+Del** → the host shows its security/lock screen (Windows) or the
   mapped action (Linux host). A "Sent key to host" toast appears.
6. Select **Send Esc** → Escape registers on the host.

## Tier 2 — Regression

1. Other menu items still work (Toggle Performance Stats toggles the overlay).

## What to check and report

| # | Check | Expected |
|---|-------|----------|
| 1 | Four "Send …" items present | Yes |
| 2 | Super opens host start menu | Yes |
| 3 | Alt+F4 closes focused host window | Yes |
| 4 | Ctrl+Alt+Del triggers host secure attention / mapped action | Yes |
| 5 | Esc registers on host | Yes |
| 6 | "Sent key to host" toast shown; other items unaffected | Yes |

Report SteamOS + Mesa version and the host OS (Windows/Linux) used.

## Report format
Commit `testing/test47-quickmenu-special-keys/report.md` on
`diagnostic/test47-quickmenu-special-keys-report`; PR targets the test branch.

## Safety rules (standing, streaming exception for this cycle)
- No package installs, no `sudo` outside read-only inspection; do not modify the AppImage
- Streaming authorized; pairing is not — if host isn't paired, stop and report
