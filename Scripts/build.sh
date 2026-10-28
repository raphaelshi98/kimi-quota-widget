#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEAM_ID="${1:-${DEVELOPMENT_TEAM:-}}"
XCODE_DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
KIMI_EXECUTABLE="${KIMI_EXECUTABLE:-$HOME/.kimi-code/bin/kimi}"

if [[ -z "$TEAM_ID" ]]; then
    CERTIFICATE_SUBJECT="$(security find-certificate -c "Apple Development" -p 2>/dev/null | openssl x509 -noout -subject 2>/dev/null || true)"
    if [[ "$CERTIFICATE_SUBJECT" =~ OU=([A-Z0-9]{10}) ]]; then
        TEAM_ID="${BASH_REMATCH[1]}"
    fi
fi

if [[ ! "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
    echo "请提供 10 位 Apple Team ID，例如：./Scripts/build.sh ABCDE12345" >&2
    echo "也可以先运行：DEVELOPMENT_TEAM=ABCDE12345 ./Scripts/build.sh" >&2
    exit 1
fi

if [[ ! -x "$KIMI_EXECUTABLE" ]]; then
    echo "未找到 Kimi Code CLI：$KIMI_EXECUTABLE" >&2
    echo "请先安装 Kimi Code 并执行 kimi login。" >&2
    exit 1
fi

if ! DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" xcodebuild -version >/dev/null 2>&1; then
    echo "完整 Xcode 不可用，请安装 Xcode、接受许可并安装平台组件。" >&2
    exit 1
fi

BUNDLE_ID="${KIMI_QUOTA_BUNDLE_ID:-com.kimiquota.${TEAM_ID}.app}"
APP_GROUP="${APP_GROUP_IDENTIFIER:-${TEAM_ID}.${BUNDLE_ID}.shared}"
if [[ ! "$BUNDLE_ID" =~ ^[A-Za-z0-9.-]+$ ]] || [[ ! "$APP_GROUP" =~ ^[A-Za-z0-9.-]+$ ]]; then
    echo "Bundle ID 和 App Group 只能包含字母、数字、点与连字符。" >&2
    exit 1
fi

echo "使用 Kimi Code CLI：$("$KIMI_EXECUTABLE" --version)"
echo "使用 Team ID：$TEAM_ID"
echo "Bundle ID：$BUNDLE_ID"
echo "App Group：$APP_GROUP"

OLD_PID="$(pgrep -x KimiQuota || true)"
if [[ -n "$OLD_PID" ]]; then
    CHILD_PID="$(pgrep -P "$OLD_PID" || true)"
    pkill -TERM -x KimiQuota || true
    if [[ -n "$CHILD_PID" ]]; then
        kill -TERM $CHILD_PID 2>/dev/null || true
    fi
fi

DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" xcodebuild -quiet \
    -project "$ROOT_DIR/KimiQuota.xcodeproj" \
    -scheme KimiQuota \
    -destination 'platform=macOS' \
    -configuration Release \
    -derivedDataPath "$ROOT_DIR/build" \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    KIMI_QUOTA_BUNDLE_ID="$BUNDLE_ID" \
    APP_GROUP_IDENTIFIER="$APP_GROUP" \
    build

APP_PATH="$ROOT_DIR/build/Build/Products/Release/KimiQuota.app"
WIDGET_PATH="$APP_PATH/Contents/PlugIns/KimiQuotaWidget.appex"

codesign --verify --deep --strict "$APP_PATH"
pluginkit -a "$WIDGET_PATH"
pluginkit -e use -i "${BUNDLE_ID}.widget"
open "$APP_PATH"

echo "完成：$APP_PATH"
echo "请在通知中心选择“编辑小组件”，添加“Kimi 额度”。"
