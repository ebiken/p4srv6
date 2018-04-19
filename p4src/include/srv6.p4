/* Copyright 2017-present Kentaro Ebisawa <ebiken.g@gmail.com>
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
 */

/* Written in P4_14 */
/* SRv6 related headers and actions are defined in this file */

///// HEADER //////////////////////////////////////////////
// draft-ietf-6man-segment-routing-header-10
// 3. Segment Routing Extension Header (SRH)
// Optional TLV not defined (yet) for simplisity.
header_type ipv6_srh_t {
    fields {
		nextHeader   : 8;
		hdrExtLen    : 8;
		routingType  : 8;
		segmentsLeft : 8;
		lastEntry    : 8;
		flags        : 8;
		tag          : 16;
	}
}
header ipv6_srh_t ipv6_srh;

header_type ipv6_srh_segment_t {
	fields {
		sid : 128;
	}
}
#define SRH_MAX_SEGMENTS 3
// +1 for inline mode
header ipv6_srh_segment_t ipv6_srh_segment_list[SRH_MAX_SEGMENTS+1];

header_type srv6_meta_t {
	fields {
		teid: 32;
		EndMGTP6E_SRGW : 96;
		segmentsLeft: 8;
		ipv6_payloadLen : 16;
	}
}
metadata srv6_meta_t srv6_meta;

///// PARSER //////////////////////////////////////////////
parser parse_ipv6_srh {
	extract(ipv6_srh);
	return parse_ipv6_srh_seg0;
}
parser parse_ipv6_srh_seg0 {
	extract(ipv6_srh_segment_list[0]);
	return select(ipv6_srh.lastEntry) {
		//0 : ingress;
		0 : parse_ipv6_srh_payload;
		default: parse_ipv6_srh_seg1;
	}
}
parser parse_ipv6_srh_seg1 {
	extract(ipv6_srh_segment_list[1]);
	return select(ipv6_srh.lastEntry) {
		//1 : ingress;
		1 : parse_ipv6_srh_payload;
		default: parse_ipv6_srh_seg2;
	}
}
parser parse_ipv6_srh_seg2 {
	extract(ipv6_srh_segment_list[2]);
	return select(ipv6_srh.lastEntry) {
		//2 : ingress;
		2 : parse_ipv6_srh_payload;
		default: parse_ipv6_srh_seg3;
	}
}
parser parse_ipv6_srh_seg3 {
	extract(ipv6_srh_segment_list[3]);
	// SRH_MAX_SEGMENTS +1 = 4 so this is the last segment in the list.
	//return ingress;
	return parse_ipv6_srh_payload;
}
parser parse_ipv6_srh_payload {
	return select(ipv6_srh.nextHeader) {
		//IP_PROTOCOLS_ICMP : parse_icmp;
		IP_PROTOCOLS_IPV4 : parse_ipv4;
		IP_PROTOCOLS_TCP  : parse_tcp;
		IP_PROTOCOLS_UDP  : parse_udp;
		IP_PROTOCOLS_IPV6 : parse_ipv6_inner;
		default: ingress;
	}
}
parser parse_ipv6_inner {
	extract(ipv6_inner);
	return ingress;
}

///// ACTION //////////////////////////////////////////////
action ipv6_srh_insert(proto) {
	// TODO: should we add SRH(8) size here to ipv6.payloadLen, or in each functions?
	add_header(ipv6_srh);
	modify_field(ipv6_srh.nextHeader, proto);
	modify_field(ipv6_srh.hdrExtLen, 0);
	modify_field(ipv6_srh.routingType, 4);
	modify_field(ipv6_srh.segmentsLeft, 0);
	modify_field(ipv6_srh.lastEntry, 0);
	modify_field(ipv6_srh.flags, 0);
	modify_field(ipv6_srh.tag, 0);
}

// original ipv6 will be copied to ipv6_inner.
// ipv6 will be new outer ipv6 header.
action ipv6_encap_ipv6(srcAddr, dstAddr) {
	// ipv6_inner is actually original header. copy it.
	add_header(ipv6_inner);
	copy_header(ipv6_inner, ipv6);
	// update original (outer) header
	add_to_field(ipv6.payloadLen, 40); // size of ipv6_inner
	modify_field(ipv6.nextHdr, IP_PROTOCOLS_IPV6);
	modify_field(ipv6.srcAddr, srcAddr);
	modify_field(ipv6.dstAddr, dstAddr);
}
	

