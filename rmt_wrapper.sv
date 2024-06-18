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
	parameter C_FIFO_BIT_WIDTH = 4,
	parameter NUM_OF_STAGES = 5
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

// logic just for the first stage
logic stg0_phv_in_valid;
logic stg0_phv_in_valid_sv;
logic [PKT_VEC_WIDTH-1:0] stg0_phv_in;
logic [PKT_VEC_WIDTH-1:0] stg0_phv_in_sv;
logic [C_VLANID_WIDTH-1:0] stg0_vlan_in;
logic [C_VLANID_WIDTH-1:0] stg0_vlan_in_sv;
logic stg0_vlan_valid_in;
logic stg0_vlan_valid_in_sv;

// logic parametric in the number of stages
logic [PKT_VEC_WIDTH-1:0] stg_phv_out [NUM_OF_STAGES-2:0];
logic [PKT_VEC_WIDTH-1:0] stg_phv_out_sv [NUM_OF_STAGES-2:0];
logic stg_phv_out_valid [NUM_OF_STAGES-2:0];
logic stg_phv_out_valid_sv [NUM_OF_STAGES-2:0];
logic stg_vlan_ready [NUM_OF_STAGES-1:0];
logic [C_VLANID_WIDTH-1:0] stg_vlan_out [NUM_OF_STAGES-2:0];
logic [C_VLANID_WIDTH-1:0] stg_vlan_out_sv [NUM_OF_STAGES-2:0];
logic stg_vlan_valid_out [NUM_OF_STAGES-2:0];
logic stg_vlan_valid_out_sv [NUM_OF_STAGES-2:0];

// back pressure signals
logic s_axis_tready_p;
logic stg_ready[NUM_OF_STAGES-1:0];


/*=================================================*/

logic [C_VLANID_WIDTH-1:0] s_vlan_id;
logic s_vlan_id_valid;

logic [C_VLANID_WIDTH-1:0] s_vlan_id_sv;
logic s_vlan_id_valid_sv;

//NOTE: to filter out packets other than UDP/IP.
logic [C_S_AXIS_DATA_WIDTH-1:0] s_axis_tdata_f;
logic [(C_S_AXIS_DATA_WIDTH/8)-1:0] s_axis_tkeep_f;
logic [C_S_AXIS_TUSER_WIDTH-1:0] s_axis_tuser_f;
logic s_axis_tvalid_f;
logic s_axis_tready_f;
logic s_axis_tlast_f;

logic [C_S_AXIS_DATA_WIDTH-1:0] s_axis_tdata_f_sv;
logic [(C_S_AXIS_DATA_WIDTH/8)-1:0] s_axis_tkeep_f_sv;
logic [C_S_AXIS_TUSER_WIDTH-1:0] s_axis_tuser_f_sv;
logic s_axis_tvalid_f_sv;
logic s_axis_tlast_f_sv;

//NOTE: filter control packets from data packets.
logic [C_S_AXIS_DATA_WIDTH-1:0] ctrl_s_axis_tdata [NUM_OF_STAGES+1:0];
logic [(C_S_AXIS_DATA_WIDTH/8)-1:0] ctrl_s_axis_tkeep [NUM_OF_STAGES+1:0];
logic [C_S_AXIS_TUSER_WIDTH-1:0] ctrl_s_axis_tuser [NUM_OF_STAGES+1:0];
logic ctrl_s_axis_tvalid [NUM_OF_STAGES+1:0];
logic ctrl_s_axis_tlast [NUM_OF_STAGES+1:0];

logic [C_S_AXIS_DATA_WIDTH-1:0] ctrl_s_axis_tdata_sv [NUM_OF_STAGES+1:0];
logic [(C_S_AXIS_DATA_WIDTH/8)-1:0] ctrl_s_axis_tkeep_sv [NUM_OF_STAGES+1:0];
logic [C_S_AXIS_TUSER_WIDTH-1:0] ctrl_s_axis_tuser_sv [NUM_OF_STAGES+1:0];
logic ctrl_s_axis_tvalid_sv [NUM_OF_STAGES+1:0];
logic ctrl_s_axis_tlast_sv [NUM_OF_STAGES+1:0];



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
	.c_m_axis_tdata		(ctrl_s_axis_tdata[0]),
	.c_m_axis_tkeep		(ctrl_s_axis_tkeep[0]),
	.c_m_axis_tuser		(ctrl_s_axis_tuser[0]),
	.c_m_axis_tvalid	(ctrl_s_axis_tvalid[0]),
	.c_m_axis_tlast		(ctrl_s_axis_tlast[0])
);

