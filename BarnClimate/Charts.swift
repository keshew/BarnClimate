//
//  Charts.swift
//  BarnClimate
//
//  Hand-built charts (line, area, bar, ring gauge, sparkline) using Shape/Path.
//  Swift Charts is iOS 16+, so everything here is drawn manually for iOS 14.
//

import SwiftUI

// MARK: - Normalisation helpers

private func normalized(_ values: [Double]) -> (points: [Double], minV: Double, maxV: Double) {
    guard let minV = values.min(), let maxV = values.max() else { return ([], 0, 1) }
    let span = max(maxV - minV, 0.0001)
    return (values.map { ($0 - minV) / span }, minV, maxV)
}

// MARK: - Line + area chart

struct LineAreaChart: View {
    let values: [Double]
    var color: Color = Brand.green
    var showDots: Bool = true
    var animate: Bool = true

    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let norm = normalized(values)
            let pts = points(in: geo.size, normalized: norm.points)
            ZStack {
                // Area fill
                areaPath(points: pts, height: geo.size.height)
                    .fill(LinearGradient(colors: [color.opacity(0.30), color.opacity(0.02)],
                                         startPoint: .top, endPoint: .bottom))
                    .opacity(Double(progress))
                // Line
                linePath(points: pts)
                    .trim(from: 0, to: progress)
                    .stroke(LinearGradient(colors: [color, color.opacity(0.7)],
                                           startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                // Dots
                if showDots {
                    ForEach(Array(pts.enumerated()), id: \.offset) { idx, p in
                        Circle()
                            .fill(color)
                            .frame(width: 6, height: 6)
                            .position(p)
                            .opacity(Double(progress))
                    }
                }
            }
        }
        .onAppear {
            if animate {
                withAnimation(.easeOut(duration: 0.9)) { progress = 1 }
            } else { progress = 1 }
        }
        .onDisappear { progress = 0 }
    }

    private func points(in size: CGSize, normalized: [Double]) -> [CGPoint] {
        guard normalized.count > 1 else {
            return normalized.map { CGPoint(x: size.width / 2, y: size.height * (1 - CGFloat($0))) }
        }
        let stepX = size.width / CGFloat(normalized.count - 1)
        let topPad: CGFloat = 8, bottomPad: CGFloat = 8
        let usable = size.height - topPad - bottomPad
        return normalized.enumerated().map { idx, v in
            CGPoint(x: CGFloat(idx) * stepX, y: topPad + usable * (1 - CGFloat(v)))
        }
    }

    private func linePath(points: [CGPoint]) -> Path {
        Path { p in
            guard let first = points.first else { return }
            p.move(to: first)
            for pt in points.dropFirst() { p.addLine(to: pt) }
        }
    }

    private func areaPath(points: [CGPoint], height: CGFloat) -> Path {
        Path { p in
            guard let first = points.first, let last = points.last else { return }
            p.move(to: CGPoint(x: first.x, y: height))
            p.addLine(to: first)
            for pt in points.dropFirst() { p.addLine(to: pt) }
            p.addLine(to: CGPoint(x: last.x, y: height))
            p.closeSubpath()
        }
    }
}

// MARK: - Sparkline (compact, no dots)

struct Sparkline: View {
    let values: [Double]
    var color: Color = Brand.green
    var body: some View {
        GeometryReader { geo in
            let norm = normalized(values)
            let pts = points(in: geo.size, normalized: norm.points)
            ZStack {
                Path { p in
                    guard let first = pts.first, let last = pts.last else { return }
                    p.move(to: CGPoint(x: first.x, y: geo.size.height))
                    p.addLine(to: first)
                    for pt in pts.dropFirst() { p.addLine(to: pt) }
                    p.addLine(to: CGPoint(x: last.x, y: geo.size.height))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [color.opacity(0.25), color.opacity(0.0)],
                                     startPoint: .top, endPoint: .bottom))
                Path { p in
                    guard let first = pts.first else { return }
                    p.move(to: first)
                    for pt in pts.dropFirst() { p.addLine(to: pt) }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func points(in size: CGSize, normalized: [Double]) -> [CGPoint] {
        guard normalized.count > 1 else { return [CGPoint(x: 0, y: size.height / 2)] }
        let stepX = size.width / CGFloat(normalized.count - 1)
        return normalized.enumerated().map { idx, v in
            CGPoint(x: CGFloat(idx) * stepX, y: 4 + (size.height - 8) * (1 - CGFloat(v)))
        }
    }
}

// MARK: - Bar chart

struct BarChart: View {
    let values: [Double]
    var labels: [String] = []
    var color: Color = Brand.green
    @State private var grow: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let maxV = max(values.max() ?? 1, 0.0001)
            let count = values.count
            let spacing: CGFloat = 8
            let barWidth = count > 0 ? (geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count) : 0
            let labelHeight: CGFloat = labels.isEmpty ? 0 : 18
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(0..<count, id: \.self) { i in
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(color.opacity(0.12))
                                .frame(height: geo.size.height - labelHeight)
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(LinearGradient(colors: [color, color.opacity(0.6)],
                                                     startPoint: .top, endPoint: .bottom))
                                .frame(height: (geo.size.height - labelHeight) * CGFloat(values[i] / maxV) * grow)
                        }
                        if !labels.isEmpty {
                            Text(i < labels.count ? labels[i] : "")
                                .font(.barn(10, .medium))
                                .foregroundColor(AppColor.textSecondary)
                                .lineLimit(1)
                                .frame(height: labelHeight)
                        }
                    }
                    .frame(width: barWidth)
                }
            }
        }
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { grow = 1 } }
        .onDisappear { grow = 0 }
    }
}

// MARK: - Ring gauge

struct RingGauge: View {
    let progress: Double // 0...1
    var lineWidth: CGFloat = 12
    var color: Color = Brand.green
    var label: String
    var caption: String
    @State private var animated: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: animated)
                .stroke(AngularGradient(gradient: Gradient(colors: [color.opacity(0.6), color]),
                                        center: .center),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text(label)
                    .font(.barn(22, .bold))
                    .foregroundColor(AppColor.text)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(caption)
                    .font(.barn(11, .medium))
                    .foregroundColor(AppColor.textSecondary)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) { animated = CGFloat(progress.clamped(to: 0...1)) }
        }
        .onChange(of: progress) { new in
            withAnimation(.easeOut(duration: 0.6)) { animated = CGFloat(new.clamped(to: 0...1)) }
        }
        .onDisappear { animated = 0 }
    }
}

// MARK: - Donut status breakdown

struct StatusDonut: View {
    let good: Int
    let warning: Int
    let critical: Int
    @State private var appear: CGFloat = 0

    private var total: Double { Double(max(good + warning + critical, 1)) }

    var body: some View {
        ZStack {
            segment(start: 0, value: Double(good), color: Brand.good)
            segment(start: Double(good), value: Double(warning), color: Brand.warning)
            segment(start: Double(good + warning), value: Double(critical), color: Brand.critical)
            VStack(spacing: 0) {
                Text("\(good + warning + critical)")
                    .font(.barn(26, .bold)).foregroundColor(AppColor.text)
                Text("Zones").font(.barn(11, .medium)).foregroundColor(AppColor.textSecondary)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.8)) { appear = 1 } }
        .onDisappear { appear = 0 }
    }

    private func segment(start: Double, value: Double, color: Color) -> some View {
        Circle()
            .trim(from: CGFloat(start / total),
                  to: CGFloat((start + value * Double(appear)) / total))
            .stroke(color, style: StrokeStyle(lineWidth: 18, lineCap: .butt))
            .rotationEffect(.degrees(-90))
    }
}
