#include "quickmenumanager.h"
#include "servercommandmanager.h"
#include "clipboardmanager.h"
#include "../streaming/session.h"
#include "../streaming/input/input.h"
#include "../settings/streamingpreferences.h"

#include <Limelight.h>
#include <cstring>

// Forward declaration of KeyCombo enum values
enum KeyCombo {
    KeyComboQuit,
    KeyComboUngrabInput,
    KeyComboToggleFullScreen,
    KeyComboToggleStatsOverlay,
    KeyComboToggleMouseMode,
    KeyComboToggleCursorHide,
    KeyComboToggleMinimize,
    KeyComboPasteText,
    KeyComboTogglePointerRegionLock,
    KeyComboQuitAndExit,
    KeyComboToggleQuickMenu,
    KeyComboMax
};

#include <QQmlContext>
#include <QQmlEngine>
#include <QQmlComponent>
#include <QGuiApplication>
#include <QQuickItem>
#include <QQuickWindow>
#include <QQuickRenderControl>
#include <QQuickRenderTarget>
#include <QQuickGraphicsDevice>
#include <QOpenGLContext>
#include <QOffscreenSurface>
#include <QOpenGLFramebufferObject>
#include <QSurfaceFormat>
#include <QImage>
#include <QKeyEvent>
#include <QTimer>
#include <QWindow>
#include <QUrl>
#include <QDesktopServices>
#include <QDebug>

#include <SDL.h>
#include <Limelight.h>

// How often the offscreen menu is re-rendered while visible. The menu is small
// (500x400) and this only runs while the menu is open, so a 30 Hz refresh keeps
// animations/selection highlights smooth at negligible cost.
static const int kRenderIntervalMs = 33;

// BL-1665: gamepad nav auto-repeat. Hold ~380ms before repeating, then advance the selection
// every ~90ms — the same "delay then fast repeat" cadence keyboards use, so holding the d-pad
// or pushing the left stick scrolls the menu continuously instead of moving exactly once.
static const int kNavRepeatInitialMs = 380;
static const int kNavRepeatMs = 90;

QuickMenuManager::QuickMenuManager(QObject *parent)
    : QObject(parent)
    , m_isVisible(false)
    , m_serverCommandManager(nullptr)
    , m_clipboardManager(nullptr)
    , m_isFullscreen(false)
    , m_isMouseCaptured(false)
    , m_isKeyboardCaptured(false)
    , m_isStatsVisible(false)
    , m_glContext(nullptr)
    , m_offscreenSurface(nullptr)
    , m_renderControl(nullptr)
    , m_quickWindow(nullptr)
    , m_qmlEngine(nullptr)
    , m_qmlComponent(nullptr)
    , m_rootItem(nullptr)
    , m_fbo(nullptr)
    , m_renderTimer(nullptr)
    // BL-1622: the menu renders into this FBO and the renderers blit it 1:1, centered. 500x400 was
    // only ~26% of a 1920-wide stream — physically tiny + cramped. Bumped to a readable default that
    // still fits an 800px-tall surface. (A viewport-relative size is a follow-up.)
    , m_overlaySize(720, 600)
    , m_overlayReady(false)
{
    m_renderTimer = new QTimer(this);
    m_renderTimer->setInterval(kRenderIntervalMs);
    connect(m_renderTimer, &QTimer::timeout, this, &QuickMenuManager::renderToSurface);

    // BL-1665: gamepad nav auto-repeat timer.
    m_navRepeatKey = 0;
    m_navRepeatTimer = new QTimer(this);
    connect(m_navRepeatTimer, &QTimer::timeout, this, &QuickMenuManager::onNavRepeat);
}

QuickMenuManager::~QuickMenuManager()
{
    teardownOverlayRenderer();
}

bool QuickMenuManager::hasServerCommands() const
{
    if (!m_serverCommandManager) {
        return false;
    }

    // test81 (review fix): hasPermission() is a plain accessor, not Q_INVOKABLE — the
    // old QMetaObject::invokeMethod-by-name silently failed and always returned false,
    // which made "Server Commands" permanently read as unavailable. Both objects live
    // on the main thread, so a direct call is correct.
    return m_serverCommandManager->hasPermission();
}

bool QuickMenuManager::isFullscreen() const
{
    return m_isFullscreen;
}

bool QuickMenuManager::isMouseCaptured() const
{
    return m_isMouseCaptured;
}

bool QuickMenuManager::isKeyboardCaptured() const
{
    return m_isKeyboardCaptured;
}

bool QuickMenuManager::isStatsVisible() const
{
    return m_isStatsVisible;
}

