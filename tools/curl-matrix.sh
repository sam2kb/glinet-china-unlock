#!/bin/sh
# Real HTTPS checks for the router's WAN, tunnel and policy paths.
#
# The script changes nothing on the router except:
#   - a temporary network namespace and veth pair for the isolated client
#   - an optional entry in the policy's source set for the selected-client test
#
# It removes both on exit. Read the comments before running it.

set -u

MODE=${MODE:-all}
WAN_IF=${WAN_IF:-}
WG_IF=${WG_IF:-wgclient1}
LAN_IF=${LAN_IF:-br-lan}
LAN_IP=${LAN_IP:-}
LAN_MAC=${LAN_MAC:-}
LAN_DNS=${LAN_DNS:-}
LAN_GATEWAY=${LAN_GATEWAY:-$LAN_DNS}
LAN_PREFIX=${LAN_PREFIX:-24}
DOMAINS=${DOMAINS:-}
CHECK_URL=${CHECK_URL:-}
SELECT_SET=${SELECT_SET:-}
SELECT_TEST_CLIENT=${SELECT_TEST_CLIENT:-0}
PIN_DOMAIN=${PIN_DOMAIN:-}
PIN_IP=${PIN_IP:-}
LABEL=${LABEL:-manual}
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
OUT=${OUT:-/tmp/curl-matrix/${STAMP}-$$}

NS="cm-$$"
HOST_LINK="cmh-$$"
PEER_LINK="cmp-$$"
NS_CREATED=0
LINK_CREATED=0
RESOLVER_CREATED=0
SET_ADDED=0
FAILED=0
TESTS=0

die() { echo "ERROR: $*" >&2; exit 2; }
log() { echo "== $*" >&2; }

cleanup() {
  if [ "$SET_ADDED" = 1 ]; then
    nft delete element inet vpn_table "$SELECT_SET" "{ \"$LAN_MAC\" }" 2>/dev/null || true
  fi
  if [ "$NS_CREATED" = 1 ]; then
    ip netns del "$NS" 2>/dev/null || true
  fi
  if [ "$RESOLVER_CREATED" = 1 ]; then
    rm -rf "/etc/netns/$NS" 2>/dev/null || true
  fi
  if [ "$LINK_CREATED" = 1 ]; then
    ip link del "$HOST_LINK" 2>/dev/null || true
  fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM

case "$MODE" in
  all|router|lan) ;;
  *) die "MODE must be all, router or lan" ;;
esac

[ -n "$DOMAINS" ] || die "Set DOMAINS to a file with one test hostname per line"
[ -r "$DOMAINS" ] || die "Cannot read $DOMAINS"
[ -n "$CHECK_URL" ] || die "Set CHECK_URL to a URL that returns the address the exit sees"

if [ "$MODE" = all ] || [ "$MODE" = router ]; then
  [ -n "$WAN_IF" ] || die "Set WAN_IF to the WAN interface name"
fi
if [ "$MODE" = all ] || [ "$MODE" = lan ]; then
  [ -n "$LAN_IP" ] || die "Set LAN_IP to an unused test address"
  [ -n "$LAN_MAC" ] || die "Set LAN_MAC to a synthetic test MAC"
  [ -n "$LAN_DNS" ] || die "Set LAN_DNS to the router's LAN address"
fi
if [ "$SELECT_TEST_CLIENT" = 1 ]; then
  [ -n "$SELECT_SET" ] || die "Set SELECT_SET to the policy source set name"
fi

mkdir -p "$OUT"
RES="$OUT/results.tsv"
printf 'context\tdomain\tstatus\tfinal_url\texit_address\ttime_total\n' > "$RES"

state() {
  {
    echo "### date"; date -u
    echo "### wg"; wg show all 2>/dev/null || echo none
    echo "### ip rule"; ip rule show 2>/dev/null
    echo "### ip route"; ip route show 2>/dev/null
    echo "### route_policy"; uci show route_policy 2>/dev/null || echo none
    echo "### vpn table"; nft list table inet vpn_table 2>/dev/null || echo none
    echo "### dns table"; nft list table inet dns_table 2>/dev/null || echo none
    echo "### dnsproxy"; pgrep -f dnsproxy 2>/dev/null || echo none
  } > "$1" 2>&1
}

