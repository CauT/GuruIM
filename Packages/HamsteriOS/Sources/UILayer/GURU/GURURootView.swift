import HamsterKit
import SwiftUI

struct GURURootView: View {
  @ObservedObject var viewModel: GURUViewModel
  @State private var showDeleteAlert = false
  @State private var dateToDelete: Date?
  @State private var showDeleteSelectedAlert = false
  @State private var showingPreview = false

  var body: some View {
    List {
      // 统计概览
      Section {
        statsRow
      } header: {
        Text("数据概览")
      }

      // 日期列表
      Section {
        if viewModel.availableDates.isEmpty {
          Text("暂无采集数据\n使用仓输入法打字后将在此显示")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        } else {
          ForEach(viewModel.availableDates, id: \.self) { date in
            dateRow(date)
          }
        }
      } header: {
        HStack {
          Text("采集记录")
          Spacer()
          Button(viewModel.selectedDates.count == viewModel.availableDates.count ? "全不选" : "全选") {
            if viewModel.selectedDates.count == viewModel.availableDates.count {
              viewModel.deselectAll()
            } else {
              viewModel.selectAll()
            }
          }
          .font(.caption)
        }
      }

      // 操作区
      if !viewModel.availableDates.isEmpty {
        Section {
          uploadButton
          exportButton
          deleteSelectedButton
        } header: {
          Text("操作")
        }
      }

      // 状态消息
      if !viewModel.statusMessage.isEmpty {
        Section {
          Text(viewModel.statusMessage)
            .font(.subheadline)
            .foregroundColor(viewModel.statusMessage.contains("✓") ? .green : .secondary)
        }
      }

      // 剪贴板监听
      Section {
        Toggle(isOn: Binding(
          get: { viewModel.clipboardEnabled },
          set: { viewModel.toggleClipboardMonitor($0) }
        )) {
          Label("剪贴板监听", systemImage: "clipboard")
        }
        if viewModel.clipboardEnabled {
          HStack {
            Label("已记录", systemImage: "doc.on.clipboard")
            Spacer()
            Text("\(viewModel.clipboardEntryCount) 条")
              .foregroundColor(.secondary)
          }
          .font(.subheadline)
        }
      } header: {
        Text("剪贴板")
      } footer: {
        Text("开启后，每次使用仓输入法时将自动记录剪贴板新增内容（含时间戳与类型标注），供 AI 助理分析。")
          .font(.caption)
      }

      // 最近剪贴板记录
      if viewModel.clipboardEnabled && !viewModel.clipboardPreviewEntries.isEmpty {
        Section {
          ForEach(viewModel.clipboardPreviewEntries) { entry in
            VStack(alignment: .leading, spacing: 3) {
              HStack {
                Text(entry.formattedTime)
                  .font(.caption2)
                  .foregroundColor(.secondary)
                Text("·")
                  .font(.caption2)
                  .foregroundColor(.secondary)
                Text("[剪贴板/\(entry.contentType.rawValue)]")
                  .font(.caption2)
                  .foregroundColor(.accentColor)
              }
              Text(entry.preview)
                .font(.caption)
                .lineLimit(2)
            }
            .padding(.vertical, 2)
          }
        } header: {
          Text("最近剪贴板（今日）")
        }
      }

      // 说明
      Section {
        helpText
      } header: {
        Text("说明")
      }
    }
    .navigationTitle("Now Guru")
    .sheet(isPresented: $showingPreview) {
      previewSheet
    }
    .alert("删除确认", isPresented: $showDeleteAlert) {
      Button("删除", role: .destructive) {
        if let date = dateToDelete { viewModel.deleteDate(date) }
      }
      Button("取消", role: .cancel) {}
    } message: {
      if let date = dateToDelete {
        Text("删除 \(viewModel.formattedDate(date)) 的本地记录？iCloud 中的数据不受影响。")
      }
    }
    .alert("删除选中记录", isPresented: $showDeleteSelectedAlert) {
      Button("删除", role: .destructive) {
        viewModel.deleteSelected()
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text("删除已选 \(viewModel.selectedDates.count) 天的本地记录？iCloud 中的数据不受影响。")
    }
    .onAppear { viewModel.reload() }
  }

  // MARK: - Components

  var statsRow: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Label("\(viewModel.totalEntryCount) 条记录", systemImage: "doc.text")
        Spacer()
        Label(viewModel.storageSize, systemImage: "internaldrive")
          .foregroundColor(.secondary)
      }
      HStack {
        Label("\(viewModel.availableDates.count) 天", systemImage: "calendar")
        Spacer()
        Label("\(viewModel.selectedDates.count) 天已选", systemImage: "checkmark.circle")
          .foregroundColor(.accentColor)
      }
    }
    .font(.subheadline)
  }

  func dateRow(_ date: Date) -> some View {
    HStack {
      Image(systemName: viewModel.selectedDates.contains(date) ? "checkmark.circle.fill" : "circle")
        .foregroundColor(viewModel.selectedDates.contains(date) ? .accentColor : .secondary)
        .onTapGesture { viewModel.toggleDateSelection(date) }

      VStack(alignment: .leading, spacing: 2) {
        Text(viewModel.formattedDate(date))
          .font(.body)
        Text("\(viewModel.entryCount(for: date)) 条")
          .font(.caption)
          .foregroundColor(.secondary)
      }

      Spacer()

      Button {
        viewModel.loadPreview(for: date)
        showingPreview = true
      } label: {
        Image(systemName: "eye")
          .foregroundColor(.secondary)
      }
      .buttonStyle(.plain)
    }
    .swipeActions(edge: .trailing) {
      Button(role: .destructive) {
        dateToDelete = date
        showDeleteAlert = true
      } label: {
        Label("删除", systemImage: "trash")
      }
    }
  }

  var uploadButton: some View {
    Button {
      viewModel.uploadSelected { _ in }
    } label: {
      HStack {
        if viewModel.isUploading {
          ProgressView(value: viewModel.uploadProgress)
            .frame(width: 80)
          Text("上传中 \(Int(viewModel.uploadProgress * 100))%")
        } else {
          Image(systemName: "icloud.and.arrow.up")
          Text("上传到 iCloud（\(viewModel.selectedDates.count) 天）")
        }
      }
    }
    .disabled(viewModel.isUploading || viewModel.selectedDates.isEmpty)
  }

  var exportButton: some View {
    Button {
      guard let url = viewModel.exportFileURL() else { return }
      let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
      // 直接通过 UIKit 呈现，避免嵌套在 SwiftUI sheet 里导致白屏
      UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }?
        .rootViewController?
        .present(activityVC, animated: true)
    } label: {
      HStack {
        Image(systemName: "square.and.arrow.up")
        Text("导出为 Markdown（供 AI 分析）")
      }
    }
    .disabled(viewModel.selectedDates.isEmpty)
  }

  var previewSheet: some View {
    NavigationView {
      List {
        if let date = viewModel.previewDate {
          Section("\(viewModel.formattedDate(date)) · \(viewModel.previewEntries.count) 条") {
            ForEach(viewModel.previewEntries) { entry in
              VStack(alignment: .leading, spacing: 4) {
                if let ctx = entry.context, !ctx.isEmpty {
                  Text(ctx)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(6)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
                }
                Text(entry.text)
                  .font(.body)
                HStack {
                  Text(entry.formattedTime)
                  Text("·")
                  Text(entry.appContext)
                }
                .font(.caption2)
                .foregroundColor(.secondary)
              }
              .padding(.vertical, 2)
            }
          }
        }
      }
      .navigationTitle("预览")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("关闭") { showingPreview = false }
        }
      }
    }
  }

  var deleteSelectedButton: some View {
    Button(role: .destructive) {
      showDeleteSelectedAlert = true
    } label: {
      HStack {
        Image(systemName: "trash")
        Text("删除本地记录（\(viewModel.selectedDates.count) 天）")
      }
    }
    .disabled(viewModel.selectedDates.isEmpty)
  }

  var helpText: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("• 仓输入法在使用过程中自动采集您的输入（RIME 上屏词汇及英文单词）")
      Text("• 数据保存在本机私有空间，不会自动上传")
      Text("• 点击「上传到 iCloud」将选定日期的数据同步至 iCloud Drive/GURU/")
      Text("• 导出 Markdown 文件后，可直接粘贴到 Claude、ChatGPT 等 AI 助手进行分析")
      Text("• 删除本地记录不影响已上传到 iCloud 的数据")
    }
    .font(.caption)
    .foregroundColor(.secondary)
  }
}

