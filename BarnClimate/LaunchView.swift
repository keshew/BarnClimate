//
//  LaunchView.swift
//  BarnClimate
//
//  Thematic splash: drifting pollen motes (the air/climate), pulsing
//  ventilation rings (airflow), a slowly turning sun, and a spring-entrance
//  barn emblem. Three simultaneously animated layers, a single coordinator
//  timer, and full animation cleanup on disappear.
//

import SwiftUI

private struct Mote: Identifiable {
    let id: Int
    let x: CGFloat       // 0...1 horizontal base
    let size: CGFloat
    let offset: CGFloat  // 0...1 phase offset
    let speed: CGFloat
    let drift: CGFloat
}

struct LaunchView: View {
    let onFinished: () -> Void

    // Staged reveal flags
    @State private var bgIn = false
    @State private var showRings = false
    @State private var showLogo = false

    // Continuous (infinite) loop drivers
    @State private var riseProgress: CGFloat = 0
    @State private var ringProgress: CGFloat = 0
    @State private var gradientShift = false
    @State private var sunSpin = false
    @State private var isAnimating = false

    // Exit transition
    @State private var exitScale: CGFloat = 1
    @State private var exitOpacity: Double = 1

    // Single coordinator
    @State private var elapsed: Double = 0
    @State private var coordinator: Timer?
    @State private var didFinish = false

    private let motes: [Mote] = (0..<16).map { i in
        let f = CGFloat(i)
        return Mote(id: i,
                    x: (f * 0.137).truncatingRemainder(dividingBy: 1),
                    size: 4 + (f * 1.7).truncatingRemainder(dividingBy: 8),
                    offset: (f * 0.061).truncatingRemainder(dividingBy: 1),
                    speed: 0.6 + (f * 0.07).truncatingRemainder(dividingBy: 0.6),
                    drift: 10 + (f * 3).truncatingRemainder(dividingBy: 26))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                background
                ventilationRings(in: geo.size)
                motesLayer(in: geo.size)
                emblem
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .scaleEffect(exitScale)
        .opacity(exitOpacity)
        .onAppear(perform: start)
        .onDisappear(perform: cleanup)
    }

    // MARK: - Layer 1: background

    private var background: some View {
        LinearGradient(
            colors: gradientShift
                ? [Color(hex: "F7FDF9"), Color(hex: "DCFCE7"), Color(hex: "FFFBEB")]
                : [Color(hex: "FFFBEB"), Color(hex: "ECFDF5"), Color(hex: "D1FAE5")],
            startPoint: gradientShift ? .topLeading : .top,
            endPoint: gradientShift ? .bottomTrailing : .bottom
        )
        .opacity(bgIn ? 1 : 0)
        .ignoresSafeArea()
        .overlay(
            // soft sun glow, slowly rotating
            Circle()
                .fill(RadialGradient(colors: [Brand.yellow.opacity(0.45), .clear],
                                     center: .center, startRadius: 4, endRadius: 160))
                .frame(width: 320, height: 320)
                .offset(x: 110, y: -240)
                .rotationEffect(.degrees(sunSpin ? 360 : 0))
                .opacity(bgIn ? 1 : 0)
        )
    }

    // MARK: - Layer 2: ventilation rings (airflow)

    private func ventilationRings(in size: CGSize) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let phase = (ringProgress + CGFloat(i) * 0.33).truncatingRemainder(dividingBy: 1)
                Circle()
                    .stroke(Brand.green.opacity(Double(1 - phase) * 0.5), lineWidth: 2.5)
                    .frame(width: 80 + phase * 240, height: 80 + phase * 240)
            }
        }
        .position(x: size.width / 2, y: size.height / 2 - 30)
        .opacity(showRings ? 1 : 0)
        .scaleEffect(showRings ? 1 : 0.6)
    }

    // MARK: - Layer 2b: drifting motes

    private func motesLayer(in size: CGSize) -> some View {
        ZStack {
            ForEach(motes) { mote in
                let cycle = (riseProgress * mote.speed + mote.offset).truncatingRemainder(dividingBy: 1)
                let y = size.height * (1 - cycle)
                let x = size.width * mote.x + sin(cycle * .pi * 2) * mote.drift
                Circle()
                    .fill(LinearGradient(colors: [Brand.green.opacity(0.7), Brand.yellow.opacity(0.6)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: mote.size, height: mote.size)
                    .position(x: x, y: y)
                    .opacity(Double(sin(cycle * .pi)) * (showRings ? 0.9 : 0))
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Layer 3: emblem + title

    private var emblem: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(AppGradient.primaryButton)
                    .frame(width: 112, height: 112)
                    .shadow(color: Brand.green.opacity(0.5), radius: 18, x: 0, y: 10)
                Image(systemName: "house.fill")
                    .font(.system(size: 46, weight: .bold))
                    .foregroundColor(.white)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Brand.yellow)
                    .offset(x: 30, y: -34)
            }
            .scaleEffect(showLogo ? 1 : 0.4)
            .opacity(showLogo ? 1 : 0)

            VStack(spacing: 6) {
                Text("BarnClimate")
                    .font(.barn(34, .heavy))
                    .foregroundColor(Color(hex: "064E3B"))
                Text("Farm climate, under control")
                    .font(.barn(15, .medium))
                    .foregroundColor(Color(hex: "065F46"))
            }
            .opacity(showLogo ? 1 : 0)
            .offset(y: showLogo ? 0 : 16)
        }
    }

    // MARK: - Coordinator

    private func start() {
        withAnimation(.easeOut(duration: 0.6)) { bgIn = true }

        // Infinite loops
        withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) { riseProgress = 1 }
        withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)) { ringProgress = 1 }
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) { gradientShift = true }
        withAnimation(.linear(duration: 24).repeatForever(autoreverses: false)) { sunSpin = true }
        isAnimating = true

        coordinator?.invalidate()
        elapsed = 0
        coordinator = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            elapsed += 0.05
            if elapsed >= 0.6 && !showRings {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { showRings = true }
            }
            if elapsed >= 1.4 && !showLogo {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { showLogo = true }
            }
            if elapsed >= 2.5 && exitScale == 1 {
                withAnimation(.easeIn(duration: 0.45)) {
                    exitScale = 1.25
                    exitOpacity = 0
                }
            }
            if elapsed >= 2.95 && !didFinish {
                didFinish = true
                cleanup()
                onFinished()
            }
        }
    }

    private func cleanup() {
        coordinator?.invalidate()
        coordinator = nil
        isAnimating = false
        // Reset infinite-loop drivers so animations don't leak into the next screen.
        riseProgress = 0
        ringProgress = 0
        gradientShift = false
        sunSpin = false
    }
}
