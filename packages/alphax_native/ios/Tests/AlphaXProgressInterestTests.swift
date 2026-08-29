import Foundation

@main
struct AlphaXProgressInterestTests {
    static func main() {
        let none = AlphaXProgressInterest(arguments: [:])
        let downloadOnly = AlphaXProgressInterest(arguments: [
            "downloadProgressRequested": true,
        ])
        let uploadOnly = AlphaXProgressInterest(arguments: [
            "uploadProgressRequested": true,
        ])

        require(!none.isRequested(direction: "download"), "no observer must suppress download progress")
        require(!none.isRequested(direction: "upload"), "no observer must suppress upload progress")
        require(downloadOnly.isRequested(direction: "download"), "download interest must be enabled")
        require(!downloadOnly.isRequested(direction: "upload"), "download interest must not enable upload")
        require(!uploadOnly.isRequested(direction: "download"), "upload interest must not enable download")
        require(uploadOnly.isRequested(direction: "upload"), "upload interest must be enabled")
        require(!downloadOnly.isRequested(direction: "unknown"), "unknown direction must be suppressed")
        print("AlphaX Apple progress-interest tests passed")
    }

    private static func require(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) {
        precondition(condition(), message)
    }
}
