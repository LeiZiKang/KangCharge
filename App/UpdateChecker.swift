import Foundation
import SwiftUI

/// Lightweight, zero-dependency release checker against GitHub Releases.
/// Runs silently at most once per 24 hours on launch, fails silently when offline,
/// and never interrupts active work.
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String, url: URL, notes: String?)
        case failed
    }

    private enum Key {
        static let autoCheck = "kc.autoCheckUpdates"
        static let lastChecked = "kc.lastUpdateCheck"
    }

    private let releasesAPI = URL(string: "https://api.github.com/repos/LeiZiKang/KangCharge/releases/latest")!
    private let fallbackReleasesPage = URL(string: "https://github.com/LeiZiKang/KangCharge/releases")!

    @Published var autoCheckEnabled: Bool {
        didSet { UserDefaults.standard.set(autoCheckEnabled, forKey: Key.autoCheck) }
    }
    @Published var status: Status = .idle

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0.0"
    }

    private init() {
        let defaults = UserDefaults.standard
        self.autoCheckEnabled = defaults.object(forKey: Key.autoCheck) as? Bool ?? true
    }

    func checkOnLaunchIfNeeded() {
        guard autoCheckEnabled else { return }
        if let last = UserDefaults.standard.object(forKey: Key.lastChecked) as? Date,
           Date().timeIntervalSince(last) < 24 * 3600 {
            return
        }
        Task { await checkNow(silent: true) }
    }

    func checkNow(silent: Bool = false) async {
        if !silent { status = .checking }
        var request = URLRequest(url: releasesAPI)
        request.timeoutInterval = 10
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("KangCharge/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.urlCache = nil
        let session = URLSession(configuration: config)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                if !silent { status = .upToDate }
                return
            }
            struct Release: Decodable {
                let tagName: String
                let htmlUrl: String
                let body: String?
            }
            let release = try JSONDecoder.snakeCase.decode(Release.self, from: data)
            UserDefaults.standard.set(Date(), forKey: Key.lastChecked)

            let remote = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            if Self.isNewer(remote, than: currentVersion) {
                let url = URL(string: release.htmlUrl) ?? fallbackReleasesPage
                status = .available(version: remote, url: url, notes: release.body)
            } else if !silent {
                status = .upToDate
            }
        } catch {
            if !silent { status = .failed }
        }
    }

    private static func isNewer(_ remote: String, than local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        let count = max(r.count, l.count)
        for i in 0..<count {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv != lv { return rv > lv }
        }
        return false
    }
}
