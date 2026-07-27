#include "servercommandmanager.h"
#include "nvcomputer.h"
#include "nvhttp.h"
#include "streaming/session.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QNetworkRequest>
#include <QUrl>
#include <QXmlStreamReader>
#include <QEventLoop>
#include <QDebug>
#include <QTimer>
#include <Limelight.h>

// Define static member
const QList<ServerCommandManager::ServerCommand> ServerCommandManager::BUILTIN_COMMANDS = {
    {"restart", "Restart Computer", "Restart the host computer", {}},
    {"shutdown", "Shutdown Computer", "Shutdown the host computer", {}},
    {"sleep", "Sleep Computer", "Put the host computer to sleep", {}},
    {"hibernate", "Hibernate Computer", "Hibernate the host computer", {}},
    {"lock", "Lock Computer", "Lock the host computer", {}}
};

ServerCommandManager::ServerCommandManager(QObject *parent)
    : QObject(parent)
    , m_computer(nullptr)
    , m_http(nullptr)
    , m_hasPermission(false)
    , m_isExecuting(false)
    , m_refreshInProgress(false)
{
    qDebug() << "ServerCommandManager: Initialized";
}

ServerCommandManager::~ServerCommandManager()
{
    qDebug() << "ServerCommandManager: Destroyed";
}

void ServerCommandManager::setConnection(NvComputer *computer, NvHTTP *http)
{
    m_computer = computer;
    // Take ownership of the NvHTTP handed to us — the previous one
    // (and its QNetworkAccessManager) leaked on every new streaming session.
    if (m_http && m_http != http && m_http->parent() == this) {
        delete m_http;
    }
    m_http = http;
    if (m_http && !m_http->parent()) {
        m_http->setParent(this);
    }
    
    bool oldPermission = m_hasPermission;
    
    // Check if this is an Apollo server and refresh commands
    if (computer && http) {
        refreshCommands();
    } else {
        m_hasPermission = false;
        m_availableCommands.clear();
        m_commandNames.clear();
        m_commandDescriptions.clear();
        emit commandsRefreshed();
    }
    
    if (oldPermission != m_hasPermission) {
        emit permissionChanged();
    }
}

void ServerCommandManager::disconnect()
{
    m_computer = nullptr;
    m_http = nullptr;
    m_hasPermission = false;
    m_availableCommands.clear();
    m_commandNames.clear();
    m_commandDescriptions.clear();
    emit commandsRefreshed();
}

bool ServerCommandManager::hasServerCommandPermission() const
{
    return m_hasPermission;
}

