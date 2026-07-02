//
//  AddRecordView.swift
//  BarnClimate
//
//  Screen 11 — Add Record: Date, Status, Value (+ metric, zone, note).
//

import SwiftUI

struct AddRecordView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: AppSettings
    @Environment(\.presentationMode) private var presentation

    var preselectedRoomID: UUID? = nil

    @State private var roomID: UUID?
    @State private var metric: ReadingMetric = .temperature
    @State private var date = Date()
    @State private var status: ClimateStatus = .good
    @State private var valueText: String = ""
    @State private var note: String = ""
    @State private var showError = false

    private var parsedValue: Double? {
        Double(valueText.replacingOccurrences(of: ",", with: "."))
    }
    private var isValid: Bool { parsedValue != nil }

    var body: some View {
        NavigationView {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        zoneSection
                        metricSection
                        valueField
                        statusSection
                        dateSection
                        AppTextEditor(title: "Note", text: $note)
                        if showError {
                            Text("Enter a numeric value to save this record.")
                                .font(.barn(13, .semibold)).foregroundColor(Brand.critical)
                        }
                        PrimaryButton(title: "Save record", icon: "checkmark") { save() }
                    }
                    .padding(20)
                }
            }
            .navigationBarTitle("Add record", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { presentation.wrappedValue.dismiss() }
                        .foregroundColor(AppColor.textSecondary)
                }
            }
            .onAppear {
                roomID = preselectedRoomID ?? store.rooms.first?.id
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var zoneSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Zone").font(.barn(13, .semibold)).foregroundColor(AppColor.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.rooms) { room in
                        SelectableChip(title: room.name, icon: room.category.icon,
                                       isSelected: roomID == room.id, tint: room.category.tint) {
                            roomID = room.id
                        }
                    }
                }
            }
        }
    }

    private var metricSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Metric").font(.barn(13, .semibold)).foregroundColor(AppColor.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ReadingMetric.allCases) { m in
                        SelectableChip(title: m.title, icon: m.icon, isSelected: metric == m, tint: m.tint) {
                            withAnimation { metric = m }
                        }
                    }
                }
            }
        }
    }

    private var valueField: some View {
        AppTextField(title: "Value (\(unitLabel))",
                     placeholder: "e.g. \(placeholderValue)",
                     text: $valueText, icon: metric.icon, keyboard: .decimalPad)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Status").font(.barn(13, .semibold)).foregroundColor(AppColor.textSecondary)
            HStack(spacing: 8) {
                ForEach(ClimateStatus.allCases) { s in
                    Button {
                        withAnimation { status = s }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: s.icon).font(.system(size: 12, weight: .bold))
                            Text(s.title).font(.barn(13, .semibold))
                        }
                        .foregroundColor(status == s ? .white : s.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(status == s ? AnyView(s.color) : AnyView(s.color.opacity(0.12)))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.95))
                }
            }
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Date & time").font(.barn(13, .semibold)).foregroundColor(AppColor.textSecondary)
            DatePicker("", selection: $date, in: ...Date())
                .datePickerStyle(GraphicalDatePickerStyle())
                .accentColor(Brand.greenDeep)
                .padding(12)
                .background(AppColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppColor.separator, lineWidth: 1))
        }
    }

    private var unitLabel: String {
        metric == .temperature ? settings.tempUnit.symbol : "%"
    }
    private var placeholderValue: String {
        switch metric {
        case .temperature: return settings.tempUnit == .celsius ? "18.0" : "64.0"
        case .humidity:    return "60"
        case .ventilation: return "50"
        }
    }

    private func save() {
        guard let value = parsedValue else {
            withAnimation { showError = true }
            Haptics.warning(settings.hapticsEnabled)
            return
        }
        // Temperature stored internally in Celsius.
        let storedValue = metric == .temperature ? settings.tempUnit.toCelsius(value) : value
        let record = ClimateRecord(roomID: roomID, date: date, metric: metric,
                                   value: storedValue, status: status, note: note)
        store.addRecord(record)
        Haptics.success(settings.hapticsEnabled)
        presentation.wrappedValue.dismiss()
    }
}
