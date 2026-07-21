#!/usr/bin/env python3
"""BL-2263 Settings IA — deterministic settings-control manifest extractor.

Parses app/gui/SettingsView.qml (plus the included ClipboardSettings.qml
component) as TEXT (no Qt required) and emits a machine-checkable JSON
manifest of every user-visible settings control:

    { "type", "id", "label", "prefs" (StreamingPreferences members touched),
      "tooltip", "category" (sidebar index), "category_label", "card"
      (enclosing GroupBox id), "card_pos" (declaration order in card),
      "global_pos" (declaration order over the whole file), "in_dialog",
      "source" (file), "line" }

Identity for the zero-drop gate = (id, label, sorted-writable-prefs).
Position fields are EXPECTED to change in the IA overhaul; identity is not.

Usage:  python3 tests/settings-ia/extract_manifest.py [--out FILE]
Deterministic: same input -> byte-identical output (sorted keys, no
timestamps).
"""

import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SETTINGS_QML = os.path.join(REPO, "app", "gui", "SettingsView.qml")
CLIPBOARD_QML = os.path.join(REPO, "app", "gui", "ClipboardSettings.qml")

# Control component types that constitute a user-visible settings control.
CONTROL_TYPES = {
    "VbToggleRow", "CheckBox", "AutoResizingComboBox", "ComboBox",
    "Slider", "SpinBox", "TextField", "RadioButton", "Button",
}
# Containers that mean "this control lives inside a popup dialog".
DIALOG_TYPES = {"NavigableDialog", "NavigableMessageDialog", "Dialog", "Popup"}
# Card containers.
CARD_TYPES = {"GroupBox", "VbSettingsCard"}
# StreamingPreferences members that are NOT persisted preference state
# (methods, enum constants, signals) — excluded from the "prefs" identity.
PREF_EXCLUDE_RE = re.compile(
    r"^(save|reload|retranslate|applyPreset|getDefaultBitrate|getFpsChoices|"
    r"[A-Z0-9_]+|.*Changed)$"
)

OBJ_OPEN_RE = re.compile(r"^(\s*)([A-Za-z_][A-Za-z0-9_.]*)\s*\{")
ID_RE = re.compile(r"^\s*id:\s*([A-Za-z_][A-Za-z0-9_]*)\s*$")
TEXT_RE = re.compile(r'^\s*text:\s*qsTr\("((?:[^"\\]|\\.)*)"\)')
TOOLTIP_RE = re.compile(r'^\s*ToolTip\.text:\s*qsTr\("((?:[^"\\]|\\.)*)"\)')
CAT_RE = re.compile(r"visible:.*settingsPage\.category\s*===\s*(\d+)")
PREF_RE = re.compile(r"StreamingPreferences\.([A-Za-z_][A-Za-z0-9_]*)")


def brace_delta(line):
    """Net brace count for a line, ignoring braces inside string literals
    and line comments."""
    net_open = 0
    opens = 0
    in_str = None
    i = 0
    n = len(line)
    while i < n:
        c = line[i]
        if in_str:
            if c == "\\":
                i += 2
                continue
            if c == in_str:
                in_str = None
        elif c in ('"', "'"):
            in_str = c
        elif c == "/" and i + 1 < n and line[i + 1] == "/":
            break  # line comment
        elif c == "{":
            net_open += 1
            opens += 1
        elif c == "}":
            net_open -= 1
        i += 1
    return net_open, opens


