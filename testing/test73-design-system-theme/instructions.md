# test73 — Design-system Theme token singleton (P3.17)

**Branch:** `test73-design-system-theme` · **Base:** `vibemis-main` · **Type:** launcher-only
**What changed:** Introduces `app/gui/Theme.qml`, a QML **singleton** of design tokens
(colors / type sizes / spacing — see `docs/DESIGN_SYSTEM.md`), registered in `app/main.cpp` via
`qmlRegisterSingletonType(QUrl("qrc:/gui/Theme.qml"), "Theme", 1, 0, "Theme")`. As the first
*use*, `main.qml`'s top-right **"Version X"** label (shown only on the Settings screen) now reads
its color/size from `Theme.accent` / `Theme.fontSection`.

**Why this matters / what to confirm:** This is infrastructure — the visual change is intentionally
tiny. The real test is that **the Theme singleton resolves at runtime**. Because `main.qml` does
`import Theme 1.0` at the top, a broken registration would make the *whole app fail to load*. So
"app launches + Settings shows a teal version label + no Theme errors in the log" = PASS.

No host, pairing, or stream needed.

---

## Tier 1 — app launches and the Theme singleton resolves

1. `./testing/run-cycle.sh test73-design-system-theme` — fetches the alpha, verifies md5, runs
   `selftest --json`, captures a launch log.
   - **Expect:** `selftest --json` → **exit 0** (the app fully initialised the QML engine, which
     means `import Theme 1.0` resolved — a bad singleton registration would abort startup).
2. Launch the app to the main window (the harness already does a bounded launch). Grep the launch log:
   ```
   grep -iE "Theme|is not a type|Singleton|QQmlApplicationEngine failed|SettingsView" /tmp/vibemis-test73-design-system-theme.log
   ```
   - **PASS signal:** no `Theme is not a type`, no `QQmlApplicationEngine failed to load`, no
     QML error mentioning `Theme`. (Lines merely *naming* Theme are fine; errors are not.)
3. Open the app, go to **Settings**. Look at the **top-right of the toolbar**: the **"Version …"**
   text should render in **Vibemis teal (#00CCCC)** (previously default white/grey).
   - Screenshot it: Desktop Mode `spectacle -b -n -a -o /tmp/test73-version-teal.png`; Game Mode
     **Super+S**.

**Tier 1 PASS** = selftest exit 0 **and** no Theme-related QML error in the log **and** the Settings
version label is teal.

## Tier 2 — no regression

- Settings opens and scrolls normally; all sections render as before (only the version label color
  changed). Computers/Add-PC screens and navigation are unaffected.
- No new `Critical`/`Warning` QML lines vs. a previous build. Quote any you see.

## Report

`testing/test73-design-system-theme/report.md`: TL;DR table (Tier 1 / Tier 2) → evidence (selftest
exit, grep result, the teal-version screenshot) → recommendation. Tick the `test73` row in
`TEST_CHECKLIST.md` in the same commit. If the app fails to launch or the log shows a `Theme`
type/singleton error, that's a **FAIL (ITERATE)** — quote the exact error line.
