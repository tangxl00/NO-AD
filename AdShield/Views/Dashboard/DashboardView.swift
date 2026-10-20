//
//  DashboardView.swift
//  AdShield
//
//  Main dashboard with DNS toggle, daily stats, and status indicators.
//

import SwiftUI

struct DashboardView: View {
    
    @StateObject private var proxyManager = DNSProxyManager.shared
    @StateObject private var logStore = BlockingLogStore.shared
    
    @State private var showingShakeGuide = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // DNS Toggle Card
                    dnsToggleCard
                    
                    // Today's Stats
                    statsCard
                    
                    // Quick Actions
                    quickActionsCard
                    
                    // Status Info
                    statusCard
                }
                .padding()
            }
            .navigationTitle("AdShield")
            .sheet(isPresented: $showingShakeGuide) {
                ShakeGuideView()
            }
        }
    }
    
    // MARK: - DNS Toggle Card
    
    private var dnsToggleCard: some View {
        VStack(spacing: 16) {
            Image(systemName: proxyManager.isEnabled ? "shield.checkerboard" : "shield.slash")
                .font(.system(size: 64))
                .foregroundColor(proxyManager.isEnabled ? .green : .gray)
                .animation(.easeInOut, value: proxyManager.isEnabled)
            
            Text(proxyManager.isEnabled ? "DNS Filtering Active" : "DNS Filtering Off")
                .font(.title2)
                .fontWeight(.semibold)
            
            Toggle("", isOn: .init(
                get: { proxyManager.isEnabled },
                set: { _ in Task { await proxyManager.toggle() } }
            ))
            .labelsHidden()
            .scaleEffect(1.3)
            .tint(.green)
            
            if proxyManager.isInstalling {
                ProgressView("Configuring...")
            }
            
            if let error = proxyManager.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Stats Card
    
    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(.headline)
            
            HStack {
                StatItem(value: "\(logStore.stats.todayBlocked)", label: "Blocked", color: .red)
                Spacer()
                StatItem(value: "\(logStore.stats.totalBlocked)", label: "Total", color: .blue)
            }
            
            if !logStore.topDomains(limit: 3).isEmpty {
                Divider()
                Text("Top Blocked Domains")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(logStore.topDomains(limit: 3), id: \.domain) { item in
                    HStack {
                        Text(item.domain)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text("\(item.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Quick Actions
    
    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
            
            HStack(spacing: 12) {
                QuickActionButton(title: "Shake Guide", icon: "hand.tap") {
                    showingShakeGuide = true
                }
                
                QuickActionButton(title: "Update Rules", icon: "arrow.clockwise") {
                    Task {
                        await updateRules()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Status Card
    
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.headline)
            
            StatusRow(label: "Rule Version", value: UserDefaults.standard.string(forKey: UserDefaultsKeys.ruleVersion) ?? "Unknown")
            StatusRow(label: "Last Update", value: lastUpdateText)
            StatusRow(label: "Rule Entries", value: "\(UserDefaults.standard.integer(forKey: UserDefaultsKeys.ruleEntryCount))")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var lastUpdateText: String {
        if let date = UserDefaults.standard.object(forKey: UserDefaultsKeys.lastRuleUpdateTime) as? Date {
            let formatter = RelativeDateTimeFormatter()
            return formatter.localizedString(for: date, relativeTo: Date())
        }
        return "Never"
    }
    
    private func updateRules() async {
        // Trigger rule update
        let downloader = RuleDownloader.shared
        do {
            if let result = try await downloader.download(from: RuleSourceDefaults.domainsURL) {
                let compiler = RuleCompiler.shared
                let compiled = try await compiler.compile(domains: result.domains, version: result.etag)
                try await compiler.persist(rules: compiled)
                
                UserDefaults.standard.set(result.etag, forKey: UserDefaultsKeys.ruleVersion)
                UserDefaults.standard.set(result.totalCount, forKey: UserDefaultsKeys.ruleEntryCount)
                UserDefaults.standard.set(Date(), forKey: UserDefaultsKeys.lastRuleUpdateTime)
            }
        } catch {
            print("Rule update failed: \(error)")
        }
    }
}

// MARK: - Subviews

struct StatItem: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct StatusRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
        }
    }
}
