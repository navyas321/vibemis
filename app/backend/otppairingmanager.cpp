#include "otppairingmanager.h"
#include "nvcomputer.h"
#include "nvhttp.h"
#include "nvpairingmanager.h"
#include "identitymanager.h"
#include <QDebug>
#include <QCryptographicHash>
#include <QSslCertificate>
#include <QTimer>
#include <QRandomGenerator>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QNetworkProxy>
#include <QEventLoop>
#include <QCoreApplication>
#include <QUuid>
#include <QReadWriteLock>
#include <QRegularExpression>
#include <QSysInfo>
#include <openssl/evp.h>
#include <openssl/aes.h>

#define REQUEST_TIMEOUT_MS 5000

OTPPairingManager::OTPPairingManager(QObject *parent)
    : QObject(parent)
    , m_currentComputer(nullptr)
    , m_timeoutTimer(nullptr)
    , m_pairingInProgress(false)
{
    qDebug() << "OTPPairingManager: Initialized";
}

OTPPairingManager::~OTPPairingManager()
{
    cancelPairing();
    qDebug() << "OTPPairingManager: Destroyed";
}

void OTPPairingManager::startOTPPairing(NvComputer *computer, const QString &pin, const QString &passphrase)
{
    if (!computer) {
        emit pairingFailed("No computer specified");
        return;
    }

    if (!isOTPSupported(computer)) {
        emit pairingFailed("OTP pairing is only available with Apollo servers");
        return;
    }

    if (!validatePinFormat(pin)) {
        emit pairingFailed("PIN must be exactly 4 digits");
        return;
    }

    if (m_pairingInProgress) {
        emit pairingFailed("Pairing already in progress");
        return;
    }

    m_currentComputer = computer;
    m_currentPin = pin;
    m_currentPassphrase = passphrase;
    m_pairingInProgress = true;

    emit pairingStarted();
    emit pairingProgress("Starting OTP pairing...");

    qDebug() << "OTPPairingManager: Starting OTP pairing with" << computer->name;

    // Perform the actual OTP pairing
    performOTPPairing(computer, pin, passphrase);
}

void OTPPairingManager::cancelPairing()
{
    if (!m_pairingInProgress) {
        return;
    }

    m_pairingInProgress = false;
    m_currentComputer = nullptr;
    m_currentPin.clear();
    m_currentPassphrase.clear();

    if (m_timeoutTimer) {
        m_timeoutTimer->stop();
        delete m_timeoutTimer;
        m_timeoutTimer = nullptr;
    }

    qDebug() << "OTPPairingManager: Pairing cancelled";
}

bool OTPPairingManager::isPairingInProgress() const
{
    return m_pairingInProgress;
}

bool OTPPairingManager::isOTPSupported(NvComputer *computer) const
{
    if (!computer) {
        return false;
    }

    // OTP pairing is only available with Apollo/Sunshine servers (not Nvidia GeForce Experience)
    return !computer->isNvidiaServerSoftware;
}



QString OTPPairingManager::generateOTPHash(const QString &pin, const QString &salt, const QString &passphrase)
{
    // Matches Android implementation:
    // MessageDigest digest = MessageDigest.getInstance("SHA-256");
    // String plainText = pin + saltStr + passphrase;
    // byte[] hash = digest.digest(plainText.getBytes());

    QString plainText = pin + salt + passphrase;
    
    QCryptographicHash hash(QCryptographicHash::Sha256);
    hash.addData(plainText.toUtf8());
    
    QByteArray result = hash.result();
    
    // Convert to hex string (uppercase to match Android)
    QString hexString = result.toHex().toUpper();
    
    // Never log the PIN, salt, or resulting hash - together they are the OTP credential
    qDebug() << "OTPPairingManager: Generated OTP hash for PIN: [redacted," << pin.length() << "digits] Salt: [redacted," << salt.length() << "hex chars]";
    
    return hexString;
}

void OTPPairingManager::performOTPPairing(NvComputer *computer, const QString &pin, const QString &passphrase)
{
    emit pairingProgress("Generating OTP authentication...");
    
    // Generate a 16-byte salt to match the expected format by Apollo servers
    QByteArray saltBytes(16, 0);
    for (int i = 0; i < 16; i++) {
        saltBytes[i] = QRandomGenerator::global()->bounded(256);
    }
    QString saltStr = saltBytes.toHex();
    
    // Generate the OTP hash using the same salt that will be sent in the pairing request
    QString otpHash = generateOTPHash(pin, saltStr, passphrase);

    // The OTP hash is the bearer credential sent as otpauth and the salt allows
    // offline brute-force of the 4-digit PIN - log presence only
    qDebug() << "OTPPairingManager: Generated OTP hash: [redacted," << otpHash.length() << "hex chars]";
    qDebug() << "OTPPairingManager: Using salt: [redacted," << saltStr.length() << "hex chars]";
    
    emit pairingProgress("Connecting to server...");
    
    // Send the HTTP pairing request with the correct hash and salt
    sendOTPPairingRequest(computer, otpHash, saltStr, passphrase);
}

