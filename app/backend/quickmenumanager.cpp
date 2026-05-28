#include "quickmenumanager.h"
#include "servercommandmanager.h"
#include "clipboardmanager.h"
#include "../streaming/session.h"

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
#include <QGuiApplication>
#include <QQuickView>
#include <QQuickItem>
#include <QWindow>
#include <QUrl>
#include <QDebug>
#include <QTimer>

QuickMenuManager::QuickMenuManager(QObject *parent)
    : QObject(parent)
    , m_isVisible(false)
    , m_window(nullptr)
    , m_quickView(nullptr)
    , m_quickMenuItem(nullptr)
    , m_serverCommandManager(nullptr)
    , m_clipboardManager(nullptr)
    , m_isFullscreen(false)
    , m_isMouseCaptured(false)
    , m_isKeyboardCaptured(false)
    , m_isStatsVisible(false)
    , m_windowX(0)
    , m_windowY(0)
    , m_windowWidth(800)
    , m_windowHeight(600)
    , m_hasWindowGeometry(false)
    , m_ToastWindow(nullptr)
{
}

QuickMenuManager::~QuickMenuManager()
{
    if (m_quickView) {
        delete m_quickView;
    }
    if (m_ToastWindow) {
        delete m_ToastWindow;
    }
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
        createQuickView();
    } else {
        if (m_quickView) {
            m_quickView->hide();
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
    }
}

void QuickMenuManager::showToast(const QString &message) {
    // Updated implementation, now displays outside QuickMenu
    if (!m_ToastWindow) {
        m_ToastWindow = new QQuickView();
        m_ToastWindow->setSource(QUrl("qrc:/gui/Toast.qml"));
        m_ToastWindow->setColor(QColor(Qt::transparent));
        m_ToastWindow->setFlags(Qt::ToolTip | Qt::FramelessWindowHint);
        m_ToastWindow->setResizeMode(QQuickView::SizeRootObjectToView);
    }

    QVariant retVal;
    QMetaObject::invokeMethod(m_ToastWindow->rootObject(), "showToast",
                              Q_RETURN_ARG(QVariant, retVal),
                              Q_ARG(QVariant, message));
    m_ToastWindow->show();
    QTimer::singleShot(3000, m_ToastWindow, &QQuickView::hide);

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
    m_window = window;
}

void QuickMenuManager::setWindowGeometry(int x, int y, int width, int height)
{
    qDebug() << "QuickMenuManager::setWindowGeometry:" << x << y << width << height;
    m_windowX = x;
    m_windowY = y;
    m_windowWidth = width;
    m_windowHeight = height;
    m_hasWindowGeometry = true;
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

void QuickMenuManager::createQuickView()
{
    qDebug() << "QuickMenuManager::createQuickView() called";
    
    if (!m_quickView) {
        qDebug() << "Creating new QQuickView";
        m_quickView = new QQuickView();
        m_quickView->setResizeMode(QQuickView::SizeViewToRootObject);
        
        // Set up the QML context
        QQmlContext *context = m_quickView->rootContext();
        context->setContextProperty("quickMenuManager", this);
        
        // Load the QML file
        qDebug() << "Loading QML from: qrc:/gui/QuickMenu.qml";
        m_quickView->setSource(QUrl("qrc:/gui/QuickMenu.qml"));
        
        qDebug() << "QML loading status:" << m_quickView->status();
        if (m_quickView->status() == QQuickView::Error) {
            qDebug() << "QuickMenuManager: Error loading QML:" << m_quickView->errors();
            return;
        } else if (m_quickView->status() == QQuickView::Ready) {
            qDebug() << "QML loaded successfully";
        } else {
            qDebug() << "QML loading in progress, status:" << m_quickView->status();
        }
        
        m_quickMenuItem = m_quickView->rootObject();
        qDebug() << "Root object:" << m_quickMenuItem;
        
        if (m_quickMenuItem) {
            qDebug() << "Root object created successfully";
            // Make sure the root object is visible
            m_quickMenuItem->setProperty("visible", true);
            qDebug() << "Root object set to visible";
        } else {
            qDebug() << "Failed to create root object";
        }
        
        // Make it a popup overlay
        m_quickView->setFlags(Qt::WindowStaysOnTopHint | Qt::FramelessWindowHint | Qt::Tool);
        
        // Set transparent background
        m_quickView->setColor(QColor(Qt::transparent));
        
        // Position the view to center the menu on screen
        int centerX, centerY;
        if (m_hasWindowGeometry) {
            centerX = m_windowX + (m_windowWidth - 500) / 2;
            centerY = m_windowY + (m_windowHeight - 400) / 2;
            qDebug() << "Centering menu at:" << centerX << centerY;
            m_quickView->setGeometry(centerX, centerY, 500, 400);
        } else {
            qDebug() << "Using default centered position";
            m_quickView->setGeometry(400, 300, 500, 400);
        }
    }
    
    if (m_quickView) {
        // Don't call updateQuickView() - it overrides our centered positioning
        qDebug() << "Showing QuickView with geometry:" << m_quickView->geometry();
        m_quickView->show();
        m_quickView->raise();
        m_quickView->requestActivate();
    }
}

void QuickMenuManager::updateQuickView()
{
    // Don't update geometry - we want to keep the centered position
    // This function used to override our centered positioning
    qDebug() << "updateQuickView() called but not changing geometry to preserve centering";
}

void QuickMenuManager::sendKeyCombo(int keyCombo)
{
    // This function would need to integrate with the input system
    // to send the appropriate key combinations
    // For now, we'll just emit the signals and let the Session handle it
    
    // This is a placeholder - in a real implementation, you'd need to 
    // trigger the key combo through the input system
    qDebug() << "QuickMenuManager: Sending key combo:" << keyCombo;
}
