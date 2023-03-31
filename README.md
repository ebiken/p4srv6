# p4srv6 ... proto-typing SRv6 functions with P4 lang.

> Old P4-14 version is moved under [p4-14](https://github.com/ebiken/p4srv6/tree/master/p4-14) for archival purpose. 
>
> Branch v20191206 is created to archive pre-refactoring version started working from April 2023.

The objective of this project is to implement SRv6 functions still under discussion using P4 Lang to make running code available for testing and demo.
To support SRv6 functions with routing tables and topology requiring vlans etc, we plan to expand this code to include basic layer 2/3 switch features required to test SRv6 as well.

This project was started as part of SRv6 Mobile User Plane POC conducted in [SRv6 consortium](https://seg6.net).
Thus current priority is functions from [Mobile Uplane draft](https://datatracker.ietf.org/doc/draft-ietf-dmm-srv6-mobile-uplane/).
But planning to expand to general [SRv6 Network Programming](https://datatracker.ietf.org/doc/draft-filsfils-spring-srv6-network-programming/) functions for Edge Computing and Data Center use cases.

Please raise issue with use case description if you want to any SRv6 functions not implemented yet.

Note that this is still in very early development (alpha phase) and we expect pipeline structures including tables attributes and indirections would change while adding more features.

## P4 Target and Architecture

This is written for v1model architecture and confirmed to run on [BMv2](https://github.com/p4lang/behavioral-model).

I am trying to make as most code common among different architectures as possible.

Following Target Architectures are in my mind. Any contribution is more than welcome. :)
* v1model : [v1model.p4](https://github.com/p4lang/p4c/blob/master/p4include/v1model.p4) (Supported)
* PSA : [psa.p4](https://github.com/p4lang/p4c/blob/master/p4include/psa.p4)
* p4c-xdp : [xdp_model.p4](https://github.com/vmware/p4c-xdp/blob/master/p4include/xdp_model.p4) 
* Tofino Model
* SmartNIC ??

## List of SRv6 functions of interest and status (a.k.a. Road Map)

* Non functional design items

| Item name | schedule |
|-----------|----------|
| BSID friendly table structure | future |

* Basic Switching Features (Layer 1/2/3)

| Feature | Schedule |
|---------|----------|
| Port Forwarding | DONE |
| dmac table (static) | DONE |
| VLAN (port) | Dec, 2019 |
| VLAN (Tag) | future |
| IPv4 forwarding (LPM) | Dec, 2019 |
| IPv6 forwarding (LPM) | Dec, 2019 |
| Host Interface (ping/arp) | future |
| dmac (learning agent) | future |

* [draft-ietf-dmm-srv6-mobile-uplane-06](https://datatracker.ietf.org/doc/draft-ietf-dmm-srv6-mobile-uplane/)

Updates from `-03` to `-06` => Nov, 2019

| Function | schedule | description |
|----------|----------|-------------|
| Args.Mob.Session | | Consider with End.MAP, End.DT and End.DX |
| End.MAP | | |
| End.M.GTP6.D | Nov, 2019 | GTP-U/IPv6 => SRv6 |
| End.M.GTP6.E | Nov, 2019 | SRv6 => GTP-U/IPv6 |
| End.M.GTP4.E | DONE | SRv6 => GTP-U/IPv4 |
| T.M.Tmap => T.M.GTP4.D | DONE => Nov, 2019 | GTP-U/IPv4 => SRv6 |
| End.Limit | | Rate Limiting function |

* [draft-murakami-dmm-user-plane-message-mapping](https://datatracker.ietf.org/doc/draft-murakami-dmm-user-plane-message-mapping/)

Nov, 2019

* [draft-filsfils-spring-srv6-network-programming-07](https://datatracker.ietf.org/doc/draft-filsfils-spring-srv6-network-programming/)

Transit behaviors

| Function | schedule | description |
|----------|----------|-------------|
| T | n/a | Transit behavior|
| T.Insert | DONE | |
| T.Insert.Red | DONE | |
| T.Encaps | future | |
| T.Encaps.Red | future | |
| T.Encaps.L2 | future | |
| T.Encaps.L2.Red | future | |

Functions associated with a SID

| Function | schedule | description |
|----------|----------|-------------|
| End | PARTIAL | without error handling |
| End.X | April, 2019 | |
| End.T | | |
| End.DX2 (V) | | |
| End.DT2 (U/M) | | |
| End.DX6 | | |
| End.DX4 | | |
| End.DT6 | | |
| End.DT4 | | |
| End.DT46 | | |
| End.B6.Insert | | |
| End.B6.Insert.Red | | |
| End.B6.Encaps | | |
| End.B6.Encaps.Red | | |
| End.BM | | |
| End.S | | |

Flavours

| Function | schedule | description |
|----------|----------|-------------|
| PSP | May, 2019 | Penultimate Segment Pop |
| USP | | Ultimate Segment Pop |
| USD | | Ultimate Segment Decapsulation |

