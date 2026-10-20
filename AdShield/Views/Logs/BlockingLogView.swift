//
//  BlockingLogView.swift
//  AdShield
//
//  Blocking history with daily trends and top domains.
//

import SwiftUI

struct BlockingLogView: View {
    
    @StateObject private var store = BlockingLogStore.shared
    @State private var selectedDays = 7
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Daily Trend (Last 7 Days)")) {
                    DailyTrendView(data: store.dailyCountsForLast(days: 7))
                        .frame(height: 120)
                }
                
                Section(header: Text("Top Blocked Domains")) {
                    ForEach(store.topDomains(limit: 10), id: \.domain) { item in
                        HStack {
                            Text(item.domain)
                                .font(.body)
                                .lineLimit(1)
                            Spacer()
                            Text("\(item.count)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Recent Blocks")) {
                    ForEach(store.logs.prefix(50)) { log in
                        LogRow(log: log)
                    }
                }
            }
            .navigationTitle("Blocking Logs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { Task { await store.clearAllLogs() } }) {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }
}

struct LogRow: View {
    let log: BlockingLog
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.domain)
                    .font(.body)
                    .lineLimit(1)
                Spacer()
                Text(log.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text(log.ruleType.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("• \(log.action.rawValue)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct DailyTrendView: View {
    let data: [(date: String, count: UInt64)]
    
    var maxValue: UInt64 {
        data.map(\.count).max() ?? 1
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(data, id: \.date) { item in
                    VStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red.opacity(0.7))
                            .frame(height: maxValue > 0 ? CGFloat(item.count) / CGFloat(maxValue) * geometry.size.height * 0.8 : 0)
                        
                        Text(shortDate(item.date))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private func shortDate(_ dateString: String) -> String {
        let parts = dateString.split(separator: "-")
        guard parts.count == 3 else { return dateString }
        return "\(parts[1])-\(parts[2])"
    }
}
