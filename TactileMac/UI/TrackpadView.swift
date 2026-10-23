import SwiftUI

struct TrackpadView: View {
    var pulseToken: Int = 0
    var pulseDirection: String = "click"
    @Environment(\.colorScheme) private var colorScheme
    @State private var ripple = false
    @State private var cursorOffset: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color.white.opacity(0.10), Color.white.opacity(0.035)]
                                : [Color.white, Color(nsColor: .controlBackgroundColor)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Theme.cardStroke(colorScheme), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.10), radius: 16, y: 8)

                // Subtle surface texture.
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        RadialGradient(colors: [Theme.purple.opacity(0.06), .clear], center: .topLeading, startRadius: 2, endRadius: size.width * 0.9)
                    )
                    .padding(2)

                // Center seam used by Force Touch trackpads.
                Rectangle()
                    .fill(Theme.divider.opacity(0.28))
                    .frame(width: 0.7, height: size.height * 0.55)
                    .opacity(0.5)

                if ripple {
                    Circle()
                        .stroke(Theme.teal.opacity(0.5), lineWidth: 2)
                        .frame(width: size.width * 0.16, height: size.width * 0.16)
                        .scaleEffect(ripple ? 1.8 : 0.5)
                        .opacity(ripple ? 0 : 1)
                }

                Circle()
                    .fill(Theme.purple)
                    .frame(width: 13, height: 13)
                    .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 1.5))
                    .shadow(color: Theme.purple.opacity(0.45), radius: 5)
                    .offset(cursorOffset)
                    .animation(.easeInOut(duration: 0.28), value: pulseToken)

                VStack {
                    HStack {
                        StatusPill(text: "Simulated", color: Theme.purple, systemImage: "sparkles")
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Text("trackpad surface")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(14)
            }
            .onChange(of: pulseToken) { _, _ in
                ripple = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                    withAnimation(.easeOut(duration: 0.55)) { ripple = true }
                }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    switch pulseDirection {
                    case "up": cursorOffset = CGSize(width: 0, height: -26)
                    case "down": cursorOffset = CGSize(width: 0, height: 22)
                    case "right": cursorOffset = CGSize(width: min(50, size.width * 0.15), height: 0)
                    default: cursorOffset = CGSize(width: min(24, size.width * 0.08), height: min(10, size.height * 0.06))
                    }
                }
            }
            .onAppear {
                cursorOffset = CGSize(width: size.width * 0.10, height: -size.height * 0.04)
            }
        }
        .aspectRatio(1.55, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Decorative trackpad visualization. Use the preview buttons to play click and scroll sounds.")
    }
}

struct HapticGlyphView: View {
    var pulseToken: Int = 0
    @State private var phase = false

    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(Theme.teal.opacity(phase ? 0 : 0.35 - Double(index) * 0.08), lineWidth: 2)
                    .frame(width: 84 + CGFloat(index) * 44, height: 84 + CGFloat(index) * 44)
                    .scaleEffect(phase ? 1.10 : 0.94)
                    .animation(
                        .easeOut(duration: 1.4).repeatForever(autoreverses: false).delay(Double(index) * 0.25),
                        value: phase
                    )
            }
            Circle()
                .fill(LinearGradient(colors: [Theme.teal, Theme.tealDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 78, height: 78)
                .overlay(
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .shadow(color: Theme.teal.opacity(0.4), radius: 16, y: 6)
                .scaleEffect(phase ? 1.04 : 0.98)
        }
        .frame(height: 168)
        .onAppear { phase = true }
        .onChange(of: pulseToken) { _, _ in
            phase = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { phase = true }
        }
        .accessibilityHidden(true)
    }
}
