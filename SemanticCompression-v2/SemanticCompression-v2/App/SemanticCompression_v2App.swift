//
//  SemanticCompressionApp.swift
//  SemanticCompressionApp
//
//  Created by Tasuku Kato on 2025/10/21.
//

import SwiftUI

@main
struct SemanticCompressionApp: App {

    @StateObject private var taggerHolder = TaggerHolder()

    @StateObject private var modelManager =
        ModelManager()

    init() {
        Task.detached(priority: .utility) {

            let isInstalled = await MainActor.run {
                ModelManager.shared.isModelInstalled
            }

            if isInstalled {
                try? await SigLIP2Service.shared.loadIfNeeded()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(taggerHolder)
                .environmentObject(modelManager)
                .task {
                    taggerHolder.loadAll()
                }
        }
    }
}
