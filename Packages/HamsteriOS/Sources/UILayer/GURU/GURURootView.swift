import HamsterKit
import SwiftUI

struct GURURootView: View {
  @ObservedObject var viewModel: GURUViewModel
  @State private var showDeleteAlert = false
  @State private var dateToDelete: Date?
  @State private var showDeleteSelectedAlert = false
  @State private var showingPreview = false
  @State private var showingAIChat = false
  @State private var showingAISettings = false
  @State private var showingPromptEditor = false
  @State private var editingPrompt: AIPrompt?
  @State private var selectedPrompt: AIPrompt?
  @State private var includeGURU = true
  @State private var clientIDInput: String = GoogleDriveService.shared.clientID
  @State private var includeClipboard = true
  @State private var showClearClipboardAlert = false

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
          Text("暂无采集数据\n使用咕噜输入法打字后将在此显示")
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
            if viewModel.selectedDates.count == viewModel.availableDates.count { viewModel.deselectAll() }
            else { viewModel.selectAll() }
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
          Text("iCloud 操作")
        }
      }

      // Google Drive 同步
      googleDriveSection

      // 敏感词过滤
      sensitiveFilterSection

      // AI 分析
      aiSection

      // 剪贴板监听
      clipboardSection

      // 最近剪贴板记录
      if viewModel.clipboardEnabled && !viewModel.clipboardPreviewEntries.isEmpty {
        clipboardPreviewSection
      }

      // 状态消息
      if !viewModel.statusMessage.isEmpty {
        Section {
          Text(viewModel.statusMessage)
            .font(.subheadline)
            .foregroundColor(viewModel.statusMessage.contains("✓") ? .green : .secondary)
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
    .sheet(isPresented: $showingPreview) { previewSheet }
    .sheet(isPresented: $showingAIChat) { aiChatSheet }
    .sheet(isPresented: $showingAISettings) { aiSettingsSheet }
    .sheet(isPresented: $showingPromptEditor) {
      if let prompt = editingPrompt {
        promptEditorSheet(prompt: prompt)
      }
    }
    .alert("删除确认", isPresented: $showDeleteAlert) {
      Button("删除", role: .destructive) { if let d = dateToDelete { viewModel.deleteDate(d) } }
      Button("取消", role: .cancel) {}
    } message: {
      if let d = dateToDelete { Text("删除 \(viewModel.formattedDate(d)) 的本地记录？") }
    }
    .alert("删除选中记录", isPresented: $showDeleteSelectedAlert) {
      Button("删除", role: .destructive) { viewModel.deleteSelected() }
      Button("取消", role: .cancel) {}
    } message: {
      Text("删除已选 \(viewModel.selectedDates.count) 天的本地记录？iCloud 中的数据不受影响。")
    }
    .alert("清空剪贴板", isPresented: $showClearClipboardAlert) {
      Button("清空", role: .destructive) { viewModel.clearAllClipboardEntries() }
      Button("取消", role: .cancel) {}
    } message: {
      Text("删除所有剪贴板记录？此操作不可恢复。")
    }
    .onAppear { viewModel.reload() }
  }

  // MARK: - Stats

  var statsRow: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Label("\(viewModel.totalEntryCount) 条记录", systemImage: "doc.text")
        Spacer()
        Label(viewModel.storageSize, systemImage: "internaldrive").foregroundColor(.secondary)
      }
      HStack {
        Label("\(viewModel.availableDates.count) 天", systemImage: "calendar")
        Spacer()
        Label("\(viewModel.selectedDates.count) 天已选", systemImage: "checkmark.circle").foregroundColor(.accentColor)
      }
    }
    .font(.subheadline)
  }

  // MARK: - Date Row

  func dateRow(_ date: Date) -> some View {
    HStack {
      Image(systemName: viewModel.selectedDates.contains(date) ? "checkmark.circle.fill" : "circle")
        .foregroundColor(viewModel.selectedDates.contains(date) ? .accentColor : .secondary)
        .onTapGesture { viewModel.toggleDateSelection(date) }
      VStack(alignment: .leading, spacing: 2) {
        Text(viewModel.formattedDate(date)).font(.body)
        Text("\(viewModel.entryCount(for: date)) 条").font(.caption).foregroundColor(.secondary)
      }
      Spacer()
      Button { viewModel.loadPreview(for: date); showingPreview = true } label: {
        Image(systemName: "eye").foregroundColor(.secondary)
      }
      .buttonStyle(.plain)
    }
    .swipeActions(edge: .trailing) {
      Button(role: .destructive) { dateToDelete = date; showDeleteAlert = true } label: {
        Label("删除", systemImage: "trash")
      }
    }
  }

  // MARK: - iCloud Buttons

  var uploadButton: some View {
    Button { viewModel.uploadSelected { _ in } } label: {
      HStack {
        if viewModel.isUploading {
          ProgressView(value: viewModel.uploadProgress).frame(width: 80)
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
      let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
      UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }
        .first { $0.isKeyWindow }?.rootViewController?.present(vc, animated: true)
    } label: {
      HStack {
        Image(systemName: "square.and.arrow.up")
        Text("导出为 Markdown（供 AI 分析）")
      }
    }
    .disabled(viewModel.selectedDates.isEmpty)
  }

  var deleteSelectedButton: some View {
    Button(role: .destructive) { showDeleteSelectedAlert = true } label: {
      HStack {
        Image(systemName: "trash")
        Text("删除本地记录（\(viewModel.selectedDates.count) 天）")
      }
    }
    .disabled(viewModel.selectedDates.isEmpty)
  }

  // MARK: - Google Drive Section

  var googleDriveSection: some View {
    Section {
      if let email = viewModel.googleDriveEmail {
        HStack {
          Image(systemName: "person.circle.fill").foregroundColor(.green)
          VStack(alignment: .leading, spacing: 2) {
            Text("已登录").font(.caption2).foregroundColor(.secondary)
            Text(email).font(.subheadline)
          }
          Spacer()
          Button("退出") { viewModel.googleSignOut() }
            .font(.subheadline).foregroundColor(.red)
        }
        Button {
          viewModel.syncToGoogleDrive()
        } label: {
          HStack {
            if viewModel.isGoogleSyncing {
              ProgressView(value: viewModel.googleSyncProgress).frame(width: 80)
              Text("同步中 \(Int(viewModel.googleSyncProgress * 100))%")
            } else {
              Image(systemName: "arrow.triangle.2.circlepath.icloud")
              Text("同步到 Google Drive（\(viewModel.selectedDates.count) 天）")
            }
          }
        }
        .disabled(viewModel.isGoogleSyncing || viewModel.selectedDates.isEmpty)
      } else {
        // Client ID 配置行
        HStack {
          TextField("OAuth Client ID", text: $clientIDInput)
            .autocorrectionDisabled()
            .autocapitalization(.none)
            .font(.system(.footnote, design: .monospaced))
          if !clientIDInput.isEmpty && clientIDInput != viewModel.googleClientID {
            Button("保存") {
              viewModel.saveGoogleClientID(clientIDInput)
            }
            .font(.subheadline)
          }
        }
        // 登录按钮（配置后才启用）
        Button {
          guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else { return }
          viewModel.googleSignIn(anchor: window)
        } label: {
          Label("登录 Google 账号", systemImage: "person.badge.plus")
        }
        .disabled(viewModel.googleClientID.isEmpty)
      }
      if !viewModel.googleStatusMessage.isEmpty {
        Text(viewModel.googleStatusMessage)
          .font(.caption)
          .foregroundColor(viewModel.googleStatusMessage.contains("✓") ? .green : .secondary)
      }
    } header: {
      Text("Google Drive 同步")
    } footer: {
      VStack(alignment: .leading, spacing: 4) {
        Text("同步 GURU 输入记录至 Google Drive / Hamster / GURU / 目录。")
        if viewModel.googleDriveEmail == nil {
          Text("首次使用：前往 Google Cloud Console → APIs & Services → Credentials，创建 **Web 应用** 类型的 OAuth 2.0 Client ID，在「已获授权的重定向 URI」中添加：\nhamster://oauth2redirect")
        }
      }
      .font(.caption)
    }
  }

  // MARK: - Sensitive Filter Section

  var sensitiveFilterSection: some View {
    Section {
      // 输入场景过滤
      NavigationLink {
        InputTypePrivacyView()
      } label: {
        HStack {
          Label("输入类型过滤", systemImage: "hand.raised.fill")
          Spacer()
          let blockedCount = InputCategory.allCases
            .filter { InputTypeFilter.shared.isBlocked($0) }.count
          Text("\(blockedCount)/\(InputCategory.allCases.count) 已屏蔽")
            .font(.caption).foregroundColor(.secondary)
        }
      }
      // 敏感词 / 正则过滤
      NavigationLink {
        SensitiveFilterSettingsView()
      } label: {
        HStack {
          Label("敏感词过滤", systemImage: "shield.lefthalf.filled")
          Spacer()
          let activeCount = (SensitiveFilter.shared.filterPhone ? 1 : 0)
            + (SensitiveFilter.shared.filterBankCard ? 1 : 0)
            + (SensitiveFilter.shared.filterEmail ? 1 : 0)
            + SensitiveFilter.shared.customWords.count
          if activeCount > 0 {
            Text("\(activeCount) 条规则")
              .font(.caption).foregroundColor(.secondary)
          }
        }
      }
    } header: {
      Text("隐私保护")
    } footer: {
      Text("输入类型过滤：按场景屏蔽采集（密码/支付/验证码等）。敏感词过滤：内容写入时将手机号、银行卡等替换为 ***。")
        .font(.caption)
    }
  }

  // MARK: - AI Section

  var aiSection: some View {
    Section {
      Button { showingAISettings = true } label: {
        HStack {
          Label(viewModel.aiSelectedProvider.rawValue, systemImage: "cpu")
          Spacer()
          Text(viewModel.aiSelectedModel)
            .font(.caption).foregroundColor(.secondary).lineLimit(1)
          Image(systemName: "chevron.right").font(.caption2).foregroundColor(.secondary)
        }
      }
      .foregroundColor(.primary)

      // 选择 Prompt
      ForEach(viewModel.savedPrompts.prefix(3)) { prompt in
        Button {
          selectedPrompt = prompt
          viewModel.clearAIConversation()
          showingAIChat = true
        } label: {
          HStack {
            Image(systemName: "text.bubble").foregroundColor(.accentColor)
            Text(prompt.name)
            Spacer()
            Image(systemName: "chevron.right").font(.caption2).foregroundColor(.secondary)
          }
        }
        .foregroundColor(.primary)
      }

      Button { showingPromptEditor = true; editingPrompt = AIPrompt(name: "", content: "") } label: {
        Label("新建 Prompt", systemImage: "plus.circle")
      }
    } header: {
      HStack {
        Text("AI 分析")
        Spacer()
        Button("管理 Prompt") { showingAISettings = true }
          .font(.caption)
      }
    } footer: {
      Text("选择 Prompt 后可将采集记录一键发送给 AI 分析。支持 OpenAI / OpenRouter / Claude。")
        .font(.caption)
    }
  }

  // MARK: - Clipboard Section

  var clipboardSection: some View {
    Section {
      Toggle(isOn: Binding(get: { viewModel.clipboardEnabled }, set: { viewModel.toggleClipboardMonitor($0) })) {
        Label("剪贴板监听", systemImage: "clipboard")
      }
      if viewModel.clipboardEnabled {
        HStack {
          Label("已记录", systemImage: "doc.on.clipboard")
          Spacer()
          Text("\(viewModel.clipboardEntryCount) 条").foregroundColor(.secondary)
        }
        .font(.subheadline)

        if viewModel.clipboardEntryCount > 0 {
          Button(role: .destructive) { showClearClipboardAlert = true } label: {
            Label("清空剪贴板记录", systemImage: "trash")
          }
        }
      }
    } header: {
      Text("剪贴板")
    } footer: {
      Text("开启后，每次使用咕噜输入法时将自动记录剪贴板新增内容（文字、图片、Emoji），含时间戳与类型标注。")
        .font(.caption)
    }
  }

  var clipboardPreviewSection: some View {
    Section {
      ForEach(viewModel.clipboardPreviewEntries) { entry in
        VStack(alignment: .leading, spacing: 3) {
          HStack {
            Text(entry.formattedTime).font(.caption2).foregroundColor(.secondary)
            Text("·").font(.caption2).foregroundColor(.secondary)
            Text("[剪贴板/\(entry.contentType.rawValue)]").font(.caption2).foregroundColor(.accentColor)
          }
          Text(entry.preview).font(.caption).lineLimit(2)
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing) {
          Button(role: .destructive) {
            viewModel.deleteClipboardEntry(id: entry.id)
          } label: {
            Label("删除", systemImage: "trash")
          }
        }
      }
    } header: {
      Text("最近剪贴板（今日）")
    }
  }

  // MARK: - Preview Sheet

  var previewSheet: some View {
    NavigationView {
      List {
        if let date = viewModel.previewDate {
          Section("\(viewModel.formattedDate(date)) · \(viewModel.previewEntries.count) 条") {
            ForEach(viewModel.previewEntries) { entry in
              VStack(alignment: .leading, spacing: 4) {
                if let ctx = entry.context, !ctx.isEmpty {
                  Text(ctx).font(.caption).foregroundColor(.secondary).lineLimit(2)
                    .padding(6).background(Color(.systemGray6)).cornerRadius(6)
                }
                Text(entry.text).font(.body)
                HStack {
                  Text(entry.formattedTime); Text("·"); Text(entry.appContext)
                }
                .font(.caption2).foregroundColor(.secondary)
              }
              .padding(.vertical, 2)
              .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                  viewModel.deleteEntry(id: entry.id)
                } label: {
                  Label("删除", systemImage: "trash")
                }
              }
            }
          }
        }
      }
      .navigationTitle("预览")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) { Button("关闭") { showingPreview = false } }
      }
    }
  }

  // MARK: - AI Chat Sheet

  var aiChatSheet: some View {
    NavigationView {
      AIChatView(viewModel: viewModel, prompt: selectedPrompt, includeGURU: includeGURU, includeClipboard: includeClipboard)
        .navigationTitle(selectedPrompt?.name ?? "AI 分析")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) { Button("关闭") { showingAIChat = false } }
          ToolbarItem(placement: .topBarTrailing) {
            Button("清空") { viewModel.clearAIConversation() }
          }
        }
    }
  }

  // MARK: - AI Settings Sheet

  var aiSettingsSheet: some View {
    NavigationView {
      AISettingsView(viewModel: viewModel)
        .navigationTitle("AI 设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) { Button("完成") { showingAISettings = false } }
        }
    }
  }

  // MARK: - Prompt Editor Sheet

  func promptEditorSheet(prompt: AIPrompt) -> some View {
    PromptEditorView(prompt: prompt) { saved in
      viewModel.savePrompt(saved)
      showingPromptEditor = false
    } onCancel: {
      showingPromptEditor = false
    }
  }

  // MARK: - Help

  var helpText: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("• 咕噜输入法在使用过程中自动采集您的输入（RIME 上屏词汇及英文单词）")
      Text("• 数据保存在本机私有空间，不会自动上传")
      Text("• 支持上传到 iCloud Drive / 同步到 Google Drive")
      Text("• 开启剪贴板监听后记录文字、图片、Emoji 类型")
      Text("• 选择日期后可一键发给 AI（OpenAI / OpenRouter / Claude）分析")
    }
    .font(.caption).foregroundColor(.secondary)
  }
}

