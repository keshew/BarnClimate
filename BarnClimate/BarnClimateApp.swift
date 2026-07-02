//
//  BarnClimateApp.swift
//  BarnClimate
//
//  Entry point. Flow: Splash -> Onboarding (first launch only) -> Main App.
//  No login / welcome / account screens — the app opens straight into content.
//

import SwiftUI

@main
struct BarnClimateApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var store = AppStore()

    init() {
        // Transparent, themed navigation bars across the app.
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        let titleColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: "ECFDF5") : UIColor(hex: "064E3B")
        }
        appearance.titleTextAttributes = [
            .foregroundColor: titleColor,
            .font: UIFont.systemFont(ofSize: 17, weight: .bold)
        ]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(hex: "16A34A")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(store)
                .preferredColorScheme(settings.colorScheme)
                .accentColor(Brand.greenDeep)
        }
    }
}

// MARK: - Root flow controller

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var stage: Stage = .splash

    enum Stage { case splash, onboarding, main }

    var body: some View {
        ZStack {
            switch stage {
            case .splash:
                LaunchView { afterSplash() }
                    .transition(.opacity)
            case .onboarding:
                OnboardingView { completeOnboarding() }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .main:
                MainTabView()
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.85), value: stage)
    }

    private func afterSplash() {
        stage = hasCompletedOnboarding ? .main : .onboarding
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        stage = .main
    }
}
