# Test4 — verify `LD_LIBRARY_PATH` prefer-host-libva fix on Legion Go S Z2

**Artifact to test:** `Vibemis-0.6.7-vibemis-test4-libva-host-pref-x86_64.AppImage`
**md5:** `b8c4e4f4c094b07e75032645dfcd53d9`
**Branch under test:** `fix/appimage-vaapi-driver-paths` (second commit on top of `fecbda8e`)
**Tied PR:** #4 (will be updated with this commit before the test is shipped)
**Previous report context:** `DIAGNOSTIC_REPORT_test3.md` (in PR #6) — identified that bundled libva 1.20 can't load Mesa 25.3's `__vaDriverInit_1_22`.

## What changed since test3

The AppRun init hook (`apprun-hooks/01-libva-driver-paths.sh`) now does two things instead of one:

1. (Unchanged) Exports `LIBVA_DRIVERS_PATH` so the libva loader finds the host's `/usr/lib64/dri` etc.
2. (**NEW**) Searches for a system `libva.so.2` at `/usr/lib64`, `/usr/lib/x86_64-linux-gnu`, `/usr/lib`. On the FIRST match, prepends that directory to `LD_LIBRARY_PATH` so the dynamic loader picks up the **host's** libva.so.2 instead of the bundled (1.20) one. Surgical — only one dir is prepended; we don't surface the rest of the system library set.

A diagnostic line is emitted to stderr so the choice is visible in run logs:

```
[vibemis-apprun-hook] preferring host libva.so.2 from /usr/lib64
```

If the line is absent in the run log, the hook didn't find a host libva (in which case the bundled one is used — and we expect the original failure).

An escape hatch: setting `VIBEMIS_SKIP_HOST_LIBVA=1` before launch disables step 2 and reverts to the test3 behavior. Useful for A/B comparison.

## Goals

Confirm two things, in this order:

1. **Goal A — hardware decode works on the Legion Go S Z2.** The "No functioning hardware accelerated video decoder was detected by Artemis" warning should be gone. `libva error: ... has no function __vaDriverInit_1_0` should also be gone. A successful `vaInitialize` should appear in either the run log or the libva trace file.
2. **Goal B — no regression vs test3 elsewhere.** mDNS discovery should still find `Navid-PC.local.` (or whatever Vibepollo host is on the LAN). GUI should launch and reach the Computers screen.

## What to run

```
# Find the AppImage (any of these)
find $HOME -maxdepth 4 -name "Vibemis-0.6.7-vibemis-test4-*.AppImage" 2>/dev/null
chmod +x "$APPIMAGE"

# Tier 1 — the new path (default)
env LIBVA_TRACE=/tmp/vibemis-libva-test4.log \
    LIBVA_TRACE_LOGSIZE=1G \
    LIBVA_MESSAGING_LEVEL=2 \
    QT_LOGGING_RULES="*.debug=true" \
    "$APPIMAGE" 2>&1 | tee /tmp/vibemis-run-test4.log &
sleep 25
pkill -f "Vibemis-0.6.7" || true

# Tier 2 — comparison run with the escape hatch, to confirm the hook is the differentiator
env VIBEMIS_SKIP_HOST_LIBVA=1 \
    LIBVA_TRACE=/tmp/vibemis-libva-test4-skipped.log \
    LIBVA_TRACE_LOGSIZE=1G \
    LIBVA_MESSAGING_LEVEL=2 \
    "$APPIMAGE" 2>&1 | tee /tmp/vibemis-run-test4-skipped.log &
sleep 15
pkill -f "Vibemis-0.6.7" || true
```

## What to extract for the report

For **both runs**:

- `grep "preferring host libva.so.2" /tmp/vibemis-run-test4*.log` — should appear in the default run, NOT in the `VIBEMIS_SKIP_HOST_LIBVA=1` run.
- `grep -iE "no function __vaDriverInit|VA_STATUS_ERROR|libva error" /tmp/vibemis-run-test4*.log | head` — expected: empty (or far fewer lines) in the default run, same as test3 in the skipped run.
- `grep -iE "no functioning|hardware accel" /tmp/vibemis-run-test4*.log | head` — the warning text from the GUI.
- `grep -iE "vaInitialize|VAEntrypoint|VAProfile" /tmp/vibemis-libva-test4*.log 2>/dev/null | head -20` — successful libva initialization markers.
- `grep -iE "mDNS|qmdns|discover|Processing new PC" /tmp/vibemis-run-test4.log | head -20` — confirm mDNS still works.

## Report format

Write a single file `testing/test4-libva-host-preference/report.md` on a new branch `diagnostic/test4-libva-host-pref-report`. Keep the structure under 10 sections, similar to `DIAGNOSTIC_REPORT_test3.md`:

1. Headline TL;DR — did Goal A work? did Goal B regress? two-row table.
2. Default run — was the "preferring host libva" line present?
3. Default run — libva errors / VA init status (paste relevant lines).
4. Default run — mDNS discovery (paste relevant lines).
5. Default run — the "No functioning HW decoder" warning, present or absent?
6. Skipped run — confirm it reverted to test3 behavior (control sample).
7. Other unexpected log lines worth flagging.
8. Your guess at root cause if Goal A still failed, or "fix verified working" if it succeeded.
9. Recommended next step (merge PR #4 ✅, or try fix #1 / #2 from the test3 report).
10. Artifact paths.

Open a PR against `fix/appimage-vaapi-driver-paths` (stacked) so the report ties to the exact commit it's testing.

## Constraints (unchanged from the workflow rules)

- No package installs, no sudo outside read-only inspection.
- No AppImage modifications.
- If a step needs the user to do something physical (set up Vibepollo, swap networks, etc.), stop and ask.
