//
//  OnboardingView.swift
//  AdShield
//
//  First-launch guided setup for DNS proxy authorization.
//

import SwiftUI

struct OnboardingView: View {
    
    @AppStorage(UserDefaultsKeys.onboardingCompleted) private var onboardingCompleted = false
    @State private var currentStep = 0
    
    private let steps = OnboardingStep.allCases
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentStep) {
                ForEach(0..<steps.count, id: \.self) { index in
                    OnboardingStepView(step: steps[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            VStack(spacing: 16) {
                if currentStep == steps.count - 1 {
                    Button(action: completeOnboarding) {
                        Text("开始使用")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                } else {
                    Button(action: { currentStep += 1 }) {
                        Text("下一步")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                
                Button(action: { onboardingCompleted = true }) {
                    Text("跳过")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }
    
    private func completeOnboarding() {
        onboardingCompleted = true
        Task {
            await DNSProxyManager.shared.installAndEnable()
        }
    }
}

enum OnboardingStep: CaseIterable {
    case welcome
    case howItWorks
    case privacy
    case permissions
    
    var title: String {
        switch self {
        case .welcome: return "欢迎使用 AdShield"
        case .howItWorks: return "工作原理"
        case .privacy: return "隐私优先"
        case .permissions: return "最后一步"
        }
    }
    
    var description: String {
        switch self {
        case .welcome:
            return "在 DNS 层面拦截广告和跟踪器，让你的 iPhone 浏览体验更干净、更快速、更私密。"
        case .howItWorks:
            return "AdShield 在你的设备上以 DNS 代理方式运行。当应用尝试加载广告时，我们会在域名解析阶段直接拦截——内容还没开始下载就已被阻止。"
        case .privacy:
            return "所有过滤都在你的设备本地完成，用于广告拦截的 DNS 查询不会离开手机。无账号、无跟踪、无数据收集。"
        case .permissions:
            return "iOS 需要 VPN 权限来接管 DNS 流量。别担心——我们并不是真正的 VPN，你的流量不会经过任何远程服务器。点击「开始使用」完成授权。"
        }
    }
    
    var icon: String {
        switch self {
        case .welcome: return "shield.fill"
        case .howItWorks: return "network"
        case .privacy: return "lock.fill"
        case .permissions: return "checkmark.shield"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .welcome: return .green
        case .howItWorks: return .blue
        case .privacy: return .orange
        case .permissions: return .purple
        }
    }
}

struct OnboardingStepView: View {
    let step: OnboardingStep
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: step.icon)
                .font(.system(size: 100))
                .foregroundColor(step.iconColor)
            
            VStack(spacing: 16) {
                Text(step.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(step.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            Spacer()
        }
    }
}
