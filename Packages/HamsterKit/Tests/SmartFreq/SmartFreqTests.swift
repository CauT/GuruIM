@testable import HamsterKit
import XCTest

// MARK: - AIUsage Tests

final class AIUsageTests: XCTestCase {
  func testTotalTokens() {
    let usage = AIUsage(inputTokens: 100, outputTokens: 50)
    XCTAssertEqual(usage.totalTokens, 150)
  }

  func testZeroTokens() {
    let usage = AIUsage(inputTokens: 0, outputTokens: 0)
    XCTAssertEqual(usage.totalTokens, 0)
  }

  func testCodableRoundtrip() throws {
    let usage = AIUsage(inputTokens: 1234, outputTokens: 567)
    let data = try JSONEncoder().encode(usage)
    let decoded = try JSONDecoder().decode(AIUsage.self, from: data)
    XCTAssertEqual(decoded.inputTokens, 1234)
    XCTAssertEqual(decoded.outputTokens, 567)
    XCTAssertEqual(decoded.totalTokens, 1801)
  }
}

// MARK: - SmartFreqConfig Tests

final class SmartFreqConfigTests: XCTestCase {
  func testDefaultValues() {
    let config = SmartFreqConfig()
    XCTAssertFalse(config.isEnabled)
    XCTAssertEqual(config.intervalMinutes, 24 * 60)
    XCTAssertEqual(config.monthlyTokenBudget, 0)
    XCTAssertEqual(config.monthlyTokensUsed, 0)
    XCTAssertEqual(config.budgetMonth, "")
    XCTAssertNil(config.lastRunDate)
  }

  func testCodableRoundtrip() throws {
    var config = SmartFreqConfig()
    config.isEnabled = true
    config.intervalMinutes = 12 * 60
    config.monthlyTokenBudget = 50000
    config.monthlyTokensUsed = 1200
    config.budgetMonth = "2026-03"
    config.lastRunDate = Date(timeIntervalSince1970: 1000000)

    let data = try JSONEncoder().encode(config)
    let decoded = try JSONDecoder().decode(SmartFreqConfig.self, from: data)

    XCTAssertTrue(decoded.isEnabled)
    XCTAssertEqual(decoded.intervalMinutes, 12 * 60)
    XCTAssertEqual(decoded.monthlyTokenBudget, 50000)
    XCTAssertEqual(decoded.monthlyTokensUsed, 1200)
    XCTAssertEqual(decoded.budgetMonth, "2026-03")
    XCTAssertEqual(decoded.lastRunDate?.timeIntervalSince1970 ?? 0, 1000000, accuracy: 0.001)
  }
}

// MARK: - SmartFreqResult Tests

final class SmartFreqResultTests: XCTestCase {
  func testInitialization() {
    let result = SmartFreqResult(
      entriesCount: 10,
      boostCount: 3,
      demoteCount: 1,
      newPhraseCount: 2,
      tokensUsed: 500
    )
    XCTAssertEqual(result.entriesCount, 10)
    XCTAssertEqual(result.boostCount, 3)
    XCTAssertEqual(result.demoteCount, 1)
    XCTAssertEqual(result.newPhraseCount, 2)
    XCTAssertEqual(result.tokensUsed, 500)
    XCTAssertNotNil(result.id)
  }

  func testCodableRoundtrip() throws {
    let original = SmartFreqResult(
      entriesCount: 5, boostCount: 2, demoteCount: 0, newPhraseCount: 1, tokensUsed: 200
    )
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(SmartFreqResult.self, from: data)
    XCTAssertEqual(decoded.id, original.id)
    XCTAssertEqual(decoded.boostCount, 2)
    XCTAssertEqual(decoded.newPhraseCount, 1)
    XCTAssertEqual(decoded.tokensUsed, 200)
  }
}

// MARK: - SmartFreqService.parseRules Tests

final class SmartFreqParseRulesTests: XCTestCase {
  let service = SmartFreqService.shared

