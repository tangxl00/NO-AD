# AdShield Build Guide

> **Environment Note:** This guide assumes you are building on **macOS with Xcode 14+** installed. The Linux sandbox used for code generation cannot compile iOS apps.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Apple Developer Account Setup](#2-apple-developer-account-setup)
3. [App ID & App Group Configuration](#3-app-id--app-group-configuration)
4. [DNS Proxy Entitlement](#4-dns-proxy-entitlement)
5. [Certificates & Provisioning Profiles](#5-certificates--provisioning-profiles)
6. [Project Configuration](#6-project-configuration)
7. [Build & Install](#7-build--install)
8. [Free Developer Account Limitations](#8-free-developer-account-limitations)
9. [Troubleshooting](#9-troubleshooting)
10. [NEDNSSettingsManager Fallback](#10-nednssettingsmanager-fallback)

---

## 1. Prerequisites

- macOS 12+ (Monterey or later)
- Xcode 14.0+ (download from Mac App Store or [Apple Developer](https://developer.apple.com/download/))
- An Apple Developer account (free or paid)
- An iPhone running iOS 15+ (Simulator cannot test Network Extensions)

---

## 2. Apple Developer Account Setup

### Free Account (Personal)

1. Go to [developer.apple.com](https://developer.apple.com/)
2. Sign in with your Apple ID
3. Accept the developer agreement
4. No payment required for development/sideloading

### Paid Account ($99/year)

Required for:
- App Store distribution
- TestFlight
- Custom enterprise distribution
- Access to certain entitlements (some Network Extension capabilities)

**Recommendation:** Start with a free account for local testing. Upgrade to paid when ready for App Store submission.

---

## 3. App ID & App Group Configuration

### Step 3.1: Register App ID

1. Go to [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list)
2. Click the **+** button to add a new identifier
3. Select **App IDs**, then **App**
4. Configure:
   - **Description:** AdShield
   - **Bundle ID:** `com.YOUR_ORG.AdShield` (replace `YOUR_ORG` with your reverse-domain)
   - **Capabilities:** Check:
     - App Groups
     - Network Extensions

5. Click **Continue**, then **Register**

### Step 3.2: Register Extension App ID

Repeat for the extension:
- **Bundle ID:** `com.YOUR_ORG.AdShield.DNSProxy`
- **Capabilities:** Check:
  - App Groups
  - Network Extensions

### Step 3.3: Register App Group

1. In the same page, click **+** > **App Groups**
2. Set **Identifier:** `group.com.YOUR_ORG.AdShield`
3. Set **Description:** AdShield Shared Container
4. Click **Continue**, then **Register**

### Step 3.4: Link App Group to App IDs

1. Edit your main App ID
2. Under **App Groups**, click **Configure**
3. Select `group.com.YOUR_ORG.AdShield`
4. Save
5. Repeat for the Extension App ID

---

## 4. DNS Proxy Entitlement

The DNS proxy capability uses the `com.apple.developer.networking.networkextension` entitlement with the `dns-proxy` value. **As of 2026, enabling `dns-proxy` no longer requires a separate approval request form** — it is a standard capability you toggle on in the Apple Developer portal, gated by a **paid Apple Developer Program membership** (free accounts cannot enable Network Extensions capabilities).

> **Correction (2026-10):** An earlier revision of this guide described a request-form approval flow for `dns-proxy`. That was inaccurate. The request forms only apply to *other* special entitlement values, e.g. `app-push-provider` ([Local Push request form](https://developer.apple.com/contact/request/local-push-connectivity)), HotspotHelper, and Family Controls distribution. See Apple Developer Forums reports confirming Network Extension values are now self-serve.

### How to Enable

1. Join the **paid Apple Developer Program** ($99/year) at [developer.apple.com/programs](https://developer.apple.com/programs/)
2. Go to [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list)
3. Open your App ID (the extension App ID too — repeat these steps for both)
4. Under **Capabilities**, find **Network Extensions**, click **Configure**
5. Check **DNS Proxy** (dns-proxy)
6. Save, then **regenerate and re-download** the provisioning profiles for both App IDs
7. In Xcode, confirm both targets show *Network Extensions → DNS Proxy* under Signing & Capabilities

The resulting entitlement in both `.entitlements` files is:

```xml
<key>com.apple.developer.networking.networkextension</key>
<array>
    <string>dns-proxy</string>
</array>
```

### If the Checkbox Is Unavailable

A small number of accounts report the Network Extensions capability not being selectable in the portal. In that case:

- Submit a request via the general entitlement channel: [developer.apple.com/contact/request/entitlement-migration-requests/](https://developer.apple.com/contact/request/entitlement-migration-requests/) or open a support case at [developer.apple.com/contact](https://developer.apple.com/contact/)
- Community reports indicate review turnaround of roughly **2–6 weeks** with no guaranteed timeline

### Critical Deployment Restriction (read before building)

Per Apple's [TN3134](https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment) (rev. 2025-08-19), on **iOS** the DNS proxy app extension only functions on:

| iOS version | Requirement |
|-------------|-------------|
| iOS 11 – 15 | **Supervised devices only** |
| iOS 16+ | **Per-app on MDM-managed devices** |

In practice this means a consumer App Store ad-blocker **cannot rely on NEDNSProxyProvider on ordinary user devices** — this is why mainstream apps (AdGuard, NextDNS, Cloudflare 1.1.1.1) ship DNS filtering via `NEDNSSettingsManager` or a VPN profile instead. For development/testing on your own supervised device, or for MDM/enterprise distribution, the DNS proxy path works.

**Recommendation:** treat the `NEDNSSettingsManager` fallback (Section 10) as the primary consumer-distribution path, and keep the DNS proxy path for supervised/MDM scenarios.

---

## 5. Certificates & Provisioning Profiles

### Step 5.1: Create Certificate

1. In **Certificates, Identifiers & Profiles**, click **Certificates** > **+**
2. Select **Apple Development**
3. Follow instructions to create a Certificate Signing Request (CSR) via Keychain Access
4. Upload the CSR, then download the certificate
5. Double-click the `.cer` file to install in Keychain Access

### Step 5.2: Create Provisioning Profiles

You need **two** provisioning profiles:

#### Profile 1: Main App

1. Click **Profiles** > **+**
2. Select **iOS App Development**
3. Select your main App ID (`com.YOUR_ORG.AdShield`)
4. Select your certificate
5. Select your device(s)
6. Name it: `AdShield Development`
7. Download and double-click to install

#### Profile 2: Extension

1. Click **Profiles** > **+**
2. Select **iOS App Development**
3. Select your extension App ID (`com.YOUR_ORG.AdShield.DNSProxy`)
4. Select your certificate
5. Select your device(s)
6. Name it: `AdShield DNSProxy Development`
7. Download and double-click to install

---

## 6. Project Configuration

Before building, update all placeholder values in the project:

### 6.1 Update Bundle Identifiers

Open `AdShield.xcodeproj` in Xcode and update:

| Target | Setting | Value |
|--------|---------|-------|
| AdShield | Bundle Identifier | `com.YOUR_ORG.AdShield` |
| AdShieldExtension | Bundle Identifier | `com.YOUR_ORG.AdShield.DNSProxy` |

### 6.2 Update App Group

Search and replace `group.com.YOUR_ORG.AdShield` with your actual App Group ID in:

- `Shared/Constants.swift` → `AppGroup.identifier`
- `AdShield/AdShield.entitlements`
- `AdShieldExtension/AdShieldExtension.entitlements`

### 6.3 Update Team ID

In Xcode:
1. Select the project in the navigator
2. Select **AdShield** target
3. Go to **Signing & Capabilities**
4. Select your **Team**
5. Repeat for **AdShieldExtension** target

### 6.4 Update entitlements bundle identifiers

In both `.entitlements` files, update:
- `group.com.YOUR_ORG.AdShield` → your actual App Group

---

## 7. Build & Install

### Option A: Xcode Direct Build (Recommended for Development)

1. Open `AdShield.xcodeproj` in Xcode
2. Select your iPhone as the target device
3. Press **Cmd+R** to build and run
4. Xcode will automatically sign and install

### Option B: Build IPA Script (Signed)

```bash
# Navigate to project root
cd /path/to/AdShield

# Configure environment variables
export TEAM_ID="YOUR_ACTUAL_TEAM_ID"
export PROVISIONING_PROFILE_APP="AdShield Development"
export PROVISIONING_PROFILE_EXT="AdShield DNSProxy Development"
export CERTIFICATE_NAME="Apple Development: Your Name (TEAM_ID)"

# Run build script
chmod +x scripts/build-ipa.sh
./scripts/build-ipa.sh release
```

The IPA will be at `build/exported/AdShield.ipa`.

### Option C: AltStore / SideStore (Sideloading)

For free developer accounts, use AltStore to sideload:

1. Install [AltStore](https://altstore.io/) on your Mac and iPhone
2. Build the signed IPA using the script above
3. Open AltServer on Mac, connect iPhone via USB
4. In AltStore on iPhone, tap **+** and select the IPA
5. The app installs with 7-day re-signing handled by AltStore

### Option D: TestFlight (Paid Account Required)

1. Build the signed IPA
2. Use **Transporter** app (from Mac App Store) to upload
3. Or use `xcrun altool` command:
   ```bash
   xcrun altool --upload-app --type ios --file build/exported/AdShield.ipa --apiKey YOUR_API_KEY --apiIssuer YOUR_ISSUER_ID
   ```

### Option E: TrollStore — No Developer Account Needed (Recommended for Personal Use)

This is the **simplest path** if your device supports TrollStore. You do **not** need an Apple Developer account, certificates, or provisioning profiles.

**Prerequisites:**
- iOS device running a TrollStore-compatible version (see [TrollStore official repo](https://github.com/opa334/TrollStore) for supported versions)
- TrollStore installed on the device

**Build methods:**

#### E.1 GitHub Actions 云端构建（推荐，无需 macOS）

1. Fork 或新建 GitHub Public 仓库，上传本项目全部文件
2. 进入仓库 **Actions** 页面
3. 选择 **Build AdShield IPA (TrollStore / Unsigned)** 工作流
4. 点击 **Run workflow**
5. 等待约 5–10 分钟，下载产出的 `AdShield-IPA-Unsigned` Artifact

> 详细图文步骤参见项目根目录 `README.md` 的「3 步获取 IPA」章节。

#### E.2 本地 macOS 构建

```bash
cd /path/to/AdShield
chmod +x scripts/build-trollstore-ipa.sh
./scripts/build-trollstore-ipa.sh release
```

产出的 `build/AdShield-unsigned.ipa` 即为未签名 IPA。

**安装步骤：**

1. 将 IPA 文件传输到 iPhone（AirDrop、文件共享、或网盘下载）
2. 在 iPhone 上打开 **TrollStore** App
3. 点击右下角 **+** 按钮
4. 选择 `AdShield-unsigned.ipa`
5. 等待安装完成
6. 进入 TrollStore 的 **Settings** 标签，点击 **Rebuild Icon Cache**
7. 返回主屏幕，AdShield 图标会出现

**为什么免签名 IPA 可以工作？**

TrollStore 利用 iOS CoreTrust 漏洞，允许安装使用**任意证书**（包括自签名、伪造签名、甚至无签名）的 IPA。安装时，TrollStore 会：
1. 将 App 注册到系统
2. 自动处理签名验证绕过
3. **保留原始 entitlements**（包括 App Group 和 Network Extensions）

这意味着 AdShield 的 `dns-proxy` entitlement 和 App Group 配置在 TrollStore 安装后仍然有效，Extension 可以正常启动。

**已知限制：**
- TrollStore 仅支持特定 iOS 版本，不支持的设备需改用 Option B/C/D
- 系统重启后 App 仍然保留，无需像免费签名那样每 7 天重签
- 部分 OTA 系统更新可能导致 TrollStore 失效，更新前请查看社区兼容性报告

---

## 8. Free Developer Account Limitations

| Limitation | Details |
|------------|---------|
| **Certificate expiry** | 7 days — app stops launching after 7 days and must be re-signed |
| **Device limit** | Max 3 apps sideloaded simultaneously via free provisioning |
| **Push Notifications** | Not available |
| **App Store** | Cannot submit to App Store |
| **TestFlight** | Not available |
| **Entitlements** | Some entitlements (like certain Network Extensions) may not auto-provision |

**Workaround for 7-day limit:** Use TrollStore (Option E) or AltStore, which automates re-signing on-device via Wi-Fi sync.

---

## 9. Troubleshooting

### "No account for team YOUR_TEAM_ID"

- Ensure you're signed into Xcode with the correct Apple ID
- Xcode > Preferences > Accounts > Add your Apple ID

### "Provisioning profile doesn't include the dns-proxy entitlement"

- Regenerate the profile *after* enabling Network Extensions → DNS Proxy on the App ID (Section 4); profiles generated before the capability was added won't contain it
- Confirm you use a **paid** Apple Developer Program account — free accounts cannot enable Network Extensions
- If the capability is missing entirely from the portal, see Section 4 "If the Checkbox Is Unavailable"

### "App Group not found"

- Verify the App Group identifier in the entitlements file matches exactly what you registered
- Check that both the app and extension targets have the App Group capability enabled

### "Extension not appearing in system settings"

- Network Extensions require a physical device (not Simulator)
- Ensure the extension target is embedded in the app target (Build Phases > Embed App Extensions)
- Try Settings > General > VPN & Device Management > DNS to manually enable

### Build script fails with "archive failed"

- Check `build/archive.log` for specific errors
- Ensure all placeholders in the script are replaced
- Verify your signing certificate and provisioning profiles are valid

### GitHub Actions build fails with "Scheme AdShield not found"

- 确认 `AdShield.xcodeproj/xcshareddata/xcschemes/AdShield.xcscheme` 已提交到仓库
- 若缺失，在本地 macOS 上用 Xcode 打开工程，选择 Product → Scheme → Manage Schemes，勾选 **Shared**，然后重新提交

---

## 10. NEDNSSettingsManager Fallback

If you target ordinary (non-supervised) consumer devices — where the DNS proxy extension cannot function per TN3134 — build with the `NEDNSSettingsManager` path instead. This does **not** require a paid-program capability beyond the standard `dns-settings` value.

### Key Differences

| Feature | DNS Proxy Provider | NEDNSSettingsManager |
|---------|-------------------|---------------------|
| Local filtering | Yes (Bloom Filter) | No (relies on remote DNS) |
| Entitlement | `dns-proxy` (paid program capability) | `dns-settings` (Xcode checkbox) |
| Works on ordinary user devices | **No** (supervised/MDM only per TN3134) | Yes |
| Interception point | All DNS traffic | System DNS configuration |
| Custom rules | Full support | Limited (depends on DNS service) |
| App Store approval | Medium risk | Low risk (many precedents) |

> Recommendation: use DNS Proxy for supervised/MDM scenarios; use NEDNSSettingsManager as the primary consumer path (see Section 4).

### To Use the Fallback

The project includes a build-time flag. To switch:

1. In Xcode, go to **Build Settings** for both targets
2. Add a custom flag: `SWIFT_ACTIVE_COMPILATION_CONDITIONS = NEDNSSETTINGS_FALLBACK`
3. Update `DNSProxyManager.swift` to use `NEDNSSettingsManager` instead of `NEDNSProxyProvider`

A full fallback implementation is beyond MVP scope but the architecture is designed to support this switch with minimal UI changes.

---

## Quick Reference: File Checklist Before Build

- [ ] `Shared/Constants.swift` — App Group ID updated
- [ ] `AdShield/AdShield.entitlements` — App Group ID + Team ID updated
- [ ] `AdShieldExtension/AdShieldExtension.entitlements` — App Group ID + Team ID updated
- [ ] Xcode project — Bundle identifiers updated for both targets
- [ ] Xcode project — Team selected in Signing & Capabilities
- [ ] Apple Developer Portal — App IDs registered with correct capabilities
- [ ] Apple Developer Portal — App Group registered and linked
- [ ] Apple Developer Portal — Provisioning profiles created and downloaded
- [ ] Keychain Access — Development certificate installed
- [ ] iPhone — Connected and trusted
