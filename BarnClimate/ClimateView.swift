//
//  ClimateView.swift
//  BarnClimate
//
//  Screen 9 — Climate Graph (main): live data, statuses, activity, graphs.
//

import SwiftUI

struct ClimateView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: AppSettings

    @State private var selectedRoomID: UUID?
    @State private var metric: ReadingMetric = .temperature
    @State private var showAddRecord = false
    @State private var pulse = false

    private var selectedRoom: Room? {
        if let id = selectedRoomID, let r = store.room(id) { return r }
        return store.rooms.first
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppBackground()
                if store.rooms.isEmpty {
                    EmptyStateView(icon: "thermometer",
                                   title: "No zones yet",
                                   message: "Add a barn or zone in the Sensors tab to start tracking its climate.")
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            zonePicker
                            if let room = selectedRoom {
                                liveHeader(room)
                                metricPicker
                                graphCard(room)
                                gaugeRow(room)
                                statusCard(room)
                                detailLink(room)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 110)
                    }
                }
            }
            .navigationBarTitle("Climate", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddRecord = true } label: {
                        Image(systemName: "plus.circle.fill").foregroundColor(Brand.greenDeep)
                    }
                }
            }
            .sheet(isPresented: $showAddRecord) {
                AddRecordView(preselectedRoomID: selectedRoom?.id)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            if selectedRoomID == nil { selectedRoomID = store.rooms.first?.id }
            store.startLiveUpdates()
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { pulse = true }
        }
        .onDisappear {
            store.stopLiveUpdates()
            pulse = false   // stop the live indicator loop
        }
    }

    // MARK: Zone picker

    private var zonePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(store.rooms) { room in
                    SelectableChip(title: room.name,
                                   icon: room.category.icon,
                                   isSelected: room.id == selectedRoom?.id,
                                   tint: room.category.tint) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            selectedRoomID = room.id
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: Live header

    private func liveHeader(_ room: Room) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(room.name).font(.barn(20, .bold)).foregroundColor(AppColor.text)
                        Text(room.category.title).font(.barn(13, .medium)).foregroundColor(AppColor.textSecondary)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Circle().fill(Brand.good).frame(width: 8, height: 8).opacity(pulse ? 1 : 0.3)
                        Text("LIVE").font(.barn(11, .bold)).foregroundColor(Brand.greenDeep)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Brand.good.opacity(0.14)).clipShape(Capsule())
                }
                HStack(spacing: 12) {
                    bigReading("thermometer", Brand.critical, settings.temperatureText(room.temperature, decimals: 1))
                    bigReading("drop.fill", Brand.blue, String(format: "%.0f%%", room.humidity))
                    bigReading("wind", Brand.cyan, String(format: "%.0f%%", room.ventilation))
                }
            }
        }
    }

    private func bigReading(_ icon: String, _ tint: Color, _ value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundColor(tint)
            Text(value).font(.barn(18, .bold)).foregroundColor(AppColor.text)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Metric picker

    private var metricPicker: some View {
        HStack(spacing: 8) {
            ForEach(ReadingMetric.allCases) { m in
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { metric = m }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: m.icon).font(.system(size: 13, weight: .bold))
                        Text(m.title).font(.barn(13, .semibold))
                    }
                    .foregroundColor(metric == m ? .white : AppColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(metric == m ? AnyView(m.tint) : AnyView(AppColor.surface))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(metric == m ? Color.clear : AppColor.separator, lineWidth: 1))
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.95))
            }
        }
    }

    // MARK: Graph

    private func graphCard(_ room: Room) -> some View {
        let series = displaySeries(room)
        return AppCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label {
                        Text("\(metric.title) • last 24h").font(.barn(14, .semibold))
                            .foregroundColor(AppColor.text)
                    } icon: {
                        Image(systemName: metric.icon).foregroundColor(metric.tint)
                    }
                    Spacer()
                    Text(currentValueText(room)).font(.barn(16, .bold)).foregroundColor(metric.tint)
                }
                LineAreaChart(values: series, color: metric.tint)
                    .frame(height: 170)
                    .id(metric)   // re-animate on metric change
                HStack {
                    statBubble("Min", minText(series))
                    Spacer()
                    statBubble("Avg", avgText(series))
                    Spacer()
                    statBubble("Max", maxText(series))
                }
            }
        }
    }

    private func statBubble(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.barn(15, .bold)).foregroundColor(AppColor.text)
            Text(title).font(.barn(11, .medium)).foregroundColor(AppColor.textSecondary)
        }
    }

    // MARK: Gauges

    private func gaugeRow(_ room: Room) -> some View {
        HStack(spacing: 12) {
            gauge(.temperature, value: room.temperature, range: room.category.idealTemp,
                  label: settings.temperatureText(room.temperature, decimals: 0))
            gauge(.humidity, value: room.humidity, range: room.category.idealHumidity,
                  label: String(format: "%.0f%%", room.humidity))
            gauge(.ventilation, value: room.ventilation, range: 30...80,
                  label: String(format: "%.0f%%", room.ventilation))
        }
    }

    private func gauge(_ m: ReadingMetric, value: Double, range: ClosedRange<Double>, label: String) -> some View {
        let progress = ((value - range.lowerBound) / max(range.upperBound - range.lowerBound, 0.001)).clamped(to: 0...1)
        return AppCard(padding: 12) {
            VStack(spacing: 8) {
                RingGauge(progress: progress, lineWidth: 9, color: m.tint, label: label, caption: m.title)
                    .frame(height: 84)
            }
        }
    }

    // MARK: Status + activity

    private func statusCard(_ room: Room) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Status & activity").font(.barn(16, .bold)).foregroundColor(AppColor.text)
                    Spacer()
                    StatusPill(status: room.status)
                }
                activityRow(icon: "thermometer", title: "Temperature",
                            ok: room.category.idealTemp.contains(room.temperature),
                            detail: String(format: "ideal %.0f–%.0f°C", room.category.idealTemp.lowerBound, room.category.idealTemp.upperBound))
                activityRow(icon: "drop.fill", title: "Humidity",
                            ok: room.category.idealHumidity.contains(room.humidity),
                            detail: String(format: "ideal %.0f–%.0f%%", room.category.idealHumidity.lowerBound, room.category.idealHumidity.upperBound))
                activityRow(icon: "wind", title: "Ventilation",
                            ok: room.ventilation >= 30,
                            detail: "fan power active")
            }
        }
    }

    private func activityRow(icon: String, title: String, ok: Bool, detail: String) -> some View {
        HStack(spacing: 12) {
            IconBadge(systemName: icon, color: ok ? Brand.good : Brand.warning, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.barn(14, .semibold)).foregroundColor(AppColor.text)
                Text(detail).font(.barn(12, .regular)).foregroundColor(AppColor.textSecondary)
            }
            Spacer()
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(ok ? Brand.good : Brand.warning)
        }
    }

    private func detailLink(_ room: Room) -> some View {
        NavigationLink(destination: RoomDetailView(roomID: room.id)) {
            HStack {
                Text("Open full details").font(.barn(15, .semibold)).foregroundColor(.white)
                Spacer()
                Image(systemName: "arrow.right").foregroundColor(.white)
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
            .background(AppGradient.primaryButton)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: Series helpers

    private func displaySeries(_ room: Room) -> [Double] {
        let raw = room.history.map { $0.value(for: metric) }
        if metric == .temperature {
            return raw.map { settings.tempUnit.value(fromCelsius: $0) }
        }
        return raw
    }

    private func currentValueText(_ room: Room) -> String {
        switch metric {
        case .temperature: return settings.temperatureText(room.temperature)
        case .humidity:    return String(format: "%.0f%%", room.humidity)
        case .ventilation: return String(format: "%.0f%%", room.ventilation)
        }
    }

    private func unitSuffix() -> String {
        metric == .temperature ? settings.tempUnit.symbol : "%"
    }
    private func minText(_ s: [Double]) -> String { String(format: "%.1f%@", s.min() ?? 0, unitSuffix()) }
    private func maxText(_ s: [Double]) -> String { String(format: "%.1f%@", s.max() ?? 0, unitSuffix()) }
    private func avgText(_ s: [Double]) -> String {
        guard !s.isEmpty else { return "0" }
        return String(format: "%.1f%@", s.reduce(0, +) / Double(s.count), unitSuffix())
    }
}
