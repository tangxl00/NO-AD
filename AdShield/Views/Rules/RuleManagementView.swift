//
//  RuleManagementView.swift
//  AdShield
//
//  Rule source management with update controls and manual refresh.
//

import SwiftUI

struct RuleManagementView: View {
    
    @State private var ruleSources: [RuleSource] = [.default]
    @State private var isUpdating = false
    @State private var updateMessage: String?
    @State private var showingAddSource = false
    @State private var newSourceURL = ""
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("启用的规则源")) {
                    ForEach(ruleSources) { source in
                        RuleSourceRow(source: source, isUpdating: isUpdating)
                    }
                    .onDelete(perform: deleteSource)
                }
                
                Section {
                    Button(action: { showingAddSource = true }) {
                        Label("添加规则源", systemImage: "plus")
                    }
                }
                
                Section(header: Text("更新设置")) {
                    Toggle("自动更新", isOn: .init(
                        get: { UserDefaults.standard.bool(forKey: UserDefaultsKeys.autoUpdateRules) },
                        set: { UserDefaults.standard.set($0, forKey: UserDefaultsKeys.autoUpdateRules) }
                    ))
                    
                    Button(action: { Task { await manualUpdate() } }) {
                        HStack {
                            Text("立即更新")
                            Spacer()
                            if isUpdating {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isUpdating)
                }
                
                if let message = updateMessage {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(message.contains("失败") ? .red : .green)
                    }
                }
            }
            .navigationTitle("规则")
            .sheet(isPresented: $showingAddSource) {
                AddRuleSourceSheet(url: $newSourceURL, onAdd: addSource)
            }
        }
    }
    
    private func manualUpdate() async {
        isUpdating = true
        updateMessage = nil
        
        let downloader = RuleDownloader.shared
        do {
            if let result = try await downloader.download(from: RuleSourceDefaults.domainsURL) {
                let compiler = RuleCompiler.shared
                let compiled = try await compiler.compile(domains: result.domains, version: result.etag)
                try await compiler.persist(rules: compiled)
                
                UserDefaults.standard.set(result.etag, forKey: UserDefaultsKeys.ruleVersion)
                UserDefaults.standard.set(result.totalCount, forKey: UserDefaultsKeys.ruleEntryCount)
                UserDefaults.standard.set(Date(), forKey: UserDefaultsKeys.lastRuleUpdateTime)
                
                updateMessage = "已更新：\(result.totalCount) 个域名"
            } else {
                updateMessage = "当前没有可用更新"
            }
        } catch {
            updateMessage = "失败：\(error.localizedDescription)"
        }
        
        isUpdating = false
    }
    
    private func deleteSource(at offsets: IndexSet) {
        ruleSources.remove(atOffsets: offsets)
    }
    
    private func addSource() {
        guard !newSourceURL.isEmpty, URL(string: newSourceURL) != nil else { return }
        let source = RuleSource(name: "自定义", url: newSourceURL, format: .domainsTxt)
        ruleSources.append(source)
        newSourceURL = ""
        showingAddSource = false
    }
}

struct RuleSourceRow: View {
    let source: RuleSource
    let isUpdating: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(source.name)
                .font(.headline)
            Text(source.url)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            HStack {
                Label(source.enabled ? "已启用" : "已停用", systemImage: source.enabled ? "checkmark.circle" : "xmark.circle")
                    .font(.caption2)
                    .foregroundColor(source.enabled ? .green : .red)
                
                if let count = source.entryCount {
                    Text("\(count) 条规则")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if let date = source.lastUpdated {
                    Text("更新于 \(date, style: .relative)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddRuleSourceSheet: View {
    @Binding var url: String
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("规则源网址")) {
                    TextField("https://", text: $url)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
                
                Section {
                    Text("支持的格式：domains.txt（每行一个域名）")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("添加规则源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        onAdd()
                    }
                    .disabled(url.isEmpty)
                }
            }
        }
    }
}