// we will have multiple pkt fifos and phv fifos
// pkt fifo logics
logic [C_S_AXIS_DATA_WIDTH-1:0] pkt_fifo_tdata_out [C_NUM_QUEUES-1:0];
logic [C_S_AXIS_TUSER_WIDTH-1:0] pkt_fifo_tuser_out [C_NUM_QUEUES-1:0];
logic [(C_S_AXIS_DATA_WIDTH/8)-1:0] pkt_fifo_tkeep_out [C_NUM_QUEUES-1:0];
logic pkt_fifo_tlast_out [C_NUM_QUEUES-1:0];

// output from parser
logic [C_S_AXIS_DATA_WIDTH-1:0] parser_m_axis_tdata [C_NUM_QUEUES-1:0];
logic [C_S_AXIS_TUSER_WIDTH-1:0] parser_m_axis_tuser [C_NUM_QUEUES-1:0];
logic [(C_S_AXIS_DATA_WIDTH/8)-1:0] parser_m_axis_tkeep [C_NUM_QUEUES-1:0];
logic parser_m_axis_tlast [C_NUM_QUEUES-1:0];
logic parser_m_axis_tvalid [C_NUM_QUEUES-1:0];

logic pkt_fifo_rd_en [C_NUM_QUEUES-1:0];
logic [C_NUM_QUEUES-1:0] pkt_fifo_nearly_full;
logic pkt_fifo_empty [C_NUM_QUEUES-1:0];

assign s_axis_tready_f = ~|pkt_fifo_nearly_full;
// equivalent to the old:
// assign s_axis_tready_f = !pkt_fifo_nearly_full[0] && !pkt_fifo_nearly_full[1] &&
//                          !pkt_fifo_nearly_full[2] && !pkt_fifo_nearly_full[3];

genvar i;
// create a fifo interposed between the parser and the data cache
generate
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
logic [(PKT_VEC_WIDTH/2):0] high_phv_out [C_NUM_QUEUES-1:0];
logic [(PKT_VEC_WIDTH/2):0] low_phv_out [C_NUM_QUEUES-1:0];

generate
	for (i=0; i<C_NUM_QUEUES; i=i+1) begin
		assign phv_fifo_out[i] = {high_phv_out[i], low_phv_out[i]};
	end
endgenerate

// create 2 fifos (since each fifo is half the size of the phv) interposed between the phv exiting from the last stage and the phv entering the deparser
generate 
	for (i=0; i<C_NUM_QUEUES; i=i+1) begin:
		sub_phv_fifo_1
		fallthrough_small_fifo #(
			.WIDTH(PKT_VEC_WIDTH/2),
			.MAX_DEPTH_BITS(6)
		)
		phv_fifo_1 (
			.clk			(clk),
			.reset			(~aresetn),
			.din			(last_stg_phv_out[i][(PKT_VEC_WIDTH/2)-1:0]),
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
			.WIDTH(PKT_VEC_WIDTH/2),
			.MAX_DEPTH_BITS(6)
		)
		phv_fifo_2 (
			.clk			(clk),
			.reset			(~aresetn),
			.din			(last_stg_phv_out[i][PKT_VEC_WIDTH-1:(PKT_VEC_WIDTH/2)]),
			.wr_en			(last_stg_phv_out_valid[i]),
			.rd_en			(phv_fifo_rd_en[i]),
			.dout			(high_phv_out[i]),
			.full			(),
			.nearly_full		(),
			.empty			()
		);
	end
endgenerate

