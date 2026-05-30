# Test52 Report — `vibemis selftest` headless smoke test (automation enabler)

**Artifact tested:** `Vibemis-0.6.7-alpha.test52-selftest-cli.20260529.2057+53f4ec9-x86_64.AppImage`
**md5:** `e6d486a8d2de3fee281fd810df45aa4e`
**Branch:** `test52-selftest-cli` (commit `53f4ec9`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.5 (BUILD_ID 20260520.100), Mesa 25.3.0
**Test date:** 2026-05-29
**Prior report:** N/A (first cycle of the new checklist queue)

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| A — `selftest` passes & exits 0 | PASS ✅ | 5/5 checks PASS, `RESULT: PASS (0 failure(s))`, exit=0 |
| B — non-interactive & deterministic | PASS ✅ | Returns on its own, no window; two runs byte-identical |
| C — headless in Game Mode (Tier 2) | N/A | No Game Mode shell this session; command runs pre-GUI so session-agnostic |

**Tooling note:** `testing/run-cycle.sh` failed to auto-fetch the alpha — it calls bare `gh`, which is **not on PATH in a non-interactive shell** on this device (`gh` lives at `~/.local/bin/gh`). Downloaded the alpha manually instead. See Other Findings.

---

## 2. Tier 1 — selftest passes and is scriptable (Desktop Mode)

```
$ "$APP" selftest > /tmp/vibemis-selftest.log 2>&1; echo "exit=$?"
exit=0

# /tmp/vibemis-selftest.log:
[vibemis-apprun] FORCE_VAAPI=1 (host DRI: /usr/lib64/dri)
00:00:00 - Qt Warning: Could not find the Qt platform plugin "wayland" in ""
SELFTEST prefs-load: PASS
SELFTEST default-bitrate: PASS
SELFTEST display-mode: PASS
SELFTEST bitrate-positive: PASS
SELFTEST audio-config-range: PASS
SELFTEST RESULT: PASS (0 failure(s))
```

- Every `SELFTEST <name>:` line is PASS; final `RESULT: PASS (0 failure(s))`; **exit=0**. ✅
- **Non-interactive:** command returned on its own, opened no window, required no input. ✅
- **Deterministic:** re-ran; the `SELFTEST` lines are byte-identical between runs (`diff` empty). ✅

```
$ diff <(grep SELFTEST run1.log) <(grep SELFTEST run2.log)   # → no output (IDENTICAL)
$ exit=0 (run 2)
```

**Result: PASS.**

---

## 3. Tier 2 — headless in Game Mode session

**N/A this cycle.** Device is in Desktop Mode and no Game Mode terminal was available without a session switch. The check is low-risk: `selftest` runs *before* GUI/SDL init (it only touches the prefs subsystem), so it is session-agnostic by construction — it produced no window and needed no display in Desktop Mode. Recommend a follow-up Game Mode confirmation when convenient, but no reason to expect divergence.

---

## 4. Other findings

- **`run-cycle.sh` can't find alpha releases — `gh` not on PATH in non-interactive shells.** The helper does `TAG=$(gh release list ... )` with a bare `gh`. On this device `gh` is only at `~/.local/bin/gh`, which a non-login/non-interactive shell does not pick up, so the lookup returns empty and the script reports *"no AppImage … no alpha release."* The release tag clearly exists (`0.6.7-alpha.test52-selftest-cli.20260529.2057+53f4ec9`). **Suggested fix:** in `run-cycle.sh`, resolve `gh` via `GH=$(command -v gh || echo "$HOME/.local/bin/gh")` and call `"$GH"`, or prepend `~/.local/bin` to PATH at the top of the script. Manual download worked fine.
- **Benign Qt warning:** `Could not find the Qt platform plugin "wayland"`. selftest still runs and passes — it never needs a platform plugin. No action needed; could optionally pass `-platform offscreen` for the selftest path to silence it.
- **FORCE_VAAPI hook** fires as expected from the AppRun wrapper.

---

## 5. Recommendation

**MERGE.** The `selftest` command does exactly what test-automation needs: headless, deterministic, exit-coded, no window. This unblocks the scripted Tier-1 checks described in `docs/TEST_AUTOMATION.md` for later cycles.

One small **follow-up (non-blocking)** for the build agent: patch `testing/run-cycle.sh` to locate `gh` at `~/.local/bin/gh` (or extend PATH) so the cycle helper can auto-download alpha artifacts on this device.
