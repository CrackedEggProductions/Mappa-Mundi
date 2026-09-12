#!/usr/bin/env bash
# Headless verification also checks engine logs: nested GDScript errors need not
# propagate to a test's completion sentinel or Godot's process exit status.
set -uo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
export XDG_DATA_HOME="$PROJECT_ROOT/builds/test-userdata"
export XDG_CONFIG_HOME="$PROJECT_ROOT/builds/test-config"
export XDG_CACHE_HOME="$PROJECT_ROOT/builds/test-cache"

mkdir -p "$PROJECT_ROOT/builds/verification" \
    "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" || exit 1
LOG_DIR="$(mktemp -d "$PROJECT_ROOT/builds/verification/run-XXXXXXXX")" || exit 1
cd -- "$PROJECT_ROOT" || exit 1

run_checked() {
    local label="$1" log_file="$2" command_status
    shift 2
    "$@" > "$log_file" 2>&1
    command_status=$?
    if (( command_status != 0 )) || grep -Eq '^SCRIPT ERROR:|^ERROR:|^WARNING:' "$log_file"; then
        printf 'FAIL: %s (process exit %s)\n' "$label" "$command_status" >&2
        grep -En '^SCRIPT ERROR:|^ERROR:|^WARNING:' "$log_file" >&2 || true
        tail -n 12 "$log_file" >&2
        printf 'Log: %s\n' "$log_file" >&2
        return 1
    fi
    return 0
}

if ! run_checked "editor import" "$LOG_DIR/import.log" \
    "$GODOT_BIN" --headless --path "$PROJECT_ROOT" --editor --import; then
    printf 'Fresh editor import requires local editor sockets; restricted sandboxes may need approval to run it outside the sandbox.\n' >&2
    exit 1
fi
printf 'PASS: editor import\n'

# Restrict discovery to source modules; generated build files are never scanned.
find autoload content core presentation tests -type f -name '*.gd' -print0 \
    | sort -z > "$LOG_DIR/scripts.list" || exit 1
script_count=0
while IFS= read -r -d '' script_path; do
    script_count=$((script_count + 1))
    if ! run_checked "parse $script_path" "$LOG_DIR/parse-$script_count.log" \
        "$GODOT_BIN" --headless --path "$PROJECT_ROOT" \
        --check-only --script "res://$script_path"; then
        exit 1
    fi
done < "$LOG_DIR/scripts.list"
if (( script_count == 0 )); then
    printf 'FAIL: no GDScript source files found\n' >&2
    exit 1
fi
printf 'PASS: %s GDScript files parsed without diagnostics\n' "$script_count"

if [[ "${1:-}" == "--" ]]; then
    shift
fi
if ! run_checked "headless tests" "$LOG_DIR/tests.log" \
    "$GODOT_BIN" --headless --path "$PROJECT_ROOT" \
    --script res://tests/test_runner.gd -- "$@"; then
    exit 1
fi
tail -n 1 "$LOG_DIR/tests.log"
printf 'Logs: %s\n' "$LOG_DIR"