parser_top #(
	.C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH), //for 100g mac exclusively
	.C_S_AXIS_TUSER_WIDTH(),
	.PKT_HDR_LEN()
)
phv_parser
(
	.axis_clk		(clk),
	.aresetn		(aresetn),
	// input slave axi stream
	.s_axis_tdata		(s_axis_tdata_f_sv),
	.s_axis_tuser		(s_axis_tuser_f_sv),
	.s_axis_tkeep		(s_axis_tkeep_f_sv),
	// .s_axis_tvalid(s_axis_tvalid_f_sv & s_axis_tready_f),
	.s_axis_tvalid		(s_axis_tvalid_f_sv),
	.s_axis_tlast		(s_axis_tlast_f_sv),
	.s_axis_tready		(s_axis_tready_p),

	.s_vlan_id		(s_vlan_id_sv),
	.s_vlan_id_valid	(s_vlan_id_valid_sv),

	// output
	.parser_valid		(stg0_phv_in_valid),
	.pkt_hdr_vec		(stg0_phv_in),
	.out_vlan		(stg0_vlan_in),
	.out_vlan_valid		(stg0_vlan_valid_in),
	.out_vlan_ready		(stg_vlan_ready[0]),
	// 
	.stg_ready_in		(stg_ready[0]),

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
	.ctrl_s_axis_tdata	(ctrl_s_axis_tdata_sv[0]),
	.ctrl_s_axis_tuser	(ctrl_s_axis_tuser_sv[0]),
	.ctrl_s_axis_tkeep	(ctrl_s_axis_tkeep_sv[0]),
	.ctrl_s_axis_tlast	(ctrl_s_axis_tlast_sv[0]),
	.ctrl_s_axis_tvalid	(ctrl_s_axis_tvalid_sv[0]),

	.ctrl_m_axis_tdata	(ctrl_s_axis_tdata[1]),
	.ctrl_m_axis_tuser	(ctrl_s_axis_tuser[1]),
	.ctrl_m_axis_tkeep	(ctrl_s_axis_tkeep[1]),
	.ctrl_m_axis_tlast	(ctrl_s_axis_tlast[1]),
	.ctrl_m_axis_tvalid	(ctrl_s_axis_tvalid[1])
);

stage #(
	.C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
	.STAGE_ID(0)
)
first_stage
(
	.axis_clk		(clk),
	.aresetn		(aresetn),

	// input
	.phv_in			(stg0_phv_in_sv),
	.phv_in_valid		(stg0_phv_in_valid_sv),
	.vlan_in		(stg0_vlan_in_sv),
	.vlan_valid_in		(stg0_vlan_valid_in_sv),
	.vlan_ready_out		(stg_vlan_ready[0]),
	// output
	.vlan_out		(stg_vlan_out[0]),
	.vlan_valid_out		(stg_vlan_valid_out[0]),
	.vlan_out_ready		(stg_vlan_ready[1]),
	// output
	.phv_out		(stg_phv_out[0]),
	.phv_out_valid		(stg_phv_out_valid[0]),
	// back-pressure signals
	.stage_ready_out	(stg_ready[0]),
	.stage_ready_in		(stg_ready[1]),

	// control path
	.c_s_axis_tdata		(ctrl_s_axis_tdata_sv[1]),
	.c_s_axis_tuser		(ctrl_s_axis_tuser_sv[1]),
	.c_s_axis_tkeep		(ctrl_s_axis_tkeep_sv[1]),
	.c_s_axis_tlast		(ctrl_s_axis_tlast_sv[1]),
	.c_s_axis_tvalid	(ctrl_s_axis_tvalid_sv[1]),

	.c_m_axis_tdata		(ctrl_s_axis_tdata[2]),
	.c_m_axis_tuser		(ctrl_s_axis_tuser[2]),
	.c_m_axis_tkeep		(ctrl_s_axis_tkeep[2]),
	.c_m_axis_tlast		(ctrl_s_axis_tlast[2]),
	.c_m_axis_tvalid	(ctrl_s_axis_tvalid[2])
);


