//
//  AppGroupPaths.swift
//  AdShield
//
//  Manages file paths within the App Group shared container.
//

import Foundation

public final class AppGroupPaths {
    
    public static let shared = AppGroupPaths()
    
    private let containerURL: URL
    
    private init() {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) {
            self.containerURL = url
        } else {
            // App Group unavailable (e.g., unsigned IPA installed via TrollStore, where the
            // re-signing entitlement set does not include our App Group). Fall back to the
            // app's own container so the app still launches; cross-process sharing with the
            // DNS extension is degraded until a real App Group is provisioned.
            print("AppGroupPaths: App Group unavailable (\(AppGroup.identifier)), falling back to local container")
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.containerURL = support.appendingPathComponent("AdShieldShared", isDirectory: true)
        }
    }
    
    /// Root URL of the App Group container.
    public var root: URL { containerURL }
    
    // MARK: - Directories
    
    public var rulesDirectory: URL {
        containerURL.appendingPathComponent(SharedFileNames.rulesDirectory, isDirectory: true)
    }
    
    public var whitelistDirectory: URL {
        containerURL.appendingPathComponent(SharedFileNames.whitelistDirectory, isDirectory: true)
    }
    
    public var feedbackDirectory: URL {
        containerURL.appendingPathComponent(SharedFileNames.feedbackDirectory, isDirectory: true)
    }
    
    public var logsDirectory: URL {
        containerURL.appendingPathComponent(SharedFileNames.logsDirectory, isDirectory: true)
    }
    
    public var configDirectory: URL {
        containerURL.appendingPathComponent(SharedFileNames.configDirectory, isDirectory: true)
    }
    
    public var whitelistBackupDirectory: URL {
        whitelistDirectory.appendingPathComponent(SharedFileNames.whitelistBackupDirectory, isDirectory: true)
    }
    
    // MARK: - Files
    
    public var bloomFilterFile: URL {
        rulesDirectory.appendingPathComponent(SharedFileNames.bloomFilterFile)
    }
    
    public var hashSetFile: URL {
        rulesDirectory.appendingPathComponent(SharedFileNames.hashSetFile)
    }
    
    public var whitelistFile: URL {
        whitelistDirectory.appendingPathComponent(SharedFileNames.whitelistFile)
    }
    
    public var whitelistVersionFile: URL {
        whitelistDirectory.appendingPathComponent(SharedFileNames.whitelistVersionFile)
    }
    
    public var whitelistChecksumFile: URL {
        whitelistDirectory.appendingPathComponent(SharedFileNames.whitelistChecksumFile)
    }
    
    public var whitelistReloadStatusFile: URL {
        whitelistDirectory.appendingPathComponent(SharedFileNames.whitelistReloadStatusFile)
    }
    
    public var configFile: URL {
        configDirectory.appendingPathComponent(SharedFileNames.configFile)
    }
    
    public var statsFile: URL {
        configDirectory.appendingPathComponent(SharedFileNames.statsFile)
    }
    
    // MARK: - Setup
    
    /// Creates all necessary directories if they don't exist.
    public func ensureDirectories() throws {
        let directories = [
            rulesDirectory,
            whitelistDirectory,
            feedbackDirectory,
            logsDirectory,
            configDirectory,
            whitelistBackupDirectory
        ]
        for dir in directories {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
    }
}
