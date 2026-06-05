#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-Debug}"
SCHEME="${SCHEME:-DiaryCompanion}"
PROJECT="${PROJECT:-DiaryCompanion.xcodeproj}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/DerivedData/IPA}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/artifacts/ipa}"
IPA_NAME="${IPA_NAME:-Vesper-dev.ipa}"

cd "$ROOT_DIR"

rm -rf "$DERIVED_DATA_PATH"
mkdir -p "$OUTPUT_DIR"

xcodebuild \
  -allowProvisioningUpdates \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-iphoneos/DiaryCompanion.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app bundle not found at $APP_PATH" >&2
  exit 1
fi

STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT

mkdir -p "$STAGING_DIR/Payload"
cp -R "$APP_PATH" "$STAGING_DIR/Payload/"

IPA_PATH="$OUTPUT_DIR/$IPA_NAME"
rm -f "$IPA_PATH"
(
  cd "$STAGING_DIR"
  /usr/bin/zip -qry "$IPA_PATH" Payload
)

echo "$IPA_PATH"
