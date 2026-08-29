#if os(macOS)
import FlutterMacOS
#else
import Flutter
#endif
import Foundation
import CFNetwork
import CryptoKit
import Security

/// Flutter entry point shared by the iOS and macOS URLSession adapters.
public final class AlphaXNativePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    private let engine: AlphaXURLSessionEngine

    public init(registrar: FlutterPluginRegistrar) {
#if os(macOS)
        let messenger = registrar.messenger
#else
        let messenger = registrar.messenger()
#endif
        methodChannel = FlutterMethodChannel(
            name: "alphax_native/transport",
            binaryMessenger: messenger
        )
        eventChannel = FlutterEventChannel(
            name: "alphax_native/events",
            binaryMessenger: messenger
        )
        engine = AlphaXURLSessionEngine()
        super.init()
        engine.methodChannel = methodChannel
        registrar.addMethodCallDelegate(self, channel: methodChannel)
        eventChannel.setStreamHandler(self)
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        _ = AlphaXNativePlugin(registrar: registrar)
    }

    deinit {
        engine.detach()
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        engine.handle(call, result: result)
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        engine.setEventSink(events)
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        engine.setEventSink(nil)
        return nil
    }

#if os(iOS)
    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        engine.detach()
    }
#endif
}

/// Explicitly gated counters used by the post-1.0 integration-cost spike.
///
/// This remains private to the native implementation. It is empty/disabled
/// unless a benchmark process invokes the private debug method on the
/// transport channel and does not alter request scheduling.
private final class AlphaXIntegrationCounters {
    private let lock = NSLock()
    private var enabled = false
    private var configuredChunkSize: Int?
    private var configuredMaxCredits: Int?
    private var requests: [String: RequestCounters] = [:]

    func configure(_ value: Bool, chunkSize: Int? = nil, maxCredits: Int? = nil) {
        lock.lock()
        enabled = value
        configuredChunkSize = chunkSize.flatMap { $0 > 0 ? $0 : nil }
        configuredMaxCredits = maxCredits.flatMap { $0 > 0 ? $0 : nil }
        requests.removeAll()
        lock.unlock()
    }

    func chunkSize(_ defaultValue: Int) -> Int {
        lock.lock()
        let value = configuredChunkSize ?? defaultValue
        lock.unlock()
        return value
    }

    func maxCredits(_ defaultValue: Int) -> Int {
        lock.lock()
        let value = configuredMaxCredits ?? defaultValue
        lock.unlock()
        return value
    }

    func register(_ requestId: String, nativeFileMode: String) {
        lock.lock()
        if enabled {
            requests[requestId] = RequestCounters(nativeFileMode: nativeFileMode)
        }
        lock.unlock()
    }

    func credit(_ requestId: String, amount: Int) {
        update(requestId) {
            $0.creditMessageCount += 1
            $0.creditUnits += Int64(max(0, amount))
        }
    }

    func chunk(_ requestId: String, bytes: Int) {
        update(requestId) {
            $0.responseChunkCount += 1
            $0.responseBodyBytes += Int64(max(0, bytes))
        }
    }

    func nativeRead(_ requestId: String, bytes: Int) {
        update(requestId) {
            $0.nativeReadCount += 1
            $0.nativeReadBytes += Int64(max(0, bytes))
        }
    }

    func nativeFileWrite(_ requestId: String, bytes: Int) {
        update(requestId) {
            let count = Int64(max(0, bytes))
            $0.nativeFileWriteCount += 1
            $0.nativeFileWriteBytes += count
            $0.responseBodyBytes += count
        }
    }

    func progress(_ requestId: String) {
        update(requestId) { $0.progressEventCount += 1 }
    }

    func uploadDemand(_ requestId: String) {
        update(requestId) { $0.uploadDemandCount += 1 }
    }

    func observableBuffer(_ requestId: String, bytes: Int) {
        update(requestId) {
            $0.peakObservableBufferBytes = max(
                $0.peakObservableBufferBytes,
                Int64(max(0, bytes))
            )
        }
    }

    func appleDataSplit(_ requestId: String, sourceBytes: Int, copiedBytes: Int) {
        update(requestId) {
            $0.appleDataSplitCount += 1
            $0.appleDataSplitSourceBytes += Int64(max(0, sourceBytes))
            $0.appleDataSplitCopiedBytes += Int64(max(0, copiedBytes))
        }
    }

    func taskSuspend(_ requestId: String) {
        update(requestId) { $0.taskSuspendCount += 1 }
    }

    func taskResume(_ requestId: String) {
        update(requestId) { $0.taskResumeCount += 1 }
    }

    func backpressureState(
        _ requestId: String,
        snapshot: AlphaXURLSessionBackpressure.Snapshot
    ) {
        update(requestId) {
            $0.currentCredits = Int64(snapshot.credits)
            $0.currentPendingChunkCount = Int64(snapshot.pendingChunkCount)
            $0.currentPendingBytes = Int64(snapshot.pendingBytes)
            $0.currentDeferredBytes = Int64(snapshot.deferredBytes)
            $0.currentRetainedBytes = Int64(snapshot.retainedBytes)
            $0.taskSuspended = snapshot.suspended
            $0.completionRequested = snapshot.completionRequested
            $0.peakPendingBytes = max(
                $0.peakPendingBytes,
                Int64(max(0, snapshot.pendingBytes))
            )
            $0.peakRetainedBytes = max(
                $0.peakRetainedBytes,
                Int64(max(0, snapshot.retainedBytes))
            )
            $0.redundantSuspendChecks = Int64(snapshot.redundantSuspendChecks)
        }
    }

    func snapshot() -> [String: Any] {
        lock.lock()
        let result: [String: Any] = [
            "enabled": enabled,
            "platform": "apple",
            "requests": requests.map { requestId, value in
                [
                    "requestId": requestId,
                    "nativeFileMode": value.nativeFileMode,
                    "responseChunkCount": value.responseChunkCount,
                    "responseBodyBytes": value.responseBodyBytes,
                    "nativeReadCount": value.nativeReadCount,
                    "nativeReadBytes": value.nativeReadBytes,
                    "nativeFileWriteCount": value.nativeFileWriteCount,
                    "nativeFileWriteBytes": value.nativeFileWriteBytes,
                    "progressEventCount": value.progressEventCount,
                    "creditMessageCount": value.creditMessageCount,
                    "creditUnits": value.creditUnits,
                    "uploadDemandCount": value.uploadDemandCount,
                    "peakObservableBufferBytes": value.peakObservableBufferBytes,
                    "appleDataSplitCount": value.appleDataSplitCount,
                    "appleDataSplitSourceBytes": value.appleDataSplitSourceBytes,
                    "appleDataSplitCopiedBytes": value.appleDataSplitCopiedBytes,
                    "taskSuspendCount": value.taskSuspendCount,
                    "taskResumeCount": value.taskResumeCount,
                    "currentCredits": value.currentCredits,
                    "currentPendingChunkCount": value.currentPendingChunkCount,
                    "currentPendingBytes": value.currentPendingBytes,
                    "currentDeferredBytes": value.currentDeferredBytes,
                    "currentRetainedBytes": value.currentRetainedBytes,
                    "peakPendingBytes": value.peakPendingBytes,
                    "peakRetainedBytes": value.peakRetainedBytes,
                    "taskSuspended": value.taskSuspended,
                    "completionRequested": value.completionRequested,
                    "redundantSuspendChecks": value.redundantSuspendChecks,
                ]
            },
        ]
        lock.unlock()
        return result
    }

    private func update(_ requestId: String, _ action: (inout RequestCounters) -> Void) {
        lock.lock()
        if enabled, var value = requests[requestId] {
            action(&value)
            requests[requestId] = value
        }
        lock.unlock()
    }

