//
//  ContentView.swift
//  AdShield
//
//  Main tab view hosting all feature screens.
//

import SwiftUI

struct ContentView: View {
    
    @AppStorage(UserDefaultsKeys.onboardingCompleted) private var onboardingCompleted = false
    
    var body: some View {
        Group {
            if onboardingCompleted {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
    }
}

struct MainTabView: View {
    
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "shield.fill")
                }
            
            RuleManagementView()
                .tabItem {
                    Label("Rules", systemImage: "list.bullet")
                }
            
            WhitelistView()
                .tabItem {
                    Label("Whitelist", systemImage: "checkmark.shield")
                }
            
            BlockingLogView()
                .tabItem {
                    Label("Logs", systemImage: "chart.bar.fill")
                }
            
            FeedbackListView()
                .tabItem {
                    Label("Feedback", systemImage: "exclamationmark.bubble")
                }
        }
    }
}
