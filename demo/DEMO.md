# How to run demo?

Compile P4.
```
p4c -x p4-14 p4srv6.p4
```

Create 2 name spaces as host.
```
sudo ./tools/namespace-hosts.sh -c
```

Run switch
```
>> simple_switch is from bmv2.
>> ex: ~/p4lang/bmv2/targets/simple_switch/simple_switch
sudo simple_switch p4srv6.json -i 0@vtap0 -i 1@vtap1 -i 2@vtap102 -i 3@vtap103 \
--log-console -L debug -- nanolog ipc:///tmp/bm-0-log.ipc --notifications-addr \
ipc:///tmp/bmv2-0-notifications.ipc
```

Run P4 runtime CLI
```
~/p4lang/bmv2/targets/simple_switch/runtime_CLI
```

Enter table entry.
```
>> RuntimeCmd: help table_add
>> Add entry to a match table:
>>   table_add <table name> <action name> <match fields> => <action parameters> [priority]
RuntimeCmd:
//table_add fwd forward 0 => 1
//table_add fwd forward 1 => 0
table_add fwd forward 0 => 2
table_add fwd forward 2 => 0
table_add fwd forward 1 => 3
table_add fwd forward 3 => 1

table_add srv6_localsid srv6_T_Insert1 db8::2 => db8::11
table_add srv6_localsid srv6_T_Insert2 db8::2 => db8::21 db8::22
table_add srv6_localsid srv6_T_Insert3 db8::2 => db8::31 db8::32 db8::33
>> srcAddr=db8::1:11, sid0=db8::11
table_add srv6_localsid srv6_T_Encaps1 db8::2 => db8::1:11 db8::11
table_add srv6_localsid srv6_T_Encaps2 db8::2 => db8::1:11 db8::21 db8::22
table_add srv6_localsid srv6_T_Encaps3 db8::2 => db8::1:11 db8::31 db8::32 db8::33

>> srcAddr=db8::1:11, sid0=db8::11
table_add srv6_localsid srv6_End_M_GTP6_D3 db8::2 => db8::1:11 db8::31 db8::32 db8::33
table_add srv6_localsid srv6_End_M_GTP6_D3 db8::2:2 => db8::1:11 db8::31 db8::32 db8::33
```

Ping from host0 (172.20.0.1/db8::1) to host1 (172.20.0.2/db8::2)
Capture packet on host1 to confirm SRH is inserted.
```
# ip netns exec host1 tcpdump -i veth1 -w p4srv6-test.trc

# ip netns exec host0 ping 172.20.0.2
# ip netns exec host0 ping6 db8::2
```

## GTP encap table/action

gtpu_encap_v6 table and action can be used to generate IPv6 over GTP-U over UDP/IPv6.
Example table entry:
```
>> srcAddr, dstAddr, srcPort(0xaa), dstPort(2152:GTP-U), type(255:G-PDU), teid(100)
>> note: Message Type 1 is Echo request, 255 is G-PDU
table_add gtpu_encap_v6 gtpu_encap_v6 db8::2 => db8::1:1 db8::2:2 0x100 2152 255 100 

>> Example to configure IPv6 -> GTP -> SRv6 using srv6_End_M_GTP6_D3.
table_add fwd forward 0 => 2
table_add fwd forward 2 => 0
table_add fwd forward 1 => 3
table_add fwd forward 3 => 1
table_add srv6_localsid srv6_End_M_GTP6_D3 db8::2:2 => db8::1:11 db8::31 db8::32 db8::33
table_add gtpu_v6 gtpu_encap_v6 db8::2 => db8::1:1 db8::2:2 0x100 2152 255 100
```

* Test T.Encaps.Red (downlink)
Ping from host1(db8::2) to host0 (db8::1). Match field dstAddr is db8::1.
Action is srv6_T_Encaps_Red2(srcAddr, sid0, sid1).
SRGW::TEID is db8:1::64 (SRGW=db8:1::/96, TEID=100)
```
table_add fwd forward 0 => 1
table_add fwd forward 1 => 0
table_add srv6_localsid srv6_T_Encaps_Red2 db8::1 => db8:1::4 db8:1::3 db8:1::64
```

* Test T.Encaps1 + T.Encaps.Red (downlink)
T.Encaps.Red2 will add 2 segments: SRGW::TEID (db8:1::64), dNB(db8:1::1)

```
table_add fwd forward 0 => 2
table_add fwd forward 2 => 0
table_add fwd forward 1 => 3
table_add fwd forward 3 => 1
table_add srv6_localsid srv6_T_Encaps_Red2 db8::1 => db8:1::4 db8:1::64 db8:1::1
table_add srv6_localsid srv6_End_M_GTP6_E db8:1::64 => db8:1::2
```

* Test End.DT6 with Linux T.Encaps.
ping6 to db8:b::2 from host0(db8::1), and SRv6 packet with dstAddr db8::2 will be generated with seg6 entry configured with iproute2.
Route lookup is not implemented (yet) so End DT6 is actually just poping SRH/SegmentList.
```
sudo ip netns exec host0 ip -6 route add db8:b::2/128 encap seg6 mode encap segs db8::2,c0be::2 via db8::2
sudo ip netns exec host0 ip -6 route add db8:b::3/128 encap seg6 mode encap segs db8::2,c0be::2,c0be::3 via db8::2
sudo ip netns exec host0 ip -6 route add db8:b::4/128 encap seg6 mode encap segs db8::2,c0be::2,c0be::3,c0be::4 via db8::2

table_add fwd forward 0 => 1
table_add fwd forward 1 => 0
table_add srv6_localsid srv6_End_DT6 db8::2 => 
```









