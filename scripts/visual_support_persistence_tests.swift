import Foundation

#if !canImport(Combine)
protocol ObservableObject: AnyObject {}
@propertyWrapper struct Published<Value> {
    var wrappedValue: Value
    init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}
#endif

// Test doubles only for persisted domains unrelated to visual supports. The
// visual declarations are extracted from the production SessionToolsDomain.
struct LifeRouteClientProfile: Codable {
    var id = UUID()
    var first2 = "AA"
    var last2 = "BB"
    var address = ""
    var preferredActivities: [String] = []
    var currentTargets: [String] = []
    var behaviorsOfConcern: [String] = []
    var communicationNotes = ""
    var promptingNotes = ""
    var caregiverNotes = ""
    var clinicalNotes = ""
    var code: String { first2 + last2 }
}

enum ClientProfileCore {
    static func normalizedPair(_ value: String) -> String {
        String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2)).uppercased()
    }
}

enum LifeRoutePlaceKind: String, Codable { case other }

struct LifeRouteSavedPlace: Codable {
    var id: UUID
    var name: String
    var address: String
    var kind: LifeRoutePlaceKind
    var minimumVisitMinutes: Int
    var useInGapSuggestions: Bool
}

enum LifeRouteTodoCategory: String, Codable { case other }
enum LifeRouteTodoPriority: String, Codable {
    case normal
    var sortWeight: Int { 0 }
}

struct LifeRouteTodo: Codable {
    var id: UUID
    var title: String
    var category: LifeRouteTodoCategory
    var durationMinutes: Int
    var savedPlaceID: UUID?
    var address: String
    var priority: LifeRouteTodoPriority
    var dueDate: Date
    var notes: String
    var completed: Bool
    var createdAt: Date
    var completedAt: Date?
}

@main
@MainActor
enum VisualSupportPersistenceTests {
    private static var assertionCount = 0

    private static let clientAID = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
    private static let clientBID = UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000002")!
    private static let iconA1ID = UUID(uuidString: "A1000000-0000-0000-0000-000000000001")!
    private static let iconA2ID = UUID(uuidString: "A2000000-0000-0000-0000-000000000002")!
    private static let iconB1ID = UUID(uuidString: "B1000000-0000-0000-0000-000000000001")!
    private static let choiceID = UUID(uuidString: "C1000000-0000-0000-0000-000000000001")!
    private static let scheduleID = UUID(uuidString: "51000000-0000-0000-0000-000000000001")!
    private static let step1ID = UUID(uuidString: "51100000-0000-0000-0000-000000000001")!
    private static let step2ID = UUID(uuidString: "51200000-0000-0000-0000-000000000002")!

    private static let iconA1Bytes = Data([0x00, 0x01, 0x7F, 0x80, 0xFE, 0xFF, 0x41, 0x42, 0x43])
    private static let iconB1Bytes = Data([0xCA, 0xFE, 0xBA, 0xBE, 0x10, 0x20, 0x30, 0x00])

    static func main() async throws {
        try await legacyMigrationAndEditingContract()
        try await iconRemovalAndClientRetentionContract()
        try await failedDiskWriteContract()
        print("Visual support model + actual persistence fixtures passed (\(assertionCount) assertions).")
    }

