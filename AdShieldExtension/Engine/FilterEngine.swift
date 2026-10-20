//
//  FilterEngine.swift
//  AdShieldExtension
//
//  Core filtering engine: Bloom Filter + HashSet + Whitelist.
//

import Foundation

final class FilterEngine {
    
    private var bloomFilter: BloomFilter?
    private var hashSet: Set<String>?
    private var whitelistSet: Set<String> = []
    private var userBlacklistSet: Set<String> = []
    
    private let queue = DispatchQueue(label: "com.YOUR_ORG.AdShield.filter", qos: .userInitiated)
    
    init() throws {
        try loadRules()
        try loadWhitelist()
    }
    
    // MARK: - Rule Loading
    
    func reloadRules() throws {
        try queue.sync {
            try loadRules()
        }
    }
    
    private func loadRules() throws {
        let paths = AppGroupPaths.shared
        
        // Load Bloom Filter
        let bloomURL = paths.bloomFilterFile
        let metaURL = paths.rulesDirectory.appendingPathComponent("rules.bloomfilter.meta")
        
        if FileManager.default.fileExists(atPath: bloomURL.path),
           FileManager.default.fileExists(atPath: metaURL.path) {
            let bloomData = try Data(contentsOf: bloomURL)
            let metaData = try Data(contentsOf: metaURL)
            let meta = try JSONDecoder().decode(BloomFilterMetadata.self, from: metaData)
            
            self.bloomFilter = BloomFilter(data: bloomData, bitCount: meta.bitCount, hashCount: meta.hashCount)
        }
        
        // Load Hash Set for secondary confirmation
        let hashSetURL = paths.hashSetFile
        if FileManager.default.fileExists(atPath: hashSetURL.path) {
            let hashData = try Data(contentsOf: hashSetURL)
            self.hashSet = try deserializeHashSet(hashData)
        }
    }
    
    private func loadWhitelist() throws {
        let paths = AppGroupPaths.shared
        let whitelistURL = paths.whitelistFile
        
        guard FileManager.default.fileExists(atPath: whitelistURL.path) else {
            // Load built-in defaults if no whitelist exists
            whitelistSet = Self.builtinWhitelist()
            return
        }
        
        let data = try Data(contentsOf: whitelistURL)
        let snapshot = try JSONDecoder().decode(WhitelistSnapshot.self, from: data)
        
        guard snapshot.verifyChecksum() else {
            // Use built-in if checksum fails
            whitelistSet = Self.builtinWhitelist()
            return
        }
        
        whitelistSet = Set(snapshot.items.map(\.domain))
    }
    
    // MARK: - Query APIs
    
    func isWhitelisted(_ domain: String) -> Bool {
        queue.sync {
            whitelistSet.contains(domain.lowercased())
        }
    }
    
    func isUserBlacklisted(_ domain: String) -> Bool {
        queue.sync {
            userBlacklistSet.contains(domain.lowercased())
        }
    }
    
    func mayBeBlocked(_ domain: String) -> Bool {
        queue.sync {
            guard let bloom = bloomFilter else { return false }
            return bloom.mayContain(domain.lowercased())
        }
    }
    
    func isConfirmedBlocked(_ domain: String) -> Bool {
        queue.sync {
            guard let hashSet = hashSet else { return false }
            return hashSet.contains(domain.lowercased())
        }
    }
    
    // MARK: - Updates
    
    func updateWhitelist(_ items: [WhitelistItem]) {
        queue.async { [weak self] in
            self?.whitelistSet = Set(items.map(\.domain))
        }
    }
    
    func updateUserBlacklist(_ domains: [String]) {
        queue.async { [weak self] in
            self?.userBlacklistSet = Set(domains.map { $0.lowercased() })
        }
    }
    
    // MARK: - Private
    
    private func deserializeHashSet(_ data: Data) throws -> Set<String> {
        var result = Set<String>()
        var offset = 0
        
        while offset + 4 <= data.count {
            let length = UInt32(bigEndian: data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) })
            offset += 4
            
            guard offset + Int(length) <= data.count else { break }
            if let domain = String(data: data.subdata(in: offset..<offset+Int(length)), encoding: .utf8) {
                result.insert(domain)
            }
            offset += Int(length)
        }
        
        return result
    }
    
    private static func builtinWhitelist() -> Set<String> {
        [
            "alipay.com",
            "alicdn.com",
            "apple.com",
            "icloud.com",
            "qq.com",
            "wechat.com",
        ]
    }
}
