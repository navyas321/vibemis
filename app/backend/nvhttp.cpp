#include "nvcomputer.h"
#include "nvhttp.h"
#include "nvcomputer.h"
#include "identitymanager.h"
#include "settings/streamingpreferences.h"
#include <Limelight.h>

#include <QDebug>
#include <QUuid>
#include <QtNetwork/QNetworkReply>
#include <QEventLoop>
#include <QTimer>
#include <QXmlStreamReader>
#include <QSslKey>
#include <QImageReader>
#include <QtEndian>
#include <QNetworkProxy>
#include <QSysInfo>
#include <QRandomGenerator>

#define FAST_FAIL_TIMEOUT_MS 2000
#define REQUEST_TIMEOUT_MS 5000
#define LAUNCH_TIMEOUT_MS 120000
#define RESUME_TIMEOUT_MS 30000
#define QUIT_TIMEOUT_MS 30000

#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
#define XML_NAME_EQUALS(x, y) ((x) == (y))
#else
#define XML_NAME_EQUALS(x, y) ((x) == (u##y))
#endif

NvHTTP::NvHTTP(NvAddress address, uint16_t httpsPort, QSslCertificate serverCert, QNetworkAccessManager* nam) :
    m_Nam(nam ? nam : new QNetworkAccessManager(this)),
    m_ServerCert(serverCert)
{
    m_BaseUrlHttp.setScheme("http");
    m_BaseUrlHttps.setScheme("https");

    setAddress(address);
    setHttpsPort(httpsPort);

    // Never use a proxy server
    QNetworkProxy noProxy(QNetworkProxy::NoProxy);
    m_Nam->setProxy(noProxy);
}

NvHTTP::NvHTTP(NvComputer* computer, QNetworkAccessManager* nam) :
    NvHTTP(computer->activeAddress, computer->activeHttpsPort, computer->serverCert, nam)
{

}

void NvHTTP::setServerCert(QSslCertificate serverCert)
{
    m_ServerCert = serverCert;
}

void NvHTTP::setAddress(NvAddress address)
{
    Q_ASSERT(!address.isNull());

    m_Address = address;

    m_BaseUrlHttp.setHost(address.address());
    m_BaseUrlHttps.setHost(address.address());

    m_BaseUrlHttp.setPort(address.port());
}

void NvHTTP::setHttpsPort(uint16_t port)
{
    m_BaseUrlHttps.setPort(port);
}

NvAddress NvHTTP::address()
{
    return m_Address;
}

QSslCertificate NvHTTP::serverCert()
{
    return m_ServerCert;
}

uint16_t NvHTTP::httpPort()
{
    return m_BaseUrlHttp.port();
}

uint16_t NvHTTP::httpsPort()
{
    return m_BaseUrlHttps.port();
}

QVector<int>
NvHTTP::parseQuad(QString quad)
{
    QVector<int> ret;

    // Return an empty vector for old GFE versions
    // that were missing GfeVersion.
    if (quad.isEmpty()) {
        return ret;
    }

    QStringList parts = quad.split(".");
    ret.reserve(parts.length());
    for (int i = 0; i < parts.length(); i++)
    {
        ret.append(parts.at(i).toInt());
    }

    return ret;
}

int
NvHTTP::getCurrentGame(QString serverInfo)
{
    // GFE 2.8 started keeping currentgame set to the last game played. As a result, it no longer
    // has the semantics that its name would indicate. To contain the effects of this change as much
    // as possible, we'll force the current game to zero if the server isn't in a streaming session.
    QString serverState = getXmlString(serverInfo, "state");
    if (serverState.endsWith("_SERVER_BUSY"))
    {
        return getXmlString(serverInfo, "currentgame").toInt();
    }
    else
    {
        return 0;
    }
}

