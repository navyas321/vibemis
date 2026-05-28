#pragma once

#include <QObject>
#include <QClipboard>
#include <QTimer>
#include <QQmlEngine>
#include <QCryptographicHash>

class NvComputer;
class NvHTTP;

// Declare opaque pointers for Qt's meta-object system
#ifndef NVCOMPUTER_OPAQUE_DECLARED
#define NVCOMPUTER_OPAQUE_DECLARED
Q_DECLARE_OPAQUE_POINTER(NvComputer*)
#endif

#ifndef NVHTTP_OPAQUE_DECLARED
#define NVHTTP_OPAQUE_DECLARED
Q_DECLARE_OPAQUE_POINTER(NvHTTP*)
#endif

/**
 * @brief Manages clipboard synchronization between client and server
 * 
 * This class handles bidirectional clipboard sync with Apollo/Sunshine servers
 * using the /actions/clipboard HTTP endpoint. Based on Vibemis Android implementation.
 */
class ClipboardManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isEnabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool isConnected READ isConnected NOTIFY connectionChanged)
    Q_PROPERTY(bool textOnlyMode READ textOnlyMode WRITE setTextOnlyMode NOTIFY textOnlyModeChanged)
    Q_PROPERTY(int maxContentSizeMB READ maxContentSizeMB WRITE setMaxContentSizeMB NOTIFY maxContentSizeMBChanged)
    Q_PROPERTY(bool showNotifications READ showNotifications WRITE setShowNotifications NOTIFY showNotificationsChanged)
    Q_PROPERTY(bool bidirectionalSync READ isBidirectionalSyncEnabled WRITE setBidirectionalSync NOTIFY bidirectionalSyncChanged)
    QML_ELEMENT

public:
    explicit ClipboardManager(QObject *parent = nullptr);
    ~ClipboardManager();
    
    // Singleton access for consistent instance across UI and Session
    static ClipboardManager* instance();
    static ClipboardManager* create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);

    // Property getters
    bool isEnabled() const { return m_enabled; }
    bool isConnected() const { return m_connected; }
    bool textOnlyMode() const { return m_textOnlyMode; }
    int maxContentSizeMB() const { return m_maxContentSizeMB; }
    bool showNotifications() const { return m_showNotifications; }

    // Property setters
    void setEnabled(bool enabled);
    void setTextOnlyMode(bool textOnly);
    void setMaxContentSizeMB(int sizeMB);
    void setShowNotifications(bool show);

    // Connection management
    Q_INVOKABLE void setConnection(NvComputer *computer, NvHTTP *http);
    Q_INVOKABLE void disconnect();

    // Manual sync operations (matches Android API)
    Q_INVOKABLE bool sendClipboard(bool force = false);
    Q_INVOKABLE bool getClipboard();

    // Smart sync control (matches Android settings)
    Q_INVOKABLE void enableSmartSync(bool enabled);
    Q_INVOKABLE bool isSmartSyncEnabled() const;

    // Apollo server detection (clipboard sync only works with Apollo servers)
    Q_INVOKABLE bool isClipboardSyncSupported() const;

    // Auto-sync triggers (matches Android behavior)
    Q_INVOKABLE void onStreamStarted();
    Q_INVOKABLE void onStreamResumed();
    Q_INVOKABLE void onFocusLost();

    // Settings (matches Android preferences)
    Q_INVOKABLE void setMaxClipboardSize(int maxSize);
    Q_INVOKABLE int getMaxClipboardSize() const;

    Q_INVOKABLE void setBidirectionalSync(bool enabled);
    Q_INVOKABLE bool isBidirectionalSyncEnabled() const;

    Q_INVOKABLE void setShowToast(bool enabled);
    Q_INVOKABLE bool shouldShowToast() const;

    Q_INVOKABLE void setHideContent(bool enabled);
    Q_INVOKABLE bool shouldHideContent() const;

signals:
    void clipboardSyncStarted();
    void clipboardSyncCompleted();
    void clipboardSyncFailed(const QString &error);
    void clipboardContentChanged();
    void showToast(const QString &message);
    void apolloSupportChanged(bool supported);
    
    // Property change signals
    void enabledChanged();
    void connectionChanged();
    void textOnlyModeChanged();
    void maxContentSizeMBChanged();
    void showNotificationsChanged();
    void bidirectionalSyncChanged();

private slots:
    void onClipboardChanged();

private:
    // Settings management
    void loadSettings();
    
    // Core clipboard operations (matches Android implementation)
    QString getClipboardContent(bool force = false);
    void setClipboardContent(const QString &content);
    
    // Loop prevention (matches Android CLIPBOARD_IDENTIFIER logic)
    bool isOwnClipboardChange(const QString &content);
    void markAsOwnContent(const QString &content);
    QString generateContentHash(const QString &content);
    
    // HTTP operations (matches Android NvHTTP methods)
    bool sendClipboardToServer(const QString &content);
    QString getClipboardFromServer();

private:
    static constexpr int DEFAULT_MAX_SIZE = 1048576; // 1MB (matches Android)
    static const QString CLIPBOARD_IDENTIFIER; // Matches Android constant

    QClipboard *m_clipboard;
    
    NvComputer *m_computer;
    NvHTTP *m_http;
    
    // Settings (matches Android preferences)
    bool m_smartSyncEnabled;
    bool m_bidirectionalSync;
    bool m_showToast;
    bool m_hideContent;
    int m_maxClipboardSize;
    
    // New property backing variables
    bool m_enabled;
    bool m_connected;
    bool m_textOnlyMode;
    int m_maxContentSizeMB;
    bool m_showNotifications;
    
    // State tracking (matches Android implementation)
    QString m_lastSentContent;
    QString m_lastReceivedContent;
    QStringList m_ownContentHashes;
    bool m_syncInProgress;
    
    // Static instance for singleton pattern
    static ClipboardManager* s_instance;
};