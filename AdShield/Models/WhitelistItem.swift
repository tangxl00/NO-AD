//
//  WhitelistItem.swift
//  AdShield
//
//  A whitelisted domain with metadata.
//

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// A single whitelisted domain entry.
public struct WhitelistItem: Codable, Identifiable, Equatable {
    public let id: UUID
    public let domain: String
    public let addedAt: Date
    public let source: Source
    public var note: String?
    
    public enum Source: String, Codable, CaseIterable {
        case userManual = "user_manual"
        case feedbackDriven = "feedback_driven"
        case builtin = "builtin"
    }
    
    public init(id: UUID = UUID(),
                domain: String,
                addedAt: Date = Date(),
                source: Source = .userManual,
                note: String? = nil) {
        self.id = id
        self.domain = domain.lowercased()
        self.addedAt = addedAt
        self.source = source
        self.note = note
    }
}

// MARK: - Whitelist Persistence Format

/// Format used for atomic write to App Group shared storage.
public struct WhitelistSnapshot: Codable {
    public let version: UInt64
    public let items: [WhitelistItem]
    public let checksum: String
    public let updatedAt: Date
    
    public init(version: UInt64, items: [WhitelistItem], updatedAt: Date = Date()) {
        self.version = version
        self.items = items
        self.updatedAt = updatedAt
        // Compute SHA-256 checksum of JSON-encoded items
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(items) {
            self.checksum = Self.computeChecksum(data)
        } else {
            self.checksum = ""
        }
    }
    
    public func verifyChecksum() -> Bool {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(items) else { return false }
        return checksum == Self.computeChecksum(data)
    }
    
    private static func computeChecksum(_ data: Data) -> String {
        var hash = Data()
        #if canImport(CryptoKit)
        if #available(iOS 13.0, *) {
            let digest = SHA256.hash(data: data)
            hash = Data(digest)
        } else {
            hash = fallbackHash(data)
        }
        #else
        hash = fallbackHash(data)
        #endif
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    private static func fallbackHash(_ data: Data) -> Data {
        // Simple fallback using CommonCrypto would go here.
        // For this implementation, return first 32 bytes or padded zeros.
        var result = Data(data.prefix(32))
        while result.count < 32 {
            result.append(0)
        }
        return result
    }
}
