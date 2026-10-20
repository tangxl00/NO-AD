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
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) else {
            fatalError("Failed to access App Group container: \(AppGroup.identifier). Ensure App Group capability is configured.")
        }
        self.containerURL = url
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
