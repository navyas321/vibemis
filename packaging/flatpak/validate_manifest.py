#!/usr/bin/env python3
"""BL-2231 flatpak manifest validation — called by .github/workflows/flatpak.yml.

This code deliberately lives OUTSIDE .github/workflows/: the BL-2213
audio-invariants guard (scripts/check-audio-invariants.sh, check 7) greps the
workflow files for forbidden SDL3/sdl2-compat adoption strings, and this
enforcement code must NAME those strings to forbid them. Keeping it here keeps
the workflow files literal-free (no false positive) while the enforcement
stays fully active in CI.

Run from the repo root:  python3 packaging/flatpak/validate_manifest.py
"""
import json
import os
import sys

try:
    import yaml
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pyyaml"])
    import yaml

base = "packaging/flatpak"
manifest_path = os.path.join(base, "io.github.navyas321.Vibemis.yml")
with open(manifest_path, encoding="utf-8") as f:
    manifest = yaml.safe_load(f)

assert manifest["app-id"] == "io.github.navyas321.Vibemis", manifest["app-id"]
assert manifest["command"] == "vibemis"

# Every type:file source must exist next to the manifest.
missing = []
for mod in manifest["modules"]:
    for src in mod.get("sources", []):
        if isinstance(src, dict) and src.get("type") == "file":
            p = os.path.join(base, src["path"])
            if not os.path.isfile(p):
                missing.append(p)
assert not missing, f"manifest references missing files: {missing}"

for j in ("flathub.json", "VkLayer_FROG_gamescope_wsi.x86_64.json"):
    with open(os.path.join(base, j), encoding="utf-8") as f:
        json.load(f)

# AUDIO INVARIANT GUARD (BL-2213): the manifest must build REAL SDL2
# and must never grow SDL3 / sdl2-compat modules or sources.
names = [m["name"] for m in manifest["modules"]]
assert "SDL2" in names, f"real SDL2 module missing: {names}"
bad = [n for n in names if n.lower() in ("sdl3", "sdl2-compat")]
assert not bad, f"FORBIDDEN SDL module(s) (BL-2213 audio invariant): {bad}"

sdl2 = next(m for m in manifest["modules"] if m["name"] == "SDL2")
git_srcs = [s for s in sdl2["sources"] if isinstance(s, dict) and s.get("type") == "git"]
for s in git_srcs:
    assert "sdl2-compat" not in s.get("url", ""), f"sdl2-compat source URL forbidden: {s['url']}"
    assert s.get("tag", "release-2.").startswith("release-2."), \
        f"SDL2 module must pin a real SDL2-line tag, got {s.get('tag')}"
opts = sdl2.get("build-options", {}).get("config-opts", [])
assert "-DSDL_PULSEAUDIO=ON" in opts, "SDL2 must be built with PulseAudio"

# LIBDIR GUARD (first-build RCA, 2026-07-21): on the KDE SDK, cmake/meson
# default to /app/lib64, which qmake's link_pkgconfig never searches (build
# breaks) and the deployed app never loads from (RPATH + LD_LIBRARY_PATH are
# /app/lib) — the runtime's own compat SDL would silently win at app runtime.
assert "-DCMAKE_INSTALL_LIBDIR=lib" in opts, \
    "SDL2 must install to /app/lib (lib64 is invisible to qmake AND to the app at runtime)"
for m in manifest["modules"]:
    mopts = list(m.get("config-opts") or []) + \
        list(m.get("build-options", {}).get("config-opts") or [])
    if m.get("buildsystem") == "meson":
        assert "--libdir=/app/lib" in mopts, \
            f"meson module {m['name']} must pin --libdir=/app/lib (SDK default is lib64)"
    elif m.get("buildsystem") in ("cmake", "cmake-ninja"):
        assert "-DCMAKE_INSTALL_LIBDIR=lib" in mopts, \
            f"cmake module {m['name']} must pin -DCMAKE_INSTALL_LIBDIR=lib (SDK default is lib64)"

print("manifest OK:", manifest_path)
print("modules:", ", ".join(names))
