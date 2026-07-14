import Foundation

protocol CodexAccountDataWriting {
    /// A thrown error must leave the destination bytes unchanged.
    func write(_ data: Data, to url: URL) throws
}

final class LiveCodexAccountDataWriter: CodexAccountDataWriting {
    func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: [.atomic])
    }
}
