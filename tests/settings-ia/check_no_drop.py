#!/usr/bin/env python3
"""BL-2263 zero-drop regression gate.

Asserts, comparing tests/settings-ia/manifest-before.json against
manifest-after.json (both produced by extract_manifest.py):

  1. Every control in BEFORE exists in AFTER exactly once.
     Identity = (id, label, sorted backing preference keys).
  2. Every control in AFTER exists in BEFORE (no orphans / duplicates).
  3. For each control, ONLY category / card / position / line changed —
     type, label, tooltip and preference keys are byte-identical.
  4. Control counts match.

Exit 0 = PASS (prints a category-by-category move summary).
Exit 1 = FAIL (prints every violation).

Usage:
    python3 tests/settings-ia/extract_manifest.py --out tests/settings-ia/manifest-after.json
    python3 tests/settings-ia/check_no_drop.py
"""

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BEFORE = os.path.join(HERE, "manifest-before.json")
AFTER = os.path.join(HERE, "manifest-after.json")

# The fields that constitute control IDENTITY (must never change).
IDENTITY = ("id", "label", "prefs")
# The fields that must stay equal for a matched control (invariants).
INVARIANT = ("type", "label", "tooltip", "prefs", "in_dialog")
# The fields allowed to change (the whole point of the IA overhaul).
ALLOWED_CHANGE = ("category", "category_label", "card", "card_pos",
                  "global_pos", "line", "card_line", "source")


def key(c):
    return (c["id"], c["label"], tuple(c["prefs"]))


def load(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def index(manifest):
    out = {}
    for c in manifest["controls"]:
        out.setdefault(key(c), []).append(c)
    return out


def main():
    before = load(BEFORE)
    after = load(AFTER)
    bi, ai = index(before), index(after)
    failures = []

    # 1+2: exact once-and-only-once matching in both directions.
    for k, bcs in sorted(bi.items(), key=lambda kv: str(kv[0])):
        acs = ai.get(k, [])
        if len(acs) != len(bcs):
            failures.append("DROP/DUP: %r appears %dx before, %dx after"
                            % (k, len(bcs), len(acs)))
    for k, acs in sorted(ai.items(), key=lambda kv: str(kv[0])):
        if k not in bi:
            failures.append("ORPHAN: %r appears in after only" % (k,))

    # 3: invariants unchanged for matched controls.
    for k in sorted(set(bi) & set(ai), key=str):
        for b, a in zip(bi[k], ai[k]):
            for f in INVARIANT:
                if b.get(f) != a.get(f):
                    failures.append("MUTATED %s: %r  %r -> %r"
                                    % (f, k, b.get(f), a.get(f)))

    # 4: counts.
    if before["control_count"] != after["control_count"]:
        failures.append("COUNT: %d before vs %d after"
                        % (before["control_count"], after["control_count"]))

    if failures:
        print("ZERO-DROP GATE: FAIL (%d violations)" % len(failures))
        for f in failures:
            print("  " + f)
        return 1

    # PASS: print the move summary.
    moves = []
    for k in sorted(set(bi) & set(ai), key=str):
        for b, a in zip(bi[k], ai[k]):
            if (b["category"], b["card"]) != (a["category"], a["card"]):
                moves.append((b, a))
    print("ZERO-DROP GATE: PASS — %d controls before == %d controls after, "
          "0 dropped, 0 orphaned, 0 mutated" %
          (before["control_count"], after["control_count"]))
    print("moves (%d):" % len(moves))
    for b, a in moves:
        print("  %-28s %s/%s -> %s/%s" % (
            b["id"] or repr((b["label"] or "")[:24]),
            b["category_label"], b["card"], a["category_label"], a["card"]))
    cats = {}
    for c in after["controls"]:
        cats[c["category_label"]] = cats.get(c["category_label"], 0) + 1
    print("after category counts: %s" % json.dumps(cats, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
