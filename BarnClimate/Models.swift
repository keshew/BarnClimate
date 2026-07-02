//
//  Models.swift
//  BarnClimate
//
//  Data models and domain enums for the farm-climate domain.
//

import SwiftUI

// MARK: - Status

enum ClimateStatus: String, Codable, CaseIterable, Identifiable {
    case good, warning, critical
    var id: String { rawValue }

    var title: String {
        switch self {
        case .good:     return "Good"
        case .warning:  return "Warning"
        case .critical: return "Critical"
        }
    }

    var color: Color {
        switch self {
        case .good:     return Brand.good
        case .warning:  return Brand.warning
        case .critical: return Brand.critical
        }
    }

    var icon: String {
        switch self {
        case .good:     return "checkmark.circle.fill"
        case .warning:  return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }

    var rank: Int {
        switch self {
        case .good: return 0
        case .warning: return 1
        case .critical: return 2
        }
    }
}

// MARK: - Room category

enum RoomCategory: String, Codable, CaseIterable, Identifiable {
    case livestock, poultry, greenhouse, dairy, storage, stable
    var id: String { rawValue }

    var title: String {
        switch self {
        case .livestock:  return "Livestock"
        case .poultry:    return "Poultry"
        case .greenhouse: return "Greenhouse"
        case .dairy:      return "Dairy"
        case .storage:    return "Storage"
        case .stable:     return "Stable"
        }
    }

    var icon: String {
        switch self {
        case .livestock:  return "pawprint.fill"
        case .poultry:    return "hare.fill"
        case .greenhouse: return "leaf.fill"
        case .dairy:      return "drop.fill"
        case .storage:    return "shippingbox.fill"
        case .stable:     return "house.fill"
        }
    }

    var tint: Color {
        switch self {
        case .livestock:  return Brand.greenDeep
        case .poultry:    return Brand.yellowDeep
        case .greenhouse: return Brand.green
        case .dairy:      return Brand.blue
        case .storage:    return Brand.cyan
        case .stable:     return Brand.yellow
        }
    }

    /// Ideal climate window for the category (Celsius / % RH).
    var idealTemp: ClosedRange<Double> {
        switch self {
        case .livestock:  return 10...20
        case .poultry:    return 18...24
        case .greenhouse: return 20...28
        case .dairy:      return 4...10
        case .storage:    return 2...12
        case .stable:     return 12...22
        }
    }

    var idealHumidity: ClosedRange<Double> {
        switch self {
        case .livestock:  return 50...75
        case .poultry:    return 50...70
        case .greenhouse: return 60...80
        case .dairy:      return 55...75
        case .storage:    return 40...60
        case .stable:     return 50...70
        }
    }
}

// MARK: - Reading types

enum ReadingMetric: String, Codable, CaseIterable, Identifiable {
    case temperature, humidity, ventilation
    var id: String { rawValue }

    var title: String {
        switch self {
        case .temperature: return "Temperature"
        case .humidity:    return "Humidity"
        case .ventilation: return "Ventilation"
        }
    }

    var icon: String {
        switch self {
        case .temperature: return "thermometer"
        case .humidity:    return "drop.fill"
        case .ventilation: return "wind"
        }
    }

    var tint: Color {
        switch self {
        case .temperature: return Brand.critical
        case .humidity:    return Brand.blue
        case .ventilation: return Brand.cyan
        }
    }

    /// Unit suffix (temperature handled separately for °C/°F).
    var unit: String {
        switch self {
        case .temperature: return "°"
        case .humidity:    return "%"
        case .ventilation: return "%"
        }
    }
}

// MARK: - Time-series reading

struct Reading: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var date: Date
    var temperature: Double   // Celsius
    var humidity: Double       // % RH
    var ventilation: Double    // % fan power

    func value(for metric: ReadingMetric) -> Double {
        switch metric {
        case .temperature: return temperature
        case .humidity:    return humidity
        case .ventilation: return ventilation
        }
    }
}

// MARK: - Room (a barn / group / zone)

struct Room: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var category: RoomCategory
    var notes: String = ""
    var temperature: Double   // current Celsius
    var humidity: Double
    var ventilation: Double
    var createdAt: Date = Date()
    var history: [Reading] = []

    var status: ClimateStatus {
        let tStatus = Room.status(value: temperature, in: category.idealTemp, tolerance: 4)
        let hStatus = Room.status(value: humidity, in: category.idealHumidity, tolerance: 12)
        return [tStatus, hStatus].max(by: { $0.rank < $1.rank }) ?? .good
    }

    static func status(value: Double, in range: ClosedRange<Double>, tolerance: Double) -> ClimateStatus {
        if range.contains(value) { return .good }
        let distance = value < range.lowerBound ? range.lowerBound - value : value - range.upperBound
        return distance <= tolerance ? .warning : .critical
    }

    func value(for metric: ReadingMetric) -> Double {
        switch metric {
        case .temperature: return temperature
        case .humidity:    return humidity
        case .ventilation: return ventilation
        }
    }
}

// MARK: - Manual climate record (Add Record: Date / Status / Value)

struct ClimateRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var roomID: UUID?
    var date: Date
    var metric: ReadingMetric
    var value: Double          // stored in Celsius for temperature
    var status: ClimateStatus
    var note: String = ""
}

// MARK: - Alert / warning

struct ClimateAlert: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var roomID: UUID?
    var title: String
    var message: String
    var severity: ClimateStatus
    var date: Date = Date()
    var isRead: Bool = false
    var isResolved: Bool = false
}

// MARK: - Task

enum TaskPriority: String, Codable, CaseIterable, Identifiable {
    case low, medium, high
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .low:    return Brand.blue
        case .medium: return Brand.yellowDeep
        case .high:   return Brand.critical
        }
    }
}

struct FarmTask: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var detail: String = ""
    var dueDate: Date
    var isDone: Bool = false
    var priority: TaskPriority = .medium
    var roomID: UUID?
    var reminderOn: Bool = false
}

// MARK: - Recommendation

struct Recommendation: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var body: String
    var icon: String
    var tintHex: String
    var actionLabel: String

    var tint: Color { Color(hex: tintHex) }
}