check_exit() {
  context=$1
  iface=$2
  namespace=$3
  body="$OUT/$context-exit.body"
  hdr="$OUT/$context-exit.headers"
  err="$OUT/$context-exit.err"

  set -- -q -4 --noproxy '*' --fail --location --max-redirs 5 \
    --connect-timeout 6 --max-time 20 --silent --show-error \
    --dump-header "$hdr" --output "$body" \
    --write-out 'status=%{http_code}\ttime=%{time_total}\n'
  [ -n "$iface" ] && set -- "$@" --interface "$iface"
  set -- "$@" "$CHECK_URL"

  TESTS=$((TESTS + 1))
  if [ "$namespace" = 1 ]; then
    ip netns exec "$NS" curl "$@" > "$OUT/tmp.out" 2> "$err"
  else
    curl "$@" > "$OUT/tmp.out" 2> "$err"
  fi
  if [ $? -eq 0 ]; then
    status=$(sed -n 's/^status=\([0-9]*\).*/\1/p' "$OUT/tmp.out" | tail -n 1)
    time=$(sed -n 's/^.*\ttime=\([0-9.]*\).*/\1/p' "$OUT/tmp.out" | tail -n 1)
    exit_addr=$(grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' "$body" 2>/dev/null | head -n 1)
    printf '%s\t(exit-check)\t%s\t%s\t%s\t%s\n' "$context" "${status:-0}" "" "$exit_addr" "${time:-}" >> "$RES"
  else
    rc=$?
    printf '%s\t(exit-check)\tERR(%s)\t\t\t\n' "$context" "$rc" >> "$RES"
    FAILED=$((FAILED + 1))
  fi
}

check_one() {
  context=$1
  domain=$2
  iface=$3
  namespace=$4
  extra=$5
  safe=$(echo "$domain" | tr '/:' '__')
  body="$OUT/$context-$safe.body"
  hdr="$OUT/$context-$safe.headers"
  err="$OUT/$context-$safe.err"

  set -- -q -4 --noproxy '*' --fail --location --max-redirs 5 \
    --connect-timeout 6 --max-time 20 --silent --show-error \
    --dump-header "$hdr" --output "$body" \
    --write-out 'status=%{http_code}\turl=%{url_effective}\ttime=%{time_total}\n'
  [ -n "$iface" ] && set -- "$@" --interface "$iface"
  [ -n "$extra" ] && set -- "$@" $extra
  set -- "$@" "https://$domain/"

  TESTS=$((TESTS + 1))
  if [ "$namespace" = 1 ]; then
    ip netns exec "$NS" curl "$@" > "$OUT/tmp.out" 2> "$err"
  else
    curl "$@" > "$OUT/tmp.out" 2> "$err"
  fi
  if [ $? -eq 0 ]; then
    status=$(sed -n 's/^status=\([0-9]*\).*/\1/p' "$OUT/tmp.out" | tail -n 1)
    url=$(sed -n 's/^.*\turl=\([^\t]*\).*/\1/p' "$OUT/tmp.out" | tail -n 1)
    time=$(sed -n 's/^.*\ttime=\([0-9.]*\).*/\1/p' "$OUT/tmp.out" | tail -n 1)
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$context" "$domain" "${status:-0}" "$url" "" "${time:-}" >> "$RES"
  else
    rc=$?
    printf '%s\t%s\tERR(%s)\t\t\t\n' "$context" "$domain" "$rc" >> "$RES"
    FAILED=$((FAILED + 1))
  fi
}

run_context() {
  context=$1
  iface=$2
  namespace=$3
  check_exit "$context" "$iface" "$namespace"
  while IFS= read -r domain; do
    case "$domain" in
      ''|'#'*) continue ;;
    esac
    extra=""
    if [ -n "$PIN_DOMAIN" ] && [ -n "$PIN_IP" ] && [ "$domain" = "$PIN_DOMAIN" ]; then
      extra="--resolve ${PIN_DOMAIN}:443:${PIN_IP}"
    fi
    check_one "$context" "$domain" "$iface" "$namespace" "$extra"
  done < "$DOMAINS"
}

lan_setup() {
  if ip neigh show "$LAN_IP" 2>/dev/null | grep -q .; then
    die "The test address $LAN_IP already appears in the neighbor table"
  fi
  ip netns add "$NS"
  NS_CREATED=1
  ip link add "$HOST_LINK" type veth peer name "$PEER_LINK"
  LINK_CREATED=1
  ip link set "$PEER_LINK" netns "$NS"
  ip link set "$HOST_LINK" master "$LAN_IF"
  ip link set "$HOST_LINK" up
  ip netns exec "$NS" ip link set lo up
  ip netns exec "$NS" ip link set "$PEER_LINK" address "$LAN_MAC" up
  ip netns exec "$NS" ip addr add "$LAN_IP/$LAN_PREFIX" dev "$PEER_LINK"
  ip netns exec "$NS" ip route add default via "$LAN_GATEWAY"
  mkdir -p "/etc/netns/$NS"
  RESOLVER_CREATED=1
  echo "nameserver $LAN_DNS" > "/etc/netns/$NS/resolv.conf"
}

state "$OUT/state-before.txt"

if [ "$MODE" = all ] || [ "$MODE" = router ]; then
  log "router normal"
  run_context router-normal "" 0
  log "router forced WAN"
  run_context router-wan "$WAN_IF" 0
  if ip link show "$WG_IF" >/dev/null 2>&1; then
    log "router forced tunnel"
    run_context router-wg "$WG_IF" 0
  else
    log "skipping the tunnel context: $WG_IF is not present"
  fi
fi

if [ "$MODE" = all ] || [ "$MODE" = lan ]; then
  lan_setup
  log "isolated client"
  run_context lan "" 1
  if [ "$SELECT_TEST_CLIENT" = 1 ]; then
    nft add element inet vpn_table "$SELECT_SET" "{ \"$LAN_MAC\" }"
    SET_ADDED=1
    log "isolated client added to $SELECT_SET"
    run_context lan-selected "" 1
  fi
fi

state "$OUT/state-after.txt"
echo "Tests: $TESTS, failures: $FAILED" | tee "$OUT/summary.txt"
echo "Results: $RES"
[ "$FAILED" -eq 0 ] || exit 1
exit 0
