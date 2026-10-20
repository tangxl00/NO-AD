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
                        Label("Report False Positive", systemImage: "plus")
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
            .navigationTitle("Feedback")
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
        case .pending: return "Pending"
        case .whitelisted: return "Whitelisted"
        case .ignored: return "Ignored"
        case .reportedUpstream: return "Reported Upstream"
        case .resolved: return "Resolved"
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
                    Text("• \(category.rawValue.replacingOccurrences(of: "_", with: " "))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if item.status == .pending {
                HStack(spacing: 8) {
                    Button("Whitelist") {
                        Task { await FeedbackStore.shared.whitelistAndResolve(id: item.id) }
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    
                    Button("Ignore") {
                        Task { await FeedbackStore.shared.ignore(id: item.id) }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    
                    Button("Report") {
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
        Text(status.rawValue.replacingOccurrences(of: "_", with: " "))
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(8)
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
                Section(header: Text("Domain")) {
                    TextField("example.com", text: $domain)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }
                
                Section(header: Text("Category")) {
                    Picker("Reason", selection: $category) {
                        ForEach(FeedbackReasonCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                .tag(cat)
                        }
                    }
                }
                
                Section(header: Text("Scenario (Optional)")) {
                    TextEditor(text: $scenario)
                        .frame(minHeight: 80)
                }
                
                Section {
                    Text("Your feedback is stored locally and never uploaded to any server unless you choose to report upstream.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Report False Positive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        onSubmit()
                    }
                    .disabled(domain.isEmpty)
                }
            }
        }
    }
}
