import HamsterUIKit
import UIKit

/// 输入法设置汇总页 — 包含原有 Hamster 输入法相关的全部设置项
public class InputMethodSettingsViewController: NibLessViewController {
  private let mainViewModel: MainViewModel
  private let enableColorSchema: () -> Bool

  private lazy var tableView: UITableView = {
    let tv = UITableView(frame: .zero, style: .insetGrouped)
    tv.register(SettingTableViewCell.self, forCellReuseIdentifier: SettingTableViewCell.identifier)
    tv.dataSource = self
    tv.delegate = self
    tv.translatesAutoresizingMaskIntoConstraints = false
    return tv
  }()

  private lazy var sections: [SettingSectionModel] = buildSections()

  init(mainViewModel: MainViewModel, enableColorSchema: @escaping () -> Bool) {
    self.mainViewModel = mainViewModel
    self.enableColorSchema = enableColorSchema
    super.init()
  }

  public override func loadView() {
    title = "输入法设置"
    let root = UIView()
    root.addSubview(tableView)
    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: root.topAnchor),
      tableView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
    ])
    view = root
  }

  private func buildSections() -> [SettingSectionModel] {
    [
      SettingSectionModel(title: "输入相关", items: [
        .init(
          icon: UIImage(systemName: "highlighter")!.withTintColor(.yellow),
          text: "输入方案设置",
          accessoryType: .disclosureIndicator,
          navigationAction: { [unowned self] in mainViewModel.subViewSubject.send(.inputSchema) }
        ),
        .init(
          icon: UIImage(systemName: "wifi")!,
          text: "Wi-Fi上传方案",
          accessoryType: .disclosureIndicator,
          navigationAction: { [unowned self] in mainViewModel.subViewSubject.send(.uploadInputSchema) }
        ),
        .init(
          icon: UIImage(systemName: "folder")!,
          text: "文件管理",
          accessoryType: .disclosureIndicator,
          navigationAction: { [unowned self] in mainViewModel.subViewSubject.send(.finder) }
        ),
      ]),
      SettingSectionModel(title: "键盘相关", items: [
        .init(
          icon: UIImage(systemName: "keyboard")!,
          text: "键盘设置",
          accessoryType: .disclosureIndicator,
          navigationAction: { [unowned self] in mainViewModel.subViewSubject.send(.keyboardSettings) }
        ),
        .init(
          icon: UIImage(systemName: "paintpalette")!,
          text: "键盘配色",
          accessoryType: .disclosureIndicator,
          navigationLinkLabel: { [unowned self] in enableColorSchema() ? "启用" : "禁用" },
          navigationAction: { [unowned self] in mainViewModel.subViewSubject.send(.colorSchema) }
        ),
        .init(
          icon: UIImage(systemName: "speaker.wave.3")!,
          text: "按键音与震动",
          accessoryType: .disclosureIndicator,
          navigationAction: { [unowned self] in mainViewModel.subViewSubject.send(.feedback) }
        ),
      ]),
      SettingSectionModel(title: "云同步", items: [
        .init(
          icon: UIImage(systemName: "icloud")!,
          text: "iCloud 同步",
          accessoryType: .disclosureIndicator,
          navigationAction: { [unowned self] in mainViewModel.subViewSubject.send(.iCloud) }
        ),
      ]),
      SettingSectionModel(title: "备份", items: [
        .init(
          icon: UIImage(systemName: "externaldrive.badge.timemachine")!,
          text: "软件备份",
          accessoryType: .disclosureIndicator,
          navigationAction: { [unowned self] in mainViewModel.subViewSubject.send(.backup) }
        ),
      ]),
      SettingSectionModel(title: "RIME", items: [
        .init(
          icon: UIImage(systemName: "r.square")!,
          text: "RIME",
          accessoryType: .disclosureIndicator,
          navigationAction: { [unowned self] in mainViewModel.subViewSubject.send(.rime) }
        ),
      ]),
    ]
  }
}

// MARK: - UITableViewDataSource

extension InputMethodSettingsViewController: UITableViewDataSource {
  public func numberOfSections(in tableView: UITableView) -> Int {
    sections.count
  }

  public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    sections[section].items.count
  }

  public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let item = sections[indexPath.section].items[indexPath.row]
    let cell = tableView.dequeueReusableCell(withIdentifier: SettingTableViewCell.identifier, for: indexPath)
    guard let cell = cell as? SettingTableViewCell else { return cell }
    cell.updateWithSettingItem(item)
    return cell
  }
}

// MARK: - UITableViewDelegate

extension InputMethodSettingsViewController: UITableViewDelegate {
  public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: false)
    let item = sections[indexPath.section].items[indexPath.row]
    item.navigationAction?()
  }
}
