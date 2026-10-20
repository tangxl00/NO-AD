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
                        Text("Get Started")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                } else {
                    Button(action: { currentStep += 1 }) {
                        Text("Next")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                
                Button(action: { onboardingCompleted = true }) {
                    Text("Skip")
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
        case .welcome: return "Welcome to AdShield"
        case .howItWorks: return "How It Works"
        case .privacy: return "Privacy First"
        case .permissions: return "One More Step"
        }
    }
    
    var description: String {
        switch self {
        case .welcome:
            return "Block ads and trackers at the DNS level. Enjoy a cleaner, faster, and more private browsing experience on your iPhone."
        case .howItWorks:
            return "AdShield runs as a DNS proxy on your device. When an app tries to load an ad, we intercept the domain lookup and block it — before any content downloads."
        case .privacy:
            return "All filtering happens locally on your device. Your DNS queries never leave your phone for ad-blocking purposes. No accounts, no tracking, no data collection."
        case .permissions:
            return "iOS requires VPN permission to route DNS traffic. Don't worry — we're not a VPN. Your traffic doesn't go through remote servers. Tap Get Started to authorize."
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