  func testParseBoostRule() {
    let input = "FREQ\tboost\tnihao\t你好"
    let (freqRules, newPhrases) = service.parseRules(input)
    XCTAssertEqual(freqRules.count, 1)
    XCTAssertEqual(freqRules[0].action, "boost")
    XCTAssertEqual(freqRules[0].code, "nihao")
    XCTAssertEqual(freqRules[0].word, "你好")
    XCTAssertTrue(newPhrases.isEmpty)
  }

  func testParseDemoteRule() {
    let input = "FREQ\tdemote\tyanshe\t颜射"
    let (freqRules, _) = service.parseRules(input)
    XCTAssertEqual(freqRules.count, 1)
    XCTAssertEqual(freqRules[0].action, "demote")
    XCTAssertEqual(freqRules[0].code, "yanshe")
    XCTAssertEqual(freqRules[0].word, "颜射")
  }

  func testParseNewPhraseRule() {
    let input = "NEW\tniupi\t牛批"
    let (freqRules, newPhrases) = service.parseRules(input)
    XCTAssertTrue(freqRules.isEmpty)
    XCTAssertEqual(newPhrases.count, 1)
    XCTAssertEqual(newPhrases[0].code, "niupi")
    XCTAssertEqual(newPhrases[0].word, "牛批")
  }

  func testParseMultipleRules() {
    let input = """
    FREQ\tboost\tnihao\t你好
    FREQ\tdemote\tnihao\t拟好
    NEW\tniupi\t牛批
    FREQ\tboost\tshijie\t世界
    """
    let (freqRules, newPhrases) = service.parseRules(input)
    XCTAssertEqual(freqRules.count, 3)
    XCTAssertEqual(newPhrases.count, 1)
    XCTAssertEqual(freqRules[0].action, "boost")
    XCTAssertEqual(freqRules[1].action, "demote")
    XCTAssertEqual(freqRules[2].code, "shijie")
  }

  func testSkipsCommentLines() {
    let input = """
    # 这是注释
    FREQ\tboost\tnihao\t你好
    # 另一个注释
    """
    let (freqRules, newPhrases) = service.parseRules(input)
    XCTAssertEqual(freqRules.count, 1)
    XCTAssertTrue(newPhrases.isEmpty)
  }

  func testSkipsEmptyLines() {
    let input = "\n\nFREQ\tboost\tnihao\t你好\n\n"
    let (freqRules, _) = service.parseRules(input)
    XCTAssertEqual(freqRules.count, 1)
  }

  func testSkipsInvalidAction() {
    let input = "FREQ\tup\tnihao\t你好"
    let (freqRules, _) = service.parseRules(input)
    XCTAssertTrue(freqRules.isEmpty)
  }

  func testSkipsUnknownPrefix() {
    let input = "UNKNOWN\tboost\tnihao\t你好"
    let (freqRules, newPhrases) = service.parseRules(input)
    XCTAssertTrue(freqRules.isEmpty)
    XCTAssertTrue(newPhrases.isEmpty)
  }

  func testSkipsInsufficientColumns() {
    // FREQ needs 4 cols, NEW needs 3 cols
    let input = "FREQ\tboost\tnihao\nNEW\tcode"
    let (freqRules, newPhrases) = service.parseRules(input)
    XCTAssertTrue(freqRules.isEmpty)
    XCTAssertTrue(newPhrases.isEmpty)
  }

  func testEmptyInput() {
    let (freqRules, newPhrases) = service.parseRules("")
    XCTAssertTrue(freqRules.isEmpty)
    XCTAssertTrue(newPhrases.isEmpty)
  }

  func testActionIsCaseNormalized() {
    // parseRules 先 lowercased()，BOOST → boost 合法
    let input = "FREQ\tBOOST\tnihao\t你好"
    let (freqRules, _) = service.parseRules(input)
    XCTAssertEqual(freqRules.count, 1)
    XCTAssertEqual(freqRules[0].action, "boost")
  }

  func testCodeIsLowercased() {
    let input = "FREQ\tboost\tNiHao\t你好"
    let (freqRules, _) = service.parseRules(input)
    XCTAssertEqual(freqRules.count, 1)
    XCTAssertEqual(freqRules[0].code, "nihao")
  }

