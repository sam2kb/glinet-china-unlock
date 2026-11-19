# 3. WireGuard client: backend marker and profile

## Symptom

Profile imported, no interface. `wg show interfaces` empty. Dashboard shows nothing to connect.

Cause on the tested build: `/tmp/run/vpn-client-booted` missing. `/usr/bin/rtp2.sh` exits without it.

## Mechanism

```mermaid
flowchart LR
    A[init.d/vpn-client boot] --> B[/tmp/run/vpn-client-booted]
    B --> C[rtp2.sh runs]
    C --> D[wgclient interface]
    D --> E[profile endpoint + DNS]
    E --> F[tunnel]
```

- `/etc/init.d/vpn-client`, start priority 95, `boot()` creates the marker and runtime dirs.
- `/tmp/run/vpn-client-booted` is the marker; `/tmp` does not survive a reboot; the init script recreates it at boot.
- `/usr/bin/rtp2.sh` exits when the marker is absent.
- The backend creates the interface after the marker exists and a profile is imported.

## Walkthrough

1. Back up the config.

```sh
backup=/etc/vpn-backend-backup-$(date -u +%Y%m%dT%H%M%SZ)
mkdir -p "$backup"
cp -p /etc/config/network /etc/config/wireguard /etc/config/route_policy "$backup/" 2>/dev/null || true
```

2. Check the marker.

```sh
ls -l /tmp/run/vpn-client-booted
```

3. If absent, run the boot function once.

```sh
/etc/init.d/vpn-client boot
```

4. Check the interface.

```sh
wg show interfaces
ip -4 addr show <wg-interface>
```

5. Import the profile in the vendor UI.

## Profile fields

| Field | Value |
|---|---|
| Address | `<client-tunnel-address>/32` |
| PrivateKey | `<client-private-key>` |
| DNS | `<tunnel-dns-address>` or the exit's resolver addresses |
| MTU | 1420 |
| PublicKey (peer) | `<exit-public-key>` |
| PresharedKey | `<preshared-key>` |
| Endpoint | `<exit-zt-address>:51820` (the exit's ZeroTier address) |
| AllowedIPs | `0.0.0.0/0`, `::/0` for a full tunnel |
| PersistentKeepalive | 15 |

Template: [templates/wg-client.conf.tpl](../templates/wg-client.conf.tpl).

## The DNS is required

The test: the tunnel came up and handshook, but the clients' requests did not resolve. Setting the exit's resolver addresses on the WireGuard interface fixed it. `dnsmasq` then used those addresses for the tunnel resolver.

- Without the DNS, a handshake can be present and the data path still fail.
- The vendor UI's DNS field and the `[Interface] DNS` line are the same value.

## Verify

```sh
wg show
```

- The interface exists.
- The address is the profile's.
- The endpoint is the exit's ZeroTier address.
- The latest handshake is recent.
- A request through the tunnel resolves and returns data (see 07).

## Pitfalls

- The marker is in `/tmp`; a reboot removes it and the init script recreates it. Check it before changing the profile.
- The boot function is not a reboot.
- Import the profile before the backend start; the interface is created on start.
- The endpoint must be reachable. If it is an overlay address, the overlay must be up first.
- The profile can differ from the UI display; check `wg show`.
- The interface name may be recreated; use `wg show interfaces`.
- A handshake is not data.
- A profile without the DNS can handshake and fail name resolution.
