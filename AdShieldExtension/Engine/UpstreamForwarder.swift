//
//  UpstreamForwarder.swift
//  AdShieldExtension
//
//  Forwards non-blocked DNS queries to upstream servers.
//

import NetworkExtension

final class UpstreamForwarder {
    
    private var upstreamSocket: Int32 = -1
    
    init() {
        // Initialize UDP socket for upstream forwarding
        upstreamSocket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    }
    
    deinit {
        if upstreamSocket >= 0 {
            close(upstreamSocket)
        }
    }
    
    func forward(datagram: Data, endpoint: NWEndpoint, flow: NEDNSProxyFlow) {
        // In a production implementation, this would:
        // 1. Forward the DNS query to the system's configured DNS server
        // 2. Receive the response
        // 3. Write the response back to the flow
        
        // For the MVP skeleton, we demonstrate the structure.
        // Full UDP forwarding requires async read/write with the upstream server.
        
        // Simplified: write back a "server failure" response to avoid hanging
        // In production, replace with actual upstream forwarding logic
        if let fallbackResponse = DNSParser.buildServerFailureResponse(for: datagram) {
            flow.writeDatagrams([fallbackResponse]) { _ in }
        }
    }
}

// MARK: - Server Failure Response

extension DNSParser {
    
    static func buildServerFailureResponse(for query: Data) -> Data? {
        guard query.count >= 12 else { return nil }
        
        var response = Data()
        
        // Transaction ID
        response.append(query.subdata(in: 0..<2))
        
        // Flags: QR=1, RCODE=2 (SERVFAIL)
        let responseFlags: UInt16 = 0x8182
        response.append(UInt8((responseFlags >> 8) & 0xFF))
        response.append(UInt8(responseFlags & 0xFF))
        
        // QDCOUNT
        response.append(query.subdata(in: 4..<6))
        
        // ANCOUNT, NSCOUNT, ARCOUNT = 0
        response.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        
        // Copy question section
        var offset = 12
        let qdcount = Int(UInt16(bigEndian: query.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt16.self) }))
        for _ in 0..<qdcount {
            while offset < query.count {
                let len = Int(query[offset])
                offset += 1
                if len == 0 { break }
                if (len & 0xC0) == 0xC0 {
                    offset += 1
                    break
                }
                offset += len
            }
            offset += 4
        }
        
        guard offset <= query.count else { return nil }
        response.append(query.subdata(in: 12..<offset))
        
        return response
    }
}