    private static func legacyMigrationAndEditingContract() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("liferoute-visual-support-legacy-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let stateDirectory = root.appendingPathComponent("LifeRoute/NativeState", isDirectory: true)
        let imageDirectory = stateDirectory.appendingPathComponent("VisualImages", isDirectory: true)
        try fileManager.createDirectory(at: imageDirectory, withIntermediateDirectories: true)

        let iconA1URL = imageDirectory.appendingPathComponent(fileName(for: iconA1ID))
        let iconB1URL = imageDirectory.appendingPathComponent(fileName(for: iconB1ID))
        try iconA1Bytes.write(to: iconA1URL, options: [.atomic])
        try iconB1Bytes.write(to: iconB1URL, options: [.atomic])
        let initialImageDigests = try imageDigests(in: imageDirectory)

        let legacyJSON = legacySchema7Fixture()
        let legacyData = try JSONSerialization.data(withJSONObject: legacyJSON, options: [.sortedKeys])
        try legacyData.write(
            to: stateDirectory.appendingPathComponent("native-state-v1.json", isDirectory: false),
            options: [.atomic]
        )

        var store = LifeRoutePersistenceStore(fileManager: fileManager, applicationSupportDirectory: root)
        expect(store.recoveryMessage == nil, "schema 7 is read as a supported additive migration")
        var restored = store.loadClientVisualSupports()
        assertLegacyIdentity(restored, phase: "initial schema 7 load")

        let core = ClientVisualSupportCore(restoredState: restored, persistenceStore: store)
        let token = try core.saveTokenBoard(
            clientCode: "AABB",
            title: "  Five then playground  ",
            tokenCount: 5,
            rewardIconID: iconA1ID,
            rewardLabel: "  Playground  "
        )
        expect(token.title == "Five then playground", "new token title is normalized")
        expect(token.rewardLabel == "Playground", "new token reward label is normalized")
        await store.flushPendingWrites()

        store = LifeRoutePersistenceStore(fileManager: fileManager, applicationSupportDirectory: root)
        expect(store.recoveryMessage == nil, "schema 8 rewrite reconstructs without recovery")
        restored = store.loadClientVisualSupports()
        assertLegacyIdentity(restored, phase: "reopen after token save")
        expect(restored.tokenBoards.map(\.id) == [token.id], "new token persists without duplicating legacy artifacts")
        expect(restored.tokenBoards.first?.tokenCount == 5, "new token count survives reconstruction")
        expect(restored.tokenBoards.first?.rewardIconID == iconA1ID, "new token reward reference survives reconstruction")
        try expect(imageDigests(in: imageDirectory) == initialImageDigests, "token save leaves every legacy image file byte-for-byte unchanged")
        try expect(Data(contentsOf: iconA1URL) == iconA1Bytes, "client A image data is exact after rewrite")
        try expect(Data(contentsOf: iconB1URL) == iconB1Bytes, "client B image data is exact after rewrite")
        try assertExternalImageReferences(in: stateDirectory, expected: [iconA1ID, iconB1ID])

        let editingCore = ClientVisualSupportCore(restoredState: restored, persistenceStore: store)
        let originalChoice = try require(restored.choiceBoards.first(where: { $0.id == choiceID }), "legacy choice exists")
        let originalSchedule = try require(restored.schedules.first(where: { $0.id == scheduleID }), "legacy schedule exists")
        let originalToken = try require(restored.tokenBoards.first(where: { $0.id == token.id }), "saved token exists")

        let choiceCountBefore = editingCore.choiceBoards.count
        let editedChoice = try editingCore.updateChoiceBoard(
            id: choiceID,
            clientCode: "AABB",
            title: "Updated choices",
            iconIDs: [iconA1ID, iconA2ID],
            columns: 3
        )
        expect(editedChoice.id == originalChoice.id, "choice edit keeps its stable id")
        expect(editedChoice.createdAt == originalChoice.createdAt, "choice edit keeps createdAt")
        expect(editingCore.choiceBoards.count == choiceCountBefore, "choice edit does not append a duplicate")
        expect(editingCore.choiceBoards.filter { $0.id == choiceID }.count == 1, "choice id remains unique")

        expectError(.crossClientReference, "choice edit rejects a different owner") {
            _ = try editingCore.updateChoiceBoard(
                id: choiceID, clientCode: "CCDD", title: "Wrong owner",
                iconIDs: [iconB1ID], columns: 2
            )
        }
        expectError(.crossClientReference, "schedule edit rejects a different owner") {
            _ = try editingCore.updateSchedule(
                id: scheduleID, clientCode: "CCDD", title: "Wrong owner",
                steps: originalSchedule.steps, kind: .firstThen
            )
        }
        expectError(.crossClientReference, "token edit rejects a different owner") {
            _ = try editingCore.updateTokenBoard(
                id: token.id, clientCode: "CCDD", title: "Wrong owner", tokenCount: 5,
                rewardIconID: iconB1ID, rewardLabel: "Wrong"
            )
        }
        expectError(.crossClientReference, "token save rejects a cross-client reward image") {
            _ = try editingCore.saveTokenBoard(
                clientCode: "AABB", title: "Cross-client reward", tokenCount: 4,
                rewardIconID: iconB1ID, rewardLabel: "Wrong"
            )
        }

        expectError(.invalidFirstThenStepCount, "new First / Then rejects one step") {
            _ = try editingCore.saveSchedule(
                clientCode: "AABB", title: "Incomplete",
                steps: [ClientVisualScheduleStep(label: "Only")], kind: .firstThen
            )
        }
        expectError(.invalidFirstThenStepCount, "First / Then edit rejects three steps") {
            _ = try editingCore.updateSchedule(
                id: scheduleID, clientCode: "AABB", title: "Invalid",
                steps: originalSchedule.steps + [ClientVisualScheduleStep(label: "Extra")], kind: .firstThen
            )
        }
        expect(editingCore.schedules.first(where: { $0.id == scheduleID })?.kind == nil,
               "failed First / Then edit leaves legacy kind unknown")

        let scheduleCountBefore = editingCore.schedules.count
        let editedSchedule = try editingCore.updateSchedule(
            id: scheduleID,
            clientCode: "AABB",
            title: "Explicit First Then",
            steps: originalSchedule.steps,
            kind: .firstThen
        )
        expect(editedSchedule.id == originalSchedule.id, "schedule edit keeps its stable id")
        expect(editedSchedule.createdAt == originalSchedule.createdAt, "schedule edit keeps createdAt")
        expect(editedSchedule.kind == .firstThen, "explicit legacy conversion records First / Then kind")
        expect(editingCore.schedules.count == scheduleCountBefore, "schedule edit does not append a duplicate")
        expect(editingCore.schedules.filter { $0.id == scheduleID }.count == 1, "schedule id remains unique")

        expectError(.invalidTokenCount, "token save rejects count below three") {
            _ = try editingCore.saveTokenBoard(
                clientCode: "AABB", title: "Too few", tokenCount: 2,
                rewardIconID: nil, rewardLabel: "Reward"
            )
        }
        expectError(.invalidTokenCount, "token save rejects count above ten") {
            _ = try editingCore.saveTokenBoard(
                clientCode: "AABB", title: "Too many", tokenCount: 11,
                rewardIconID: nil, rewardLabel: "Reward"
            )
        }
        expectError(.invalidTokenCount, "token edit rejects out-of-range count") {
            _ = try editingCore.updateTokenBoard(
                id: token.id, clientCode: "AABB", title: "Invalid edit", tokenCount: 11,
                rewardIconID: iconA1ID, rewardLabel: "Reward"
            )
        }

        let tokenCountBefore = editingCore.tokenBoards.count
        let editedToken = try editingCore.updateTokenBoard(
            id: token.id,
            clientCode: "AABB",
            title: "Six then playground",
            tokenCount: 6,
            rewardIconID: iconA2ID,
            rewardLabel: "Outside"
        )
        expect(editedToken.id == originalToken.id, "token edit keeps its stable id")
        expect(editedToken.createdAt == originalToken.createdAt, "token edit keeps createdAt")
        expect(editingCore.tokenBoards.count == tokenCountBefore, "token edit does not append a duplicate")
        expect(editingCore.tokenBoards.filter { $0.id == token.id }.count == 1, "token id remains unique")

        let deletedChoice = try editingCore.saveChoiceBoard(
            clientCode: "AABB", title: "Delete me", iconIDs: [iconA2ID], columns: 2
        )
        editingCore.removeChoiceBoard(id: deletedChoice.id)
        expectError(.missingArtifact, "deleted choice edit fails instead of recreating") {
            _ = try editingCore.updateChoiceBoard(
                id: deletedChoice.id, clientCode: "AABB", title: "Do not recreate",
                iconIDs: [iconA2ID], columns: 2
            )
        }

        let deletedSchedule = try editingCore.saveSchedule(
            clientCode: "AABB", title: "Delete me",
            steps: [ClientVisualScheduleStep(label: "Step")], kind: .visualSchedule
        )
        editingCore.removeSchedule(id: deletedSchedule.id)
        expectError(.missingArtifact, "deleted schedule edit fails instead of recreating") {
            _ = try editingCore.updateSchedule(
                id: deletedSchedule.id, clientCode: "AABB", title: "Do not recreate",
                steps: deletedSchedule.steps, kind: .visualSchedule
            )
        }

        let deletedToken = try editingCore.saveTokenBoard(
            clientCode: "AABB", title: "Delete me", tokenCount: 3,
            rewardIconID: nil, rewardLabel: "Reward"
        )
        editingCore.removeTokenBoard(id: deletedToken.id)
        expectError(.missingArtifact, "deleted token edit fails instead of recreating") {
            _ = try editingCore.updateTokenBoard(
                id: deletedToken.id, clientCode: "AABB", title: "Do not recreate", tokenCount: 3,
                rewardIconID: nil, rewardLabel: "Reward"
            )
        }

        await store.flushPendingWrites()
        let finalStore = LifeRoutePersistenceStore(fileManager: fileManager, applicationSupportDirectory: root)
        let finalState = finalStore.loadClientVisualSupports()
        expect(finalState.choiceBoards.filter { $0.id == choiceID }.count == 1, "edited choice reconstructs exactly once")
        expect(finalState.choiceBoards.first(where: { $0.id == choiceID })?.createdAt == originalChoice.createdAt,
               "reconstructed choice keeps original createdAt")
        expect(finalState.schedules.filter { $0.id == scheduleID }.count == 1, "edited schedule reconstructs exactly once")
        expect(finalState.schedules.first(where: { $0.id == scheduleID })?.kind == .firstThen,
               "explicit First / Then kind reconstructs")
        expect(finalState.schedules.first(where: { $0.id == scheduleID })?.createdAt == originalSchedule.createdAt,
               "reconstructed schedule keeps original createdAt")
        expect(finalState.tokenBoards.filter { $0.id == token.id }.count == 1, "edited token reconstructs exactly once")
        expect(finalState.tokenBoards.first(where: { $0.id == token.id })?.createdAt == originalToken.createdAt,
               "reconstructed token keeps original createdAt")
        expect(finalState.tokenBoards.first(where: { $0.id == token.id })?.tokenCount == 6,
               "edited token count reconstructs")
        try expect(imageDigests(in: imageDirectory) == initialImageDigests,
                   "all edits leave the legacy image files byte-for-byte unchanged")
    }

