# Steam one-click library launch — design doc

**Status:** implemented (script + docs), pending on-device verification.
**Owner ask (verbatim):** "one-click launch from a SteamOS library game window directly into a
Vibemis session with that exact game open — like how MoonDeckBuddy works with DeckyLoader, but
design something that doesn't require installing so many things (DeckyLoader is already
installed on my device, so using it is fine)."
**Target device:** Lenovo Legion Go S Z2, SteamOS 3.x, Game Mode primary. DeckyLoader is already
installed on the device (so it's an available option, not a blocker) — the ask is specifically for
**fewer moving parts**, not "DeckyLoader-free at all costs."
**Prior art:** the SteamOS one-click integration effort — this doc is the research +
implementation for auto-populating Steam shortcuts from the host app list (shortcuts.vdf editing,
with safety researched first).

---

## 1. What we're starting from

Vibemis already ships the key enabler for *any* one-click design: a CLI.

```
vibemis list  <host> [--csv] [--verbose]     # apps on a paired host (CSV adds ID/HDR/Hidden/
                                              # Direct-Launch/Boxart-URL columns)
vibemis stream <host> "<app>"                # start streaming a specific app directly
vibemis pair   <host>
vibemis quit   <host>
```

(`app/cli/commandlineparser.cpp`, `listapps.cpp`, `startstream.cpp`.) This means every design
below reduces to "get Steam to run `vibemis stream "<host>" "<app>"`, with one click, in Game
Mode" — there is no need to invent a control protocol between the SteamOS client and the host;
Moonlight/Apollo already is that protocol, and the Vibemis CLI already wraps it.

Two pieces have already shipped, both real-device-tested on this exact Legion Go S Z2:

- `scripts/install-vibemis-desktop.sh` — installs the AppImage to a stable path
  (`~/Applications/Vibemis.AppImage`) with a clean `Name=Vibemis` desktop entry.
- `scripts/add-game-to-steam.sh <host> <app>` / `scripts/add-all-games-to-steam.sh <host>
  [--confirm]` — generate one `.desktop` launcher per host game
  (`Exec="$APPIMAGE" stream "<host>" "<app>"`), device-verified on 2026-05-30 (4/4 apps parsed
  and launched correctly on the real host "Navid-PC").

The gap those don't close: a `.desktop` file is **not** a Steam library tile. The user still has
to open Desktop Mode, run "Add a Non-Steam Game to My Library," and tick each one by hand. That's
the friction this ticket is about closing.

## 2. What MoonDeckBuddy does (and why we don't need its shape)

Going from what's documented about MoonDeck's architecture (no new research performed for this
doc — this is from existing knowledge): MoonDeck is a **Decky Loader plugin**
(runs on the Deck, in Game Mode, as a Quick-Access-Menu panel) paired with **MoonDeckBuddy**, a
**second, separate service that has to be installed and kept running on the host PC**. The Buddy
service exposes a small HTTP API the Decky plugin talks to: resolve Steam app IDs on the host,
launch/close games, query/set host display resolution, put the host to sleep, etc. It also
creates Steam shortcuts on the Deck for host games so they're launchable from the plugin's menu.

That's two new pieces of software per install (Decky plugin + host Buddy binary/service) plus an
ongoing network service on the host, on top of Moonlight/Sunshine itself. It buys real value for
MoonDeck's use case (live host-side control: resolution switching, sleep/wake, precise per-title
Steam-app-ID resolution) — but Vibemis doesn't need most of that surface. Vibemis already reaches
the host directly over the Moonlight/Apollo protocol via the CLI; there is no host-side
companion to install, no second network service, no second protocol to keep working across
Vibemis/Vibepollo version changes. That is the concrete "fewer moving parts" win available here,
independent of which SteamOS-side design (a/b/c below) is picked.

## 3. Candidate designs

### (a) shortcuts.vdf auto-population — **RECOMMENDED**

