import Foundation

/// 剪贴板内容类型
public enum ClipboardContentType: String, Codable {
  case url        = "URL"
  case email      = "Email"
  case phone      = "电话"
  case code       = "代码"
  case text       = "文本"
}

/// 剪贴板记录条目
public struct ClipboardEntry: Codable, Identifiable {
  public let id: UUID
  /// 记录时间
  public let timestamp: Date
  /// 剪贴板内容
  public let content: String
  /// 内容类型
  public let contentType: ClipboardContentType

  public init(timestamp: Date, content: String, contentType: ClipboardContentType) {
    self.id = UUID()
    self.timestamp = timestamp
    self.content = content
    self.contentType = contentType
  }
}

public extension ClipboardEntry {
  var formattedTime: String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss"
    return f.string(from: timestamp)
  }

  /// 截断内容用于预览（前 100 字符）
  var preview: String {
    content.count <= 100 ? content : String(content.prefix(100)) + "…"
  }
}

extension ClipboardContentType {
  /// 从字符串内容推断类型
  static func infer(from text: String) -> ClipboardContentType {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

    // URL：以 http/https/ftp 开头，或典型域名格式
    if let url = URL(string: trimmed),
       let scheme = url.scheme,
       ["http", "https", "ftp"].contains(scheme) {
      return .url
    }

    // Email
    let emailPattern = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
    if trimmed.range(of: emailPattern, options: .regularExpression) != nil {
      return .email
    }

    // 电话号码（宽松匹配：纯数字/+/- /空格组合，8-15位）
    let phonePattern = #"^\+?[\d\s\-\(\)]{7,15}$"#
    if trimmed.range(of: phonePattern, options: .regularExpression) != nil {
      return .phone
    }

    // 代码（包含典型代码特征：花括号、括号配对、关键字）
    let codeSignals = ["{", "}", "=>", "->", "func ", "def ", "class ", "import ", "//", "/*", "var ", "let ", "const "]
    let codeMatchCount = codeSignals.filter { trimmed.contains($0) }.count
    if codeMatchCount >= 2 {
      return .code
    }

    return .text
  }
}
