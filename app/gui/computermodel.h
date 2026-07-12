#include "backend/computermanager.h"
#include "streaming/session.h"

#include <QAbstractListModel>

class ComputerModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Roles
    {
        NameRole = Qt::UserRole,
        OnlineRole,
        PairedRole,
        BusyRole,
        WakeableRole,
        StatusUnknownRole,
        ServerSupportedRole,
        DetailsRole,
        ApolloVersionRole,
        IsApolloServerRole,
        PermissionSummaryRole
    };
    // Expose the role enum to QML so ComputerModel.OnlineRole / NameRole resolve to their
    // int values (used by PcView's live host-count and the existing data(index, role) calls,
    // which previously fell back silently because the enum was never registered).
    Q_ENUM(Roles)

    explicit ComputerModel(QObject* object = nullptr);

    // Must be called before any QAbstractListModel functions
    Q_INVOKABLE void initialize(ComputerManager* computerManager);

    QVariant data(const QModelIndex &index, int role) const override;

    int rowCount(const QModelIndex &parent) const override;

    virtual QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void deleteComputer(int computerIndex);

    Q_INVOKABLE QString generatePinString();

    Q_INVOKABLE void pairComputer(int computerIndex, QString pin);

    Q_INVOKABLE void pairComputerWithOTP(int computerIndex, QString pin, QString passphrase);

    // Called from QML when the user confirms they have entered the PIN in the
    // host web UI. Releases the semaphore that gates phase 2 of OTP pairing.
    Q_INVOKABLE void resumeOTPPairing();

    Q_INVOKABLE bool isOTPSupported(int computerIndex);

    Q_INVOKABLE void testConnectionForComputer(int computerIndex);

    Q_INVOKABLE void wakeComputer(int computerIndex);

    Q_INVOKABLE void renameComputer(int computerIndex, QString name);

    Q_INVOKABLE Session* createSessionForCurrentGame(int computerIndex);

signals:
    void pairingCompleted(QVariant error);
    void connectionTestCompleted(int result, QString blockedPorts);
    // Forwarded from ComputerManager::otpStage1Completed — UI shows Continue button
    void otpStage1Completed();

private slots:
    void handleComputerStateChanged(NvComputer* computer);

    void handlePairingCompleted(NvComputer* computer, QString error);

private:
    QVector<NvComputer*> m_Computers;
    ComputerManager* m_ComputerManager;
};
