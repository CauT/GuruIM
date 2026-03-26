import Foundation

/// 支持的 AI 提供商
public enum AIProvider: String, Codable, CaseIterable {
  case openai      = "OpenAI"
  case openrouter  = "OpenRouter"
  case claude      = "Claude"
  case kimi        = "Kimi"
  case minimax     = "MiniMax"
  case glm         = "GLM"

  public var baseURL: String {
    switch self {
    case .openai:     return "https://api.openai.com/v1"
    case .openrouter: return "https://openrouter.ai/api/v1"
    case .claude:     return "https://api.anthropic.com/v1"
    case .kimi:       return "https://api.moonshot.cn/v1"
    case .minimax:    return "https://api.minimax.chat/v1"
    case .glm:        return "https://open.bigmodel.cn/api/paas/v4"
    }
  }

  public var defaultModel: String {
    switch self {
    case .openai:     return "gpt-4o"
    case .openrouter: return "openai/gpt-4o"
    case .claude:     return "claude-opus-4-6"
    case .kimi:       return "moonshot-v1-8k"
    case .minimax:    return "abab6.5s-chat"
    case .glm:        return "glm-4-flash"
    }
  }

  /// 使用 OpenAI 兼容协议的提供商
  public var isOpenAICompat: Bool { self != .claude }
}

/// AI Prompt 模板
public struct AIPrompt: Codable, Identifiable {
  public let id: UUID
  public var name: String
  public var content: String

  public init(id: UUID = UUID(), name: String, content: String) {
    self.id = id
    self.name = name
    self.content = content
  }
}

/// AI 对话消息
public struct AIMessage: Codable {
  public let role: String   // "user" | "assistant" | "system"
  public let content: String

  public init(role: String, content: String) {
    self.role = role
    self.content = content
  }
}

/// AI 服务 - 统一封装 OpenAI / OpenRouter / Claude API
public class AIService {
  public static let shared = AIService()

  private let defaults = UserDefaults(suiteName: HamsterConstants.appGroupName)

  // MARK: - Config Storage

  public var selectedProvider: AIProvider {
    get {
      let raw = defaults?.string(forKey: "ai_provider") ?? AIProvider.claude.rawValue
      return AIProvider(rawValue: raw) ?? .claude
    }
    set { defaults?.set(newValue.rawValue, forKey: "ai_provider") }
  }

  public var selectedModel: String {
    get { defaults?.string(forKey: "ai_model") ?? selectedProvider.defaultModel }
    set { defaults?.set(newValue, forKey: "ai_model") }
  }

  public func apiKey(for provider: AIProvider) -> String {
    defaults?.string(forKey: "ai_key_\(provider.rawValue)") ?? ""
  }

  public func setApiKey(_ key: String, for provider: AIProvider) {
    defaults?.set(key, forKey: "ai_key_\(provider.rawValue)")
  }

  // MARK: - Prompt Management

  private let promptsKey = "ai_prompts"

  public var savedPrompts: [AIPrompt] {
    get {
      guard let data = defaults?.data(forKey: promptsKey),
            let prompts = try? JSONDecoder().decode([AIPrompt].self, from: data)
      else { return defaultPrompts }
      return prompts
    }
    set {
      defaults?.set(try? JSONEncoder().encode(newValue), forKey: promptsKey)
    }
  }

  private var defaultPrompts: [AIPrompt] {
    [
      AIPrompt(name: "输入习惯分析", content: "请分析以下我的输入记录，总结我的输入习惯、常用词汇、关注话题，并给出洞察：\n\n"),
      AIPrompt(name: "剪贴板内容整理", content: "以下是我最近的剪贴板内容，请帮我整理、分类，提取关键信息：\n\n"),
      AIPrompt(name: "写作风格分析", content: "请分析以下文本样本，描述我的写作风格特点：\n\n"),
      AIPrompt(name: "自由问答", content: ""),
    ]
  }

  public func addPrompt(_ prompt: AIPrompt) {
    var prompts = savedPrompts
    prompts.append(prompt)
    savedPrompts = prompts
  }

  public func updatePrompt(_ prompt: AIPrompt) {
    var prompts = savedPrompts
    if let idx = prompts.firstIndex(where: { $0.id == prompt.id }) {
      prompts[idx] = prompt
    }
    savedPrompts = prompts
  }

