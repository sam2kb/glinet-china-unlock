# tools

## curl-matrix.sh

The script makes real HTTPS requests from several contexts and records what each one used:

- `router-normal`: the router's own routing, policy included
- `router-wan`: a request bound to the WAN interface
- `router-wg`: a request bound to the WireGuard interface
- `lan`: an isolated client with a synthetic MAC, using the router as gateway and DNS
- `lan-selected`: the same client, added to the policy's source set

Each context first requests `CHECK_URL` to see the address the exit reports, then requests each name in the domains file.

The script changes nothing except the temporary namespace and, if `SELECT_TEST_CLIENT=1`, the one set entry it deletes on exit. It does not restart services and does not edit the configuration.

## Requirements

- `ip`, `curl`, `nft`, `nslookup`, `timeout`, `sed`, `grep`, `tee` on the router
- `ip netns` support for the isolated client
- a domains file you are allowed to test
- a check URL that returns the address the exit sees

## Variables

| Variable | Meaning |
|---|---|
| `MODE` | `all`, `router` or `lan` (default `all`) |
| `WAN_IF` | the WAN interface name, required for the router contexts |
| `WG_IF` | the WireGuard interface name (default `wgclient1`) |
| `LAN_IF` | the LAN bridge (default `br-lan`) |
| `LAN_IP` | an unused test address on the LAN |
| `LAN_MAC` | a synthetic MAC for the test client |
| `LAN_DNS` | the router's LAN address, used as the namespace resolver |
| `LAN_GATEWAY` | the namespace default gateway (defaults to `LAN_DNS`) |
| `LAN_PREFIX` | the test address prefix (default `24`) |
| `DOMAINS` | the file with one test hostname per line |
| `CHECK_URL` | the URL that returns the exit's address |
| `SELECT_SET` | the policy's source set name, required for `SELECT_TEST_CLIENT=1` |
| `SELECT_TEST_CLIENT` | `1` to add the test MAC to the set and run the selected context |
| `PIN_DOMAIN`, `PIN_IP` | optional control: resolve one test name to a fixed address |
| `LABEL` | a label for the output directory |
| `OUT` | the output directory (default under `/tmp/curl-matrix`) |

The test address must be unused and outside the DHCP pool. The script checks the neighbor table and refuses to continue if the address appears there. That check is a guard; confirm on the router before a run.

## Usage

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

The `<...>` values are placeholders. Do not commit a filled command line or the domains file.

## Output

`results.tsv` has one row per request: the context, the name, the status, the final URL, the exit address and the total time. The raw headers and bodies, the state snapshots and the summary are in the same directory.

The exit address column is filled on the `(exit-check)` row for each context. A context whose exit address matches the exit's public address used the tunnel; one that matches the WAN address used the WAN.

## Limits

- The isolated client is a network namespace with a synthetic MAC. It reproduces the routing, the policy match and the DNS path. It does not reproduce a browser's trust store, a client's own secure DNS, or a Wi-Fi driver.
- The check URL returns one address. A service behind a CDN can answer from different addresses; that is not a tunnel failure.
- One successful request is a start, not a full pass. Test a second name and a second address.
- The state snapshots are point-in-time. Concurrent traffic makes the counters and conntrack noisy.

## Cleanup

The script traps its exit and removes the namespace, the veth pair, the resolver file and the optional set entry. If a run is interrupted, check the router for a leftover namespace or set entry.