A script (`scripts/steam-sync-host-games.py`) runs `vibemis list <host> --csv`, and for each app
writes (or updates) a non-Steam Steam shortcut whose `Exe` is the Vibemis AppImage and whose
`LaunchOptions` is `stream "<host>" "<app>"`, plus grid artwork if a cover is already cached.
Every host game becomes a real Steam library tile. One click in Game Mode streams it — no menus,
no Desktop Mode round-trip.

- **Moving parts added:** one script. No new running service, no new client-side plugin runtime.
- **Risk:** `shortcuts.vdf` is Valve's undocumented binary VDF format, and Steam keeps it loaded
  in memory and overwrites the file with that in-memory copy on exit. Get this wrong and you can
  wipe a user's other non-Steam games. This is a real risk, not a hypothetical one — see §4 for
  how it's mitigated (backup, round-trip self-check, closed-Steam requirement, byte-for-byte
  readback verification).
- **UX cost:** requires closing Steam once to run `--apply`, and re-running the sync (still with
  Steam closed) whenever the host's app list changes. Not live/dynamic like a Decky panel would
  be — new host games don't appear until the next sync.
- **This is what the maintainer explicitly described wanting**: "a Steam library tile with that
  exact game" as the click target, which (b) doesn't deliver without a manual step and (c)
  doesn't deliver at all (a Decky panel is a menu, not a library tile).

### (b) One `.desktop` per game + manual "Add to Steam" — fallback, already shipped

`scripts/add-game-to-steam.sh` / `add-all-games-to-steam.sh` (already shipped, device-tested). Zero
binary-format risk — only writes `.desktop` files under `~/.local/share/applications/`. The
remaining step, ticking each one in Steam's "Add a Non-Steam Game" dialog, is manual and one-time
per game, but 100% safe and requires no new research or code.

- **Recommendation:** keep this as the documented fallback / manual path (already true today),
  and point users at it if they'd rather not have any script touch `shortcuts.vdf`, or if (a)
  hits a hard blocker on a future Steam client update that changes the VDF format.

### (c) Minimal Decky plugin calling the CLI

A small Decky Loader plugin (Python backend + a Quick-Access-Menu panel) that shells out to
`vibemis list` / `vibemis stream` and shows the result as an in-Game-Mode picker, with no Steam
library tiles involved at all.

- **Best in-Game-Mode UX** of the three: live (no sync step, no stale list), no Steam restart
  needed, no library clutter from games you rarely play.
- **But it is not what was asked for** — the maintainer's framing is explicitly a *library tile*
  ("a SteamOS library game window"), not a menu you open in a plugin.