void QuickMenuManager::setVisible(bool visible)
{
    if (m_isVisible == visible) {
        return;
    }

    m_isVisible = visible;

    if (visible) {
        // Lazily build the offscreen renderer on first show (main thread).
        if (!initOverlayRenderer()) {
            SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                         "QuickMenuManager: failed to initialize offscreen overlay renderer");
            m_isVisible = false;
            emit visibilityChanged();
            return;
        }

        // Reset to the main menu each time it opens.
        if (m_rootItem) {
            m_rootItem->setProperty("currentMenu", "main");
            m_rootItem->setProperty("focus", true);
            QMetaObject::invokeMethod(m_rootItem, "forceActiveFocus");
        }

        // Enable the overlay slot, render the first frame, and start the refresh loop.
        // BL-1630: fetch the Session ONCE — s_ActiveSession is cleared from a pool thread,
        // so a second Session::get() between check and use can return null mid-teardown.
        Session* session = Session::get();
        if (session) {
            session->getOverlayManager().setOverlayState(Overlay::OverlayQuickMenu, true);
        }
        renderToSurface();
        m_renderTimer->start();
    } else {
        m_renderTimer->stop();
        // BL-1665: cancel any in-flight nav auto-repeat so a held direction doesn't keep
        // firing into a hidden menu (and doesn't resume on the next open).
        m_navRepeatTimer->stop();
        m_navRepeatKey = 0;
        Session* session = Session::get();
        if (session) {
            session->getOverlayManager().setOverlayState(Overlay::OverlayQuickMenu, false);
        }
    }

    emit visibilityChanged();
}

void QuickMenuManager::toggle()
{
    setVisible(!m_isVisible);
}

void QuickMenuManager::show()
{
    setVisible(true);
}

void QuickMenuManager::hide()
{
    setVisible(false);
}

bool QuickMenuManager::initOverlayRenderer()
{
    if (m_overlayReady) {
        return true;
    }

    // 1. Dedicated OpenGL context + offscreen surface. This context is independent of
    //    SDL's video context — we render the menu to an FBO and read it back to the CPU,
    //    so there is no GL resource sharing and no dependency on a visible window.
    m_glContext = new QOpenGLContext();
    QSurfaceFormat fmt;
    fmt.setDepthBufferSize(16);
    fmt.setStencilBufferSize(8);
    m_glContext->setFormat(fmt);
    if (!m_glContext->create()) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "QuickMenuManager: QOpenGLContext::create() failed");
        teardownOverlayRenderer();
        return false;
    }

    m_offscreenSurface = new QOffscreenSurface();
    m_offscreenSurface->setFormat(m_glContext->format());
    m_offscreenSurface->create();
    if (!m_offscreenSurface->isValid()) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "QuickMenuManager: QOffscreenSurface is not valid");
        teardownOverlayRenderer();
        return false;
    }

    // 2. Render control + offscreen QQuickWindow.
    m_renderControl = new QQuickRenderControl(this);
    m_quickWindow = new QQuickWindow(m_renderControl);
    m_quickWindow->setColor(Qt::transparent);

    if (!m_glContext->makeCurrent(m_offscreenSurface)) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "QuickMenuManager: makeCurrent() failed during init");
        teardownOverlayRenderer();
        return false;
    }

    // Bind our GL context to Qt Quick's RHI so fromOpenGLTexture refers to it.
    m_quickWindow->setGraphicsDevice(QQuickGraphicsDevice::fromOpenGLContext(m_glContext));

    if (!m_renderControl->initialize()) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "QuickMenuManager: QQuickRenderControl::initialize() failed");
        m_glContext->doneCurrent();
        teardownOverlayRenderer();
        return false;
    }

    // 3. Framebuffer object as the render target.
    QOpenGLFramebufferObjectFormat fboFormat;
    fboFormat.setAttachment(QOpenGLFramebufferObject::CombinedDepthStencil);
    m_fbo = new QOpenGLFramebufferObject(m_overlaySize, fboFormat);
    m_quickWindow->setRenderTarget(
        QQuickRenderTarget::fromOpenGLTexture(m_fbo->texture(), m_overlaySize));

    // 4. Load the QML scene into our own engine.
    m_qmlEngine = new QQmlEngine(this);
    if (!m_qmlEngine->incubationController()) {
        m_qmlEngine->setIncubationController(m_quickWindow->incubationController());
    }
    m_qmlEngine->rootContext()->setContextProperty("quickMenuManager", this);

    m_qmlComponent = new QQmlComponent(m_qmlEngine, QUrl(QStringLiteral("qrc:/gui/QuickMenu.qml")), this);
    if (m_qmlComponent->isError()) {
        for (const QQmlError& err : m_qmlComponent->errors()) {
            SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                         "QuickMenuManager: QML error: %s", err.toString().toUtf8().constData());
        }
        m_glContext->doneCurrent();
        teardownOverlayRenderer();
        return false;
    }

    QObject* rootObject = m_qmlComponent->create();
    m_rootItem = qobject_cast<QQuickItem*>(rootObject);
    if (!m_rootItem) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "QuickMenuManager: QML root is not a QQuickItem");
        delete rootObject;
        m_glContext->doneCurrent();
        teardownOverlayRenderer();
        return false;
    }

    m_rootItem->setParentItem(m_quickWindow->contentItem());
    m_quickWindow->contentItem()->setSize(m_overlaySize);
    m_quickWindow->setGeometry(0, 0, m_overlaySize.width(), m_overlaySize.height());
    m_rootItem->setSize(m_overlaySize);

    m_glContext->doneCurrent();

    m_overlayReady = true;
    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "QuickMenuManager: offscreen overlay renderer initialized (%dx%d)",
                m_overlaySize.width(), m_overlaySize.height());
    return true;
}

