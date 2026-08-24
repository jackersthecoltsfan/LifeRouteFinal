#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 6 ]; then
  echo "Usage: $0 APP_NAME SCHEME PROJECT BUNDLE_ID APP_SOURCE_PATH CONCURRENCY_PREFIX"
  exit 2
fi

APP_NAME="$1"
SCHEME="$2"
PROJECT="$3"
BUNDLE_ID="$4"
APP_SOURCE_PATH="$5"
CONCURRENCY_PREFIX="$6"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE_DIR="$ROOT/ReusableAppWorkflow"
mkdir -p "$ROOT/.github/workflows" "$ROOT/scripts"

render() {
  local source="$1"
  local destination="$2"
  sed \
    -e "s|__APP_NAME__|$APP_NAME|g" \
    -e "s|__SCHEME__|$SCHEME|g" \
    -e "s|__PROJECT__|$PROJECT|g" \
    -e "s|__BUNDLE_ID__|$BUNDLE_ID|g" \
    -e "s|__APP_SOURCE_PATH__|$APP_SOURCE_PATH|g" \
    -e "s|__CONCURRENCY_PREFIX__|$CONCURRENCY_PREFIX|g" \
    "$source" > "$destination"
}

render "$TEMPLATE_DIR/ios-ci.template.yml" "$ROOT/.github/workflows/ios-ci.yml"
render "$TEMPLATE_DIR/auto-testflight.template.yml" "$ROOT/.github/workflows/auto-testflight.yml"
render "$TEMPLATE_DIR/testflight.template.yml" "$ROOT/.github/workflows/testflight.yml"

if [ ! -f "$ROOT/scripts/prepare_build.sh" ]; then
  cp "$TEMPLATE_DIR/prepare_build.template.sh" "$ROOT/scripts/prepare_build.sh"
  chmod +x "$ROOT/scripts/prepare_build.sh"
fi

cp "$TEMPLATE_DIR/apple_ci_assets.rb" "$ROOT/scripts/apple_ci_assets.rb"
chmod +x "$ROOT/scripts/apple_ci_assets.rb"

echo "Reusable iOS workflows installed for $APP_NAME."
echo "Next: add the four required GitHub Apple secrets and customize scripts/prepare_build.sh."
