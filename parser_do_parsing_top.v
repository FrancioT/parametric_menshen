`timescale 1ns / 1ps



module parser_do_parsing_top #(
	parameter C_AXIS_DATA_WIDTH = 512,
	parameter C_AXIS_TUSER_WIDTH = 128,
	parameter PKT_HDR_LEN = (6+4+2)*8*8+256, // check with the doc
	parameter C_NUM_SEGS = 2,
	parameter C_PARSER_RAM_WIDTH = 160,
	parameter C_VLANID_WIDTH = 12
)
(
	input					clk,
	input					aresetn,

	input [C_NUM_SEGS*C_AXIS_DATA_WIDTH-1:0]	segs_in,
	input										segs_in_valid,
	input [C_AXIS_TUSER_WIDTH-1:0]				tuser_1st_in,
	input [C_PARSER_RAM_WIDTH-1:0]				bram_in,
	input										bram_in_valid,

	input										stg_ready,
	input										stg_vlan_ready,

	// phv output
	output reg [PKT_HDR_LEN-1:0]					pkt_hdr_vec,
	output reg										parser_valid,
	output reg [C_VLANID_WIDTH-1:0]					vlan_out,
	output reg										vlan_out_valid
);

wire [C_NUM_SEGS*C_AXIS_DATA_WIDTH-1:0]			sub_parser_segs_in;
wire											sub_parser_segs_in_valid;
wire [C_AXIS_TUSER_WIDTH-1:0]					sub_parser_tuser_1st_in;
wire [C_PARSER_RAM_WIDTH-1:0]					sub_parser_bram_in;
wire											sub_parser_bram_in_valid;


assign sub_parser_segs_in = segs_in;
assign sub_parser_segs_in_valid = segs_in_valid;
assign sub_parser_tuser_1st_in = tuser_1st_in;

assign sub_parser_bram_in = bram_in;
assign sub_parser_bram_in_valid = bram_in_valid;

wire [PKT_HDR_LEN-1:0]		sub_parser_pkt_hdr_out;
wire					sub_parser_pkt_hdr_valid;
wire [C_VLANID_WIDTH-1:0]	sub_parser_vlan_out;
wire					sub_parser_vlan_out_valid;

reg [PKT_HDR_LEN-1:0]		sub_parser_pkt_hdr_out_d1;
reg					sub_parser_pkt_hdr_valid_d1;
reg [C_VLANID_WIDTH-1:0]	sub_parser_vlan_out_d1;
reg					sub_parser_vlan_out_valid_d1;

parser_do_parsing #(
	.C_AXIS_DATA_WIDTH(C_AXIS_DATA_WIDTH),
	.C_AXIS_TUSER_WIDTH(C_AXIS_TUSER_WIDTH)
)
phv_do_parsing (
	.axis_clk			(clk),
	.aresetn			(aresetn),
	.tdata_segs			(sub_parser_segs_in),
	.tuser_1st			(sub_parser_tuser_1st_in),
	.segs_valid			(sub_parser_segs_in_valid),

	.bram_in			(sub_parser_bram_in),
	.bram_in_valid		(sub_parser_bram_in_valid),
	.stg_ready_in		(1'b1),
	// output
	.parser_valid		(sub_parser_pkt_hdr_valid),
	.pkt_hdr_vec		(sub_parser_pkt_hdr_out),
	.vlan_out			(sub_parser_vlan_out),
	.vlan_out_valid		(sub_parser_vlan_out_valid)
);


reg [PKT_HDR_LEN-1:0] pkt_hdr_vec_next;
reg parser_valid_next;

always @(*) begin
	pkt_hdr_vec_next = pkt_hdr_vec;
	parser_valid_next = 0;
	
	if (sub_parser_pkt_hdr_valid_d1) begin
		pkt_hdr_vec_next = sub_parser_pkt_hdr_out_d1;
		parser_valid_next = 1;
	end
end

always @(posedge clk) begin
	if (~aresetn) begin
		pkt_hdr_vec <= 0;
		parser_valid <= 0;
	end
	else begin
		pkt_hdr_vec <= pkt_hdr_vec_next;
		parser_valid <= parser_valid_next;
	end
end

reg [C_VLANID_WIDTH-1:0] vlan_out_next;
reg vlan_out_valid_next;

always @(*) begin
	vlan_out_next = vlan_out;
	vlan_out_valid_next = 0;
        
	if (sub_parser_vlan_out_valid_d1) begin
		vlan_out_next = sub_parser_vlan_out_d1;
		vlan_out_valid_next = 1;
	end
end

always @(posedge clk) begin
	if (~aresetn) begin
		vlan_out <= 0;
		vlan_out_valid <= 0;
	end
	else begin
		vlan_out <= vlan_out_next;
		vlan_out_valid <= vlan_out_valid_next;
	end
end

always @(posedge clk) begin
	if (~aresetn) begin
		sub_parser_pkt_hdr_out_d1 <= 0;
		sub_parser_pkt_hdr_valid_d1 <= 0;
		sub_parser_vlan_out_d1 <= 0;
		sub_parser_vlan_out_valid_d1 <= 0;
	end
	else begin
		sub_parser_pkt_hdr_out_d1 <= sub_parser_pkt_hdr_out;
		sub_parser_pkt_hdr_valid_d1 <= sub_parser_pkt_hdr_valid;
		sub_parser_vlan_out_d1 <= sub_parser_vlan_out;
		sub_parser_vlan_out_valid_d1 <= sub_parser_vlan_out_valid;
	end
end

endmodule
