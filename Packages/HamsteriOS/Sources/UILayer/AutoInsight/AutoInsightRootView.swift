import HamsterKit
import SwiftUI
import UIKit

// MARK: - Date formatting helpers

private let dayFormatter: DateFormatter = {
  let f = DateFormatter()
  f.dateStyle = .medium
  f.timeStyle = .none
  return f
}()

private let longDayFormatter: DateFormatter = {
  let f = DateFormatter()
  f.dateStyle = .long
  f.timeStyle = .none
  return f
}()

private let timeFormatter: DateFormatter = {
  let f = DateFormatter()
  f.dateStyle = .none
  f.timeStyle = .short
  return f
}()

// MARK: - Root / List

public struct AutoInsightRootView: View {
  @StateObject private var viewModel = AutoInsightViewModel()
  @State private var selectedResult: AutoInsightResult?
  @State private var showSettings = false

  public init() {}

  public var body: some View {
    NavigationView {
      Group {
        if viewModel.results.isEmpty {
          emptyState
        } else {
          resultList
        }
      }
      .navigationTitle("每日洞察")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button { showSettings = true } label: {
            Image(systemName: "gearshape")
          }
        }
      }
    }
    .navigationViewStyle(.stack)
    .sheet(item: $selectedResult) { result in
      AutoInsightDetailView(result: result, viewModel: viewModel)
        .onDisappear { viewModel.reload() }
    }
    .sheet(isPresented: $showSettings) {
      AutoInsightSettingsView(viewModel: viewModel)
        .onDisappear { viewModel.reload() }
    }
    .onAppear { viewModel.reload() }
  }

  // MARK: Empty state

  private var emptyState: some View {
    VStack(spacing: 20) {
      Image(systemName: "sparkles")
        .font(.system(size: 56))
        .foregroundColor(.purple)

      Text("每日洞察")
        .font(.title2.bold())

      Text("开启后，咕噜输入法将定时自动分析你的输入记录，\n生成心灵陪伴与事务指导，通过通知提醒你查看。")
        .font(.subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)

      Button {
        showSettings = true
      } label: {
        Label("立即开启", systemImage: "bolt.fill")
          .font(.headline)
          .padding(.horizontal, 28)
          .padding(.vertical, 12)
      }
      .buttonStyle(.borderedProminent)
      .tint(.purple)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: Result list

  private var resultList: some View {
    List {
      ForEach(viewModel.results) { result in
        Button { selectedResult = result } label: {
          ResultRowView(result: result)
        }
        .buttonStyle(.plain)
      }
      .onDelete { offsets in
        offsets.forEach { viewModel.deleteResult(viewModel.results[$0]) }
      }
    }
    .listStyle(.insetGrouped)
  }
}

// MARK: - Result Row

private struct ResultRowView: View {
  let result: AutoInsightResult

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        if !result.isRead {
          Circle()
            .fill(.purple)
            .frame(width: 7, height: 7)
        }
        Text(dayFormatter.string(from: result.date))
          .font(.caption.bold())
          .foregroundColor(.secondary)
        Text(timeFormatter.string(from: result.date))
          .font(.caption)
          .foregroundColor(.secondary)
        Spacer()
        Text("分析了 \(result.entriesCount) 条")
          .font(.caption2)
          .foregroundColor(Color(uiColor: .tertiaryLabel))
      }

      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Label("心灵安慰", systemImage: "heart.fill")
            .font(.caption2.bold())
            .foregroundColor(.pink)
          Text(result.spiritualContent.prefix(50) + (result.spiritualContent.count > 50 ? "…" : ""))
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        VStack(alignment: .leading, spacing: 2) {
          Label("事务指导", systemImage: "checklist")
            .font(.caption2.bold())
            .foregroundColor(.blue)
          Text(result.taskContent.prefix(50) + (result.taskContent.count > 50 ? "…" : ""))
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(.vertical, 4)
  }
}

// MARK: - Detail View

public struct AutoInsightDetailView: View {
  let result: AutoInsightResult
  @ObservedObject var viewModel: AutoInsightViewModel
  @Environment(\.dismiss) private var dismiss

  @State private var shareItems: [Any]?
  @State private var showDeleteAlert = false

