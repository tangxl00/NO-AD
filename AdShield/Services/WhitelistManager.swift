//
//  WhitelistManager.swift
//  AdShield
//
//  Manages whitelist CRUD with atomic writes and hot-reload notification.
//

import Foundation
import Darwin
import Combine

@MainActor
public final class WhitelistManager: ObservableObject {
    
    public static let shared = WhitelistManager()
    
    @Published public private(set) var items: [WhitelistItem] = []
    @Published public private(set) var currentVersion: UInt64 = 0
    
    private let paths = AppGroupPaths.shared
    private var versionCounter: UInt64 = 0
    
    private init() {
        Task {
            await loadFromDisk()
        }
    }
    
    // MARK: - Load
    
    public func loadFromDisk() async {
        do {
            let data = try Data(contentsOf: paths.whitelistFile)
            let snapshot = try JSONDecoder().decode(WhitelistSnapshot.self, from: data)
            
            guard snapshot.verifyChecksum() else {
                print("Whitelist checksum mismatch, loading backup...")
                try await loadFromBackup()
                return
            }
            
            self.items = snapshot.items
            self.currentVersion = snapshot.version
            self.versionCounter = snapshot.version
        } catch {
            print("Failed to load whitelist: \(error)")
            // Initialize with built-in defaults if no whitelist exists
            if items.isEmpty {
                items = Self.builtinWhitelist()
                await persist()
            }
        }
    }
    
    private func loadFromBackup() async throws {
        let backupDir = paths.whitelistBackupDirectory
        let files = try FileManager.default.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        
        for file in files.prefix(3) {
            do {
                let data = try Data(contentsOf: file)
                let snapshot = try JSONDecoder().decode(WhitelistSnapshot.self, from: data)
                if snapshot.verifyChecksum() {
                    self.items = snapshot.items
                    self.currentVersion = snapshot.version
                    self.versionCounter = snapshot.version
                    return
                }
            } catch {
                continue
            }
        }
        
        // Fallback to built-in
        items = Self.builtinWhitelist()
        await persist()
    }
    
    // MARK: - CRUD
    
    public func add(domain: String, note: String? = nil) async {
        let normalized = domain.lowercased().trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty, !items.contains(where: { $0.domain == normalized }) else { return }
        
        let item = WhitelistItem(domain: normalized, source: .userManual, note: note)
        items.append(item)
        await persist()
    }
    
    public func remove(id: UUID) async {
        items.removeAll { $0.id == id }
        await persist()
    }
    
    public func remove(domain: String) async {
        let normalized = domain.lowercased()
        items.removeAll { $0.domain == normalized }
        await persist()
    }
    
    public func contains(domain: String) -> Bool {
        items.contains { $0.domain == domain.lowercased() }
    }
    
    // MARK: - Persistence (Atomic)
    
    public func persist() async {
        do {
            try paths.ensureDirectories()
            
            // Increment version
            versionCounter += 1
            let version = versionCounter
            
            // Create snapshot
            let snapshot = WhitelistSnapshot(version: version, items: items)
            
            // Backup current version
            await backupCurrentVersion()
            
            // Write atomically: tmp → rename
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            
            let tmpFile = paths.whitelistFile.appendingPathExtension("tmp")
            try data.write(to: tmpFile, options: .atomic)
            try FileManager.default.moveItem(at: tmpFile, to: paths.whitelistFile)
            
            // Write version file
            let versionString = "\(version)"
            try versionString.write(to: paths.whitelistVersionFile, atomically: true, encoding: .utf8)
            
            // Write checksum file
            try snapshot.checksum.write(to: paths.whitelistChecksumFile, atomically: true, encoding: .utf8)
            
            currentVersion = version
            
            // Notify extension via darwin_notify
            notifyExtension()
            
        } catch {
            print("Failed to persist whitelist: \(error)")
        }
    }
    
    private func backupCurrentVersion() async {
        do {
            let backupDir = paths.whitelistBackupDirectory
            try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
            
            if FileManager.default.fileExists(atPath: paths.whitelistFile.path) {
                let timestamp = ISO8601DateFormatter().string(from: Date())
                let backupFile = backupDir.appendingPathComponent("whitelist_\(timestamp).json")
                try FileManager.default.copyItem(at: paths.whitelistFile, to: backupFile)
                
                // Clean old backups (keep last 3)
                let files = try FileManager.default.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "json" }
                    .sorted { $0.lastPathComponent > $1.lastPathComponent }
                
                for file in files.dropFirst(3) {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        } catch {
            print("Backup failed: \(error)")
        }
    }
    
    private func notifyExtension() {
        // Darwin notify via CoreFoundation's Darwin notify center
        // (notify.h is not visible to Swift on iOS; CFNotificationCenter is the supported path)
        let name = CFNotificationName(rawValue: IPCNotification.whitelistChanged as CFString)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            name,
            nil,
            nil,
            true
        )
    }
    
    // MARK: - Built-in Defaults
    
    private static func builtinWhitelist() -> [WhitelistItem] {
        let domains = [
            "alipay.com",
            "alicdn.com",
            "alibaba.com",
            "taobao.com",
            "tmall.com",
            "wechat.com",
            "qq.com",
            "wx.qq.com",
            "apple.com",
            "icloud.com",
            "meituan.com",
            "dianping.com",
            "jd.com",
            "bilibili.com",
            "zhihu.com",
            "weibo.com",
            "gov.cn",
        ]
        return domains.map { WhitelistItem(domain: $0, source: .builtin, note: "Built-in protection") }
    }
}
