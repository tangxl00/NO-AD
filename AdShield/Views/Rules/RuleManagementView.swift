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
                Section(header: Text("Active Sources")) {
                    ForEach(ruleSources) { source in
                        RuleSourceRow(source: source, isUpdating: isUpdating)
                    }
                    .onDelete(perform: deleteSource)
                }
                
                Section {
                    Button(action: { showingAddSource = true }) {
                        Label("Add Rule Source", systemImage: "plus")
                    }
                }
                
                Section(header: Text("Update Settings")) {
                    Toggle("Auto Update", isOn: .init(
                        get: { UserDefaults.standard.bool(forKey: UserDefaultsKeys.autoUpdateRules) },
                        set: { UserDefaults.standard.set($0, forKey: UserDefaultsKeys.autoUpdateRules) }
                    ))
                    
                    Button(action: { Task { await manualUpdate() } }) {
                        HStack {
                            Text("Update Now")
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
                            .foregroundColor(message.contains("Failed") ? .red : .green)
                    }
                }
            }
            .navigationTitle("Rules")
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
                
                updateMessage = "Updated: \(result.totalCount) domains"
            } else {
                updateMessage = "No updates available"
            }
        } catch {
            updateMessage = "Failed: \(error.localizedDescription)"
        }
        
        isUpdating = false
    }
    
    private func deleteSource(at offsets: IndexSet) {
        ruleSources.remove(atOffsets: offsets)
    }
    
    private func addSource() {
        guard !newSourceURL.isEmpty, URL(string: newSourceURL) != nil else { return }
        let source = RuleSource(name: "Custom", url: newSourceURL, format: .domainsTxt)
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
                Label(source.enabled ? "Enabled" : "Disabled", systemImage: source.enabled ? "checkmark.circle" : "xmark.circle")
                    .font(.caption2)
                    .foregroundColor(source.enabled ? .green : .red)
                
                if let count = source.entryCount {
                    Text("\(count) entries")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if let date = source.lastUpdated {
                    Text("Updated \(date, style: .relative) ago")
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
                Section(header: Text("Rule Source URL")) {
                    TextField("https://", text: $url)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
                
                Section {
                    Text("Supported formats: domains.txt (one domain per line)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd()
                    }
                    .disabled(url.isEmpty)
                }
            }
        }
    }
}
