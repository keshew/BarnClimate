//
//  Components.swift
//  BarnClimate
//
//  Reusable, theme-styled UI building blocks (cards, buttons, inputs, chips).
//

import SwiftUI

// MARK: - Background

struct AppBackground: View {
    var body: some View {
        AppGradient.background.ignoresSafeArea()
    }
}

// MARK: - Button styles

struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Primary / Secondary buttons

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var gradient: LinearGradient = AppGradient.primaryButton
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon = icon {
                    Image(systemName: icon).font(.barn(17, .semibold))
                }
                Text(title).font(.barn(17, .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Brand.green.opacity(0.35), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon = icon {
                    Image(systemName: icon).font(.barn(17, .semibold))
                }
                Text(title).font(.barn(17, .semibold))
            }
            .foregroundColor(Brand.greenDeep)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Brand.green.opacity(0.4), lineWidth: 1.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Card container

struct AppCard<Content: View>: View {
    var padding: CGFloat = 16
    let content: Content
    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }
    var body: some View {
        content
            .padding(padding)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppColor.separator, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Icon badge

struct IconBadge: View {
    let systemName: String
    var color: Color = Brand.green
    var size: CGFloat = 44
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundColor(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}

// MARK: - Status pill

struct StatusPill: View {
    let status: ClimateStatus
    var compact: Bool = false
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: status.icon).font(.system(size: compact ? 10 : 12, weight: .bold))
            if !compact { Text(status.title).font(.barn(12, .bold)) }
        }
        .foregroundColor(status.color)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 5 : 6)
        .background(status.color.opacity(0.16))
        .clipShape(Capsule())
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        HStack {
            Text(title)
                .font(.barn(20, .bold))
                .foregroundColor(AppColor.text)
            Spacer()
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.barn(14, .semibold))
                        .foregroundColor(Brand.greenDeep)
                }
            }
        }
    }
}

// MARK: - Stat tile

struct StatTile: View {
    let title: String
    let value: String
    let icon: String
    var tint: Color = Brand.green
    var trend: String? = nil
    var trendUp: Bool = true

    var body: some View {
        AppCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    IconBadge(systemName: icon, color: tint, size: 38)
                    Spacer()
                    if let trend = trend {
                        HStack(spacing: 3) {
                            Image(systemName: trendUp ? "arrow.up.right" : "arrow.down.right")
                            Text(trend)
                        }
                        .font(.barn(11, .bold))
                        .foregroundColor(trendUp ? Brand.good : Brand.critical)
                    }
                }
                Text(value)
                    .font(.barn(24, .bold))
                    .foregroundColor(AppColor.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(title)
                    .font(.barn(12, .medium))
                    .foregroundColor(AppColor.textSecondary)
            }
        }
    }
}

// MARK: - Inputs

struct AppTextField: View {
    let title: String
    var placeholder: String = ""
    @Binding var text: String
    var icon: String? = nil
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.barn(13, .semibold))
                .foregroundColor(AppColor.textSecondary)
            HStack(spacing: 10) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(Brand.greenDeep)
                        .frame(width: 18)
                }
                TextField(placeholder, text: $text)
                    .font(.barn(16, .medium))
                    .foregroundColor(AppColor.text)
                    .keyboardType(keyboard)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(AppColor.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColor.separator, lineWidth: 1)
            )
        }
    }
}

struct AppTextEditor: View {
    let title: String
    @Binding var text: String
    var minHeight: CGFloat = 90

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.barn(13, .semibold))
                .foregroundColor(AppColor.textSecondary)
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Add notes…")
                        .font(.barn(16, .regular))
                        .foregroundColor(AppColor.textMuted)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 18)
                }
                TextEditor(text: $text)
                    .font(.barn(16, .medium))
                    .foregroundColor(AppColor.text)
                    .frame(minHeight: minHeight)
                    .padding(8)
                    .opacityWorkaround()
            }
            .background(AppColor.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColor.separator, lineWidth: 1)
            )
        }
    }
}

private extension View {
    // TextEditor draws its own opaque background on iOS 14/15; make it blend in.
    func opacityWorkaround() -> some View {
        self.onAppear { UITextView.appearance().backgroundColor = .clear }
    }
}

// MARK: - Selectable chip

struct SelectableChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    var tint: Color = Brand.green
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                }
                Text(title).font(.barn(14, .semibold)).lineLimit(1)
            }
            .foregroundColor(isSelected ? .white : AppColor.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isSelected { tint } else { AppColor.surface }
                }
            )
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSelected ? Color.clear : AppColor.separator, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.94))
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Brand.green.opacity(0.12)).frame(width: 96, height: 96)
                Image(systemName: icon)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundColor(Brand.greenDeep)
            }
            Text(title)
                .font(.barn(19, .bold))
                .foregroundColor(AppColor.text)
            Text(message)
                .font(.barn(14, .regular))
                .foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle).font(.barn(15, .semibold)).foregroundColor(.white)
                        .padding(.horizontal, 22).padding(.vertical, 12)
                        .background(AppGradient.primaryButton)
                        .clipShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Metric row

struct MetricRow: View {
    let metric: ReadingMetric
    let valueText: String
    let progress: Double // 0...1
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Label {
                    Text(metric.title).font(.barn(14, .semibold)).foregroundColor(AppColor.text)
                } icon: {
                    Image(systemName: metric.icon).foregroundColor(metric.tint)
                }
                Spacer()
                Text(valueText).font(.barn(15, .bold)).foregroundColor(AppColor.text)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(metric.tint.opacity(0.15)).frame(height: 8)
                    Capsule().fill(metric.tint)
                        .frame(width: max(6, geo.size.width * CGFloat(progress.clamped(to: 0...1))), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Share sheet (UIActivityViewController)

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
