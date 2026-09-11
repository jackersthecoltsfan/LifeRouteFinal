import Foundation
import CoreGraphics

@main struct LivingThemeTests {
    static func main() {
        var count = 0
        func expect(_ value: Bool, _ reason: String) {
            count += 1
            precondition(value, reason)
        }
        let scene = LivingThemeScene.scene(for: "scenery.rainforest.day")
        expect(scene == .rainforestDay, "existing persisted rainforest ID selects V2")
        for id in ["royal", "dynamic.emeraldFlow", "scenery.rainforest.night", "unknown"] {
            expect(LivingThemeScene.scene(for: id) == nil, "pending and retired scenes never select a motion program")
        }
        expect(LivingThemeScene.scene(for: "scenery.ocean.day") == .oceanDay, "Ocean Day registered")
        expect(LivingThemeScene.scene(for: "scenery.ocean.night") == .oceanNight, "Ocean Night registered")
        expect(LivingThemeRegistration.all.count == 12, "exact twelve-scene product registry")
        expect(LivingThemeRegistration.all.filter { $0.motionStatus == .implemented }.count == 3, "only three implemented motion scenes")
        expect(LivingThemeRegistration.all.filter { $0.motionStatus == .pending }.count == 9, "nine explicitly pending")
        expect(Set(LivingThemeRegistration.all.map(\.themeIdentifier)).count == 12, "unique stable scene identity")
        expect(LivingThemeScene.oceanDay.fragmentFunction == LivingThemeScene.oceanNight.fragmentFunction, "Ocean shares physical motion model")
        expect(LivingThemeScene.oceanDay.artworkName != LivingThemeScene.oceanNight.artworkName, "Day and Night are distinct photographs")
        expect(LivingOceanConfiguration.day != .night, "geometry and lighting have explicit variants")
        expect(LivingOceanConfiguration.day.horizon < LivingOceanConfiguration.night.horizon, "observed horizon ordering")
        expect(MemoryLayout<LivingOceanConfiguration>.stride == 32, "Ocean Swift Metal ABI")
        let full = LivingSceneQuality.resolve(reduceMotion: false, lowPower: false, thermal: .nominal, effectsEnabled: true)
        expect(full.framesPerSecond == 30, "bounded full frame rate")
        expect(full.maximumDrawableDimension == 1280, "bounded full drawable")
        let reduced = LivingSceneQuality.resolve(reduceMotion: true, lowPower: false, thermal: .nominal, effectsEnabled: true)
        expect(reduced.framesPerSecond == 15 && reduced.motionAmount == 0.25 && reduced.atmosphereAmount == 0, "Reduce Motion calms primary water and drops secondary effects")
        let still = LivingSceneQuality.resolve(reduceMotion: false, lowPower: false, thermal: .critical, effectsEnabled: true)
        expect(still.framesPerSecond == 0 && still.motionAmount == 0, "critical thermal retains still scene")
        let power = LivingSceneQuality.resolve(reduceMotion: false, lowPower: true, thermal: .nominal, effectsEnabled: true)
        expect(power.framesPerSecond == 20 && power.maximumDrawableDimension == 960 && power.atmosphereAmount == 0, "low power reduces pixels, cadence and secondary systems")
        expect(LivingSceneQuality.resolve(reduceMotion: false, lowPower: false, thermal: .serious, effectsEnabled: true) == power, "serious thermal degrades coherently")
        expect(LivingSceneQuality.resolve(reduceMotion: false, lowPower: false, thermal: .critical, effectsEnabled: true) == still, "critical thermal is static")
        expect(LivingSceneQuality.resolve(reduceMotion: false, lowPower: false, thermal: .nominal, effectsEnabled: false) == still, "no-effects comparison is static")
        for size in [CGSize(width: 393, height: 852), CGSize(width: 852, height: 393), CGSize(width: 1024, height: 1366)] {
            let pixels = full.drawableSize(for: size, scale: 3)
            expect(max(pixels.width, pixels.height) <= 1280, "resolution cap survives rotation/tablet")
            expect(abs(pixels.width / pixels.height - size.width / size.height) < 0.003, "resolution policy preserves aspect")
        }
        expect(full.drawableSize(for: .zero, scale: 3) == .zero, "zero layout cannot allocate drawables")
        expect(full.drawableSize(for: CGSize(width: CGFloat.infinity, height: 300), scale: 3) == .zero, "invalid geometry cannot allocate drawables")
        let portrait = LivingSceneFraming.uvScale(viewport: CGSize(width: 393, height: 852), artwork: CGSize(width: 941, height: 1672))
        expect(portrait.x < 1 && abs(portrait.y - 1) < 0.00001, "portrait crops sides of photograph")
        let landscape = LivingSceneFraming.uvScale(viewport: CGSize(width: 852, height: 393), artwork: CGSize(width: 941, height: 1672))
        expect(abs(landscape.x - 1) < 0.00001 && landscape.y < 1, "landscape crops top/bottom with fixed center")
        expect(MemoryLayout<LivingSceneUniforms>.stride == 32, "Swift/Metal uniform ABI")
        for active in [true, false] {
            for exposed in [true, false] {
                for attached in [true, false] {
                    for applicationActive in [true, false] {
                        for animation in [true, false] {
                            let playback = LivingScenePlayback(isActive: active, isExposed: exposed,
                                allowsAnimation: animation, reduceMotion: false, effectsEnabled: true)
                            let actual = playback.runsContinuously(attached: attached, applicationActive: applicationActive, quality: full)
                            expect(actual == (active && exposed && attached && applicationActive && animation), "every visibility gate independently stops the driver")
                            expect(!playback.runsContinuously(attached: attached, applicationActive: applicationActive, quality: still), "Still never runs the driver")
                        }
                    }
                }
            }
        }
        var clock = LivingSceneClock()
        expect(clock.sample(at: 100) == 0, "unattached scene has no clock work")
        clock.setRunning(true)
        expect(clock.sample(at: 100) == 0, "first active frame establishes epoch")
        expect(abs(clock.sample(at: 100.033) - 0.033) < 0.00001, "active monotonic time advances")
        clock.setRunning(true)
        expect(abs(clock.sample(at: 100.066) - 0.066) < 0.00001, "repeat start cannot reset the clock")
        clock.setRunning(false)
        let frozen = clock.elapsed
        expect(clock.sample(at: 9000) == frozen, "background time is excluded")
        clock.setRunning(false)
        clock.setRunning(true)
        expect(clock.sample(at: 12000) == frozen, "resume has no temporal jump")
        expect(abs(clock.sample(at: 12000.04) - frozen - 0.04) < 0.00001, "resume advances from the retained frame")
        let beforeHitch = clock.elapsed
        expect(abs(clock.sample(at: 12500) - beforeHitch - 0.1) < 0.00001, "long hitch is bounded without catch-up")
        let beforeInvalid = clock.elapsed
        expect(clock.sample(at: .nan) == beforeInvalid, "invalid time is ignored")
        expect(clock.sample(at: 12400) == beforeInvalid, "time cannot move backwards")
        print("PASS: Living Themes V2 \(count) deterministic assertions")
    }
}
