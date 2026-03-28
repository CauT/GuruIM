import Foundation

public class LogService {
  public static let shared = LogService()

  public enum Level: String {
    case info  = "INFO"
    case warn  = "WARN"
    case error = "ERROR"
  }

  private let maxLines = 500
  private let trimTarget = 400   // 超上限后保留的行数
  private let writeQueue = DispatchQueue(label: "com.desgemini.log", qos: .utility)

  private var fileURL: URL? {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: HamsterConstants.appGroupName)?
      .appendingPathComponent("debug_log.txt")
  }

  // MARK: - Write

  public func log(_ message: String, level: Level = .info, tag: String = "") {
    let line = format(message, level: level, tag: tag)
    writeQueue.async { [weak self] in
      self?.appendLine(line)
    }
  }

  private func format(_ message: String, level: Level, tag: String) -> String {
    let ts = Self.timestampFormatter.string(from: Date())
    let tagPart = tag.isEmpty ? "" : "[\(tag)] "
    return "[\(ts)] [\(level.rawValue)] \(tagPart)\(message)"
  }

  private func appendLine(_ line: String) {
    guard let url = fileURL else { return }
    let fm = FileManager.default

    if !fm.fileExists(atPath: url.path) {
      try? (line + "\n").write(to: url, atomically: false, encoding: .utf8)
      return
    }

    // 先检查行数，超限时修剪
    if let existing = try? String(contentsOf: url, encoding: .utf8) {
      var lines = existing.components(separatedBy: "\n").filter { !$0.isEmpty }
      if lines.count >= maxLines {
        lines = Array(lines.suffix(trimTarget))
        let trimmed = lines.joined(separator: "\n") + "\n" + line + "\n"
        try? trimmed.write(to: url, atomically: true, encoding: .utf8)
        return
      }
    }

    // 普通追加
    guard let handle = try? FileHandle(forWritingTo: url) else {
      try? (line + "\n").write(to: url, atomically: false, encoding: .utf8)
      return
    }
    handle.seekToEndOfFile()
    handle.write(Data((line + "\n").utf8))
    handle.closeFile()
  }

  // MARK: - Read

  /// 返回日志行（新→旧）
  public func entries() -> [String] {
    guard let url = fileURL,
          let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
    return content.components(separatedBy: "\n")
      .filter { !$0.isEmpty }
      .reversed()
  }

  public func exportText() -> String {
    entries().reversed().joined(separator: "\n")
  }

  // MARK: - Clear

  public func clear() {
    writeQueue.async { [weak self] in
      guard let url = self?.fileURL else { return }
      try? "".write(to: url, atomically: true, encoding: .utf8)
    }
  }

  // MARK: - Helpers

  private static let timestampFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MM-dd HH:mm:ss"
    return f
  }()
}

