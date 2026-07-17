# CLAUDE.md — orientation for Claude sessions working on Vibemis

This file is read at the start of every Claude session in this repo. Keep it short — link out
to longer docs rather than duplicating their content here.

## What this repo is

**Vibemis** is a Linux-focused fork of [Vibemis Qt](https://github.com/navyas321/vibemis)
(itself a fork of [Moonlight Qt](https://github.com/moonlight-stream/moonlight-qt)). It's a
desktop / Steam Deck / handheld streaming client tuned to pair with **Vibepollo** (a Sunshine
fork). C++ / Qt 6 / QML, built with qmake6.

## Branch model

- **Default branch:** `vibemis-main` — long-running integration branch where work lands.
- **Original upstream mirror:** `develop` — mirror of wjbeckett's Vibemis Qt `develop` at the
  time of fork. Don't push to it.
- **Submodule of note:** `moonlight-common-c/moonlight-common-c` points at
  [ClassicOldSong's Apollo-lineage fork](https://github.com/ClassicOldSong/moonlight-common-c),
  NOT mainline `moonlight-stream/moonlight-common-c`. Whenever an upstream moonlight-qt rebase
  happens, the wrapper `.pro` must be checked for upstream's new symbols that ClassicOldSong's
  fork doesn't expose (e.g. `src/rswrapper.c`, `nanors/`, `LiSendControllerTouchEvent2`,
  `LI_CCAP_DUAL_TOUCHPAD`, `LiGetMicroseconds`).
- **Test branch naming:** feature branches carrying a test-cycle AppImage are named
  `test<N>-<slug>` — see the private agent-meta repo (below) for why this convention exists.

## Build and development

- **Build system, environment, submodule notes:** [`docs/BUILD_SYSTEM.md`](docs/BUILD_SYSTEM.md)
- **Project structure, key source files:** [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md)
- **Versioning, CI release tiers, the AppImage pipeline:** [`docs/RELEASING.md`](docs/RELEASING.md)
  — read this before pushing; the CI smart-build check silently skips AppImage builds on
  `.md`-only HEAD commits, which trips people up constantly.
- **Scriptable self-test / verification surfaces:** [`docs/SELFTEST.md`](docs/SELFTEST.md)
  (`vibemis selftest`, `--json`, log-driven assertions, headless CLI host checks)
- **Contributing conventions** (commit format, PR test scorecard): [`CONTRIBUTING.md`](CONTRIBUTING.md)
- **Design tokens and assets:** [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md), `docs/design/`

## Agent-orchestration meta lives elsewhere

Session governance, personas, SOPs, the build-agent/test-agent handoff, per-cycle test
instructions and reports, and Claude Code slash commands for this project all live in the
private repo **`navyas321/vibemis-agent-meta`** — agents clone it side by side with this one
and start sessions from its root (its `CLAUDE.md` is the governance file; it references
`../vibemis` for code operations). This split (P4.0, BL-1565/BL-2035) keeps this repo's history
free of agent-loop process narrative and device/infra details ahead of it going public.

If you're a Claude session here and don't have access to the meta repo, you can still build,
test (via `docs/SELFTEST.md`), and contribute using only what's in this repo — you just won't
have the test-cycle handoff context.