void QuickMenuManager::renderToSurface()
{
    if (!m_overlayReady || !m_isVisible || !m_glContext || !m_fbo) {
        return;
    }

    if (!m_glContext->makeCurrent(m_offscreenSurface)) {
        return;
    }

    m_renderControl->polishItems();
    m_renderControl->beginFrame();
    m_renderControl->sync();
    m_renderControl->render();
    m_renderControl->endFrame();

    QImage image = m_fbo->toImage();
    m_glContext->doneCurrent();

    if (image.isNull()) {
        return;
    }

    // SDL_PIXELFORMAT_ARGB8888 on little-endian == QImage::Format_ARGB32 byte order.
    if (image.format() != QImage::Format_ARGB32) {
        image = image.convertToFormat(QImage::Format_ARGB32);
    }

    SDL_Surface* surface = SDL_CreateRGBSurfaceWithFormat(
        0, image.width(), image.height(), 32, SDL_PIXELFORMAT_ARGB8888);
    if (!surface) {
        return;
    }

    const int rowBytes = image.width() * 4;
    for (int y = 0; y < image.height(); ++y) {
        memcpy(static_cast<uint8_t*>(surface->pixels) + y * surface->pitch,
               image.constScanLine(y),
               rowBytes);
    }

    Session* session = Session::get();   // BL-1630: single fetch (TOCTOU vs pool-thread clear)
    if (session) {
        session->getOverlayManager().updateOverlaySurface(Overlay::OverlayQuickMenu, surface);
    } else {
        SDL_FreeSurface(surface);
    }
}

void QuickMenuManager::teardownOverlayRenderer()
{
    if (m_renderTimer) {
        m_renderTimer->stop();
    }

    // Make the context current so GL resources tear down cleanly.
    if (m_glContext && m_offscreenSurface && m_offscreenSurface->isValid()) {
        m_glContext->makeCurrent(m_offscreenSurface);
    }

    // BL-1630: destruction ORDER matters, and deleteLater() is a trap here — on the quit
    // path the event loop is already dead, so a queued deletion never runs and the live QML
    // scene would outlive its engine (crash inside the outer QQmlApplicationEngine dtor).
    // The root item is C++-owned (QQmlComponent::create()), so delete it directly, and keep
    // the engine alive until AFTER the window/render-control that host its scene are gone.
    delete m_rootItem;
    m_rootItem = nullptr;
    delete m_qmlComponent;
    m_qmlComponent = nullptr;
    delete m_fbo;
    m_fbo = nullptr;
    // test81 (review fix): the QQuickWindow was constructed WITH this render control and
    // references it during its own destruction — the window must be destroyed first.
    delete m_quickWindow;
    m_quickWindow = nullptr;
    delete m_renderControl;
    m_renderControl = nullptr;
    // Engine last (BL-1630): scene objects above may call back into it while dying.
    delete m_qmlEngine;
    m_qmlEngine = nullptr;

    if (m_glContext) {
        m_glContext->doneCurrent();
    }
    delete m_offscreenSurface;
    m_offscreenSurface = nullptr;
    delete m_glContext;
    m_glContext = nullptr;

    m_overlayReady = false;
}

