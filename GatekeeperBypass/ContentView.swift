import SwiftUI

struct ContentView: View {
    @State private var isTargeted = false
    @State private var lastOpened: String? = nil
    @State private var isError = false

    var body: some View {
        VStack(spacing: 20) {
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

            if let name = lastOpened {
                HStack(spacing: 6) {
                    Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(isError ? .red : .green)
                    Text(name)
                        .font(.system(size: 12))
                        .foregroundStyle(isError ? .red : .secondary)
                }
                .transition(.opacity)
            }
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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        process.arguments = ["-cr", url.path]
        do {
            try process.run()
            process.waitUntilExit()
            NSWorkspace.shared.open(url)
            isError = false
            lastOpened = "Opened \(url.lastPathComponent)"
        } catch {
            isError = true
            lastOpened = "Failed: \(error.localizedDescription)"
        }
    }
}
