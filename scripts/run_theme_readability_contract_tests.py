#!/usr/bin/env python3
"""Run current theme/migration and resolved-color contracts without an Xcode project change.

Like the existing presentation harness, this extracts production declarations.
The frozen expected mapping was recorded from the complete final-prose donor.
Color-pair checks do not certify composited native glass or physical appearance.
"""
from pathlib import Path
import json
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
app = (ROOT / 'LifeRoute/LifeRouteApp.swift').read_text()

def block(text, marker):
    start = text.index(marker)
    pos = text.index('{', start)
    depth, end = 1, pos + 1
    while depth:
        if text[end] == '{': depth += 1
        elif text[end] == '}': depth -= 1
        end += 1
    return text[start:end]

source = app.split('final class LifeRouteThemeStore:', 1)[0].replace('import UIKit', '')
source += '\nextension LifeRouteTheme {\n'
for name in ['v071RetainedDynamicCatalog', 'v071RetainedSceneryCatalog']:
    start = app.index('    static let ' + name)
    end = app.index('\n\n', start)
    source += app[start:end] + '\n'
for marker in ['var isV071RetainedDynamic:', 'var isV071RetainedScenery:', 'var scenerySceneID:']:
    source += block(app, marker) + '\n'
source += '}\nenum ResolutionProbe {\n'
for marker in ['private static func shippingTheme', 'private static func resolveStoredTheme']:
    source += block(app, marker).replace('private static', 'static') + '\n'
source += '}\n'
for name in ['ScenicRoyalThemeBridge.swift', 'ScenicRoyalDesignSystem.swift', 'SceneryEffectContracts.swift']:
    source += (ROOT / 'LifeRoute' / name).read_text() + '\n'
source += '\n' + block((ROOT / 'LifeRoute/ScenicRoyalThemeComponents.swift').read_text(), 'enum ScenicRoyalThemeCategory:')
source += '\nextension LifeRouteTheme {\n'
components = (ROOT / 'LifeRoute/ScenicRoyalThemeComponents.swift').read_text()
for marker in ['var thumbnailAssetName:', 'var sceneryThumbnailAssetName:', 'var isNightScenery:']:
    source += block(components, marker) + '\n'
source += '}\n'