  public var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 24) {
          // 日期 + 统计
          VStack(spacing: 4) {
            Text(longDayFormatter.string(from: result.date))
              .font(.headline)
            Text(timeFormatter.string(from: result.date))
              .font(.subheadline)
              .foregroundColor(.secondary)
            Text("基于 \(result.entriesCount) 条输入记录生成")
              .font(.caption)
              .foregroundColor(Color(uiColor: .tertiaryLabel))
              .padding(.top, 2)
          }
          .padding(.top, 8)

          spiritualCard
          taskCard

          // 操作按钮行
          HStack(spacing: 12) {
            ShareButton(title: "分享心灵安慰", icon: "heart", color: .pink) {
              shareItems = [result.spiritualContent]
            }
            ShareButton(title: "分享事务指导", icon: "checklist", color: .blue) {
              shareItems = [result.taskContent]
            }
            ShareButton(title: "全部分享", icon: "square.and.arrow.up", color: .purple) {
              shareItems = [viewModel.shareText(for: result)]
            }
          }
          .padding(.horizontal, 4)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 40)
      }
      .navigationTitle("每日洞察")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("关闭") { dismiss() }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(role: .destructive) { showDeleteAlert = true } label: {
            Image(systemName: "trash")
              .foregroundColor(.red)
          }
        }
      }
    }
    .navigationViewStyle(.stack)
    .sheet(item: Binding(
      get: { shareItems.map(ShareItemsWrapper.init) },
      set: { if $0 == nil { shareItems = nil } }
    )) { wrapper in
      ShareSheet(items: wrapper.items)
    }
    .alert("确认删除", isPresented: $showDeleteAlert) {
      Button("删除", role: .destructive) {
        viewModel.deleteResult(result)
        dismiss()
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text("删除后无法恢复")
    }
    .onAppear { viewModel.markAsRead(result) }
  }

  // MARK: Cards

  private var spiritualCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label("心灵安慰", systemImage: "heart.text.square.fill")
        .font(.subheadline.bold())
        .foregroundColor(.pink)

      Text(result.spiritualContent)
        .font(.body)
        .lineSpacing(6)
        .foregroundColor(.primary)
        .textSelection(.enabled)
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      LinearGradient(
        colors: [Color(red: 1.0, green: 0.93, blue: 0.95), Color(red: 0.96, green: 0.90, blue: 1.0)],
        startPoint: .topLeading, endPoint: .bottomTrailing
      )
    )
    .cornerRadius(16)
  }

  private var taskCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label("事务指导", systemImage: "checklist")
        .font(.subheadline.bold())
        .foregroundColor(.blue)

      Text(result.taskContent)
        .font(.system(.body, design: .rounded))
        .lineSpacing(5)
        .foregroundColor(.primary)
        .textSelection(.enabled)
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      LinearGradient(
        colors: [Color(red: 0.90, green: 0.95, blue: 1.0), Color(red: 0.90, green: 0.98, blue: 0.95)],
        startPoint: .topLeading, endPoint: .bottomTrailing
      )
    )
    .cornerRadius(16)
  }
}

// MARK: - Settings View

public struct AutoInsightSettingsView: View {
  @ObservedObject var viewModel: AutoInsightViewModel
  @Environment(\.dismiss) private var dismiss

  // DEBUG: 5m 选项仅用于测试，上线前移除
  private let intervalOptions: [(String, Int)] = [
    ("5分钟", 5), ("12小时", 12 * 60), ("24小时", 24 * 60), ("48小时", 48 * 60), ("72小时", 72 * 60)
  ]

