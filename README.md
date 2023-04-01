# p4srv6 ... proto-typing SRv6 functions with P4 lang.

- [About p4srv6](#about-p4srv6)
- [P4 Targets and Architectures](#p4-targets-and-architectures)
- [List of SRv6 functions of interest and status (a.k.a. Road Map)](#list-of-srv6-functions-of-interest-and-status-aka-road-map)
- [Reference](#reference)
- [Archives](#archives)

## About p4srv6

At the time of its inception in 2018, the objective of this project *was* to implement SRv6 functions still under discussion at IETF using P4 Lang to make running code available for testing and demo.

After 5+ years, the standardization of SRv6 has progressed, and many specifications have become RFCs. Open Source implementation has also advanced. For switch type implementation, SONiC now (in 202211, 202305 release) supports many SRv6 functions including uSID. Switch Abstraction Interface (SAI), which is the de facto standard API for Switch ASICs, is used by SONiC to communicate with ASIC from multiple vendors. e.g. Intel/Barefoot Tofino, Cisco Silicon One, Broadcom, Marvell, etc. 

Since SAI has become the de facto of Switch Object and Pipeline Model, p4srv6 is being refactored in a way that is (not perfect but some what) compatible with SAI, aiming to provide an implementation that serves as a educational reference for people who are interested in how packets are processed inside ASIC behind SAI.

## P4 Targets and Architectures

- BMv2 v1model
  - The main target of this p4srv6 is switch based P4 target which is [BMv2](https://github.com/p4lang/behavioral-model) using [v1model.p4](https://github.com/p4lang/p4c/blob/master/p4include/v1model.p4) architecture.
- Tofino Native Architecture (TNA)
  - Tofino Native Architecture is now public on GitHub [Open-Tofino](https://github.com/barefootnetworks/Open-Tofino) with [architecture document(pdf)](https://github.com/barefootnetworks/Open-Tofino/blob/master/PUBLIC_Tofino-Native-Arch.pdf) and [P4 architecture file (tna.p4)](https://github.com/barefootnetworks/Open-Tofino/blob/master/share/p4c/p4include/tna.p4)
  - However, there are still some restrictions (e.g. doesn't have an ASIC simulator publically available so anyone can try)
  - Thus, the P4 code in this repo is written to be compatible with TNA as much as posible, but not intented to run full demo nor fully documented. (Since it's difficult to do so without violating Intel NDA/SLA)
- SmartNIC (FPGA, IPU, DPU, ARM-Manycore, etc.)
  - There is no plan to support SmartNIC type of targets. However, P4 work in this area is evolving very fast. Thus, I would recommend checking other projects for SRv6 implementation on SmartNIC.


## List of SRv6 functions of interest and status (a.k.a. Road Map)

* Data Plane (P4) Switching

| Feature                    | Schedule |
| -------------------------- | -------- |
| Port Forwarding            | TBD      |
| L2 (dmac) forwarding       | TBD      |
| VLAN (port)                | TBD      |
| VLAN (Tag)                 | TBD      |
| IPv4 forwarding (lpm/host) | TBD      |
| IPv6 forwarding (lpm/host) | TBD      |

* Control Plane
 
| L2 learning agent          | TBD      |
| Host Interface (ping/arp)  | TBD      |

* [draft-ietf-dmm-srv6-mobile-uplane-24](https://datatracker.ietf.org/doc/draft-ietf-dmm-srv6-mobile-uplane/)

| Function         | schedule | description            |
| ---------------- | -------- | ---------------------- |
| Args.Mob.Session |          |                        |
| End.MAP          |          |                        |
| End.M.GTP6.D     |          | GTP-U/IPv6 => SRv6     |
| End.M.GTP6.Di    |          | GTP-U/IPv6 => SRv6     |
| End.M.GTP6.E     |          | SRv6 => GTP-U/IPv6     |
| End.M.GTP4.E     |          | SRv6 => GTP-U/IPv4     |
| T.M.GTP4.D       |          | GTP-U/IPv4 => SRv6     |
| End.Limit        | -        | Rate Limiting function |

* [draft-murakami-dmm-user-plane-message-encoding-05](https://datatracker.ietf.org/doc/draft-murakami-dmm-user-plane-message-encoding/)

| Function               | schedule | description |
| ---------------------- | -------- | ----------- |
| Args.Mob.Upmsg         |          |             |
| Encoding of Tags Field |          |             |
| User Plane message IE  |          |             |


* [RFC8986: SRv6 Network Programming](https://datatracker.ietf.org/doc/rfc8986/)

SR Policy Headend Behaviors

| Function        | schedule | description                                   |
| --------------- | -------- | --------------------------------------------- |
| H.Encaps        |          | SR Headend with Encapsulation in an SR Policy |
| H.Encaps.Red    |          | H.Encaps with Reduced Encapsulation           |
| H.Encaps.L2     |          | H.Encaps Applied to Received L2 Frames        |
| H.Encaps.L2.Red |          | H.Encaps.Red Applied to Received L2 Frames    |

SR Endpoint Behaviors

| Function          | schedule | description                                         |
| ----------------- | -------- | --------------------------------------------------- |
| End               |          |                                                     |
| End.X             |          | L3 Cross-Connect                                    |
| End.T             |          | Specific IPv6 Table Lookup                          |
| End.DX6           |          | Decapsulation and IPv6 Cross-Connect                |
| End.DX4           |          | Decapsulation and IPv4 Cross-Connect                |
| End.DT6           |          | Decapsulation and Specific IPv6 Table Lookup        |
| End.DT4           |          | Decapsulation and Specific IPv4 Table Lookup        |
| End.DT46          |          | Decapsulation and Specific IP Table Lookup          |
| End.DX2           |          | Decapsulation and L2 Cross-Connect                  |
| End.DX2V          |          | Decapsulation and VLAN L2 Table Lookup              |
| End.DT2U          |          | Decapsulation and Unicast MAC L2 Table Lookup       |
| End.DT2M          |          | Decapsulation and L2 Table Flooding                 |
| End.B6.Encaps     |          | Endpoint Bound to an SRv6 Policy with Encapsulation |
| End.B6.Encaps.Red |          | End.B6.Encaps with Reduced SRH                      |
| End.BM            |          | Endpoint Bound to an SR-MPLS Policy                 |

Flavours

| Function | schedule | description                    |
| -------- | -------- | ------------------------------ |
| PSP      |          | Penultimate Segment Pop        |
| USP      |          | Ultimate Segment Pop           |
| USD      |          | Ultimate Segment Decapsulation |

## Reference

- [SRv6 consortium](https://seg6.net) is where many people in Japan interested in SRv6 gathers.



## Archives

You can find old version of p4srv6 here

- [2019/03/03] Old P4-14 version is moved under [p4-14](https://github.com/ebiken/p4srv6/tree/master/p4-14) for archival purpose. 
- [2023/03/31] Branch v20191206 is created to archive pre-refactoring version started working from April 2023.
