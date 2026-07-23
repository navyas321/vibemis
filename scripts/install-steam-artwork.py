#!/usr/bin/env python3
"""Install Vibemis's library artwork for its own Steam shortcut.

WHY VIBEMIS LOOKED BROKEN IN GAME MODE
--------------------------------------
A non-Steam shortcut has no artwork of its own, so Steam renders it as a flat coloured
rectangle with the app name in plain text. Every real app in the library ships art, so
Vibemis was the one entry that looked like a placeholder -- while ES-DE, sitting right
next to it, showed a full hero and logo.

The art has to land in `userdata/<user>/config/grid/` under the shortcut's appid:

    <appid>p.png       600x900    portrait capsule  <- the library grid tile
    <appid>.png        920x430    landscape capsule
    <appid>_hero.png   1920x620   hero banner behind the detail page
    <appid>_logo.png   transparent, drawn over the hero by Steam
    <appid>_icon.png   256x256

GETTING THE APPID RIGHT
----------------------
Modern Steam stores an `appid` key inside each shortcuts.vdf entry; that value is
authoritative and is what we use. Only when it is absent do we fall back to the legacy
derivation, crc32(quoted-exe + AppName) | 0x80000000 -- which is fragile because it
depends on the Exe string matching byte-for-byte, quotes included. Deriving when we
could have read is how artwork ends up written under an appid nothing references.

Usage:
    python3 scripts/install-steam-artwork.py            # install for every Steam user
    python3 scripts/install-steam-artwork.py --dry-run  # show what would happen
    python3 scripts/install-steam-artwork.py --name "Vibemis (Beta)"

Read-only with respect to shortcuts.vdf: this only ever writes PNGs into grid/.
"""
from __future__ import annotations

import argparse
import importlib.util
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
DEFAULT_ART = os.path.join(REPO, "app", "res", "steam")

# Steam's grid filename suffix  ->  the asset that belongs there.
ASSETS = [
    ("p", "vibemis_p.png"),
    ("", "vibemis.png"),
    ("_hero", "vibemis_hero.png"),
    ("_logo", "vibemis_logo.png"),
    ("_icon", "vibemis_icon.png"),
]


def load_steam_helpers():
    """Reuse the binary-VDF parser and Steam discovery from steam-sync-host-games.py.

    That file already parses shortcuts.vdf, finds the Steam root across the several
    layouts (native, Flatpak, SteamOS), and derives legacy appids. A second copy here
    would be a second thing to keep correct.
    """
    path = os.path.join(HERE, "steam-sync-host-games.py")
    if not os.path.exists(path):
        sys.exit(f"missing {path} -- it provides the shortcuts.vdf parser")
    spec = importlib.util.spec_from_file_location("steam_sync", path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["steam_sync"] = mod
    spec.loader.exec_module(mod)
    return mod


def find_vibemis_shortcuts(shortcuts: dict, want_name: str):
    """Yield (appid, name) for the app's OWN shortcut(s).

    Deliberately not "any shortcut whose Exe is the Vibemis AppImage":
    scripts/steam-sync-host-games.py creates one shortcut per host game, all launching
    the same AppImage with `stream` launch options, and each already carries the game's
    own box art. Overwriting those with the Vibemis tile would replace real per-game
    artwork with a generic one. Match on the app's own name, and skip anything carrying
    stream launch options.
    """
    for entry in shortcuts.values():
        if not isinstance(entry, dict):
            continue
        name = str(entry.get("AppName", "") or "")
        if name.strip().lower() != want_name.strip().lower():
            continue
        if "stream" in str(entry.get("LaunchOptions", "") or "").lower():
            continue
        appid = entry.get("appid")
        if isinstance(appid, int) and appid:
            yield appid & 0xFFFFFFFF, name
        else:
            mod = sys.modules["steam_sync"]
            yield mod.gen_appid(str(entry.get("Exe", "")), name), name


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--art-dir", default=DEFAULT_ART, help="directory holding the PNGs")
    ap.add_argument("--name", default="Vibemis", help="shortcut AppName to match")
    ap.add_argument("--dry-run", action="store_true", help="report, write nothing")
    ap.add_argument("--no-overwrite", action="store_true",
                    help="keep any artwork already present (e.g. hand-picked SteamGridDB art)")
    ap.add_argument("--steam-root", default=os.environ.get("VIBEMIS_STEAM_ROOT", ""),
                    help="Steam install root, when auto-detection misses it (Flatpak Steam, "
                         "a second drive). Also settable as VIBEMIS_STEAM_ROOT.")
    args = ap.parse_args()

    missing = [f for _, f in ASSETS if not os.path.exists(os.path.join(args.art_dir, f))]
    if missing:
        sys.exit(f"missing artwork in {args.art_dir}: {', '.join(missing)}\n"
                 f"Regenerate with: python3 scripts/gen-steam-artwork.py")

    mod = load_steam_helpers()
    root = args.steam_root or mod.steam_root()
    if root and not os.path.isdir(os.path.join(root, "userdata")):
        sys.exit(f"{root} has no userdata/ -- that is not a Steam root.")
    if not root:
        print("Steam does not appear to be installed here -- nothing to do.")
        return 0

    users = mod.find_users(root)
    if not users:
        print(f"No Steam user profiles under {root}/userdata -- nothing to do.")
        return 0

    total, found_any = 0, False
    for user in users:
        vdf = mod.vdf_path(root, user)
        if not os.path.exists(vdf):
            continue
        try:
            with open(vdf, "rb") as f:
                parsed = mod.parse(f.read())
        except (OSError, ValueError, IndexError) as e:
            print(f"warning: could not read {vdf}: {e}", file=sys.stderr)
            continue

        shortcuts = parsed.get("shortcuts", {}) or {}
        for appid, name in find_vibemis_shortcuts(shortcuts, args.name):
            found_any = True
            gdir = mod.grid_dir(root, user)
            print(f"user {user}: \"{name}\" -> appid {appid} ({gdir})")
            if not args.dry_run:
                os.makedirs(gdir, exist_ok=True)
            for suffix, filename in ASSETS:
                dest = os.path.join(gdir, f"{appid}{suffix}.png")
                if args.no_overwrite and os.path.exists(dest):
                    print(f"    keep    {os.path.basename(dest)} (already present)")
                    continue
                if args.dry_run:
                    print(f"    would write {os.path.basename(dest)}")
                    continue
                try:
                    shutil.copy2(os.path.join(args.art_dir, filename), dest)
                    print(f"    wrote   {os.path.basename(dest)}")
                    total += 1
                except OSError as e:
                    print(f"    warning: {dest}: {e}", file=sys.stderr)

    if not found_any:
        print(f"No Steam shortcut named \"{args.name}\" found.")
        print("Add Vibemis to Steam first (Games -> Add a Non-Steam Game), then re-run this.")
        return 0

    if not args.dry_run:
        print(f"\nInstalled {total} artwork file(s).")
        print("Fully restart Steam (not just Game Mode) to see the new tile -- Steam caches "
              "library art for the session.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
