//
//  TasksView.swift
//  BarnClimate
//
//  Screen 13 — Tasks: list with completion, priority, reminders.
//

import SwiftUI

struct TasksView: View {
    @EnvironmentObject var store: AppStore
    @State private var showCompleted = false
    @State private var showAdd = false
    @State private var editingTask: FarmTask?

    private var list: [FarmTask] {
        showCompleted ? store.completedTasks.sorted { $0.dueDate > $1.dueDate } : store.pendingTasks
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        SelectableChip(title: "Pending (\(store.pendingTasks.count))",
                                       isSelected: !showCompleted, tint: Brand.greenDeep) {
                            withAnimation { showCompleted = false }
                        }
                        SelectableChip(title: "Done (\(store.completedTasks.count))",
                                       isSelected: showCompleted, tint: Brand.greenDeep) {
                            withAnimation { showCompleted = true }
                        }
                    }
                    if list.isEmpty {
                        EmptyStateView(icon: "list.bullet.rectangle",
                                       title: showCompleted ? "Nothing completed yet" : "No pending tasks",
                                       message: showCompleted ? "Finished tasks will appear here."
                                                              : "Add a task to plan barn maintenance.",
                                       actionTitle: showCompleted ? nil : "Add task") { showAdd = true }
                    } else {
                        ForEach(list) { task in
                            TaskRow(task: task)
                                .onTapGesture { editingTask = task }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitle("Tasks", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus.circle.fill").foregroundColor(Brand.greenDeep)
                }
            }
        }
        .sheet(isPresented: $showAdd) { AddTaskView() }
        .sheet(item: $editingTask) { task in AddTaskView(editingTask: task) }
    }
}

// MARK: - Task row

struct TaskRow: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: AppSettings
    let task: FarmTask

    var body: some View {
        AppCard(padding: 14) {
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        store.toggleTask(task)
                    }
                    Haptics.tap(settings.hapticsEnabled)
                } label: {
                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(task.isDone ? Brand.good : AppColor.textMuted)
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.85))

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.barn(15, .semibold))
                        .foregroundColor(task.isDone ? AppColor.textMuted : AppColor.text)
                        .strikethrough(task.isDone, color: AppColor.textMuted)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Label {
                            Text(task.dueDate, style: .date).font(.barn(11, .medium))
                        } icon: {
                            Image(systemName: "calendar").font(.system(size: 10))
                        }
                        .foregroundColor(dueColor)
                        if task.reminderOn {
                            Image(systemName: "bell.fill").font(.system(size: 10)).foregroundColor(Brand.yellowDeep)
                        }
                        if let room = store.room(task.roomID) {
                            Text(room.name).font(.barn(11, .medium)).foregroundColor(AppColor.textMuted)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
                Circle().fill(task.priority.color).frame(width: 10, height: 10)
            }
        }
    }

    private var dueColor: Color {
        if task.isDone { return AppColor.textMuted }
        return task.dueDate < Date() ? Brand.critical : AppColor.textSecondary
    }
}

// MARK: - Add / edit task

struct AddTaskView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: AppSettings
    @Environment(\.presentationMode) private var presentation

    var editingTask: FarmTask? = nil
    var presetDate: Date? = nil
    var presetTitle: String? = nil
    var presetDetail: String? = nil

    @State private var title = ""
    @State private var detail = ""
    @State private var dueDate = Date().addingTimeInterval(3600)
    @State private var priority: TaskPriority = .medium
    @State private var roomID: UUID?
    @State private var reminderOn = false
    @State private var showError = false

    private var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationView {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        AppTextField(title: "Title", placeholder: "e.g. Replace intake filters",
                                     text: $title, icon: "list.bullet.rectangle")
                        AppTextEditor(title: "Details", text: $detail)
                        prioritySection
                        zoneSection
                        dateSection
                        reminderToggle
                        if showError {
                            Text("Please enter a task title.")
                                .font(.barn(13, .semibold)).foregroundColor(Brand.critical)
                        }
                        PrimaryButton(title: editingTask == nil ? "Add task" : "Save", icon: "checkmark") { save() }
                        if editingTask != nil {
                            SecondaryButton(title: "Delete task", icon: "trash") { delete() }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationBarTitle(editingTask == nil ? "New task" : "Edit task", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { presentation.wrappedValue.dismiss() }
                        .foregroundColor(AppColor.textSecondary)
                }
            }
            .onAppear(perform: load)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Priority").font(.barn(13, .semibold)).foregroundColor(AppColor.textSecondary)
            HStack(spacing: 8) {
                ForEach(TaskPriority.allCases) { p in
                    Button { withAnimation { priority = p } } label: {
                        Text(p.title).font(.barn(13, .semibold))
                            .foregroundColor(priority == p ? .white : p.color)
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .background(priority == p ? AnyView(p.color) : AnyView(p.color.opacity(0.12)))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.95))
                }
            }
        }
    }

    private var zoneSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Linked zone (optional)").font(.barn(13, .semibold)).foregroundColor(AppColor.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    SelectableChip(title: "None", isSelected: roomID == nil, tint: Brand.greenDeep) { roomID = nil }
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

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Due date & time").font(.barn(13, .semibold)).foregroundColor(AppColor.textSecondary)
            DatePicker("", selection: $dueDate)
                .datePickerStyle(GraphicalDatePickerStyle())
                .accentColor(Brand.greenDeep)
                .padding(12)
                .background(AppColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppColor.separator, lineWidth: 1))
        }
    }

    private var reminderToggle: some View {
        AppCard(padding: 14) {
            Toggle(isOn: $reminderOn) {
                HStack(spacing: 10) {
                    IconBadge(systemName: "bell.fill", color: Brand.yellowDeep, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reminder").font(.barn(15, .semibold)).foregroundColor(AppColor.text)
                        Text("Notify me at the due time").font(.barn(12, .regular)).foregroundColor(AppColor.textSecondary)
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: Brand.green))
            .onChange(of: reminderOn) { on in
                if on { NotificationManager.shared.requestAuthorization() }
            }
        }
    }

    private func load() {
        if editingTask == nil {
            if let t = presetTitle { title = t }
            if let d = presetDetail { detail = d }
        }
        if let preset = presetDate, editingTask == nil {
            // Keep the time of day but jump to the chosen calendar day.
            let cal = Calendar.current
            var comps = cal.dateComponents([.year, .month, .day], from: preset)
            comps.hour = 9; comps.minute = 0
            dueDate = cal.date(from: comps) ?? preset
        }
        guard let task = editingTask else { return }
        title = task.title
        detail = task.detail
        dueDate = task.dueDate
        priority = task.priority
        roomID = task.roomID
        reminderOn = task.reminderOn
    }

    private func save() {
        guard isValid else {
            withAnimation { showError = true }
            Haptics.warning(settings.hapticsEnabled)
            return
        }
        var task = editingTask ?? FarmTask(title: "", dueDate: dueDate)
        task.title = title.trimmingCharacters(in: .whitespaces)
        task.detail = detail
        task.dueDate = dueDate
        task.priority = priority
        task.roomID = roomID
        task.reminderOn = reminderOn

        if editingTask == nil { store.addTask(task) } else { store.updateTask(task) }
        NotificationManager.shared.scheduleTaskReminder(task)
        Haptics.success(settings.hapticsEnabled)
        presentation.wrappedValue.dismiss()
    }

    private func delete() {
        guard let task = editingTask else { return }
        NotificationManager.shared.cancelTaskReminder(task)
        store.deleteTask(task)
        presentation.wrappedValue.dismiss()
    }
}
