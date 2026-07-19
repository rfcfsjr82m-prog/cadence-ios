import Foundation

/// Fetches presets from a remote JSON URL, caches them on disk, and merges
/// them into SwiftData on launch. Any preset with an ID not already in the
/// local store is inserted; existing ones are updated in-place.
///
/// The remote JSON is a plain array of TimerConfig objects:
///   [ { "id": "...", "name": "...", ... }, ... ]
///
/// Host the file at the URL below (e.g. a raw GitHub file) and update it
/// any time you want to add or change presets without shipping an app update.
@MainActor
final class RemotePresetsManager {

    static let shared = RemotePresetsManager()

    private static let remoteURL = URL(string:
        "https://raw.githubusercontent.com/rfcfsjr82m-prog/cadence-presets/refs/heads/main/presets.json"
    )!

    private static let cacheURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("remote_presets.json")
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    private init() {}

    // MARK: - Public

    /// Call on app launch. Loads cached presets immediately (synchronous),
    /// then kicks off a background fetch to refresh the cache.
    func loadAndSync(insert: @escaping @MainActor (TimerConfig) -> Void,
                     update: @escaping @MainActor (TimerConfig) -> Void,
                     existingIDs: @escaping @MainActor () -> Set<UUID>) {
        // 1. Apply cached presets immediately so they're available offline
        if let cached = loadCache() {
            merge(cached, insert: insert, update: update, existingIDs: existingIDs)
        }

        // 2. Fetch fresh presets in the background
        Task { [weak self] in
            guard let self else { return }
            guard let fresh = await self.fetch() else { return }
            self.saveCache(fresh)
            self.merge(fresh, insert: insert, update: update, existingIDs: existingIDs)
        }
    }

    // MARK: - Private

    private func fetch() async -> [TimerConfig]? {
        do {
            print("[RemotePresets] Fetching from \(Self.remoteURL)")
            let (data, response) = try await URLSession.shared.data(from: Self.remoteURL)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("[RemotePresets] HTTP status: \(status)")
            guard status == 200 else { return nil }
            let presets = try decoder.decode([TimerConfig].self, from: data)
            print("[RemotePresets] Decoded \(presets.count) preset(s): \(presets.map(\.name))")
            return presets
        } catch {
            print("[RemotePresets] Error: \(error)")
            return nil
        }
    }

    private func loadCache() -> [TimerConfig]? {
        guard let data = try? Data(contentsOf: Self.cacheURL) else { return nil }
        return try? decoder.decode([TimerConfig].self, from: data)
    }

    private func saveCache(_ presets: [TimerConfig]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(presets) else { return }
        try? data.write(to: Self.cacheURL, options: .atomic)
    }

    private func merge(_ presets: [TimerConfig],
                       insert: @MainActor (TimerConfig) -> Void,
                       update: @MainActor (TimerConfig) -> Void,
                       existingIDs: @MainActor () -> Set<UUID>) {
        let ids = existingIDs()
        print("[RemotePresets] Merging \(presets.count) preset(s), existing IDs count: \(ids.count)")
        for var preset in presets {
            preset.isPreset = true
            if ids.contains(preset.id) {
                print("[RemotePresets] Updating existing: \(preset.name)")
                update(preset)
            } else {
                print("[RemotePresets] Inserting new: \(preset.name)")
                insert(preset)
            }
        }
    }
}
