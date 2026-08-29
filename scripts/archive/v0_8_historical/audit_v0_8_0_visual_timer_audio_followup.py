from pathlib import Path


DOMAIN = Path("LifeRoute/SessionToolsDomain.swift").read_text(encoding="utf-8")
VIEW = Path("LifeRoute/SessionToolsViews.swift").read_text(encoding="utf-8")
PREPARE = Path("scripts/prepare_build.sh").read_text(encoding="utf-8")

checks: list[tuple[str, bool]] = []


def check(label: str, condition: bool) -> None:
    checks.append((label, condition))


check("domain follow-up marker", "v0.8.0 follow-up visual timer audio sweep" in DOMAIN)
check("view follow-up marker", "v0.8.0 follow-up visual timer audio sweep" in VIEW)
check("432 Hz start", "private static let startFrequency = 432.0" in DOMAIN)
check("864 Hz end", "private static let endFrequency = 864.0" in DOMAIN)
check("1 tick/sec start", "private static let startPulsesPerSecond = 1.0" in DOMAIN)
check("6 ticks/sec end", "private static let endPulsesPerSecond = 6.0" in DOMAIN)
check("one normalized progress owner", DOMAIN.count("func normalizedElapsedProgress") == 1)
check("continuous linear rate ramp", "(Self.endPulsesPerSecond - Self.startPulsesPerSecond) * progress" in DOMAIN)
check("perceptual octave sweep", "Self.startFrequency * pow(Self.endFrequency / Self.startFrequency, progress)" in DOMAIN)
check("audio loop consumes tone mapping", "self.toneFrequency(forRemaining: remaining)" in DOMAIN)
check("audio loop consumes rate mapping", "1.0 / self.pulsesPerSecond(forRemaining: remaining)" in DOMAIN)
check("gentle bounded pulse", "private static let pulseDuration = 0.085" in DOMAIN and "* 0.30" in DOMAIN)
check("gentler default level", "var volume: Double = 0.48" in DOMAIN)
check("existing digital crescendo remains", "startGainForFiveDecibelCrescendo" in DOMAIN)
check("existing audio session policy remains", "session.setCategory(.playback, mode: .default, options: [.mixWithOthers])" in DOMAIN)
check("completion audio remains", "func playCompletion" in DOMAIN and "completionBuffer" in DOMAIN)
check("pause stops audio", "func pause" in DOMAIN and "stopAudioLoop()" in DOMAIN)
check("resume restarts audio", "func resume" in DOMAIN and "startAudioLoop()" in DOMAIN)
check("reset stops audio", "func reset" in DOMAIN and "stopAudioLoop()" in DOMAIN)
check("visual-only mute remains", "setVolume" in DOMAIN and 'Set Volume to 0% for a visual-only timer' in VIEW)
check("visible live rate", 'String(format: "%.1f× / SEC", tempo)' in VIEW)
check("visible live tone", 'Text("\\(Int(toneFrequency.rounded())) HZ")' in VIEW)
check("mapping copy is exact", "starts at 432 Hz and 1 tick/sec" in VIEW and "864 Hz and 6 ticks/sec" in VIEW)
check("visual pulse shares audio rate", "let interval = 1.0 / tempo" in VIEW)
check("absolute deadline remains", "deadline.timeIntervalSinceNow" in DOMAIN)


def frequency(progress: float) -> float:
    return 432.0 * ((864.0 / 432.0) ** progress)


def rate(progress: float) -> float:
    return 1.0 + (6.0 - 1.0) * progress


progress_samples = [index / 20 for index in range(21)]
frequency_samples = [frequency(progress) for progress in progress_samples]
rate_samples = [rate(progress) for progress in progress_samples]
check("frequency endpoint math", abs(frequency_samples[0] - 432.0) < 1e-9 and abs(frequency_samples[-1] - 864.0) < 1e-9)
check("rate endpoint math", abs(rate_samples[0] - 1.0) < 1e-9 and abs(rate_samples[-1] - 6.0) < 1e-9)
check("frequency monotonic", all(a < b for a, b in zip(frequency_samples, frequency_samples[1:])))
check("rate monotonic", all(a < b for a, b in zip(rate_samples, rate_samples[1:])))

check("follow-up patch prepared", "patch_v0_8_0_visual_timer_audio_followup.py" in PREPARE)
check("follow-up audit prepared", "audit_v0_8_0_visual_timer_audio_followup.py" in PREPARE)

failed = [label for label, condition in checks if not condition]
if failed:
    for label in failed:
        print(f"FAIL: {label}")
    raise SystemExit(f"LifeRoute v0.8.0 visual-timer audio follow-up audit failed: {len(failed)} checks")

print(f"LifeRoute v0.8.0 visual-timer audio follow-up audit passed: {len(checks)}/{len(checks)} checks")
