//
//  RuleDownloader.swift
//  AdShield
//
//  Downloads anti-AD domains.txt with caching, ETag support, and streaming parse.
//

import Foundation

public actor RuleDownloader {
    
    public static let shared = RuleDownloader()
    
    private let session: URLSession
    private var lastETag: String?
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Download
    
    /// Downloads rules from the given URL. Returns nil if not modified (HTTP 304).
    public func download(from urlString: String) async throws -> DownloadResult? {
        guard let url = URL(string: urlString) else {
            throw RuleDownloadError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("AdShield/1.0", forHTTPHeaderField: "User-Agent")
        
        // Add conditional request headers if we have cached data
        if let etag = lastETag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RuleDownloadError.invalidResponse
        }
        
        if httpResponse.statusCode == 304 {
            return nil // Not modified
        }
        
        guard httpResponse.statusCode == 200 else {
            throw RuleDownloadError.httpError(statusCode: httpResponse.statusCode)
        }
        
        // Save ETag for next request
        if let etag = httpResponse.value(forHTTPHeaderField: "ETag") {
            self.lastETag = etag
        }
        
        // Stream-parse the response
        let domains = try parseDomains(from: data)
        
        return DownloadResult(
            domains: domains,
            totalCount: domains.count,
            etag: lastETag,
            timestamp: Date()
        )
    }
    
    // MARK: - Parse
    
    /// Parses domains.txt format: one domain per line, skip comments and empty lines.
    private func parseDomains(from data: Data) throws -> [String] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw RuleDownloadError.decodeFailure
        }
        
        var domains = Set<String>()
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines and comments
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            
            // Normalize: lowercase
            let normalized = trimmed.lowercased()
            
            // Validate domain format
            guard isValidDomain(normalized) else { continue }
            
            domains.insert(normalized)
        }
        
        // Sanity check: expect at least 50k domains
        guard domains.count >= 50_000 else {
            throw RuleDownloadError.insufficientData(count: domains.count)
        }
        
        return Array(domains)
    }
    
    /// RFC 1123 domain validation (simplified).
    private func isValidDomain(_ domain: String) -> Bool {
        let pattern = "^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)*$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return false }
        let range = NSRange(location: 0, length: domain.utf16.count)
        return regex.firstMatch(in: domain, options: [], range: range) != nil
    }
}

// MARK: - Types

public struct DownloadResult {
    public let domains: [String]
    public let totalCount: Int
    public let etag: String?
    public let timestamp: Date
}

public enum RuleDownloadError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodeFailure
    case insufficientData(count: Int)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid rule source URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodeFailure:
            return "Failed to decode response data"
        case .insufficientData(let count):
            return "Rule file seems incomplete (only \(count) domains, expected > 50,000)"
        }
    }
}
