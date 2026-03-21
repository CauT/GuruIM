# Hamster iOS 工程编译指南

## 项目背景

Hamster 是基于 RIME 的 iOS 输入法，依赖一批预编译 xcframework（librime、libglog、libleveldb 等）。
这些库来自 LibrimeKit，原始仓库已不可访问（404）。当前使用的是 simulator-only 构建，
通过二进制补丁将 platform 标志统一为 iOS Simulator（platform=7）。

---

## 预编译二进制处理原则

### 原则 1：先扫描，再操作

拿到任何预编译 `.a` / xcframework，第一步是用工具建立基线，不要靠猜测：

```bash
# 检查所有 .a 文件的 Mach-O platform 标志
for f in Frameworks/**/*.a; do
  echo "=== $f ==="
  otool -l "$f" | grep -A4 "LC_BUILD_VERSION\|LC_VERSION_MIN"
done

# 检查实际导出符号（用于和头文件对照）
nm path/to/lib.a | grep "符号关键词"
```

**不要**：看到链接报错才去查。**要**：编译前一次性扫描所有库。

### 原则 2：头文件版本必须与库版本严格对应

预编译库的头文件与库本身可能版本不一致，用新头文件套在旧库上会导致结构体越界访问。

检查方法：
```bash
# 确认库实际提供了头文件声明的函数
nm lib.a | grep "期望的函数名"
```

如果某个函数在头文件里有声明但 `nm` 找不到，说明版本不匹配。使用 `data_size`（RIME API 的版本控制字段）或 NULL 检查做运行时守卫：

```objc
// RIME API 版本守卫示例
RimeApi* api = rime_get_api();
ptrdiff_t offset = (char*)&api->newer_field - (char*)&api->data_size;
if (offset < api->data_size && api->newer_field) {
    // 安全调用新 API
} else {
    // 回退到旧 API
}
```

### 原则 3：平台标志不匹配要一次性修全

多个库 platform 标志不一致时，用脚本一次性扫描并批量修复，不要等链接报错再逐个处理：

```bash
# 扫描所有库的 platform（2=iOS device, 7=iOS Simulator）
python3 -c "
import glob, struct
for path in glob.glob('Frameworks/**/*.a', recursive=True):
    with open(path, 'rb') as f:
        data = f.read()
    # 查找 LC_BUILD_VERSION (0x32) 的 platform 字段
    ...
"
```

---

## 链接兼容性原则

### 原则 4：符号名不匹配优先用链接器 -alias，不要写汇编 trampoline

C++ 符号因 API 版本差异（如参数类型从 `int` 变为具名 enum）导致 mangled name 不同时，
正确做法是链接器 `-alias` flag，而不是汇编 trampoline。

**原因**：ARM64 `b` 指令只能跳转 ±128MB，SPM 静态链接不做重定位，
超出范围时 branch target 变成垃圾地址，导致 `EXC_BAD_ACCESS PC alignment` crash。

```
# 在 Xcode project.pbxproj 的 OTHER_LDFLAGS 中添加：
# -alias <库中实际存在的符号> <调用方期望的符号>
-Xlinker -alias -Xlinker __ZN6google10LogMessageC1EPKciNS_11LogSeverityE \
-Xlinker __ZN6google10LogMessageC1EPKcii
```

验证 alias 是否生效：
```bash
nm path/to/binary | grep "期望的符号"
# 两个符号应指向同一地址
```

### 原则 5：链接 flag 要同时加到所有使用该库的 target

同一个库被多个 target 链接时（如主 app + keyboard extension），
链接 flag 需要同时加到所有 target 的 build configuration（Debug + Release），不能遗漏。

---

## 调试崩溃原则

### 原则 6：EXC_BAD_ACCESS PC alignment crash 的排查路径

PC 地址非 4 字节对齐（如 `0xb880e2`）时，这是跳转到了无效地址：

1. 检查崩溃报告的 `usedImages`，找 PC 所属 image（base=0 说明是绝对地址，不在任何合法 image 中）
2. 检查调用栈，找到发起跳转的函数
3. 用 `nm` 确认该函数内引用的所有符号是否都已正确 resolve
4. 检查是否有函数指针从结构体越界位置读取（struct 版本不匹配）

### 原则 7：利用 DiagnosticReports 分析 extension crash

keyboard extension 崩溃时 Xcode console 无输出，崩溃日志在：

```
~/Library/Logs/DiagnosticReports/HamsterKeyboard-*.ips
```

解析方式：
```bash
python3 -c "
import json
with open('crash.ips') as f:
    content = f.read()
idx = content.index('\n{')
body = json.loads(content[idx:])
crashed = next(t for t in body['threads'] if t.get('triggered'))
print('PC:', hex(crashed['threadState']['pc']['value']))
for f in crashed['frames'][:10]:
    print(f)
"
```

---

## 当前工程状态

- **构建目标**：iOS Simulator only（arm64）
- **DEVELOPMENT_TEAM**：`2E5A2Y6BLT`（付费开发者账号）
- **Bundle ID 前缀**：`com.donglingyong.Hamster`
- **App Group**：`group.com.donglingyong.Hamster`
- **xcframework platform**：全部已补丁为 iOS Simulator（platform=7）
- **glog 兼容**：通过 `-alias` linker flag 桥接新旧 API 符号差异
- **SbxlmKeyboard**：已从 build scheme 中移除（librime-sbxlm 兼容问题未解决）
