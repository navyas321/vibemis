#include "computermodel.h"
#include "backend/serverpermissions.h"
#include "settings/vibemissettings.h"

#include <QThreadPool>
#include <QDateTime>

ComputerModel::ComputerModel(QObject* object)
    : QAbstractListModel(object) {}

void ComputerModel::initialize(ComputerManager* computerManager)
{
    m_ComputerManager = computerManager;
    connect(m_ComputerManager, &ComputerManager::computerStateChanged,
            this, &ComputerModel::handleComputerStateChanged);
    connect(m_ComputerManager, &ComputerManager::pairingCompleted,
            this, &ComputerModel::handlePairingCompleted);
    connect(m_ComputerManager, &ComputerManager::otpStage1Completed,
            this, &ComputerModel::otpStage1Completed);

    m_Computers = m_ComputerManager->getComputers();
}

QVariant ComputerModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid()) {
        return QVariant();
    }

    Q_ASSERT(index.row() < m_Computers.count());

    NvComputer* computer = m_Computers[index.row()];
    QReadLocker lock(&computer->lock);

    switch (role) {
    case NameRole:
        return computer->name;
    case OnlineRole:
        return computer->state == NvComputer::CS_ONLINE;
    case PairedRole:
        return computer->pairState == NvComputer::PS_PAIRED;
    case BusyRole:
        return computer->currentGameId != 0;
    case WakeableRole:
        return !computer->macAddress.isEmpty();
    case StatusUnknownRole:
        return computer->state == NvComputer::CS_UNKNOWN;
    case ServerSupportedRole:
        return computer->isSupportedServerVersion;
    case ApolloVersionRole:
        return computer->apolloVersion;
    case IsApolloServerRole:
        return computer->isApolloServer();
    case PermissionSummaryRole: {
        // Vibemis (P3.13): a concise at-a-glance access level for Apollo hosts, which grant the
        // first paired client full permissions and later clients view/input-only. Empty for hosts
        // that don't report permissions (e.g. plain Sunshine / not yet connected).
        quint32 p = computer->serverPermissions;
        if (p == 0) {
            return QString();
        }
        const quint32 inputMask = ServerPermissions::CONTROLLER_INPUT | ServerPermissions::TOUCH_INPUT |
                                  ServerPermissions::PEN_INPUT | ServerPermissions::MOUSE_INPUT |
                                  ServerPermissions::KEYBOARD_INPUT;
        if (p & ServerPermissions::LAUNCH_APPS) {
            return tr("Full access");
        }
        else if (p & inputMask) {
            return tr("View + input");
        }
        else {
            return tr("View only");
        }
    }
    case HostTypeRole: {
        // Redesign 1a host-type badge. Detection is best-effort (Vibepollo deliberately mimics
        // Sunshine's serverinfo — no ApolloVersion, state=SUNSHINE_SERVER_FREE), so we key on the
        // Apollo-lineage PERMISSION model: Apollo advertises ApolloVersion; Vibepollo does not but
        // still exposes serverPermissions once paired; vanilla Sunshine has no permission model.
        if (!computer->apolloVersion.isEmpty()) {
            return QStringLiteral("APOLLO");
        }
        else if (computer->serverPermissions != 0) {
            return QStringLiteral("VIBEPOLLO");
        }
        else {
            return QStringLiteral("SUNSHINE");
        }
    }
    case TransportRole: {
        // Tailscale hands out addresses in the 100.64.0.0/10 CGNAT range (100.64.x – 100.127.x);
        // anything else on the active path is treated as LAN.
        QString addr = computer->activeAddress.address();
        if (addr.startsWith(QStringLiteral("100."))) {
            bool ok = false;
            int second = addr.section('.', 1, 1).toInt(&ok);
            if (ok && second >= 64 && second <= 127) {
                return QStringLiteral("Tailscale");
            }
        }
        return QStringLiteral("LAN");
    }
    case LatencyTextRole:
        // TODO(BL-1598): surface a measured RTT here (e.g. "4 ms"). Empty for now so the card shows
        // transport only rather than a fabricated number.
        return QString();
    case LastSeenTextRole: {
        // Bare relative delta ("just now" / "3 min ago" / "2 h ago" / "5 d ago); the PcView
        // delegate prepends the "Last seen " label. Only meaningful for an offline host we
        // actually saw online at least once this session (lastSeenMs > 0).
        if (computer->state == NvComputer::CS_ONLINE || computer->lastSeenMs <= 0) {
            return QString();
        }
        qint64 deltaMs = QDateTime::currentMSecsSinceEpoch() - computer->lastSeenMs;
        if (deltaMs < 0) {
            deltaMs = 0;
        }
        qint64 mins = deltaMs / 60000;
        if (mins < 1) {
            return tr("just now");
        }
        else if (mins < 60) {
            return tr("%n min ago", "", (int)mins);
        }
        qint64 hours = mins / 60;
        if (hours < 24) {
            return tr("%n h ago", "", (int)hours);
        }
        qint64 days = hours / 24;
        return tr("%n d ago", "", (int)days);
    }
    case DetailsRole: {
        QString state, pairState;

        switch (computer->state) {
        case NvComputer::CS_ONLINE:
            state = tr("Online");
            break;
        case NvComputer::CS_OFFLINE:
            state = tr("Offline");
            break;
        default:
            state = tr("Unknown");
            break;
        }

        switch (computer->pairState) {
        case NvComputer::PS_PAIRED:
            pairState = tr("Paired");
            break;
        case NvComputer::PS_NOT_PAIRED:
            pairState = tr("Unpaired");
            break;
        default:
            pairState = tr("Unknown");
            break;
        }

        QString details;
        
        // Basic Information Section
        details += tr("═══ COMPUTER INFORMATION ═══") + '\n';
        details += tr("Name: %1").arg(computer->name) + '\n';
        details += tr("Status: %1").arg(state) + '\n';
        details += tr("Pair State: %1").arg(pairState) + '\n';
        details += tr("Running Game: %1").arg(computer->state == NvComputer::CS_ONLINE ? 
                     (computer->currentGameId != 0 ? QString::number(computer->currentGameId) : tr("None")) : 
                     tr("Unknown")) + '\n';
        
        // Network Information Section
        details += '\n' + tr("═══ NETWORK INFORMATION ═══") + '\n';
        details += tr("Active Address: %1").arg(computer->activeAddress.toString()) + '\n';
        details += tr("Local Address: %1").arg(computer->localAddress.toString()) + '\n';
        details += tr("Remote Address: %1").arg(computer->remoteAddress.toString()) + '\n';
        details += tr("IPv6 Address: %1").arg(computer->ipv6Address.toString()) + '\n';
        details += tr("Manual Address: %1").arg(computer->manualAddress.toString()) + '\n';
        details += tr("HTTPS Port: %1").arg(computer->state == NvComputer::CS_ONLINE ? QString::number(computer->activeHttpsPort) : tr("Unknown")) + '\n';
        
        // System Information Section
        details += '\n' + tr("═══ SYSTEM INFORMATION ═══") + '\n';
        details += tr("UUID: %1").arg(computer->uuid) + '\n';
        details += tr("MAC Address: %1").arg(computer->macAddress.isEmpty() ? tr("Unknown") : QString(computer->macAddress.toHex(':'))) + '\n';

        // Vibemis: surface the host software version so users can tell whether their Apollo /
        // Vibepollo / Sunshine host is up to date. apolloVersion is empty on Vibepollo (see
        // NvComputer::isApolloServer note), so also show the generic app/GFE version when present.
        if (!computer->apolloVersion.isEmpty()) {
            details += tr("Apollo Version: %1").arg(computer->apolloVersion) + '\n';
        }
        if (!computer->appVersion.isEmpty()) {
            details += tr("Host Software Version: %1").arg(computer->appVersion) + '\n';
        }
        else if (!computer->gfeVersion.isEmpty()) {
            details += tr("Host Software Version: %1").arg(computer->gfeVersion) + '\n';
        }

        // Server Capabilities Section (Apollo/Sunshine servers only)
        if (computer->serverPermissions != 0) {
            details += '\n' + tr("═══ SERVER CAPABILITIES ═══") + '\n';
            
            QString detailedPermissions = ServerPermissions::getDetailedPermissions(computer->serverPermissions);
            if (!detailedPermissions.isEmpty()) {
                details += detailedPermissions;
            }
        }
        
        // Server Commands Section
        if (!computer->serverCommands.isEmpty()) {
            details += '\n' + tr("═══ SERVER COMMANDS ═══") + '\n';
            details += tr("Available Commands: %1").arg(computer->serverCommands.join(", "));
        }

        // Vibemis P3.13: Apollo-only save-sync awareness. Apollo hosts can sync per-app
        // save data across clients; note the capability (host-side feature, configured on
        // the Apollo host, not in Vibemis).
        if (computer->isApolloServer()) {
            details += QLatin1Char('\n');
            details += tr("Apollo feature: per-app save sync is supported by Apollo hosts "
                          "(enable it per-app on the host).");
        }

        return details;
    }
    default:
        return QVariant();
    }
}