//// SRv6 Functions
// For "inline" mode:
// 1. dstAddr of received packet will be added to the last segment to traverse (seg[0])
// 2. dstAddr will be modified to the fist segment to traverse (seg[n])
action srv6_T_Insert1(sid0) {
    ipv6_srh_insert(ipv6.nextHdr);
    add_header(ipv6_srh_segment_list[0]);
    modify_field(ipv6_srh_segment_list[0].sid, ipv6.dstAddr);
    add_header(ipv6_srh_segment_list[1]);
    modify_field(ipv6_srh_segment_list[1].sid, sid0);
    modify_field(ipv6_srh.hdrExtLen, 4); // TODO
    modify_field(ipv6_srh.segmentsLeft, 1);
    modify_field(ipv6_srh.lastEntry, 1);
    // update original ipv6 headers
    modify_field(ipv6.nextHdr, IP_PROTOCOLS_SRV6);
    modify_field(ipv6.dstAddr, sid0);
    add_to_field(ipv6.payloadLen, 8+16*2); // SRH(8)+Seg(16)*2
}
action srv6_T_Insert2(sid0, sid1) {
    ipv6_srh_insert(ipv6.nextHdr);
    add_header(ipv6_srh_segment_list[0]);
    modify_field(ipv6_srh_segment_list[0].sid, ipv6.dstAddr);
    add_header(ipv6_srh_segment_list[1]);
    modify_field(ipv6_srh_segment_list[1].sid, sid1);
    add_header(ipv6_srh_segment_list[2]);
    modify_field(ipv6_srh_segment_list[2].sid, sid0);
    modify_field(ipv6_srh.hdrExtLen, 6);
    modify_field(ipv6_srh.segmentsLeft, 2);
    modify_field(ipv6_srh.lastEntry, 2);
    // update original ipv6 headers
    modify_field(ipv6.nextHdr, IP_PROTOCOLS_SRV6);
    modify_field(ipv6.dstAddr, sid0);
    add_to_field(ipv6.payloadLen, 8+16*3); // SRH(8)+Seg(16)*3
}
action srv6_T_Insert3(sid0, sid1, sid2) {
	ipv6_srh_insert(ipv6.nextHdr);
	add_header(ipv6_srh_segment_list[0]);
	modify_field(ipv6_srh_segment_list[0].sid, ipv6.dstAddr);
	add_header(ipv6_srh_segment_list[1]);
	modify_field(ipv6_srh_segment_list[1].sid, sid2);
	add_header(ipv6_srh_segment_list[2]);
	modify_field(ipv6_srh_segment_list[2].sid, sid1);
	add_header(ipv6_srh_segment_list[3]);
	modify_field(ipv6_srh_segment_list[3].sid, sid0);
	modify_field(ipv6_srh.hdrExtLen, 8);
	modify_field(ipv6_srh.segmentsLeft, 3);
	modify_field(ipv6_srh.lastEntry, 3);
	// update original ipv6 headers
	modify_field(ipv6.nextHdr, IP_PROTOCOLS_SRV6);
	modify_field(ipv6.dstAddr, sid0);
	add_to_field(ipv6.payloadLen, 8+16*4); // SRH(8)+Seg(16)*4
}