void QuickMenuManager::injectKey(int qtKey)
{
    if (!m_isVisible || !m_quickWindow) {
        return;
    }

    // Deliver synthetic key press+release to the offscreen window. It is never shown,
    // so it never holds OS focus; events must be posted to it explicitly.
    QKeyEvent press(QEvent::KeyPress, qtKey, Qt::NoModifier);
    QKeyEvent release(QEvent::KeyRelease, qtKey, Qt::NoModifier);
    QCoreApplication::sendEvent(m_quickWindow, &press);
    QCoreApplication::sendEvent(m_quickWindow, &release);

    // Re-render immediately so the selection highlight updates without waiting for the
    // next timer tick.
    renderToSurface();
}

void QuickMenuManager::injectNavKey(int qtKey)
{
    if (!m_isVisible || !m_quickWindow) {
        return;
    }

    // Fire once immediately, then hold for kNavRepeatInitialMs before the fast repeat kicks in
    // (standard key-repeat feel). start() resets the interval, so a fresh press always gets the
    // full initial delay rather than inheriting the fast cadence from a previous hold.
    injectKey(qtKey);
    m_navRepeatKey = qtKey;
    m_navRepeatTimer->start(kNavRepeatInitialMs);
}

void QuickMenuManager::stopNavRepeat(int qtKey)
{
    // Only stop if the key being released is the one we're currently repeating — otherwise a
    // stale release (e.g. the left stick re-centering after a d-pad hold) would cancel an
    // unrelated active repeat.
    if (m_navRepeatKey == qtKey) {
        m_navRepeatTimer->stop();
        m_navRepeatKey = 0;
    }
}

void QuickMenuManager::onNavRepeat()
{
    if (!m_isVisible || m_navRepeatKey == 0) {
        m_navRepeatTimer->stop();
        m_navRepeatKey = 0;
        return;
    }
    injectKey(m_navRepeatKey);
    // After the first (initial-delay) fire, switch to the fast repeat cadence.
    if (m_navRepeatTimer->interval() != kNavRepeatMs) {
        m_navRepeatTimer->setInterval(kNavRepeatMs);
    }
}

void QuickMenuManager::injectText(const QString& text)
{
    if (!m_isVisible || !m_quickWindow || text.isEmpty()) {
        return;
    }
    // Deliver the character(s) as a synthetic key press carrying text — a focused
    // TextField in the offscreen scene consumes them. The key code is unimportant for
    // text entry; Qt::Key_unknown with the text payload is sufficient.
    QKeyEvent press(QEvent::KeyPress, Qt::Key_unknown, Qt::NoModifier, text);
    QKeyEvent release(QEvent::KeyRelease, Qt::Key_unknown, Qt::NoModifier, text);
    QCoreApplication::sendEvent(m_quickWindow, &press);
    QCoreApplication::sendEvent(m_quickWindow, &release);
    renderToSurface();
}

void QuickMenuManager::sendText(const QString& text)
{
    if (text.isEmpty()) {
        return;
    }
    // Send the whole string to the host as a UTF-8 text event (the OSK gap on
    // keyboard-less handhelds). moonlight-common-c takes the byte length.
    QByteArray utf8 = text.toUtf8();
    LiSendUtf8TextEvent(utf8.constData(), (unsigned int)utf8.size());
    showToast(QStringLiteral("Sent text to host"));
}

void QuickMenuManager::executeAction(const QString &action)
{
    qDebug() << "QuickMenuManager: Executing action:" << action;

    if (action == "disconnect") {
        disconnect();
    } else if (action == "quit") {
        quit();
    } else if (action == "server_commands") {
        // This is now handled in QML for navigation
        qDebug() << "Server commands navigation (handled in QML)";
    } else if (action == "server_restart") {
        executeServerCommand("restart");
    } else if (action == "server_shutdown") {
        executeServerCommand("shutdown");
    } else if (action == "server_suspend") {
        executeServerCommand("suspend");
    } else if (action == "clipboard_upload") {
        uploadClipboard();
    } else if (action == "clipboard_fetch") {
        fetchClipboard();
    } else if (action == "toggle_stats") {
        toggleStats();
    } else if (action == "toggle_mouse") {
        toggleMouseCapture();
    } else if (action == "toggle_keyboard") {
        toggleKeyboardCapture();
    } else if (action == "toggle_fullscreen") {
        toggleFullscreen();
    } else if (action == "key_ctrl_alt_del" || action == "key_super" ||
               action == "key_alt_f4" || action == "key_esc") {
        sendSpecialKey(action);
    } else if (action == "paste_clipboard") {
        pasteClipboard();
    } else if (action == "stream_info") {
        showStreamInfo();
    } else if (action == "toggle_touch_overlay") {
        toggleTouchOverlay();
    } else if (action == "open_steam_keyboard") {
        openSteamKeyboard();
    }
}

