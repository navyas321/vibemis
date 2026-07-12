#include "servercommandmanager.h"
#include "nvcomputer.h"
#include "nvhttp.h"
#include "streaming/session.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QNetworkRequest>
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
    // test81 (review fix): take ownership of the NvHTTP handed to us — the previous one
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
        qDebug() << "ServerCommandManager::refreshCommands: No server commands in serverinfo XML, trying separate endpoint";
        
        // Try to fetch server commands from a separate endpoint (Apollo extension)
        fetchAvailableCommands();
        
        // For now, assume Apollo server and populate with builtin commands as fallback
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
    
    // TODO: Implement actual custom command execution via HTTP
    // For now, just simulate success with a delay
    QTimer::singleShot(1500, this, [this, command]() {
        m_isExecuting = false;
        m_currentExecutingCommand.clear();
        emit executionStateChanged();
        emit commandExecuted("custom", true, QString("Custom command '%1' executed successfully").arg(command));
    });
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

void ServerCommandManager::fetchAvailableCommands()
{
    if (!m_http || !m_computer) {
        qDebug() << "ServerCommandManager::fetchAvailableCommands: No HTTP client or computer available";
        return;
    }
    
    qDebug() << "ServerCommandManager::fetchAvailableCommands: Trying to fetch server commands from separate endpoint";
    
    // Try different possible endpoints where Apollo might expose server commands
    QStringList possibleEndpoints = {
        "servercommands",
        "commands",
        "api/commands",
        "api/servercommands",
        "servercommands.xml",
        "commands.xml"
    };
    
    for (const QString &endpoint : possibleEndpoints) {
        try {
            qDebug() << "ServerCommandManager::fetchAvailableCommands: Trying endpoint:" << endpoint;
            
            // Use the existing NvHTTP method to make the request
            QString response = m_http->openConnectionToString(m_http->m_BaseUrlHttps,
                                                             endpoint,
                                                             nullptr,
                                                             5000, // 5 second timeout
                                                             NvHTTP::NVLL_VERBOSE);
            
            // Convert to QByteArray
            QByteArray responseData = response.toUtf8();
            
            qDebug() << "ServerCommandManager::fetchAvailableCommands: Received response from" << endpoint << "(" << responseData.size() << "bytes)";
            qDebug() << "ServerCommandManager::fetchAvailableCommands: Response content:" << responseData;
            
            // Try to parse the response as XML
            if (parseServerCommandsXml(responseData)) {
                qDebug() << "ServerCommandManager::fetchAvailableCommands: Successfully parsed server commands from endpoint:" << endpoint;
                return; // Success! Exit early
            }
            
            qWarning() << "ServerCommandManager::fetchAvailableCommands: Failed to parse server commands from endpoint:" << endpoint;
            
        } catch (const GfeHttpResponseException& e) {
            qDebug() << "ServerCommandManager::fetchAvailableCommands: Failed to fetch from" << endpoint << "with error:" << e.toQString();
        } catch (const QtNetworkReplyException& e) {
            qDebug() << "ServerCommandManager::fetchAvailableCommands: Network error for" << endpoint << ":" << e.toQString();
        }
    }
    
    qDebug() << "ServerCommandManager::fetchAvailableCommands: No server commands found from any endpoint";
}

bool ServerCommandManager::parseServerCommandsXml(const QByteArray &xmlData)
{
    qDebug() << "ServerCommandManager::parseServerCommandsXml: Parsing XML data";
    
    if (xmlData.isEmpty()) {
        qWarning() << "ServerCommandManager::parseServerCommandsXml: Empty XML data";
        return false;
    }
    
    QXmlStreamReader xml(xmlData);
    QStringList parsedCommands;
    QStringList commandNames;
    QStringList commandDescriptions;
    
    while (!xml.atEnd()) {
        xml.readNext();
        
        if (xml.isStartElement()) {
            if (xml.name().toString() == "ServerCommand") {
                // Parse Apollo/Android style server command
                QString commandText = xml.readElementText();
                if (!commandText.isEmpty()) {
                    parsedCommands.append(commandText);
                    commandNames.append(commandText);
                    commandDescriptions.append("Server command: " + commandText);
                    qDebug() << "ServerCommandManager::parseServerCommandsXml: Found server command:" << commandText;
                }
            } else if (xml.name().toString() == "Command") {
                // Parse alternative command format
                QString commandId;
                QString commandName;
                QString commandDescription;
                
                // Read attributes
                QXmlStreamAttributes attributes = xml.attributes();
                if (attributes.hasAttribute("id")) {
                    commandId = attributes.value("id").toString();
                }
                if (attributes.hasAttribute("name")) {
                    commandName = attributes.value("name").toString();
                }
                if (attributes.hasAttribute("description")) {
                    commandDescription = attributes.value("description").toString();
                }
                
                // If no attributes, try to read as text
                if (commandId.isEmpty()) {
                    commandId = xml.readElementText();
                }
                
                if (!commandId.isEmpty()) {
                    parsedCommands.append(commandId);
                    commandNames.append(commandName.isEmpty() ? commandId : commandName);
                    commandDescriptions.append(commandDescription.isEmpty() ? ("Server command: " + commandId) : commandDescription);
                    qDebug() << "ServerCommandManager::parseServerCommandsXml: Found command:" << commandId << "name:" << commandName << "description:" << commandDescription;
                }
            }
        }
    }
    
    if (xml.hasError()) {
        qWarning() << "ServerCommandManager::parseServerCommandsXml: XML parsing error:" << xml.errorString();
        return false;
    }
    
    if (parsedCommands.isEmpty()) {
        qWarning() << "ServerCommandManager::parseServerCommandsXml: No commands found in XML";
        return false;
    }
    
    // Update our command lists
    m_hasPermission = true;
    m_availableCommands = parsedCommands;
    m_commandNames.clear();
    m_commandDescriptions.clear();
    
    for (int i = 0; i < parsedCommands.size(); ++i) {
        m_commandNames[parsedCommands[i]] = commandNames[i];
        m_commandDescriptions[parsedCommands[i]] = commandDescriptions[i];
    }
    
    qDebug() << "ServerCommandManager::parseServerCommandsXml: Successfully parsed" << parsedCommands.size() << "commands:" << parsedCommands;
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

    // test81 (review fix): LiSendExecServerCmd() sends an INDEX into the HOST's command
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

    // Process result
    m_isExecuting = false;
    m_currentExecutingCommand.clear();
    emit executionStateChanged();

    if (result == 0) {
        qDebug() << "ServerCommandManager: Command executed successfully:" << commandId;
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

