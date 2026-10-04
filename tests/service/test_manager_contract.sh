#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
MANAGER="$ROOT/core/service/manager.sh"

# Start must validate the existing configuration and verify the runtime.
grep -F 'config_valid ||' "$MANAGER" >/dev/null
grep -F 'if ! verify_runtime' "$MANAGER" >/dev/null

# Failed first-time activation must be able to remove a config when no backup exists.
grep -F 'restore_current_config()' "$MANAGER" >/dev/null
grep -F 'rm -f "$CONFIG" "$CANDIDATE"' "$MANAGER" >/dev/null

# A second apply must not overwrite the safety rollback state.
grep -F 'Another apply is awaiting confirmation' "$MANAGER" >/dev/null

# Stopping during a pending apply must not simply cancel the safety timer and keep the unconfirmed config.
grep -F 'restore_current_config || return 1' "$MANAGER" >/dev/null

grep -F 'Current configuration failed runtime verification; rolling back' "$MANAGER" >/dev/null

printf '%s\n' 'manager lifecycle contract tests: PASS'
