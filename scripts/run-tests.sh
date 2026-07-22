#!/bin/bash
# Compiles the usage-resolution sources together with the test harness and
# runs it. No XCTest/SPM — mirrors build.sh's bare-swiftc approach. The env
# token stub routes resolveUsage through the injected probe deterministically
# (see Tests/ResolveUsageTests.swift).
set -euo pipefail

cd "$(dirname "$0")/.."

OUT_DIR=$(mktemp -d)
trap 'rm -rf "$OUT_DIR"' EXIT

swiftc \
  -parse-as-library \
  -o "$OUT_DIR/resolve-usage-tests" \
  Sources/Model/UsageDisplayModeStore.swift \
  Sources/Usage/AppUsage.swift \
  Sources/Usage/ClaudeCredentials.swift \
  Sources/Usage/CodexAuthModels.swift \
  Sources/Usage/CodexAuthParser.swift \
  Sources/Usage/CodexAccountDataWriter.swift \
  Sources/Usage/CodexAccountStore.swift \
  Sources/Usage/CodexResetCredits.swift \
  Sources/Usage/UsageFetcher.swift \
  Tests/CodexAccountTests.swift \
  Tests/ResolveUsageTests.swift

CLAUDE_CODE_OAUTH_TOKEN="test-stub-token" "$OUT_DIR/resolve-usage-tests"

mkdir -p "$OUT_DIR/codex-home"
HOME="$OUT_DIR/codex-home" CFFIXED_USER_HOME="$OUT_DIR/codex-home" swiftc \
  -parse-as-library \
  -o "$OUT_DIR/codex-usage-window-tests" \
  Sources/Model/UsageDisplayModeStore.swift \
  Sources/Usage/AppUsage.swift \
  Sources/Usage/ClaudeCredentials.swift \
  Sources/Usage/CodexResetCredits.swift \
  Sources/Usage/CodexAuthModels.swift \
  Sources/Usage/CodexAuthParser.swift \
  Sources/Usage/UsageFetcher.swift \
  Tests/CodexUsageWindowContract.swift \
  Tests/CodexUsageWindowUpstreamAdapter.swift

HOME="$OUT_DIR/codex-home" CFFIXED_USER_HOME="$OUT_DIR/codex-home" "$OUT_DIR/codex-usage-window-tests"

swiftc \
  -parse-as-library \
  -framework AppKit \
  -o "$OUT_DIR/chatgpt-host-tests" \
  Sources/Model/UsageDisplayModeStore.swift \
  Sources/Usage/AppUsage.swift \
  Sources/Usage/ClaudeCredentials.swift \
  Sources/Usage/CodexResetCredits.swift \
  Sources/Usage/CodexAuthModels.swift \
  Sources/Usage/CodexAuthParser.swift \
  Sources/Usage/CodexAccountDataWriter.swift \
  Sources/Usage/CodexAccountStore.swift \
  Sources/Usage/ChatGPTHostPolicy.swift \
  Sources/Usage/ChatGPTHostController.swift \
  Sources/Usage/CodexAccountApplyCoordinator.swift \
  Sources/Usage/UsageFetcher.swift \
  Tests/ChatGPTHostControllerTests.swift

"$OUT_DIR/chatgpt-host-tests"

swiftc \
  -parse-as-library \
  -o "$OUT_DIR/notch-height-tests" \
  Sources/Model/NotchInfo.swift \
  Sources/Model/IslandSpacingStore.swift \
  Sources/Model/PreferenceStorage.swift \
  Tests/NotchHeightTests.swift

"$OUT_DIR/notch-height-tests"
