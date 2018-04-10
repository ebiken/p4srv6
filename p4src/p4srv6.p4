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

#include "include/headers.p4"
#include "include/parser.p4"
#include "include/srv6.p4"
#include "include/gtp.p4"

/*** ACTIONS ***/

action _nop() {
	// no operation
}
action _drop() {
	drop();
}
action forward(port) {
	modify_field(standard_metadata.egress_spec, port);
}

/*** TABLES ***/

table fwd {
	reads {
        standard_metadata.ingress_port: exact;
    }
    actions {forward; _drop;}
    // size : 8
}

// SRv6 Tables
table srv6_localsid {
	reads {
		ipv6.dstAddr: exact; // TODO: should be lpm/masked match?
	}
	actions {
		srv6_T_Insert1; srv6_T_Insert2; srv6_T_Insert3;
		srv6_T_Encaps2; srv6_T_Encaps1; srv6_T_Encaps3;
		srv6_T_Encaps_Red2; srv6_T_Encaps_Red3;
		srv6_End_DT6;
		srv6_End_M_GTP6_D3;
		srv6_End_M_GTP6_E;
	}
}

// GTP Tables
table gtpu_v6 {
	reads {
		ipv6.dstAddr: exact; // TODO: should be lpm/masked match?
	}
	actions {
		gtpu_encap_v6;
		gtpu_decap_v6;
	}
}

///// CONTROL /////////////////////////////////////////////
control ingress{
    apply(fwd);
	apply(srv6_localsid);
	apply(gtpu_v6);
}
