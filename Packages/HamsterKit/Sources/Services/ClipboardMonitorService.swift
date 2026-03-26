import Foundation
import UIKit

/// 剪贴板监听服务 - 记录每次剪贴板内容变化（文字、图片、Emoji）
/// 键盘扩展和主 App 共享同一个单例（通过 App Group）
public class ClipboardMonitorService {
  public static let shared = ClipboardMonitorService()

  private let fileManager = FileManager.default
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let writeQueue = DispatchQueue(label: "com.desgemini.clipboard.write", qos: .utility)
  private let defaults = UserDefaults(suiteName: HamsterConstants.appGroupName)

  /// 上次记录时的 changeCount，持久化到 UserDefaults，防止进程重启后漏采
  /// 默认 -1 确保首次运行时总会触发一次检查
  private var lastChangeCount: Int {
    get { defaults?.object(forKey: "clipboard_last_change_count") as? Int ?? -1 }
    set { defaults?.set(newValue, forKey: "clipboard_last_change_count") }
  }

  /// 是否启用剪贴板监听
  public var isEnabled: Bool {
    get { defaults?.bool(forKey: "clipboardMonitorEnabled") ?? false }
    set { defaults?.set(newValue, forKey: "clipboardMonitorEnabled") }
  }

  // MARK: - Paths

  private var appGroupURL: URL? {
    fileManager.containerURL(forSecurityApplicationGroupIdentifier: HamsterConstants.appGroupName)
  }

  public var clipboardBaseURL: URL? {
    appGroupURL?.appendingPathComponent("Clipboard", isDirectory: true)
  }

  private var imagesURL: URL? {
    clipboardBaseURL?.appendingPathComponent("images", isDirectory: true)
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
    createDirectoriesIfNeeded()
  }

  // MARK: - Monitor

  /// 检查剪贴板是否有新内容，有则记录（在键盘弹出时调用）
  public func checkAndRecord() {
    guard isEnabled else { return }
    let current = UIPasteboard.general.changeCount
    guard current != lastChangeCount else { return }
    lastChangeCount = current

    let pasteboard = UIPasteboard.general

    // 优先尝试图片
    if pasteboard.hasImages, let image = pasteboard.image {
      recordImage(image)
      return
    }

    // 文字（含 Emoji）：写入前经敏感词过滤
    guard let rawText = pasteboard.string,
          !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    let text = SensitiveFilter.shared.filter(rawText)
    let type = ClipboardContentType.infer(from: text)
    let entry = ClipboardEntry(timestamp: Date(), content: text, contentType: type)
    writeQueue.async { [weak self] in self?.writeEntry(entry) }
  }

  private func recordImage(_ image: UIImage) {
    writeQueue.async { [weak self] in
      guard let self else { return }
      // 保存图片到 Clipboard/images/UUID.jpg
      let filename = "\(UUID().uuidString).jpg"
      guard let imgURL = self.imagesURL?.appendingPathComponent(filename),
            let data = image.jpegData(compressionQuality: 0.8)
      else { return }
      try? data.write(to: imgURL)
      let entry = ClipboardEntry(
        timestamp: Date(),
        content: "",
        contentType: .image,
        imageFilename: filename
      )
      self.writeEntry(entry)
    }
  }

  // MARK: - Write

  private func writeEntry(_ entry: ClipboardEntry) {
    guard entry.isMeaningful, let url = dailyFileURL(for: entry.timestamp) else { return }
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

  /// 读取图片数据（仅 image 类型条目有效）
  public func imageData(for entry: ClipboardEntry) -> UIImage? {
    guard entry.contentType == .image, let filename = entry.imageFilename,
          let url = imagesURL?.appendingPathComponent(filename) else { return nil }
    return UIImage(contentsOfFile: url.path)
  }

  public func totalEntryCount() -> Int {
    availableDates().reduce(0) { $0 + entries(for: $1).count }
  }

  // MARK: - Delete

  public func deleteEntry(id: UUID, for date: Date) {
    guard let url = dailyFileURL(for: date) else { return }
    let all = entries(for: date)
    // 删除该条目引用的图片
    if let entry = all.first(where: { $0.id == id }), let filename = entry.imageFilename {
      if let imgURL = imagesURL?.appendingPathComponent(filename) {
        try? fileManager.removeItem(at: imgURL)
      }
    }
    let remaining = all.filter { $0.id != id }
    if remaining.isEmpty {
      try? fileManager.removeItem(at: url)
    } else {
      let lines = remaining.compactMap { try? encoder.encode($0) }.compactMap { String(data: $0, encoding: .utf8) }
      try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }
  }

  public func deleteEntries(for date: Date) {
    // 同时删除当天引用的图片文件
    entries(for: date).compactMap(\.imageFilename).forEach { filename in
      if let url = imagesURL?.appendingPathComponent(filename) {
        try? fileManager.removeItem(at: url)
      }
    }
    guard let url = dailyFileURL(for: date) else { return }
    try? fileManager.removeItem(at: url)
  }

  public func deleteAllEntries() {
    availableDates().forEach { deleteEntries(for: $0) }
  }

  // MARK: - Export

  public func exportMarkdown(dates: [Date]) -> String {
    var md = "# Clipboard Log\n\n"
    for date in dates.sorted() {
      let entries = entries(for: date)
      guard !entries.isEmpty else { continue }
      md += "## \(Self.dateFormatter.string(from: date))\n\n"
      for entry in entries {
        md += "### \(entry.formattedTime) · [剪贴板/\(entry.contentType.rawValue)]\n\n"
        if entry.contentType == .image {
          md += "_[图片已保存，文件名: \(entry.imageFilename ?? "unknown")]_\n\n"
        } else {
          md += entry.content + "\n\n"
        }
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

  private func createDirectoriesIfNeeded() {
    if let base = clipboardBaseURL {
      try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)
    }
    if let imgs = imagesURL {
      try? fileManager.createDirectory(at: imgs, withIntermediateDirectories: true)
    }
  }
}
