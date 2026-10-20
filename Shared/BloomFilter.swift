//
//  BloomFilter.swift
//  AdShield
//
//  Space-efficient probabilistic set for DNS domain filtering.
//  Parameters: n=120_000, p=0.001, k=10, m≈1.7 Mbit (~220 KB).
//

import Foundation

/// A Bloom Filter implementation optimized for DNS domain filtering.
/// Uses double-hashing to generate k hash values from 2 base hashes.
public final class BloomFilter {
    
    private var bits: [UInt8]
    private let bitCount: UInt
    private let hashCount: UInt
    
    /// Initialize with configured parameters.
    public init(expectedElements: UInt = BloomFilterConfig.expectedElements,
                falsePositiveRate: Double = BloomFilterConfig.falsePositiveRate) {
        let m = UInt(Double(expectedElements) * log(1.0 / falsePositiveRate) / log(2.0))
        let k = UInt((Double(m) / Double(expectedElements)) * log(2.0))
        self.bitCount = max(m, 1)
        self.hashCount = max(k, 1)
        let byteCount = Int((bitCount + 7) / 8)
        self.bits = [UInt8](repeating: 0, count: byteCount)
    }
    
    /// Initialize from serialized data (for loading from disk).
    public init?(data: Data, bitCount: UInt, hashCount: UInt) {
        let expectedBytes = Int((bitCount + 7) / 8)
        guard data.count == expectedBytes else { return nil }
        self.bits = [UInt8](data)
        self.bitCount = bitCount
        self.hashCount = hashCount
    }
    
    /// Serialize to Data for disk storage.
    public var serializedData: Data {
        Data(bits)
    }
    
    /// Number of bits in the filter.
    public var size: UInt { bitCount }
    
    /// Number of hash functions.
    public var numHashes: UInt { hashCount }
    
    // MARK: - Insertion
    
    /// Insert a domain into the filter.
    public func insert(_ domain: String) {
        let hashes = hashValues(for: domain)
        for h in hashes {
            setBit(at: h)
        }
    }
    
    /// Insert multiple domains.
    public func insert(contentsOf domains: [String]) {
        for domain in domains {
            insert(domain)
        }
    }
    
    // MARK: - Query
    
    /// Check if a domain might be in the filter (may return false positives).
    public func mayContain(_ domain: String) -> Bool {
        let hashes = hashValues(for: domain)
        for h in hashes {
            if !getBit(at: h) {
                return false
            }
        }
        return true
    }
    
    // MARK: - Private
    
    /// Generate k hash values using double-hashing technique.
    private func hashValues(for domain: String) -> [UInt] {
        guard let data = domain.lowercased().data(using: .utf8) else { return [] }
        
        var h1: UInt64 = 0
        var h2: UInt64 = 0
        
        // FNV-1a 64-bit for h1
        var fnv: UInt64 = 0xcbf29ce484222325
        for byte in data {
            fnv = (fnv ^ UInt64(byte)) &* 0x100000001b3
        }
        h1 = fnv
        
        // DJB2 for h2
        var djb: UInt64 = 5381
        for byte in data {
            djb = ((djb << 5) &+ djb) &+ UInt64(byte)
        }
        h2 = djb
        
        var results = [UInt]()
        results.reserveCapacity(Int(hashCount))
        for i in 0..<hashCount {
            let combined = (h1 &+ UInt64(i) &* h2) % UInt64(bitCount)
            results.append(UInt(combined))
        }
        return results
    }
    
    private func setBit(at index: UInt) {
        let byteIndex = Int(index / 8)
        let bitOffset = Int(index % 8)
        bits[byteIndex] |= (1 << bitOffset)
    }
    
    private func getBit(at index: UInt) -> Bool {
        let byteIndex = Int(index / 8)
        let bitOffset = Int(index % 8)
        return (bits[byteIndex] & (1 << bitOffset)) != 0
    }
}

// MARK: - BloomFilter Metadata (for serialization header)

public struct BloomFilterMetadata: Codable {
    public let version: Int
    public let bitCount: UInt
    public let hashCount: UInt
    public let elementCount: UInt
    public let createdAt: Date
    public let checksum: String
    
    public init(version: Int = 1,
                bitCount: UInt,
                hashCount: UInt,
                elementCount: UInt,
                createdAt: Date = Date(),
                checksum: String) {
        self.version = version
        self.bitCount = bitCount
        self.hashCount = hashCount
        self.elementCount = elementCount
        self.createdAt = createdAt
        self.checksum = checksum
    }
}
