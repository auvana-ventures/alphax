import Foundation

@main
struct AlphaXURLSessionCorrectnessTests {
    static func main() {
        run("timing representative intervals", testRepresentativePhaseIntervalsAreMillisecondsOnce)
        run("timing unavailable and invalid intervals", testUnavailableAndInvalidIntervalsRemainUnavailable)
        run("timing total boundary", testTotalTimingUsesTheSameMillisecondsBoundary)
        run("oversized callback draining", testOversizedCallbackIsSplitAndDrainedWithoutRepeatedSuspend)
        run("callback size boundaries", testCallbackSizesRemainBoundedAndOrdered)
        run("completion ordering", testCompletionWaitsUntilAllAcceptedChunksAreDrained)
        run("cancellation cleanup", testCancellationClearsPendingDataAndSuppressesResume)
        run("slow consumer pause and resume", testSlowConsumerSuspendsAndResumesExactlyOnce)
        run("file finalization without destination", testDestinationAbsentIsFinalized)
        run("file replacement", testExistingDestinationIsReplaced)
        run("failed replacement preserves destination", testFailedReplacementDoesNotReportSuccessOrDeleteOldDestination)
        print("AlphaX Apple URLSession correctness tests passed")
    }

    private static func run(_ name: String, _ test: () throws -> Void) {
        do {
            try test()
            print("PASS: \(name)")
        } catch {
            fatalError("FAIL: \(name): \(error)")
        }
    }

    private static func require(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) {
        precondition(condition(), message)
    }

    private static func requireEqual<T: Equatable>(
        _ actual: T,
        _ expected: T,
        _ message: String
    ) {
        require(actual == expected, "\(message); actual=\(actual), expected=\(expected)")
    }

    private static func testRepresentativePhaseIntervalsAreMillisecondsOnce() {
        let values: [(TimeInterval, Int)] = [
            (0.001, 1),
            (0.010, 10),
            (0.100, 100),
            (1.000, 1000),
        ]
        for (seconds, expectedMilliseconds) in values {
            let start = Date(timeIntervalSinceReferenceDate: 10)
            let end = start.addingTimeInterval(seconds)
            requireEqual(
                AlphaXURLSessionTiming.interval(start, end),
                expectedMilliseconds,
                "phase duration must be milliseconds exactly once"
            )
            requireEqual(
                AlphaXURLSessionTiming.milliseconds(seconds),
                expectedMilliseconds,
                "total duration must be milliseconds exactly once"
            )
        }
    }

    private static func testUnavailableAndInvalidIntervalsRemainUnavailable() {
        require(AlphaXURLSessionTiming.interval(nil, Date()) == nil, "missing start must stay unavailable")
        require(AlphaXURLSessionTiming.interval(Date(), nil) == nil, "missing end must stay unavailable")
        let start = Date(timeIntervalSinceReferenceDate: 10)
        let end = Date(timeIntervalSinceReferenceDate: 9)
        require(AlphaXURLSessionTiming.interval(start, end) == nil, "negative phase must stay unavailable")
        require(AlphaXURLSessionTiming.milliseconds(-0.001) == nil, "negative interval must stay unavailable")
        require(AlphaXURLSessionTiming.milliseconds(.infinity) == nil, "infinite interval must stay unavailable")
        require(AlphaXURLSessionTiming.milliseconds(.nan) == nil, "NaN interval must stay unavailable")
    }

    private static func testTotalTimingUsesTheSameMillisecondsBoundary() {
        requireEqual(
            AlphaXURLSessionTiming.milliseconds(1.234),
            1234,
            "total duration must use the shared conversion"
        )
        requireEqual(AlphaXURLSessionTiming.milliseconds(0), 0, "zero duration must remain zero")

        let start = Date(timeIntervalSinceReferenceDate: 100)
        let response = start.addingTimeInterval(0.130)
        let end = start.addingTimeInterval(0.250)
        let phaseMilliseconds = [
            AlphaXURLSessionTiming.interval(start, start.addingTimeInterval(0.010)),
            AlphaXURLSessionTiming.interval(start.addingTimeInterval(0.010), start.addingTimeInterval(0.020)),
            AlphaXURLSessionTiming.interval(start.addingTimeInterval(0.020), start.addingTimeInterval(0.030)),
            AlphaXURLSessionTiming.interval(response, end),
        ].compactMap { $0 }.reduce(0, +)
        requireEqual(phaseMilliseconds, 150, "phase timings must remain coherent in milliseconds")
        requireEqual(
            AlphaXURLSessionTiming.interval(start, end),
            250,
            "task total must cover the same timeline without double scaling"
        )
        require(phaseMilliseconds <= 250, "phase timings cannot exceed the task total")
    }

