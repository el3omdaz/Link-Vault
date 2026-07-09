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
    private let pendingSharesKey = "linkvault.pendingShares.v2"

    private let legacyURLKey = "linkvault.pendingShare.url"
    private let legacyTitleKey = "linkvault.pendingShare.title"
    private let legacyTextKey = "linkvault.pendingShare.text"
    private let legacyNoteKey = "linkvault.pendingShare.note"
    private let legacyCategoryKey = "linkvault.pendingShare.category"
    private let legacyTimestampKey = "linkvault.pendingShare.timestamp"

    private struct PendingShareRecord: Codable {
        let id: String
        let url: String
        let title: String
        let text: String
        let note: String
        let category: String
        let timestamp: Double

        var dictionary: [String: Any] {
            [
                "id": id,
                "url": url,
                "title": title,
                "text": text,
                "note": note,
                "cat": category,
                "timestamp": timestamp
            ]
        }
    }

    @objc func getPendingShare(_ call: CAPPluginCall) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            call.resolve(["hasShare": false, "shares": []])
            return
        }

        var records = loadRecords(from: defaults)
        if let legacy = legacyRecord(from: defaults) {
            records.append(legacy)
            records.sort { $0.timestamp < $1.timestamp }
            saveRecords(records, to: defaults)
            clearLegacy(defaults)
        }

        guard let first = records.first else {
            call.resolve(["hasShare": false, "shares": [], "count": 0])
            return
        }

        call.resolve([
            "hasShare": true,
            "count": records.count,
            "shares": records.map { $0.dictionary },
            "url": first.url,
            "title": first.title,
            "text": first.text,
            "note": first.note,
            "cat": first.category,
            "timestamp": first.timestamp
        ])
    }

    @objc func clearPendingShare(_ call: CAPPluginCall) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            call.resolve(["cleared": false, "remaining": 0])
            return
        }

        let cutoff = call.getDouble("upToTimestamp") ?? Double.greatestFiniteMagnitude
        let records = loadRecords(from: defaults)
        let remaining = records.filter { $0.timestamp > cutoff }
        saveRecords(remaining, to: defaults)

        let legacyTimestamp = defaults.double(forKey: legacyTimestampKey)
        if cutoff == Double.greatestFiniteMagnitude || legacyTimestamp <= cutoff {
            clearLegacy(defaults)
        }

        defaults.synchronize()
        call.resolve(["cleared": true, "remaining": remaining.count])
    }

    private func loadRecords(from defaults: UserDefaults) -> [PendingShareRecord] {
        guard let data = defaults.data(forKey: pendingSharesKey),
              let records = try? JSONDecoder().decode([PendingShareRecord].self, from: data) else {
            return []
        }
        return records.sorted { $0.timestamp < $1.timestamp }
    }

    private func saveRecords(_ records: [PendingShareRecord], to defaults: UserDefaults) {
        if records.isEmpty {
            defaults.removeObject(forKey: pendingSharesKey)
            return
        }
        if let encoded = try? JSONEncoder().encode(records) {
            defaults.set(encoded, forKey: pendingSharesKey)
        }
    }

    private func legacyRecord(from defaults: UserDefaults) -> PendingShareRecord? {
        let url = defaults.string(forKey: legacyURLKey) ?? ""
        let text = defaults.string(forKey: legacyTextKey) ?? ""
        guard !url.isEmpty || !text.isEmpty else { return nil }

        let timestamp = defaults.double(forKey: legacyTimestampKey)
        return PendingShareRecord(
            id: UUID().uuidString,
            url: url,
            title: defaults.string(forKey: legacyTitleKey) ?? "",
            text: text,
            note: defaults.string(forKey: legacyNoteKey) ?? "",
            category: defaults.string(forKey: legacyCategoryKey) ?? "",
            timestamp: timestamp > 0 ? timestamp : Date().timeIntervalSince1970
        )
    }

    private func clearLegacy(_ defaults: UserDefaults) {
        defaults.removeObject(forKey: legacyURLKey)
        defaults.removeObject(forKey: legacyTitleKey)
        defaults.removeObject(forKey: legacyTextKey)
        defaults.removeObject(forKey: legacyNoteKey)
        defaults.removeObject(forKey: legacyCategoryKey)
        defaults.removeObject(forKey: legacyTimestampKey)
    }
}
