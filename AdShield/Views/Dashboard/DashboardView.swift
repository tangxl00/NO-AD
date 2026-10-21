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
    @State private var isUpdatingRules = false
    @State private var ruleUpdateMessage: String?
    @State private var ruleUpdateFailed = false
    
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
            
            Text(proxyManager.isEnabled ? "DNS 过滤已开启" : "DNS 过滤已关闭")
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
                ProgressView("正在配置…")
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
            Text("今日")
                .font(.headline)
            
            HStack {
                StatItem(value: "\(logStore.stats.todayBlocked)", label: "已拦截", color: .red)
                Spacer()
                StatItem(value: "\(logStore.stats.totalBlocked)", label: "累计", color: .blue)
            }
            
            if !logStore.topDomains(limit: 3).isEmpty {
                Divider()
                Text("拦截最多的域名")
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
            Text("快捷操作")
                .font(.headline)
            
            HStack(spacing: 12) {
                QuickActionButton(title: "摇一摇广告指南", icon: "hand.tap") {
                    showingShakeGuide = true
                }
                
                QuickActionButton(title: "更新规则", icon: "arrow.clockwise") {
                    Task {
                        await updateRules()
                    }
                }
            }
            
            if isUpdatingRules {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("正在下载最新规则…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            
            if let message = ruleUpdateMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(ruleUpdateFailed ? .red : .secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Status Card
    
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("状态")
                .font(.headline)
            
            StatusRow(label: "规则版本", value: UserDefaults.standard.string(forKey: UserDefaultsKeys.ruleVersion) ?? "未知")
            StatusRow(label: "上次更新", value: lastUpdateText)
            StatusRow(label: "规则条数", value: "\(UserDefaults.standard.integer(forKey: UserDefaultsKeys.ruleEntryCount))")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var lastUpdateText: String {
        if let date = UserDefaults.standard.object(forKey: UserDefaultsKeys.lastRuleUpdateTime) as? Date {
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            return formatter.localizedString(for: date, relativeTo: Date())
        }
        return "从未更新"
    }
    
    private func updateRules() async {
        // 防止重复点击；下载期间 UI 显示转圈
        guard !isUpdatingRules else { return }
        isUpdatingRules = true
        defer { isUpdatingRules = false }
        ruleUpdateMessage = nil
        
        // 主源 + 备用源按序尝试，全部失败才向用户报错（不再静默吞掉）
        var sources = [RuleSourceDefaults.domainsURL] + RuleSourceDefaults.fallbackDomainsURLs
        var lastError: Error?
        
        while !sources.isEmpty {
            let urlString = sources.removeFirst()
            do {
                if let result = try await RuleDownloader.shared.download(from: urlString) {
                    let compiler = RuleCompiler.shared
                    let compiled = try await compiler.compile(domains: result.domains, version: result.etag)
                    try await compiler.persist(rules: compiled)
                    
                    UserDefaults.standard.set(result.etag, forKey: UserDefaultsKeys.ruleVersion)
                    UserDefaults.standard.set(result.totalCount, forKey: UserDefaultsKeys.ruleEntryCount)
                    UserDefaults.standard.set(Date(), forKey: UserDefaultsKeys.lastRuleUpdateTime)
                    
                    ruleUpdateFailed = false
                    ruleUpdateMessage = "规则已更新：\(result.totalCount) 条域名"
                } else {
                    // HTTP 304：本地规则已是最新
                    ruleUpdateFailed = false
                    ruleUpdateMessage = "规则已是最新版本"
                }
                return
            } catch {
                lastError = error
                // 尝试下一个源
            }
        }
        
        ruleUpdateFailed = true
        if let lastError = lastError {
            ruleUpdateMessage = "规则更新失败：\(lastError.localizedDescription)"
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
