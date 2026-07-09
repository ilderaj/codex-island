import Foundation

struct CodexResetCreditsSnapshot: Equatable {
    let credits: [CodexResetCredit]
    let availableCount: Int?
    let updatedAt: Date

    func availableInventory(now: Date = Date()) -> CodexResetCreditInventory {
        CodexResetCreditInventory(credits: credits, now: now)
    }

    func presentation(now: Date = Date()) -> CodexResetCreditsPresentation? {
        CodexResetCreditsPresentation(snapshot: self, now: now)
    }
}

struct CodexResetCredit: Equatable {
    let status: String
    let title: String?
    let grantedAt: Date?
    let expiresAt: Date?
}

struct CodexResetCreditInventory: Equatable {
    let credits: [CodexResetCredit]

    init(credits: [CodexResetCredit], now: Date) {
        self.credits = credits
            .filter { credit in
                credit.status == "available" && (credit.expiresAt.map { $0 > now } ?? true)
            }
            .sorted { lhs, rhs in
                switch (lhs.expiresAt, rhs.expiresAt) {
                case let (left?, right?):
                    if left != right { return left < right }
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    break
                }
                return (lhs.title ?? "") < (rhs.title ?? "")
            }
    }
}

struct CodexResetCreditsPresentation: Equatable {
    let title = "Reset credits"
    let summary: String

    init?(snapshot: CodexResetCreditsSnapshot, now: Date = Date()) {
        let inventory = snapshot.availableInventory(now: now)
        guard !inventory.credits.isEmpty else { return nil }

        let countText = inventory.credits.count == 1 ? "1 available" : "\(inventory.credits.count) available"
        let expiryParts = inventory.credits.prefix(3).map { Self.expiryText(for: $0, now: now) }
        let hidden = inventory.credits.count - expiryParts.count
        let suffix = hidden > 0 ? ["+\(hidden)"] : []
        summary = ([countText] + expiryParts + suffix).joined(separator: " · ")
    }

    private static func expiryText(for credit: CodexResetCredit, now: Date) -> String {
        guard let expiresAt = credit.expiresAt else { return "No expiry" }
        let remaining = max(0, expiresAt.timeIntervalSince(now))
        if remaining >= 86_400 {
            return "\(Int(remaining / 86_400))d"
        }
        if remaining >= 3_600 {
            return "\(Int(remaining / 3_600))h"
        }
        return "\(max(1, Int(remaining / 60)))m"
    }
}

struct CodexResetCreditsResponse: Decodable {
    let availableCount: Int?
    let credits: [Credit]

    private enum CodingKeys: String, CodingKey {
        case availableCount = "available_count"
        case credits
    }

    struct Credit: Decodable {
        let status: String
        let title: String?
        let grantedAt: Date?
        let expiresAt: Date?

        private enum CodingKeys: String, CodingKey {
            case status
            case title
            case grantedAt = "granted_at"
            case expiresAt = "expires_at"
        }

        var model: CodexResetCredit {
            CodexResetCredit(
                status: status,
                title: title,
                grantedAt: grantedAt,
                expiresAt: expiresAt
            )
        }
    }

    static func decode(data: Data, updatedAt: Date = Date()) throws -> CodexResetCreditsSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let seconds = ISO8601DateFormatter()
            seconds.formatOptions = [.withInternetDateTime]
            if let date = fractional.date(from: raw) ?? seconds.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO-8601 date"
            )
        }

        let response = try decoder.decode(Self.self, from: data)
        return CodexResetCreditsSnapshot(
            credits: response.credits.map(\.model),
            availableCount: response.availableCount,
            updatedAt: updatedAt
        )
    }
}