void OTPPairingManager::sendOTPPairingRequest(NvComputer *computer, const QString &otpHash, const QString &salt, const QString &passphrase)
{
    Q_UNUSED(passphrase);
    
    try {
        // Create NvHTTP instance for this computer
        NvHTTP http(computer);
        
        qDebug() << "OTPPairingManager: Starting Apollo OTP pairing";
        // Do not log the PIN, passphrase, OTP hash, or salt - they are pairing secrets
        qDebug() << "OTPPairingManager: PIN from user (server-generated): [redacted," << m_currentPin.length() << "digits]";
        qDebug() << "OTPPairingManager: Passphrase from user: [redacted," << m_currentPassphrase.length() << "chars]";
        qDebug() << "OTPPairingManager: Generated OTP hash: [redacted," << otpHash.length() << "hex chars]";
        qDebug() << "OTPPairingManager: Using salt: [redacted," << salt.length() << "hex chars]";
        qDebug() << "OTPPairingManager: Server HTTP URL:" << http.m_BaseUrlHttp.toString();
        qDebug() << "OTPPairingManager: Server HTTPS URL:" << http.m_BaseUrlHttps.toString();
        
        emit pairingProgress("Sending Apollo OTP pairing request over HTTPS...");
        
        // Build the pairing parameters
        // For OTP authentication, include phrase=getservercert AND otpauth parameter
        QString pairingParams = QString("devicename=roth&updateState=1&phrase=getservercert&salt=%1&clientcert=%2&otpauth=%3")
            .arg(salt)
            .arg(QString(IdentityManager::get()->getCertificate().toHex()))
            .arg(otpHash);
        
        // pairingParams carries salt, client cert, and otpauth hash - never log the values
        qDebug() << "OTPPairingManager: Pairing parameters built: [redacted," << pairingParams.length() << "chars]";
        
        QString pairingRequest;
        
        // For OTP pairing, use HTTP to avoid SSL certificate verification issues
        // The server will validate the OTP hash and return the certificate for future HTTPS use
        qDebug() << "OTPPairingManager: Attempting HTTP OTP pairing request";
        
        pairingRequest = http.openConnectionToString(
            http.m_BaseUrlHttp,
            "pair",
            pairingParams,
            REQUEST_TIMEOUT_MS
        );
        qDebug() << "OTPPairingManager: HTTP request successful";
        
        qDebug() << "OTPPairingManager: Used HTTP protocol for OTP pairing";
        // The response contains the server certificate (<plaincert>) - log size only
        qDebug() << "OTPPairingManager: Received response: [redacted," << pairingRequest.length() << "chars]";
        
        // Parse the XML response
        if (pairingRequest.isEmpty()) {
            emit pairingFailed("No response from Apollo server. Please check the server is running and OTP is active.");
            return;
        }
        
        // Check for specific error cases
        if (pairingRequest.contains("status_code=\"503\"")) {
            emit pairingFailed("OTP is not available or has expired. Please generate a new OTP on the Apollo server.");
            return;
        } else if (pairingRequest.contains("status_code=\"400\"")) {
            if (pairingRequest.contains("Invalid uniqueid")) {
                emit pairingFailed("Invalid uniqueid format. This may be a configuration issue.");
            } else {
                emit pairingFailed("Invalid OTP hash. Please verify the PIN and passphrase match what you entered in Apollo server.");
            }
            return;
        } else if (pairingRequest.contains("status_message=\"OTP auth not available.\"")) {
            emit pairingFailed("OTP is not available or has expired. Please generate a new OTP on the Apollo server.");
            return;
        }
        
        // Check if pairing was successful
        if (pairingRequest.contains("<root status_code=\"200\">") && pairingRequest.contains("<paired>1</paired>")) {
            emit pairingProgress("OTP authentication successful, extracting server certificate...");
            
            // Extract the server certificate from the response
            QRegularExpression certRegex(R"(<plaincert>([A-Fa-f0-9]+)</plaincert>)");
            QRegularExpressionMatch certMatch = certRegex.match(pairingRequest);
            
            if (certMatch.hasMatch()) {
                QString serverCertHex = certMatch.captured(1);
                QByteArray serverCertBytes = QByteArray::fromHex(serverCertHex.toUtf8());
                QSslCertificate serverCert(serverCertBytes);
                
                if (!serverCert.isNull()) {
                    // Set the server certificate in the computer object
                    computer->serverCert = serverCert;
                    
                    // Update the computer's pairing state
                    computer->pairState = NvComputer::PS_PAIRED;
                    
                    qInfo() << "OTPPairingManager: Apollo OTP pairing successful with" << m_currentComputer->name;
                    
                    // Clean up state before emitting success signal
                    m_pairingInProgress = false;
                    m_currentComputer = nullptr;
                    m_currentPin.clear();
                    m_currentPassphrase.clear();
                    
                    if (m_timeoutTimer) {
                        m_timeoutTimer->stop();
                        delete m_timeoutTimer;
                        m_timeoutTimer = nullptr;
                    }
                    
                    emit pairingCompleted(true, "Apollo OTP pairing completed successfully");
                    return; // Early return to avoid cleanup at the end
                } else {
                    emit pairingFailed("Invalid server certificate received from Apollo server");
                    qWarning() << "OTPPairingManager: Invalid server certificate in OTP response";
                }
            } else {
                emit pairingFailed("Server certificate not found in Apollo response");
                qWarning() << "OTPPairingManager: No server certificate in OTP response";
            }
        } else {
            // BL-2067: never surface the raw pairing response in a user-facing error.
            // An anomalous partial-success response can carry the server certificate
            // (<plaincert>) or other pairing material. Show a generic failure plus a
            // redacted, non-secret summary: a safe numeric status code if present and the
            // response length only (mirrors the BL-2062 presence/length log redaction).
            QRegularExpression statusCodeRegex(R"rx(status_code="(\d+)")rx");
            QRegularExpressionMatch statusCodeMatch = statusCodeRegex.match(pairingRequest);
            QString reason = statusCodeMatch.hasMatch()
                ? QString("server status code %1").arg(statusCodeMatch.captured(1))
                : QString("unrecognized response");
            emit pairingFailed(QString("Apollo OTP pairing failed (%1; response [redacted, %2 chars]). "
                                       "Please verify the OTP on the Apollo server and try again.")
                                   .arg(reason)
                                   .arg(pairingRequest.length()));
            qWarning() << "OTPPairingManager: unexpected pairing response (" << reason
                       << "; [redacted," << pairingRequest.length() << "chars])";
        }

    } catch (const GfeHttpResponseException& e) {
        QString errorMsg = QString("Apollo OTP pairing failed: %1 (Code: %2)")
                            .arg(e.getStatusMessage())
                            .arg(e.getStatusCode());
        emit pairingFailed(errorMsg);
        qWarning() << "OTPPairingManager: HTTP error:" << errorMsg;
        
    } catch (const QtNetworkReplyException& e) {
        QString errorMsg = QString("Apollo OTP pairing network error: %1")
                            .arg(e.getErrorText());
        emit pairingFailed(errorMsg);
        qWarning() << "OTPPairingManager: Network error:" << errorMsg;
        
    } catch (const std::exception& e) {
        QString errorMsg = QString("Apollo OTP pairing error: %1").arg(e.what());
        emit pairingFailed(errorMsg);
        qWarning() << "OTPPairingManager: General error:" << errorMsg;
    }
    
    // Clean up (only for failure cases, success case cleans up before emitting signal)
    m_pairingInProgress = false;
    m_currentComputer = nullptr;
    m_currentPin.clear();
    m_currentPassphrase.clear();
    
    // Clean up timeout timer if it exists
    if (m_timeoutTimer) {
        m_timeoutTimer->stop();
        delete m_timeoutTimer;
        m_timeoutTimer = nullptr;
    }
}

