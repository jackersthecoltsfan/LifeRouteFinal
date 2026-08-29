#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "LifeRoute/V054ThemeCenterView.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.7.0 Build E theme compatibility failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def main() -> None:
    text = PATH.read_text(encoding="utf-8")
    marker = "v0.7.0 Build E validated theme catalog compatibility"
    if marker in text:
        return

    if "v0.7.0 Build E Theme Center" not in text:
        raise SystemExit("v0.7.0 Build E theme compatibility failed: Build E Theme Center marker missing")

    catalog = r'''    // v0.7.0 Build E validated theme catalog compatibility: retain the reviewed v0.6.3
    // Core ordering and the v0.6.2 Dynamic/Scenery catalogs while changing presentation only.
    private let coreThemes: [LifeRouteTheme] = [.royal, .cobaltShine, .golden, .sunflare, .noir, .kaleidoscope, .light, .dark, .classic, .accessible]
    private let dynamicThemes: [LifeRouteTheme] = [.solarFlare, .electricStorm, .ultraviolet, .arcticPulse, .aurora, .sapphireTide]
    private let sceneryThemes: [LifeRouteTheme] = [.mountain, .ocean, .space, .desert, .forest, .sunshine]

'''
    text = replace_once(
        text,
        "    private let columns = [\n",
        catalog + "    private let columns = [\n",
        "curated theme catalogs",
    )

    old_filtered = '''    private var filteredThemes: [LifeRouteTheme] {
        LifeRouteTheme.allCases.filter(selectedCategory.matches)
    }
'''
    new_filtered = '''    private var filteredThemes: [LifeRouteTheme] {
        switch selectedCategory {
        case .all:
            let curated = coreThemes + dynamicThemes + sceneryThemes
            return curated.filter { LifeRouteTheme.allCases.contains($0) }
        case .core:
            return coreThemes
        case .dynamic:
            return dynamicThemes
        case .scenery:
            return sceneryThemes
        }
    }
'''
    text = replace_once(text, old_filtered, new_filtered, "filtered theme catalog")

    PATH.write_text(text, encoding="utf-8")
    print("LifeRoute v0.7.0 Build E theme compatibility applied: validated Core/Dynamic/Scenery theme catalogs preserved inside the compact browser.")


if __name__ == "__main__":
    main()
