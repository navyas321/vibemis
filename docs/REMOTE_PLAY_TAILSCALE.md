# Remote play over Tailscale

Stream to your gaming PC from anywhere — coffee shop, hotel, another house — as if you were on the
same LAN, without port-forwarding or exposing anything to the public internet. Vibemis pairs with
[Tailscale](https://tailscale.com), a zero-config WireGuard mesh VPN, so your handheld and host get
stable private `100.x.y.z` addresses that work across networks.

## What you need
- Your **host PC** running Apollo/Vibepollo (or Sunshine) **and** Tailscale, signed into your tailnet.
- Your **client** (Legion Go S / SteamOS, or any Linux) with Vibemis.
- One Tailscale account (free tier is plenty) on both devices.

## Setup (client side)
1. **Get on the tailnet.** Run the helper:
   ```bash
   ./scripts/setup-tailscale.sh
   ```
   It installs Tailscale if needed (with a no-sudo userspace fallback for SteamOS's immutable
   rootfs), then runs `tailscale up` and prints a login URL — open it once and sign in. Re-runnable
   and idempotent. Check status anytime with `./scripts/setup-tailscale.sh --check`.
2. **Tell Vibemis to prefer tailnet addresses.** In **Settings → enable "Prefer Tailscale addresses
   for remote play"** (test51). Vibemis will then reach hosts by their `100.x` / MagicDNS address
   first, so the same host entry works on LAN *and* remotely.
3. **Add / stream your host** by its Tailscale IP (`100.x.y.z`) or MagicDNS name (`myhost.tailnet.ts.net`).
   Pair once (the PIN flow is the same as on LAN); after that it just connects.

You can do steps via the guided flow too: `./scripts/vibemis-setup.sh --host myhost.tailnet.ts.net`.

## Tips
- **MagicDNS** (enable it in the Tailscale admin console) lets you use `myhost` instead of the IP.
- **Quality on the go:** remote links are usually slower than LAN. Lower the bitrate (the data-usage
  estimate under the slider helps), and once it's available, the **Adaptive bitrate** setting
  (experimental, test62) eases stutter on flaky links.
- **Latency:** Tailscale prefers a direct WireGuard path; if a connection falls back to a DERP relay
  it'll be higher latency. `tailscale status` shows `direct` vs `relay`.
- **Battery:** userspace mode on SteamOS routes via a local proxy — fine for streaming, but for full
  transparent routing install Tailscale with root per Tailscale's Steam Deck guide.

## Security
Traffic is end-to-end encrypted (WireGuard) and stays within your tailnet — nothing is exposed to the
public internet, and no router ports are opened. Only devices signed into *your* Tailscale account can
see the host.

## Troubleshooting
- `setup-tailscale.sh --check` → shows installed / up state.
- Host not appearing? Confirm both devices show in `tailscale status` and the host's Tailscale is up.
- `vibemis-doctor.sh <host-tailscale-ip>` tests reachability + the streaming port from the client.
