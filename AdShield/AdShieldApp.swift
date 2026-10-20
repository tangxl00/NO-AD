//
//  AdShieldApp.swift
//  AdShield
//
//  Main app entry point.
//

import SwiftUI

@main
struct AdShieldApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Ensure App Group directories exist
        do {
            try AppGroupPaths.shared.ensureDirectories()
        } catch {
            print("Failed to setup directories: \(error)")
        }
        
        // Register background refresh task for rule updates
        registerBackgroundTasks()
        
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleBackgroundRuleUpdate()
    }
    
    // MARK: - Background Tasks
    
    private func registerBackgroundTasks() {
        // BGAppRefreshTask would be registered here on iOS 13+
        // Simplified for iOS 15+ target
    }
    
    private func scheduleBackgroundRuleUpdate() {
        // Schedule daily background rule check
        // Implementation depends on BGTaskScheduler API
    }
}
