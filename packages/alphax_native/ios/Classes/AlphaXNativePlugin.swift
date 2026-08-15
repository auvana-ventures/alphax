#if os(macOS)
import FlutterMacOS
#else
import Flutter
#endif
import Foundation

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

private final class AlphaXURLSessionEngine: NSObject, URLSessionDataDelegate, URLSessionDownloadDelegate, URLSessionTaskDelegate {
    weak var methodChannel: FlutterMethodChannel?

    private let stateLock = NSLock()
    private var eventSink: FlutterEventSink?
    private var operations: [Int: AlphaXURLSessionOperation] = [:]
    private var closed = false
    private var closeCompletion: FlutterResult?
    private var sessionCreated = false
    private var session: URLSession?

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
            engine: self
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
            "proxyConfiguration": "unsupported",
            "certificatePinning": "unsupported",
            "mutualTls": "unsupported",
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
}

private final class AlphaXURLSessionOperation {
    let requestId: String
    private let arguments: [String: Any]
    private weak var engine: AlphaXURLSessionEngine?
    private let stateLock = NSLock()
    private var task: URLSessionTask?
    private var terminal = false
    private var started = false
    private var response: HTTPURLResponse?
    private var redirects: [[String: Any]] = []
    private var metrics: [String: Any] = [:]
    private var pendingChunks: [Data] = []
    private var pendingBytes = 0
    private var credits = 0
    private var suspended = false
    private var completionPending = false
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

    private let maxCredits = 4
    private let maxQueuedBytes = 256 * 1024
    private let chunkSize = 64 * 1024

