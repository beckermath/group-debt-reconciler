import Foundation
import Observation
import SwiftUI

enum CreateGroupStep: Hashable {
    case addMembers
}

@Observable
final class CreateGroupModel {
    var groupName = ""
    var bannerUIImage: UIImage?
    var bannerData: Data?
    var groupId: String?
    var addedGuests: [String] = []
    var inviteCode: String?
    var isCreating = false
    var isSubmitting = false
    var isGeneratingLink = false
    var error: String?

    var isNameValid: Bool {
        !groupName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var trimmedName: String {
        groupName.trimmingCharacters(in: .whitespaces)
    }
}
