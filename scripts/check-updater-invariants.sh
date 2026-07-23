#!/usr/bin/env bash
# BL-2437/2438/2439 auto-updater safety guard.
# Three user-reported failures this protects against:
#   1. A Stable-channel user was silently moved to Beta and auto-updated to a
#      prerelease. Root cause: AutoResizingComboBox's Left/Right handlers called
#      in/decrementCurrentIndex() with the popup CLOSED, which emits activated()
#      and persists the new value — and gamepad d-pad/stick Left/Right arrive as
#      raw arrow keys (unlike Up/Down, which UiNavMode turns into Tab/Backtab).
#   2. Update UI told the user to "open the release page".
#   3. The updater navigated to github.com instead of installing.
# The updater must ALWAYS self-install and must NEVER bounce a user to a browser.
# Run from the repo root.
set -u
fail=0
err() { echo "UPDATER-INVARIANT FAIL: $1" >&2; fail=1; }

COMBO="app/gui/AutoResizingComboBox.qml"
MAIN="app/gui/main.qml"
CHECKER="app/backend/autoupdatechecker.cpp"
UPDSH="scripts/vibemis-update.sh"

# 1. Arrow keys must never edit a closed combo box (all four directions guarded).
for key in onUpPressed onDownPressed onLeftPressed onRightPressed; do
  grep -A2 "Keys.$key" "$COMBO" | grep -qF 'if (popup.visible)' \
    || err "$COMBO: Keys.$key is missing the closed-popup guard"
done
if grep -qE '^\s*(in|de)crementCurrentIndex\(\)' "$COMBO"; then
  err "$COMBO: bare in/decrementCurrentIndex() call — edits the value with the popup closed"
fi

# 2. The updater never sends the user to the release page / GitHub.
if grep -n 'openUrl' "$MAIN" | grep -qi 'releaseUrl'; then
  err "$MAIN: updater opens the release URL — it must always install in place"
fi
if grep -qi 'open the release page' "$MAIN"; then
  err "$MAIN: user-facing text still advertises opening the release page"
fi

# 3. Channel enforcement is re-asserted at install time, not only at offer time.
grep -qF 'channelFloor(StreamingPreferences::get()->updateChannel)' "$CHECKER" \
  || err "$CHECKER: install() no longer re-validates the offer against the live channel floor"

# 4. Selection must not blindly take the first feed entry (feed is created_at-ordered).
if grep -qF 'The feed is newest-first' "$CHECKER"; then
  err "$CHECKER: reinstated the false 'feed is newest-first' assumption"
fi

# 5. The update script defaults to STABLE; prereleases require an explicit opt-in.
grep -qE '^CHANNEL_STABLE=1' "$UPDSH" \
  || err "$UPDSH: default channel is not stable (a Stable user would get a beta)"
grep -qF -- '--beta|--prerelease' "$UPDSH" \
  || err "$UPDSH: no explicit --beta opt-in for prereleases"

if [ "$fail" -ne 0 ]; then
  echo "One or more updater invariants failed." >&2
  exit 1
fi
echo "All updater invariants hold."
