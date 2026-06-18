import AppKit
import SwiftUI

/// Shared settings model backed by UserDefaults.
final class SettingsModel: ObservableObject {
    static let shared = SettingsModel()

    @Published var uiScale: Double {
        didSet {
            UserDefaults.standard.set(uiScale, forKey: "uiScale")
            Task { @MainActor in
                StatusModel.shared.uiScale = uiScale
            }
        }
    }

    @Published var autoStart: Bool {
        didSet {
            UserDefaults.standard.set(autoStart, forKey: "autoStart")
            toggleAutoStart(enabled: autoStart)
        }
    }

    private init() {
        self.uiScale = UserDefaults.standard.double(forKey: "uiScale") == 0 ? 1.0 : UserDefaults.standard.double(forKey: "uiScale")
        self.autoStart = UserDefaults.standard.bool(forKey: "autoStart")
    }

    // MARK: - Auto-start management

    private func toggleAutoStart(enabled: Bool) {
        let plistPath = Bundle.main.path(forResource: "com.opencode.statusball", ofType: "plist")
        let launchPath = plistPath ?? "/Users/xuhao/Documents/light/OpenCodeStatusBall/launch/com.opencode.statusball.plist"
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let uid = Int(getuid())

        if enabled {
            let args: [String] = [
                "launchctl", "bootstrap", "gui/\(uid)",
                "-w", launchPath
                    .replacingOccurrences(of: "__HOME__", with: homeDir)
                    .replacingOccurrences(of: "__BIN__", with: Bundle.main.executablePath ?? "")
            ]
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/launchctl")
            task.arguments = args
            task.standardOutput = Pipe()
            task.standardError = Pipe()
            do {
                try task.run()
                task.waitUntilExit()
            } catch {
                print("Failed to bootstrap LaunchAgent: \(error)")
            }
        } else {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/launchctl")
            task.arguments = ["launchctl", "bootout", "gui/\(uid)/com.opencode.statusball", "--force"]
            task.standardOutput = Pipe()
            task.standardError = Pipe()
            do {
                try task.run()
                task.waitUntilExit()
            } catch {
                print("Failed to bootout LaunchAgent: \(error)")
            }
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(8)
                        .background(Color.black.opacity(0.2))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .frame(height: 32)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.95))

            Form {
                Section {
                    HStack {
                        Text("UI Scale")
                        Slider(value: $model.uiScale, in: 0.5...2.0, step: 0.1)
                        Text("\(String(format: "%.1f", model.uiScale))x")
                            .frame(width: 40, alignment: .trailing)
                    }
                    .padding(.vertical, 4)

                    Text("Adjusts the size of status dots and capsule. Changes apply immediately.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    Toggle("Start at login", isOn: $model.autoStart)
                        .toggleStyle(.switch)

                    Text("Automatically launch OpenCodeStatusBall when you log in.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .frame(width: 320, height: 180)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Preview

#Preview {
    SettingsView(model: SettingsModel.shared)
}
