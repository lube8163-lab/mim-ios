//
//  FeedLoader.swift
//  SemanticCompressionApp
//

import Foundation

/// Cloudflare Worker API ベースURL
enum FeedAPI {
    static let base = "https://example"
}

struct FeedLoader {

    static func fetchPage(page: Int, pageSize: Int = 10) async throws -> [Post] {

        // 🔥 ローカルユーザーIDを付与（いいね状態の取得に必須）
        let userId = LikeManager.shared.userId
        
        let urlString = "\(FeedAPI.base)/feed?page=\(page)&size=\(pageSize)&userId=\(userId)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        #if DEBUG
        print("📡 Fetching feed from:", url.absoluteString)
        #endif

        let (data, response) = try await URLSession.shared.data(from: url)

        if let http = response as? HTTPURLResponse,
            !(200...299).contains(http.statusCode) {
            throw NSError(
                domain: "FeedLoader",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Server returned HTTP \(http.statusCode)"]
            )
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let decoded = try decoder.decode([Post].self, from: data)

            // 🔥 Post の同一インスタンス化（ここは完璧！）
            let resolved = decoded.map { PostStore.shared.resolve($0) }

            #if DEBUG
            print("📥 Loaded \(resolved.count) posts")
            #endif
            return resolved

        } catch {
            #if DEBUG
            print("❌ JSON decode error:", error)
            print("❌ Response JSON:", String(data: data, encoding: .utf8) ?? "nil")
            #endif
            throw error
        }
    }
}
