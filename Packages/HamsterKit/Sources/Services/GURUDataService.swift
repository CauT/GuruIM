import Foundation

/// GURU 数据服务 - 本地存储、读取、上传 iCloud
/// 键盘扩展和主 App 共享同一个单例（通过 App Group）
public class GURUDataService {
  public static let shared = GURUDataService()

  private let fileManager = FileManager.default
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let writeQueue = DispatchQueue(label: "com.desgemini.guru.write", qos: .utility)

  // MARK: - Paths

  private var appGroupURL: URL? {
    fileManager.containerURL(forSecurityApplicationGroupIdentifier: HamsterConstants.appGroupName)
  }

  public var guruBaseURL: URL? {
    appGroupURL?.appendingPathComponent("GURU", isDirectory: true)
  }

  public static let dateFormatter: DateFormatter = {
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
    createDirectoryIfNeeded()
  }

  // MARK: - Write

  /// 保存一条完整的 session 记录（键盘 session 结束时调用）
  /// 写入前自动经过敏感词过滤，命中内容替换为 ***
  public func saveSession(_ entry: GURUEntry) {
    guard entry.isMeaningful else { return }
    let filtered = GURUEntry(
      startTime: entry.startTime,
      text: SensitiveFilter.shared.filter(entry.text),
      context: entry.context.map { SensitiveFilter.shared.filter($0) },
      appContext: entry.appContext
    )
    guard filtered.isMeaningful else { return }
    writeQueue.async { [weak self] in
      self?.writeEntry(filtered)
    }
  }

  private func writeEntry(_ entry: GURUEntry) {
    guard let url = dailyFileURL(for: entry.startTime) else { return }
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
    guard let base = guruBaseURL else { return [] }
    return (try? fileManager.contentsOfDirectory(atPath: base.path))?
      .compactMap { filename -> Date? in
        let name = (filename as NSString).deletingPathExtension
        return Self.dateFormatter.date(from: name)
      }
      .sorted(by: >) ?? []
  }

  public func entries(for date: Date) -> [GURUEntry] {
    guard let url = dailyFileURL(for: date),
          fileManager.fileExists(atPath: url.path),
          let content = try? String(contentsOf: url, encoding: .utf8) else { return [] }
    return content
      .components(separatedBy: "\n")
      .compactMap { line -> GURUEntry? in
        guard !line.isEmpty, let data = line.data(using: .utf8) else { return nil }
        return try? decoder.decode(GURUEntry.self, from: data)
      }
  }

  public func totalEntryCount() -> Int {
    availableDates().reduce(0) { $0 + entries(for: $1).count }
  }

  /// 文件大小（bytes）
  public func localStorageSize() -> Int64 {
    guard let base = guruBaseURL else { return 0 }
    let urls = (try? fileManager.contentsOfDirectory(
      at: base, includingPropertiesForKeys: [.fileSizeKey])) ?? []
    return urls.reduce(0) { sum, url in
      let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
      return sum + Int64(size)
    }
  }

  // MARK: - Delete

  public func deleteEntry(id: UUID, for date: Date) {
    guard let url = dailyFileURL(for: date) else { return }
    let remaining = entries(for: date).filter { $0.id != id }
    if remaining.isEmpty {
      try? fileManager.removeItem(at: url)
    } else {
      let lines = remaining.compactMap { try? encoder.encode($0) }.compactMap { String(data: $0, encoding: .utf8) }
      try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }
  }

  public func deleteEntries(for date: Date) {
    guard let url = dailyFileURL(for: date) else { return }
    try? fileManager.removeItem(at: url)
  }

  public func deleteAllEntries() {
    availableDates().forEach { deleteEntries(for: $0) }
  }

  // MARK: - Export (Markdown for AI)

  /// 导出指定日期的 Markdown 格式内容（适合喂给大模型）
  public func exportMarkdown(dates: [Date]) -> String {
    var md = "# My Input Log\n\n"
    for date in dates.sorted() {
      let entries = entries(for: date)
      guard !entries.isEmpty else { continue }
      md += "## \(Self.dateFormatter.string(from: date))\n\n"
      for entry in entries {
        md += "### \(entry.formattedTime) · \(entry.appContext)\n\n"
        if let ctx = entry.context, !ctx.isEmpty {
          md += "> **上下文:** \(ctx)\n\n"
        }
        md += entry.text + "\n\n"
        md += "---\n\n"
      }
    }
    return md
  }

  // MARK: - iCloud Upload

  public func uploadToiCloud(
    dates: [Date],
    progress: ((Double) -> Void)? = nil,
    completion: @escaping (Result<Int, Error>) -> Void
  ) {
    guard let icloudURL = URL.iCloudDocumentURL else {
      completion(.failure(GURUError.iCloudUnavailable))
      return
    }
    let guruiCloudURL = icloudURL.appendingPathComponent("GURU", isDirectory: true)
    do {
      try fileManager.createDirectory(at: guruiCloudURL, withIntermediateDirectories: true)
    } catch {
      completion(.failure(error))
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      var uploadedCount = 0
      let total = max(dates.count, 1)
      for (index, date) in dates.enumerated() {
        guard let localURL = self.dailyFileURL(for: date),
              self.fileManager.fileExists(atPath: localURL.path) else {
          progress?(Double(index + 1) / Double(total))
          continue
        }
        let filename = Self.dateFormatter.string(from: date) + ".jsonl"
        let destURL = guruiCloudURL.appendingPathComponent(filename)
        do {
          if self.fileManager.fileExists(atPath: destURL.path) {
            let localContent = try String(contentsOf: localURL, encoding: .utf8)
            let handle = try FileHandle(forWritingTo: destURL)
            handle.seekToEndOfFile()
            handle.write(Data(localContent.utf8))
            handle.closeFile()
          } else {
            try self.fileManager.copyItem(at: localURL, to: destURL)
          }
          uploadedCount += 1
        } catch {}
        progress?(Double(index + 1) / Double(total))
      }
      DispatchQueue.main.async {
        completion(.success(uploadedCount))
      }
    }
  }

  // MARK: - Private

  private func dailyFileURL(for date: Date) -> URL? {
    let filename = Self.dateFormatter.string(from: date) + ".jsonl"
    return guruBaseURL?.appendingPathComponent(filename)
  }

  private func createDirectoryIfNeeded() {
    guard let base = guruBaseURL else { return }
    try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)
  }

  // MARK: - Errors

  public enum GURUError: LocalizedError {
    case iCloudUnavailable
    public var errorDescription: String? {
      switch self {
      case .iCloudUnavailable: return "iCloud 不可用，请在设置中启用 iCloud"
      }
    }
  }
}
