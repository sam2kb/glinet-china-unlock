# 6. Findings

## Worked

- Removing `lang_hide` exposed every hidden page: VPN client, dashboard, OpenVPN server, WireGuard server, AdGuard Home, Tor, Dynamic DNS.
- The backend boot function created the marker and the interface.
- The policy matched the selected source MAC and the resolved destination addresses, and routed them through the WireGuard interface.
- Hardware acceleration off made the marked forwarding work.
- The vendor DNS page + dnsproxy + dnsmasq + port 53 redirect chain worked.
- Key-only SSH from LAN and ZeroTier worked with the interface list at all.
- WireGuard over the exit's ZeroTier address carried data after the direct endpoint did not.
- The tunnel DNS on the WireGuard interface fixed name resolution.
- The ZeroTier route survived a reboot.

## Failed or surprised

- Direct WireGuard handshook without carrying data.
- The UI reported no internet while data worked (`track_ip` targets).
- The VPN pages were hidden by a menu property, not missing packages.
- The backend did not start from the profile alone; the marker was required.
- The policy rule did nothing until DNS filled the destination set.
- Client-side secure DNS bypassed the marking.
- Marked forwarding failed with hardware acceleration on.
- The WireGuard tunnel handshook without the interface DNS and failed name resolution.
- Binding SSH to the ZeroTier interface broke SSH over the overlay.
- The exit peer counters showed an unexplained send/receive asymmetry.
- The ZeroTier path was relayed at one point and direct at another; the version difference was present but not proven.
- Tor and AdGuard Home each warn that enabling them breaks the VPN/DNS setup.

## Unproven

- Whether the direct WireGuard loss was filtering or a path fault.
- The counter asymmetry cause.
- Whether the relay came from the ZeroTier version or the network.
- Full hostname coverage for the listed services.
- Real browser behavior versus the isolated client.
- The hardware-offload mechanism beyond the observed behavior.
- Another self-hosted WireGuard implementation beyond OPNsense.
- The country-code unlock route on this model.

## Do not conflate

| Evidence | Proves |
|---|---|
| WireGuard handshake | keys and UDP path |
| ZeroTier ping | overlay path |
| HTTP 200 through tunnel | data path for that request |
| Destination set populated | DNS went through the router for a listed name |
| Mark present | policy matched that source and destination |
| Page visible | menu entry exposed, service not necessarily enabled |

## Limits

- The isolated client is a namespace with a synthetic MAC; no browser trust store, client secure DNS or Wi-Fi driver.
- One pass is not proof; test a second name and address.
- Counters and conntrack are point-in-time.
- The exit was one OPNsense instance; other implementations differ at the firewall and UI.
