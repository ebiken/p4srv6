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

#ifndef _HEADERS_
#define _HEADERS_


typedef bit<48> EthernetAddress;
typedef bit<32> IPv4Address;
typedef bit<128> IPv6Address;

typedef bit<16> EthernetType;
const EthernetType ETH_P_IPV4 = 16w0x0800;
const EthernetType ETH_P_ARP  = 16w0x0806;
const EthernetType ETH_P_VLAN = 16w0x8100;
const EthernetType ETH_P_IPV6 = 16w0x86dd;

// https://www.iana.org/assignments/protocol-numbers/protocol-numbers.xhtml
typedef bit<8> IPProtocol;
const IPProtocol IPPROTO_HOPOPT = 0; // IPv6 Hop-by-Hop Option
const IPProtocol IPPROTO_ICMP = 1;
const IPProtocol IPPROTO_IPV4 = 4;
const IPProtocol IPPROTO_TCP = 6;
const IPProtocol IPPROTO_UDP = 17;
const IPProtocol IPPROTO_IPV6 = 41;
const IPProtocol IPPROTO_ROUTE = 43; // Routing Header for IPv6
const IPProtocol IPPROTO_FRAG = 44; // Fragment Header for IPv6
const IPProtocol IPPROTO_GRE = 47;
const IPProtocol IPPROTO_ICMPv6 = 58; // ICMP for IPv6
const IPProtocol IPPROTO_NONXT = 59; // No Next Header for IPv6

typedef bit<16> UDPPort;
const UDPPort UDP_PORT_GTPC = 2123;
const UDPPort UDP_PORT_GTPU = 2152;

header Ethernet_h {
    EthernetAddress dstAddr;
    EthernetAddress srcAddr;
    EthernetType etherType;
}

header IPv4_h {
    bit<4> version;
    bit<4> ihl;
    bit<8> diffserv;
    bit<16> totalLen;
    bit<16> identification;
    bit<3> flags;
    bit<13> fragOffset;
    bit<8> ttl;
    IPProtocol protocol;
    bit<16> hdrChecksum;
    IPv4Address srcAddr;
    IPv4Address dstAddr;
}

header IPv6_h {
    bit<4> version;
    bit<8> trafficClass;
    bit<20> flowLabel;
    bit<16> payloadLen;
    bit<8> nextHdr;
    bit<8> hopLimit;
    IPv6Address srcAddr;
    IPv6Address dstAddr;
}

header TCP_h {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seq;
    bit<32> ack;
    bit<4> dataOffset;
    bit<4> res;
    bit<8> flags;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}

header UDP_h {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<16> length;
    bit<16> checksum;
}

header ICMP_h {
    bit<8> type;
    bit<8> code;
    bit<16> hdrChecksum;
    bit<32> restOfHeader;
    // restOfHeader vary based on the ICMP type and code
    // implement correctly when supporting ICMP
}

// Segment Routing Extension Header (SRH) based on version 15
// https://datatracker.ietf.org/doc/draft-ietf-6man-segment-routing-header/
header SRH_h {
    bit<8> nextHdr;
    bit<8> hdrExtLen;
    bit<8> routingType;
    bit<8> segmentsLeft;
    bit<8> lastEntry;
    bit<8> flags;
    bit<16> tag;
}

header SRH_SegmentList_h {
    bit<128> sid;
}

// GTP User Data Messages (GTPv1)
// 3GPP TS 29.060 V15.3.0 (2018-12) "Table 1: Messages in GTP"
typedef bit<8> GTPv1Type;
const GTPv1Type GTPV1_ECHO    = 1; // Echo Request
const GTPv1Type GTPV1_ECHORES = 2; // Echo Response
const GTPv1Type GTPV1_END  = 254; // End Marker
const GTPv1Type GTPV1_GPDU = 255; // G-PDU

// 3GPP TS 29.060 V15.3.0 (2018-12) "6 GTP Header"
header GTPU_h {
    bit<3>  version;       // Version field: always 1 for GTPv1
    bit<1>  pt;            // Protocol Type (PT): GTP(1), GTP'(0)
    bit<1>  reserved;      // always zero (0)
    bit<1>  e;             // Extension Header flag (E)
    bit<1>  s;             // Sequence number flag (S): not present(0), present(1)
    bit<1>  pn;            // N-PDU Number flag (PN)
    GTPv1Type messageType;
    bit<16> messageLen;
    bit<32> teid;          // Tunnel endpoint id
}

// Structure of parsed headers are defined in the main file (ex: switch.p4) to
// make it easier to add custom or temp header without modifying headers.h
// struct Header_h {
// }

#endif /* _HEADERS_ */
