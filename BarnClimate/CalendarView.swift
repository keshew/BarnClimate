//
//  CalendarView.swift
//  BarnClimate
//
//  Screen 14 — Calendar: events and reminders by day.
//

import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var store: AppStore

    @State private var month: Date = Date()
    @State private var selected: Date = Date()
    @State private var showAdd = false

    private let cal = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    monthCard
                    daySection
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitle("Calendar", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus.circle.fill").foregroundColor(Brand.greenDeep)
                }
            }
        }
        .sheet(isPresented: $showAdd) { AddTaskView(presetDate: selected) }
    }

    // MARK: Month grid

    private var monthCard: some View {
        AppCard {
            VStack(spacing: 14) {
                HStack {
                    Button { changeMonth(-1) } label: {
                        Image(systemName: "chevron.left").foregroundColor(Brand.greenDeep)
                            .padding(8).background(Brand.green.opacity(0.12)).clipShape(Circle())
                    }
                    Spacer()
                    Text(monthTitle).font(.barn(18, .bold)).foregroundColor(AppColor.text)
                    Spacer()
                    Button { changeMonth(1) } label: {
                        Image(systemName: "chevron.right").foregroundColor(Brand.greenDeep)
                            .padding(8).background(Brand.green.opacity(0.12)).clipShape(Circle())
                    }
                }
                HStack(spacing: 6) {
                    ForEach(weekdaySymbols, id: \.self) { s in
                        Text(s).font(.barn(11, .bold)).foregroundColor(AppColor.textMuted)
                            .frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, day in
                        dayCell(day)
                    }
                }
            }
        }
    }

    private func dayCell(_ day: Date?) -> some View {
        Group {
            if let day = day {
                let isSelected = cal.isDate(day, inSameDayAs: selected)
                let isToday = cal.isDateInToday(day)
                let count = store.tasks(on: day).count
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { selected = day }
                } label: {
                    VStack(spacing: 3) {
                        Text("\(cal.component(.day, from: day))")
                            .font(.barn(14, isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? .white : (isToday ? Brand.greenDeep : AppColor.text))
                        Circle()
                            .fill(count > 0 ? (isSelected ? Color.white : Brand.green) : Color.clear)
                            .frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(
                        cellBackground(isSelected: isSelected, isToday: isToday)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    )
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.9))
            } else {
                Color.clear.frame(height: 42)
            }
        }
    }

    @ViewBuilder
    private func cellBackground(isSelected: Bool, isToday: Bool) -> some View {
        if isSelected {
            AppGradient.primaryButton
        } else if isToday {
            Brand.green.opacity(0.12)
        } else {
            Color.clear
        }
    }

    // MARK: Selected-day tasks

    private var daySection: some View {
        let tasks = store.tasks(on: selected)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedTitle).font(.barn(18, .bold)).foregroundColor(AppColor.text)
                Spacer()
                Text("\(tasks.count) event\(tasks.count == 1 ? "" : "s")")
                    .font(.barn(13, .medium)).foregroundColor(AppColor.textSecondary)
            }
            if tasks.isEmpty {
                AppCard {
                    HStack(spacing: 12) {
                        IconBadge(systemName: "calendar", color: Brand.blue, size: 38)
                        Text("No events on this day. Tap + to add one.")
                            .font(.barn(13, .medium)).foregroundColor(AppColor.textSecondary)
                        Spacer()
                    }
                }
            } else {
                ForEach(tasks) { task in
                    TaskRow(task: task)
                }
            }
        }
    }

    // MARK: Helpers

    private var monthTitle: String {
        let f = DateFormatter(); f.dateFormat = "LLLL yyyy"
        return f.string(from: month)
    }
    private var selectedTitle: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, d MMM"
        return f.string(from: selected)
    }
    private var weekdaySymbols: [String] {
        let f = DateFormatter()
        let syms = f.veryShortStandaloneWeekdaySymbols ?? ["S","M","T","W","T","F","S"]
        let first = cal.firstWeekday - 1
        return Array(syms[first...] + syms[..<first])
    }

    private var daysInMonth: [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: month),
              let firstWeekday = cal.dateComponents([.weekday], from: interval.start).weekday
        else { return [] }
        let daysCount = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for d in 0..<daysCount {
            if let date = cal.date(byAdding: .day, value: d, to: interval.start) {
                cells.append(date)
            }
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private func changeMonth(_ delta: Int) {
        if let m = cal.date(byAdding: .month, value: delta, to: month) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { month = m }
        }
    }
}
