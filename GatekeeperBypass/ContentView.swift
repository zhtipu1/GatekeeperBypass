import SwiftUI

struct ContentView: View {
    @State private var activeTab: Tab = .drop
    @AppStorage("autoCloseAfterOpen") private var autoClose: Bool = false

    enum Tab { case drop, about }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "lock.shield")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("GatekeeperBypass")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text("Open apps without Gatekeeper")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                HStack(spacing: 4) {
                    TabButton(label: "Drop", icon: "arrow.down.circle", tab: .drop, active: $activeTab)
                    TabButton(label: "About", icon: "info.circle", tab: .about, active: $activeTab)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)

            Divider()

            if activeTab == .drop {
                DropView(autoClose: $autoClose)
            } else {
                AboutView()
            }
        }
        .frame(width: 420)
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let label: String
    let icon: String
    let tab: ContentView.Tab
    @Binding var active: ContentView.Tab

    var body: some View {
        Button { active = tab } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                active == tab ? Color.accentColor.opacity(0.15) : Color.clear,
                in: RoundedRectangle(cornerRadius: 6))
            .foregroundStyle(active == tab ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Drop View

struct DropView: View {
    @Binding var autoClose: Bool
    @State private var isTargeted = false
    @State private var lastOpened: String? = nil
    @State private var isError = false

    var body: some View {
        VStack(spacing: 20) {
            // Drop zone
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
                    )
                    .frame(height: 180)
                    .animation(.easeInOut(duration: 0.15), value: isTargeted)

                VStack(spacing: 10) {
                    Image(systemName: isTargeted ? "lock.open.fill" : "lock.shield")
                        .font(.system(size: 36))
                        .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
                        .animation(.easeInOut(duration: 0.15), value: isTargeted)
                    Text("Drop .app here to open")
                        .font(.system(size: 14, weight: .medium))
                    Text("Strips Gatekeeper quarantine and launches it")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }

            // Status message
            if let name = lastOpened {
                HStack(spacing: 6) {
                    Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(isError ? Color.red : Color.green)
                    Text(name)
                        .font(.system(size: 12))
                        .foregroundStyle(isError ? Color.red : Color.secondary)
                }
                .transition(.opacity)
            }

            Divider()

            // Auto-close toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-close after opening")
                        .font(.system(size: 12, weight: .medium))
                    Text("Quit this app automatically once the dropped app launches")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                // Custom Binding — no onChange, safe from re-render side effects
                Toggle("", isOn: Binding(
                    get: { autoClose },
                    set: { autoClose = $0 }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
            .padding(.horizontal, 4)
        }
        .padding(24)
        .animation(.easeInOut(duration: 0.2), value: lastOpened)
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                strip(url: url)
            }
        }
        return true
    }

    func strip(url: URL) {
        // Run xattr async so we never block the main thread.
        // Blocking main thread with waitUntilExit() was causing the window
        // to freeze after one use, making it unresponsive until force-quit.
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
            process.arguments = ["-cr", url.path]
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            do {
                try process.run()
                process.waitUntilExit()
                DispatchQueue.main.async {
                    NSWorkspace.shared.open(url)
                    isError = false
                    lastOpened = "Opened \(url.lastPathComponent)"
                    if autoClose {
                        // Small delay so user sees the success message briefly
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            NSApplication.shared.terminate(nil)
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isError = true
                    lastOpened = "Failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 72, height: 72)
                    Image(systemName: "lock.shield")
                        .font(.system(size: 30))
                        .foregroundStyle(Color.accentColor)
                }
                VStack(spacing: 6) {
                    Text("GatekeeperBypass")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                    Text("Version 1.0")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Text("Drop any .app file onto the window to strip \n the Gatekeeper quarantine flag and open it. \n No terminal needed.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                Divider().padding(.horizontal, 60)
                VStack(spacing: 4) {
                    Text("Developed by")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("Zahidul Haque Tipu")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text("All rights reserved.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
