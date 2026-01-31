import SwiftUI
import PhotosUI

struct NewPostView: View {

    @Environment(\.dismiss) private var dismiss
    @Binding var posts: [Post]

    @EnvironmentObject var taggerHolder: TaggerHolder
    @EnvironmentObject var modelManager: ModelManager

    // UI state
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var userText: String = ""

    @State private var isPosting = false
    @State private var errorMessage: String?

    private let uploader = PostUploader()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                // ===== 上：スクロール領域（画像プレビューなど） =====
                ScrollView {
                    VStack(spacing: 12) {

                        if let img = selectedImage {
                            imagePreview(img)
                        }

                        if selectedImage != nil {
                            Text("意味を抽出して再構成します")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.top, 12)
                }

                Divider()

                // ===== 下：常に操作できるComposer（TextEditorはここ） =====
                composerArea
            }
            .navigationTitle("新規投稿")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {

                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .disabled(isPosting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isPosting ? "投稿中…" : "投稿") {
                        Task { await handlePost() }
                    }
                    .disabled(
                        isPosting ||
                        (selectedImage == nil &&
                         userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    )
                }
            }
        }
    }
}

// MARK: - Composer Area

extension NewPostView {

    private var composerArea: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack(alignment: .top, spacing: 12) {

                userAvatar

                ZStack(alignment: .topLeading) {
                    if userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("いまどうしてる？")
                            .foregroundColor(.secondary)
                            .padding(.top, 10)
                            .padding(.leading, 6)
                    }

                    TextEditor(text: $userText)
                        .frame(minHeight: 80, maxHeight: 120)
                        .padding(4)
                        .scrollContentBackground(.hidden)
                }
            }

            HStack {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("画像", systemImage: "photo")
                        .font(.subheadline)
                }

                Spacer()
            }

            if let err = errorMessage {
                Text(err)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .onChange(of: selectedItem) { _ in loadImage() }
    }

    private var userAvatar: some View {
        let name = UserManager.shared.currentUser.displayName
        let initial = String(name.prefix(1)).uppercased()

        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)

            Text(initial)
                .foregroundColor(.white)
                .font(.headline)
        }
    }
}

// MARK: - Image Preview

extension NewPostView {

    private func imagePreview(_ img: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(height: 220)
                .clipped()
                .cornerRadius(14)
                .padding(.horizontal)

            Button {
                selectedItem = nil
                selectedImage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .shadow(radius: 4)
                    .padding(18)
            }
            .accessibilityLabel("画像を削除")
        }
    }
}

// MARK: - Logic

extension NewPostView {

    func loadImage() {
        Task {
            if let data = try? await selectedItem?.loadTransferable(type: Data.self),
               let ui = UIImage(data: data) {
                await MainActor.run {
                    selectedImage = ui
                }
            }
        }
    }

    func handlePost() async {

        guard !isPosting else { return }
        await MainActor.run {
            isPosting = true
            errorMessage = nil
        }
        defer {
            Task { @MainActor in
                isPosting = false
            }
        }

        let id = UUID().uuidString
        let localUser = UserManager.shared.currentUser

        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)

        // ① 即時表示用ローカルポスト
        let tempPost = Post(
            id: id,
            userId: localUser.id,
            displayName: localUser.displayName,
            avatarUrl: localUser.avatarUrl,
            caption: nil,
            semanticPrompt: nil,
            regionTags: nil,
            userText: trimmed.isEmpty ? nil : trimmed,
            hasImage: selectedImage != nil,
            status: .pending,
            createdAt: Date(),
            localImage: selectedImage
        )

        await MainActor.run {
            posts.insert(tempPost, at: 0)
            dismiss()
        }

        // ② Semantic Extraction（画像があるときだけ）
        if selectedImage != nil {
            SemanticExtractionTask.shared.process(
                post: tempPost,
                taggers: taggerHolder
            )
        } else {
            #if DEBUG
            print("ℹ️ Skip semantic extraction (no image)")
            #endif
        }

        // ③ Upload
        do {
            try await uploader.upload(post: tempPost)
        } catch {
            #if DEBUG
            print("⚠️ Upload failed:", error)
            #endif
            await MainActor.run {
                errorMessage = "アップロードに失敗しました"
            }
        }
    }
}
