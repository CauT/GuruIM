import AuthenticationServices
import Foundation

/// Google Drive 同步服务 - 通过 REST API 上传 GURU 和剪贴板数据
/// 不依赖任何第三方 SDK，使用 ASWebAuthenticationSession + URLSession
public class GoogleDriveService: NSObject {
  public static let shared = GoogleDriveService()

  private let tokenEndpoint = "https://oauth2.googleapis.com/token"
  private let driveScope = "https://www.googleapis.com/auth/drive.file"
  private let profileScope = "https://www.googleapis.com/auth/userinfo.email"

  // MARK: - Token Storage（App Group UserDefaults，键盘扩展和主 App 共享）

  private let defaults = UserDefaults(suiteName: HamsterConstants.appGroupName)

  // MARK: - Client ID（用户通过 UI 配置，存 UserDefaults）

  private let clientIDKey = "gdrive_client_id"
  private let fixedRedirectURI = "hamster://oauth2redirect"
  private let callbackScheme = "hamster"

  public var clientID: String {
    get { defaults?.string(forKey: clientIDKey) ?? "" }
    set { defaults?.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: clientIDKey) }
  }

  public var isConfigured: Bool { !clientID.isEmpty }

  public var isSignedIn: Bool { refreshToken != nil }

  public var signedInEmail: String? {
    get { defaults?.string(forKey: "gdrive_email") }
    set { defaults?.set(newValue, forKey: "gdrive_email") }
  }

  private var accessToken: String? {
    get { defaults?.string(forKey: "gdrive_access_token") }
    set { defaults?.set(newValue, forKey: "gdrive_access_token") }
  }

  private var refreshToken: String? {
    get { defaults?.string(forKey: "gdrive_refresh_token") }
    set { defaults?.set(newValue, forKey: "gdrive_refresh_token") }
  }

  private var tokenExpiry: Date? {
    get { defaults?.object(forKey: "gdrive_token_expiry") as? Date }
    set { defaults?.set(newValue, forKey: "gdrive_token_expiry") }
  }

  // MARK: - OAuth Sign In

  private var authSession: ASWebAuthenticationSession?
  private var anchorProvider: AnchorProvider?

  /// 发起 Google OAuth 登录（需提供 UIWindow 作为呈现锚点）
  public func signIn(anchor: ASPresentationAnchor, completion: @escaping (Result<Void, Error>) -> Void) {
    guard isConfigured else {
      completion(.failure(GDriveError.notConfigured))
      return
    }
    let state = UUID().uuidString
    var comps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    comps.queryItems = [
      .init(name: "client_id", value: clientID),
      .init(name: "redirect_uri", value: fixedRedirectURI),
      .init(name: "response_type", value: "code"),
      .init(name: "scope", value: "\(driveScope) \(profileScope)"),
      .init(name: "access_type", value: "offline"),
      .init(name: "prompt", value: "consent"),
      .init(name: "state", value: state),
    ]
    guard let url = comps.url else {
      completion(.failure(GDriveError.authFailed))
      return
    }
    let provider = AnchorProvider(anchor: anchor)
    anchorProvider = provider
    let session = ASWebAuthenticationSession(
      url: url,
      callbackURLScheme: callbackScheme
    ) { [weak self] callbackURL, error in
      if let error = error {
        if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
          completion(.failure(GDriveError.cancelled))
        } else {
          completion(.failure(error))
        }
        return
      }
      guard let callbackURL,
            let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
              .queryItems?.first(where: { $0.name == "code" })?.value
      else {
        completion(.failure(GDriveError.authFailed))
        return
      }
      self?.exchangeCodeForTokens(code: code, completion: completion)
    }
    session.presentationContextProvider = provider
    session.prefersEphemeralWebBrowserSession = false
    authSession = session
    session.start()
  }

  public func signOut() {
    ["gdrive_access_token", "gdrive_refresh_token", "gdrive_token_expiry", "gdrive_email"]
      .forEach { defaults?.removeObject(forKey: $0) }
  }

  // MARK: - Token Exchange

  private func exchangeCodeForTokens(code: String, completion: @escaping (Result<Void, Error>) -> Void) {
    var request = URLRequest(url: URL(string: tokenEndpoint)!)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    let params: [String: String] = [
      "code": code,
      "client_id": clientID,
      "redirect_uri": fixedRedirectURI,
      "grant_type": "authorization_code",
    ]
    request.httpBody = params
      .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
      .joined(separator: "&")
      .data(using: .utf8)

    URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
      if let error = error {
        DispatchQueue.main.async { completion(.failure(error)) }
        return
      }
      guard let data,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let accessToken = json["access_token"] as? String,
            let refreshToken = json["refresh_token"] as? String
      else {
        DispatchQueue.main.async { completion(.failure(GDriveError.tokenExchangeFailed)) }
        return
      }
      self?.accessToken = accessToken
      self?.refreshToken = refreshToken
      if let expiresIn = json["expires_in"] as? TimeInterval {
        self?.tokenExpiry = Date().addingTimeInterval(expiresIn)
      }
      self?.fetchUserEmail { DispatchQueue.main.async { completion(.success(())) } }
    }.resume()
  }

  private func refreshAccessToken(completion: @escaping (Result<String, Error>) -> Void) {
    guard let refresh = refreshToken else {
      completion(.failure(GDriveError.notSignedIn))
      return
    }
    // 有效期内直接复用
    if let expiry = tokenExpiry, expiry > Date().addingTimeInterval(60), let token = accessToken {
      completion(.success(token))
      return
    }
    var request = URLRequest(url: URL(string: tokenEndpoint)!)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    let params: [String: String] = [
      "refresh_token": refresh,
      "client_id": clientID,
      "grant_type": "refresh_token",
    ]
    request.httpBody = params
      .map { "\($0.key)=\($0.value)" }
      .joined(separator: "&")
      .data(using: .utf8)

    URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
      if let error = error { completion(.failure(error)); return }
      guard let data,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let token = json["access_token"] as? String
      else {
        completion(.failure(GDriveError.tokenRefreshFailed))
        return
      }
      self?.accessToken = token
      if let expiresIn = json["expires_in"] as? TimeInterval {
        self?.tokenExpiry = Date().addingTimeInterval(expiresIn)
      }
      completion(.success(token))
    }.resume()
  }

  private func fetchUserEmail(completion: @escaping () -> Void) {
    guard let token = accessToken else { completion(); return }
    var req = URLRequest(url: URL(string: "https://www.googleapis.com/userinfo/v2/me")!)
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
      if let data,
         let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
         let email = json["email"] as? String {
        self?.signedInEmail = email
      }
      completion()
    }.resume()
  }

  // MARK: - Drive Folder API

  private func findOrCreateFolder(
    name: String, parentId: String? = nil, token: String,
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    var q = "name='\(name)' and mimeType='application/vnd.google-apps.folder' and trashed=false"
    if let parent = parentId { q += " and '\(parent)' in parents" }
    var comps = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!
    comps.queryItems = [.init(name: "q", value: q), .init(name: "fields", value: "files(id)")]
    var req = URLRequest(url: comps.url!)
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    URLSession.shared.dataTask(with: req) { [weak self] data, _, error in
      if let error = error { completion(.failure(error)); return }
      guard let data,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let files = json["files"] as? [[String: Any]]
      else { completion(.failure(GDriveError.apiFailed("list folders"))); return }
      if let id = files.first?["id"] as? String {
        completion(.success(id))
      } else {
        self?.createFolder(name: name, parentId: parentId, token: token, completion: completion)
      }
    }.resume()
  }

  private func createFolder(
    name: String, parentId: String?, token: String,
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    var req = URLRequest(url: URL(string: "https://www.googleapis.com/drive/v3/files")!)
    req.httpMethod = "POST"
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    var meta: [String: Any] = ["name": name, "mimeType": "application/vnd.google-apps.folder"]
    if let parent = parentId { meta["parents"] = [parent] }
    req.httpBody = try? JSONSerialization.data(withJSONObject: meta)
    URLSession.shared.dataTask(with: req) { data, _, error in
      if let error = error { completion(.failure(error)); return }
      guard let data,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let id = json["id"] as? String
      else { completion(.failure(GDriveError.apiFailed("create folder"))); return }
      completion(.success(id))
    }.resume()
  }

  // MARK: - Drive File Upload

  private func findFileId(name: String, folderId: String, token: String, completion: @escaping (Result<String?, Error>) -> Void) {
    let q = "name='\(name)' and '\(folderId)' in parents and trashed=false"
    var comps = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!
    comps.queryItems = [.init(name: "q", value: q), .init(name: "fields", value: "files(id)")]
    var req = URLRequest(url: comps.url!)
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    URLSession.shared.dataTask(with: req) { data, _, error in
      if let error = error { completion(.failure(error)); return }
      guard let data,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let files = json["files"] as? [[String: Any]]
      else { completion(.failure(GDriveError.apiFailed("find file"))); return }
      completion(.success(files.first?["id"] as? String))
    }.resume()
  }

  /// 上传文件（存在则覆盖，否则新建）
  private func uploadOrReplaceFile(
    data: Data, name: String, folderId: String, mimeType: String, token: String,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    findFileId(name: name, folderId: folderId, token: token) { [weak self] result in
      switch result {
      case .failure(let e): completion(.failure(e))
      case .success(let fileId):
        if let fileId {
          self?.updateFile(fileId: fileId, data: data, mimeType: mimeType, token: token, completion: completion)
        } else {
          self?.createFile(data: data, name: name, folderId: folderId, mimeType: mimeType, token: token, completion: completion)
        }
      }
    }
  }

  private func createFile(
    data: Data, name: String, folderId: String, mimeType: String, token: String,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    let boundary = "Boundary-\(UUID().uuidString)"
    var req = URLRequest(url: URL(string: "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart")!)
    req.httpMethod = "POST"
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    let meta = try? JSONSerialization.data(withJSONObject: ["name": name, "parents": [folderId]])
    var body = Data()
    body.append("--\(boundary)\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n".data(using: .utf8)!)
    body.append(meta ?? Data())
    body.append("\r\n--\(boundary)\r\nContent-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
    body.append(data)
    body.append("\r\n--\(boundary)--".data(using: .utf8)!)
    req.httpBody = body
    URLSession.shared.dataTask(with: req) { _, _, error in
      DispatchQueue.main.async { completion(error.map { .failure($0) } ?? .success(())) }
    }.resume()
  }

  private func updateFile(
    fileId: String, data: Data, mimeType: String, token: String,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    var req = URLRequest(url: URL(string: "https://www.googleapis.com/upload/drive/v3/files/\(fileId)?uploadType=media")!)
    req.httpMethod = "PATCH"
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req.setValue(mimeType, forHTTPHeaderField: "Content-Type")
    req.httpBody = data
    URLSession.shared.dataTask(with: req) { _, _, error in
      DispatchQueue.main.async { completion(error.map { .failure($0) } ?? .success(())) }
    }.resume()
  }

  // MARK: - Public Sync

  /// 同步选定日期的 GURU 输入记录到 Google Drive/Hamster/GURU/
  public func syncGURU(
    dates: [Date],
    guruBaseURL: URL,
    progress: ((Double) -> Void)? = nil,
    completion: @escaping (Result<Int, Error>) -> Void
  ) {
    refreshAccessToken { [weak self] result in
      switch result {
      case .failure(let e): DispatchQueue.main.async { completion(.failure(e)) }
      case .success(let token):
        self?.findOrCreateFolder(name: "Hamster", token: token) { result in
          switch result {
          case .failure(let e): DispatchQueue.main.async { completion(.failure(e)) }
          case .success(let hamsterId):
            self?.findOrCreateFolder(name: "GURU", parentId: hamsterId, token: token) { result in
              switch result {
              case .failure(let e): DispatchQueue.main.async { completion(.failure(e)) }
              case .success(let folderId):
                self?.uploadLocalFiles(
                  dates: dates, baseURL: guruBaseURL, folderId: folderId,
                  mimeType: "application/jsonlines", token: token,
                  progress: progress, completion: completion
                )
              }
            }
          }
        }
      }
    }
  }

  /// 同步选定日期的剪贴板记录到 Google Drive/Hamster/Clipboard/
  public func syncClipboard(
    dates: [Date],
    clipboardBaseURL: URL,
    progress: ((Double) -> Void)? = nil,
    completion: @escaping (Result<Int, Error>) -> Void
  ) {
    refreshAccessToken { [weak self] result in
      switch result {
      case .failure(let e): DispatchQueue.main.async { completion(.failure(e)) }
      case .success(let token):
        self?.findOrCreateFolder(name: "Hamster", token: token) { result in
          switch result {
          case .failure(let e): DispatchQueue.main.async { completion(.failure(e)) }
          case .success(let hamsterId):
            self?.findOrCreateFolder(name: "Clipboard", parentId: hamsterId, token: token) { result in
              switch result {
              case .failure(let e): DispatchQueue.main.async { completion(.failure(e)) }
              case .success(let folderId):
                self?.uploadLocalFiles(
                  dates: dates, baseURL: clipboardBaseURL, folderId: folderId,
                  mimeType: "application/jsonlines", token: token,
                  progress: progress, completion: completion
                )
              }
            }
          }
        }
      }
    }
  }

  private func uploadLocalFiles(
    dates: [Date], baseURL: URL, folderId: String, mimeType: String, token: String,
    progress: ((Double) -> Void)?,
    completion: @escaping (Result<Int, Error>) -> Void
  ) {
    let fm = FileManager.default
    let total = max(dates.count, 1)
    var uploaded = 0
    var index = 0

    func next() {
      guard index < dates.count else {
        DispatchQueue.main.async { completion(.success(uploaded)) }
        return
      }
      let date = dates[index]
      index += 1
      let filename = GURUDataService.dateFormatter.string(from: date) + ".jsonl"
      let fileURL = baseURL.appendingPathComponent(filename)
      guard fm.fileExists(atPath: fileURL.path),
            let data = try? Data(contentsOf: fileURL)
      else {
        DispatchQueue.main.async { progress?(Double(index) / Double(total)) }
        next(); return
      }
      uploadOrReplaceFile(data: data, name: filename, folderId: folderId, mimeType: mimeType, token: token) { result in
        if case .success = result { uploaded += 1 }
        DispatchQueue.main.async { progress?(Double(index) / Double(total)) }
        next()
      }
    }
    next()
  }

  // MARK: - Errors

  public enum GDriveError: LocalizedError {
    case notConfigured
    case authFailed
    case cancelled
    case notSignedIn
    case tokenExchangeFailed
    case tokenRefreshFailed
    case apiFailed(String)

    public var errorDescription: String? {
      switch self {
      case .notConfigured: return "请先在设置中填入 Google OAuth Client ID"
      case .authFailed: return "Google 授权失败"
      case .cancelled: return "已取消登录"
      case .notSignedIn: return "未登录 Google 账号"
      case .tokenExchangeFailed: return "获取 Token 失败，请检查 Client ID 是否正确"
      case .tokenRefreshFailed: return "Token 刷新失败，请重新登录"
      case .apiFailed(let msg): return "Google Drive API 错误：\(msg)"
      }
    }
  }
}

// MARK: - ASWebAuthenticationSession Anchor

private class AnchorProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
  let anchor: ASPresentationAnchor
  init(anchor: ASPresentationAnchor) { self.anchor = anchor }
  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { anchor }
}
