import CryptoKit
import Foundation
import Security
import SpotifyNowShared

enum SpotifyOAuth {
    static let redirectURI = "spotifynow://callback"
    static let requiredScopes: Set<String> = [
        "playlist-read-private",
        "playlist-read-collaborative",
        "playlist-modify-private",
        "playlist-modify-public",
        "user-read-currently-playing",
    ]
    static let scopes = requiredScopes.sorted().joined(separator: " ")

    static let authorizeURL = URL(string: "https://accounts.spotify.com/authorize")!
    static let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
}

enum PKCE {
    static func verifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            bytes = Array(UUID().uuidString.utf8.prefix(32))
        }
        return Data(bytes).base64URLEncodedString()
    }

    static func challenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }
}

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }
}

struct SpotifyToken: Equatable {
    var accessToken: String
    var expiresAt: Date
    var refreshToken: String?
    var scope: String?
}

enum SpotifyWebAPI {
    static func authorizationURL(clientID: String, verifier: String, state: String) -> URL {
        var components = URLComponents(url: SpotifyOAuth.authorizeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: SpotifyOAuth.redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: PKCE.challenge(for: verifier)),
            URLQueryItem(name: "scope", value: SpotifyOAuth.scopes),
            URLQueryItem(name: "state", value: state),
        ]
        return components.url!
    }

    static func exchange(code: String, clientID: String, verifier: String) async throws -> SpotifyToken {
        try await tokenRequest([
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: SpotifyOAuth.redirectURI),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "code_verifier", value: verifier),
        ])
    }

    static func refresh(refreshToken: String, clientID: String) async throws -> SpotifyToken {
        try await tokenRequest([
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "client_id", value: clientID),
        ])
    }

    static func currentUser(token: String) async throws -> (id: String, name: String?) {
        let data = try await send(url: URL(string: "https://api.spotify.com/v1/me")!, method: "GET", token: token, body: nil)
        let user = try JSONDecoder().decode(UserPayload.self, from: data)
        return (user.id, user.displayName)
    }

    static func editablePlaylists(token: String, userID: String) async throws -> [PlaylistCandidate] {
        var next = URL(string: "https://api.spotify.com/v1/me/playlists?limit=50")!
        var collected: [PlaylistCandidate] = []
        var pages = 0
        while pages < 40 {
            let data = try await send(url: next, method: "GET", token: token, body: nil)
            let page = try JSONDecoder().decode(PlaylistPage.self, from: data)
            collected.append(contentsOf: page.items.compactMap(\.candidate))
            pages += 1
            guard let nextString = page.next, let nextURL = URL(string: nextString) else { break }
            next = nextURL
        }
        return PlaylistEditing.editable(collected, userID: userID)
    }

    static func contains(uri: String, playlistID: String, token: String) async throws -> Bool {
        // February 2026: playlist contents moved from /tracks to /items. The item
        // itself is `item`; `track` remains only as a deprecated alias.
        var next = URL(string: "https://api.spotify.com/v1/playlists/\(playlistID)/items?limit=50")!
        var pages = 0
        while pages < 60 {
            let data = try await send(url: next, method: "GET", token: token, body: nil)
            let page = try JSONDecoder().decode(PlaylistItemsPage.self, from: data)
            if page.items.contains(where: { $0.savedURI == uri }) {
                return true
            }
            pages += 1
            guard let nextString = page.next, let nextURL = URL(string: nextString) else {
                return false
            }
            next = nextURL
        }
        throw SpotifyAPIError(
            message: "This playlist is too large to check for duplicates, so it was left unchanged.",
            status: 0,
            requiresReconsent: false
        )
    }

    static func add(uri: String, playlistID: String, token: String) async throws {
        let body = try JSONEncoder().encode(AddTracksBody(uris: [uri]))
        _ = try await send(
            url: URL(string: "https://api.spotify.com/v1/playlists/\(playlistID)/items")!,
            method: "POST",
            token: token,
            body: body
        )
    }

    private static func tokenRequest(_ items: [URLQueryItem]) async throws -> SpotifyToken {
        var request = URLRequest(url: SpotifyOAuth.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = items
        request.httpBody = Data((components.percentEncodedQuery ?? "").utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(data: data, response: response)
        let payload = try JSONDecoder().decode(TokenPayload.self, from: data)
        return SpotifyToken(
            accessToken: payload.accessToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(payload.expiresIn)),
            refreshToken: payload.refreshToken,
            scope: payload.scope
        )
    }

    private static func send(url: URL, method: String, token: String, body: Data?) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(data: data, response: response)
        return data
    }

    private static func validate(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw SpotifyAPIError(message: "Spotify didn’t answer.", status: 0, requiresReconsent: false)
        }
        guard (200...299).contains(http.statusCode) else {
            let spotifyMessage = errorMessage(from: data, status: http.statusCode)
            let lower = spotifyMessage.lowercased()
            throw SpotifyAPIError(
                message: SpotifyFailureCopy.describe(status: http.statusCode, spotifyMessage: spotifyMessage),
                status: http.statusCode,
                requiresReconsent: http.statusCode == 403 && (lower.contains("scope") || lower.contains("insufficient"))
            )
        }
    }

    private static func errorMessage(from data: Data, status: Int) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let description = json["error_description"] as? String, !description.isEmpty {
                return description
            }
            if let error = json["error"] as? String, !error.isEmpty {
                return error
            }
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String, !message.isEmpty {
                return message
            }
        }
        let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !raw.isEmpty { return raw }
        return "HTTP \(status)"
    }
}

