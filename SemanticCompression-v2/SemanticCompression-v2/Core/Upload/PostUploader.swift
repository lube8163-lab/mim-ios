//
//  PostUploadPayload.swift
//  SemanticCompression-v2
//
//  Created by Tasuku Kato on 2025/12/09.
//

import Foundation

// ======================================================
//  Cloudflare Worker `/post` に合わせた送信フォーマット
// ======================================================
struct PostUploadPayload: Codable {
    let id: String

    // --- 投稿者情報（D1 users テーブルと一致） ---
    let userId: String
    let displayName: String
    let avatarUrl: String

    // --- 投稿内容 ---
    let caption: String?
    let semanticPrompt: String?
    let regionTags: [RegionTag]?
    let userText: String?
    let hasImage: Bool

    // ISO8601 文字列
    let createdAt: String
}


// ======================================================
//  アップロードロジック
// ======================================================
final class PostUploader {

    private let endpoint = "https://example/post"

    func upload(post: Post) async throws {

        // 🔹 ローカルユーザー（UserManager が保持）
        let localUser = UserManager.shared.currentUser

        // 🔹 Worker のフィールドに完全対応した payload
        let payload = PostUploadPayload(
            id: post.id,

            userId: localUser.id,
            displayName: localUser.displayName,
            avatarUrl: localUser.avatarUrl,

            caption: post.caption,
            semanticPrompt: post.semanticPrompt,
            regionTags: post.regionTags,
            userText: post.userText,
            hasImage: post.hasImage,

            createdAt: ISO8601DateFormatter().string(from: post.createdAt)
        )

        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // 🔹 JSON へエンコード
        let jsonData = try JSONEncoder().encode(payload)
        request.httpBody = jsonData

        // 🔹 POST 実行
        let (_, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              200..<300 ~= http.statusCode else {
            #if DEBUG
            print("❌ Server returned:", (response as? HTTPURLResponse)?.statusCode ?? -1)
            #endif
            throw URLError(.badServerResponse)
        }
        
        #if DEBUG
        print("✅ Post uploaded to server: \(post.id)")
        #endif
    }
}
