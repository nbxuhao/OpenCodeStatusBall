import net from "node:net"
import type { Plugin } from "@opencode-ai/plugin"

const SOCKET = "/tmp/opencode-status.sock"

function emit(obj: Record<string, unknown>) {
  const line = JSON.stringify(obj) + "\n"
  const sock = net.createConnection(SOCKET)
  sock.on("error", () => {})
  sock.on("connect", () => sock.end(line))
}

const lastStatus = new Map<string, string>()
const sessionModels = new Map<string, string>()
const sessionTokens = new Map<string, { input: number; output: number }>()

function attachTokenPayload(sid: string, payload: Record<string, unknown>) {
  const tokens = sessionTokens.get(sid)
  if (tokens && (tokens.input > 0 || tokens.output > 0)) {
    payload.tokenInput = tokens.input
    payload.tokenOutput = tokens.output
  }
}

function sendStatus(sessionID: string, status: string, label: string, detail?: string, action?: string) {
  const key = `${status}|${detail ?? ""}|${action ?? ""}`
  if (lastStatus.get(sessionID) === key) return
  lastStatus.set(sessionID, key)
  const payload: Record<string, unknown> = { kind: "status", sessionID, status, label }
  if (detail) payload.detail = detail
  if (action) payload.action = action
  const model = sessionModels.get(sessionID)
  if (model) payload.model = model
  attachTokenPayload(sessionID, payload)
  emit(payload)
}

function pushStatus(sessionID: string, label: string) {
  const key = lastStatus.get(sessionID)
  if (!key) return
  const [status, ...rest] = key.split("|")
  const detail = rest[0] || undefined
  const action = rest[1] || undefined
  lastStatus.delete(sessionID)
  sendStatus(sessionID, status || "idle", label, detail, action)
}

function cleanSession(sid: string) {
  lastStatus.delete(sid)
  sessionModels.delete(sid)
  sessionTokens.delete(sid)
}

const subagentSIDs = new Map<string, { parentID: string; callID: string }>()
let nextCallID = 0

const StatusBallPlugin: Plugin = async (input) => {
  const label =
    (input.directory || input.worktree || "").split("/").pop() || "session"

  if (input.sessionID) {
    sendStatus(input.sessionID, "idle", label)
  }

  return {
    event: async ({ event }) => {
      const ev = event as { type: string; properties?: Record<string, unknown> }
      const props = ev.properties || {}
      const sid = props.sessionID as string | undefined
      if (!sid) return

      if (ev.type === "session.updated") {
        const info = props.info as Record<string, unknown> | undefined
        if (info) {
          const raw = (info as any).model
          if (raw) {
            const modelName = typeof raw === "string" ? raw : raw.name ?? raw.displayName ?? raw.id ?? String(raw)
            sessionModels.set(sid, modelName)
          }
          const t = (info as any).tokens
          if (t && typeof t === "object") {
            const input = typeof t.input === "number" ? t.input : 0
            const output = typeof t.output === "number" ? t.output : 0
            if (input > 0 || output > 0) {
              sessionTokens.set(sid, { input, output })
            }
            pushStatus(sid, label)
          }
        }
        if (info?.parentID) {
          const parentID = info.parentID as string
          if (!subagentSIDs.has(sid)) {
            const callID = `call_${++nextCallID}`
            subagentSIDs.set(sid, { parentID, callID })
            emit({ kind: "subagent", sessionID: parentID, callID, action: "add", label, subagentSID: sid })
          }
          return
        }
      }

      if (ev.type === "message.updated") {
        const info = props.info as Record<string, unknown> | undefined
        if (info) {
          const t = (info as any).tokens as Record<string, unknown> | undefined
          if (t && typeof t === "object") {
            const input = typeof t.input === "number" ? t.input : 0
            const output = typeof t.output === "number" ? t.output : 0
            if (input > 0 || output > 0) {
              sessionTokens.set(sid, { input, output })
            }
            pushStatus(sid, label)
          }
        }
      }

      if (subagentSIDs.has(sid)) {
        if (ev.type === "session.deleted") {
          const sub = subagentSIDs.get(sid)!
          emit({ kind: "subagent", sessionID: sub.parentID, callID: sub.callID, action: "remove", label })
          subagentSIDs.delete(sid)
          cleanSession(sid)
        }
        return
      }

      switch (ev.type) {
        case "session.status": {
          const s = props.status as { type: string; label?: unknown } | undefined
          if (!s) return
          const detail = typeof s.label === "string" ? s.label : undefined
          if (s.type === "idle") sendStatus(sid, "idle", label, detail)
          else if (s.type === "busy") sendStatus(sid, "running", label, detail)
          else if (s.type === "retry") sendStatus(sid, "running", label, detail || "retry")
          return
        }
        case "session.idle":
          sendStatus(sid, "idle", label)
          return
        case "session.error": {
          const msg = (props as any).message || "error"
          sendStatus(sid, "stopped", label, msg)
          return
        }
        case "session.deleted": {
          const sub = subagentSIDs.get(sid)
          if (sub) {
            emit({ kind: "subagent", sessionID: sub.parentID, callID: sub.callID, action: "remove", label })
            subagentSIDs.delete(sid)
          } else {
            sendStatus(sid, "idle", label, undefined, "remove")
          }
          cleanSession(sid)
          return
        }
      }
    },

    "permission.ask": async (perm, _out) => {
      const sid = (perm as { sessionID?: string }).sessionID
      if (!sid) return
      sendStatus(sid, "askingQuestion", label, "permission")
    },
  }
}

export default StatusBallPlugin