void ServerCommandManager::refreshCommands()
{
    if (m_refreshInProgress || !m_computer || !m_http) {
        qDebug() << "ServerCommandManager::refreshCommands: Cannot refresh - inProgress:" << m_refreshInProgress
                 << ", computer:" << (m_computer != nullptr)
                 << ", http:" << (m_http != nullptr);
        return;
    }
    
    m_refreshInProgress = true;
    bool oldPermission = m_hasPermission;
    
    qDebug() << "ServerCommandManager::refreshCommands: Starting refresh";
    qDebug() << "ServerCommandManager::refreshCommands: Server commands from computer:" << m_computer->serverCommands;
    
    // Check if server commands are available from serverinfo XML (Android approach)
    if (!m_computer->serverCommands.isEmpty()) {
        qDebug() << "ServerCommandManager::refreshCommands: Found server commands in serverinfo XML";
        m_hasPermission = true;
        m_availableCommands.clear();
        m_commandNames.clear();
        m_commandDescriptions.clear();
        
        // Use the commands from the serverinfo XML
        for (const QString &cmd : m_computer->serverCommands) {
            m_availableCommands.append(cmd);
            m_commandNames[cmd] = cmd; // Use command ID as display name for now
            m_commandDescriptions[cmd] = "Server command: " + cmd;
        }
        
        qDebug() << "ServerCommandManager::refreshCommands: Loaded commands from serverinfo:" << m_availableCommands;
    } else {
        qDebug() << "ServerCommandManager::refreshCommands: No server commands in serverinfo XML, using builtins";

        // The old fetchAvailableCommands() here fired up to 6
        // SEQUENTIAL BLOCKING HTTP probes (5s timeout each = up to 30s) against speculative
        // endpoints ("servercommands", "commands", ...) that Apollo does NOT expose — commands
        // arrive via the serverinfo XML (m_computer->serverCommands, handled above). The probes
        // always failed and then we fell back to builtins anyway, so they only added latency to
        // stream start (refreshCommands runs inside Session::initialize via BlockingQueuedConnection).
        // Removed — go straight to the builtin fallback.
        if (isApolloServer()) {
            m_hasPermission = true;
            m_availableCommands.clear();
            m_commandNames.clear();
            m_commandDescriptions.clear();
            
            for (const auto &cmd : BUILTIN_COMMANDS) {
                m_availableCommands.append(cmd.id);
                m_commandNames[cmd.id] = cmd.name;
                m_commandDescriptions[cmd.id] = cmd.description;
            }
            
            qDebug() << "ServerCommandManager::refreshCommands: Apollo server detected, using builtin commands:" << m_availableCommands;
        } else {
            m_hasPermission = false;
            m_availableCommands.clear();
            m_commandNames.clear();
            m_commandDescriptions.clear();
            
            qDebug() << "ServerCommandManager::refreshCommands: Non-Apollo server, no commands available";
        }
    }
    
    m_refreshInProgress = false;
    emit commandsRefreshed();
    
    if (oldPermission != m_hasPermission) {
        emit permissionChanged();
    }
}

void ServerCommandManager::executeCommand(const QString &commandId)
{
    if (!m_computer || !m_http || !m_hasPermission) {
        emit commandFailed(commandId, "Server commands not available");
        return;
    }
    
    if (!m_availableCommands.contains(commandId)) {
        emit commandFailed(commandId, "Command not found");
        return;
    }

    if (m_isExecuting) {
        emit commandFailed(commandId, "Another command is already executing");
        return;
    }
    
    m_isExecuting = true;
    m_currentExecutingCommand = commandId;
    emit executionStateChanged();
    
    qDebug() << "ServerCommandManager: Executing command:" << commandId;
    
    // Execute the actual command via HTTP
    sendCommandExecution(commandId);
}

void ServerCommandManager::executeCustomCommand(const QString &command)
{
    if (command.isEmpty()) {
        emit commandFailed("custom", "Empty command");
        return;
    }

    if (!m_computer || !m_http || !m_hasPermission) {
        emit commandFailed("custom", "Server commands not available");
        return;
    }

    if (m_isExecuting) {
        emit commandFailed("custom", "Another command is already executing");
        return;
    }
    
    m_isExecuting = true;
    m_currentExecutingCommand = "custom";
    emit executionStateChanged();

    qDebug() << "ServerCommandManager: Executing custom command:" << command;

    // BL-2539: this used to be a stub -- a 1.5 s QTimer that emitted
    // commandExecuted(..., true, ...) without sending ANYTHING to the host,
    // so every custom command showed a success toast over a silent no-op
    // (found on-device when a test agent tried to trigger the host's
    // "Bubbles" command and nothing happened).
    //
    // Real execution, two routes:
    //  1. If the text names a command from the HOST's own list and a stream
    //     is active, use the same ENet index path the menu uses
    //     (LiSendExecServerCmd) -- identical semantics to tapping the entry.
    //  2. Otherwise send it to Apollo's /actions/server HTTP endpoint over
    //     the paired HTTPS connection and report the host's actual answer.
    //     An unknown command surfaces as a FAILURE, never a fake success.
    if (m_computer->serverCommands.contains(command) &&
            isStreamingSessionActive()) {
        sendCommandExecution(command);
        return;
    }

    sendHttpCustomCommand(command);
}

