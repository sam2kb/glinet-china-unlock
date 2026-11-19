#!/bin/sh
# Point the vendor internet check at addresses that are reachable from your WAN.
# Set TRACK_IP to one or two addresses, separated by a space and quoted.
#
# Use addresses you control or are allowed to probe. The check re-evaluates
# on its next cycle or after a reboot.

set -eu
: "${TRACK_IP:?Set TRACK_IP to one or two reachable addresses, quoted}"

uci set glconfig.general.track_ip="$TRACK_IP"
uci commit glconfig

echo "track_ip set to: $TRACK_IP"