    private static func iconRemovalAndClientRetentionContract() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("liferoute-visual-support-retain-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let store = LifeRoutePersistenceStore(fileManager: fileManager, applicationSupportDirectory: root)
        var clientA = LifeRouteClientProfile()
        clientA.id = clientAID
        clientA.first2 = "AA"
        clientA.last2 = "BB"
        var clientB = LifeRouteClientProfile()
        clientB.id = clientBID
        clientB.first2 = "CC"
        clientB.last2 = "DD"
        store.saveClients([clientA, clientB])

        let core = ClientVisualSupportCore(persistenceStore: store)
        let iconA = try core.addIcon(clientCode: "AABB", label: "A reward", imageData: iconA1Bytes)
        let iconB = try core.addIcon(clientCode: "CCDD", label: "B reward", imageData: iconB1Bytes)
        let tokenA = try core.saveTokenBoard(
            clientCode: "AABB", title: "A board", tokenCount: 3,
            rewardIconID: iconA.id, rewardLabel: "A reward"
        )
        let tokenB = try core.saveTokenBoard(
            clientCode: "CCDD", title: "B board", tokenCount: 10,
            rewardIconID: iconB.id, rewardLabel: "B reward"
        )

        core.removeIcon(id: iconA.id)
        expect(core.tokenBoards.first(where: { $0.id == tokenA.id }) != nil,
               "removing a reward icon retains its token board")
        expect(core.tokenBoards.first(where: { $0.id == tokenA.id })?.rewardIconID == nil,
               "removing a reward icon clears only the token reference")
        expect(core.tokenBoards.first(where: { $0.id == tokenB.id })?.rewardIconID == iconB.id,
               "removing one client's icon leaves another client's reward reference")

        store.saveClients([clientA])
        core.retainClients([clientA])
        expect(core.tokenBoards.map(\.id) == [tokenA.id], "retaining client A removes client B token boards")
        expect(core.icons.allSatisfy { $0.clientID == clientAID }, "retaining client A removes client B icons")

        await store.flushPendingWrites()
        let reopenedStore = LifeRoutePersistenceStore(fileManager: fileManager, applicationSupportDirectory: root)
        let reopened = reopenedStore.loadClientVisualSupports()
        expect(reopened.tokenBoards.map(\.id) == [tokenA.id], "retained token selection survives reconstruction")
        expect(reopened.tokenBoards.first?.rewardIconID == nil, "cleared reward reference survives reconstruction")
        expect(reopened.icons.isEmpty, "removed and unretained image records stay removed after reconstruction")
    }

