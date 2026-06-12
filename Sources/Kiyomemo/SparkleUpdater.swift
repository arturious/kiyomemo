import Sparkle

@MainActor
final class SparkleUpdater: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = SparkleUpdater()

    @Published private(set) var updateMessage: String?

    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: self,
        userDriverDelegate: nil
    )

    private override init() {
        super.init()
        _ = controller
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    func consumeUpdateMessage() -> String? {
        defer { updateMessage = nil }
        return updateMessage
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        updateMessage = "Update \(item.displayVersionString) available"
    }
}
