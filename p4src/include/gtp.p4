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
/* GTP GPRS Tunneling Protocol related headers and actions are defined in this file */

///// HEADER //////////////////////////////////////////////

//// GTPv1 User Data
// flags consists of below bits.
//   [flag field name]      : typical GTPv1U value
//   Version(3bits)         : 1 (GTPv1)
//   Protocol Type          : 1 (GTP)
//   Reserved               : 0 (must be 0)
//   Extention (E)          : 0
//   Sequence number (S)    : 0
//   N-PDU number flag (PN) : 0
header_type gtpu_t {
    fields { // 8bytes
		flags  : 8;
		type   : 8;
		length : 16;
		teid   : 32;
	}
}
header gtpu_t gtpu;

// Parse first 4 bit of GTP-U payload to to identify protocol inside GTP-U.
// This only works if one is sure user packet is either IPv4 or IPv6.
//header_type gtpu_payload_t {
//	fields {
//		version : 4; // either IPv4(4) or IPv6(6)
//	}
//}
//header gtpu_payload_t gtpu_payload;

///// PARSER //////////////////////////////////////////////
parser parse_gtpu {
    extract(gtpu);
    //return parse_gtpu_payload;
	return select(current(0,4)) { // version field
		0x04 : parse_gtpu_ipv4;
		0x06 : parse_gtpu_ipv6;
	}
}
//parser parse_gtpu_payload {
//	extract(gtpu_payload);
//	return ingress;
//}
parser parse_gtpu_ipv4 {
	extract(gtpu_ipv4);
	return ingress;
}
parser parse_gtpu_ipv6 {
	extract(gtpu_ipv6);
	return ingress;
}
///// ACTIONS /////////////////////////////////////////////
action gtpu_encap_v6(srcAddr, dstAddr, srcPort, dstPort, type, teid) {
	// ethernet|ipv6 => ethernet|ipv6(new)|udp|gtpu|gtpu_ipv6(original)
    add_header(udp);
    add_header(gtpu);
    add_header(gtpu_ipv6);
    copy_header(gtpu_ipv6, ipv6);
	// set ipv6 fields which needs to be modified from the original packet
	add_to_field(ipv6.payloadLen, 20+8+8); // IPv6(20)+UDP(8)+GTPU(8)
	modify_field(ipv6.nextHdr, IP_PROTOCOLS_UDP);
	modify_field(ipv6.srcAddr, srcAddr);
	modify_field(ipv6.dstAddr, dstAddr);
	// set udp
	modify_field(udp.srcPort, srcPort); // TODO: generate from flow label, or random??
	modify_field(udp.dstPort, dstPort); // default 2123
	modify_field(udp.length_, ipv6.payloadLen-20); // Substract IPv6(20)
	// TODO: calculate checksum after updating gtpu??
	// set gtpu
	// Flags: ver:001,type:1(GTP) | 00,0(Seq),0
	modify_field(gtpu.flags, 0x30); 
	modify_field(gtpu.type, type);
	modify_field(gtpu.length, udp.length_-16); // Substract UDP, GTPU header length
	modify_field(gtpu.teid, teid);
}






