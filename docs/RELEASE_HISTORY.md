# Vibemis release history — the Semantic Versioning catalog

Every build this project ever published, catalogued under **[Semantic Versioning 2.0.0](https://semver.org)**.
Everything that predates the first stable cut is a pre-release of `0.1.0` at its chronological
position; burnt stable cuts are `rc` entries; the adopted first stable is **`0.4.0.0`** (kept
under its original four-part tag because deployed devices key on it — canonically `0.4.0`).
Restored and renumbered 2026-07-13 from local clone tags, the 507-run CI inventory, git
history, and session-transcript archaeology after a release-page cleanup deleted the originals.

## Numbering rules

| Class | Tag shape | Notes |
|---|---|---|
| alpha (automated builds, incl. the 2025 dev era) | `X.Y.Z-alpha.NNN` | NNN = dense chronological counter, zero-padded |
| beta (manual-testing builds) | `X.Y.Z-beta.NNN` | dense chronological counter, zero-padded |
| rc (stable cuts that failed adoption) | `X.Y.Z-rc.NNN` | the burnt-number stories live here |
| stable | `X.Y.Z` (bare) | only stables are non-prerelease; Latest ⇔ newest stable |

Pre-releases version against the stable they preceded. Counters are zero-padded because
GitHub's release-page sort compares the prerelease suffix lexically (verified empirically).
Marker entries are prerelease-flagged and artifact-free (originals purged — rebuild from the
recorded commit); each body's **Version** line equals the release title, with the original
tag preserved on its own line. A burnt number is never reused for different bits.

## The story in stables

The `0.1.0` train (175 pre-releases across a year of automated and manual builds, including
the two pre-scheme stables `1.0.0`/`1.0.1` at their chronological slots) ended in two burnt
rc cuts (tag-reuse incidents that stranded installed devices — the origin of the no-reuse
rule). `0.2.0-rc.001` and `0.3.0-rc.001` burned the same way or were superseded within the
hour. **`0.3.1`** genuinely shipped (System Information accuracy + working links) but was
structurally invisible to deployed updaters and was superseded the same day by
**`0.4.0.0` — the adopted first stable**, the only non-prerelease entry, holder of the
Latest badge, live-fire proven against the oldest deployed client generation. Future
releases: `0.5.0-alpha.NNN` / `0.5.0-beta.NNN` → `0.5.0`.

## Full catalog (181 entries)

| Catalog version | Original tag | Class | Commit | Run | Built |
|---|---|---|---|---|---|
| `0.1.0-alpha.001` | `dev-develop-866a377-20250725-0911` | dev | `866a377` | — | 2025-07-25 09:11Z |
| `0.1.0-alpha.002` | `dev-develop-da2f0fc-20250726-1157` | dev | `da2f0fc` | — | 2025-07-26 11:57Z |
| `0.1.0-alpha.003` | `dev-develop-edb66fc-20250726-2104` | dev | `edb66fc` | — | 2025-07-26 21:04Z |
| `0.1.0-alpha.004` | `develop-0a1ee1d-20250726-2327` | dev | `0a1ee1d` | — | 2025-07-26 23:27Z |
| `0.1.0-alpha.005` | `v0.1.0-dev-20-3ad5f15` | dev | `3ad5f158` | #20 | 2025-07-27 09:48Z |
| `0.1.0-alpha.006` | `v0.1.1-dev-21-e12f2cb` | dev | `e12f2cba` | #21 | 2025-07-27 10:39Z |
| `0.1.0-alpha.007` | `v0.1.1-dev-22-d4cb222` | dev | `d4cb2222` | #22 | 2025-07-27 12:03Z |
| `0.1.0-alpha.008` | `v0.1.2-dev-23-60d67f8` | dev | `60d67f8f` | #23 | 2025-07-27 13:59Z |
| `0.1.0-alpha.009` | `0.1.0-dev.20250728.0212+0ae71d0` | dev | `0ae71d0` | — | 2025-07-28 02:12Z |
| `0.1.0-alpha.010` | `0.3.0-dev.20250728.0721+07c58b7` | dev | `07c58b7` | — | 2025-07-28 07:21Z |
| `0.1.0-alpha.011` | `0.3.1-dev.20250728.2308+b0f4824` | dev | `b0f4824` | — | 2025-07-28 23:08Z |
| `0.1.0-alpha.012` | `0.4.0-dev.20250729.0616+dd3f695` | dev | `dd3f695` | — | 2025-07-29 06:16Z |
| `0.1.0-alpha.013` | `0.4.2-dev.20250729.1115+eab6961` | dev | `eab6961` | — | 2025-07-29 11:15Z |
| `0.1.0-alpha.014` | `0.4.3-dev.20250730.0109+3af6baf` | dev | `3af6baf` | — | 2025-07-30 01:09Z |
| `0.1.0-alpha.015` | `0.5.1-dev.20250804.1208+c31bc64` | dev | `c31bc64` | — | 2025-08-04 12:08Z |
| `0.1.0-alpha.016` | `0.5.1-dev.20250805.0610+eb4521c` | dev | `eb4521c` | — | 2025-08-05 06:10Z |
| `0.1.0-alpha.017` | `0.5.2-dev.20250805.0624+e60d8e4` | dev | `e60d8e4` | — | 2025-08-05 06:24Z |
| `0.1.0-alpha.018` | `0.5.4-dev.20250806.0942+5ee2a96` | dev | `5ee2a96` | — | 2025-08-06 09:42Z |
| `0.1.0-alpha.019` | `0.5.5-dev.20250807.0426+0677333` | dev | `0677333` | — | 2025-08-07 04:26Z |
| `0.1.0-alpha.020` | `0.5.6-dev.20250807.0611+2570bf2` | dev | `2570bf2` | — | 2025-08-07 06:11Z |
| `0.1.0-alpha.021` | `0.5.7-dev.20250808.2113+f564fda` | dev | `f564fda` | — | 2025-08-08 21:13Z |
| `0.1.0-alpha.022` | `0.6.0-dev.20250815.0755+0b56fc4` | dev | `0b56fc4` | — | 2025-08-15 07:55Z |
| `0.1.0-alpha.023` | `0.6.1-dev.20250815.2321+0ec85e6` | dev | `0ec85e6` | — | 2025-08-15 23:21Z |
| `0.1.0-alpha.024` | `0.6.2-dev.20250818.0115+a7f5590` | dev | `a7f5590` | — | 2025-08-18 01:15Z |
| `0.1.0-alpha.025` | `0.6.3-dev.20250820.0014+e5d443a` | dev | `e5d443a` | — | 2025-08-20 00:14Z |
| `0.1.0-alpha.026` | `0.6.4-dev.20250820.0157+57c9a27` | dev | `57c9a27` | — | 2025-08-20 01:57Z |
| `0.1.0-alpha.027` | `0.6.5-dev.20250821.0305+712bd5a` | dev | `712bd5a` | — | 2025-08-21 03:05Z |
| `0.1.0-alpha.028` | `0.6.6-dev.20250828.2114+0cdeaef` | dev | `0cdeaef` | — | 2025-08-28 21:14Z |
| `0.1.0-alpha.029` | `0.6.7-dev.20250831.0017+afe2de7` | dev | `afe2de7` | — | 2025-08-31 00:17Z |
| `0.1.0-alpha.030` | `0.6.7-alpha.test48-steamos-helper-scripts.20260529.2018+87ec098` | alpha | `87ec098` | #104 | 2026-05-29 20:18Z |
| `0.1.0-alpha.031` | `0.6.7-alpha.test50-perf-overlay-textsize.20260529.2036+586966b` | alpha | `586966b` | #108 | 2026-05-29 20:36Z |
| `0.1.0-alpha.032` | `0.6.7-alpha.test52-selftest-cli.20260529.2057+53f4ec9` | alpha | `53f4ec9` | #111 | 2026-05-29 20:57Z |
| `0.1.0-alpha.033` | `0.6.7-alpha.test53-perf-guidance.20260529.2105+90eef29` | alpha | `90eef29` | #112 | 2026-05-29 21:05Z |
| `0.1.0-alpha.034` | `0.6.7-alpha.test54-selftest-json.20260529.2108+15732f9` | alpha | `15732f9` | #113 | 2026-05-29 21:08Z |
| `0.1.0-alpha.035` | `0.6.7-alpha.test57-suppress-rumble.20260529.2121+97bdd6f` | alpha | `97bdd6f` | #116 | 2026-05-29 21:21Z |
| `0.1.0-alpha.036` | `0.6.7-alpha.test58-host-version-details.20260529.2131+7dbd093` | alpha | `7dbd093` | #118 | 2026-05-29 21:31Z |
| `0.1.0-alpha.037` | `0.6.7-alpha.test60-permission-summary.20260529.2142+5352649` | alpha | `5352649` | #120 | 2026-05-29 21:42Z |
| `0.1.0-alpha.038` | `0.6.7-alpha.test61-virtual-display-hint.20260529.2144+9465ea6` | alpha | `9465ea6` | #121 | 2026-05-29 21:44Z |
| `0.1.0-alpha.039` | `0.6.7-alpha.test63-copy-system-info.20260529.2155+e1817e7` | alpha | `e1817e7` | #126 | 2026-05-29 21:55Z |
| `0.1.0-alpha.040` | `0.6.7-alpha.test67-low-latency-preset.20260529.2212+0cb5fd4` | alpha | `0cb5fd4` | #131 | 2026-05-29 22:12Z |
| `0.1.0-alpha.041` | `0.6.7-alpha.test69-tailscale-oneclick-setup.20260529.2222+7ea6c84` | alpha | `7ea6c84` | #133 | 2026-05-29 22:22Z |
| `0.1.0-alpha.042` | `0.6.7-alpha.test70-tailscale-setup-button.20260529.2224+65168d5` | alpha | `65168d5` | #134 | 2026-05-29 22:24Z |
| `0.1.0-alpha.043` | `0.6.7-alpha.test71-fix-button-caps.20260530.0123+0c53f09` | alpha | `0c53f09` | #146 | 2026-05-30 01:23Z |
| `0.1.0-alpha.044` | `0.6.7-alpha.test59-bitrate-data-estimate.20260530.0702+adf5e0a` | alpha | `adf5e0a` | #152 | 2026-05-30 07:02Z |
| `0.1.0-alpha.045` | `0.6.7-alpha.test65-av1-codec-hint.20260530.0714+215b657` | alpha | `215b657` | #156 | 2026-05-30 07:14Z |
| `0.1.0-alpha.046` | `0.6.7-alpha.test66-stream-summary.20260530.0724+49cdb1f` | alpha | `49cdb1f` | #159 | 2026-05-30 07:24Z |
| `0.1.0-alpha.047` | `0.6.7-alpha.test62-adaptive-bitrate-slice.20260530.0755+8c93281` | alpha | `8c93281` | #167 | 2026-05-30 07:55Z |
| `0.1.0-alpha.048` | `0.6.7-alpha.test73-design-system-theme.20260530.0801+55a2c21` | alpha | `55a2c21` | #170 | 2026-05-30 08:01Z |
| `0.1.0-alpha.049` | `0.6.7-alpha.test74-guided-setup.20260530.0822+2f5391b` | alpha | `2f5391b` | #174 | 2026-05-30 08:22Z |
| `0.1.0-alpha.050` | `0.6.7-alpha.test49-perf-overlay-position.20260530.0827+ee4a70c` | alpha | `ee4a70c` | #178 | 2026-05-30 08:27Z |
| `0.1.0-alpha.051` | `0.6.7-alpha.test68-native-res-hint.20260530.0901+a8cab24` | alpha | `a8cab24` | #190 | 2026-05-30 09:01Z |
| `0.1.0-alpha.052` | `0.6.7-alpha.test72-perf-overlay-clock.20260530.0915+52d5020` | alpha | `52d5020` | #193 | 2026-05-30 09:15Z |
| `0.1.0-alpha.053` | `0.6.7-alpha.test64-motion-capability.20260530.1038+6281c22` | alpha | `6281c22` | #196 | 2026-05-30 10:38Z |
| `0.1.0-alpha.054` | `0.6.7-alpha.test56-help-links.20260530.1216+ae39edd` | alpha | `ae39edd` | #210 | 2026-05-30 12:16Z |
| `0.1.0-alpha.055` | `0.6.7-alpha.test55-system-info.20260530.1635+3d1873e` | alpha | `3d1873e` | #218 | 2026-05-30 16:35Z |
| `0.1.0-alpha.056` | `0.6.7-alpha.test51-prefer-tailscale.20260530.1639+4a11f8f` | alpha | `4a11f8f` | #221 | 2026-05-30 16:39Z |
| `0.1.0-alpha.057` | `0.6.7-alpha.test22-quickmenu-overlay.20260530.1801+14e7314` | alpha | `14e7314` | #225 | 2026-05-30 18:01Z |
| `0.1.0-alpha.058` | `0.6.7-alpha.test76-per-game-profiles.20260711.2348+010b36c` | alpha | `010b36c` | #232 | 2026-07-11 23:48Z |
| `0.1.0-alpha.059` | `0.6.7-alpha.test77-quickmenu-gamepad-close.20260711.2353+e04647a` | alpha | `e04647a` | #233 | 2026-07-11 23:53Z |
| `0.1.0-alpha.060` | `0.7.0-alpha.test25-video-scale-mode.20260712.0008+a5b888a` | alpha | `a5b888a` | #247 | 2026-07-12 00:08Z |
| `0.1.0-alpha.061` | `0.7.0-alpha.test26-configurable-quickmenu-shortcut.20260712.0008+c51a2f0` | alpha | `c51a2f0` | #248 | 2026-07-12 00:08Z |
| `0.1.0-alpha.062` | `0.7.0-alpha.test36-quickmenu-paddle-combo.20260712.0008+6e2a620` | alpha | `6e2a620` | #249 | 2026-07-12 00:08Z |
| `0.1.0-alpha.063` | `0.7.1-alpha.test77-quickmenu-gamepad-close.20260712.0010+7ce593f` | alpha | `7ce593f` | #251 | 2026-07-12 00:10Z |
| `0.1.0-alpha.064` | `0.7.0-alpha.test31-video-zoom.20260712.0012+5f51830` | alpha | `5f51830` | #253 | 2026-07-12 00:12Z |
| `0.1.0-alpha.065` | `0.7.0-alpha.test32-video-pan.20260712.0013+66f537f` | alpha | `66f537f` | #254 | 2026-07-12 00:13Z |
| `0.1.0-alpha.066` | `0.7.0-alpha.test24-compact-perf-overlay.20260712.0014+0a4396f` | alpha | `0a4396f` | #256 | 2026-07-12 00:14Z |
| `0.1.0-alpha.067` | `0.7.0-alpha.test40-battery-saver.20260712.0014+8fb0168` | alpha | `8fb0168` | #255 | 2026-07-12 00:14Z |
| `0.1.0-alpha.068` | `0.7.0-alpha.test23-vibepollo-presets.20260712.0022+93e45bc` | alpha | `93e45bc` | #258 | 2026-07-12 00:22Z |
| `0.1.0-alpha.069` | `0.8.0-alpha.test76-per-game-profiles.20260712.0028+756ffd7` | alpha | `756ffd7` | #262 | 2026-07-12 00:28Z |
| `0.1.0-alpha.070` | `0.7.1-alpha.test78-cli-app-seek.20260712.0040+639de73` | alpha | `639de73` | #267 | 2026-07-12 00:40Z |
| `0.1.0-alpha.071` | `0.8.0-alpha.test29-quickmenu-content.20260712.0041+73ce477` | alpha | `73ce477` | #269 | 2026-07-12 00:41Z |
| `0.1.0-alpha.072` | `0.8.0-alpha.test33-quickmenu-streaminfo.20260712.0042+39eca57` | alpha | `39eca57` | #270 | 2026-07-12 00:42Z |
| `0.1.0-alpha.073` | `0.8.0-alpha.test47-quickmenu-special-keys.20260712.0042+cb66a91` | alpha | `cb66a91` | #271 | 2026-07-12 00:42Z |
| `0.1.0-alpha.074` | `0.9.0-alpha.test79-theme-wave1.20260712.0048+53842ae` | alpha | `53842ae` | #278 | 2026-07-12 00:48Z |
| `0.1.0-alpha.075` | `0.8.0-alpha.test81-review-fixes.20260712.0102+21540ac` | alpha | `21540ac` | #280 | 2026-07-12 01:02Z |
| `0.1.0-alpha.076` | `0.9.1-alpha.test81-review-fixes.20260712.0102+0c33360` | alpha | `0c33360` | #281 | 2026-07-12 01:02Z |
| `0.1.0-alpha.077` | `0.10.0-alpha.test80-auto-reconnect.20260712.0108+99527db` | alpha | `99527db` | #285 | 2026-07-12 01:08Z |
| `0.1.0-alpha.078` | `0.10.1-alpha.test81-review-fixes.20260712.0117+cbbb8d7` | alpha | `cbbb8d7` | #288 | 2026-07-12 01:17Z |
| `0.1.0-alpha.079` | `0.10.1-alpha.test81-review-fixes.20260712.0118+d366cad` | alpha | `d366cad` | #290 | 2026-07-12 01:18Z |
| `0.1.0-alpha.080` | `0.11.0-alpha.test82-motion-forward.20260712.0127+36775e0` | alpha | `36775e0` | #295 | 2026-07-12 01:27Z |
| `0.1.0-alpha.081` | `0.11.1-alpha.test83-review-fixes-2.20260712.0133+37d07dd` | alpha | `37d07dd` | #299 | 2026-07-12 01:33Z |
| `0.1.0-alpha.082` | `0.11.2-alpha.test84-nonthreaded-pump.20260712.0136+314846c` | alpha | `314846c` | #300 | 2026-07-12 01:36Z |
| `0.1.0-alpha.083` | `0.11.3-alpha.test85-savesync-note.20260712.0141+a8cebba` | alpha | `a8cebba` | #301 | 2026-07-12 01:41Z |
| `0.1.0-alpha.084` | `0.11.1-alpha.test83-review-fixes-2.20260712.0143+7dd0506` | alpha | `7dd0506` | #303 | 2026-07-12 01:43Z |
| `0.1.0-alpha.085` | `0.11.2-alpha.test84-nonthreaded-pump.20260712.0144+b897b75` | alpha | `b897b75` | #307 | 2026-07-12 01:44Z |
| `0.1.0-alpha.086` | `0.11.3-alpha.test85-savesync-note.20260712.0144+4be23ca` | alpha | `4be23ca` | #309 | 2026-07-12 01:44Z |
| `0.1.0-alpha.087` | `0.11.3-alpha.test29-quickmenu-content.20260712.0148+a6c9564` | alpha | `a6c9564` | #312 | 2026-07-12 01:48Z |
| `0.1.0-alpha.088` | `0.11.3-alpha.test33-quickmenu-streaminfo.20260712.0148+0b8ba79` | alpha | `0b8ba79` | #313 | 2026-07-12 01:48Z |
| `0.1.0-alpha.089` | `0.11.3-alpha.test47-quickmenu-special-keys.20260712.0148+34ef441` | alpha | `34ef441` | #314 | 2026-07-12 01:48Z |
| `0.1.0-alpha.090` | `0.12.0-alpha.test86-quickmenu-textsend.20260712.0201+c0cbba1` | alpha | `c0cbba1` | #316 | 2026-07-12 02:01Z |
| `0.1.0-alpha.091` | `0.11.3-alpha.test47-quickmenu-special-keys.20260712.0205+49886c7` | alpha | `49886c7` | #319 | 2026-07-12 02:05Z |
| `0.1.0-alpha.092` | `0.11.3-alpha.test33-quickmenu-streaminfo.20260712.0206+b429805` | alpha | `b429805` | #321 | 2026-07-12 02:06Z |
| `0.1.0-alpha.093` | `0.12.0-alpha.test86-quickmenu-textsend.20260712.0208+2816817` | alpha | `2816817` | #324 | 2026-07-12 02:08Z |
| `0.1.0-alpha.094` | `0.13.0-alpha.test87-quickmenu-toggles.20260712.0212+a5eb640` | alpha | `a5eb640` | #326 | 2026-07-12 02:12Z |
| `0.1.0-alpha.095` | `0.13.0-alpha.test26-configurable-quickmenu-shortcut.20260712.0214+4d8f830` | alpha | `4d8f830` | #330 | 2026-07-12 02:14Z |
| `0.1.0-alpha.096` | `0.14.0-alpha.test88-redesign-tokens.20260712.0232+6c68ac5` | alpha | `6c68ac5` | #344 | 2026-07-12 02:32Z |
| `0.1.0-alpha.097` | `0.15.0-alpha.test89-redesign-help.20260712.0236+4067506` | alpha | `4067506` | #346 | 2026-07-12 02:36Z |
| `0.1.0-alpha.098` | `0.16.0-alpha.test90-redesign-addpc.20260712.0246+556010f` | alpha | `556010f` | #348 | 2026-07-12 02:46Z |
| `0.1.0-alpha.099` | `0.17.0-alpha.test91-redesign-appgrid.20260712.0248+8fbfc25` | alpha | `8fbfc25` | #350 | 2026-07-12 02:48Z |
| `0.1.0-alpha.100` | `0.18.0-alpha.test92-redesign-computers.20260712.0250+1d6420b` | alpha | `1d6420b` | #353 | 2026-07-12 02:50Z |
| `0.1.0-alpha.101` | `0.19.0-alpha.test93-tailscale-status.20260712.0304+34fc1b7` | alpha | `34fc1b7` | #355 | 2026-07-12 03:04Z |
| `0.1.0-alpha.102` | `0.20.0-alpha.test94-redesign-fonts.20260712.0309+06ac125` | alpha | `06ac125` | #357 | 2026-07-12 03:09Z |
| `0.1.0-alpha.103` | `0.21.0-alpha.test95-redesign-icon.20260712.0314+70d3384` | alpha | `70d3384` | #361 | 2026-07-12 03:14Z |
| `0.1.0-alpha.104` | `0.22.0-alpha.test96-redesign-settings-chip.20260712.0331+b6f8c1e` | alpha | `b6f8c1e` | #364 | 2026-07-12 03:31Z |
| `0.1.0-alpha.105` | `0.22.1-alpha.test97-help-card-fix.20260712.0345+f454b9b` | alpha | `f454b9b` | #366 | 2026-07-12 03:45Z |
| `0.1.0-alpha.106` | `0.22.2-alpha.test98-typetext-menu-fix.20260712.0346+df5d6c4` | alpha | `df5d6c4` | #368 | 2026-07-12 03:46Z |
| `0.1.0-alpha.107` | `0.22.3-alpha.test99-deadcode-cleanup.20260712.0350+aa954a2` | alpha | `aa954a2` | #370 | 2026-07-12 03:50Z |
| `0.1.0-alpha.108` | `0.22.3-alpha.test86-quickmenu-textsend.20260712.0354+bf7b5bb` | alpha | `bf7b5bb` | #371 | 2026-07-12 03:54Z |
| `0.1.0-alpha.109` | `0.22.3-alpha.test89-redesign-help.20260712.0354+bf7b5bb` | alpha | `bf7b5bb` | #371 | 2026-07-12 03:54Z |
| `0.1.0-alpha.110` | `0.23.0-alpha.test100-host-options-sheet.20260712.0416+82174ee` | alpha | `82174ee` | #374 | 2026-07-12 04:16Z |
| `0.1.0-alpha.111` | `0.24.0-alpha.test101-settings-sidebar.20260712.0515+790a10d` | alpha | `790a10d` | #376 | 2026-07-12 05:15Z |
| `0.1.0-alpha.112` | `0.22.4-alpha.test102-settings-parse-fix.20260712.0533+1111697` | alpha | `1111697` | #377 | 2026-07-12 05:33Z |
| `0.1.0-alpha.113` | `0.23.1-alpha.test103-app-icon.20260712.0558+5cb9b6e` | alpha | `5cb9b6e` | #381 | 2026-07-12 05:58Z |
| `0.1.0-alpha.114` | `0.23.1-alpha.test104-gamescope-pkill.20260712.0558+9512136` | alpha | `9512136` | #382 | 2026-07-12 05:58Z |
| `0.1.0-alpha.115` | `0.25.0-alpha.test107-home-chrome.20260712.0706+a2231cb` | alpha | `a2231cb` | #391 | 2026-07-12 07:06Z |
| `0.1.0-alpha.116` | `0.26.3-alpha.test108-settings-shoulder-nav.20260712.0951+f276213` | alpha | `f276213` | #413 | 2026-07-12 09:51Z |
| `0.1.0-alpha.117` | `1.0.1-alpha.test109-gamescope-scaling.20260713.0528+b6198e4` | alpha | `b6198e4` | #460 | 2026-07-13 05:28Z |
| `0.1.0-alpha.118` | `1.0.1-alpha.test109-gamescope-scaling.20260713.0559+a98b7a1` | alpha | `a98b7a1` | #465 | 2026-07-13 05:59Z |
| `0.1.0-alpha.119` | `1.0.1-alpha.test109-gamescope-scaling.20260713.0723+873d44c` | alpha | `873d44c` | #473 | 2026-07-13 07:23Z |
| `0.1.0-beta.001` | `0.0.486.0` | beta | `2f7e0b7` | #486 | — |
| `0.1.0-beta.002` | `0.6.7-beta.20260711.0854+e7a2a4b` | beta | `e7a2a4b` | #227 | 2026-07-11 08:54Z |
| `0.1.0-beta.003` | `0.7.0-beta.20260712.0003+d40afc4` | beta | `d40afc4` | #244 | 2026-07-12 00:03Z |
| `0.1.0-beta.004` | `0.7.1-beta.20260712.0021+4a03d72` | beta | `4a03d72` | #257 | 2026-07-12 00:21Z |
| `0.1.0-beta.005` | `0.8.0-beta.20260712.0037+91d5022` | beta | `91d5022` | #263 | 2026-07-12 00:37Z |
| `0.1.0-beta.006` | `0.9.0-beta.20260712.0054+ddfd4d1` | beta | `ddfd4d1` | #279 | 2026-07-12 00:54Z |
| `0.1.0-beta.007` | `0.9.0-beta.20260712.0107+ea78ea7` | beta | `ea78ea7` | #284 | 2026-07-12 01:07Z |
| `0.1.0-beta.008` | `0.10.0-beta.20260712.0113+0cec433` | beta | `0cec433` | #287 | 2026-07-12 01:13Z |
| `0.1.0-beta.009` | `0.10.0-beta.20260712.0118+eb7b088` | beta | `eb7b088` | #291 | 2026-07-12 01:18Z |
| `0.1.0-beta.010` | `0.10.0-beta.20260712.0119+963e30c` | beta | `963e30c` | #292 | 2026-07-12 01:19Z |
| `0.1.0-beta.011` | `0.10.1-beta.20260712.0123+383f378` | beta | `383f378` | #293 | 2026-07-12 01:23Z |
| `0.1.0-beta.012` | `0.11.0-beta.20260712.0132+02cc28c` | beta | `02cc28c` | #298 | 2026-07-12 01:32Z |
| `0.1.0-beta.013` | `0.11.3-beta.20260712.0147+306cd8c` | beta | `306cd8c` | #311 | 2026-07-12 01:47Z |
| `0.1.0-beta.014` | `0.11.3-beta.20260712.0206+2d755ab` | beta | `2d755ab` | #322 | 2026-07-12 02:06Z |
| `0.1.0-beta.015` | `0.11.3-beta.20260712.0206+5f7da82` | beta | `5f7da82` | #320 | 2026-07-12 02:06Z |
| `0.1.0-beta.016` | `0.12.0-beta.20260712.0208+3ed3c8b` | beta | `3ed3c8b` | #325 | 2026-07-12 02:08Z |
| `0.1.0-beta.017` | `0.13.0-beta.20260712.0213+5d5dd4e` | beta | `5d5dd4e` | #327 | 2026-07-12 02:13Z |
| `0.1.0-beta.018` | `0.13.0-beta.20260712.0214+bf56a89` | beta | `bf56a89` | #329 | 2026-07-12 02:14Z |
| `0.1.0-beta.019` | `0.15.0-beta.20260712.0237+ce61cb9` | beta | `ce61cb9` | #347 | 2026-07-12 02:37Z |
| `0.1.0-beta.020` | `0.18.0-beta.20260712.0250+5c96250` | beta | `5c96250` | #354 | 2026-07-12 02:50Z |
| `0.1.0-beta.021` | `0.19.0-beta.20260712.0304+e203f2a` | beta | `e203f2a` | #356 | 2026-07-12 03:04Z |
| `0.1.0-beta.022` | `0.20.0-beta.20260712.0313+d9b91eb` | beta | `d9b91eb` | #359 | 2026-07-12 03:13Z |
| `0.1.0-beta.023` | `0.21.0-beta.20260712.0314+9fecaaf` | beta | `9fecaaf` | #362 | 2026-07-12 03:14Z |
| `0.1.0-beta.024` | `0.22.0-beta.20260712.0331+e1bc9c6` | beta | `e1bc9c6` | #365 | 2026-07-12 03:31Z |
| `0.1.0-beta.025` | `0.22.1-beta.20260712.0345+cc82e42` | beta | `cc82e42` | #367 | 2026-07-12 03:45Z |
| `0.1.0-beta.026` | `0.22.2-beta.20260712.0347+4e9e47e` | beta | `4e9e47e` | #369 | 2026-07-12 03:47Z |
| `0.1.0-beta.027` | `0.22.3-beta.20260712.0351+bf7b5bb` | beta | `bf7b5bb` | #371 | 2026-07-12 03:51Z |
| `0.1.0-beta.028` | `0.23.0-beta.20260712.0542+43c6445` | beta | `43c6445` | #379 | 2026-07-12 05:42Z |
| `0.1.0-beta.029` | `0.23.1-beta.20260712.0601+025eb18` | beta | `025eb18` | #383 | 2026-07-12 06:01Z |
| `0.1.0-beta.030` | `0.24.0-beta.20260712.0614+c2f99d6` | beta | `c2f99d6` | #385 | 2026-07-12 06:14Z |
| `0.1.0-beta.031` | `0.24.1-beta.20260712.0633+f9861b5` | beta | `f9861b5` | #386 | 2026-07-12 06:33Z |
| `0.1.0-beta.032` | `0.24.2-beta.20260712.0640+6ab6799` | beta | `6ab6799` | #388 | 2026-07-12 06:40Z |
| `0.1.0-beta.033` | `0.25.0-beta.20260712.0708+a2231cb` | beta | `a2231cb` | #391 | 2026-07-12 07:08Z |
| `0.1.0-beta.034` | `0.25.3-beta.20260712.0751+2542454` | beta | `2542454` | #401 | 2026-07-12 07:51Z |
| `0.1.0-beta.035` | `0.25.4-beta.20260712.0806+c34b99c` | beta | `c34b99c` | #403 | 2026-07-12 08:06Z |
| `0.1.0-beta.036` | `0.26.0-beta.20260712.0848+77fd3c7` | beta | `77fd3c7` | #406 | 2026-07-12 08:48Z |
| `0.1.0-beta.037` | `0.26.2-beta.20260712.0931+524534b` | beta | `524534b` | #409 | 2026-07-12 09:31Z |
| `0.1.0-beta.038` | `0.26.5-beta.20260712.1003+2a25469` | beta | `2a25469` | #419 | 2026-07-12 10:03Z |
| `0.1.0-beta.039` | `1.0.0-beta.20260712.1125+74fc67d` | beta | `74fc67d` | #429 | 2026-07-12 11:25Z |
| `0.1.0-beta.040` | `1.0.0-beta.20260712.1152+77e3501` | beta | `77e3501` | #432 | 2026-07-12 11:52Z |
| `0.1.0-beta.041` | `1.0.0-beta.20260712.1217+9d429ed` | beta | `9d429ed` | #434 | 2026-07-12 12:17Z |
| `0.1.0-beta.042` | `1.0.0-beta.20260712.1317+60d95b3` | beta | `60d95b3` | #436 | 2026-07-12 13:17Z |
| `0.1.0-beta.043` | `1.0.0-beta.20260712.1348+2db0667` | beta | `2db0667` | #438 | 2026-07-12 13:48Z |
| `0.1.0-beta.044` | `1.0.0-beta.20260712.1359+516ba04` | beta | `516ba04` | #440 | 2026-07-12 13:59Z |
| `0.1.0-beta.045` | `1.0.0-beta.20260713.0208+24c27ee` | beta | `24c27ee` | #443 | 2026-07-13 02:08Z |
| `0.1.0-beta.046` | `1.0.0` | stable (pre-scheme) | `2068768` | #446 | 2026-07-13 |
| `0.1.0-beta.047` | `1.0.1-beta.20260713.0349+88f4619` | beta | `88f4619` | #451 | 2026-07-13 03:49Z |
| `0.1.0-beta.048` | `1.0.1-beta.20260713.0413+fce9093` | beta | `fce9093` | #453 | 2026-07-13 04:13Z |
| `0.1.0-beta.049` | `1.0.1-beta.20260713.0421+0a911e5` | beta | `0a911e5` | #455 | 2026-07-13 04:21Z |
| `0.1.0-beta.050` | `1.0.1-beta.20260713.0528+b6198e4` | beta | `b6198e4` | #460 | 2026-07-13 05:28Z |
| `0.1.0-beta.051` | `1.0.1-beta.20260713.0559+a98b7a1` | beta | `a98b7a1` | #465 | 2026-07-13 05:59Z |
| `0.1.0-beta.052` | `1.0.1` | stable (pre-scheme) | `4fd166f` | #470 | 2026-07-13 |
| `0.1.0-beta.053` | `1.1.0-beta.20260713.0756+1507a45` | beta | `1507a45` | #479 | 2026-07-13 07:56Z |
| `0.1.0-beta.054` | `0.0.481.0` | beta | `90ca8c2` | #481 | 2026-07-13 08:13Z |
| `0.1.0-beta.055` | `0.0.482.0` | beta | `f69e325` | #482 | 2026-07-13 08:19Z |
| `0.1.0-beta.056` | `0.0.485.0` | beta | `83ba993` | #485 | 2026-07-13 08:21Z |
| `0.1.0-rc.001` | `0.1.0.0` | stable cut (burnt) | `e1a12de` | #489 | 2026-07-13 09:36Z |
| `0.1.0-rc.002` | `0.1.0.0` | stable cut (burnt) | `b72c1dc` | #491 | 2026-07-13 10:10Z |
| `0.2.0-rc.001` | `0.2.0.0` | stable cut (burnt) | `e2a4dfd` | #492 | 2026-07-13 10:24Z |
| `0.3.0-rc.001` | `0.3.0.0` | stable cut (burnt) | `166eab7` | #497 | 2026-07-13 11:13Z |
| `0.3.1` | `0.3.0.1` | stable patch (superseded) | `0378e19` | #503 | 2026-07-13 11:38Z |
| `0.4.0.0` | `0.4.0.0` | stable ✅ (≡ 0.4.0) | `6715aa5` | #505 | 2026-07-13 12:06Z |