QString
NvHTTP::getServerInfo(NvLogLevel logLevel, bool fastFail)
{
    QString serverInfo;
    
    // Add devicename parameter to match Android client behavior
    QString deviceName = QSysInfo::machineHostName();
    if (deviceName.isEmpty()) {
        deviceName = "Vibemis";
    }
    QString deviceNameParam = "devicename=" + deviceName;

    // Check if we have a pinned cert and HTTPS port for this host yet
    if (!m_ServerCert.isNull() && httpsPort() != 0)
    {
        // If we have a server cert, we must use HTTPS.
        serverInfo = openConnectionToString(m_BaseUrlHttps,
                                            "serverinfo",
                                            deviceNameParam,
                                            fastFail ? FAST_FAIL_TIMEOUT_MS : REQUEST_TIMEOUT_MS,
                                            logLevel);
        // Only log response if not suppressing output (polling requests use NVLL_NONE)
        if (logLevel != NvLogLevel::NVLL_NONE) {
            qInfo() << "getServerInfo HTTPS response:" << serverInfo;
        }
        verifyResponseStatus(serverInfo);
    }
    else
    {
        // Only use HTTP prior to pairing or fetching HTTPS port
        serverInfo = openConnectionToString(m_BaseUrlHttp,
                                            "serverinfo",
                                            deviceNameParam,
                                            fastFail ? FAST_FAIL_TIMEOUT_MS : REQUEST_TIMEOUT_MS,
                                            logLevel);
        // Only log response if not suppressing output (polling requests use NVLL_NONE)
        if (logLevel != NvLogLevel::NVLL_NONE) {
            qInfo() << "getServerInfo response:" << serverInfo;
        }

        // Populate the HTTPS port
        uint16_t httpsPort = getXmlString(serverInfo, "HttpsPort").toUShort();
        if (httpsPort == 0) {
            httpsPort = DEFAULT_HTTPS_PORT;
        }
        setHttpsPort(httpsPort);

        // If we just needed to determine the HTTPS port, we'll try again over
        // HTTPS now that we have the port number
        if (!m_ServerCert.isNull()) {
            return getServerInfo(logLevel, fastFail);
        }
    }

    return serverInfo;
}

