#!/bin/sh
set -eu

if [ "${CONFIGURATION:-}" != "Debug" ]; then
    exit 0
fi

full_commit=$(/usr/bin/git -C "${SRCROOT}" rev-parse --verify HEAD)
if ! /usr/bin/printf '%s\n' "${full_commit}" | /usr/bin/grep -Eq '^[0-9a-f]{40}$'; then
    /usr/bin/printf 'error: Unable to derive LifeRoute source commit from Git HEAD.\n' >&2
    exit 1
fi

short_commit=$(/usr/bin/printf '%.7s' "${full_commit}")
identity_path="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/LifeRouteSourceCommit.txt"

/bin/mkdir -p "$(/usr/bin/dirname "${identity_path}")"
/usr/bin/printf '%s\n' "${short_commit}" > "${identity_path}"
