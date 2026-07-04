import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private var didOpenApp = false

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
        label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func extractSharedContent() {
        guard let inputItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            completeWithoutContent()
            return
        }

        var collectedURL: String?
        var collectedText: String?
        var collectedTitle: String?
        let group = DispatchGroup()

        for item in inputItems {
            if let attributedTitle = item.attributedTitle?.string, !attributedTitle.isEmpty {
                collectedTitle = attributedTitle
            }
            if let attributedText = item.attributedContentText?.string, !attributedText.isEmpty {
                collectedText = attributedText
            }

            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { value, _ in
                        if let url = value as? URL {
                            collectedURL = url.absoluteString
                        } else if let text = value as? String {
                            collectedURL = text
                        }
                        group.leave()
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { value, _ in
                        if let text = value as? String {
                            if collectedText == nil { collectedText = text }
                            if collectedURL == nil { collectedURL = Self.firstURL(in: text) }
                        }
                        group.leave()
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { value, _ in
                        if let text = value as? String {
                            if collectedText == nil { collectedText = text }
                            if collectedURL == nil { collectedURL = Self.firstURL(in: text) }
                        }
                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.openContainingApp(url: collectedURL, title: collectedTitle, text: collectedText)
        }
    }

    private func openContainingApp(url: String?, title: String?, text: String?) {
        if didOpenApp { return }
        didOpenApp = true

        var components = URLComponents()
        components.scheme = "linkvault"
        components.host = "share"
        components.queryItems = [
            URLQueryItem(name: "url", value: url ?? ""),
            URLQueryItem(name: "title", value: title ?? ""),
            URLQueryItem(name: "text", value: text ?? "")
        ]

        guard let deepLink = components.url else {
            completeWithoutContent()
            return
        }

        extensionContext?.open(deepLink) { [weak self] _ in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }

    private func completeWithoutContent() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private static func firstURL(in text: String) -> String? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.firstMatch(in: text, options: [], range: range)?.url?.absoluteString
    }
}