action srv6_T_Encaps1(srcAddr, sid0) {
	ipv6_encap_ipv6(srcAddr, sid0); // dstAddr==sid0
	ipv6_srh_insert(IP_PROTOCOLS_IPV6);
	add_header(ipv6_srh_segment_list[0]);
	modify_field(ipv6_srh_segment_list[0].sid, sid0);
    modify_field(ipv6_srh.hdrExtLen, 2); // 2bytes*(number of seg)
    modify_field(ipv6_srh.segmentsLeft, 0);
    modify_field(ipv6_srh.lastEntry, 0);
	// update original ipv6 headers
	modify_field(ipv6.nextHdr, IP_PROTOCOLS_SRV6);
	modify_field(ipv6.dstAddr, sid0);
	add_to_field(ipv6.payloadLen, 8+16*1); // SRH(8)+Seg(16)*1
}
action srv6_T_Encaps2(srcAddr, sid0, sid1) {
	ipv6_encap_ipv6(srcAddr, sid0); // dstAddr==sid0
	ipv6_srh_insert(IP_PROTOCOLS_IPV6);
	modify_field(ipv6.nextHdr, IP_PROTOCOLS_SRV6);
	add_header(ipv6_srh_segment_list[0]);
	modify_field(ipv6_srh_segment_list[0].sid, sid1);
	add_header(ipv6_srh_segment_list[1]);
	modify_field(ipv6_srh_segment_list[1].sid, sid0);
    modify_field(ipv6_srh.hdrExtLen, 4); // 2bytes*(number of seg)
    modify_field(ipv6_srh.segmentsLeft, 1);
    modify_field(ipv6_srh.lastEntry, 1);
	// update original ipv6 headers
	modify_field(ipv6.nextHdr, IP_PROTOCOLS_SRV6);
	modify_field(ipv6.dstAddr, sid0);
	add_to_field(ipv6.payloadLen, 8+16*2); // SRH(8)+Seg(16)*2
}
action srv6_T_Encaps3(srcAddr, sid0, sid1, sid2) {
	ipv6_encap_ipv6(srcAddr, sid0); // dstAddr==sid0
	ipv6_srh_insert(IP_PROTOCOLS_IPV6);
	modify_field(ipv6.nextHdr, IP_PROTOCOLS_SRV6);
	add_header(ipv6_srh_segment_list[0]);
	modify_field(ipv6_srh_segment_list[0].sid, sid2);
	add_header(ipv6_srh_segment_list[1]);
	modify_field(ipv6_srh_segment_list[1].sid, sid1);
	add_header(ipv6_srh_segment_list[2]);
	modify_field(ipv6_srh_segment_list[2].sid, sid0);
    modify_field(ipv6_srh.hdrExtLen, 6); // 2bytes*(number of seg)
    modify_field(ipv6_srh.segmentsLeft, 2);
    modify_field(ipv6_srh.lastEntry, 2);
	// update original ipv6 headers
	modify_field(ipv6.nextHdr, IP_PROTOCOLS_SRV6);
	modify_field(ipv6.dstAddr, sid0);
	add_to_field(ipv6.payloadLen, 8+16*3); // SRH(8)+Seg(16)*3
}

action srv6_T_Encaps_Red2(srcAddr, sid0, sid1) {
    ipv6_encap_ipv6(srcAddr, sid0); // dstAddr==sid0
    ipv6_srh_insert(IP_PROTOCOLS_IPV6);
    modify_field(ipv6.nextHdr, IP_PROTOCOLS_SRV6);
    add_header(ipv6_srh_segment_list[0]);
    modify_field(ipv6_srh_segment_list[0].sid, sid1);
    modify_field(ipv6_srh.hdrExtLen, 2); // 2bytes*(number of seg)
    modify_field(ipv6_srh.segmentsLeft, 1);
    modify_field(ipv6_srh.lastEntry, 0);
    // update original ipv6 headers
    modify_field(ipv6.nextHdr, IP_PROTOCOLS_SRV6);
    modify_field(ipv6.dstAddr, sid0);
    add_to_field(ipv6.payloadLen, 8+16*1); // SRH(8)+Seg(16)*1
}
action srv6_T_Encaps_Red3(srcAddr, sid0, sid1, sid2) {
    ipv6_encap_ipv6(srcAddr, sid0); // dstAddr==sid0
    ipv6_srh_insert(IP_PROTOCOLS_IPV6);
    modify_field(ipv6.nextHdr, IP_PROTOCOLS_SRV6);
    add_header(ipv6_srh_segment_list[0]);
    modify_field(ipv6_srh_segment_list[0].sid, sid2);
    add_header(ipv6_srh_segment_list[1]);
    modify_field(ipv6_srh_segment_list[1].sid, sid1);
    modify_field(ipv6_srh.hdrExtLen, 4); // 2bytes*(number of seg)
    modify_field(ipv6_srh.segmentsLeft, 2);
    modify_field(ipv6_srh.lastEntry, 1);
    // update original ipv6 headers
    modify_field(ipv6.nextHdr, IP_PROTOCOLS_SRV6);
    modify_field(ipv6.dstAddr, sid0);
    add_to_field(ipv6.payloadLen, 8+16*2); // SRH(8)+Seg(16)*2
}

///// End.* functions

