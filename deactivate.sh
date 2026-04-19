#!/usr/bin/env bash
# Source this file to deactivate the kitty-tmux-shim.
# Usage: source deactivate.sh

if [ -z "${KITTY_TMUX_SHIM_ACTIVE:-}" ]; then
    echo "kitty-tmux-shim: not active, nothing to deactivate" >&2
    return 0 2>/dev/null || exit 0
fi

if [ -d "${KITTY_TMUX_SHIM_STATE:-}" ]; then
    for pidfile in "$KITTY_TMUX_SHIM_STATE"/*.pid; do
        [ -f "$pidfile" ] || continue
        pid=$(cat "$pidfile" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
        fi
    done
    rm -rf "$KITTY_TMUX_SHIM_STATE"
fi

if [ -n "${KITTY_TMUX_SHIM_ORIG_PATH:-}" ]; then
    export PATH="$KITTY_TMUX_SHIM_ORIG_PATH"
fi

unset TMUX
unset TMUX_PANE
unset KITTY_TMUX_SHIM_ACTIVE
unset KITTY_TMUX_SHIM_DIR
unset KITTY_TMUX_SHIM_STATE
unset KITTY_TMUX_SHIM_REAL_TMUX
unset KITTY_TMUX_SHIM_ORIG_PATH
unset KITTY_TMUX_SHIM_DEBUG
