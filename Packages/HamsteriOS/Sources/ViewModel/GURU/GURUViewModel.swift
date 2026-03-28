import Combine
import Foundation
import HamsterKit
import UIKit

class GURUViewModel: ObservableObject {
  // MARK: - Published State (GURU)

  @Published var availableDates: [Date] = []
  @Published var selectedDates: Set<Date> = []
  @Published var previewEntries: [GURUEntry] = []
  @Published var previewDate: Date?
  @Published var isUploading: Bool = false
  @Published var uploadProgress: Double = 0
  @Published var statusMessage: String = ""
  @Published var totalEntryCount: Int = 0
  @Published var storageSize: String = ""

  // MARK: - Clipboard State

  @Published var clipboardEnabled: Bool = ClipboardMonitorService.shared.isEnabled
  @Published var clipboardEntryCount: Int = 0
  @Published var clipboardPreviewEntries: [ClipboardEntry] = []


  // MARK: - AI State

  @Published var aiSelectedProvider: AIProvider = AIService.shared.selectedProvider
  @Published var aiSelectedModel: String = AIService.shared.selectedModel
  @Published var aiMessages: [AIMessage] = []
  @Published var aiIsLoading: Bool = false
  @Published var aiStatusMessage: String = ""
  @Published var savedPrompts: [AIPrompt] = AIService.shared.savedPrompts

  private let service = GURUDataService.shared
  private let clipboardService = ClipboardMonitorService.shared
  private let aiService = AIService.shared

  // MARK: - Init

  init() { reload() }

  // MARK: - Data

  func reload() {
    availableDates = service.availableDates()
    totalEntryCount = service.totalEntryCount()
    storageSize = formatBytes(service.localStorageSize())
    selectedDates = Set(availableDates)
    if let first = availableDates.first { loadPreview(for: first) }
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
    if selectedDates.contains(date) { selectedDates.remove(date) }
    else { selectedDates.insert(date) }
  }

  func selectAll() { selectedDates = Set(availableDates) }
  func deselectAll() { selectedDates = [] }

  // MARK: - iCloud Upload

  func uploadSelected(completion: @escaping (Bool) -> Void) {
    guard !selectedDates.isEmpty else { statusMessage = "请先选择要上传的日期"; completion(false); return }
    isUploading = true
    uploadProgress = 0
    statusMessage = "正在上传..."
    service.uploadToiCloud(
      dates: Array(selectedDates),
      progress: { [weak self] p in DispatchQueue.main.async { self?.uploadProgress = p } },
      completion: { [weak self] result in
        DispatchQueue.main.async {
          self?.isUploading = false
          switch result {
          case .success(let count): self?.statusMessage = "已上传 \(count) 个文件到 iCloud ✓"; completion(true)
          case .failure(let error): self?.statusMessage = "上传失败：\(error.localizedDescription)"; completion(false)
          }
        }
      }
    )
  }

  // MARK: - Export

  func exportMarkdown() -> String { service.exportMarkdown(dates: Array(selectedDates).sorted()) }

  func exportFileURL() -> URL? {
    let markdown = exportMarkdown()
    let filename = "GURU-Export-\(Date().formatted(date: .abbreviated, time: .omitted)).md"
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    try? markdown.write(to: url, atomically: true, encoding: .utf8)
    return url
  }

  // MARK: - Delete

  func deleteDate(_ date: Date) { service.deleteEntries(for: date); reload() }
  func deleteSelected() { selectedDates.forEach { service.deleteEntries(for: $0) }; reload() }

  func deleteEntry(id: UUID) {
    guard let date = previewDate else { return }
    service.deleteEntry(id: id, for: date)
    previewEntries.removeAll { $0.id == id }
    totalEntryCount = service.totalEntryCount()
  }

  func deleteClipboardEntry(id: UUID) {
    guard let date = clipboardService.availableDates().first else { return }
    clipboardService.deleteEntry(id: id, for: date)
    clipboardPreviewEntries.removeAll { $0.id == id }
    clipboardEntryCount = clipboardService.totalEntryCount()
  }

  func clearAllClipboardEntries() {
    clipboardService.deleteAllEntries()
    clipboardPreviewEntries.removeAll()
    clipboardEntryCount = 0
  }

  // MARK: - AI

  func setProvider(_ provider: AIProvider) {
    aiService.selectedProvider = provider
    aiSelectedProvider = provider
    aiSelectedModel = provider.defaultModel
    aiService.selectedModel = aiSelectedModel
  }

  func setModel(_ model: String) {
    aiService.selectedModel = model
    aiSelectedModel = model
  }

  func setAPIKey(_ key: String, for provider: AIProvider) {
    aiService.setApiKey(key, for: provider)
  }

  func apiKey(for provider: AIProvider) -> String {
    aiService.apiKey(for: provider)
  }

  /// 构建携带选定日期数据的用户消息并发送
  func sendAIQuery(prompt: AIPrompt, includeGURU: Bool, includeClipboard: Bool) {
    var contextText = prompt.content

    if includeGURU && !selectedDates.isEmpty {
      contextText += "\n\n## 我的输入记录（选定日期）\n\n"
      contextText += service.exportMarkdown(dates: Array(selectedDates).sorted())
    }

    if includeClipboard {
      let clipDates = clipboardService.availableDates()
      if !clipDates.isEmpty {
        contextText += "\n\n## 我的剪贴板记录\n\n"
        contextText += clipboardService.exportMarkdown(dates: clipDates)
      }
    }

    sendAIMessage(content: contextText)
  }

  func sendAIMessage(content: String) {
    guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    aiMessages.append(AIMessage(role: "user", content: content))
    aiIsLoading = true
    aiStatusMessage = "AI 分析中..."

    aiService.chat(messages: aiMessages) { [weak self] result in
      DispatchQueue.main.async {
        self?.aiIsLoading = false
        switch result {
        case .success(let reply):
          self?.aiMessages.append(AIMessage(role: "assistant", content: reply))
          self?.aiStatusMessage = ""
        case .failure(let error):
          self?.aiStatusMessage = error.localizedDescription
        }
      }
    }
  }

  func clearAIConversation() {
    aiMessages = []
    aiStatusMessage = ""
  }

  func reloadSavedPrompts() {
    savedPrompts = aiService.savedPrompts
  }

  func savePrompt(_ prompt: AIPrompt) {
    if savedPrompts.contains(where: { $0.id == prompt.id }) {
      aiService.updatePrompt(prompt)
    } else {
      aiService.addPrompt(prompt)
    }
    reloadSavedPrompts()
  }

  func deletePrompt(id: UUID) {
    aiService.deletePrompt(id: id)
    reloadSavedPrompts()
  }

  // MARK: - Helpers

  func entryCount(for date: Date) -> Int { service.entries(for: date).count }
  func formattedDate(_ date: Date) -> String { GURUDataService.dateFormatter.string(from: date) }

  private func formatBytes(_ bytes: Int64) -> String {
    if bytes < 1024 { return "\(bytes) B" }
    if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
    return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
  }
}