generate
	for (i=0; i<NUM_OF_STAGES+2; i=i+1) begin
		always_ff @(posedge clk) begin
			if (~aresetn) begin
				ctrl_s_axis_tdata_sv[i] <= {C_S_AXIS_DATA_WIDTH{1'b 0}};
				ctrl_s_axis_tuser_sv[i] <= {C_S_AXIS_TUSER_WIDTH{1'b 0}};
				ctrl_s_axis_tkeep_sv[i] <= {(C_S_AXIS_DATA_WIDTH/8){1'b 0}};
				ctrl_s_axis_tlast_sv[i] <= 0;
				ctrl_s_axis_tvalid_sv[i] <= 0;
			end
			else begin
				ctrl_s_axis_tdata_sv[i] <= ctrl_s_axis_tdata[i];
				ctrl_s_axis_tuser_sv[i] <= ctrl_s_axis_tuser[i];
				ctrl_s_axis_tkeep_sv[i] <= ctrl_s_axis_tkeep[i];
				ctrl_s_axis_tlast_sv[i] <= ctrl_s_axis_tlast[i];
				ctrl_s_axis_tvalid_sv[i] <= ctrl_s_axis_tvalid[i];
			end
		end
	end
endgenerate

generate
	for (i=0; i<NUM_OF_STAGES-1; i=i+1) begin
		always_ff @(posedge clk) begin
			if (~aresetn) begin
				stg_phv_out_sv[i] <= {PKT_VEC_WIDTH{1'b 0}};
				stg_phv_out_valid_sv[i] <= 0;
				stg_vlan_out_sv[i] <= {C_VLANID_WIDTH{1'b 0}};
				stg_vlan_valid_out_sv[i] <= 0;
			end
			else begin
				stg_phv_out_sv[i] <= stg_phv_out[i];
				stg_phv_out_valid_sv[i] <= stg_phv_out_valid[i];
				stg_vlan_out_sv[i] <= stg_vlan_out[i];
				stg_vlan_valid_out_sv[i] <= stg_vlan_valid_out[i];
			end
		end
	end
endgenerate

generate
	for (i=0; i<NUM_OF_STAGES-2; i=i+1) begin:
		middle_stage
		stage #(
			.C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
			.STAGE_ID(i+1)
		)
		stage_i
		(
			.axis_clk		(clk),
			.aresetn		(aresetn),

			// input
			.phv_in			(stg_phv_out_sv[i]),
			.phv_in_valid		(stg_phv_out_valid_sv[i]),
			.vlan_in		(stg_vlan_out_sv[i]),
			.vlan_valid_in		(stg_vlan_valid_out_sv[i]),
			.vlan_ready_out		(stg_vlan_ready[i+1]),
			// output
			.vlan_out		(stg_vlan_out[i+1]),
			.vlan_valid_out		(stg_vlan_valid_out[i+1]),
			.vlan_out_ready		(stg_vlan_ready[i+2]),
			// output
			.phv_out		(stg_phv_out[i+1]),
			.phv_out_valid		(stg_phv_out_valid[i+1]),
			// back-pressure signals
			.stage_ready_out	(stg_ready[i+1]),
			.stage_ready_in		(stg_ready[i+2]),

			// control path
			.c_s_axis_tdata		(ctrl_s_axis_tdata_sv[i+2]),
			.c_s_axis_tuser		(ctrl_s_axis_tuser_sv[i+2]),
			.c_s_axis_tkeep		(ctrl_s_axis_tkeep_sv[i+2]),
			.c_s_axis_tlast		(ctrl_s_axis_tlast_sv[i+2]),
			.c_s_axis_tvalid	(ctrl_s_axis_tvalid_sv[i+2]),

			.c_m_axis_tdata		(ctrl_s_axis_tdata[i+3]),
			.c_m_axis_tuser		(ctrl_s_axis_tuser[i+3]),
			.c_m_axis_tkeep		(ctrl_s_axis_tkeep[i+3]),
			.c_m_axis_tlast		(ctrl_s_axis_tlast[i+3]),
			.c_m_axis_tvalid	(ctrl_s_axis_tvalid[i+3])
		);
	end
endgenerate

// [NOTICE] change to last stage
last_stage #(
	.C_S_AXIS_DATA_WIDTH(512),
	//.C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
	.STAGE_ID(NUM_OF_STAGES)
)
final_stage
(
	.axis_clk		(clk),
	.aresetn		(aresetn),

	// input
	.phv_in			(stg_phv_out_sv[NUM_OF_STAGES-2]),
	.phv_in_valid		(stg_phv_out_valid_sv[NUM_OF_STAGES-2]),
	.vlan_in		(stg_vlan_out_sv[NUM_OF_STAGES-2]),
	.vlan_valid_in		(stg_vlan_valid_out_sv[NUM_OF_STAGES-2]),
	.vlan_ready_out		(stg_vlan_ready[NUM_OF_STAGES-1]),
	// back-pressure signals
	.stage_ready_out	(stg_ready[NUM_OF_STAGES-1]),
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
	.c_s_axis_tdata		(ctrl_s_axis_tdata_sv[NUM_OF_STAGES]),
	.c_s_axis_tuser		(ctrl_s_axis_tuser_sv[NUM_OF_STAGES]),
	.c_s_axis_tkeep		(ctrl_s_axis_tkeep_sv[NUM_OF_STAGES]),
	.c_s_axis_tlast		(ctrl_s_axis_tlast_sv[NUM_OF_STAGES]),
	.c_s_axis_tvalid	(ctrl_s_axis_tvalid_sv[NUM_OF_STAGES]),

	.c_m_axis_tdata		(ctrl_s_axis_tdata[NUM_OF_STAGES+1]),
	.c_m_axis_tuser		(ctrl_s_axis_tuser[NUM_OF_STAGES+1]),
	.c_m_axis_tkeep		(ctrl_s_axis_tkeep[NUM_OF_STAGES+1]),
	.c_m_axis_tlast		(ctrl_s_axis_tlast[NUM_OF_STAGES+1]),
	.c_m_axis_tvalid	(ctrl_s_axis_tvalid[NUM_OF_STAGES+1])
);


logic [C_S_AXIS_DATA_WIDTH-1:0] depar_out_tdata [C_NUM_QUEUES-1:0];
logic [(C_S_AXIS_DATA_WIDTH/8)-1:0] depar_out_tkeep [C_NUM_QUEUES-1:0];
logic [C_S_AXIS_TUSER_WIDTH-1:0] depar_out_tuser [C_NUM_QUEUES-1:0];
logic depar_out_tvalid [C_NUM_QUEUES-1:0];
logic depar_out_tlast [C_NUM_QUEUES-1:0];
logic depar_out_tready [C_NUM_QUEUES-1:0];

logic [C_S_AXIS_DATA_WIDTH-1:0] depar_out_tdata_sv [C_NUM_QUEUES-1:0];
logic [(C_S_AXIS_DATA_WIDTH/8)-1:0] depar_out_tkeep_sv [C_NUM_QUEUES-1:0];
logic [C_S_AXIS_TUSER_WIDTH-1:0] depar_out_tuser_sv [C_NUM_QUEUES-1:0];
logic depar_out_tvalid_sv [C_NUM_QUEUES-1:0];
logic depar_out_tlast_sv [C_NUM_QUEUES-1:0];

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
			.ctrl_s_axis_tdata	(ctrl_s_axis_tdata_sv[NUM_OF_STAGES+1]),
			.ctrl_s_axis_tuser	(ctrl_s_axis_tuser_sv[NUM_OF_STAGES+1]),
			.ctrl_s_axis_tkeep	(ctrl_s_axis_tkeep_sv[NUM_OF_STAGES+1]),
			.ctrl_s_axis_tvalid	(ctrl_s_axis_tvalid_sv[NUM_OF_STAGES+1]),
			.ctrl_s_axis_tlast	(ctrl_s_axis_tlast_sv[NUM_OF_STAGES+1])
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
	.s_axis_tdata_0		(depar_out_tdata_sv[0]),
	.s_axis_tkeep_0		(depar_out_tkeep_sv[0]),
	.s_axis_tuser_0		(depar_out_tuser_sv[0]),
	.s_axis_tlast_0		(depar_out_tlast_sv[0]),
	.s_axis_tvalid_0	(depar_out_tvalid_sv[0]),
	.s_axis_tready_0	(depar_out_tready[0]),

	.s_axis_tdata_1		(depar_out_tdata_sv[1]),
	.s_axis_tkeep_1		(depar_out_tkeep_sv[1]),
	.s_axis_tuser_1		(depar_out_tuser_sv[1]),
	.s_axis_tlast_1		(depar_out_tlast_sv[1]),
	.s_axis_tvalid_1	(depar_out_tvalid_sv[1]),
	.s_axis_tready_1	(depar_out_tready[1]),

	.s_axis_tdata_2		(depar_out_tdata_sv[2]),
	.s_axis_tkeep_2		(depar_out_tkeep_sv[2]),
	.s_axis_tuser_2		(depar_out_tuser_sv[2]),
	.s_axis_tlast_2		(depar_out_tlast_sv[2]),
	.s_axis_tvalid_2	(depar_out_tvalid_sv[2]),
	.s_axis_tready_2	(depar_out_tready[2]),

	.s_axis_tdata_3		(depar_out_tdata_sv[3]),
	.s_axis_tkeep_3		(depar_out_tkeep_sv[3]),
	.s_axis_tuser_3		(depar_out_tuser_sv[3]),
	.s_axis_tlast_3		(depar_out_tlast_sv[3]),
	.s_axis_tvalid_3	(depar_out_tvalid_sv[3]),
	.s_axis_tready_3	(depar_out_tready[3])
);


always_ff @(posedge clk) begin
	if (~aresetn) begin
		stg0_phv_in_valid_sv <= 0;
		stg0_phv_in_sv <= 0;
		stg0_vlan_in_sv <= 0;
		stg0_vlan_valid_in_sv <= 0;

		s_axis_tdata_f_sv <= 0;
		s_axis_tkeep_f_sv <= 0;
		s_axis_tuser_f_sv <= 0;
		s_axis_tlast_f_sv <= 0;
		s_axis_tvalid_f_sv <= 0;

		s_vlan_id_sv <= 0;
		s_vlan_id_valid_sv <= 0;
	end
	else begin
		stg0_phv_in_valid_sv <= stg0_phv_in_valid;
		stg0_phv_in_sv <= stg0_phv_in;
		stg0_vlan_in_sv <= stg0_vlan_in;
		stg0_vlan_valid_in_sv <= stg0_vlan_valid_in;

		s_axis_tdata_f_sv <= s_axis_tdata_f;
		s_axis_tkeep_f_sv <= s_axis_tkeep_f;
		s_axis_tuser_f_sv <= s_axis_tuser_f;
		s_axis_tlast_f_sv <= s_axis_tlast_f;
		s_axis_tvalid_f_sv <= s_axis_tvalid_f;

		s_vlan_id_sv <= s_vlan_id;
		s_vlan_id_valid_sv <= s_vlan_id_valid;
	end
end

// delay deparser out
always_ff @(posedge clk) begin
	if (~aresetn) begin
		for (idx=0; idx<C_NUM_QUEUES; idx=idx+1) begin
			depar_out_tdata_sv[idx] <= 0;
			depar_out_tkeep_sv[idx] <= 0;
			depar_out_tuser_sv[idx] <= 0;
			depar_out_tvalid_sv[idx] <= 0;
			depar_out_tlast_sv[idx] <= 0;
		end
	end
	else begin
		for (idx=0; idx<C_NUM_QUEUES; idx=idx+1) begin
			depar_out_tdata_sv[idx] <= depar_out_tdata[idx];
			depar_out_tkeep_sv[idx] <= depar_out_tkeep[idx];
			depar_out_tuser_sv[idx] <= depar_out_tuser[idx];
			depar_out_tvalid_sv[idx] <= depar_out_tvalid[idx];
			depar_out_tlast_sv[idx] <= depar_out_tlast[idx];
		end
	end
end

endmodule
