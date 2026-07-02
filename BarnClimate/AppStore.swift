//
//  AppStore.swift
//  BarnClimate
//
//  Single source of truth (model + repository layer for MVVM).
//  Holds all data, performs CRUD, persists to UserDefaults as JSON,
//  and seeds realistic demo content on first launch.
//

import SwiftUI
import Combine

// Codable snapshot persisted to disk.
private struct PersistedState: Codable {
    var rooms: [Room]
    var records: [ClimateRecord]
    var alerts: [ClimateAlert]
    var tasks: [FarmTask]
}

final class AppStore: ObservableObject {

    @Published var rooms: [Room] = []
    @Published var records: [ClimateRecord] = []
    @Published var alerts: [ClimateAlert] = []
    @Published var tasks: [FarmTask] = []

    /// Live activity ticker — drives subtle real-time updates on the Climate screen.
    @Published var liveTick: Int = 0
    private var liveTimer: Timer?

    private let storageKey = "BarnClimate.state.v1"

    let recommendations: [Recommendation] = AppStore.defaultRecommendations

    init() {
        if !load() {
            seedDemo()
            save()
        }
    }

    // MARK: - Live activity

    func startLiveUpdates() {
        guard liveTimer == nil else { return }
        liveTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.applyLiveDrift()
        }
    }

    func stopLiveUpdates() {
        liveTimer?.invalidate()
        liveTimer = nil
    }

    private func applyLiveDrift() {
        guard !rooms.isEmpty else { return }
        for i in rooms.indices {
            let t = Double(liveTick)
            let drift = sin((t + Double(i) * 1.7) * 0.6) * 0.18
            rooms[i].temperature = (rooms[i].temperature + drift).clamped(to: -5...40)
            rooms[i].humidity = (rooms[i].humidity + drift * 1.4).clamped(to: 10...95)
            rooms[i].ventilation = (rooms[i].ventilation + drift * 2.2).clamped(to: 0...100)
        }
        liveTick += 1
        // Persist occasionally to keep disk in sync without thrashing.
        if liveTick % 5 == 0 { save() }
    }

    // MARK: - Persistence

    @discardableResult
    private func load() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return false }
        do {
            let state = try JSONDecoder().decode(PersistedState.self, from: data)
            rooms = state.rooms
            records = state.records
            alerts = state.alerts
            tasks = state.tasks
            return !rooms.isEmpty
        } catch {
            return false
        }
    }

    func save() {
        let state = PersistedState(rooms: rooms, records: records, alerts: alerts, tasks: tasks)
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// Export the entire dataset as pretty JSON for the Backup feature.
    func exportJSON() -> String {
        let state = PersistedState(rooms: rooms, records: records, alerts: alerts, tasks: tasks)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(state), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }

    // MARK: - Room CRUD

    func room(_ id: UUID?) -> Room? {
        guard let id = id else { return nil }
        return rooms.first { $0.id == id }
    }

    func addRoom(name: String, category: RoomCategory, notes: String) {
        let temp = category.idealTemp.midpoint
        let hum = category.idealHumidity.midpoint
        var room = Room(name: name, category: category, notes: notes,
                        temperature: temp, humidity: hum, ventilation: 45)
        room.history = AppStore.generateHistory(base: room)
        rooms.append(room)
        save()
        recomputeAlerts(for: room)
    }

    func updateRoom(_ room: Room) {
        guard let idx = rooms.firstIndex(where: { $0.id == room.id }) else { return }
        rooms[idx] = room
        save()
        recomputeAlerts(for: room)
    }

    func deleteRoom(_ room: Room) {
        rooms.removeAll { $0.id == room.id }
        records.removeAll { $0.roomID == room.id }
        alerts.removeAll { $0.roomID == room.id }
        tasks.removeAll { $0.roomID == room.id }
        save()
    }

    func deleteRooms(at offsets: IndexSet) {
        let ids = offsets.map { rooms[$0].id }
        for id in ids { if let r = rooms.first(where: { $0.id == id }) { deleteRoom(r) } }
    }

    // MARK: - Record CRUD

    func addRecord(_ record: ClimateRecord) {
        records.insert(record, at: 0)
        // Reflect the latest manual value onto the room's current reading.
        if let roomID = record.roomID, let idx = rooms.firstIndex(where: { $0.id == roomID }) {
            switch record.metric {
            case .temperature: rooms[idx].temperature = record.value
            case .humidity:    rooms[idx].humidity = record.value
            case .ventilation: rooms[idx].ventilation = record.value
            }
            var reading = Reading(date: record.date,
                                  temperature: rooms[idx].temperature,
                                  humidity: rooms[idx].humidity,
                                  ventilation: rooms[idx].ventilation)
            reading.date = record.date
            rooms[idx].history.append(reading)
            rooms[idx].history = Array(rooms[idx].history.suffix(48))
            recomputeAlerts(for: rooms[idx])
        }
        save()
    }

    func deleteRecord(_ record: ClimateRecord) {
        records.removeAll { $0.id == record.id }
        save()
    }

    func records(for roomID: UUID?) -> [ClimateRecord] {
        guard let roomID = roomID else { return records }
        return records.filter { $0.roomID == roomID }
    }

    // MARK: - Alerts

    private func recomputeAlerts(for room: Room) {
        // Auto-raise an alert when a room enters warning/critical and none is open.
        let status = room.status
        guard status != .good else { return }
        let existing = alerts.first { $0.roomID == room.id && !$0.isResolved }
        if existing == nil {
            let message: String
            if !room.category.idealTemp.contains(room.temperature) {
                message = String(format: "Temperature %.1f°C is outside the ideal %.0f–%.0f°C range.",
                                 room.temperature, room.category.idealTemp.lowerBound, room.category.idealTemp.upperBound)
            } else {
                message = String(format: "Humidity %.0f%% is outside the ideal %.0f–%.0f%% range.",
                                 room.humidity, room.category.idealHumidity.lowerBound, room.category.idealHumidity.upperBound)
            }
            let alert = ClimateAlert(roomID: room.id,
                                     title: "\(room.name) needs attention",
                                     message: message,
                                     severity: status)
            alerts.insert(alert, at: 0)
        }
    }

    func markAlertRead(_ alert: ClimateAlert) {
        guard let idx = alerts.firstIndex(where: { $0.id == alert.id }) else { return }
        alerts[idx].isRead = true
        save()
    }

    func resolveAlert(_ alert: ClimateAlert) {
        guard let idx = alerts.firstIndex(where: { $0.id == alert.id }) else { return }
        alerts[idx].isResolved = true
        alerts[idx].isRead = true
        save()
    }

    func deleteAlert(_ alert: ClimateAlert) {
        alerts.removeAll { $0.id == alert.id }
        save()
    }

    func markAllAlertsRead() {
        for i in alerts.indices { alerts[i].isRead = true }
        save()
    }

    var unreadAlertCount: Int { alerts.filter { !$0.isRead && !$0.isResolved }.count }

    // MARK: - Tasks

    func addTask(_ task: FarmTask) {
        tasks.append(task)
        tasks.sort { $0.dueDate < $1.dueDate }
        save()
    }

    func updateTask(_ task: FarmTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx] = task
        tasks.sort { $0.dueDate < $1.dueDate }
        save()
    }

    func toggleTask(_ task: FarmTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].isDone.toggle()
        save()
    }

    func deleteTask(_ task: FarmTask) {
        tasks.removeAll { $0.id == task.id }
        save()
    }

    func deleteTasks(at offsets: IndexSet, in list: [FarmTask]) {
        let ids = offsets.map { list[$0].id }
        tasks.removeAll { ids.contains($0.id) }
        save()
    }

    var pendingTasks: [FarmTask] { tasks.filter { !$0.isDone }.sorted { $0.dueDate < $1.dueDate } }
    var completedTasks: [FarmTask] { tasks.filter { $0.isDone } }

    func tasks(on day: Date) -> [FarmTask] {
        tasks.filter { Calendar.current.isDate($0.dueDate, inSameDayAs: day) }
            .sorted { $0.dueDate < $1.dueDate }
    }

    // MARK: - Analytics

    var averageTemperature: Double {
        guard !rooms.isEmpty else { return 0 }
        return rooms.map { $0.temperature }.reduce(0, +) / Double(rooms.count)
    }
    var averageHumidity: Double {
        guard !rooms.isEmpty else { return 0 }
        return rooms.map { $0.humidity }.reduce(0, +) / Double(rooms.count)
    }
    var averageVentilation: Double {
        guard !rooms.isEmpty else { return 0 }
        return rooms.map { $0.ventilation }.reduce(0, +) / Double(rooms.count)
    }

    func statusCount(_ status: ClimateStatus) -> Int {
        rooms.filter { $0.status == status }.count
    }

    var overallStatus: ClimateStatus {
        rooms.map { $0.status }.max(by: { $0.rank < $1.rank }) ?? .good
    }

    /// Average value of a metric across all rooms' history per time index — used for Trends.
    func aggregatedSeries(for metric: ReadingMetric) -> [Double] {
        let lengths = rooms.map { $0.history.count }
        guard let minLen = lengths.min(), minLen > 0 else { return [] }
        var series: [Double] = []
        for i in 0..<minLen {
            let vals = rooms.map { $0.history[$0.history.count - minLen + i].value(for: metric) }
            series.append(vals.reduce(0, +) / Double(vals.count))
        }
        return series
    }

    // MARK: - Reset / restore

    func resetToDemo() {
        rooms = []; records = []; alerts = []; tasks = []
        seedDemo()
        save()
    }

    func clearAll() {
        rooms = []; records = []; alerts = []; tasks = []
        save()
    }

    // MARK: - Demo data

    private static func generateHistory(base room: Room, points: Int = 24) -> [Reading] {
        var readings: [Reading] = []
        let now = Date()
        for i in 0..<points {
            let hoursAgo = Double(points - i)
            let date = now.addingTimeInterval(-hoursAgo * 3600)
            let phase = Double(i) / Double(points) * .pi * 2
            let temp = room.temperature + sin(phase) * 1.8 + cos(phase * 1.7) * 0.6
            let hum = room.humidity + cos(phase) * 5 + sin(phase * 0.8) * 2
            let vent = room.ventilation + sin(phase * 1.3) * 12
            readings.append(Reading(date: date,
                                    temperature: temp,
                                    humidity: hum.clamped(to: 10...95),
                                    ventilation: vent.clamped(to: 0...100)))
        }
        return readings
    }

    private func seedDemo() {
        let specs: [(String, RoomCategory, Double, Double, Double)] = [
            ("North Barn",      .livestock,  16.2, 64, 52),
            ("Poultry House A", .poultry,    21.5, 58, 60),
            ("Greenhouse 1",    .greenhouse, 25.0, 72, 40),
            ("Milking Parlor",  .dairy,       7.5, 66, 48),
            ("Grain Storage",   .storage,    14.5, 55, 30), // slightly warm -> warning
            ("West Stable",     .stable,     17.0, 61, 55)
        ]
        var newRooms: [Room] = []
        for spec in specs {
            var room = Room(name: spec.0, category: spec.1, notes: "Sensor node online.",
                            temperature: spec.2, humidity: spec.3, ventilation: spec.4)
            room.history = AppStore.generateHistory(base: room)
            newRooms.append(room)
        }
        rooms = newRooms

        // Seed a few manual records
        if let gh = rooms.first(where: { $0.category == .greenhouse }) {
            records.append(ClimateRecord(roomID: gh.id, date: Date().addingTimeInterval(-7200),
                                         metric: .humidity, value: 72, status: .good,
                                         note: "Misting cycle complete"))
        }
        if let store = rooms.first(where: { $0.category == .storage }) {
            records.append(ClimateRecord(roomID: store.id, date: Date().addingTimeInterval(-3600),
                                         metric: .temperature, value: 14.5, status: .warning,
                                         note: "Above target, ventilation increased"))
        }

        // Seed tasks
        let cal = Calendar.current
        tasks = [
            FarmTask(title: "Check ventilation filters", detail: "Replace clogged intake filters in North Barn.",
                     dueDate: cal.date(byAdding: .hour, value: 3, to: Date()) ?? Date(),
                     priority: .high, roomID: rooms.first?.id),
            FarmTask(title: "Calibrate humidity sensor", detail: "Greenhouse 1 reads slightly high.",
                     dueDate: cal.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
                     priority: .medium, roomID: rooms.first(where: { $0.category == .greenhouse })?.id),
            FarmTask(title: "Inspect cooling unit", detail: "Milking parlor target 4–10°C.",
                     dueDate: cal.date(byAdding: .day, value: 2, to: Date()) ?? Date(),
                     priority: .low, roomID: rooms.first(where: { $0.category == .dairy })?.id)
        ]

        // Recompute alerts from seeded rooms
        for room in rooms { recomputeAlerts(for: room) }
    }

    static let defaultRecommendations: [Recommendation] = [
        Recommendation(title: "Increase airflow at midday",
                       body: "Temperatures peak between 12:00–15:00. Schedule fans to ramp up 20% to keep livestock comfortable.",
                       icon: "wind", tintHex: "22D3EE", actionLabel: "Create task"),
        Recommendation(title: "Lower greenhouse humidity",
                       body: "Humidity above 75% encourages mold. Run dehumidification or open vents after watering.",
                       icon: "drop.fill", tintHex: "3B82F6", actionLabel: "Create task"),
        Recommendation(title: "Cold-chain check for dairy",
                       body: "Keep the milking parlor between 4–10°C. Verify the compressor cycles correctly each morning.",
                       icon: "snowflake", tintHex: "22C55E", actionLabel: "Create task"),
        Recommendation(title: "Insulate at night",
                       body: "Night temperatures drop quickly. Close curtains and reduce ventilation after sunset to save energy.",
                       icon: "moon.fill", tintHex: "EAB308", actionLabel: "Create task"),
        Recommendation(title: "Watch the grain store",
                       body: "Storage zones should stay cool and dry (2–12°C). A warm spell raises spoilage risk.",
                       icon: "shippingbox.fill", tintHex: "EF4444", actionLabel: "Create task")
    ]
}

// MARK: - Small numeric helpers

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

extension ClosedRange where Bound == Double {
    var midpoint: Double { (lowerBound + upperBound) / 2 }
}
