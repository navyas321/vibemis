#include "startstream.h"
#include "backend/computermanager.h"
#include "backend/computerseeker.h"
#include "streaming/session.h"

#include <QCoreApplication>
#include <QStringList>
#include <QTimer>

#define COMPUTER_SEEK_TIMEOUT 30000
#define APP_SEEK_TIMEOUT 10000

namespace CliStartStream
{

enum State {
    StateInit,
    StateSeekComputer,
    StateSeekApp,
    StateStartSession,
    StateFailure,
};

class Event
{
public:
    enum Type {
        AppQuitCompleted,
        AppQuitRequested,
        ComputerFound,
        ComputerUpdated,
        Executed,
        Timedout,
    };

    Event(Type type)
        : type(type), computerManager(nullptr), computer(nullptr) {}

    Type type;
    ComputerManager *computerManager;
    NvComputer *computer;
    QString errorMessage;
};

class LauncherPrivate
{
    Q_DECLARE_PUBLIC(Launcher)

public:
    LauncherPrivate(Launcher *q) : q_ptr(q) {}

    void handleEvent(Event event)
    {
        Q_Q(Launcher);

        switch (event.type) {
        // Occurs when CliStartStreamSegue becomes visible and the UI calls launcher's execute()
        case Event::Executed:
            if (m_State == StateInit) {
                m_State = StateSeekComputer;
                m_ComputerManager = event.computerManager;

                m_ComputerSeeker = new ComputerSeeker(m_ComputerManager, m_ComputerName, q);
                q->connect(m_ComputerSeeker, &ComputerSeeker::computerFound,
                           q, &Launcher::onComputerFound);
                q->connect(m_ComputerSeeker, &ComputerSeeker::errorTimeout,
                           q, &Launcher::onTimeout);
                m_ComputerSeeker->start(COMPUTER_SEEK_TIMEOUT);

                q->connect(m_ComputerManager, &ComputerManager::computerStateChanged,
                           q, &Launcher::onComputerUpdated);
                q->connect(m_ComputerManager, &ComputerManager::quitAppCompleted,
                           q, &Launcher::onQuitAppCompleted);

                emit q->searchingComputer();
            }
            break;
        // Occurs when searched computer is found
        case Event::ComputerFound:
            if (m_State == StateSeekComputer) {
                if (event.computer->pairState == NvComputer::PS_PAIRED) {
                    m_State = StateSeekApp;
                    m_Computer = event.computer;
                    m_TimeoutTimer->start(APP_SEEK_TIMEOUT);
                    emit q->searchingApp();

                    // The app list is often already cached for a known host, and no
                    // further computerStateChanged may arrive within the seek window — which
                    // used to time out with "Failed to find application" even though the app
                    // was present. Try the cached list immediately instead of waiting for
                    // the next update event.
                    trySeekApp(q);
                } else {
                    m_State = StateFailure;
                    QString msg = QObject::tr("Computer %1 has not been paired. "
                                              "Please open Moonlight to pair before streaming.")
                            .arg(event.computer->name);
                    emit q->failed(msg);
                }
            }
            break;
        // Occurs when a computer is updated
        case Event::ComputerUpdated:
            if (m_State == StateSeekApp) {
                trySeekApp(q);
            }
            break;
        // Occurs when there was another app running on computer and user accepted quit
        // confirmation dialog
        case Event::AppQuitRequested:
            if (m_State == StateSeekApp) {
                m_ComputerManager->quitRunningApp(m_Computer);
            }
            break;
        // Occurs when the previous app quit has been completed, handles quitting errors if any
        // happened. ComputerUpdated event's handler handles session start when previous app has
        // quit.
        case Event::AppQuitCompleted:
            if (m_State == StateSeekApp && !event.errorMessage.isEmpty()) {
                m_State = StateFailure;
                emit q->failed(QObject::tr("Quitting app failed, reason: %1").arg(event.errorMessage));
            }
            break;
        // Occurs when computer or app search timed out
        case Event::Timedout:
            if (m_State == StateSeekComputer) {
                m_State = StateFailure;
                emit q->failed(QObject::tr("Failed to connect to %1").arg(m_ComputerName));
            }
            if (m_State == StateSeekApp) {
                m_State = StateFailure;
                // Name the apps that ARE available so a typo'd/renamed app is
                // self-diagnosing from the CLI output.
                QStringList available;
                for (const NvApp &a : m_Computer->appList) {
                    available.append(sanitizeAppName(a.name));
                }
                emit q->failed(QObject::tr("Failed to find application %1").arg(m_AppName)
                               + (available.isEmpty()
                                  ? QObject::tr(" (the host returned an empty app list)")
                                  : QObject::tr(" (available: %1)").arg(available.join(", "))));
            }
            break;
        }
    }