// MARK: - AI Chat View

private struct AIChatView: View {
  @ObservedObject var viewModel: GURUViewModel
  let prompt: AIPrompt?
  let includeGURU: Bool
  let includeClipboard: Bool

  @State private var inputText = ""
  @State private var hasSentInitialPrompt = false

  var body: some View {
    VStack(spacing: 0) {
      // 消息列表
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(Array(viewModel.aiMessages.enumerated()), id: \.offset) { _, msg in
              MessageBubble(message: msg)
            }
            if viewModel.aiIsLoading {
              HStack {
                ProgressView().scaleEffect(0.8)
                Text("AI 思考中...").font(.caption).foregroundColor(.secondary)
              }
              .padding(.horizontal)
            }
          }
          .padding()
          .id("bottom")
        }
        .onChange(of: viewModel.aiMessages.count) { _ in
          withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
        }
      }

      if !viewModel.aiStatusMessage.isEmpty {
        Text(viewModel.aiStatusMessage)
          .font(.caption).foregroundColor(.red)
          .padding(.horizontal)
      }

      Divider()

      // 包含数据选项（仅首次）
      if !hasSentInitialPrompt {
        HStack {
          Toggle("GURU记录", isOn: .constant(includeGURU)).labelsHidden()
          Text("含 GURU 记录").font(.caption2)
          Spacer()
          Toggle("剪贴板", isOn: .constant(includeClipboard)).labelsHidden()
          Text("含剪贴板").font(.caption2)
          Spacer()
          Button("发送分析") {
            if let p = prompt {
              viewModel.sendAIQuery(prompt: p, includeGURU: includeGURU, includeClipboard: includeClipboard)
            }
            hasSentInitialPrompt = true
          }
          .buttonStyle(.borderedProminent)
          .disabled(viewModel.aiIsLoading)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        Divider()
      }

      // 输入框
      HStack {
        TextEditor(text: $inputText)
          .frame(minHeight: 36, maxHeight: 100)
          .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4)))
          .overlay(
            Group {
              if inputText.isEmpty {
                Text("继续对话...").foregroundColor(.secondary).padding(8).allowsHitTesting(false)
              }
            }, alignment: .topLeading
          )
        Button {
          let text = inputText
          inputText = ""
          viewModel.sendAIMessage(content: text)
        } label: {
          Image(systemName: "paperplane.fill")
        }
        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.aiIsLoading)
      }
      .padding()
    }
  }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
  let message: AIMessage

  var isUser: Bool { message.role == "user" }

  var body: some View {
    HStack {
      if isUser { Spacer(minLength: 40) }
      Text(message.content)
        .font(.body)
        .padding(10)
        .background(isUser ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
        .cornerRadius(12)
        .textSelection(.enabled)
      if !isUser { Spacer(minLength: 40) }
    }
  }
}

