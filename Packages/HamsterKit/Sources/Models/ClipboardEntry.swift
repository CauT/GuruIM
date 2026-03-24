import Foundation

/// 剪贴板内容类型
public enum ClipboardContentType: String, Codable {
  case url        = "URL"
  case email      = "Email"
  case phone      = "电话"
  case code       = "代码"
  case emoji      = "Emoji"
  case image      = "图片"
  case text       = "文本"
}

/// 剪贴板记录条目
public struct ClipboardEntry: Codable, Identifiable {
  public let id: UUID
  /// 记录时间
  public let timestamp: Date
  /// 文字内容（图片类型为空字符串）
  public let content: String
  /// 内容类型
  public let contentType: ClipboardContentType
  /// 图片文件名（仅 image 类型有效，存于 Clipboard/images/ 目录）
  public let imageFilename: String?

  public init(
    timestamp: Date,
    content: String,
    contentType: ClipboardContentType,
    imageFilename: String? = nil
  ) {
    self.id = UUID()
    self.timestamp = timestamp
    self.content = content
    self.contentType = contentType
    self.imageFilename = imageFilename
  }
}

public extension ClipboardEntry {
  var formattedTime: String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss"
    return f.string(from: timestamp)
  }

  /// 截断内容用于预览
  var preview: String {
    switch contentType {
    case .image: return "[图片]"
    default: return content.count <= 100 ? content : String(content.prefix(100)) + "…"
    }
  }

  var isMeaningful: Bool {
    switch contentType {
    case .image: return imageFilename != nil
    default: return !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
  }
}

// MARK: - Type Inference

public extension ClipboardContentType {
  static func infer(from text: String) -> ClipboardContentType {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

    // Emoji：字符串完全由 emoji 组成（或绝大多数是 emoji）
    if isMainlyEmoji(trimmed) { return .emoji }

    // URL
    if let url = URL(string: trimmed),
       let scheme = url.scheme,
       ["http", "https", "ftp"].contains(scheme),
       url.host != nil {
      return .url
    }

    // Email
    if trimmed.range(of: #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#, options: .regularExpression) != nil {
      return .email
    }

    // 电话号码
    if trimmed.range(of: #"^\+?[\d\s\-\(\)]{7,15}$"#, options: .regularExpression) != nil {
      return .phone
    }

    // 代码特征
    let codeSignals = ["{", "}", "=>", "->", "func ", "def ", "class ", "import ", "//", "/*", "var ", "let ", "const "]
    if codeSignals.filter({ trimmed.contains($0) }).count >= 2 { return .code }

    return .text
  }

  private static func isMainlyEmoji(_ text: String) -> Bool {
    guard !text.isEmpty else { return false }
    let emojiCount = text.unicodeScalars.filter { $0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value > 0x238C) }.count
    let total = text.unicodeScalars.filter { !$0.properties.isWhitespace }.count
    return total > 0 && Double(emojiCount) / Double(total) >= 0.7
  }
}
