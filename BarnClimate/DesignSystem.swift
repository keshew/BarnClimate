//
//  DesignSystem.swift
//  BarnClimate
//
//  Color palette, typography, adaptive colors and app-wide settings.
//  iOS 14.0+ — no APIs newer than iOS 14 are used here.
//

import SwiftUI

// MARK: - Hex color helpers

extension UIColor {
    convenience init(hex: String) {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if str.hasPrefix("#") { str.removeFirst() }
        if str.count == 6 { str.append("FF") } // add full alpha
        var value: UInt64 = 0
        Scanner(string: str).scanHexInt64(&value)
        let r = CGFloat((value & 0xFF000000) >> 24) / 255.0
        let g = CGFloat((value & 0x00FF0000) >> 16) / 255.0
        let b = CGFloat((value & 0x0000FF00) >> 8) / 255.0
        let a = CGFloat(value & 0x000000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

extension Color {
    init(hex: String) {
        self.init(UIColor(hex: hex))
    }

    /// Adaptive color that resolves to a different hex in dark mode.
    static func adaptive(light: String, dark: String) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

// MARK: - Brand palette (constant across light/dark)

enum Brand {
    static let green      = Color(hex: "22C55E")
    static let greenDeep  = Color(hex: "16A34A")
    static let yellow     = Color(hex: "FACC15")
    static let yellowDeep = Color(hex: "EAB308")
    static let blue       = Color(hex: "3B82F6")
    static let cyan       = Color(hex: "22D3EE")

    // Status colors
    static let good       = Color(hex: "22C55E")
    static let warning    = Color(hex: "FACC15")
    static let critical   = Color(hex: "EF4444")
}

// MARK: - Adaptive surface palette

enum AppColor {
    static let background      = Color.adaptive(light: "FFFBEB", dark: "0E1613")
    static let backgroundAlt   = Color.adaptive(light: "F7FDF9", dark: "0A110D")
    static let surface         = Color.adaptive(light: "FFFFFF", dark: "16221C")
    static let surfaceAlt      = Color.adaptive(light: "F1FAF4", dark: "1C2A23")
    static let surfaceElevated = Color.adaptive(light: "FFFFFF", dark: "1E2E26")
    static let text            = Color.adaptive(light: "064E3B", dark: "ECFDF5")
    static let textSecondary   = Color.adaptive(light: "065F46", dark: "8FD3B0")
    static let textMuted       = Color.adaptive(light: "5B8A77", dark: "5E8C76")
    static let separator       = Color.adaptive(light: "E4F0E8", dark: "26342C")
    static let fieldBackground = Color.adaptive(light: "F4FBF7", dark: "111A15")
}

// MARK: - Gradients

enum AppGradient {
    static var background: LinearGradient {
        LinearGradient(
            colors: [AppColor.background, AppColor.backgroundAlt],
            startPoint: .top, endPoint: .bottom
        )
    }

    static var primaryButton: LinearGradient {
        LinearGradient(colors: [Brand.green, Brand.greenDeep],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var accentButton: LinearGradient {
        LinearGradient(colors: [Brand.yellow, Brand.yellowDeep],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var blueButton: LinearGradient {
        LinearGradient(colors: [Brand.blue, Brand.cyan],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func status(_ status: ClimateStatus) -> LinearGradient {
        let base = status.color
        return LinearGradient(colors: [base, base.opacity(0.7)],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Typography (rounded, farm-friendly)

extension Font {
    static func barn(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Theme mode

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.fill"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - Temperature units

enum TempUnit: String, CaseIterable, Identifiable {
    case celsius, fahrenheit
    var id: String { rawValue }

    var title: String { self == .celsius ? "Celsius (°C)" : "Fahrenheit (°F)" }
    var symbol: String { self == .celsius ? "°C" : "°F" }

    /// Convert a stored Celsius value to the display unit.
    func value(fromCelsius c: Double) -> Double {
        self == .celsius ? c : c * 9.0 / 5.0 + 32.0
    }

    /// Convert a display value back to Celsius for storage.
    func toCelsius(_ value: Double) -> Double {
        self == .celsius ? value : (value - 32.0) * 5.0 / 9.0
    }

    func format(celsius c: Double, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f%@", value(fromCelsius: c), symbol)
    }
}

// MARK: - App settings (app-wide, persisted, reactive)

final class AppSettings: ObservableObject {

    private enum Keys {
        static let theme = "settings.themeMode"
        static let unit = "settings.tempUnit"
        static let farmName = "settings.farmName"
        static let dailyReminder = "settings.dailyReminderEnabled"
        static let dailyReminderTime = "settings.dailyReminderTime"
        static let criticalAlerts = "settings.criticalAlertsEnabled"
        static let haptics = "settings.hapticsEnabled"
    }

    @Published var themeMode: AppThemeMode { didSet { persist() } }
    @Published var tempUnit: TempUnit { didSet { persist() } }
    @Published var farmName: String { didSet { persist() } }
    @Published var dailyReminderEnabled: Bool { didSet { persist() } }
    @Published var dailyReminderTime: Date { didSet { persist() } }
    @Published var criticalAlertsEnabled: Bool { didSet { persist() } }
    @Published var hapticsEnabled: Bool { didSet { persist() } }

    init() {
        let d = UserDefaults.standard
        themeMode = AppThemeMode(rawValue: d.string(forKey: Keys.theme) ?? "") ?? .system
        tempUnit = TempUnit(rawValue: d.string(forKey: Keys.unit) ?? "") ?? .celsius
        farmName = d.string(forKey: Keys.farmName) ?? "Green Meadow Farm"
        dailyReminderEnabled = d.bool(forKey: Keys.dailyReminder)
        if let t = d.object(forKey: Keys.dailyReminderTime) as? Double {
            dailyReminderTime = Date(timeIntervalSince1970: t)
        } else {
            // default 08:00 today
            var comps = DateComponents()
            comps.hour = 8; comps.minute = 0
            dailyReminderTime = Calendar.current.date(from: comps) ?? Date()
        }
        // default ON for critical & haptics on first launch
        criticalAlertsEnabled = d.object(forKey: Keys.criticalAlerts) as? Bool ?? true
        hapticsEnabled = d.object(forKey: Keys.haptics) as? Bool ?? true
    }

    private func persist() {
        let d = UserDefaults.standard
        d.set(themeMode.rawValue, forKey: Keys.theme)
        d.set(tempUnit.rawValue, forKey: Keys.unit)
        d.set(farmName, forKey: Keys.farmName)
        d.set(dailyReminderEnabled, forKey: Keys.dailyReminder)
        d.set(dailyReminderTime.timeIntervalSince1970, forKey: Keys.dailyReminderTime)
        d.set(criticalAlertsEnabled, forKey: Keys.criticalAlerts)
        d.set(hapticsEnabled, forKey: Keys.haptics)
    }

    var colorScheme: ColorScheme? { themeMode.colorScheme }

    /// Format a Celsius value for display in the chosen unit.
    func temperatureText(_ celsius: Double, decimals: Int = 1) -> String {
        tempUnit.format(celsius: celsius, decimals: decimals)
    }
}

// MARK: - Haptics helper

enum Haptics {
    static func tap(_ enabled: Bool = true) {
        guard enabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
    }
    static func success(_ enabled: Bool = true) {
        guard enabled else { return }
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
    }
    static func warning(_ enabled: Bool = true) {
        guard enabled else { return }
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.warning)
    }
}
