#!/usr/bin/env python3
"""steam-sync-host-games.py -- one-click Steam library tiles for a Vibemis host (BL-1786, P3.10 #4)

Turns every app on a paired Vibemis host into its own non-Steam Steam shortcut whose target is
the Vibemis AppImage launched straight into that game (`vibemis stream "<host>" "<app>"`). Once
synced, each host game IS a tile in the Steam library -- one click in Game Mode streams it
directly, no menus. This is the "MoonDeckBuddy-style" one-click flow the maintainer asked for,
but with fewer moving parts: no host-side companion service, no Decky plugin -- just this script
talking to the Vibemis CLI and Steam's own shortcuts.vdf.

Design doc: docs/STEAM_ONE_CLICK_DESIGN.md (recommendation, trade-offs, on-device test plan).

Pipeline
--------
1. Run `<vibemis-appimage> list "<host>" --csv` to get the host's app list (name, hidden flag,
   and a Boxart URL column that is the *already-resolved* path to a cached cover, if Vibemis has
   one cached for that host -- see the design doc for why this script never talks to the box art
   cache layout directly).
2. For each app (skipping Hidden apps by default), compute a Steam shortcut entry whose Exe is
   the Vibemis AppImage and whose LaunchOptions is `stream "<host>" "<app>"`.
3. Parse the user's shortcuts.vdf (binary VDF), update-in-place any entry this script created on
   a previous run (matched by Exe + LaunchOptions, not by array index or AppName, so renaming the
   display name never creates a duplicate), append new entries for anything new, back up the
   original file with a timestamp, round-trip-verify the serializer against the *existing* file
   before writing a byte, then write + read back to confirm.
4. If a game has a cached cover (a real `file://` Boxart URL, not the qrc placeholder), copy it
   into Steam's grid/ art folder under the Steam-native appid so the library tile shows real
   cover art instead of the generic "unknown application" icon.

Dry-run by default -- prints the exact plan (create/update/skip counts, one line per app) and
touches nothing. Pass --apply to actually write. Steam must be closed before --apply (it keeps
shortcuts.vdf in memory and overwrites this file with its in-memory copy on exit); the script
refuses to write while steam.exe/steam is running unless --force.

Pure standard library. Cross-platform Steam discovery (Windows/Linux/macOS), but the intended
target is SteamOS (Linux) -- see docs/STEAM_ONE_CLICK_DESIGN.md.

Usage
-----
    # Dry run: see what would change (safe to run anytime, including while Steam is open)
    python3 steam-sync-host-games.py "Navid-PC"

    # Apply (Steam must be closed first)
    python3 steam-sync-host-games.py "Navid-PC" --apply

    # List the Vibemis-managed shortcuts already in shortcuts.vdf (any host, or filter with a host arg)
    python3 steam-sync-host-games.py --list
    python3 steam-sync-host-games.py "Navid-PC" --list

    # Remove shortcuts for apps no longer on the host (off by default -- opt in explicitly)
    python3 steam-sync-host-games.py "Navid-PC" --apply --prune-missing

Override the AppImage path with --appimage or $VIBEMIS_APPIMAGE (default:
~/Applications/Vibemis.AppImage, matching install-vibemis-desktop.sh).
"""
from __future__ import annotations

import argparse
import binascii
import csv
import io
import os
import platform
import shutil
import subprocess
import sys
import time

# ---------------------------------------------------------------------------
# Binary VDF (Valve Data Format) reader / writer
#
# Token types inside a map:
#   0x00  nested map     -> key (cstring), then children, terminated by 0x08
#   0x01  string         -> key (cstring), value (cstring)
#   0x02  int32          -> key (cstring), 4 bytes little-endian (unsigned)
#   0x08  end of map
# Strings are UTF-8, NUL-terminated. The whole file is one root map whose only
# key is "shortcuts" -> { "0": {entry}, "1": {entry}, ... }.
# ---------------------------------------------------------------------------


class _Reader:
    def __init__(self, data: bytes):
        self.d = data
        self.i = 0

    def cstring(self) -> str:
        end = self.d.index(b"\x00", self.i)
        s = self.d[self.i:end].decode("utf-8")
        self.i = end + 1
        return s

    def byte(self) -> int:
        b = self.d[self.i]
        self.i += 1
        return b

    def int32(self) -> int:
        v = int.from_bytes(self.d[self.i:self.i + 4], "little", signed=False)
        self.i += 4
        return v

    def read_map(self) -> dict:
        out: dict = {}
        while True:
            t = self.byte()
            if t == 0x08:          # end of map
                return out
            key = self.cstring()
            if t == 0x00:
                out[key] = self.read_map()
            elif t == 0x01:
                out[key] = self.cstring()
            elif t == 0x02:
                out[key] = self.int32()
            else:
                raise ValueError(f"Unknown VDF token 0x{t:02x} at offset {self.i}")


