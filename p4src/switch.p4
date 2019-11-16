/*
 * Copyright 2019 TOYOTA InfoTechnology Center Co., Ltd.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Kentaro Ebisawa <ebisawa@jp.toyota-itc.com>
 *
 */

#include <core.p4>
#include <v1model.p4>

//-------------------------------------------------------------------------
// TYPES
#ifdef _V1_MODEL_P4_
typedef bit<9>  PortId_t; // ingress_port/egress_port in v1model
#endif /* _V1_MODEL_P4_ */


//-------------------------------------------------------------------------
// HEADER
#include "headers.p4"

#define SRH_SID_MAX 4 // Max number of SIDs in SRH Segment List
struct Header {
    Ethernet_h ether;
    IPv6_h ipv6;
    SRH_h srh;
    SRH_SegmentList_h[SRH_SID_MAX] srh_sid; // [0]~[SRH_SID_MAX-1]
    IPv4_h ipv4;
    ICMP_h icmp;
    TCP_h tcp;
    UDP_h udp;
    GTPU_h gtpu;
    // inner headers
    Ethernet_h inner_ether;
    IPv6_h inner_ipv6;
    IPv4_h inner_ipv4;
    //ICMP_h inner_icmp;
    TCP_h inner_tcp;
    UDP_h inner_udp;
}

//-------------------------------------------------------------------------
// METADATA
//   Split metadata to two part, ingress and egress, so it will be easier
//   to map to architecture having user metadata for each.

// Generic ingress metadata (architecture independent)
struct IngressMetadata {
    // none defined yet
}
// Generic egress metadata (architecture independent)
struct EgressMetadata {
    // none defined yet
    //PortId_t ingress_port;
}
struct SRv6Metadata {
    bit<128> nextsid;
}
// User Metadata (for v1model)
struct UserMetadata {
    IngressMetadata ig_md;
    EgressMetadata eg_md;
    SRv6Metadata srv6;
}

//-------------------------------------------------------------------------
// INCLUDE PARSER and other protocols
#include "parser.p4"
#include "srv6.p4"

//-------------------------------------------------------------------------
// CONTROL

control L2Fwd(
    in EthernetAddress ether_dst_addr,
    inout IngressMetadata ig_md,
    inout PortId_t egress_port)
    (bit<32> table_size_dmac) {

    action dmac_miss() {
        // TODO: flood to mcast group
    }
    action dmac_hit(PortId_t port) {
        egress_port = port;
    }

    table dmac {
        key = {
            ether_dst_addr : exact;
        }
        actions = {
            dmac_miss;
            dmac_hit;
        }
        const default_action = dmac_miss;
        size = table_size_dmac;
    }

    apply {
        dmac.apply();
    }
}
control PortFwd(
        in PortId_t in_port,
        inout PortId_t egress_port) {

    action set_egress_port(PortId_t port) {
        egress_port = port;
    }

    table portfwd {
        key = {
            in_port : exact; // ingress phy port
        }

        actions = {
            set_egress_port;
        }
    }

    apply {
        portfwd.apply();
    }
}

// CONTROL: INGRESS -------------------------------------------------------

control SwitchIngress(
            inout Header hdr,
            inout UserMetadata user_md,
            inout standard_metadata_t st_md) {

    // Instantiate controlls
    PortFwd() port_fwd;
    SRv6() srv6;
    L2Fwd(1024) l2fwd;

    // Local MAC address. Apply Layer 3 tables when hit.
    action local_mac_hit() {}
    table local_mac {
        key = {
            hdr.ether.dstAddr : exact;
        }
        actions = {
            NoAction;
            local_mac_hit();
        }
        const default_action = NoAction;
        size = 512; // number of Layer 3 interfaces
    }

    apply {

        mark_to_drop(st_md); // set default action to drop to avoid unexpected packets going out.

        // policy L1 (port) forwarding table useful untill l2fwd is implemented.
        port_fwd.apply(st_md.ingress_port, st_md.egress_spec);

        // apply srv6 without local_mac validation for quick testing
        srv6.apply(hdr, user_md, st_md.ingress_port, st_md.egress_spec);

        // switch(local_mac.apply().action_run) {
        //    local_mac_hit : {
        //        srv6.apply(hdr, ig_md);
        //        /*** TODO: Layer 3 FIB
        //        if (hdr.ipv4.isValid()) {
        //            fib.apply(x,x,x);
        //        }
        //        if (hdr.ipv6.isValid()) {
        //            fibv6.apply(x, x, x);
        //        }
        //        ***/
        //    }
        // }
        // egress_spec vs egress_port in v1model:
        //   https://github.com/p4lang/behavioral-model/issues/603
        //   In v1model, egress_spec is used to specify output port in Ingress.
        //   egress_port is read only and only used in Egress pipeline.
        l2fwd.apply(hdr.ether.dstAddr, user_md.ig_md, st_md.egress_spec);
    }
}



// CONTROL: EGRESS --------------------------------------------------------

control SwitchEgress(
            inout Header hdr,
            inout UserMetadata user_md,
            inout standard_metadata_t st_md) {
    // do nothing
    apply { }
}


// CONTROL: CHECKSUM ------------------------------------------------------

control NoSwitchVerifyChecksum(
            inout Header hdr,
            inout UserMetadata user_md) {
    // dummy control to skip checkum
    apply { }
}
control SwitchVerifyChecksum(
            inout Header hdr,
            inout UserMetadata user_md) {
    apply {
        verify_checksum(hdr.ipv4.isValid() && hdr.ipv4.ihl == 5,
            { hdr.ipv4.version,
                hdr.ipv4.ihl,
                hdr.ipv4.diffserv,
                hdr.ipv4.totalLen,
                hdr.ipv4.identification,
                hdr.ipv4.flags,
                hdr.ipv4.fragOffset,
                hdr.ipv4.ttl,
                hdr.ipv4.protocol,
                hdr.ipv4.srcAddr,
                hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum, HashAlgorithm.csum16);
    }
}
/*****************************************************
/* replace this with SwitchComputeChecksum for debug
control NoSwitchComputeChecksum(
            inout Header hdr,
            inout UserMetadata user_md) {
    // dummy control to skip checkum
    apply { }
}
**/
control SwitchComputeChecksum(
            inout Header hdr,
            inout UserMetadata user_md) {
    apply {
        update_checksum(hdr.ipv4.isValid() && hdr.ipv4.ihl == 5,
            { hdr.ipv4.version,
                hdr.ipv4.ihl,
                hdr.ipv4.diffserv,
                hdr.ipv4.totalLen,
                hdr.ipv4.identification,
                hdr.ipv4.flags,
                hdr.ipv4.fragOffset,
                hdr.ipv4.ttl,
                hdr.ipv4.protocol,
                hdr.ipv4.srcAddr,
                hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum, HashAlgorithm.csum16);
    }
}

V1Switch(SwitchParser(),
         //SwitchVerifyChecksum(),
         NoSwitchVerifyChecksum(),
         SwitchIngress(),
         SwitchEgress(),
         SwitchComputeChecksum(),
         //NoSwitchComputeChecksum(),
         SwitchDeparser()) main;
