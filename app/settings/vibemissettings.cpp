#include "vibemissettings.h"
#include <QStandardPaths>
#include <QDir>
#include <QDebug>

VibemisSettings* VibemisSettings::s_instance = nullptr;

VibemisSettings::VibemisSettings(QObject *parent)
    : QObject(parent)
    , m_settings(nullptr)
{
    // Create settings directory if it doesn't exist
    QString configPath = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    QDir configDir(configPath);
    if (!configDir.exists()) {
        configDir.mkpath(".");
    }

    // Initialize settings
    QString settingsPath = configPath + "/vibemis-settings.ini";
    m_settings = new QSettings(settingsPath, QSettings::IniFormat, this);

    // Load defaults first, then load saved settings
    loadDefaults();
    load();

    qDebug() << "VibemisSettings: Initialized with config at" << settingsPath;
}

VibemisSettings* VibemisSettings::instance()
{
    if (!s_instance) {
        s_instance = new VibemisSettings();
    }
    return s_instance;
}

VibemisSettings* VibemisSettings::create(QQmlEngine *qmlEngine, QJSEngine *jsEngine)
{
    Q_UNUSED(qmlEngine)
    Q_UNUSED(jsEngine)
    return instance();
}

void VibemisSettings::save()
{
    if (!m_settings) {
        return;
    }

    qDebug() << "VibemisSettings: Saving settings";

    // Clipboard sync settings
    m_settings->beginGroup("ClipboardSync");
    m_settings->setValue("enabled", m_clipboardSyncEnabled);
    m_settings->setValue("bidirectional", m_clipboardSyncBidirectional);
    m_settings->setValue("maxSize", m_clipboardSyncMaxSize);
    m_settings->endGroup();

    // Server commands settings
    m_settings->beginGroup("ServerCommands");
    m_settings->setValue("enabled", m_serverCommandsEnabled);
    m_settings->setValue("showAdvanced", m_showAdvancedCommands);
    m_settings->endGroup();

    // OTP pairing settings
    m_settings->beginGroup("OTPPairing");
    m_settings->setValue("enabled", m_otpPairingEnabled);
    m_settings->setValue("timeout", m_otpPairingTimeout);
    m_settings->endGroup();

    // Client-side display settings
    m_settings->beginGroup("ClientDisplay");
    m_settings->setValue("fractionalRefreshRateEnabled", m_fractionalRefreshRateEnabled);
    m_settings->setValue("customRefreshRate", m_customRefreshRate);
    m_settings->setValue("resolutionScalingEnabled", m_resolutionScalingEnabled);
    m_settings->setValue("resolutionScaleFactor", m_resolutionScaleFactor);
    m_settings->setValue("virtualDisplayEnabled", m_virtualDisplayEnabled);
    m_settings->endGroup();

    // App ordering settings
    m_settings->beginGroup("AppOrdering");
    m_settings->setValue("customOrderingEnabled", m_customAppOrderingEnabled);
    m_settings->setValue("orderingMode", m_appOrderingMode);
    m_settings->endGroup();

    // Permission viewing settings
    m_settings->beginGroup("Permissions");
    m_settings->setValue("showServerPermissions", m_showServerPermissions);
    m_settings->endGroup();

    // Input-only mode settings
    m_settings->beginGroup("InputOnly");
    m_settings->setValue("enabled", m_inputOnlyModeEnabled);
    m_settings->endGroup();

    m_settings->sync();
}

