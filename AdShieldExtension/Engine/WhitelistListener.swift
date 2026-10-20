//
//  WhitelistListener.swift
//  AdShieldExtension
//
//  Listens for whitelist changes via darwin_notify, file watcher, and polling fallback.
//  Uses double-buffer for atomic hot-reload without blocking DNS queries.
//

import Foundation
import Darwin

protocol WhitelistListenerDelegate: AnyObject {
    func whitelistDidUpdate(_ items: [WhitelistItem])
}

final class WhitelistListener {
    
    weak var delegate: WhitelistListenerDelegate?
    
    private var filePresenter: WhitelistFilePresenter?
    private var pollTimer: Timer?
    private var lastVersion: UInt64 = 0
    private let pollInterval: TimeInterval = 5.0
    
    private let paths = AppGroupPaths.shared
    
    init(delegate: WhitelistListenerDelegate) {
        self.delegate = delegate
        startListening()
    }
    
    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        filePresenter = nil
    }
    
    // MARK: - Listening
    
    private func startListening() {
        // Primary: darwin_notify registration
        registerDarwinNotify()
        
        // Secondary: FilePresenter
        setupFilePresenter()
        
        // Fallback: polling
        startPolling()
    }
    
    private func registerDarwinNotify() {
        let notificationName = IPCNotification.whitelistChanged
        let token = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
        
        let status = notify_register_check(notificationName, token)
        guard status == NOTIFY_STATUS_OK else {
            print("Failed to register darwin notify: \(status)")
            return
        }
        
        // Set up dispatch source for notifications
        var notifyToken: Int32 = 0
        let regStatus = notify_register_dispatch(notificationName, &notifyToken, DispatchQueue.global()) { [weak self] _ in
            self?.handleWhitelistChanged()
        }
        
        if regStatus != NOTIFY_STATUS_OK {
            print("notify_register_dispatch failed: \(regStatus)")
        }
    }
    
    private func setupFilePresenter() {
        filePresenter = WhitelistFilePresenter(delegate: self)
        if let presenter = filePresenter {
            NSFileCoordinator.addFilePresenter(presenter)
        }
    }
    
    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.checkVersionFile()
        }
    }
    
    // MARK: - Change Detection
    
    private func checkVersionFile() {
        do {
            let versionString = try String(contentsOf: paths.whitelistVersionFile, encoding: .utf8)
            guard let version = UInt64(versionString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
            
            if version > lastVersion {
                lastVersion = version
                handleWhitelistChanged()
            }
        } catch {
            // Version file may not exist yet
        }
    }
    
    private func handleWhitelistChanged() {
        do {
            let data = try Data(contentsOf: paths.whitelistFile)
            let snapshot = try JSONDecoder().decode(WhitelistSnapshot.self, from: data)
            
            guard snapshot.verifyChecksum() else {
                print("Whitelist checksum mismatch, ignoring update")
                writeReloadStatus(success: false, error: "checksum_mismatch")
                return
            }
            
            // Update version tracking
            lastVersion = snapshot.version
            
            // Notify delegate with new whitelist items
            delegate?.whitelistDidUpdate(snapshot.items)
            
            writeReloadStatus(success: true)
            
        } catch {
            print("Failed to reload whitelist: \(error)")
            writeReloadStatus(success: false, error: error.localizedDescription)
        }
    }
    
    private func writeReloadStatus(success: Bool, error: String? = nil) {
        let status = WhitelistReloadStatus(success: success, timestamp: Date(), error: error)
        do {
            let data = try JSONEncoder().encode(status)
            try data.write(to: paths.whitelistReloadStatusFile, options: .atomic)
        } catch {
            print("Failed to write reload status: \(error)")
        }
    }
}

// MARK: - FilePresenter

class WhitelistFilePresenter: NSObject, NSFilePresenter {
    
    weak var delegate: WhitelistListener?
    
    var presentedItemURL: URL? {
        AppGroupPaths.shared.whitelistFile
    }
    
    var presentedItemOperationQueue: OperationQueue {
        OperationQueue.main
    }
    
    init(delegate: WhitelistListener) {
        self.delegate = delegate
    }
    
    func presentedItemDidChange() {
        delegate?.reloadWhitelistFromDisk()
    }
}

// MARK: - WhitelistReloadStatus

struct WhitelistReloadStatus: Codable {
    let success: Bool
    let timestamp: Date
    let error: String?
}

// MARK: - WhitelistListener Extension

extension WhitelistListener {
    /// Exposed for FilePresenter callback. Delegates to the internal reload logic.
    func reloadWhitelistFromDisk() {
        self.handleWhitelistChanged()
    }
}
