#!/usr/bin/env bash
# Vibemis — one-command Tailscale setup for remote play (P3.7).
#
# Goal: get this device onto your Tailscale tailnet with the least possible fuss, so you can
# stream to your PC from anywhere. The ONLY interactive step is logging in once via a URL this
# script prints (that's the "minimal user input"). After that, in Vibemis enable
# Settings -> "Prefer Tailscale addresses" (test51) and stream your host by its Tailscale IP.
#
# Run it:   ./scripts/setup-tailscale.sh
#
# It tries, in order:
#   1. Use an already-installed tailscale (best case — just brings it up).
#   2. Install via Tailscale's official installer (needs sudo; the canonical path on most distros).
#   3. Fall back to a userspace install under ~/.local (no sudo) for locked-down/immutable systems
#      like SteamOS, using userspace-networking mode.
# It is idempotent — safe to re-run.

set -u

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/vibemis-tailscale"
LOCAL_BIN="$HOME/.local/bin"
SOCK="$STATE_DIR/tailscaled.sock"
TS_VERSION="${VIBEMIS_TS_VERSION:-1.78.1}"   # pin a known-good stable; override via env if needed
mkdir -p "$STATE_DIR" "$LOCAL_BIN"

say()  { printf '\n\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

# Resolve a usable tailscale CLI (system first, then our userspace copy).
ts_cli() {
    if have tailscale; then echo "tailscale"; return 0; fi
    if [ -x "$LOCAL_BIN/tailscale" ]; then echo "$LOCAL_BIN/tailscale"; return 0; fi
    return 1
}

bring_up_and_report() {
    local TS="$1"; shift
    local SOCK_ARGS=("$@")   # may be empty (system daemon) or --socket=... (userspace)
    say "Bringing Tailscale up — if a login URL appears below, open it and sign in (one time):"
    "$TS" "${SOCK_ARGS[@]}" up --accept-routes || warn "'tailscale up' returned non-zero — re-run after logging in if needed."
    local IP
    IP=$("$TS" "${SOCK_ARGS[@]}" ip -4 2>/dev/null | head -1)
    echo
    echo "==================================================================="
    echo " Tailscale is ready for Vibemis remote play."
    [ -n "$IP" ] && echo "   This device's Tailscale IP: $IP"
    echo "   Next in Vibemis:"
    echo "     1. Settings -> enable 'Prefer Tailscale addresses for remote play'."
    echo "     2. Make sure your host PC also runs Tailscale (same account)."
    echo "     3. Add/stream the host by its Tailscale IP (100.x.y.z) or MagicDNS name."
    echo "==================================================================="
}

# ---- 0) Non-blocking status check (safe for automated testing; no sudo, no login) ----------
# `setup-tailscale.sh --check` just reports current state and exits — it never installs, never
# calls sudo, and never runs `tailscale up` (which would block waiting for browser login).
if [ "${1:-}" = "--check" ]; then
    if TS=$(ts_cli); then
        echo "tailscale: installed ($TS)"
        if "$TS" status >/dev/null 2>&1 || { [ -S "$SOCK" ] && "$TS" --socket="$SOCK" status >/dev/null 2>&1; }; then
            echo "tailscale: up"
        else
            echo "tailscale: installed but not up (run without --check to bring it up)"
        fi
    else
        echo "tailscale: not installed (run without --check to set it up)"
    fi
    exit 0
fi

# ---- 1) Already installed? Just use it. ----------------------------------------------------
if TS=$(ts_cli); then
    say "Found existing Tailscale ($TS)."
    if [ -S "$SOCK" ] && ! have tailscale; then
        bring_up_and_report "$TS" --socket="$SOCK"
    else
        bring_up_and_report "$TS"
    fi
    exit 0
fi

# ---- 2) Official installer (uses sudo; the easy path on normal distros) --------------------
say "Tailscale not found. Trying the official installer (you may be asked for your password)…"
if have sudo && curl -fsSL https://tailscale.com/install.sh | sh; then
    if have tailscale; then
        # On systemd distros the installer starts tailscaled automatically.
        bring_up_and_report "tailscale"
        exit 0
    fi
fi
warn "Official install path unavailable (locked-down/immutable system or no sudo)."

# ---- 3) Userspace fallback (no sudo) — works on SteamOS's immutable rootfs ------------------
say "Installing a userspace Tailscale under ~/.local (no sudo)…"
ARCH="amd64"; case "$(uname -m)" in aarch64|arm64) ARCH="arm64";; esac
URL="https://pkgs.tailscale.com/stable/tailscale_${TS_VERSION}_${ARCH}.tgz"
TMP="$(mktemp -d)"
if ! curl -fsSL "$URL" -o "$TMP/ts.tgz"; then
    warn "Could not download $URL — check your internet connection and try again."
    rm -rf "$TMP"; exit 1
fi
tar -xzf "$TMP/ts.tgz" -C "$TMP"
cp "$TMP"/tailscale_*/tailscale  "$LOCAL_BIN/tailscale"
cp "$TMP"/tailscale_*/tailscaled "$LOCAL_BIN/tailscaled"
chmod +x "$LOCAL_BIN/tailscale" "$LOCAL_BIN/tailscaled"
rm -rf "$TMP"

say "Starting tailscaled in userspace-networking mode (no root/TUN required)…"
if ! "$LOCAL_BIN/tailscale" --socket="$SOCK" status >/dev/null 2>&1; then
    nohup "$LOCAL_BIN/tailscaled" \
        --tun=userspace-networking \
        --socket="$SOCK" \
        --statedir="$STATE_DIR" >"$STATE_DIR/tailscaled.log" 2>&1 &
    sleep 2
fi
warn "Userspace mode: the tailnet is reachable for apps that use Tailscale's SOCKS5/HTTP proxy."
warn "For full transparent routing, install Tailscale with root (see the official Steam Deck guide)."
bring_up_and_report "$LOCAL_BIN/tailscale" --socket="$SOCK"
echo
echo "(If '$LOCAL_BIN' is not on your PATH, run tailscale as: $LOCAL_BIN/tailscale status)"
