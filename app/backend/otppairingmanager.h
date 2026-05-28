#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QCryptographicHash>
#include <QTimer>
#include <QSslCertificate>

class NvComputer;
class NvHTTP;
class NvPairingManager;

// Forward declarations for Qt MOC system
Q_DECLARE_OPAQUE_POINTER(NvComputer*)

/**
 * @brief Manages OTP (One-Time Password) pairing with Apollo servers
 * 
 * This class implements OTP pairing functionality as used in Vibemis Android.
 * It extends the standard PIN pairing with SHA-256 hash authentication.
 * Based on PairingManager.java implementation.
 */
class OTPPairingManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    enum PairState
    {
        PAIRED,
        PIN_WRONG,
        FAILED,
        ALREADY_IN_PROGRESS
    };

    explicit OTPPairingManager(QObject *parent = nullptr);
    ~OTPPairingManager();

    // OTP pairing operations (matches Android API)
    Q_INVOKABLE void startOTPPairing(NvComputer *computer, const QString &pin, const QString &passphrase = QString());
    Q_INVOKABLE void cancelPairing();
    
    // State queries
    Q_INVOKABLE bool isPairingInProgress() const;
    Q_INVOKABLE bool isOTPSupported(NvComputer *computer) const;

signals:
    void pairingStarted();
    void pairingCompleted(bool success, const QString &message);
    void pairingFailed(const QString &error);
    void pairingProgress(const QString &status);

private slots:
    void onPairingTimeout();

private:
    // OTP hash generation (matches Android implementation)
    QString generateOTPHash(const QString &pin, const QString &salt, const QString &passphrase);
    
    // Pairing flow helpers
    void performOTPPairing(NvComputer *computer, const QString &pin, const QString &passphrase);
    bool validatePinFormat(const QString &pin);
    
    // Network request helpers
    void sendOTPPairingRequest(NvComputer *computer, const QString &otpHash, const QString &salt, const QString &passphrase);
    
    // Apollo OTP pairing implementation
    PairState performApolloOTPPairing(NvPairingManager &pairingManager, NvComputer *serverInfo, const QString &pin, const QString &passphrase);
    
    // AES encryption/decryption helpers (similar to NvPairingManager)
    QByteArray encryptAES(const QByteArray &plaintext, const QByteArray &key);
    QByteArray decryptAES(const QByteArray &ciphertext, const QByteArray &key);

private:
    static constexpr int OTP_PIN_LENGTH = 4; // Matches Android constant
    
    NvComputer *m_currentComputer;
    QTimer *m_timeoutTimer;
    
    bool m_pairingInProgress;
    QString m_currentPin;
    QString m_currentPassphrase;
};
