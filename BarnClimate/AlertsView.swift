//
//  AlertsView.swift
//  BarnClimate
//
//  Screen 11/18 — Alerts & Notifications: warnings list with actions.
//

import SwiftUI

struct AlertsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: AppSettings

    enum Filter: String, CaseIterable, Identifiable {
        case active, unread, resolved
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }
    @State private var filter: Filter = .active

    private var shown: [ClimateAlert] {
        switch filter {
        case .active:   return store.alerts.filter { !$0.isResolved }
        case .unread:   return store.alerts.filter { !$0.isRead && !$0.isResolved }
        case .resolved: return store.alerts.filter { $0.isResolved }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        summary
                        filterPicker
                        if shown.isEmpty {
                            EmptyStateView(icon: "checkmark.seal.fill",
                                           title: "All clear",
                                           message: filter == .resolved
                                            ? "No resolved alerts yet."
                                            : "No active alerts. Your barns are healthy.")
                        } else {
                            ForEach(shown) { alert in
                                AlertRow(alert: alert, showActions: true)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 110)
                }
            }
            .navigationBarTitle("Alerts", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Mark all read") { withAnimation { store.markAllAlertsRead() } }
                        .font(.barn(14, .semibold))
                        .foregroundColor(Brand.greenDeep)
                        .disabled(store.unreadAlertCount == 0)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var summary: some View {
        AppCard {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(store.overallStatus.color.opacity(0.15)).frame(width: 64, height: 64)
                    Image(systemName: "bell.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(store.overallStatus.color)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(store.unreadAlertCount) unread")
                        .font(.barn(18, .bold)).foregroundColor(AppColor.text)
                    Text("\(store.alerts.filter { !$0.isResolved }.count) active • \(store.alerts.filter { $0.isResolved }.count) resolved")
                        .font(.barn(13, .medium)).foregroundColor(AppColor.textSecondary)
                }
                Spacer()
            }
        }
    }

    private var filterPicker: some View {
        HStack(spacing: 8) {
            ForEach(Filter.allCases) { f in
                SelectableChip(title: f.title, isSelected: filter == f, tint: Brand.greenDeep) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { filter = f }
                }
            }
        }
    }
}

// MARK: - Alert row

struct AlertRow: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: AppSettings
    let alert: ClimateAlert
    var showActions: Bool = false

    var body: some View {
        AppCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    IconBadge(systemName: alert.severity.icon, color: alert.severity.color, size: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(alert.title).font(.barn(15, .bold)).foregroundColor(AppColor.text)
                                .lineLimit(1)
                            if !alert.isRead && !alert.isResolved {
                                Circle().fill(Brand.critical).frame(width: 8, height: 8)
                            }
                        }
                        Text(alert.date, style: .relative)
                            .font(.barn(11, .medium)).foregroundColor(AppColor.textMuted)
                    }
                    Spacer()
                    if alert.isResolved {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(Brand.good)
                    }
                }
                Text(alert.message)
                    .font(.barn(13, .regular)).foregroundColor(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if showActions && !alert.isResolved {
                    HStack(spacing: 10) {
                        if !alert.isRead {
                            actionChip("Mark read", "envelope.open.fill", Brand.blue) {
                                withAnimation { store.markAlertRead(alert) }
                            }
                        }
                        actionChip("Resolve", "checkmark.circle.fill", Brand.good) {
                            withAnimation { store.resolveAlert(alert) }
                            Haptics.success(settings.hapticsEnabled)
                        }
                        Spacer()
                        Button {
                            withAnimation { store.deleteAlert(alert) }
                        } label: {
                            Image(systemName: "trash").foregroundColor(Brand.critical.opacity(0.8))
                        }
                    }
                }
            }
        }
        .onTapGesture {
            if !alert.isRead { store.markAlertRead(alert) }
        }
    }

    private func actionChip(_ title: String, _ icon: String, _ tint: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11, weight: .bold))
                Text(title).font(.barn(12, .semibold))
            }
            .foregroundColor(tint)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(tint.opacity(0.12)).clipShape(Capsule())
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.94))
    }
}
