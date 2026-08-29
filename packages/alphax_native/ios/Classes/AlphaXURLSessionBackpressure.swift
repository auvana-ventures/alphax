import Foundation

/// Private, transport-local response delivery state for URLSession callbacks.
///
/// URLSession may deliver a Data callback larger than AlphaX's Dart stream
/// chunk/window. The state machine retains at most the bounded AlphaX queue
/// plus the current callback remainder, and emits one suspend transition for
/// a logical pause. It does not call URLSessionTask itself; the operation
/// applies the returned transitions outside its lock.
internal final class AlphaXURLSessionBackpressure {
    internal struct Snapshot {
        let credits: Int
        let pendingChunkCount: Int
        let pendingBytes: Int
        let deferredBytes: Int
        let retainedBytes: Int
        let suspended: Bool
        let inputCompleted: Bool
        let completionRequested: Bool
        let terminal: Bool
        let suspendTransitions: Int
        let resumeTransitions: Int
        let redundantSuspendChecks: Int
    }

    internal struct Output {
        let chunks: [Data]
        let suspendTask: Bool
        let resumeTask: Bool
        let completed: Bool
        let snapshot: Snapshot
    }

    private struct Source {
        let data: Data
        var offset: Int
    }

    let chunkSize: Int
    let maxCredits: Int
    let maxQueuedBytes: Int

    private var pendingChunks: [Data] = []
    private var pendingBytes = 0
    private var deferredSources: [Source] = []
    private var credits = 0
    private var suspended = false
    private var inputCompleted = false
    private var completionRequested = false
    private var completionEmitted = false
    private var terminal = false
    private var suspendTransitions = 0
    private var resumeTransitions = 0
    private var redundantSuspendChecks = 0

    init(chunkSize: Int = 64 * 1024, maxCredits: Int = 4) {
        precondition(chunkSize > 0)
        precondition(maxCredits > 0)
        self.chunkSize = chunkSize
        self.maxCredits = maxCredits
        maxQueuedBytes = chunkSize * maxCredits
    }

    func grant(_ amount: Int) -> Output {
        guard !terminal, amount > 0 else { return output() }
        credits = min(maxCredits, credits + amount)
        var chunks: [Data] = []
        drainAvailable(into: &chunks)
        return output(chunks: chunks)
    }

    func receive(_ data: Data) -> Output {
        guard !terminal, !inputCompleted else { return output() }
        var chunks: [Data] = []
        // A normal URLSession callback cannot arrive while the task is
        // suspended. If a provider does deliver another callback, retaining
        // it here preserves byte order rather than dropping data.
        drainAvailable(into: &chunks)
        if deferredSources.isEmpty {
            consume(data, into: &chunks)
        } else {
            deferredSources.append(Source(data: data, offset: 0))
        }
        return output(chunks: chunks)
    }

    func markInputCompleted() -> Output {
        guard !terminal else { return output() }
        inputCompleted = true
        completionRequested = true
        var chunks: [Data] = []
        drainAvailable(into: &chunks)
        return output(chunks: chunks)
    }

    func cancel() -> Output {
        guard !terminal else { return output() }
        terminal = true
        pendingChunks.removeAll(keepingCapacity: false)
        pendingBytes = 0
        deferredSources.removeAll(keepingCapacity: false)
        credits = 0
        // Cancellation invalidates any future resume work. The underlying
        // task is cancelled by the operation, so a resume must not be issued.
        suspended = false
        return output()
    }

    var isDrained: Bool {
        pendingChunks.isEmpty && deferredSources.isEmpty
    }

    var snapshot: Snapshot { makeSnapshot() }

    private func consume(_ data: Data, into chunks: inout [Data]) {
        var offset = 0
        while offset < data.count {
            let count = min(chunkSize, data.count - offset)
            if credits > 0 {
                chunks.append(makeChunk(data, offset: offset, count: count))
                credits -= 1
                offset += count
            } else if pendingBytes + count <= maxQueuedBytes {
                pendingChunks.append(makeChunk(data, offset: offset, count: count))
                pendingBytes += count
                offset += count
            } else {
                deferredSources.append(Source(data: data, offset: offset))
                return
            }
        }
    }

    private func drainAvailable(into chunks: inout [Data]) {
        while credits > 0 {
            if !pendingChunks.isEmpty {
                let chunk = pendingChunks.removeFirst()
                pendingBytes -= chunk.count
                credits -= 1
                chunks.append(chunk)
                continue
            }
            guard !deferredSources.isEmpty else { return }
            var source = deferredSources.removeFirst()
            let count = min(chunkSize, source.data.count - source.offset)
            chunks.append(makeChunk(source.data, offset: source.offset, count: count))
            source.offset += count
            credits -= 1
            if source.offset < source.data.count {
                deferredSources.insert(source, at: 0)
            }
        }
    }

    private func makeChunk(_ data: Data, offset: Int, count: Int) -> Data {
        if offset == 0, count == data.count { return data }
        return data.subdata(in: offset..<(offset + count))
    }

    private func output(chunks: [Data] = []) -> Output {
        var suspendTask = false
        var resumeTask = false
        let needsSuspension = !terminal && !inputCompleted &&
            (credits == 0 || !deferredSources.isEmpty)
        if needsSuspension {
            if suspended {
                redundantSuspendChecks += 1
            } else {
                suspended = true
                suspendTransitions += 1
                suspendTask = true
            }
        } else if suspended && credits > 0 &&
                    pendingChunks.isEmpty && deferredSources.isEmpty &&
                    (!inputCompleted || completionRequested) {
            suspended = false
            resumeTransitions += 1
            resumeTask = true
        }

        var completed = false
        if completionRequested && inputCompleted && isDrained && !suspended && !completionEmitted {
            completionEmitted = true
            completed = true
        }
        return Output(
            chunks: chunks,
            suspendTask: suspendTask,
            resumeTask: resumeTask,
            completed: completed,
            snapshot: makeSnapshot()
        )
    }

    private func output() -> Output {
        output(chunks: [])
    }

    private func makeSnapshot() -> Snapshot {
        let deferredBytes = deferredSources.reduce(0) { total, source in
            total + source.data.count - source.offset
        }
        return Snapshot(
            credits: credits,
            pendingChunkCount: pendingChunks.count,
            pendingBytes: pendingBytes,
            deferredBytes: deferredBytes,
            retainedBytes: pendingBytes + deferredBytes,
            suspended: suspended,
            inputCompleted: inputCompleted,
            completionRequested: completionRequested,
            terminal: terminal,
            suspendTransitions: suspendTransitions,
            resumeTransitions: resumeTransitions,
            redundantSuspendChecks: redundantSuspendChecks
        )
    }
}