void QuickMenuManager::openTextSend()
{
    // BL-1562: show the menu (lazily initializing the offscreen renderer if needed),
    // then jump straight to the text-send view — the same path as picking "Type Text"
    // from the main menu, so field focus and text-input routing behave identically.
    // (BL-2002: no longer the overlay KBD button's target — that requests the SteamOS
    // keyboard via openSteamKeyboard(); this stays as the programmatic text-send entry.)
    show();
    if (m_rootItem) {
        QMetaObject::invokeMethod(m_rootItem, "executeAction",
                                  Q_ARG(QVariant, QStringLiteral("type_text")));
    }
}

void QuickMenuManager::openSteamKeyboard()
{
    // BL-2002: raise the SteamOS on-screen keyboard over the stream. Gamescope pops
    // the OSK for the steam://open/keyboard URL and the typed keys arrive as normal
    // key events, flowing to the host through the standard keyboard path. SDL_OpenURL
    // (SDL >= 2.0.14) needs no Qt platform URL handler, so try it first; fall back to
    // QDesktopServices for older SDL or on SDL failure.
    bool requested = false;
#if SDL_VERSION_ATLEAST(2, 0, 14)
    requested = SDL_OpenURL("steam://open/keyboard") == 0;
#endif
    if (!requested) {
        requested = QDesktopServices::openUrl(QUrl(QStringLiteral("steam://open/keyboard")));
    }

    // "requested", not "opened": QDesktopServices can report success whenever a URL
    // handler launches, even if no keyboard actually rises (Steam absent but handler
    // registered) — the toast must not overclaim.
    showToast(requested ? QStringLiteral("Steam keyboard requested")
                        : QStringLiteral("Steam not available"));
}

void QuickMenuManager::commitTouchMode(bool absoluteTouchMode)
{
    // BL-2007: the SDL input thread already flipped its live m_AbsoluteTouchMode —
    // mirror the new mode into the persisted preference (the Settings toggle stays
    // in sync through the NOTIFY signal) and announce it.
    auto prefs = StreamingPreferences::get();
    prefs->absoluteTouchMode = absoluteTouchMode;
    prefs->save();
    emit prefs->absoluteTouchModeChanged();

    showToast(absoluteTouchMode ? QStringLiteral("Touch mode: Direct touch")
                                : QStringLiteral("Touch mode: Virtual trackpad"));
}

void QuickMenuManager::toggleTouchOverlay()
{
    // BL-1562: flip + persist the preference, then apply it to the live session.
    auto prefs = StreamingPreferences::get();
    prefs->enableTouchOverlay = !prefs->enableTouchOverlay;
    prefs->save();
    emit prefs->enableTouchOverlayChanged();

    Session* session = Session::get();   // BL-1630: single fetch (TOCTOU vs pool-thread clear)
    if (session) {
        // BL-2007: icon-only buttons — the glyph surfaces regenerate inside
        // setOverlayState(), no label text involved.
        auto& overlayManager = session->getOverlayManager();
        overlayManager.setOverlayState(Overlay::OverlayTouchButtonMenu, prefs->enableTouchOverlay);
        overlayManager.setOverlayState(Overlay::OverlayTouchButtonKbd, prefs->enableTouchOverlay);
        overlayManager.setOverlayState(Overlay::OverlayTouchButtonTouchMode, prefs->enableTouchOverlay);
    }

    showToast(prefs->enableTouchOverlay ? QStringLiteral("Touch overlay: On")
                                        : QStringLiteral("Touch overlay: Off"));
}

void QuickMenuManager::showStreamInfo()
{
    auto prefs = StreamingPreferences::get();
    if (!prefs) {
        return;
    }

    const char* codec;
    switch (prefs->videoCodecConfig) {
    case StreamingPreferences::VCC_FORCE_H264: codec = "H.264"; break;
    case StreamingPreferences::VCC_FORCE_HEVC: codec = "HEVC";  break;
    case StreamingPreferences::VCC_FORCE_AV1:  codec = "AV1";   break;
    default:                                   codec = "Auto";  break;
    }

    QString info = QStringLiteral("%1x%2 @ %3 · %4 Mbps · %5")
                       .arg(prefs->width)
                       .arg(prefs->height)
                       .arg(prefs->fps)
                       .arg(prefs->bitrateKbps / 1000.0, 0, 'f', 1)
                       .arg(codec);
    showToast(info);
}

