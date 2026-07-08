import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController, UITextViewDelegate, UITextFieldDelegate {
    private let appGroupId = "group.com.linkvaultq8.shared"
    private let collectionQueue = DispatchQueue(label: "com.linkvaultq8.share.collection")
    private var didStartExtraction = false
    private var didComplete = false
    private var didStartSave = false
    private let categoryOptions = ["تلقائي", "يوتيوب", "طبخ", "تعليم", "أخرى"]
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
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let contentStack = UIStackView()
    private let handleView = UIView()
    private let heroCircle = UIView()
    private let heroIconLabel = UILabel()
    private let screenTitleLabel = UILabel()
    private let messageLabel = UILabel()
    private let previewCard = UIView()
    private let previewTitleLabel = UILabel()
    private let previewDomainLabel = UILabel()
    private let previewURLLabel = UILabel()
    private let titleField = UITextField()
    private let notesTextView = UITextView()
    private let notesPlaceholderLabel = UILabel()
    private let categoriesContainer = UIStackView()
    private let categoriesRow1 = UIStackView()
    private let categoriesRow2 = UIStackView()
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
            trait.userInterfaceStyle == .dark ? UIColor(red: 0.09, green: 0.10, blue: 0.13, alpha: 1.0) : UIColor.white
        }
        cardView.layer.cornerRadius = 28
        cardView.layer.masksToBounds = true
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.12
        cardView.layer.shadowRadius = 24
        view.addSubview(cardView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        cardView.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 14
        contentStack.alignment = .fill
        contentView.addSubview(contentStack)

        handleView.translatesAutoresizingMaskIntoConstraints = false
        handleView.backgroundColor = UIColor.systemGray4
        handleView.layer.cornerRadius = 2.5

        heroCircle.translatesAutoresizingMaskIntoConstraints = false
        heroCircle.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.12)
        heroCircle.layer.cornerRadius = 34
        heroIconLabel.translatesAutoresizingMaskIntoConstraints = false
        heroIconLabel.text = "🔖"
        heroIconLabel.font = UIFont.systemFont(ofSize: 30)
        heroCircle.addSubview(heroIconLabel)

        screenTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        screenTitleLabel.text = "حفظ الرابط"
        screenTitleLabel.textAlignment = .center
        screenTitleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.text = "جاري قراءة الرابط..."
        messageLabel.textAlignment = .center
        messageLabel.textColor = .secondaryLabel
        messageLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        messageLabel.numberOfLines = 0

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()

        previewCard.translatesAutoresizingMaskIntoConstraints = false
        previewCard.backgroundColor = UIColor.secondarySystemBackground
        previewCard.layer.cornerRadius = 18
        previewCard.layer.borderWidth = 1
        previewCard.layer.borderColor = UIColor.separator.cgColor

        previewTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        previewTitleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        previewTitleLabel.textAlignment = .right
        previewTitleLabel.numberOfLines = 2
        previewTitleLabel.text = "الرابط المشترك"

        previewDomainLabel.translatesAutoresizingMaskIntoConstraints = false
        previewDomainLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        previewDomainLabel.textColor = .systemGreen
        previewDomainLabel.textAlignment = .right
        previewDomainLabel.numberOfLines = 1

        previewURLLabel.translatesAutoresizingMaskIntoConstraints = false
        previewURLLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        previewURLLabel.textColor = .secondaryLabel
        previewURLLabel.textAlignment = .right
        previewURLLabel.numberOfLines = 2

        previewCard.addSubview(previewTitleLabel)
        previewCard.addSubview(previewDomainLabel)
        previewCard.addSubview(previewURLLabel)

        let titleLabel = makeSectionLabel("العنوان")
        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.borderStyle = .none
        titleField.backgroundColor = UIColor.secondarySystemBackground
        titleField.layer.cornerRadius = 14
        titleField.layer.borderWidth = 1
        titleField.layer.borderColor = UIColor.separator.cgColor
        titleField.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        titleField.textAlignment = .right
        titleField.clearButtonMode = .whileEditing
        titleField.delegate = self
        let titlePadding = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        titleField.leftView = titlePadding
        titleField.leftViewMode = .always
        titleField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        titleField.rightViewMode = .always
        NSLayoutConstraint.activate([titleField.heightAnchor.constraint(equalToConstant: 52)])

        let categoriesLabel = makeSectionLabel("التصنيف")
        categoriesContainer.translatesAutoresizingMaskIntoConstraints = false
        categoriesContainer.axis = .vertical
        categoriesContainer.spacing = 10
        categoriesContainer.alignment = .fill
        categoriesRow1.translatesAutoresizingMaskIntoConstraints = false
        categoriesRow2.translatesAutoresizingMaskIntoConstraints = false
        categoriesRow1.axis = .horizontal
        categoriesRow1.spacing = 8
        categoriesRow1.distribution = .fillEqually
        categoriesRow2.axis = .horizontal
        categoriesRow2.spacing = 8
        categoriesRow2.distribution = .fillEqually
        categoriesContainer.addArrangedSubview(categoriesRow1)
        categoriesContainer.addArrangedSubview(categoriesRow2)
        buildCategoryButtons()

        let notesLabel = makeSectionLabel("ملاحظات")
        let notesWrap = UIView()
        notesWrap.translatesAutoresizingMaskIntoConstraints = false
        notesWrap.backgroundColor = UIColor.secondarySystemBackground
        notesWrap.layer.cornerRadius = 14
        notesWrap.layer.borderWidth = 1
        notesWrap.layer.borderColor = UIColor.separator.cgColor
        notesTextView.translatesAutoresizingMaskIntoConstraints = false
        notesTextView.backgroundColor = .clear
        notesTextView.font = UIFont.systemFont(ofSize: 16)
        notesTextView.textAlignment = .right
        notesTextView.delegate = self
        notesTextView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        notesTextView.isScrollEnabled = false
        notesPlaceholderLabel.translatesAutoresizingMaskIntoConstraints = false
        notesPlaceholderLabel.text = "أضف ملاحظاتك هنا..."
        notesPlaceholderLabel.font = UIFont.systemFont(ofSize: 16)
        notesPlaceholderLabel.textColor = .placeholderText
        notesPlaceholderLabel.textAlignment = .right
        notesWrap.addSubview(notesTextView)
        notesWrap.addSubview(notesPlaceholderLabel)
        NSLayoutConstraint.activate([
            notesTextView.topAnchor.constraint(equalTo: notesWrap.topAnchor),
            notesTextView.bottomAnchor.constraint(equalTo: notesWrap.bottomAnchor),
            notesTextView.leadingAnchor.constraint(equalTo: notesWrap.leadingAnchor),
            notesTextView.trailingAnchor.constraint(equalTo: notesWrap.trailingAnchor),
            notesPlaceholderLabel.topAnchor.constraint(equalTo: notesWrap.topAnchor, constant: 14),
            notesPlaceholderLabel.trailingAnchor.constraint(equalTo: notesWrap.trailingAnchor, constant: -16),
            notesPlaceholderLabel.leadingAnchor.constraint(greaterThanOrEqualTo: notesWrap.leadingAnchor, constant: 16),
            notesWrap.heightAnchor.constraint(greaterThanOrEqualToConstant: 110)
        ])

        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.setTitle("حفظ الرابط", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.titleLabel?.font = UIFont.systemFont(ofSize: 19, weight: .bold)
        saveButton.backgroundColor = UIColor.systemGreen
        saveButton.layer.cornerRadius = 16
        saveButton.isEnabled = false
        saveButton.alpha = 0.65
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        NSLayoutConstraint.activate([saveButton.heightAnchor.constraint(equalToConstant: 56)])

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("إلغاء", for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        cancelButton.setTitleColor(.systemGreen, for: .normal)
        cancelButton.backgroundColor = UIColor.secondarySystemBackground
        cancelButton.layer.cornerRadius = 16
        cancelButton.layer.borderWidth = 1
        cancelButton.layer.borderColor = UIColor.separator.cgColor
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        NSLayoutConstraint.activate([cancelButton.heightAnchor.constraint(equalToConstant: 52)])

        [handleView, heroCircle, screenTitleLabel, messageLabel, activityIndicator, previewCard, titleLabel, titleField, categoriesLabel, categoriesContainer, notesLabel, notesWrap, saveButton, cancelButton].forEach {
            contentStack.addArrangedSubview($0)
        }

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 18),
            cardView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -18),
            cardView.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            cardView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            scrollView.topAnchor.constraint(equalTo: cardView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            handleView.widthAnchor.constraint(equalToConstant: 44),
            handleView.heightAnchor.constraint(equalToConstant: 5),
            heroCircle.widthAnchor.constraint(equalToConstant: 68),
            heroCircle.heightAnchor.constraint(equalToConstant: 68),
            heroIconLabel.centerXAnchor.constraint(equalTo: heroCircle.centerXAnchor),
            heroIconLabel.centerYAnchor.constraint(equalTo: heroCircle.centerYAnchor),

            previewTitleLabel.topAnchor.constraint(equalTo: previewCard.topAnchor, constant: 16),
            previewTitleLabel.leadingAnchor.constraint(equalTo: previewCard.leadingAnchor, constant: 16),
            previewTitleLabel.trailingAnchor.constraint(equalTo: previewCard.trailingAnchor, constant: -16),
            previewDomainLabel.topAnchor.constraint(equalTo: previewTitleLabel.bottomAnchor, constant: 6),
            previewDomainLabel.leadingAnchor.constraint(equalTo: previewCard.leadingAnchor, constant: 16),
            previewDomainLabel.trailingAnchor.constraint(equalTo: previewCard.trailingAnchor, constant: -16),
            previewURLLabel.topAnchor.constraint(equalTo: previewDomainLabel.bottomAnchor, constant: 6),
            previewURLLabel.leadingAnchor.constraint(equalTo: previewCard.leadingAnchor, constant: 16),
            previewURLLabel.trailingAnchor.constraint(equalTo: previewCard.trailingAnchor, constant: -16),
            previewURLLabel.bottomAnchor.constraint(equalTo: previewCard.bottomAnchor, constant: -16)
        ])

        contentStack.setCustomSpacing(2, after: heroCircle)
        contentStack.setCustomSpacing(2, after: screenTitleLabel)
        contentStack.setCustomSpacing(6, after: messageLabel)
        contentStack.setCustomSpacing(2, after: titleLabel)
        contentStack.setCustomSpacing(2, after: categoriesLabel)
        contentStack.setCustomSpacing(2, after: notesLabel)

        heroCircle.centerXAnchor.constraint(equalTo: contentStack.centerXAnchor).isActive = true
        handleView.centerXAnchor.constraint(equalTo: contentStack.centerXAnchor).isActive = true
    }

    private func makeSectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.textColor = .secondaryLabel
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textAlignment = .right
        return label
    }

    private func buildCategoryButtons() {
        categoriesRow1.arrangedSubviews.forEach { $0.removeFromSuperview() }
        categoriesRow2.arrangedSubviews.forEach { $0.removeFromSuperview() }
        categoryButtons.removeAll()

        for (index, title) in categoryOptions.enumerated() {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
            button.layer.cornerRadius = 12
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor.separator.cgColor
            button.backgroundColor = UIColor.secondarySystemBackground
            button.setTitleColor(.label, for: .normal)
            button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
            button.addTarget(self, action: #selector(categoryTapped(_:)), for: .touchUpInside)
            button.tag = index
            categoryButtons.append(button)
            if index < 3 {
                categoriesRow1.addArrangedSubview(button)
            } else {
                categoriesRow2.addArrangedSubview(button)
            }
        }
        updateCategoryButtonsSelection()
    }

    @objc private func categoryTapped(_ sender: UIButton) {
        let title = categoryOptions[sender.tag]
        selectedCategory = title == "تلقائي" ? nil : title
        updateCategoryButtonsSelection()
    }

    private func updateCategoryButtonsSelection() {
        for (index, button) in categoryButtons.enumerated() {
            let title = categoryOptions[index]
            let selected = (title == "تلقائي" && selectedCategory == nil) || (selectedCategory == title)
            button.backgroundColor = selected ? UIColor.systemGreen.withAlphaComponent(0.14) : UIColor.secondarySystemBackground
            button.layer.borderColor = selected ? UIColor.systemGreen.cgColor : UIColor.separator.cgColor
            button.setTitleColor(selected ? .systemGreen : .label, for: .normal)
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self] in
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
            if let url = url?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty { self.payload.url = url }
            if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty, self.payload.title == nil { self.payload.title = title }
            if let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty, self.payload.text == nil { self.payload.text = text }
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
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true

        let candidateURL = payload.url ?? Self.firstURL(in: payload.text ?? "")
        let resolvedTitle = resolvedTitleForPayload(payload, candidateURL: candidateURL)

        titleField.text = resolvedTitle
        previewTitleLabel.text = resolvedTitle
        previewDomainLabel.text = domainText(for: candidateURL)
        previewURLLabel.text = candidateURL ?? payload.text ?? ""

        if let candidateURL, !candidateURL.isEmpty {
            messageLabel.text = "راجع العنوان أو أضف ملاحظة ثم اضغط حفظ. سنحاول فتح LinkVault تلقائيًا بعد الحفظ."
            saveButton.isEnabled = true
            saveButton.alpha = 1.0
        } else if let text = payload.text, !text.isEmpty {
            messageLabel.text = "تم العثور على نص مشارك. أضف ما تريد ثم اضغط حفظ."
            previewURLLabel.text = text
            saveButton.isEnabled = true
            saveButton.alpha = 1.0
        } else {
            showNoContentState()
        }
    }

    private func resolvedTitleForPayload(_ payload: SharedPayload, candidateURL: String?) -> String {
        if let title = payload.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty { return title }
        if let candidateURL, let url = URL(string: candidateURL) {
            let last = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
            if !last.isEmpty && last != "/" { return last.replacingOccurrences(of: "-", with: " ") }
            return url.host?.replacingOccurrences(of: "www.", with: "") ?? candidateURL
        }
        return ""
    }

    private func domainText(for urlString: String?) -> String {
        guard let urlString, let url = URL(string: urlString) else { return "" }
        return url.host?.replacingOccurrences(of: "www.", with: "") ?? ""
    }

    private func showNoContentState() {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        messageLabel.text = "ما قدرنا نقرأ رابط من المشاركة."
        previewTitleLabel.text = "لا توجد معاينة"
        previewDomainLabel.text = ""
        previewURLLabel.text = "جرّب المشاركة من Safari أو YouTube أو انسخ الرابط كنص."
        saveButton.isEnabled = false
        saveButton.alpha = 0.65
    }

    @objc private func saveButtonTapped() {
        if didComplete || didStartSave { return }
        didStartSave = true
        saveButton.isEnabled = false
        saveButton.alpha = 0.65
        cancelButton.isEnabled = false
        messageLabel.text = "جاري حفظ الرابط..."

        collectionQueue.async { [weak self] in
            guard let self else { return }
            var currentPayload = self.payload
            let editedTitle = self.titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !editedTitle.isEmpty { currentPayload.title = editedTitle }
            let noteText = self.notesTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            currentPayload.note = noteText.isEmpty ? nil : noteText
            currentPayload.category = self.selectedCategory
            self.payload = currentPayload
            let saved = self.savePayloadToAppGroup(currentPayload)
            DispatchQueue.main.async {
                if saved {
                    self.messageLabel.text = "تم حفظ الرابط بنجاح. جاري محاولة فتح LinkVault..."
                } else {
                    self.messageLabel.text = "تعذر حفظ النسخة المشتركة. سنحاول فتح LinkVault مباشرة إذا أمكن."
                }
                self.openContainingApp(with: currentPayload, appGroupSaved: saved)
            }
        }
    }

    private func openContainingApp(with payload: SharedPayload, appGroupSaved: Bool) {
        guard let deepLink = makeDeepLinkURL(from: payload) else {
            if appGroupSaved {
                messageLabel.text = "تم الحفظ. افتح LinkVault يدويًا وسيظهر الرابط تلقائيًا."
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                    self?.completeOnce()
                }
            } else {
                didStartSave = false
                saveButton.isEnabled = true
                saveButton.alpha = 1.0
                cancelButton.isEnabled = true
                messageLabel.text = "تعذر تجهيز الرابط للفتح. جرّب مرة ثانية."
            }
            return
        }

        guard let context = extensionContext else {
            if appGroupSaved {
                messageLabel.text = "تم حفظ الرابط. افتح LinkVault يدويًا وسيظهر تلقائيًا."
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
                    self?.completeOnce()
                }
            } else {
                didStartSave = false
                saveButton.isEnabled = true
                saveButton.alpha = 1.0
                cancelButton.isEnabled = true
                messageLabel.text = "تعذر فتح LinkVault. جرّب مرة ثانية."
            }
            return
        }

        context.open(deepLink) { [weak self] success in
            DispatchQueue.main.async {
                guard let self else { return }
                if success {
                    self.messageLabel.text = "تم فتح LinkVault."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                        self?.completeOnce()
                    }
                } else if appGroupSaved {
                    self.messageLabel.text = "تم حفظ الرابط. إذا لم يُفتح التطبيق تلقائيًا، افتح LinkVault يدويًا وسيظهر الرابط."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
                        self?.completeOnce()
                    }
                } else {
                    self.didStartSave = false
                    self.saveButton.isEnabled = true
                    self.saveButton.alpha = 1.0
                    self.cancelButton.isEnabled = true
                    self.messageLabel.text = "تعذر فتح LinkVault. تأكد من تثبيت التطبيق ثم جرّب مرة ثانية."
                }
            }
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
        notesPlaceholderLabel.isHidden = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func textFieldDidChangeSelection(_ textField: UITextField) {
        if textField == titleField {
            previewTitleLabel.text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? textField.text : "الرابط المشترك"
        }
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
