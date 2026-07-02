//
//  RecommendationsView.swift
//  BarnClimate
//
//  Screen 12 — Recommendations: advice and one-tap actions.
//

import SwiftUI

struct RecommendationsView: View {
    @EnvironmentObject var store: AppStore
    @State private var draftTask: TaskDraft?

    // Wrapper so .sheet(item:) can carry recommendation context.
    struct TaskDraft: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    intro
                    ForEach(dynamicTips) { tip in
                        recommendationCard(tip)
                    }
                    ForEach(store.recommendations) { rec in
                        recommendationCard(TaskDraft(title: rec.title, detail: rec.body),
                                           icon: rec.icon, tint: rec.tint, action: rec.actionLabel)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitle("Recommendations", displayMode: .inline)
        .sheet(item: $draftTask) { draft in
            AddTaskView(presetTitle: draft.title, presetDetail: draft.detail)
        }
    }

    private var intro: some View {
        AppCard {
            HStack(spacing: 14) {
                IconBadge(systemName: "sparkles", color: Brand.yellowDeep, size: 50)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Smart suggestions").font(.barn(17, .bold)).foregroundColor(AppColor.text)
                    Text("Based on your current readings and ideal climate windows.")
                        .font(.barn(13, .medium)).foregroundColor(AppColor.textSecondary)
                }
                Spacer()
            }
        }
    }

    /// Live tips generated from the actual data.
    private var dynamicTips: [TaskDraft] {
        var tips: [TaskDraft] = []
        for room in store.rooms where room.status != .good {
            if !room.category.idealTemp.contains(room.temperature) {
                let dir = room.temperature > room.category.idealTemp.upperBound ? "Cool down" : "Warm up"
                tips.append(TaskDraft(
                    title: "\(dir) \(room.name)",
                    detail: String(format: "%@ is %.1f°C — target %.0f–%.0f°C. Adjust ventilation or heating.",
                                   room.name, room.temperature,
                                   room.category.idealTemp.lowerBound, room.category.idealTemp.upperBound)))
            } else if !room.category.idealHumidity.contains(room.humidity) {
                tips.append(TaskDraft(
                    title: "Balance humidity in \(room.name)",
                    detail: String(format: "Humidity is %.0f%% — target %.0f–%.0f%%.",
                                   room.humidity,
                                   room.category.idealHumidity.lowerBound, room.category.idealHumidity.upperBound)))
            }
        }
        return tips
    }

    private func recommendationCard(_ tip: TaskDraft,
                                    icon: String = "exclamationmark.bubble.fill",
                                    tint: Color = Brand.green,
                                    action: String = "Create task") -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    IconBadge(systemName: icon, color: tint, size: 44)
                    Text(tip.title).font(.barn(16, .bold)).foregroundColor(AppColor.text)
                    Spacer()
                }
                Text(tip.detail).font(.barn(13, .regular)).foregroundColor(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    draftTask = tip
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text(action).font(.barn(14, .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(LinearGradient(colors: [tint, tint.opacity(0.75)],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }
}
