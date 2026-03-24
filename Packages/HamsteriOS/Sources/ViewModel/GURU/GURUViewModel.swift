import Combine
import Foundation
import HamsterKit
import UIKit

class GURUViewModel: ObservableObject {
  // MARK: - Published State

  @Published var availableDates: [Date] = []
  @Published var selectedDates: Set<Date> = []
  @Published var previewEntries: [GURUEntry] = []
  @Published var previewDate: Date?
  @Published var isUploading: Bool = false
  @Published var uploadProgress: Double = 0
  @Published var statusMessage: String = ""
  @Published var totalEntryCount: Int = 0
  @Published var storageSize: String = ""

  private let service = GURUDataService.shared
  private let clipboardService = ClipboardMonitorService.shared

  // MARK: - Clipboard State

  @Published var clipboardEnabled: Bool = ClipboardMonitorService.shared.isEnabled
  @Published var clipboardEntryCount: Int = 0
  @Published var clipboardPreviewEntries: [ClipboardEntry] = []

  // MARK: - Init

  init() {
    reload()
  }

  // MARK: - Data

  func reload() {
    availableDates = service.availableDates()
    totalEntryCount = service.totalEntryCount()
    storageSize = formatBytes(service.localStorageSize())
    // 默认全选
    selectedDates = Set(availableDates)
    if let first = availableDates.first {
      loadPreview(for: first)
    }
    reloadClipboard()
  }

  func reloadClipboard() {
    clipboardEnabled = clipboardService.isEnabled
    clipboardEntryCount = clipboardService.totalEntryCount()
    if let today = clipboardService.availableDates().first {
      clipboardPreviewEntries = Array(clipboardService.entries(for: today).suffix(5).reversed())
    } else {
      clipboardPreviewEntries = []
    }
  }

  func toggleClipboardMonitor(_ enabled: Bool) {
    clipboardService.isEnabled = enabled
    clipboardEnabled = enabled
  }

  func loadPreview(for date: Date) {
    previewDate = date
    previewEntries = service.entries(for: date)
  }

  func toggleDateSelection(_ date: Date) {
    if selectedDates.contains(date) {
      selectedDates.remove(date)
    } else {
      selectedDates.insert(date)
    }
  }

  func selectAll() {
    selectedDates = Set(availableDates)
  }

  func deselectAll() {
    selectedDates = []
  }

  // MARK: - Upload

  func uploadSelected(completion: @escaping (Bool) -> Void) {
    guard !selectedDates.isEmpty else {
      statusMessage = "请先选择要上传的日期"
      completion(false)
      return
    }
    isUploading = true
    uploadProgress = 0
    statusMessage = "正在上传..."

    service.uploadToiCloud(
      dates: Array(selectedDates),
      progress: { [weak self] p in
        DispatchQueue.main.async { self?.uploadProgress = p }
      },
      completion: { [weak self] result in
        DispatchQueue.main.async {
          self?.isUploading = false
          switch result {
          case .success(let count):
            self?.statusMessage = "已上传 \(count) 个文件到 iCloud ✓"
            completion(true)
          case .failure(let error):
            self?.statusMessage = "上传失败：\(error.localizedDescription)"
            completion(false)
          }
        }
      }
    )
  }

  // MARK: - Export

  func exportMarkdown() -> String {
    service.exportMarkdown(dates: Array(selectedDates).sorted())
  }

  func exportFileURL() -> URL? {
    let markdown = exportMarkdown()
    let filename = "GURU-Export-\(Date().formatted(date: .abbreviated, time: .omitted)).md"
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    try? markdown.write(to: url, atomically: true, encoding: .utf8)
    return url
  }

  // MARK: - Delete

  func deleteDate(_ date: Date) {
    service.deleteEntries(for: date)
    reload()
  }

  func deleteSelected() {
    selectedDates.forEach { service.deleteEntries(for: $0) }
    reload()
  }

  // MARK: - Helpers

  func entryCount(for date: Date) -> Int {
    service.entries(for: date).count
  }

  func formattedDate(_ date: Date) -> String {
    GURUDataService.dateFormatter.string(from: date)
  }

  private func formatBytes(_ bytes: Int64) -> String {
    if bytes < 1024 { return "\(bytes) B" }
    if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
    return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
  }
}
