#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QSize>

#include <atomic>

class NvComputer;
class NvHTTP;
#include "backend/servercommandmanager.h"
class ClipboardManager;

// Forward declarations for the offscreen QML → surface render pipeline.
QT_BEGIN_NAMESPACE
class QWindow;
class QQuickItem;
class QQuickWindow;
class QQuickRenderControl;
class QQmlComponent;
class QOpenGLContext;
class QOffscreenSurface;
class QOpenGLFramebufferObject;
class QTimer;
QT_END_NAMESPACE

/**
 * @brief Manages the Quick Menu overlay system
 *
 * The Quick Menu is rendered from QML offscreen (via QQuickRenderControl into an
 * OpenGL framebuffer), read back to an RGBA SDL_Surface, and published to the
 * OverlayManager as the OverlayQuickMenu overlay type. Every video renderer
 * (EGL, SDL, VAAPI) already composites OverlayManager surfaces into the stream,
 * so the menu appears correctly in SteamOS Game Mode (Gamescope) — unlike the
 * previous QQuickView approach, which relied on a separate OS window that
 * Gamescope does not composite.
 *
 * Input (gamepad/keyboard navigation) is injected as synthetic Qt key events into
 * the offscreen QQuickWindow via injectKey(), since the window is never shown and
 * therefore never holds OS keyboard focus.
 */
class QuickMenuManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isVisible READ isVisible WRITE setVisible NOTIFY visibilityChanged)
    Q_PROPERTY(bool hasServerCommands READ hasServerCommands NOTIFY serverCommandsChanged)
    Q_PROPERTY(bool isFullscreen READ isFullscreen NOTIFY fullscreenChanged)
    Q_PROPERTY(bool isMouseCaptured READ isMouseCaptured NOTIFY mouseCaptureChanged)
    Q_PROPERTY(bool isKeyboardCaptured READ isKeyboardCaptured NOTIFY keyboardCaptureChanged)
    Q_PROPERTY(bool isStatsVisible READ isStatsVisible NOTIFY statsVisibilityChanged)
    Q_PROPERTY(ServerCommandManager* serverCommandManager READ serverCommandManager CONSTANT)
    QML_ELEMENT

public:
    explicit QuickMenuManager(QObject *parent = nullptr);
    ~QuickMenuManager();

    // Property getters
    bool isVisible() const { return m_isVisible; }
    bool hasServerCommands() const;
    bool isFullscreen() const;
    bool isMouseCaptured() const;
    bool isKeyboardCaptured() const;
    bool isStatsVisible() const;

    // Menu management
    Q_INVOKABLE void setVisible(bool visible);
    Q_INVOKABLE void toggle();
    Q_INVOKABLE void show();
    Q_INVOKABLE void hide();

    // Inject a navigation key (a Qt::Key value) into the offscreen menu. Called from
    // the SDL input thread via QueuedConnection; safe to call when the menu is hidden
    // (it is simply ignored).
    Q_INVOKABLE void injectKey(int qtKey);

    // Action handlers
    Q_INVOKABLE void executeAction(const QString &action);
    Q_INVOKABLE void disconnect();
    Q_INVOKABLE void quit();
    Q_INVOKABLE void executeServerCommand(const QString &command);
    Q_INVOKABLE void showToast(const QString &message);
    Q_INVOKABLE void uploadClipboard();
    Q_INVOKABLE void fetchClipboard();
    Q_INVOKABLE void toggleStats();
    Q_INVOKABLE void toggleMouseCapture();
    Q_INVOKABLE void toggleKeyboardCapture();
    Q_INVOKABLE void toggleFullscreen();
<<<<<<< HEAD
    Q_INVOKABLE void sendSpecialKey(const QString &action);
=======
    Q_INVOKABLE void pasteClipboard();
>>>>>>> origin/vibemis-main

    // Integration with other managers
    void setServerCommandManager(ServerCommandManager *manager);
    void setClipboardManager(ClipboardManager *manager);

    // Window management (legacy hooks kept for the Session call sites; geometry is no
    // longer used for positioning since the menu is centered by the renderer).
    void setWindow(QWindow *window);
    void setWindowGeometry(int x, int y, int width, int height);

    ServerCommandManager* serverCommandManager() const { return m_serverCommandManager; }

signals:
    void visibilityChanged();
    void serverCommandsChanged();
    void fullscreenChanged();
    void mouseCaptureChanged();
    void keyboardCaptureChanged();
    void statsVisibilityChanged();

    // Action signals
    void disconnectRequested();
    void quitRequested();
    void serverCommandsRequested();
    void clipboardUploadRequested();
    void clipboardFetchRequested();
    void statsToggleRequested();
    void mouseCaptureToggleRequested();
    void keyboardCaptureToggleRequested();
    void fullscreenToggleRequested();

private slots:
    void onServerCommandsChanged();
    void onFullscreenChanged();
    void onMouseCaptureChanged();
    void onKeyboardCaptureChanged();
    void onStatsVisibilityChanged();
    void renderToSurface();

private:
    bool initOverlayRenderer();
    void teardownOverlayRenderer();
    void sendKeyCombo(int keyCombo);

    // test81 (review fix): read from the SDL input thread (gamepad/keyboard intercepts)
    // while written on the Qt main thread — must be atomic.
    std::atomic<bool> m_isVisible;

    ServerCommandManager *m_serverCommandManager;
    ClipboardManager *m_clipboardManager;

    // State tracking
    bool m_isFullscreen;
    bool m_isMouseCaptured;
    bool m_isKeyboardCaptured;
    bool m_isStatsVisible;

    // Offscreen QML → surface render pipeline (all used on the Qt main thread).
    QOpenGLContext *m_glContext;
    QOffscreenSurface *m_offscreenSurface;
    QQuickRenderControl *m_renderControl;
    QQuickWindow *m_quickWindow;
    QQmlEngine *m_qmlEngine;
    QQmlComponent *m_qmlComponent;
    QQuickItem *m_rootItem;
    QOpenGLFramebufferObject *m_fbo;
    QTimer *m_renderTimer;
    QSize m_overlaySize;
    bool m_overlayReady;
};
