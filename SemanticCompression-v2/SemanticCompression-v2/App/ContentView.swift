import SwiftUI
import Combine
import CoreML

final class PostList: ObservableObject {
    @Published var items: [Post] = []
}

struct ContentView: View {

    // MARK: - Boot State

    enum AppBootState {
        case launching
        case preparingModel
        case ready
    }

    @State private var appBootState: AppBootState = .launching

    // MARK: - Core State

    @StateObject private var postList = PostList()
    @EnvironmentObject var modelManager: ModelManager

    @State private var showNewPost = false
    @State private var showInstallModels = false

    @State private var genLog = "Ready"
    @State private var isLoadingFeed = false

    @State private var generator: ImageGenerator?
    @State private var isGeneratorReady = false

    // Pagination
    @State private var currentPage = 0
    private let pageSize = 10

    // Image generation queue
    @State private var generationQueue: [Post] = []
    @State private var isGenerating = false

    // MARK: - Body

    var body: some View {
        ZStack {
            switch appBootState {
            case .launching, .preparingModel:
                AppLaunchView()

            case .ready:
                mainContent
            }
        }
        .task {
            await bootSequence()
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        NavigationView {
            ZStack {
                feedBody
                floatingNewPostButton
            }
            .navigationTitle("Semantic Feed")
            .toolbar { profileButton }
        }
        .sheet(isPresented: $showNewPost) {
            NewPostView(posts: $postList.items)
        }
        .sheet(isPresented: $showInstallModels) {
            InstallModelsView(modelManager: modelManager)
        }
        .onAppear {
            let hasSeen = UserDefaults.standard.bool(forKey: "hasSeenInstallPrompt")
            if !modelManager.isModelInstalled && !hasSeen {
                showInstallModels = true
                UserDefaults.standard.set(true, forKey: "hasSeenInstallPrompt")
            }
        }
        .onDisappear {
            Task { await generator?.unloadResources() }
        }
    }
}

extension ContentView {

    func bootSequence() async {

        // ユーザー登録
        let user = UserManager.shared.currentUser
        await UserService.register(user)

        // モデル未インストールなら即 ready
        guard modelManager.isModelInstalled else {
            appBootState = .ready
            await loadInitialPage()
            return
        }

        appBootState = .preparingModel

        // SD 初期化（ここで固まっても OK）
        let sdDir = ModelManager.modelsRoot
            .appendingPathComponent("StableDiffusion/sd15")

        do {
            let gen = try ImageGenerator(modelsDirectory: sdDir)
            self.generator = gen
            self.isGeneratorReady = true
        } catch {
            #if DEBUG
            print("❌ SD init failed:", error)
            #endif
            self.generator = nil
            self.isGeneratorReady = false
        }

        appBootState = .ready
        await loadInitialPage()
    }
}

extension ContentView {

    @ViewBuilder
    private var feedBody: some View {
        VStack(spacing: 0) {

            if postList.items.isEmpty && isLoadingFeed {
                ProgressView("Fetching feed...")
                    .padding(.top, 40)

            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(postList.items) { post in
                            PostCardView(
                                post: post,
                                isModelInstalled: modelManager.isModelInstalled
                            )
                            .onAppear {
                                if post.id == postList.items.last?.id {
                                    Task { await loadNextPage() }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
                .refreshable {
                    await refreshFeed()
                }
            }

            Divider()
            bottomStatusBar
        }
    }
}

extension ContentView {

    private var bottomStatusBar: some View {
        Group {
            if modelManager.isModelInstalled {
                Text(genLog)
            } else {
                Text("⚠️ モデル未インストール（画像生成は無効）")
                    .foregroundColor(.orange)
            }
        }
        .font(.footnote)
        .foregroundColor(.gray)
        .padding(.bottom, 6)
    }

    private var floatingNewPostButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: { showNewPost = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 56))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.accentColor)
                        .shadow(radius: 3)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
        }
    }

    private var profileButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            NavigationLink(destination: UserProfileView()) {
                Image(systemName: "person.circle")
            }
        }
    }
}

extension ContentView {

    func loadInitialPage() async {
        isLoadingFeed = true
        do {
            let firstPage = try await FeedLoader.fetchPage(page: 0, pageSize: pageSize)
            postList.items = firstPage
            currentPage = 0
            isLoadingFeed = false

            if modelManager.isModelInstalled {
                enqueueImages(for: firstPage)
            }
        } catch {
            genLog = "❌ Failed to load feed"
            isLoadingFeed = false
        }
    }

    func loadNextPage() async {
        guard !isLoadingFeed else { return }
        isLoadingFeed = true

        do {
            let next = try await FeedLoader.fetchPage(
                page: currentPage + 1,
                pageSize: pageSize
            )
            guard !next.isEmpty else {
                isLoadingFeed = false
                return
            }

            postList.items.append(contentsOf: next)
            currentPage += 1

            if modelManager.isModelInstalled {
                enqueueImages(for: next)
            }
        } catch {
            genLog = "⚠️ Page load failed"
        }

        isLoadingFeed = false
    }

    func refreshFeed() async {
        do {
            let latest = try await FeedLoader.fetchPage(page: 0, pageSize: pageSize)
            let existing = Set(postList.items.map { $0.id })
            let newPosts = latest.filter { !existing.contains($0.id) }

            guard !newPosts.isEmpty else { return }
            postList.items.insert(contentsOf: newPosts, at: 0)

            if modelManager.isModelInstalled {
                enqueueImages(for: newPosts)
            }
        } catch {
            genLog = "⚠️ Refresh failed"
        }
    }

    @MainActor
    func enqueueImages(for posts: [Post]) {
        for post in posts {
            if let prompt = post.semanticPrompt,
               let cached = ImageCacheManager.shared.load(for: prompt),
               let idx = postList.items.firstIndex(where: { $0.id == post.id }) {
                postList.items[idx].localImage = cached
            } else {
                generationQueue.append(post)
            }
        }

        guard !isGenerating else { return }
        isGenerating = true
        Task { await processQueue() }
    }

    @MainActor
    func processQueue() async {
        guard let generator else {
            isGenerating = false
            return
        }

        while !generationQueue.isEmpty {
            let post = generationQueue.removeFirst()
            guard let prompt = post.semanticPrompt else { continue }

            do {
                let img = try await generator.generateImage(from: prompt)
                if let idx = postList.items.firstIndex(where: { $0.id == post.id }) {
                    postList.items[idx].localImage = img
                }
                ImageCacheManager.shared.save(img, for: prompt)
            } catch {
                #if DEBUG
                print("⚠️ Image generation failed:", error)
                #endif
            }

            try? await Task.sleep(nanoseconds: 400_000_000)
        }

        isGenerating = false
    }
}


