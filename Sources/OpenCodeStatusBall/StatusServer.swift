import Foundation
import Darwin

/// Listens on a Unix domain socket for line-delimited JSON messages
/// and updates StatusModel accordingly.
///
/// Wire format (one JSON object per line, '\n' terminated):
///   { "status": "running" | "idle" | "waitingSubAgent" | "askingQuestion" | "stopped",
///     "detail": "optional short string" }
///
/// Socket path: /tmp/opencode-status.sock
///
/// Implemented with classic BSD sockets because Network.framework's
/// NWListener doesn't support AF_UNIX listening reliably.
final class StatusServer {
    static let socketPath = "/tmp/opencode-status.sock"

    private var listenFD: Int32 = -1
    private let acceptQueue = DispatchQueue(label: "com.opencode.statusball.accept")
    private let workerQueue = DispatchQueue(label: "com.opencode.statusball.workers", attributes: .concurrent)
    private var stopping = false

    func start() {
        try? FileManager.default.removeItem(atPath: Self.socketPath)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Self.socketPath.utf8CString
        let maxLen = MemoryLayout.size(ofValue: addr.sun_path)
        guard pathBytes.count <= maxLen else {
            close(fd)
            return
        }
        withUnsafeMutablePointer(to: &addr.sun_path) { sunPathPtr in
            sunPathPtr.withMemoryRebound(to: CChar.self, capacity: maxLen) { dest in
                pathBytes.withUnsafeBufferPointer { src in
                    _ = memcpy(dest, src.baseAddress, src.count)
                }
            }
        }

        let bindResult = withUnsafePointer(to: &addr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                bind(fd, sa, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            close(fd)
            return
        }

        guard listen(fd, 16) == 0 else {
            close(fd)
            return
        }

        chmod(Self.socketPath, 0o666)

        listenFD = fd

        acceptQueue.async { [weak self] in
            self?.acceptLoop(fd)
        }
    }

    func stop() {
        stopping = true
        if listenFD >= 0 {
            close(listenFD)
            listenFD = -1
        }
        try? FileManager.default.removeItem(atPath: Self.socketPath)
    }

    deinit { stop() }

    private func acceptLoop(_ fd: Int32) {
        while !stopping {
            var clientAddr = sockaddr()
            var addrLen = socklen_t(MemoryLayout<sockaddr>.size)
            let client = accept(fd, &clientAddr, &addrLen)
            if client < 0 {
                if errno == EINTR { continue }
                if stopping { return }
                return
            }
            workerQueue.async { [weak self] in
                self?.serveClient(client)
            }
        }
    }

    private func serveClient(_ fd: Int32) {
        defer { close(fd) }
        var buffer = Data()
        var chunk = [UInt8](repeating: 0, count: 4096)
        while !stopping {
            let n = chunk.withUnsafeMutableBufferPointer { buf -> Int in
                read(fd, buf.baseAddress, buf.count)
            }
            if n <= 0 { break }
            buffer.append(chunk, count: n)
            buffer = consumeLines(from: buffer)
            if buffer.count > 1 << 20 {
                return
            }
        }
    }

    private func consumeLines(from buffer: Data) -> Data {
        var remaining = buffer
        let newline: UInt8 = 0x0A
        while let idx = remaining.firstIndex(of: newline) {
            let line = remaining[remaining.startIndex..<idx]
            remaining = remaining[(idx + 1)...]
            handleLine(Data(line))
        }
        return Data(remaining)
    }

    private struct Payload: Decodable {
        let kind: String?
        let sessionID: String
        let status: String?
        let detail: String?
        let label: String?
        let action: String?
        let callID: String?
        let model: String?
        let tokenInput: Int?
        let tokenOutput: Int?
    }

    private func handleLine(_ data: Data) {
        guard !data.isEmpty,
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return
        }

        let kind = payload.kind ?? "status"

        if kind == "subagent" {
            let parentID = payload.sessionID
            let callID = payload.callID ?? ""
            let action = payload.action ?? ""
            let label = payload.label ?? ""
            if action == "add" {
                Task { @MainActor in
                    StatusModel.shared.addSubagent(parentID: parentID, callID: callID, label: label)
                }
            } else if action == "remove" {
                Task { @MainActor in
                    StatusModel.shared.removeSubagent(parentID: parentID, callID: callID)
                }
            }
            return
        }

        let sessionID = payload.sessionID
        let detail = payload.detail ?? ""
        let label = payload.label ?? ""

        if payload.action == "remove" {
            Task { @MainActor in
                StatusModel.shared.remove(sessionID: sessionID)
            }
            return
        }

        guard let rawStatus = payload.status, let status = AgentStatus(rawValue: rawStatus) else {
            return
        }

        Task { @MainActor in
            StatusModel.shared.upsert(sessionID: sessionID,
                                       status: status,
                                       detail: detail,
                                       label: label,
                                       model: payload.model,
                                       tokenInput: payload.tokenInput,
                                       tokenOutput: payload.tokenOutput)
        }
    }
}
