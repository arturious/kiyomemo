import Sparkle

@MainActor
final class SparkleUpdater {
    static let shared = SparkleUpdater()

    private let controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    private init() {}

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
