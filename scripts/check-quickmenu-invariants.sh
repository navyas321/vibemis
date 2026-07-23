#!/usr/bin/env bash
# BL-2443 Quick Menu wiring guard.
#
# The Quick Menu registers each button in TWO places: the ListElement's `action`
# id in app/gui/QuickMenu.qml, and a dispatch arm in QuickMenuManager::executeAction().
# Miss the second and the button is SILENTLY DEAD — it renders, it is focusable, it
# clicks, and nothing happens. No warning, no toast, no log. That is exactly how the
# old "Send Shift+Tab" button shipped: "key_shift_tab" was never added to the dispatch
# chain, so sendSpecialKey() (its only call site) was never reached and its whole
# implementation was unreachable dead code.
#
# This asserts every key_* action declared in the QML is actually dispatched.
# Run from the repo root.
set -u
fail=0
err() { echo "QUICKMENU-INVARIANT FAIL: $1" >&2; fail=1; }

QML="app/gui/QuickMenu.qml"
MGR="app/backend/quickmenumanager.cpp"

[ -f "$QML" ] || { echo "missing $QML" >&2; exit 1; }
[ -f "$MGR" ] || { echo "missing $MGR" >&2; exit 1; }

# 1. Every key_* action id in the QML must be dispatched in executeAction().
#    Scoped to the executeAction() BODY on purpose: sendSpecialKey() also compares
#    the same ids, so a whole-file grep would match the handler and pass on exactly
#    the bug this guards (declared + implemented, but never dispatched — which is
#    precisely how key_shift_tab shipped dead).
DISPATCH=$(awk '/^void QuickMenuManager::executeAction/{f=1} f{print} f&&/^}$/{exit}' "$MGR")
if [ -z "$DISPATCH" ]; then
  err "$MGR: could not locate the executeAction() body — this guard is not actually checking anything"
else
  for act in $(grep -oE 'action: "key_[a-z0-9_]+"' "$QML" | sed -E 's/.*"(key_[a-z0-9_]+)"/\1/' | sort -u); do
    printf '%s' "$DISPATCH" | grep -qF "action == \"$act\"" \
      || err "$act is declared in QuickMenu.qml but never dispatched in executeAction() — the button would be DEAD"
  done
fi

# 2. The Alt+Tab chord must press a REAL left-Alt (VK_LMENU 0xA4) around VK_TAB.
#    A bitfield-only MODIFIER_ALT cannot hold Alt across the Tab down/up.
if grep -qF 'action == "key_alt_tab"' "$MGR"; then
  grep -qF 'LiSendKeyboardEvent(0xA4, KEY_ACTION_DOWN, MODIFIER_ALT)' "$MGR" \
    || err "$MGR: key_alt_tab no longer presses a real VK_LMENU (0xA4) — Alt+Tab needs Alt held across Tab"
  grep -qF 'LiSendKeyboardEvent(0xA4, KEY_ACTION_UP,   0)' "$MGR" \
    || err "$MGR: key_alt_tab no longer releases VK_LMENU — a stuck Alt on the host"
fi

# 3. The retired Shift+Tab action must not linger as LIVE CODE (a QML action id or a
#    dispatch comparison). Prose mentions in comments are deliberate history — the
#    "why it was dead" note is the most valuable comment in this file.
if grep -qF 'action: "key_shift_tab"' "$QML" || grep -qF 'action == "key_shift_tab"' "$MGR"; then
  err "key_shift_tab is still live code — it was replaced by key_alt_tab"
fi

if [ "$fail" -ne 0 ]; then
  echo "One or more Quick Menu invariants failed." >&2
  exit 1
fi
echo "All Quick Menu invariants hold."