void ServerCommandManager::sendHttpCustomCommand(const QString &command)
{
    // Same endpoint and transport as sendHttpServerCommand() uses for the
    // built-ins; the command name is percent-encoded because it is free text.
    try {
        QString arguments = "command=" +
            QString::fromUtf8(QUrl::toPercentEncoding(command));
        QString response = m_http->openConnectionToString(m_http->m_BaseUrlHttps,
                                                          "actions/server",
                                                          arguments.toUtf8().constData(),
                                                          10000,
                                                          NvHTTP::NVLL_VERBOSE);

        m_isExecuting = false;
        m_currentExecutingCommand.clear();
        emit executionStateChanged();

        if (response.contains("success", Qt::CaseInsensitive) ||
                response.contains("200") ||
                response.contains("OK")) {
            qDebug() << "ServerCommandManager: Custom command executed via HTTP:" << command;
            emit commandExecuted("custom", true,
                                 QString("Command '%1' executed").arg(command));
        }
        else {
            qWarning() << "ServerCommandManager: Custom command rejected by host:" << command
                       << "response:" << response;
            emit commandFailed("custom",
                               QString("Host rejected command '%1': %2").arg(command, response));
        }
    } catch (const GfeHttpResponseException& e) {
        m_isExecuting = false;
        m_currentExecutingCommand.clear();
        emit executionStateChanged();
        emit commandFailed("custom",
                           QString("Command '%1' failed: %2").arg(command, e.toQString()));
    } catch (const QtNetworkReplyException& e) {
        m_isExecuting = false;
        m_currentExecutingCommand.clear();
        emit executionStateChanged();
        emit commandFailed("custom",
                           QString("Command '%1' failed: %2").arg(command, e.toQString()));
    }
}

QStringList ServerCommandManager::getAvailableCommands() const
{
    return m_availableCommands;
}

QString ServerCommandManager::getCommandName(const QString &commandId) const
{
    return m_commandNames.value(commandId, commandId);
}

QString ServerCommandManager::getCommandDescription(const QString &commandId) const
{
    return m_commandDescriptions.value(commandId, "No description available");
}

bool ServerCommandManager::isApolloServer() const
{
    if (!m_computer) {
        qDebug() << "ServerCommandManager::isApolloServer: No computer object";
        return false;
    }
    
    // Simplified Apollo detection - always return true and let HTTP calls fail naturally
    // This matches the approach used in ClipboardManager for better reliability
    qDebug() << "ServerCommandManager::isApolloServer: Assuming Apollo server (simplified detection)";
    return true;
}