    private static func testOversizedCallbackIsSplitAndDrainedWithoutRepeatedSuspend() {
        let controller = AlphaXURLSessionBackpressure()
        _ = controller.grant(4)
        let source = patternedData(count: 5 * 1024 * 1024)
        var output = controller.receive(source)
        var delivered = output.chunks
        var suspendActions = output.suspendTask ? 1 : 0
        var resumeActions = output.resumeTask ? 1 : 0

        requireEqual(delivered.count, 4, "initial credits must emit four chunks")
        require(output.suspendTask, "the bounded window must suspend once it is exhausted")
        require(!output.resumeTask, "initial delivery cannot resume the task")
        requireEqual(output.snapshot.pendingBytes, 4 * chunkSize, "pending bytes must stay at the window")
        requireEqual(
            output.snapshot.deferredBytes,
            source.count - 8 * chunkSize,
            "only the callback remainder may be deferred"
        )
        requireEqual(
            output.snapshot.retainedBytes,
            source.count - 4 * chunkSize,
            "logical retention must include only the bounded queue and callback remainder"
        )
        requireEqual(output.snapshot.suspendTransitions, 1, "one callback exhaustion means one suspend transition")

        while !controller.isDrained {
            output = controller.grant(4)
            delivered.append(contentsOf: output.chunks)
            if output.suspendTask { suspendActions += 1 }
            if output.resumeTask { resumeActions += 1 }
            require(!output.suspendTask, "a suspended task must not receive a redundant suspend action")
            require(output.snapshot.pendingBytes <= 4 * chunkSize, "pending bytes must remain bounded")
        }

        // The last emitted batch consumes the final credits. The consumer's
        // next credit grant is what lets a suspended URLSession task finish
        // its callback/response lifecycle after all body bytes are drained.
        if !output.resumeTask {
            output = controller.grant(1)
            if output.suspendTask { suspendActions += 1 }
            if output.resumeTask { resumeActions += 1 }
        }

        require(output.resumeTask, "draining the callback remainder must resume the task")
        requireEqual(suspendActions, 1, "suspend must be called once per logical pause")
        requireEqual(resumeActions, 1, "resume must be called once per logical pause")
        requireEqual(output.snapshot.resumeTransitions, 1, "resume transition must be balanced")
        requireEqual(output.snapshot.retainedBytes, 0, "drained callback must release logical retention")
        requireEqual(delivered.reduce(0) { $0 + $1.count }, source.count, "all callback bytes must arrive")
        requireEqual(checksum(delivered), checksum([source]), "callback bytes must retain order and content")
    }

    private static func testCallbackSizesRemainBoundedAndOrdered() {
        let sizes = [64 * 1024, 128 * 1024, 256 * 1024, 257 * 1024, 1024 * 1024]
        for size in sizes {
            let controller = AlphaXURLSessionBackpressure()
            _ = controller.grant(4)
            let source = patternedData(count: size)
            var output = controller.receive(source)
            var delivered = output.chunks
            var suspendActions = output.suspendTask ? 1 : 0
            var resumeActions = output.resumeTask ? 1 : 0
            while !controller.isDrained {
                output = controller.grant(4)
                delivered.append(contentsOf: output.chunks)
                if output.suspendTask { suspendActions += 1 }
                if output.resumeTask { resumeActions += 1 }
                require(!output.suspendTask, "a callback must not trigger repeated suspend actions")
                require(output.snapshot.pendingBytes <= 4 * chunkSize, "pending bytes must remain bounded")
                require(output.snapshot.retainedBytes <= size, "logical callback retention must not grow beyond input")
            }
            if !output.resumeTask {
                output = controller.grant(1)
                if output.suspendTask { suspendActions += 1 }
                if output.resumeTask { resumeActions += 1 }
            }
            requireEqual(delivered.reduce(0) { $0 + $1.count }, size, "callback size must be conserved")
            requireEqual(checksum(delivered), checksum([source]), "callback content must be conserved")
            requireEqual(output.snapshot.retainedBytes, 0, "callback retention must be released after draining")
            let exhausted = size >= 4 * chunkSize
            requireEqual(suspendActions, exhausted ? 1 : 0, "suspend transition must match credit exhaustion")
            requireEqual(resumeActions, exhausted ? 1 : 0, "resume transition must match credit exhaustion")
        }
    }

