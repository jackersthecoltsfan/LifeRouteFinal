import SwiftUI
import MetalKit
import OSLog

/// The existing root backdrop selects this view for ONE scene. Foreground
/// SwiftUI state never receives frame time, drawable changes or GPU callbacks.
struct LivingThemeEnvironment: UIViewRepresentable {
    let scene: LivingThemeScene
    let playback: LivingScenePlayback

    func makeUIView(context: Context) -> LivingEnvironmentSurface {
        LivingEnvironmentSurface(scene: scene, playback: playback)
    }

    func updateUIView(_ surface: LivingEnvironmentSurface, context: Context) {
        surface.update(playback: playback)
    }

    static func dismantleUIView(_ surface: LivingEnvironmentSurface, coordinator: ()) {
        surface.tearDown()
    }
}

/// One surface owns one renderer and its lifetime. Metal is opaque after its
/// first completed frame; a static image covers asynchronous preparation/failure.
final class LivingEnvironmentSurface: UIView {
    private let fallback = UIImageView()
    private var metalView: MTKView?
    private var renderer: LivingSceneRenderer?
    private var playback: LivingScenePlayback
    private var applicationActive = true
    private var observations: [NSObjectProtocol] = []
    private var tornDown = false
    private let scene: LivingThemeScene
    private var preparation: Task<Void, Never>?

    init(scene: LivingThemeScene, playback: LivingScenePlayback) {
        self.scene = scene
        self.playback = playback
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        clipsToBounds = true
        fallback.contentMode = .scaleAspectFill
        fallback.clipsToBounds = true
        fallback.image = UIImage(named: scene.artworkName)
        addSubview(fallback)
        let center = NotificationCenter.default
        observations.append(center.addObserver(forName: UIApplication.willResignActiveNotification,
                                                object: nil, queue: .main) { [weak self] _ in
            self?.applicationActive = false
            self?.reconcile()
        })
        observations.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                                object: nil, queue: .main) { [weak self] _ in
            self?.applicationActive = true
            self?.reconcile()
        })
        observations.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                                object: nil, queue: .main) { [weak self] _ in
            self?.metalView?.releaseDrawables()
        })
        for name in [ProcessInfo.thermalStateDidChangeNotification,
                     Notification.Name.NSProcessInfoPowerStateDidChange] {
            observations.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.reconcile()
            })
        }
        prepareRenderer()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        fallback.frame = bounds
        metalView?.frame = bounds
        reconcile()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        reconcile()
    }

    func update(playback: LivingScenePlayback) {
        guard !tornDown, self.playback != playback else { return }
        self.playback = playback
        reconcile()
    }

    private func prepareRenderer() {
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        let scene = scene
        // Pipeline compilation and asset upload cannot delay theme selection,
        // toolbar construction or root layout. Only one preparation is in flight.
        preparation = Task { [weak self] in
            let resources = try? await LivingScenePreparation.shared.prepare(device: device, scene: scene)
            guard !Task.isCancelled, let self, !self.tornDown else { return }
            guard let resources else {
                Logger(subsystem: "Com.Brandongood.LifeRoute", category: "LivingTheme")
                    .error("Living scene unavailable; retaining static scenery")
                return
            }
            let view = MTKView(frame: self.bounds, device: device)
            view.colorPixelFormat = .bgra8Unorm_srgb
            view.framebufferOnly = true
            view.isOpaque = true
            view.isUserInteractionEnabled = false
            view.isAccessibilityElement = false
            view.autoResizeDrawable = false
            view.isPaused = true
            view.enableSetNeedsDisplay = true
            view.isHidden = false
            let renderer = LivingSceneRenderer(resources: resources)
            renderer.firstFrame = { [weak self, weak view] in
                guard let self, !self.tornDown else { return }
                view?.isHidden = false
                self.fallback.isHidden = true
                // UIImage cache is system-owned; the surface drops its own
                // duplicate image after Metal owns the visible composition.
                self.fallback.image = nil
            }
            renderer.renderFailure = { [weak self, weak view] in
                guard let self, !self.tornDown else { return }
                view?.isPaused = true
                view?.isHidden = true
                view?.delegate = nil
                self.renderer?.tearDown()
                self.renderer = nil
                view?.releaseDrawables()
                self.fallback.image = UIImage(named: self.scene.artworkName)
                self.fallback.isHidden = false
                Logger(subsystem: "Com.Brandongood.LifeRoute", category: "LivingTheme")
                    .error("Living scene GPU stopped; retaining static scenery")
            }
            self.renderer = renderer
            self.metalView = view
            view.delegate = renderer
            self.insertSubview(view, belowSubview: self.fallback)
            self.reconcile()
        }
    }

    private func reconcile() {
        guard !tornDown, let renderer, let view = metalView else { return }
        let thermal: LivingSceneQuality.Thermal
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermal = .nominal
        case .fair: thermal = .fair
        case .serious: thermal = .serious
        case .critical: thermal = .critical
        @unknown default: thermal = .serious
        }
        let quality = LivingSceneQuality.resolve(reduceMotion: playback.reduceMotion,
            lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled,
            thermal: thermal, effectsEnabled: playback.effectsEnabled)
        let attached = window != nil && !isHidden && bounds.width > 0 && bounds.height > 0
        renderer.configure(view: view, playback: playback, attached: attached,
                           applicationActive: applicationActive, quality: quality)
    }

