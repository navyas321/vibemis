# test58 — Show host software version in PC details (P3.13)

**Feature:** The **View Details** dialog for a PC now shows the host software version in the
**System Information** section: "Apollo Version" (when the host reports it) and/or
"Host Software Version" (app/GFE version). Lets users tell whether their Apollo / Vibepollo /
Sunshine host is up to date. Single-function change in `computermodel.cpp` (DetailsRole).
**Branch:** `test58-host-version-details` · **Base:** `vibemis-main` · **Artifact:** 🔬 alpha
pre-release (tag contains `test58-host-version-details`).

> Launcher-only. Most informative against a **paired, online** host (version is fetched from the
> host); an offline/unpaired host may show no version line — that's expected.

## Setup
1. Download the alpha AppImage, `chmod +x`, record `md5sum` + SteamOS/Mesa versions.

## Tier 1 — details dialog renders the new line (online host)
1. With a paired host **Online** in the Computers list, open its context menu → **View Details**.
2. In the **═══ SYSTEM INFORMATION ═══** section, confirm a **"Host Software Version: …"** line
   (and, if your host reports it, **"Apollo Version: …"**) appears below UUID/MAC.
   - ✅ PASS if a non-empty version string is shown for an online host.

## Tier 2 — no crash / graceful when version unknown
1. View Details on an **offline** or freshly-added host.
   - ✅ PASS if the dialog still opens and the System Information section renders without the
     version line (or with it absent) — no blank "Version: " artifact, no crash.

## Tier 3 — regression check
1. Confirm the rest of the details dialog (Network, Server Capabilities, Server Commands) is
   unchanged and complete.
   - ✅ PASS if all prior sections still render correctly.

## What to capture / report
- md5 + environment, the host type (Apollo/Vibepollo/Sunshine) and the version line(s) shown.
- A screenshot of the details dialog (`spectacle -b -n -a -o <file>`).

## Report
Write `testing/test58-host-version-details/report.md`, update the `test58` row in
`testing/TEST_CHECKLIST.md`, commit both on `diagnostic/test58-host-version-details-report`,
open a PR targeting `test58-host-version-details`.
