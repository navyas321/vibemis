# Vibemis release history — the Semantic Versioning catalog

Every build this project ever published, catalogued under **[Semantic Versioning 2.0.0](https://semver.org)**
as one release train: `0.1.0-alpha.NNN` → `0.1.0-beta.NNN` → `0.1.0-rc.NNN` → **`0.1.0`**
(the first stable, sole non-prerelease, Latest). Restored and renumbered 2026-07-13 from local
clone tags, the CI run inventory (507+ runs), and git history after a release-page cleanup
deleted the originals.

## Proven properties (machine-checked against the live release API)

- **P1 Grammar totality** — all 182 tags match `^0\.1\.0(-(alpha|beta|rc)\.\d{3})?$`; zero exceptions.
- **P2 Train density** — alpha = exactly {001..119}, beta = {001..056}, rc = {001..006}; each a contiguous interval from 001; exactly one bare tag (`0.1.0`).
- **P3 Uniform increments** — in canonical order every consecutive pair is same-class with ΔN=+1, or a class boundary restarting at 001 (bare terminal). Nothing else exists. ∎
- **P4 Chronology** — within every train, catalog order is non-decreasing in commit timestamp; cross-train order is semver precedence (alpha < beta < rc < release).
- **P5 Latest invariant** — exactly one non-prerelease entry (`0.1.0`) and `/releases/latest` resolves to it.
- **P6 Completeness** — 182 entries = 119 alpha + 56 beta + 6 rc + 1 stable, accounting for every release-producing CI run.

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

## Full catalog (182 entries)

| Catalog version | Class | Commit | Run | Built |
|---|---|---|---|---|
| `0.1.0` | stable ✅ Latest | `60736b0` | #510 | 2026-07-13 13:33Z |
| `0.1.0-alpha.001` | dev | `866a377` | — | 2025-07-25 09:11Z |
| `0.1.0-alpha.002` | dev | `da2f0fc` | — | 2025-07-26 11:57Z |
| `0.1.0-alpha.003` | dev | `edb66fc` | — | 2025-07-26 21:04Z |
| `0.1.0-alpha.004` | dev | `0a1ee1d` | — | 2025-07-26 23:27Z |
| `0.1.0-alpha.005` | dev | `3ad5f158` | #20 | 2025-07-27 09:48Z |
| `0.1.0-alpha.006` | dev | `e12f2cba` | #21 | 2025-07-27 10:39Z |
| `0.1.0-alpha.007` | dev | `d4cb2222` | #22 | 2025-07-27 12:03Z |
| `0.1.0-alpha.008` | dev | `60d67f8f` | #23 | 2025-07-27 13:59Z |
| `0.1.0-alpha.009` | dev | `0ae71d0` | — | 2025-07-28 02:12Z |
| `0.1.0-alpha.010` | dev | `07c58b7` | — | 2025-07-28 07:21Z |
| `0.1.0-alpha.011` | dev | `b0f4824` | — | 2025-07-28 23:08Z |
| `0.1.0-alpha.012` | dev | `dd3f695` | — | 2025-07-29 06:16Z |
| `0.1.0-alpha.013` | dev | `eab6961` | — | 2025-07-29 11:15Z |
| `0.1.0-alpha.014` | dev | `3af6baf` | — | 2025-07-30 01:09Z |
| `0.1.0-alpha.015` | dev | `c31bc64` | — | 2025-08-04 12:08Z |
| `0.1.0-alpha.016` | dev | `eb4521c` | — | 2025-08-05 06:10Z |
| `0.1.0-alpha.017` | dev | `e60d8e4` | — | 2025-08-05 06:24Z |
| `0.1.0-alpha.018` | dev | `5ee2a96` | — | 2025-08-06 09:42Z |
| `0.1.0-alpha.019` | dev | `0677333` | — | 2025-08-07 04:26Z |
| `0.1.0-alpha.020` | dev | `2570bf2` | — | 2025-08-07 06:11Z |
| `0.1.0-alpha.021` | dev | `f564fda` | — | 2025-08-08 21:13Z |
| `0.1.0-alpha.022` | dev | `0b56fc4` | — | 2025-08-15 07:55Z |
| `0.1.0-alpha.023` | dev | `0ec85e6` | — | 2025-08-15 23:21Z |
| `0.1.0-alpha.024` | dev | `a7f5590` | — | 2025-08-18 01:15Z |
| `0.1.0-alpha.025` | dev | `e5d443a` | — | 2025-08-20 00:14Z |
| `0.1.0-alpha.026` | dev | `57c9a27` | — | 2025-08-20 01:57Z |
| `0.1.0-alpha.027` | dev | `712bd5a` | — | 2025-08-21 03:05Z |
| `0.1.0-alpha.028` | dev | `0cdeaef` | — | 2025-08-28 21:14Z |
| `0.1.0-alpha.029` | dev | `afe2de7` | — | 2025-08-31 00:17Z |
| `0.1.0-alpha.030` | alpha | `87ec098` | #104 | 2026-05-29 20:18Z |
| `0.1.0-alpha.031` | alpha | `586966b` | #108 | 2026-05-29 20:36Z |
| `0.1.0-alpha.032` | alpha | `53f4ec9` | #111 | 2026-05-29 20:57Z |
| `0.1.0-alpha.033` | alpha | `90eef29` | #112 | 2026-05-29 21:05Z |
| `0.1.0-alpha.034` | alpha | `15732f9` | #113 | 2026-05-29 21:08Z |
| `0.1.0-alpha.035` | alpha | `97bdd6f` | #116 | 2026-05-29 21:21Z |
| `0.1.0-alpha.036` | alpha | `7dbd093` | #118 | 2026-05-29 21:31Z |
| `0.1.0-alpha.037` | alpha | `5352649` | #120 | 2026-05-29 21:42Z |
| `0.1.0-alpha.038` | alpha | `9465ea6` | #121 | 2026-05-29 21:44Z |
| `0.1.0-alpha.039` | alpha | `e1817e7` | #126 | 2026-05-29 21:55Z |
| `0.1.0-alpha.040` | alpha | `0cb5fd4` | #131 | 2026-05-29 22:12Z |
| `0.1.0-alpha.041` | alpha | `7ea6c84` | #133 | 2026-05-29 22:22Z |
| `0.1.0-alpha.042` | alpha | `65168d5` | #134 | 2026-05-29 22:24Z |
| `0.1.0-alpha.043` | alpha | `0c53f09` | #146 | 2026-05-30 01:23Z |
| `0.1.0-alpha.044` | alpha | `adf5e0a` | #152 | 2026-05-30 07:02Z |
| `0.1.0-alpha.045` | alpha | `215b657` | #156 | 2026-05-30 07:14Z |
| `0.1.0-alpha.046` | alpha | `49cdb1f` | #159 | 2026-05-30 07:24Z |
| `0.1.0-alpha.047` | alpha | `8c93281` | #167 | 2026-05-30 07:55Z |
| `0.1.0-alpha.048` | alpha | `55a2c21` | #170 | 2026-05-30 08:01Z |
| `0.1.0-alpha.049` | alpha | `2f5391b` | #174 | 2026-05-30 08:22Z |
| `0.1.0-alpha.050` | alpha | `ee4a70c` | #178 | 2026-05-30 08:27Z |
| `0.1.0-alpha.051` | alpha | `a8cab24` | #190 | 2026-05-30 09:01Z |
| `0.1.0-alpha.052` | alpha | `52d5020` | #193 | 2026-05-30 09:15Z |
| `0.1.0-alpha.053` | alpha | `6281c22` | #196 | 2026-05-30 10:38Z |
| `0.1.0-alpha.054` | alpha | `ae39edd` | #210 | 2026-05-30 12:16Z |
| `0.1.0-alpha.055` | alpha | `3d1873e` | #218 | 2026-05-30 16:35Z |
| `0.1.0-alpha.056` | alpha | `4a11f8f` | #221 | 2026-05-30 16:39Z |
| `0.1.0-alpha.057` | alpha | `14e7314` | #225 | 2026-05-30 18:01Z |
| `0.1.0-alpha.058` | alpha | `010b36c` | #232 | 2026-07-11 23:48Z |
| `0.1.0-alpha.059` | alpha | `e04647a` | #233 | 2026-07-11 23:53Z |
| `0.1.0-alpha.060` | alpha | `a5b888a` | #247 | 2026-07-12 00:08Z |
| `0.1.0-alpha.061` | alpha | `c51a2f0` | #248 | 2026-07-12 00:08Z |
| `0.1.0-alpha.062` | alpha | `6e2a620` | #249 | 2026-07-12 00:08Z |
| `0.1.0-alpha.063` | alpha | `7ce593f` | #251 | 2026-07-12 00:10Z |
| `0.1.0-alpha.064` | alpha | `5f51830` | #253 | 2026-07-12 00:12Z |
| `0.1.0-alpha.065` | alpha | `66f537f` | #254 | 2026-07-12 00:13Z |
| `0.1.0-alpha.066` | alpha | `0a4396f` | #256 | 2026-07-12 00:14Z |
| `0.1.0-alpha.067` | alpha | `8fb0168` | #255 | 2026-07-12 00:14Z |
| `0.1.0-alpha.068` | alpha | `93e45bc` | #258 | 2026-07-12 00:22Z |
| `0.1.0-alpha.069` | alpha | `756ffd7` | #262 | 2026-07-12 00:28Z |
| `0.1.0-alpha.070` | alpha | `639de73` | #267 | 2026-07-12 00:40Z |
| `0.1.0-alpha.071` | alpha | `73ce477` | #269 | 2026-07-12 00:41Z |
| `0.1.0-alpha.072` | alpha | `39eca57` | #270 | 2026-07-12 00:42Z |
| `0.1.0-alpha.073` | alpha | `cb66a91` | #271 | 2026-07-12 00:42Z |
| `0.1.0-alpha.074` | alpha | `53842ae` | #278 | 2026-07-12 00:48Z |
| `0.1.0-alpha.075` | alpha | `21540ac` | #280 | 2026-07-12 01:02Z |
| `0.1.0-alpha.076` | alpha | `0c33360` | #281 | 2026-07-12 01:02Z |
| `0.1.0-alpha.077` | alpha | `99527db` | #285 | 2026-07-12 01:08Z |
| `0.1.0-alpha.078` | alpha | `cbbb8d7` | #288 | 2026-07-12 01:17Z |
| `0.1.0-alpha.079` | alpha | `d366cad` | #290 | 2026-07-12 01:18Z |
| `0.1.0-alpha.080` | alpha | `36775e0` | #295 | 2026-07-12 01:27Z |
| `0.1.0-alpha.081` | alpha | `37d07dd` | #299 | 2026-07-12 01:33Z |
| `0.1.0-alpha.082` | alpha | `314846c` | #300 | 2026-07-12 01:36Z |
| `0.1.0-alpha.083` | alpha | `a8cebba` | #301 | 2026-07-12 01:41Z |
| `0.1.0-alpha.084` | alpha | `7dd0506` | #303 | 2026-07-12 01:43Z |
| `0.1.0-alpha.085` | alpha | `b897b75` | #307 | 2026-07-12 01:44Z |
| `0.1.0-alpha.086` | alpha | `4be23ca` | #309 | 2026-07-12 01:44Z |
| `0.1.0-alpha.087` | alpha | `a6c9564` | #312 | 2026-07-12 01:48Z |
| `0.1.0-alpha.088` | alpha | `0b8ba79` | #313 | 2026-07-12 01:48Z |
| `0.1.0-alpha.089` | alpha | `34ef441` | #314 | 2026-07-12 01:48Z |
| `0.1.0-alpha.090` | alpha | `c0cbba1` | #316 | 2026-07-12 02:01Z |
| `0.1.0-alpha.091` | alpha | `49886c7` | #319 | 2026-07-12 02:05Z |
| `0.1.0-alpha.092` | alpha | `b429805` | #321 | 2026-07-12 02:06Z |
| `0.1.0-alpha.093` | alpha | `2816817` | #324 | 2026-07-12 02:08Z |
| `0.1.0-alpha.094` | alpha | `a5eb640` | #326 | 2026-07-12 02:12Z |
| `0.1.0-alpha.095` | alpha | `4d8f830` | #330 | 2026-07-12 02:14Z |
| `0.1.0-alpha.096` | alpha | `6c68ac5` | #344 | 2026-07-12 02:32Z |
| `0.1.0-alpha.097` | alpha | `4067506` | #346 | 2026-07-12 02:36Z |
| `0.1.0-alpha.098` | alpha | `556010f` | #348 | 2026-07-12 02:46Z |
| `0.1.0-alpha.099` | alpha | `8fbfc25` | #350 | 2026-07-12 02:48Z |
| `0.1.0-alpha.100` | alpha | `1d6420b` | #353 | 2026-07-12 02:50Z |
| `0.1.0-alpha.101` | alpha | `34fc1b7` | #355 | 2026-07-12 03:04Z |
| `0.1.0-alpha.102` | alpha | `06ac125` | #357 | 2026-07-12 03:09Z |
| `0.1.0-alpha.103` | alpha | `70d3384` | #361 | 2026-07-12 03:14Z |
| `0.1.0-alpha.104` | alpha | `b6f8c1e` | #364 | 2026-07-12 03:31Z |
| `0.1.0-alpha.105` | alpha | `f454b9b` | #366 | 2026-07-12 03:45Z |
| `0.1.0-alpha.106` | alpha | `df5d6c4` | #368 | 2026-07-12 03:46Z |
| `0.1.0-alpha.107` | alpha | `aa954a2` | #370 | 2026-07-12 03:50Z |
| `0.1.0-alpha.108` | alpha | `bf7b5bb` | #371 | 2026-07-12 03:54Z |
| `0.1.0-alpha.109` | alpha | `bf7b5bb` | #371 | 2026-07-12 03:54Z |
| `0.1.0-alpha.110` | alpha | `82174ee` | #374 | 2026-07-12 04:16Z |
| `0.1.0-alpha.111` | alpha | `790a10d` | #376 | 2026-07-12 05:15Z |
| `0.1.0-alpha.112` | alpha | `1111697` | #377 | 2026-07-12 05:33Z |
| `0.1.0-alpha.113` | alpha | `5cb9b6e` | #381 | 2026-07-12 05:58Z |
| `0.1.0-alpha.114` | alpha | `9512136` | #382 | 2026-07-12 05:58Z |
| `0.1.0-alpha.115` | alpha | `a2231cb` | #391 | 2026-07-12 07:06Z |
| `0.1.0-alpha.116` | alpha | `f276213` | #413 | 2026-07-12 09:51Z |
| `0.1.0-alpha.117` | alpha | `b6198e4` | #460 | 2026-07-13 05:28Z |
| `0.1.0-alpha.118` | alpha | `a98b7a1` | #465 | 2026-07-13 05:59Z |
| `0.1.0-alpha.119` | alpha | `873d44c` | #473 | 2026-07-13 07:23Z |
| `0.1.0-beta.001` | beta | `e7a2a4b` | #227 | 2026-07-11 08:54Z |
| `0.1.0-beta.002` | beta | `d40afc4` | #244 | 2026-07-12 00:03Z |
| `0.1.0-beta.003` | beta | `4a03d72` | #257 | 2026-07-12 00:21Z |
| `0.1.0-beta.004` | beta | `91d5022` | #263 | 2026-07-12 00:37Z |
| `0.1.0-beta.005` | beta | `ddfd4d1` | #279 | 2026-07-12 00:54Z |
| `0.1.0-beta.006` | beta | `ea78ea7` | #284 | 2026-07-12 01:07Z |
| `0.1.0-beta.007` | beta | `0cec433` | #287 | 2026-07-12 01:13Z |
| `0.1.0-beta.008` | beta | `eb7b088` | #291 | 2026-07-12 01:18Z |
| `0.1.0-beta.009` | beta | `963e30c` | #292 | 2026-07-12 01:19Z |
| `0.1.0-beta.010` | beta | `383f378` | #293 | 2026-07-12 01:23Z |
| `0.1.0-beta.011` | beta | `02cc28c` | #298 | 2026-07-12 01:32Z |
| `0.1.0-beta.012` | beta | `306cd8c` | #311 | 2026-07-12 01:47Z |
| `0.1.0-beta.013` | beta | `2d755ab` | #322 | 2026-07-12 02:06Z |
| `0.1.0-beta.014` | beta | `5f7da82` | #320 | 2026-07-12 02:06Z |
| `0.1.0-beta.015` | beta | `3ed3c8b` | #325 | 2026-07-12 02:08Z |
| `0.1.0-beta.016` | beta | `5d5dd4e` | #327 | 2026-07-12 02:13Z |
| `0.1.0-beta.017` | beta | `bf56a89` | #329 | 2026-07-12 02:14Z |
| `0.1.0-beta.018` | beta | `ce61cb9` | #347 | 2026-07-12 02:37Z |
| `0.1.0-beta.019` | beta | `5c96250` | #354 | 2026-07-12 02:50Z |
| `0.1.0-beta.020` | beta | `e203f2a` | #356 | 2026-07-12 03:04Z |
| `0.1.0-beta.021` | beta | `d9b91eb` | #359 | 2026-07-12 03:13Z |
| `0.1.0-beta.022` | beta | `9fecaaf` | #362 | 2026-07-12 03:14Z |
| `0.1.0-beta.023` | beta | `e1bc9c6` | #365 | 2026-07-12 03:31Z |
| `0.1.0-beta.024` | beta | `cc82e42` | #367 | 2026-07-12 03:45Z |
| `0.1.0-beta.025` | beta | `4e9e47e` | #369 | 2026-07-12 03:47Z |
| `0.1.0-beta.026` | beta | `bf7b5bb` | #371 | 2026-07-12 03:51Z |
| `0.1.0-beta.027` | beta | `43c6445` | #379 | 2026-07-12 05:42Z |
| `0.1.0-beta.028` | beta | `025eb18` | #383 | 2026-07-12 06:01Z |
| `0.1.0-beta.029` | beta | `c2f99d6` | #385 | 2026-07-12 06:14Z |
| `0.1.0-beta.030` | beta | `f9861b5` | #386 | 2026-07-12 06:33Z |
| `0.1.0-beta.031` | beta | `6ab6799` | #388 | 2026-07-12 06:40Z |
| `0.1.0-beta.032` | beta | `a2231cb` | #391 | 2026-07-12 07:08Z |
| `0.1.0-beta.033` | beta | `2542454` | #401 | 2026-07-12 07:51Z |
| `0.1.0-beta.034` | beta | `c34b99c` | #403 | 2026-07-12 08:06Z |
| `0.1.0-beta.035` | beta | `77fd3c7` | #406 | 2026-07-12 08:48Z |
| `0.1.0-beta.036` | beta | `524534b` | #409 | 2026-07-12 09:31Z |
| `0.1.0-beta.037` | beta | `2a25469` | #419 | 2026-07-12 10:03Z |
| `0.1.0-beta.038` | beta | `74fc67d` | #429 | 2026-07-12 11:25Z |
| `0.1.0-beta.039` | beta | `77e3501` | #432 | 2026-07-12 11:52Z |
| `0.1.0-beta.040` | beta | `9d429ed` | #434 | 2026-07-12 12:17Z |
| `0.1.0-beta.041` | beta | `60d95b3` | #436 | 2026-07-12 13:17Z |
| `0.1.0-beta.042` | beta | `2db0667` | #438 | 2026-07-12 13:48Z |
| `0.1.0-beta.043` | beta | `516ba04` | #440 | 2026-07-12 13:59Z |
| `0.1.0-beta.044` | beta | `24c27ee` | #443 | 2026-07-13 02:08Z |
| `0.1.0-beta.045` | stable (pre-scheme) | `2068768` | #446 | 2026-07-13 |
| `0.1.0-beta.046` | beta | `88f4619` | #451 | 2026-07-13 03:49Z |
| `0.1.0-beta.047` | beta | `fce9093` | #453 | 2026-07-13 04:13Z |
| `0.1.0-beta.048` | beta | `0a911e5` | #455 | 2026-07-13 04:21Z |
| `0.1.0-beta.049` | beta | `b6198e4` | #460 | 2026-07-13 05:28Z |
| `0.1.0-beta.050` | beta | `a98b7a1` | #465 | 2026-07-13 05:59Z |
| `0.1.0-beta.051` | stable (pre-scheme) | `4fd166f` | #470 | 2026-07-13 |
| `0.1.0-beta.052` | beta | `1507a45` | #479 | 2026-07-13 07:56Z |
| `0.1.0-beta.053` | beta | `90ca8c2` | #481 | 2026-07-13 08:13Z |
| `0.1.0-beta.054` | beta | `f69e325` | #482 | 2026-07-13 08:19Z |
| `0.1.0-beta.055` | beta | `83ba993` | #485 | 2026-07-13 08:21Z |
| `0.1.0-beta.056` | beta | `2f7e0b7` | #486 | 2026-07-13 08:46Z |
| `0.1.0-rc.001` | stable cut (rc, burnt) | `e1a12de` | #489 | 2026-07-13 09:36Z |
| `0.1.0-rc.002` | stable cut (rc, burnt) | `b72c1dc` | #491 | 2026-07-13 10:10Z |
| `0.1.0-rc.003` | stable cut (rc, burnt) | `e2a4dfd` | #492 | 2026-07-13 10:24Z |
| `0.1.0-rc.004` | stable cut (rc, burnt) | `166eab7` | #497 | 2026-07-13 11:13Z |
| `0.1.0-rc.005` | stable patch cut (rc, superseded; artifact) | `0378e19` | #503 | 2026-07-13 11:38Z |
| `0.1.0-rc.006` | adopted candidate (rc; ran on device; artifact) | `6715aa5` | #505 | 2026-07-13 12:06Z |
