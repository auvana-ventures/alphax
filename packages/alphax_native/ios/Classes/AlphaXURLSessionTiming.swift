import Foundation

/// Internal URLSession timing conversion helpers.
///
/// URLSession exposes phase durations as `TimeInterval` values in seconds.
/// The native adapter's metric contract names these fields in milliseconds.
/// Keep the conversion in one small seam so unit tests can exercise the unit
/// boundary without constructing URLSessionTaskMetrics.
internal enum AlphaXURLSessionTiming {
    static func interval(_ start: Date?, _ end: Date?) -> Int? {
        guard let start, let end else { return nil }
        return milliseconds(end.timeIntervalSince(start))
    }

    static func milliseconds(_ interval: TimeInterval) -> Int? {
        guard interval.isFinite, interval >= 0 else { return nil }
        let value = interval * 1000
        guard value <= Double(Int.max) else { return nil }
        return Int(value.rounded())
    }
}