    private static func failedDiskWriteContract() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("liferoute-visual-support-write-failure-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let store = LifeRoutePersistenceStore(fileManager: fileManager, applicationSupportDirectory: root)
        var client = LifeRouteClientProfile()
        client.id = clientAID
        client.first2 = "AA"
        client.last2 = "BB"
        store.saveClients([client])
        await store.flushPendingWrites()
        expect(store.recoveryMessage == nil, "write-failure fixture begins from a confirmed store")

        let core = ClientVisualSupportCore(persistenceStore: store)
        let stateDirectory = root.appendingPathComponent("LifeRoute/NativeState", isDirectory: true)
        let imageDirectory = stateDirectory.appendingPathComponent("VisualImages", isDirectory: true)
        try fileManager.removeItem(at: imageDirectory)
        try Data([0x42]).write(to: imageDirectory, options: [.atomic])

        let failedBoard = try core.saveTokenBoard(
            clientCode: "AABB", title: "Retry this board", tokenCount: 4,
            rewardIconID: nil, rewardLabel: "Break"
        )
        do {
            try await core.confirmSavedBoards()
            expect(false, "a blocked image directory cannot report a confirmed save")
        } catch {
            expect(error.localizedDescription == ClientVisualSupportError.persistenceUnavailable.localizedDescription,
                   "actual writer failure surfaces as persistenceUnavailable")
        }
        expect(core.tokenBoards.map(\.id) == [failedBoard.id],
               "failed save keeps the draft's stable in-memory id for retry")

        let diskData = try Data(contentsOf: stateDirectory.appendingPathComponent("native-state-v1.json"))
        let diskObject = try JSONSerialization.jsonObject(with: diskData) as! [String: Any]
        expect((diskObject["tokenBoards"] as? [[String: Any]])?.isEmpty == true,
               "failed writer does not create a false persisted token board")

        try fileManager.removeItem(at: imageDirectory)
        try fileManager.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        let retried = try core.updateTokenBoard(
            id: failedBoard.id, clientCode: "AABB", title: "Retry succeeded", tokenCount: 4,
            rewardIconID: nil, rewardLabel: "Break"
        )
        expect(retried.id == failedBoard.id, "retry edits the failed draft under the same id")
        expect(retried.createdAt == failedBoard.createdAt, "retry preserves the failed draft createdAt")
        try await core.confirmSavedBoards()
        expect(store.recoveryMessage == nil, "successful retry clears the writer error")

        let reopened = LifeRoutePersistenceStore(fileManager: fileManager, applicationSupportDirectory: root)
            .loadClientVisualSupports()
        expect(reopened.tokenBoards.map(\.id) == [failedBoard.id],
               "successful retry reconstructs one token board under the original id")
        expect(reopened.tokenBoards.first?.title == "Retry succeeded",
               "successful retry reconstructs the edited draft")
    }

