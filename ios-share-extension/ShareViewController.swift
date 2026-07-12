import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController, UITextViewDelegate {
    private let appGroupId = "group.com.linkvaultq8.shared"
    private let pendingSharesKey = "linkvault.pendingShares.v2"
    private let categoriesKey = "linkvault.categories.v1"
    private let languageKey = "linkvault.language.v1"
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
    private var categoryOptions: [String] = []
    private var keyboardBottomConstraint: NSLayoutConstraint!
    private var appLanguage = "en"
    private var isArabic: Bool { appLanguage == "ar" }

    private func tr(_ arabic: String, _ english: String) -> String {
        isArabic ? arabic : english
    }

    private func resolveAppLanguage() {
        let saved = UserDefaults(suiteName: appGroupId)?.string(forKey: languageKey) ?? "device"
        if saved == "ar" || saved == "en" {
            appLanguage = saved
        } else {
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
            appLanguage = preferred.hasPrefix("ar") ? "ar" : "en"
        }
    }

    private func displayCategory(_ value: String) -> String {
        guard !isArabic else { return value }
        let names = ["أفلام":"Movies", "مسلسلات":"TV Shows", "يوتيوب":"YouTube", "تعليم":"Education", "طبخ":"Cooking", "مشتريات":"Shopping", "أفكار":"Ideas", "أخرى":"Other"]
        return names[value] ?? value
    }

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
    private let categoryButton = UIButton(type: .system)
    private let customCategoryField = UITextField()
    private let noteTextView = UITextView()
    private let notePlaceholder = UILabel()
    private let saveButton = GradientButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        resolveAppLanguage()
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
        view.semanticContentAttribute = isArabic ? .forceRightToLeft : .forceLeftToRight

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

        titleLabel.text = tr("حفظ الرابط", "Save link")
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
        previewTitleLabel.text = tr("جاري قراءة الرابط...", "Reading link...")
        previewTitleLabel.textAlignment = isArabic ? .right : .left
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
            string: tr("العنوان", "Title"),
            attributes: [.foregroundColor: appMuted.withAlphaComponent(0.72)]
        )
        titleField.textAlignment = isArabic ? .right : .left
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

        categoryStack.axis = .vertical
        categoryStack.spacing = 8
        categoryStack.distribution = .fill
        categoryStack.alignment = .fill
        configureCategoryPicker()

        let noteWrap = UIView()
        noteWrap.translatesAutoresizingMaskIntoConstraints = false
        noteWrap.backgroundColor = appCard
        noteWrap.layer.cornerRadius = 12
        noteWrap.layer.borderWidth = 1
        noteWrap.layer.borderColor = appBorder.cgColor

        noteTextView.translatesAutoresizingMaskIntoConstraints = false
        noteTextView.backgroundColor = .clear
        noteTextView.textAlignment = isArabic ? .right : .left
        noteTextView.textColor = .white
        noteTextView.tintColor = appAccent
        noteTextView.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        noteTextView.delegate = self
        noteTextView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        noteTextView.keyboardAppearance = .dark
        noteTextView.isScrollEnabled = true

        notePlaceholder.translatesAutoresizingMaskIntoConstraints = false
        notePlaceholder.text = tr("أضف ملاحظاتك هنا...", "Add your notes here...")
        notePlaceholder.textAlignment = isArabic ? .right : .left
        notePlaceholder.textColor = appMuted.withAlphaComponent(0.72)
        notePlaceholder.font = UIFont.systemFont(ofSize: 17)

        noteWrap.addSubview(noteTextView)
        noteWrap.addSubview(notePlaceholder)

        [titleLabel, subtitleLabel, activityIndicator, previewBox, titleField, categoryStack, noteWrap].forEach {
            formStack.addArrangedSubview($0)
        }

        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.setTitle(tr("حفظ الرابط", "Save link"), for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        saveButton.layer.cornerRadius = 14
        saveButton.layer.masksToBounds = true
        saveButton.gradientColors = [appAccent.cgColor, appAccent2.cgColor]
        saveButton.isEnabled = false
        saveButton.alpha = 0.60
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle(tr("إغلاق", "Close"), for: .normal)
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
            categoryStack.heightAnchor.constraint(greaterThanOrEqualToConstant: 46),

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

    private func configureCategoryPicker() {
        categoryOptions = loadCategoriesFromAppGroup()

        categoryButton.translatesAutoresizingMaskIntoConstraints = false
        categoryButton.setTitle(tr("التصنيف: تلقائي", "Type: Automatic"), for: .normal)
        categoryButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        categoryButton.contentHorizontalAlignment = isArabic ? .right : .left
        categoryButton.backgroundColor = appCard
        categoryButton.setTitleColor(appText, for: .normal)
        categoryButton.layer.cornerRadius = 12
        categoryButton.layer.borderWidth = 1
        categoryButton.layer.borderColor = appBorder.cgColor
        categoryButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        categoryButton.showsMenuAsPrimaryAction = true
        categoryStack.addArrangedSubview(categoryButton)

        customCategoryField.translatesAutoresizingMaskIntoConstraints = false
        customCategoryField.attributedPlaceholder = NSAttributedString(
            string: tr("اكتب اسم النوع الجديد", "Enter a new type name"),
            attributes: [.foregroundColor: appMuted.withAlphaComponent(0.72)]
        )
        customCategoryField.textAlignment = isArabic ? .right : .left
        customCategoryField.textColor = appText
        customCategoryField.tintColor = appAccent
        customCategoryField.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        customCategoryField.backgroundColor = appCard
        customCategoryField.layer.cornerRadius = 12
        customCategoryField.layer.borderWidth = 1
        customCategoryField.layer.borderColor = appBorder.cgColor
        customCategoryField.keyboardAppearance = .dark
        customCategoryField.setPadding(left: 12, right: 12)
        customCategoryField.heightAnchor.constraint(equalToConstant: 48).isActive = true
        customCategoryField.isHidden = true
        categoryStack.addArrangedSubview(customCategoryField)

        updateCategoryMenu()
    }

    private func loadCategoriesFromAppGroup() -> [String] {
        let fallback = ["أفلام", "مسلسلات", "يوتيوب", "تعليم", "طبخ", "مشتريات", "أفكار", "أخرى"]
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return fallback }
        return normalizeCategories(defaults.stringArray(forKey: categoriesKey) ?? fallback)
    }

    private func normalizeCategories(_ raw: [String]) -> [String] {
        var seen: [String] = []
        for item in raw {
            let value = item.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty || value == "أخرى" { continue }
            if !seen.contains(value) { seen.append(value) }
        }
        seen.append("أخرى")
        return seen
    }

    private func updateCategoryMenu() {
        var actions: [UIAction] = [
            UIAction(title: tr("تلقائي", "Automatic"), state: selectedCategory == nil ? .on : .off) { [weak self] _ in
                self?.selectCategory(nil)
            }
        ]
        for category in categoryOptions {
            actions.append(UIAction(title: displayCategory(category), state: selectedCategory == category ? .on : .off) { [weak self] _ in
                self?.selectCategory(category)
            })
        }
        categoryButton.menu = UIMenu(title: tr("اختر النوع", "Choose type"), children: actions)
        let title = selectedCategory == nil ? tr("التصنيف: تلقائي", "Type: Automatic") : "\(tr("التصنيف", "Type")): \(displayCategory(selectedCategory ?? ""))"
        categoryButton.setTitle(title, for: .normal)
        customCategoryField.isHidden = selectedCategory != "أخرى"
        if selectedCategory == "أخرى" { customCategoryField.becomeFirstResponder() }
    }

    private func selectCategory(_ category: String?) {
        selectedCategory = category
        updateCategoryMenu()
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
            subtitleLabel.text = tr("أضف ملاحظة أو اختر تصنيفًا ثم احفظ", "Add a note or choose a type, then save")
            saveButton.isEnabled = true
            saveButton.alpha = 1.0
        } else if let text = payload.text, !text.isEmpty {
            previewTitleLabel.text = tr("نص مشارك", "Shared text")
            previewURLLabel.text = text
            titleField.text = payload.title ?? ""
            subtitleLabel.text = tr("أضف ملاحظة ثم احفظ", "Add a note, then save")
            saveButton.isEnabled = true
            saveButton.alpha = 1.0
        } else {
            showNoContentState()
        }
    }

    private func showNoContentState() {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        previewTitleLabel.text = tr("لا يوجد رابط واضح", "No clear link found")
        previewURLLabel.text = tr("جرّب المشاركة من Safari أو YouTube أو انسخ الرابط كنص.", "Try sharing from Safari or YouTube, or copy the link as text.")
        subtitleLabel.text = tr("لم نتمكن من قراءة رابط من المشاركة", "We could not read a link from this share")
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
        return tr("رابط محفوظ", "Saved link")
    }

    @objc private func saveButtonTapped() {
        if didComplete || didStartSave { return }
        didStartSave = true
        view.endEditing(true)
        saveButton.isEnabled = false
        saveButton.alpha = 0.60
        cancelButton.isEnabled = false
        subtitleLabel.text = tr("جاري حفظ الرابط...", "Saving link...")

        var currentPayload = payload
        let editedTitle = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !editedTitle.isEmpty { currentPayload.title = editedTitle }
        let note = noteTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !note.isEmpty { currentPayload.note = note }
        if selectedCategory == "أخرى" {
            let custom = customCategoryField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            currentPayload.category = custom.isEmpty ? "أخرى" : custom
        } else {
            currentPayload.category = selectedCategory
        }
        payload = currentPayload

        if appendPayloadToAppGroup(currentPayload) {
            subtitleLabel.text = tr("تم حفظ الرابط بنجاح ✓", "Link saved successfully ✓")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
                self?.completeOnce()
            }
        } else {
            didStartSave = false
            saveButton.isEnabled = true
            saveButton.alpha = 1.0
            cancelButton.isEnabled = true
            subtitleLabel.text = tr("تعذر الحفظ. تأكد من App Group ثم جرّب مرة ثانية.", "Could not save. Check the App Group and try again.")
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
