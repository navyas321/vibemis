# Test39 Instructions — First-run welcome hint (P3.10)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Goal:** Verify a one-time welcome dialog shows on first launch with the key onboarding tips,
and does NOT show again afterward.

**No stream/host needed** — launcher-UI check.

---

## Artifact

**AppImage:** `testing/test39-first-run-hint/Vibemis-0.6.7-vibemis-test39-first-run-hint-x86_64.AppImage`
**md5:** `9251915e1f8e29486db8739f84f0ab9d`

```bash
md5sum testing/test39-first-run-hint/*.AppImage
```

## Setup

```bash
cd ~/vibemis
git fetch origin test39-first-run-hint
git checkout test39-first-run-hint && git pull
chmod +x testing/test39-first-run-hint/*.AppImage
```

> The hint shows only when `seenWelcomeHint` is false. If you've run a Vibemis build before,
> the flag may already be set. To force a true first-run, temporarily move the config:
> ```bash
> mv ~/.config/Vibemis ~/.config/Vibemis.bak 2>/dev/null || true
> ```
> (restore with `mv ~/.config/Vibemis.bak ~/.config/Vibemis` after the test).

## Tier 1 — Hint shows once

1. First launch (fresh config): a **"Welcome to Vibemis!"** dialog appears with three bullets:
   Quick Menu combos, Add-to-Steam tip, and Settings pointer.
2. Press **OK** (or dismiss). The app continues normally.
3. **Quit and relaunch** → the welcome dialog does **NOT** appear again.

## Tier 2 — No regression

1. Confirm the normal startup (PC list, polling, any hardware-warning dialogs) is unaffected —
   the app reaches the main screen as usual whether or not the hint showed.
2. Navigable with gamepad/keyboard (the OK button is reachable).

## What to check and report

| # | Check | Expected |
|---|-------|----------|
| 1 | Welcome dialog shows on first run with the 3 tips | Yes |
| 2 | Dismissing it lets the app continue | Yes |
| 3 | It does NOT reappear on next launch | Yes |
| 4 | Normal startup unaffected (no regression) | Yes |
| 5 | OK button reachable via gamepad/keyboard | Yes |

Report SteamOS + Mesa version; a screenshot of the dialog is ideal.

## Report format
Commit `testing/test39-first-run-hint/report.md` on `diagnostic/test39-first-run-hint-report`;
PR targets the test branch.

## Safety rules (standing)
- No package installs, no `sudo`. If you moved `~/.config/Vibemis`, restore it after.
