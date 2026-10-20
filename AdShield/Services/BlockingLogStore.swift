//
//  BlockingLogStore.swift
//  AdShield
//
//  Local persistence for DNS blocking logs. No data leaves device.
//

import Foundation

@MainActor
public final class BlockingLogStore: ObservableObject {
    
    public static let shared = BlockingLogStore()
    
    @Published public private(set) var logs: [BlockingLog] = []
    @Published public private(set) var stats: BlockingStats
    
    private let logsURL: URL
    private let statsURL: URL
    private let maxLogDays = 7
    private let maxLogCount = 10_000
    
    private init() {
        let paths = AppGroupPaths.shared
        self.logsURL = paths.logsDirectory.appendingPathComponent("logs.json")
        self.statsURL = paths.configDirectory.appendingPathComponent("stats.json")
        self.stats = BlockingStats()
        Task {
            await load()
        }
    }
    
    // MARK: - Load / Save
    
    public func load() async {
        do {
            let logData = try Data(contentsOf: logsURL)
            logs = try JSONDecoder().decode([BlockingLog].self, from: logData)
        } catch {
            logs = []
        }
        
        do {
            let statsData = try Data(contentsOf: statsURL)
            stats = try JSONDecoder().decode(BlockingStats.self, from: statsData)
            stats.resetDailyIfNeeded()
        } catch {
            stats = BlockingStats()
        }
        
        await pruneOldLogs()
    }
    
    private func saveLogs() async {
        do {
            try FileManager.default.createDirectory(at: logsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(logs)
            try data.write(to: logsURL, options: .atomic)
        } catch {
            print("Failed to save logs: \(error)")
        }
    }
    
    private func saveStats() async {
        do {
            try FileManager.default.createDirectory(at: statsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(stats)
            try data.write(to: statsURL, options: .atomic)
        } catch {
            print("Failed to save stats: \(error)")
        }
    }
    
    // MARK: - Record
    
    public func record(domain: String, source: String, ruleType: BlockingLog.RuleType, action: BlockingLog.BlockAction = .nxdomain) async {
        let log = BlockingLog(domain: domain, source: source, ruleType: ruleType, action: action)
        logs.insert(log, at: 0)
        stats.recordBlock(domain: domain)
        
        // Prune if exceeding max count
        if logs.count > maxLogCount {
            logs = Array(logs.prefix(maxLogCount))
        }
        
        await saveLogs()
        await saveStats()
    }
    
    // MARK: - Query
    
    public func logsForLast(days: Int) -> [BlockingLog] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return logs.filter { $0.timestamp >= cutoff }
    }
    
    public func topDomains(limit: Int = 10) -> [(domain: String, count: UInt64)] {
        let sorted = stats.topDomains.sorted { $0.value > $1.value }
        return sorted.prefix(limit).map { (domain: $0.key, count: $0.value) }
    }
    
    public func dailyCountsForLast(days: Int) -> [(date: String, count: UInt64)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        var result: [(String, UInt64)] = []
        for dayOffset in (0..<days).reversed() {
            guard let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let key = formatter.string(from: date)
            let count = stats.dailyCounts[key] ?? 0
            result.append((key, count))
        }
        return result
    }
    
    // MARK: - Maintenance
    
    private func pruneOldLogs() async {
        let cutoff = Calendar.current.date(byAdding: .day, value: -maxLogDays, to: Date()) ?? Date()
        logs.removeAll { $0.timestamp < cutoff }
        await saveLogs()
    }
    
    public func clearAllLogs() async {
        logs.removeAll()
        stats = BlockingStats()
        await saveLogs()
        await saveStats()
    }
}