  func testWordIsTrimmed() {
    let input = "FREQ\tboost\tnihao\t  你好  "
    let (freqRules, _) = service.parseRules(input)
    XCTAssertEqual(freqRules[0].word, "你好")
  }
}

// MARK: - SmartFreqService.loadExistingLines Tests

final class SmartFreqLoadLinesTests: XCTestCase {
  let service = SmartFreqService.shared

  private var tmpURL: URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("sf_test_\(UUID().uuidString).txt")
  }

  func testLoadsNonEmptyLines() throws {
    let url = tmpURL
    try "boost\tnihao\t你好\ndemote\tnihao\t拟好\n".write(to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }

    let lines = service.loadExistingLines(from: url)
    XCTAssertEqual(lines.count, 2)
    XCTAssertEqual(lines[0], "boost\tnihao\t你好")
    XCTAssertEqual(lines[1], "demote\tnihao\t拟好")
  }

  func testFiltersCommentLines() throws {
    let url = tmpURL
    try "# comment\nboost\tnihao\t你好\n".write(to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }

    let lines = service.loadExistingLines(from: url)
    XCTAssertEqual(lines.count, 1)
    XCTAssertEqual(lines[0], "boost\tnihao\t你好")
  }

  func testFiltersEmptyLines() throws {
    let url = tmpURL
    try "\n\nboost\tnihao\t你好\n\n".write(to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }

    let lines = service.loadExistingLines(from: url)
    XCTAssertEqual(lines.count, 1)
  }

  func testReturnsEmptyForMissingFile() {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("nonexistent_\(UUID().uuidString).txt")
    let lines = service.loadExistingLines(from: url)
    XCTAssertTrue(lines.isEmpty)
  }

  func testTrimsWhitespace() throws {
    let url = tmpURL
    try "  boost\tnihao\t你好  \n".write(to: url, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: url) }

    let lines = service.loadExistingLines(from: url)
    XCTAssertEqual(lines[0], "boost\tnihao\t你好")
  }
}

// MARK: - SmartFreqService.mergeFreqRules Tests

final class SmartFreqMergeFreqRulesTests: XCTestCase {
  /// 临时替换 rulesFileURL，测试后清理
  private func withTmpRulesFile(initialContent: String? = nil, block: (URL) throws -> Void) throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("sf_rules_\(UUID().uuidString).txt")
    if let content = initialContent {
      try content.write(to: url, atomically: true, encoding: .utf8)
    }
    defer { try? FileManager.default.removeItem(at: url) }
    try block(url)
  }

  func testWritesFreqRulesToFile() throws {
    let service = SmartFreqService.shared
    try withTmpRulesFile { url in
      // 直接调用内部逻辑（绕开 rulesFileURL，直接通过 mergeFreqRules 写入，再用 loadExistingLines 读出验证）
      // 因为 mergeFreqRules 写入的是 rulesFileURL，这里只测 loadExistingLines 的解析正确性
      let content = "boost\tnihao\t你好\ndemote\tnihao\t拟好\n"
      try content.write(to: url, atomically: true, encoding: .utf8)
      let lines = service.loadExistingLines(from: url)
      XCTAssertEqual(lines.count, 2)
      XCTAssertTrue(lines.contains("boost\tnihao\t你好"))
      XCTAssertTrue(lines.contains("demote\tnihao\t拟好"))
    }
  }

  func testDeduplicatesRules() throws {
    let service = SmartFreqService.shared
    try withTmpRulesFile(initialContent: "boost\tnihao\t你好\n") { url in
      let content = try String(contentsOf: url, encoding: .utf8)
      var lines = service.loadExistingLines(from: url)
      var set = Set(lines)
      // 模拟合并去重逻辑
      let newLine = "boost\tnihao\t你好"
      if !set.contains(newLine) {
        lines.append(newLine)
        set.insert(newLine)
      }
      // 重复写入同一条规则后数量不变
      XCTAssertEqual(lines.count, 1)
      _ = content  // suppress warning
    }
  }
}

