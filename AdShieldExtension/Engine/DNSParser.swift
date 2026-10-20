//
//  DNSParser.swift
//  AdShieldExtension
//
//  Minimal DNS packet parser and NXDOMAIN response builder.
//

import Foundation

enum DNSParser {
    
    // MARK: - Parse Query Domain
    
    static func extractQueryDomain(from data: Data) -> String? {
        guard data.count >= 12 else { return nil }
        
        // Check flags: ensure it's a standard query (QR=0, OPCODE=0)
        let flags = UInt16(bigEndian: data.withUnsafeBytes { $0.load(fromByteOffset: 2, as: UInt16.self) })
        guard (flags & 0x8000) == 0 else { return nil } // QR must be 0 (query)
        
        // Parse question section
        var offset = 12 // Header is 12 bytes
        let qdcount = Int(UInt16(bigEndian: data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt16.self) }))
        guard qdcount > 0 else { return nil }
        
        // Read the QNAME (domain name in label format)
        var labels: [String] = []
        while offset < data.count {
            let labelLength = Int(data[offset])
            offset += 1
            
            if labelLength == 0 {
                break // End of name
            }
            
            // Check for compression pointer (0xC0 mask)
            if (labelLength & 0xC0) == 0xC0 {
                // Compression not fully handled in this simplified parser
                // For MVP, return nil to forward upstream
                return nil
            }
            
            guard offset + labelLength <= data.count else { return nil }
            if let label = String(data: data.subdata(in: offset..<offset+labelLength), encoding: .utf8) {
                labels.append(label)
            }
            offset += labelLength
        }
        
        guard !labels.isEmpty else { return nil }
        return labels.joined(separator: ".").lowercased()
    }
    
    // MARK: - Build NXDOMAIN Response
    
    static func buildNXDOMAINResponse(for query: Data) -> Data? {
        guard query.count >= 12 else { return nil }
        
        var response = Data()
        
        // Copy transaction ID (2 bytes)
        response.append(query.subdata(in: 0..<2))
        
        // Flags: QR=1 (response), OPCODE=0, AA=1, TC=0, RD=1, RA=1, Z=0, RCODE=3 (NXDOMAIN)
        let responseFlags: UInt16 = 0x8183 // Response + NXDOMAIN
        response.append(UInt8((responseFlags >> 8) & 0xFF))
        response.append(UInt8(responseFlags & 0xFF))
        
        // QDCOUNT: copy from query
        response.append(query.subdata(in: 4..<6))
        
        // ANCOUNT: 0
        response.append(contentsOf: [0x00, 0x00])
        
        // NSCOUNT: 0
        response.append(contentsOf: [0x00, 0x00])
        
        // ARCOUNT: 0
        response.append(contentsOf: [0x00, 0x00])
        
        // Copy question section (everything after header)
        let qdcount = Int(UInt16(bigEndian: query.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt16.self) }))
        guard qdcount > 0 else { return nil }
        
        // Find end of question section (need to skip QNAME + QTYPE + QCLASS)
        var offset = 12
        for _ in 0..<qdcount {
            // Skip QNAME
            while offset < query.count {
                let len = Int(query[offset])
                offset += 1
                if len == 0 { break }
                if (len & 0xC0) == 0xC0 {
                    offset += 1 // Compression pointer
                    break
                }
                offset += len
            }
            // Skip QTYPE (2) + QCLASS (2)
            offset += 4
        }
        
        guard offset <= query.count else { return nil }
        response.append(query.subdata(in: 12..<offset))
        
        return response
    }
}
