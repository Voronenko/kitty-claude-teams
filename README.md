# kitty-tmux-wrapper

Use [Claude Code](https://docs.anthropic.com/en/docs/claude-code) **Agent Teams** inside [Kitty](https://sw.kovidgoyal.net/kitty/) — no tmux required.

## The Problem

Claude Code's Agent Teams feature spawns each teammate in its own terminal pane using **tmux**. If you use Kitty as your terminal (without tmux), Agent Teams falls back to in-process mode — no split panes, no visual separation.

## The Solution

This project provides a **tmux shim** — a fake `tmux` binary that intercepts Claude Code's tmux commands and translates them to Kitty remote control equivalents. Agent teammates spawn as real Kitty windows within your current tab.

```
┌──────────────────────┬──────────────────────┐
│                      │  researcher          │
│   Claude Code        ├──────────────────────┤
│   (your session)     │  implementer         │
│                      ├──────────────────────┤
│                      │  tester              │
└──────────────────────┴──────────────────────┘
```

Agent panes are created as Kitty windows with horizontal/vertical splits.

## Requirements

- **Kitty** 0.26+ (tested on 0.46.1)
- **Bash** 4+
- **Claude Code** with Agent Teams support
- **jq** or **python3** (optional, for future JSON parsing needs)

## Installation

```bash
git clone <repo-url> kitty-tmux-wrapper
cd kitty-tmux-wrapper
bash install.sh
```

The install script copies files to `${XDG_DATA_HOME:-~/.local/share}/kitty-tmux-shim/` and prints the activation snippet.

### Kitty Configuration

Add to `~/.config/kitty/kitty.conf`:

```conf
allow_remote_control yes
enabled_layouts splits
```

Or include provided config:

```conf
include /path/to/kitty-tmux-wrapper/extras/kitty-shim.conf
```

**Hybrid activation (recommended):**

The `kitty-shim.conf` file includes these env vars:

```conf
env TMUX=kitty-shim:/tmp/kitty-shim,$$,0
env TMUX_PANE=%0
```

This sets the fake tmux environment **automatically** when Kitty starts. Combined with manual PATH setup in your shell, this reduces configuration to just:

```bash
# Add to ~/.bashrc or ~/.zshrc:
export PATH="${XDG_DATA_HOME:-$HOME/.local/share}/kitty-tmux-shim/bin:$PATH"
```

When both kitty.conf and shell PATH are set correctly, the shim activates automatically without sourcing `activate.sh`. This is the simplest setup for everyday use.

Or include the provided config:

```conf
include /path/to/kitty-tmux-wrapper/extras/kitty-shim.conf
```

### Shell Activation

**Hybrid activation (recommended):** Minimal setup with kitty.conf env vars + shell PATH:

1. **Step 1: Add to `~/.config/kitty/kitty.conf`** (or include the config):
   ```conf
   include /path/to/kitty-tmux-wrapper/extras/kitty-shim.conf
   ```

2. **Step 2: Add to `~/.bashrc`** or `~/.zshrc`**:
   ```bash
   export PATH="${XDG_DATA_HOME:-$HOME/.local/share}/kitty-tmux-shim/bin:$PATH"
   ```

3. **Step 3: Restart Kitty**

That's it! The shim activates automatically when you start Kitty, with no need to source `activate.sh`.

**Traditional activation (full shell config):** If kitty.conf is not configured or you prefer full control:

Add **one** of these to your shell config:

**Bash** (`~/.bashrc`):
```bash
if [ -n "${KITTY_WINDOW_ID:-}" ]; then
    _shim="${XDG_DATA_HOME:-$HOME/.local/share}/kitty-tmux-shim/activate.sh"
    [ -f "$_shim" ] && . "$_shim"
    unset _shim
fi
```

**Zsh** (`~/.zshrc`):
```zsh
if [[ -n "${KITTY_WINDOW_ID:-}" ]]; then
    _shim="${XDG_DATA_HOME:-$HOME/.local/share}/kitty-tmux-shim/activate.sh"
    [[ -f "$_shim" ]] && source "$_shim"
    unset _shim
fi
```

Then restart your shell inside Kitty.

## Real life integration within dotfiles

This project actually evolved from mine dotfiles

zshrc:

```sh
# kitty-tmux-shim: Hybrid activation (env vars from kitty.conf, PATH + state init here)
if [[ -n "${KITTY_WINDOW_ID:-}" ]]; then
    export PATH="$HOME/dotfiles/config/kitty/kitty-tmux-shim/bin:$PATH"

    # Use KITTY_WINDOW_ID to isolate different kitty instances
    _shim_root="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/kitty-tmux-shim-$(id -u)"
    export KITTY_TMUX_SHIM_STATE="$_shim_root/window-${KITTY_WINDOW_ID}"
    unset _shim_root

    mkdir -p "$KITTY_TMUX_SHIM_STATE"
    [[ ! -f "$KITTY_TMUX_SHIM_STATE/next_id" ]] && echo "1" > "$KITTY_TMUX_SHIM_STATE/next_id"
    # Initialize sessions file with default "main" session
    if [[ ! -f "$KITTY_TMUX_SHIM_STATE/sessions" ]]; then
        echo "main" > "$KITTY_TMUX_SHIM_STATE/sessions"
    fi
fi
```

and portion of kitty tmux shim under:  https://github.com/Voronenko/dotfiles/tree/master/config/kitty

How it works in mine dotfiles: https://github.com/Voronenko/dotfiles/blob/master/config/kitty/README.tmux-shim.md

## Usage

Once activated, just use Claude Code normally inside Kitty:

```bash
claude           # start Claude Code
# Create a team → teammates appear as Kitty windows
```

The shim activates automatically when you're inside Kitty (it checks for the `$KITTY_WINDOW_ID` env var). Outside Kitty, it stays dormant.

### Deactivation

```bash
source ~/.local/share/kitty-tmux-shim/deactivate.sh
```

### Uninstall

```bash
cd kitty-tmux-wrapper
bash install.sh --uninstall
# Then remove the activation snippet from your shell config
```

## Configuration

| Variable | Default | Description |
|---|---|---|
| `KITTY_TMUX_SHIM_DEBUG` | unset | Set to `1` to log all tmux calls to `$STATE_DIR/shim.log` |

## How It Works TLDR

The shim uses Kitty's **remote control protocol** (`kitten @` commands):

```mermaid
sequenceDiagram
    participant CC as Claude Code
    participant Shim as Shim (bin/tmux)
    participant Kitty as Kitty Terminal
    participant W as kitty-window-wrapper

    Note over CC,Kitty: 1. Create Pane (split-window)
    CC->>Shim: tmux split-window -h -P -F '#{pane_id}'
    Shim->>Shim: alloc pane ID (%1)
    Shim->>Shim: snapshot parent env
    Shim->>Kitty: kitten @ launch --type=window --location=hsplit
    Kitty->>W: starts wrapper in new window
    W->>W: restores env, writes PID + kitty_id
    W->>W: creates FIFO, touches .ready
    W-->>Shim: .ready sentinel
    Shim->>Shim: wait for .ready
    Shim-->>CC: %1

    Note over CC,Kitty: 2. Send Command (send-keys)
    CC->>Shim: tmux send-keys -t %1 "cmd" Enter
    Shim->>W: write "cmd" to FIFO
    W->>W: reads FIFO, eval "$cmd"
    W->>Kitty: command runs in window

    Note over CC,Kitty: 3. Destroy Pane (kill-pane)
    CC->>Shim: tmux kill-pane -t %1
    Shim->>W: SIGTERM to wrapper PID
    Shim->>Kitty: kitten @ close-window
    Shim->>Shim: clean up state files
```


## Architecture Overview (diagrams)

### High-Level Flow

```mermaid
flowchart LR
    CC[Claude Code] -->|tmux split-window| KS[kitty-tmux-shim]
    CC -->|tmux send-keys| KS
    KS -->|kitten @ launch| KW[Kitty Window]
    KS -->|kitten @ send-text| KW
    KS -->|kitten @ close-window| KW
    KS -->|kitten @ set-window-title| KW
    KW --> WRP[kitty-window-wrapper]
```

### Window Creation Flow

```mermaid
sequenceDiagram
    participant CC as Claude Code
    participant Shim as kitty-tmux-shim
    participant Kitty as Kitty
    participant Wrapper as kitty-window-wrapper

    CC->>Shim: tmux split-window -h -l 70% -P -F '#{pane_id}'
    Shim->>Shim: alloc_pane_id() → %1
    Shim->>Kitty: kitten @ launch --no-response --type=window --location=hsplit --allow-remote-control
    Note over Kitty: Creates new OS window
    Kitty->>Wrapper: Launch in new window
    Wrapper->>Wrapper: Set KITTY_WINDOW_ID env var
    Wrapper->>Shim: Write .kitty_id → "6"
    Wrapper->>Shim: Touch .ready
    Shim->>Shim: Wait for .ready, read .kitty_id
    Shim->>CC: Return %1

    CC->>Shim: tmux send-keys -t %1 "claude-agent ... --agent-name researcher Enter"
    Shim->>Shim: Write command to .fifo
    Wrapper->>Wrapper: Read command from .fifo
    Wrapper->>Shim: Parse --agent-name, write .agent_name
    Wrapper->>Shim: Touch .named
    Wrapper->>Wrapper: exec claude-agent command
    Shim->>Shim: Wait for .named, read .agent_name
    Shim->>Kitty: kitten @ --no-response set-window-title --match=id:6 "researcher"
```

### State Directory Structure

```mermaid
graph TD
    Root["/run/user/1000/kitty-tmux-shim-1000/"]
    Root --> W1["window-1/"]
    Root --> W2["window-2/"]
    Root --> W3["window-3/"]

    W1 --> P1["%1.pid"]
    W1 --> K1["%1.kitty_id"]
    W1 --> F1["%1.fifo"]
    W1 --> R1["%1.ready"]
    W1 --> N1["%1.named"]
    W1 --> A1["%1.agent_name"]

    style Root fill:#f9f,stroke:#333,stroke-width:2px
    style W1 fill:#bbf,stroke:#333,stroke-width:1px
    style W2 fill:#bbf,stroke:#333,stroke-width:1px
    style W3 fill:#bbf,stroke:#333,stroke-width:1px
```

### Component Architecture

```mermaid
graph TB
    subgraph "Claude Code"
        T1[TmuxBackend.ts]
        AG[Agent Spawner]
    end

    subgraph "kitty-tmux-shim"
        TMUX[bin/tmux]
        WRAP[bin/kitty-window-wrapper]
    end

    subgraph "Kitty Terminal"
        KW1[Window 1: Leader]
        KW2[Window 2: Agent]
        KW3[Window 3: Agent]
    end

    subgraph "State Directory"
        FIFO[.fifo files]
        LOCK[next_id.lock]
        LOG[shim.log]
    end

    AG -->|tmux commands| TMUX
    TMUX -->|launch| WRAP
    TMUX -->|read/write| FIFO
    TMUX -->|acquire| LOCK
    TMUX -->|logging| LOG

    WRAP -->|spawned in| KW2
    WRAP -->|spawned in| KW3

    style T1 fill:#bfb,stroke:#333
    style TMUX fill:#bbf,stroke:#333
    style WRAP fill:#bbf,stroke:#333
    style KW1 fill:#fbb,stroke:#333
    style KW2 fill:#fbb,stroke:#333
    style KW3 fill:#fbb,stroke:#333
```

### Parallel Spawn Protection

```mermaid
sequenceDiagram
    participant CC as Claude Code
    participant L1 as Shim (Pane 1)
    participant L2 as Lock (next_id.lock)
    participant K1 as Kitty (Window 1)
    participant L3 as Shim (Pane 3)

    CC->>L1: tmux split-window (agent1)
    L1->>L2: mkdir next_id.lock (acquire)
    L1->>L1: Read next_id → "1"
    L1->>L1: Increment next_id → "2"
    L1->>L2: Release lock
    L1->>K1: kitten @ launch (wrapper for %1)
    K1->>L1: Return window ID

    Note over L1,L3: Parallel request for agent2

    CC->>L3: tmux split-window (agent2)
    L3->>L2: mkdir next_id.lock (wait for L1)
    L1->>L2: Release lock
    L3->>L2: mkdir next_id.lock (acquire)
    L3->>L3: Read next_id → "2"
    L3->>L3: Increment next_id → "3"
    L3->>L2: Release lock
    L3->>K1: kitten @ launch (wrapper for %2)
    K1->>L3: Return window ID

    Note over CC,K1: Result: %1 and %2 created with unique IDs
```


### Environment Forwarding

Kitty's `kitten @ launch` does inherit the parent's environment when using `--cwd=current`. The wrapper also restores additional environment from a snapshot file for pane-specific variables (`TMUX_PANE`, state dir).

### Command Mapping

| Tmux Command | Kitty Equivalent | Behavior |
|---|---|---|
| `split-window -h` | `kitten @ launch --type=window --location=hsplit` | Horizontal split |
| `split-window -v` | `kitten @ launch --type=window --location=vsplit` | Vertical split |
| `new-window` | `kitten @ launch --type=tab` | New tab |
| `send-keys -t %N` | FIFO delivery or `kitten @ send-text` | Send command |
| `kill-pane -t %N` | SIGTERM + `kitten @ close-window` | Close window |
| `display-message -p '#{pane_id}'` | Return `$TMUX_PANE` | Query pane ID |
| `list-panes` | Scan state dir for active PIDs | List panes |
| `select-pane -t %N` | `kitten @ focus-window` | Focus window |
| `has-session` | Check sessions file | Session check |
| `new-session` | Track in sessions file | Session create |
| `select-layout`, `resize-pane`, etc. | No-op | Layout management |

## Troubleshooting

### Panes don't appear

1. **Remote control not enabled**: Check `allow_remote_control yes` in `kitty.conf`
2. **Shim not activated**: Run `echo $KITTY_TMUX_SHIM_ACTIVE` — should print `1`
3. **Check debug log**: `export KITTY_TMUX_SHIM_DEBUG=1` then check `$KITTY_TMUX_SHIM_STATE/shim.log`

### Commands not executing in panes

1. **Check FIFO**: `ls -la $KITTY_TMUX_SHIM_STATE/*.fifo`
2. **Check wrapper PID**: `cat $KITTY_TMUX_SHIM_STATE/<N>.pid` and verify with `kill -0 <pid>`
3. **Check Kitty windows**: `kitten @ ls | jq '.[] | .tabs[].windows[] | {id, title}'`

### kill-pane doesn't work

1. **Check PID**: `cat $KITTY_TMUX_SHIM_STATE/<N>.pid`
2. **Manually close**: `kitten @ close-window --match=id:<kitty_window_id>`

## Known Limitations

- **Layout management** — Kitty manages layouts automatically; tmux layout commands are no-ops
- **Pane styling** — No Kitty equivalent to tmux pane-border-style; styling commands are ignored
- **Hide/show panes** — Not implemented (would require moving to hidden tab)
- **Socket isolation** — Claude's `-L` socket isolation is ignored (stripped from args)
- **Fragile to Claude Code updates** — new tmux commands added upstream may need shim updates

## Compatibility

| Platform | Status |
|---|---|
| Linux (x86_64) | Tested |
| macOS (Apple Silicon) | Should work |
| macOS (Intel) | Should work |
| WSL2 | Untested |

## License

MIT
