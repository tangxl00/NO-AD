//
//  DNSProxyManager.swift
//  AdShield
//
//  Manages the NEDNSProxyProvider lifecycle and system configuration.
//

import Foundation
import NetworkExtension
import Combine

@MainActor
public final class DNSProxyManager: ObservableObject {
    
    public static let shared = DNSProxyManager()
    
    @Published public private(set) var isEnabled: Bool = false
    @Published public private(set) var isInstalling: Bool = false
    @Published public private(set) var lastError: String?
    
    private var proxyManager: NEDNSProxyManager?
    
    private init() {
        loadState()
    }
    
    // MARK: - State Loading
    
    private func loadState() {
        NEDNSProxyManager.shared().loadFromPreferences { [weak self] error in
            Task { @MainActor in
                if let error = error {
                    self?.lastError = "Failed to load preferences: \(error.localizedDescription)"
                    return
                }
                let manager = NEDNSProxyManager.shared()
                self?.proxyManager = manager
                self?.isEnabled = manager.isEnabled
            }
        }
    }
    
    // MARK: - Install / Enable
    
    public func installAndEnable() async {
        isInstalling = true
        defer { isInstalling = false }
        
        let manager = NEDNSProxyManager.shared()
        
        // Create provider configuration
        let providerProtocol = NEDNSProxyProviderProtocol()
        providerProtocol.providerBundleIdentifier = BundleIdentifiers.extensionTarget
        providerProtocol.providerConfiguration = [:]
        providerProtocol.serverAddress = "127.0.0.1"
        providerProtocol.includeAllNetworks = false
        
        manager.providerProtocol = providerProtocol
        manager.localizedDescription = "AdShield DNS Proxy"
        
        do {
            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()
            manager.isEnabled = true
            try await manager.saveToPreferences()
            isEnabled = true
        } catch {
            lastError = "Failed to enable DNS Proxy: \(error.localizedDescription)"
            isEnabled = false
        }
    }
    
    // MARK: - Disable
    
    public func disable() async {
        let manager = NEDNSProxyManager.shared()
        manager.isEnabled = false
        
        do {
            try await manager.saveToPreferences()
            isEnabled = false
        } catch {
            lastError = "Failed to disable DNS Proxy: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Toggle
    
    public func toggle() async {
        if isEnabled {
            await disable()
        } else {
            await installAndEnable()
        }
    }
    
    // MARK: - Status Refresh
    
    public func refreshStatus() async {
        let manager = NEDNSProxyManager.shared()
        do {
            try await manager.loadFromPreferences()
            isEnabled = manager.isEnabled
        } catch {
            lastError = "Failed to refresh status: \(error.localizedDescription)"
        }
    }
}
