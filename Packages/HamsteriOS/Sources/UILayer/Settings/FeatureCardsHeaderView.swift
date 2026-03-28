import UIKit

/// 设置页顶部核心功能卡片区：Now Guru + 每日洞察 + 智能调频
final class FeatureCardsHeaderView: UIView {
  var guruAction: (() -> Void)?
  var autoInsightAction: (() -> Void)?
  var smartFreqAction: (() -> Void)?

  // MARK: - Subviews

  private let sectionLabel: UILabel = {
    let label = UILabel()
    label.text = "核心功能"
    label.font = .systemFont(ofSize: 13, weight: .semibold)
    label.textColor = .secondaryLabel
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
  }()

  private lazy var guruCard: UIView = makeCard(
    icon: "brain.head.profile",
    iconColor: .systemPurple,
    cardColor: UIColor.systemPurple.withAlphaComponent(0.12),
    borderColor: UIColor.systemPurple.withAlphaComponent(0.25),
    title: "Now Guru",
    subtitle: "输入采集 · 剪贴板监听 · AI 分析"
  )

  private lazy var autoInsightCard: UIView = makeCard(
    icon: "sparkles",
    iconColor: .systemOrange,
    cardColor: UIColor.systemOrange.withAlphaComponent(0.10),
    borderColor: UIColor.systemOrange.withAlphaComponent(0.22),
    title: "每日洞察",
    subtitle: "心灵陪伴 · 事务指导 · AI 分析"
  )

  private lazy var smartFreqCard: UIView = makeCard(
    icon: "bolt.fill",
    iconColor: .systemCyan,
    cardColor: UIColor.systemCyan.withAlphaComponent(0.10),
    borderColor: UIColor.systemCyan.withAlphaComponent(0.22),
    title: "智能调频",
    subtitle: "自动优化 · 词频调整 · 新词发现"
  )

  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) { fatalError() }

  // MARK: - Layout helpers

  private let cardStack: UIStackView = {
    let sv = UIStackView()
    sv.axis = .horizontal
    sv.distribution = .fillEqually
    sv.spacing = 12
    sv.translatesAutoresizingMaskIntoConstraints = false
    return sv
  }()

  // MARK: - Setup

  private func setup() {
    cardStack.addArrangedSubview(guruCard)
    cardStack.addArrangedSubview(autoInsightCard)
    cardStack.addArrangedSubview(smartFreqCard)
    addSubview(sectionLabel)
    addSubview(cardStack)

    NSLayoutConstraint.activate([
      sectionLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
      sectionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

      cardStack.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 8),
      cardStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      cardStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
      cardStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

      cardStack.heightAnchor.constraint(equalToConstant: 118),
    ])

    addTapGesture(to: guruCard, selector: #selector(guruTapped))
    addTapGesture(to: autoInsightCard, selector: #selector(autoInsightTapped))
    addTapGesture(to: smartFreqCard, selector: #selector(smartFreqTapped))
  }

  private func addTapGesture(to view: UIView, selector: Selector) {
    view.isUserInteractionEnabled = true
    view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: selector))
  }

  // MARK: - Actions

  @objc private func guruTapped() {
    bounce(guruCard) { [weak self] in self?.guruAction?() }
  }

  @objc private func autoInsightTapped() {
    bounce(autoInsightCard) { [weak self] in self?.autoInsightAction?() }
  }

  @objc private func smartFreqTapped() {
    bounce(smartFreqCard) { [weak self] in self?.smartFreqAction?() }
  }

  private func bounce(_ view: UIView, completion: @escaping () -> Void) {
    UIView.animate(withDuration: 0.08, animations: {
      view.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
    }) { _ in
      UIView.animate(withDuration: 0.1, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 4) {
        view.transform = .identity
      }
      completion()
    }
  }

  // MARK: - Card Factory

  private func makeCard(
    icon: String,
    iconColor: UIColor,
    cardColor: UIColor,
    borderColor: UIColor,
    title: String,
    subtitle: String
  ) -> UIView {
    let card = UIView()
    card.backgroundColor = cardColor
    card.layer.cornerRadius = 14
    card.layer.borderWidth = 1
    card.layer.borderColor = borderColor.cgColor
    card.translatesAutoresizingMaskIntoConstraints = false

    let iconConf = UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold)
    let iconImage = UIImage(systemName: icon, withConfiguration: iconConf)
    let iconView = UIImageView(image: iconImage)
    iconView.tintColor = iconColor
    iconView.contentMode = .scaleAspectFit
    iconView.translatesAutoresizingMaskIntoConstraints = false

    let chevron = UIImageView(image: UIImage(systemName: "chevron.right",
      withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)))
    chevron.tintColor = .tertiaryLabel
    chevron.translatesAutoresizingMaskIntoConstraints = false

    let titleLabel = UILabel()
    titleLabel.text = title
    titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
    titleLabel.textColor = .label
    titleLabel.translatesAutoresizingMaskIntoConstraints = false

    let subtitleLabel = UILabel()
    subtitleLabel.text = subtitle
    subtitleLabel.font = .systemFont(ofSize: 11, weight: .regular)
    subtitleLabel.textColor = .secondaryLabel
    subtitleLabel.numberOfLines = 2
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

    card.addSubview(iconView)
    card.addSubview(chevron)
    card.addSubview(titleLabel)
    card.addSubview(subtitleLabel)

    NSLayoutConstraint.activate([
      iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
      iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
      iconView.widthAnchor.constraint(equalToConstant: 30),
      iconView.heightAnchor.constraint(equalToConstant: 30),

      chevron.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
      chevron.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),

      titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 10),
      titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
      titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),

      subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
      subtitleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
      subtitleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
    ])

    return card
  }
}
