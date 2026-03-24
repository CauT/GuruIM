import Foundation

/// 敏感词过滤服务
/// 在 GURU 和剪贴板内容写入磁盘前，将匹配到的内容替换为 ***
/// 设置持久化在 App Group UserDefaults，键盘扩展与主 App 共享
public final class SensitiveFilter {
  public static let shared = SensitiveFilter()

  private let defaults = UserDefaults(suiteName: HamsterConstants.appGroupName)

  // MARK: - Toggles（默认全部关闭，用户需手动开启）

  /// 过滤手机号（中国大陆：1[3-9]开头，11位）
  public var filterPhone: Bool {
    get { defaults?.bool(forKey: "sf_phone") ?? false }
    set { defaults?.set(newValue, forKey: "sf_phone") }
  }

  /// 过滤银行卡号（13-19位纯数字）
  public var filterBankCard: Bool {
    get { defaults?.bool(forKey: "sf_bankcard") ?? false }
    set { defaults?.set(newValue, forKey: "sf_bankcard") }
  }

  /// 过滤 Email 地址
  public var filterEmail: Bool {
    get { defaults?.bool(forKey: "sf_email") ?? false }
    set { defaults?.set(newValue, forKey: "sf_email") }
  }

  // MARK: - Custom Words

  private let wordsKey = "sf_custom_words"

  public var customWords: [String] {
    get {
      guard let data = defaults?.data(forKey: wordsKey),
            let words = try? JSONDecoder().decode([String].self, from: data) else { return [] }
      return words
    }
    set {
      defaults?.set(try? JSONEncoder().encode(newValue), forKey: wordsKey)
    }
  }

  public func addWord(_ word: String) {
    let w = word.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !w.isEmpty else { return }
    var list = customWords
    if !list.contains(w) { list.append(w) }
    customWords = list
  }

  public func removeWord(_ word: String) {
    customWords = customWords.filter { $0 != word }
  }

  public func removeWords(at indices: IndexSet) {
    var list = customWords
    for index in indices.reversed() where index < list.count {
      list.remove(at: index)
    }
    customWords = list
  }

  // MARK: - Filter

  /// 对文本进行过滤，将命中内容替换为 ***
  public func filter(_ text: String) -> String {
    guard isAnyFilterActive else { return text }
    var result = text

    // 1. 自定义敏感词（大小写不敏感）
    for word in customWords where !word.isEmpty {
      result = result.replacingOccurrences(
        of: NSRegularExpression.escapedPattern(for: word),
        with: "***",
        options: [.regularExpression, .caseInsensitive]
      )
    }

    // 2. 手机号（中国大陆）
    if filterPhone {
      result = replaceRegex(#"(?<!\d)1[3-9]\d{9}(?!\d)"#, in: result)
    }

    // 3. 银行卡号（13-19位数字，前后不紧跟其他数字）
    if filterBankCard {
      result = replaceRegex(#"(?<!\d)\d{13,19}(?!\d)"#, in: result)
    }

    // 4. Email
    if filterEmail {
      result = replaceRegex(
        #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#,
        in: result
      )
    }

    return result
  }

  // MARK: - Private

  private var isAnyFilterActive: Bool {
    filterPhone || filterBankCard || filterEmail || !customWords.isEmpty
  }

  private func replaceRegex(_ pattern: String, in text: String) -> String {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
    let range = NSRange(text.startIndex..., in: text)
    return regex.stringByReplacingMatches(in: text, range: range, withTemplate: "***")
  }
}
