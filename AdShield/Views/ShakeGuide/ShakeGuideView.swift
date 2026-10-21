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
            appName: "微博",
            steps: [
                "进入「我」的页面",
                "点击「设置」（齿轮图标）",
                "点击「隐私设置」",
                "关闭「摇一摇广告」"
            ]
        ),
        AppGuide(
            appName: "知乎",
            steps: [
                "进入「我的」页面",
                "点击「设置」",
                "点击「隐私」",
                "关闭「摇一摇打开」"
            ]
        ),
        AppGuide(
            appName: "哔哩哔哩",
            steps: [
                "进入「我的」页面",
                "点击「设置」",
                "点击「隐私设置」",
                "关闭「摇一摇广告」"
            ]
        ),
        AppGuide(
            appName: "淘宝",
            steps: [
                "进入「我的淘宝」",
                "点击「设置」",
                "点击「隐私」",
                "关闭「摇一摇互动」"
            ]
        ),
        AppGuide(
            appName: "京东",
            steps: [
                "进入「我的」页面",
                "点击「设置」",
                "点击「通用」",
                "关闭「摇一摇打开」"
            ]
        ),
        AppGuide(
            appName: "美团",
            steps: [
                "进入「我的」页面",
                "点击「设置」",
                "点击「隐私管理」",
                "关闭「摇一摇广告」"
            ]
        ),
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("AdShield 能阻止广告内容加载，但无法阻止应用检测摇一摇手势本身。以下是常见应用关闭「摇一摇开屏广告」的方法。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("应用指南")) {
                    ForEach(guides) { guide in
                        AppGuideRow(guide: guide)
                    }
                }
                
                Section {
                    Text("注意：应用设置可能随版本更新变化。如果路径已过时，请在应用的最新设置菜单中查找。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("摇一摇广告指南")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
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
