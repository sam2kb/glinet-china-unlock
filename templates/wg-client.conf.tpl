# Client WireGuard profile template.
# Replace every <...> placeholder. Do not commit a filled copy.
# The endpoint is the exit's ZeroTier address, not its public address.

[Interface]
Address = <client-tunnel-address>/32
PrivateKey = <client-private-key>
# The resolver the tunnel uses. Add the exit's resolver address, or both
# addresses the exit provides. Without it the handshake can work and the
# clients' requests still fail.
DNS = <tunnel-dns-address>
MTU = 1420

[Peer]
PublicKey = <exit-public-key>
PresharedKey = <preshared-key>
Endpoint = <exit-zt-address>:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 15