int ComputerModel::rowCount(const QModelIndex& parent) const
{
    // We should not return a count for valid index values,
    // only the parent (which will not have a "valid" index).
    if (parent.isValid()) {
        return 0;
    }

    return m_Computers.count();
}

QHash<int, QByteArray> ComputerModel::roleNames() const
{
    QHash<int, QByteArray> names;

    names[NameRole] = "name";
    names[OnlineRole] = "online";
    names[PairedRole] = "paired";
    names[BusyRole] = "busy";
    names[WakeableRole] = "wakeable";
    names[StatusUnknownRole] = "statusUnknown";
    names[ServerSupportedRole] = "serverSupported";
    names[DetailsRole] = "details";
    names[ApolloVersionRole] = "apolloVersion";
    names[IsApolloServerRole] = "isApolloServer";
    names[PermissionSummaryRole] = "permissionSummary";
    names[HostTypeRole] = "hostType";
    names[TransportRole] = "transport";
    names[LatencyTextRole] = "latencyText";
    names[LastSeenTextRole] = "lastSeenText";

    return names;
}

Session* ComputerModel::createSessionForCurrentGame(int computerIndex)
{
    Q_ASSERT(computerIndex < m_Computers.count());

    NvComputer* computer = m_Computers[computerIndex];

    // We must currently be streaming a game to use this function
    Q_ASSERT(computer->currentGameId != 0);

    for (NvApp& app : computer->appList) {
        if (app.id == computer->currentGameId) {
            return new Session(computer, app);
        }
    }

    // We have a current running app but it's not in our app list
    Q_ASSERT(false);
    return nullptr;
}

