import Foundation

/// 智能调频配置
public struct SmartFreqConfig: Codable {
  public var isEnabled: Bool
  /// 两次分析之间最小间隔（小时）
  public var intervalHours: Int
  /// 月度 Token 预算上限（0=不限）
  public var monthlyTokenBudget: Int
  /// 当月已消耗 Token 数
  public var monthlyTokensUsed: Int
  /// 预算统计月份（yyyy-MM 格式，用于月度重置）
  public var budgetMonth: String
  /// 上次执行时间
  public var lastRunDate: Date?

  public init(
    isEnabled: Bool = false,
    intervalHours: Int = 24,
    monthlyTokenBudget: Int = 0,
    monthlyTokensUsed: Int = 0,
    budgetMonth: String = "",
    lastRunDate: Date? = nil
  ) {
    self.isEnabled = isEnabled
    self.intervalHours = intervalHours
    self.monthlyTokenBudget = monthlyTokenBudget
    self.monthlyTokensUsed = monthlyTokensUsed
    self.budgetMonth = budgetMonth
    self.lastRunDate = lastRunDate
  }
}
