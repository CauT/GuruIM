import HamsterKit
import SwiftUI

/// 输入类型隐私过滤设置页面
struct InputTypePrivacyView: View {
  // 用 @State 本地镜像驱动 UI 刷新，onChange 时写回 InputTypeFilter
  @State private var blockedStates: [InputCategory: Bool] = Self.loadStates()

  private let filter = InputTypeFilter.shared

  var body: some View {
    List {
      // 说明
      Section {
        Text("iOS 键盘扩展可通过 isSecureTextEntry、textContentType、keyboardType 等信号识别当前输入场景。在此为每类场景单独设置是否采集输入记录。")
          .font(.caption)
          .foregroundColor(.secondary)
      }

      // 高敏感（始终不采集）
      Section {
        alwaysBlockedRow(.password)
      } header: {
        Label("始终不采集", systemImage: "lock.shield.fill")
      } footer: {
        Text("密码框通过 isSecureTextEntry 可靠识别，无论任何设置均不会采集。")
          .font(.caption)
      }

      // 高敏感（默认关闭，用户可手动开启）
      Section {
        toggleRow(.payment)
        toggleRow(.otp)
        toggleRow(.login)
      } header: {
        Label("高敏感 · 默认不采集", systemImage: "exclamationmark.shield")
      } footer: {
        Text("建议保持关闭。若有需要可手动开启采集。")
          .font(.caption)
      }

      // 中等敏感（默认采集）
      Section {
        toggleRow(.phone)
        toggleRow(.email)
        toggleRow(.name)
        toggleRow(.address)
        toggleRow(.organization)
      } header: {
        Label("中等敏感 · 默认采集", systemImage: "person.badge.shield.checkmark")
      } footer: {
        Text("包含个人联系和身份信息，可按需关闭采集。")
          .font(.caption)
      }

      // 低敏感（默认采集）
      Section {
        toggleRow(.url)
        toggleRow(.dateTime)
        toggleRow(.logistics)
        toggleRow(.general)
      } header: {
        Label("低敏感 · 默认采集", systemImage: "checkmark.shield")
      } footer: {
        Text("普通使用场景，关闭后该类输入不会进入 GURU 记录。")
          .font(.caption)
      }

      // 重置
      Section {
        Button(role: .destructive) {
          filter.resetToDefaults()
          blockedStates = Self.loadStates()
        } label: {
          Label("恢复默认设置", systemImage: "arrow.counterclockwise")
        }
      }
    }
    .navigationTitle("输入类型过滤")
    .navigationBarTitleDisplayMode(.inline)
  }

  // MARK: - Rows

  /// 始终屏蔽行（不可切换）
  private func alwaysBlockedRow(_ category: InputCategory) -> some View {
    HStack(spacing: 12) {
      Image(systemName: category.systemImage)
        .foregroundColor(.red)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 2) {
        Text(category.displayName).font(.body)
        Text(category.detail).font(.caption).foregroundColor(.secondary).lineLimit(2)
      }
      Spacer()
      Text("始终屏蔽")
        .font(.caption)
        .foregroundColor(.red)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Color.red.opacity(0.1))
        .clipShape(Capsule())
    }
    .padding(.vertical, 2)
  }

  /// 可切换行：blocked = true 表示「屏蔽/不采集」
  private func toggleRow(_ category: InputCategory) -> some View {
    let isBlocked = Binding<Bool>(
      get: { blockedStates[category] ?? category.isBlockedByDefault },
      set: { newVal in
        blockedStates[category] = newVal
        filter.setBlocked(newVal, for: category)
      }
    )
    return HStack(spacing: 12) {
      Image(systemName: category.systemImage)
        .foregroundColor(isBlocked.wrappedValue ? .orange : .green)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 2) {
        Text(category.displayName).font(.body)
        Text(category.detail).font(.caption).foregroundColor(.secondary).lineLimit(2)
      }
      Spacer()
      // Toggle 语义：ON = 采集，OFF = 不采集（屏蔽）
      Toggle("", isOn: Binding(
        get: { !isBlocked.wrappedValue },
        set: { isBlocked.wrappedValue = !$0 }
      ))
      .labelsHidden()
    }
    .padding(.vertical, 2)
  }

  // MARK: - Helpers

  private static func loadStates() -> [InputCategory: Bool] {
    Dictionary(uniqueKeysWithValues: InputCategory.allCases.map { ($0, InputTypeFilter.shared.isBlocked($0)) })
  }
}
