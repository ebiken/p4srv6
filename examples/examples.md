# Examples of P4 SRv6 related stuff

## packet captures (Linux dataplane + iproute2)

```
sysctl net.ipv6.conf.all.seg6_enabled=1
ip netns exec host0 sysctl net.ipv6.conf.all.seg6_enabled=1
ip netns exec host1 sysctl net.ipv6.conf.all.seg6_enabled=1

> seg6-inline-3segs.trc
sudo ip netns exec host0 ip -6 route add db8:b::2/128 encap seg6 mode inline segs db8::2,c0be::2,c0be::3 via db8::2
> seg6-encap-3segs.trc
sudo ip netns exec host0 ip -6 route add db8:b::3/128 encap seg6 mode encap segs db8::2,c0be::2,c0be::3 via db8::2
```


## packet captures (p4srv6)

* T.Insert
```
RuntimeCmd:
table_add fwd forward 0 => 1
table_add fwd forward 1 => 0

> p4srv6-inline-1seg-01.trc
table_add srv6_localsid srv6_T_Insert1 db8::2 => db8::11
> p4srv6-inline-2seg-01.trc
table_add srv6_localsid srv6_T_Insert2 db8::2 => db8::21 db8::22
> p4srv6-inline-3seg-01.trc
table_add srv6_localsid srv6_T_Insert3 db8::2 => db8::31 db8::32 db8::33
```

