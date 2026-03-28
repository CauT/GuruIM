import Foundation
import OSLog
import UserNotifications

/// 每日洞察配置
public struct AutoInsightConfig: Codable {
  public var isEnabled: Bool
  /// 两次分析之间最小间隔（分钟）
  public var intervalMinutes: Int
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
    intervalMinutes: Int = 24 * 60,
    personalBackground: String = "",
    spiritualPrompt: String = AutoInsightService.defaultSpiritualPrompt,
    taskPrompt: String = AutoInsightService.defaultTaskPrompt,
    lastRunDate: Date? = nil
  ) {
    self.isEnabled = isEnabled
    self.intervalMinutes = intervalMinutes
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
    let minInterval = TimeInterval(cfg.intervalMinutes * 60)
    return Date().timeIntervalSince(lastRun) >= minInterval
  }

  /// 满足条件时执行分析（异步，不阻塞键盘）
  public func runIfNeeded() async {
    let log = LogService.shared
    let cfg = config
    guard cfg.isEnabled else {
      log.log("跳过：未启用每日洞察", tag: "AutoInsight")
      return
    }
    let provider = AIService.shared.selectedProvider
    guard !AIService.shared.apiKey(for: provider).isEmpty else {
      log.log("跳过：\(provider.rawValue) API Key 未配置", level: .warn, tag: "AutoInsight")
      return
    }
    if let lastRun = cfg.lastRunDate {
      let elapsed = Date().timeIntervalSince(lastRun)
      let minInterval = TimeInterval(cfg.intervalMinutes * 60)
      guard elapsed >= minInterval else {
        let remaining = Int((minInterval - elapsed) / 60)
        log.log("跳过：距上次运行仅 \(Int(elapsed / 60)) 分钟，还需等待 \(remaining) 分钟", tag: "AutoInsight")
        return
      }
    }
    // 立即更新 lastRunDate，防止并发重入
    var updatedCfg = cfg
    updatedCfg.lastRunDate = Date()
    config = updatedCfg

    await run()
  }

  /// 手动立即触发分析（忽略时间间隔限制）
  public func runNow() async {
    let log = LogService.shared
    let provider = AIService.shared.selectedProvider
    guard !AIService.shared.apiKey(for: provider).isEmpty else {
      log.log("手动触发失败：\(provider.rawValue) API Key 未配置", level: .error, tag: "AutoInsight")
      return
    }
    var cfg = config
    cfg.lastRunDate = Date()
    config = cfg
    log.log("手动触发分析", tag: "AutoInsight")
    await run()
  }

  // MARK: - Core Analysis

  private func run() async {
    let log = LogService.shared
    let cfg = config
    log.log("开始分析（间隔 \(cfg.intervalMinutes) 分钟内的 GURU 数据）", tag: "AutoInsight")

    let guruText = loadGURUText(sinceMinutes: cfg.intervalMinutes)
    let entryCount = guruText.components(separatedBy: "\n").filter { !$0.isEmpty }.count

    guard !guruText.isEmpty else {
      log.log("无 GURU 数据，跳过本次分析", level: .warn, tag: "AutoInsight")
      return
    }
    log.log("GURU 数据 \(entryCount) 条，发起两路并发 AI 请求", tag: "AutoInsight")

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

    let spiritual: String
    switch spiritualResult {
    case .success(let s):
      spiritual = s
      log.log("心灵安慰 ✓ \(s.count) 字", tag: "AutoInsight")
    case .failure(let e):
      spiritual = "（分析失败，请检查 API Key 配置）"
      log.log("心灵安慰 ✗ \(e.localizedDescription)", level: .error, tag: "AutoInsight")
    }

    let task: String
    switch taskResult {
    case .success(let t):
      task = t
      log.log("事务指导 ✓ \(t.count) 字", tag: "AutoInsight")
    case .failure(let e):
      task = "（分析失败，请检查 API Key 配置）"
      log.log("事务指导 ✗ \(e.localizedDescription)", level: .error, tag: "AutoInsight")
    }

    let insight = AutoInsightResult(
      spiritualContent: spiritual,
      taskContent: task,
      entriesCount: entryCount
    )

    // 保存结果
    var allResults = results
    allResults.insert(insight, at: 0)
    results = allResults
    log.log("结果已保存（共 \(allResults.count) 条）", tag: "AutoInsight")

    // 发送本地通知
    await scheduleNotification()
  }

  // MARK: - Data Loading

  private func loadGURUText(sinceMinutes minutes: Int) -> String {
    let since = Date().addingTimeInterval(TimeInterval(-minutes * 60))
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
