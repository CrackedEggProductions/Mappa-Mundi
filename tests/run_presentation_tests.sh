#!/usr/bin/env bash
# Separate from core-only tests; no display server required.
set -uo pipefail
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export XDG_DATA_HOME="$PROJECT_ROOT/builds/test-userdata"
export XDG_CONFIG_HOME="$PROJECT_ROOT/builds/test-config"
export XDG_CACHE_HOME="$PROJECT_ROOT/builds/test-cache"
mkdir -p "$PROJECT_ROOT/builds/verification" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" || exit 1
LOG_DIR="$(mktemp -d "$PROJECT_ROOT/builds/verification/presentation-XXXXXXXX")" || exit 1
"${GODOT_BIN:-godot}" --headless --path "$PROJECT_ROOT" --editor --import > "$LOG_DIR/import.log" 2>&1
status=$?
if (( status != 0 )) || grep -Eq '^SCRIPT ERROR:|^ERROR:|^WARNING:' "$LOG_DIR/import.log"; then
    tail -n 20 "$LOG_DIR/import.log"
    exit 1
fi
"${GODOT_BIN:-godot}" --headless --path "$PROJECT_ROOT" --script res://tests/presentation_runner.gd > "$LOG_DIR/tests.log" 2>&1
status=$?
if (( status != 0 )) || grep -Eq '^SCRIPT ERROR:|^ERROR:|^WARNING:|^FAIL:' "$LOG_DIR/tests.log"; then
    grep -En '^SCRIPT ERROR:|^ERROR:|^WARNING:|^FAIL:' "$LOG_DIR/tests.log" || true
    tail -n 15 "$LOG_DIR/tests.log"
    printf 'Logs: %s\n' "$LOG_DIR"
    exit 1
fi
tail -n 1 "$LOG_DIR/tests.log"
printf 'Logs: %s\n' "$LOG_DIR"
