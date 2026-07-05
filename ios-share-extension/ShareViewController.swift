import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private var didStartOpenFlow = false
    private var didComplete = false
    private var didFinishExtraction = false
    private let collectionQueue = DispatchQueue(label: "com.linkvaultq8.share.collection")

    private struct SharedPayload {
        var url: String?
        var title: String?
        var text: String?
    }

    private var payload = SharedPayload()
    private var statusLabel: UILabel?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
        showLoadingView()
        extractSharedContent()
    }

    private func showLoadingView() {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "جاري إرسال الرابط إلى LinkVault..."
        label.textAlignment = .center
        label.textColor = .white
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        view.addSubview(label)
        statusLabel = label

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func extractSharedContent() {
        let inputItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        guard !inputItems.isEmpty else {
            openContainingAppWithCurrentPayload()
            return
        }

        let group = DispatchGroup()

        for item in inputItems {
            if let attributedTitle = item.attributedTitle?.string, !attributedTitle.isEmpty {
                mergePayload(title: attributedTitle)
            }

            if let attributedText = item.attributedContentText?.string, !attributedText.isEmpty {
                mergePayload(text: attributedText)
            }

            for provider in item.attachments ?? [] {
                loadURLIfAvailable(from: provider, group: group)
                loadTextIfAvailable(from: provider, group: group)
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.finishExtractionAndOpen()
        }

        // Some host apps occasionally do not call one of the NSItemProvider callbacks.
        // Never leave the host app stuck behind the share extension.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.finishExtractionAndOpen()
        }
    }

    private func loadURLIfAvailable(from provider: NSItemProvider, group: DispatchGroup) {
        guard provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) else { return }

        group.enter()
        provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] value, _ in
            defer { group.leave() }

            if let url = value as? URL {
                self?.mergePayload(url: url.absoluteString)
            } else if let nsurl = value as? NSURL {
                self?.mergePayload(url: nsurl.absoluteString)
            } else if let text = value as? String {
                self?.mergePayload(url: Self.firstURL(in: text) ?? text)
            }
        }
    }

    private func loadTextIfAvailable(from provider: NSItemProvider, group: DispatchGroup) {
        let identifiers = [UTType.plainText.identifier, UTType.text.identifier, "public.utf8-plain-text"]
        guard let identifier = identifiers.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else { return }

        group.enter()
        provider.loadItem(forTypeIdentifier: identifier, options: nil) { [weak self] value, _ in
            defer { group.leave() }

            if let text = value as? String {
                self?.mergePayload(text: text)
                if let foundURL = Self.firstURL(in: text) {
                    self?.mergePayload(url: foundURL)
                }
            } else if let data = value as? Data, let text = String(data: data, encoding: .utf8) {
                self?.mergePayload(text: text)
                if let foundURL = Self.firstURL(in: text) {
                    self?.mergePayload(url: foundURL)
                }
            }
        }
    }

    private func mergePayload(url: String? = nil, title: String? = nil, text: String? = nil) {
        collectionQueue.async { [weak self] in
            guard let self else { return }

            if let url, !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.payload.url = url
            }
            if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, self.payload.title == nil {
                self.payload.title = title
            }
            if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, self.payload.text == nil {
                self.payload.text = text
            }
        }
    }

    private func finishExtractionAndOpen() {
        if didFinishExtraction || didStartOpenFlow || didComplete { return }
        didFinishExtraction = true

        collectionQueue.async { [weak self] in
            DispatchQueue.main.async {
                self?.openContainingAppWithCurrentPayload()
            }
        }
    }

    private func openContainingAppWithCurrentPayload() {
        if didStartOpenFlow || didComplete { return }
        didStartOpenFlow = true
        statusLabel?.text = "يتم فتح LinkVault..."

        collectionQueue.async { [weak self] in
            guard let self else { return }
            let currentPayload = self.payload

            DispatchQueue.main.async {
                self.openContainingApp(payload: currentPayload)
            }
        }
    }

    private func openContainingApp(payload: SharedPayload) {
        var components = URLComponents()
        components.scheme = "linkvault"
        components.host = "share"

        let extractedURL = payload.url ?? Self.firstURL(in: payload.text ?? "") ?? ""
        components.queryItems = [
            URLQueryItem(name: "url", value: extractedURL),
            URLQueryItem(name: "title", value: payload.title ?? ""),
            URLQueryItem(name: "text", value: payload.text ?? "")
        ]

        guard let deepLink = components.url else {
            completeOnce()
            return
        }

        // Critical runtime fix: do not wait forever for the host app/open callback.
        // The share extension must always complete so Safari/Notes/etc. never freeze.
        extensionContext?.open(deepLink) { [weak self] _ in
            self?.completeOnce()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.completeOnce()
        }
    }

    private func completeOnce() {
        if didComplete { return }
        didComplete = true
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private static func firstURL(in text: String) -> String? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.firstMatch(in: text, options: [], range: range)?.url?.absoluteString
    }
}
