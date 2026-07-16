# Test114 Instructions -- server-command result check no longer inverted (BL-1990)

**For:** Linux test agent on the Lenovo Legion Go S Z2 (SteamOS 3.x)
**Prior report:** `testing/test113-bubbles-e2e/report.md` (PR #196) -- flagged the client polarity bug
**Goal:** Confirm that triggering a server command during an active stream now logs SUCCESS
(not a false "Command execution failed ... result: 1"), and that a genuine send failure is
still surfaced as a failure.

---

## Background

test113 (Bubbles in-session E2E) passed the host side but caught a CLIENT polarity bug, filed
as BL-1990. Root cause (confirmed against the library, not guessed):

- `LiSendExecServerCmd()` (moonlight-common-c `src/ControlStream.c:2054`) returns the `bool`
  from `sendMessageAndForget()`. That bool is **true/nonzero = the command was SENT to the host
  OK**, **false/0 = the send failed** (`sendMessageEnet` returns `true` at ControlStream.c:816,
  `false` at :813). The library's own caller `sendInputPacketOnControlStream` treats `== 0`
  as failure (:1664).
- The client `app/backend/servercommandmanager.cpp` checked `if (result == 0)` as the SUCCESS
  branch -- **inverted**. A successful send returns 1, so the code took the else branch and
  logged: `ServerCommandManager: Command execution failed: <cmd> with result: 1`, even though
  the command was delivered.

**The fix (this build):** the success branch is now `if (result != 0)` and logs
`ServerCommandManager: Command sent successfully: <cmd>`; the failure branch (`result == 0`)
still emits `commandFailed` and the `execution failed with result:` warning. One-line polarity
flip in `servercommandmanager.cpp`; no change to the send itself.

Expected on-device: the same Bubbles command that worked end-to-end in test113 now logs a
clean success on the client instead of the misleading "failed ... result: 1".

---

## Artifact

Per repo policy (`.gitignore`: "Test AppImages live in GitHub Releases / CI artifacts, not in
the repo"), the artifact is the **CI alpha pre-release** built from this branch, NOT a committed
AppImage.

**Release tag:** `0.2.0-alpha.006`  (expected -- last alpha was `0.2.0-alpha.005`; confirm it
is the NEWEST `0.2.0-alpha.*` and that its release body names branch
`test114-servercmd-resultfix`).
**md5:** `MD5_PLACEHOLDER`  (recompute after download and confirm it matches; see below).

Download and verify:
```bash
cd ~/vibemis
# newest alpha prerelease (this cycle's build):
TAG=$(gh release list --repo navyas321/vibemis --limit 30 --json tagName \
        --jq '[.[].tagName | select(startswith("0.2.0-alpha."))] | .[0]')
echo "downloading $TAG"
gh release download "$TAG" --repo navyas321/vibemis --dir ~/Downloads --pattern '*.AppImage' --clobber
APP=$(ls -t ~/Downloads/*.AppImage | head -1)
chmod +x "$APP"
md5sum "$APP"        # record this; must equal the md5 above once pinned
```
(If `gh` is not on PATH in a non-interactive shell it is usually at `~/.local/bin/gh`.)

---

## Test procedure

### Setup
```bash
cd ~/vibemis
git fetch origin test114-servercmd-resultfix
git checkout test114-servercmd-resultfix && git pull   # for these instructions + to write the report
# APP is the downloaded alpha AppImage from the Artifact step above.
```

### Tier 0 -- smoke + selftest (no host needed)
```bash
"$APP" selftest --json ; echo "selftest exit=$?"
# Bounded launch to confirm the UI comes up and there is no crash:
timeout 20s "$APP" > /tmp/vibemis-test114-boot.log 2>&1 & PID=$!
sleep 16 ; kill "$PID" 2>/dev/null ; wait "$PID" 2>/dev/null
grep -iE "EGLRenderer|renderer|error|SEGV|critical" /tmp/vibemis-test114-boot.log | head
```
Expected: `selftest --json` returns a JSON blob with `"ok": true` (exit 0); boot log shows the
renderer coming up with no SEGV/critical.

### Tier 1 -- pair + stream (host required; needs the maintainer's host operator)
This gates Tier 2: server commands only run during an ACTIVE streaming session
(`ServerCommandManager::isStreamingSessionActive()`).
1. Ensure the Vibepollo host is up and its SCREEN IS ON (a host operator is present -- see Safety).
2. Launch the AppImage, pair if needed, and START A STREAM to the host.
3. Confirm the stream is live (video visible, input works).

### Tier 2 -- trigger a server command once (the actual fix under test)
With the stream live, capture the client log while triggering the Bubbles server command
exactly once:
```bash
"$APP" > /tmp/vibemis-test114-servercmd.log 2>&1 &
# ... pair + stream, then open the Quick Menu and trigger the "Bubbles" server command ONCE ...
# after the command is sent and host-side Bubbles has run + self-terminated, stop the client, then:
grep -nE "ServerCommandManager: (Command sent successfully|Command execution failed|Using ENet)" \
     /tmp/vibemis-test114-servercmd.log
```

---

## What to check and report

1. **Client logs SUCCESS, not a false failure.** In the Tier 2 log:
   - MUST see: `ServerCommandManager: Command sent successfully: <bubbles>`
   - MUST NOT see: `ServerCommandManager: Command execution failed: <bubbles> with result: 1`
   ```bash
   grep -c "Command sent successfully" /tmp/vibemis-test114-servercmd.log     # expect >= 1
   grep -c "execution failed .*result: 1" /tmp/vibemis-test114-servercmd.log  # expect 0
   ```
2. **Host side still self-terminates.** The Bubbles command runs on the host and Bubbles
   self-terminates (host screen returns to normal). Note whether host-side teardown was clean
   (standing host-side teardown rule, BL-1821).
3. **Real failure still surfaces (design check).** Confirm by inspection that the failure path
   is intact: if a send ever returns 0 the client still emits `commandFailed` and logs
   `execution failed with result: 0`. No on-device action required unless you can force a send
   failure (e.g. trigger a command when the control stream is not healthy); if you do, record
   the log.
4. Tier 0 selftest exit code and any boot-log anomalies.

---

## Report format

Commit `testing/test114-servercmd-resultfix/report.md` on branch
`diagnostic/test114-servercmd-resultfix-report` and open a PR **targeting `vibemis-main`**.

Required sections: TL;DR table (Goal A -- no false failure / Goal B -- no regression), results
per tier, recommendation.

---

## Safety rules (standing)
- No package installs, no sudo outside read-only inspection.
- Do not modify the AppImage.
- Only pair/stream and trigger the server command because THIS cycle explicitly asks for it
  (Tier 1 + Tier 2). Trigger the Bubbles command ONCE.
- **Host screen must be ON with a host operator present** -- a server command drives the host;
  the maintainer is physically at the Legion Go and at/aware of the host. If the host is
  unattended or its screen is off, STOP and ask before Tier 2.
- If a step needs a permission or capability outside these rules, stop and ask.
