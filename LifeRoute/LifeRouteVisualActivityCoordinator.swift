import Combine
import Foundation

/// The bounded rendering profiles used by the root ambient environment. They
/// make same-device A/B captures distinguish the page shell, scenery effects,
/// Dynamic effect, and their combined cost without changing the scenery camera.
enum LifeRouteAmbientRenderMode: String, CaseIterable, Sendable {
    case full
    case frozen
    case sceneryOnly
    case dynamicOnly
    case noEffects

    var plan: LifeRouteAmbientRenderPlan {
        switch self {
        case .full:
            return .init(usesLiveClock: true, showsSceneryEffects: true, showsDynamicEffect: true)
        case .frozen:
            return .init(usesLiveClock: false, showsSceneryEffects: true, showsDynamicEffect: true)
        case .sceneryOnly:
            return .init(usesLiveClock: true, showsSceneryEffects: true, showsDynamicEffect: false)
        case .dynamicOnly:
            return .init(usesLiveClock: true, showsSceneryEffects: false, showsDynamicEffect: true)
        case .noEffects:
            return .init(usesLiveClock: false, showsSceneryEffects: false, showsDynamicEffect: false)
        }
    }
}

struct LifeRouteAmbientRenderPlan: Equatable, Sendable {
    let usesLiveClock: Bool
    let showsSceneryEffects: Bool
    let showsDynamicEffect: Bool

    var showsStaticEffects: Bool {
        showsSceneryEffects || showsDynamicEffect
    }
}

/// Root-owned reference counting for foreground experiences that should pause
/// ambient movement. Callers retain the returned request identifier for their
/// visible lifetime and release that exact identifier on disappearance.
@MainActor
final class LifeRouteVisualActivityCoordinator: ObservableObject {
    @Published private(set) var ambientSuspensionCount = 0

    private var activeRequests = Set<UUID>()
    private var foregroundRequests = Set<UUID>()
    private var themeCenterRequestID: UUID?

    var ambientRenderingIsActive: Bool {
        activeRequests.isEmpty
    }

    /// Living scenery remains exposed during selector and root interactions.
    /// Opaque coverage (including Timer D) still releases the scene renderer.
    var livingEnvironmentRenderingIsActive: Bool {
        activeRequests.subtracting(foregroundRequests).isEmpty
    }

    @discardableResult
    func acquireForegroundInteraction() -> UUID {
        let requestID = UUID()
        foregroundRequests.insert(requestID)
        activeRequests.insert(requestID)
        publishStateIfNeeded()
        return requestID
    }

    @discardableResult
    func acquireAmbientSuspension() -> UUID {
        let requestID = UUID()
        activeRequests.insert(requestID)
        publishStateIfNeeded()
        return requestID
    }

    func releaseAmbientSuspension(_ requestID: UUID) {
        guard activeRequests.remove(requestID) != nil else { return }
        foregroundRequests.remove(requestID)
        publishStateIfNeeded()
    }

    /// Bridges Theme Center visibility into the shared reference-counted
    /// coordinator. Repeated lifecycle callbacks are intentionally idempotent.
    func setThemeCenterVisible(_ isVisible: Bool) {
        if isVisible {
            guard themeCenterRequestID == nil else { return }
            themeCenterRequestID = acquireForegroundInteraction()
        } else {
            guard let requestID = themeCenterRequestID else { return }
            releaseAmbientSuspension(requestID)
            themeCenterRequestID = nil
        }
    }

    private func publishStateIfNeeded() {
        let updatedCount = activeRequests.count
        guard ambientSuspensionCount != updatedCount else { return }
        ambientSuspensionCount = updatedCount
    }
}

#if DEBUG
/// Launch-only, non-persistent rendering choices for deterministic local A/B
/// capture. Example: `-LifeRouteVisualActivityMode sceneryOnly`.
enum LifeRouteDebugVisualActivityMode: String, CaseIterable {
    case full
    case frozen
    case sceneryOnly
    case dynamicOnly
    case noEffects

    static var current: Self {
        let arguments = ProcessInfo.processInfo.arguments
        guard let keyIndex = arguments.firstIndex(of: "-LifeRouteVisualActivityMode") else {
            return .full
        }
        let valueIndex = arguments.index(after: keyIndex)
        guard arguments.indices.contains(valueIndex), let mode = Self(rawValue: arguments[valueIndex]) else {
            return .full
        }
        return mode
    }

    var ambientRenderMode: LifeRouteAmbientRenderMode {
        LifeRouteAmbientRenderMode(rawValue: rawValue) ?? .full
    }
}
#endif
