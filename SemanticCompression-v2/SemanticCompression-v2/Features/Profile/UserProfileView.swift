import SwiftUI
import PhotosUI

struct UserProfileView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var userManager = UserManager.shared

    // Profile edit
    @State private var newName = ""
    @State private var showCopied = false

    // Avatar upload
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploading = false

    // Account delete
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false

    var body: some View {
        Form {

            // MARK: - USER INFO (read only)
            userInfoSection

            // MARK: - PROFILE EDIT
            profileEditSection

            // MARK: - APP / SETTINGS
            appSettingsSection

            // MARK: - DANGER ZONE
            dangerZoneSection
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .alert("Copied!", isPresented: $showCopied) {
            Button("OK", role: .cancel) {}
        }
        .confirmationDialog(
            "アカウントを削除しますか？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("削除する", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この操作は取り消せません。投稿は匿名化されます。")
        }
        .onAppear {
            newName = userManager.currentUser.displayName
        }
    }

    // MARK: - Sections

    private var userInfoSection: some View {
        Section(header: Text("User")) {
            HStack(spacing: 16) {

                AsyncImage(
                    url: URL(string: userManager.currentUser.avatarUrl)
                ) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(userManager.currentUser.displayName)
                        .font(.headline)

                    Text(userManager.currentUser.id)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .contextMenu {
                            Button("Copy User ID") {
                                UIPasteboard.general.string =
                                    userManager.currentUser.id
                                showCopied = true
                            }
                        }
                }
            }
        }
    }

    private var profileEditSection: some View {
        Section(header: Text("Profile")) {

            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images
            ) {
                Label("Change Avatar", systemImage: "photo")
            }
            .onChange(of: selectedPhoto) { _ in
                Task { await uploadAvatar() }
            }

            if isUploading {
                ProgressView("Uploading…")
            }

            TextField("Display Name", text: $newName)

            Button("Save Changes") {
                saveProfile()
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var appSettingsSection: some View {
        Section(header: Text("App")) {

            NavigationLink {
                SettingsView()
            } label: {
                Label("Settings", systemImage: "gear")
            }

            NavigationLink {
                ModelManagementView()
            } label: {
                Label("AI Models", systemImage: "cpu")
            }

            NavigationLink {
                LanguageSettingsView()
            } label: {
                Label("Language", systemImage: "globe")
            }
        }
    }

    private var dangerZoneSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Text("アカウントを削除")
            }
        }
    }

    // MARK: - Avatar Upload

    private func uploadAvatar() async {
        guard let item = selectedPhoto else { return }

        isUploading = true
        defer { isUploading = false }

        do {
            guard
                let data = try await item.loadTransferable(type: Data.self),
                let original = UIImage(data: data)
            else { return }

            let resized = original.resizedSquare(to: 256)
            guard let jpeg = resized.jpegData(compressionQuality: 0.75)
            else { return }

            let rawUrl = try await AvatarUploader.uploadAvatar(
                for: userManager.currentUser.id,
                data: jpeg
            )

            // cache bust
            let bustedUrl =
                rawUrl + "?v=\(Int(Date().timeIntervalSince1970))"

            var updated = userManager.currentUser
            updated.avatarUrl = bustedUrl
            userManager.saveUser(updated)

            #if DEBUG
            print("✅ Avatar uploaded:", bustedUrl)
            #endif

        } catch {
            #if DEBUG
            print("❌ Avatar upload failed:", error)
            #endif
        }
    }

    // MARK: - Save Profile

    private func saveProfile() {
        var updated = userManager.currentUser
        updated.displayName = newName
        userManager.saveUser(updated)
        dismiss()
    }

    // MARK: - Delete Account

    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }

        let userId = userManager.currentUser.id

        do {
            try await AccountService.deleteAccount(userId: userId)
            userManager.resetUser()
            dismiss()
            #if DEBUG
            print("✅ Account deleted")
            #endif
        } catch {
            #if DEBUG
            print("❌ Account delete failed:", error)
            #endif
        }
    }
}

//struct ModelManagementView: View {
  //  var body: some View {
    //    Text("Model management coming soon")
      //      .navigationTitle("AI Models")
    //}
//}

struct LanguageSettingsView: View {
    var body: some View {
        Text("Language settings coming soon")
            .navigationTitle("Language")
    }
}