    private struct RequestCounters {
        let nativeFileMode: String
        var responseChunkCount: Int64 = 0
        var responseBodyBytes: Int64 = 0
        var nativeReadCount: Int64 = 0
        var nativeReadBytes: Int64 = 0
        var nativeFileWriteCount: Int64 = 0
        var nativeFileWriteBytes: Int64 = 0
        var progressEventCount: Int64 = 0
        var creditMessageCount: Int64 = 0
        var creditUnits: Int64 = 0
        var uploadDemandCount: Int64 = 0
        var peakObservableBufferBytes: Int64 = 0
        var appleDataSplitCount: Int64 = 0
        var appleDataSplitSourceBytes: Int64 = 0
        var appleDataSplitCopiedBytes: Int64 = 0
        var taskSuspendCount: Int64 = 0
        var taskResumeCount: Int64 = 0
        var currentCredits: Int64 = 0
        var currentPendingChunkCount: Int64 = 0
        var currentPendingBytes: Int64 = 0
        var currentDeferredBytes: Int64 = 0
        var currentRetainedBytes: Int64 = 0
        var peakPendingBytes: Int64 = 0
        var peakRetainedBytes: Int64 = 0
        var taskSuspended = false
        var completionRequested = false
        var redundantSuspendChecks: Int64 = 0
    }
}

private final class AlphaXURLSessionEngine: NSObject, URLSessionDataDelegate, URLSessionDownloadDelegate, URLSessionTaskDelegate {
    weak var methodChannel: FlutterMethodChannel?

    private let stateLock = NSLock()
    private var eventSink: FlutterEventSink?
    private var operations: [Int: AlphaXURLSessionOperation] = [:]
    private var closed = false
    private var closeCompletion: FlutterResult?
    private var sessionCreated = false
    private var session: URLSession?
    private var tlsPolicy: [String: Any] = [:]
    private var proxyPolicy: [String: Any] = [:]
    private let integrationCounters = AlphaXIntegrationCounters()

    private let delegateQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.auvana.ventures.alphax.urlsession.delegate"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()

    func setEventSink(_ sink: FlutterEventSink?) {
        stateLock.lock()
        eventSink = sink
        stateLock.unlock()
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            let arguments = dictionary(call.arguments) ?? [:]
            let requestedTLS = dictionary(arguments["tlsPolicy"]) ?? [:]
            let requestedProxy = dictionary(arguments["proxyPolicy"]) ?? [:]
            if let policyError = policyError(tls: requestedTLS, proxy: requestedProxy) {
                result(policyError)
                return
            }
            stateLock.lock()
            // A Flutter engine may create another logical AlphaX transport
            // after a previous facade has awaited close. Reopen only after
            // URLSession invalidation has completed; an active request is
            // never silently detached from its old session.
            if closed {
                closed = false
                session = nil
                sessionCreated = false
            }
            tlsPolicy = requestedTLS
            proxyPolicy = requestedProxy
            stateLock.unlock()
            result(capabilities())
        case "start":
            guard let arguments = dictionary(call.arguments) else {
                result(FlutterError(code: "request", message: "Apple request arguments are invalid", details: nil))
                return
            }
            start(arguments, result: result)
        case "grantCredits":
            guard let arguments = dictionary(call.arguments),
                  let requestId = arguments["requestId"] as? String,
                  let credits = integer(arguments["credits"]),
                  let operation = operation(forRequestId: requestId) else {
                result(FlutterError(code: "unknown_request", message: "Unknown Apple request", details: nil))
                return
            }
            integrationCounters.credit(requestId, amount: credits)
            operation.grantCredits(credits)
            result(nil)
        case "cancel":
            guard let arguments = dictionary(call.arguments),
                  let requestId = arguments["requestId"] as? String,
                  let operation = operation(forRequestId: requestId) else {
                result(nil)
                return
            }
            operation.cancel(arguments["reason"] as? String ?? "The Apple request was cancelled")
            result(nil)
        case "close":
            close(result: result)
        case "debugEnableInstrumentation":
            let arguments = dictionary(call.arguments) ?? [:]
            integrationCounters.configure(
                arguments["enabled"] as? Bool ?? true,
                chunkSize: integer(arguments["chunkSize"]),
                maxCredits: integer(arguments["maxCredits"])
            )
            result(nil)
        case "debugSnapshot":
            result(integrationCounters.snapshot())
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func start(_ arguments: [String: Any], result: @escaping FlutterResult) {
        stateLock.lock()
        let isClosed = closed
        stateLock.unlock()
        guard !isClosed else {
            result(FlutterError(code: "client_closed", message: "Apple transport is closed", details: nil))
            return
        }
        guard let requestId = arguments["requestId"] as? String else {
            result(FlutterError(code: "request", message: "Apple requestId is missing", details: nil))
            return
        }
        let operation = AlphaXURLSessionOperation(
            requestId: requestId,
            arguments: arguments,
            engine: self,
            integrationCounters: integrationCounters
        )
        operation.start(session: sessionInstance())
        if operation.taskIdentifier >= 0 {
            stateLock.lock()
            operations[operation.taskIdentifier] = operation
            stateLock.unlock()
            operation.resume()
        }
        result(nil)
    }

    private func close(result: @escaping FlutterResult) {
        stateLock.lock()
        if closed {
            stateLock.unlock()
            result(nil)
            return
        }
        closed = true
        let active = Array(operations.values)
        operations.removeAll()
        let activeSession = session
        let shouldAwaitInvalidation = sessionCreated
        if shouldAwaitInvalidation {
            closeCompletion = result
        }
        stateLock.unlock()
        active.forEach { $0.cancel("Apple transport is closed") }
        if shouldAwaitInvalidation {
            activeSession?.invalidateAndCancel()
        } else {
            result(nil)
        }
    }

    func detach() {
        stateLock.lock()
        closed = true
        let active = Array(operations.values)
        operations.removeAll()
        let activeSession = session
        session = nil
        sessionCreated = false
        eventSink = nil
        let completion = closeCompletion
        closeCompletion = nil
        stateLock.unlock()
        active.forEach { $0.cancel("The Apple Flutter engine detached") }
        activeSession?.invalidateAndCancel()
        completion?(nil)
    }

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        stateLock.lock()
        self.session = nil
        sessionCreated = false
        let completion = closeCompletion
        closeCompletion = nil
        stateLock.unlock()
        // Invalidation after invalidateAndCancel commonly reports a native
        // cancellation error. AlphaX close has already requested cancellation;
        // completion means the URLSession callback lifecycle is now quiescent.
        completion?(nil)
    }

    private func sessionInstance() -> URLSession {
        stateLock.lock()
        if let session {
            stateLock.unlock()
            return session
        }
        let configuration = URLSessionConfiguration.default
        applyProxyPolicy(proxyPolicy, to: configuration)
        // The platform configuration owns protocol negotiation. In
        // particular, do not force HTTP/1.1 or add an H3-only fallback here.
        let created = URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: delegateQueue
        )
        session = created
        sessionCreated = true
        stateLock.unlock()
        return created
    }

    func proxyAuthorizationHeader() -> String? {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard (proxyPolicy["mode"] as? String) == "explicit",
              (proxyPolicy["scheme"] as? String) == "http",
              let username = proxyPolicy["username"] as? String,
              let password = proxyPolicy["password"] as? String else {
            return nil
        }
        let credentials = Data("\(username):\(password)".utf8)
        return "Basic \(credentials.base64EncodedString())"
    }

    func remove(_ operation: AlphaXURLSessionOperation) {
        stateLock.lock()
        operations.removeValue(forKey: operation.taskIdentifier)
        stateLock.unlock()
    }

    func emit(_ event: [String: Any]) {
        stateLock.lock()
        let sink = eventSink
        stateLock.unlock()
        sink?(event)
    }

    private func operation(forRequestId requestId: String) -> AlphaXURLSessionOperation? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return operations.values.first { $0.requestId == requestId }
    }

    private func capabilities() -> [String: Any] {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let osVersion = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        let h3: String
#if os(iOS)
        if #available(iOS 15.0, *) {
            h3 = "supported"
        } else {
            h3 = "unsupported"
        }