def parse(data: bytes) -> dict:
    return _Reader(data).read_map()


def _cstr(s: str) -> bytes:
    return s.encode("utf-8") + b"\x00"


def serialize_map(m: dict) -> bytes:
    out = bytearray()
    for key, val in m.items():
        if isinstance(val, dict):
            out += b"\x00" + _cstr(key) + serialize_map(val)
        elif isinstance(val, bool):                     # guard: bool before int
            out += b"\x02" + _cstr(key) + int(val).to_bytes(4, "little")
        elif isinstance(val, int):
            out += b"\x02" + _cstr(key) + (val & 0xFFFFFFFF).to_bytes(4, "little")
        elif isinstance(val, str):
            out += b"\x01" + _cstr(key) + _cstr(val)
        else:
            raise TypeError(f"Unsupported VDF value type for {key!r}: {type(val)}")
    out += b"\x08"                                       # end of this map
    return bytes(out)


def roundtrip_ok(original: bytes) -> bool:
    try:
        return serialize_map(parse(original)) == original
    except Exception:
        return False


# ---------------------------------------------------------------------------
# Steam discovery (same conventions as the steam-shortcut skill's add_shortcut.py)
# ---------------------------------------------------------------------------


def steam_root() -> str | None:
    sysname = platform.system()
    candidates: list[str] = []
    if sysname == "Windows":
        try:
            import winreg
            for hive, sub in ((winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam"),
                              (winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\WOW6432Node\Valve\Steam")):
                try:
                    with winreg.OpenKey(hive, sub) as k:
                        val = winreg.QueryValueEx(k, "SteamPath" if hive == winreg.HKEY_CURRENT_USER else "InstallPath")[0]
                        candidates.append(val.replace("/", "\\"))
                except OSError:
                    pass
        except Exception:
            pass
        candidates += [r"C:\Program Files (x86)\Steam", r"C:\Program Files\Steam"]
    elif sysname == "Darwin":
        candidates.append(os.path.expanduser("~/Library/Application Support/Steam"))
    else:  # Linux / SteamOS
        home = os.path.expanduser("~")
        candidates += [
            os.path.join(home, ".steam", "steam"),
            os.path.join(home, ".local", "share", "Steam"),
            os.path.join(home, ".var", "app", "com.valvesoftware.Steam", "data", "Steam"),
        ]
    for c in candidates:
        if c and os.path.isdir(os.path.join(c, "userdata")):
            return c
    return None


def find_users(root: str) -> list[str]:
    ud = os.path.join(root, "userdata")
    users = []
    for name in os.listdir(ud):
        if name.isdigit() and os.path.isdir(os.path.join(ud, name, "config")):
            users.append(name)
    return users


def vdf_path(root: str, user: str) -> str:
    return os.path.join(root, "userdata", user, "config", "shortcuts.vdf")


def grid_dir(root: str, user: str) -> str:
    return os.path.join(root, "userdata", user, "config", "grid")


def steam_running() -> bool:
    try:
        if platform.system() == "Windows":
            out = os.popen('tasklist /FI "IMAGENAME eq steam.exe" /NH').read().lower()
            return "steam.exe" in out
        out = os.popen("pgrep -x steam 2>/dev/null").read().strip()
        return bool(out)
    except Exception:
        return False


# ---------------------------------------------------------------------------
# Shortcut construction
# ---------------------------------------------------------------------------


def gen_appid(exe_quoted: str, name: str) -> int:
    """Legacy non-Steam appid: crc32(exe+name) with the high bit set. Steam also uses this
    value to locate custom grid/library artwork (grid/<appid>.png, grid/<appid>p.png)."""
    crc = binascii.crc32((exe_quoted + name).encode("utf-8")) & 0xFFFFFFFF
    return crc | 0x80000000


def make_entry(appid: int, app_name: str, exe: str, start_dir: str, launch_options: str, icon: str) -> dict:
    return {
        "appid": appid,
        "AppName": app_name,
        "Exe": f'"{exe}"',
        "StartDir": f'"{start_dir}"',
        "icon": icon,
        "ShortcutPath": "",
        "LaunchOptions": launch_options,
        "IsHidden": 0,
        "AllowDesktopConfig": 1,
        "AllowOverlay": 1,
        "OpenVR": 0,
        "Devkit": 0,
        "DevkitGameID": "",
        "DevkitOverrideAppID": 0,
        "LastPlayTime": 0,
        "FlatpakAppID": "",
        "tags": {},
    }


def launch_options_for(host: str, app: str) -> str:
    return f'stream "{host}" "{app}"'


def is_vibemis_entry(entry: dict, exe_quoted: str, host: str | None = None) -> bool:
    if entry.get("Exe") != exe_quoted:
        return False
    lo = entry.get("LaunchOptions", "")
    if not lo.startswith('stream "'):
        return False
    if host is not None:
        return lo.startswith(f'stream "{host}" ')
    return True


# ---------------------------------------------------------------------------
# Vibemis CLI -- app list with resolved (already-cached) box art paths
# ---------------------------------------------------------------------------


class HostApp:
    __slots__ = ("name", "hidden", "boxart_path")

    def __init__(self, name: str, hidden: bool, boxart_path: str | None):
        self.name = name
        self.hidden = hidden
        self.boxart_path = boxart_path


def file_url_to_path(url: str) -> str | None:
    """Best-effort file:// URL -> local path. Returns None for non-file URLs
    (e.g. the qrc:/res/no_app_image.png placeholder Vibemis uses when a cover
    hasn't been cached yet)."""
    if not url or not url.startswith("file://"):
        return None
    path = url[len("file://"):]
    # Windows-style file:///C:/... URLs carry a leading slash before the drive letter.
    if len(path) >= 3 and path[0] == "/" and path[2] == ":":
        path = path[1:]
    return path


def list_host_apps(appimage: str, host: str) -> list[HostApp]:
    try:
        proc = subprocess.run(
            [appimage, "list", host, "--csv"],
            capture_output=True, text=True, encoding="utf-8", timeout=45,
        )
    except FileNotFoundError:
        die(f"Vibemis AppImage not found/executable at: {appimage}", 2)
    except subprocess.TimeoutExpired:
        die(f"`vibemis list \"{host}\" --csv` timed out (host unreachable / not paired?)", 5)

    if proc.returncode != 0:
        detail = (proc.stderr or proc.stdout or "").strip()
        die(f"`vibemis list \"{host}\" --csv` failed (exit {proc.returncode}): {detail}", 5)

    rows = list(csv.reader(io.StringIO(proc.stdout)))
    if not rows:
        die(f"No output from `vibemis list \"{host}\" --csv` -- is the host paired and reachable?", 5)

    header = [h.strip() for h in rows[0]]
    try:
        idx_name = header.index("Name")
        idx_hidden = header.index("Hidden")
        idx_boxart = header.index("Boxart URL")
    except ValueError:
        die(f"Unexpected `vibemis list --csv` header: {header!r} (Vibemis CLI output format changed?)", 5)

    apps: list[HostApp] = []
    for row in rows[1:]:
        if len(row) != len(header):
            print(f"warning: skipping malformed CSV row (column count mismatch): {row!r}", file=sys.stderr)
            continue
        name = row[idx_name]
        if not name:
            continue
        hidden = row[idx_hidden].strip().lower() == "true"
        boxart_path = file_url_to_path(row[idx_boxart])
        if boxart_path and not os.path.isfile(boxart_path):
            boxart_path = None
        apps.append(HostApp(name, hidden, boxart_path))
    return apps


# ---------------------------------------------------------------------------
# CLI plumbing
# ---------------------------------------------------------------------------


def die(msg: str, code: int) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    raise SystemExit(code)


def default_appimage() -> str:
    env = os.environ.get("VIBEMIS_APPIMAGE")
    if env:
        return env
    return os.path.join(os.path.expanduser("~"), "Applications", "Vibemis.AppImage")


def resolve_steam(args) -> tuple[str, str]:
    root = args.steam_root or steam_root()
    if not root:
        die("could not locate a Steam installation. Pass --steam-root.", 2)
    users = find_users(root)
    if not users:
        die(f"no user accounts under {root}{os.sep}userdata", 2)
    if len(users) > 1 and not args.user:
        die("multiple Steam users found; pass --user <id>. Options: " + ", ".join(users), 2)
    user = args.user or users[0]
    if user not in users:
        die(f"user {user} not found. Options: {', '.join(users)}", 2)
    return root, user


def load_shortcuts(path: str) -> dict:
    if os.path.exists(path):
        original = open(path, "rb").read()
    else:
        original = serialize_map({"shortcuts": {}})
    if not roundtrip_ok(original):
        die("round-trip self-check failed on the existing shortcuts.vdf -- refusing to touch it "
            "so nothing gets corrupted. Inspect it (and any *.bak files) by hand.", 4)
    return parse(original)


def cmd_list(args) -> int:
    root, user = resolve_steam(args)
    path = vdf_path(root, user)
    root_map = load_shortcuts(path)
    shortcuts = root_map.get("shortcuts", {})
    appimage = os.path.abspath(args.appimage or default_appimage())
    exe_quoted = f'"{appimage}"'

    found = 0
    for idx in sorted(shortcuts, key=lambda k: int(k)):
        entry = shortcuts[idx]
        if is_vibemis_entry(entry, exe_quoted, args.host):
            found += 1
            print(f"  [{idx}] {entry.get('AppName')}  ->  {entry.get('LaunchOptions')}")
    scope = f" for host \"{args.host}\"" if args.host else ""
    print(f"{found} Vibemis-managed shortcut(s){scope} in {path}")
    return 0


def cmd_sync(args) -> int:
    host = args.host
    appimage = os.path.abspath(args.appimage or default_appimage())
    if not args.apply and not os.path.exists(appimage):
        # Dry-run can still proceed device-independently (useful for authoring/testing the
        # script off-device), but flag it clearly since the app list step will fail.
        print(f"note: Vibemis AppImage not found at {appimage} (only matters once the plan runs "
              f"`vibemis list`, and always matters for --apply)", file=sys.stderr)

    root, user = resolve_steam(args)
    path = vdf_path(root, user)
    gdir = grid_dir(root, user)

    apps = list_host_apps(appimage, host)
    if not apps:
        die(f"host \"{host}\" has no apps (or all were filtered) -- nothing to sync.", 5)

    visible = [a for a in apps if args.include_hidden or not a.hidden]
    skipped_hidden = len(apps) - len(visible)

    root_map = load_shortcuts(path)
    shortcuts = root_map.setdefault("shortcuts", {})
    exe_quoted = f'"{appimage}"'
    start_dir = os.path.dirname(appimage) or "."

    # Index existing Vibemis entries for this host by LaunchOptions so re-runs update in place.
    existing_by_lo: dict[str, str] = {}
    for idx, entry in shortcuts.items():
        if is_vibemis_entry(entry, exe_quoted, host):
            existing_by_lo[entry.get("LaunchOptions", "")] = idx

    creates, updates, art_writes, quoting_skips = [], [], [], []
    seen_lo = set()

    for app in visible:
        if '"' in host or '"' in app.name:
            quoting_skips.append(app.name)
            continue
        lo = launch_options_for(host, app.name)
        seen_lo.add(lo)
        app_display_name = f"{app.name} — {host}"  # em dash disambiguates by host
        appid = gen_appid(exe_quoted, app_display_name)
        icon = app.boxart_path or ""
        entry = make_entry(appid, app_display_name, appimage, start_dir, lo, icon)

        if lo in existing_by_lo:
            idx = existing_by_lo[lo]
            updates.append((idx, app.name, appid))
            if args.apply:
                shortcuts[idx] = entry
        else:
            idx = str(max((int(k) for k in shortcuts), default=-1) + 1)
            creates.append((idx, app.name, appid))
            if args.apply:
                shortcuts[idx] = entry

        if app.boxart_path:
            art_writes.append((appid, app.boxart_path, app.name))

    prunes = []
    if args.prune_missing:
        for lo, idx in existing_by_lo.items():
            if lo not in seen_lo:
                prunes.append((idx, shortcuts[idx].get("AppName")))
                if args.apply:
                    del shortcuts[idx]

    # ---- Report the plan -----------------------------------------------------------------
    verb = "Applying" if args.apply else "Would apply (dry-run; pass --apply to write)"
    print(f"{verb}: {len(creates)} new, {len(updates)} updated, {len(prunes)} pruned, "
          f"{skipped_hidden} hidden app(s) skipped.")
    for idx, name, appid in creates:
        print(f"  + create [{idx}] \"{name}\"  (appid {appid})")
    for idx, name, appid in updates:
        print(f"  ~ update [{idx}] \"{name}\"  (appid {appid})")
    for idx, name in prunes:
        print(f"  - prune  [{idx}] \"{name}\"")
    for name in quoting_skips:
        print(f"  ! skip \"{name}\" -- name or host contains a double quote; can't be safely "
              f"embedded in Steam LaunchOptions", file=sys.stderr)
    with_art = sum(1 for a in visible if a.boxart_path)
    print(f"Cover art available for {with_art}/{len(visible)} app(s) "
          f"(only apps already cached by browsing this host once in the Vibemis GUI/app-grid "
          f"have a cached cover -- see docs/STEAM_ONE_CLICK_DESIGN.md).")

    if not args.apply:
        print(f"\nDry run only -- nothing written. Re-run with --apply "
              f"(Steam must be closed) to write {path}.")
        return 0

    if not creates and not updates and not prunes:
        print("Nothing to change.")
        return 0

    if steam_running() and not args.force:
        die("Steam appears to be running. Close it first (it rewrites shortcuts.vdf from memory "
            "on exit and would silently wipe this change), or pass --force if you're certain "
            "Steam is not running.", 3)

    # ---- Write: backup, verify serializer, write, read back ------------------------------
    if os.path.exists(path):
        stamp = time.strftime("%Y%m%dT%H%M%S")
        backup = f"{path}.bak-{stamp}"
        shutil.copy2(path, backup)
        print(f"Backup -> {backup}")
    else:
        os.makedirs(os.path.dirname(path), exist_ok=True)

    new_bytes = serialize_map(root_map)
    with open(path, "wb") as f:
        f.write(new_bytes)

    readback = open(path, "rb").read()
    ok = readback == new_bytes
    print(f"Wrote {len(new_bytes)} bytes to {path}. Readback OK: {ok}")
    if not ok:
        die("readback verification failed after writing shortcuts.vdf -- restore from the "
            "backup above immediately.", 6)

    # ---- Grid artwork (best-effort; never blocks the shortcuts.vdf result) ---------------
    if art_writes:
        os.makedirs(gdir, exist_ok=True)
        written = 0
        for appid, src, name in art_writes:
            for suffix in ("p", ""):  # <appid>p.png = portrait "library capsule"; <appid>.png = capsule
                dest = os.path.join(gdir, f"{appid}{suffix}.png")
                if os.path.exists(dest) and not args.overwrite_art:
                    continue
                try:
                    shutil.copy2(src, dest)
                    written += 1
                except OSError as e:
                    print(f"warning: could not write grid art for \"{name}\" -> {dest}: {e}",
                          file=sys.stderr)
        print(f"Wrote {written} grid artwork file(s) to {gdir}")

    print("\nReopen Steam and go to Game Mode -- the synced games appear as library tiles "
          "under Non-Steam Games. One click streams them directly.")
    return 0


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        description="Sync a Vibemis host's app list into Steam library shortcuts (BL-1786).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("host", nargs="?",
                     help="Host name/UUID/IP as known to Vibemis (same value you'd pass to "
                          "`vibemis list <host>` / `vibemis stream <host> <app>`)")
    ap.add_argument("--apply", action="store_true",
                     help="Write changes. Default is dry-run: print the plan, write nothing.")
    ap.add_argument("--list", dest="list_mode", action="store_true",
                     help="List existing Vibemis-managed shortcuts (filtered to --host if given) "
                          "and exit. Read-only, safe while Steam is running.")
    ap.add_argument("--user", help="Steam account id under userdata/ (auto-detected if only one)")
    ap.add_argument("--steam-root", help="Override Steam install dir auto-detection")
    ap.add_argument("--appimage",
                     help="Path to the Vibemis AppImage (default: $VIBEMIS_APPIMAGE or "
                          "~/Applications/Vibemis.AppImage)")
    ap.add_argument("--include-hidden", action="store_true",
                     help="Also sync apps the host has marked Hidden (skipped by default)")
    ap.add_argument("--overwrite-art", action="store_true",
                     help="Overwrite existing grid artwork files (default: only fill in gaps, "
                          "never clobber art you've customized in Steam)")
    ap.add_argument("--prune-missing", action="store_true",
                     help="Remove Vibemis-managed shortcuts for this host whose app is no longer "
                          "in the host's current list (default: leave stale entries alone)")
    ap.add_argument("--force", action="store_true",
                     help="Write even if Steam appears to be running (risky -- Steam may "
                          "overwrite shortcuts.vdf again on its next exit)")
    args = ap.parse_args(argv)

    if args.list_mode:
        return cmd_list(args)

    if not args.host:
        ap.error("host is required unless --list is given")

    return cmd_sync(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