    private static func legacySchema7Fixture() -> [String: Any] {
        [
            "schemaVersion": 7,
            "clients": [
                clientJSON(id: clientAID, first: "AA", last: "BB"),
                clientJSON(id: clientBID, first: "CC", last: "DD")
            ],
            "visualIcons": [
                [
                    "id": iconA1ID.uuidString,
                    "clientID": clientAID.uuidString,
                    "clientCode": "AABB",
                    "label": "Wash hands",
                    "imageFileName": fileName(for: iconA1ID),
                    "createdAt": "2026-01-02T03:04:05Z"
                ],
                [
                    "id": iconA2ID.uuidString,
                    "clientID": clientAID.uuidString,
                    "clientCode": "AABB",
                    "label": "Shoes",
                    "createdAt": "2026-01-02T03:05:05Z"
                ],
                [
                    "id": iconB1ID.uuidString,
                    "clientID": clientBID.uuidString,
                    "clientCode": "CCDD",
                    "label": "Snack",
                    "imageFileName": fileName(for: iconB1ID),
                    "createdAt": "2026-01-02T03:06:05Z"
                ]
            ],
            "choiceBoards": [[
                "id": choiceID.uuidString,
                "clientID": clientAID.uuidString,
                "clientCode": "AABB",
                "title": "Morning choices",
                "iconIDs": [iconA2ID.uuidString, iconA1ID.uuidString],
                "columns": 2,
                "createdAt": "2026-02-03T04:05:06Z"
            ]],
            "visualSchedules": [[
                "id": scheduleID.uuidString,
                "clientID": clientAID.uuidString,
                "clientCode": "AABB",
                "title": "Legacy two step",
                "steps": [
                    ["id": step1ID.uuidString, "label": "First stored step", "iconID": iconA1ID.uuidString],
                    ["id": step2ID.uuidString, "label": "Then stored step", "iconID": iconA2ID.uuidString]
                ],
                "createdAt": "2026-03-04T05:06:07Z"
            ]],
            "homeAddress": "",
            "savedPlaces": [],
            "todos": [],
            "dayStops": [],
            "routeBufferMinutes": 10,
            "manualCalendarEvents": [],
            "providerCalendarEvents": []
        ]
    }