#else
        if #available(macOS 12.0, *) {
            h3 = "supported"
        } else {
            h3 = "unsupported"
        }
#endif
        return [
            "transportName": "Apple URLSession",
            "transportVersion": "Foundation / OS \(osVersion)",
            "http10": "unsupported",
            "http11": "supported",
            "http2": "supported",
            "http3": h3,
            "streamingUpload": "supported",
            "streamingDownload": "supported",
            "nativeFileUpload": "supported",
            "nativeFileDownload": "supported",
            "uploadProgress": "supported",
            "downloadProgress": "supported",
            "proxyConfiguration": "supported",
            "tlsDefaultTrust": "supported",
            "customTrustAnchors": "supported",
            "certificatePinning": "supported",
            "mutualTls": "unsupported",
            "systemProxy": "supported",
            "directConnectionPolicy": "supported",
            "explicitHttpProxy": "supported",
            "explicitHttpsProxy": "unsupported",
            "proxyAuthentication": "supported",
            "protocolRequirement": "supported",
            "connectionMigration": "unsupported",
            "backgroundTransfer": "unsupported",
            "negotiatedProtocolReporting": "supported",
        ]
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let operation = operation(forTask: dataTask) else {
            completionHandler(.cancel)
            return
        }
        operation.didReceive(response: response)
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        operation(forTask: dataTask)?.didReceive(data: data)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        needNewBodyStream completionHandler: @escaping (InputStream?) -> Void
    ) {
        guard let operation = operation(forTask: task) else {
            completionHandler(nil)
            return
        }
        completionHandler(operation.newBodyStream())
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let operation = operation(forTask: task) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        operation.handle(
            challenge: challenge,
            tlsPolicy: tlsPolicy,
            proxyPolicy: proxyPolicy,
            completionHandler: completionHandler
        )
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let operation = operation(forTask: task) else {
            completionHandler(nil)
            return
        }
        operation.handleRedirect(response: response, newRequest: request, completionHandler: completionHandler)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        operation(forTask: task)?.didSendBodyData(
            totalBytesSent: totalBytesSent,
            totalBytesExpectedToSend: totalBytesExpectedToSend
        )
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        operation(forTask: task)?.didFinishCollecting(metrics: metrics)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        operation(forTask: task)?.didComplete(
            error: error,
            response: task.response as? HTTPURLResponse
        )
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        operation(forTask: downloadTask)?.didWriteDownload(
            totalBytesWritten: totalBytesWritten,
            totalBytesExpectedToWrite: totalBytesExpectedToWrite,
            response: downloadTask.response as? HTTPURLResponse
        )
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        operation(forTask: downloadTask)?.didFinishDownloading(to: location)
    }

    func operation(forTask task: URLSessionTask) -> AlphaXURLSessionOperation? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return operations[task.taskIdentifier]
    }

    private func dictionary(_ value: Any?) -> [String: Any]? {
        guard let value = value as? [AnyHashable: Any] else {
            return value as? [String: Any]
        }
        return value.reduce(into: [String: Any]()) { result, entry in
            if let key = entry.key as? String {
                result[key] = entry.value
            }
        }
    }

    private func integer(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private func policyError(tls: [String: Any], proxy: [String: Any]) -> FlutterError? {
        let clientIdentity = tls["clientIdentityReference"] as? String
        if let clientIdentity, !clientIdentity.isEmpty {
            return FlutterError(
                code: "unsupported_tls_policy",
                message: "URLSession client-identity lookup is not implemented",
                details: ["capability": "mutualTls"]
            )
        }
        let anchors = tls["trustAnchors"] as? [Any] ?? []
        let includePlatformTrust = tls["includePlatformTrust"] as? Bool ?? true
        if !anchors.isEmpty && anchors.contains(where: {
            let anchorData = data($0)
            return anchorData.isEmpty || SecCertificateCreateWithData(nil, anchorData as CFData) == nil
        }) {
            return FlutterError(
                code: "unsupported_tls_policy",
                message: "A URLSession trust anchor is not valid DER data",
                details: ["capability": "customTrustAnchors"]
            )
        }
        if !includePlatformTrust && anchors.isEmpty {
            return FlutterError(
                code: "unsupported_tls_policy",
                message: "URLSession replacement trust requires at least one trust anchor",
                details: ["capability": "customTrustAnchors"]
            )
        }
        if let pins = tls["pins"] as? [Any] {
            for rawPin in pins {
                guard let pin = dictionary(rawPin),
                      let digest = pin["sha256SpkiBase64"] as? String,
                      let digestData = Data(base64Encoded: digest),
                      digestData.count == 32,
                      let expiresAt = integer64(pin["expiresAtMs"]),
                      expiresAt > Int64(Date().timeIntervalSince1970 * 1000) else {
                    return FlutterError(
                        code: "unsupported_tls_policy",
                        message: "A URLSession SPKI pin is invalid or expired",
                        details: ["capability": "certificatePinning"]
                    )
                }
            }
        }
        let mode = proxy["mode"] as? String ?? "system"
        if mode == "explicit", (proxy["scheme"] as? String ?? "http") != "http" {
            return FlutterError(
                code: "unsupported_proxy_policy",
                message: "URLSession explicit HTTPS-proxy configuration is not portable",
                details: ["capability": "explicitHttpsProxy"]
            )
        }
        if mode == "explicit", ((proxy["host"] as? String)?.isEmpty != false || integer(proxy["port"]) == nil) {
            return FlutterError(
                code: "unsupported_proxy_policy",
                message: "URLSession explicit proxy configuration is invalid",
                details: ["capability": "explicitHttpProxy"]
            )
        }
        return nil
    }

    private func applyProxyPolicy(_ policy: [String: Any], to configuration: URLSessionConfiguration) {
        let mode = policy["mode"] as? String ?? "system"
        switch mode {
        case "direct":
            let proxy: [String: Any] = [
                kCFNetworkProxiesHTTPEnable as String: 0,
                // The CFNetwork key names are stable across the iOS and macOS
                // deployment boundary even when an SDK overlay does not expose
                // the HTTPS constants. Direct mode disables both destination
                // proxy paths.
                "HTTPSEnable": 0,
            ]
            configuration.connectionProxyDictionary = proxy
        case "explicit":
            guard let host = policy["host"] as? String, let port = integer(policy["port"]) else { return }
            let proxy: [String: Any] = [
                kCFNetworkProxiesHTTPEnable as String: 1,
                kCFNetworkProxiesHTTPProxy as String: host,
                kCFNetworkProxiesHTTPPort as String: port,
                // An explicit AlphaX HTTP proxy can service HTTPS destinations
                // through CONNECT. This is distinct from an HTTPS proxy
                // endpoint, which remains an unsupported policy scheme.
                "HTTPSEnable": 1,
                "HTTPSProxy": host,
                "HTTPSPort": port,
            ]
            configuration.connectionProxyDictionary = proxy
        default:
            // URLSessionConfiguration.default inherits system proxy behavior.
            break
        }
    }

    private func integer64(_ value: Any?) -> Int64? {
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        if let value = value as? NSNumber { return value.int64Value }
        return nil
    }

    private func data(_ value: Any?) -> Data {
        if let value = value as? FlutterStandardTypedData { return value.data }
        if let value = value as? Data { return value }
        if let value = value as? [UInt8] { return Data(value) }
        if let value = value as? [NSNumber] { return Data(value.map(\.uint8Value)) }
        return Data()
    }
}

