import WatchConnectivity
import WidgetKit

final class WatchSync: NSObject, WCSessionDelegate {
    private let model: WatchModel

    @MainActor init(model: WatchModel) {
        self.model = model
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated, !session.receivedApplicationContext.isEmpty {
            receive(session.receivedApplicationContext)
        }
    }
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        receive(applicationContext)
    }
    private func receive(_ context: [String: Any]) {
        guard let demo = context["demo"] as? Bool else { return }
        let url = (context["serverURL"] as? String).flatMap(AppConfig.validatedServerURL)
        let nickname = context["nickname"] as? String
        Task { @MainActor in
            await model.applyConfiguration(url: url, demo: demo, nickname: nickname)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
