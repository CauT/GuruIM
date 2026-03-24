import Foundation
import UIKit

/// 剪贴板监听服务 - 记录每次剪贴板内容变化
/// 键盘扩展和主 App 共享同一个单例（通过 App Group）
public class ClipboardMonitorService {
  public static let shared = ClipboardMonitorService()

  private let fileManager = FileManager.default
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let writeQueue = DispatchQueue(label: "com.desgemini.clipboard.write", qos: .utility)

  /// 上次记录时的 changeCount，用于检测新变化
  private var lastChangeCount: Int

  /// 是否启用剪贴板监听（从 UserDefaults App Group 读取）
  public var isEnabled: Bool {
    get {
      UserDefaults(suiteName: HamsterConstants.appGroupName)?.bool(forKey: "clipboardMonitorEnabled") ?? false
    }
    set {
      UserDefaults(suiteName: HamsterConstants.appGroupName)?.set(newValue, forKey: "clipboardMonitorEnabled")
    }
  }

  // MARK: - Paths

  private var appGroupURL: URL? {
    fileManager.containerURL(forSecurityApplicationGroupIdentifier: HamsterConstants.appGroupName)
  }

  public var clipboardBaseURL: URL? {
    appGroupURL?.appendingPathComponent("Clipboard", isDirectory: true)
  }

  private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = .current
    return f
  }()

  // MARK: - Init

  public init() {
    encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    lastChangeCount = UIPasteboard.general.changeCount
    createDirectoryIfNeeded()
  }

  // MARK: - Monitor

  /// 检查剪贴板是否有新内容，有则记录（在键盘弹出时调用）
  public func checkAndRecord() {
    guard isEnabled else { return }
    let current = UIPasteboard.general.changeCount
    guard current != lastChangeCount else { return }
    lastChangeCount = current

    guard let text = UIPasteboard.general.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

    let entry = ClipboardEntry(
      timestamp: Date(),
      content: text,
      contentType: ClipboardContentType.infer(from: text)
    )
    writeQueue.async { [weak self] in
      self?.writeEntry(entry)
    }
  }

  // MARK: - Write

  private func writeEntry(_ entry: ClipboardEntry) {
    guard let url = dailyFileURL(for: entry.timestamp) else { return }
    do {
      let data = try encoder.encode(entry)
      guard var line = String(data: data, encoding: .utf8) else { return }
      line += "\n"
      if fileManager.fileExists(atPath: url.path) {
        let handle = try FileHandle(forWritingTo: url)
        handle.seekToEndOfFile()
        handle.write(Data(line.utf8))
        handle.closeFile()
      } else {
        try line.write(to: url, atomically: false, encoding: .utf8)
      }
    } catch {
      // 键盘扩展不能崩溃，静默失败
    }
  }

  // MARK: - Read

  public func availableDates() -> [Date] {
    guard let base = clipboardBaseURL else { return [] }
    return (try? fileManager.contentsOfDirectory(atPath: base.path))?
      .compactMap { filename -> Date? in
        let name = (filename as NSString).deletingPathExtension
        return Self.dateFormatter.date(from: name)
      }
      .sorted(by: >) ?? []
  }

  public func entries(for date: Date) -> [ClipboardEntry] {
    guard let url = dailyFileURL(for: date),
          fileManager.fileExists(atPath: url.path),
          let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
    return content
      .components(separatedBy: "\n")
      .compactMap { line -> ClipboardEntry? in
        guard !line.isEmpty, let data = line.data(using: .utf8) else { return nil }
        return try? decoder.decode(ClipboardEntry.self, from: data)
      }
  }

  public func totalEntryCount() -> Int {
    availableDates().reduce(0) { $0 + entries(for: $1).count }
  }

  // MARK: - Delete

  public func deleteEntries(for date: Date) {
    guard let url = dailyFileURL(for: date) else { return }
    try? fileManager.removeItem(at: url)
  }

  public func deleteAllEntries() {
    availableDates().forEach { deleteEntries(for: $0) }
  }

  // MARK: - Export (Markdown for AI)

  /// 导出 Markdown 格式（适合喂给大模型）
  public func exportMarkdown(dates: [Date]) -> String {
    var md = "# Clipboard Log\n\n"
    for date in dates.sorted() {
      let entries = entries(for: date)
      guard !entries.isEmpty else { continue }
      md += "## \(Self.dateFormatter.string(from: date))\n\n"
      for entry in entries {
        md += "### \(entry.formattedTime) · [剪贴板/\(entry.contentType.rawValue)]\n\n"
        md += entry.content + "\n\n"
        md += "---\n\n"
      }
    }
    return md
  }

  // MARK: - Private

  private func dailyFileURL(for date: Date) -> URL? {
    let filename = Self.dateFormatter.string(from: date) + ".jsonl"
    return clipboardBaseURL?.appendingPathComponent(filename)
  }

  private func createDirectoryIfNeeded() {
    guard let base = clipboardBaseURL else { return }
    try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)
  }
}