    private static func clientJSON(id: UUID, first: String, last: String) -> [String: Any] {
        [
            "id": id.uuidString,
            "first2": first,
            "last2": last,
            "address": "",
            "preferredActivities": [],
            "currentTargets": [],
            "behaviorsOfConcern": [],
            "communicationNotes": "",
            "promptingNotes": "",
            "caregiverNotes": "",
            "clinicalNotes": ""
        ]
    }

    private static func assertLegacyIdentity(_ state: RestoredClientVisualSupportState, phase: String) {
        expect(state.icons.map(\.id) == [iconA1ID, iconA2ID, iconB1ID], "\(phase): icon UUID and order survive")
        expect(state.icons.map(\.label) == ["Wash hands", "Shoes", "Snack"], "\(phase): icon labels survive")
        expect(state.icons.first(where: { $0.id == iconA1ID })?.imageData == iconA1Bytes,
               "\(phase): first exact image bytes hydrate")
        expect(state.icons.first(where: { $0.id == iconB1ID })?.imageData == iconB1Bytes,
               "\(phase): second exact image bytes hydrate")
        expect(state.icons.first(where: { $0.id == iconA2ID })?.imageData == nil,
               "\(phase): label-only icon remains label-only")

        expect(state.choiceBoards.map(\.id) == [choiceID], "\(phase): choice UUID survives")
        expect(state.choiceBoards.first?.title == "Morning choices", "\(phase): choice title survives")
        expect(state.choiceBoards.first?.iconIDs == [iconA2ID, iconA1ID], "\(phase): choice ordering survives")
        expect(state.choiceBoards.first?.createdAt == isoDate("2026-02-03T04:05:06Z"),
               "\(phase): choice createdAt survives")

        expect(state.schedules.map(\.id) == [scheduleID], "\(phase): schedule UUID survives")
        expect(state.schedules.first?.title == "Legacy two step", "\(phase): schedule title survives")
        expect(state.schedules.first?.steps.map(\.id) == [step1ID, step2ID], "\(phase): step UUID/order survive")
        expect(state.schedules.first?.steps.map(\.iconID) == [iconA1ID, iconA2ID], "\(phase): step image references survive")
        expect(state.schedules.first?.createdAt == isoDate("2026-03-04T05:06:07Z"),
               "\(phase): schedule createdAt survives")
        expect(state.schedules.first?.kind == nil, "\(phase): legacy schedule kind stays unknown without a count heuristic")
    }

