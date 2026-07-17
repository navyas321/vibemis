#include "backend/otppairingmanager.h"
#include "backend/nvcomputer.h"
#include "backend/nvhttp.h"
#include "backend/nvaddress.h"
#include <QCoreApplication>
#include <QTimer>
#include <QDebug>
#include <QCommandLineParser>
#include <QCommandLineOption>

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    
    // Set up command line parser
    QCommandLineParser parser;
    parser.setApplicationDescription("Test OTP Pairing with Apollo Server");
    parser.addHelpOption();
    parser.addVersionOption();
    
    QCommandLineOption serverOption(QStringList() << "s" << "server",
                                   "Apollo server IP address", "server");
    parser.addOption(serverOption);
    
    QCommandLineOption pinOption(QStringList() << "p" << "pin",
                                "4-digit PIN code", "pin");
    parser.addOption(pinOption);
    
    QCommandLineOption passphraseOption(QStringList() << "passphrase",
                                       "Passphrase for OTP pairing", "passphrase");
    parser.addOption(passphraseOption);
    
    parser.process(app);
    
    QString serverAddress = parser.value(serverOption);
    QString pin = parser.value(pinOption);
    QString passphrase = parser.value(passphraseOption);
    
    // Validate inputs
    if (serverAddress.isEmpty()) {
        qWarning() << "Server address is required. Use --server <IP>";
        return 1;
    }
    
    if (pin.isEmpty()) {
        qWarning() << "PIN is required. Use --pin <4-digit PIN>";
        return 1;
    }
    
    if (pin.length() != 4) {
        qWarning() << "PIN must be exactly 4 digits";
        return 1;
    }
    
    if (passphrase.isEmpty()) {
        passphrase = "default"; // Use default passphrase if not provided
    }
    
    qInfo() << "Starting OTP pairing test with Apollo server...";
    qInfo() << "Server:" << serverAddress;
    // Do not echo the PIN or passphrase - they are pairing secrets
    qInfo() << "PIN: [redacted," << pin.length() << "digits]";
    qInfo() << "Passphrase: [redacted," << passphrase.length() << "chars]";
    
    // Create OTP pairing manager
    OTPPairingManager otpManager;
    
    // Connect to signals
    QObject::connect(&otpManager, &OTPPairingManager::pairingStarted, []() {
        qInfo() << "✓ OTP pairing started";
    });
    
    QObject::connect(&otpManager, &OTPPairingManager::pairingProgress, [](const QString &status) {
        qInfo() << "⏳ OTP pairing progress:" << status;
    });
    
    QObject::connect(&otpManager, &OTPPairingManager::pairingCompleted, [](bool success, const QString &message) {
        if (success) {
            qInfo() << "✅ OTP pairing completed successfully:" << message;
        } else {
            qWarning() << "❌ OTP pairing failed:" << message;
        }
        QCoreApplication::quit();
    });
    
    QObject::connect(&otpManager, &OTPPairingManager::pairingFailed, [](const QString &error) {
        qWarning() << "❌ OTP pairing failed:" << error;
        QCoreApplication::quit();
    });
    
    // Create a mock computer object for the Apollo server
    NvComputer *apolloComputer = new NvComputer();
    apolloComputer->name = "Apollo Server";
    apolloComputer->activeAddress = NvAddress(serverAddress, 47989); // Default Apollo port
    apolloComputer->activeHttpsPort = 47984; // Default Apollo HTTPS port
    apolloComputer->isNvidiaServerSoftware = false; // Apollo is not Nvidia software
    apolloComputer->state = NvComputer::CS_ONLINE;
    apolloComputer->pairState = NvComputer::PS_NOT_PAIRED;
    
    // Test OTP support detection
    if (!otpManager.isOTPSupported(apolloComputer)) {
        qWarning() << "❌ Server does not support OTP pairing";
        return 1;
    }
    
    qInfo() << "✓ Server supports OTP pairing";
    
    // Start the OTP pairing process
    QTimer::singleShot(100, [&otpManager, apolloComputer, pin, passphrase]() {
        qInfo() << "Starting OTP pairing process...";
        otpManager.startOTPPairing(apolloComputer, pin, passphrase);
    });
    
    // Set up timeout
    QTimer::singleShot(30000, []() {
        qWarning() << "❌ Test timed out after 30 seconds";
        QCoreApplication::quit();
    });
    
    int result = app.exec();
    
    // Clean up
    delete apolloComputer;
    
    return result;
}
