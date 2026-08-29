from __future__ import annotations

import plistlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SWIFT = ROOT / "LifeRoute" / "LifeRouteWebView.swift"
PBX = ROOT / "LifeRoute.xcodeproj" / "project.pbxproj"
PLIST = ROOT / "LifeRoute" / "Info.plist"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f"Could not patch {label}: marker not found")
    return text.replace(old, new, 1)


# WebView bridge actions.
swift = SWIFT.read_text(encoding="utf-8")
swift = replace_once(
    swift,
    '''            case "openPlace":\n                let provider = (body["provider"] as? String) ?? "apple"\n                let query = (body["query"] as? String) ?? ""\n                openPlace(provider: provider, query: query)\n            default:\n''',
    '''            case "openPlace":\n                let provider = (body["provider"] as? String) ?? "apple"\n                let query = (body["query"] as? String) ?? ""\n                openPlace(provider: provider, query: query)\n            case "startLiveDayActivity":\n                if #available(iOS 16.1, *) {\n                    Task {\n                        let payload = await LifeRouteLiveActivityManager.start(from: body)\n                        self.emit(type: "liveActivityStatus", payload: payload)\n                    }\n                } else {\n                    emit(type: "liveActivityStatus", payload: [\n                        "supported": false,\n                        "started": false,\n                        "message": "Live Activities require iOS 16.1 or later."\n                    ])\n                }\n            case "updateLiveDayActivity":\n                if #available(iOS 16.1, *) {\n                    Task {\n                        let payload = await LifeRouteLiveActivityManager.update()\n                        self.emit(type: "liveActivityStatus", payload: payload)\n                    }\n                }\n            case "endLiveDayActivity":\n                if #available(iOS 16.1, *) {\n                    Task {\n                        await LifeRouteLiveActivityManager.endAll(dismissImmediately: true)\n                        self.emit(type: "liveActivityStatus", payload: [\n                            "supported": true,\n                            "ended": true\n                        ])\n                    }\n                }\n            default:\n''',
    "Live Activity message bridge",
)
SWIFT.write_text(swift, encoding="utf-8")

# Host app declaration required by ActivityKit.
with PLIST.open("rb") as handle:
    plist = plistlib.load(handle)
plist["NSSupportsLiveActivities"] = True
with PLIST.open("wb") as handle:
    plistlib.dump(plist, handle, sort_keys=False)

