//
//  OnboardingView.swift
//  BarnClimate
//
//  Three illustrated onboarding scenes, each with a distinct interaction:
//   1. Smart control  — tap to burst particles + spin the fan
//   2. Track everything — drag a sensor node to drive the live bars
//   3. Save time       — tilt / gyroscope parallax (auto-sway fallback)
//

import SwiftUI
import CoreMotion

// MARK: - Container

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var page = 0
    private let pageCount = 3

    var body: some View {
        ZStack {
            AppBackground()

            TabView(selection: $page) {
                OnboardSmartControl().tag(0)
                OnboardTrackEverything().tag(1)
                OnboardSaveTime().tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

            VStack {
                HStack {
                    Spacer()
                    Button(action: finish) {
                        Text("Skip")
                            .font(.barn(15, .semibold))
                            .foregroundColor(AppColor.textSecondary)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(AppColor.surface.opacity(0.7))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()

                HStack(alignment: .center) {
                    // Dots
                    HStack(spacing: 8) {
                        ForEach(0..<pageCount, id: \.self) { i in
                            Capsule()
                                .fill(i == page ? Brand.greenDeep : Brand.green.opacity(0.3))
                                .frame(width: i == page ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: page)
                        }
                    }
                    Spacer()
                    Button(action: next) {
                        HStack(spacing: 8) {
                            Text(page == pageCount - 1 ? "Get Started" : "Next")
                                .font(.barn(16, .bold))
                            Image(systemName: page == pageCount - 1 ? "checkmark" : "arrow.right")
                                .font(.barn(15, .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 22).padding(.vertical, 14)
                        .background(AppGradient.primaryButton)
                        .clipShape(Capsule())
                        .shadow(color: Brand.green.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }

    private func next() {
        if page < pageCount - 1 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { page += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        onComplete()
    }
}

// MARK: - Shared scaffold

private struct OnboardScaffold<Scene: View>: View {
    let title: String
    let subtitle: String
    let scene: Scene
    init(title: String, subtitle: String, @ViewBuilder scene: () -> Scene) {
        self.title = title
        self.subtitle = subtitle
        self.scene = scene()
    }
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)
            scene
                .frame(height: 320)
                .padding(.horizontal, 24)
            Spacer(minLength: 24)
            VStack(spacing: 12) {
                Text(title)
                    .font(.barn(30, .heavy))
                    .foregroundColor(AppColor.text)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.barn(16, .medium))
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer(minLength: 120)
        }
    }
}

// MARK: - Screen 1: Smart control (tap to burst)

private struct OnboardSmartControl: View {
    @State private var fanSpin = false
    @State private var burstID = 0
    @State private var burst: CGFloat = 0
    @State private var pop: CGFloat = 1

    var body: some View {
        OnboardScaffold(title: "Smart control",
                        subtitle: "Tap the fan to adjust airflow. Every control responds instantly across your barn.") {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Brand.green.opacity(0.16), .clear],
                                         center: .center, startRadius: 10, endRadius: 150))

                // Burst particles
                ForEach(0..<10, id: \.self) { i in
                    let angle = Double(i) / 10.0 * 2 * .pi
                    Circle()
                        .fill(i % 2 == 0 ? Brand.green : Brand.yellow)
                        .frame(width: 12, height: 12)
                        .offset(x: cos(angle) * Double(burst) * 110,
                                y: sin(angle) * Double(burst) * 110)
                        .opacity(Double(1 - burst))
                }
                .id(burstID)

                // Fan control
                Button(action: trigger) {
                    ZStack {
                        Circle()
                            .fill(AppGradient.blueButton)
                            .frame(width: 130, height: 130)
                            .shadow(color: Brand.blue.opacity(0.4), radius: 16, x: 0, y: 8)
                        Image(systemName: "wind")
                            .font(.system(size: 56, weight: .bold))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(fanSpin ? 360 : 0))
                    }
                    .scaleEffect(pop)
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.9))

                Text("Tap me")
                    .font(.barn(13, .bold))
                    .foregroundColor(Brand.blue)
                    .offset(y: 96)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) { fanSpin = true }
        }
        .onDisappear {
            fanSpin = false      // stop infinite spin
            burst = 0
        }
    }

    private func trigger() {
        Haptics.tap()
        burstID += 1
        burst = 0
        pop = 0.85
        withAnimation(.easeOut(duration: 0.7)) { burst = 1 }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { pop = 1 }
    }
}

// MARK: - Screen 2: Track everything (drag)

private struct OnboardTrackEverything: View {
    @State private var dragX: CGFloat = 0.5

    private let barCount = 12

    var body: some View {
        OnboardScaffold(title: "Track everything",
                        subtitle: "Drag the sensor to scrub history. Temperature, humidity and ventilation update live.") {
            GeometryReader { geo in
                VStack(spacing: 18) {
                    barsView
                    readoutView
                    trackView(width: geo.size.width)
                    Text("Drag the sensor")
                        .font(.barn(13, .bold))
                        .foregroundColor(Brand.greenDeep)
                }
            }
        }
        .onDisappear { dragX = 0.5 }
    }

    private var barsView: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(0..<barCount, id: \.self) { i in
                bar(index: i)
            }
        }
        .frame(height: 170, alignment: .bottom)
    }

    private func bar(index: Int) -> some View {
        let center: CGFloat = CGFloat(index) / CGFloat(barCount - 1)
        let dist: CGFloat = abs(center - dragX)
        let intensity: CGFloat = 1 - min(dist * 2.2, 1)
        let height: CGFloat = 30 + intensity * 130
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(LinearGradient(colors: [Brand.green, Brand.cyan],
                                 startPoint: .top, endPoint: .bottom))
            .frame(height: height)
            .opacity(Double(0.55 + intensity * 0.45))
    }

    private var readoutView: some View {
        let temp: Double = 12 + Double(dragX) * 16
        let hum: Double = 50 + Double(dragX) * 35
        return HStack(spacing: 14) {
            readout(icon: "thermometer", tint: Brand.critical, value: String(format: "%.1f°C", temp))
            readout(icon: "drop.fill", tint: Brand.blue, value: String(format: "%.0f%%", hum))
        }
    }

    private func trackView(width: CGFloat) -> some View {
        let fillWidth: CGFloat = max(14, dragX * width)
        let nodeOffset: CGFloat = dragX * width - 17
        return ZStack(alignment: .leading) {
            Capsule().fill(Brand.green.opacity(0.18)).frame(height: 10)
            Capsule().fill(AppGradient.primaryButton).frame(width: fillWidth, height: 10)
            Circle()
                .fill(Color.white)
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(Brand.greenDeep, lineWidth: 3))
                .overlay(Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Brand.greenDeep))
                .shadow(color: Brand.green.opacity(0.4), radius: 6, x: 0, y: 3)
                .offset(x: nodeOffset)
        }
        .frame(height: 34)
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    dragX = (v.location.x / width).clamped(to: 0...1)
                }
        )
    }

    private func readout(icon: String, tint: Color, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(tint)
            Text(value).font(.barn(18, .bold)).foregroundColor(AppColor.text)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(AppColor.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppColor.separator, lineWidth: 1))
    }
}

