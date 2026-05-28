#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QAbstractListModel>
#include <QJsonObject>
#include <QTimer>
#include "nvcomputer.h"

class NvHTTP;

// Declare opaque pointers for Qt's meta-object system
// (Only declare if not already declared by clipboardmanager.h)
#ifndef NVCOMPUTER_OPAQUE_DECLARED
#define NVCOMPUTER_OPAQUE_DECLARED
Q_DECLARE_OPAQUE_POINTER(NvComputer*)
#endif

#ifndef NVHTTP_OPAQUE_DECLARED  
#define NVHTTP_OPAQUE_DECLARED
Q_DECLARE_OPAQUE_POINTER(NvHTTP*)
#endif

/**
 * @brief Manages server commands functionality with Apollo servers
 * 
 * This class implements server commands as used in Vibemis Android.
 * It requires the server_cmd permission from Apollo servers.
 * Based on GameMenu.java implementation.
 */
class ServerCommandManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool hasPermission READ hasPermission NOTIFY permissionChanged)
    Q_PROPERTY(bool isExecuting READ isExecuting NOTIFY executionStateChanged)
    QML_ELEMENT

public:
    // Server command structure (matches Android ServerCommand)
    struct ServerCommand {
        QString id;
        QString name;
        QString description;
        QJsonObject parameters;
    };

    explicit ServerCommandManager(QObject *parent = nullptr);
    ~ServerCommandManager();

    // Property getters
    bool hasPermission() const { return m_hasPermission; }
    bool isExecuting() const { return m_isExecuting; }

    // Connection management
    Q_INVOKABLE void setConnection(NvComputer *computer, NvHTTP *http);
    Q_INVOKABLE void disconnect();

    // Command operations (matches Android API)
    Q_INVOKABLE bool hasServerCommandPermission() const;
    Q_INVOKABLE void refreshCommands();
    Q_INVOKABLE void executeCommand(const QString &commandId);
    Q_INVOKABLE void executeCustomCommand(const QString &command);

    // Command list access
    Q_INVOKABLE QStringList getAvailableCommands() const;
    Q_INVOKABLE QString getCommandName(const QString &commandId) const;
    Q_INVOKABLE QString getCommandDescription(const QString &commandId) const;

    // Apollo server detection (matches Android logic)
    Q_INVOKABLE bool isApolloServer() const;

signals:
    void permissionChanged();
    void commandsRefreshed();
    void commandExecuted(const QString& commandId, bool success, const QString& result);
    void commandFailed(const QString& commandId, const QString& error);
    void executionStateChanged();

public slots:
    void onComputerPairingCompleted();
    void onComputerStateChanged();
    void noCommandsAvailable(); // Matches Android dialog

private slots:
    void onCommandsReceived();
    void onCommandExecutionFinished();

private:
    // Permission checking (matches Android ComputerDetails.Operations)
    bool checkServerCommandPermission();
    
    // HTTP operations (placeholder for actual implementation)
    void fetchAvailableCommands();
    void sendCommandExecution(const QString &commandId);
    
    // XML parsing
    bool parseServerCommandsXml(const QByteArray &xmlData);
    
    // Streaming session state checking
    bool isStreamingSessionActive() const;
    
    // HTTP-based server command execution (Apollo server approach)
    bool sendHttpServerCommand(const QString &commandId);

private:
    // Builtin commands (matches Android implementation)
    static const QList<ServerCommand> BUILTIN_COMMANDS;
    
    NvComputer *m_computer;
    NvHTTP *m_http;
    
    bool m_hasPermission;
    bool m_isExecuting;
    QStringList m_availableCommands;
    QHash<QString, QString> m_commandNames;
    QHash<QString, QString> m_commandDescriptions;
    
    bool m_refreshInProgress;
    QString m_currentExecutingCommand;
};