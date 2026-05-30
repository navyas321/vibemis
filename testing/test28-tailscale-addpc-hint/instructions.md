# Test28 Instructions — Tailscale hint in Add-PC dialog (P3.7 #2)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** Confirm the "Add PC" dialog shows a helper line explaining that a Tailscale address
can be used for off-network hosts, and that adding a host still works.

**No stream needed** — launcher-UI check. You do NOT need to actually connect.

---

## Artifact

**AppImage:** `testing/test28-tailscale-addpc-hint/Vibemis-0.6.7-vibemis-test28-tailscale-addpc-hint-x86_64.AppImage`
**md5:** `dfe52f38eb6fc06721bbbf71f8be1893`

```bash
md5sum testing/test28-tailscale-addpc-hint/*.AppImage
```

---

## Setup

```bash
cd ~/vibemis
git fetch origin test28-tailscale-addpc-hint
git checkout test28-tailscale-addpc-hint && git pull
chmod +x testing/test28-tailscale-addpc-hint/*.AppImage
./testing/test28-tailscale-addpc-hint/*.AppImage --appimage-extract-and-run &
```

---

## Tier 1 — Hint visible

1. On the main screen, trigger **Add PC** (the "+" / add-host action).
2. The dialog should show the IP prompt, the text field, **and a smaller greyed hint line**
   below it mentioning **Tailscale** (local IP for same-network; Tailscale 100.x.x.x /
   MagicDNS for a different network).
3. Confirm the hint text wraps and is readable (not cut off).

## Tier 2 — Dialog still works

1. Type any value and press **Cancel** — dialog closes, nothing added.
2. (Optional, only if a host IP is known and you're permitted) typing a valid IP and pressing
   **OK** still attempts to add it as before. Do NOT connect/pair.

---

## What to check and report

| # | Check | Expected |
|---|-------|----------|
| 1 | Add-PC dialog shows the Tailscale hint line | Yes |
| 2 | Hint wraps/readable, doesn't break dialog layout | Yes |
| 3 | Text field + OK/Cancel still function | Yes |

Screenshot of the dialog is ideal. Report SteamOS + Mesa version.

---

## Report format

Commit `testing/test28-tailscale-addpc-hint/report.md` on
`diagnostic/test28-tailscale-addpc-hint-report`; PR targets the test branch.

---

## Safety rules (standing)
- No package installs, no `sudo` outside read-only inspection; do not modify the AppImage
- Do not pair/connect — adding-dialog UI check only