struct SpotifyAPIError: LocalizedError {
    var message: String
    var status: Int
    var requiresReconsent: Bool
    var errorDescription: String? { message }
}

private struct TokenPayload: Decodable {
    var accessToken: String
    var expiresIn: Int
    var refreshToken: String?
    var scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

private struct UserPayload: Decodable {
    var id: String
    var displayName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

private struct PlaylistPage: Decodable {
    var items: [Item]
    var next: String?

    struct Item: Decodable {
        var id: String?
        var name: String?
        var collaborative: Bool?
        var owner: Owner?
        var images: [Cover]?
        /// February 2026 rename of `tracks`.
        var items: Count?
        var tracks: Count?

        struct Owner: Decodable {
            var id: String?
        }

        struct Cover: Decodable {
            var url: String?
            var width: Int?
        }

        struct Count: Decodable {
            var total: Int?
        }

        enum CodingKeys: String, CodingKey {
            case id, name, collaborative, owner, images, items, tracks
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id)
            name = try container.decodeIfPresent(String.self, forKey: .name)
            collaborative = try container.decodeIfPresent(Bool.self, forKey: .collaborative)
            owner = try container.decodeIfPresent(Owner.self, forKey: .owner)
            images = try? container.decode([Cover].self, forKey: .images)
            // `items` replaced `tracks` in February 2026. Either may be absent or a different shape.
            items = try? container.decode(Count.self, forKey: .items)
            tracks = try? container.decode(Count.self, forKey: .tracks)
        }

        var candidate: PlaylistCandidate? {
            guard let id, !id.isEmpty, let name, !name.isEmpty, let ownerID = owner?.id, !ownerID.isEmpty else {
                return nil
            }
            let covers = (images ?? []).map { (url: $0.url ?? "", width: $0.width) }
            return PlaylistCandidate(
                id: id,
                name: name,
                ownerID: ownerID,
                collaborative: collaborative ?? false,
                imageURL: PlaylistCover.preferredURL(covers),
                trackCount: items?.total ?? tracks?.total ?? 0
            )
        }
    }
}

private struct PlaylistItemsPage: Decodable {
    var items: [Item]
    var next: String?

    struct Item: Decodable {
        /// Current field. `track` is the deprecated alias.
        var item: Content?
        var track: Content?

        struct Content: Decodable {
            var uri: String?
        }

        enum CodingKeys: String, CodingKey {
            case item, track
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            item = try? container.decode(Content.self, forKey: .item)
            track = try? container.decode(Content.self, forKey: .track)
        }

        var savedURI: String? { item?.uri ?? track?.uri }
    }
}

private struct AddTracksBody: Encodable {
    var uris: [String]
}
