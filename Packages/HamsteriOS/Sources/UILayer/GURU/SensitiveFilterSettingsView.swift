import HamsterKit
import SwiftUI

/// 敏感词过滤设置页面
struct SensitiveFilterSettingsView: View {
  // 从 SensitiveFilter.shared 直接读取，用 @State 做本地镜像以驱动刷新
  @State private var filterPhone: Bool = SensitiveFilter.shared.filterPhone
  @State private var filterBankCard: Bool = SensitiveFilter.shared.filterBankCard
  @State private var filterEmail: Bool = SensitiveFilter.shared.filterEmail
  @State private var customWords: [String] = SensitiveFilter.shared.customWords
  @State private var newWord: String = ""
  @State private var showAddAlert: Bool = false

  private let filter = SensitiveFilter.shared

  var body: some View {
    List {
      // 内置识别规则
      Section {
        Toggle(isOn: $filterPhone) {
          VStack(alignment: .leading, spacing: 2) {
            Text("手机号")
            Text("中国大陆 1[3-9] 开头 11 位号码")
              .font(.caption).foregroundColor(.secondary)
          }
        }
        .onChange(of: filterPhone) { filter.filterPhone = $0 }

        Toggle(isOn: $filterBankCard) {
          VStack(alignment: .leading, spacing: 2) {
            Text("银行卡号")
            Text("13–19 位连续数字")
              .font(.caption).foregroundColor(.secondary)
          }
        }
        .onChange(of: filterBankCard) { filter.filterBankCard = $0 }

        Toggle(isOn: $filterEmail) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Email 地址")
            Text("标准 user@domain.tld 格式")
              .font(.caption).foregroundColor(.secondary)
          }
        }
        .onChange(of: filterEmail) { filter.filterEmail = $0 }
      } header: {
        Text("自动识别（替换为 ***）")
      } footer: {
        Text("开启后，GURU 输入记录和剪贴板内容在保存时会自动屏蔽匹配项。")
          .font(.caption)
      }

      // 自定义敏感词列表
      Section {
        ForEach(customWords, id: \.self) { word in
          HStack {
            Image(systemName: "xmark.circle.fill")
              .foregroundColor(.secondary)
              .onTapGesture { removeWord(word) }
            Text(word)
          }
        }
        .onDelete { indices in
          filter.removeWords(at: indices)
          customWords = filter.customWords
        }

        // 添加输入行
        HStack {
          TextField("输入敏感词，回车添加", text: $newWord)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .submitLabel(.done)
            .onSubmit { addWord() }
          if !newWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Button { addWord() } label: {
              Image(systemName: "plus.circle.fill").foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
          }
        }
      } header: {
        HStack {
          Text("自定义敏感词")
          Spacer()
          if !customWords.isEmpty {
            EditButton().font(.caption)
          }
        }
      } footer: {
        Text("匹配时不区分大小写，命中则替换为 ***。")
          .font(.caption)
      }

      // 预览区
      if isAnyActive {
        Section {
          previewRow(label: "手机号示例", sample: "联系我：13812345678 或微信")
          previewRow(label: "银行卡示例", sample: "卡号：6222021234567890123")
          previewRow(label: "Email 示例", sample: "邮件：user@example.com")
          if let first = customWords.first {
            previewRow(label: "自定义词示例", sample: "包含\(first)的一段文字")
          }
        } header: {
          Text("过滤效果预览")
        }
      }
    }
    .navigationTitle("敏感词过滤")
    .navigationBarTitleDisplayMode(.inline)
  }

  // MARK: - Helpers

  private var isAnyActive: Bool {
    filterPhone || filterBankCard || filterEmail || !customWords.isEmpty
  }

  private func addWord() {
    let w = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !w.isEmpty else { return }
    filter.addWord(w)
    customWords = filter.customWords
    newWord = ""
  }

  private func removeWord(_ word: String) {
    filter.removeWord(word)
    customWords = filter.customWords
  }

  private func previewRow(label: String, sample: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label).font(.caption2).foregroundColor(.secondary)
      HStack(spacing: 8) {
        Text(sample)
          .font(.caption)
          .foregroundColor(.secondary)
          .lineLimit(1)
        Image(systemName: "arrow.right").font(.caption2).foregroundColor(.secondary)
        Text(filter.filter(sample))
          .font(.caption)
          .foregroundColor(.primary)
          .lineLimit(1)
      }
    }
    .padding(.vertical, 2)
  }
}
