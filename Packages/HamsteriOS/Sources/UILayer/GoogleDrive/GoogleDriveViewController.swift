import AuthenticationServices
import HamsterKit
import HamsterUIKit
import SwiftUI
import UIKit

public class GoogleDriveViewController: UIViewController {
  private let viewModel = GoogleDriveViewModel()

  public override func viewDidLoad() {
    super.viewDidLoad()
    title = "Google Drive 同步"
    let hosting = UIHostingController(rootView: GoogleDriveRootView(viewModel: viewModel))
    addChild(hosting)
    view.addSubview(hosting.view)
    hosting.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
      hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    hosting.didMove(toParent: self)
  }
}

// MARK: - ViewModel

@MainActor
class GoogleDriveViewModel: ObservableObject {
  @Published var email: String? = GoogleDriveService.shared.signedInEmail
  @Published var clientID: String = GoogleDriveService.shared.clientID
  @Published var isSyncing: Bool = false
  @Published var syncProgress: Double = 0
  @Published var statusMessage: String = ""

  private let googleService = GoogleDriveService.shared
  private let guruService = GURUDataService.shared

  func saveClientID(_ id: String) {
    googleService.clientID = id
    clientID = id
  }

  func signIn(anchor: ASPresentationAnchor) {
    guard googleService.isConfigured else {
      statusMessage = "请先填入 Google OAuth Client ID"
      return
    }
    statusMessage = "正在打开 Google 登录..."
    googleService.signIn(anchor: anchor) { [weak self] result in
      DispatchQueue.main.async {
        switch result {
        case .success:
          self?.email = GoogleDriveService.shared.signedInEmail
          self?.statusMessage = "已登录 Google Drive ✓"
        case .failure(let error):
          self?.statusMessage = "登录失败：\(error.localizedDescription)"
        }
      }
    }
  }

  func signOut() {
    googleService.signOut()
    email = nil
    statusMessage = ""
  }

  func syncAll() {
    guard let guruBase = guruService.guruBaseURL else {
      statusMessage = "无法获取本地数据路径"
      return
    }
    let dates = guruService.availableDates()
    guard !dates.isEmpty else {
      statusMessage = "暂无记录可同步"
      return
    }
    isSyncing = true
    syncProgress = 0
    statusMessage = "正在同步到 Google Drive..."

    googleService.syncGURU(
      dates: dates,
      guruBaseURL: guruBase,
      progress: { [weak self] p in DispatchQueue.main.async { self?.syncProgress = p } },
      completion: { [weak self] result in
        DispatchQueue.main.async {
          self?.isSyncing = false
          switch result {
          case .success(let count): self?.statusMessage = "已同步 \(count) 个文件到 Google Drive ✓"
          case .failure(let error): self?.statusMessage = "同步失败：\(error.localizedDescription)"
          }
        }
      }
    )
  }
}

// MARK: - SwiftUI View

struct GoogleDriveRootView: View {
  @ObservedObject var viewModel: GoogleDriveViewModel
  @State private var clientIDInput: String = GoogleDriveService.shared.clientID

  var body: some View {
    Form {
      if let email = viewModel.email {
        // 已登录态
        Section {
          HStack {
            Image(systemName: "person.circle.fill").foregroundColor(.green)
            VStack(alignment: .leading, spacing: 2) {
              Text("已登录").font(.caption2).foregroundColor(.secondary)
              Text(email).font(.subheadline)
            }
            Spacer()
            Button("退出") { viewModel.signOut() }
              .font(.subheadline).foregroundColor(.red)
          }

          Button {
            viewModel.syncAll()
          } label: {
            HStack {
              if viewModel.isSyncing {
                ProgressView(value: viewModel.syncProgress).frame(width: 80)
                Text("同步中 \(Int(viewModel.syncProgress * 100))%")
              } else {
                Image(systemName: "arrow.triangle.2.circlepath.icloud")
                Text("同步所有记录到 Google Drive")
              }
            }
          }
          .disabled(viewModel.isSyncing)

          if !viewModel.statusMessage.isEmpty {
            Text(viewModel.statusMessage)
              .font(.caption)
              .foregroundColor(viewModel.statusMessage.contains("✓") ? .green : .secondary)
          }
        } header: {
          Text("同步")
        } footer: {
          Text("同步 GURU 采集记录至 Google Drive / Hamster / GURU / 目录。")
            .font(.caption)
        }
      } else {
        // 未登录态
        Section {
          HStack {
            TextField("OAuth Client ID", text: $clientIDInput)
              .autocorrectionDisabled()
              .autocapitalization(.none)
              .font(.system(.footnote, design: .monospaced))
            if !clientIDInput.isEmpty && clientIDInput != viewModel.clientID {
              Button("保存") {
                viewModel.saveClientID(clientIDInput)
              }
              .font(.subheadline)
            }
          }

          Button {
            guard let window = UIApplication.shared.connectedScenes
              .compactMap({ $0 as? UIWindowScene }).flatMap({ $0.windows })
              .first(where: { $0.isKeyWindow }) else { return }
            viewModel.signIn(anchor: window)
          } label: {
            Label("登录 Google 账号", systemImage: "person.badge.plus")
          }
          .disabled(viewModel.clientID.isEmpty)

          if !viewModel.statusMessage.isEmpty {
            Text(viewModel.statusMessage)
              .font(.caption).foregroundColor(.secondary)
          }
        } header: {
          Text("账号")
        } footer: {
          VStack(alignment: .leading, spacing: 4) {
            Text("同步 GURU 采集记录至 Google Drive / Hamster / GURU / 目录。")
            Text("首次使用：前往 Google Cloud Console → APIs & Services → Credentials，创建 **Web 应用** 类型的 OAuth 2.0 Client ID，在「已获授权的重定向 URI」中添加：\nhamster://oauth2redirect")
          }
          .font(.caption)
        }
      }
    }
  }
}
