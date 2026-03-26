# Hamster / 仓输入法

基于 [RIME 中州韻輸入法引擎](https://github.com/rime/librime) 的 iOS 输入法，集成 Now Guru 智能助手功能。

## 功能特性

### RIME 输入法

- 支持多种输入方案（内置雾凇拼音）
- 26 键标准键盘 / 中文九宫格 / 数字九宫格
- 自定义键盘布局与划动配置
- 键盘配色方案
- 按键气泡、按键音与震动反馈
- 符号键盘与分类符号键盘
- Emoji 表情键盘（工具栏按钮快速切换，支持分类浏览与最近使用）
- 删除键上滑删除整行
- Wi-Fi 上传输入方案
- 文件管理
- iCloud 同步
- 软件备份与恢复

### Now Guru 智能助手

- **输入采集**：记录键盘输入内容，构建个人数据档案
- **剪贴板监听**：后台持续轮询剪贴板变化，自动采集复制内容
- **AI 分析**：支持 OpenAI / OpenRouter / Claude / Kimi / MiniMax / GLM 多家 AI 后端，自定义 Prompt 对话
- **Google Drive 同步**：OAuth 授权登录，GURU 数据云端备份
- **隐私保护**：输入类型过滤（按应用场景分类）、敏感词过滤、一键隐私暂停
- **每日洞察（Auto Insight）**：定时 AI 分析输入记录，生成心灵安慰与事务指导，本地通知提醒，支持分享与自定义 Prompt

## 项目结构

```
Hamster/
├── Hamster/                    # 主 App Target
├── HamsterKeyboard/            # 键盘 Extension Target
├── Packages/
│   ├── HamsterKeyboardKit/     # 键盘核心库（按键、布局、手势、候选栏）
│   ├── HamsterKit/             # 基础服务库（AI、剪贴板、GURU、配置模型）
│   ├── HamsteriOS/             # iOS UI 层（设置、ViewModel、ViewController）
│   ├── HamsterUIKit/           # UIKit 基础组件
│   ├── RimeKit/                # RIME 引擎 Swift 封装
│   └── HamsterFileServer/      # Wi-Fi 文件上传服务
├── Frameworks/                 # 预编译 xcframework（librime 等）
└── SharedSupport/              # 内置输入方案资源
```

## 编译运行

### 环境要求

- macOS 14+, Xcode 15+
- iOS 16.4+ (Deployment Target)
- 付费 Apple 开发者账号

### 步骤

1. 下载预编译 Framework

```sh
make framework
```

2. 下载内置输入方案

```sh
make schema
```

3. Xcode 打开项目并运行

```sh
xed .
```

> 详细的编译注意事项（platform 补丁、链接器 alias 等）见 `CLAUDE.md`。

## 配置说明

- **App Group**: `group.com.donglingyong.Hamster`
- **Bundle ID 前缀**: `com.donglingyong.Hamster`
- **GURU 数据共享**: 通过 App Group UserDefaults 在主 App 与键盘 Extension 间同步

## 第三方库

| 项目 | 许可证 |
|------|--------|
| [librime](https://github.com/rime/librime) | BSD License |
| [KeyboardKit](https://github.com/KeyboardKit/KeyboardKit) | MIT License |
| [Squirrel](https://github.com/rime/squirrel) | GPL-3.0 License |
| [Runestone](https://github.com/simonbs/Runestone) | MIT License |
| [TreeSitterLanguages](https://github.com/simonbs/TreeSitterLanguages) | MIT License |
| [ProgressHUD](https://github.com/relatedcode/ProgressHUD) | MIT License |
| [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) | MIT License |
| [Yams](https://github.com/jpsim/Yams) | MIT License |
| [GCDWebServer](https://github.com/swisspol/GCDWebServer) | BSD License |

## 许可证

本项目采用 [MIT License](LICENSE.txt)。

本项目最初采用 GPL-3.0 许可，从 v2.1.0 开始变更为 MIT 许可。

## 致谢

感谢 TF 版本交流群中的 @一梦浮生、@CZ36P9z9 等伙伴对测试版本的反馈与帮助，也感谢 @王牌饼干 为输入法制作的工具。感谢 @amorphobia 为 LibrimeKit 提交的 Github Action 配置。

## 捐赠

如果「仓」对您有帮助，可以请我吃份「煎饼馃子」，感激不尽~

> 注意：不接收有偿咨询服务，请勿因此打赏，谢谢。

### AppStore

<a href="https://apps.apple.com/cn/app/%E4%BB%93%E8%BE%93%E5%85%A5%E6%B3%95/id6446617683?itscg=30200&itsct=apps_box_appicon" style="width: 170px; height: 170px; border-radius: 22%; overflow: hidden; display: inline-block; vertical-align: middle;"><img src="https://is4-ssl.mzstatic.com/image/thumb/Purple126/v4/16/b3/b8/16b3b836-12aa-206a-f849-79e37bf6528c/AppIcon-0-1x_U007emarketing-0-10-0-85-220.png/540x540bb.jpg" alt="仓输入法" style="width: 170px; height: 170px; border-radius: 22%; overflow: hidden; display: inline-block; vertical-align: middle;"></a>

<a href="https://apps.apple.com/cn/app/%E4%BB%93%E8%BE%93%E5%85%A5%E6%B3%95/id6446617683?itsct=apps_box_badge&itscg=30200" style="display: inline-block; overflow: hidden; border-radius: 13px; width: 250px; height: 83px;"><img src="https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us?size=250x83&releaseDate=1680912000" alt="Download on the App Store" style="border-radius: 13px; width: 250px; height: 83px;"></a>