void QuickMenuManager::pasteClipboard()
{
    // Type the host clipboard's text into the remote session (mirrors the
    // Ctrl+Alt+Shift+V keyboard shortcut), so it works from a gamepad too.
    if (SDL_HasClipboardText()) {
        char* text = SDL_GetClipboardText();
        if (text != nullptr) {
            if (text[0] != '\0') {
                LiSendUtf8TextEvent(text, (unsigned int)strlen(text));
                showToast(QStringLiteral("Pasted clipboard text"));
            }
            SDL_free(text);
        }
    } else {
        showToast(QStringLiteral("Clipboard is empty"));
    }
}

void QuickMenuManager::sendSpecialKey(const QString &action)
{
    // Send a special key chord to the host (remote-desktop control). Windows VK codes.
    short vk = 0;
    char modifiers = 0;
    if (action == "key_ctrl_alt_del") {
        vk = 0x2E;                                 // VK_DELETE
        modifiers = MODIFIER_CTRL | MODIFIER_ALT;
    } else if (action == "key_super") {
        vk = 0x5B;                                 // VK_LWIN (Super)
    } else if (action == "key_alt_f4") {
        vk = 0x73;                                 // VK_F4
        modifiers = MODIFIER_ALT;
    } else if (action == "key_esc") {
        vk = 0x1B;                                 // VK_ESCAPE
    } else if (action == "key_shift_tab") {
        // BL-1788: MODIFIER_SHIFT must ride the same DOWN/UP pair as VK_TAB — hosts
        // apply modifiers per-event, so a separate shift press would race focus code.
        vk = 0x09;                                 // VK_TAB (reverse focus traversal)
        modifiers = MODIFIER_SHIFT;
    } else {
        return;
    }

    LiSendKeyboardEvent(vk, KEY_ACTION_DOWN, modifiers);
    LiSendKeyboardEvent(vk, KEY_ACTION_UP, modifiers);
    showToast(QStringLiteral("Sent key to host"));
}

void QuickMenuManager::showToast(const QString &message) {
    // Route the toast through the in-menu QML toast (visible while the menu is open).
    // The old standalone QQuickView toast window did not composite in Game Mode.
    if (m_isVisible && m_rootItem) {
        QMetaObject::invokeMethod(m_rootItem, "showToastMessage",
                                  Q_ARG(QVariant, message));
    }
    else {
        // BL-2002/BL-2007: the overlay KBD / TOUCH-MODE buttons act with the menu
        // CLOSED, where the QML toast never composites. Surface the message through
        // the transient centered text overlay instead — the same mechanism (and 2s
        // auto-hide) executeServerCommand() uses for its out-of-menu error.
        Session* session = Session::get();   // BL-1630: single fetch (TOCTOU)
        if (session) {
            auto& overlayManager = session->getOverlayManager();
            overlayManager.setOverlayState(Overlay::OverlayServerCommands, true);
            overlayManager.updateOverlayText(Overlay::OverlayServerCommands,
                                             message.toUtf8().constData());

            // test81 (review fix): don't capture the session-owned OverlayManager by
            // reference — the session can be torn down inside the 2s window (UAF).
            // Re-fetch the live session (if any) when the timer fires.
            QTimer::singleShot(2000, []() {
                Session* s = Session::get();   // BL-1630: single fetch (TOCTOU)
                if (s) {
                    s->getOverlayManager().setOverlayState(Overlay::OverlayServerCommands, false);
                }
            });
        }
    }
    qDebug() << "QuickMenuManager: showToast(" << message << ")";
}

void QuickMenuManager::disconnect()
{
    qDebug() << "QuickMenuManager: Disconnect requested";
    emit disconnectRequested();

    // BL-1630: hide NOW (stops the 33ms render timer + releases the overlay slot while the
    // session is intact) and queue the offscreen-renderer teardown for the next main-loop
    // tick — we are currently INSIDE a JS frame of the engine teardown would destroy.
    setVisible(false);
    QMetaObject::invokeMethod(this, &QuickMenuManager::teardownOverlayRenderer,
                              Qt::QueuedConnection);

    // Send SDL quit event to disconnect
    SDL_Event quitEvent;
    quitEvent.type = SDL_QUIT;
    quitEvent.quit.timestamp = SDL_GetTicks();
    SDL_PushEvent(&quitEvent);
}

