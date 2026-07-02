//
//  DashboardView.swift
//  BarnClimate
//
//  Screen 6 — Dashboard: Main stats, Tasks, Warnings, Quick actions.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: AppSettings
    var switchTab: (AppTab) -> Void

    @State private var showAddRecord = false
    @State private var showAddRoom = false

    var body: some View {
        NavigationView {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        overallCard
                        mainStats
                        quickActions
                        warningsSection
                        tasksSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 110)
                }
            }
            .navigationBarTitle("Dashboard", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape.fill").foregroundColor(Brand.greenDeep)
                    }
                }
            }
            .sheet(isPresented: $showAddRecord) { AddRecordView() }
            .sheet(isPresented: $showAddRoom) { AddRoomView() }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.barn(15, .medium))
                .foregroundColor(AppColor.textSecondary)
            Text(settings.farmName)
                .font(.barn(28, .heavy))
                .foregroundColor(AppColor.text)
        }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Good morning,"
        case 12..<17: return "Good afternoon,"
        case 17..<22: return "Good evening,"
        default: return "Hello,"
        }
    }

    // MARK: Overall status hero

    private var overallCard: some View {
        let status = store.overallStatus
        return AppCard {
            HStack(spacing: 16) {
                RingGauge(progress: comfortScore,
                          color: status.color,
                          label: "\(Int(comfortScore * 100))%",
                          caption: "Comfort")
                    .frame(width: 96, height: 96)
                VStack(alignment: .leading, spacing: 8) {
                    StatusPill(status: status)
                    Text(headline(for: status))
                        .font(.barn(16, .bold))
                        .foregroundColor(AppColor.text)
                    Text("\(store.rooms.count) zones monitored • \(store.statusCount(.critical)) critical")
                        .font(.barn(13, .medium))
                        .foregroundColor(AppColor.textSecondary)
                }
                Spacer()
            }
        }
    }

    private var comfortScore: Double {
        guard !store.rooms.isEmpty else { return 1 }
        let good = Double(store.statusCount(.good))
        let warn = Double(store.statusCount(.warning))
        return ((good + warn * 0.5) / Double(store.rooms.count)).clamped(to: 0...1)
    }

    private func headline(for status: ClimateStatus) -> String {
        switch status {
        case .good: return "All barns are comfortable"
        case .warning: return "Some zones need a look"
        case .critical: return "Action needed in a zone"
        }
    }

    // MARK: Main stats

    private var mainStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Main stats")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                      spacing: 12) {
                StatTile(title: "Avg temperature",
                         value: settings.temperatureText(store.averageTemperature),
                         icon: "thermometer", tint: Brand.critical,
                         trend: "1.2°", trendUp: true)
                StatTile(title: "Avg humidity",
                         value: String(format: "%.0f%%", store.averageHumidity),
                         icon: "drop.fill", tint: Brand.blue,
                         trend: "3%", trendUp: false)
                StatTile(title: "Ventilation",
                         value: String(format: "%.0f%%", store.averageVentilation),
                         icon: "wind", tint: Brand.cyan,
                         trend: "5%", trendUp: true)
                StatTile(title: "Active zones",
                         value: "\(store.rooms.count)",
                         icon: "square.grid.2x2.fill", tint: Brand.green)
            }
        }
    }

    // MARK: Quick actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Quick actions")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)],
                      spacing: 12) {
                actionButton("Add record", "plus.circle.fill", Brand.green) { showAddRecord = true }
                actionButton("Add zone", "house.fill", Brand.greenDeep) { showAddRoom = true }
                actionButton("Climate", "thermometer", Brand.critical) { switchTab(.climate) }
                NavigationLink(destination: TasksView()) {
                    quickTile("Tasks", "list.bullet.rectangle", Brand.yellowDeep)
                }.buttonStyle(ScaleButtonStyle())
                NavigationLink(destination: RecommendationsView()) {
                    quickTile("Tips", "lightbulb.fill", Brand.yellow)
                }.buttonStyle(ScaleButtonStyle())
                NavigationLink(destination: CalendarView()) {
                    quickTile("Calendar", "calendar", Brand.blue)
                }.buttonStyle(ScaleButtonStyle())
            }
        }
    }

    private func actionButton(_ title: String, _ icon: String, _ tint: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { quickTile(title, icon, tint) }
            .buttonStyle(ScaleButtonStyle())
    }

    private func quickTile(_ title: String, _ icon: String, _ tint: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(LinearGradient(colors: [tint, tint.opacity(0.7)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text(title).font(.barn(12, .semibold)).foregroundColor(AppColor.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AppColor.separator, lineWidth: 1))
    }

    // MARK: Warnings

    private var warningsSection: some View {
        let active = store.alerts.filter { !$0.isResolved }.prefix(3)
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Warnings", actionTitle: active.isEmpty ? nil : "See all") {
                switchTab(.alerts)
            }
            if active.isEmpty {
                AppCard {
                    HStack(spacing: 12) {
                        IconBadge(systemName: "checkmark.seal.fill", color: Brand.good)
                        Text("No active warnings. Everything looks healthy.")
                            .font(.barn(14, .medium)).foregroundColor(AppColor.textSecondary)
                        Spacer()
                    }
                }
            } else {
                ForEach(Array(active)) { alert in
                    AlertRow(alert: alert)
                }
            }
        }
    }

    // MARK: Tasks

    private var tasksSection: some View {
        let pending = store.pendingTasks.prefix(3)
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Tasks")
            if pending.isEmpty {
                AppCard {
                    HStack(spacing: 12) {
                        IconBadge(systemName: "list.bullet.rectangle", color: Brand.green)
                        Text("No pending tasks. Nice work!")
                            .font(.barn(14, .medium)).foregroundColor(AppColor.textSecondary)
                        Spacer()
                    }
                }
            } else {
                ForEach(Array(pending)) { task in
                    TaskRow(task: task)
                }
                NavigationLink(destination: TasksView()) {
                    Text("View all tasks")
                        .font(.barn(14, .semibold))
                        .foregroundColor(Brand.greenDeep)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
        }
    }
}