void
NvHTTP::startApp(QString verb,
                bool isGfe,
                int appId,
                QString appUuid,
                PSTREAM_CONFIGURATION streamConfig,
                bool sops,
                bool localAudio,
                int gamepadMask,
                bool persistGameControllersOnDisconnect,
                QString& rtspSessionUrl)
{
    int riKeyId;

    memcpy(&riKeyId, streamConfig->remoteInputAesIv, sizeof(riKeyId));
    riKeyId = qFromBigEndian(riKeyId);

    // Get streaming preferences for Apollo parameters
    StreamingPreferences* prefs = StreamingPreferences::get();
    
    // Build base parameters - prefer UUID when available, fallback to appId
    QString baseParams = "appid="+QString::number(appId)+
                        "&mode="+QString::number(streamConfig->width)+"x"+
                        QString::number(streamConfig->height)+"x";

    // TODO: Future State - replace teh above block with the below.
    // Build base parameters - prefer UUID when available, fallback to appId
    //QString baseParams;

    //if (!appUuid.isEmpty()) {
        // If a UUID is present, use it and omit the appID
    //    baseParams = "appuuid=" + appUuid;
    //    qInfo() << "Launching with UUID:" << appUuid;
    //} else {
        // Otherwise, fall back to using the appID
    //    baseParams = "appid=" + QString::number(appId);
    //    qInfo() << "Launching with App ID:" << appId;
    //}

    //baseParams += "&mode=" + QString::number(streamConfig->width) + "x" +
    //            QString::number(streamConfig->height) + "x";
    
    // Handle fractional refresh rate for Apollo servers
    if (prefs->enableFractionalRefreshRate) {
        // Send fractional rate directly (Apollo will handle the conversion)
        baseParams += QString::number(prefs->customRefreshRate, 'f', 2);
        qInfo() << "Using fractional refresh rate:" << prefs->customRefreshRate << "Hz";
    } else {
        // Using an FPS value over 60 causes SOPS to default to 720p60,
        // so force it to 0 to ensure the correct resolution is set. We
        // used to use 60 here but that locked the frame rate to 60 FPS
        // on GFE 3.20.3. We don't need this hack for Sunshine.
        baseParams += QString::number((streamConfig->fps > 60 && isGfe) ? 0 : streamConfig->fps);
    }

    // TODO: Remove this block in future state
    if (!appUuid.isEmpty()) {
        baseParams += "&appuuid="+appUuid;
        qInfo() << "Launching app with ID:" << appId << "and UUID:" << appUuid;
    } else {
        qInfo() << "Launching app with ID:" << appId << "(no UUID available)";
    }
    
    // Continue with standard parameters
    QString allParams = baseParams +
                    "&additionalStates=1&sops="+QString::number(sops ? 1 : 0)+
                    "&rikey="+QByteArray(streamConfig->remoteInputAesKey, sizeof(streamConfig->remoteInputAesKey)).toHex()+
                    "&rikeyid="+QString::number(riKeyId)+
                    ((streamConfig->supportedVideoFormats & VIDEO_FORMAT_MASK_10BIT) ?
                        "&hdrMode=1&clientHdrCapVersion=0&clientHdrCapSupportedFlagsInUint32=0&clientHdrCapMetaDataId=NV_STATIC_METADATA_TYPE_1&clientHdrCapDisplayData=0x0x0x0x0x0x0x0x0x0x0" :
                        "")+
                    "&localAudioPlayMode="+QString::number(localAudio ? 1 : 0)+
                    "&surroundAudioInfo="+QString::number(SURROUNDAUDIOINFO_FROM_AUDIO_CONFIGURATION(streamConfig->audioConfiguration))+
                    "&remoteControllersBitmap="+QString::number(gamepadMask)+
                    "&gcmap="+QString::number(gamepadMask)+
                    "&gcpersist="+QString::number(persistGameControllersOnDisconnect ? 1 : 0);
    
    // Add Apollo-specific parameters
    if (prefs->useVirtualDisplay) {
        allParams += "&virtualDisplay=1";
        qInfo() << "Requesting virtual display from Apollo server";
    }
    
    if (prefs->enableResolutionScaling && prefs->resolutionScaleFactor != 100) {
        allParams += "&scaleFactor=" + QString::number(prefs->resolutionScaleFactor);
        qInfo() << "Requesting resolution scaling:" << prefs->resolutionScaleFactor << "%";
    }
    
    // Add Limelight parameters
    allParams += LiGetLaunchUrlQueryParameters();

    QString response = openConnectionToString(m_BaseUrlHttps,
                                             verb,
                                             allParams,
                                             LAUNCH_TIMEOUT_MS);

    qInfo() << "Launch response:" << response;

    // Throws if the request failed
    verifyResponseStatus(response);

    rtspSessionUrl = getXmlString(response, "sessionUrl0");
}

void
NvHTTP::quitApp()
{
    QString response =
            openConnectionToString(m_BaseUrlHttps,
                                   "cancel",
                                   nullptr,
                                   QUIT_TIMEOUT_MS);

    qInfo() << "Quit response:" << response;

    // Throws if the request failed
    verifyResponseStatus(response);

    // Newer GFE versions will just return success even if quitting fails
    // if we're not the original requester.
    if (getCurrentGame(getServerInfo(NvHTTP::NVLL_ERROR)) != 0) {
        // Generate a synthetic GfeResponseException letting the caller know
        // that they can't kill someone else's stream.
        throw GfeHttpResponseException(599, "");
    }
}

