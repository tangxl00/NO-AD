# AdShield

iOS DNS 层广告屏蔽应用，基于 NetworkExtension DNS Proxy Provider + Bloom Filter 实现高效、轻量的本地广告拦截。

> **重要说明：** 本项目在 Linux 沙箱环境中完成源码编写，**未在 macOS / Xcode 环境中编译验证**。请在 macOS 上使用 Xcode 14+ 打开并构建。

---

## 快速开始（GitHub Actions 云端编译）

无需 macOS 电脑，无需 Apple Developer 账号，3 步即可获得可安装的 IPA 文件。

### 环境要求

- 一个 **GitHub 账号**（免费即可）
- 一部已安装 **TrollStore** 的 iOS 设备（iOS 15.0+）

### 3 步获取 IPA

#### ① 在 GitHub 新建 Public 仓库

1. 登录 [github.com](https://github.com)，点击右上角 **+** → **New repository**
2. 仓库名称填写 `AdShield`（或其他你喜欢的名字）
3. **Visibility 选择 Public**（Public 仓库可使用免费的 GitHub Actions macOS runner）
4. 点击 **Create repository**

#### ② 上传本项目全部文件

在仓库页面，点击 **Add file** → **Upload files**，然后将本压缩包解压后的全部文件拖入上传区域，点击 **Commit changes**。

> 或者使用命令行推送：
> ```bash
> git clone <你的仓库地址>
> # 将本包全部文件复制到仓库目录
> git add .
> git commit -m "Initial commit"
> git push origin main
> ```

#### ③ 触发构建并下载 IPA

1. 进入仓库页面，点击顶部 **Actions** 标签
2. 在左侧选择 **Build AdShield IPA (TrollStore / Unsigned)** 工作流
3. 点击右侧 **Run workflow** → 选择分支 `main` → 再次点击 **Run workflow**
4. 等待构建完成（约 5–10 分钟），页面下方会出现一个 **Artifacts** 区域
5. 点击 **AdShield-IPA-Unsigned** 即可下载 IPA 文件

下载完成后，通过 TrollStore 安装到设备即可使用。

---

## 功能特性

- **DNS 层拦截**：通过 NEDNSProxyProvider 拦截 DNS 查询，在域名解析阶段阻断广告请求
- **Bloom Filter 规则引擎**：基于概率数据结构，~220KB 内存即可承载 12 万条规则，查询复杂度 O(k)
- **anti-AD 规则源**：自动下载并编译 https://anti-ad.net/domains.txt，支持增量更新
- **白名单热更新**：主 App 原子化写入 App Group 共享存储 → darwin_notify 通知 → Extension 端双缓冲区原子切换，全程不中断 DNS 服务
- **误杀反馈**：完整的 9 字段反馈数据模型 + 4 状态状态机，支持本地管理与规则源上报
- **拦截统计**：本地持久化统计（今日拦截数、总拦截数、Top 域名等），隐私优先不上传
- **首次开通引导**：帮助用户完成系统级 DNS Proxy 授权与启用

## 工程结构

```
AdShield/
├── AdShield.xcodeproj/          # Xcode 工程（含共享 Scheme）
├── AdShield/                     # 主 App Target（SwiftUI，iOS 15+）
│   ├── AdShieldApp.swift         # App 入口
│   ├── ContentView.swift         # 根视图 / Tab 导航
│   ├── Views/
│   │   ├── Dashboard/            # 仪表盘（开关、统计）
│   │   ├── Rules/                # 规则管理（源、刷新、更新时间）
│   │   ├── Whitelist/            # 白名单管理
│   │   ├── Logs/                 # 拦截记录与统计
│   │   ├── Feedback/             # 误杀反馈历史
│   │   ├── Onboarding/           # 首次开通引导
│   │   └── ShakeGuide/           # 摇一摇说明页
│   ├── Services/
│   │   ├── DNSProxyManager.swift # NEDNSProxyManager 封装
│   │   ├── RuleDownloader.swift  # anti-AD 规则下载器
│   │   ├── RuleCompiler.swift    # 规则编译（→ Bloom Filter）
│   │   ├── WhitelistManager.swift# 白名单 CRUD + 原子写入
│   │   ├── FeedbackStore.swift   # 反馈数据本地存储
│   │   └── BlockingLogStore.swift# 拦截记录本地存储
│   ├── Models/
│   │   ├── FeedbackItem.swift    # 反馈数据模型
│   │   ├── WhitelistItem.swift   # 白名单数据模型
│   │   ├── BlockingLog.swift     # 拦截记录模型
│   │   └── RuleSource.swift      # 规则源模型
│   ├── Resources/
│   │   ├── Info.plist
│   │   └── Assets.xcassets/      # （运行时创建）
│   └── AdShield.entitlements     # App Entitlements（含 App Group）
├── AdShieldExtension/            # DNS Proxy Extension Target
│   ├── DNSProxyProvider.swift    # NEDNSProxyProvider 实现
│   ├── Engine/
│   │   ├── FilterEngine.swift    # 过滤引擎（4 级优先级）
│   │   ├── WhitelistListener.swift # 白名单变更监听（3 级通知）
│   │   ├── DNSParser.swift       # DNS 报文解析器
│   │   └── UpstreamForwarder.swift # 上游 DNS 转发
│   ├── Info.plist
│   └── AdShieldExtension.entitlements # Extension Entitlements
├── Shared/                       # 主 App + Extension 共享代码
│   ├── BloomFilter.swift         # Bloom Filter 核心实现
│   ├── Constants.swift           # 常量、配置参数
│   └── AppGroupPaths.swift       # App Group 路径管理
├── scripts/
│   ├── build-ipa.sh              # 签名 IPA 构建脚本（需开发者账号）
│   └── build-trollstore-ipa.sh   # 免签名 IPA 构建脚本（本地使用）
├── docs/
│   └── BUILD.md                  # 详细构建与安装指南
├── .github/workflows/
│   ├── build-trollstore.yml      # 默认：免签名巨魔构建（自动触发）
│   └── build-signed.yml          # 可选：签名构建（需配置 Secrets）
├── README.md                     # 本文件
└── .gitignore
```

## CI / 自动化构建

本项目包含两个 GitHub Actions 工作流：

| 工作流 | 触发方式 | 用途 | 需 Secrets |
|--------|---------|------|-----------|
| `build-trollstore.yml` | push / PR / 手动 | **默认**。免签名构建，产出可直接用 TrollStore 安装的 IPA | 否 |
| `build-signed.yml` | 手动（workflow_dispatch） | 可选。使用 Apple Developer 证书签名 | 是（见下表） |

### 签名构建所需的 Secrets（仅当你需要签名版时）

| Secret | 说明 |
|--------|------|
| `TEAM_ID` | Apple Developer Team ID |
| `DEVELOPMENT_CERTIFICATE_BASE64` | 开发证书（Base64 编码的 .p12） |
| `CERTIFICATE_PASSWORD` | 证书密码 |
| `APP_PROVISIONING_PROFILE_BASE64` | App Provisioning Profile（Base64） |
| `EXTENSION_PROVISIONING_PROFILE_BASE64` | Extension Provisioning Profile（Base64） |
| `CERTIFICATE_NAME` | 证书完整名称 |
| `BUNDLE_ID` | Bundle ID（默认 `com.YOUR_ORG.AdShield`） |
| `PROVISIONING_PROFILE_APP` | App Provisioning Profile 名称 |
| `PROVISIONING_PROFILE_EXT` | Extension Provisioning Profile 名称 |

在仓库 **Settings → Secrets and variables → Actions → New repository secret** 中配置。

## 常见问题（GitHub Actions 构建）

### Q: Public 仓库的 macOS runner 有免费额度吗？

有。GitHub Free 账号的 Public 仓库享有**无限制**的 GitHub Actions 使用时长（含 macOS runner）。Private 仓库每月有 2,000 分钟限额（macOS 按 10 倍计费，即 200 分钟 macOS 时长）。

**建议：使用 Public 仓库构建。**

### Q: 构建一次大概需要多长时间？

首次构建（无缓存）约 **8–15 分钟**，主要耗时在：
- macOS runner 启动与初始化（1–2 分钟）
- Xcode 依赖解析与编译（5–10 分钟）
- Archive 与 IPA 打包（1–2 分钟）

后续构建若代码无大变更，Xcode 增量编译会更快。

### Q: 构建产物（Artifact）能保存多久？

默认保存 **90 天**（本 workflow 已设置 `retention-days: 90`）。90 天后 Artifact 自动删除，如需长期保留建议下载到本地或 Release 中附加。

### Q: 下载的 IPA 如何安装到手机？

**TrollStore 用户（推荐）：**
1. 将 IPA 传输到 iPhone（AirDrop、iTunes 文件共享、或上传到网盘后下载）
2. 打开 TrollStore App
3. 点击右下角 **+** 号，选择 IPA 文件
4. 安装完成后，在 TrollStore 的 **Settings** 中点击 **Rebuild Icon Cache**

> 详细图文步骤见 [`docs/BUILD.md`](docs/BUILD.md) 第 7 节 Option E。

**非 TrollStore 用户：**
- 需要使用 `build-signed.yml`  workflow 生成签名版 IPA，然后通过 AltStore / SideStore / Apple Configurator 安装
- 或自行在 macOS 上使用 Xcode 直接构建运行

### Q: 为什么免签名 IPA 不能通过 AltStore 安装？

AltStore / SideStore 等侧载工具依赖标准的 iOS 签名机制，只能安装**已签名**的 IPA。TrollStore 利用 CoreTrust 漏洞（iOS 15.0–16.6.1 / 17.0）允许安装**任意签名或未签名**的 IPA，并自行处理签名与 entitlements。因此免签名 IPA 仅限 TrollStore 环境使用。

### Q: 构建失败了怎么办？

1. 进入 Actions 页面，点击失败的工作流运行记录
2. 查看具体失败的 Step 的日志输出
3. 常见原因：
   - **Archive 失败**：检查是否修改了项目文件导致编译错误
   - **Scheme 未找到**：确保 `AdShield.xcodeproj/xcshareddata/xcschemes/AdShield.xcscheme` 已提交到仓库
   - **Extension 未嵌入**：检查 `project.pbxproj` 中 Embed App Extensions build phase 是否完整

如果日志无法定位问题，可下载 **build-logs** Artifact 查看完整编译日志。

## 本地开发构建

如果你有 macOS + Xcode 环境，可直接本地构建：

```bash
# 免签名本地构建（TrollStore）
./scripts/build-trollstore-ipa.sh release

# 签名本地构建（需配置证书）
export TEAM_ID="YOUR_TEAM_ID"
export PROVISIONING_PROFILE_APP="..."
export PROVISIONING_PROFILE_EXT="..."
export CERTIFICATE_NAME="..."
./scripts/build-ipa.sh release
```

完整本地构建指南请参见 [`docs/BUILD.md`](docs/BUILD.md)。

## 技术架构要点

### Bloom Filter 参数

| 参数 | 值 | 说明 |
|------|------|------|
| 预期元素数 n | 120,000 | anti-AD 规则量 + 10% 余量 |
| 误判率 p | 0.001 | 千分之一 |
| 哈希函数数 k | ~10 | 双哈希派生 |
| 位数组大小 m | ~1.7 Mbit | 约 220 KB |

### 过滤优先级（从高到低）

1. **白名单**（用户自定义 + 内置）—— 最高优先级放行
2. **用户黑名单**—— 自定义拦截
3. **Bloom Filter 初筛**—— 快速排除大部分非广告域名
4. **Hash Set 确认**—— 对 Bloom Filter 命中进行二次精确确认，消除误判

## DNS Proxy Entitlement 说明

本项目使用 `com.apple.developer.networking.networkextension` entitlement（值为 `dns-proxy`）。

- **TrollStore 安装**：无需 Apple Developer 账号，TrollStore 安装时会自行注入并处理 entitlements
- **标准签名安装**：需要付费 Apple Developer Program（$99/年）并在开发者后台启用 Network Extensions → DNS Proxy

**关键部署限制：** iOS 上 DNS Proxy 扩展仅在受监管（supervised）设备或 MDM 管理设备上可用。面向普通消费者的场景，请参见 [`docs/BUILD.md`](docs/BUILD.md) 第 10 节 `NEDNSSettingsManager` 降级路径。

## 已知限制

- DNS Proxy 无法在 iOS 模拟器中运行，必须使用真机测试
- 部分网络环境（企业 VPN、部分运营商 DNS 劫持）可能与 DNS Proxy 冲突
- TrollStore 仅支持特定 iOS 版本范围（详见 TrollStore 官方文档）

## 许可证

本项目源码仅供学习与技术研究使用。anti-AD 规则版权归规则维护者所有。
