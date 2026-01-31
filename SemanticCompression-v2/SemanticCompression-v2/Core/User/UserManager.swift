//
//  UserManager.swift
//  SemanticCompression-v2
//

import Foundation
import Combine

struct LocalUser: Codable {
    let id: String              // Keychain の UUID
    var displayName: String     // UserDefaults
    var avatarUrl: String       // UserDefaults
}

final class UserManager: ObservableObject {

    static let shared = UserManager()

    @Published private(set) var currentUser: LocalUser

    private let defaults = UserDefaults.standard
    private let key_displayName = "user_displayName"
    private let key_avatarUrl = "user_avatarUrl"

    private init() {
        let id = KeychainUserID.shared.getUserID()
        let name = defaults.string(forKey: key_displayName) ?? "You"
        let avatar = defaults.string(forKey: key_avatarUrl)
            ?? "https://example.com/avatar/default.png"

        self.currentUser = LocalUser(
            id: id,
            displayName: name,
            avatarUrl: avatar
        )
    }

    func saveUser(_ user: LocalUser) {
        currentUser = user
        defaults.set(user.displayName, forKey: key_displayName)
        defaults.set(user.avatarUrl, forKey: key_avatarUrl)
    }
    
    func resetUser() {
        defaults.removeObject(forKey: key_displayName)
        defaults.removeObject(forKey: key_avatarUrl)

        // ← ここが今有効になる
        KeychainUserID.shared.deleteUserID()

        let newId = KeychainUserID.shared.getUserID()

        currentUser = LocalUser(
            id: newId,
            displayName: "You",
            avatarUrl: ""
        )
    }
}