QVector<NvDisplayMode>
NvHTTP::getDisplayModeList(QString serverInfo)
{
    QXmlStreamReader xmlReader(serverInfo);
    QVector<NvDisplayMode> modes;

    while (!xmlReader.atEnd()) {
        while (xmlReader.readNextStartElement()) {
            auto name = xmlReader.name();
            if (XML_NAME_EQUALS(name, "DisplayMode")) {
                modes.append(NvDisplayMode());
            }
            else if (!modes.isEmpty()) {
                if (XML_NAME_EQUALS(name, "Width")) {
                    modes.last().width = xmlReader.readElementText().toInt();
                }
                else if (XML_NAME_EQUALS(name, "Height")) {
                    modes.last().height = xmlReader.readElementText().toInt();
                }
                else if (XML_NAME_EQUALS(name, "RefreshRate")) {
                    modes.last().refreshRate = xmlReader.readElementText().toInt();
                }
            }
        }
    }

    return modes;
}

QVector<NvApp>
NvHTTP::getAppList()
{
    QString appxml = openConnectionToString(m_BaseUrlHttps,
                                            "applist",
                                            nullptr,
                                            REQUEST_TIMEOUT_MS,
                                            NvLogLevel::NVLL_ERROR);
    verifyResponseStatus(appxml);

    QXmlStreamReader xmlReader(appxml);
    QVector<NvApp> apps;
    while (!xmlReader.atEnd()) {
        while (xmlReader.readNextStartElement()) {
            auto name = xmlReader.name();
            if (XML_NAME_EQUALS(name, "App")) {
                // We must have a valid app before advancing to the next one
                if (!apps.isEmpty() && !apps.last().isInitialized()) {
                    qWarning() << "Invalid applist XML";
                    throw std::runtime_error("Invalid applist XML");
                }
                apps.append(NvApp());
            }
            // Vibemis: hand-merged — upstream added the `!apps.isEmpty()` safety
            // wrapper and the XML_NAME_EQUALS macro style; wjbeckett added the
            // UUID branch for Apollo's UUID-based app launching. Keeping both.
            else if (!apps.isEmpty()) {
                if (XML_NAME_EQUALS(name, "AppTitle")) {
                    apps.last().name = xmlReader.readElementText();
                }
                else if (XML_NAME_EQUALS(name, "ID")) {
                    apps.last().id = xmlReader.readElementText().toInt();
                }
                else if (XML_NAME_EQUALS(name, "UUID")) {
                    apps.last().uuid = xmlReader.readElementText();
                }
                else if (XML_NAME_EQUALS(name, "IsHdrSupported")) {
                    apps.last().hdrSupported = xmlReader.readElementText() == "1";
                }
                else if (XML_NAME_EQUALS(name, "IsAppCollectorGame")) {
                    apps.last().isAppCollectorGame = xmlReader.readElementText() == "1";
                }
            }
        }
    }

    return apps;
}

void
NvHTTP::verifyResponseStatus(QString xml)
{
    QXmlStreamReader xmlReader(xml);

    while (xmlReader.readNextStartElement())
    {
        if (XML_NAME_EQUALS(xmlReader.name(), "root"))
        {
            // Status code can be 0xFFFFFFFF in some rare cases on GFE 3.20.3, and
            // QString::toInt() will fail in that case, so use QString::toUInt()
            // and cast the result to an int instead.
            int statusCode = (int)xmlReader.attributes().value("status_code").toUInt();
            if (statusCode == 200)
            {
                // Successful
                return;
            }
            else
            {
                QString statusMessage = xmlReader.attributes().value("status_message").toString();
                if (statusCode != 401) {
                    // 401 is expected for unpaired PCs when we fetch serverinfo over HTTPS
                    qWarning() << "Request failed:" << statusCode << statusMessage;
                }
                if (statusCode == -1 && statusMessage == "Invalid") {
                    // Special case handling an audio capture error which GFE doesn't
                    // provide any useful status message for.
                    statusCode = 418;
                    statusMessage = tr("Missing audio capture device. Reinstalling GeForce Experience should resolve this error.");
                }
                throw GfeHttpResponseException(statusCode, statusMessage);
            }
        }
    }

    throw GfeHttpResponseException(-1, "Malformed XML (missing root element)");
}

