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

    # Create veth and vtap
    run ip link add veth1 type veth peer name vtap1
    run ip link add veth2 type veth peer name vtap2
    run ip link add veth3 type veth peer name vtap3

    # Connect veth to host1, host2, host3
    run ip link set veth1 netns host1
    run ip link set veth2 netns host2
    run ip link set veth3 netns host3

    # Set IP address (IPv4 Only for L2Fwd)
    run ip netns exec host1 ip addr add 172.20.0.1/24 dev veth1
    run ip netns exec host1 ip link set veth1 address 02:03:04:05:06:01
    #run ip netns exec host1 ip -6 addr add fd01::1/64 dev veth1
    run ip netns exec host2 ip addr add 172.20.0.2/24 dev veth2
    run ip netns exec host2 ip link set veth2 address 02:03:04:05:06:02
    #run ip netns exec host2 ip -6 addr add fd01::2/64 dev veth2
    run ip netns exec host3 ip addr add 172.20.0.3/24 dev veth3
    run ip netns exec host3 ip link set veth3 address 02:03:04:05:06:03
    #run ip netns exec host3 ip -6 addr add fd01::3/64 dev veth3

    # Link up loopback and veth
    run ip netns exec host1 ip link set veth1 up
    run ip netns exec host1 ip link set lo up
    run ip netns exec host2 ip link set veth2 up
    run ip netns exec host2 ip link set lo up
    run ip netns exec host3 ip link set veth3 up
    run ip netns exec host3 ip link set lo up
    run ip link set dev vtap1 up
    run ip link set dev vtap2 up
    run ip link set dev vtap3 up
}

destroy_network () {
    echo "destroy_network"
    # paired interface will be automatically deleted (ex: vtap1 for veth1)
    #silent ip link del veth0
    silent ip link del veth1
    silent ip link del veth2
    silent ip link del veth3

    #silent ip netns del host0
    silent ip netns del host1
    silent ip netns del host2
    silent ip netns del host3
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
Create 3 netns with tap interface visible to default ns as vtap1,2,3.
IPv4 and MAC address is statically configured for each veth.

 veth1: 172.20.0.1/24, 0203:0405:0601
 veth2: 172.20.0.2/24, 0203:0405:0602
 veth3: 172.20.0.3/24, 0203:0405:0603

 ns:host1   ns:host2   ns:host3
 +-------+  +-------+  +-------+
 | veth1 |  | veth2 |  | veth3 |
 +---+---+  +---+---+  +---+---+
     |          |          |
   vtap1      vtap2      vtap3

EOF
