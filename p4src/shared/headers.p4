/*
 * Copyright 2023 Kentaro Ebisawa
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
 * Kentaro Ebisawa https://github.com/ebiken
 *
 */

#ifndef _HEADERS_P4_
#define _HEADERS_P4_

//-------------------------------------------------------------------
// TYPES: move to types.p4
//-------------------------------------------------------------------

//typedef bit<48> mac_addr_t;

//-------------------------------------------------------------------
// Protocol Header Definitions
//-------------------------------------------------------------------

header ethernet_h {
    bit<48> dst_addr;
    bit<48> src_addr;
    bit<16> ether_type;
}

// https://en.wikipedia.org/wiki/IEEE_802.1Q
header vlan_tag_h {
    bit<3>  pcp;
    bit<1>  dei;
    bit<12> vlan_id;
    bit<16> ether_type;
}

header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<16> total_len;
    bit<16> identification;
    bit<3>  flags;
    bit<13> frag_offset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdr_checksum;
    bit<32> src_addr;
    bit<32> dst_addr;
}

header ipv6_h {
    bit<4>   version;
    bit<8>   traffic_class;
    bit<20>  flow_label;
    bit<16>  payload_len;
    bit<8>   next_hdr;
    bit<8>   hop_limit;
    bit<128> src_addr;
    bit<128> dst_addr;
}

header tcp_h {
    bit<16> src_port;
    bit<16> dst_port;
    bit<32> seq_no;
    bit<32> ack_no;
    bit<4>  data_offset;
    bit<4>  res;
    bit<8>  flags;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgent_ptr;
}

header udp_h {
    bit<16> src_port;
    bit<16> dst_port;
    bit<16> length;
    bit<16> checksum;
}

header icmp_h {
    bit<8>  type;
    bit<8>  code;
    bit<16> checksum;
    //bit<32> ... define sub-header for each type/code
}

// IPv6 Segment Routing Header (SRH) -- RFC8754 
header srh_h {
    bit<8>  next_hdr;
    bit<8>  hdr_ext_len;   // in 8-octet units, not including the first 8 octets.
    bit<8>  routing_type;  // (4) for SRv6
    bit<8>  seg_left;      // Number of segments remaining to be visited. (mutable)
    bit<8>  last_entry;    // Zero based index of the last element of the Segment List.
    bit<8>  flags;         // Unused. MUST be 0 on transmission and ignored on receipt.
    bit<12> tag;           // Must be zero if unused on transmission.
    bit<4>  gtp_message_type; // least significant 4 bits of tag "draft-murakami-03 5.3."
    // ... Segment List -- srh_segment_list_t
    // ... Optional TLV objects (variable)
}
header srh_segment_list_h {
    bit<128> sid;
}

// GTP User Data Messages (GTPv1) -- draft-murakami-user-plane-message-encoding-03
// Field name aligned with 3GPP GTP-U definition
header gtpu_h {
    bit<3>  version;
    bit<1>  pt;           // Protocol Type
    bit<1>  r;            // reserved
    bit<1>  e;            // Extension header flag
    bit<1>  s;            // Sequence number flag
    bit<1>  pn;           // N-PDU number flag
    bit<8>  message_type; // GTPv1Type_*
    bit<16> length;       // Message Length
    bit<32> teid;         // Tunnel endpoint id
}
// Optional fields. Does not exist when (e,s,pn) are all zero.
header gtpu_opt_h {
    bit<16> seq;       // Sequence Number
    bit<8>  npdu;      // N-PDU Number
    bit<8>  next_ext_hdr; // Next Extention Header
}
