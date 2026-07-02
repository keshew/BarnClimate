//
//  SettingsView.swift
//  BarnClimate
//
//  Screen 20 — Settings: Theme, Units, Backup (+ farm, notifications).
//  Every control here has a real, persisted, visible effect.
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: AppStore

    @State private var showShare = false
    @State private var shareURL: URL?
    @State private var confirmRestore = false
    @State private var confirmClear = false
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined
    @State private var savedToast = false

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    farmCard
                    themeSection
                    unitsSection
                    notificationsSection
                    backupSection
                    statsCard
                    aboutFooter
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 40)
            }

            if savedToast { toast }
        }
        .navigationBarTitle("Settings", displayMode: .inline)
        .sheet(isPresented: $showShare) {
            if let url = shareURL { ShareSheet(items: [url]) }
        }
        .alert(isPresented: $confirmRestore) {
            Alert(title: Text("Restore demo data?"),
                  message: Text("This replaces all current data with the sample farm."),
                  primaryButton: .destructive(Text("Restore")) {
                    store.resetToDemo(); flashSaved()
                  },
                  secondaryButton: .cancel())
        }
        .onAppear {
            NotificationManager.shared.authorizationStatus { notifStatus = $0 }
        }
    }

    // MARK: Farm name

    private var farmCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Farm").font(.barn(16, .bold)).foregroundColor(AppColor.text)
                AppTextField(title: "Farm name", placeholder: "My Farm",
                             text: Binding(get: { settings.farmName },
                                           set: { settings.farmName = $0 }),
                             icon: "house.fill")
            }
        }
    }

    // MARK: Theme

    private var themeSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                Label {
                    Text("Appearance").font(.barn(16, .bold)).foregroundColor(AppColor.text)
                } icon: { Image(systemName: "paintbrush.fill").foregroundColor(Brand.green) }
                HStack(spacing: 10) {
                    ForEach(AppThemeMode.allCases) { mode in
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                settings.themeMode = mode
                            }
                            Haptics.tap(settings.hapticsEnabled)
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(settings.themeMode == mode ? .white : Brand.greenDeep)
                                Text(mode.title).font(.barn(12, .semibold))
                                    .foregroundColor(settings.themeMode == mode ? .white : AppColor.text)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(settings.themeMode == mode
                                        ? AnyView(AppGradient.primaryButton)
                                        : AnyView(AppColor.surfaceAlt))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(settings.themeMode == mode ? Color.clear : AppColor.separator, lineWidth: 1))
                        }
                        .buttonStyle(ScaleButtonStyle(scale: 0.95))
                    }
                }
                Text("Changes the whole app instantly and is saved for next launch.")
                    .font(.barn(11, .medium)).foregroundColor(AppColor.textMuted)
            }
        }
    }

    // MARK: Units

    private var unitsSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                Label {
                    Text("Units").font(.barn(16, .bold)).foregroundColor(AppColor.text)
                } icon: { Image(systemName: "thermometer").foregroundColor(Brand.critical) }
                HStack(spacing: 10) {
                    ForEach(TempUnit.allCases) { unit in
                        Button {
                            withAnimation { settings.tempUnit = unit }
                            Haptics.tap(settings.hapticsEnabled)
                        } label: {
                            Text(unit.title).font(.barn(14, .semibold))
                                .foregroundColor(settings.tempUnit == unit ? .white : AppColor.text)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(settings.tempUnit == unit
                                            ? AnyView(AppGradient.primaryButton)
                                            : AnyView(AppColor.surfaceAlt))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(settings.tempUnit == unit ? Color.clear : AppColor.separator, lineWidth: 1))
                        }
                        .buttonStyle(ScaleButtonStyle(scale: 0.96))
                    }
                }
                Text("Sample: \(settings.temperatureText(20))")
                    .font(.barn(12, .medium)).foregroundColor(AppColor.textSecondary)
            }
        }
    }

    // MARK: Notifications

    private var notificationsSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                Label {
                    Text("Notifications").font(.barn(16, .bold)).foregroundColor(AppColor.text)
                } icon: { Image(systemName: "bell.fill").foregroundColor(Brand.yellowDeep) }

                Toggle(isOn: Binding(get: { settings.dailyReminderEnabled },
                                     set: { newVal in
                                        settings.dailyReminderEnabled = newVal
                                        if newVal { NotificationManager.shared.requestAuthorization { _ in
                                            NotificationManager.shared.authorizationStatus { notifStatus = $0 }
                                        } }
                                        NotificationManager.shared.scheduleDailyClimateCheck(
                                            at: settings.dailyReminderTime, enabled: newVal)
                                     })) {
                    settingLabel("Daily climate check", "A reminder to review your barns")
                }
                .toggleStyle(SwitchToggleStyle(tint: Brand.green))

                if settings.dailyReminderEnabled {
                    DatePicker("Reminder time",
                               selection: Binding(get: { settings.dailyReminderTime },
                                                  set: { newVal in
                                                    settings.dailyReminderTime = newVal
                                                    NotificationManager.shared.scheduleDailyClimateCheck(
                                                        at: newVal, enabled: true)
                                                  }),
                               displayedComponents: .hourAndMinute)
                        .font(.barn(14, .medium))
                        .accentColor(Brand.greenDeep)
                }

                Divider().background(AppColor.separator)

                Toggle(isOn: Binding(get: { settings.criticalAlertsEnabled },
                                     set: { settings.criticalAlertsEnabled = $0 })) {
                    settingLabel("Critical alerts", "Push when a zone goes critical")
                }
                .toggleStyle(SwitchToggleStyle(tint: Brand.green))

                Toggle(isOn: Binding(get: { settings.hapticsEnabled },
                                     set: { settings.hapticsEnabled = $0; if $0 { Haptics.tap(true) } })) {
                    settingLabel("Haptic feedback", "Subtle taps on interactions")
                }
                .toggleStyle(SwitchToggleStyle(tint: Brand.green))

                if notifStatus == .denied {
                    Text("Notifications are disabled in iOS Settings.")
                        .font(.barn(11, .medium)).foregroundColor(Brand.critical)
                }
            }
        }
    }

    private func settingLabel(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.barn(15, .semibold)).foregroundColor(AppColor.text)
            Text(subtitle).font(.barn(12, .regular)).foregroundColor(AppColor.textSecondary)
        }
    }

    // MARK: Backup

    private var backupSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                Label {
                    Text("Backup").font(.barn(16, .bold)).foregroundColor(AppColor.text)
                } icon: { Image(systemName: "externaldrive.fill").foregroundColor(Brand.blue) }

                backupRow("Export data", "Share a JSON backup file", "square.and.arrow.up", Brand.blue) {
                    exportData()
                }
                backupRow("Restore demo data", "Reset to the sample farm", "arrow.triangle.2.circlepath", Brand.yellowDeep) {
                    confirmRestore = true
                }
                backupRow("Clear all data", "Delete every zone and record", "trash.fill", Brand.critical) {
                    confirmClear = true
                }
            }
        }
        .alert(isPresented: $confirmClear) {
            Alert(title: Text("Clear all data?"),
                  message: Text("This permanently removes everything. This cannot be undone."),
                  primaryButton: .destructive(Text("Clear")) {
                    store.clearAll(); flashSaved()
                  },
                  secondaryButton: .cancel())
        }
    }

    private func backupRow(_ title: String, _ subtitle: String, _ icon: String, _ tint: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconBadge(systemName: icon, color: tint, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.barn(15, .semibold)).foregroundColor(AppColor.text)
                    Text(subtitle).font(.barn(12, .regular)).foregroundColor(AppColor.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(AppColor.textMuted)
            }
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.98))
    }

    // MARK: Stats

    private var statsCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your farm at a glance").font(.barn(16, .bold)).foregroundColor(AppColor.text)
                HStack(spacing: 12) {
                    miniStat("\(store.rooms.count)", "Zones")
                    miniStat("\(store.records.count)", "Records")
                    miniStat("\(store.tasks.count)", "Tasks")
                    miniStat("\(store.alerts.count)", "Alerts")
                }
            }
        }
    }

    private func miniStat(_ value: String, _ title: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.barn(20, .bold)).foregroundColor(Brand.greenDeep)
            Text(title).font(.barn(11, .medium)).foregroundColor(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(AppColor.surfaceAlt).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var aboutFooter: some View {
        VStack(spacing: 4) {
            Text("BarnClimate").font(.barn(15, .bold)).foregroundColor(AppColor.text)
            Text("Version 1.0 • Farm climate, under control")
                .font(.barn(11, .medium)).foregroundColor(AppColor.textMuted)
        }
        .frame(maxWidth: .infinity).padding(.top, 8)
    }

    private var toast: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("Done").font(.barn(14, .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(Brand.greenDeep).clipShape(Capsule())
            .shadow(color: Brand.green.opacity(0.4), radius: 10, x: 0, y: 5)
            .padding(.bottom, 30)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: Actions

    private func exportData() {
        let json = store.exportJSON()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("BarnClimate-backup.json")
        do {
            try json.data(using: .utf8)?.write(to: url)
            shareURL = url
            showShare = true
        } catch {
            shareURL = nil
        }
    }

    private func flashSaved() {
        Haptics.success(settings.hapticsEnabled)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { savedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation { savedToast = false }
        }
    }
}
