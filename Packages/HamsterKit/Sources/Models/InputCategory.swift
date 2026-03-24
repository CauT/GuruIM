import Foundation

/// iOS 键盘扩展可感知的输入场景分类
/// 来源：isSecureTextEntry / UITextContentType / UIKeyboardType / UIReturnKeyType
public enum InputCategory: String, Codable, CaseIterable, Identifiable {
  // MARK: - 高敏感（默认不采集）

  /// 密码框（isSecureTextEntry = true 或 textContentType 为 password/newPassword）
  case password     = "password"
  /// 支付/信用卡（textContentType: creditCardNumber）
  case payment      = "payment"
  /// 验证码/OTP（textContentType: oneTimeCode）
  case otp          = "otp"
  /// 账号登录（textContentType: username）
  case login        = "login"

  // MARK: - 中等敏感（默认采集，用户可关闭）

  /// 电话号码（textContentType: telephoneNumber / keyboardType: phonePad, namePhonePad）
  case phone        = "phone"
  /// Email 地址（textContentType: emailAddress / keyboardType: emailAddress）
  case email        = "email"
  /// 姓名（textContentType: name/givenName/familyName/middleName/namePrefix/nameSuffix/nickname）
  case name         = "name"
  /// 地址/位置（textContentType: fullStreetAddress/streetAddressLine1-2/addressCity/addressState/
  ///            addressCityAndState/countryName/postalCode/location/sublocality）
  case address      = "address"
  /// 组织/职位（textContentType: organizationName/jobTitle）
  case organization = "organization"

  // MARK: - 低敏感（默认采集）

  /// URL / 搜索（textContentType: URL / keyboardType: URL/webSearch / returnKey: search/google/yahoo）
  case url          = "url"
  /// 日期/时间（textContentType: dateTime）
  case dateTime     = "dateTime"
  /// 物流/出行（textContentType: flightNumber/shipmentTrackingNumber）
  case logistics    = "logistics"
  /// 普通文字（以上均不匹配时）
  case general      = "general"

  public var id: String { rawValue }

  // MARK: - Display

  public var displayName: String {
    switch self {
    case .password:     return "密码 / 安全"
    case .payment:      return "支付 / 信用卡"
    case .otp:          return "验证码 / OTP"
    case .login:        return "账号登录"
    case .phone:        return "电话号码"
    case .email:        return "Email 地址"
    case .name:         return "姓名 / 昵称"
    case .address:      return "地址 / 位置"
    case .organization: return "组织 / 职位"
    case .url:          return "URL / 搜索"
    case .dateTime:     return "日期 / 时间"
    case .logistics:    return "快递 / 航班"
    case .general:      return "普通文字"
    }
  }

  public var detail: String {
    switch self {
    case .password:     return "isSecureTextEntry · password · newPassword"
    case .payment:      return "creditCardNumber"
    case .otp:          return "oneTimeCode"
    case .login:        return "username"
    case .phone:        return "telephoneNumber · phonePad · namePhonePad"
    case .email:        return "emailAddress · keyboardType.emailAddress"
    case .name:         return "name · givenName · familyName · nickname 等"
    case .address:      return "streetAddress · city · postalCode · location 等"
    case .organization: return "organizationName · jobTitle"
    case .url:          return "URL · keyboardType.URL · webSearch"
    case .dateTime:     return "dateTime"
    case .logistics:    return "flightNumber · shipmentTrackingNumber"
    case .general:      return "default · numbersAndPunctuation · numberPad 等"
    }
  }

  public var systemImage: String {
    switch self {
    case .password:     return "lock.fill"
    case .payment:      return "creditcard.fill"
    case .otp:          return "number.square.fill"
    case .login:        return "person.fill"
    case .phone:        return "phone.fill"
    case .email:        return "envelope.fill"
    case .name:         return "person.text.rectangle.fill"
    case .address:      return "map.fill"
    case .organization: return "building.2.fill"
    case .url:          return "safari.fill"
    case .dateTime:     return "calendar"
    case .logistics:    return "shippingbox.fill"
    case .general:      return "text.cursor"
    }
  }

  /// 密码始终不采集，不向用户暴露开关
  public var isAlwaysBlocked: Bool { self == .password }

  /// 默认是否屏蔽采集
  public var isBlockedByDefault: Bool {
    switch self {
    case .password, .payment, .otp, .login: return true
    default: return false
    }
  }
}
