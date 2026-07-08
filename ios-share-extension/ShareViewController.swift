
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController, UITextViewDelegate {
    private let appGroupId = "group.com.linkvaultq8.shared"
    private let collectionQueue = DispatchQueue(label: "com.linkvaultq8.share.collection")
    private var didStartExtraction = false
    private var didComplete = false
    private var didStartSave = false
    private var selectedCategory: String? = nil
    private var categoryButtons: [UIButton] = []

    private struct SharedPayload {
        var url: String?
        var title: String?
        var text: String?
        var note: String?
        var category: String?
    }

    private var payload = SharedPayload()

    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let previewBox = UIView()
    private let previewTitleLabel = UILabel()
    private let previewURLLabel = UILabel()
    private let titleField = UITextField()
    private let categoryStack = UIStackView()
    private let noteTextView = UITextView()
    private let notePlaceholder = UILabel()
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
        view.backgroundColor = UIColor.black.withAlphaComponent(0.32)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.10, green: 0.11, blue: 0.15, alpha: 1.0)
            : UIColor.white
        }
        cardView.layer.cornerRadius = 24
        cardView.layer.masksToBounds = true
        view.addSubview(cardView)

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        cardView.addSubview(stack)

        titleLabel.text = "حفظ الرابط"
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)

        subtitleLabel.text = "LinkVault Q8"
        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        subtitleLabel.numberOfLines = 0

        activityIndicator.startAnimating()

        previewBox.backgroundColor = UIColor.secondarySystemBackground
        previewBox.layer.cornerRadius = 14
        previewBox.layer.borderWidth = 1
        previewBox.layer.borderColor = UIColor.separator.cgColor
        previewBox.translatesAutoresizingMaskIntoConstraints = false

        previewTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        previewTitleLabel.text = "جاري قراءة الرابط..."
        previewTitleLabel.textAlignment = .right
        previewTitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        previewTitleLabel.numberOfLines = 2

        previewURLLabel.translatesAutoresizingMaskIntoConstraints = false
        previewURLLabel.text = ""
        previewURLLabel.textAlignment = .right
        previewURLLabel.textColor = .secondaryLabel
        previewURLLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        previewURLLabel.numberOfLines = 2

        previewBox.addSubview(previewTitleLabel)
        previewBox.addSubview(previewURLLabel)

        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.placeholder = "العنوان"
        titleField.textAlignment = .right
        titleField.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleField.backgroundColor = UIColor.secondarySystemBackground
        titleField.layer.cornerRadius = 12
        titleField.layer.borderWidth = 1
        titleField.layer.borderColor = UIColor.separator.cgColor
        titleField.clearButtonMode = .whileEditing
        titleField.setPadding(left: 12, right: 12)

        categoryStack.axis = .horizontal
        categoryStack.spacing = 8
        categoryStack.distribution = .fillEqually
        categoryStack.alignment = .fill
        buildCategoryButtons()

        let noteWrap = UIView()
        noteWrap.translatesAutoresizingMaskIntoConstraints = false
        noteWrap.backgroundColor = UIColor.secondarySystemBackground
        noteWrap.layer.cornerRadius = 12
        noteWrap.layer.borderWidth = 1
        noteWrap.layer.borderColor = UIColor.separator.cgColor

        noteTextView.translatesAutoresizingMaskIntoConstraints = false
        noteTextView.backgroundColor = .clear
        noteTextView.textAlignment = .right
        noteTextView.font = UIFont.systemFont(ofSize: 15)
        noteTextView.delegate = self
        noteTextView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        noteTextView.isScrollEnabled = false

        notePlaceholder.translatesAutoresizingMaskIntoConstraints = false
        notePlaceholder.text = "أضف ملاحظاتك هنا..."
        notePlaceholder.textAlignment = .right
        notePlaceholder.textColor = .placeholderText
        notePlaceholder.font = UIFont.systemFont(ofSize: 15)

        noteWrap.addSubview(noteTextView)
        noteWrap.addSubview(notePlaceholder)

        saveButton.setTitle("حفظ الرابط", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        saveButton.backgroundColor = .systemGreen
        saveButton.layer.cornerRadius = 14
        saveButton.isEnabled = false
        saveButton.alpha = 0.60
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)

        cancelButton.setTitle("إغلاق", for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        cancelButton.setTitleColor(.systemGreen, for: .normal)
        cancelButton.backgroundColor = UIColor.secondarySystemBackground
        cancelButton.layer.cornerRadius = 14
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)

        [titleLabel, subtitleLabel, activityIndicator, previewBox, titleField, categoryStack, noteWrap, saveButton, cancelButton].forEach {
            stack.addArrangedSubview($0)
        }

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 18),
            cardView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -18),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            cardView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            stack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -18),

            previewBox.heightAnchor.constraint(greaterThanOrEqualToConstant: 78),
            previewTitleLabel.topAnchor.constraint(equalTo: previewBox.topAnchor, constant: 12),
            previewTitleLabel.leadingAnchor.constraint(equalTo: previewBox.leadingAnchor, constant: 12),
            previewTitleLabel.trailingAnchor.constraint(equalTo: previewBox.trailingAnchor, constant: -12),
            previewURLLabel.topAnchor.constraint(equalTo: previewTitleLabel.bottomAnchor, constant: 5),
            previewURLLabel.leadingAnchor.constraint(equalTo: previewBox.leadingAnchor, constant: 12),
            previewURLLabel.trailingAnchor.constraint(equalTo: previewBox.trailingAnchor, constant: -12),
            previewURLLabel.bottomAnchor.constraint(lessThanOrEqualTo: previewBox.bottomAnchor, constant: -12),

            titleField.heightAnchor.constraint(equalToConstant: 48),
            categoryStack.heightAnchor.constraint(equalToConstant: 46),

            noteWrap.heightAnchor.constraint(greaterThanOrEqualToConstant: 92),
            noteTextView.topAnchor.constraint(equalTo: noteWrap.topAnchor),
            noteTextView.leadingAnchor.constraint(equalTo: noteWrap.leadingAnchor),
            noteTextView.trailingAnchor.constraint(equalTo: noteWrap.trailingAnchor),
            noteTextView.bottomAnchor.constraint(equalTo: noteWrap.bottomAnchor),
            notePlaceholder.topAnchor.constraint(equalTo: noteWrap.topAnchor, constant: 14),
            notePlaceholder.trailingAnchor.constraint(equalTo: noteWrap.trailingAnchor, constant: -14),
            notePlaceholder.leadingAnchor.constraint(greaterThanOrEqualTo: noteWrap.leadingAnchor, constant: 14),

            saveButton.heightAnchor.constraint(equalToConstant: 52),
            cancelButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    private func buildCategoryButtons() {
        let categories = ["تلقائي", "يوتيوب", "طبخ", "أخرى"]
        categoryButtons.removeAll()
        for (index, category) in categories.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            button.setTitle(category, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
            button.layer.cornerRadius = 12
            button.layer.borderWidth = 1
            button.addTarget(self, action: #selector(categoryTapped(_:)), for: .touchUpInside)
            categoryStack.addArrangedSubview(button)
            categoryButtons.append(button)
        }
        updateCategorySelection()
    }

    @objc private func categoryTapped(_ sender: UIButton) {
        let categories = ["تلقائي", "يوتيوب", "طبخ", "أخرى"]
        let picked = categories[sender.tag]
        selectedCategory = picked == "تلقائي" ? nil : picked
        updateCategorySelection()
    }

    private func updateCategorySelection() {
        for button in categoryButtons {
            let selected = (button.tag == 0 && selectedCategory == nil) || button.title(for: .normal) == selectedCategory
            button.backgroundColor = selected ? UIColor.systemGreen.withAlphaComponent(0.14) : UIColor.secondarySystemBackground
            button.setTitleColor(selected ? .systemGreen : .label, for: .normal)
            button.layer.borderColor = selected ? UIColor.systemGreen.cgColor : UIColor.separator.cgColor
        }
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
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
            guard let self = self else { return }

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
            guard let self = self else { return }
            let currentPayload = self.payload
            DispatchQueue.main.async {
                self.updateUI(for: currentPayload)
            }
        }
    }

    private func updateUI(for payload: SharedPayload) {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true

        let candidate = payload.url ?? Self.firstURL(in: payload.text ?? "")
        if let candidate = candidate, !candidate.isEmpty {
            let resolvedTitle = resolvedTitle(payload: payload, url: candidate)
            previewTitleLabel.text = resolvedTitle
            previewURLLabel.text = candidate
            titleField.text = resolvedTitle
            subtitleLabel.text = "أضف ملاحظة أو اختر تصنيف ثم احفظ"
            saveButton.isEnabled = true
            saveButton.alpha = 1.0
        } else if let text = payload.text, !text.isEmpty {
            previewTitleLabel.text = "نص مشارك"
            previewURLLabel.text = text
            titleField.text = payload.title ?? ""
            subtitleLabel.text = "أضف ملاحظة ثم احفظ"
            saveButton.isEnabled = true
            saveButton.alpha = 1.0
        } else {
            showNoContentState()
        }
    }

    private func showNoContentState() {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        previewTitleLabel.text = "لا يوجد رابط واضح"
        previewURLLabel.text = "جرّب المشاركة من Safari أو YouTube أو انسخ الرابط كنص."
        subtitleLabel.text = "لم نتمكن من قراءة رابط من المشاركة"
        saveButton.isEnabled = false
        saveButton.alpha = 0.60
    }

    private func resolvedTitle(payload: SharedPayload, url: String) -> String {
        if let title = payload.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        if let parsed = URL(string: url) {
            if let host = parsed.host?.replacingOccurrences(of: "www.", with: ""), !host.isEmpty {
                return host
            }
        }
        return "رابط محفوظ"
    }

    @objc private func saveButtonTapped() {
        if didComplete || didStartSave { return }
        didStartSave = true
        saveButton.isEnabled = false
        saveButton.alpha = 0.60
        cancelButton.isEnabled = false
        subtitleLabel.text = "جاري حفظ الرابط..."

        var currentPayload = payload
        let editedTitle = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !editedTitle.isEmpty { currentPayload.title = editedTitle }
        let note = noteTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !note.isEmpty { currentPayload.note = note }
        currentPayload.category = selectedCategory
        payload = currentPayload

        let saved = savePayloadToAppGroup(currentPayload)
        if saved {
            subtitleLabel.text = "تم الحفظ بنجاح. جاري محاولة فتح LinkVault..."
        } else {
            subtitleLabel.text = "تعذر حفظ النسخة المشتركة. سنحاول فتح LinkVault مباشرة."
        }

        openContainingApp(with: currentPayload, appGroupSaved: saved)
    }

    private func openContainingApp(with payload: SharedPayload, appGroupSaved: Bool) {
        guard let deepLink = makeDeepLinkURL(from: payload) else {
            completeAfterSave(appGroupSaved)
            return
        }

        guard let context = extensionContext else {
            completeAfterSave(appGroupSaved)
            return
        }

        context.open(deepLink) { [weak self] success in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if success {
                    self.subtitleLabel.text = "تم فتح LinkVault."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        self.completeOnce()
                    }
                } else {
                    self.completeAfterSave(appGroupSaved)
                }
            }
        }
    }

    private func completeAfterSave(_ saved: Bool) {
        if saved {
            subtitleLabel.text = "تم حفظ الرابط. افتح LinkVault يدويًا وسيظهر الرابط."
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
                self?.completeOnce()
            }
        } else {
            didStartSave = false
            saveButton.isEnabled = true
            saveButton.alpha = 1.0
            cancelButton.isEnabled = true
            subtitleLabel.text = "تعذر الحفظ. تأكد من App Group ثم جرّب مرة ثانية."
        }
    }

    private func makeDeepLinkURL(from payload: SharedPayload) -> URL? {
        let extractedURL = payload.url ?? Self.firstURL(in: payload.text ?? "") ?? ""
        let text = payload.text ?? ""
        let title = payload.title ?? ""
        let note = payload.note ?? ""
        let category = payload.category ?? ""

        guard !extractedURL.isEmpty || !text.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = "linkvaultq8"
        components.host = "share"

        var queryItems = [URLQueryItem]()
        if !extractedURL.isEmpty { queryItems.append(URLQueryItem(name: "url", value: extractedURL)) }
        if !title.isEmpty { queryItems.append(URLQueryItem(name: "title", value: title)) }
        if !text.isEmpty { queryItems.append(URLQueryItem(name: "text", value: text)) }
        if !note.isEmpty { queryItems.append(URLQueryItem(name: "note", value: note)) }
        if !category.isEmpty { queryItems.append(URLQueryItem(name: "cat", value: category)) }
        queryItems.append(URLQueryItem(name: "source", value: "share_extension"))
        queryItems.append(URLQueryItem(name: "ts", value: String(Int(Date().timeIntervalSince1970))))
        components.queryItems = queryItems

        return components.url
    }

    @objc private func cancelButtonTapped() {
        completeOnce()
    }

    func textViewDidChange(_ textView: UITextView) {
        notePlaceholder.isHidden = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func savePayloadToAppGroup(_ payload: SharedPayload) -> Bool {
        let extractedURL = payload.url ?? Self.firstURL(in: payload.text ?? "") ?? ""
        let text = payload.text ?? ""
        let title = payload.title ?? ""
        let note = payload.note ?? ""
        let category = payload.category ?? ""

        guard !extractedURL.isEmpty || !text.isEmpty else { return false }
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return false }

        defaults.set(extractedURL, forKey: "linkvault.pendingShare.url")
        defaults.set(title, forKey: "linkvault.pendingShare.title")
        defaults.set(text, forKey: "linkvault.pendingShare.text")
        defaults.set(note, forKey: "linkvault.pendingShare.note")
        defaults.set(category, forKey: "linkvault.pendingShare.category")
        defaults.set(Date().timeIntervalSince1970, forKey: "linkvault.pendingShare.timestamp")
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

private extension UITextField {
    func setPadding(left: CGFloat, right: CGFloat) {
        let leftView = UIView(frame: CGRect(x: 0, y: 0, width: left, height: 1))
        self.leftView = leftView
        self.leftViewMode = .always

        let rightView = UIView(frame: CGRect(x: 0, y: 0, width: right, height: 1))
        self.rightView = rightView
        self.rightViewMode = .always
    }
}