// 4.1.  End: Endpoint
// 1.   IF NH=SRH and SL > 0
// 2.      decrement SL
// 3.      update the IPv6 DA with SRH[SL]
// 4.      FIB lookup on the updated DA                            ;; Ref1
// 5.      forward accordingly to the matched entry                ;; Ref2
// 6.   ELSE
// 7.      drop the packet                                         ;; Ref3
//FIXME: Having End0 and End1 is a durty hack to workaround p4c error for below.
//  modify_field(ipv6.dstAddr, ipv6_srh_segment_list[ipv6_srh.segmentsLeft].sid);
//  Most likely storing ipv6_srh.segmentsLeft in metadata to be used will solve this.
action srv6_End0() {
	//TODO: Implement PSP
	//TODO: Flag packet drop if SL=0 (per Ref3)
	subtract_from_field(ipv6_srh.segmentsLeft, 1);
	modify_field(ipv6.dstAddr, ipv6_srh_segment_list[0].sid); // FIXME
}
action srv6_End1() {
	subtract_from_field(ipv6_srh.segmentsLeft, 1);
	modify_field(ipv6.dstAddr, ipv6_srh_segment_list[1].sid); // FIXME
}

// 4.10. End.DT6: Endpoint with decapsulation and specific IPv6 table lookup
// 1. IF NH=SRH and SL > 0
// 2.   drop the packet ;; Ref1
// 3. ELSE IF ENH = 41 ;; Ref2
// 4.   pop the (outer) IPv6 header and its extension headers
// 5.   lookup the exposed inner IPv6 DA in IPv6 table T
// 6.   forward via the matched table entry
// 7. ELSE
// 8.   drop the packet
action srv6_End_DT6() {
	copy_header(ipv6, ipv6_inner);
	remove_header(ipv6_srh);
	// remove all possible SIDs regardless of if it actually exists
	// not sure if this works on non-BMv2 switches (i.e. ASIC,NPU,FPGA)
	remove_header(ipv6_srh_segment_list[0]);
	remove_header(ipv6_srh_segment_list[1]);
	remove_header(ipv6_srh_segment_list[2]);
	remove_header(ipv6_srh_segment_list[3]);
	remove_header(ipv6_inner);
	// TODO: Add flag to Lookup IPv6 Table specific to the SID
}

