import HamsterKit
import SwiftUI

// MARK: - Formatters

private let sfDayFormatter: DateFormatter = {
  let f = DateFormatter()
  f.dateFormat = "MM-dd"
  return f
}()

private let sfTimeFormatter: DateFormatter = {
  let f = DateFormatter()
  f.dateFormat = "HH:mm"
  return f
}()

// MARK: - Root View

public struct SmartFreqRootView: View {
  @StateObject private var viewModel = SmartFreqViewModel()
  @State private var showSettings = false

  public init() {}

  public var body: some View {
    NavigationView {
      Group {
        if viewModel.results.isEmpty && !viewModel.isEnabled {
          emptyState
        } else {
          mainContent
        }
      }
      .navigationTitle("智能调频")
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
    .sheet(isPresented: $showSettings) {
      SmartFreqSettingsView(viewModel: viewModel)
        .onDisappear { viewModel.reload() }
    }
    .onAppear { viewModel.reload() }
  }

  // MARK: Empty State

  private var emptyState: some View {
    VStack(spacing: 20) {
      Image(systemName: "bolt.fill")
        .font(.system(size: 56))
        .foregroundColor(.cyan)

      Text("智能调频")
        .font(.title2.bold())

      Text("开启后，输入法将静默分析你的输入习惯，\n自动优化候选词排序并发现新词。")
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
      .tint(.cyan)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: Main Content

  private var mainContent: some View {
    List {
      // Stats Dashboard
      Section {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
          StatCard(title: "调频次数", value: "\(viewModel.totalFreqAdjustments)", color: .cyan)
          StatCard(title: "新增词数", value: "\(viewModel.totalNewPhrases)", color: .green)
          StatCard(title: "Token 消耗", value: viewModel.formatTokens(viewModel.currentMonthTokens), color: .orange)
          StatCard(title: "上次分析", value: viewModel.relativeTime(from: viewModel.lastRunDate), color: .purple)
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        .listRowBackground(Color.clear)
      }

      // History
      Section("分析记录") {
        ForEach(viewModel.results) { result in
          SmartFreqResultRow(result: result)
        }
        .onDelete { offsets in
          offsets.forEach { viewModel.deleteResult(viewModel.results[$0]) }
        }
      }
    }
    .listStyle(.insetGrouped)
  }
}

// MARK: - Stat Card

private struct StatCard: View {
  let title: String
  let value: String
  let color: Color

  var body: some View {
    VStack(spacing: 6) {
      Text(value)
        .font(.title2.bold().monospacedDigit())
        .foregroundColor(color)
      Text(title)
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 14)
    .background(color.opacity(0.1))
    .cornerRadius(12)
  }
}

// MARK: - Result Row

private struct SmartFreqResultRow: View {
  let result: SmartFreqResult

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text("\(sfDayFormatter.string(from: result.date)) \(sfTimeFormatter.string(from: result.date))")
          .font(.caption.bold())
          .foregroundColor(.secondary)
        Spacer()
        Text("分析 \(result.entriesCount) 条")
          .font(.caption2)
          .foregroundColor(Color(uiColor: .tertiaryLabel))
      }

      HStack(spacing: 12) {
        if result.boostCount > 0 {
          Label("提升 \(result.boostCount)", systemImage: "arrow.up.circle.fill")
            .font(.caption2)
            .foregroundColor(.cyan)
        }
        if result.demoteCount > 0 {
          Label("降频 \(result.demoteCount)", systemImage: "arrow.down.circle.fill")
            .font(.caption2)
            .foregroundColor(.orange)
        }
        if result.newPhraseCount > 0 {
          Label("新增 \(result.newPhraseCount)", systemImage: "plus.circle.fill")
            .font(.caption2)
            .foregroundColor(.green)
        }
        if result.tokensUsed > 0 {
          Spacer()
          Text("\(result.tokensUsed) tokens")
            .font(.caption2)
            .foregroundColor(Color(uiColor: .tertiaryLabel))
        }
      }
    }
    .padding(.vertical, 4)
  }
}

// MARK: - Settings View

public struct SmartFreqSettingsView: View {
  @ObservedObject var viewModel: SmartFreqViewModel
  @Environment(\.dismiss) private var dismiss

  // DEBUG: 5m 选项仅用于测试，上线前移除
  private let intervalOptions: [(String, Int)] = [
    ("5m", 5), ("12h", 12 * 60), ("24h", 24 * 60), ("48h", 48 * 60), ("72h", 72 * 60)
  ]

  public var body: some View {
    NavigationView {
      Form {
        Section {
          Toggle("启用智能调频", isOn: $viewModel.isEnabled)
            .tint(.cyan)
        } footer: {
          Text("开启后，输入法每隔设定时间自动分析输入记录，优化候选词排序并添加新词。全程后台静默执行。")
        }

        Section("分析频次") {
          Picker("间隔", selection: $viewModel.intervalMinutes) {
            ForEach(intervalOptions, id: \.1) { label, hours in
              Text(label).tag(hours)
            }
          }
          .pickerStyle(.segmented)
          .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        }

        Section {
          HStack {
            Text("月度 Token 上限")
            Spacer()
            TextField("0 = 不限", value: $viewModel.monthlyTokenBudget, format: .number)
              .multilineTextAlignment(.trailing)
              .keyboardType(.numberPad)
              .foregroundColor(.secondary)
              .frame(width: 100)
          }
        } header: {
          Text("Token 预算")
        } footer: {
          Text("当月消耗达到上限后自动暂停分析。设为 0 表示不限制。当前已用：\(viewModel.formatTokens(viewModel.currentMonthTokens))")
        }

        Section {
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
          Text("与每日洞察共用同一 AI 配置。")
        }

        Section("API Key") {
          SmartFreqSecureKeyField(
            placeholder: "填入 API Key",
            key: viewModel.apiKey(for: viewModel.aiSelectedProvider)
          ) {
            viewModel.setAPIKey($0, for: viewModel.aiSelectedProvider)
          }
        }

        Section {
          Button(role: .destructive) {
            viewModel.resetAllRules()
          } label: {
            HStack {
              Spacer()
              Text("重置所有规则")
              Spacer()
            }
          }
        } footer: {
          Text("清空所有已生成的调频规则和新词，恢复到初始状态。")
        }
      }
      .navigationTitle("智能调频设置")
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

// MARK: - Secure Key Field

private struct SmartFreqSecureKeyField: View {
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