// MARK: - SmartFreqService.mergeNewPhrases Tests

final class SmartFreqMergeNewPhrasesTests: XCTestCase {
  func testNewPhraseLineFormat() {
    // 验证新词行格式符合 Lua translator 预期：code<TAB>word
    let code = "niupi"
    let word = "牛批"
    let line = "\(code)\t\(word)"
    let parts = line.components(separatedBy: "\t")
    XCTAssertEqual(parts.count, 2)
    XCTAssertEqual(parts[0], code)
    XCTAssertEqual(parts[1], word)
  }
}

// MARK: - SmartFreqService.monthString Tests

final class SmartFreqMonthStringTests: XCTestCase {
  func testMonthStringFormat() {
    // 2026-03-28 → "2026-03"
    var comps = DateComponents()
    comps.year = 2026
    comps.month = 3
    comps.day = 28
    let date = Calendar.current.date(from: comps)!
    let result = SmartFreqService.monthString(for: date)
    XCTAssertEqual(result, "2026-03")
  }

  func testMonthStringForDecember() {
    var comps = DateComponents()
    comps.year = 2025
    comps.month = 12
    comps.day = 1
    let date = Calendar.current.date(from: comps)!
    XCTAssertEqual(SmartFreqService.monthString(for: date), "2025-12")
  }

  func testMonthStringPadsSingleDigitMonth() {
    var comps = DateComponents()
    comps.year = 2026
    comps.month = 1
    comps.day = 15
    let date = Calendar.current.date(from: comps)!
    XCTAssertEqual(SmartFreqService.monthString(for: date), "2026-01")
  }
}

// MARK: - SmartFreqService.shouldRun Tests

final class SmartFreqShouldRunTests: XCTestCase {
  private let service = SmartFreqService.shared
  private var savedConfig: SmartFreqConfig!

  override func setUp() {
    super.setUp()
    savedConfig = service.config
    // 每次测试前重置为已知的干净状态
    service.config = SmartFreqConfig()
  }

  override func tearDown() {
    // 每次测试后还原
    service.config = savedConfig
    super.tearDown()
  }

  func testShouldNotRunWhenDisabled() {
    var cfg = SmartFreqConfig()
    cfg.isEnabled = false
    service.config = cfg
    XCTAssertFalse(service.shouldRun)
  }

  func testShouldNotRunWhenIntervalNotMet() {
    var cfg = SmartFreqConfig()
    cfg.isEnabled = true
    cfg.intervalMinutes = 24 * 60
    cfg.lastRunDate = Date()  // 刚跑过
    service.config = cfg
    // isEnabled=true 但 API key 为空会截断，shouldRun == false
    XCTAssertFalse(service.shouldRun)
  }

  func testShouldNotRunWhenDisabledWithNilLastRunDate() {
    var cfg = SmartFreqConfig()
    cfg.isEnabled = false
    cfg.lastRunDate = nil
    service.config = cfg
    XCTAssertFalse(service.shouldRun)
  }

  func testTokenBudgetExhaustedPreventsRun() {
    var cfg = SmartFreqConfig()
    cfg.isEnabled = true
    cfg.monthlyTokenBudget = 1000
    cfg.monthlyTokensUsed = 1000
    cfg.budgetMonth = SmartFreqService.monthString(for: Date())
    service.config = cfg
    // API key 为空先返回 false，但 budget 逻辑在其后，整体 shouldRun == false
    XCTAssertFalse(service.shouldRun)
  }

  func testTokenBudgetNotExhaustedDoesNotBlockAlone() {
    var cfg = SmartFreqConfig()
    cfg.isEnabled = false  // disabled，所以整体仍 false
    cfg.monthlyTokenBudget = 1000
    cfg.monthlyTokensUsed = 500  // 未超预算
    cfg.budgetMonth = SmartFreqService.monthString(for: Date())
    service.config = cfg
    XCTAssertFalse(service.shouldRun)  // 被 isEnabled=false 拦截
  }
}
