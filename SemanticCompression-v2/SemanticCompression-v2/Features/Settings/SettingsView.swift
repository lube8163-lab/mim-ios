//
//  SettingsView.swift
//  SemanticCompression-v2
//
//  Created by Tasuku Kato on 2025/12/16.
//


import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section("このアプリについて") {
                NavigationLink {
                    AppInfoView()
                } label: {
                    Text("アプリの説明")
                }
            }

            Section("ライセンス") {
                NavigationLink {
                    LicenseView()
                } label: {
                    Text("使用モデルとライセンス")
                }
            }
        }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
    }
}
