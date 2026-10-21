//
//  FeedbackListView.swift
//  AdShield
//
//  False-positive feedback list with status management.
//

import SwiftUI

struct FeedbackListView: View {
    
    @StateObject private var store = FeedbackStore.shared
    @State private var showingAddFeedback = false
    @State private var newDomain = ""
    @State private var newScenario = ""
    @State private var selectedCategory: FeedbackReasonCategory = .normalWebsite
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(action: { showingAddFeedback = true }) {
                        Label("报告误杀", systemImage: "plus")
                    }
                }
                
                ForEach(FeedbackStatus.allCases, id: \.self) { status in
                    let items = store.items.filter { $0.status == status }
                    if !items.isEmpty {
                        Section(header: Text(statusDisplayName(status))) {
                            ForEach(items) { item in
                                FeedbackRow(item: item)
                            }
                        }
                    }
                }
            }
            .navigationTitle("反馈")
            .sheet(isPresented: $showingAddFeedback) {
                AddFeedbackSheet(
                    domain: $newDomain,
                    scenario: $newScenario,
                    category: $selectedCategory,
                    onSubmit: submitFeedback
                )
            }
        }
    }
    
    private func statusDisplayName(_ status: FeedbackStatus) -> String {
        switch status {
        case .pending: return "待处理"
        case .whitelisted: return "已加白"
        case .ignored: return "已忽略"
        case .reportedUpstream: return "已上报"
        case .resolved: return "已解决"
        }
    }
    
    private func submitFeedback() {
        guard !newDomain.isEmpty else { return }
        Task {
            let env = DeviceEnvironment()
            await store.add(
                domain: newDomain,
                scenario: newScenario.isEmpty ? nil : newScenario,
                reasonCategory: selectedCategory,
                deviceEnv: env
            )
            newDomain = ""
            newScenario = ""
            showingAddFeedback = false
        }
    }
}

struct FeedbackRow: View {
    let item: FeedbackItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.domain)
                    .font(.body)
                    .lineLimit(1)
                Spacer()
                StatusBadge(status: item.status)
            }
            
            if let scenario = item.scenario {
                Text(scenario)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Text(item.timestamp, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if let category = item.reasonCategory {
                    Text("• \(categoryDisplayName(category))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if item.status == .pending {
                HStack(spacing: 8) {
                    Button("加白") {
                        Task { await FeedbackStore.shared.whitelistAndResolve(id: item.id) }
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    
                    Button("忽略") {
                        Task { await FeedbackStore.shared.ignore(id: item.id) }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    
                    Button("上报") {
                        Task { await FeedbackStore.shared.reportUpstream(id: item.id) }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let status: FeedbackStatus
    
    var color: Color {
        switch status {
        case .pending: return .orange
        case .whitelisted: return .green
        case .ignored: return .gray
        case .reportedUpstream: return .blue
        case .resolved: return .purple
        }
    }
    
    var body: some View {
        Text(statusBadgeText)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(8)
    }
    
    private var statusBadgeText: String {
        switch status {
        case .pending: return "待处理"
        case .whitelisted: return "已加白"
        case .ignored: return "已忽略"
        case .reportedUpstream: return "已上报"
        case .resolved: return "已解决"
        }
    }
}

struct AddFeedbackSheet: View {
    @Binding var domain: String
    @Binding var scenario: String
    @Binding var category: FeedbackReasonCategory
    let onSubmit: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("域名")) {
                    TextField("example.com", text: $domain)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }
                
                Section(header: Text("误杀类型")) {
                    Picker("原因", selection: $category) {
                        ForEach(FeedbackReasonCategory.allCases, id: \.self) { cat in
                            Text(categoryDisplayName(cat))
                                .tag(cat)
                        }
                    }
                }
                
                Section(header: Text("具体场景（选填）")) {
                    TextEditor(text: $scenario)
                        .frame(minHeight: 80)
                }
                
                Section {
                    Text("你的反馈仅保存在本机，除非你主动选择「上报」，否则不会上传到任何服务器。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("报告误杀")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("提交") {
                        onSubmit()
                    }
                    .disabled(domain.isEmpty)
                }
            }
        }
    }
}

/// 本地化误杀类型标签（rawValue 是 JSON 存储值，不可改动）
func categoryDisplayName(_ category: FeedbackReasonCategory) -> String {
    switch category {
    case .normalWebsite: return "正常网站被拦截"
    case .appFunctionBroken: return "应用功能异常"
    case .paymentBanking: return "支付/银行类"
    case .other: return "其他"
    }
}
