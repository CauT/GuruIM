import Foundation

/// 输入类型隐私过滤服务
/// 按 InputCategory 控制是否采集对应场景的输入，设置持久化在 App Group UserDefaults
public final class InputTypeFilter {
  public static let shared = InputTypeFilter()

  private let defaults = UserDefaults(suiteName: HamsterConstants.appGroupName)
  private let keyPrefix = "itf_blocked_"

  /// 某个分类是否被屏蔽（不采集）
  public func isBlocked(_ category: InputCategory) -> Bool {
    // 密码始终屏蔽
    if category.isAlwaysBlocked { return true }
    // 读取用户设置，未设置时使用默认值
    let key = keyPrefix + category.rawValue
    if let stored = defaults?.object(forKey: key) as? Bool { return stored }
    return category.isBlockedByDefault
  }

  /// 设置某个分类的屏蔽状态
  public func setBlocked(_ blocked: Bool, for category: InputCategory) {
    guard !category.isAlwaysBlocked else { return }
    defaults?.set(blocked, forKey: keyPrefix + category.rawValue)
  }

  /// 重置所有为默认值
  public func resetToDefaults() {
    InputCategory.allCases.forEach { category in
      guard !category.isAlwaysBlocked else { return }
      defaults?.removeObject(forKey: keyPrefix + category.rawValue)
    }
  }
}
