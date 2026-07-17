pragma Singleton
import QtQuick 2.9

// Vibemis design tokens. Single source of truth for color/type/spacing — see
// docs/DESIGN_SYSTEM.md. Import as `import Theme 1.0` and reference e.g. Theme.accent,
// Theme.spacingM, Theme.fontSection. Registered as a QML singleton in app/main.cpp via
// qmlRegisterSingletonType(QUrl("qrc:/gui/Theme.qml"), "Theme", 1, 0, "Theme").
QtObject {
    // ---- Color ----
    readonly property color accent:        "#00CCCC"  // Vibemis teal — interactive emphasis
    readonly property color accentPressed: "#00A3A3"
    readonly property color background:    "#303030"  // app root
    readonly property color surface:       "#2D2D2D"  // raised surfaces / overlays
    readonly property color surfaceAlt:    "#424242"  // popups / combo dropdowns
    readonly property color border:        "#444444"
    readonly property color textPrimary:   "#FFFFFF"
    readonly property color textSecondary: "#CCCCCC"
    readonly property color textTertiary:  "#AAAAAA"
    readonly property color textDisabled:  "#777777"
    readonly property color success:       "#4CAF50"
    readonly property color warning:       "#E0A030"  // the single amber
    readonly property color error:         "#F44336"
    readonly property color info:          "#80A0C0"
    readonly property color scrim:         "#D0000000"

    // ---- Typography (pointSize; pair with bold where noted in DESIGN_SYSTEM.md) ----
    readonly property int fontDisplay: 24  // overlay/Quick Menu title (bold)
    readonly property int fontTitle:   20  // screen/toolbar titles (bold)
    readonly property int fontHeading: 14  // card titles, menu primary (bold)
    readonly property int fontSection: 12  // GroupBox section titles (bold)
    readonly property int fontBody:    11  // standard labels/body
    readonly property int fontCaption:  9  // hints, descriptions, advisories

    // ---- Spacing (4px base) ----
    readonly property int spacingXS:  4
    readonly property int spacingS:   8
    readonly property int spacingM:  12
    readonly property int spacingL:  16
    readonly property int spacingXL: 24

    // ---- Shape ----
    readonly property int radius:      10  // cards / overlays / toasts
    readonly property int radiusS:      5  // buttons / chips
    readonly property int borderWidth:  1

    // ---- Ergonomics (handheld touch/focus targets) ----
    readonly property int touchMinHeight: 40
    readonly property int touchMinWidth:  88
}