void QuickMenuManager::quit()
{
    qDebug() << "QuickMenuManager: Quit requested";
    emit quitRequested();

    // BL-1630 (the quit-from-Quick-Menu crash): quitting tears the Qt event loop down while
    // the offscreen menu renderer is still live (visible menu, armed 33ms timer, live GL
    // context + second QQmlEngine), leaving it to be destroyed in a broken order inside the
    // outer QQmlApplicationEngine destructor. Hide synchronously and queue the teardown for
    // the next main-loop tick, BEFORE pushing SDL_QUIT (can't tear down inline — we're in a
    // JS frame of the engine being destroyed).
    setVisible(false);
    QMetaObject::invokeMethod(this, &QuickMenuManager::teardownOverlayRenderer,
                              Qt::QueuedConnection);

    // Vibemis BL-1686 (maintainer directive): "Quit" from the Quick Menu terminates the
    // running app on the HOST but keeps Vibemis open at the grid, so another session can
    // be started without relaunching. (The whole-app exit remains available via the
    // Ctrl+Alt+Shift+Q quitAndExit keyboard combo and plain window close.)
    Session* session = Session::get();
    if (session) {
        session->setShouldQuitAppAfter();
    }

    SDL_Event quitEvent;
    quitEvent.type = SDL_QUIT;
    quitEvent.quit.timestamp = SDL_GetTicks();
    SDL_PushEvent(&quitEvent);
}

void QuickMenuManager::executeServerCommand(const QString &command)
{
    qDebug() << "QuickMenuManager: Server command requested:" << command;
    emit serverCommandsRequested();

    // Map our simplified command names to the actual ServerCommandManager command IDs
    // test81 (review fix): ServerCommandManager::executeCommand matches against the
    // host-provided / builtin command list ("restart", "shutdown", "sleep", ...) — the
    // old "restart_server"/"shutdown_server"/"suspend_computer" ids matched nothing and
    // every server command failed with "Command not found".
    QString commandId;
    if (command == "restart") {
        commandId = "restart";
    } else if (command == "shutdown") {
        commandId = "shutdown";
    } else if (command == "suspend") {
        commandId = "sleep";
    } else {
        qDebug() << "QuickMenuManager: Unknown server command:" << command;
        return;
    }

    // Use QMetaObject::invokeMethod to safely execute the server command from any thread
    // This ensures thread safety when accessing ServerCommandManager from QML
    if (m_serverCommandManager) {
        // First check if the server command manager has permission (thread-safe property access)
        // test81 (review fix): direct call — invokeMethod-by-name on a non-invokable
        // accessor always failed and left hasPermission false (see hasServerCommands()).
        bool hasPermission = m_serverCommandManager->hasPermission();

        if (hasPermission) {
            qDebug() << "QuickMenuManager: Executing server command:" << commandId;
            // Execute the command using thread-safe invocation
            QMetaObject::invokeMethod(m_serverCommandManager, "executeCommand",
                                      Qt::QueuedConnection,
                                      Q_ARG(QString, commandId));
        } else {
            qDebug() << "QuickMenuManager: Server commands not available or no permission";

            // Show error message briefly
            Session* session = Session::get();   // BL-1630: single fetch (TOCTOU)
            if (session) {
                auto& overlayManager = session->getOverlayManager();
                overlayManager.setOverlayState(Overlay::OverlayServerCommands, true);
                overlayManager.updateOverlayText(Overlay::OverlayServerCommands, "Server commands not available");

                // test81 (review fix): don't capture the session-owned OverlayManager by
                // reference — the session can be torn down inside the 2s window (UAF).
                // Re-fetch the live session (if any) when the timer fires.
                QTimer::singleShot(2000, []() {
                    Session* s = Session::get();   // BL-1630: single fetch (TOCTOU)
                    if (s) {
                        s->getOverlayManager().setOverlayState(Overlay::OverlayServerCommands, false);
                    }
                });
            }
        }
    } else {
        qDebug() << "QuickMenuManager: No ServerCommandManager available";
    }
}

void QuickMenuManager::uploadClipboard()
{
    qDebug() << "QuickMenuManager: Clipboard upload requested";
    emit clipboardUploadRequested();

    if (m_clipboardManager) {
        m_clipboardManager->sendClipboard();
    }
}

void QuickMenuManager::fetchClipboard()
{
    qDebug() << "QuickMenuManager: Clipboard fetch requested";
    emit clipboardFetchRequested();

    if (m_clipboardManager) {
        m_clipboardManager->getClipboard();
    }
}

void QuickMenuManager::toggleStats()
{
    qDebug() << "QuickMenuManager: Stats toggle requested";
    emit statsToggleRequested();

    // Toggle debug overlay (performance stats)
    Session* session = Session::get();   // BL-1630: single fetch (TOCTOU vs pool-thread clear)
    if (session) {
        auto& overlayManager = session->getOverlayManager();
        bool currentState = overlayManager.isOverlayEnabled(Overlay::OverlayDebug);
        overlayManager.setOverlayState(Overlay::OverlayDebug, !currentState);

        m_isStatsVisible = !currentState;
        emit statsVisibilityChanged();
    }
}

