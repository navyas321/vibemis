pragma Singleton
import QtQuick 2.9
import StreamingPreferences 1.0

// Vibemis redesign design tokens.
// Dark theme only. Canvas 1920x1200 (Legion Go S),
// scales to 1280x800 (Steam Deck) via anchors/Layouts — never hard-code coordinates against these.
// Registered as a QML singleton in app/main.cpp: qmlRegisterSingletonType(qrc:/gui/VbTokens.qml).
QtObject {
    id: t

    // ---- Color ----
    readonly property color bgApp:        "#08090B"  // outermost app bg behind the rounded window
    readonly property color bgWindow:     "#0E1013"  // main screen background
    readonly property color bgElev:       "#15181D"  // cards, panels, dialogs, sidebar rows
    readonly property color bgElev2:      "#1B1F26"  // focused/selected surface fill, chips
    readonly property color bgFooter:     "#0B0D10"  // bottom gamepad hint bar
    readonly property color stroke:       Qt.rgba(1, 1, 1, 0.08)  // default 1px card border
    readonly property color strokeSoft:   Qt.rgba(1, 1, 1, 0.06)  // header/footer dividers
    readonly property color text:         "#ECEEF1"  // primary text
    readonly property color textDim:      "#98A1AB"  // secondary / label text
    readonly property color textMute:     "#B9C0C8"  // tertiary / inactive item labels

    // Accent is swappable — one of the 4 curated values. Index 0 is the Vibemis brand
    // teal #00CCCC (BL-2077): the single canonical accent that Theme.qml + all literals now
    // resolve through, and the anchor for the P3.17/P3.18 design work.
    readonly property var accentOptions:  ["#00CCCC", "#7C8CF8", "#3ED598", "#F0A868"]
    // Bound to the saved preference (Settings > accent picker); persists across restarts.
    property int accentIndex: StreamingPreferences.uiAccentIndex
    readonly property color accent:       accentOptions[accentIndex]
    readonly property color accentHi:     "#6ADDE7"  // accent gradient light stop / link hover

    readonly property color statusOnline:  "#3ED598"  // online dot, RESUME badge
    readonly property color statusOffline: "#5A626C"  // offline dot / greyed monitor
    readonly property color statusDanger:  "#F26D6D"  // destructive (Delete PC)

    readonly property color textOnAccent: "#08090B"  // text on an accent-filled button

    // ---- Typography (families + sizes; weights per the type scale) ----
    readonly property string fontDisplay: "Sora"     // titles, card names, wordmark, all-caps labels
    readonly property string fontBody:    "Manrope"  // body + UI text
    readonly property int sizeScreenTitle:  34
    readonly property int sizeSectionTitle: 28
    readonly property int sizeCardName:     27
    readonly property int sizeBody:         16
    readonly property int sizeLabel:        14
    readonly property int sizeBadge:        13
    readonly property int sizeWordmark:     21
    readonly property real wordmarkSpacing: 3.0
    readonly property real badgeSpacing:    1.2

    // ---- Radius ----
    readonly property int radiusWindow:     20
    readonly property int radiusCard:       16
    readonly property int radiusDialog:     24
    readonly property int radiusControl:    14
    readonly property int radiusIconButton: 14
    readonly property int radiusPill:       999
    readonly property int radiusBadge:      7

    // ---- Spacing ----
    readonly property int screenPadX: 56
    readonly property int screenPadY: 52
    readonly property int headerH:    84
    readonly property int footerH:    72
    readonly property int cardGap:    32
    readonly property int tileGap:    36
    readonly property int iconButton: 52

    // ---- Gamepad ergonomics ----
    readonly property int minHitTarget: 56
    readonly property int listRowH:     66
    readonly property int buttonGlyphD: 30

    // ---- Focus ring recipe (2px accent border + 5px accent@22% glow + drop; focused fill = bgElev2) ----
    readonly property int   focusBorder:      2
    readonly property int   focusGlow:        5
    readonly property real  focusGlowAlpha:   0.22
    readonly property color focusedFill:      bgElev2
    // Semi-transparent accent for the glow layer.
    readonly property color focusGlowColor:   Qt.rgba(accent.r, accent.g, accent.b, focusGlowAlpha)

    // ---- Motion (ms) ----
    readonly property int onlinePulseMs: 2400   // opacity 1 -> 0.45 -> 1, infinite
    readonly property int caretBlinkMs:  1000   // Add-PC input caret
    readonly property int sheetInMs:     220    // side-sheet slide-in
    readonly property color dialogScrim: Qt.rgba(4/255, 5/255, 7/255, 0.72)
    readonly property color sheetScrim:  Qt.rgba(4/255, 5/255, 7/255, 0.60)

    // ---- Global UI flags ----
    property bool showHints: StreamingPreferences.uiShowHints   // gamepad hint-bar visibility (Settings toggle)

    // ========================================================================
    //  SEMANTIC TOKEN LAYER  (BL-2107 / P3.17 design pass)
    //  Role-named tokens layered OVER the base tokens above. New / restyled
    //  surfaces reference these by ROLE ("what is this element?") instead of a
    //  raw base token, so intent is explicit and a future theme swap re-points
    //  roles rather than pages. Every entry either ALIASES a base token (zero
    //  new pixels) or is a NEW value whose WCAG AA contrast on the app's actual
    //  dark surfaces is computed and tabulated in docs/DESIGN_SYSTEM.md.
    //  Purely additive — already-migrated pages that read base tokens directly
    //  (PcView, AppView, Toast, ClipboardSettings, QuickMenu) are untouched.
    // ========================================================================

    // ---- Surface / background scale (sunken -> raised) ----
    readonly property color surfaceSunken:  bgApp       // #08090B  behind the rounded window
    readonly property color surfaceBase:    bgWindow    // #0E1013  screen background
    readonly property color surfaceRaised:  bgElev      // #15181D  cards, panels, sidebar rows
    readonly property color surfaceOverlay: bgElev2     // #1B1F26  focused/selected fill, chips
    readonly property color surfaceFooter:  bgFooter    // #0B0D10  gamepad hint bar
    readonly property color divider:        stroke      // 1px card border      (white @ 8%)
    readonly property color dividerSoft:    strokeSoft  // header/footer divider (white @ 6%)

    // ---- Text hierarchy (contrast tags are vs surfaceRaised #15181D) ----
    readonly property color textPrimary:   text         // #ECEEF1  15.3:1  AAA  headings, values
    readonly property color textSecondary: textDim       // #98A1AB   6.8:1  AA   labels, secondary
    readonly property color textTertiary:  "#A9AFB6"     //           8.0:1  AAA  captions, hints, helper lines
    readonly property color textDisabled:  "#5A626C"     //           2.9:1  large/decorative only (disabled)
    // textOnAccent (#08090B) is defined in the base block above — text on an accent fill.

    // ---- Interactive states: normal / hover / focus / pressed / disabled ----
    readonly property color accentPressed:      "#00A3A3" // pressed accented control (matches legacy Theme.accentPressed)
    readonly property color interactiveHover:   bgElev2    // row / list-item / icon-button hover fill
    readonly property color interactiveFocus:   focusedFill// focused fill (= bgElev2) — pair with the focus ring
    readonly property color interactivePressed: bgElev     // pressed neutral fill (recedes under the press)
    readonly property color controlTrackOff:    "#2A2F37"  // toggle / switch OFF track (accent = ON)
    readonly property color controlTrackOn:     accent     // toggle / switch ON  track
    readonly property real  disabledOpacity:    0.38       // whole-control disabled dim (opacity multiplier)

    // ---- Status / feedback (contrast tags vs surfaceRaised #15181D) ----
    readonly property color statusSuccess: statusOnline // #3ED598  9.5:1  AAA  positive / recommended (✓)
    readonly property color statusWarning: "#E0A030"    //          7.8:1  AAA  advisory / caution (⚠) — the single amber
    readonly property color statusInfo:    "#80A0C0"    //          6.5:1  AA   neutral informational note
    // statusDanger (#F26D6D) and statusOffline (#5A626C) are defined in the base block above.

    // ---- Spacing scale (4px base, 6 steps) ----
    // Small, named intra-component scale. Screen-frame constants (screenPadX/Y,
    // headerH, cardGap, tileGap) stay as their own tuned base tokens above.
    readonly property int space1:  4   // tight: icon->text, label->helper line
    readonly property int space2:  8   // intra-component, list-row gaps
    readonly property int space3: 12   // default control spacing, group inner padding
    readonly property int space4: 16   // between form groups
    readonly property int space5: 24   // section separation
    readonly property int space6: 32   // major block separation (= cardGap)

    // ---- Type scale (6 roles; aliases over the pixel size* base tokens) ----
    // Redesign surfaces use these pixel roles with fontDisplay (titles/labels)
    // or fontBody (copy). Legacy pointSize surfaces (SettingsView) are tracked
    // for a later type pass — see docs/design/specs/.
    readonly property int typeDisplay: sizeScreenTitle  // 34  screen titles, big empty states
    readonly property int typeTitle:   sizeSectionTitle // 28  section titles
    readonly property int typeHeading: sizeCardName     // 27  card / PC names
    readonly property int typeBody:    sizeBody         // 16  body copy, control text
    readonly property int typeLabel:   sizeLabel        // 14  field labels, menu items
    readonly property int typeCaption: sizeBadge        // 13  captions, badges, hints
}
