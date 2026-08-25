from pathlib import Path
import runpy


def replace_once(path: Path, old: str, new: str, label: str):
    text = path.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"Could not harden {label}: expected source not found")
    path.write_text(text.replace(old, new, 1))


native = Path("LifeRoute/LifeRouteWebView.swift")

# Match the browser calendar strategy: ignore deleted/hidden calendars, prefer
# calendars the user selected (or primary), and cap the working set.
replace_once(
    native,
    '''            let items = payload["items"] as? [[String: Any]] ?? []
            return items.filter { item in
                (item["deleted"] as? Bool) != true && (item["hidden"] as? Bool) != true
            }
''',
    '''            let items = payload["items"] as? [[String: Any]] ?? []
            let usable = items.filter { item in
                (item["deleted"] as? Bool) != true && (item["hidden"] as? Bool) != true
            }
            let selected = usable.filter { item in
                (item["primary"] as? Bool) == true || (item["selected"] as? Bool) != false
            }
            return Array((selected.isEmpty ? usable : selected).prefix(40))
''',
    "native Google calendar working-set cap",
)

replace_once(
    native,
    '''                var pageToken: String?

                repeat {
''',
    '''                var pageToken: String?
                var pages = 0

                repeat {
''',
    "native Google page counter",
)
replace_once(
    native,
    '''                    pageToken = payload["nextPageToken"] as? String
                } while pageToken != nil
''',
    '''                    pageToken = payload["nextPageToken"] as? String
                    pages += 1
                } while pageToken != nil && pages < 8
''',
    "native Google page cap",
)

print("External service workloads bounded: native Google Calendar uses selected/primary calendars, max 40 calendars, max 8 event pages each.")

# Keep the secure-link/media/calendar hardening in the same deterministic
# external-services phase of preparation.
runpy.run_path("scripts/patch_external_links_hardening_v1.py", run_name="__main__")
