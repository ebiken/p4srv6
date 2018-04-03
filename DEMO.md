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
sudo simple_switch p4srv6.json -i 0@vtap0 -i 1@vtap1 -- nanolog \
ipc:///tmp/bm-0-log.ipc --log-console -L debug --notifications-addr \
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
table_add fwd forward 0 => 1
table_add fwd forward 1 => 0

table_add srv6_localsid srv6_T_Insert1 db8::2 => db8::11
table_add srv6_localsid srv6_T_Insert2 db8::2 => db8::21 db8::22
table_add srv6_localsid srv6_T_Insert3 db8::2 => db8::31 db8::32 db8::33
>> srcAddr=db8::1:11, sid0=db8::11
table_add srv6_localsid srv6_T_Encap1 db8::2 => db8::1:11 db8::11
table_add srv6_localsid srv6_T_Encap2 db8::2 => db8::1:11 db8::21 db8::22
table_add srv6_localsid srv6_T_Encap3 db8::2 => db8::1:11 db8::31 db8::32 db8::33
```

Ping from host0 (172.20.0.1/db8::1) to host1 (172.20.0.2/db8::2)
Capture packet on host1 to confirm SRH is inserted.
```
# ip netns exec host1 tcpdump -i veth1 -w p4srv6-test.trc

# ip netns exec host0 ping 172.20.0.2
# ip netns exec host0 ping6 db8::2
```

