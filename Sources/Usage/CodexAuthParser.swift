import CryptoKit
import Foundation

enum CodexAuthParser {
    static func readActiveContext(paths: CodexAccountPaths = CodexAccountPaths()) throws -> CodexAuthContext {
        try parseAuth(data: Data(contentsOf: paths.activeAuthPath))
    }

    static func parseAuth(data: Data) throws -> CodexAuthContext {
        let file = try JSONDecoder().decode(CodexAuthFile.self, from: data)
        guard let accessToken = file.tokens.accessToken, !accessToken.isEmpty else {
            throw CodexAuthError.missingAccessToken
        }

        let claims = parseJWTClaims(file.tokens.idToken)
        let userId = firstString(claims, keys: ["chatgpt_user_id", "user_id", "sub"])
        let accountId = firstString(claims, keys: ["chatgpt_account_id", "account_id"])
            ?? file.tokens.accountID
        let plan = firstString(claims, keys: ["chatgpt_plan_type", "plan_type"])
        let email = firstString(claims, keys: ["email"])
        let confidence = identityConfidence(
            userId: userId,
            accountId: accountId,
            principalId: file.tokens.principalID
        )
        let key = accountKey(
            authMode: file.authMode,
            userId: userId,
            accountId: accountId,
            principalId: file.tokens.principalID,
            claims: claims
        )

        return CodexAuthContext(
            accountKey: key,
            accessToken: accessToken,
            chatgptAccountId: accountId,
            identity: CodexIdentity(
                email: email,
                chatgptUserId: userId,
                chatgptAccountId: accountId,
                principalId: file.tokens.principalID,
                plan: plan,
                confidence: confidence
            ),
            authFile: file,
            rawData: data
        )
    }

    static func parseJWTClaims(_ idToken: String?) -> [String: Any] {
        guard let idToken else { return [:] }
        let parts = idToken.split(separator: ".")
        guard parts.count >= 2,
              let payload = base64URLDecode(String(parts[1])),
              let obj = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            return [:]
        }
        return obj
    }

    static func accountKey(
        authMode: String?,
        userId: String?,
        accountId: String?,
        principalId: String?,
        claims: [String: Any] = [:]
    ) -> String {
        let material: String
        if let userId, let accountId {
            material = "codex-island-v1:strong:\(userId):\(accountId)"
        } else if let principalId, let accountId {
            material = "codex-island-v1:medium:\(principalId):\(accountId)"
        } else {
            let issuer = claims["iss"] as? String ?? ""
            let audience = claims["aud"] as? String ?? ""
            let subject = claims["sub"] as? String ?? ""
            material = [
                "codex-island-v1:low",
                authMode ?? "",
                principalId ?? "",
                accountId ?? "",
                issuer,
                audience,
                subject,
            ].joined(separator: ":")
        }
        return "acct_" + sha256HexPrefix(material, byteCount: 16)
    }

    private static func identityConfidence(
        userId: String?,
        accountId: String?,
        principalId: String?
    ) -> CodexIdentityConfidence {
        if userId != nil && accountId != nil { return .strong }
        if principalId != nil && accountId != nil { return .medium }
        return .low
    }

    private static func firstString(_ obj: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = obj[key] as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private static func base64URLDecode(_ value: String) -> Data? {
        var s = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = s.count % 4
        if pad > 0 {
            s += String(repeating: "=", count: 4 - pad)
        }
        return Data(base64Encoded: s)
    }

    private static func sha256HexPrefix(_ value: String, byteCount: Int) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.prefix(byteCount).map { String(format: "%02x", $0) }.joined()
    }
}
enum CodexAuthError: LocalizedError {
    case missingAccessToken

    var errorDescription: String? {
        switch self {
        case .missingAccessToken:
            return "No Codex access token found"
        }
    }
}
