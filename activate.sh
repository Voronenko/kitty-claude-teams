#!/usr/bin/env bash
# Source this file to activate the kitty-tmux-shim.
# Usage: source activate.sh

if [ -z "${KITTY_WINDOW_ID:-}" ]; then
    echo "kitty-tmux-shim: not inside kitty, skipping activation" >&2
    return 1 2>/dev/null || exit 1
fi

if [ -n "${KITTY_TMUX_SHIM_ACTIVE:-}" ]; then
    return 0 2>/dev/null || exit 0
fi

KITTY_TMUX_SHIM_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/kitty-tmux-shim"

_runtime_base="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
_shim_root="${_runtime_base}/kitty-tmux-shim-$(id -u)"
KITTY_TMUX_SHIM_STATE="${_shim_root}/default"
unset _runtime_base

KITTY_TMUX_SHIM_REAL_TMUX="$(command -v tmux 2>/dev/null || true)"
export KITTY_TMUX_SHIM_REAL_TMUX

KITTY_TMUX_SHIM_ORIG_PATH="$PATH"
export KITTY_TMUX_SHIM_ORIG_PATH

export PATH="${KITTY_TMUX_SHIM_DIR}/bin:${PATH}"

export TMUX="kitty-shim:/tmp/kitty-shim,$$,0"
export TMUX_PANE="%0"

export KITTY_TMUX_SHIM_DIR
export KITTY_TMUX_SHIM_STATE

if [ -L "$_shim_root" ]; then
    echo "kitty-tmux-shim: ERROR: state root is a symlink, refusing to activate" >&2
    unset _shim_root
    return 1 2>/dev/null || exit 1
fi
mkdir -p "$_shim_root"
chmod 700 "$_shim_root"
_owner=$(stat -c '%u' "$_shim_root" 2>/dev/null || stat -f '%u' "$_shim_root" 2>/dev/null)
if [ "$_owner" != "$(id -u)" ]; then
    echo "kitty-tmux-shim: ERROR: state root not owned by current user" >&2
    unset _shim_root _owner
    return 1 2>/dev/null || exit 1
fi
unset _owner
mkdir -p "$KITTY_TMUX_SHIM_STATE"
unset _shim_root

if [ ! -f "$KITTY_TMUX_SHIM_STATE/next_id" ]; then
    echo "1" > "$KITTY_TMUX_SHIM_STATE/next_id"
fi

if [ ! -f "$KITTY_TMUX_SHIM_STATE/sessions" ]; then
    touch "$KITTY_TMUX_SHIM_STATE/sessions"
fi

command find "$KITTY_TMUX_SHIM_STATE" -maxdepth 1 -name '*.pid' 2>/dev/null | while IFS= read -r _pidfile; do
    _pid=$(cat "$_pidfile" 2>/dev/null)
    if [ -n "$_pid" ] && ! kill -0 "$_pid" 2>/dev/null; then
        _key="${_pidfile##*/}"
        _key="${_key%.pid}"
        rm -f "$KITTY_TMUX_SHIM_STATE/${_key}.pid" \
              "$KITTY_TMUX_SHIM_STATE/${_key}.kitty_id" \
              "$KITTY_TMUX_SHIM_STATE/${_key}.fifo" \
              "$KITTY_TMUX_SHIM_STATE/${_key}.ready" \
              "$KITTY_TMUX_SHIM_STATE/${_key}.cmd" \
              "$KITTY_TMUX_SHIM_STATE/${_key}.named" \
              "$KITTY_TMUX_SHIM_STATE/${_key}.group"
    fi
done

command find "$KITTY_TMUX_SHIM_STATE" -maxdepth 1 -name '*.kitty_id' 2>/dev/null | while IFS= read -r _idfile; do
    _key="${_idfile##*/}"
    _key="${_key%.kitty_id}"
    [ -f "$KITTY_TMUX_SHIM_STATE/${_key}.pid" ] || rm -f "$_idfile"
done

rm -f "$KITTY_TMUX_SHIM_STATE/parent.env"
rm -rf "$KITTY_TMUX_SHIM_STATE/next_id.lock"

export KITTY_TMUX_SHIM_ACTIVE=1
