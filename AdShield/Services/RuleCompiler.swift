//
//  RuleCompiler.swift
//  AdShield
//
//  Compiles domain lists into Bloom Filter + Hash Set binary formats.
//

import Foundation

public actor RuleCompiler {
    
    public static let shared = RuleCompiler()
    
    private init() {}
    
    // MARK: - Compile
    
    /// Compiles a list of domains into Bloom Filter and Hash Set binaries.
    public func compile(domains: [String], version: String? = nil) throws -> CompiledRules {
        // Build Bloom Filter
        let bloomFilter = BloomFilter()
        bloomFilter.insert(contentsOf: domains)
        
        let bloomData = bloomFilter.serializedData
        let bloomMeta = BloomFilterMetadata(
            bitCount: bloomFilter.size,
            hashCount: bloomFilter.numHashes,
            elementCount: UInt(domains.count),
            checksum: Self.computeChecksum(bloomData)
        )
        
        // Build Hash Set binary (for secondary confirmation)
        let hashSetData = try serializeHashSet(domains)
        
        return CompiledRules(
            sourceID: UUID(),
            domainCount: domains.count,
            bloomFilterData: bloomData,
            bloomFilterMeta: bloomMeta,
            hashSetData: hashSetData,
            version: version
        )
    }
    
    // MARK: - Persist
    
    /// Writes compiled rules to App Group shared container atomically.
    public func persist(rules: CompiledRules) throws {
        let paths = AppGroupPaths.shared
        try paths.ensureDirectories()
        
        // Write Bloom Filter atomically
        let bloomTemp = paths.bloomFilterFile.appendingPathExtension("tmp")
        try rules.bloomFilterData.write(to: bloomTemp, options: .atomic)
        try FileManager.default.moveItem(at: bloomTemp, to: paths.bloomFilterFile)
        
        // Write Bloom Filter metadata
        let metaURL = paths.rulesDirectory.appendingPathComponent("rules.bloomfilter.meta")
        let metaData = try JSONEncoder().encode(rules.bloomFilterMeta)
        try metaData.write(to: metaURL, options: .atomic)
        
        // Write Hash Set atomically
        let hashTemp = paths.hashSetFile.appendingPathExtension("tmp")
        try rules.hashSetData.write(to: hashTemp, options: .atomic)
        try FileManager.default.moveItem(at: hashTemp, to: paths.hashSetFile)
        
        // Write version info
        let versionInfo = RuleVersionInfo(
            compiledAt: rules.compiledAt,
            domainCount: rules.domainCount,
            version: rules.version
        )
        let versionData = try JSONEncoder().encode(versionInfo)
        let versionURL = paths.rulesDirectory.appendingPathComponent("version.json")
        try versionData.write(to: versionURL, options: .atomic)
    }
    
    // MARK: - Private
    
    private func serializeHashSet(_ domains: [String]) throws -> Data {
        // Simple serialization: length-prefixed UTF-8 strings, sorted for binary search
        let sorted = domains.sorted()
        var data = Data()
        for domain in sorted {
            guard let domainData = domain.data(using: .utf8) else { continue }
            var length = UInt32(domainData.count).bigEndian
            data.append(Data(bytes: &length, count: 4))
            data.append(domainData)
        }
        return data
    }
    
    private static func computeChecksum(_ data: Data) -> String {
        // SHA-256 checksum computation
        #if canImport(CryptoKit)
        if #available(iOS 13.0, *) {
            import CryptoKit
            let digest = SHA256.hash(data: data)
            return Data(digest).map { String(format: "%02x", $0) }.joined()
        }
        #endif
        // Fallback: truncated data hash
        return data.prefix(32).base64EncodedString()
    }
}

// MARK: - Rule Version Info

private struct RuleVersionInfo: Codable {
    let compiledAt: Date
    let domainCount: Int
    let version: String?
}