void ComputerModel::deleteComputer(int computerIndex)
{
    Q_ASSERT(computerIndex < m_Computers.count());

    beginRemoveRows(QModelIndex(), computerIndex, computerIndex);

    // m_Computer[computerIndex] will be deleted by this call
    m_ComputerManager->deleteHost(m_Computers[computerIndex]);

    // Remove the now invalid item
    m_Computers.removeAt(computerIndex);

    endRemoveRows();
}

class DeferredWakeHostTask : public QRunnable
{
public:
    DeferredWakeHostTask(NvComputer* computer)
        : m_Computer(computer) {}

    void run()
    {
        m_Computer->wake();
    }

private:
    NvComputer* m_Computer;
};

void ComputerModel::wakeComputer(int computerIndex)
{
    Q_ASSERT(computerIndex < m_Computers.count());

    DeferredWakeHostTask* wakeTask = new DeferredWakeHostTask(m_Computers[computerIndex]);
    QThreadPool::globalInstance()->start(wakeTask);
}

void ComputerModel::renameComputer(int computerIndex, QString name)
{
    Q_ASSERT(computerIndex < m_Computers.count());

    m_ComputerManager->renameHost(m_Computers[computerIndex], name);
}

QString ComputerModel::generatePinString()
{
    return m_ComputerManager->generatePinString();
}

class DeferredTestConnectionTask : public QObject, public QRunnable
{
    Q_OBJECT
public:
    void run()
    {
        unsigned int portTestResult = LiTestClientConnectivity("qt.conntest.moonlight-stream.org", 443, ML_PORT_FLAG_ALL);
        if (portTestResult == ML_TEST_RESULT_INCONCLUSIVE) {
            emit connectionTestCompleted(-1, QString());
        }
        else {
            char blockedPorts[512];
            LiStringifyPortFlags(portTestResult, "\n", blockedPorts, sizeof(blockedPorts));
            emit connectionTestCompleted(portTestResult, QString(blockedPorts));
        }
    }

signals:
    void connectionTestCompleted(int result, QString blockedPorts);
};

void ComputerModel::testConnectionForComputer(int)
{
    DeferredTestConnectionTask* testConnectionTask = new DeferredTestConnectionTask();
    QObject::connect(testConnectionTask, &DeferredTestConnectionTask::connectionTestCompleted,
                     this, &ComputerModel::connectionTestCompleted);
    QThreadPool::globalInstance()->start(testConnectionTask);
}

void ComputerModel::pairComputer(int computerIndex, QString pin)
{
    Q_ASSERT(computerIndex < m_Computers.count());

    m_ComputerManager->pairHost(m_Computers[computerIndex], pin);
}

void ComputerModel::pairComputerWithOTP(int computerIndex, QString pin, QString passphrase)
{
    Q_ASSERT(computerIndex < m_Computers.count());

    m_ComputerManager->pairHostWithOTP(m_Computers[computerIndex], pin, passphrase);
}

void ComputerModel::resumeOTPPairing()
{
    m_ComputerManager->resumeOTPPairing();
}

bool ComputerModel::isOTPSupported(int computerIndex)
{
    Q_ASSERT(computerIndex < m_Computers.count());

    NvComputer* computer = m_Computers[computerIndex];
    QReadLocker lock(&computer->lock);
    
    // OTP pairing is only available with Apollo/Sunshine servers (not Nvidia GeForce Experience)
    return !computer->isNvidiaServerSoftware;
}

void ComputerModel::handlePairingCompleted(NvComputer*, QString error)
{
    qDebug() << "ComputerModel::handlePairingCompleted called with error:" << error;
    emit pairingCompleted(error.isEmpty() ? QVariant() : error);
    qDebug() << "ComputerModel: Emitted pairingCompleted signal";
}

void ComputerModel::handleComputerStateChanged(NvComputer* computer)
{
    QVector<NvComputer*> newComputerList = m_ComputerManager->getComputers();

    // Reset the model if the structural layout of the list has changed
    if (m_Computers != newComputerList) {
        beginResetModel();
        m_Computers = newComputerList;
        endResetModel();
    }
    else {
        // Let the view know that this specific computer changed
        int index = m_Computers.indexOf(computer);
        emit dataChanged(createIndex(index, 0), createIndex(index, 0));
    }
}

#include "computermodel.moc"