#if DEBUG
    var debugRenderer: LivingSceneRenderer? { renderer }
    var debugShowsFallback: Bool { !fallback.isHidden }
#endif

    func tearDown() {
        guard !tornDown else { return }
        tornDown = true
        preparation?.cancel()
        preparation = nil
        observations.forEach(NotificationCenter.default.removeObserver)
        observations.removeAll()
        metalView?.isPaused = true
        metalView?.delegate = nil
        renderer?.tearDown()
        renderer = nil
        metalView?.releaseDrawables()
        metalView?.removeFromSuperview()
        metalView = nil
        fallback.image = nil
    }

    deinit {
        preparation?.cancel()
        observations.forEach(NotificationCenter.default.removeObserver)
    }
}

/// Serial preparation bounds rapid still/living switches. Cancelled requests
/// cannot start a new upload; at most one already-started upload may finish.
private actor LivingScenePreparation {
    static let shared = LivingScenePreparation()
    func prepare(device: MTLDevice, scene: LivingThemeScene) throws -> LivingSceneResources {
        try Task.checkCancellation()
        let resources = try LivingSceneResources(device: device, scene: scene)
        try Task.checkCancellation()
        return resources
    }
}

/// Immutable GPU resources cross the one asynchronous preparation boundary.
/// No application data, network access, render-time image decode or global cache.
final class LivingSceneResources: @unchecked Sendable {
    let device: MTLDevice
    let queue: MTLCommandQueue
    let pipeline: MTLRenderPipelineState
    let artwork: MTLTexture

    init(device: MTLDevice, scene: LivingThemeScene) throws {
        self.device = device
        guard let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(),
              let vertex = library.makeFunction(name: "livingSceneVertex"),
              let fragment = library.makeFunction(name: scene.fragmentFunction) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.queue = queue
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        artwork = try MTKTextureLoader(device: device).newTexture(name: scene.artworkName,
            scaleFactor: 1, bundle: .main, options: [
                .SRGB: true,
                .generateMipmaps: false,
                .textureUsage: MTLTextureUsage.shaderRead.rawValue,
                .textureStorageMode: MTLStorageMode.private.rawValue,
            ])
    }
}

final class LivingSceneRenderer: NSObject, MTKViewDelegate {
    private var resources: LivingSceneResources?
    private var clock = LivingSceneClock()
    private var quality = LivingSceneQuality.resolve(reduceMotion: true, lowPower: false,
                                                     thermal: .nominal, effectsEnabled: true)
    private var canDraw = false
    private var needsFirstFrame = true
    private var tornDown = false
    private let inFlight = DispatchSemaphore(value: 2)
    var firstFrame: (() -> Void)?
    var renderFailure: (() -> Void)?
#if DEBUG
    private let diagnostics = LivingSceneDiagnostics()
#endif

    init(resources: LivingSceneResources) {
        self.resources = resources
        super.init()
    }

