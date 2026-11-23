import UIKit
import WatchConnectivity

/// Sends only configuration; the watch fetches its own charger readings.
final class WatchSync: NSObject, WCSessionDelegate {
    static let shared = WatchSync()
    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        NotificationCenter.default.addObserver(self, selector: #selector(push),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @objc func push() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        // Property-list payloads cannot contain nil. Empty strings explicitly clear values.
        let context: [String: Any] = ["serverURL": AppConfig.serverURL?.absoluteString ?? "",
                                      "demo": ChargerSource.isDemo,
                                      "nickname": AppConfig.customDeviceName ?? ""]
        try? session.updateApplicationContext(context)
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated { push() }
    }
    func sessionWatchStateDidChange(_ session: WCSession) { push() }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
