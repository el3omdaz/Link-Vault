import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let appGroupId = "group.com.linkvaultq8.shared"
    private let collectionQueue = DispatchQueue(label: "com.linkvaultq8.share.collection")
    private var didStartExtraction = false
    private var didComplete = false
    private var didStartSave = false

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
    private let saveButton = UIButton(type: .system)
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

        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.setTitle("حفظ في LinkVault", for: .normal)
        saveButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        saveButton.isEnabled = false
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("إغلاق", for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [saveButton, cancelButton])
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
            messageLabel.text = "تم العثور على الرابط. اضغط حفظ، ثم افتح LinkVault إذا ما انتقل تلقائيًا."
            previewLabel.text = candidate
            saveButton.isEnabled = true
        } else if let text = payload.text, !text.isEmpty {
            messageLabel.text = "تم العثور على النص. اضغط حفظ، ثم افتح LinkVault إذا ما انتقل تلقائيًا."
            previewLabel.text = text
            saveButton.isEnabled = true
        } else {
            showNoContentState()
        }
    }

    private func showNoContentState() {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        messageLabel.text = "ما قدرنا نقرأ رابط من المشاركة."
        previewLabel.text = "جرّب المشاركة من Safari أو انسخ الرابط كنص."
        saveButton.isEnabled = false
    }

    @objc private func saveButtonTapped() {
        if didComplete || didStartSave { return }
        didStartSave = true
        saveButton.isEnabled = false
        cancelButton.isEnabled = false
        messageLabel.text = "جاري حفظ الرابط..."

        collectionQueue.async { [weak self] in
            guard let self else { return }
            let currentPayload = self.payload
            let saved = self.savePayloadToAppGroup(currentPayload)
            DispatchQueue.main.async {
                self.previewLabel.text = currentPayload.url ?? Self.firstURL(in: currentPayload.text ?? "") ?? currentPayload.text ?? ""
                if saved {
                    self.messageLabel.text = "تم الحفظ. إذا ما انتقل التطبيق تلقائيًا، افتح LinkVault وسيظهر الرابط."
                } else {
                    self.messageLabel.text = "تعذر حفظ النسخة الاحتياطية. جاري محاولة فتح LinkVault بالرابط مباشرة..."
                }
                self.openContainingApp(with: currentPayload, appGroupSaved: saved)
            }
        }
    }

    private func openContainingApp(with payload: SharedPayload, appGroupSaved: Bool) {
        guard let deepLink = makeDeepLinkURL(from: payload) else {
            if appGroupSaved {
                messageLabel.text = "تم الحفظ. افتح LinkVault وسيظهر الرابط تلقائيًا."
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    self?.completeOnce()
                }
            } else {
                didStartSave = false
                saveButton.isEnabled = true
                cancelButton.isEnabled = true
                messageLabel.text = "تعذر تجهيز الرابط للفتح. جرّب مرة ثانية."
            }
            return
        }

        guard let context = extensionContext else {
            if appGroupSaved {
                messageLabel.text = "تم حفظ الرابط. افتح LinkVault يدويًا وسيظهر تلقائيًا."
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                    self?.completeOnce()
                }
            } else {
                didStartSave = false
                saveButton.isEnabled = true
                cancelButton.isEnabled = true
                messageLabel.text = "تعذر فتح LinkVault. جرّب مرة ثانية."
            }
            return
        }

        context.open(deepLink, completionHandler: { [weak self] success in
            DispatchQueue.main.async {
                guard let self else { return }
                if success {
                    self.messageLabel.text = "تم فتح LinkVault."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                        self?.completeOnce()
                    }
                } else if appGroupSaved {
                    self.messageLabel.text = "تم حفظ الرابط. افتح LinkVault يدويًا وسيظهر تلقائيًا."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                        self?.completeOnce()
                    }
                } else {
                    self.didStartSave = false
                    self.saveButton.isEnabled = true
                    self.cancelButton.isEnabled = true
                    self.messageLabel.text = "تعذر فتح LinkVault. تأكد من تثبيت التطبيق ثم جرّب مرة ثانية."
                }
            }
        })
    }

    private func makeDeepLinkURL(from payload: SharedPayload) -> URL? {
        let extractedURL = payload.url ?? Self.firstURL(in: payload.text ?? "") ?? ""
        let text = payload.text ?? ""
        let title = payload.title ?? ""

        guard !extractedURL.isEmpty || !text.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = "linkvaultq8"
        components.host = "share"

        var queryItems = [URLQueryItem]()
        if !extractedURL.isEmpty { queryItems.append(URLQueryItem(name: "url", value: extractedURL)) }
        if !title.isEmpty { queryItems.append(URLQueryItem(name: "title", value: title)) }
        if extractedURL.isEmpty && !text.isEmpty { queryItems.append(URLQueryItem(name: "text", value: text)) }
        queryItems.append(URLQueryItem(name: "source", value: "share_extension"))
        queryItems.append(URLQueryItem(name: "ts", value: String(Int(Date().timeIntervalSince1970))))
        components.queryItems = queryItems

        return components.url
    }

    @objc private func cancelButtonTapped() {
        completeOnce()
    }

    private func savePayloadToAppGroup(_ payload: SharedPayload) -> Bool {
        let extractedURL = payload.url ?? Self.firstURL(in: payload.text ?? "") ?? ""
        let text = payload.text ?? ""
        let title = payload.title ?? ""

        guard !extractedURL.isEmpty || !text.isEmpty else { return false }

        // A nil suite here is the one real hard-failure case worth surfacing:
        // the App Group identifier is malformed, or the entitlement is
        // completely absent for this extension.
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return false }

        defaults.set(extractedURL, forKey: "linkvault.pendingShare.url")
        defaults.set(title, forKey: "linkvault.pendingShare.title")
        defaults.set(text, forKey: "linkvault.pendingShare.text")
        defaults.set(Date().timeIntervalSince1970, forKey: "linkvault.pendingShare.timestamp")

        // NOTE: we deliberately do NOT gate success on synchronize()'s return
        // value anymore. synchronize() has been deprecated since iOS 12 —
        // Apple's own docs say plainly that it "is unnecessary and shouldn't
        // be used" — because the OS now persists UserDefaults automatically
        // in the background. Its return value no longer reliably reflects
        // whether the set() calls above actually persisted, so using it here
        // was producing a false "تعذر حفظ الرابط" error even when the App
        // Group write genuinely succeeded. We still call it (harmless) but
        // no longer trust what it returns.
        defaults.synchronize()
        return true
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