    private static func testCompletionWaitsUntilAllAcceptedChunksAreDrained() {
        let controller = AlphaXURLSessionBackpressure()
        _ = controller.grant(4)
        _ = controller.receive(patternedData(count: 5 * 1024 * 1024))
        var output = controller.markInputCompleted()
        require(!output.completed, "completion cannot precede pending body delivery")
        require(!controller.isDrained, "the accepted callback remainder must still be pending")

        while !controller.isDrained {
            output = controller.grant(4)
            require(!output.completed || controller.isDrained, "completion must be last")
        }
        if !output.resumeTask {
            output = controller.grant(1)
            require(output.resumeTask, "the final credit must resume the task")
        }
        require(output.completed, "completion must fire after the final body chunk")
    }

    private static func testCancellationClearsPendingDataAndSuppressesResume() {
        let controller = AlphaXURLSessionBackpressure()
        _ = controller.grant(4)
        _ = controller.receive(patternedData(count: 5 * 1024 * 1024))
        let cancelled = controller.cancel()
        require(cancelled.snapshot.terminal, "cancel must make the state terminal")
        requireEqual(cancelled.snapshot.pendingBytes, 0, "cancel must clear pending chunks")
        requireEqual(cancelled.snapshot.deferredBytes, 0, "cancel must clear callback remainder")
        require(!cancelled.resumeTask, "cancel must invalidate future resume work")
        require(controller.grant(4).chunks.isEmpty, "credits after cancel must be ignored")
        require(!controller.markInputCompleted().completed, "completion after cancel must be ignored")
    }

    private static func testSlowConsumerSuspendsAndResumesExactlyOnce() {
        let controller = AlphaXURLSessionBackpressure()
        _ = controller.grant(4)
        let first = controller.receive(patternedData(count: 512 * 1024))
        require(first.suspendTask, "slow consumer must suspend the task")
        requireEqual(first.snapshot.pendingBytes, 4 * chunkSize, "slow consumer window must be bounded")
        require(first.snapshot.suspended, "state must record the task as suspended")

        let partial = controller.grant(1)
        require(!partial.suspendTask, "partial drain must not suspend again")
        require(!partial.resumeTask, "partial drain must not resume before the queue is drained")
        require(partial.snapshot.suspended, "partial drain must remain paused")
        let resumed = controller.grant(4)
        require(resumed.resumeTask, "full drain must resume the task")
        requireEqual(resumed.snapshot.resumeTransitions, 1, "slow consumer pause must resume once")
    }

    private static func testDestinationAbsentIsFinalized() throws {
        let (root, source, target) = try makeFixture(existingTarget: false)
        defer { try? FileManager.default.removeItem(at: root) }
        try AlphaXURLSessionFileFinalizer.finalize(location: source, target: target)
        requireEqual(try String(contentsOf: target, encoding: .utf8), "new", "new destination must contain the downloaded file")
        require(!FileManager.default.fileExists(atPath: source.path), "temporary source must be consumed")
    }

    private static func testExistingDestinationIsReplaced() throws {
        let (root, source, target) = try makeFixture(existingTarget: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try AlphaXURLSessionFileFinalizer.finalize(location: source, target: target)
        requireEqual(try String(contentsOf: target, encoding: .utf8), "new", "existing destination must be replaced")
    }

    private static func testFailedReplacementDoesNotReportSuccessOrDeleteOldDestination() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("alphax-finalizer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appendingPathComponent("destination")
        try Data("old".utf8).write(to: target)
        let missingSource = root.appendingPathComponent("missing")
        var failed = false
        do {
            try AlphaXURLSessionFileFinalizer.finalize(location: missingSource, target: target)
        } catch {
            failed = true
        }
        require(failed, "a missing temporary file must fail finalization")
        requireEqual(try String(contentsOf: target, encoding: .utf8), "old", "failed replacement must preserve old destination")
    }

    private static func patternedData(count: Int) -> Data {
        Data((0..<count).map { UInt8($0 % 251) })
    }

    private static func checksum(_ pieces: [Data]) -> UInt64 {
        pieces.reduce(0) { partial, piece in
            piece.reduce(partial) { ($0 &* 31) &+ UInt64($1) }
        }
    }

    private static func makeFixture(existingTarget: Bool) throws -> (URL, URL, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("alphax-finalizer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("temporary")
        let target = root.appendingPathComponent("destination")
        try Data("new".utf8).write(to: source)
        if existingTarget {
            try Data("old".utf8).write(to: target)
        }
        return (root, source, target)
    }

    private static let chunkSize = 64 * 1024
}
