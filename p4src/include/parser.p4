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

/*** parser definition ***/

#define ETHERTYPE_IPV4 0x0800
#define ETHERTYPE_IPV6 0x86dd

#define IP_PROTOCOLS_ICMP 1
#define IP_PROTOCOLS_IPV4 4
#define IP_PROTOCOLS_TCP  6
#define IP_PROTOCOLS_UDP  17
#define IP_PROTOCOLS_IPV6 41
#define IP_PROTOCOLS_SRV6 43

#define UDP_PORT_GTPU 2152 // GTP user data messages (GTP-U)

parser parse_tcp {
    extract(tcp);
    return ingress;
}

parser parse_udp {
    extract(udp);
    return select(latest.dstPort) {
        UDP_PORT_GTPU : parse_gtpu;
        default: ingress;
    }
}

parser parse_ipv6 {
	extract(ipv6);
	return select(latest.nextHdr) {
        //IP_PROTOCOLS_ICMP6 : parse_icmp6;
        IP_PROTOCOLS_TCP  : parse_tcp;
        IP_PROTOCOLS_UDP  : parse_udp;
        IP_PROTOCOLS_SRV6 : parse_ipv6_srh;
        default: ingress;
	}
}

parser parse_ipv4 {
    extract(ipv4);
    return select(latest.protocol) {
        //IP_PROTOCOLS_ICMP : parse_icmp;
        IP_PROTOCOLS_TCP : parse_tcp;
        IP_PROTOCOLS_UDP : parse_udp;
        default: ingress;
    }
}

parser parse_ethernet {
    extract(ethernet);
    return select(latest.etherType) {
        ETHERTYPE_IPV4 : parse_ipv4;
        ETHERTYPE_IPV6 : parse_ipv6;
        default: ingress;
    }
}

parser start {
    return parse_ethernet;
}
