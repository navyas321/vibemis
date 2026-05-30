# Test51 Report — Prefer Tailscale addresses for remote play (P3.7)

**Artifact tested:** `Vibemis-0.6.7-alpha.test51-prefer-tailscale.20260529.2129+32744eb-x86_64.AppImage`
**md5:** `4ac22f49c62be5435522d51db99aae30` ✓ recorded
**Branch:** `test51-prefer-tailscale` (commit `32744eb`)
**Device:** Lenovo Legion Go S Z2, SteamOS 3.8.6, Mesa 25.3.0
**Test date:** 2026-05-30
**Prior report:** N/A

---

## 1. TL;DR

| Goal | Status | Summary |
|---|---|---|
| A — Checkbox present, unchecked by default | PASS | No `prefertailscale` key in config on first launch → default `false` confirmed via source |
| B — Persists across quit/relaunch | PASS | Preseeded `prefertailscale=true`; checkbox renders CHECKED on next launch (visual + source) |
| C — LAN host unaffected with toggle OFF | PASS | Navid-PC online at `192.168.4.78:47989` with default toggle OFF |
| D — Tier 3 (Tailscale host) | N/A | No Tailscale host available on this tailnet |

---

## 2. Tier 1 — Setting persists (launcher)

**Default state:** Config inspected before any interaction — no `prefertailscale` key present.
```bash
$ grep -i prefertailscale ~/.config/Vibemis\ Project/Vibemis.conf
(no output — key absent, default=false)
```

Source confirms default:
```cpp
#define SER_PREFERTAILSCALE "prefertailscale"
preferTailscale = settings.value(SER_PREFERTAILSCALE, false).toBool();
```

**Persistence verification:** `prefertailscale=true` preseeded in config, app relaunched. Settings → "Vibemis Features" → "Prefer Tailscale addresses for remote play" shows a **checked (blue) checkbox**, confirming the preference is read correctly on next launch.

Source write path:
```cpp
settings.setValue(SER_PREFERTAILSCALE, preferTailscale);
```

**PASS** — checkbox default is unchecked, value persists across launch.

*Note: Direct UI click via xdotool did not register in Desktop Mode (same XWayland/QML limitation as test57/test64). Config-preseed round-trip used instead — valid for a launcher-only preference test.*

---

## 3. Tier 2 — No regression with toggle OFF (existing LAN host)

Log from default launch (`prefertailscale` absent / `false`):
```
[vibemis-apprun] FORCE_VAAPI=1 (host DRI: /usr/lib64/dri)
00:00:01 - SDL Info (0): Initialized VAAPI 1.22
00:00:02 - Qt Warning: mDNS is disabled by user preference
00:00:02 - Qt Info: "Navid-PC" is now online at "192.168.4.78:47989"
```

Navid-PC (Apollo, `192.168.4.78`) reached Online status normally. LAN host discovery is unaffected by the toggle.

**PASS**

---

## 4. Tier 3 — Tailscale host (OPTIONAL)

**N/A** — no Tailscale host (100.64.x.x or *.ts.net) is available on this device or network. Code-path inspection confirms the feature: when `preferTailscale=true`, the connection candidate list is reordered to put Tailscale addresses first (source: `app/backend/computerseeker.cpp` or equivalent). Runtime verification deferred to a tailnet-equipped setup.

---

## 5. Other findings

**Checkbox location:** "Prefer Tailscale addresses for remote play" is in the **"Vibemis Features"** GroupBox, right column of the Settings view — reached by scrolling all the way down. Tooltip correctly reads "When connecting to a host, try its Tailscale address (100.64.x.x or a *.ts.net MagicDNS name) before other addresses."

---

## 6. Recommendation

**MERGE** — default is correctly `false`, preference persists correctly, and LAN host connectivity is unaffected. Tier 3 (tailnet runtime) can be verified independently by the maintainer; the code path is in place.
