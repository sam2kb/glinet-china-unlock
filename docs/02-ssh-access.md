# 2. SSH access

## Target state

| Item | Value |
|---|---|
| Auth | key only |
| Port | 22 |
| Password auth | off |
| Root password auth | off |
| Interface | all |
| WAN | closed |
| ZeroTier zone | input ACCEPT |
| Vendor UI SSH boxes | unchecked |

## Walkthrough

1. Leave the vendor UI's SSH access checkboxes unchecked.
2. Open LuCI's SSH Access page (System → Administration → SSH Access).
3. Set port 22, password authentication off, root password authentication off.
4. Add the workstation's public key to the root account.
5. Leave the interface list at all. Do not bind to the ZeroTier interface (see below).
6. Confirm the firewall zones: WAN closed, ZeroTier input ACCEPT.

## Config

```sh
uci show dropbear
```

```text
dropbear.@dropbear[0].PasswordAuth='off'
dropbear.@dropbear[0].Port='22'
dropbear.@dropbear[0].enable='1'
dropbear.@dropbear[0].RootPasswordAuth='off'
```

```sh
uci -q get firewall.@defaults[0].input   # REJECT
uci -q get firewall.zerotier.input       # ACCEPT
uci -q get firewall.wan6.input           # DROP
uci -q get firewall.wgclient1.input      # DROP
uci show wan-access                      # whitelist='0'
```

ZeroTier zone:

```text
config zone
    option name 'zerotier'
    option network 'zerotier'
    option input 'ACCEPT'
    option output 'ACCEPT'
    option forward 'REJECT'
```

## Interface binding failure

Selecting the ZeroTier interface in the SSH Access page broke SSH over the overlay: the connection stopped answering. The tested config leaves the interface list at all and relies on the firewall zone.

Not isolated: whether the cause was the interface option, the overlay coming up after the SSH service, or the dropbear bind. The working configuration is the all-interface list plus the zone input policy.

## Verify

```sh
ssh -p 22 root@<router-lan-address>   # from the LAN
ssh -p 22 root@<zt-address>           # over ZeroTier
```

- Password login fails.
- The WAN port is unreachable without the overlay.
- `uci show dropbear` shows the password options off.

## Pitfalls

- The vendor UI and LuCI both write dropbear settings; the vendor boxes can reopen the service or reset auth.
- Binding to the ZeroTier interface breaks SSH on the tested router.
- The ZeroTier zone's input ACCEPT opens every router service to every authorized member. Authorize only your members.
- A firmware update can reset dropbear or the vendor UI boxes.
- A reauthorized ZeroTier member can get a new address; confirm the host key change.
- The private key stays on the workstation.
