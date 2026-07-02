//
//  NotificationManager.swift
//  BarnClimate
//
//  Thin wrapper around UNUserNotificationCenter for real local reminders.
//

import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Authorization

    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion?(granted) }
        }
    }

    func authorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    // MARK: - Task reminders

    func scheduleTaskReminder(_ task: FarmTask) {
        guard task.reminderOn, task.dueDate > Date() else {
            cancelTaskReminder(task)
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Task due: \(task.title)"
        content.body = task.detail.isEmpty ? "Tap to review this farm task." : task.detail
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute],
                                                    from: task.dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: taskID(task), content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    func cancelTaskReminder(_ task: FarmTask) {
        center.removePendingNotificationRequests(withIdentifiers: [taskID(task)])
    }

    private func taskID(_ task: FarmTask) -> String { "task.\(task.id.uuidString)" }

    // MARK: - Daily climate check

    private let dailyID = "daily.climate.check"

    func scheduleDailyClimateCheck(at time: Date, enabled: Bool) {
        center.removePendingNotificationRequests(withIdentifiers: [dailyID])
        guard enabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Daily climate check"
        content.body = "Review temperature, humidity and ventilation across your barns."
        content.sound = .default

        var comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        comps.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: dailyID, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    // MARK: - Critical alert (fires shortly after detection)

    func fireCriticalAlert(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .defaultCritical
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
