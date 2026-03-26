import Foundation
import OSLog
import UserNotifications

/// 每日洞察配置
public struct AutoInsightConfig: Codable {
  public var isEnabled: Bool
  /// 两次分析之间最小间隔（小时）
  public var intervalHours: Int
  /// 个人背景信息（可选，传入 prompt）
  public var personalBackground: String
  /// 心灵安慰 Prompt 模板
  public var spiritualPrompt: String
  /// 事务指导 Prompt 模板
  public var taskPrompt: String
  /// 上次执行时间
  public var lastRunDate: Date?

  public init(
    isEnabled: Bool = false,
    intervalHours: Int = 24,
    personalBackground: String = "",
    spiritualPrompt: String = AutoInsightService.defaultSpiritualPrompt,
    taskPrompt: String = AutoInsightService.defaultTaskPrompt,
    lastRunDate: Date? = nil
  ) {
    self.isEnabled = isEnabled
    self.intervalHours = intervalHours
    self.personalBackground = personalBackground
    self.spiritualPrompt = spiritualPrompt
    self.taskPrompt = taskPrompt
    self.lastRunDate = lastRunDate
  }
}

/// 每日洞察服务 - 定时分析 GURU 记录并生成 AI 洞察
public class AutoInsightService {
  public static let shared = AutoInsightService()

  private let defaults = UserDefaults(suiteName: HamsterConstants.appGroupName)
  private let configKey = "auto_insight_config"
  private let resultsKey = "auto_insight_results"
  private let logger = Logger(subsystem: "com.hamster", category: "AutoInsight")

  /// 最多保存的结果条数
  private let maxResults = 30

  // MARK: - Default Prompts

  public static let defaultSpiritualPrompt = """
你是一位富有洞察力和温暖的心理陪伴者。根据用户近期的输入记录，感知ta当前的情绪状态、关注焦点和生活节奏，以温柔、真诚的语气写一段个性化的心灵关怀文字。要有洞察力，不要泛泛而谈，让用户感到被真正理解。控制在200字以内。
{background}

用户近期输入记录（按时间顺序）：
{data}
"""

  public static let defaultTaskPrompt = """
你是一位专业的效率顾问。根据用户近期的输入记录，分析ta正在处理和关注的事项，给出结构化的事务指导：1) 当前进行中的重要事项；2) 可能被遗忘的细节或风险；3) 接下来的建议优先级。语气简洁专业，使用列表格式，控制在300字以内。
{background}

用户近期输入记录（按时间顺序）：
{data}
"""

  // MARK: - Config

  public var config: AutoInsightConfig {
    get {
      guard let data = defaults?.data(forKey: configKey),
            let c = try? JSONDecoder().decode(AutoInsightConfig.self, from: data)
      else { return AutoInsightConfig() }
      return c
    }
    set {
      defaults?.set(try? JSONEncoder().encode(newValue), forKey: configKey)
    }
  }

  // MARK: - Results

  public var results: [AutoInsightResult] {
    get {
      guard let data = defaults?.data(forKey: resultsKey),
            let r = try? JSONDecoder().decode([AutoInsightResult].self, from: data)
      else { return [] }
      return r.sorted { $0.date > $1.date }
    }
    set {
      // 保留最新 maxResults 条
      let trimmed = newValue.sorted { $0.date > $1.date }.prefix(maxResults)
      defaults?.set(try? JSONEncoder().encode(Array(trimmed)), forKey: resultsKey)
    }
  }

  public var unreadCount: Int { results.filter { !$0.isRead }.count }

  public func markAsRead(_ id: UUID) {
    var r = results
    if let idx = r.firstIndex(where: { $0.id == id }) {
      r[idx].isRead = true
      results = r
    }
  }

  public func deleteResult(_ id: UUID) {
    results = results.filter { $0.id != id }
  }

  // MARK: - Trigger Check

  /// 是否满足执行条件（供键盘扩展在 viewWillAppear 时调用）
  public var shouldRun: Bool {
    let cfg = config
    guard cfg.isEnabled else { return false }
    // 需要有 API Key
    let provider = AIService.shared.selectedProvider
    guard !AIService.shared.apiKey(for: provider).isEmpty else { return false }
    // 检查时间间隔
    guard let lastRun = cfg.lastRunDate else { return true }
    let minInterval = TimeInterval(cfg.intervalHours * 3600)
    return Date().timeIntervalSince(lastRun) >= minInterval
  }

