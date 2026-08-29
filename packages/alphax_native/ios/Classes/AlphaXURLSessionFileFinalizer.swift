import Foundation

/// Private file-finalization seam for URLSession download tasks.
///
/// FileManager owns the platform-specific replacement behavior. AlphaX does
/// not promise that this operation is atomic across all supported file
/// systems; it only reports success after the final target operation succeeds.
internal enum AlphaXURLSessionFileFinalizer {
    static func finalize(
        location: URL,
        target: URL,
        fileManager: FileManager = .default
    ) throws {
        let parent = target.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: parent,
            withIntermediateDirectories: true,
            attributes: nil
        )
        if fileManager.fileExists(atPath: target.path) {
            _ = try fileManager.replaceItemAt(
                target,
                withItemAt: location,
                backupItemName: nil,
                options: []
            )
        } else {
            try fileManager.moveItem(at: location, to: target)
        }
    }
}
