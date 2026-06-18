import Foundation
import SwiftUI

/// All possible states a single session can show.
enum AgentStatus: String, Codable, CaseIterable {
    case idle           // 灰：空闲
    case running        // 绿：主 agent 工作中
    case waitingSubAgent // 蓝：等子 agent
    case askingQuestion  // 黄：问问题/权限
    case stopped         // 红：停止/出错

    var color: Color {
        switch self {
        case .idle:             return Color(red: 0.61, green: 0.64, blue: 0.69)  // warm gray
        case .running:          return Color(red: 0.24, green: 0.76, blue: 0.52)  // emerald
        case .waitingSubAgent:  return Color(red: 0.38, green: 0.65, blue: 0.98)  // soft blue
        case .askingQuestion:   return Color(red: 0.96, green: 0.62, blue: 0.04)  // amber
        case .stopped:          return Color(red: 0.98, green: 0.44, blue: 0.52)  // rose
        }
    }

    var glow: Color {
        switch self {
        case .idle:             return Color(red: 0.55, green: 0.58, blue: 0.65)
        case .running:          return Color(red: 0.10, green: 0.88, blue: 0.55)
        case .waitingSubAgent:  return Color(red: 0.23, green: 0.51, blue: 0.96)
        case .askingQuestion:   return Color(red: 0.98, green: 0.75, blue: 0.14)
        case .stopped:          return Color(red: 1.00, green: 0.55, blue: 0.62)
        }
    }

    var label: String {
        switch self {
        case .idle:            return "Idle"
        case .running:         return "Running"
        case .waitingSubAgent: return "Waiting for sub-agent"
        case .askingQuestion:  return "Asking question"
        case .stopped:         return "Stopped"
        }
    }

    var pulses: Bool {
        switch self {
        case .running, .askingQuestion: return true
        default:                        return false
        }
    }

    /// Whether this status implies the session is "done" and should be auto-evicted.
    var isTerminal: Bool {
        switch self {
        case .stopped: return true
        default:       return false
        }
    }
}

/// Per-session record.
struct SessionState: Identifiable, Equatable {
    let id: String        // sessionID — used as Identifiable key
    var status: AgentStatus
    var detail: String
    var model: String?
    var tokenInput: Int?
    var tokenOutput: Int?
    var lastUpdate: Date
    var label: String     // short human-friendly label (e.g. cwd basename)
    var subagents: Set<String> = []  // active sub-agent callIDs
    var activeSince: Date?

    /// Stable HSB accent derived from sessionID.
    var accent: Color { Self.accentColor(for: id) }

    static func accentColor(for sessionID: String) -> Color {
        // FNV-1a 32-bit hash, deterministic.
        var hash: UInt32 = 0x811C9DC5
        for byte in sessionID.utf8 {
            hash ^= UInt32(byte)
            hash &*= 0x01000193
        }
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.78, brightness: 0.95)
    }
}

/// Multi-session state container. Mutated only on the main actor.
@MainActor
final class StatusModel: ObservableObject {
    static let shared = StatusModel()

    /// Insertion-ordered list of sessions for stable left-to-right rendering.
    @Published private(set) var sessions: [SessionState] = []

    private let evictionDelay: TimeInterval = 1.2
    private let idleEvictionDelay: TimeInterval = 3.0

    /// Pending eviction tasks keyed by sessionID, so we can cancel them
    /// if the session re-activates before timeout.
    private var pendingEvictions: [String: Task<Void, Never>] = [:]

    /// Called on every session mutation so the AppKit window can resize.
    var onUpdate: (() -> Void)?

    private init() {}

    // MARK: - Mutations

    /// Insert or update a session.
    func upsert(sessionID: String, status: AgentStatus, detail: String, label: String, model: String? = nil, tokenInput: Int? = nil, tokenOutput: Int? = nil) {
        cancelEviction(for: sessionID)

        if let idx = sessions.firstIndex(where: { $0.id == sessionID }) {
            sessions[idx].status = status
            sessions[idx].detail = detail
            sessions[idx].lastUpdate = Date()
            if !label.isEmpty { sessions[idx].label = label }
            if let m = model, !m.isEmpty { sessions[idx].model = m }
            if let ti = tokenInput { sessions[idx].tokenInput = ti }
            if let to = tokenOutput { sessions[idx].tokenOutput = to }
            if status.pulses {
                if sessions[idx].activeSince == nil { sessions[idx].activeSince = Date() }
            } else {
                sessions[idx].activeSince = nil
            }
        } else {
            if status.isTerminal { return }
            let new = SessionState(
                id: sessionID,
                status: status,
                detail: detail,
                model: model,
                tokenInput: tokenInput,
                tokenOutput: tokenOutput,
                lastUpdate: Date(),
                label: label.isEmpty ? Self.shortID(sessionID) : label,
                activeSince: status.pulses ? Date() : nil
            )
            sessions.append(new)
        }

        if status.isTerminal {
            scheduleEviction(for: sessionID, delay: evictionDelay)
        } else if status == .idle, let idx = sessions.firstIndex(where: { $0.id == sessionID }), sessions[idx].subagents.isEmpty {
            scheduleEviction(for: sessionID, delay: idleEvictionDelay)
        }
        onUpdate?()
    }

    /// Explicitly drop a session immediately.
    func remove(sessionID: String) {
        cancelEviction(for: sessionID)
        sessions.removeAll { $0.id == sessionID }
        onUpdate?()
    }

    func addSubagent(parentID: String, callID: String, label: String) {
        if let idx = sessions.firstIndex(where: { $0.id == parentID }) {
            sessions[idx].subagents.insert(callID)
        } else {
            let new = SessionState(
                id: parentID,
                status: .running,
                detail: "",
                lastUpdate: Date(),
                label: label.isEmpty ? Self.shortID(parentID) : label,
                subagents: [callID]
            )
            sessions.append(new)
        }
        onUpdate?()
    }

    func removeSubagent(parentID: String, callID: String) {
        if let idx = sessions.firstIndex(where: { $0.id == parentID }) {
            sessions[idx].subagents.remove(callID)
            onUpdate?()
        }
    }

    // MARK: - Eviction

    private func scheduleEviction(for sessionID: String, delay: TimeInterval) {
        let task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.sessions.removeAll { $0.id == sessionID }
                self?.pendingEvictions[sessionID] = nil
                self?.onUpdate?()
            }
        }
        pendingEvictions[sessionID] = task
    }

    private func cancelEviction(for sessionID: String) {
        pendingEvictions[sessionID]?.cancel()
        pendingEvictions[sessionID] = nil
    }

    // MARK: - Helpers

    static func shortID(_ id: String) -> String {
        guard id.count > 6 else { return id }
        return String(id.suffix(6))
    }
}
