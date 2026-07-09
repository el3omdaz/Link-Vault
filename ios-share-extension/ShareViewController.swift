import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController, UITextViewDelegate {
    private let appGroupId = "group.com.linkvaultq8.shared"
    private let pendingSharesKey = "linkvault.pendingShares.v2"
    private let collectionQueue = DispatchQueue(label: "com.linkvaultq8.share.collection")

    private let appBackground = UIColor(red: 13/255, green: 13/255, blue: 20/255, alpha: 1)
    private let appSurface = UIColor(red: 19/255, green: 19/255, blue: 31/255, alpha: 1)
    private let appCard = UIColor(red: 26/255, green: 26/255, blue: 46/255, alpha: 1)
    private let appBorder = UIColor(red: 42/255, green: 42/255, blue: 69/255, alpha: 1)
    private let appAccent = UIColor(red: 124/255, green: 106/255, blue: 1, alpha: 1)
    private let appAccent2 = UIColor(red: 168/255, green: 85/255, blue: 247/255, alpha: 1)
    private let appText = UIColor(red: 238/255, green: 238/255, blue: 1, alpha: 1)
    private let appMuted = UIColor(red: 161/255, green: 161/255, blue: 199/255, alpha: 1)

    private var didStartExtraction = false
    private var didComplete = false
    private var didStartSave = false
    private var selectedCategory: String?
    private var categoryButtons: [UIButton] = []
    private var keyboardBottomConstraint: NSLayoutConstraint!

    private struct SharedPayload {
        var url: String?
        var title: String?
        var text: String?
        var note: String?
        var category: String?
    }

    private struct PendingShareRecord: Codable {
        let id: String
        let url: String
        let title: String
        let text: String
        let note: String
        let category: String
        let timestamp: Double
    }

    private var payload = SharedPayload()

    private let cardView = UIView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let previewBox = UIView()
    private let previewTitleLabel = UILabel()
    private let previewURLLabel = UILabel()
    private let titleField = UITextField()
    private let categoryStack = UIStackView()
    private let noteTextView = UITextView()
    private let notePlaceholder = UILabel()
    private let saveButton = GradientButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        registerForKeyboardNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !didStartExtraction {
            didStartExtraction = true
            extractSharedContent()
        }
    }

    private func configureUI() {
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = UIColor.black.withAlphaComponent(0.58)

        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        dismissTap.cancelsTouchesInView = false
        view.addGestureRecognizer(dismissTap)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = appSurface
        cardView.layer.cornerRadius = 24
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = appBorder.cgColor
        cardView.layer.masksToBounds = true
        view.addSubview(cardView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = false
        scrollView.keyboardDismissMode = .interactive
        scrollView.showsVerticalScrollIndicator = false
        cardView.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        let formStack = UIStackView()
        formStack.translatesAutoresizingMaskIntoConstraints = false
        formStack.axis = .vertical
        formStack.spacing = 12
        formStack.alignment = .fill
        contentView.addSubview(formStack)

        titleLabel.text = "حفظ الرابط"
        titleLabel.textAlignment = .center
        titleLabel.textColor = appText
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)

        subtitleLabel.text = "LinkVault Q8"
        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = appMuted
        subtitleLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        subtitleLabel.numberOfLines = 0

        activityIndicator.color = appAccent
        activityIndicator.startAnimating()

        previewBox.backgroundColor = appCard
        previewBox.layer.cornerRadius = 14
        previewBox.layer.borderWidth = 1
        previewBox.layer.borderColor = appBorder.cgColor
        previewBox.translatesAutoresizingMaskIntoConstraints = false

        previewTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        previewTitleLabel.text = "جاري قراءة الرابط..."
        previewTitleLabel.textAlignment = .right
        previewTitleLabel.textColor = appText
        previewTitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        previewTitleLabel.numberOfLines = 2

        previewURLLabel.translatesAutoresizingMaskIntoConstraints = false
        previewURLLabel.text = ""
        previewURLLabel.textAlignment = .right
        previewURLLabel.textColor = appMuted
        previewURLLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        previewURLLabel.numberOfLines = 2
        previewURLLabel.semanticContentAttribute = .forceLeftToRight

        previewBox.addSubview(previewTitleLabel)
        previewBox.addSubview(previewURLLabel)

        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.attributedPlaceholder = NSAttributedString(
            string: "العنوان",
            attributes: [.foregroundColor: appMuted.withAlphaComponent(0.72)]
        )
        titleField.textAlignment = .right
        titleField.textColor = appText
        titleField.tintColor = appAccent
        titleField.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleField.backgroundColor = appCard
        titleField.layer.cornerRadius = 12
        titleField.layer.borderWidth = 1
        titleField.layer.borderColor = appBorder.cgColor
        titleField.clearButtonMode = .whileEditing
        titleField.keyboardAppearance = .dark
        titleField.setPadding(left: 12, right: 12)

        categoryStack.axis = .horizontal
        categoryStack.spacing = 8
        categoryStack.distribution = .fillEqually
        categoryStack.alignment = .fill
        buildCategoryButtons()

        let noteWrap = UIView()
        noteWrap.translatesAutoresizingMaskIntoConstraints = false
        noteWrap.backgroundColor = appCard
        noteWrap.layer.cornerRadius = 12
        noteWrap.layer.borderWidth = 1
        noteWrap.layer.borderColor = appBorder.cgColor

        noteTextView.translatesAutoresizingMaskIntoConstraints = false
        noteTextView.backgroundColor = .clear
        noteTextView.textAlignment = .right
        noteTextView.textColor = .white
        noteTextView.tintColor = appAccent
        noteTextView.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        noteTextView.delegate = self
        noteTextView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        noteTextView.keyboardAppearance = .dark
        noteTextView.isScrollEnabled = true

        notePlaceholder.translatesAutoresizingMaskIntoConstraints = false
        notePlaceholder.text = "أضف ملاحظاتك هنا..."
        notePlaceholder.textAlignment = .right
        notePlaceholder.textColor = appMuted.withAlphaComponent(0.72)
        notePlaceholder.font = UIFont.systemFont(ofSize: 17)

        noteWrap.addSubview(noteTextView)
        noteWrap.addSubview(notePlaceholder)

        [titleLabel, subtitleLabel, activityIndicator, previewBox, titleField, categoryStack, noteWrap].forEach {
            formStack.addArrangedSubview($0)
        }

        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.setTitle("حفظ الرابط", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        saveButton.layer.cornerRadius = 14
        saveButton.layer.masksToBounds = true
        saveButton.gradientColors = [appAccent.cgColor, appAccent2.cgColor]
        saveButton.isEnabled = false
        saveButton.alpha = 0.60
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("إغلاق", for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        cancelButton.setTitleColor(appAccent, for: .normal)
        cancelButton.backgroundColor = appCard
        cancelButton.layer.cornerRadius = 14
        cancelButton.layer.borderWidth = 1
        cancelButton.layer.borderColor = appBorder.cgColor
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)

        let actionStack = UIStackView(arrangedSubviews: [saveButton, cancelButton])
        actionStack.translatesAutoresizingMaskIntoConstraints = false
        actionStack.axis = .vertical
        actionStack.spacing = 10
        cardView.addSubview(actionStack)

        keyboardBottomConstraint = cardView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -12)
        let preferredHeight = cardView.heightAnchor.constraint(equalToConstant: 570)
        preferredHeight.priority = .defaultHigh
        let minimumHeight = cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 300)
        minimumHeight.priority = UILayoutPriority(700)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 18),
            cardView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -18),
            cardView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            keyboardBottomConstraint,
            preferredHeight,
            minimumHeight,

            scrollView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 18),
            scrollView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: actionStack.topAnchor, constant: -14),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            formStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            formStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            formStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            formStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

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

            noteWrap.heightAnchor.constraint(equalToConstant: 108),
            noteTextView.topAnchor.constraint(equalTo: noteWrap.topAnchor),
            noteTextView.leadingAnchor.constraint(equalTo: noteWrap.leadingAnchor),
            noteTextView.trailingAnchor.constraint(equalTo: noteWrap.trailingAnchor),
            noteTextView.bottomAnchor.constraint(equalTo: noteWrap.bottomAnchor),
            notePlaceholder.topAnchor.constraint(equalTo: noteWrap.topAnchor, constant: 15),
            notePlaceholder.trailingAnchor.constraint(equalTo: noteWrap.trailingAnchor, constant: -16),
            notePlaceholder.leadingAnchor.constraint(greaterThanOrEqualTo: noteWrap.leadingAnchor, constant: 16),

            actionStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            actionStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            actionStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -18),
            saveButton.heightAnchor.constraint(equalToConstant: 52),
            cancelButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    private func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let converted = view.convert(frame, from: nil)
        let overlap = max(0, view.bounds.maxY - converted.minY)
        updateKeyboardConstraint(to: -(overlap + 10), notification: notification)
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        updateKeyboardConstraint(to: -12, notification: notification)
    }

    private func updateKeyboardConstraint(to constant: CGFloat, notification: Notification) {
        keyboardBottomConstraint.constant = constant
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curveValue = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7
        let options = UIView.AnimationOptions(rawValue: curveValue << 16)
        UIView.animate(withDuration: duration, delay: 0, options: options) {
            self.view.layoutIfNeeded()
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
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
            button.backgroundColor = selected ? appAccent.withAlphaComponent(0.20) : appCard
            button.setTitleColor(selected ? .white : appMuted, for: .normal)
            button.layer.borderColor = selected ? appAccent.cgColor : appBorder.cgColor
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
            subtitleLabel.text = "أضف ملاحظة أو اختر تصنيفًا ثم احفظ"
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
        if let parsed = URL(string: url),
           let host = parsed.host?.replacingOccurrences(of: "www.", with: ""),
           !host.isEmpty {
            return host
        }
        return "رابط محفوظ"
    }

    @objc private func saveButtonTapped() {
        if didComplete || didStartSave { return }
        didStartSave = true
        view.endEditing(true)
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

        if appendPayloadToAppGroup(currentPayload) {
            subtitleLabel.text = "تم حفظ الرابط بنجاح ✓"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
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

    @objc private func cancelButtonTapped() {
        completeOnce()
    }

    func textViewDidChange(_ textView: UITextView) {
        notePlaceholder.isHidden = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func appendPayloadToAppGroup(_ payload: SharedPayload) -> Bool {
        let extractedURL = payload.url ?? Self.firstURL(in: payload.text ?? "") ?? ""
        let text = payload.text ?? ""
        let title = payload.title ?? ""
        let note = payload.note ?? ""
        let category = payload.category ?? ""

        guard !extractedURL.isEmpty || !text.isEmpty else { return false }
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return false }

        var records = loadPendingRecords(from: defaults)
        migrateLegacyPayloadIfNeeded(defaults: defaults, records: &records)

        let newRecord = PendingShareRecord(
            id: UUID().uuidString,
            url: extractedURL,
            title: title,
            text: text,
            note: note,
            category: category,
            timestamp: Date().timeIntervalSince1970
        )
        records.append(newRecord)

        guard let encoded = try? JSONEncoder().encode(records) else { return false }
        defaults.set(encoded, forKey: pendingSharesKey)
        defaults.synchronize()
        return true
    }

    private func loadPendingRecords(from defaults: UserDefaults) -> [PendingShareRecord] {
        guard let data = defaults.data(forKey: pendingSharesKey),
              let records = try? JSONDecoder().decode([PendingShareRecord].self, from: data) else {
            return []
        }
        return records.sorted { $0.timestamp < $1.timestamp }
    }

    private func migrateLegacyPayloadIfNeeded(defaults: UserDefaults, records: inout [PendingShareRecord]) {
        let legacyURL = defaults.string(forKey: "linkvault.pendingShare.url") ?? ""
        let legacyText = defaults.string(forKey: "linkvault.pendingShare.text") ?? ""
        guard !legacyURL.isEmpty || !legacyText.isEmpty else { return }

        let legacyTimestamp = defaults.double(forKey: "linkvault.pendingShare.timestamp")
        records.append(PendingShareRecord(
            id: UUID().uuidString,
            url: legacyURL,
            title: defaults.string(forKey: "linkvault.pendingShare.title") ?? "",
            text: legacyText,
            note: defaults.string(forKey: "linkvault.pendingShare.note") ?? "",
            category: defaults.string(forKey: "linkvault.pendingShare.category") ?? "",
            timestamp: legacyTimestamp > 0 ? legacyTimestamp : Date().timeIntervalSince1970
        ))

        defaults.removeObject(forKey: "linkvault.pendingShare.url")
        defaults.removeObject(forKey: "linkvault.pendingShare.title")
        defaults.removeObject(forKey: "linkvault.pendingShare.text")
        defaults.removeObject(forKey: "linkvault.pendingShare.note")
        defaults.removeObject(forKey: "linkvault.pendingShare.category")
        defaults.removeObject(forKey: "linkvault.pendingShare.timestamp")
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

private final class GradientButton: UIButton {
    var gradientColors: [CGColor] = [] {
        didSet { gradientLayer.colors = gradientColors }
    }

    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureGradient()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureGradient()
    }

    private func configureGradient() {
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.insertSublayer(gradientLayer, at: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}

private extension UITextField {
    func setPadding(left: CGFloat, right: CGFloat) {
        let leftPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: left, height: 1))
        leftView = leftPaddingView
        leftViewMode = .always

        let rightPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: right, height: 1))
        rightView = rightPaddingView
        rightViewMode = .always
    }
}
