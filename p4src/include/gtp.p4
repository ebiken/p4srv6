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
header_type gtpu_payload_t {
	fields {
		version : 4; // either IPv4(4) or IPv6(6)
	}
}
header gtpu_payload_t gtpu_payload;

///// PARSER //////////////////////////////////////////////
parser parse_gtpu {
    extract(gtpu);
    return parse_gtpu_payload;
}
parser parse_gtpu_payload {
    extract(gtpu_payload);
    return ingress;
}