void VibemisSettings::load()
{
    if (!m_settings) {
        return;
    }

    qDebug() << "VibemisSettings: Loading settings";

    // Clipboard sync settings
    m_settings->beginGroup("ClipboardSync");
    m_clipboardSyncEnabled = m_settings->value("enabled", false).toBool();
    m_clipboardSyncBidirectional = m_settings->value("bidirectional", true).toBool();
    m_clipboardSyncMaxSize = m_settings->value("maxSize", 1048576).toInt(); // 1MB default
    m_settings->endGroup();

    // Server commands settings
    m_settings->beginGroup("ServerCommands");
    m_serverCommandsEnabled = m_settings->value("enabled", false).toBool();
    m_showAdvancedCommands = m_settings->value("showAdvanced", false).toBool();
    m_settings->endGroup();

    // OTP pairing settings
    m_settings->beginGroup("OTPPairing");
    m_otpPairingEnabled = m_settings->value("enabled", false).toBool();
    m_otpPairingTimeout = m_settings->value("timeout", 120).toInt(); // 2 minutes default
    m_settings->endGroup();

    // Client-side display settings
    m_settings->beginGroup("ClientDisplay");
    m_fractionalRefreshRateEnabled = m_settings->value("fractionalRefreshRateEnabled", false).toBool();
    m_customRefreshRate = m_settings->value("customRefreshRate", 60.0).toDouble();
    m_resolutionScalingEnabled = m_settings->value("resolutionScalingEnabled", false).toBool();
    m_resolutionScaleFactor = m_settings->value("resolutionScaleFactor", 1.0).toDouble();
    m_virtualDisplayEnabled = m_settings->value("virtualDisplayEnabled", false).toBool();
    m_settings->endGroup();

    // App ordering settings
    m_settings->beginGroup("AppOrdering");
    m_customAppOrderingEnabled = m_settings->value("customOrderingEnabled", false).toBool();
    m_appOrderingMode = m_settings->value("orderingMode", "alphabetical").toString();
    m_settings->endGroup();

    // Permission viewing settings
    m_settings->beginGroup("Permissions");
    m_showServerPermissions = m_settings->value("showServerPermissions", true).toBool(); // Temporarily enabled for testing
    m_settings->endGroup();

    // Input-only mode settings
    m_settings->beginGroup("InputOnly");
    m_inputOnlyModeEnabled = m_settings->value("enabled", false).toBool();
    m_settings->endGroup();
}

void VibemisSettings::resetToDefaults()
{
    qDebug() << "VibemisSettings: Resetting to defaults";
    
    loadDefaults();
    save();
    
    // Emit all change signals
    emit clipboardSyncEnabledChanged();
    emit clipboardSyncBidirectionalChanged();
    emit clipboardSyncMaxSizeChanged();
    emit serverCommandsEnabledChanged();
    emit showAdvancedCommandsChanged();
    emit otpPairingEnabledChanged();
    emit otpPairingTimeoutChanged();
    emit fractionalRefreshRateEnabledChanged();
    emit customRefreshRateChanged();
    emit resolutionScalingEnabledChanged();
    emit resolutionScaleFactorChanged();
    emit virtualDisplayEnabledChanged();
    emit customAppOrderingEnabledChanged();
    emit appOrderingModeChanged();
    emit showServerPermissionsChanged();
    emit inputOnlyModeEnabledChanged();
}

void VibemisSettings::loadDefaults()
{
    // Clipboard sync defaults
    m_clipboardSyncEnabled = false;
    m_clipboardSyncBidirectional = true;
    m_clipboardSyncMaxSize = 1048576; // 1MB

    // Server commands defaults
    m_serverCommandsEnabled = false;
    m_showAdvancedCommands = false;

    // OTP pairing defaults
    m_otpPairingEnabled = false;
    m_otpPairingTimeout = 120; // 2 minutes

    // Client-side display defaults
    m_fractionalRefreshRateEnabled = false;
    m_customRefreshRate = 60.0;
    m_resolutionScalingEnabled = false;
    m_resolutionScaleFactor = 1.0;
    m_virtualDisplayEnabled = false;

    // App ordering defaults
    m_customAppOrderingEnabled = false;
    m_appOrderingMode = "alphabetical";

    // Permission viewing defaults
    m_showServerPermissions = false;

    // Input-only mode defaults
    m_inputOnlyModeEnabled = false;
}