///// End.M.* functions
action srv6_End_M_GTP6_D2(srcAddr, sid0, sid1) {
	remove_header(udp);
	remove_header(gtpu);
    subtract_from_field(ipv6.payloadLen, 16); // UDP(8)+GTPU(8)
    modify_field(ipv6.nextHdr, IP_PROTOCOLS_SRV6);
    add_to_field(ipv6.payloadLen, 8+16*1); // SRH(8)+Seg(16)*1
    ipv6_srh_insert(0); // push srh with nextHeader=0
	// TODO: set correct value for IPv6
    modify_field(ipv6_srh.nextHeader, 41);
	add_header(ipv6_srh_segment_list[0]);
    modify_field(ipv6_srh_segment_list[0].sid, sid1);
	// End.M.GTP6.D use seg0 as DA, but does NOT include it in the seg list.
    modify_field(ipv6_srh.hdrExtLen, 2); // 2bytes*(number of seg)
    modify_field(ipv6_srh.segmentsLeft, 1);
    modify_field(ipv6_srh.lastEntry, 0); // sid0 is not included thus 1 smaller.
	// 4. set the outer IPv6 SA to A
    modify_field(ipv6.srcAddr, srcAddr);
	// 5. set the outer IPv6 DA to S1
    modify_field(ipv6.dstAddr, sid0); 
	// 6. forward according to the first segment of the SRv6 Policy
}
action srv6_End_M_GTP6_D3(srcAddr, sid0, sid1, sid2) {
	// 2. pop the IP, UDP and GTP headers
	//   Size information in the original IP header is required.
	//   Thus, just pop UDP/GTP header and keep original IP header.
	remove_header(udp);
	remove_header(gtpu);
    subtract_from_field(ipv6.payloadLen, 16); // UDP(8)+GTPU(8)
	// 3. push a new IPv6 header with its own SRH <S2, S3>
	//   Update exsiting (outer) IPv6 header
    modify_field(ipv6.nextHdr, IP_PROTOCOLS_SRV6);
    add_to_field(ipv6.payloadLen, 8+16*2); // SRH(8)+Seg(16)*2
    ipv6_srh_insert(0); // push srh with nextHeader=0
	// TODO: set correct value for IPv6
    modify_field(ipv6_srh.nextHeader, 41);
    // modify_field(ipv6_srh.nextHeader, gtpu_payload.version);
	// IP_PROTOCOLS_IPV4(4), IP_PROTOCOLS_IPV6(41)
	//	(gtpu_payload.version && 4)*IP_PROTOCOLS_IPV4
	//	+ (gtpu_payload.version && 6)*IP_PROTOCOLS_IPV6
	//	);
	add_header(ipv6_srh_segment_list[0]);
    modify_field(ipv6_srh_segment_list[0].sid, sid2);
    add_header(ipv6_srh_segment_list[1]);
    modify_field(ipv6_srh_segment_list[1].sid, sid1);
	// End.M.GTP6.D use seg0 as DA, but does NOT include it in the seg list.
    modify_field(ipv6_srh.hdrExtLen, 4); // 2bytes*(number of seg)
    modify_field(ipv6_srh.segmentsLeft, 2);
    modify_field(ipv6_srh.lastEntry, 1); // sid0 is not included thus 1 smaller.
	// 4. set the outer IPv6 SA to A
    modify_field(ipv6.srcAddr, srcAddr);
	// 5. set the outer IPv6 DA to S1
    modify_field(ipv6.dstAddr, sid0); 
	// 6. forward according to the first segment of the SRv6 Policy
}
action srv6_End_M_GTP6_E(srcAddr) {
    // 2.    decrement SL
	subtract_from_field(ipv6_srh.segmentsLeft, 1);
	// store SRGW to meta data. dstAddr = SRGW::TEID
	shift_right(srv6_meta.EndMGTP6E_SRGW, ipv6.dstAddr, 32);
	modify_field(ipv6.srcAddr, srcAddr);
    // 3.    store SRH[SL] in variable new_DA
	srv6_meta.segmentsLeft = ipv6_srh.segmentsLeft;
    // 4.    store TEID in variable new_TEID
	bit_and(srv6_meta.teid, 0x000000000000000000000000ffffffff, ipv6.dstAddr);
    // 5.    pop IP header and all it's extension headers
	// don't pop IPv6 header. will reuse it.
	remove_header(ipv6_srh);
	remove_header(ipv6_srh_segment_list[0]);
	remove_header(ipv6_srh_segment_list[1]);
	remove_header(ipv6_srh_segment_list[2]);
	remove_header(ipv6_srh_segment_list[3]);
    // 7.    set IPv6 DA to new_DA
	// Maybe we need table to call srv6_End_M_GTP6_E1~3 based on SL,
	// But let's assume SL=1 when packet reaches SRGW and SL[0] is gNB addr.
	modify_field(ipv6.dstAddr, ipv6_srh_segment_list[0].sid);
	// Adjust IP length: UDP(8)+GTP(8) - ( SRH(8) + SEG(16)*(n+1) )
	srv6_meta.ipv6_payloadLen = ipv6.payloadLen+8+8-8-16; // TODO
	modify_field(ipv6.payloadLen, srv6_meta.ipv6_payloadLen);
	modify_field(ipv6.nextHdr, IP_PROTOCOLS_UDP);
    // 6.    push new IPv6 header and GTP-U header
	add_header(udp);
	add_header(gtpu);
	// Although identical, you have to add gtpu_ipv6 and remove ipv6_inner
	// to help deparser to undertstand it would come after gtpu_ipv6 header.
	add_header(gtpu_ipv6);
	copy_header(gtpu_ipv6, ipv6_inner);
	remove_header(ipv6_inner);

    modify_field(udp.srcPort, 1000); // TODO: generate from flow label, or random??
    modify_field(udp.dstPort, UDP_PORT_GTPU);
	// ipv6.payloadLen does not incude ipv6 header. udp.len does include udp header.
	// Thus, udp.length = ipv6.payloadLen.
    modify_field(udp.length_, ipv6.payloadLen); 
	// TODO: update UDP checksum
    // 8.    set GTP_TEID to new_TEID
	modify_field(gtpu.teid, srv6_meta.teid);
    modify_field(gtpu.flags, 0x30);
    modify_field(gtpu.type, 255); // G-PDU(255)
	// gtpu.length length of payload and optional fields.
	// exclude udp(8) and 8 byte mandatory field (including teid) 
    modify_field(gtpu.length, udp.length_-16);
    // 9.    lookup the new_DA and forward the packet accordingly
}