def parse_file(path, source_name, category_of_card=None, base_ctx=None):
    """Parse one QML file; returns (controls, cards).

    category_of_card: optional fn(card_stack) -> category override used when
    this file is an embedded component (ClipboardSettings) whose category is
    decided by its instantiation site in SettingsView.qml.
    """
    with open(path, "r", encoding="utf-8") as f:
        lines = f.read().split("\n")

    stack = []  # list of dicts: {type, id, line, category, is_card, is_dialog, is_control, rec}
    controls = []
    cards = []
    last_label_text = {}  # depth -> last Label/Text qsTr seen at that depth
    global_pos = 0

    depth = 0
    for lineno, line in enumerate(lines, 1):
        m = OBJ_OPEN_RE.match(line)
        net, opens = brace_delta(line)
        opened_obj = None
        if m and opens >= 1:
            qtype = m.group(2)
            # Only treat Uppercase-initial tokens as QML object declarations
            # (filters out JS blocks like `if (...) {`, `function foo() {`).
            if qtype[0].isupper() and net >= 1:
                opened_obj = {
                    "type": qtype,
                    "id": None,
                    "line": lineno,
                    "depth": depth,
                    "is_card": qtype in CARD_TYPES,
                    "is_dialog": qtype in DIALOG_TYPES,
                    "is_control": qtype in CONTROL_TYPES,
                    "category": None,
                    "texts": [],
                    "tooltip": None,
                    "prefs": set(),
                    "pending_label": last_label_text.get(depth),
                }

        # Property capture applies to innermost open object.
        if stack:
            cur = stack[-1]
            im = ID_RE.match(line)
            if im and cur["owner_depth"] == depth - 1 and cur["obj"]["id"] is None:
                cur["obj"]["id"] = im.group(1)
            tm = TEXT_RE.match(line)
            if tm:
                for entry in reversed(stack):
                    if entry["obj"]["is_control"] or entry["obj"]["is_card"]:
                        entry["obj"]["texts"].append(tm.group(1))
                        break
                # remember Label text as a potential label for a following combo
                if not cur["obj"]["is_control"]:
                    last_label_text[cur["owner_depth"]] = tm.group(1)
            ttm = TOOLTIP_RE.match(line)
            if ttm:
                for entry in reversed(stack):
                    if entry["obj"]["is_control"]:
                        if entry["obj"]["tooltip"] is None:
                            entry["obj"]["tooltip"] = ttm.group(1)
                        break
            cm = CAT_RE.search(line)
            if cm:
                for entry in reversed(stack):
                    if entry["obj"]["is_card"] or entry["obj"]["type"] in ("Text", "Label"):
                        if entry["obj"]["category"] is None:
                            entry["obj"]["category"] = int(cm.group(1))
                        break
            for pm in PREF_RE.finditer(line.split("//")[0]):
                name = pm.group(1)
                if not PREF_EXCLUDE_RE.match(name):
                    for entry in reversed(stack):
                        if entry["obj"]["is_control"]:
                            entry["obj"]["prefs"].add(name)
                            break

        if opened_obj is not None:
            stack.append({"obj": opened_obj, "owner_depth": depth})

        depth += net

        # Pop closed objects.
        while stack and depth <= stack[-1]["owner_depth"]:
            closed = stack.pop()["obj"]
            enclosing_cards = [e["obj"] for e in stack if e["obj"]["is_card"]]
            in_dialog = any(e["obj"]["is_dialog"] for e in stack) or closed["is_dialog"]
            if closed["is_card"]:
                cards.append({
                    "id": closed["id"],
                    "line": closed["line"],
                    "category": closed["category"],
                    "source": source_name,
                })
            if closed["is_control"]:
                card = enclosing_cards[0] if enclosing_cards else None
                label = closed["texts"][0] if closed["texts"] else None
                if label is None:
                    label = closed["pending_label"]
                controls.append({
                    "type": closed["type"],
                    "id": closed["id"],
                    "label": label,
                    "tooltip": closed["tooltip"],
                    "prefs": sorted(closed["prefs"]),
                    "card": (card["id"] if card else (base_ctx or {}).get("card")),
                    "card_line": closed["line"],
                    "in_dialog": in_dialog,
                    "source": source_name,
                    "line": closed["line"],
                })
                global_pos += 1

    return controls, cards


def main():
    out_path = None
    args = sys.argv[1:]
    if args and args[0] == "--out":
        out_path = args[1]

    controls, cards = parse_file(SETTINGS_QML, "SettingsView.qml")
    card_cat = {c["id"]: c["category"] for c in cards if c["id"]}

    # Controls inherit category from their enclosing card.
    for c in controls:
        c["category"] = card_cat.get(c["card"])

    # The embedded ClipboardSettings component: category = the card that
    # instantiates `ClipboardSettings {` in SettingsView.qml.
    with open(SETTINGS_QML, "r", encoding="utf-8") as f:
        sv = f.read()
    clip_card = None
    idx = sv.find("ClipboardSettings {")
    if idx >= 0:
        # nearest preceding card id
        for m in re.finditer(r"id:\s*(\w*GroupBox\w*)", sv[:idx]):
            clip_card = m.group(1)
    if os.path.exists(CLIPBOARD_QML) and clip_card:
        clip_controls, _ = parse_file(
            CLIPBOARD_QML, "ClipboardSettings.qml", base_ctx={"card": clip_card})
        for c in clip_controls:
            c["card"] = clip_card
            c["category"] = card_cat.get(clip_card)
        controls.extend(clip_controls)

    # Filter: keep only controls that belong to a categorized settings card.
    # (Header back button, dialog Ok/Cancel chrome etc. have no card/category.)
    manifest_controls = [c for c in controls if c["category"] is not None]

    # Deterministic ordering: category, then card declaration line, then line.
    manifest_controls.sort(key=lambda c: (c["category"], c["card_line"], c["source"], c["line"]))
    for i, c in enumerate(manifest_controls):
        c["global_pos"] = i
    # per-card position
    by_card = {}
    for c in manifest_controls:
        by_card.setdefault(c["card"], []).append(c)
    for card_id, items in by_card.items():
        for j, c in enumerate(items):
            c["card_pos"] = j

    cat_labels = {}
    mcat = re.search(r"model:\s*\[(.*?)\]", sv, re.S)
    if mcat:
        for i, lm in enumerate(re.finditer(r'label:\s*qsTr\("([^"]+)"\)', mcat.group(1))):
            cat_labels[i] = lm.group(1)
    for c in manifest_controls:
        c["category_label"] = cat_labels.get(c["category"], str(c["category"]))

    result = {
        "schema": "bl2263-settings-ia-manifest/1",
        "categories": cat_labels,
        "cards": sorted(
            [c for c in cards if c["category"] is not None],
            key=lambda c: (c["category"], c["line"])),
        "control_count": len(manifest_controls),
        "controls": manifest_controls,
    }
    text = json.dumps(result, indent=2, sort_keys=True, ensure_ascii=False)
    if out_path:
        with open(out_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text + "\n")
        print("wrote %s (%d controls, %d cards)" % (
            out_path, len(manifest_controls), len(result["cards"])))
    else:
        print(text)


if __name__ == "__main__":
    main()