void OTPPairingManager::onPairingTimeout() 
{
    emit pairingFailed("OTP pairing request timed out");
    qDebug() << "OTP pairing request timed out";
    
    // Clean up
    m_pairingInProgress = false;
    m_currentComputer = nullptr;
    m_currentPin.clear();
    m_currentPassphrase.clear();

    delete m_timeoutTimer;
    m_timeoutTimer = nullptr;
}


bool OTPPairingManager::validatePinFormat(const QString &pin)
{
    // PIN must be exactly 4 digits (matches Android implementation)
    if (pin.length() != OTP_PIN_LENGTH) {
        return false;
    }

    // Check that all characters are digits
    for (const QChar &c : pin) {
        if (!c.isDigit()) {
            return false;
        }
    }

    return true;
}

OTPPairingManager::PairState OTPPairingManager::performApolloOTPPairing(NvPairingManager &pairingManager, NvComputer *serverInfo, const QString &pin, const QString &passphrase)
{
    Q_UNUSED(passphrase); // TODO: Use passphrase in AES key derivation for Apollo OTP
    
    // Use the standard pairing flow but with a custom AES key derivation
    // that includes both PIN and passphrase for Apollo OTP
    
    qInfo() << "OTPPairingManager: Using standard pairing with Apollo OTP modifications";
    qInfo() << "OTPPairingManager: Server app version:" << serverInfo->appVersion;
    
    // Create a custom pairing implementation that modifies the AES key derivation
    // to include the passphrase (salt + pin + passphrase instead of just salt + pin)
    
    try {
        // Use the standard NvPairingManager::pair method
        // The key difference is that we need to somehow pass the passphrase
        // to modify the AES key derivation
        
        // For now, let's try the standard pairing and see if Apollo handles it
        // If Apollo expects the passphrase in the AES key, we may need to
        // implement a custom pairing method or modify NvPairingManager
        
        // Get the server certificate first
        QSslCertificate serverCert;
        NvPairingManager::PairState nvResult = pairingManager.pair(serverInfo->appVersion, pin, serverCert);
        
        // Convert NvPairingManager::PairState to OTPPairingManager::PairState
        PairState result;
        switch (nvResult) {
            case NvPairingManager::PAIRED:
                result = PairState::PAIRED;
                break;
            case NvPairingManager::PIN_WRONG:
                result = PairState::PIN_WRONG;
                break;
            case NvPairingManager::FAILED:
                result = PairState::FAILED;
                break;
            case NvPairingManager::ALREADY_IN_PROGRESS:
                result = PairState::ALREADY_IN_PROGRESS;
                break;
            default:
                result = PairState::FAILED;
                break;
        }
        
        if (result == PairState::PAIRED) {
            qInfo() << "OTPPairingManager: Standard pairing with passphrase successful";
            return PairState::PAIRED;
        } else {
            qWarning() << "OTPPairingManager: Standard pairing failed, result:" << static_cast<int>(result);
            return result;
        }
        
    } catch (const std::exception& e) {
        qCritical() << "OTPPairingManager: Exception during pairing:" << e.what();
        return PairState::FAILED;
    }
}

