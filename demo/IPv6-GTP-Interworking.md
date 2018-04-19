# IPv6 GTP Inerworking demo


Run script `./tools/IPv6-GTP-Interworking.sh -c`

* Create 2 name spaces, host0 and host1.
* Create veth/vtap and vtap pairs: veth0/vtap0, veth1/vtap1, vtap(11/12,13/14,15/16)
* Assign veth0/1 to host0/1.

Run two simple_switch (bmv2) for GTP and SRv6. (Default thrift port is 9090)

```
>> for gNB(GTP gateway)
sudo simple_switch p4srv6.json -i 0@vtap0 -i 11@vtap11 \
--notifications-addr ipc:///tmp/bmv2-1-notifications.ipc \
--thrift-port 9091 \
--log-console -L debug -- nanolog ipc:///tmp/bm-1-log.ipc &

>> for SRv6
sudo simple_switch p4srv6.json -i 1@vtap1 -i 12@vtap12 -i 13@vtap13 -i 14@vtap14 -i 15@vtap15 -i 16@vtap16 \
--notifications-addr ipc:///tmp/bmv2-0-notifications.ipc \
--thrift-port 9090 \
--log-console -L debug -- nanolog ipc:///tmp/bm-0-log.ipc &
```

Run P4 runtime CLI

```
~/p4lang/bmv2/targets/simple_switch/runtime_CLI --thrift-port 9090
~/p4lang/bmv2/targets/simple_switch/runtime_CLI --thrift-port 9091
```

Set rules to chain veth/vtap and vtap pairs.
ping between host0/1 to confirm bmv2 is running fine.

```
>> SRv6 (thrift-port 9090)
table_add fwd forward 12 => 13
table_add fwd forward 13 => 12
table_add fwd forward 14 => 15
table_add fwd forward 15 => 14
table_add fwd forward 16 =>  1
table_add fwd forward  1 => 16
>> gNB (thrift-port 9091)
table_add fwd forward  0 => 11
table_add fwd forward 11 =>  0

sudo ip netns exec host0 ping6 2001:db8:a::2
```

Set rules for "IPv6 GTP Interworking demo".

```
>>>> SRv6 (thrift-port 9090)
>> Upstream
table_add srv6_localsid srv6_End_M_GTP6_D2 2001:db8:1::1 => 2001:db8:1::1 2001:db8:1::11 2001:db8:1::2
table_add srv6_localsid srv6_End0 2001:db8:1::11 =>
table_add srv6_localsid srv6_End_DT6 2001:db8:1::2 =>
>> Downstream
// NG: table_add srv6_localsid srv6_T_Encaps_Red2 2001:db8:a::1 => 2001:db8:1::12 2001:db8:ff::64 2001:db8:b::1
table_add srv6_localsid srv6_T_Encaps_Red3 2001:db8:a::1 => 2001:db8:1::2 2001:db8:1::12 2001:db8:ff::64 2001:db8:b::1
// FIXME: This should be the same "srv6_End" as upstream.
table_add srv6_localsid srv6_End1 2001:db8:1::12 =>
table_add srv6_localsid srv6_End_M_GTP6_E 2001:db8:ff::64 => 2001:db8:ff::64

>>>> gNB  (thrift-port 9091)
>> srcAddr, dstAddr, srcPort(0xaa), dstPort(2152:GTP-U), type(255:G-PDU), teid(100)
table_add gtpu_v6 gtpu_encap_v6 2001:db8:a::2 => 2001:db8:b::1 2001:db8:1::1 0x100 2152 255 100
table_add gtpu_v6 gtpu_decap_v6 2001:db8:b::1 =>
```

Start wireshark / tcpdump at any interface you want to snoop packet and ping.

```
sudo tcpdump -i vtap0 -w 0419-01-vtap0.trc &
sudo tcpdump -i vtap1 -w 0419-01-vtap1.trc &
sudo tcpdump -i vtap11 -w 0419-01-vtap11.trc &
sudo tcpdump -i vtap13 -w 0419-01-vtap13.trc &
sudo tcpdump -i vtap15 -w 0419-01-vtap15.trc &

```


==========
WORKAROUND MEMO
```
# ip -6 neigh add <IPv6 address> lladdr <link-layer address> dev <device>
sudo ip netns exec host0 ip -6 neigh add 2001:db8:a::2 lladdr 12:c1:aa:04:91:01 dev veth0
sudo ip netns exec host1 ip -6 neigh add 2001:db8:a::1 lladdr 52:cc:2c:d7:50:a2 dev veth1
```
