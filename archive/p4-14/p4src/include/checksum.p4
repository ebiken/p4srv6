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

/* ip tcp udp checksum calculation */

field_list ipv4_checksum_list {
    ipv4.version;
    ipv4.ihl;
    ipv4.diffserv;
    ipv4.totalLen;
    ipv4.identification;
    ipv4.flags;
    ipv4.fragOffset;
    ipv4.ttl;
    ipv4.protocol;
    ipv4.srcAddr;
    ipv4.dstAddr;
}

field_list_calculation ipv4_checksum {
    input {
        ipv4_checksum_list;
    }
    algorithm : csum16;
    output_width : 16;
}

calculated_field ipv4.hdrChecksum  {
    verify ipv4_checksum if (ipv4.ihl == 5);
    update ipv4_checksum if (ipv4.ihl == 5);
}

field_list udp_checksum_list {
    ipv4.srcAddr;
    ipv4.dstAddr;
    8'0;
    ipv4.protocol;
    udp.length_;
    udp.srcPort;
    udp.dstPort;
    payload;
}
field_list_calculation udp_checksum {
    input {
        udp_checksum_list;
    }
    algorithm : csum16;
    output_width : 16;
}
calculated_field udp.checksum {
    //verify udp_checksum if(valid(udp));
    update udp_checksum if(valid(udp));
}

header_type tcp_metadata_t {
    fields {
        tcpLength : 16;
    }
}
metadata tcp_metadata_t tcp_metadata;
field_list tcp_checksum_list {
    ipv4.srcAddr;
    ipv4.dstAddr;
    8'0;
    ipv4.protocol;
    tcp_metadata.tcpLength;
    tcp.srcPort;
    ipv4.ttl;
    ipv4.protocol;
    ipv4.srcAddr;
    ipv4.dstAddr;
}

field_list_calculation ipv4_checksum {
    input {
        ipv4_checksum_list;
    }
    algorithm : csum16;
    output_width : 16;
}

calculated_field ipv4.hdrChecksum  {
    verify ipv4_checksum if (ipv4.ihl == 5);
    update ipv4_checksum if (ipv4.ihl == 5);
}

field_list udp_checksum_list {
    ipv4.srcAddr;
    ipv4.dstAddr;
    8'0;
    ipv4.protocol;
    udp.length_;
    udp.srcPort;
    udp.dstPort;
    payload;
}
field_list_calculation udp_checksum {
    input {
        udp_checksum_list;
    }
    algorithm : csum16;
    output_width : 16;
}
calculated_field udp.checksum {
    //verify udp_checksum if(valid(udp));
    update udp_checksum if(valid(udp));
}

header_type tcp_metadata_t {
    fields {
        tcpLength : 16;
    }
}
metadata tcp_metadata_t tcp_metadata;
field_list tcp_checksum_list {
    ipv4.srcAddr;
    ipv4.dstAddr;
    8'0;
    ipv4.protocol;
    tcp_metadata.tcpLength;
    tcp.srcPort;
    tcp.dstPort;
    tcp.seqNo;
    tcp.ackNo;
    tcp.dataOffset;
    tcp.res;
    tcp.flags;
    tcp.window;
    tcp.urgentPtr;
    payload;
}

field_list_calculation tcp_checksum {
    input {
        tcp_checksum_list;
    }
    algorithm : csum16;
    output_width : 16;
}

calculated_field tcp.checksum {
    verify tcp_checksum if(valid(tcp));
    update tcp_checksum if(valid(tcp));
}

