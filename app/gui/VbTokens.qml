pragma Singleton
import QtQuick 2.9
import StreamingPreferences 1.0

// Vibemis redesign design tokens — mapped 1:1 from docs/design/redesign/tokens/vibemis-tokens.json
// (the Claude Design handoff, P3.17/P3.18). Dark theme only. Canvas 1920x1200 (Legion Go S),
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

    // Accent is swappable — one of the 4 curated values (index 0 = default #2FC6D0).
    readonly property var accentOptions:  ["#2FC6D0", "#7C8CF8", "#3ED598", "#F0A868"]
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
}
