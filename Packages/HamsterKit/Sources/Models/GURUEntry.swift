import Foundation

/// GURU 数据采集条目 - 记录用户一次键盘 session 内的完整输入
public struct GURUEntry: Codable, Identifiable {
  public let id: UUID
  /// session 开始时间（键盘弹出时记录）
  public let startTime: Date
  /// 本次 session 内打出的完整文本（含标点、空格，已应用删除操作）
  public let text: String
  /// 键盘弹出瞬间光标周围已有的文本（session 开始前捕获，与 text 无重叠）
  public let context: String?
  /// 输入所在的 app 上下文描述（通过 textDocumentProxy 推断）
  public let appContext: String

  public init(startTime: Date, text: String, context: String?, appContext: String) {
    self.id = UUID()
    self.startTime = startTime
    self.text = text
    self.context = context
    self.appContext = appContext
  }
}

public extension GURUEntry {
  /// 格式化会话开始时间（用于展示）
  var formattedTime: String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f.string(from: startTime)
  }

  /// 键盘类型描述（兼容旧 UI 展示，返回 appContext）
  var keyboardType: String { appContext }

  /// 是否为有意义的内容（过滤纯空白）
  var isMeaningful: Bool {
    text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
  }
}