private final class AlphaXURLSessionOperation {
    let requestId: String
    private let arguments: [String: Any]
    private weak var engine: AlphaXURLSessionEngine?
    private let integrationCounters: AlphaXIntegrationCounters
    private let stateLock = NSLock()
    private var task: URLSessionTask?
    private var terminal = false
    private var started = false
    private var response: HTTPURLResponse?
    private var redirects: [[String: Any]] = []
    private var metrics: [String: Any] = [:]
    private var completionPending = false
    private let backpressure: AlphaXURLSessionBackpressure
    private var bytesDownloaded: Int64 = 0
    private var bytesUploaded: Int64 = 0
    private var firstByteDate: Date?
    private var responseDate: Date?
    private var outputPath: String?
    private var outputURL: URL?
    private var timeoutItems: [String: DispatchWorkItem] = [:]
    private var uploadBridge: AlphaXUploadBridge?
    private var taskCompleted = false
    private var metricsCollected = false

    private let chunkSize: Int
    private let maxCredits: Int
    private let progressInterest: AlphaXProgressInterest

    init(
        requestId: String,
        arguments: [String: Any],
        engine: AlphaXURLSessionEngine,
        integrationCounters: AlphaXIntegrationCounters
    ) {
        self.requestId = requestId
        self.arguments = arguments
        self.engine = engine
        self.integrationCounters = integrationCounters
        self.chunkSize = integrationCounters.chunkSize(64 * 1024)
        self.maxCredits = integrationCounters.maxCredits(4)
        self.progressInterest = AlphaXProgressInterest(arguments: arguments)
        self.backpressure = AlphaXURLSessionBackpressure(
            chunkSize: self.chunkSize,
            maxCredits: self.maxCredits
        )
    }

    var taskIdentifier: Int {
        stateLock.lock()
        defer { stateLock.unlock() }
        return task?.taskIdentifier ?? -1
    }

    func start(session: URLSession) {
        do {
            var request = try makeRequest()
            let body = dictionary(arguments["body"])
            let kind = body?["kind"] as? String ?? "empty"
            let directPath = arguments["directDownloadPath"] as? String
            integrationCounters.register(
                requestId,
                nativeFileMode: directPath?.isEmpty == false ? "download" :
                    (kind == "file" ? "upload" : "none")
            )
            let created: URLSessionTask
            if let path = directPath, !path.isEmpty {
                outputPath = path
                created = session.downloadTask(with: request)
            } else {
                switch kind {
                case "bytes":
                    // Byte bodies are already materialized by the public
                    // AlphaX body model. A data task keeps the response body
                    // on the URLSessionDataDelegate path; streamed/file
                    // bodies continue to use upload tasks below.
                    let bodyData = data(body?["bytes"])
                    if request.httpMethod?.uppercased() == "OPTIONS" {
                        // The current Foundation runtime can omit an
                        // httpBody attached to an OPTIONS data task. The
                        // upload-task initializer preserves the materialized
                        // request body without changing the public API.
                        created = session.uploadTask(with: request, from: bodyData)
                    } else {
                        request.httpBody = bodyData
                        created = session.dataTask(with: request)
                    }
                case "file":
                    guard let path = body?["path"] as? String else {
                        throw AlphaXNativeError.requestBody("Apple file upload path is missing")
                    }
                    created = session.uploadTask(with: request, fromFile: URL(fileURLWithPath: path))
                case "dart":
                    uploadBridge = AlphaXUploadBridge(
                        requestId: requestId,
                        methodChannel: engine?.methodChannel,
                        onDemand: { [weak self] in
                            guard let self else { return }
                            self.integrationCounters.uploadDemand(self.requestId)
                        }
                    )
                    created = session.uploadTask(withStreamedRequest: request)
                default:
                    created = session.dataTask(with: request)
                }
            }
            stateLock.lock()
            task = created
            stateLock.unlock()
            if let priority = arguments["priority"] as? String {
                created.priority = priority == "high" ? URLSessionTask.highPriority :
                    priority == "low" ? URLSessionTask.lowPriority : URLSessionTask.defaultPriority
            }
            scheduleTimeouts()
        } catch {
            finishError(kind: "request_body", message: error.localizedDescription)
        }
    }

    func resume() {
        stateLock.lock()
        let activeTask = task
        stateLock.unlock()
        activeTask?.resume()
    }

    func grantCredits(_ amount: Int) {
        guard amount > 0 else { return }
        stateLock.lock()
        guard !terminal else {
            stateLock.unlock()
            return
        }
        let output = backpressure.grant(amount)
        stateLock.unlock()
        applyBackpressure(output)
        completeSuccessIfReady()
    }

    func cancel(_ reason: String) {
        stateLock.lock()
        if terminal {
            stateLock.unlock()
            return
        }
        terminal = true
        let cancelledState = backpressure.cancel()
        integrationCounters.backpressureState(requestId, snapshot: cancelledState.snapshot)
        let activeTask = task
        stateLock.unlock()
        cancelTimeouts()
        activeTask?.cancel()
        engine?.emit([
            "type": "error",
            "requestId": requestId,
            "kind": "cancellation",
            "message": reason,
            "timeoutKind": NSNull(),
        ])
        engine?.remove(self)
    }

    func didReceive(response: URLResponse) {
        guard let httpResponse = response as? HTTPURLResponse else {
            finishError(kind: "protocol", message: "Apple URLSession returned a non-HTTP response")
            return
        }
        stateLock.lock()
        self.response = httpResponse
        responseDate = Date()
        stateLock.unlock()
        if httpResponse.statusCode == 407 {
            finishError(
                kind: "proxy_authentication",
                message: "The configured proxy rejected authentication",
                details: ["statusCode": httpResponse.statusCode]
            )
            return
        }
        cancelTimeout("connect")
        cancelTimeout("request")
        if let readMillis = milliseconds(dictionary(arguments["timeouts"])?["readMs"]) {
            scheduleTimeout(kind: "read", milliseconds: readMillis)
        }
        emitStartedIfNeeded()
    }

    func didReceive(data: Data) {
        stateLock.lock()
        if terminal {
            stateLock.unlock()
            return
        }
        bytesDownloaded += Int64(data.count)
        if firstByteDate == nil { firstByteDate = Date() }
        let output = backpressure.receive(data)
        stateLock.unlock()
        resetReadTimeout()
        integrationCounters.nativeRead(requestId, bytes: data.count)
        integrationCounters.observableBuffer(requestId, bytes: data.count)
        if data.count > chunkSize {
            integrationCounters.appleDataSplit(
                requestId,
                sourceBytes: data.count,
                copiedBytes: data.count
            )
        }
        applyBackpressure(output)
        stateLock.lock()
        let shouldEmitProgress = !terminal
        stateLock.unlock()
        if shouldEmitProgress { emitDownloadProgress() }
    }

    func newBodyStream() -> InputStream? {
        guard let uploadBridge else { return nil }
        stateLock.lock()
        let isRedirectReplay = !redirects.isEmpty
        stateLock.unlock()
        if isRedirectReplay, !uploadBridge.reset() {
            finishError(
                kind: "request_body",
                message: "The Dart request body could not be reset for redirect replay"
            )
            return nil
        }
        return AlphaXBodyInputStream(bridge: uploadBridge)
    }

    func handle(
        challenge: URLAuthenticationChallenge,
        tlsPolicy: [String: Any],
        proxyPolicy: [String: Any],
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let protectionSpace = challenge.protectionSpace
        if protectionSpace.isProxy(),
           protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic,
           let username = proxyPolicy["username"] as? String,
           let password = proxyPolicy["password"] as? String {
            completionHandler(
                .useCredential,
                URLCredential(user: username, password: password, persistence: .none)
            )
            return
        }
        guard protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        let host = protectionSpace.host
        switch validateServerTrust(trust, host: host, policy: tlsPolicy) {
        case .success(let credential):
            completionHandler(credential == nil ? .performDefaultHandling : .useCredential, credential)
        case .failure(let kind, let message, let details):
            completionHandler(.cancelAuthenticationChallenge, nil)
            finishError(kind: kind, message: message, details: details)
        }
    }