  public func deletePrompt(id: UUID) {
    savedPrompts = savedPrompts.filter { $0.id != id }
  }

  // MARK: - Chat

  /// 发送消息到当前选定的 AI 提供商
  public func chat(
    messages: [AIMessage],
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    let provider = selectedProvider
    let key = apiKey(for: provider)
    guard !key.isEmpty else {
      completion(.failure(AIError.noAPIKey(provider)))
      return
    }
    switch provider {
    case .claude:
      chatClaude(messages: messages, apiKey: key, completion: completion)
    default:
      chatOpenAICompat(messages: messages, provider: provider, apiKey: key, completion: completion)
    }
  }

  // MARK: - OpenAI-compatible (OpenAI + OpenRouter)

  private func chatOpenAICompat(
    messages: [AIMessage],
    provider: AIProvider,
    apiKey: String,
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    let url = URL(string: "\(provider.baseURL)/chat/completions")!
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if provider == .openrouter {
      req.setValue("Hamster iOS", forHTTPHeaderField: "X-Title")
    }
    let body: [String: Any] = [
      "model": selectedModel,
      "messages": messages.map { ["role": $0.role, "content": $0.content] },
      "max_tokens": 4096,
    ]
    req.httpBody = try? JSONSerialization.data(withJSONObject: body)
    URLSession.shared.dataTask(with: req) { data, response, error in
      if let error = error { DispatchQueue.main.async { completion(.failure(error)) }; return }
      guard let data else { DispatchQueue.main.async { completion(.failure(AIError.emptyResponse)) }; return }
      guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        DispatchQueue.main.async { completion(.failure(AIError.parseError)) }; return
      }
      // 错误响应
      if let errObj = json["error"] as? [String: Any], let msg = errObj["message"] as? String {
        DispatchQueue.main.async { completion(.failure(AIError.apiError(msg))) }; return
      }
      guard let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
      else {
        DispatchQueue.main.async { completion(.failure(AIError.parseError)) }; return
      }
      DispatchQueue.main.async { completion(.success(content)) }
    }.resume()
  }

  // MARK: - Claude (Anthropic Messages API)

  private func chatClaude(
    messages: [AIMessage],
    apiKey: String,
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    let url = URL(string: "https://api.anthropic.com/v1/messages")!
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
    req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")

    // Claude API 将 system 消息单独处理
    let systemMsg = messages.first(where: { $0.role == "system" })?.content
    let chatMsgs = messages.filter { $0.role != "system" }

    var body: [String: Any] = [
      "model": selectedModel,
      "max_tokens": 4096,
      "messages": chatMsgs.map { ["role": $0.role, "content": $0.content] },
    ]
    if let sys = systemMsg, !sys.isEmpty { body["system"] = sys }
    req.httpBody = try? JSONSerialization.data(withJSONObject: body)

    URLSession.shared.dataTask(with: req) { data, _, error in
      if let error = error { DispatchQueue.main.async { completion(.failure(error)) }; return }
      guard let data else { DispatchQueue.main.async { completion(.failure(AIError.emptyResponse)) }; return }
      guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        DispatchQueue.main.async { completion(.failure(AIError.parseError)) }; return
      }
      if let errObj = json["error"] as? [String: Any], let msg = errObj["message"] as? String {
        DispatchQueue.main.async { completion(.failure(AIError.apiError(msg))) }; return
      }
      guard let content = json["content"] as? [[String: Any]],
            let text = content.first(where: { $0["type"] as? String == "text" })?["text"] as? String
      else {
        DispatchQueue.main.async { completion(.failure(AIError.parseError)) }; return
      }
      DispatchQueue.main.async { completion(.success(text)) }
    }.resume()
  }

  // MARK: - Errors

  public enum AIError: LocalizedError {
    case noAPIKey(AIProvider)
    case emptyResponse
    case parseError
    case apiError(String)

    public var errorDescription: String? {
      switch self {
      case .noAPIKey(let p): return "请先在设置中填入 \(p.rawValue) API Key"
      case .emptyResponse: return "AI 返回了空响应"
      case .parseError: return "解析 AI 响应失败"
      case .apiError(let msg): return "AI API 错误：\(msg)"
      }
    }
  }
}
