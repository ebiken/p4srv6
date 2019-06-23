#! /bin/bash

# This script will create(remove) veth/host attached to namespace
# and corresponding tap interface.

if [[ $(id -u) -ne 0 ]] ; then echo "Please run with sudo" ; exit 1 ; fi

set -e

if [ -n "$SUDO_UID" ]; then
    uid=$SUDO_UID
else
    uid=$UID
fi

run () {
    echo "$@"
    "$@" || exit 1
}

silent () {
    "$@" 2> /dev/null || true
}

create_network () {
    echo "create_network"
    # Create network namespaces
    # add host0 if you want to keep id inline with ns name
    #run ip netns add host0
    run ip netns add host1
    run ip netns add host2
    run ip netns add host3
    run ip netns add host4

    # Create veth and vtap
    run ip link add veth1 type veth peer name vtap1
    run ip link add veth2 type veth peer name vtap2
    run ip link add veth3 type veth peer name vtap3
    run ip link add veth4 type veth peer name vtap4

    # Add veth to host1, host2, host3 and vtap to host4
    run ip link set veth1 netns host1
    run ip link set veth2 netns host2
    run ip link set veth3 netns host3
    run ip link set veth4 netns host2
    run ip link set vtap4 netns host4

    # Set IP address
    run ip netns exec host1 ip -6 addr add fd01::1/64 dev veth1
    run ip netns exec host2 ip -6 addr add fd01::2/64 dev veth2
    run ip netns exec host2 ip -6 addr add fdff::3/64 dev veth4
    run ip netns exec host3 ip -6 addr add fd01::3/64 dev veth3
    run ip netns exec host4 ip -6 addr add fdff::4/64 dev vtap4

    # Link up loopback and veth
    run ip netns exec host1 ip link set veth1 up
    run ip netns exec host1 ip link set lo up
    run ip netns exec host2 ip link set veth2 up
    run ip netns exec host2 ip link set veth4 up
    run ip netns exec host2 ip link set lo up
    run ip netns exec host3 ip link set veth3 up
    run ip netns exec host3 ip link set lo up
    run ip link set dev vtap1 up
    run ip link set dev vtap2 up
    run ip link set dev vtap3 up
    run ip netns exec host4 ip link set dev vtap4 up
    run ip netns exec host4 ip link set dev lo up

    # make sure to disable checksum offloading
    run ip netns exec host1 ethtool --offload veth1 rx off tx off
    run ip netns exec host2 ethtool --offload veth2 rx off tx off
    run ip netns exec host2 ethtool --offload veth4 rx off tx off
    run ip netns exec host3 ethtool --offload veth3 rx off tx off

    # add route on host3, host4
    run ip netns exec host3 ip -6 route add fdff::/64 via fd01::2
    run ip netns exec host4 ip -6 route add fd01::/64 via fdff::3
    # enable packet forwarding on host2, host3
    run ip netns exec host2 sysctl -w net.ipv6.conf.all.forwarding=1
    run ip netns exec host3 sysctl -w net.ipv6.conf.all.forwarding=1
}

destroy_network () {
    echo "destroy_network"
    # paired interface will be automatically deleted (ex: vtap1 for veth1)
    #silent ip link del veth0
    run ip link del vtap1
    run ip link del vtap2
    run ip link del vtap3
    run ip netns exec host4 ip link del vtap4

    #silent ip netns del host0
    run ip netns del host1
    run ip netns del host2
    run ip netns del host3
    run ip netns del host4
}

while getopts "cd" ARGS;
do
    case $ARGS in
    c ) create_network
        exit 1;;
    d ) destroy_network
        exit 1;;
    esac
done

echo "Usage: $0 -{c|d} (c: create, d:delete)"
cat << EOF
netns, veth: <IPv4>, <IPv6>
    host1, veth1: fd01::1/64
    host2, veth2: fd01::2/64
    host2, veth4: fdff::3/64
    host3, veth3: fd01::3/64
    default, vtap4: fdff::4/64
vtap:
    vtap1, vtap2, vtap3, vtap4

Create 4 netns with tap interface visible to default ns as vtap1/2/3/4.

 ns:host1   ns:host3   ns:host2          ns:host4
 +-------+  +-------+  +--------------+  +-------+
 | veth1 |  | veth3 |  | veth2  veth4 +--+ vtap4 |
 +---+---+  +---+---+  +---+------+---+  +-------+
     |          |          |
   vtap1      vtap3      vtap2

* checksum offloading disabled on all veth
* host3: route to fdff::/64 via fd01::2
* host4: route to fd01::/64 via fdff::3
* host3, host2: sysctl -w net.ipv6.conf.all.forwarding=1
EOF