    private static func assertExternalImageReferences(in stateDirectory: URL, expected ids: [UUID]) throws {
        let data = try Data(contentsOf: stateDirectory.appendingPathComponent("native-state-v1.json"))
        let object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        expect((object["schemaVersion"] as? Int) == 8, "first mutation upgrades the persisted schema to 8")
        let icons = object["visualIcons"] as! [[String: Any]]
        let references = Set(icons.compactMap { $0["imageFileName"] as? String })
        expect(references == Set(ids.map(fileName(for:))), "rewritten JSON keeps canonical external image references")
        expect(icons.allSatisfy { $0["imageData"] == nil }, "rewritten JSON never inlines image bytes")
        let schedules = object["visualSchedules"] as! [[String: Any]]
        expect(schedules.first(where: { ($0["id"] as? String)?.caseInsensitiveCompare(scheduleID.uuidString) == .orderedSame })?["kind"] == nil,
               "unknown legacy schedule kind is not invented during rewrite")
    }

    private static func imageDigests(in directory: URL) throws -> [String: String] {
        let files = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ).sorted { $0.lastPathComponent < $1.lastPathComponent }
        return Dictionary(uniqueKeysWithValues: try files.map { url in
            let data = try Data(contentsOf: url)
            return (url.lastPathComponent, stableDigest(data))
        })
    }

    // A deterministic test digest plus direct Data equality assertions avoids a
    // crypto-framework dependency in the command-line contract executable.
    private static func stableDigest(_ data: Data) -> String {
        var value: UInt64 = 0xcbf29ce484222325
        for byte in data {
            value ^= UInt64(byte)
            value &*= 0x100000001b3
        }
        return String(format: "%016llx", value)
    }

    private static func fileName(for id: UUID) -> String {
        "\(id.uuidString.lowercased()).visual"
    }

    private static func isoDate(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private static func require<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else {
            fputs("Fixture failure: \(message)\n", stderr)
            throw FixtureError.missingValue(message)
        }
        return value
    }

    private static func expectError(
        _ expected: ClientVisualSupportError,
        _ message: String,
        operation: () throws -> Void
    ) {
        assertionCount += 1
        do {
            try operation()
            fputs("Assertion failed: \(message); operation succeeded\n", stderr)
            exit(1)
        } catch {
            guard error.localizedDescription == expected.localizedDescription else {
                fputs("Assertion failed: \(message); expected '\(expected.localizedDescription)', got '\(error.localizedDescription)'\n", stderr)
                exit(1)
            }
        }
    }

    private static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) rethrows {
        assertionCount += 1
        guard try condition() else {
            fputs("Assertion failed: \(message)\n", stderr)
            exit(1)
        }
    }

    private enum FixtureError: Error {
        case missingValue(String)
    }
}
