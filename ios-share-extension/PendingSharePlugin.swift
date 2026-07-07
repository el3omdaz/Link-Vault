import Foundation
import Capacitor

@objc(PendingSharePlugin)
public class PendingSharePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "PendingSharePlugin"
    public let jsName = "PendingShare"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "getPendingShare", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "clearPendingShare", returnType: CAPPluginReturnPromise)
    ]

    private let appGroupId = "group.com.linkvaultq8.shared"
    private let urlKey = "linkvault.pendingShare.url"
    private let titleKey = "linkvault.pendingShare.title"
    private let textKey = "linkvault.pendingShare.text"
    private let timestampKey = "linkvault.pendingShare.timestamp"

    @objc func getPendingShare(_ call: CAPPluginCall) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            call.resolve(["hasShare": false])
            return
        }

        let url = defaults.string(forKey: urlKey) ?? ""
        let title = defaults.string(forKey: titleKey) ?? ""
        let text = defaults.string(forKey: textKey) ?? ""
        let timestamp = defaults.double(forKey: timestampKey)

        guard !url.isEmpty || !text.isEmpty else {
            call.resolve(["hasShare": false])
            return
        }

        // Do not clear here. The web app clears the pending share only after it
        // actually opens the Add Link flow. Clearing during read can lose the
        // URL if the JavaScript boot sequence, router, or modal initialization
        // fails before the share is consumed.
        call.resolve([
            "hasShare": true,
            "url": url,
            "title": title,
            "text": text,
            "timestamp": timestamp
        ])
    }

    @objc func clearPendingShare(_ call: CAPPluginCall) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            call.resolve(["cleared": false])
            return
        }
        clear(defaults)
        call.resolve(["cleared": true])
    }

    private func clear(_ defaults: UserDefaults) {
        defaults.removeObject(forKey: urlKey)
        defaults.removeObject(forKey: titleKey)
        defaults.removeObject(forKey: textKey)
        defaults.removeObject(forKey: timestampKey)
        defaults.synchronize()
    }
}