void ServerCommandManager::sendCommandExecution(const QString &commandId)
{
    qDebug() << "ServerCommandManager: Sending command execution:" << commandId;

    if (!m_computer) {
        qWarning() << "ServerCommandManager: No computer object available";
        m_isExecuting = false;
        m_currentExecutingCommand.clear();
        emit executionStateChanged();
        emit commandFailed(commandId, "No computer connection");
        return;
    }

    // LiSendExecServerCmd() sends an INDEX into the HOST's command
    // list. The old builtin-list fallback sent an index into OUR local list, so on a
    // host whose list differs, "shutdown" could execute whatever the host had at that
    // slot. Only ever index into the host-provided list; without one, refuse.
    QStringList serverCommands = m_computer->serverCommands;
    qDebug() << "ServerCommandManager: Using server-provided commands:" << serverCommands;
    
    if (serverCommands.isEmpty()) {
        qWarning() << "ServerCommandManager: No server commands available";
        m_isExecuting = false;
        m_currentExecutingCommand.clear();
        emit executionStateChanged();
        emit commandFailed(commandId, "No server commands available");
        return;
    }

    qDebug() << "ServerCommandManager: Available server commands:" << serverCommands;

    // Find the command in the server's command list
    int cmdId = -1;
    for (int i = 0; i < serverCommands.size(); ++i) {
        if (serverCommands[i] == commandId) {
            cmdId = i;
            break;
        }
    }

    if (cmdId == -1) {
        qWarning() << "ServerCommandManager: Command not found in server commands:" << commandId;
        qWarning() << "ServerCommandManager: Available commands:" << serverCommands;
        m_isExecuting = false;
        m_currentExecutingCommand.clear();
        emit executionStateChanged();
        emit commandFailed(commandId, "Command not supported by server");
        return;
    }

    qDebug() << "ServerCommandManager: Mapped command" << commandId << "to index" << cmdId;

    // Check for active streaming session
    if (!isStreamingSessionActive()) {
        qWarning() << "ServerCommandManager: Cannot execute command - no active streaming session";
        m_isExecuting = false;
        m_currentExecutingCommand.clear();
        emit executionStateChanged();
        emit commandFailed(commandId, "Server commands are only available during active streaming sessions");
        return;
    }

    // Use ENet-based command execution (correct approach for Apollo servers)
    qDebug() << "ServerCommandManager: Using ENet-based command execution";
    int result = LiSendExecServerCmd(static_cast<uint8_t>(cmdId));

    // Process result. LiSendExecServerCmd() returns the bool from
    // sendMessageAndForget() (moonlight-common-c ControlStream.c): NONZERO/true means
    // the command was sent to the host OK, 0/false means the send failed. Treat nonzero
    // as success -- the old "result == 0" check was inverted and logged a successful
    // send (result 1) as "execution failed with result: 1".
    m_isExecuting = false;
    m_currentExecutingCommand.clear();
    emit executionStateChanged();

    if (result != 0) {
        qDebug() << "ServerCommandManager: Command sent successfully:" << commandId;
        emit commandExecuted(commandId, true, "Command executed successfully");
    } else {
        qWarning() << "ServerCommandManager: Command execution failed:" << commandId << "with result:" << result;
        emit commandFailed(commandId, QString("Command execution failed with result: %1").arg(result));
    }
}

void ServerCommandManager::onCommandsReceived()
{
    // TODO: Handle response from fetchAvailableCommands()
    // This would parse the HTTP response and update available commands
    qDebug() << "ServerCommandManager: Commands received from server";
}

void ServerCommandManager::onCommandExecutionFinished()
{
    // TODO: Handle response from sendCommandExecution()
    // This would parse the execution result and emit commandExecuted signal
    qDebug() << "ServerCommandManager: Command execution finished";
}

bool ServerCommandManager::isStreamingSessionActive() const
{
    // Check if there's an active streaming session using Session::get()
    Session* activeSession = Session::get();
    
    if (!activeSession) {
        qDebug() << "ServerCommandManager: No active session";
        return false;
    }
    
    // The session exists, but we need to check if it has successfully connected
    // Since m_AsyncConnectionSuccess is private, we'll assume that if we have an active session
    // and basic connection requirements are met, we can attempt the command
    // The LiSendExecServerCmd function will provide the definitive answer
    
    if (!m_computer || !m_http) {
        qDebug() << "ServerCommandManager: No computer or HTTP connection";
        return false;
    }
    
    qDebug() << "ServerCommandManager: Session appears to be active";
    return true;
}

void ServerCommandManager::onComputerPairingCompleted()
{
    qDebug() << "ServerCommandManager::onComputerPairingCompleted: Computer pairing completed, refreshing commands";
    
    // Wait a short moment to ensure the computer state is fully updated after pairing
    QTimer::singleShot(1000, this, [this]() {
        if (m_computer && m_http) {
            qDebug() << "ServerCommandManager::onComputerPairingCompleted: Delayed refresh after pairing";
            refreshCommands();
        }
    });
}

void ServerCommandManager::onComputerStateChanged()
{
    if (!m_computer) {
        qDebug() << "ServerCommandManager::onComputerStateChanged: No computer object";
        return;
    }
    
    qDebug() << "ServerCommandManager::onComputerStateChanged: Computer state changed, pair state:" << m_computer->pairState;
    
    // If the computer is now paired and we don't have server commands yet, refresh them
    if (m_computer->pairState == NvComputer::PS_PAIRED && m_availableCommands.isEmpty() && !m_refreshInProgress) {
        qDebug() << "ServerCommandManager::onComputerStateChanged: Computer is now paired, refreshing server commands";
        QTimer::singleShot(500, this, [this]() {
            if (m_computer && m_http && m_computer->pairState == NvComputer::PS_PAIRED) {
                qDebug() << "ServerCommandManager::onComputerStateChanged: Delayed refresh after state change";
                refreshCommands();
            }
        });
    }
}

