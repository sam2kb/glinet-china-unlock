# 7. Verification

## Contexts

| Context | What it tests |
|---|---|
| `router-normal` | router routing and policy |
| `router-wan` | request bound to the WAN interface |
| `router-wg` | request bound to the WireGuard interface |
| `lan` | isolated client with a synthetic MAC, router as gateway and DNS |
| `lan-selected` | same client added to the policy source set |

Each context requests the check URL first (exit address), then each test hostname.

## Script

[tools/curl-matrix.sh](../tools/curl-matrix.sh)

```sh
MODE=all \
WAN_IF=<wan-interface> \
WG_IF=<wg-interface> \
LAN_IF=br-lan \
LAN_IP=<unused-test-address> \
LAN_MAC=<synthetic-test-mac> \
LAN_DNS=<router-lan-address> \
DOMAINS=/tmp/test-domains.txt \
CHECK_URL=<check-url> \
SELECT_SET=<source-set-name> \
SELECT_TEST_CLIENT=1 \
sh tools/curl-matrix.sh
```

Requirements: `ip`, `curl`, `nft`, `nslookup`, `timeout`, `sed`, `grep`, `tee`; `ip netns` support. The test address must be unused and outside the DHCP pool.

## Checks

Per name:

- real HTTPS GET, redirects followed, certificate verified
- status, final URL, TTFB, total time
- exit address from the check URL
- DNS answers for the name

State before/after:

- `wg show all` (no private keys)
- `route_policy`, `nft` sets, `ip rule`, table route
- dnsproxy, dnsmasq upstream
- conntrack for the test addresses

Results: `results.tsv`, raw headers/bodies, state snapshots.

## Reading results

| Observation | Meaning |
|---|---|
| Exit address = exit public address | tunnel used |
| Exit address = WAN public address | WAN used |
| Timeout with recent handshake | data path/MTU/DNS, not keys |
| Name fails only in isolated client | DNS path |
| Selected context changes result | policy match |

## Pitfalls

- Router and isolated client DNS answers can differ; record both.
- Pinning a name to an address bypasses the DNS step; keep pinned and unpinned results separate.
- Client-side DoH/DoT bypasses the router resolver; the isolated client uses the router.
- A proxy or client VPN changes the path before the router sees it.
- One success is not a full pass.
- The check URL must be one you are allowed to use.
- The namespace and the optional set entry must be cleaned up after a failed run.
- Concurrent traffic makes counters and conntrack noisy.
