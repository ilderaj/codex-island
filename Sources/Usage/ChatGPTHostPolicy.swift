import Foundation

struct ChatGPTHostTarget: Equatable {
    let applicationURL: URL
    let executableURL: URL

    static let defaultApplicationURL = URL(fileURLWithPath: "/Applications/ChatGPT.app")

    static func validate(applicationURL: URL) throws -> ChatGPTHostTarget {
        let appURL = applicationURL.resolvingSymlinksInPath().standardizedFileURL
        let executableURL = appURL.appendingPathComponent("Contents/MacOS/ChatGPT")
        let executableName = Bundle(url: appURL)?
            .object(forInfoDictionaryKey: "CFBundleExecutable") as? String
        guard appURL.lastPathComponent == "ChatGPT.app",
              executableName == "ChatGPT",
              FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw ChatGPTHostError.identityMismatch
        }
        return ChatGPTHostTarget(applicationURL: appURL, executableURL: executableURL)
    }
}

protocol ChatGPTHostTargetValidating {
    func validateTarget() throws -> ChatGPTHostTarget
}

struct ChatGPTHostPolicy: ChatGPTHostTargetValidating {
    let candidateURL: URL

    init(candidateURL: URL = ChatGPTHostTarget.defaultApplicationURL) {
        self.candidateURL = candidateURL
    }

    func validateTarget() throws -> ChatGPTHostTarget {
        try ChatGPTHostTarget.validate(applicationURL: candidateURL)
    }
}

enum ChatGPTHostError: LocalizedError {
    case identityMismatch
    var errorDescription: String? { "ChatGPT host identity mismatch" }
}
