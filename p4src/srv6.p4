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

#ifndef _SRV6_
#define _SRV6_

control SRv6(
    inout Header hdr,
    inout UserMetadata user_md,
    in PortId_t in_port,
    inout PortId_t egress_port) {

    // Counters for actions in transit and end (localsid) behaviors.
#ifdef _V1_MODEL_P4_
    // see v1model.p4 for counter definitions.
    direct_counter(CounterType.packets_and_bytes) cnt_srv6_t_v4;
    direct_counter(CounterType.packets_and_bytes) cnt_srv6_t_v6;
    direct_counter(CounterType.packets_and_bytes) cnt_srv6_t_udp;
    direct_counter(CounterType.packets_and_bytes) cnt_srv6_e;
    direct_counter(CounterType.packets_and_bytes) cnt_srv6_e_iif;
#endif /* _V1_MODEL_P4_ */

    /*** HELPER ACTIONS *******************************************************/
    action remove_srh_header() {
        hdr.srh.setInvalid();
        // switch_srv6.p4: SRH_SID_MAX 4
        hdr.srh_sid[0].setInvalid();
        hdr.srh_sid[1].setInvalid();
        hdr.srh_sid[2].setInvalid();
        hdr.srh_sid[3].setInvalid();
        hdr.srh.setInvalid();
    }

    /*** HELPER ACTIONS : PUSH SRH/SID ****************************************/
    // https://datatracker.ietf.org/doc/draft-ietf-6man-segment-routing-header/
    // NextHeader, HdrExtLen, SegmentsLeft are defined in "RFC8200 IPv6 Specification"
    // Hdr Ext Len: 8-bit unsigned integer.  Length of the Routing header in
    //              8-octet units, not including the first 8 octets.
    //  => with no TLV, this is 2*(number_of_sid)
    // Segments Left: 8-bit unsigned integer.  Number of route segments
    //   remaining, i.e., number of explicitly listed intermediate nodes still
    //   to be visited before reaching the final destination.
    //  => "number_of_sid - 1" for normal insert/encaps
    //  => "number_of_sid" for reduced insert/encaps (TODO: double check)
    // Last Entry: contains the index (zero based), in the Segment List,
    //             of the last element of the Segment List.
    action push_srh(bit<8> nextHdr, bit<8> hdrExtLen, bit<8> segmentsLeft, bit<8> lastEntry) {
        hdr.srh.setValid();
        hdr.srh.nextHdr = nextHdr;
        hdr.srh.hdrExtLen = hdrExtLen;
        hdr.srh.routingType = 4; // TBD, to be assigned by IANA (suggested value: 4)
        hdr.srh.segmentsLeft = segmentsLeft;
        hdr.srh.lastEntry = lastEntry;
        hdr.srh.flags = 0;
        hdr.srh.tag = 0;
    }
    action push_srh_sid1(
            bit<8> nextHdr,
            bit<8> segmentsLeft,
            bit<128> sid1) {
        // SID List <sid1>
        hdr.ipv6.payloadLen = hdr.ipv6.payloadLen + 16w24; // SRH(8) + SID(16)
        push_srh(nextHdr, 8w2, segmentsLeft, 8w0);
        hdr.srh_sid[0].setValid();
        hdr.srh_sid[0].sid = sid1;
    }
    action push_srh_sid2(
            bit<8> nextHdr,
            bit<8> segmentsLeft,
            bit<128> sid1, bit<128> sid2) {
        // SID List <sid1, sid2>
        hdr.ipv6.payloadLen = hdr.ipv6.payloadLen + 16w40; // SRH(8) + SID(16)*2
        push_srh(nextHdr, 8w4, segmentsLeft, 8w1);
        hdr.srh_sid[0].setValid();
        hdr.srh_sid[0].sid = sid2;
        hdr.srh_sid[1].setValid();
        hdr.srh_sid[1].sid = sid1;
    }
    action push_srh_sid3(
            bit<8> nextHdr,
            bit<8> segmentsLeft,
            bit<128> sid1, bit<128> sid2, bit<128> sid3) {
        // SID List <sid1, sid2, sid3>
        hdr.ipv6.payloadLen = hdr.ipv6.payloadLen + 16w56; // SRH(8) + SID(16)*3
        push_srh(nextHdr, 8w6, segmentsLeft, 8w2);
        hdr.srh_sid[0].setValid();
        hdr.srh_sid[0].sid = sid3;
        hdr.srh_sid[1].setValid();
        hdr.srh_sid[1].sid = sid2;
        hdr.srh_sid[2].setValid();
        hdr.srh_sid[2].sid = sid1;
    }
    action push_srh_sid4(
            bit<8> nextHdr,
            bit<8> segmentsLeft,
            bit<128> sid1, bit<128> sid2, bit<128> sid3, bit<128> sid4) {
        // SID List <sid1, sid2, sid3, sid4>
        hdr.ipv6.payloadLen = hdr.ipv6.payloadLen + 16w72; // SRH(8) + SID(16)*4
        push_srh(nextHdr, 8w8, segmentsLeft, 8w3);
        hdr.srh_sid[0].setValid();
        hdr.srh_sid[0].sid = sid4;
        hdr.srh_sid[1].setValid();
        hdr.srh_sid[1].sid = sid3;
        hdr.srh_sid[2].setValid();
        hdr.srh_sid[2].sid = sid2;
        hdr.srh_sid[3].setValid();
        hdr.srh_sid[3].sid = sid1;
    }

    /*** TRANSIT ACTION & TABLES **********************************************/
    // hdr.srh.nextHdr:
    //   T.Insert: nextHdr in the original IPv6 hdr
    //   T.Encaps and match with IPv4 : IPPROTO_IPV4(4) 
    //   T.Encaps and match with IPv6 : IPPROTO_IPV6(41)
    //   T.Encaps.L2, T.Encaps.L2.Red : IPPROTO_NONXT(59)

    // T.Insert will use ipv6.dstAddr as 1st SID. Thus, will have +1 SIDs.
    action t_insert_sid1(bit<128> sid1) {
        push_srh_sid2(hdr.ipv6.nextHdr, 1, sid1, hdr.ipv6.dstAddr);
        hdr.ipv6.nextHdr = IPPROTO_ROUTE;
        hdr.ipv6.dstAddr = sid1;
        cnt_srv6_t_v6.count();
    }
    action t_insert_sid2(bit<128> sid1, bit<128> sid2) {
        push_srh_sid3(hdr.ipv6.nextHdr, 2, sid1, sid2, hdr.ipv6.dstAddr);
        hdr.ipv6.nextHdr = IPPROTO_ROUTE;
        hdr.ipv6.dstAddr = sid1;
        cnt_srv6_t_v6.count();
    }
    action t_insert_sid3(bit<128> sid1, bit<128> sid2, bit<128> sid3) {
        push_srh_sid4(hdr.ipv6.nextHdr, 3, sid1, sid2, sid3, hdr.ipv6.dstAddr);
        hdr.ipv6.nextHdr = IPPROTO_ROUTE;
        hdr.ipv6.dstAddr = sid1;
        cnt_srv6_t_v6.count();
    }
    // T.Encaps
    // TODO: Encaps require different header operation based on protocol
    //       of the original packet (ex: IPv4, IPv6)
    //       Consider defining different actions for IPv4/IPv6 or have a
    //       table later in the pipeline to copy IPv4/IPv6 to inner hdr
    //       and push new ones.
    //action t_encaps_sid1(IPv6Address ipv6src, bit<128> sid1) {
    //}
    // T.Encaps.L2
    //action t_encaps_l2_sid1(IPv6Address ipv6src, bit<128> sid1) {
    //}

    action t_m_replace_ipv4_to_ipv6(bit<32> iw_prefix, IPv6Address ipv6_src_addr) {
        hdr.ether.etherType = ETH_P_IPV6;
        hdr.ipv6.setValid();
        hdr.ipv6.version = 4w6;
        hdr.ipv6.trafficClass = 8w0;
        hdr.ipv6.flowLabel = 20w0;
        hdr.ipv6.payloadLen = hdr.ipv4.totalLen - 16w36;
        hdr.ipv6.nextHdr = 8w4; // TODO: User PDU. Should be configurable.
        hdr.ipv6.hopLimit = hdr.ipv4.ttl;
        hdr.ipv6.srcAddr = ipv6_src_addr;
        // Generate SID based on GTPU packet.
        hdr.ipv6.dstAddr[31:0] = hdr.gtpu.teid;
        hdr.ipv6.dstAddr[63:32] = hdr.ipv4.srcAddr;
        hdr.ipv6.dstAddr[95:64] = hdr.ipv4.dstAddr;
        hdr.ipv6.dstAddr[127:96] = iw_prefix; // GTP SRv6 InterWork prefix
        // remove IPv4/UDP/GTPU headers
        hdr.gtpu.setInvalid();
        hdr.udp.setInvalid();
        hdr.ipv4.setInvalid();
    }
    // TODO: T.M.Tmap: Support PREFIX longer than 32bits.
    // * In some environment (ex: private LTE) one might not be able to alocate
    // * prefix longer than 32bits. Experiment and feedback to IETF DMM ML.
    action t_m_tmap(bit<32> iw_prefix, IPv6Address ipv6_src_addr) {
        t_m_replace_ipv4_to_ipv6(iw_prefix, ipv6_src_addr);
        cnt_srv6_t_udp.count();
    }
    // T.M.Tmap is not capable of adding SRH&SID in draft-ietf-dmm-srv6-mobile-uplane-03
    // * t_m_tmap_sid1() action is capable of adding SRH&SID. Report result to IETF DMM
    // * mailing list ML to discuss if we should extend or add another behavior.
    action t_m_tmap_sid1(bit<32> iw_prefix, IPv6Address ipv6_src_addr,
            bit<128> sid1) {
        t_m_replace_ipv4_to_ipv6(iw_prefix, ipv6_src_addr);
        push_srh_sid2(hdr.ipv6.nextHdr, 1, sid1, hdr.ipv6.dstAddr);
        hdr.ipv6.nextHdr = IPPROTO_ROUTE;
        hdr.ipv6.dstAddr = sid1;
        cnt_srv6_t_udp.count();
    }
    action t_m_tmap_sid2(bit<32> iw_prefix, IPv6Address ipv6_src_addr,
            bit<128> sid1, bit<128> sid2) {
        t_m_replace_ipv4_to_ipv6(iw_prefix, ipv6_src_addr);
        push_srh_sid3(hdr.ipv6.nextHdr, 2, sid1, sid2, hdr.ipv6.dstAddr);
        hdr.ipv6.nextHdr = IPPROTO_ROUTE;
        hdr.ipv6.dstAddr = sid1;
        cnt_srv6_t_udp.count();
    }
    action t_m_tmap_sid3(bit<32> iw_prefix, IPv6Address ipv6_src_addr,
            bit<128> sid1, bit<128> sid2, bit<128> sid3) {
        t_m_replace_ipv4_to_ipv6(iw_prefix, ipv6_src_addr);
        push_srh_sid4(hdr.ipv6.nextHdr, 3, sid1, sid2, sid3, hdr.ipv6.dstAddr);
        hdr.ipv6.nextHdr = IPPROTO_ROUTE;
        hdr.ipv6.dstAddr = sid1;
        cnt_srv6_t_udp.count();
    }
    action srv6_debug_v6() {
        //debug
        cnt_srv6_t_v6.count();
    }
    table srv6_transit_v6 {
        key = {
            hdr.ipv6.dstAddr: exact; // TODO: change to LPM
        }
        actions = {
            @defaultonly NoAction;
            t_insert_sid1;       // T.Insert with 2 SIDs (DA + sid1)
            t_insert_sid2;       // T.Insert with 3 SIDs (DA + sid1/2)
            t_insert_sid3;       // T.Insert with 4 SIDs (DA + sid1/2/3)
            //t_encaps_sid1;       // T.Encaps
            //t_encaps_l2_sid1;    // T.Encaps.L2
            // Custom functions
            //srv6_debug_v6;
        }
        const default_action = NoAction;
        counters = cnt_srv6_t_v6;
    }
    table srv6_transit_v4 {
        key = {
            hdr.ipv4.dstAddr: exact; // TODO: change to LPM
        }
        actions = {
            @defaultonly NoAction;
            //t_encaps_sid1;       // T.Encaps
            //t_encaps_l2_sid1;    // T.Encaps.L2
        }
        const default_action = NoAction;
        counters = cnt_srv6_t_v4;
    }
    table srv6_transit_udp {
        key = {
            hdr.udp.dstPort : exact;
        }
        actions = {
            @defaultonly NoAction;
            // SRv6 Mobile Userplane : draft-ietf-dmm-srv6-mobile-uplane
            t_m_tmap;
            t_m_tmap_sid1;  // 2 SIDs (DA + sid1)
            t_m_tmap_sid2;  // 3 SIDs (DA + sid1/2)
            t_m_tmap_sid3;  // 4 SIDs (DA + sid1/2/3)
        }
        const default_action = NoAction;
        counters = cnt_srv6_t_udp;
    }
    /*** END (localsid) ACTION & TABLES ***************************************/
    // End: Prerequisite for executing End function is NH=SRH and SL>0
    //      match key should be updated to check this prerequisite.
    action end() {
        // 1.   IF NH=SRH and SL > 0
        // 2.      decrement SL
        hdr.srh.segmentsLeft = hdr.srh.segmentsLeft - 1;
        // 3.      update the IPv6 DA with SRH[SL]
        hdr.ipv6.dstAddr = user_md.srv6.nextsid;
        // 4.      FIB lookup on the updated DA
        // 5.      forward accordingly to the matched entry
        // TODO
    }
    action end_m_gtp4_e() {
        hdr.ether.etherType = ETH_P_IPV4;
        hdr.ipv4.setValid();
        hdr.ipv4.version = 4w4;
        hdr.ipv4.ihl = 4w5;
        hdr.ipv4.diffserv = 8w0;
        // IPv6 Payload Length + IPv4 Header(20) + UDP(8) + GTP(8)
        hdr.ipv4.totalLen = hdr.ipv6.payloadLen + 16w36 - 16w40;
        //DEBUG hdr.ipv4.totalLen = hdr.ipv6.payloadLen + 16w36;
        hdr.ipv4.identification = 16w0;
        hdr.ipv4.flags = 3w0;
        hdr.ipv4.fragOffset = 13w0;
        hdr.ipv4.ttl = hdr.ipv6.hopLimit;
        hdr.ipv4.protocol = IPPROTO_UDP;
        // IPv4 header checksum will be calculated later.
        hdr.ipv4.srcAddr = hdr.ipv6.dstAddr[63:32];
        hdr.ipv4.dstAddr = hdr.ipv6.dstAddr[95:64];
        hdr.udp.setValid();
        hdr.udp.srcPort = UDP_PORT_GTPU; // 16w2152
        hdr.udp.dstPort = UDP_PORT_GTPU; // 16w2152
        hdr.udp.length = hdr.ipv6.payloadLen + 16w16 -16w40; // Payload + UDP(8) + GTP(8)
        //DEBUG hdr.udp.length = hdr.ipv6.payloadLen + 16w16; // Payload + UDP(8) + GTP(8)
        hdr.gtpu.setValid();
        hdr.gtpu.version = 3w1;
        hdr.gtpu.pt = 1w1;
        hdr.gtpu.reserved = 1w0;
        hdr.gtpu.e = 1w0; // No Extention Header
        hdr.gtpu.s = 1w0; // No Sequence number
        hdr.gtpu.pn = 1w0;
        hdr.gtpu.messageType = GTPV1_GPDU; // 8w255
        hdr.gtpu.messageLen = hdr.ipv6.payloadLen; // Same as the original IPv6 Payload
        hdr.gtpu.teid = hdr.ipv6.dstAddr[31:0];
        // remove IPv6/SRH headers
        remove_srh_header();
        hdr.ipv6.setInvalid();

        cnt_srv6_e.count();
    }
    // https://tools.ietf.org/html/draft-xuclad-spring-sr-service-programming-02#section-6.4.1
    // 6.4.1.  SRv6 masquerading proxy pseudocode
    // Masquerading: Upon receiving a packet destined for S, where S is an
    // IPv6 masquerading proxy segment, a node N processes it as follows.
    // 1.   IF NH=SRH & SL > 0 THEN
    // 2.       Update the IPv6 DA with SRH[0]
    // 3.       Forward the packet on IFACE-OUT
    // 4.   ELSE
    // 5.       Drop the packet
    action end_am(PortId_t oif, EthernetAddress dmac) {
        // TODO: "NH=SRH & SL > 0" should be validated as part of match rule
        hdr.ipv6.dstAddr = hdr.srh_sid[0].sid;
        hdr.ether.dstAddr = dmac;
        egress_port = oif;
    }
    // De-masquerading: Upon receiving a non-link-local IPv6 packet on
    // IFACE-IN, a node N processes it as follows.
    // 1.   IF NH=SRH & SL > 0 THEN
    // 2.       Decrement SL
    // 3.       Update the IPv6 DA with SRH[SL]                      ;; Ref1
    // 4.       Lookup DA in appropriate table and proceed accordingly
    action end_am_d(PortId_t oif) {
        // TODO: "NH=SRH & SL > 0" should be validated as part of match rule
        hdr.srh.segmentsLeft = hdr.srh.segmentsLeft - 1;
        hdr.ipv6.dstAddr = user_md.srv6.nextsid;
        egress_port = oif; // TODO: Workaround untill L2Fwd() and L3 support
    }
    table srv6_end { // localsid
        key = {
            hdr.ipv6.dstAddr : ternary;
            // hdr.srh.isValid() : ternary;
            // hdr.srh.segmentLeft : ternary;
            // hdr.srh.nextHdr : ternary; // for decap
        }
        actions = {
            @defaultonly NoAction;
            // SRv6 Network Program  : draft-filsfils-spring-srv6-network-programming
            end;                    // End
            //end_x;                  // End.X

            // SRv6 Mobile Userplane : draft-ietf-dmm-srv6-mobile-uplane
            end_m_gtp4_e;           // End.M.GTP4.E

            // Proxy Functions : draft-xuclad-spring-sr-service-programming
            end_am;
        }
        const default_action = NoAction;
        counters = cnt_srv6_e;
    }
    table srv6_end_iif { // Input Interface based SRv6 End.* table
        key = {
            in_port : exact; // ingress phy port
            // hdr.srh.isValid() : ternary;
        }
        actions = {
            @defaultonly NoAction;
            // Proxy Functions : draft-xuclad-spring-sr-service-programming
            end_am_d;
        }
        const default_action = NoAction;
        counters = cnt_srv6_e_iif;
    }


    /*** HELPER TABLE TO SET NEXT SID *****************************************/
    action set_nextsid_1() {
        user_md.srv6.nextsid = hdr.srh_sid[0].sid;
    }
    action set_nextsid_2() {
        user_md.srv6.nextsid = hdr.srh_sid[1].sid;
    }
    action set_nextsid_3() {
        user_md.srv6.nextsid = hdr.srh_sid[2].sid;
    }
    action set_nextsid_4() {
        user_md.srv6.nextsid = hdr.srh_sid[3].sid;
    }
    table srv6_set_nextsid { // helper table
        key = {
            hdr.srh.segmentsLeft : exact;
        }
        actions = {
            NoAction;
            set_nextsid_1;
            set_nextsid_2;
            set_nextsid_3;
            set_nextsid_4;
        }
        const default_action = NoAction;
        const entries = {
            (1) : set_nextsid_1();
            (2) : set_nextsid_2();
            (3) : set_nextsid_3();
            (4) : set_nextsid_4();
        }
    }
    apply {
        if (hdr.srh.isValid()) {
            srv6_set_nextsid.apply();
        }
        if (hdr.ipv6.isValid()) {
            if(!srv6_end_iif.apply().hit) {
                if(!srv6_end.apply().hit) {
                    srv6_transit_v6.apply();
                }
            }
        } else if (hdr.ipv4.isValid()) {
            if(!srv6_transit_udp.apply().hit) {
                srv6_transit_v4.apply();
            }
        }
    }
}


#endif /* _SRV6_ */
