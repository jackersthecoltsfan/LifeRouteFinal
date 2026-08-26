import Foundation
import Combine

struct LifeRouteClientProfile: Identifiable, Codable, Hashable {
    let id: UUID
    var first2: String
    var last2: String
    var address: String
    var preferredActivities: [String]
    var currentTargets: [String]
    var behaviorsOfConcern: [String]
    var communicationNotes: String
    var promptingNotes: String
    var caregiverNotes: String
    var clinicalNotes: String
    var updatedAt: Date

    var code: String { first2 + last2 }
}

enum ClientProfileCoreError: LocalizedError {
    case invalidInitials
    case duplicateCode(String)

    var errorDescription: String? {
        switch self {
        case .invalidInitials:
            return "Use exactly two first-name initials and two last-name initials."
        case .duplicateCode(let code):
            return "A client with code \(code) is already saved."
        }
    }
}

@MainActor
final class ClientProfileCore: ObservableObject {
    @Published private(set) var clients: [LifeRouteClientProfile] = []

    func saveProfile(
        id: UUID?,
        first2: String,
        last2: String,
        address: String,
        preferredActivities: String,
        currentTargets: String,
        behaviorsOfConcern: String,
        communicationNotes: String,
        promptingNotes: String,
        caregiverNotes: String,
        clinicalNotes: String
    ) throws -> LifeRouteClientProfile {
        let first = Self.normalizedPair(first2)
        let last = Self.normalizedPair(last2)
        guard first.count == 2, last.count == 2 else { throw ClientProfileCoreError.invalidInitials }

        let code = first + last
        if clients.contains(where: { $0.code.caseInsensitiveCompare(code) == .orderedSame && $0.id != id }) {
            throw ClientProfileCoreError.duplicateCode(code)
        }

        let profile = LifeRouteClientProfile(
            id: id ?? UUID(),
            first2: first,
            last2: last,
            address: Self.clean(address),
            preferredActivities: Self.list(from: preferredActivities),
            currentTargets: Self.list(from: currentTargets),
            behaviorsOfConcern: Self.list(from: behaviorsOfConcern),
            communicationNotes: Self.clean(communicationNotes),
            promptingNotes: Self.clean(promptingNotes),
            caregiverNotes: Self.clean(caregiverNotes),
            clinicalNotes: Self.clean(clinicalNotes),
            updatedAt: Date()
        )

        if let index = clients.firstIndex(where: { $0.id == profile.id }) {
            clients[index] = profile
        } else {
            clients.append(profile)
        }
        clients.sort { $0.code.localizedCaseInsensitiveCompare($1.code) == .orderedAscending }
        return profile
    }

    func removeClient(id: UUID) {
        clients.removeAll { $0.id == id }
    }

    func client(code: String) -> LifeRouteClientProfile? {
        clients.first { $0.code.caseInsensitiveCompare(code) == .orderedSame }
    }

    static func normalizedPair(_ value: String) -> String {
        let letters = value.unicodeScalars
            .filter { CharacterSet.letters.contains($0) }
            .prefix(2)
        let raw = String(String.UnicodeScalarView(letters))
        guard let first = raw.first else { return "" }
        let remainder = raw.dropFirst().lowercased()
        return String(first).uppercased() + remainder
    }

    static func list(from value: String) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in value.split(whereSeparator: { $0 == "\n" || $0 == "," || $0 == ";" }) {
            let item = clean(String(raw))
            let key = item.lowercased()
            guard !item.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(item)
            if result.count == 60 { break }
        }
        return result
    }

    private static func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