// MARK: - AI Settings View

private struct AISettingsView: View {
  @ObservedObject var viewModel: GURUViewModel
  @State private var showingPromptEditor = false
  @State private var editingPrompt: AIPrompt?
  @State private var openAIKey = ""
  @State private var openRouterKey = ""
  @State private var claudeKey = ""
  @State private var customModel = ""

  var body: some View {
    List {
      // Provider 选择
      Section("AI 提供商") {
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
      }

      // 模型
      Section("模型") {
        TextField("模型名称", text: Binding(
          get: { viewModel.aiSelectedModel },
          set: { viewModel.setModel($0) }
        ))
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        Text("当前提供商默认：\(viewModel.aiSelectedProvider.defaultModel)")
          .font(.caption).foregroundColor(.secondary)
      }

      // API Keys
      Section("API Keys") {
        SecureKeyField(label: "OpenAI Key", placeholder: "sk-...", key: viewModel.apiKey(for: .openai)) {
          viewModel.setAPIKey($0, for: .openai)
        }
        SecureKeyField(label: "OpenRouter Key", placeholder: "sk-or-...", key: viewModel.apiKey(for: .openrouter)) {
          viewModel.setAPIKey($0, for: .openrouter)
        }
        SecureKeyField(label: "Claude Key", placeholder: "sk-ant-...", key: viewModel.apiKey(for: .claude)) {
          viewModel.setAPIKey($0, for: .claude)
        }
      }

      // Prompts
      Section {
        ForEach(viewModel.savedPrompts) { prompt in
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(prompt.name).font(.body)
              Text(prompt.content.prefix(50)).font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
            Button { editingPrompt = prompt; showingPromptEditor = true } label: {
              Image(systemName: "pencil").foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
          }
        }
        .onDelete { indices in
          indices.forEach { viewModel.deletePrompt(id: viewModel.savedPrompts[$0].id) }
        }
        Button { editingPrompt = AIPrompt(name: "", content: ""); showingPromptEditor = true } label: {
          Label("新建 Prompt", systemImage: "plus")
        }
      } header: {
        Text("Prompt 管理")
      }
    }
    .onAppear {
      openAIKey = viewModel.apiKey(for: .openai)
      openRouterKey = viewModel.apiKey(for: .openrouter)
      claudeKey = viewModel.apiKey(for: .claude)
      customModel = viewModel.aiSelectedModel
      viewModel.reloadSavedPrompts()
    }
    .sheet(isPresented: $showingPromptEditor) {
      if let prompt = editingPrompt {
        NavigationView {
          PromptEditorView(prompt: prompt) { saved in
            viewModel.savePrompt(saved)
            showingPromptEditor = false
          } onCancel: {
            showingPromptEditor = false
          }
          .navigationTitle(prompt.name.isEmpty ? "新建 Prompt" : "编辑 Prompt")
          .navigationBarTitleDisplayMode(.inline)
        }
      }
    }
  }
}

