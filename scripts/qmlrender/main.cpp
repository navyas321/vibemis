// Vibemis QML render harness (BL-1688/BL-1699): renders a QML file offscreen with the
// app's real fonts + VbTokens singleton and saves a PNG. Used to validate in-stream
// overlay layouts (Quick Menu) that can't be render-tested by launching the full app
// off-device. Usage: qmlrender <scene.qml> <out.png> [holdMs]
#include <QGuiApplication>
#include <QQuickView>
#include <QQuickItem>
#include <QQmlEngine>
#include <QFontDatabase>
#include <QTimer>
#include <QImage>
#include <QUrl>
#include <QDebug>

int main(int argc, char** argv) {
    if (argc < 3) {
        fprintf(stderr, "usage: qmlrender <scene.qml> <out.png> [holdMs]\n");
        return 1;
    }
    qputenv("QT_QUICK_BACKEND", "software");   // no GPU needed (WSL-safe)
    QGuiApplication app(argc, argv);

    // The device fonts — fallback metrics differ and lie about clipping (the
    // text-cutoff RCA), so load the real ones.
    QFontDatabase::addApplicationFont(QStringLiteral(FONT_DIR "/Sora.ttf"));
    QFontDatabase::addApplicationFont(QStringLiteral(FONT_DIR "/Manrope.ttf"));

    // Same registrations the app performs (main.cpp) so gui/*.qml load unmodified.
    qmlRegisterModule("ServerCommandManager", 1, 0);   // imported, no types used
    // VbTokens reads two prefs (accent index, hint visibility) — shim singleton.
    qmlRegisterSingletonType(QUrl::fromLocalFile(QStringLiteral(SHIM_DIR "/StreamingPreferences.qml")),
                             "StreamingPreferences", 1, 0, "StreamingPreferences");
    qmlRegisterSingletonType(QUrl::fromLocalFile(QStringLiteral(GUI_DIR "/VbTokens.qml")),
                             "Vibemis.Redesign", 1, 0, "VbTokens");

    QQuickView view;
    view.setResizeMode(QQuickView::SizeViewToRootObject);
    view.setSource(QUrl::fromLocalFile(QString::fromLocal8Bit(argv[1])));
    if (view.status() == QQuickView::Error) {
        const auto errs = view.errors();
        for (const auto& e : errs) {
            qWarning() << e;
        }
        return 2;
    }
    view.show();

    int holdMs = argc > 3 ? atoi(argv[3]) : 900;

    // BL-1709: optional key simulation — 4th arg like "Up,Up,Down" posts real key
    // events to the window between render settle and grab, printing the active focus
    // item's objectName after each press so nav flows can be validated headlessly.
    QString keyScript = argc > 4 ? QString::fromLocal8Bit(argv[4]) : QString();

    QTimer::singleShot(holdMs, &app, [&, keyScript]() {
        if (!keyScript.isEmpty()) {
            const QStringList keys = keyScript.split(',', Qt::SkipEmptyParts);
            for (const QString& k : keys) {
                int keyCode = Qt::Key_unknown;
                Qt::KeyboardModifiers mods = Qt::NoModifier;
                QString kk = k.trimmed().toLower();
                if (kk == "up") keyCode = Qt::Key_Up;
                else if (kk == "down") keyCode = Qt::Key_Down;
                else if (kk == "left") keyCode = Qt::Key_Left;
                else if (kk == "right") keyCode = Qt::Key_Right;
                else if (kk == "tab") keyCode = Qt::Key_Tab;
                else if (kk == "backtab") { keyCode = Qt::Key_Tab; mods = Qt::ShiftModifier; }
                else if (kk == "esc") keyCode = Qt::Key_Escape;
                else if (kk == "return") keyCode = Qt::Key_Return;
                if (keyCode == Qt::Key_unknown) continue;
                QKeyEvent press(QEvent::KeyPress, keyCode, mods);
                QKeyEvent release(QEvent::KeyRelease, keyCode, mods);
                QCoreApplication::sendEvent(&view, &press);
                QCoreApplication::sendEvent(&view, &release);
                QQuickItem* f = view.activeFocusItem();
                fprintf(stdout, "AFTER %s: focus=%s\n", k.trimmed().toUtf8().constData(),
                        f ? (f->objectName().isEmpty() ? f->metaObject()->className()
                                                       : f->objectName().toUtf8().constData())
                          : "<none>");
            }
        }
        QImage img = view.grabWindow();
        bool ok = !img.isNull() && img.save(QString::fromLocal8Bit(argv[2]));
        fprintf(stdout, "RENDER %s: %dx%d -> %s\n", ok ? "OK" : "FAIL",
                img.width(), img.height(), argv[2]);
        app.exit(ok ? 0 : 3);
    });
    return app.exec();
}