- **More install surface, not less**, even with DeckyLoader already present: it's a second
  language/runtime for this codebase (Decky plugins are Python + TypeScript/Svelte, versioned
  against DeckyLoader's own plugin API, distributed via the Decky store or manual sideload) that
  the existing Vibemis team (C++/Qt/bash) would now own and keep compatible across DeckyLoader
  updates — a genuinely different maintenance burden than a couple of Python/bash scripts living
  next to the CLI they already ship.

### Comparison

| | (a) shortcuts.vdf sync | (b) `.desktop` + manual add | (c) Decky plugin |
|---|---|---|---|
| Matches "library tile, one click" ask | Yes | Only after a manual step | No (menu, not a tile) |
| New moving parts | 1 script | 1 script (done) | new plugin runtime + packaging |
| Binary-format risk | Yes (mitigated, §4) | None | None |
| Manual steps per game | 0 (after first sync) | 1 (Add to Steam) | 0 |
| Live / auto-updates on host change | No (re-run sync) | No | Yes |
| Extra language/toolchain for this repo | No (Python, stdlib) | No (bash) | Yes (Decky/Svelte) |
| Host-side companion service | No | No | No |

**Recommendation: ship (a) as the primary path, keep (b) as the documented fallback.** (a) is the
only option that satisfies the literal ask (a library tile that one-clicks into the exact game)
without adding a new plugin runtime to maintain. The binary-format risk is real but bounded and
mitigated the same way the repo's own `steam-shortcut` reference pattern already handles it
(mandatory backup, round-trip self-check before writing, byte-for-byte readback verification,
refuse-while-Steam-running guard) — see §4. No hard blocker was found; if one turns up on-device
(e.g. a future Steam client changes the VDF schema and the round-trip check starts failing), the
script fails closed (refuses to write) and (b) is there as a zero-risk fallback with zero
additional work.

## 4. Implementation

**Script:** `scripts/steam-sync-host-games.py` (pure standard library, no dependencies; Python
chosen over bash because binary VDF parsing needs real byte-level structure, not text
processing — this mirrors the existing `steam-shortcut` reference implementation this design
follows).

```
python3 scripts/steam-sync-host-games.py "<host>"                        # dry-run (default)
python3 scripts/steam-sync-host-games.py "<host>" --apply                # write (Steam must be closed)
python3 scripts/steam-sync-host-games.py "<host>" --apply --prune-missing
python3 scripts/steam-sync-host-games.py --list                          # read-only, any time
```

Flags: `--apply` (default is dry-run — prints the exact create/update/prune plan and touches
nothing), `--list` (read-only inventory of Vibemis-managed shortcuts, safe even while Steam is
running), `--user`, `--steam-root`, `--appimage` (or `$VIBEMIS_APPIMAGE`, default
`~/Applications/Vibemis.AppImage` — same convention as `install-vibemis-desktop.sh`),
`--include-hidden` (host apps marked Hidden are skipped by default), `--overwrite-art` (grid art
is fill-in-gaps by default, never clobbers art the user customized in Steam), `--prune-missing`
(opt-in removal of synced shortcuts for apps no longer on the host — off by default so a
transient host/network hiccup can never delete a tile), `--force` (bypass the Steam-running
guard).

### shortcuts.vdf safety

1. **Mandatory backup before any write**, timestamped: `shortcuts.vdf.bak-<YYYYmmddTHHMMSS>`.
   Never overwrites a previous backup.
2. **Round-trip self-check**: before touching the file, parse it and re-serialize it; if the
   bytes don't match byte-for-byte, refuse to write anything (exit 4). This proves the parser/
   serializer pair faithfully reproduces *this exact file* before it's trusted to append/update
   entries in it — an unrecognized future VDF field would trip this guard instead of silently
   dropping data.
3. **Steam-must-be-closed guard**: refuses to write if `steam`/`steam.exe` is detected running,
   unless `--force`. (Steam holds the file in memory and rewrites it from that copy on exit,
   which would silently discard the sync.)
4. **Update in place, never duplicate**: existing entries are matched by `(Exe, LaunchOptions)`,
   not by array index or display name, so re-running the sync after a host app rename or after
   changing the AppImage's icon updates the existing tile instead of creating a second one. Any
   shortcut this tool did *not* create (a user's own non-Steam games, or one added via the
   `steam-shortcut` skill) is left completely untouched — verified in testing (§6 below).
5. **Byte-for-byte readback verification** after writing; a mismatch is a hard failure (exit 6)
   with the backup path printed so recovery is a single `cp` away.
6. **appid**: the standard legacy non-Steam-shortcut convention,
   `crc32(quoted_exe + AppName) | 0x80000000` — this is both the `appid` field Steam reads from
   `shortcuts.vdf` and the id Steam uses to locate custom grid artwork, so no separate ID
   bookkeeping is needed.

This was exercised with an in-process test harness against a synthetic `userdata/<id>/config/`
tree (create → idempotent re-apply → `--include-hidden` → `--prune-missing` → foreign-shortcut
preservation → `--list` → corrupted-file refusal). All 8 scenarios passed, including confirming a
manually-added non-Vibemis shortcut survives every sync untouched and that re-running with no
host changes updates the same 2 entries rather than growing to 4. This is dev-machine logic
verification only — it does not replace the on-device test plan in §8 (no real Steam client, no
real AppImage, no real Legion Go S Z2 GPU/Gamescope involved).

### Artwork wiring

`app/backend/boxartmanager.cpp` caches box art on disk as
`Path::getBoxArtCacheDir()/<computer-uuid>/<appId>.png` (`Path::getBoxArtCacheDir()` resolves via
`QStandardPaths::CacheLocation` under the org/app name Vibemis registers —
`QCoreApplication::setOrganizationName("Vibemis Project")` /
`setApplicationName("Vibemis")` in `app/main.cpp`; the equivalent `~/.config/Vibemis
Project/Vibemis.conf` settings path was independently confirmed on this exact device, giving high
confidence the cache directory follows `~/.cache/Vibemis Project/Vibemis/boxart/...` on Linux,
though this was not directly re-verified).

**The sync script deliberately does not reconstruct that path itself.** Instead it reads the
`Boxart URL` column from `vibemis list <host> --csv` (`app/cli/listapps.cpp` `printAppCSV`),
which is the C++ code's own already-resolved answer — `file://...` if a cover is cached,
`qrc:/res/no_app_image.png` (the in-app placeholder) otherwise. This avoids the sync script
having to independently reverse-engineer Qt's cache-path logic (org name, `QStandardPaths`
version/platform quirks) and guarantees it never gets out of sync with however the C++ side
computes that path in the future.