    func handleRedirect(
        response: HTTPURLResponse,
        newRequest: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        let policy = dictionary(arguments["redirect"])
        let mode = policy?["mode"] as? String ?? "follow"
        let maxRedirects = integer(policy?["maxRedirects"]) ?? 5
        let from = response.url?.absoluteString ?? ""
        let to = newRequest.url?.absoluteString ?? ""
        let method = newRequest.httpMethod
        let info: [String: Any] = [
            "statusCode": response.statusCode,
            "from": from,
            "to": to,
            "method": method as Any,
        ]
        switch mode {
        case "manual":
            completionHandler(nil)
            stateLock.lock()
            self.response = response
            stateLock.unlock()
            emitStartedIfNeeded()
            finishSuccess()
        case "reject":
            completionHandler(nil)
            finishError(kind: "redirect", message: "Redirects are disabled by AlphaX policy")
        default:
            stateLock.lock()
            let count = redirects.count
            let replayable = bodyReplayable()
            if count >= maxRedirects {
                stateLock.unlock()
                completionHandler(nil)
                finishError(kind: "redirect", message: "The redirect limit was exceeded")
                return
            }
            if !replayable {
                stateLock.unlock()
                completionHandler(nil)
                finishError(kind: "redirect", message: "A redirect cannot replay the single-consumption request body")
                return
            }
            redirects.append(info)
            stateLock.unlock()
            completionHandler(sanitizeRedirectRequest(newRequest, from: response.url))
        }
    }

    private func sanitizeRedirectRequest(_ request: URLRequest, from sourceURL: URL?) -> URLRequest {
        guard let sourceURL, let targetURL = request.url, !sameOrigin(sourceURL, targetURL) else {
            return request
        }
        var sanitized = request
        for header in ["Authorization", "Proxy-Authorization", "Cookie"] {
            sanitized.setValue(nil, forHTTPHeaderField: header)
        }
        return sanitized
    }

    private func sameOrigin(_ left: URL, _ right: URL) -> Bool {
        guard left.scheme?.caseInsensitiveCompare(right.scheme ?? "") == .orderedSame,
              left.host?.caseInsensitiveCompare(right.host ?? "") == .orderedSame else {
            return false
        }
        return effectivePort(left) == effectivePort(right)
    }

    private func effectivePort(_ url: URL) -> Int? {
        if let port = url.port { return port }
        switch url.scheme?.lowercased() {
        case "http": return 80
        case "https": return 443
        default: return nil
        }
    }

    func didSendBodyData(totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        stateLock.lock()
        if terminal {
            stateLock.unlock()
            return
        }
        bytesUploaded = totalBytesSent
        let total = totalBytesExpectedToSend > 0 ? totalBytesExpectedToSend : nil
        stateLock.unlock()
        guard progressInterest.isRequested(direction: "upload") else { return }
        integrationCounters.progress(requestId)
        engine?.emit([
            "type": "progress",
            "requestId": requestId,
            "direction": "upload",
            "bytesTransferred": totalBytesSent,
            "totalBytes": total as Any,
            "isComplete": total != nil && totalBytesSent >= total!,
        ])
    }

    func didFinishCollecting(metrics: URLSessionTaskMetrics) {
        stateLock.lock()
        metricsCollected = true
        stateLock.unlock()
        guard let transaction = metrics.transactionMetrics.last else {
            finishSuccessIfMetricsReady()
            return
        }
        // Some Apple OS/network combinations include a trailing transaction
        // record without a protocol name when HTTP/3 is requested. Keep the
        // last transaction for timing and transfer metrics, but select the
        // last non-empty protocol across the task's transaction history. This
        // preserves the final negotiated protocol without converting an
        // actually reported earlier transaction into `unknown`.
        let protocolName = metrics.transactionMetrics.reversed().compactMap {
            $0.networkProtocolName
        }.first
        let protocolValue = normalizedProtocol(protocolName)
        let total = metrics.taskInterval.duration
        let ttfb = AlphaXURLSessionTiming.interval(
            transaction.requestStartDate,
            transaction.responseStartDate
        )
        let transfer = AlphaXURLSessionTiming.interval(
            transaction.responseStartDate,
            transaction.responseEndDate
        )
        stateLock.lock()
        self.metrics = [
            "dnsDurationMs": optionalInt(AlphaXURLSessionTiming.interval(
                transaction.domainLookupStartDate,
                transaction.domainLookupEndDate
            )),
            "connectDurationMs": optionalInt(AlphaXURLSessionTiming.interval(
                transaction.connectStartDate,
                transaction.connectEndDate
            )),
            "tlsDurationMs": optionalInt(AlphaXURLSessionTiming.interval(
                transaction.secureConnectionStartDate,
                transaction.secureConnectionEndDate
            )),
            "timeToFirstByteMs": optionalInt(ttfb),
            "transferDurationMs": optionalInt(transfer),
            "totalDurationMs": optionalInt(AlphaXURLSessionTiming.milliseconds(total)),
            "uploadedBytes": bytesUploaded,
            "downloadedBytes": bytesDownloaded,
            "protocol": protocolValue,
            "rawProtocol": protocolName ?? NSNull(),
            "redirectCount": redirects.count,
            "connectionReused": transaction.isReusedConnection,
        ]
        stateLock.unlock()
        finishSuccessIfMetricsReady()
    }

    func didWriteDownload(
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64,
        response downloadResponse: HTTPURLResponse?
    ) {
        stateLock.lock()
        if terminal {
            stateLock.unlock()
            return
        }
        stateLock.unlock()
        if let downloadResponse {
            stateLock.lock()
            let shouldEmitResponse = self.response == nil
            if shouldEmitResponse {
                self.response = downloadResponse
                responseDate = Date()
            }
            stateLock.unlock()
            if shouldEmitResponse {
                cancelTimeout("connect")
                cancelTimeout("request")
                emitStartedIfNeeded(
                    contentLength: totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : nil
                )
            }
        }
        stateLock.lock()
        let deltaBytes = max(0, totalBytesWritten - bytesDownloaded)
        bytesDownloaded = totalBytesWritten
        if firstByteDate == nil { firstByteDate = Date() }
        stateLock.unlock()
        if deltaBytes > 0 {
            integrationCounters.nativeFileWrite(
                requestId,
                bytes: Int(min(deltaBytes, Int64(Int.max)))
            )
        }
        emitStartedIfNeeded(contentLength: totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : nil)
        resetReadTimeout()
        guard progressInterest.isRequested(direction: "download") else { return }
        integrationCounters.progress(requestId)
        engine?.emit([
            "type": "progress",
            "requestId": requestId,
            "direction": "download",
            "bytesTransferred": totalBytesWritten,
            "totalBytes": totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : NSNull(),
            "isComplete": totalBytesExpectedToWrite > 0 && totalBytesWritten >= totalBytesExpectedToWrite,
        ])
    }

    func didFinishDownloading(to location: URL) {
        guard let path = outputPath else { return }
        do {
            let target = URL(fileURLWithPath: path)
            try AlphaXURLSessionFileFinalizer.finalize(location: location, target: target)
            stateLock.lock()
            outputURL = target
            stateLock.unlock()
        } catch {
            // The URLSession temporary file is provider-owned. Best-effort
            // cleanup is safe here because finalization never succeeded.
            try? FileManager.default.removeItem(at: location)
            finishError(kind: "response_body", message: "The native download file could not be finalized: \(error.localizedDescription)")
        }
    }

