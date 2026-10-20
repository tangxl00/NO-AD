//
//  FeedbackStore.swift
//  AdShield
//
//  Local persistence for false-positive feedback using JSON file storage.
//  Rationale: JSON is sufficient for expected volume (< 1k records);
//  Core Data adds complexity without benefit at this scale.
//

import Foundation

@MainActor
public final class FeedbackStore: ObservableObject {
    
    public static let shared = FeedbackStore()
    
    @Published public private(set) var items: [FeedbackItem] = []
    
    private let storageURL: URL
    private let maxRetentionDays = 90
    
    private init() {
        let paths = AppGroupPaths.shared
        self.storageURL = paths.feedbackDirectory.appendingPathComponent("feedback.json")
        Task {
            await load()
        }
    }
    
    // MARK: - Load / Save
    
    public func load() async {
        do {
            let data = try Data(contentsOf: storageURL)
            let decoded = try JSONDecoder().decode([FeedbackItem].self, from: data)
            items = decoded
            await pruneOldRecords()
        } catch {
            items = []
        }
    }
    
    private func save() async {
        do {
            try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(items)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("Failed to save feedback: \(error)")
        }
    }
    
    // MARK: - CRUD
    
    public func add(domain: String,
                    source: FeedbackSource = .manualSubmit,
                    scenario: String? = nil,
                    reasonCategory: FeedbackReasonCategory? = nil,
                    deviceEnv: DeviceEnvironment? = nil) async {
        let normalized = domain.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Deduplication: same domain + source + day
        let newItem = FeedbackItem(
            domain: normalized,
            source: source,
            scenario: scenario,
            reasonCategory: reasonCategory,
            deviceEnv: deviceEnv
        )
        
        // Check for duplicate within 24h
        if items.contains(where: { $0.dedupKey == newItem.dedupKey }) {
            return
        }
        
        items.insert(newItem, at: 0)
        await save()
    }
    
    public func addFromLog(domain: String) async {
        await add(domain: domain, source: .autoFromLog)
    }
    
    public func updateStatus(id: UUID, status: FeedbackStatus, resolution: String? = nil) async {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = status
        if let resolution = resolution {
            items[index].resolution = resolution
        }
        await save()
    }
    
    public func whitelistAndResolve(id: UUID) async {
        guard let item = items.first(where: { $0.id == id }) else { return }
        await WhitelistManager.shared.add(domain: item.domain, note: "From feedback #\(id.uuidString.prefix(8))")
        await updateStatus(id: id, status: .whitelisted, resolution: "Added to whitelist")
    }
    
    public func ignore(id: UUID) async {
        await updateStatus(id: id, status: .ignored, resolution: "Confirmed as ad domain")
    }
    
    public func reportUpstream(id: UUID) async {
        await updateStatus(id: id, status: .reportedUpstream, resolution: "Submitted to anti-AD upstream")
    }
    
    public func delete(id: UUID) async {
        items.removeAll { $0.id == id }
        await save()
    }
    
    // MARK: - Sync with Rule Updates
    
    /// Checks if domains in "pending" or "reported_upstream" status have been removed from rules.
    public func syncWithRuleUpdate() async {
        // This would check against the current rule set.
        // Simplified: mark resolved if domain is no longer in active rules.
        // Actual implementation would load the hash set and check membership.
        for (index, item) in items.enumerated() where item.status == .reportedUpstream {
            // Placeholder: in production, check if domain still in rule set
            // If removed, update status to resolved
            let isStillBlocked = await checkDomainInRules(item.domain)
            if !isStillBlocked {
                items[index].status = .resolved
                items[index].resolution = "Domain removed from rule set in latest update"
            }
        }
        await save()
    }
    
    private func checkDomainInRules(_ domain: String) async -> Bool {
        // Would load the compiled hash set and check membership
        // Returning true as placeholder
        return true
    }
    
    // MARK: - Maintenance
    
    private func pruneOldRecords() async {
        let cutoff = Calendar.current.date(byAdding: .day, value: -maxRetentionDays, to: Date()) ?? Date()
        items.removeAll { item in
            (item.status == .ignored || item.status == .resolved) && item.timestamp < cutoff
        }
        await save()
    }
    
    public func clearAllHistory() async {
        items.removeAll()
        await save()
    }
}
