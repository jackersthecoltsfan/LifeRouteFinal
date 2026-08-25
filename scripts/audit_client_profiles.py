from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROFILES = (ROOT / "LifeRoute/Web/client-profiles-v1.js").read_text()
TOOLS = (ROOT / "LifeRoute/Web/client-profile-tools-v1.js").read_text()
PREPARE = (ROOT / "scripts/prepare_build.sh").read_text()
INDEX = (ROOT / "LifeRoute/Web/index.html").read_text()

checks = []

def check(label, condition):
    checks.append((bool(condition), label))

# Setup owns one rich profile editor, preserving ABA code/address compatibility.
for marker in [
    "clientProfileEditor",
    "clientPreferredActivities",
    "clientCurrentTargets",
    "clientBehaviorsOfConcern",
    "clientCommunicationNotes",
    "clientPromptingNotes",
    "clientCaregiverNotes",
    "clientClinicalNotes",
    "saveClientButton",
    "clientCodePreview",
]:
    check(f"profile editor contains {marker}", marker in PROFILES)

check("profiles retain first two initials", "first2: formatPair" in PROFILES)
check("profiles retain last two initials", "last2: formatPair" in PROFILES)
check("profiles retain route address", "address: clean(client?.address)" in PROFILES)
check("preferred activities stored as normalized list", "preferredActivities: listFrom" in PROFILES)
check("current targets stored as normalized list", "currentTargets: listFrom" in PROFILES)
check("behaviors stored as normalized list", "behaviorsOfConcern: listFrom" in PROFILES)
check("profile updates preserve unknown existing client fields", "...previous" in PROFILES)
check("duplicate client codes are blocked", "is already saved as another client" in PROFILES)
check("profile save triggers route client reconciliation", "applyLifeRouteClientLocations" in PROFILES)
check("profile save triggers client selector sync", "refreshLifeRouteToolClients" in PROFILES)
check("profile changes dispatch shared event", 'CustomEvent("liferoute:clients-changed"' in PROFILES)
check("profile screen edits existing clients", "data-edit-client" in PROFILES and "fillEditor" in PROFILES)
check("profile remove requires confirmation", "window.confirm" in PROFILES and "data-remove-client" in PROFILES)

# Privacy/local-first: rich client fields must not gain a network path. The UI must
# warn that local storage alone is not a HIPAA guarantee and that direct PHI should
# not be entered. Service location remains the only profile value handed to route
# reconciliation, while all rich profile fields stay local to session tools.
check("profile module uses production local state store", 'const STORE = "liferoute_v3"' in PROFILES)
check("profile module has no fetch", "fetch(" not in PROFILES)
check("profile module has no remote URL", "https://" not in PROFILES and "http://" not in PROFILES)
check(
    "profile privacy copy warns against PHI and explains local-storage limitation",
    "Do not enter PHI or direct identifiers" in PROFILES
    and "Local storage does not by itself guarantee HIPAA compliance" in PROFILES,
)
check(
    "service-location route boundary remains explicit",
    "Service location" in PROFILES
    and "address: clean(client?.address)" in PROFILES
    and "applyLifeRouteClientLocations" in PROFILES
    and "fetch(" not in PROFILES,
)

# Session plan builder consumes the same client profile safely.
check("tool bridge reads saved profile module", "LifeRouteClientProfilesV1" in TOOLS)
check("tool bridge falls back to prefs clients", "Array.isArray(prefs.clients)" in TOOLS)
check("tool bridge falls back to local persistence", "saved?.prefs?.clients" in TOOLS)
check("selecting client autofills targets", "sessionPlanTargets" in TOOLS and "currentTargets" in TOOLS)
check("selecting client autofills preferred activities", "sessionPlanReinforcers" in TOOLS and "preferredActivities" in TOOLS)
check("manual field edits stop profile overwrites", "event.isTrusted" in TOOLS and 'profileAutofill = "0"' in TOOLS)
check("profile context summarizes saved data", "sessionPlanClientContext" in TOOLS and "sessionPlanProfileStats" in TOOLS)
check("tool bridge has no network access", "fetch(" not in TOOLS and "https://" not in TOOLS)

# Shared native/web startup wiring.
check("prepare includes client profiles", '"client-profiles-v1.js"' in PREPARE)
check("prepare includes client profile tools", '"client-profile-tools-v1.js"' in PREPARE)
check("prepared HTML loads client profiles", '<script src="client-profiles-v1.js"></script>' in INDEX)
check("prepared HTML loads client profile tools", '<script src="client-profile-tools-v1.js"></script>' in INDEX)
check("profile screen loads after smart context", INDEX.find('client-profiles-v1.js') > INDEX.find('smart-context.js') >= 0)
check("profile tool bridge loads after RBT tools", INDEX.find('client-profile-tools-v1.js') > INDEX.find('rbt-tools.js') >= 0)

failed = [label for ok, label in checks if not ok]
print(f"LifeRoute client profile audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    for label in failed:
        print(f"FAIL: {label}")
    raise SystemExit(1)
print("LifeRoute rich client profiles, local privacy, editing, and session-tool integration passed.")
