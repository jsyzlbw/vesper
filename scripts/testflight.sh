#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${PROJECT:-$ROOT_DIR/DiaryCompanion.xcodeproj}"
SCHEME="${SCHEME:-DiaryCompanion}"
CONFIGURATION="${CONFIGURATION:-Release}"
BUNDLE_ID="${BUNDLE_ID:-com.liangbowenbill.DiaryCompanion}"
TEAM_ID="${TEAM_ID:-6TA82JX42Z}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-$ROOT_DIR/artifacts/testflight}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ARTIFACTS_DIR/Vesper.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ARTIFACTS_DIR/export}"
EXPORT_OPTIONS_PLIST="$ARTIFACTS_DIR/ExportOptions.plist"

log() {
  printf '[testflight] %s\n' "$*"
}

warn() {
  printf '[testflight] WARNING: %s\n' "$*" >&2
}

fail() {
  printf '[testflight] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ./scripts/testflight.sh <preflight|archive|upload>

Commands:
  preflight  Check the local TestFlight release prerequisites.
  archive    Create an App Store Connect IPA in artifacts/testflight/export.
  upload     Upload the exported IPA with an App Store Connect API key.

Optional archive overrides:
  VERSION=0.1.0 BUILD_NUMBER=2 ./scripts/testflight.sh archive

Required upload environment variables:
  ASC_API_KEY_ID
  ASC_API_ISSUER_ID
  ASC_API_PRIVATE_KEY_PATH

Optional signing override:
  TEAM_ID=YOUR_TEAM_ID
EOF
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "缺少命令：$1"
}

build_setting() {
  local key="$1"
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -showBuildSettings 2>/dev/null |
    awk -F ' = ' -v key="$key" '$1 ~ "^[[:space:]]*" key "$" { print $2; exit }'
}

plist_value() {
  local key="$1"
  /usr/libexec/PlistBuddy -c "Print :$key" "$ROOT_DIR/DiaryCompanion/Info.plist" 2>/dev/null || true
}

canonical_path() {
  local path="$1"
  local dir base
  dir="$(dirname "$path")"
  base="$(basename "$path")"
  mkdir -p "$dir"
  (cd "$dir" && printf '%s/%s\n' "$(pwd -P)" "$base")
}

