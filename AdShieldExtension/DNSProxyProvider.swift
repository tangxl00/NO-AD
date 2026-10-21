//
//  DNSProxyProvider.swift
//  AdShieldExtension
//
//  NEDNSProxyProvider implementation for local DNS filtering.
//

import NetworkExtension
import Darwin

class DNSProxyProvider: NEDNSProxyProvider {
    
    private var filterEngine: FilterEngine?
    private var whitelistListener: WhitelistListener?
    private var upstreamForwarder: UpstreamForwarder?
    
    // MARK: - Lifecycle
    
    override func startProxy(options: [String : Any]? = nil, completionHandler: @escaping (Error?) -> Void) {
        do {
            try AppGroupPaths.shared.ensureDirectories()
            
            // Initialize filter engine with compiled rules
            self.filterEngine = try FilterEngine()
            
            // Initialize whitelist listener
            self.whitelistListener = WhitelistListener(delegate: self)
            
            // Initialize upstream forwarder
            self.upstreamForwarder = UpstreamForwarder()
            
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }
    
    override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        filterEngine = nil
        whitelistListener?.stop()
        whitelistListener = nil
        upstreamForwarder = nil
        completionHandler()
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        completionHandler()
    }
    
    override func wake() {
        // Reload rules if needed
        try? filterEngine?.reloadRules()
    }
    
    // MARK: - DNS Query Handling
    
    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        guard let dnsFlow = flow as? NEAppProxyUDPFlow else {
            flow.closeReadWithError(nil)
            flow.closeWriteWithError(nil)
            return false
        }
        
        dnsFlow.readDatagrams { [weak self] datagrams, remoteEndpoints, error in
            guard let self = self else { return }
            
            guard error == nil, let datagrams = datagrams, let endpoints = remoteEndpoints else {
                dnsFlow.closeReadWithError(nil)
                return
            }
            
            for (index, datagram) in datagrams.enumerated() {
                guard index < endpoints.count else { continue }
                let endpoint = endpoints[index]
                
                self.processDNSQuery(datagram: datagram, endpoint: endpoint, flow: dnsFlow)
            }
        }
        return true
    }
    
    private func processDNSQuery(datagram: Data, endpoint: NWEndpoint, flow: NEAppProxyUDPFlow) {
        // Parse DNS query to extract domain
        guard let queryDomain = DNSParser.extractQueryDomain(from: datagram) else {
            // Forward upstream if we can't parse
            upstreamForwarder?.forward(datagram: datagram, endpoint: endpoint, flow: flow)
            return
        }
        
        // Check whitelist first (highest priority)
        if filterEngine?.isWhitelisted(queryDomain) == true {
            upstreamForwarder?.forward(datagram: datagram, endpoint: endpoint, flow: flow)
            return
        }
        
        // Check user custom blacklist
        if filterEngine?.isUserBlacklisted(queryDomain) == true {
            sendBlockResponse(flow: flow, originalDatagram: datagram, endpoint: endpoint)
            return
        }
        
        // Check anti-AD Bloom Filter
        if filterEngine?.mayBeBlocked(queryDomain) == true {
            // Secondary confirmation with full hash set
            if filterEngine?.isConfirmedBlocked(queryDomain) == true {
                sendBlockResponse(flow: flow, originalDatagram: datagram, endpoint: endpoint)
                return
            }
        }
        
        // Not blocked — forward to upstream DNS
        upstreamForwarder?.forward(datagram: datagram, endpoint: endpoint, flow: flow)
    }
    
    private func sendBlockResponse(flow: NEAppProxyUDPFlow, originalDatagram: Data, endpoint: NWEndpoint) {
        guard let response = DNSParser.buildNXDOMAINResponse(for: originalDatagram) else {
            flow.closeWriteWithError(nil)
            return
        }
        
        flow.writeDatagrams([response], sentBy: [endpoint]) { error in
            if let error = error {
                print("Failed to write block response: \(error)")
            }
        }
    }
}

// MARK: - WhitelistListenerDelegate

extension DNSProxyProvider: WhitelistListenerDelegate {
    
    func whitelistDidUpdate(_ items: [WhitelistItem]) {
        filterEngine?.updateWhitelist(items)
    }
}
