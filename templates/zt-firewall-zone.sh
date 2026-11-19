#!/bin/sh
# Create a firewall zone for the ZeroTier interface so overlay members can
# reach the router's SSH and web UI, and forward through it if needed.
#
# Set ZT_NETWORK to the UCI network name of the ZeroTier interface, for example
# the name shown by `uci show network | grep -i zerotier`.
#
# The zone's input policy accepts every service the router listens on, from
# every authorized member of the overlay. Keep the overlay private and
# authorize only the members you control.

set -eu
: "${ZT_NETWORK:?Set ZT_NETWORK to the ZeroTier UCI network name}"

uci set firewall.zerotier=zone
uci set firewall.zerotier.name='zerotier'
uci set firewall.zerotier.network="$ZT_NETWORK"
uci set firewall.zerotier.input='ACCEPT'
uci set firewall.zerotier.output='ACCEPT'
uci set firewall.zerotier.forward='REJECT'
uci set firewall.zerotier.masq='1'
uci set firewall.zerotier.mtu_fix='1'
uci commit firewall
/etc/init.d/firewall reload

echo "ZeroTier zone set on network $ZT_NETWORK"
echo "Check the zone on the router's firewall page before relying on it."