    // Run one seek attempt against the computer's current app list. Called on
    // entry to StateSeekApp (cached list) and on every ComputerUpdated. Starts the
    // session / requests a quit exactly like the old inline ComputerUpdated handler.
    void trySeekApp(Launcher *q)
    {
        int index = getAppIndex();
        if (-1 != index) {
            NvApp app = m_Computer->appList[index];
            m_TimeoutTimer->stop();
            if (isNotStreaming() || isStreamingApp(app)) {
                m_State = StateStartSession;
                Session* session = new Session(m_Computer, app, m_Preferences);
                emit q->sessionCreated(app.name, session);
            } else {
                emit q->appQuitRequired(getCurrentAppName());
            }
        }
    }

    // Host app names can carry zero-width /
    // format Unicode characters that break both matching and readable error output.
    // Strip format-category chars and trim before comparing or displaying.
    static QString sanitizeAppName(const QString& name)
    {
        QString out;
        out.reserve(name.size());
        for (const QChar& c : name) {
            if (c.category() != QChar::Other_Format) {
                out.append(c);
            }
        }
        return out.trimmed();
    }

    int getAppIndex() const
    {
        // Exact match first (sanitized + case-insensitive)...
        const QString wanted = sanitizeAppName(m_AppName).toLower();
        for (int i = 0; i < m_Computer->appList.length(); i++) {
            if (sanitizeAppName(m_Computer->appList[i].name).toLower() == wanted) {
                return i;
            }
        }
        // ...then a UNIQUE substring match ("desk" -> "Desktop") so minor host-side
        // renames ("Desktop (Virtual)") don't break scripted launches. Ambiguous
        // prefixes still fail (and the timeout message lists the candidates).
        int found = -1;
        for (int i = 0; i < m_Computer->appList.length(); i++) {
            if (sanitizeAppName(m_Computer->appList[i].name).toLower().contains(wanted)) {
                if (found != -1) {
                    return -1; // ambiguous — require an exact name
                }
                found = i;
            }
        }
        return found;
    }

    bool isNotStreaming() const
    {
        return m_Computer->currentGameId == 0;
    }

    bool isStreamingApp(NvApp app) const
    {
        return m_Computer->currentGameId == app.id;
    }

    QString getCurrentAppName() const
    {
        for (const NvApp& app : std::as_const(m_Computer->appList)) {
            if (m_Computer->currentGameId == app.id) {
                return app.name;
            }
        }
        return "<UNKNOWN>";
    }

    Launcher *q_ptr;
    QString m_ComputerName;
    QString m_AppName;
    StreamingPreferences *m_Preferences;
    ComputerManager *m_ComputerManager;
    ComputerSeeker *m_ComputerSeeker;
    NvComputer *m_Computer;
    State m_State;
    QTimer *m_TimeoutTimer;
};

Launcher::Launcher(QString computer, QString app,
                   StreamingPreferences* preferences, QObject *parent)
    : QObject(parent),
      m_DPtr(new LauncherPrivate(this))
{
    Q_D(Launcher);
    d->m_ComputerName = computer;
    d->m_AppName = app;
    d->m_Preferences = preferences;
    d->m_State = StateInit;
    d->m_TimeoutTimer = new QTimer(this);
    d->m_TimeoutTimer->setSingleShot(true);
    connect(d->m_TimeoutTimer, &QTimer::timeout,
            this, &Launcher::onTimeout);
}

Launcher::~Launcher()
{
}

void Launcher::execute(ComputerManager *manager)
{
    Q_D(Launcher);
    Event event(Event::Executed);
    event.computerManager = manager;
    d->handleEvent(event);
}

void Launcher::quitRunningApp()
{
    Q_D(Launcher);
    Event event(Event::AppQuitRequested);
    d->handleEvent(event);
}

bool Launcher::isExecuted() const
{
    Q_D(const Launcher);
    return d->m_State != StateInit;
}

void Launcher::onComputerFound(NvComputer *computer)
{
    Q_D(Launcher);
    Event event(Event::ComputerFound);
    event.computer = computer;
    d->handleEvent(event);
}

void Launcher::onComputerUpdated(NvComputer *computer)
{
    Q_D(Launcher);
    Event event(Event::ComputerUpdated);
    event.computer = computer;
    d->handleEvent(event);
}

void Launcher::onTimeout()
{
    Q_D(Launcher);
    Event event(Event::Timedout);
    d->handleEvent(event);
}

void Launcher::onQuitAppCompleted(QVariant error)
{
    Q_D(Launcher);
    Event event(Event::AppQuitCompleted);
    event.errorMessage = error.toString();
    d->handleEvent(event);
}

}
