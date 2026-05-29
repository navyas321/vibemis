#include "quickmenumanager.h"
#include "servercommandmanager.h"
#include "clipboardmanager.h"
#include "../streaming/session.h"

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
#include <QDebug>

#include <SDL.h>

// How often the offscreen menu is re-rendered while visible. The menu is small
// (500x400) and this only runs while the menu is open, so a 30 Hz refresh keeps
// animations/selection highlights smooth at negligible cost.
static const int kRenderIntervalMs = 33;

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
    , m_overlaySize(500, 400)
    , m_overlayReady(false)
{
    m_renderTimer = new QTimer(this);
    m_renderTimer->setInterval(kRenderIntervalMs);
    connect(m_renderTimer, &QTimer::timeout, this, &QuickMenuManager::renderToSurface);
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

    // Use thread-safe property access when called from QML
    bool hasPermission = false;
    QMetaObject::invokeMethod(m_serverCommandManager, "hasPermission",
                              Qt::DirectConnection,  // Use DirectConnection if we're on the same thread
                              Q_RETURN_ARG(bool, hasPermission));
    return hasPermission;
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
        if (Session::get()) {
            Session::get()->getOverlayManager().setOverlayState(Overlay::OverlayQuickMenu, true);
        }
        renderToSurface();
        m_renderTimer->start();
    } else {
        m_renderTimer->stop();
        if (Session::get()) {
            Session::get()->getOverlayManager().setOverlayState(Overlay::OverlayQuickMenu, false);
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

    if (Session::get()) {
        Session::get()->getOverlayManager().updateOverlaySurface(Overlay::OverlayQuickMenu, surface);
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

    if (m_rootItem) {
        m_rootItem->deleteLater();
        m_rootItem = nullptr;
    }
    delete m_qmlComponent;
    m_qmlComponent = nullptr;
    delete m_qmlEngine;
    m_qmlEngine = nullptr;
    delete m_fbo;
    m_fbo = nullptr;
    delete m_renderControl;
    m_renderControl = nullptr;
    delete m_quickWindow;
    m_quickWindow = nullptr;

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
    } else if (action == "paste_clipboard") {
        pasteClipboard();
    }
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

void QuickMenuManager::showToast(const QString &message) {
    // Route the toast through the in-menu QML toast (visible while the menu is open).
    // The old standalone QQuickView toast window did not composite in Game Mode.
    if (m_rootItem) {
        QMetaObject::invokeMethod(m_rootItem, "showToastMessage",
                                  Q_ARG(QVariant, message));
    }
    qDebug() << "QuickMenuManager: showToast(" << message << ")";
}

void QuickMenuManager::disconnect()
{
    qDebug() << "QuickMenuManager: Disconnect requested";
    emit disconnectRequested();

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

    // Set flag to exit after quit and send quit event
    if (Session::get()) {
        Session::get()->setShouldExitAfterQuit();
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
    QString commandId;
    if (command == "restart") {
        commandId = "restart_server";
    } else if (command == "shutdown") {
        commandId = "shutdown_server";
    } else if (command == "suspend") {
        commandId = "suspend_computer";
    } else {
        qDebug() << "QuickMenuManager: Unknown server command:" << command;
        return;
    }

    // Use QMetaObject::invokeMethod to safely execute the server command from any thread
    // This ensures thread safety when accessing ServerCommandManager from QML
    if (m_serverCommandManager) {
        // First check if the server command manager has permission (thread-safe property access)
        bool hasPermission = false;
        // DirectConnection: QuickMenuManager and ServerCommandManager both live on
        // the main thread (Qt singletons), so BlockingQueuedConnection would deadlock.
        QMetaObject::invokeMethod(m_serverCommandManager, "hasPermission",
                                  Qt::DirectConnection,
                                  Q_RETURN_ARG(bool, hasPermission));

        if (hasPermission) {
            qDebug() << "QuickMenuManager: Executing server command:" << commandId;
            // Execute the command using thread-safe invocation
            QMetaObject::invokeMethod(m_serverCommandManager, "executeCommand",
                                      Qt::QueuedConnection,
                                      Q_ARG(QString, commandId));
        } else {
            qDebug() << "QuickMenuManager: Server commands not available or no permission";

            // Show error message briefly
            if (Session::get()) {
                auto& overlayManager = Session::get()->getOverlayManager();
                overlayManager.setOverlayState(Overlay::OverlayServerCommands, true);
                overlayManager.updateOverlayText(Overlay::OverlayServerCommands, "Server commands not available");

                QTimer::singleShot(2000, [&overlayManager]() {
                    overlayManager.setOverlayState(Overlay::OverlayServerCommands, false);
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
    if (Session::get()) {
        auto& overlayManager = Session::get()->getOverlayManager();
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

    // For keyboard capture, we'll simulate the capture toggle
    // This would need to be implemented in the input handler
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
    // Positioning is handled by the renderer (centered). Retained as a no-op so the
    // Session call site does not need conditional compilation.
    Q_UNUSED(x); Q_UNUSED(y); Q_UNUSED(width); Q_UNUSED(height);
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
    // Placeholder — integration with the input system happens via the Session/overlay
    // toggles invoked from the action handlers above.
    qDebug() << "QuickMenuManager: Sending key combo:" << keyCombo;
}
