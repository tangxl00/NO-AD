//
//  WhitelistView.swift
//  AdShield
//
//  Whitelist management with add/remove and domain search.
//

import SwiftUI

struct WhitelistView: View {
    
    @StateObject private var manager = WhitelistManager.shared
    @State private var newDomain = ""
    @State private var searchText = ""
    
    private var filteredItems: [WhitelistItem] {
        if searchText.isEmpty {
            return manager.items
        }
        return manager.items.filter { $0.domain.contains(searchText.lowercased()) }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        TextField("添加域名…", text: $newDomain)
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                        
                        Button(action: addDomain) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .disabled(newDomain.isEmpty)
                    }
                }
                
                Section(header: Text("已加白名单的域名（\(filteredItems.count)）")) {
                    ForEach(filteredItems) { item in
                        WhitelistItemRow(item: item)
                    }
                    .onDelete(perform: deleteItem)
                }
            }
            .navigationTitle("白名单")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        }
    }
    
    private func addDomain() {
        guard !newDomain.isEmpty else { return }
        Task {
            await manager.add(domain: newDomain)
            newDomain = ""
        }
    }
    
    private func deleteItem(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { filteredItems[$0] }
        Task {
            for item in itemsToDelete {
                await manager.remove(id: item.id)
            }
        }
    }
}

struct WhitelistItemRow: View {
    let item: WhitelistItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.domain)
                .font(.body)
            
            HStack {
                Text(whitelistSourceName(item.source))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if let note = item.note {
                    Text("• \(note)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// 本地化白名单来源标签（rawValue 是 JSON 存储值，不可改动）
private func whitelistSourceName(_ source: WhitelistItem.Source) -> String {
    switch source {
    case .userManual: return "手动添加"
    case .feedbackDriven: return "误杀反馈"
    case .builtin: return "内置规则"
    }
}