  /// 满足条件时执行分析（异步，不阻塞键盘）
  public func runIfNeeded() async {
    guard shouldRun else { return }
    // 立即更新 lastRunDate，防止并发重入
    var cfg = config
    cfg.lastRunDate = Date()
    config = cfg

    await run()
  }

  // MARK: - Core Analysis

  private func run() async {
    let cfg = config
    let guruText = loadGURUText(sinceHours: cfg.intervalHours)
    guard !guruText.isEmpty else {
      logger.info("AutoInsight: no GURU data in the past \(cfg.intervalHours)h, skipping")
      return
    }

    let backgroundSection = cfg.personalBackground.isEmpty
      ? ""
      : "\n用户个人背景：\(cfg.personalBackground)\n"

    func buildPrompt(_ template: String) -> String {
      template
        .replacingOccurrences(of: "{background}", with: backgroundSection)
        .replacingOccurrences(of: "{data}", with: guruText)
    }

    let spiritualPromptText = buildPrompt(cfg.spiritualPrompt)
    let taskPromptText = buildPrompt(cfg.taskPrompt)

    // 两个 AI 调用并发执行
    async let spiritualCall = callAI(prompt: spiritualPromptText)
    async let taskCall = callAI(prompt: taskPromptText)

    let (spiritualResult, taskResult) = await (spiritualCall, taskCall)

    let spiritual = (try? spiritualResult.get()) ?? "（分析失败，请检查 API Key 配置）"
    let task = (try? taskResult.get()) ?? "（分析失败，请检查 API Key 配置）"

    let entryCount = guruText.components(separatedBy: "\n").filter { !$0.isEmpty }.count

    let insight = AutoInsightResult(
      spiritualContent: spiritual,
      taskContent: task,
      entriesCount: entryCount
    )

    // 保存结果
    var allResults = results
    allResults.insert(insight, at: 0)
    results = allResults

    // 发送本地通知
    await scheduleNotification()
    logger.info("AutoInsight: analysis completed, \(entryCount) entries")
  }

  // MARK: - Data Loading

  private func loadGURUText(sinceHours hours: Int) -> String {
    let since = Date().addingTimeInterval(TimeInterval(-hours * 3600))
    let calendar = Calendar.current
    var lines: [String] = []

    // 遍历从 since 到今天的所有日期
    var cursor = since
    while cursor <= Date() {
      let entries = GURUDataService.shared.entries(for: cursor)
        .filter { $0.startTime >= since && $0.isMeaningful }
      for e in entries {
        let appCtx = e.appContext.isEmpty ? "未知" : e.appContext
        let text = String(e.text.prefix(300))
        lines.append("[\(e.formattedTime)][\(appCtx)] \(text)")
      }
      guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
      cursor = next
    }

    return lines.joined(separator: "\n")
  }

  // MARK: - AI Call

  private func callAI(prompt: String) async -> Result<String, Error> {
    await withCheckedContinuation { continuation in
      let messages = [AIMessage(role: "user", content: prompt)]
      AIService.shared.chat(messages: messages) { result in
        continuation.resume(returning: result)
      }
    }
  }

  // MARK: - Notification

  private func scheduleNotification() async {
    let center = UNUserNotificationCenter.current()

    // 检查权限
    let settings = await center.notificationSettings()
    guard settings.authorizationStatus == .authorized ||
          settings.authorizationStatus == .provisional else { return }

    let content = UNMutableNotificationContent()
    content.title = "你的每日洞察已生成 ✦"
    content.body = "心灵陪伴与事务指导已就绪，点击查看"
    content.sound = .default
    content.userInfo = ["action": "openAutoInsight"]

    // 立即触发（1秒后）
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    let request = UNNotificationRequest(
      identifier: "autoInsight_\(UUID().uuidString)",
      content: content,
      trigger: trigger
    )
    try? await center.add(request)
  }
}
