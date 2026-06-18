import SwiftUI

struct CapsuleBarView: View {
    @ObservedObject var model: StatusModel
    @State private var hoveredID: String? = nil

    private let dotSize: CGFloat = 11
    private let dotSpacing: CGFloat = 10
    private let hPad: CGFloat = 13
    private let vPad: CGFloat = 8

    var body: some View {
        HStack(spacing: dotSpacing) {
            if model.sessions.isEmpty {
                EmptyDot()
            } else {
                ForEach(model.sessions) { session in
                    SessionDot(
                        session: session,
                        size: dotSize,
                        isHovered: hoveredID == session.id
                    )
                    .onHover { entered in
                        hoveredID = entered ? session.id : (hoveredID == session.id ? nil : hoveredID)
                    }
                    .popover(
                        isPresented: Binding(
                            get: { hoveredID == session.id },
                            set: { if !$0 && hoveredID == session.id { hoveredID = nil } }
                        ),
                        arrowEdge: .bottom
                    ) {
                        TooltipContent(session: session)
                    }
                }
            }
        }
        .padding(.horizontal, hPad)
        .padding(.vertical, vPad)
        .background(
            Capsule(style: .continuous)
                .fill(Color(red: 0.10, green: 0.10, blue: 0.12).opacity(0.92))
        )
        .fixedSize()
        .animation(.easeOut(duration: 0.18), value: model.sessions.map(\.id))
    }
}

private struct EmptyDot: View {
    @State private var dim = false
    var body: some View {
        Circle()
            .fill(Color.white.opacity(dim ? 0.18 : 0.42))
            .frame(width: 7, height: 7)
            .frame(width: 11, height: 11)
            .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: dim)
            .onAppear { dim = true }
    }
}

private struct TooltipContent: View {
    let session: SessionState
    @State private var now = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 7) {
                Circle()
                    .fill(session.status.color)
                    .frame(width: 7, height: 7)
                Text(session.label)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.primary)
            }

            Text(session.status.label)
                .font(.system(size: 10.5))
                .foregroundColor(.secondary)

            if let model = session.model {
                Text(model)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            if !session.detail.isEmpty {
                Text(session.detail)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            if let input = session.tokenInput, let output = session.tokenOutput {
                Text(formatTokens(input) + " in / " + formatTokens(output) + " out")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            if let since = session.activeSince {
                Text("Running for \(formatDuration(now.timeIntervalSince(since)))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .onReceive(timer) { t in now = t }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .frame(minWidth: 150, alignment: .leading)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let m = total / 60
        let s = total % 60
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1000 { return String(format: "%.1fK", Double(n) / 1000) }
        return "\(n)"
    }
}

struct SessionDot: View {
    let session: SessionState
    let size: CGFloat
    let isHovered: Bool

    private let orbitRadius: CGFloat = 11
    private let satelliteSize: CGFloat = 3.5
    private let period: Double = 8

    var body: some View {
        let hasSub = !session.subagents.isEmpty
        let container: CGFloat = 25

        ZStack {
            if session.status.pulses {
                PulseRing(color: session.status.color, delay: 0)
                    .frame(width: size, height: size)
                PulseRing(color: session.status.color, delay: 1.1)
                    .frame(width: size, height: size)
            }

            ThinkingCore(color: session.status.color,
                         size: size)

            if hasSub {
                SatelliteOrbit(
                    count: session.subagents.count,
                    color: Color.white.opacity(0.7),
                    radius: orbitRadius,
                    satelliteSize: satelliteSize,
                    period: period
                )
            }
        }
        .frame(width: container, height: container)
        .scaleEffect(isHovered ? 1.18 : 1.0)
        .animation(.easeOut(duration: 0.16), value: isHovered)
        .contentShape(Rectangle().inset(by: -3))
    }
}

private struct SatelliteOrbit: View {
    let count: Int
    let color: Color
    let radius: CGFloat
    let satelliteSize: CGFloat
    let period: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60)) { timeline in
            let phase = (timeline.date.timeIntervalSinceReferenceDate * (2 * .pi / period))
                .truncatingRemainder(dividingBy: 2 * .pi)
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    let angle = (2 * .pi / Double(count)) * Double(i)
                    Circle()
                        .fill(color)
                        .frame(width: satelliteSize, height: satelliteSize)
                        .offset(
                            x: cos(angle + phase) * radius,
                            y: sin(angle + phase) * radius
                        )
                }
            }
        }
    }
}

private struct ThinkingCore: View {
    let color: Color
    let size: CGFloat
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}

private struct PulseRing: View {
    let color: Color
    let delay: Double
    @State private var phase: CGFloat = 0

    var body: some View {
        Circle()
            .strokeBorder(color, lineWidth: 1.2)
            .scaleEffect(1.0 + phase * 1.4)
            .opacity(0.55 - phase * 0.55)
            .animation(
                .easeOut(duration: 2.6)
                    .repeatForever(autoreverses: false)
                    .delay(delay),
                value: phase
            )
            .onAppear { phase = 1.0 }
    }
}
