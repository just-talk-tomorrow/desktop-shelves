import AppKit
import Combine

/// Only new, stable screenshots are copied. Directory access stays off the UI thread.
@MainActor
final class ShelfCapture: ObservableObject {
    @Published var enabled: Bool { didSet { defaults.set(enabled, forKey: "shelfCaptureEnabled"); reset() } }
    private let store: ShelfStore
    private let defaults: UserDefaults
    private let directories: [URL]
    private let tendederoDirectory: URL
    private var timer: Timer?
    private var known = Set<URL>()
    private var pending: [URL: Int] = [:]
    private var busy = false
    private let automaticallyPoll: Bool
    private var generation = 0
    private var readyDirectories = Set<URL>()

    init(store: ShelfStore, defaults: UserDefaults = .standard, active: Bool = true, directory: URL? = nil,
         systemDirectory: URL? = nil, automaticallyPoll: Bool = true) {
        self.store = store; self.defaults = defaults; self.automaticallyPoll = automaticallyPoll
        tendederoDirectory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tendedero/Screenshots")
        let configured = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")
        let system = configured.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        directories = Array(Set([tendederoDirectory, systemDirectory ?? system]))
        enabled = active && (defaults.object(forKey: "shelfCaptureEnabled") as? Bool ?? true)
        reset()
    }
    private nonisolated static func files(_ directories: [URL]) -> [URL] {
        directories.flatMap { directory in
            ((try? FileManager.default.contentsOfDirectory(at: directory,
                includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? [])
                .filter { ["png", "jpg", "jpeg", "heic", "tiff"].contains($0.pathExtension.lowercased()) }
        }
    }
    private struct Candidate: Sendable { let url: URL; let size: Int }
    private nonisolated static func candidates(_ directories: [URL], tendedero: URL) -> [Candidate] {
        files(directories).sorted { $0.lastPathComponent < $1.lastPathComponent }.compactMap { url in
            let inInbox = url.deletingLastPathComponent().resolvingSymlinksInPath().path == tendedero.resolvingSymlinksInPath().path
            guard inInbox || NSMetadataItem(url: url)?.value(forAttribute: "kMDItemIsScreenCapture") as? Bool == true,
                  let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true, let size = values.fileSize, size > 0 else { return nil }
            return Candidate(url: url, size: size)
        }
    }
    private func reset() {
        generation += 1
        timer?.invalidate(); timer = nil; pending = [:]; known = []; readyDirectories = []
        guard enabled else { return }
        let directories = self.directories, expected = generation
        if !automaticallyPoll {
            known = Set(Self.files(directories)); readyDirectories = Set(directories)
            return
        }
        // macOS may wait for permission on Desktop. It must never block the other inbox.
        for directory in directories {
            Task { [weak self] in
                let initial = await Task.detached(priority: .utility) { Self.files([directory]) }.value
                guard let self, self.enabled, self.generation == expected else { return }
                self.known.formUnion(initial); self.readyDirectories.insert(directory)
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.scan() }
        }
    }
    func scan() async {
        guard enabled, !readyDirectories.isEmpty, !busy, !store.importing else { return }
        busy = true; defer { busy = false }
        let directories = Array(readyDirectories), tendedero = tendederoDirectory, expected = generation
        let current = await Task.detached(priority: .utility) { Self.candidates(directories, tendedero: tendedero) }.value
        guard enabled, generation == expected else { return }
        for file in current where !known.contains(file.url) {
            if pending[file.url] == file.size {
                await store.importURLs([file.url])
                known.insert(file.url); pending[file.url] = nil
            } else { pending[file.url] = file.size }
        }
        // Do not discard baseline entries which the metadata index has not classified yet.
    }
    deinit { timer?.invalidate() }
}