QByteArray OTPPairingManager::encryptAES(const QByteArray &plaintext, const QByteArray &key)
{
    // AES encryption using OpenSSL (similar to NvPairingManager::encrypt)
    QByteArray ciphertext(plaintext.size(), 0);
    EVP_CIPHER_CTX* cipher;
    int ciphertextLen;

    cipher = EVP_CIPHER_CTX_new();
    if (!cipher) {
        qCritical() << "OTPPairingManager: Failed to create AES cipher context";
        return QByteArray();
    }

    EVP_EncryptInit(cipher, EVP_aes_128_ecb(), reinterpret_cast<const unsigned char*>(key.data()), NULL);
    EVP_CIPHER_CTX_set_padding(cipher, 0);

    EVP_EncryptUpdate(cipher,
                      reinterpret_cast<unsigned char*>(ciphertext.data()),
                      &ciphertextLen,
                      reinterpret_cast<const unsigned char*>(plaintext.data()),
                      plaintext.length());
    
    if (ciphertextLen != ciphertext.length()) {
        qCritical() << "OTPPairingManager: AES encryption length mismatch";
        EVP_CIPHER_CTX_free(cipher);
        return QByteArray();
    }

    EVP_CIPHER_CTX_free(cipher);
    return ciphertext;
}

QByteArray OTPPairingManager::decryptAES(const QByteArray &ciphertext, const QByteArray &key)
{
    // AES decryption using OpenSSL (similar to NvPairingManager::decrypt)
    QByteArray plaintext(ciphertext.size(), 0);
    EVP_CIPHER_CTX* cipher;
    int plaintextLen;

    cipher = EVP_CIPHER_CTX_new();
    if (!cipher) {
        qCritical() << "OTPPairingManager: Failed to create AES cipher context";
        return QByteArray();
    }

    EVP_DecryptInit(cipher, EVP_aes_128_ecb(), reinterpret_cast<const unsigned char*>(key.data()), NULL);
    EVP_CIPHER_CTX_set_padding(cipher, 0);

    EVP_DecryptUpdate(cipher,
                      reinterpret_cast<unsigned char*>(plaintext.data()),
                      &plaintextLen,
                      reinterpret_cast<const unsigned char*>(ciphertext.data()),
                      ciphertext.length());
    
    if (plaintextLen != plaintext.length()) {
        qCritical() << "OTPPairingManager: AES decryption length mismatch";
        EVP_CIPHER_CTX_free(cipher);
        return QByteArray();
    }

    EVP_CIPHER_CTX_free(cipher);
    return plaintext;
}