# Xcode target + shared source membership. Keep this text patch deterministic so
# the repository remains hand-readable and every build starts from the same base.
pbx = PBX.read_text(encoding="utf-8")
if "LifeRouteLiveActivity.appex" not in pbx:
    pbx = replace_once(
        pbx,
        "/* End PBXBuildFile section */",
        '''\t\tC10000000000000000000001 /* LiveActivityManager.swift in Sources */ = {isa = PBXBuildFile; fileRef = C20000000000000000000001 /* LiveActivityManager.swift */; };\n\t\tC10000000000000000000002 /* LifeRouteActivityAttributes.swift in Sources */ = {isa = PBXBuildFile; fileRef = C20000000000000000000002 /* LifeRouteActivityAttributes.swift */; };\n\t\tC10000000000000000000003 /* LifeRouteActivityAttributes.swift in Sources */ = {isa = PBXBuildFile; fileRef = C20000000000000000000002 /* LifeRouteActivityAttributes.swift */; };\n\t\tC10000000000000000000004 /* LifeRouteLiveActivityWidget.swift in Sources */ = {isa = PBXBuildFile; fileRef = C20000000000000000000003 /* LifeRouteLiveActivityWidget.swift */; };\n\t\tC10000000000000000000005 /* LifeRouteLiveActivity.appex in Embed App Extensions */ = {isa = PBXBuildFile; fileRef = C20000000000000000000005 /* LifeRouteLiveActivity.appex */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };\n/* End PBXBuildFile section */''',
        "Live Activity build files",
    )
    pbx = replace_once(
        pbx,
        "/* End PBXFileReference section */",
        '''\t\tC20000000000000000000001 /* LiveActivityManager.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = LiveActivityManager.swift; sourceTree = "<group>"; };\n\t\tC20000000000000000000002 /* LifeRouteActivityAttributes.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = LifeRouteActivityAttributes.swift; sourceTree = "<group>"; };\n\t\tC20000000000000000000003 /* LifeRouteLiveActivityWidget.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = LifeRouteLiveActivityWidget.swift; sourceTree = "<group>"; };\n\t\tC20000000000000000000004 /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };\n\t\tC20000000000000000000005 /* LifeRouteLiveActivity.appex */ = {isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = LifeRouteLiveActivity.appex; sourceTree = BUILT_PRODUCTS_DIR; };\n/* End PBXFileReference section */''',
        "Live Activity file references",
    )
    pbx = replace_once(
        pbx,
        "/* End PBXFrameworksBuildPhase section */",
        '''\t\tC30000000000000000000001 /* Frameworks */ = {\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = ();\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n/* End PBXFrameworksBuildPhase section */''',
        "Live Activity frameworks phase",
    )
    pbx = replace_once(
        pbx,
        '''\t\tA40000000000000000000001 = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\tA40000000000000000000002 /* LifeRoute */,\n\t\t\t\tA40000000000000000000003 /* Products */,\n\t\t\t);''',
        '''\t\tA40000000000000000000001 = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\tA40000000000000000000002 /* LifeRoute */,\n\t\t\t\tC40000000000000000000001 /* LifeRouteShared */,\n\t\t\t\tC40000000000000000000002 /* LifeRouteLiveActivity */,\n\t\t\t\tA40000000000000000000003 /* Products */,\n\t\t\t);''',
        "root groups",
    )
    pbx = replace_once(
        pbx,
        '''\t\t\t\tA20000000000000000000003 /* LifeRouteWebView.swift */,\n\t\t\t\tA20000000000000000000004 /* Assets.xcassets */,''',
        '''\t\t\t\tA20000000000000000000003 /* LifeRouteWebView.swift */,\n\t\t\t\tC20000000000000000000001 /* LiveActivityManager.swift */,\n\t\t\t\tA20000000000000000000004 /* Assets.xcassets */,''',
        "app group manager",
    )
    pbx = replace_once(
        pbx,
        '''\t\t\tchildren = (\n\t\t\t\tA20000000000000000000007 /* LifeRoute.app */,\n\t\t\t);\n\t\t\tname = Products;''',
        '''\t\t\tchildren = (\n\t\t\t\tA20000000000000000000007 /* LifeRoute.app */,\n\t\t\t\tC20000000000000000000005 /* LifeRouteLiveActivity.appex */,\n\t\t\t);\n\t\t\tname = Products;''',
        "extension product",
    )
    pbx = replace_once(
        pbx,
        "/* End PBXGroup section */",
        '''\t\tC40000000000000000000001 /* LifeRouteShared */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\tC20000000000000000000002 /* LifeRouteActivityAttributes.swift */,\n\t\t\t);\n\t\t\tpath = LifeRouteShared;\n\t\t\tsourceTree = "<group>";\n\t\t};\n\t\tC40000000000000000000002 /* LifeRouteLiveActivity */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\tC20000000000000000000003 /* LifeRouteLiveActivityWidget.swift */,\n\t\t\t\tC20000000000000000000004 /* Info.plist */,\n\t\t\t);\n\t\t\tpath = LifeRouteLiveActivity;\n\t\t\tsourceTree = "<group>";\n\t\t};\n/* End PBXGroup section */''',
        "extension groups",
    )
    pbx = replace_once(
        pbx,
        '''\t\t\tbuildPhases = (\n\t\t\t\tA60000000000000000000001 /* Sources */,\n\t\t\t\tA30000000000000000000001 /* Frameworks */,\n\t\t\t\tA60000000000000000000002 /* Resources */,\n\t\t\t);\n\t\t\tbuildRules = ();\n\t\t\tdependencies = ();''',
        '''\t\t\tbuildPhases = (\n\t\t\t\tA60000000000000000000001 /* Sources */,\n\t\t\t\tA30000000000000000000001 /* Frameworks */,\n\t\t\t\tA60000000000000000000002 /* Resources */,\n\t\t\t\tC60000000000000000000003 /* Embed App Extensions */,\n\t\t\t);\n\t\t\tbuildRules = ();\n\t\t\tdependencies = (\n\t\t\t\tC80000000000000000000002 /* PBXTargetDependency */,\n\t\t\t);''',
        "host embeds Live Activity extension",
    )
    pbx = replace_once(
        pbx,
        "/* End PBXNativeTarget section */",
        '''\t\tC50000000000000000000001 /* LifeRouteLiveActivity */ = {\n\t\t\tisa = PBXNativeTarget;\n\t\t\tbuildConfigurationList = C90000000000000000000001 /* Build configuration list for PBXNativeTarget "LifeRouteLiveActivity" */;\n\t\t\tbuildPhases = (\n\t\t\t\tC60000000000000000000001 /* Sources */,\n\t\t\t\tC30000000000000000000001 /* Frameworks */,\n\t\t\t\tC60000000000000000000002 /* Resources */,\n\t\t\t);\n\t\t\tbuildRules = ();\n\t\t\tdependencies = ();\n\t\t\tname = LifeRouteLiveActivity;\n\t\t\tproductName = LifeRouteLiveActivity;\n\t\t\tproductReference = C20000000000000000000005 /* LifeRouteLiveActivity.appex */;\n\t\t\tproductType = "com.apple.product-type.app-extension";\n\t\t};\n/* End PBXNativeTarget section */''',
        "Live Activity native target",
    )
    pbx = replace_once(
        pbx,
        '''\t\t\t\tTargetAttributes = {\n\t\t\t\t\tA50000000000000000000001 = {\n\t\t\t\t\t\tCreatedOnToolsVersion = 26.6;\n\t\t\t\t\t};\n\t\t\t\t};''',
        '''\t\t\t\tTargetAttributes = {\n\t\t\t\t\tA50000000000000000000001 = {\n\t\t\t\t\t\tCreatedOnToolsVersion = 26.6;\n\t\t\t\t\t};\n\t\t\t\t\tC50000000000000000000001 = {\n\t\t\t\t\t\tCreatedOnToolsVersion = 26.6;\n\t\t\t\t\t};\n\t\t\t\t};''',
        "target attributes",
    )
    pbx = replace_once(
        pbx,
        '''\t\t\ttargets = (A50000000000000000000001 /* LifeRoute */);''',
        '''\t\t\ttargets = (\n\t\t\t\tA50000000000000000000001 /* LifeRoute */,\n\t\t\t\tC50000000000000000000001 /* LifeRouteLiveActivity */,\n\t\t\t);''',
        "project target list",
    )
    pbx = replace_once(
        pbx,
        "/* End PBXResourcesBuildPhase section */",
        '''\t\tC60000000000000000000002 /* Resources */ = {\n\t\t\tisa = PBXResourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = ();\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n/* End PBXResourcesBuildPhase section */''',
        "extension resources phase",
    )
    pbx = replace_once(
        pbx,
        '''\t\t\tfiles = (\n\t\t\t\tA10000000000000000000001 /* LifeRouteApp.swift in Sources */,\n\t\t\t\tA10000000000000000000002 /* ContentView.swift in Sources */,\n\t\t\t\tA10000000000000000000003 /* LifeRouteWebView.swift in Sources */,\n\t\t\t);''',
        '''\t\t\tfiles = (\n\t\t\t\tA10000000000000000000001 /* LifeRouteApp.swift in Sources */,\n\t\t\t\tA10000000000000000000002 /* ContentView.swift in Sources */,\n\t\t\t\tA10000000000000000000003 /* LifeRouteWebView.swift in Sources */,\n\t\t\t\tC10000000000000000000001 /* LiveActivityManager.swift in Sources */,\n\t\t\t\tC10000000000000000000002 /* LifeRouteActivityAttributes.swift in Sources */,\n\t\t\t);''',
        "host Live Activity sources",
    )
    pbx = replace_once(
        pbx,
        "/* End PBXSourcesBuildPhase section */",
        '''\t\tC60000000000000000000001 /* Sources */ = {\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t\tC10000000000000000000003 /* LifeRouteActivityAttributes.swift in Sources */,\n\t\t\t\tC10000000000000000000004 /* LifeRouteLiveActivityWidget.swift in Sources */,\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n/* End PBXSourcesBuildPhase section */''',
        "extension sources phase",
    )
    # Copy-files phase and target dependency proxy live in their own sections.
    insert_before = "/* Begin PBXFrameworksBuildPhase section */"
    extra_sections = '''/* Begin PBXCopyFilesBuildPhase section */\n\t\tC60000000000000000000003 /* Embed App Extensions */ = {\n\t\t\tisa = PBXCopyFilesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tdstPath = "";\n\t\t\tdstSubfolderSpec = 13;\n\t\t\tfiles = (\n\t\t\t\tC10000000000000000000005 /* LifeRouteLiveActivity.appex in Embed App Extensions */,\n\t\t\t);\n\t\t\tname = "Embed App Extensions";\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n/* End PBXCopyFilesBuildPhase section */\n\n/* Begin PBXContainerItemProxy section */\n\t\tC80000000000000000000001 /* PBXContainerItemProxy */ = {\n\t\t\tisa = PBXContainerItemProxy;\n\t\t\tcontainerPortal = A70000000000000000000001 /* Project object */;\n\t\t\tproxyType = 1;\n\t\t\tremoteGlobalIDString = C50000000000000000000001;\n\t\t\tremoteInfo = LifeRouteLiveActivity;\n\t\t};\n/* End PBXContainerItemProxy section */\n\n'''
    if extra_sections not in pbx:
        pbx = pbx.replace(insert_before, extra_sections + insert_before, 1)

    target_dep = '''/* Begin PBXTargetDependency section */\n\t\tC80000000000000000000002 /* PBXTargetDependency */ = {\n\t\t\tisa = PBXTargetDependency;\n\t\t\ttarget = C50000000000000000000001 /* LifeRouteLiveActivity */;\n\t\t\ttargetProxy = C80000000000000000000001 /* PBXContainerItemProxy */;\n\t\t};\n/* End PBXTargetDependency section */\n\n'''
    pbx = pbx.replace("/* Begin XCBuildConfiguration section */", target_dep + "/* Begin XCBuildConfiguration section */", 1)

    pbx = replace_once(
        pbx,
        "/* End XCBuildConfiguration section */",
        '''\t\tC10000000000000000000011 /* Debug */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {\n\t\t\t\tAPPLICATION_EXTENSION_API_ONLY = YES;\n\t\t\t\tCODE_SIGN_STYLE = Automatic;\n\t\t\t\tCURRENT_PROJECT_VERSION = 2;\n\t\t\t\tDEVELOPMENT_TEAM = "";\n\t\t\t\tGENERATE_INFOPLIST_FILE = NO;\n\t\t\t\tINFOPLIST_FILE = LifeRouteLiveActivity/Info.plist;\n\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.1;\n\t\t\t\tLD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks";\n\t\t\t\tMARKETING_VERSION = 0.3.0;\n\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = Com.Brandongood.LifeRoute.LiveActivity;\n\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";\n\t\t\t\tSKIP_INSTALL = YES;\n\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";\n\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;\n\t\t\t\tSWIFT_VERSION = 5.0;\n\t\t\t\tTARGETED_DEVICE_FAMILY = 1;\n\t\t\t};\n\t\t\tname = Debug;\n\t\t};\n\t\tC10000000000000000000012 /* Release */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {\n\t\t\t\tAPPLICATION_EXTENSION_API_ONLY = YES;\n\t\t\t\tCODE_SIGN_STYLE = Automatic;\n\t\t\t\tCURRENT_PROJECT_VERSION = 2;\n\t\t\t\tDEVELOPMENT_TEAM = "";\n\t\t\t\tGENERATE_INFOPLIST_FILE = NO;\n\t\t\t\tINFOPLIST_FILE = LifeRouteLiveActivity/Info.plist;\n\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.1;\n\t\t\t\tLD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks";\n\t\t\t\tMARKETING_VERSION = 0.3.0;\n\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = Com.Brandongood.LifeRoute.LiveActivity;\n\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";\n\t\t\t\tSKIP_INSTALL = YES;\n\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";\n\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;\n\t\t\t\tSWIFT_VERSION = 5.0;\n\t\t\t\tTARGETED_DEVICE_FAMILY = 1;\n\t\t\t};\n\t\t\tname = Release;\n\t\t};\n/* End XCBuildConfiguration section */''',
        "extension build configurations",
    )
    pbx = replace_once(
        pbx,
        "/* End XCConfigurationList section */",
        '''\t\tC90000000000000000000001 /* Build configuration list for PBXNativeTarget "LifeRouteLiveActivity" */ = {\n\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n\t\t\t\tC10000000000000000000011 /* Debug */,\n\t\t\t\tC10000000000000000000012 /* Release */,\n\t\t\t);\n\t\t\tdefaultConfigurationIsVisible = 0;\n\t\t\tdefaultConfigurationName = Release;\n\t\t};\n/* End XCConfigurationList section */''',
        "extension configuration list",
    )

PBX.write_text(pbx, encoding="utf-8")
print("LifeRoute Live Activity bridge and Xcode extension target ready.")