ensure_artifact_path() {
  local label="$1"
  local path="$2"
  local artifacts_root target workspace_root

  [[ -n "$path" ]] || fail "$label 不能为空。"
  mkdir -p "$ARTIFACTS_DIR"
  artifacts_root="$(cd "$ARTIFACTS_DIR" && pwd -P)"
  workspace_root="$(cd "$ROOT_DIR" && pwd -P)"
  target="$(canonical_path "$path")"

  case "$target" in
    "$artifacts_root"/*) ;;
    *) fail "$label 必须位于 ARTIFACTS_DIR 内。当前值：${target}；ARTIFACTS_DIR：${artifacts_root}" ;;
  esac

  case "$target" in
    "/"|"$workspace_root"|"$artifacts_root")
      fail "$label 指向了不安全路径：$target"
      ;;
  esac
}

check_api_key_hint() {
  local missing=0
  for variable in ASC_API_KEY_ID ASC_API_ISSUER_ID ASC_API_PRIVATE_KEY_PATH; do
    if [[ -z "$(printenv "$variable" 2>/dev/null || true)" ]]; then
      warn "未设置 ${variable}。运行 upload 前必须配置 App Store Connect API Key。"
      missing=1
    fi
  done

  if [[ -n "${ASC_API_PRIVATE_KEY_PATH:-}" && ! -f "$ASC_API_PRIVATE_KEY_PATH" ]]; then
    warn "ASC_API_PRIVATE_KEY_PATH 指向的文件不存在：$ASC_API_PRIVATE_KEY_PATH"
    missing=1
  fi

  return "$missing"
}

preflight() {
  local errors=0

  log "检查 Xcode..."
  if ! command -v xcodebuild >/dev/null 2>&1; then
    warn "找不到 xcodebuild。请先安装 Xcode，并运行 sudo xcode-select -s /Applications/Xcode.app。"
    errors=$((errors + 1))
  else
    log "Xcode: $(xcodebuild -version | tr '\n' ' ')"
  fi

  if [[ ! -d "$PROJECT" ]]; then
    warn "找不到工程：$PROJECT"
    errors=$((errors + 1))
  elif ! xcodebuild -list -project "$PROJECT" 2>/dev/null |
    sed -n '/Schemes:/,$p' |
    grep -Eq "^[[:space:]]+$SCHEME$"; then
    warn "工程中找不到 scheme：$SCHEME"
    errors=$((errors + 1))
  else
    log "Scheme: $SCHEME"
  fi

  if (( errors == 0 )); then
    local actual_bundle_id marketing_version build_number plist_version plist_build
    actual_bundle_id="$(build_setting PRODUCT_BUNDLE_IDENTIFIER)"
    marketing_version="$(build_setting MARKETING_VERSION)"
    build_number="$(build_setting CURRENT_PROJECT_VERSION)"
    plist_version="$(plist_value CFBundleShortVersionString)"
    plist_build="$(plist_value CFBundleVersion)"

    if [[ "$actual_bundle_id" != "$BUNDLE_ID" ]]; then
      warn "Bundle ID 不匹配。预期 $BUNDLE_ID，实际 ${actual_bundle_id:-<未设置>}。"
      errors=$((errors + 1))
    else
      log "Bundle ID: $actual_bundle_id"
    fi

    if [[ -z "$marketing_version" ]]; then
      warn "MARKETING_VERSION 未设置。请在 Xcode 工程中设置版本号，例如 0.1.0；archive 时也可用 VERSION=0.1.0 覆盖。"
      errors=$((errors + 1))
    else
      log "Marketing version: $marketing_version"
    fi

    if [[ "$plist_version" != '$(MARKETING_VERSION)' ]]; then
      warn "Info.plist 缺少 CFBundleShortVersionString = \$(MARKETING_VERSION)。当前值：${plist_version:-<未设置>}。"
      errors=$((errors + 1))
    else
      log "Info.plist CFBundleShortVersionString: $plist_version"
    fi

    if [[ -z "$build_number" ]]; then
      warn "CURRENT_PROJECT_VERSION 未设置。请在 Xcode 工程中设置构建号，例如 1；archive 时也可用 BUILD_NUMBER=1 覆盖。"
      errors=$((errors + 1))
    else
      log "Build number: $build_number"
    fi

    if [[ "$plist_build" != '$(CURRENT_PROJECT_VERSION)' ]]; then
      warn "Info.plist 缺少 CFBundleVersion = \$(CURRENT_PROJECT_VERSION)。当前值：${plist_build:-<未设置>}。"
      errors=$((errors + 1))
    else
      log "Info.plist CFBundleVersion: $plist_build"
    fi
  fi

  log "检查代码签名 identities..."
  local identities
  identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"
  if [[ -z "$identities" || "$identities" == *"0 valid identities found"* ]]; then
    warn "没有可用签名 identity。请在 Xcode > Settings > Accounts 中登录 Apple ID 并管理证书。"
    errors=$((errors + 1))
  else
    printf '%s\n' "$identities"
  fi

  if ! grep -Eq '"Apple Distribution:|"iPhone Distribution:' <<<"$identities"; then
    warn "未发现 Apple Distribution identity。首次 archive 时 Xcode 可能自动创建；如果失败，请确认已加入 Apple Developer Program，并在 Xcode 中启用自动签名。"
  fi

  log "检查 App Store Connect API Key 环境变量..."
  check_api_key_hint || true

  if (( errors > 0 )); then
    fail "preflight 发现 $errors 个阻塞问题。请按上方提示处理后重试。"
  fi

  log "preflight 通过。"
}

write_export_options() {
  mkdir -p "$ARTIFACTS_DIR"
  cat >"$EXPORT_OPTIONS_PLIST" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>export</string>
  <key>method</key>
  <string>app-store-connect</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
EOF
}

archive() {
  require_command xcodebuild

  local archive_command=(
    xcodebuild
    -project "$PROJECT"
    -scheme "$SCHEME"
    -configuration "$CONFIGURATION"
    -destination 'generic/platform=iOS'
    -archivePath "$ARCHIVE_PATH"
    -allowProvisioningUpdates
    "DEVELOPMENT_TEAM=$TEAM_ID"
  )
  if [[ -n "${VERSION:-}" ]]; then
    archive_command+=("MARKETING_VERSION=$VERSION")
  fi
  if [[ -n "${BUILD_NUMBER:-}" ]]; then
    archive_command+=("CURRENT_PROJECT_VERSION=$BUILD_NUMBER")
  fi
  archive_command+=(archive)

  ensure_artifact_path ARCHIVE_PATH "$ARCHIVE_PATH"
  ensure_artifact_path EXPORT_PATH "$EXPORT_PATH"
  mkdir -p "$ARTIFACTS_DIR"
  rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
  write_export_options

  log "创建 Release archive..."
  "${archive_command[@]}"

  log "导出 App Store Connect IPA..."
  if ! xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
    -allowProvisioningUpdates; then
    fail "IPA 导出失败。请确认 Apple Developer Program 已生效、Apple ID 已关联 App Store Connect provider，并允许 Xcode 自动创建 iOS App Store provisioning profile。"
  fi

  local ipa
  ipa="$(find "$EXPORT_PATH" -maxdepth 1 -name '*.ipa' -print -quit)"
  [[ -n "$ipa" ]] || fail "archive 已完成，但没有找到 IPA：$EXPORT_PATH"
  log "IPA 已生成：$ipa"
}

upload() {
  require_command xcrun

  check_api_key_hint || fail "upload 需要完整的 App Store Connect API Key 环境变量。"

  local ipa
  ipa="${IPA_PATH:-$(find "$EXPORT_PATH" -maxdepth 1 -name '*.ipa' -print -quit 2>/dev/null || true)}"
  [[ -n "$ipa" && -f "$ipa" ]] || fail "找不到 IPA。请先运行 ./scripts/testflight.sh archive，或设置 IPA_PATH。"

  log "上传 IPA 到 App Store Connect..."
  xcrun altool \
    --upload-app \
    --type ios \
    --file "$ipa" \
    --apiKey "$ASC_API_KEY_ID" \
    --apiIssuer "$ASC_API_ISSUER_ID" \
    --p8-file-path "$ASC_API_PRIVATE_KEY_PATH"
  log "上传完成。等待 App Store Connect 处理构建。"
}

case "${1:-}" in
  preflight)
    preflight
    ;;
  archive)
    archive
    ;;
  upload)
    upload
    ;;
  *)
    usage
    exit 1
    ;;
esac
