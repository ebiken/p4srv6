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

    # Create veth and vtap
    run ip link add veth1 type veth peer name vtap1
    run ip link add veth2 type veth peer name vtap2
    run ip link add vtap11 type veth peer name vtap12
    run ip link add vtap13 type veth peer name vtap14

    # Connect veth between host1 and host2
    run ip link set veth1 netns host1
    run ip link set veth2 netns host2

    # Set IP address
    run ip netns exec host1 ip addr add 172.20.0.1/24 dev veth1
    run ip netns exec host1 ip -6 addr add fd01::1/64 dev veth1
    run ip netns exec host2 ip addr add 172.20.0.2/24 dev veth2
    run ip netns exec host2 ip -6 addr add fd01::2/64 dev veth2

    # Link up loopback and veth
    run ip netns exec host1 ip link set veth1 up
    run ip netns exec host1 ip link set lo up
    run ip netns exec host2 ip link set veth2 up
    run ip netns exec host2 ip link set lo up
    run ip link set dev vtap1 up
    run ip link set dev vtap2 up
    run ip link set dev vtap11 up
    run ip link set dev vtap12 up
    run ip link set dev vtap13 up
    run ip link set dev vtap14 up
}

destroy_network () {
    echo "destroy_network"
    # paired interface will be automatically deleted (ex: vtap1 for veth1)
    #silent ip link del veth0
    silent ip link del veth1
    silent ip link del veth2
    silent ip link del vtap11
    silent ip link del vtap13

    #silent ip netns del host0
    silent ip netns del host1
    silent ip netns del host2
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
Create 2 netns with tap interface visible to default ns as vtap1, vtap2.

 ns:host1   ns:host2
 +-------+  +-------+  veth1:172.20.0.1/24
 | veth1 |  | veth2 |
 +---+---+  +---+---+  veth2:172.20.0.2/24
     |          |
   vtap1      vtap2

vtap11,12,13,14 will be also created to link between switch ports.
EOF
