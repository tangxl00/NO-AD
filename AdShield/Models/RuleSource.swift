//
//  RuleSource.swift
//  AdShield
//
//  Configuration for an external rule subscription.
//

import Foundation

/// A rule source subscription configuration.
public struct RuleSource: Codable, Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var url: String
    public var enabled: Bool
    public var autoUpdate: Bool
    public var lastUpdated: Date?
    public var entryCount: Int?
    public var version: String?
    public var format: RuleFormat
    
    public enum RuleFormat: String, Codable, CaseIterable {
        case domainsTxt = "domains_txt"
        case adguard = "adguard"
        case easylist = "easylist"
    }
    
    public init(id: UUID = UUID(),
                name: String,
                url: String,
                enabled: Bool = true,
                autoUpdate: Bool = true,
                lastUpdated: Date? = nil,
                entryCount: Int? = nil,
                version: String? = nil,
                format: RuleFormat = .domainsTxt) {
        self.id = id
        self.name = name
        self.url = url
        self.enabled = enabled
        self.autoUpdate = autoUpdate
        self.lastUpdated = lastUpdated
        self.entryCount = entryCount
        self.version = version
        self.format = format
    }
    
    /// Default anti-AD source.
    public static var `default`: RuleSource {
        RuleSource(
            name: RuleSourceDefaults.name,
            url: RuleSourceDefaults.domainsURL,
            enabled: true,
            autoUpdate: true,
            format: .domainsTxt
        )
    }
}

// MARK: - Rule Compilation Result

/// Result of downloading and compiling a rule set.
public struct CompiledRules: Codable {
    public let sourceID: UUID
    public let compiledAt: Date
    public let domainCount: Int
    public let bloomFilterData: Data
    public let bloomFilterMeta: BloomFilterMetadata
    public let hashSetData: Data
    public let version: String?
    
    public init(sourceID: UUID,
                compiledAt: Date = Date(),
                domainCount: Int,
                bloomFilterData: Data,
                bloomFilterMeta: BloomFilterMetadata,
                hashSetData: Data,
                version: String? = nil) {
        self.sourceID = sourceID
        self.compiledAt = compiledAt
        self.domainCount = domainCount
        self.bloomFilterData = bloomFilterData
        self.bloomFilterMeta = bloomFilterMeta
        self.hashSetData = hashSetData
        self.version = version
    }
}