QImage
NvHTTP::getBoxArt(int appId)
{
    QNetworkReply* reply = openConnection(m_BaseUrlHttps,
                                          "appasset",
                                          "appid="+QString::number(appId)+
                                          "&AssetType=2&AssetIdx=0",
                                          REQUEST_TIMEOUT_MS,
                                          NvLogLevel::NVLL_VERBOSE);
    QImage image = QImageReader(reply).read();
    delete reply;

    return image;
}

QByteArray
NvHTTP::getXmlStringFromHex(QString xml,
                            QString tagName)
{
    return QByteArray::fromHex(getXmlString(xml, tagName).toUtf8());
}

QString
NvHTTP::getXmlString(QString xml,
                     QString tagName)
{
    QXmlStreamReader xmlReader(xml);

    while (!xmlReader.atEnd())
    {
        if (xmlReader.readNext() != QXmlStreamReader::StartElement)
        {
            continue;
        }

        if (xmlReader.name() == tagName)
        {
            return xmlReader.readElementText();
        }
    }

    return QString();
}

QStringList
NvHTTP::getXmlArray(QString xml, QString tagName)
{
    QStringList result;
    QXmlStreamReader xmlReader(xml);

    while (!xmlReader.atEnd())
    {
        if (xmlReader.readNext() != QXmlStreamReader::StartElement)
        {
            continue;
        }

        if (xmlReader.name() == tagName)
        {
            result.append(xmlReader.readElementText());
        }
    }

    return result;
}

void NvHTTP::handleSslErrors(QNetworkReply* reply, const QList<QSslError>& errors)
{
    bool ignoreErrors = true;

    if (m_ServerCert.isNull()) {
        // We should never make an HTTPS request without a cert
        Q_ASSERT(!m_ServerCert.isNull());
        return;
    }

    for (const QSslError& error : errors) {
        if (m_ServerCert != error.certificate()) {
            ignoreErrors = false;
            break;
        }
    }

    if (ignoreErrors) {
        reply->ignoreSslErrors(errors);
    }
}

QString
NvHTTP::openConnectionToString(QUrl baseUrl,
                               QString command,
                               QString arguments,
                               int timeoutMs,
                               NvLogLevel logLevel)
{
    QNetworkReply* reply = openConnection(baseUrl, command, arguments, timeoutMs, logLevel);
    QString ret;

    QTextStream stream(reply);

#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    stream.setEncoding(QStringConverter::Utf8);
#else
    stream.setCodec("UTF-8");
#endif

    ret = stream.readAll();
    delete reply;

    return ret;
}

