import Foundation

enum Base32 {
    private static let alphabet = Array("abcdefghijklmnopqrstuvwxyz234567")

    static func decode(_ input: String) -> Data? {
        var buffer = 0
        var bits = 0
        var output = Data()

        for character in input.lowercased() {
            guard let value = alphabet.firstIndex(of: character) else { return nil }
            buffer = (buffer << 5) | value
            bits += 5
            if bits >= 8 {
                bits -= 8
                output.append(UInt8((buffer >> bits) & 0xff))
                buffer &= (1 << bits) - 1
            }
        }
        return output
    }
}

struct RosterStore: Sendable {
    let persistenceDirectory: URL

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        persistenceDirectory = homeDirectory
            .appendingPathComponent("Library/Application Support/Grok Bot/sand-client-persistence", isDirectory: true)
    }

    func load() throws -> [Grokbot] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: persistenceDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        let candidates = urls.filter { url in
            guard url.pathExtension == "blob",
                  let bytes = Base32.decode(url.deletingPathExtension().lastPathComponent),
                  let key = String(data: bytes, encoding: .utf8)
            else { return false }
            return key.hasSuffix(".roster.last-roster")
        }.sorted {
            let left = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let right = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return left > right
        }

        guard let url = candidates.first else { return [] }
        let envelope = try JSONDecoder().decode(RosterEnvelope.self, from: Data(contentsOf: url))
        return envelope.value.rows
            .filter { $0.isHiddenFromSidebar != true }
            .sorted { ($0.activityDate ?? .distantPast) > ($1.activityDate ?? .distantPast) }
    }
}

struct DesktopStatus: Decodable, Sendable {
    let pid: Int32
    let signedIn: Bool
    let appVersion: String?
}

struct DesktopStatusStore: Sendable {
    let statusURL: URL

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        statusURL = homeDirectory.appendingPathComponent("Library/Application Support/Grok Bot/desktop-status.json")
    }

    func load() -> DesktopStatus? {
        guard let data = try? Data(contentsOf: statusURL),
              let status = try? JSONDecoder().decode(DesktopStatus.self, from: data),
              kill(status.pid, 0) == 0
        else { return nil }
        return status
    }
}
