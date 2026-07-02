//
//  MainTabView.swift
//  BarnClimate
//
//  Custom themed tab bar hosting the five primary sections.
//

import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case dashboard, climate, sensors, alerts, reports
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Home"
        case .climate:   return "Climate"
        case .sensors:   return "Sensors"
        case .alerts:    return "Alerts"
        case .reports:   return "Reports"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .climate:   return "thermometer"
        case .sensors:   return "gauge"
        case .alerts:    return "bell.fill"
        case .reports:   return "chart.bar.fill"
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var store: AppStore
    @State private var tab: AppTab = MainTabView.initialTab

    // Lets QA screenshots open a specific tab via an env var; .dashboard otherwise.
    private static var initialTab: AppTab {
        if let raw = ProcessInfo.processInfo.environment["UITEST_TAB"] {
            switch raw {
            case "climate": return .climate
            case "sensors": return .sensors
            case "alerts":  return .alerts
            case "reports": return .reports
            default:        return .dashboard
            }
        }
        return .dashboard
    }

    // QA-only: lets a screenshot launch open Settings / a form directly. No effect in normal use.
    @State private var qaScreen: String? = ProcessInfo.processInfo.environment["UITEST_SCREEN"]

    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackground()

            Group {
                switch tab {
                case .dashboard: DashboardView(switchTab: { tab = $0 })
                case .climate:   ClimateView()
                case .sensors:   SensorsView()
                case .alerts:    AlertsView()
                case .reports:   ReportsView()
                }
            }
            .transition(.opacity)

            customTabBar
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: Binding(get: { qaScreen != nil }, set: { if !$0 { qaScreen = nil } })) {
            qaSheet
        }
    }

    @ViewBuilder
    private var qaSheet: some View {
        switch qaScreen {
        case "settings": NavigationView { SettingsView() }.navigationViewStyle(StackNavigationViewStyle())
        case "addroom":  AddRoomView()
        case "addrecord": AddRecordView()
        default: EmptyView()
        }
    }

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(AppTab.allCases.enumerated()), id: \.element.id) { idx, item in
                tabButton(item)
                if idx < AppTab.allCases.count - 1 { Spacer(minLength: 0) }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            AppColor.surface
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .shadow(color: Color.black.opacity(0.10), radius: 16, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(AppColor.separator, lineWidth: 1)
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }

    private func tabButton(_ item: AppTab) -> some View {
        let isSelected = tab == item
        return Button {
            Haptics.tap(true)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { tab = item }
        } label: {
            HStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: item.icon)
                        .font(.system(size: 17, weight: .semibold))
                    if item == .alerts && store.unreadAlertCount > 0 {
                        Circle().fill(Brand.critical)
                            .frame(width: 9, height: 9)
                            .offset(x: 6, y: -5)
                    }
                }
                if isSelected {
                    Text(item.title)
                        .font(.barn(13, .bold))
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .foregroundColor(isSelected ? .white : AppColor.textMuted)
            .padding(.horizontal, isSelected ? 16 : 11)
            .padding(.vertical, 9)
            .background(tabBackground(isSelected))
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.9))
    }

    @ViewBuilder
    private func tabBackground(_ isSelected: Bool) -> some View {
        if isSelected {
            Capsule()
                .fill(AppGradient.primaryButton)
                .shadow(color: Brand.green.opacity(0.4), radius: 8, x: 0, y: 4)
        } else {
            Color.clear
        }
    }
}
