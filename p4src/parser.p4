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

#ifndef _PARSER_
#define _PARSER_

//-------------------------------------------------------------------------
// PARSER

parser SwitchParser(
            packet_in pkt,
            out Header hdr,
            inout UserMetadata user_md,
            inout standard_metadata_t st_md) {

    state start {
        transition parse_ethernet;
    }
    state parse_ethernet {
        pkt.extract(hdr.ether);
        transition select(hdr.ether.etherType) {
            ETH_P_IPV4 : parse_ipv4;
            ETH_P_IPV6 : parse_ipv6;
            //ETH_P_ARP  : parse_arp;
            //ETH_P_VLAN : parse_vlan;
            default : accept;
        }
    }
    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            IPPROTO_TCP : parse_tcp;
            IPPROTO_UDP : parse_udp;
            default : accept;
        }
    }
    state parse_ipv6 {
        pkt.extract(hdr.ipv6);
        transition select(hdr.ipv6.nextHdr) {
            IPPROTO_TCP : parse_tcp;
            IPPROTO_UDP : parse_udp;
            IPPROTO_ROUTE : parse_srh;
            IPPROTO_IPV4 : parse_inner_ipv4;
            IPPROTO_IPV6 : parse_inner_ipv6;
            default : accept;
        }
    }
    state parse_tcp {
        pkt.extract(hdr.tcp);
        transition accept;
    }
    state parse_udp {
        pkt.extract(hdr.udp);
        transition select(hdr.udp.dstPort) {
            UDP_PORT_GTPU: parse_gtpu;
            default: accept;
        }
    }
    state parse_gtpu {
        pkt.extract(hdr.gtpu);
        bit<4> ip_ver = pkt.lookahead<bit<4>>();
        transition select(ip_ver) {
            4w4 : parse_inner_ipv4;
            4w6 : parse_inner_ipv6;
            default : parse_inner_ether;
        }
    }
    state parse_inner_ipv4 {
        pkt.extract(hdr.inner_ipv4);
        transition select(hdr.inner_ipv4.protocol) {
            IPPROTO_TCP : parse_inner_tcp;
            IPPROTO_UDP : parse_inner_udp;
            default : accept;
        }
    }
    state parse_inner_ipv6 {
        pkt.extract(hdr.inner_ipv6);
        transition select(hdr.inner_ipv6.nextHdr) {
            IPPROTO_TCP : parse_inner_tcp;
            IPPROTO_UDP : parse_inner_udp;
            default : accept;
        }
    }
    state parse_inner_ether {
        pkt.extract(hdr.inner_ether);
        transition accept;
    }
/*** PARSE SRH (SRv6) ***/
    state parse_srh {
        pkt.extract(hdr.srh);
        transition parse_srh_sid_0;
    }
#define PARSE_SRH_SID(curr, next)               \
    state parse_srh_sid_##curr {                \
        pkt.extract(hdr.srh_sid[curr]);         \
        transition select(hdr.srh.lastEntry) {  \
            curr : parse_srh_next_header;       \
            default : parse_srh_sid_##next;     \
        }                                       \
    }                                           \
// switch_srv6.p4:SRH_SID_MAX 4
PARSE_SRH_SID(0, 1)
PARSE_SRH_SID(1, 2)
PARSE_SRH_SID(2, 3)
    state parse_srh_sid_3 {
        pkt.extract(hdr.srh_sid[3]);
        transition select(hdr.srh.lastEntry) {
            3 : parse_srh_next_header;
            // v1model: no default rule: all other packets rejected
#ifndef _V1_MODEL_P4_
            default : reject; // Too many SIDs
#endif /* _V1_MODEL_P4_ */
        }
    }
    state parse_srh_next_header {
        transition select(hdr.srh.nextHdr) {
            IPPROTO_TCP : parse_tcp;
            IPPROTO_UDP : parse_udp;
            IPPROTO_IPV4 : parse_inner_ipv4;
            IPPROTO_IPV6 : parse_inner_ipv6;
            default : accept;
        }
    }
    state parse_inner_udp {
        pkt.extract(hdr.inner_udp);
        transition accept;
    }
    state parse_inner_tcp {
        pkt.extract(hdr.inner_tcp);
        transition accept;
    }
}


//-------------------------------------------------------------------------
// DEPARSER

control SwitchDeparser(
            packet_out pkt,
            in Header hdr) {

    apply {
        pkt.emit(hdr.ether);
        pkt.emit(hdr.ipv6);
        pkt.emit(hdr.srh);
        pkt.emit(hdr.srh_sid);
        pkt.emit(hdr.ipv4);
        //pkt.emit(hdr.icmp);
        pkt.emit(hdr.tcp);
        pkt.emit(hdr.udp);
        pkt.emit(hdr.gtpu);
        pkt.emit(hdr.inner_ether);
        pkt.emit(hdr.inner_ipv6);
        pkt.emit(hdr.inner_ipv4);
        pkt.emit(hdr.inner_tcp);
        pkt.emit(hdr.inner_udp);
    }
}
#endif /* _PARSER_ */