// MARK: - Secure Key Field

private struct SecureKeyField: View {
  let label: String
  let placeholder: String
  let key: String
  let onSave: (String) -> Void

  @State private var text: String = ""
  @State private var isRevealed = false

  var body: some View {
    HStack {
      Text(label).frame(width: 110, alignment: .leading)
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

// MARK: - Prompt Editor View

struct PromptEditorView: View {
  @State private var prompt: AIPrompt
  let onSave: (AIPrompt) -> Void
  let onCancel: () -> Void

  init(prompt: AIPrompt, onSave: @escaping (AIPrompt) -> Void, onCancel: @escaping () -> Void) {
    _prompt = State(initialValue: prompt)
    self.onSave = onSave
    self.onCancel = onCancel
  }

  var body: some View {
    NavigationView {
      Form {
        Section("名称") {
          TextField("Prompt 名称", text: $prompt.name)
        }
        Section("内容") {
          TextEditor(text: $prompt.content)
            .frame(minHeight: 200)
            .font(.body)
        }
        Section {
          Text("Prompt 内容将作为消息开头发送给 AI。点击「发送分析」时，系统会自动在后面追加您选中的 GURU / 剪贴板数据。")
            .font(.caption).foregroundColor(.secondary)
        }
      }
      .navigationTitle(prompt.name.isEmpty ? "新建 Prompt" : "编辑 Prompt")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) { Button("取消") { onCancel() } }
        ToolbarItem(placement: .topBarTrailing) {
          Button("保存") { onSave(prompt) }
            .disabled(prompt.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }
}