// MARK: - Screen 3: Save time (tilt parallax)

private final class MotionManager: ObservableObject {
    private let manager = CMMotionManager()
    @Published var roll: Double = 0
    @Published var pitch: Double = 0
    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self = self, let m = motion else { return }
            self.roll = m.attitude.roll
            self.pitch = m.attitude.pitch
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        roll = 0; pitch = 0
    }
}

private struct OnboardSaveTime: View {
    @StateObject private var motion = MotionManager()
    @State private var autoPhase: CGFloat = 0

    var body: some View {
        OnboardScaffold(title: "Save time",
                        subtitle: "Automations and reminders do the watching for you. Tilt your phone to explore the scene.") {
            ZStack {
                // Layer A — far hills (small shift)
                layer(offset: 0.4, content:
                    RoundedRectangle(cornerRadius: 40)
                        .fill(Brand.green.opacity(0.18))
                        .frame(width: 300, height: 170)
                        .offset(y: 70)
                )
                // Layer B — barn (medium shift)
                layer(offset: 1.0, content:
                    ZStack {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(AppGradient.primaryButton)
                            .frame(width: 150, height: 130)
                        Image(systemName: "house.fill")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .shadow(color: Brand.green.opacity(0.35), radius: 14, x: 0, y: 8)
                )
                // Layer C — floating automation chips (large shift)
                layer(offset: 1.8, content:
                    ZStack {
                        floatChip("clock.fill", Brand.yellowDeep).offset(x: -110, y: -70)
                        floatChip("bell.fill", Brand.blue).offset(x: 110, y: -40)
                        floatChip("bolt.fill", Brand.green).offset(x: 90, y: 80)
                    }
                )
            }
        }
        .onAppear {
            if motion.isAvailable {
                motion.start()
            } else {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    autoPhase = 1
                }
            }
        }
        .onDisappear {
            motion.stop()
            autoPhase = 0   // stop fallback loop
        }
    }

    private func shift(_ factor: Double) -> CGSize {
        if motion.isAvailable {
            let x = motion.roll * 26 * factor
            let y = motion.pitch * 22 * factor
            return CGSize(width: x.clamped(to: -40...40), height: y.clamped(to: -40...40))
        } else {
            let p = Double(autoPhase) * 2 - 1
            return CGSize(width: p * 18 * factor, height: p * 8 * factor)
        }
    }

    private func layer<V: View>(offset factor: Double, content: V) -> some View {
        content.offset(shift(factor))
    }

    private func floatChip(_ icon: String, _ tint: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 50, height: 50)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: tint.opacity(0.4), radius: 8, x: 0, y: 4)
    }
}
