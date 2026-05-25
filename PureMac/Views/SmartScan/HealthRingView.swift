import SwiftUI

struct HealthRingView: View {
    let score: Int
    let tier: HealthScore.Tier
    var size: CGFloat = 200

    @State private var animatedTrim: Double = 0

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: strokeWidth)
                .frame(width: size, height: size)

            // Progress arc
            Circle()
                .trim(from: 0, to: animatedTrim)
                .stroke(
                    AngularGradient(
                        colors: tier.gradientColors,
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(Double(score) * 3.6 - 90)
                    ),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(
                    .spring(.snappy(duration: 1.2, extraBounce: 0.1)),
                    value: animatedTrim
                )

            // Center content
            VStack(spacing: 4) {
                Text("\(score)")
                    .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(score)))
                    .animation(.spring(.smooth), value: score)

                Text(tier.label.uppercased())
                    .font(.system(size: size * 0.075, weight: .bold))
                    .foregroundStyle(tier.color)
                    .tracking(1.5)
            }
        }
        .onChange(of: score, initial: true) { _, newValue in
            animatedTrim = Double(newValue) / 100.0
        }
    }

    private var strokeWidth: CGFloat { size * 0.08 }
}

// MARK: - Scanning ring animation

struct ScanningRingView: View {
    var size: CGFloat = 200

    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: size * 0.08)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(
                    LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(rotation))
                .animation(
                    .linear(duration: 1.2).repeatForever(autoreverses: false),
                    value: rotation
                )

            VStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: size * 0.18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Text("Scanning…")
                    .font(.system(size: size * 0.09, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .onAppear { rotation = 360 }
    }
}