    func didComplete(error: Error?, response completedResponse: HTTPURLResponse? = nil) {
        if let completedResponse {
            stateLock.lock()
            let shouldEmitResponse = self.response == nil
            if shouldEmitResponse {
                self.response = completedResponse
                responseDate = Date()
            }
            stateLock.unlock()
            if shouldEmitResponse {
                cancelTimeout("connect")
                cancelTimeout("request")
                emitStartedIfNeeded()
            }
        }
        stateLock.lock()
        let alreadyTerminal = terminal
        taskCompleted = error == nil
        let hasMetrics = metricsCollected
        stateLock.unlock()
        if alreadyTerminal { return }
        if let error = error {
            finishError(kind: classify(error), message: diagnosticMessage(error))
        } else if hasMetrics {
            finishSuccess()
        } else if arguments["protocolRequirement"] as? String != nil {
            // A concrete protocol requirement must never be evaluated from
            // fallback metrics. URLSession normally delivers task metrics
            // immediately after completion, but when that callback is late we
            // must wait for it so `unknown` cannot be mistaken for a failed
            // negotiation or, worse, a successful requirement. The metrics
            // callback calls finishSuccessIfMetricsReady() when it arrives.
            // If metrics never arrive, the bounded fallback fails closed as
            // `unknown` instead of leaving the request pending indefinitely.
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + .seconds(2)) { [weak self] in
                self?.finishSuccessIfMetricsReady(allowMissingMetrics: true)
            }
        } else {
            // URLSession normally delivers task metrics before completion,
            // but keep a bounded fallback for providers that omit metrics.
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + .seconds(2)) { [weak self] in
                self?.finishSuccessIfMetricsReady(allowMissingMetrics: true)
            }
        }
    }

    private func finishSuccessIfMetricsReady(allowMissingMetrics: Bool = false) {
        stateLock.lock()
        let shouldFinish = taskCompleted && (metricsCollected || allowMissingMetrics)
        stateLock.unlock()
        if shouldFinish { finishSuccess() }
    }

    private func makeRequest() throws -> URLRequest {
        guard let uri = arguments["uri"] as? String, let url = URL(string: uri) else {
            throw AlphaXNativeError.requestBody("The Apple request URI is invalid")
        }
        var request = URLRequest(url: url)
        request.httpMethod = arguments["method"] as? String ?? "GET"
        if (arguments["protocol"] as? String) == "http3" {
#if os(iOS)
            if #available(iOS 15.0, *) {
                request.assumesHTTP3Capable = true
            }
#else
            if #available(macOS 12.0, *) {
                request.assumesHTTP3Capable = true
            }
