//
//  ShakeGuideView.swift
//  AdShield
//
//  Guide for disabling shake-to-ad in common Chinese apps.
//

import SwiftUI

struct ShakeGuideView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    private let guides: [AppGuide] = [
        AppGuide(
            appName: "Weibo",
            steps: [
                "Go to Me tab",
                "Tap Settings (gear icon)",
                "Tap Privacy Settings",
                "Turn off 'Shake to open ad'"
            ]
        ),
        AppGuide(
            appName: "Zhihu",
            steps: [
                "Go to My tab",
                "Tap Settings",
                "Tap Privacy",
                "Turn off 'Shake to open'"
            ]
        ),
        AppGuide(
            appName: "Bilibili",
            steps: [
                "Go to My tab",
                "Tap Settings",
                "Tap Privacy Settings",
                "Turn off 'Shake ad'"
            ]
        ),
        AppGuide(
            appName: "Taobao",
            steps: [
                "Go to My Taobao",
                "Tap Settings",
                "Tap Privacy",
                "Turn off 'Shake to interact'"
            ]
        ),
        AppGuide(
            appName: "JD",
            steps: [
                "Go to My tab",
                "Tap Settings",
                "Tap General",
                "Turn off 'Shake to open'"
            ]
        ),
        AppGuide(
            appName: "Meituan",
            steps: [
                "Go to My tab",
                "Tap Settings",
                "Tap Privacy Management",
                "Turn off 'Shake ad'"
            ]
        ),
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("While AdShield blocks ad content from loading, it cannot prevent the shake gesture itself from being detected by apps. Here is how to disable shake-to-ad in popular apps.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("App Guides")) {
                    ForEach(guides) { guide in
                        AppGuideRow(guide: guide)
                    }
                }
                
                Section {
                    Text("Note: App settings may change with updates. If a path is outdated, please check the app's latest settings menu.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Shake Ad Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct AppGuide: Identifiable {
    let id = UUID()
    let appName: String
    let steps: [String]
}

struct AppGuideRow: View {
    let guide: AppGuide
    @State private var isExpanded = false
    
    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded,
            content: {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(guide.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Color.blue)
                                .cornerRadius(10)
                            
                            Text(step)
                                .font(.subheadline)
                        }
                    }
                }
                .padding(.vertical, 8)
            },
            label: {
                Text(guide.appName)
                    .font(.headline)
            }
        )
    }
}
