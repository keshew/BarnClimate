//
//  ReportsView.swift
//  BarnClimate
//
//  Screen 15 — Reports (analytics) + links to Trends (16) and History (17).
//

import SwiftUI

struct ReportsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: AppSettings
    @State private var showShare = false

    var body: some View {
        NavigationView {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        overviewCard
                        statusBreakdown
                        averagesCard
                        categoryCard
                        navLinks
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 110)
                }
            }
            .navigationBarTitle("Reports", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showShare = true } label: {
                        Image(systemName: "square.and.arrow.up").foregroundColor(Brand.greenDeep)
                    }
                }
            }
            .sheet(isPresented: $showShare) { ShareSheet(items: [summaryText]) }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var overviewCard: some View {
        AppCard {
            HStack(spacing: 16) {
                RingGauge(progress: comfort, color: store.overallStatus.color,
                          label: "\(Int(comfort * 100))%", caption: "Comfort")
                    .frame(width: 100, height: 100)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Farm health").font(.barn(17, .bold)).foregroundColor(AppColor.text)
                    StatusPill(status: store.overallStatus)
                    Text("\(store.rooms.count) zones • \(store.alerts.filter { !$0.isResolved }.count) open alerts")
                        .font(.barn(12, .medium)).foregroundColor(AppColor.textSecondary)
                }
                Spacer()
            }
        }
    }

    private var statusBreakdown: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Status breakdown").font(.barn(16, .bold)).foregroundColor(AppColor.text)
                HStack(spacing: 20) {
                    StatusDonut(good: store.statusCount(.good),
                                warning: store.statusCount(.warning),
                                critical: store.statusCount(.critical))
                        .frame(width: 120, height: 120)
                    VStack(alignment: .leading, spacing: 10) {
                        legendRow(.good, store.statusCount(.good))
                        legendRow(.warning, store.statusCount(.warning))
                        legendRow(.critical, store.statusCount(.critical))
                    }
                    Spacer()
                }
            }
        }
    }

    private func legendRow(_ status: ClimateStatus, _ count: Int) -> some View {
        HStack(spacing: 8) {
            Circle().fill(status.color).frame(width: 12, height: 12)
            Text(status.title).font(.barn(13, .medium)).foregroundColor(AppColor.text)
            Spacer()
            Text("\(count)").font(.barn(14, .bold)).foregroundColor(AppColor.text)
        }
    }

    private var averagesCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Averages").font(.barn(16, .bold)).foregroundColor(AppColor.text)
                MetricRow(metric: .temperature,
                          valueText: settings.temperatureText(store.averageTemperature),
                          progress: (store.averageTemperature + 5) / 45)
                MetricRow(metric: .humidity,
                          valueText: String(format: "%.0f%%", store.averageHumidity),
                          progress: store.averageHumidity / 100)
                MetricRow(metric: .ventilation,
                          valueText: String(format: "%.0f%%", store.averageVentilation),
                          progress: store.averageVentilation / 100)
            }
        }
    }

    private var categoryCard: some View {
        let cats = RoomCategory.allCases.filter { cat in store.rooms.contains { $0.category == cat } }
        return AppCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Temperature by zone").font(.barn(16, .bold)).foregroundColor(AppColor.text)
                if store.rooms.isEmpty {
                    Text("No zones to report yet.").font(.barn(13, .medium)).foregroundColor(AppColor.textSecondary)
                } else {
                    BarChart(values: store.rooms.map { settings.tempUnit.value(fromCelsius: $0.temperature) },
                             labels: store.rooms.map { String($0.name.prefix(4)) },
                             color: Brand.green)
                        .frame(height: 150)
                }
                if !cats.isEmpty {
                    Text("\(cats.count) categories monitored")
                        .font(.barn(12, .medium)).foregroundColor(AppColor.textMuted)
                }
            }
        }
    }

    private var navLinks: some View {
        VStack(spacing: 12) {
            NavigationLink(destination: TrendsView()) {
                reportLink("Trends", "Graphs and changes over time", "waveform.path.ecg", Brand.blue)
            }.buttonStyle(ScaleButtonStyle(scale: 0.98))
            NavigationLink(destination: HistoryView()) {
                reportLink("History", "Full log of records and events", "clock.arrow.circlepath", Brand.yellowDeep)
            }.buttonStyle(ScaleButtonStyle(scale: 0.98))
        }
    }

    private func reportLink(_ title: String, _ subtitle: String, _ icon: String, _ tint: Color) -> some View {
        AppCard {
            HStack(spacing: 14) {
                IconBadge(systemName: icon, color: tint, size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.barn(16, .bold)).foregroundColor(AppColor.text)
                    Text(subtitle).font(.barn(12, .medium)).foregroundColor(AppColor.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(AppColor.textMuted)
            }
        }
    }

    private var comfort: Double {
        guard !store.rooms.isEmpty else { return 1 }
        let good = Double(store.statusCount(.good))
        let warn = Double(store.statusCount(.warning))
        return ((good + warn * 0.5) / Double(store.rooms.count)).clamped(to: 0...1)
    }

    private var summaryText: String {
        var lines = ["BarnClimate report — \(settings.farmName)"]
        lines.append("Overall status: \(store.overallStatus.title)")
        lines.append(String(format: "Avg temperature: %@", settings.temperatureText(store.averageTemperature)))
        lines.append(String(format: "Avg humidity: %.0f%%", store.averageHumidity))
        lines.append(String(format: "Avg ventilation: %.0f%%", store.averageVentilation))
        lines.append("Zones: \(store.rooms.count) (\(store.statusCount(.good)) good, \(store.statusCount(.warning)) warning, \(store.statusCount(.critical)) critical)")
        lines.append("Open alerts: \(store.alerts.filter { !$0.isResolved }.count)")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Trends (Screen 16)

struct TrendsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: AppSettings
    @State private var metric: ReadingMetric = .temperature

    private var series: [Double] {
        let raw = store.aggregatedSeries(for: metric)
        return metric == .temperature ? raw.map { settings.tempUnit.value(fromCelsius: $0) } : raw
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("", selection: $metric) {
                        ForEach(ReadingMetric.allCases) { m in Text(m.title).tag(m) }
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    AppCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label {
                                    Text("Farm-wide \(metric.title.lowercased())").font(.barn(14, .semibold))
                                        .foregroundColor(AppColor.text)
                                } icon: { Image(systemName: metric.icon).foregroundColor(metric.tint) }
                                Spacer()
                                Text(changeText).font(.barn(14, .bold)).foregroundColor(changeColor)
                            }
                            if series.isEmpty {
                                Text("Not enough data yet.").font(.barn(13, .medium))
                                    .foregroundColor(AppColor.textSecondary).frame(height: 180)
                            } else {
                                LineAreaChart(values: series, color: metric.tint).frame(height: 180).id(metric)
                            }
                        }
                    }

                    AppCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Current by zone").font(.barn(16, .bold)).foregroundColor(AppColor.text)
                            BarChart(values: store.rooms.map { zoneValue($0) },
                                     labels: store.rooms.map { String($0.name.prefix(4)) },
                                     color: metric.tint)
                                .frame(height: 150)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitle("Trends", displayMode: .inline)
    }

    private func zoneValue(_ room: Room) -> Double {
        switch metric {
        case .temperature: return settings.tempUnit.value(fromCelsius: room.temperature)
        case .humidity:    return room.humidity
        case .ventilation: return room.ventilation
        }
    }

    private var changeText: String {
        guard let first = series.first, let last = series.last, series.count > 1 else { return "—" }
        let delta = last - first
        let sign = delta >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", delta))"
    }
    private var changeColor: Color {
        guard let first = series.first, let last = series.last else { return AppColor.textSecondary }
        return last >= first ? Brand.good : Brand.critical
    }
}