harness = r'''
import SwiftUI
import Foundation
@main struct ThemeContracts {
 @MainActor static func main() throws {
  var count = 0
  func expect(_ value: Bool, _ reason: String) { count += 1; if !value { fatalError(reason) } }
  func rgba(_ color: Color) -> [Double] {
   let c = color.resolve(in: EnvironmentValues())
   return [Double(c.red), Double(c.green), Double(c.blue), Double(c.opacity)]
  }
  func composite(_ a: [Double], _ b: [Double]) -> [Double] {
   (0..<3).map { a[$0] * a[3] + b[$0] * (1-a[3]) } + [1]
  }
  func lum(_ c: [Double]) -> Double {
   zip(c.prefix(3), [0.2126,0.7152,0.0722]).map { v,w in
    w * (v <= 0.04045 ? v/12.92 : pow((v+0.055)/1.055,2.4))
   }.reduce(0,+)
  }
  func ratio(_ a: [Double], _ b: [Double]) -> Double {
   (max(lum(a),lum(b))+0.05)/(min(lum(a),lum(b))+0.05)
  }
  let expected = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))) as! [String:Any]
  let core = LifeRouteTheme.phaseOneCoreGlassCatalog
  let dynamic = LifeRouteTheme.phaseTwoDynamicCatalog
  let scenery = LifeRouteTheme.phaseThreeSceneryCatalog
  let visible = core + LifeRouteTheme.visibleDynamicCatalog
  expect(LifeRouteTheme.allCases.count == 72, "Persistent ID inventory changed")
  expect(ScenicRoyalThemeCategory.allCases.map(\.rawValue) == ["CORE","DYNAMIC"], "Only two visible categories")
  expect(core.count == 12 && LifeRouteTheme.visibleDynamicCatalog.count == 20, "12 CORE / 20 DYNAMIC")
  expect(Set(visible).count == 32, "Unique complete catalog")
  expect(core.map(\.rawValue) == expected["core"] as! [String], "Core identities/order")
  expect(dynamic.map(\.rawValue) == expected["dynamic"] as! [String], "Dynamic renderer cohort")
  expect(scenery.map(\.rawValue) == expected["scenery"] as! [String], "Scenery renderer cohort")
  expect(LifeRouteTheme.visibleDynamicCatalog == dynamic + scenery, "Merged visible order")
  expect(LifeRouteTheme.v071RetainedDynamicCatalog == dynamic, "Retained Dynamic alias")
  expect(LifeRouteTheme.v071RetainedSceneryCatalog == scenery, "Retained Scenery alias")
  expect(!LifeRouteTheme.arctic.scenicRoyalStyle.isBrightEnvironment, "Core Arctic native dark background requires light copy")
  for record in expected["mapping"] as! [[String:String]] {
   let raw = record["input"]!
   let resolved = ResolutionProbe.shippingTheme(ResolutionProbe.resolveStoredTheme(raw == "<nil>" ? nil : raw))
   expect(resolved.rawValue == record["output"], "Migration changed for \(raw)")
   expect(visible.contains(resolved), "Migration left shipping catalog: \(raw)")
  }
  // Exercise real UserDefaults round-trips in an isolated suite, never the app's store.
  let suite = "LifeRoute.ThemeContracts.\(UUID().uuidString)"
  let preferences = UserDefaults(suiteName: suite)!
  defer { preferences.removePersistentDomain(forName: suite) }
  var observations: [[String:Any]] = []
  for theme in visible {
   let style = theme.scenicRoyalStyle
   let old = (expected["rows"] as! [[String:Any]]).first { $0["id"] as? String == theme.rawValue }!
   expect(theme.isPhaseTwoDynamic == old["dynamic"] as! Bool, "Dynamic dispatch \(theme)")
   expect(theme.isPhaseThreeScenery == old["scenery"] as! Bool, "Scenery dispatch \(theme)")
   expect((theme.scenerySceneID?.rawValue ?? "") == (old["scene"] as? String ?? ""), "Scene/effect profile \(theme)")
   expect(theme.scenicRoyalDynamicSceneryTheme.rawValue == old["companion"] as! String, "Companion scenery \(theme)")
   expect(theme.isNightScenery == (theme.isPhaseThreeScenery && theme.rawValue.hasSuffix(".night")), "Explicit day/night intent")
   for (name,color) in [("backgroundTop",theme.palette.backgroundTop),("backgroundBottom",theme.palette.backgroundBottom),("panel",theme.palette.panel),("accent",theme.palette.accent)] {
    expect(zip(rgba(color),old[name] as! [Double]).allSatisfy { abs($0-$1) < 0.00001 }, "Palette changed \(theme) \(name)")
   }
   preferences.set(theme.rawValue, forKey: "liferoute.selectedTheme")
   let restored = ResolutionProbe.shippingTheme(ResolutionProbe.resolveStoredTheme(preferences.string(forKey: "liferoute.selectedTheme")))
   expect(restored == theme, "Selected theme restoration \(theme)")
   expect(style.nativeColorScheme == (style.isBrightEnvironment ? ColorScheme.light : .dark), "Native material/foreground appearance disagree")
   expect(rgba(style.contentPalette.textPrimary) == rgba(style.contentPrimaryForeground), "Primary palette compatibility owner")
   expect(rgba(style.contentPalette.textSecondary) == rgba(style.contentSecondaryForeground), "Secondary palette compatibility owner")
   expect(rgba(style.contentPalette.accent) == rgba(theme.palette.accent), "Decorative accent projection changed")
   expect(rgba(style.nativeBarFill) == rgba(style.isBrightEnvironment ? Color.white : theme.palette.backgroundTop), "Preserve native night bar fill")
   expect(rgba(style.nativeSegmentedFill) == rgba(style.isBrightEnvironment ? Color.white : theme.palette.panel), "Preserve native night segmented fill")
   let selectedFill = rgba(style.selectedControlFill)
   var minimum = 100.0
   for background in [[0.0,0,0,1], [1.0,1,1,1], rgba(theme.palette.backgroundBottom)] {
    let selected = composite(selectedFill, background)
    let text = composite(rgba(style.selectedControlForeground), selected)
    expect(ratio(text,selected) >= 4.5, "Selected base foreground/fill \(theme)")
    for opacity in [0.90,0.98] { // Increase Contrast / Reduce Transparency actual opacity branches.
     var fill = rgba(style.accessibleSurfaceFill); fill[3] = opacity
     let surface = composite(fill, background)
     for foreground in [style.contentPrimaryForeground,style.contentSecondaryForeground] {
      let value = ratio(composite(rgba(foreground),surface),surface)
      minimum = min(minimum,value)
      expect(value >= 4.5, "Accessibility foreground/surface \(theme) at \(opacity): \(value)")
     }
    }
   }
   let panel = rgba(theme.palette.panelElevated)
   expect(ratio(composite(rgba(style.filledPanelForeground),panel),panel) >= 4.5, "Legacy filled panel label \(theme)")
   expect(ratio(rgba(ScenicRoyalDesignSystem.ColorToken.brandNavyDeep),rgba(style.accent)) >= 4.5, "Primary gradient / route badge accent endpoint \(theme)")
   let tintSurface = rgba(style.accessibleSurfaceFill)
   expect(ratio(composite(rgba(style.nativeControlTint),tintSurface),tintSurface) >= 3, "Functional control/focus tint \(theme)")
   observations.append(["id":theme.rawValue,"bright":style.isBrightEnvironment,"minimumAccessiblePairRatio":minimum,"thumbnail":theme.thumbnailAssetName])
  }
  let data = try JSONSerialization.data(withJSONObject:["assertions":count,"observations":observations],options:[.prettyPrinted,.sortedKeys])
  try data.write(to: URL(fileURLWithPath:CommandLine.arguments[2]))
  print("Theme readability/catalog contracts: \(count) assertions passed; 32 visible identities; 72 raw IDs plus nil/unknown/empty/whitespace inputs. Resolved-color evidence is not composited-glass acceptance.")
 }
}
'''
cache = Path(os.environ.get('LIFEROUTE_CONTRACT_CACHE_DIRECTORY', tempfile.gettempdir()))
cache.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='theme-contracts-', dir=cache) as directory:
    path = Path(directory)
    (path / 'Production.swift').write_text(source)
    (path / 'Contracts.swift').write_text(harness)
    subprocess.run(['xcrun','swiftc','-parse-as-library',str(path/'Production.swift'),str(path/'Contracts.swift'),'-o',str(path/'contracts')],check=True,cwd=ROOT)
    output = Path(os.environ.get('LIFEROUTE_THEME_CONTRACT_OUTPUT', str(cache/'theme-contract-observations.json')))
    subprocess.run([str(path/'contracts'),str(ROOT/'scripts/theme_catalog_expected.json'),str(output)],check=True,cwd=ROOT)

# Verify state/appearance wiring where ButtonStyle.Configuration is framework-owned.
components = (ROOT/'LifeRoute/ScenicRoyalComponents.swift').read_text()
secondary = block(components, 'struct ScenicRoyalSecondaryButtonStyle:')
assert r'@Environment(\.isEnabled)' in secondary
assert '.opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.46)' in secondary
assert 'configuration.isPressed && !reduceMotion' in secondary
assert '.tint(style.nativeControlTint)' in (ROOT/'LifeRoute/ScenicRoyalEnvironment.swift').read_text()
assert 'surfaceShape.fill(style.accessibleSurfaceFill.opacity(accessibleSurfaceOpacity))' in (ROOT/'LifeRoute/ScenicRoyalMaterials.swift').read_text()
print('Secondary enabled/disabled/pressed/Reduce Motion and shared appearance wiring passed; native focused/disabled appearance remains a capture gate.')
