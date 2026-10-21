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
                    Label("仪表盘", systemImage: "shield.fill")
                }
            
            RuleManagementView()
                .tabItem {
                    Label("规则", systemImage: "list.bullet")
                }
            
            WhitelistView()
                .tabItem {
                    Label("白名单", systemImage: "checkmark.shield")
                }
            
            BlockingLogView()
                .tabItem {
                    Label("日志", systemImage: "chart.bar.fill")
                }
            
            FeedbackListView()
                .tabItem {
                    Label("反馈", systemImage: "exclamationmark.bubble")
                }
        }
    }
}
