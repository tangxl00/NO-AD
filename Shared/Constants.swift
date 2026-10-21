//
//  Constants.swift
//  AdShield
//
//  Shared constants across main app and extension.
//

import Foundation

/// App Group identifier for shared container between main app and extension.
/// Replace YOUR_APP_GROUP_ID with your actual App Group identifier.
public enum AppGroup {
    public static let identifier = "group.com.YOUR_ORG.AdShield"
}

/// Darwin notification names for inter-process communication.
public enum IPCNotification {
    /// Posted by main app when whitelist changes.
    public static let whitelistChanged = "com.YOUR_ORG.AdShield.whitelist.changed"
}

/// File names used in App Group shared container.
public enum SharedFileNames {
    public static let rulesDirectory = "Library/Rules"
    public static let whitelistDirectory = "Library/Whitelist"
    public static let feedbackDirectory = "Library/Feedback"
    public static let logsDirectory = "Library/Logs"
    public static let configDirectory = "Library/Config"
    
    public static let bloomFilterFile = "rules.bloomfilter"
    public static let hashSetFile = "rules.hashset"
    public static let whitelistFile = "whitelist.json"
    public static let whitelistVersionFile = "whitelist.version"
    public static let whitelistChecksumFile = "whitelist.checksum"
    public static let whitelistReloadStatusFile = "whitelist.reload_status"
    public static let whitelistBackupDirectory = "backup"
    
    public static let configFile = "config.json"
    public static let statsFile = "stats.json"
}

/// Default anti-AD rule source.
public enum RuleSourceDefaults {
    /// 主源：anti-AD 官方域名（国内项目，但经 Cloudflare/GitHub Pages 后端分发，
    /// 部分国内网络环境可能超时）。
    public static let domainsURL = "https://anti-ad.net/domains.txt"
    /// 备用源：主源失败时按序依次尝试，全部失败才报错。
    /// 1. jsDelivr CDN 镜像（官方 GitHub 仓库 @master 分支）
    /// 2. GitHub raw（国内直连经常不可达，作为最后兜底）
    public static let fallbackDomainsURLs: [String] = [
        "https://cdn.jsdelivr.net/gh/privacy-protection-tools/anti-AD@master/anti-ad-domains.txt",
        "https://raw.githubusercontent.com/privacy-protection-tools/anti-AD/master/anti-ad-domains.txt"
    ]
    public static let name = "anti-AD"
    public static let updateIntervalHours: Int = 24
}

/// Bloom Filter parameters (tuned for ~120k domains, 0.1% false positive rate).
public enum BloomFilterConfig {
    /// Expected number of elements (with 10% headroom).
    public static let expectedElements: UInt = 120_000
    /// Target false positive rate.
    public static let falsePositiveRate: Double = 0.001
    /// Derived bit array size in bits (~1.7 Mbit ≈ 220 KB).
    public static var bitArraySize: UInt {
        UInt(Double(expectedElements) * log(1.0 / falsePositiveRate) / log(2.0))
    }
    /// Number of hash functions (k ≈ 10).
    public static var hashCount: UInt {
        UInt((Double(bitArraySize) / Double(expectedElements)) * log(2.0))
    }
}

/// UserDefaults keys (stored in shared UserDefaults via App Group).
public enum UserDefaultsKeys {
    public static let dnsProxyEnabled = "dnsProxyEnabled"
    public static let autoUpdateRules = "autoUpdateRules"
    public static let lastRuleUpdateTime = "lastRuleUpdateTime"
    public static let ruleVersion = "ruleVersion"
    public static let ruleEntryCount = "ruleEntryCount"
    public static let onboardingCompleted = "onboardingCompleted"
    public static let totalBlockedCount = "totalBlockedCount"
}

/// Bundle identifiers (replace placeholders with actual values).
public enum BundleIdentifiers {
    public static let app = "com.YOUR_ORG.AdShield"
    public static let extensionTarget = "com.YOUR_ORG.AdShield.DNSProxy"
}
