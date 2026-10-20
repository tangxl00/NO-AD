//
//  BlockingLog.swift
//  AdShield
//
//  Local-only DNS blocking log entry. No data leaves device.
//

import Foundation

/// A single DNS blocking event recorded locally.
public struct BlockingLog: Codable, Identifiable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let domain: String
    public let source: String
    public let ruleType: RuleType
    public let action: BlockAction
    
    public enum RuleType: String, Codable, CaseIterable {
        case antiAD = "anti-ad"
        case custom = "custom"
        case userBlacklist = "user_blacklist"
    }
    
    public enum BlockAction: String, Codable, CaseIterable {
        case nxdomain = "NXDOMAIN"
        case zeroIP = "0.0.0.0"
    }
    
    public init(id: UUID = UUID(),
                timestamp: Date = Date(),
                domain: String,
                source: String,
                ruleType: RuleType,
                action: BlockAction = .nxdomain) {
        self.id = id
        self.timestamp = timestamp
        self.domain = domain.lowercased()
        self.source = source
        self.ruleType = ruleType
        self.action = action
    }
}

// MARK: - Blocking Statistics

public struct BlockingStats: Codable {
    public var totalBlocked: UInt64
    public var todayBlocked: UInt64
    public var lastResetDate: Date
    public var topDomains: [String: UInt64]
    public var dailyCounts: [String: UInt64]
    
    public init(totalBlocked: UInt64 = 0,
                todayBlocked: UInt64 = 0,
                lastResetDate: Date = Date(),
                topDomains: [String: UInt64] = [:],
                dailyCounts: [String: UInt64] = [:]) {
        self.totalBlocked = totalBlocked
        self.todayBlocked = todayBlocked
        self.lastResetDate = lastResetDate
        self.topDomains = topDomains
        self.dailyCounts = dailyCounts
    }
    
    public mutating func recordBlock(domain: String) {
        totalBlocked += 1
        todayBlocked += 1
        topDomains[domain, default: 0] += 1
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dayKey = formatter.string(from: Date())
        dailyCounts[dayKey, default: 0] += 1
    }
    
    public mutating func resetDailyIfNeeded() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        let lastDay = formatter.string(from: lastResetDate)
        if today != lastDay {
            todayBlocked = 0
            lastResetDate = Date()
        }
    }
}
