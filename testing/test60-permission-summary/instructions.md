# test60 — Per-client access level in the PC context menu (P3.13)

**Feature:** The PC right-click/context menu now shows an **"Access: …"** line for Apollo hosts that
report permissions — **Full access** / **View + input** / **View only**. (Apollo grants the first
paired client full access and later clients view/input-only.) Hidden for hosts that don't report
permissions (plain Sunshine, or not yet connected). New `ComputerModel` role + context-menu item.
**Branch:** `test60-permission-summary` · **Base:** `vibemis-main` · **Artifact:** 🔬 alpha
pre-release (tag contains `test60-permission-summary`).

> Launcher-only. Most meaningful against a **paired Apollo** host; harmless otherwise.

## Setup
1. Download the alpha AppImage, `chmod +x`, record `md5sum` + SteamOS/Mesa versions.

## Tier 1 — access line shows for an Apollo host
1. With a paired **Apollo** host in the list, open its context menu (right-click / menu button).
2. Just under **"PC Status: …"**, confirm an **"Access: Full access"** (or "View + input" / "View
   only") line.
   - ✅ PASS if the line shows a sensible level for an Apollo host. (First-paired client is usually
     **Full access**.) Mark **N/A** if you only have a non-Apollo/Sunshine host.

## Tier 2 — hidden when not applicable (no crash)
1. Open the context menu for a **non-Apollo** host, or an offline/just-added host that hasn't
   reported permissions.
   - ✅ PASS if **no** "Access:" line appears (and no blank/empty menu row), and the menu otherwise
     works normally.

## Tier 3 — regression
1. Confirm the rest of the context menu (View All Apps, View Details, Wake, Delete, etc.) is intact.
   - ✅ PASS if all existing menu items work.

## What to capture / report
- md5 + environment, host type (Apollo/Sunshine), the access level shown, a screenshot of the menu.

## Report
Write `testing/test60-permission-summary/report.md`, update the `test60` row in
`testing/TEST_CHECKLIST.md`, commit both on `diagnostic/test60-permission-summary-report`,
open a PR targeting `test60-permission-summary`.
