import Combine
import Foundation
import HamsterKit

@MainActor
public class AutoInsightViewModel: ObservableObject {
  private let service = AutoInsightService.shared

  // MARK: - Results

  @Published public var results: [AutoInsightResult] = []
  @Published public var unreadCount: Int = 0

  // MARK: - Config (live editing)

  @Published public var isEnabled: Bool = false
  @Published public var intervalHours: Int = 24
  @Published public var personalBackground: String = ""
  @Published public var spiritualPrompt: String = AutoInsightService.defaultSpiritualPrompt
  @Published public var taskPrompt: String = AutoInsightService.defaultTaskPrompt

  public init() {
    reload()
  }

  // MARK: - Data

  public func reload() {
    results = service.results
    unreadCount = service.unreadCount
    let cfg = service.config
    isEnabled = cfg.isEnabled
    intervalHours = cfg.intervalHours
    personalBackground = cfg.personalBackground
    spiritualPrompt = cfg.spiritualPrompt.isEmpty ? AutoInsightService.defaultSpiritualPrompt : cfg.spiritualPrompt
    taskPrompt = cfg.taskPrompt.isEmpty ? AutoInsightService.defaultTaskPrompt : cfg.taskPrompt
  }

  public func saveConfig() {
    var cfg = service.config
    cfg.isEnabled = isEnabled
    cfg.intervalHours = intervalHours
    cfg.personalBackground = personalBackground
    cfg.spiritualPrompt = spiritualPrompt
    cfg.taskPrompt = taskPrompt
    service.config = cfg
  }

  public func deleteResult(_ result: AutoInsightResult) {
    service.deleteResult(result.id)
    reload()
  }

  public func markAsRead(_ result: AutoInsightResult) {
    service.markAsRead(result.id)
    reload()
  }

  // MARK: - Share

  public func shareText(for result: AutoInsightResult) -> String {
    let dateStr = result.date.formatted(date: .long, time: .shortened)
    return """
    📅 \(dateStr)

    💜 心灵安慰
    \(result.spiritualContent)

    📋 事务指导
    \(result.taskContent)

    — 由 Hamster 每日洞察生成
    """
  }

  public func shareSpiritual(_ result: AutoInsightResult) -> String { result.spiritualContent }
  public func shareTask(_ result: AutoInsightResult) -> String { result.taskContent }
}
