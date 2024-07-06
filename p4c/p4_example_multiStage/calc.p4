/* -*- P4_16 -*- */

/*
 * P4 Calculator
 *
 * This program implements a simple protocol. It can be carried over Ethernet
 * (Ethertype 0x1234).
 *
 * The Protocol header looks like this:
 *
 *        0                1                  2              3
 * +----------------+----------------+----------------+---------------+
 * |      P         |       4        |     Version    |     Op        |
 * +----------------+----------------+----------------+---------------+
 * |                              Operand A                           |
 * +----------------+----------------+----------------+---------------+
 * |                              Operand B                           |
 * +----------------+----------------+----------------+---------------+
 * |                              Result                              |
 * +----------------+----------------+----------------+---------------+
 *
 *
 * The device receives a packet, performs the requested operation, fills in the 
 * result and sends the packet back out of the same port it came in on, while 
 * swapping the source and destination addresses.
 *
 * If an unknown operation is specified or the header is not valid, the packet
 * is dropped 
 */

#include <core.p4>
#include <fpga.p4>

/*
 * Define the headers the program will recognize
 */

/*
 * Standard ethernet header 
 */
header ethernet_t {
    bit<48> eth_dst_addr;
    bit<48> eth_src_addr;
    bit<16> eth_ethertype;
}

header vlan_t {
    bit<16> vlan_id;
    bit<16> vlan_ethertype;
}

header ipv4_t {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<16> total_len;
    bit<16> identification;
    bit<3>  flags;
    bit<13> frag_offset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> ip_checksum;
    bit<32> ip_src_addr;
    bit<32> ip_dst_addr;
}

header udp_t {
    bit<16> udp_src_port;
    bit<16> udp_dst_port;
    bit<16> hdr_length;
    bit<16> udp_checksum;
}

header p4calc_t {
    bit<16> op;
    bit<32> operand_a;
    bit<32> operand_b;
    bit<32> res;
}

/*
 * All headers, used in the program needs to be assembed into a single struct.
 * We only need to declare the type, but there is no need to instantiate it,
 * because it is done "by the architecture", i.e. outside of P4 functions
 */
struct headers {
    ethernet_t	ethernet;
	vlan_t	vlan;
	ipv4_t	ipv4;
	udp_t	udp;
    p4calc_t	p4calc;
}

/*
 * All metadata, globally used in the program, also  needs to be assembed 
 * into a single struct. As in the case of the headers, we only need to 
 * declare the type, but there is no need to instantiate it,
 * because it is done "by the architecture", i.e. outside of P4 functions
 */
 
struct metadata {
    bit<128>  nothing;
    bit<1>    discard;
    bit<127>  still_nothing;
}

/*************************************************************************
 ***********************  P A R S E R  ***********************************
 *************************************************************************/
parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        packet.extract(hdr.ethernet);
		transition parse_vlan;
    }

	state parse_vlan {
		packet.extract(hdr.vlan);
		transition parse_ip;
	}

	state parse_ip {
		packet.extract(hdr.ipv4);
		transition parse_udp;
	}

	state parse_udp {
		packet.extract(hdr.udp);
		transition parse_custom;
	}
    
    state parse_custom {
        packet.extract(hdr.p4calc);
        transition accept;
    }
}

/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    /*action operation_add() {
        hdr.p4calc.res = hdr.p4calc.operand_a + hdr.p4calc.operand_b;
    }
    
    action operation_sub() {
        hdr.p4calc.res = hdr.p4calc.operand_a - hdr.p4calc.operand_b;
    }*/
    
    action compute_1() {
        hdr.p4calc.res = 100;
    }
    
    action compute_2() {
        hdr.p4calc.res = 50;
    }
    
    action compute_3() {
        hdr.p4calc.res = 101;
    }
    
    action compute_4() {
        hdr.p4calc.res = 51;
    }
    
    action drop_pkt() {
        meta.discard = 1;
    }
    
    action do_nothing() {}
    
    /*table first_tab {
        key = {
            hdr.p4calc.op        : exact;
        }
        actions = {
            operation_add;
            operation_sub;
        }
        const default_action = operation_add();
        const entries = {
            13: operation_add();
            26: operation_sub();
        }
    }*/
    
    table middle_tab_1 {
        key = {
            hdr.p4calc.res        : exact;
        }
        actions = {
            compute_1;
            drop_pkt;
        }
        const default_action = compute_1();
        const entries = {
            0: drop_pkt();
            1: compute_1();
        }
    }
    
    table middle_tab_2 {
        key = {
            hdr.p4calc.res        : exact;
        }
        actions = {
            compute_2;
            drop_pkt;
        }
        const default_action = compute_2();
        const entries = {
            0: compute_2();
            1: drop_pkt();
        }
    }
    
    table middle_tab_3 {
        key = {
            hdr.p4calc.operand_a        : exact;
        }
        actions = {
            compute_3;
            drop_pkt;
        }
        const default_action = compute_3();
        const entries = {
            0: drop_pkt();
            2: compute_3();
        }
    }
    
    table middle_tab_4 {
        key = {
            hdr.p4calc.operand_a        : exact;
        }
        actions = {
            compute_4;
            drop_pkt;
        }
        const default_action = compute_4();
        const entries = {
            0: compute_4();
            2: drop_pkt();
        }
    }
    
    /*table last_tab {
    	key = {
            hdr.p4calc.res        : exact;
        }
        actions = {
            do_nothing;
            drop_pkt;
        }
        const default_action = do_nothing();
        const entries = {
            0: drop_pkt();
        }
    }*/

    apply {
	//first_tab.apply();
	if(hdr.p4calc.res == 0)
		if(hdr.p4calc.operand_a == 10)
			//if(hdr.p4calc.op == 1)
				middle_tab_1.apply();
			//else
			//	middle_tab_3.apply();
		else
			//if(hdr.p4calc.operand_b == 1)
				middle_tab_2.apply();
			//else
			//	middle_tab_4.apply();
	else
		if(hdr.p4calc.operand_b == 3)
			middle_tab_3.apply();
		else
			middle_tab_4.apply();
	//last_tab.apply();
    }
}

/*************************************************************************
 ***********************  S W I T T C H **********************************
 *************************************************************************/

FpgaSwitch(
MyParser(),
MyIngress()
) main;
