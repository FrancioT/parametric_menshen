`timescale 1ns / 1ps

module rmt_wrapper #(
	// AXI-Lite parameters
	// Width of AXI lite data bus in bits
	parameter AXIL_DATA_WIDTH = 32,
	// Width of AXI lite address bus in bits
	parameter AXIL_ADDR_WIDTH = 16,
	// Width of AXI lite wstrb (width of data bus in words)
	parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
	// AXI Stream parameters
	// Slave
	parameter C_S_AXIS_DATA_WIDTH = 512,
	parameter C_S_AXIS_TUSER_WIDTH = 128,
	// Master
	// self-defined
	parameter PHV_LEN = 48*8+32*8+16*8+256,
	parameter KEY_LEN = 48*2+32*2+16*2+1,
	parameter ACT_LEN = 25,
	parameter KEY_OFF = 6*3+20,
	parameter C_NUM_QUEUES = 4,
	parameter C_VLANID_WIDTH = 12,
	parameter C_FIFO_BIT_WIDTH = 4
)
(
	input						clk,		// axis clk
	input						aresetn,	
	input [31:0]					vlan_drop_flags,
	output [31:0]					ctrl_token,

	/*
     * input Slave AXI Stream
     */
	input [C_S_AXIS_DATA_WIDTH-1:0]			s_axis_tdata,
	input [((C_S_AXIS_DATA_WIDTH/8))-1:0]		s_axis_tkeep,
	input [C_S_AXIS_TUSER_WIDTH-1:0]		s_axis_tuser,
	input						s_axis_tvalid,
	output						s_axis_tready,
	input						s_axis_tlast,

	/*
     * output Master AXI Stream
     */
	output     [C_S_AXIS_DATA_WIDTH-1:0]		m_axis_tdata,
	output     [((C_S_AXIS_DATA_WIDTH/8))-1:0]	m_axis_tkeep,
	output     [C_S_AXIS_TUSER_WIDTH-1:0]		m_axis_tuser,
	output    					m_axis_tvalid,
	input						m_axis_tready,
	output  					m_axis_tlast

	
);

integer idx;

/*=================================================*/
localparam PKT_VEC_WIDTH = (6+4+2)*8*8+256;

logic stg0_phv_in_valid;
logic [PKT_VEC_WIDTH-1:0] stg0_phv_in;

logic [PKT_VEC_WIDTH-1:0] stg0_phv_out;
logic stg0_phv_out_valid;
logic [PKT_VEC_WIDTH-1:0] stg1_phv_out;
logic stg1_phv_out_valid;
logic [PKT_VEC_WIDTH-1:0] stg2_phv_out;
logic stg2_phv_out_valid;
logic [PKT_VEC_WIDTH-1:0] stg3_phv_out;
logic stg3_phv_out_valid;

logic [PKT_VEC_WIDTH-1:0] stg0_phv_in_next;
logic [PKT_VEC_WIDTH-1:0] stg0_phv_out_next;
logic [PKT_VEC_WIDTH-1:0] stg1_phv_out_next;
logic [PKT_VEC_WIDTH-1:0] stg2_phv_out_next;
logic [PKT_VEC_WIDTH-1:0] stg3_phv_out_next;

logic stg0_phv_in_valid_next;
logic stg0_phv_out_valid_next;
logic stg1_phv_out_valid_next;
logic stg2_phv_out_valid_next;
logic stg3_phv_out_valid_next;

logic [C_VLANID_WIDTH-1:0] stg0_vlan_in;
logic stg0_vlan_valid_in;
logic [C_VLANID_WIDTH-1:0] stg0_vlan_in_next;
logic stg0_vlan_valid_in_next;

logic stg0_vlan_ready;
logic [C_VLANID_WIDTH-1:0] stg0_vlan_out;
logic stg0_vlan_valid_out;
logic [C_VLANID_WIDTH-1:0] stg0_vlan_out_next;
logic stg0_vlan_valid_out_next;

logic stg1_vlan_ready;
logic [C_VLANID_WIDTH-1:0] stg1_vlan_out;
logic stg1_vlan_valid_out;
logic [C_VLANID_WIDTH-1:0] stg1_vlan_out_next;
logic stg1_vlan_valid_out_next;

logic stg2_vlan_ready;
logic [C_VLANID_WIDTH-1:0] stg2_vlan_out;
logic stg2_vlan_valid_out;
logic [C_VLANID_WIDTH-1:0] stg2_vlan_out_next;
logic stg2_vlan_valid_out_next;

logic stg3_vlan_ready;
logic [C_VLANID_WIDTH-1:0] stg3_vlan_out;
logic stg3_vlan_valid_out;
logic [C_VLANID_WIDTH-1:0] stg3_vlan_out_next;
logic stg3_vlan_valid_out_next;

logic last_stg_vlan_ready;

// back pressure signals
logic s_axis_tready_p;
logic stg0_ready;
logic stg1_ready;
logic stg2_ready;
logic stg3_ready;
logic last_stg_ready;


/*=================================================*/

logic [C_VLANID_WIDTH-1:0] s_vlan_id;
logic s_vlan_id_valid;

logic [C_VLANID_WIDTH-1:0] s_vlan_id_next;
logic s_vlan_id_valid_next;

//NOTE: to filter out packets other than UDP/IP.
logic [C_S_AXIS_DATA_WIDTH-1:0] s_axis_tdata_f;
logic [((C_S_AXIS_DATA_WIDTH/8))-1:0] s_axis_tkeep_f;
logic [C_S_AXIS_TUSER_WIDTH-1:0] s_axis_tuser_f;
logic s_axis_tvalid_f;
logic s_axis_tready_f;
logic s_axis_tlast_f;

logic [C_S_AXIS_DATA_WIDTH-1:0] s_axis_tdata_f_next;
logic [((C_S_AXIS_DATA_WIDTH/8))-1:0] s_axis_tkeep_f_next;
logic [C_S_AXIS_TUSER_WIDTH-1:0] s_axis_tuser_f_next;
logic s_axis_tvalid_f_next;
logic s_axis_tlast_f_next;

//NOTE: filter control packets from data packets.
logic [C_S_AXIS_DATA_WIDTH-1:0] ctrl_s_axis_tdata_1;
logic [((C_S_AXIS_DATA_WIDTH/8))-1:0] ctrl_s_axis_tkeep_1;
logic [C_S_AXIS_TUSER_WIDTH-1:0] ctrl_s_axis_tuser_1;
logic ctrl_s_axis_tvalid_1;
logic ctrl_s_axis_tready_1;
logic ctrl_s_axis_tlast_1;

logic  [C_S_AXIS_DATA_WIDTH-1:0] ctrl_s_axis_tdata_1_next;
logic  [((C_S_AXIS_DATA_WIDTH/8))-1:0] ctrl_s_axis_tkeep_1_next;
logic  [C_S_AXIS_TUSER_WIDTH-1:0] ctrl_s_axis_tuser_1_next;
logic ctrl_s_axis_tvalid_1_next;
logic ctrl_s_axis_tlast_1_next;

pkt_filter #(
	.C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
	.C_S_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH)
)pkt_filter
(
	.clk			(clk),
	.aresetn		(aresetn),

	.vlan_drop_flags	(vlan_drop_flags),
	.ctrl_token		(ctrl_token),

	// input Slave AXI Stream
	.s_axis_tdata		(s_axis_tdata),
	.s_axis_tkeep		(s_axis_tkeep),
	.s_axis_tuser		(s_axis_tuser),
	.s_axis_tvalid		(s_axis_tvalid),
	.s_axis_tready		(s_axis_tready),
	.s_axis_tlast		(s_axis_tlast),

	.vlan_id		(s_vlan_id),
	.vlan_id_valid		(s_vlan_id_valid),

	// output Master AXI Stream
	.m_axis_tdata		(s_axis_tdata_f),
	.m_axis_tkeep		(s_axis_tkeep_f),
	.m_axis_tuser		(s_axis_tuser_f),
	.m_axis_tvalid		(s_axis_tvalid_f),
	// .m_axis_tready(s_axis_tready_f && s_axis_tready_p),
	.m_axis_tready		(s_axis_tready_f),
	.m_axis_tlast		(s_axis_tlast_f),

	//control path
	.c_m_axis_tdata		(ctrl_s_axis_tdata_1),
	.c_m_axis_tkeep		(ctrl_s_axis_tkeep_1),
	.c_m_axis_tuser		(ctrl_s_axis_tuser_1),
	.c_m_axis_tvalid	(ctrl_s_axis_tvalid_1),
	.c_m_axis_tlast		(ctrl_s_axis_tlast_1)
);

// we will have multiple pkt fifos and phv fifos
// pkt fifo logics
logic [C_S_AXIS_DATA_WIDTH-1:0] pkt_fifo_tdata_out [C_NUM_QUEUES-1:0];
logic [C_S_AXIS_TUSER_WIDTH-1:0] pkt_fifo_tuser_out [C_NUM_QUEUES-1:0];
logic [C_S_AXIS_DATA_WIDTH/8-1:0] pkt_fifo_tkeep_out [C_NUM_QUEUES-1:0];
logic pkt_fifo_tlast_out [C_NUM_QUEUES-1:0];

// output from parser
logic [C_S_AXIS_DATA_WIDTH-1:0] parser_m_axis_tdata [C_NUM_QUEUES-1:0];
logic [C_S_AXIS_TUSER_WIDTH-1:0] parser_m_axis_tuser [C_NUM_QUEUES-1:0];
logic [C_S_AXIS_DATA_WIDTH/8-1:0] parser_m_axis_tkeep [C_NUM_QUEUES-1:0];
logic parser_m_axis_tlast [C_NUM_QUEUES-1:0];
logic parser_m_axis_tvalid [C_NUM_QUEUES-1:0];

logic pkt_fifo_rd_en [C_NUM_QUEUES-1:0];
logic [C_NUM_QUEUES-1:0] pkt_fifo_nearly_full;
logic pkt_fifo_empty [C_NUM_QUEUES-1:0];

assign s_axis_tready_f = ~|pkt_fifo_nearly_full;
// equivalent to the old:
// assign s_axis_tready_f = !pkt_fifo_nearly_full[0] && !pkt_fifo_nearly_full[1] &&
//                          !pkt_fifo_nearly_full[2] && !pkt_fifo_nearly_full[3];

generate 
	genvar i;
	for (i=0; i<C_NUM_QUEUES; i=i+1) begin:
		sub_pkt_fifo
		fallthrough_small_fifo #(
			.WIDTH(C_S_AXIS_DATA_WIDTH+C_S_AXIS_TUSER_WIDTH+C_S_AXIS_DATA_WIDTH/8+1),
			.MAX_DEPTH_BITS(C_FIFO_BIT_WIDTH)
		)
		pkt_fifo (
			.clk			(clk),                         // input logic clk
  			.reset			(~aresetn),                    // input logic srst
  			.din			({parser_m_axis_tdata[i], parser_m_axis_tuser[i],
						  parser_m_axis_tkeep[i], parser_m_axis_tlast[i]}),     // input logic [704 : 0] din
  			.wr_en			(parser_m_axis_tvalid[i]),     // input logic wr_en
  			.rd_en			(pkt_fifo_rd_en[i]),           // input logic rd_en
  			.dout			({pkt_fifo_tdata_out[i], pkt_fifo_tuser_out[i],
						  pkt_fifo_tkeep_out[i], pkt_fifo_tlast_out[i]}),       // output logic [704 : 0] dout
			.full			(),
  			.nearly_full		(pkt_fifo_nearly_full[i]),     // output logic full
  			.empty			(pkt_fifo_empty[i])            // output logic empty
		);
	end
endgenerate

logic [PKT_VEC_WIDTH-1:0] last_stg_phv_out [C_NUM_QUEUES-1:0];
logic [PKT_VEC_WIDTH-1:0] phv_fifo_out [C_NUM_QUEUES-1:0];
logic last_stg_phv_out_valid [C_NUM_QUEUES-1:0];

logic phv_fifo_rd_en [C_NUM_QUEUES-1:0];
logic phv_fifo_nearly_full [C_NUM_QUEUES-1:0];
logic phv_fifo_empty [C_NUM_QUEUES-1:0];
logic [511:0] high_phv_out [C_NUM_QUEUES-1:0];
logic [511:0] low_phv_out [C_NUM_QUEUES-1:0];

assign phv_fifo_out[0] = {high_phv_out[0], low_phv_out[0]};
assign phv_fifo_out[1] = {high_phv_out[1], low_phv_out[1]};
assign phv_fifo_out[2] = {high_phv_out[2], low_phv_out[2]};
assign phv_fifo_out[3] = {high_phv_out[3], low_phv_out[3]};

generate 
	for (i=0; i<C_NUM_QUEUES; i=i+1) begin:
		sub_phv_fifo_1
		fallthrough_small_fifo #(
			.WIDTH(512),
			.MAX_DEPTH_BITS(6)
		)
		phv_fifo_1 (
			.clk			(clk),
			.reset			(~aresetn),
			.din			(last_stg_phv_out[i][511:0]),
			.wr_en			(last_stg_phv_out_valid[i]),
			.rd_en			(phv_fifo_rd_en[i]),
			.dout			(low_phv_out[i]),
			.full			(),
			.nearly_full		(phv_fifo_nearly_full[i]),
			.empty			(phv_fifo_empty[i])
		);
	end
endgenerate

generate
	for (i=0; i<C_NUM_QUEUES; i=i+1) begin:
		sub_phv_fifo_2
		fallthrough_small_fifo #(
			.WIDTH(512),
			.MAX_DEPTH_BITS(6)
		)
		phv_fifo_2 (
			.clk			(clk),
			.reset			(~aresetn),
			.din			(last_stg_phv_out[i][1023:512]),
			.wr_en			(last_stg_phv_out_valid[i]),
			.rd_en			(phv_fifo_rd_en[i]),
			.dout			(high_phv_out[i]),
			.full			(),
			.nearly_full		(),
			.empty			()
		);
	end
endgenerate

logic [C_S_AXIS_DATA_WIDTH-1:0] ctrl_s_axis_tdata_2;
logic [((C_S_AXIS_DATA_WIDTH/8))-1:0] ctrl_s_axis_tkeep_2;
logic [C_S_AXIS_TUSER_WIDTH-1:0] ctrl_s_axis_tuser_2;
logic ctrl_s_axis_tvalid_2;
logic ctrl_s_axis_tlast_2;

logic [C_S_AXIS_DATA_WIDTH-1:0] ctrl_s_axis_tdata_2_next;
logic [((C_S_AXIS_DATA_WIDTH/8))-1:0] ctrl_s_axis_tkeep_2_next;
logic [C_S_AXIS_TUSER_WIDTH-1:0] ctrl_s_axis_tuser_2_next;
logic ctrl_s_axis_tvalid_2_next;
logic ctrl_s_axis_tlast_2_next;

logic [C_S_AXIS_DATA_WIDTH-1:0] ctrl_s_axis_tdata_3;
logic [((C_S_AXIS_DATA_WIDTH/8))-1:0] ctrl_s_axis_tkeep_3;
logic [C_S_AXIS_TUSER_WIDTH-1:0] ctrl_s_axis_tuser_3;
logic ctrl_s_axis_tvalid_3;
logic ctrl_s_axis_tlast_3;

logic [C_S_AXIS_DATA_WIDTH-1:0] ctrl_s_axis_tdata_3_next;
logic [((C_S_AXIS_DATA_WIDTH/8))-1:0] ctrl_s_axis_tkeep_3_next;
logic [C_S_AXIS_TUSER_WIDTH-1:0] ctrl_s_axis_tuser_3_next;
logic ctrl_s_axis_tvalid_3_next;
logic ctrl_s_axis_tlast_3_next;

logic [C_S_AXIS_DATA_WIDTH-1:0] ctrl_s_axis_tdata_4;
logic [((C_S_AXIS_DATA_WIDTH/8))-1:0] ctrl_s_axis_tkeep_4;
logic [C_S_AXIS_TUSER_WIDTH-1:0] ctrl_s_axis_tuser_4;
logic ctrl_s_axis_tvalid_4;
logic ctrl_s_axis_tlast_4;

logic [C_S_AXIS_DATA_WIDTH-1:0] ctrl_s_axis_tdata_4_next;
logic [((C_S_AXIS_DATA_WIDTH/8))-1:0] ctrl_s_axis_tkeep_4_next;
logic [C_S_AXIS_TUSER_WIDTH-1:0] ctrl_s_axis_tuser_4_next;
logic ctrl_s_axis_tvalid_4_next;
logic ctrl_s_axis_tlast_4_next;

logic [C_S_AXIS_DATA_WIDTH-1:0] ctrl_s_axis_tdata_5;
logic [((C_S_AXIS_DATA_WIDTH/8))-1:0] ctrl_s_axis_tkeep_5;
logic [C_S_AXIS_TUSER_WIDTH-1:0] ctrl_s_axis_tuser_5;
logic ctrl_s_axis_tvalid_5;
logic ctrl_s_axis_tlast_5;

logic [C_S_AXIS_DATA_WIDTH-1:0] ctrl_s_axis_tdata_5_next;
logic [((C_S_AXIS_DATA_WIDTH/8))-1:0] ctrl_s_axis_tkeep_5_next;
logic [C_S_AXIS_TUSER_WIDTH-1:0] ctrl_s_axis_tuser_5_next;
logic ctrl_s_axis_tvalid_5_next;
logic ctrl_s_axis_tlast_5_next;

logic [C_S_AXIS_DATA_WIDTH-1:0] ctrl_s_axis_tdata_6;
logic [((C_S_AXIS_DATA_WIDTH/8))-1:0] ctrl_s_axis_tkeep_6;
logic [C_S_AXIS_TUSER_WIDTH-1:0] ctrl_s_axis_tuser_6;
logic ctrl_s_axis_tvalid_6;
logic ctrl_s_axis_tlast_6;

logic [C_S_AXIS_DATA_WIDTH-1:0] ctrl_s_axis_tdata_6_next;
logic [((C_S_AXIS_DATA_WIDTH/8))-1:0] ctrl_s_axis_tkeep_6_next;
logic [C_S_AXIS_TUSER_WIDTH-1:0] ctrl_s_axis_tuser_6_next;
logic ctrl_s_axis_tvalid_6_next;
logic ctrl_s_axis_tlast_6_next;

logic [C_S_AXIS_DATA_WIDTH-1:0] ctrl_s_axis_tdata_7;
logic [((C_S_AXIS_DATA_WIDTH/8))-1:0] ctrl_s_axis_tkeep_7;
logic [C_S_AXIS_TUSER_WIDTH-1:0] ctrl_s_axis_tuser_7;
logic ctrl_s_axis_tvalid_7;
logic ctrl_s_axis_tlast_7;

logic [C_S_AXIS_DATA_WIDTH-1:0] ctrl_s_axis_tdata_7_next;
logic [((C_S_AXIS_DATA_WIDTH/8))-1:0] ctrl_s_axis_tkeep_7_next;
logic [C_S_AXIS_TUSER_WIDTH-1:0] ctrl_s_axis_tuser_7_next;
logic ctrl_s_axis_tvalid_7_next;
logic ctrl_s_axis_tlast_7_next;

parser_top #(
	.C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH), //for 100g mac exclusively
	.C_S_AXIS_TUSER_WIDTH(),
	.PKT_HDR_LEN()
)
phv_parser
(
	.axis_clk		(clk),
	.aresetn		(aresetn),
	// input slvae axi stream
	.s_axis_tdata		(s_axis_tdata_f_next),
	.s_axis_tuser		(s_axis_tuser_f_next),
	.s_axis_tkeep		(s_axis_tkeep_f_next),
	// .s_axis_tvalid(s_axis_tvalid_f_next & s_axis_tready_f),
	.s_axis_tvalid		(s_axis_tvalid_f_next),
	.s_axis_tlast		(s_axis_tlast_f_next),
	.s_axis_tready		(s_axis_tready_p),

	.s_vlan_id		(s_vlan_id_next),
	.s_vlan_id_valid	(s_vlan_id_valid_next),

	// output
	.parser_valid		(stg0_phv_in_valid),
	.pkt_hdr_vec		(stg0_phv_in),
	.out_vlan		(stg0_vlan_in),
	.out_vlan_valid		(stg0_vlan_valid_in),
	.out_vlan_ready		(stg0_vlan_ready),
	// 
	.stg_ready_in		(stg0_ready),

	// output to different pkt fifos
	.m_axis_tdata_0		(parser_m_axis_tdata[0]),
	.m_axis_tuser_0		(parser_m_axis_tuser[0]),
	.m_axis_tkeep_0		(parser_m_axis_tkeep[0]),
	.m_axis_tlast_0		(parser_m_axis_tlast[0]),
	.m_axis_tvalid_0	(parser_m_axis_tvalid[0]),
	.m_axis_tready_0	(~pkt_fifo_nearly_full[0]),

	.m_axis_tdata_1		(parser_m_axis_tdata[1]),
	.m_axis_tuser_1		(parser_m_axis_tuser[1]),
	.m_axis_tkeep_1		(parser_m_axis_tkeep[1]),
	.m_axis_tlast_1		(parser_m_axis_tlast[1]),
	.m_axis_tvalid_1	(parser_m_axis_tvalid[1]),
	.m_axis_tready_1	(~pkt_fifo_nearly_full[1]),

	.m_axis_tdata_2		(parser_m_axis_tdata[2]),
	.m_axis_tuser_2		(parser_m_axis_tuser[2]),
	.m_axis_tkeep_2		(parser_m_axis_tkeep[2]),
	.m_axis_tlast_2		(parser_m_axis_tlast[2]),
	.m_axis_tvalid_2	(parser_m_axis_tvalid[2]),
	.m_axis_tready_2	(~pkt_fifo_nearly_full[2]),

	.m_axis_tdata_3		(parser_m_axis_tdata[3]),
	.m_axis_tuser_3		(parser_m_axis_tuser[3]),
	.m_axis_tkeep_3		(parser_m_axis_tkeep[3]),
	.m_axis_tlast_3		(parser_m_axis_tlast[3]),
	.m_axis_tvalid_3	(parser_m_axis_tvalid[3]),
	.m_axis_tready_3	(~pkt_fifo_nearly_full[3]),

	// control path
	.ctrl_s_axis_tdata	(ctrl_s_axis_tdata_1_next),
	.ctrl_s_axis_tuser	(ctrl_s_axis_tuser_1_next),
	.ctrl_s_axis_tkeep	(ctrl_s_axis_tkeep_1_next),
	.ctrl_s_axis_tlast	(ctrl_s_axis_tlast_1_next),
	.ctrl_s_axis_tvalid	(ctrl_s_axis_tvalid_1_next),

	.ctrl_m_axis_tdata	(ctrl_s_axis_tdata_2),
	.ctrl_m_axis_tuser	(ctrl_s_axis_tuser_2),
	.ctrl_m_axis_tkeep	(ctrl_s_axis_tkeep_2),
	.ctrl_m_axis_tlast	(ctrl_s_axis_tlast_2),
	.ctrl_m_axis_tvalid	(ctrl_s_axis_tvalid_2)
);


stage #(
	.C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
	.STAGE_ID(0)
)
stage0
(
	.axis_clk		(clk),
	.aresetn		(aresetn),

	// input
	.phv_in			(stg0_phv_in_next),
	.phv_in_valid		(stg0_phv_in_valid_next),
	.vlan_in		(stg0_vlan_in_next),
	.vlan_valid_in		(stg0_vlan_valid_in_next),
	.vlan_ready_out		(stg0_vlan_ready),
	// output
	.vlan_out		(stg0_vlan_out),
	.vlan_valid_out		(stg0_vlan_valid_out),
	.vlan_out_ready		(stg1_vlan_ready),
	// output
	.phv_out		(stg0_phv_out),
	.phv_out_valid		(stg0_phv_out_valid),
	// back-pressure signals
	.stage_ready_out	(stg0_ready),
	.stage_ready_in		(stg1_ready),

	// control path
	.c_s_axis_tdata		(ctrl_s_axis_tdata_2_next),
	.c_s_axis_tuser		(ctrl_s_axis_tuser_2_next),
	.c_s_axis_tkeep		(ctrl_s_axis_tkeep_2_next),
	.c_s_axis_tlast		(ctrl_s_axis_tlast_2_next),
	.c_s_axis_tvalid	(ctrl_s_axis_tvalid_2_next),

	.c_m_axis_tdata		(ctrl_s_axis_tdata_3),
	.c_m_axis_tuser		(ctrl_s_axis_tuser_3),
	.c_m_axis_tkeep		(ctrl_s_axis_tkeep_3),
	.c_m_axis_tlast		(ctrl_s_axis_tlast_3),
	.c_m_axis_tvalid	(ctrl_s_axis_tvalid_3)
);

stage #(
	.C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
	.STAGE_ID(1)
)
stage1
(
	.axis_clk		(clk),
	.aresetn		(aresetn),

	// input
	.phv_in			(stg0_phv_out_next),
	.phv_in_valid		(stg0_phv_out_valid_next),
	.vlan_in		(stg0_vlan_out_next),
	.vlan_valid_in		(stg0_vlan_valid_out_next),
	.vlan_ready_out		(stg1_vlan_ready),
	// output
	.vlan_out		(stg1_vlan_out),
	.vlan_valid_out		(stg1_vlan_valid_out),
	.vlan_out_ready		(stg2_vlan_ready),
	// output
	.phv_out		(stg1_phv_out),
	.phv_out_valid		(stg1_phv_out_valid),
	// back-pressure signals
	.stage_ready_out	(stg1_ready),
	.stage_ready_in		(stg2_ready),

	// control path
	.c_s_axis_tdata		(ctrl_s_axis_tdata_3_next),
	.c_s_axis_tuser		(ctrl_s_axis_tuser_3_next),
	.c_s_axis_tkeep		(ctrl_s_axis_tkeep_3_next),
	.c_s_axis_tlast		(ctrl_s_axis_tlast_3_next),
	.c_s_axis_tvalid	(ctrl_s_axis_tvalid_3_next),

	.c_m_axis_tdata		(ctrl_s_axis_tdata_4),
	.c_m_axis_tuser		(ctrl_s_axis_tuser_4),
	.c_m_axis_tkeep		(ctrl_s_axis_tkeep_4),
	.c_m_axis_tlast		(ctrl_s_axis_tlast_4),
	.c_m_axis_tvalid	(ctrl_s_axis_tvalid_4)
);

stage #(
	.C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
	.STAGE_ID(2)
)
stage2
(
	.axis_clk		(clk),
	.aresetn		(aresetn),

	// input
	.phv_in			(stg1_phv_out_next),
	.phv_in_valid		(stg1_phv_out_valid_next),
	.vlan_in		(stg1_vlan_out_next),
	.vlan_valid_in		(stg1_vlan_valid_out_next),
	.vlan_ready_out		(stg2_vlan_ready),
	// output
	.vlan_out		(stg2_vlan_out),
	.vlan_valid_out		(stg2_vlan_valid_out),
	.vlan_out_ready		(stg3_vlan_ready),
	// output
	.phv_out		(stg2_phv_out),
	.phv_out_valid		(stg2_phv_out_valid),
	// back-pressure signals
	.stage_ready_out	(stg2_ready),
	.stage_ready_in		(stg3_ready),

	// control path
	.c_s_axis_tdata		(ctrl_s_axis_tdata_4_next),
	.c_s_axis_tuser		(ctrl_s_axis_tuser_4_next),
	.c_s_axis_tkeep		(ctrl_s_axis_tkeep_4_next),
	.c_s_axis_tlast		(ctrl_s_axis_tlast_4_next),
	.c_s_axis_tvalid	(ctrl_s_axis_tvalid_4_next),

	.c_m_axis_tdata		(ctrl_s_axis_tdata_5),
	.c_m_axis_tuser		(ctrl_s_axis_tuser_5),
	.c_m_axis_tkeep		(ctrl_s_axis_tkeep_5),
	.c_m_axis_tlast		(ctrl_s_axis_tlast_5),
	.c_m_axis_tvalid	(ctrl_s_axis_tvalid_5)
);

stage #(
	.C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
	.STAGE_ID(3)
)
stage3
(
	.axis_clk		(clk),
	.aresetn		(aresetn),

	// input
	.phv_in			(stg2_phv_out_next),
	.phv_in_valid		(stg2_phv_out_valid_next),
	.vlan_in		(stg2_vlan_out_next),
	.vlan_valid_in		(stg2_vlan_valid_out_next),
	.vlan_ready_out		(stg3_vlan_ready),
	// output
	.vlan_out		(stg3_vlan_out),
	.vlan_valid_out		(stg3_vlan_valid_out),
	.vlan_out_ready		(last_stg_vlan_ready),
	// output
	.phv_out		(stg3_phv_out),
	.phv_out_valid		(stg3_phv_out_valid),
	// back-pressure signals
	.stage_ready_out	(stg3_ready),
	.stage_ready_in		(last_stg_ready),

	// control path
	.c_s_axis_tdata		(ctrl_s_axis_tdata_5_next),
	.c_s_axis_tuser		(ctrl_s_axis_tuser_5_next),
	.c_s_axis_tkeep		(ctrl_s_axis_tkeep_5_next),
	.c_s_axis_tlast		(ctrl_s_axis_tlast_5_next),
	.c_s_axis_tvalid	(ctrl_s_axis_tvalid_5_next),

	.c_m_axis_tdata		(ctrl_s_axis_tdata_6),
	.c_m_axis_tuser		(ctrl_s_axis_tuser_6),
	.c_m_axis_tkeep		(ctrl_s_axis_tkeep_6),
	.c_m_axis_tlast		(ctrl_s_axis_tlast_6),
	.c_m_axis_tvalid	(ctrl_s_axis_tvalid_6)
);


// [NOTICE] change to last stage
last_stage #(
	.C_S_AXIS_DATA_WIDTH(512),
	.STAGE_ID(4)
)
stage4
(
	.axis_clk		(clk),
	.aresetn		(aresetn),

	// input
	.phv_in			(stg3_phv_out_next),
	.phv_in_valid		(stg3_phv_out_valid_next),
	.vlan_in		(stg3_vlan_out_next),
	.vlan_valid_in		(stg3_vlan_valid_out_next),
	.vlan_ready_out		(last_stg_vlan_ready),
	// back-pressure signals
	.stage_ready_out	(last_stg_ready),
	// output
	.phv_out_0		(last_stg_phv_out[0]),
	.phv_out_valid_0	(last_stg_phv_out_valid[0]),
	.phv_fifo_ready_0	(~phv_fifo_nearly_full[0]),

	.phv_out_1		(last_stg_phv_out[1]),
	.phv_out_valid_1	(last_stg_phv_out_valid[1]),
	.phv_fifo_ready_1	(~phv_fifo_nearly_full[1]),

	.phv_out_2		(last_stg_phv_out[2]),
	.phv_out_valid_2	(last_stg_phv_out_valid[2]),
	.phv_fifo_ready_2	(~phv_fifo_nearly_full[2]),

	.phv_out_3		(last_stg_phv_out[3]),
	.phv_out_valid_3	(last_stg_phv_out_valid[3]),
	.phv_fifo_ready_3	(~phv_fifo_nearly_full[3]),

	// control path
	.c_s_axis_tdata		(ctrl_s_axis_tdata_6_next),
	.c_s_axis_tuser		(ctrl_s_axis_tuser_6_next),
	.c_s_axis_tkeep		(ctrl_s_axis_tkeep_6_next),
	.c_s_axis_tlast		(ctrl_s_axis_tlast_6_next),
	.c_s_axis_tvalid	(ctrl_s_axis_tvalid_6_next),

	.c_m_axis_tdata		(ctrl_s_axis_tdata_7),
	.c_m_axis_tuser		(ctrl_s_axis_tuser_7),
	.c_m_axis_tkeep		(ctrl_s_axis_tkeep_7),
	.c_m_axis_tlast		(ctrl_s_axis_tlast_7),
	.c_m_axis_tvalid	(ctrl_s_axis_tvalid_7)
);


logic [C_S_AXIS_DATA_WIDTH-1:0] depar_out_tdata [C_NUM_QUEUES-1:0];
logic [((C_S_AXIS_DATA_WIDTH/8))-1:0] depar_out_tkeep [C_NUM_QUEUES-1:0];
logic [C_S_AXIS_TUSER_WIDTH-1:0] depar_out_tuser [C_NUM_QUEUES-1:0];
logic depar_out_tvalid [C_NUM_QUEUES-1:0];
logic depar_out_tlast [C_NUM_QUEUES-1:0];
logic depar_out_tready [C_NUM_QUEUES-1:0];

logic [C_S_AXIS_DATA_WIDTH-1:0] depar_out_tdata_next [C_NUM_QUEUES-1:0];
logic [((C_S_AXIS_DATA_WIDTH/8))-1:0] depar_out_tkeep_next [C_NUM_QUEUES-1:0];
logic [C_S_AXIS_TUSER_WIDTH-1:0] depar_out_tuser_next [C_NUM_QUEUES-1:0];
logic depar_out_tvalid_next [C_NUM_QUEUES-1:0];
logic depar_out_tlast_next [C_NUM_QUEUES-1:0];

// multiple deparser + output arbiter
generate
	for (i=0; i<C_NUM_QUEUES; i=i+1) begin:
		sub_deparser_top
		deparser_top #(
			.C_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
			.C_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH),
			.C_PKT_VEC_WIDTH(),
			.DEPARSER_MOD_ID()
		)
		phv_deparser (
			.axis_clk		(clk),
			.aresetn		(aresetn),
		
			//data plane
			.pkt_fifo_tdata		(pkt_fifo_tdata_out[i]),
			.pkt_fifo_tkeep		(pkt_fifo_tkeep_out[i]),
			.pkt_fifo_tuser		(pkt_fifo_tuser_out[i]),
			.pkt_fifo_tlast		(pkt_fifo_tlast_out[i]),
			.pkt_fifo_empty		(pkt_fifo_empty[i]),
			// output from STAGE
			.pkt_fifo_rd_en		(pkt_fifo_rd_en[i]),
		
			.phv_fifo_out		(phv_fifo_out[i]),
			.phv_fifo_empty		(phv_fifo_empty[i]),
			.phv_fifo_rd_en		(phv_fifo_rd_en[i]),
			// output
			.depar_out_tdata	(depar_out_tdata[i]),
			.depar_out_tkeep	(depar_out_tkeep[i]),
			.depar_out_tuser	(depar_out_tuser[i]),
			.depar_out_tvalid	(depar_out_tvalid[i]),
			.depar_out_tlast	(depar_out_tlast[i]),
			// input
			.depar_out_tready	(depar_out_tready[i]),
		
			//control path
			.ctrl_s_axis_tdata	(ctrl_s_axis_tdata_7_next),
			.ctrl_s_axis_tuser	(ctrl_s_axis_tuser_7_next),
			.ctrl_s_axis_tkeep	(ctrl_s_axis_tkeep_7_next),
			.ctrl_s_axis_tvalid	(ctrl_s_axis_tvalid_7_next),
			.ctrl_s_axis_tlast	(ctrl_s_axis_tlast_7_next)
		);
	end
endgenerate

// output arbiter
output_arbiter #(
	.C_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
	.C_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH)
)
out_arb (
	.axis_clk		(clk),
	.aresetn		(aresetn),
	// output
	.m_axis_tdata		(m_axis_tdata),
	.m_axis_tkeep		(m_axis_tkeep),
	.m_axis_tuser		(m_axis_tuser),
	.m_axis_tlast		(m_axis_tlast),
	.m_axis_tvalid		(m_axis_tvalid),
	.m_axis_tready		(m_axis_tready),
	// input from deparser
	.s_axis_tdata_0		(depar_out_tdata_next[0]),
	.s_axis_tkeep_0		(depar_out_tkeep_next[0]),
	.s_axis_tuser_0		(depar_out_tuser_next[0]),
	.s_axis_tlast_0		(depar_out_tlast_next[0]),
	.s_axis_tvalid_0	(depar_out_tvalid_next[0]),
	.s_axis_tready_0	(depar_out_tready[0]),

	.s_axis_tdata_1		(depar_out_tdata_next[1]),
	.s_axis_tkeep_1		(depar_out_tkeep_next[1]),
	.s_axis_tuser_1		(depar_out_tuser_next[1]),
	.s_axis_tlast_1		(depar_out_tlast_next[1]),
	.s_axis_tvalid_1	(depar_out_tvalid_next[1]),
	.s_axis_tready_1	(depar_out_tready[1]),

	.s_axis_tdata_2		(depar_out_tdata_next[2]),
	.s_axis_tkeep_2		(depar_out_tkeep_next[2]),
	.s_axis_tuser_2		(depar_out_tuser_next[2]),
	.s_axis_tlast_2		(depar_out_tlast_next[2]),
	.s_axis_tvalid_2	(depar_out_tvalid_next[2]),
	.s_axis_tready_2	(depar_out_tready[2]),

	.s_axis_tdata_3		(depar_out_tdata_next[3]),
	.s_axis_tkeep_3		(depar_out_tkeep_next[3]),
	.s_axis_tuser_3		(depar_out_tuser_next[3]),
	.s_axis_tlast_3		(depar_out_tlast_next[3]),
	.s_axis_tvalid_3	(depar_out_tvalid_next[3]),
	.s_axis_tready_3	(depar_out_tready[3])
);


always_ff @(posedge clk) begin
	if (~aresetn) begin
		stg0_phv_in_valid_next <= 0;
		stg0_phv_out_valid_next <= 0;
		stg1_phv_out_valid_next <= 0;
		stg2_phv_out_valid_next <= 0;
		stg3_phv_out_valid_next <= 0;

		stg0_phv_in_next <= 0;
		stg0_phv_out_next <= 0;
		stg1_phv_out_next <= 0;
		stg2_phv_out_next <= 0;
		stg3_phv_out_next <= 0;

		s_axis_tdata_f_next <= 0;
		s_axis_tkeep_f_next <= 0;
		s_axis_tuser_f_next <= 0;
		s_axis_tlast_f_next <= 0;
		s_axis_tvalid_f_next <= 0;

		s_vlan_id_next <= 0;
		s_vlan_id_valid_next <= 0;

		stg0_vlan_in_next <= 0;
		stg0_vlan_valid_in_next <= 0;
		stg0_vlan_out_next <= 0;
		stg0_vlan_valid_out_next <= 0;
		stg1_vlan_out_next <= 0;
		stg1_vlan_valid_out_next <= 0;
		stg2_vlan_out_next <= 0;
		stg2_vlan_valid_out_next <= 0;
		stg3_vlan_out_next <= 0;
		stg3_vlan_valid_out_next <= 0;
	end
	else begin
		stg0_phv_in_valid_next <= stg0_phv_in_valid;
		stg0_phv_out_valid_next <= stg0_phv_out_valid;
		stg1_phv_out_valid_next <= stg1_phv_out_valid;
		stg2_phv_out_valid_next <= stg2_phv_out_valid;
		stg3_phv_out_valid_next <= stg3_phv_out_valid;

		stg0_phv_in_next <= stg0_phv_in;
		stg0_phv_out_next <= stg0_phv_out;
		stg1_phv_out_next <= stg1_phv_out;
		stg2_phv_out_next <= stg2_phv_out;
		stg3_phv_out_next <= stg3_phv_out;

		s_axis_tdata_f_next <= s_axis_tdata_f;
		s_axis_tkeep_f_next <= s_axis_tkeep_f;
		s_axis_tuser_f_next <= s_axis_tuser_f;
		s_axis_tlast_f_next <= s_axis_tlast_f;
		s_axis_tvalid_f_next <= s_axis_tvalid_f;

		s_vlan_id_next <= s_vlan_id;
		s_vlan_id_valid_next <= s_vlan_id_valid;

		stg0_vlan_in_next <= stg0_vlan_in;
		stg0_vlan_valid_in_next <= stg0_vlan_valid_in;
		stg0_vlan_out_next <= stg0_vlan_out;
		stg0_vlan_valid_out_next <= stg0_vlan_valid_out;
		stg1_vlan_out_next <= stg1_vlan_out;
		stg1_vlan_valid_out_next <= stg1_vlan_valid_out;
		stg2_vlan_out_next <= stg2_vlan_out;
		stg2_vlan_valid_out_next <= stg2_vlan_valid_out;
		stg3_vlan_out_next <= stg3_vlan_out;
		stg3_vlan_valid_out_next <= stg3_vlan_valid_out;
	end
end

// delay deparser out
always_ff @(posedge clk) begin
	if (~aresetn) begin
		for (idx=0; idx<C_NUM_QUEUES; idx=idx+1) begin
			depar_out_tdata_next[idx] <= 0;
			depar_out_tkeep_next[idx] <= 0;
			depar_out_tuser_next[idx] <= 0;
			depar_out_tvalid_next[idx] <= 0;
			depar_out_tlast_next[idx] <= 0;
		end
	end
	else begin
		for (idx=0; idx<C_NUM_QUEUES; idx=idx+1) begin
			depar_out_tdata_next[idx] <= depar_out_tdata[idx];
			depar_out_tkeep_next[idx] <= depar_out_tkeep[idx];
			depar_out_tuser_next[idx] <= depar_out_tuser[idx];
			depar_out_tvalid_next[idx] <= depar_out_tvalid[idx];
			depar_out_tlast_next[idx] <= depar_out_tlast[idx];
		end
	end
end

always_ff @(posedge clk) begin
	if (~aresetn) begin
		ctrl_s_axis_tdata_1_next <= 0;
		ctrl_s_axis_tuser_1_next <= 0;
		ctrl_s_axis_tkeep_1_next <= 0;
		ctrl_s_axis_tlast_1_next <= 0;
		ctrl_s_axis_tvalid_1_next <= 0;

		ctrl_s_axis_tdata_2_next <= 0;
		ctrl_s_axis_tuser_2_next <= 0;
		ctrl_s_axis_tkeep_2_next <= 0;
		ctrl_s_axis_tlast_2_next <= 0;
		ctrl_s_axis_tvalid_2_next <= 0;

		ctrl_s_axis_tdata_3_next <= 0;
		ctrl_s_axis_tuser_3_next <= 0;
		ctrl_s_axis_tkeep_3_next <= 0;
		ctrl_s_axis_tlast_3_next <= 0;
		ctrl_s_axis_tvalid_3_next <= 0;

		ctrl_s_axis_tdata_4_next <= 0;
		ctrl_s_axis_tuser_4_next <= 0;
		ctrl_s_axis_tkeep_4_next <= 0;
		ctrl_s_axis_tlast_4_next <= 0;
		ctrl_s_axis_tvalid_4_next <= 0;

		ctrl_s_axis_tdata_5_next <= 0;
		ctrl_s_axis_tuser_5_next <= 0;
		ctrl_s_axis_tkeep_5_next <= 0;
		ctrl_s_axis_tlast_5_next <= 0;
		ctrl_s_axis_tvalid_5_next <= 0;

		ctrl_s_axis_tdata_6_next <= 0;
		ctrl_s_axis_tuser_6_next <= 0;
		ctrl_s_axis_tkeep_6_next <= 0;
		ctrl_s_axis_tlast_6_next <= 0;
		ctrl_s_axis_tvalid_6_next <= 0;

		ctrl_s_axis_tdata_7_next <= 0;
		ctrl_s_axis_tuser_7_next <= 0;
		ctrl_s_axis_tkeep_7_next <= 0;
		ctrl_s_axis_tlast_7_next <= 0;
		ctrl_s_axis_tvalid_7_next <= 0;
	end
	else begin
		ctrl_s_axis_tdata_1_next <= ctrl_s_axis_tdata_1;
		ctrl_s_axis_tuser_1_next <= ctrl_s_axis_tuser_1;
		ctrl_s_axis_tkeep_1_next <= ctrl_s_axis_tkeep_1;
		ctrl_s_axis_tlast_1_next <= ctrl_s_axis_tlast_1;
		ctrl_s_axis_tvalid_1_next <= ctrl_s_axis_tvalid_1;

		ctrl_s_axis_tdata_2_next <= ctrl_s_axis_tdata_2;
		ctrl_s_axis_tuser_2_next <= ctrl_s_axis_tuser_2;
		ctrl_s_axis_tkeep_2_next <= ctrl_s_axis_tkeep_2;
		ctrl_s_axis_tlast_2_next <= ctrl_s_axis_tlast_2;
		ctrl_s_axis_tvalid_2_next <= ctrl_s_axis_tvalid_2;

		ctrl_s_axis_tdata_3_next <= ctrl_s_axis_tdata_3;
		ctrl_s_axis_tuser_3_next <= ctrl_s_axis_tuser_3;
		ctrl_s_axis_tkeep_3_next <= ctrl_s_axis_tkeep_3;
		ctrl_s_axis_tlast_3_next <= ctrl_s_axis_tlast_3;
		ctrl_s_axis_tvalid_3_next <= ctrl_s_axis_tvalid_3;

		ctrl_s_axis_tdata_4_next <= ctrl_s_axis_tdata_4;
		ctrl_s_axis_tuser_4_next <= ctrl_s_axis_tuser_4;
		ctrl_s_axis_tkeep_4_next <= ctrl_s_axis_tkeep_4;
		ctrl_s_axis_tlast_4_next <= ctrl_s_axis_tlast_4;
		ctrl_s_axis_tvalid_4_next <= ctrl_s_axis_tvalid_4;

		ctrl_s_axis_tdata_5_next <= ctrl_s_axis_tdata_5;
		ctrl_s_axis_tuser_5_next <= ctrl_s_axis_tuser_5;
		ctrl_s_axis_tkeep_5_next <= ctrl_s_axis_tkeep_5;
		ctrl_s_axis_tlast_5_next <= ctrl_s_axis_tlast_5;
		ctrl_s_axis_tvalid_5_next <= ctrl_s_axis_tvalid_5;

		ctrl_s_axis_tdata_6_next <= ctrl_s_axis_tdata_6;
		ctrl_s_axis_tuser_6_next <= ctrl_s_axis_tuser_6;
		ctrl_s_axis_tkeep_6_next <= ctrl_s_axis_tkeep_6;
		ctrl_s_axis_tlast_6_next <= ctrl_s_axis_tlast_6;
		ctrl_s_axis_tvalid_6_next <= ctrl_s_axis_tvalid_6;

		ctrl_s_axis_tdata_7_next <= ctrl_s_axis_tdata_7;
		ctrl_s_axis_tuser_7_next <= ctrl_s_axis_tuser_7;
		ctrl_s_axis_tkeep_7_next <= ctrl_s_axis_tkeep_7;
		ctrl_s_axis_tlast_7_next <= ctrl_s_axis_tlast_7;
		ctrl_s_axis_tvalid_7_next <= ctrl_s_axis_tvalid_7;

	end
end

endmodule
