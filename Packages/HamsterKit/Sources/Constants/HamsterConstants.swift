//
//  HamsterConstants.swift
//
//
//  Created by morse on 2023/7/3.
//

import Foundation

/// Hamster 应用常量
public enum HamsterConstants {
  /// AppGroup ID
  public static let appGroupName = "group.com.desgemini.guru"

  /// iCloud ID
  public static let iCloudID = "iCloud.com.desgemini.guru"

  /// keyboard Bundle ID
  public static let keyboardBundleID = "com.desgemini.guru.keyboard"

  /// 跳转至系统添加键盘URL
  public static let addKeyboardPath = "app-settings:root=General&path=Keyboard/KEYBOARDS"

  // MARK: 与Squirrel.app保持一致

  /// RIME 预先构建的数据目录中
  public static let rimeSharedSupportPathName = "SharedSupport"

  /// RIME UserData目录
  public static let rimeUserPathName = "Rime"

  /// RIME 内置输入方案及配置zip包
  public static let inputSchemaZipFile = "SharedSupport.zip"

  /// 仓内置方案 zip 包
  public static let userDataZipFile = "rime-ice.zip"

  /// APP URL
  /// 注意: 此值需要与info.plist中的参数保持一致
  public static let appURL = "hamster://dev.fuxiao.app.hamster"

  // MARK: - Google Drive OAuth
  // 在 https://console.cloud.google.com/ 创建 iOS 类型 OAuth 2.0 Client
  // Bundle ID: com.donglingyong.Hamster
  // 填入后需在 Hamster/Info.plist 的 CFBundleURLTypes 中添加 googleRedirectScheme 作为 URL Scheme
  public static let googleOAuthClientID = "YOUR_CLIENT_ID.apps.googleusercontent.com"
  // 反转 client ID: com.googleusercontent.apps.YOUR_CLIENT_ID
  public static let googleRedirectScheme = "com.googleusercontent.apps.YOUR_CLIENT_ID"
}
