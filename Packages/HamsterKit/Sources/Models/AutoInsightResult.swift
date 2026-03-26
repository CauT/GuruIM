import Foundation

/// 每日洞察的一次 AI 分析结果
public struct AutoInsightResult: Codable, Identifiable {
  public let id: UUID
  public let date: Date
  /// 心灵安慰内容（AI 生成）
  public let spiritualContent: String
  /// 事务指导内容（AI 生成）
  public let taskContent: String
  /// 参与分析的 GURU 条目数量
  public let entriesCount: Int
  /// 是否已被用户读取
  public var isRead: Bool

  public init(
    id: UUID = UUID(),
    date: Date = Date(),
    spiritualContent: String,
    taskContent: String,
    entriesCount: Int,
    isRead: Bool = false
  ) {
    self.id = id
    self.date = date
    self.spiritualContent = spiritualContent
    self.taskContent = taskContent
    self.entriesCount = entriesCount
    self.isRead = isRead
  }
}