QNetworkReply*
NvHTTP::openConnection(QUrl baseUrl,
                       QString command,
                       QString arguments,
                       int timeoutMs,
                       NvLogLevel logLevel)
{
    // Suppress debug output for polling requests to reduce log noise
    bool suppressDebugOutput = (logLevel == NvLogLevel::NVLL_NONE);
    if (!suppressDebugOutput) {
        qDebug() << "NvHTTP::openConnection - URL:" << baseUrl.toString() << "Command:" << command << "Arguments:" << arguments;
    }

    // Port must be set
    Q_ASSERT(baseUrl.port(0) != 0);

    // Build a URL for the request
    QUrl url(baseUrl);
    url.setPath("/" + command);

    // Use the persistent uniqueid from IdentityManager. This ID is generated once
    // and stored in QSettings, so it survives app restarts. Pairing on Vibepollo
    // (and Apollo) is tied to the client cert+uniqueid pair — using a new random
    // uniqueid on every launch causes 403 Forbidden on all HTTPS endpoints after
    // the first session because the server has only authorized the original id.
    url.setQuery("uniqueid=" + IdentityManager::get()->getUniqueId() + "&uuid=" +
                 QUuid::createUuid().toString(QUuid::WithoutBraces) +
                 ((arguments != nullptr) ? ("&" + arguments) : ""));

    QNetworkRequest request(url);

    // Add our client certificate
    request.setSslConfiguration(IdentityManager::get()->getSslConfig());

#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    // Disable HTTP/2 (GFE 3.22 doesn't like it) and Qt 6 enables it by default
    request.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
#endif

#if QT_VERSION >= QT_VERSION_CHECK(6, 3, 0)
    // Use fine-grained idle timeouts to avoid calling QNetworkAccessManager::clearAccessCache(),
    // which tears down the NAM's global thread each time. We must not keep persistent connections
    // or GFE will puke.
    request.setAttribute(QNetworkRequest::ConnectionCacheExpiryTimeoutSecondsAttribute, 0);
#endif

    auto sslErrorsConnection = connect(m_Nam, &QNetworkAccessManager::sslErrors, this, &NvHTTP::handleSslErrors);
    QNetworkReply* reply = m_Nam->get(request);

    // Run the request with a timeout if requested
    QEventLoop loop;
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    connect(QCoreApplication::instance(), &QCoreApplication::aboutToQuit, &loop, &QEventLoop::quit);
    if (timeoutMs) {
        QTimer::singleShot(timeoutMs, &loop, &QEventLoop::quit);
    }
    if (logLevel >= NvLogLevel::NVLL_VERBOSE) {
        qInfo() << "Executing request:" << url.toString();
    }
    loop.exec(QEventLoop::ExcludeUserInputEvents);

    // Abort the request if it timed out
    if (!reply->isFinished())
    {
        if (logLevel >= NvLogLevel::NVLL_ERROR) {
            qWarning() << "Aborting timed out request for" << url.toString();
        }
        reply->abort();
    }

#if QT_VERSION < QT_VERSION_CHECK(6, 3, 0)
    // If we couldn't use fine-grained connection idle timeouts, kill them all now
    m_Nam->clearAccessCache();
#endif
    disconnect(sslErrorsConnection);

    // Handle error
    if (reply->error() != QNetworkReply::NoError)
    {
        if (logLevel >= NvLogLevel::NVLL_ERROR) {
            qWarning() << command << "request failed with error:" << reply->error();
        }

        if (reply->error() == QNetworkReply::SslHandshakeFailedError) {
            // This will trigger falling back to HTTP for the serverinfo query
            // then pairing again to get the updated certificate.
            GfeHttpResponseException exception(401, "Server certificate mismatch");
            delete reply;
            throw exception;
        }
        else if (reply->error() == QNetworkReply::OperationCanceledError) {
            QtNetworkReplyException exception(QNetworkReply::TimeoutError, "Request timed out");
            delete reply;
            throw exception;
        }
        else {
            QtNetworkReplyException exception(reply->error(), reply->errorString());
            delete reply;
            throw exception;
        }
    }

    return reply;
}

// Returns "uniqueid=...&uuid=..." — the auth fragment every Moonlight/Apollo
// HTTPS request must carry. Uses the persistent uniqueid from IdentityManager
// so clipboard and other manually-built requests use the same stable id as
// openConnectionToString (which was fixed to do the same).
QString NvHTTP::getAuthParams()
{
    return "uniqueid=" + IdentityManager::get()->getUniqueId() +
           "&uuid=" + QUuid::createUuid().toString(QUuid::WithoutBraces);
}

