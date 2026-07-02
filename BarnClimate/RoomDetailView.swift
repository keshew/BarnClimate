//
//  RoomDetailView.swift
//  BarnClimate
//
//  Screen 10 — Details: full card for a single zone with charts and records.
//

import SwiftUI

struct RoomDetailView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: AppSettings
    @Environment(\.presentationMode) private var presentation

    let roomID: UUID

    @State private var showEdit = false
    @State private var showAddRecord = false
    @State private var showDeleteAlert = false
    @State private var metric: ReadingMetric = .temperature

    private var room: Room? { store.room(roomID) }

    var body: some View {
        ZStack {
            AppBackground()
            if let room = room {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        heroCard(room)
                        controlsCard(room)
                        chartCard(room)
                        recordsSection(room)
                        dangerZone
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 40)
                }
            } else {
                EmptyStateView(icon: "house.fill", title: "Zone removed",
                               message: "This zone is no longer available.")
            }
        }
        .navigationBarTitle(room?.name ?? "Details", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showEdit = true } label: {
                    Image(systemName: "pencil").foregroundColor(Brand.greenDeep)
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            if let room = room { AddRoomView(editingRoom: room) }
        }
        .sheet(isPresented: $showAddRecord) {
            AddRecordView(preselectedRoomID: roomID)
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(title: Text("Delete zone?"),
                  message: Text("This permanently removes the zone and its records."),
                  primaryButton: .destructive(Text("Delete")) {
                    if let room = room { store.deleteRoom(room) }
                    presentation.wrappedValue.dismiss()
                  },
                  secondaryButton: .cancel())
        }
    }

    private func heroCard(_ room: Room) -> some View {
        AppCard {
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    IconBadge(systemName: room.category.icon, color: room.category.tint, size: 54)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(room.name).font(.barn(20, .bold)).foregroundColor(AppColor.text)
                        Text(room.category.title).font(.barn(13, .medium)).foregroundColor(AppColor.textSecondary)
                    }
                    Spacer()
                    StatusPill(status: room.status)
                }
                HStack(spacing: 12) {
                    detailReading("thermometer", Brand.critical, settings.temperatureText(room.temperature))
                    detailReading("drop.fill", Brand.blue, String(format: "%.0f%%", room.humidity))
                    detailReading("wind", Brand.cyan, String(format: "%.0f%%", room.ventilation))
                }
                if !room.notes.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "note.text").foregroundColor(AppColor.textMuted)
                        Text(room.notes).font(.barn(13, .regular)).foregroundColor(AppColor.textSecondary)
                        Spacer()
                    }
                }
            }
        }
    }

    private func detailReading(_ icon: String, _ tint: Color, _ value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundColor(tint)
            Text(value).font(.barn(16, .bold)).foregroundColor(AppColor.text)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func controlsCard(_ room: Room) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Live controls").font(.barn(16, .bold)).foregroundColor(AppColor.text)
                Text("Adjust setpoints — changes save instantly and update the status.")
                    .font(.barn(12, .regular)).foregroundColor(AppColor.textSecondary)
                sliderRow("Target temperature",
                          value: binding(\.temperature),
                          range: -5...40, tint: Brand.critical,
                          valueText: settings.temperatureText(room.temperature, decimals: 0))
                sliderRow("Humidity",
                          value: binding(\.humidity),
                          range: 10...95, tint: Brand.blue,
                          valueText: String(format: "%.0f%%", room.humidity))
                sliderRow("Ventilation power",
                          value: binding(\.ventilation),
                          range: 0...100, tint: Brand.cyan,
                          valueText: String(format: "%.0f%%", room.ventilation))
            }
        }
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>,
                           tint: Color, valueText: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.barn(13, .semibold)).foregroundColor(AppColor.text)
                Spacer()
                Text(valueText).font(.barn(14, .bold)).foregroundColor(tint)
            }
            Slider(value: value, in: range)
                .accentColor(tint)
        }
    }

    /// Two-way binding into a stored room property; writes persist via the store.
    private func binding(_ keyPath: WritableKeyPath<Room, Double>) -> Binding<Double> {
        Binding(
            get: { self.store.room(self.roomID)?[keyPath: keyPath] ?? 0 },
            set: { newValue in
                guard var room = self.store.room(self.roomID) else { return }
                room[keyPath: keyPath] = newValue
                self.store.updateRoom(room)
            }
        )
    }

    private func chartCard(_ room: Room) -> some View {
        let series: [Double] = {
            let raw = room.history.map { $0.value(for: metric) }
            return metric == .temperature ? raw.map { settings.tempUnit.value(fromCelsius: $0) } : raw
        }()
        return AppCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("History").font(.barn(16, .bold)).foregroundColor(AppColor.text)
                    Spacer()
                    Picker("", selection: $metric) {
                        ForEach(ReadingMetric.allCases) { m in
                            Text(m.title).tag(m)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 200)
                }
                LineAreaChart(values: series, color: metric.tint).frame(height: 160).id(metric)
            }
        }
    }

    private func recordsSection(_ room: Room) -> some View {
        let recs = store.records(for: room.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Records").font(.barn(18, .bold)).foregroundColor(AppColor.text)
                Spacer()
                Button { showAddRecord = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(.barn(14, .semibold)).foregroundColor(Brand.greenDeep)
                }
            }
            if recs.isEmpty {
                AppCard {
                    HStack {
                        IconBadge(systemName: "doc.text", color: Brand.green, size: 38)
                        Text("No records yet. Add one to log a reading.")
                            .font(.barn(13, .medium)).foregroundColor(AppColor.textSecondary)
                        Spacer()
                    }
                }
            } else {
                ForEach(recs) { rec in
                    RecordRow(record: rec)
                }
            }
        }
    }

    private var dangerZone: some View {
        Button { showDeleteAlert = true } label: {
            HStack {
                Image(systemName: "trash.fill")
                Text("Delete zone").font(.barn(16, .semibold))
                Spacer()
            }
            .foregroundColor(Brand.critical)
            .padding(16)
            .background(Brand.critical.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Record row

struct RecordRow: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: AppSettings
    let record: ClimateRecord

    private var valueText: String {
        if record.metric == .temperature {
            return settings.temperatureText(record.value)
        }
        return String(format: "%.0f%%", record.value)
    }

    var body: some View {
        AppCard(padding: 14) {
            HStack(spacing: 12) {
                IconBadge(systemName: record.metric.icon, color: record.metric.tint, size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(valueText).font(.barn(16, .bold)).foregroundColor(AppColor.text)
                        StatusPill(status: record.status, compact: true)
                    }
                    Text(record.date, style: .date).font(.barn(11, .medium)).foregroundColor(AppColor.textMuted)
                        + Text(" • ") + Text(record.date, style: .time).font(.barn(11, .medium))
                    if !record.note.isEmpty {
                        Text(record.note).font(.barn(12, .regular)).foregroundColor(AppColor.textSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Button {
                    store.deleteRecord(record)
                    Haptics.tap(settings.hapticsEnabled)
                } label: {
                    Image(systemName: "trash").foregroundColor(Brand.critical.opacity(0.8))
                }
            }
        }
    }
}
