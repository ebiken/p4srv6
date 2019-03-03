# demo1 : How To run SRv6 Mobile Uplane POC (drop in replacement of GTP)

This document describes how to reproduce POC of SRv6 Mobile User Plane "drop in replacement of GTP" using BMv2 and netns.
Please make sure to use the p4srv6 version specified in the document. It's NOT expected to run in recent p4srv6, since it's actively developed and table attributes and format of runtime_CLI command to configure entries in the table could change.

SRv6 functions used: End, End.M.GTP4.E, T.M.Tmap from [draft-ietf-dmm-srv6-mobile-uplane-03](https://datatracker.ietf.org/doc/draft-ietf-dmm-srv6-mobile-uplane/03/)
> Note: T.M.Tmap is modified to support insertion of SRH/SID

Steps in this documet was tested on Ubuntu 18.04.1 LTS.

## diagram

For simplisity, PortFwd table is used to forward packets instead of L2/L3 forwarding tables.

![demo1 diagram](demo1-diagram.png)

## Install

### Install tshark

```
$ sudo apt install tshark
$ sudo usermod -a -G wireshark <username>
```

### Install libgtpnl (GTP-U client/server)

libgtpnl is a tool to configure GTP Kernel module via netlink.

> Refer to [Slideshare: Using GTP on Linux with libgtpnl](https://www.slideshare.net/kentaroebisawa/using-gtp-on-linux-with-libgtpnl) for details.

```
> Install prerequisites

$ sudo apt install libmnl-dev autoconf libtool

> Clone source code, configure and build

$ git clone git://git.osmocom.org/libgtpnl.git
$ cd libgtpnl
~/libgtpnl$ autoreconf -fi
~/libgtpnl$ ./configure
~/libgtpnl$ make
~/libgtpnl$ sudo make install
~/libgtpnl$ sudo ldconfig

> Check gtp-link and gtp-tunnel are built

~/libgtpnl$ cd tools
~/libgtpnl/tools$ ./gtp-link
Usage: ./gtp-link <add|del> <device>
~/libgtpnl/tools$ ./gtp-tunnel
./gtp-tunnel <add|delete|list> [<options,...>]
```

### Install p4c and behavior-model (BMv2)

You can use convenient script `install-p4dev-p4runtime.sh` written by Andy Fingerhut to install p4c and bmv2.
> See original page [README-install-troubleshooting.md](https://github.com/jafingerhut/p4-guide/blob/master/bin/README-install-troubleshooting.md) for the most updated informaiton.

```
$ git clone https://github.com/jafingerhut/p4-guide.git
$ cd p4-guide/bin/
~/p4-guide/bin$ ./install-p4dev-p4runtime.sh
~/p4-guide/bin$ cat p4setup.bash >> ~/.bashrc
```

## Clone and Build p4srv6

```
$ git clone https://github.com/ebiken/p4srv6.git
$ cd p4srv6
>>> TODO: checkout correct checkin

~/p4srv6$ p4c --target bmv2 --arch v1model p4src/switch.p4
```

## Run p4srv6

create namespace and assign IP address

```
~/p4srv6/demo/srv6$ sudo ./ns-hosts-srv6-demo1.sh -c
```

```
Usage: ./ns-hosts-srv6-demo1.sh -{c|d} (c: create, d:delete)

netns/veth:
    host1, veth1:172.20.0.1/24, fd01::1/64
    host2, veth2:172.20.0.2/24, fd01::2/64
vtap:
    vtap1, vtap2, vtap11, vtap12, vtap13, vtap14

Create 2 netns with tap interface visible to default ns as vtap1, vtap2.

 ns:host1   ns:host2
 +-------+  +-------+  veth1:172.20.0.1/24
 | veth1 |  | veth2 |
 +---+---+  +---+---+  veth2:172.20.0.2/24
     |          |
   vtap1      vtap2

vtap11,12,13,14 will be also created to link between switch ports.
```

make sure to disable checksum offloading

```
sudo ip netns exec host2 ethtool --offload veth2 rx off tx off
sudo ip netns exec host1 ethtool --offload veth1 rx off tx off
```

Run simple_switch

```
~/p4srv6$ sudo simple_switch switch.json -i 1@vtap1 -i 2@vtap2 -i 11@vtap11 -i 12@vtap12 -i 13@vtap13 -i 14@vtap14 --nanolog \
ipc:///tmp/bm-0-log.ipc --log-console -L debug --notifications-addr \
ipc:///tmp/bmv2-0-notifications.ipc
```

Configure PortFwd table (Layer 1 forwarding)

```
$ runtime_CLI.py
table_add portfwd set_egress_port 1 => 11
table_add portfwd set_egress_port 11 => 1
table_add portfwd set_egress_port 12 => 13
table_add portfwd set_egress_port 13 => 12
table_add portfwd set_egress_port 14 => 2
table_add portfwd set_egress_port 2 => 14
```

Confirm you can ping between host0/1 via P4 switch.

```
# ip netns exec host1 ping 172.20.0.2
# ip netns exec host1 ping6 fd01::2
```

Create GTP interface/tunnel

```
# ip netns exec host1 ip addr add 172.99.0.1/32 dev lo
# cd libgtpnl/tools
~/libgtpnl/tools# ip netns exec host1 ./gtp-link add gtp1
(open new window)
# cd libgtpnl/tools
~/libgtpnl/tools# ip netns exec host1 ./gtp-tunnel add gtp1 v1 200 100 172.99.0.2 172.20.0.2
~/libgtpnl/tools# ip netns exec host1 ip route add 172.99.0.2/32 dev gtp1
~/libgtpnl/tools# ip netns exec host2 ip addr add 172.99.0.2/32 dev lo
~/libgtpnl/tools# ip netns exec host2 ./gtp-link add gtp2
(open new window)
# cd libgtpnl/tools
~/libgtpnl/tools# ip netns exec host2 ./gtp-tunnel add gtp2 v1 100 200 172.99.0.1 172.20.0.1
~/libgtpnl/tools# ip netns exec host2 ip route add 172.99.0.1/32 dev gtp2
```

Use tshark to confirm GTP encap/decap by Linux Kernel module is working

```
# ip netns exec host1 ping 172.99.0.2

$ tshark -i vtap11
Capturing on 'vtap11'
    1 0.000000000   172.99.0.1 Å® 172.99.0.2   GTP <ICMP> 134 Echo (ping) request  id=0x198d, seq=1/256, ttl=64
    2 0.050494478   172.99.0.2 Å® 172.99.0.1   GTP <ICMP> 134 Echo (ping) reply    id=0x198d, seq=1/256, ttl=64 (request in 1)
```

Config SRv6 tables : T.M.Tmap => END => End.M.GTP4.E

```
$ runtime_CLI.py
table_add srv6_transit_udp t_m_tmap_sid1 2152 => 0xfc345678 0xfd000000000000000000000000000001 0xfd010100000000000000000000000001
table_add srv6_end end 0xfd010100000000000000000000000001&&&0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF => 100
table_add srv6_end end_m_gtp4_e 0xfc345678000000000000000000000000&&&0xFFFFFFFF000000000000000000000000 => 100
```

Use tshark to confirm GTP to SRv6 to GTP translation is working

> tshark output is trimmed for ease of view.  
> Check packet dump files for details : demo1-veth1.trc, demo1-veth2.trc, demo1-vtap11.trc, demo1-vtap13.trc

```
$ ip netns exec host1 ping 172.99.0.2

$ sudo ip netns exec host1 tshark -i veth1
    1 0.000000000   172.99.0.1 Å® 172.99.0.2   GTP <ICMP> 134 Echo (ping) request  id=0x1b5f, seq=1/256, ttl=64
    2 0.054819855   172.99.0.2 Å® 172.99.0.1   GTP <ICMP> 134 Echo (ping) reply    id=0x1b5f, seq=1/256, ttl=64 (request in 1)

$ tshark -i vtap11 -O ipv6
Capturing on 'vtap11'
Frame 1: 178 bytes on wire (1424 bits), 178 bytes captured (1424 bits) on interface 0
Ethernet II, Src: f2:c0:31:e5:84:8a (f2:c0:31:e5:84:8a), Dst: 8a:b6:22:25:ca:39 (8a:b6:22:25:ca:39)
Internet Protocol Version 6, Src: fd00::1, Dst: fd01:100::1
 ...
    Payload Length: 124
    Next Header: Routing Header for IPv6 (43)
    Hop Limit: 64
    Source: fd00::1
    Destination: fd01:100::1
    Routing Header for IPv6 (Segment Routing)
        Next Header: IPIP (4)
        Length: 4
        [Length: 40 bytes]
        Type: Segment Routing (4)
        Segments Left: 1
        First segment: 1
        Reserved: 0000
        Address[0]: fc34:5678:ac14:2:ac14:1:0:64 [next segment]
        Address[1]: fd01:100::1
        [Segments in Traversal Order]
            Address[1]: fd01:100::1
            Address[0]: fc34:5678:ac14:2:ac14:1:0:64 [next segment]
Internet Protocol Version 4, Src: 172.99.0.1, Dst: 172.99.0.2
Internet Control Message Protocol

$ tshark -i vtap13 -O ipv6
Frame 1: 178 bytes on wire (1424 bits), 178 bytes captured (1424 bits) on interface 0
Internet Protocol Version 6, Src: fd00::1, Dst: fc34:5678:ac14:2:ac14:1:0:64
 ...
    Payload Length: 124
    Next Header: Routing Header for IPv6 (43)
    Hop Limit: 64
    Source: fd00::1
    Destination: fc34:5678:ac14:2:ac14:1:0:64
    Routing Header for IPv6 (Segment Routing)
        Next Header: IPIP (4)
        Length: 4
        [Length: 40 bytes]
        Type: Segment Routing (4)
        Segments Left: 0
        First segment: 1
        Flags: 0x00
        Reserved: 0000
        Address[0]: fc34:5678:ac14:2:ac14:1:0:64
        Address[1]: fd01:100::1
        [Segments in Traversal Order]
            Address[1]: fd01:100::1
            Address[0]: fc34:5678:ac14:2:ac14:1:0:64
Internet Protocol Version 4, Src: 172.99.0.1, Dst: 172.99.0.2
Internet Control Message Protocol

$ sudo ip netns exec host2 tshark -i veth2
    1 0.000000000   172.99.0.1 Å® 172.99.0.2   GTP <ICMP> 134 Echo (ping) request  id=0x1b5f, seq=1/256, ttl=64
    2 0.000073903   172.99.0.2 Å® 172.99.0.1   GTP <ICMP> 134 Echo (ping) reply    id=0x1b5f, seq=1/256, ttl=64 (request in 1)
```

