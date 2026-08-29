import Foundation

/// Operation-local progress interest; never shared between requests.
internal struct AlphaXProgressInterest {
    let downloadRequested: Bool
    let uploadRequested: Bool

    init(arguments: [String: Any]) {
        downloadRequested = arguments["downloadProgressRequested"] as? Bool ?? false
        uploadRequested = arguments["uploadProgressRequested"] as? Bool ?? false
    }

    func isRequested(direction: String) -> Bool {
        switch direction {
        case "download": return downloadRequested
        case "upload": return uploadRequested
        default: return false
        }
    }
}
