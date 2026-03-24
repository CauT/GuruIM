import Foundation

/// GURU 隐私开关服务
/// 控制是否采集输入记录和剪贴板，状态持久化存储在 App Group UserDefaults
/// 默认值：采集开启（isCollectionEnabled = true）
public final class GURUPrivacyService {
  public static let shared = GURUPrivacyService()

  private let defaults = UserDefaults(suiteName: HamsterConstants.appGroupName)
  private let key = "guru_collection_enabled"

  /// 是否允许采集（true = 正常采集，false = 隐私模式暂停采集）
  public var isCollectionEnabled: Bool {
    get {
      // object(forKey:) returns nil when key has never been set → default to true
      guard let stored = defaults?.object(forKey: key) else { return true }
      return (stored as? Bool) ?? true
    }
    set {
      defaults?.set(newValue, forKey: key)
    }
  }

  /// 切换采集状态，返回切换后的新值
  @discardableResult
  public func toggle() -> Bool {
    let next = !isCollectionEnabled
    isCollectionEnabled = next
    return next
  }
}
