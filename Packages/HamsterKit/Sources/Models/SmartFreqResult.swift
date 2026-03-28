import Foundation

/// 智能调频单次分析结果
public struct SmartFreqResult: Codable, Identifiable {
  public let id: UUID
  public let date: Date
  /// 参与分析的 GURU 条目数量
  public let entriesCount: Int
  /// 提升词频的词条数
  public let boostCount: Int
  /// 降低词频的词条数
  public let demoteCount: Int
  /// 新增词条数
  public let newPhraseCount: Int
  /// 本次消耗的 Token 数
  public let tokensUsed: Int

  public init(
    id: UUID = UUID(),
    date: Date = Date(),
    entriesCount: Int,
    boostCount: Int,
    demoteCount: Int,
    newPhraseCount: Int,
    tokensUsed: Int
  ) {
    self.id = id
    self.date = date
    self.entriesCount = entriesCount
    self.boostCount = boostCount
    self.demoteCount = demoteCount
    self.newPhraseCount = newPhraseCount
    self.tokensUsed = tokensUsed
  }
}
