#if canImport(UIKit)
import UIKit

public final class QasimhaPromoView: UIView {
    public var amount: Decimal { didSet { if amount != oldValue { reload() } } }
    public var publicKey: String { didSet { if publicKey != oldValue { reload() } } }
    public var language: String { didSet { if language != oldValue { reload() } } }
    public var apiBaseURL: URL? { didSet { if apiBaseURL != oldValue { reload() } } }
    public var font: UIFont = .preferredFont(forTextStyle: .subheadline) { didSet { render() } }
    public var textColor: UIColor = .label { didSet { render() } }
    public var accentColor: UIColor = UIColor(red: 15 / 255, green: 110 / 255, blue: 86 / 255, alpha: 1) { didSet { render() } }

    public private(set) var plans: PromoPlans?

    private let client: PlansClient
    private let stack = UIStackView()
    private var generation = 0
    private var requested = false

    public init(amount: Decimal, publicKey: String, lang: String = "ar", client: PlansClient = PlansClient()) {
        self.amount = amount
        self.publicKey = publicKey
        self.language = lang
        self.client = client
        super.init(frame: .zero)
        configure()
    }

    public required init?(coder: NSCoder) {
        amount = 0
        publicKey = ""
        language = "ar"
        client = PlansClient()
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        isHidden = true
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil && !requested { reload() }
    }

    public override var intrinsicContentSize: CGSize {
        isHidden ? .zero : super.intrinsicContentSize
    }

    public func reload() {
        requested = true
        generation += 1
        let current = generation
        plans = nil
        render()
        guard let key = PublicKey(publicKey) else { return }
        client.fetch(amount: amount, publicKey: key, apiBaseURL: apiBaseURL, language: QasimhaLanguage.resolve(language)) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, self.generation == current else { return }
                self.plans = result
                self.render()
            }
        }
    }

    private func render() {
        for view in stack.arrangedSubviews { view.removeFromSuperview() }
        guard let plan = plans?.plans.first,
              let attachment = RiyalSymbolImage.attachment(for: font, color: textColor) else {
            isHidden = true
            invalidateIntrinsicContentSize()
            return
        }
        let language = QasimhaLanguage.resolve(self.language)
        let direction: UISemanticContentAttribute = language.isRightToLeft ? .forceRightToLeft : .forceLeftToRight
        semanticContentAttribute = direction
        stack.semanticContentAttribute = direction

        let pill = PillLabel()
        pill.text = PromoCopy.wordmark(language)
        pill.font = UIFont.boldSystemFont(ofSize: font.pointSize * 0.85)
        pill.textColor = .white
        pill.backgroundColor = accentColor
        pill.layer.cornerRadius = 6
        pill.layer.masksToBounds = true
        pill.setContentCompressionResistancePriority(.required, for: .horizontal)

        let headline = UILabel()
        headline.numberOfLines = 0
        headline.attributedText = summary(language, plan: plan, attachment: attachment)
        headline.semanticContentAttribute = direction
        headline.accessibilityLabel = accessibilitySummary(language, plan: plan)

        let row = UIStackView(arrangedSubviews: [pill, headline])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        row.semanticContentAttribute = direction
        stack.addArrangedSubview(row)

        if let trust = PromoCopy.trustLine(language, plan: plan) {
            let label = UILabel()
            label.text = trust
            label.font = UIFont.systemFont(ofSize: font.pointSize * 0.85)
            label.textColor = .secondaryLabel
            label.semanticContentAttribute = direction
            label.textAlignment = .natural
            stack.addArrangedSubview(label)
        }
        isHidden = false
        invalidateIntrinsicContentSize()
    }

    private func summary(_ language: QasimhaLanguage, plan: PromoPlan, attachment: NSTextAttachment) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.baseWritingDirection = language.isRightToLeft ? .rightToLeft : .leftToRight
        paragraph.alignment = .natural
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor, .paragraphStyle: paragraph]
        let text = NSMutableAttributedString()
        for segment in PromoCopy.summary(language, plan: plan) {
            switch segment {
            case .text(let value):
                text.append(NSAttributedString(string: value, attributes: attributes))
            case .money(let value):
                text.append(NSAttributedString(string: "\u{2066}", attributes: attributes))
                text.append(NSAttributedString(attachment: attachment))
                text.append(NSAttributedString(string: "\u{200A}" + Money.format(value) + "\u{2069}", attributes: attributes))
            }
        }
        return text
    }

    private func accessibilitySummary(_ language: QasimhaLanguage, plan: PromoPlan) -> String {
        PromoCopy.summary(language, plan: plan).map { segment -> String in
            switch segment {
            case .text(let value): return value
            case .money(let value): return PromoCopy.moneyAccessibilityLabel(language, value)
            }
        }.joined()
    }
}

final class PillLabel: UILabel {
    private let insets = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom)
    }
}
#endif