    init(requestId: String, arguments: [String: Any], engine: AlphaXURLSessionEngine) {
        self.requestId = requestId
        self.arguments = arguments
        self.engine = engine
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
            let created: URLSessionTask
            if let path = arguments["directDownloadPath"] as? String, !path.isEmpty {
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
                        methodChannel: engine?.methodChannel
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
        credits = min(maxCredits, credits + amount)
        let shouldResume = suspended && credits > 0
        if shouldResume { suspended = false }
        stateLock.unlock()
        flushPending()
        if shouldResume {
            stateLock.lock()
            let activeTask = task
            stateLock.unlock()
            activeTask?.resume()
        }
        completeSuccessIfReady()
    }

    func cancel(_ reason: String) {
        stateLock.lock()
        if terminal {
            stateLock.unlock()
            return
        }
        terminal = true
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
        stateLock.unlock()
        resetReadTimeout()
        let pieces = split(data)
        for piece in pieces {
            stateLock.lock()
            if terminal {
                stateLock.unlock()
                return
            }
            if credits > 0 {
                credits -= 1
                stateLock.unlock()
                emitChunk(piece)
                if currentCredits() == 0 { suspendForBackpressure() }
            } else {
                pendingChunks.append(piece)
                pendingBytes += piece.count
                if pendingBytes >= maxQueuedBytes {
                    suspended = true
                    task?.suspend()
                }
                stateLock.unlock()
            }
        }
        emitDownloadProgress()
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
        bytesUploaded = totalBytesSent
        let total = totalBytesExpectedToSend > 0 ? totalBytesExpectedToSend : nil
        stateLock.unlock()
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
        let protocolName = transaction.networkProtocolName
        let protocolValue = normalizedProtocol(protocolName)
        let total = metrics.taskInterval.duration
        let ttfb = interval(transaction.requestStartDate, transaction.responseStartDate)
        let transfer = interval(transaction.responseStartDate, transaction.responseEndDate)
        stateLock.lock()
        self.metrics = [
            "dnsDurationMs": optionalInt(interval(transaction.domainLookupStartDate, transaction.domainLookupEndDate)),
            "connectDurationMs": optionalInt(interval(transaction.connectStartDate, transaction.connectEndDate)),
            "tlsDurationMs": optionalInt(interval(transaction.secureConnectionStartDate, transaction.secureConnectionEndDate)),
            "timeToFirstByteMs": optionalInt(ttfb),
            "transferDurationMs": optionalInt(transfer),
            "totalDurationMs": milliseconds(total),
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
        bytesDownloaded = totalBytesWritten
        if firstByteDate == nil { firstByteDate = Date() }
        stateLock.unlock()
        emitStartedIfNeeded(contentLength: totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : nil)
        resetReadTimeout()
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
            let parent = target.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.removeItem(at: target)
            }
            try FileManager.default.moveItem(at: location, to: target)
            outputURL = target
        } catch {
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
            "redirects": redirects,
            "contentLength": length >= 0 ? length : NSNull(),
        ])
    }

    private func emitChunk(_ data: Data) {
        engine?.emit(["type": "chunk", "requestId": requestId, "bytes": data])
    }

    private func flushPending() {
        while true {
            stateLock.lock()
            guard !terminal, credits > 0, !pendingChunks.isEmpty else {
                stateLock.unlock()
                break
            }
            let data = pendingChunks.removeFirst()
            pendingBytes -= data.count
            credits -= 1
            let shouldResume = suspended && pendingBytes < maxQueuedBytes
            if shouldResume { suspended = false }
            stateLock.unlock()
            emitChunk(data)
            if shouldResume {
                stateLock.lock()
                let activeTask = task
                stateLock.unlock()
                activeTask?.resume()
            }
        }
    }

    private func suspendForBackpressure() {
        stateLock.lock()
        if !terminal, !suspended {
            suspended = true
            task?.suspend()
        }
        stateLock.unlock()
    }

    private func currentCredits() -> Int {
        stateLock.lock()
        defer { stateLock.unlock() }
        return credits
    }

    private func emitDownloadProgress() {
        stateLock.lock()
        let transferred = bytesDownloaded
        let total = response?.expectedContentLength ?? -1
        stateLock.unlock()
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
        stateLock.unlock()
        flushPending()
        completeSuccessIfReady()
    }

    private func completeSuccessIfReady() {
        stateLock.lock()
        guard completionPending, !terminal, pendingChunks.isEmpty else {
            stateLock.unlock()
            return
        }
        completionPending = false
        terminal = true
        let hasResponse = response != nil
        let started = self.started
        let finalMetrics = self.metrics
        let received = bytesDownloaded
        let redirects = self.redirects
        stateLock.unlock()
        cancelTimeouts()
        if !started, hasResponse { emitStartedIfNeeded() }
        engine?.emit([
            "type": "completed",
            "requestId": requestId,
            "metrics": finalMetrics.isEmpty ? fallbackMetrics() : finalMetrics,
            "bytesReceived": received,
            "redirects": redirects,
        ])
        engine?.remove(self)
    }

    private func finishError(kind: String, message: String, timeoutKind: String? = nil) {
        stateLock.lock()
        if terminal {
            stateLock.unlock()
            return
        }
        terminal = true
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
        ])
        engine?.remove(self)
    }

    private func fallbackMetrics() -> [String: Any] {
        stateLock.lock()
        let total = responseDate.map { milliseconds(Date().timeIntervalSince($0)) }
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

    private func split(_ data: Data) -> [Data] {
        guard data.count > chunkSize else { return [data] }
        var result: [Data] = []
        var offset = 0
        while offset < data.count {
            let count = min(chunkSize, data.count - offset)
            result.append(data.subdata(in: offset..<(offset + count)))
            offset += count
        }
        return result
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

    private func interval(_ start: Date?, _ end: Date?) -> Int? {
        guard let start, let end else { return nil }
        return milliseconds(start.distance(to: end) * 1000)
    }

    private func milliseconds(_ interval: TimeInterval) -> Int {
        Int((interval * 1000).rounded())
    }

    private func optionalInt(_ value: Int?) -> Any {
        value ?? NSNull()
    }
}

private final class AlphaXUploadBridge {
    private let requestId: String
    private weak var methodChannel: FlutterMethodChannel?

    init(requestId: String, methodChannel: FlutterMethodChannel?) {
        self.requestId = requestId
        self.methodChannel = methodChannel
    }

    func next(maxBytes: Int) -> Result<(Data, Bool), Error> {
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

private enum AlphaXNativeError: LocalizedError {
    case requestBody(String)

    var errorDescription: String? {
        switch self {
        case let .requestBody(message): return message
        }
    }
}