void QuickMenuManager::toggleMouseCapture()
{
    qDebug() << "QuickMenuManager: Mouse capture toggle requested";
    emit mouseCaptureToggleRequested();

    // Send the mouse capture toggle key combo
    sendKeyCombo(KeyComboToggleMouseMode);
}

void QuickMenuManager::toggleKeyboardCapture()
{
    qDebug() << "QuickMenuManager: Keyboard capture toggle requested";
    emit keyboardCaptureToggleRequested();

    // test87: toggle input capture (grab/ungrab) on the SDL thread. Mirrors the
    // Ctrl+Alt+Shift+Z keyboard combo (KeyComboUngrabInput).
    sendKeyCombo(KeyComboUngrabInput);
    m_isKeyboardCaptured = !m_isKeyboardCaptured;
    emit keyboardCaptureChanged();
}

void QuickMenuManager::toggleFullscreen()
{
    qDebug() << "QuickMenuManager: Fullscreen toggle requested";
    emit fullscreenToggleRequested();

    // Send the fullscreen toggle key combo
    sendKeyCombo(KeyComboToggleFullScreen);
}

void QuickMenuManager::setServerCommandManager(ServerCommandManager *manager)
{
    if (m_serverCommandManager) {
        QObject::disconnect(m_serverCommandManager, nullptr, this, nullptr);
    }

    m_serverCommandManager = manager;

    if (m_serverCommandManager) {
        connect(m_serverCommandManager, &ServerCommandManager::permissionChanged,
                this, &QuickMenuManager::onServerCommandsChanged);
    }

    emit serverCommandsChanged();
}

void QuickMenuManager::setClipboardManager(ClipboardManager *manager)
{
    m_clipboardManager = manager;
}

void QuickMenuManager::setWindow(QWindow *window)
{
    // The overlay no longer uses a separate OS window; this hook is retained for the
    // Session call site but is intentionally a no-op.
    Q_UNUSED(window);
}

void QuickMenuManager::setWindowGeometry(int x, int y, int width, int height)
{
    // Positioning is handled by the renderer (centered); x/y are unused. But the SIZE matters:
    // the menu renders into an offscreen FBO the renderers blit 1:1, so a fixed FBO on a large
    // stream surface reads tiny (test-agent device data: a 720x600 FBO covered only ~29% of the
    // 1536x960 overlay area on a 1920x1200 stream — BL-1622). Size the FBO to 80% of the stream
    // window (10% margins), clamped to a sane floor, so the menu scales with the display and the
    // QML lays out in the same coord space the user sees.
    Q_UNUSED(x); Q_UNUSED(y);
    if (width <= 0 || height <= 0) {
        return;
    }
    QSize newSize(qMax(640, (width * 8) / 10), qMax(480, (height * 8) / 10));
    if (newSize == m_overlaySize) {
        return;
    }
    m_overlaySize = newSize;
    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "QuickMenuManager: overlay size set to %dx%d (from window %dx%d)",
                newSize.width(), newSize.height(), width, height);
    if (m_overlayReady) {
        // Rebuild at the new size on next show (setWindowGeometry arrives at stream start,
        // before the first toggle, so this path is rare).
        teardownOverlayRenderer();
    }
}

void QuickMenuManager::onServerCommandsChanged()
{
    emit serverCommandsChanged();
}

void QuickMenuManager::onFullscreenChanged()
{
    emit fullscreenChanged();
}

void QuickMenuManager::onMouseCaptureChanged()
{
    emit mouseCaptureChanged();
}

void QuickMenuManager::onKeyboardCaptureChanged()
{
    emit keyboardCaptureChanged();
}

void QuickMenuManager::onStatsVisibilityChanged()
{
    emit statsVisibilityChanged();
}

void QuickMenuManager::sendKeyCombo(int keyCombo)
{
    // test87: push a registered SDL user event so the combo runs on the SDL thread (the
    // only thread that may touch the window / mouse-capture state). SDL_PushEvent is
    // thread-safe. The KeyCombo enum values here mirror SdlInputHandler::KeyCombo.
    qDebug() << "QuickMenuManager: Requesting key combo on SDL thread:" << keyCombo;
    SDL_Event ev;
    SDL_memset(&ev, 0, sizeof(ev));
    ev.type = SdlInputHandler::quickMenuComboEventType();
    ev.user.code = keyCombo;
    SDL_PushEvent(&ev);
}