// Clipboard sync setters
void VibemisSettings::setClipboardSyncEnabled(bool enabled)
{
    if (m_clipboardSyncEnabled != enabled) {
        m_clipboardSyncEnabled = enabled;
        emit clipboardSyncEnabledChanged();
    }
}

void VibemisSettings::setClipboardSyncBidirectional(bool bidirectional)
{
    if (m_clipboardSyncBidirectional != bidirectional) {
        m_clipboardSyncBidirectional = bidirectional;
        emit clipboardSyncBidirectionalChanged();
    }
}

void VibemisSettings::setClipboardSyncMaxSize(int maxSize)
{
    if (m_clipboardSyncMaxSize != maxSize) {
        m_clipboardSyncMaxSize = maxSize;
        emit clipboardSyncMaxSizeChanged();
    }
}

// Server commands setters
void VibemisSettings::setServerCommandsEnabled(bool enabled)
{
    if (m_serverCommandsEnabled != enabled) {
        m_serverCommandsEnabled = enabled;
        emit serverCommandsEnabledChanged();
    }
}

void VibemisSettings::setShowAdvancedCommands(bool show)
{
    if (m_showAdvancedCommands != show) {
        m_showAdvancedCommands = show;
        emit showAdvancedCommandsChanged();
    }
}

// OTP pairing setters
void VibemisSettings::setOtpPairingEnabled(bool enabled)
{
    if (m_otpPairingEnabled != enabled) {
        m_otpPairingEnabled = enabled;
        emit otpPairingEnabledChanged();
    }
}

void VibemisSettings::setOtpPairingTimeout(int timeout)
{
    if (m_otpPairingTimeout != timeout) {
        m_otpPairingTimeout = timeout;
        emit otpPairingTimeoutChanged();
    }
}

// Client-side display setters
void VibemisSettings::setFractionalRefreshRateEnabled(bool enabled)
{
    if (m_fractionalRefreshRateEnabled != enabled) {
        m_fractionalRefreshRateEnabled = enabled;
        emit fractionalRefreshRateEnabledChanged();
    }
}

void VibemisSettings::setCustomRefreshRate(double rate)
{
    if (qAbs(m_customRefreshRate - rate) > 0.01) {
        m_customRefreshRate = rate;
        emit customRefreshRateChanged();
    }
}

void VibemisSettings::setResolutionScalingEnabled(bool enabled)
{
    if (m_resolutionScalingEnabled != enabled) {
        m_resolutionScalingEnabled = enabled;
        emit resolutionScalingEnabledChanged();
    }
}

void VibemisSettings::setResolutionScaleFactor(double factor)
{
    if (qAbs(m_resolutionScaleFactor - factor) > 0.01) {
        m_resolutionScaleFactor = factor;
        emit resolutionScaleFactorChanged();
    }
}

void VibemisSettings::setVirtualDisplayEnabled(bool enabled)
{
    if (m_virtualDisplayEnabled != enabled) {
        m_virtualDisplayEnabled = enabled;
        emit virtualDisplayEnabledChanged();
    }
}

// App ordering setters
void VibemisSettings::setCustomAppOrderingEnabled(bool enabled)
{
    if (m_customAppOrderingEnabled != enabled) {
        m_customAppOrderingEnabled = enabled;
        emit customAppOrderingEnabledChanged();
    }
}

void VibemisSettings::setAppOrderingMode(const QString &mode)
{
    if (m_appOrderingMode != mode) {
        m_appOrderingMode = mode;
        emit appOrderingModeChanged();
    }
}

// Permission viewing setters
void VibemisSettings::setShowServerPermissions(bool show)
{
    if (m_showServerPermissions != show) {
        m_showServerPermissions = show;
        emit showServerPermissionsChanged();
    }
}

// Input-only mode setters
void VibemisSettings::setInputOnlyModeEnabled(bool enabled)
{
    if (m_inputOnlyModeEnabled != enabled) {
        m_inputOnlyModeEnabled = enabled;
        emit inputOnlyModeEnabledChanged();
    }
}