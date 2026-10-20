//
//  FeedbackItem.swift
//  AdShield
//
//  False-positive feedback data model with 9 fields and 4-state lifecycle.
//

import Foundation

/// Status lifecycle for a false-positive feedback item.
public enum FeedbackStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case whitelisted = "whitelisted"
    case ignored = "ignored"
    case reportedUpstream = "reported_upstream"
    case resolved = "resolved"
}

/// Reason category for false-positive classification.
public enum FeedbackReasonCategory: String, Codable, CaseIterable {
    case normalWebsite = "normal_website"
    case appFunctionBroken = "app_function_broken"
    case paymentBanking = "payment_banking"
    case other = "other"
}

/// Source of the feedback submission.
public enum FeedbackSource: String, Codable, CaseIterable {
    case autoFromLog = "auto_from_log"
    case manualSubmit = "manual_submit"
}

/// A single false-positive feedback record.
public struct FeedbackItem: Codable, Identifiable, Equatable {
    
    // MARK: - 9 Required Fields
    
    /// 1. Unique identifier (UUID, locally generated).
    public let id: UUID
    
    /// 2. Domain that was falsely blocked (normalized lowercase).
    public let domain: String
    
    /// 3. Source of feedback (auto from log vs manual submission).
    public let source: FeedbackSource
    
    /// 4. Timestamp when feedback was created (ISO 8601).
    public let timestamp: Date
    
    /// 5. User-described scenario (optional free text).
    public var scenario: String?
    
    /// 6. Preset reason category (optional).
    public var reasonCategory: FeedbackReasonCategory?
    
    /// 7. Device environment snapshot (optional, local-only JSON).
    public var deviceEnv: DeviceEnvironment?
    
    /// 8. Current status in the lifecycle.
    public var status: FeedbackStatus
    
    /// 9. Resolution notes (optional).
    public var resolution: String?
    
    // MARK: - Deduplication Key
    
    /// Key for deduplication: domain + source + calendar day.
    public var dedupKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: timestamp)
        return "\(domain)_\(source.rawValue)_\(day)"
    }
    
    public init(id: UUID = UUID(),
                domain: String,
                source: FeedbackSource,
                timestamp: Date = Date(),
                scenario: String? = nil,
                reasonCategory: FeedbackReasonCategory? = nil,
                deviceEnv: DeviceEnvironment? = nil,
                status: FeedbackStatus = .pending,
                resolution: String? = nil) {
        self.id = id
        self.domain = domain.lowercased()
        self.source = source
        self.timestamp = timestamp
        self.scenario = scenario
        self.reasonCategory = reasonCategory
        self.deviceEnv = deviceEnv
        self.status = status
        self.resolution = resolution
    }
}

// MARK: - Device Environment

public struct DeviceEnvironment: Codable, Equatable {
    public let iosVersion: String
    public let appVersion: String
    public let ruleVersion: String?
    public let dnsProxyActive: Bool
    
    public init(iosVersion: String = UIDevice.current.systemVersion,
                appVersion: String? = nil,
                ruleVersion: String? = nil,
                dnsProxyActive: Bool = false) {
        self.iosVersion = iosVersion
        let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        self.appVersion = appVersion ?? bundleVersion
        self.ruleVersion = ruleVersion
        self.dnsProxyActive = dnsProxyActive
    }
}