// Vibemis clipboard sync methods (Apollo servers only)
QString
NvHTTP::getClipboardContent()
{
    try {
        // openConnectionToString() doesn't expose SSL verify mode, so build the
        // GET request manually with VerifyNone — same reason as sendClipboardContent:
        // the clipboard endpoint connects by IP but the cert is issued to hostname.
        QUrl getUrl(m_BaseUrlHttps);
        getUrl.setPath("/actions/clipboard");
        getUrl.setQuery(getAuthParams() + "&type=text");
        QNetworkRequest getRequest(getUrl);
        QSslConfiguration getSslConfig = IdentityManager::get()->getSslConfig();
        getSslConfig.setPeerVerifyMode(QSslSocket::VerifyNone);
        getRequest.setSslConfiguration(getSslConfig);
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
        getRequest.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
#endif
        QNetworkReply* getReply = m_Nam->get(getRequest);
        QEventLoop getLoop;
        connect(getReply, &QNetworkReply::finished, &getLoop, &QEventLoop::quit);
        connect(QCoreApplication::instance(), &QCoreApplication::aboutToQuit, &getLoop, &QEventLoop::quit);
        QTimer::singleShot(REQUEST_TIMEOUT_MS, &getLoop, &QEventLoop::quit);
        getLoop.exec(QEventLoop::ExcludeUserInputEvents);
        QString response;
        if (!getReply->isFinished()) {
            getReply->abort();
        } else if (getReply->error() == QNetworkReply::NoError) {
            response = QString::fromUtf8(getReply->readAll());
        }
        delete getReply;
        
        if (!response.isEmpty()) {
            qDebug() << "NvHTTP: Retrieved clipboard content from server";
        } else {
            qWarning() << "NvHTTP: Clipboard GET returned empty response";
        }
        return response;
    }
    catch (const std::exception& e) {
        qWarning() << "NvHTTP: Exception getting clipboard content:" << e.what();
        return QString();
    }
}

bool
NvHTTP::sendClipboardContent(const QString& content)
{
    try {
        // Build a URL for the POST request
        QUrl url(m_BaseUrlHttps);
        url.setPath("/actions/clipboard");
        url.setQuery(getAuthParams() + "&type=text");

        QNetworkRequest request(url);
        request.setHeader(QNetworkRequest::ContentTypeHeader, "text/plain; charset=utf-8");

        // Clipboard connects by IP address, but Vibepollo/Apollo's self-signed cert
        // is issued to the hostname (e.g. "Navid-PC"). The IP is not in the cert's
        // SAN, so strict hostname verification always fails with:
        //   "SSL handshake failed: The host name did not match any of the valid hosts"
        // The peer identity is already verified during pairing (we hold the cert in
        // our trust store), so it is safe to skip hostname verification here.
        QSslConfiguration sslConfig = IdentityManager::get()->getSslConfig();
        sslConfig.setPeerVerifyMode(QSslSocket::VerifyNone);
        request.setSslConfiguration(sslConfig);

#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
        request.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
#endif

        QNetworkReply* reply = m_Nam->post(request, content.toUtf8());

        // Wait for response with timeout
        QEventLoop loop;
        connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
        connect(QCoreApplication::instance(), &QCoreApplication::aboutToQuit, &loop, &QEventLoop::quit);
        QTimer::singleShot(REQUEST_TIMEOUT_MS, &loop, &QEventLoop::quit);
        
        qDebug() << "NvHTTP: Sending clipboard content to server:" << url.toString();
        loop.exec(QEventLoop::ExcludeUserInputEvents);

        // Check for timeout
        if (!reply->isFinished()) {
            qWarning() << "NvHTTP: Clipboard send request timed out";
            reply->abort();
            delete reply;
            return false;
        }

        // Check for network errors
        if (reply->error() != QNetworkReply::NoError) {
            qWarning() << "NvHTTP: Failed to send clipboard content:" << reply->errorString();
            delete reply;
            return false;
        }

        // Check HTTP status code
        int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        delete reply;

        if (statusCode == 200) {
            qDebug() << "NvHTTP: Successfully sent clipboard content to server";
            return true;
        } else {
            qWarning() << "NvHTTP: Server returned error status:" << statusCode;
            return false;
        }
    }
    catch (const std::exception& e) {
        qWarning() << "NvHTTP: Exception sending clipboard content:" << e.what();
        return false;
    }
}

// Server command methods are now handled through LiSendExecServerCmd in the moonlight-common-c library
// instead of direct HTTP requests. This provides better compatibility with the Apollo protocol.