#endif
        }
        if let headers = dictionary(arguments["headers"]) {
            for (name, rawValues) in headers {
                let values: [Any]
                if let valuesArray = rawValues as? [Any] {
                    values = valuesArray
                } else {
                    values = [rawValues]
                }
                for value in values {
                    request.addValue(String(describing: value), forHTTPHeaderField: name)
                }
            }
        }
        if let proxyAuthorization = engine?.proxyAuthorizationHeader() {
            // URLSession does not consistently surface HTTP proxy 407
            // challenges on every Apple deployment target. When the caller
            // selected an explicit HTTP proxy, scope Basic credentials to
            // that route so the proxy receives them without relying on
            // origin authentication behavior.
            request.setValue(proxyAuthorization, forHTTPHeaderField: "Proxy-Authorization")
        }
        if let length = integer(dictionary(arguments["body"])?["length"]), length >= 0,
           request.value(forHTTPHeaderField: "Content-Length") == nil {
            request.setValue(String(length), forHTTPHeaderField: "Content-Length")
        }
        if let requestMillis = milliseconds(dictionary(arguments["timeouts"])?["requestMs"]), requestMillis > 0 {
            request.timeoutInterval = TimeInterval(requestMillis) / 1000.0
        }
        return request
    }

    private func emitStartedIfNeeded(contentLength: Int64? = nil) {
        stateLock.lock()
        if started {
            stateLock.unlock()
            return
        }
        guard let response = response else {
            stateLock.unlock()
            return
        }
        started = true
        let requested = arguments["protocol"] as? String ?? "auto"
        let required = arguments["protocolRequirement"] as? String
        let headers = headerMap(response)
        let length = contentLength ?? response.expectedContentLength
        let redirects = self.redirects
        stateLock.unlock()
        engine?.emit([
            "type": "started",
            "requestId": requestId,
            "statusCode": response.statusCode,
            "headers": headers,
            // URLSession exposes the negotiated protocol in task metrics after
            // the response completes. Never infer it from configuration/Alt-Svc.
            "protocol": "unknown",
            "requestedProtocol": requested,
            "requiredProtocol": required ?? NSNull(),
            "redirects": redirects,
            "contentLength": length >= 0 ? length : NSNull(),
        ])
    }

    private func emitChunk(_ data: Data) {
        integrationCounters.chunk(requestId, bytes: data.count)
        engine?.emit(["type": "chunk", "requestId": requestId, "bytes": data])
    }

    private func applyBackpressure(_ output: AlphaXURLSessionBackpressure.Output) {
        // Apply the upstream pause before dispatching the callback's chunks.
        // This prevents a second URLSession callback from being admitted while
        // the current callback is still being split. The state transition is
        // already committed by the controller, so suspend is emitted at most
        // once for this logical pause.
        if output.suspendTask {
            stateLock.lock()
            if !terminal {
                integrationCounters.taskSuspend(requestId)
                task?.suspend()
            }
            stateLock.unlock()
        }
        for chunk in output.chunks {
            stateLock.lock()
            let shouldEmit = !terminal
            stateLock.unlock()
            if !shouldEmit { return }
            emitChunk(chunk)
        }
        if output.resumeTask {
            stateLock.lock()
            if !terminal {
                integrationCounters.taskResume(requestId)
                task?.resume()
            }
            stateLock.unlock()
        }
        integrationCounters.backpressureState(requestId, snapshot: output.snapshot)
    }

    private func emitDownloadProgress() {
        stateLock.lock()
        guard !terminal, progressInterest.isRequested(direction: "download") else {
            stateLock.unlock()
            return
        }
        let transferred = bytesDownloaded
        let total = response?.expectedContentLength ?? -1
        stateLock.unlock()
        integrationCounters.progress(requestId)
        engine?.emit([
            "type": "progress",
            "requestId": requestId,
            "direction": "download",
            "bytesTransferred": transferred,
            "totalBytes": total >= 0 ? total : NSNull(),
            "isComplete": total >= 0 && transferred >= total,
        ])
    }

    private func finishSuccess() {
        stateLock.lock()
        if terminal {
            stateLock.unlock()
            return
        }
        // URLSession can complete a tiny response before Dart has attached a
        // listener to the response stream. Keep the bounded pending chunks
        // until credits arrive; otherwise readAsBytes() could observe an
        // empty body even though the server returned bytes.
        completionPending = true
        let output = backpressure.markInputCompleted()
        stateLock.unlock()
        applyBackpressure(output)
        completeSuccessIfReady()
    }

    private func completeSuccessIfReady() {
        stateLock.lock()
        let state = backpressure.snapshot
        guard completionPending, !terminal, state.pendingChunkCount == 0,
              state.deferredBytes == 0, !state.suspended else {
            stateLock.unlock()
            return
        }
        completionPending = false
        let hasResponse = response != nil
        let started = self.started
        let finalMetrics = self.metrics
        let received = bytesDownloaded
        let redirects = self.redirects
        let requiredProtocol = arguments["protocolRequirement"] as? String
        let actualProtocol = normalizedProtocol(stringValue(finalMetrics["protocol"]))
        if let requiredProtocol, requiredProtocol != actualProtocol {
            stateLock.unlock()
            finishError(
                kind: "protocol_requirement",
                message: "The negotiated protocol \(actualProtocol) did not satisfy \(requiredProtocol)",
                details: [
                    "requiredProtocol": requiredProtocol,
                    "actualProtocol": actualProtocol,
                ]
            )
            return
        }
        terminal = true
        stateLock.unlock()
        cancelTimeouts()
        if !started, hasResponse { emitStartedIfNeeded() }
        engine?.emit([
            "type": "completed",
            "requestId": requestId,
            "metrics": finalMetrics.isEmpty ? fallbackMetrics() : finalMetrics,
            "bytesReceived": received,
            "redirects": redirects,
            "requiredProtocol": requiredProtocol ?? NSNull(),
        ])
        engine?.remove(self)
    }

    private func finishError(
        kind: String,
        message: String,
        timeoutKind: String? = nil,
        details: [String: Any] = [:]
    ) {
        stateLock.lock()
        if terminal {
            stateLock.unlock()
            return
        }
        terminal = true
        let cancelledState = backpressure.cancel()
        integrationCounters.backpressureState(requestId, snapshot: cancelledState.snapshot)
        let activeTask = task
        stateLock.unlock()
        cancelTimeouts()
        activeTask?.cancel()
        engine?.emit([
            "type": "error",
            "requestId": requestId,
            "kind": kind,
            "message": message,
            "timeoutKind": kind == "timeout" ? (timeoutKind ?? self.timeoutKind()) : NSNull(),
            "details": details,
        ])
        engine?.remove(self)
    }

    private func fallbackMetrics() -> [String: Any] {
        stateLock.lock()
        let total = responseDate.flatMap {
            AlphaXURLSessionTiming.milliseconds(Date().timeIntervalSince($0))
        }
        let protocolValue = normalizedProtocol(nil)
        let result: [String: Any] = [
            "totalDurationMs": optionalInt(total),
            "uploadedBytes": bytesUploaded,
            "downloadedBytes": bytesDownloaded,
            "protocol": protocolValue,
            "redirectCount": redirects.count,
            "connectionReused": NSNull(),
        ]
        stateLock.unlock()
        return result
    }

    private func diagnosticMessage(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(error.localizedDescription) [\(nsError.domain):\(nsError.code)]"
    }

    private func scheduleTimeouts() {
        let values = dictionary(arguments["timeouts"])
        if let value = milliseconds(values?["connectMs"]) { scheduleTimeout(kind: "connect", milliseconds: value) }
        if let value = milliseconds(values?["requestMs"]) { scheduleTimeout(kind: "request", milliseconds: value) }
        if let value = milliseconds(values?["overallMs"]) { scheduleTimeout(kind: "overall", milliseconds: value) }
    }

    private func scheduleTimeout(kind: String, milliseconds: Int) {
        guard milliseconds > 0 else { return }
        let item = DispatchWorkItem { [weak self] in
            self?.finishError(
                kind: "timeout",
                message: "The \(kind) timeout elapsed",
                timeoutKind: kind
            )
        }
        stateLock.lock()
        timeoutItems[kind]?.cancel()
        timeoutItems[kind] = item
        stateLock.unlock()
        DispatchQueue.global(qos: .userInitiated).asyncAfter(
            deadline: .now() + .milliseconds(milliseconds),
            execute: item
        )
    }

    private func cancelTimeout(_ kind: String) {
        stateLock.lock()
        timeoutItems.removeValue(forKey: kind)?.cancel()
        stateLock.unlock()
    }

    private func cancelTimeouts() {
        stateLock.lock()
        timeoutItems.values.forEach { $0.cancel() }
        timeoutItems.removeAll()
        stateLock.unlock()
    }

    private func resetReadTimeout() {
        guard let value = milliseconds(dictionary(arguments["timeouts"])?["readMs"]) else { return }
        scheduleTimeout(kind: "read", milliseconds: value)
    }

    private func timeoutKind() -> String {
        let values = dictionary(arguments["timeouts"])
        if milliseconds(values?["readMs"]) != nil { return "read" }
        if milliseconds(values?["overallMs"]) != nil { return "overall" }
        return "request"
    }

    private func bodyReplayable() -> Bool {
        let body = dictionary(arguments["body"])
        return body?["replayable"] as? Bool ?? true
    }

    private func classify(_ error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return "connection" }
        switch nsError.code {
        case NSURLErrorCancelled: return "cancellation"
        case NSURLErrorTimedOut: return "timeout"
        case NSURLErrorDNSLookupFailed, NSURLErrorCannotFindHost, NSURLErrorBadURL: return "dns"
        case NSURLErrorServerCertificateUntrusted, NSURLErrorServerCertificateHasBadDate,
             NSURLErrorServerCertificateHasUnknownRoot, NSURLErrorServerCertificateNotYetValid,
             NSURLErrorSecureConnectionFailed, NSURLErrorClientCertificateRejected:
            return "tls"
        case NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost,
             NSURLErrorNotConnectedToInternet, NSURLErrorInternationalRoamingOff:
            return "connection"
        default: return "transport"
        }
    }

    private func dictionary(_ value: Any?) -> [String: Any]? {
        guard let value = value as? [AnyHashable: Any] else {
            return value as? [String: Any]
        }
        return value.reduce(into: [String: Any]()) { result, entry in
            if let key = entry.key as? String { result[key] = entry.value }
        }
    }

    private func integer(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private func milliseconds(_ value: Any?) -> Int? {
        if let value = integer(value) { return value }
        return nil
    }

    private func data(_ value: Any?) -> Data {
        if let value = value as? Data { return value }
        if let value = value as? FlutterStandardTypedData { return value.data }
        if let value = value as? [UInt8] { return Data(value) }
        if let value = value as? [NSNumber] { return Data(value.map(\.uint8Value)) }
        if let value = value as? [Any] { return Data(value.compactMap { ($0 as? NSNumber)?.uint8Value }) }
        return Data()
    }

    private func headerMap(_ response: HTTPURLResponse) -> [String: [String]] {
        var result: [String: [String]] = [:]
        for (key, value) in response.allHeaderFields {
            let name = String(describing: key)
            if let values = value as? [String] {
                result[name] = values
            } else {
                result[name] = [String(describing: value)]
            }
        }
        return result
    }

    private func normalizedProtocol(_ value: String?) -> String {
        guard let value = value?.lowercased(), !value.isEmpty else { return "unknown" }
        switch value {
        case "http10": return "http10"
        case "http11": return "http11"
        case "http2": return "http2"
        case "http3": return "http3"
        default: break
        }
        if value.contains("h3") || value.contains("http/3") || value.contains("quic") {
            return "http3"
        }
        if value.contains("h2") || value.contains("http/2") || value.contains("spdy") {
            return "http2"
        }
        if value.contains("1.1") { return "http11" }
        if value.contains("1.0") { return "http10" }
        return "unknown"
    }

    private func stringValue(_ value: Any?) -> String? {
        guard let value, !(value is NSNull) else { return nil }
        if let value = value as? String { return value }
        if let value = value as? NSString { return value as String }
        return String(describing: value)
    }

    private func optionalInt(_ value: Int?) -> Any {
        value ?? NSNull()
    }
}

private final class AlphaXUploadBridge {
    private let requestId: String
    private weak var methodChannel: FlutterMethodChannel?
    private let onDemand: () -> Void

    init(
        requestId: String,
        methodChannel: FlutterMethodChannel?,
        onDemand: @escaping () -> Void
    ) {
        self.requestId = requestId
        self.methodChannel = methodChannel
        self.onDemand = onDemand
    }

    func next(maxBytes: Int) -> Result<(Data, Bool), Error> {
        onDemand()
        guard let methodChannel else {
            return .failure(AlphaXNativeError.requestBody("The Apple upload channel is unavailable"))
        }
        let semaphore = DispatchSemaphore(value: 0)
        var resultValue: Result<(Data, Bool), Error>?
        methodChannel.invokeMethod(
            "uploadDemand",
            arguments: ["requestId": requestId, "maxBytes": maxBytes]
        ) { value in
            if let map = value as? [AnyHashable: Any] {
                let rawBytes = map["bytes"]
                let data: Data
                if let rawBytes = rawBytes as? FlutterStandardTypedData {
                    data = rawBytes.data
                } else if let rawBytes = rawBytes as? Data {
                    data = rawBytes
                } else if let rawBytes = rawBytes as? [UInt8] {
                    data = Data(rawBytes)
                } else {
                    data = Data()
                }
                resultValue = .success((data, map["done"] as? Bool ?? false))
            } else {
                resultValue = .failure(AlphaXNativeError.requestBody("The Dart upload response is invalid"))
            }
            semaphore.signal()
        }
        if semaphore.wait(timeout: .now() + 60) == .timedOut {
            return .failure(AlphaXNativeError.requestBody("The Dart upload callback timed out"))
        }
        return resultValue ?? .failure(AlphaXNativeError.requestBody("The Dart upload callback failed"))
    }