// MARK: - History (Screen 17)

struct HistoryView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: AppSettings

    private var records: [ClimateRecord] {
        store.records.sorted { $0.date > $1.date }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    summary
                    if records.isEmpty && store.alerts.filter({ $0.isResolved }).isEmpty {
                        EmptyStateView(icon: "clock.arrow.circlepath",
                                       title: "No history yet",
                                       message: "Logged records and resolved alerts will appear here.")
                    } else {
                        if !records.isEmpty {
                            Text("Records").font(.barn(18, .bold)).foregroundColor(AppColor.text)
                            ForEach(records) { rec in RecordRow(record: rec) }
                        }
                        let resolved = store.alerts.filter { $0.isResolved }
                        if !resolved.isEmpty {
                            Text("Resolved alerts").font(.barn(18, .bold)).foregroundColor(AppColor.text)
                                .padding(.top, 6)
                            ForEach(resolved) { alert in AlertRow(alert: alert) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitle("History", displayMode: .inline)
    }

    private var summary: some View {
        AppCard {
            HStack(spacing: 14) {
                IconBadge(systemName: "clock.arrow.circlepath", color: Brand.yellowDeep, size: 50)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(records.count) records logged").font(.barn(16, .bold)).foregroundColor(AppColor.text)
                    Text("\(store.alerts.filter { $0.isResolved }.count) alerts resolved • \(store.completedTasks.count) tasks done")
                        .font(.barn(12, .medium)).foregroundColor(AppColor.textSecondary)
                }
                Spacer()
            }
        }
    }
}
