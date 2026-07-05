import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let collectionQueue = DispatchQueue(label: "com.linkvaultq8.share.collection")
    private var didStartExtraction = false
    private var didComplete = false
    private var didStartOpen = false

    private struct SharedPayload {
        var url: String?
        var title: String?
        var text: String?
    }

    private var payload = SharedPayload()

    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let previewLabel = UILabel()
    private let openButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !didStartExtraction {
            didStartExtraction = true
            extractSharedContent()
        }
    }

    private func configureUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.28)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(red: 0.10, green: 0.11, blue: 0.14, alpha: 1.0) : UIColor.white
        }
        cardView.layer.cornerRadius = 20
        cardView.layer.masksToBounds = true
        view.addSubview(cardView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "LinkVault Q8"
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.numberOfLines = 1

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.text = "جاري قراءة الرابط..."
        messageLabel.textAlignment = .center
        messageLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        messageLabel.numberOfLines = 0

        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.text = ""
        previewLabel.textAlignment = .center
        previewLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        previewLabel.textColor = .secondaryLabel
        previewLabel.numberOfLines = 3

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()

        openButton.translatesAutoresizingMaskIntoConstraints = false
        openButton.setTitle("فتح في LinkVault", for: .normal)
        openButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        openButton.isEnabled = false
        openButton.addTarget(self, action: #selector(openButtonTapped), for: .touchUpInside)

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("إغلاق", for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [openButton, cancelButton])
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .vertical
        buttonStack.spacing = 10
        buttonStack.alignment = .fill

        [titleLabel, messageLabel, previewLabel, activityIndicator, buttonStack].forEach { cardView.addSubview($0) }

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            cardView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            messageLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),

            previewLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 10),
            previewLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            previewLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),

            activityIndicator.topAnchor.constraint(equalTo: previewLabel.bottomAnchor, constant: 16),
            activityIndicator.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),

            buttonStack.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 18),
            buttonStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -22)
        ])
    }

    private func extractSharedContent() {
        let inputItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        guard !inputItems.isEmpty else {
            showNoContentState()
            return
        }

        let group = DispatchGroup()

        for item in inputItems {
            if let attributedTitle = item.attributedTitle?.string, !attributedTitle.isEmpty {
                mergePayload(title: attributedTitle)
            }

            if let attributedText = item.attributedContentText?.string, !attributedText.isEmpty {
                mergePayload(text: attributedText)
                if let foundURL = Self.firstURL(in: attributedText) {
                    mergePayload(url: foundURL)
                }
            }

            for provider in item.attachments ?? [] {
                loadURLIfAvailable(from: provider, group: group)
                loadTextIfAvailable(from: provider, group: group)
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.finishExtractionAndUpdateUI()
        }

        // Safety fallback: even if a host app never calls an NSItemProvider callback,
        // keep the extension responsive and give the user a visible close button.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.finishExtractionAndUpdateUI()
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
                self?.mergePayload(text: text)
                if let foundURL = Self.firstURL(in: text) { self?.mergePayload(url: foundURL) }
            } else if let data = value as? Data, let text = String(data: data, encoding: .utf8) {
                self?.mergePayload(text: text)
                if let foundURL = Self.firstURL(in: text) { self?.mergePayload(url: foundURL) }
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
                if let foundURL = Self.firstURL(in: text) { self?.mergePayload(url: foundURL) }
            } else if let data = value as? Data, let text = String(data: data, encoding: .utf8) {
                self?.mergePayload(text: text)
                if let foundURL = Self.firstURL(in: text) { self?.mergePayload(url: foundURL) }
            }
        }
    }

    private func mergePayload(url: String? = nil, title: String? = nil, text: String? = nil) {
        collectionQueue.async { [weak self] in
            guard let self else { return }

            if let url = url?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty {
                self.payload.url = url
            }
            if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty, self.payload.title == nil {
                self.payload.title = title
            }
            if let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty, self.payload.text == nil {
                self.payload.text = text
            }
        }
    }

    private func finishExtractionAndUpdateUI() {
        collectionQueue.async { [weak self] in
            guard let self else { return }
            let currentPayload = self.payload
            DispatchQueue.main.async {
                self.updateUI(for: currentPayload)
            }
        }
    }

    private func updateUI(for payload: SharedPayload) {
        let candidate = payload.url ?? Self.firstURL(in: payload.text ?? "")
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true

        if let candidate, !candidate.isEmpty {
            messageLabel.text = "تم العثور على الرابط. اضغط فتح لإرساله إلى التطبيق."
            previewLabel.text = candidate
            openButton.isEnabled = true
        } else if let text = payload.text, !text.isEmpty {
            messageLabel.text = "تم العثور على نص فقط. اضغط فتح لإرساله إلى التطبيق."
            previewLabel.text = text
            openButton.isEnabled = true
        } else {
            showNoContentState()
        }
    }

    private func showNoContentState() {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        messageLabel.text = "ما قدرنا نقرأ رابط من المشاركة."
        previewLabel.text = "جرّب المشاركة من Safari أو انسخ الرابط كنص."
        openButton.isEnabled = false
    }

    @objc private func openButtonTapped() {
        if didComplete || didStartOpen { return }
        didStartOpen = true
        openButton.isEnabled = false
        messageLabel.text = "يتم فتح LinkVault..."

        collectionQueue.async { [weak self] in
            guard let self else { return }
            let currentPayload = self.payload
            DispatchQueue.main.async {
                self.openContainingApp(payload: currentPayload)
            }
        }
    }

    @objc private func cancelButtonTapped() {
        completeOnce()
    }

    private func openContainingApp(payload: SharedPayload) {
        let deepLinks = makeDeepLinks(payload: payload)
        guard let primaryDeepLink = deepLinks.first else {
            showOpenFailedState()
            return
        }

        // 1) First try the responder-chain route. It is the most reliable route
        // for iOS Share Extensions when opening the containing app by URL scheme.
        var didAskSystemToOpen = false
        for link in deepLinks {
            didAskSystemToOpen = openURLThroughResponderChain(link) || didAskSystemToOpen
        }

        // 2) Also ask the extension context to open the primary URL. Some iOS
        // versions prefer this API, while others ignore it for Share Extensions.
        extensionContext?.open(primaryDeepLink) { [weak self] success in
            DispatchQueue.main.async {
                guard let self else { return }
                if success || didAskSystemToOpen {
                    self.completeOnce(retryOpening: success ? [] : deepLinks)
                } else if !self.didComplete {
                    self.showOpenFailedState()
                }
            }
        }

        // 3) Safety close + retry. Some Share Extension hosts ignore open(_:)
        // until the extension is dismissed. In that case we complete the request
        // and retry the URL-scheme open from the completion handler.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self, !self.didComplete else { return }
            if didAskSystemToOpen {
                self.completeOnce(retryOpening: deepLinks)
            } else {
                self.showOpenFailedState()
            }
        }
    }

    private func makeDeepLinks(payload: SharedPayload) -> [URL] {
        let extractedURL = payload.url ?? Self.firstURL(in: payload.text ?? "") ?? ""
        let title = payload.title ?? ""
        let text = payload.text ?? ""
        let schemes = ["linkvaultq8", "linkvault"]

        return schemes.compactMap { scheme in
            var components = URLComponents()
            components.scheme = scheme
            components.host = "share"
            components.queryItems = [
                URLQueryItem(name: "url", value: extractedURL),
                URLQueryItem(name: "title", value: title),
                URLQueryItem(name: "text", value: text)
            ]
            return components.url
        }
    }

    @discardableResult
    private func openURLThroughResponderChain(_ url: URL) -> Bool {
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self

        while let currentResponder = responder {
            if currentResponder.responds(to: selector) {
                _ = currentResponder.perform(selector, with: url)
                return true
            }
            responder = currentResponder.next
        }

        return false
    }

    private func showOpenFailedState() {
        openButton.isEnabled = true
        cancelButton.isEnabled = true
        didStartOpen = false
        messageLabel.text = "ما قدرنا نفتح LinkVault تلقائيًا. تأكد أن التطبيق مثبت من TestFlight ثم جرّب مرة ثانية."
    }

    private func completeOnce(retryOpening deepLinks: [URL] = []) {
        if didComplete { return }
        didComplete = true
        let linksToRetry = deepLinks
        extensionContext?.completeRequest(returningItems: nil) { [weak self] _ in
            guard let self, !linksToRetry.isEmpty else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                for link in linksToRetry {
                    if self.openURLThroughResponderChain(link) { break }
                }
            }
        }
    }

    private static func firstURL(in text: String) -> String? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.firstMatch(in: text, options: [], range: range)?.url?.absoluteString
    }
}