  public var body: some View {
    NavigationView {
      Form {
        // 开关
        Section {
          Toggle("启用每日洞察", isOn: $viewModel.isEnabled)
            .tint(.purple)
        } footer: {
          Text("开启后，输入法每隔设定时间自动分析输入记录，发送本地通知提醒你查看。")
        }

        // AI 配置
        Section {
          // Provider 选择
          ForEach(AIProvider.allCases, id: \.rawValue) { provider in
            HStack {
              Text(provider.rawValue)
              Spacer()
              if viewModel.aiSelectedProvider == provider {
                Image(systemName: "checkmark").foregroundColor(.accentColor)
              }
            }
            .contentShape(Rectangle())
            .onTapGesture { viewModel.setProvider(provider) }
          }

          // 模型名称
          HStack {
            Text("模型")
            Spacer()
            TextField(viewModel.aiSelectedProvider.defaultModel, text: Binding(
              get: { viewModel.aiSelectedModel },
              set: { viewModel.setModel($0) }
            ))
            .multilineTextAlignment(.trailing)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .foregroundColor(.secondary)
          }
        } header: {
          Text("AI 提供商")
        } footer: {
          Text("洞察功能需要 AI 后端。选择提供商并填入 API Key 后才能正常使用。")
        }

        // API Key
        Section("API Key") {
          InsightSecureKeyField(
            label: viewModel.aiSelectedProvider.rawValue,
            placeholder: "填入 API Key",
            key: viewModel.apiKey(for: viewModel.aiSelectedProvider)
          ) {
            viewModel.setAPIKey($0, for: viewModel.aiSelectedProvider)
          }
        }

        // 间隔
        Section("分析间隔") {
          Picker("间隔", selection: $viewModel.intervalMinutes) {
            ForEach(intervalOptions, id: \.1) { label, hours in
              Text(label).tag(hours)
            }
          }
          .pickerStyle(.segmented)
          .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        }

        // 个人背景
        Section {
          ZStack(alignment: .topLeading) {
            if viewModel.personalBackground.isEmpty {
              Text("例如：我是一名产品经理，平时关注效率和团队管理…")
                .foregroundColor(Color(uiColor: .tertiaryLabel))
                .font(.subheadline)
                .padding(.top, 8)
                .padding(.leading, 4)
                .allowsHitTesting(false)
            }
            TextEditor(text: $viewModel.personalBackground)
              .font(.subheadline)
              .frame(minHeight: 80)
          }
        } header: {
          Text("个人背景信息")
        } footer: {
          Text("填写后 AI 会结合你的背景给出更贴合的建议")
        }

        // Prompt
        Section {
          NavigationLink("心灵安慰 Prompt") {
            PromptEditorPage(
              title: "心灵安慰 Prompt",
              text: $viewModel.spiritualPrompt,
              defaultText: AutoInsightService.defaultSpiritualPrompt
            )
          }
          NavigationLink("事务指导 Prompt") {
            PromptEditorPage(
              title: "事务指导 Prompt",
              text: $viewModel.taskPrompt,
              defaultText: AutoInsightService.defaultTaskPrompt
            )
          }
        } header: {
          Text("提示词模板")
        } footer: {
          Text("在 Prompt 中使用 {data} 代表输入记录，{background} 代表个人背景。")
        }
      }
      .navigationTitle("每日洞察设置")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("完成") {
            viewModel.saveConfig()
            dismiss()
          }
          .font(.body.bold())
        }
      }
    }
    .navigationViewStyle(.stack)
  }
}

// MARK: - Prompt Editor Page

private struct PromptEditorPage: View {
  let title: String
  @Binding var text: String
  let defaultText: String

  var body: some View {
    VStack(spacing: 0) {
      TextEditor(text: $text)
        .font(.system(.body, design: .monospaced))
        .padding(8)
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button("恢复默认") { text = defaultText }
          .font(.subheadline)
      }
    }
  }
}

// MARK: - Helpers

private struct ShareButton: View {
  let title: String
  let icon: String
  let color: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 4) {
        Image(systemName: icon)
          .font(.system(size: 16))
        Text(title)
          .font(.caption2)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      .foregroundColor(color)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
      .background(color.opacity(0.1))
      .cornerRadius(10)
    }
  }
}

private struct InsightSecureKeyField: View {
  let label: String
  let placeholder: String
  let key: String
  let onSave: (String) -> Void

  @State private var text: String = ""
  @State private var isRevealed = false

  var body: some View {
    HStack {
      if isRevealed {
        TextField(placeholder, text: $text)
          .autocorrectionDisabled()
          .textInputAutocapitalization(.never)
          .onChange(of: text) { onSave($0) }
      } else {
        SecureField(placeholder, text: $text)
          .onChange(of: text) { onSave($0) }
      }
      Button { isRevealed.toggle() } label: {
        Image(systemName: isRevealed ? "eye.slash" : "eye").foregroundColor(.secondary)
      }
      .buttonStyle(.plain)
    }
    .onAppear { text = key }
  }
}

private struct ShareItemsWrapper: Identifiable {
  let id = UUID()
  let items: [Any]
}

private struct ShareSheet: UIViewControllerRepresentable {
  let items: [Any]
  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }
  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