bool ServerCommandManager::sendHttpServerCommand(const QString &commandId)
{
    if (!m_http || !m_computer) {
        qDebug() << "ServerCommandManager::sendHttpServerCommand: No HTTP client or computer available";
        return false;
    }
    
    // Map command IDs to Apollo server command names
    QString apolloCommand;
    if (commandId == "shutdown_server") {
        apolloCommand = "shutdown";
    } else if (commandId == "restart_server") {
        apolloCommand = "restart";
    } else if (commandId == "shutdown_computer") {
        apolloCommand = "shutdown";
    } else if (commandId == "restart_computer") {
        apolloCommand = "restart";
    } else if (commandId == "suspend_computer") {
        apolloCommand = "suspend";
    } else if (commandId == "hibernate_computer") {
        apolloCommand = "hibernate";
    } else {
        qDebug() << "ServerCommandManager::sendHttpServerCommand: Unknown command ID:" << commandId;
        return false;
    }
    
    qDebug() << "ServerCommandManager::sendHttpServerCommand: Sending HTTP command:" << apolloCommand << "for command ID:" << commandId;
    
    try {
        // Use the Apollo server command endpoint
        QString arguments = "command=" + apolloCommand;
        QString response = m_http->openConnectionToString(m_http->m_BaseUrlHttps,
                                                         "actions/server",
                                                         arguments.toUtf8().constData(),
                                                         10000, // 10 second timeout
                                                         NvHTTP::NVLL_VERBOSE);
        
        qDebug() << "ServerCommandManager::sendHttpServerCommand: Received response:" << response;
        
        // Parse the response to check for success
        // Apollo server typically returns JSON or XML responses
        if (response.contains("success") || response.contains("200") || response.contains("OK")) {
            qDebug() << "ServerCommandManager::sendHttpServerCommand: Command executed successfully via HTTP";
            
            // Reset execution state and emit success
            m_isExecuting = false;
            m_currentExecutingCommand.clear();
            emit executionStateChanged();
            emit commandExecuted(commandId, true, "Command executed successfully via HTTP");
            return true;
        } else {
            qWarning() << "ServerCommandManager::sendHttpServerCommand: Command failed via HTTP, response:" << response;
            
            // Reset execution state and emit failure
            m_isExecuting = false;
            m_currentExecutingCommand.clear();
            emit executionStateChanged();
            emit commandFailed(commandId, "HTTP command execution failed: " + response);
            return true; // Return true to indicate we handled the command (even if it failed)
        }
        
    } catch (const GfeHttpResponseException& e) {
        qDebug() << "ServerCommandManager::sendHttpServerCommand: HTTP error:" << e.toQString();
        
        // Reset execution state and emit failure
        m_isExecuting = false;
        m_currentExecutingCommand.clear();
        emit executionStateChanged();
        emit commandFailed(commandId, "HTTP command execution failed: " + e.toQString());
        return true; // Return true to indicate we handled the command (even if it failed)
        
    } catch (const QtNetworkReplyException& e) {
        qDebug() << "ServerCommandManager::sendHttpServerCommand: Network error:" << e.toQString();
        
        // Reset execution state and emit failure
        m_isExecuting = false;
        m_currentExecutingCommand.clear();
        emit executionStateChanged();
        emit commandFailed(commandId, "HTTP command execution failed: " + e.toQString());
        return true; // Return true to indicate we handled the command (even if it failed)
    }
    
    return false;
}

void ServerCommandManager::noCommandsAvailable()
{
    // This matches the Android dialog shown when no server commands are available
    qDebug() << "ServerCommandManager::noCommandsAvailable: No server commands available";
    // UI components can connect to this slot to display appropriate messaging
}