    func reset() -> Bool {
        guard let methodChannel else { return false }
        let semaphore = DispatchSemaphore(value: 0)
        var succeeded = false
        methodChannel.invokeMethod(
            "uploadReset",
            arguments: ["requestId": requestId]
        ) { value in
            succeeded = !(value is FlutterError)
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + 60) == .success else { return false }
        return succeeded
    }
}

private final class AlphaXBodyInputStream: InputStream {
    private let bridge: AlphaXUploadBridge
    private weak var streamDelegate: StreamDelegate?
    private var opened = false
    private var closed = false
    private var reachedEnd = false
    private var readError: Error?

    init(bridge: AlphaXUploadBridge) {
        self.bridge = bridge
        super.init(data: Data())
    }

    override func open() {
        opened = true
    }

    override func close() {
        closed = true
    }

    override var delegate: StreamDelegate? {
        get { streamDelegate }
        set { streamDelegate = newValue }
    }

    override func property(forKey key: Stream.PropertyKey) -> Any? {
        nil
    }

    override func setProperty(_ property: Any?, forKey key: Stream.PropertyKey) -> Bool {
        false
    }

    override func schedule(in aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {}

    override func remove(from aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {}

    override var hasBytesAvailable: Bool {
        !closed && !reachedEnd
    }

    override var streamError: Error? {
        readError
    }

    override var streamStatus: Stream.Status {
        if readError != nil { return .error }
        if closed { return .closed }
        if reachedEnd { return .atEnd }
        return opened ? .open : .notOpen
    }

    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        guard !closed, !reachedEnd, len > 0 else { return 0 }
        switch bridge.next(maxBytes: len) {
        case let .success((data, done)):
            if data.isEmpty && done {
                reachedEnd = true
                return 0
            }
            data.copyBytes(to: buffer, count: min(data.count, len))
            if done && data.isEmpty { reachedEnd = true }
            return min(data.count, len)
        case let .failure(error):
            readError = error
            return -1
        }
    }
}

private enum AlphaXServerTrustValidation {
    case success(URLCredential?)
    case failure(kind: String, message: String, details: [String: Any])
}

private func validateServerTrust(
    _ trust: SecTrust,
    host: String,
    policy: [String: Any]
) -> AlphaXServerTrustValidation {
    let anchors = (policy["trustAnchors"] as? [Any] ?? []).map(alphaXData).compactMap {
        SecCertificateCreateWithData(nil, $0 as CFData)
    }
    let includePlatformTrust = policy["includePlatformTrust"] as? Bool ?? true
    let pins = policy["pins"] as? [Any] ?? []
    let hasCustomTrust = !anchors.isEmpty || !includePlatformTrust
    guard hasCustomTrust || !pins.isEmpty else {
        return .success(nil)
    }
    if !anchors.isEmpty {
        SecTrustSetAnchorCertificates(trust, anchors as CFArray)
        SecTrustSetAnchorCertificatesOnly(trust, !includePlatformTrust)
    }
    var trustError: CFError?
    guard SecTrustEvaluateWithError(trust, &trustError) else {
        return .failure(
            kind: "tls",
            message: "The server certificate did not satisfy the configured trust policy",
            details: ["host": host]
        )
    }
    if !pins.isEmpty && !alphaXTrustMatchesPins(trust, host: host, pins: pins) {
        return .failure(
            kind: "certificate_pin_mismatch",
            message: "The server certificate chain did not contain a configured SPKI pin",
            details: ["host": host]
        )
    }
    return .success(URLCredential(trust: trust))
}

private func alphaXTrustMatchesPins(_ trust: SecTrust, host: String, pins: [Any]) -> Bool {
    let applicablePins = pins.compactMap { rawPin -> (String, Bool, Data)? in
        guard let pin = alphaXDictionary(rawPin),
              let pinHost = pin["host"] as? String,
              let digest = pin["sha256SpkiBase64"] as? String,
              let digestData = Data(base64Encoded: digest) else { return nil }
        let includeSubdomains = pin["includeSubdomains"] as? Bool ?? false
        let normalizedHost = host.lowercased()
        let normalizedPinHost = pinHost.lowercased()
        let applies = normalizedHost == normalizedPinHost ||
            (includeSubdomains && normalizedHost.hasSuffix(".\(normalizedPinHost)"))
        return applies ? (normalizedPinHost, includeSubdomains, digestData) : nil
    }
    guard !applicablePins.isEmpty else { return false }
    let certificates = (SecTrustCopyCertificateChain(trust) as? [SecCertificate]) ?? []
    for certificate in certificates {
        guard let spki = alphaXSubjectPublicKeyInfo(certificate) else { continue }
        let digest = Data(SHA256.hash(data: spki))
        if applicablePins.contains(where: { $0.2 == digest }) { return true }
    }
    return false
}

private struct AlphaXDERNode {
    let tag: UInt8
    let full: Data
    let value: Data
}

private func alphaXSubjectPublicKeyInfo(_ certificate: SecCertificate) -> Data? {
    let certificateData = SecCertificateCopyData(certificate) as Data
    var offset = 0
    guard let certificateNode = alphaXReadDERNode(certificateData, offset: &offset) else { return nil }
    var tbsOffset = 0
    guard let tbsNode = alphaXReadDERNode(certificateNode.value, offset: &tbsOffset) else { return nil }
    let fields = alphaXDERChildren(tbsNode.value)
    let spkiIndex = fields.first?.tag == 0xa0 ? 6 : 5
    guard fields.indices.contains(spkiIndex) else { return nil }
    return fields[spkiIndex].full
}

private func alphaXDERChildren(_ data: Data) -> [AlphaXDERNode] {
    var result: [AlphaXDERNode] = []
    var offset = 0
    while offset < data.count {
        guard let node = alphaXReadDERNode(data, offset: &offset) else { return [] }
        result.append(node)
    }
    return result
}

private func alphaXReadDERNode(_ data: Data, offset: inout Int) -> AlphaXDERNode? {
    let start = offset
    guard data.indices.contains(offset) else { return nil }
    let tag = data[offset]
    offset += 1
    guard data.indices.contains(offset) else { return nil }
    let firstLength = data[offset]
    offset += 1
    let length: Int
    if firstLength & 0x80 == 0 {
        length = Int(firstLength)
    } else {
        let count = Int(firstLength & 0x7f)
        guard count > 0, count <= 4, offset + count <= data.count else { return nil }
        var value = 0
        for _ in 0..<count {
            value = (value << 8) | Int(data[offset])
            offset += 1
        }
        length = value
    }
    guard length >= 0, offset + length <= data.count else { return nil }
    let valueStart = offset
    let end = offset + length
    offset = end
    return AlphaXDERNode(
        tag: tag,
        full: data.subdata(in: start..<end),
        value: data.subdata(in: valueStart..<end)
    )
}

private func alphaXDictionary(_ value: Any?) -> [String: Any]? {
    guard let value = value as? [AnyHashable: Any] else { return value as? [String: Any] }
    return value.reduce(into: [String: Any]()) { result, entry in
        if let key = entry.key as? String { result[key] = entry.value }
    }
}

private func alphaXData(_ value: Any) -> Data {
    if let value = value as? FlutterStandardTypedData { return value.data }
    if let value = value as? Data { return value }
    if let value = value as? [UInt8] { return Data(value) }
    if let value = value as? [NSNumber] { return Data(value.map(\.uint8Value)) }
    return Data()
}

private enum AlphaXNativeError: LocalizedError {
    case requestBody(String)

    var errorDescription: String? {
        switch self {
        case let .requestBody(message): return message
        }
    }
}