    func configure(view: MTKView, playback: LivingScenePlayback, attached: Bool,
                   applicationActive: Bool, quality: LivingSceneQuality) {
        guard !tornDown else { return }
        let drawableSize = quality.drawableSize(for: view.bounds.size, scale: view.window?.screen.scale ?? 1)
        let drawableChanged = view.drawableSize != drawableSize
        let qualityChanged = self.quality != quality
        self.quality = quality
        let previousCanDraw = canDraw
        canDraw = attached && applicationActive && playback.isActive
        let running = playback.runsContinuously(attached: attached,
            applicationActive: applicationActive, quality: quality)
#if DEBUG
        let runningChanged = clock.isRunning != running
#endif
        clock.setRunning(running)
        if view.preferredFramesPerSecond != max(1, quality.framesPerSecond) {
            view.preferredFramesPerSecond = max(1, quality.framesPerSecond)
        }
        if view.enableSetNeedsDisplay != !running { view.enableSetNeedsDisplay = !running }
        if view.isPaused != !running { view.isPaused = !running }
        if drawableChanged { view.drawableSize = drawableSize }
        // A paused but visible scene draws only for an actual layout/policy
        // transition. Hidden/background scenes submit no command buffers.
        if canDraw && (needsFirstFrame || drawableChanged || qualityChanged || !previousCanDraw) {
            view.draw()
        }
#if DEBUG
        if runningChanged { diagnostics.report(event: running ? "resume" : "pause", elapsed: clock.elapsed) }
#endif
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard !tornDown, canDraw, let resources,
              inFlight.wait(timeout: .now()) == .success else { return }
        let started = CACurrentMediaTime()
        guard let drawable = view.currentDrawable,
              let pass = view.currentRenderPassDescriptor,
              let command = resources.queue.makeCommandBuffer(),
              let encoder = command.makeRenderCommandEncoder(descriptor: pass) else {
            inFlight.signal()
            return
        }
        let elapsed = clock.sample(at: started)
        let textureSize = CGSize(width: resources.artwork.width, height: resources.artwork.height)
        var uniforms = LivingSceneUniforms(
            uvScale: LivingSceneFraming.uvScale(viewport: view.bounds.size, artwork: textureSize),
            textureSize: SIMD2(Float(textureSize.width), Float(textureSize.height)),
            time: Float(elapsed), motion: quality.motionAmount, atmosphere: quality.atmosphereAmount)
        encoder.setRenderPipelineState(resources.pipeline)
        encoder.setFragmentTexture(resources.artwork, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<LivingSceneUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        command.present(drawable)
        let semaphore = inFlight
        let wasFirstFrame = needsFirstFrame
        needsFirstFrame = false
#if DEBUG
        diagnostics.frame(at: started, cpuMilliseconds: (CACurrentMediaTime() - started) * 1000)
        let diagnostics = diagnostics
#endif
        command.addCompletedHandler { [weak self] buffer in
            semaphore.signal()
#if DEBUG
            diagnostics.gpu(milliseconds: max(0, buffer.gpuEndTime - buffer.gpuStartTime) * 1000)
#endif
            if wasFirstFrame || buffer.status == .error {
                DispatchQueue.main.async { [weak self] in
                    guard let self, !self.tornDown else { return }
                    if buffer.status == .error {
                        self.renderFailure?()
                    } else if buffer.status == .completed {
                        self.firstFrame?()
                        self.firstFrame = nil
                    }
                }
            }
        }
        command.commit()
    }

#if DEBUG
    var debugFrameCount: Int { diagnostics.frameCount }
    var debugIsRunning: Bool { clock.isRunning }
    var debugElapsed: TimeInterval { clock.elapsed }
#endif

    func tearDown() {
        guard !tornDown else { return }
        tornDown = true
        clock.setRunning(false)
        canDraw = false
        firstFrame = nil
        renderFailure = nil
        resources = nil // GPU retains only already submitted command resources.
#if DEBUG
        diagnostics.report(event: "teardown", elapsed: clock.elapsed)
#endif
    }
}

#if DEBUG
/// Opt-in aggregate evidence only. No published properties, timers, per-frame
/// logging or production instrumentation. GPU completions use a small lock.
private final class LivingSceneDiagnostics: @unchecked Sendable {
    private static let enabled = ProcessInfo.processInfo.arguments.contains("-LifeRouteLivingDiagnostics")
    private let lock = NSLock()
    private let id = UUID().uuidString
    private var frames = 0
    private var cpuTotal = 0.0
    private var gpuTotal = 0.0
    private var gpuCount = 0
    private var maximumInterval = 0.0
    private var lastFrame: Double?

    init() { if Self.enabled { print("LIVING_SCENE created id=\(id)"); fflush(stdout) } }
    deinit { if Self.enabled { print("LIVING_SCENE released id=\(id)"); fflush(stdout) } }

    var frameCount: Int {
        lock.lock(); defer { lock.unlock() }
        return frames
    }

    func frame(at timestamp: Double, cpuMilliseconds: Double) {
        guard Self.enabled else { return }
        lock.lock(); defer { lock.unlock() }
        frames += 1
        cpuTotal += cpuMilliseconds
        if let lastFrame { maximumInterval = max(maximumInterval, timestamp - lastFrame) }
        lastFrame = timestamp
    }

    func gpu(milliseconds: Double) {
        guard Self.enabled else { return }
        lock.lock(); defer { lock.unlock() }
        gpuTotal += milliseconds
        gpuCount += 1
    }

    func report(event: String, elapsed: Double) {
        guard Self.enabled else { return }
        lock.lock(); defer { lock.unlock() }
        print("LIVING_SCENE \(event) id=\(id) frames=\(frames) elapsed=\(elapsed) cpuMeanMs=\(cpuTotal / Double(max(1, frames))) gpuMeanMs=\(gpuTotal / Double(max(1, gpuCount))) maxIntervalMs=\(maximumInterval * 1000)")
        fflush(stdout)
        lastFrame = nil // inactive time is not a pacing sample
    }
}
#endif