**Known limitation (not fixed here, flagged for the maintainer in §9):** `BoxArtManager::loadBoxArt`
only returns a real path for covers **already cached** — i.e. box art the user has previously
browsed in the Vibemis app grid for that host. When the CLI's `--csv` path calls it on an
uncached app, it kicks off an async network fetch and returns the placeholder immediately, and
the CLI process exits (`QCoreApplication::exit(0)` right after building the CSV) before that
fetch has any real chance to land. **In practice: sync gets real cover art only for games you've
already opened the app grid for at least once; everything else gets Steam's default "unknown
application" icon on first sync**, and picks up art on a later re-sync after you've browsed that
host's grid once. This was confirmed against the actual `listapps.cpp` control flow, not
guessed. Where a cover **is** cached, the sync writes it to both
`userdata/<id>/config/grid/<appid>.png` (capsule) and `grid/<appid>p.png` (portrait "library
capsule" — the one Game Mode primarily shows), never overwriting existing custom art unless
`--overwrite-art` is passed.

## 5. Why not touch the CLI itself

`app/cli/listapps.cpp` could be given a `--prefetch-boxart` mode that blocks until the async
fetch completes, closing the artwork gap in §4. That's a real C++ change with a build/test cycle
(qmake6, AppImage rebuild, device verification) — out of scope for this ticket, which is
explicitly a device-independent scripting task. Flagged as an open
question for the maintainer in §9; it's a small, well-scoped follow-up if wanted.

## 6. Naming and collision handling

Synced `AppName` is `"<app> — <host>"` (e.g. `"Portal 2 — Navid-PC"`) so the same app name on two
different hosts never collides in Steam's library, and so it's obvious in the library which
host a tile streams from. `LaunchOptions` (`stream "<host>" "<app>"`) is the actual identity key
used for update-vs-create matching (§4.4), not the display name, so renaming is safe. Host or app
names containing a literal double-quote character are skipped with a warning (Steam's
`LaunchOptions` parsing doesn't give a script a way to safely embed one) — this was not hit on the
one real device app list available (Desktop, Steam Big Picture, MoonDeckStream, Virtual Display —
none contain quotes) but the guard exists in case a Sunshine/Apollo app is ever named with one.

## 7. Verification performed in this session

- Ran the script against a synthetic Steam `userdata/` tree and a stubbed `vibemis list --csv`
  response (real AppImage execution isn't possible from this Windows dev box) — see §4 for the
  8 scenarios covered.
- Confirmed the real CSV column layout, quoting, and `--csv` flag name against
  `app/cli/commandlineparser.cpp` (`ListCommandLineParser::parse`, flag `--csv`) and
  `app/cli/listapps.cpp` (`printAppCSV`) directly, rather than guessing the format.
- Cross-checked the plain (non-CSV) `vibemis list <host>` output shape (one app name per line, no
  header) against a real device transcript.
- Did **not** run the script against a real Steam client or the real Legion Go S Z2 — that's §8.

## 8. On-Device Test Plan

Run on-device once the script is deployed. Do not run this against an active Steam session without
reading §4's Steam-must-be-closed requirement first.

1. **Preflight**: confirm `~/Applications/Vibemis.AppImage` exists (run
   `scripts/install-vibemis-desktop.sh` first if not) and a host is already paired
   (`~/Applications/Vibemis.AppImage list "<host>"` returns a non-empty app list).
2. **Dry run**: `python3 scripts/steam-sync-host-games.py "<host>"` with Steam **open**. Confirm
   it runs to completion, prints a create/update/skip plan matching the host's real app list, and
   makes **no changes** — diff `shortcuts.vdf` (or its absence) before/after, confirm no
   `.bak-*` file was created.
3. **Backup + apply**: close Steam fully (`steam -shutdown`; wait for the process to exit). Run
   `python3 scripts/steam-sync-host-games.py "<host>" --apply`. Confirm: a timestamped
   `shortcuts.vdf.bak-*` now exists next to `shortcuts.vdf`; the script reports "Readback OK:
   True"; `python3 scripts/steam-sync-host-games.py --list` shows one entry per (non-hidden) host
   app.
4. **Tiles appear**: reopen Steam, switch to Game Mode. Confirm each synced app appears as a
   library tile under Non-Steam Games, named `"<app> — <host>"`.
5. **One-click launch streams the right game**: from Game Mode, click one tile (pick a
   non-Desktop app if the host has one). Confirm Vibemis launches directly into a stream of
   *that exact app* — no host/app picker shown, matching `vibemis stream "<host>" "<app>"`
   behavior already verified by the CLI's own tests.
6. **Artwork**: for any app you had previously opened in the Vibemis GUI app grid for this host
   (so its cover is cache-warm per §4's known limitation), confirm the Steam tile shows that
   cover, not the generic icon. For an app never browsed in the GUI, confirm it shows the default
   icon (expected, not a bug) — then browse that host once in the Vibemis GUI, re-run
   `--apply`, and confirm the tile now shows real art.
7. **Idempotency**: with Steam closed again, re-run `--apply` with no host-side changes. Confirm
   the tile count in Steam is unchanged (no duplicates) and `--list` still shows exactly the same
   entries.
8. **Prune (opt-in)**: temporarily hide or rename one app on the host (or use a host with fewer
   apps than last sync). Run `--apply --prune-missing`. Confirm only that tile disappears from
   Steam and all others are untouched.
9. **Backup restores cleanly**: with Steam closed, copy the newest `shortcuts.vdf.bak-*` over
   `shortcuts.vdf`, reopen Steam, and confirm the library returns to its pre-sync state (synced
   tiles gone, any pre-existing non-Steam games — e.g. one added via the `steam-shortcut` skill —
   still present and unaffected).
10. **Non-interference**: confirm a manually-added non-Steam game (added via Steam's own "Add a
    Non-Steam Game" dialog, or via the `steam-shortcut` skill) survives steps 3–9 untouched.

## 9. Open questions for the maintainer

- Is the `"<app> — <host>"` tile naming acceptable, or would you rather have a per-host prefix/
  Steam collection instead (Steam doesn't expose creating "collections" via `shortcuts.vdf`
  itself — that's a separate `levelinfo`/library-customization file — so this would be a
  follow-up, not part of this ticket)?
- Do you want `steam-sync-host-games.py` folded into `scripts/vibemis-setup.sh`'s guided flow
  (as an opt-in step after pairing, alongside the existing `add-all-games-to-steam.sh --confirm`
  call) once it's on-device verified, or kept as a standalone opt-in script for now?
- Is the boxart-only-if-already-cached limitation (§4 "Known limitation") acceptable, or is a
  `vibemis list --csv --prefetch-boxart` follow-up (blocks until the async fetch completes, §5)
  worth scheduling as a small, separate CLI change?
- `--prune-missing` is off by default. Should the guided setup flow (if wired up per the question
  above) ever pass it automatically, or should pruning always require an explicit manual run?
