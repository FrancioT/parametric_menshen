`timescale 1ns / 1ps
module key_extract_top #(
    parameter C_S_AXIS_DATA_WIDTH = 512,
    parameter C_S_AXIS_TUSER_WIDTH = 128,
    parameter STAGE_ID = 0,
    parameter PHV_LEN = 48*8+32*8+16*8+256,
    parameter KEY_LEN = 48*2+32*2+16*2+1,
    // format of KEY_OFF entry: |--3(6B)--|--3(6B)--|--3(4B)--|--3(4B)--|--3(2B)--|--3(2B)--|
    parameter KEY_OFF = (3+3)*3+20,
    parameter AXIL_WIDTH = 32,
    parameter KEY_OFF_ADDR_WIDTH = 4,
    parameter KEY_EX_ID = 1,
	parameter C_VLANID_WIDTH = 12
    )(
    input                               clk,
    input                               rst_n,
	//
    input [PHV_LEN-1:0]                 phv_in,
    input                               phv_valid_in,
	output								ready_out,
	// input from vlan fifo
	input [C_VLANID_WIDTH-1:0]			vlan_in,
	input								vlan_in_valid,
	output								vlan_ready,

	// output PHV and key
    output [PHV_LEN-1:0]				phv_out,
    output					            phv_valid_out,
    output [KEY_LEN-1:0]	            key_out_masked,
    output								key_valid_out,
	input								ready_in,

    //control path
    input [C_S_AXIS_DATA_WIDTH-1:0]			c_s_axis_tdata,
	input [C_S_AXIS_TUSER_WIDTH-1:0]		c_s_axis_tuser,
	input [C_S_AXIS_DATA_WIDTH/8-1:0]		c_s_axis_tkeep,
	input									c_s_axis_tvalid,
	input									c_s_axis_tlast,

    output reg [C_S_AXIS_DATA_WIDTH-1:0]		c_m_axis_tdata,
	output reg [C_S_AXIS_TUSER_WIDTH-1:0]		c_m_axis_tuser,
	output reg [C_S_AXIS_DATA_WIDTH/8-1:0]		c_m_axis_tkeep,
	output reg								    c_m_axis_tvalid,
	output reg								    c_m_axis_tlast
);

wire [KEY_OFF-1:0]      key_offset_w; // output from RAM
//
wire [KEY_LEN-1:0]      key_mask_out_w; // output from RAM
//
wire extract_ready_out;

assign ready_out = extract_ready_out;
assign vlan_ready = extract_ready_out;

//
localparam	BRAM_IDLE=0,
			BRAM_CYCLE_1=1,
			BRAM_CYCLE_2=2,
			BRAM_CYCLE_3=3;

reg [2:0] bram_state, bram_state_next;
reg key_offset_valid, key_offset_valid_next;


always @(*) begin
	bram_state_next = bram_state;

	key_offset_valid_next = 0;


	case (bram_state) 
		BRAM_IDLE: begin
			if (vlan_in_valid) begin
				bram_state_next = BRAM_CYCLE_1;
			end
		end
		BRAM_CYCLE_1: begin
			bram_state_next = BRAM_IDLE;
			key_offset_valid_next = 1;
		end
	endcase
end

always @(posedge clk) begin
	if (~rst_n) begin
		bram_state <= BRAM_IDLE;
		key_offset_valid <= 0;
	end
	else begin

		bram_state <= bram_state_next;
		key_offset_valid <= key_offset_valid_next;
	end
end

reg [PHV_LEN-1:0]	phv_in_d1;
reg					phv_valid_in_d1;
reg					key_offset_valid_d1;
reg [KEY_OFF-1:0]	key_offset_w_d1; // output from RAM
reg [KEY_LEN-1:0]	key_mask_out_w_d1; // output from RAM

always @(posedge clk) begin
	if (~rst_n) begin
		phv_in_d1 <= 0;
		phv_valid_in_d1 <= 0;
		key_offset_valid_d1 <= 0;
		key_offset_w_d1 <= 0;
		key_mask_out_w_d1 <= 0;
	end
	else begin
		phv_in_d1 <= phv_in;
		phv_valid_in_d1 <= phv_valid_in;
		key_offset_valid_d1 <= key_offset_valid;
		key_offset_w_d1 <= key_offset_w;
		key_mask_out_w_d1 <= key_mask_out_w;
	end
end


//
key_extract #(
	.C_S_AXIS_DATA_WIDTH(C_S_AXIS_DATA_WIDTH),
	.C_S_AXIS_TUSER_WIDTH(C_S_AXIS_TUSER_WIDTH),
	.STAGE_ID(STAGE_ID),
	.PHV_LEN(PHV_LEN),
	.KEY_LEN(KEY_LEN),
	.KEY_OFF(KEY_OFF)
)
extractor
(
	.clk			(clk),
	.rst_n			(rst_n),
	.phv_in			(phv_in_d1),
	.phv_valid_in	(phv_valid_in_d1),
	.ready_out		(extract_ready_out),
	//
	.key_offset_valid	(key_offset_valid_d1),
	.key_offset_w		(key_offset_w_d1),
	.key_mask_w			(key_mask_out_w_d1),

	// output
	.phv_out		(phv_out),
	.phv_valid_out	(phv_valid_out),
	.key_out_masked	(key_out_masked),
	.key_valid_out	(key_valid_out),
	.ready_in		(ready_in)
);



















//======================================================================================
/****control path for 512b*****/
wire [7:0]          mod_id; //module ID
wire [3:0]          resv;
wire [15:0]         control_flag; //dst udp port num
reg  [7:0]          c_index; //table index(addr)
reg                 c_wr_en_off; //enable table write(wena)
reg                 c_wr_en_mask;


reg [2:0]           c_state;



localparam IDLE_C = 0,
           PARSE_C = 1,
           WRITE_OFF_C = 2,
           SU_WRITE_OFF_C = 3,
           WRITE_MASK_C = 4,
           SU_WRITE_MASK_C = 5,
		   FLUSH_PKT_C = 6;

generate
    assign mod_id = c_s_axis_tdata[368+:8];
    //4'b0 for key offset
    //4'b1 for key mask
    assign resv = c_s_axis_tdata[376+:4];
    assign control_flag = c_s_axis_tdata[335:320];

    reg [37:0]                    key_off_entry_reg;
    reg [192:0]                   key_mask_entry_reg;
    //LE to BE switching
    wire[C_S_AXIS_DATA_WIDTH-1:0] c_s_axis_tdata_swapped;

	assign c_s_axis_tdata_swapped = {	c_s_axis_tdata[0+:8],
										c_s_axis_tdata[8+:8],
										c_s_axis_tdata[16+:8],
										c_s_axis_tdata[24+:8],
										c_s_axis_tdata[32+:8],
										c_s_axis_tdata[40+:8],
										c_s_axis_tdata[48+:8],
										c_s_axis_tdata[56+:8],
										c_s_axis_tdata[64+:8],
										c_s_axis_tdata[72+:8],
										c_s_axis_tdata[80+:8],
										c_s_axis_tdata[88+:8],
										c_s_axis_tdata[96+:8],
										c_s_axis_tdata[104+:8],
										c_s_axis_tdata[112+:8],
										c_s_axis_tdata[120+:8],
										c_s_axis_tdata[128+:8],
										c_s_axis_tdata[136+:8],
										c_s_axis_tdata[144+:8],
										c_s_axis_tdata[152+:8],
										c_s_axis_tdata[160+:8],
										c_s_axis_tdata[168+:8],
										c_s_axis_tdata[176+:8],
										c_s_axis_tdata[184+:8],
										c_s_axis_tdata[192+:8],
										c_s_axis_tdata[200+:8],
										c_s_axis_tdata[208+:8],
										c_s_axis_tdata[216+:8],
										c_s_axis_tdata[224+:8],
										c_s_axis_tdata[232+:8],
										c_s_axis_tdata[240+:8],
										c_s_axis_tdata[248+:8],
                                        c_s_axis_tdata[256+:8],
                                        c_s_axis_tdata[264+:8],
                                        c_s_axis_tdata[272+:8],
                                        c_s_axis_tdata[280+:8],
                                        c_s_axis_tdata[288+:8],
                                        c_s_axis_tdata[296+:8],
                                        c_s_axis_tdata[304+:8],
                                        c_s_axis_tdata[312+:8],
                                        c_s_axis_tdata[320+:8],
                                        c_s_axis_tdata[328+:8],
                                        c_s_axis_tdata[336+:8],
                                        c_s_axis_tdata[344+:8],
                                        c_s_axis_tdata[352+:8],
                                        c_s_axis_tdata[360+:8],
                                        c_s_axis_tdata[368+:8],
                                        c_s_axis_tdata[376+:8],
                                        c_s_axis_tdata[384+:8],
                                        c_s_axis_tdata[392+:8],
                                        c_s_axis_tdata[400+:8],
                                        c_s_axis_tdata[408+:8],
                                        c_s_axis_tdata[416+:8],
                                        c_s_axis_tdata[424+:8],
                                        c_s_axis_tdata[432+:8],
                                        c_s_axis_tdata[440+:8],
                                        c_s_axis_tdata[448+:8],
                                        c_s_axis_tdata[456+:8],
                                        c_s_axis_tdata[464+:8],
                                        c_s_axis_tdata[472+:8],
                                        c_s_axis_tdata[480+:8],
                                        c_s_axis_tdata[488+:8],
                                        c_s_axis_tdata[496+:8],
                                        c_s_axis_tdata[504+:8]
                                        };
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            c_wr_en_off <= 1'b0;
            c_wr_en_mask <= 1'b0;
            c_index <= 8'b0;
    
            c_m_axis_tdata <= 0;
            c_m_axis_tuser <= 0;
            c_m_axis_tkeep <= 0;
            c_m_axis_tvalid <= 0;
            c_m_axis_tlast <= 0;

            key_off_entry_reg <= 0;
            key_mask_entry_reg <= 0;
    
            c_state <= IDLE_C;
    
        end
        else begin
            case(c_state)
                IDLE_C: begin
                    if(c_s_axis_tvalid && mod_id[7:3] == STAGE_ID && mod_id[2:0] == KEY_EX_ID &&
                     control_flag == 16'hf2f1)begin
                        //c_wr_en <= 1'b1;
                        c_index <= c_s_axis_tdata[384+:8];
    
                        c_m_axis_tdata <= 0;
                        c_m_axis_tuser <= 0;
                        c_m_axis_tkeep <= 0;
                        c_m_axis_tvalid <= 0;
                        c_m_axis_tlast <= 0;
    
                        //c_state <= WRITE_C;
                        if(resv == 4'b0) begin
                            c_wr_en_off <= 1'b0;
                            c_state <= WRITE_OFF_C;
                        end
                        else begin
                            c_wr_en_mask <= 1'b0;
                            c_state <= WRITE_MASK_C;
                        end
                    end
                    else begin
                        c_wr_en_off <= 1'b0;
                        c_wr_en_mask <= 1'b0;
                        c_index <= 8'b0; 
    
                        c_m_axis_tdata <= c_s_axis_tdata;
                        c_m_axis_tuser <= c_s_axis_tuser;
                        c_m_axis_tkeep <= c_s_axis_tkeep;
                        c_m_axis_tvalid <= c_s_axis_tvalid;
                        c_m_axis_tlast <= c_s_axis_tlast;
    
                        c_state <= IDLE_C;
                    end
                end
                //support full table flush
                WRITE_OFF_C: begin
                    if(c_s_axis_tvalid) begin
                        key_off_entry_reg <= c_s_axis_tdata_swapped[511 -: 38];
                        c_wr_en_off <= 1'b1;
                        if(c_s_axis_tlast) begin
                            c_state <= IDLE_C;
                        end
                        else begin
                            c_state <= SU_WRITE_OFF_C;
                        end
                    end
                    else begin
                        c_wr_en_off <= 0;
                    end
                end

                SU_WRITE_OFF_C: begin
                    if(c_s_axis_tvalid) begin
                        key_off_entry_reg <= c_s_axis_tdata_swapped[511 -: 38];
                        c_wr_en_off <= 1'b1;
                        c_index <= c_index + 1'b1;
                        if(c_s_axis_tlast) begin
                            c_state <= IDLE_C;
                        end
                        else begin
                            c_state <= SU_WRITE_OFF_C;
                        end
                    end
                    else begin
                        c_wr_en_off <= 1'b0;
                    end
                end

                WRITE_MASK_C: begin
                    if(c_s_axis_tvalid) begin
                        key_mask_entry_reg <= c_s_axis_tdata_swapped[511 -: 193];
                        c_wr_en_mask <= 1'b1;
                        if(c_s_axis_tlast) begin
                            c_state <= IDLE_C;
                        end
                        else begin
                            c_state <= SU_WRITE_MASK_C;
                        end
                    end
                    else begin
                        c_wr_en_mask <= 0;
                    end
                end

                SU_WRITE_MASK_C: begin
                    if(c_s_axis_tvalid) begin
                        key_mask_entry_reg <= c_s_axis_tdata_swapped[511 -: 193];
                        c_wr_en_mask <= 1'b1;
                        c_index <= c_index + 1'b1;
                        if(c_s_axis_tlast) begin
                            c_state <= IDLE_C;
                        end
                        else begin
                            c_state <= SU_WRITE_MASK_C;
                        end
                    end
                    else begin
                        c_wr_en_mask <= 1'b0;
                    end
                end

                default: begin
                    c_wr_en_off <= 1'b0;
                    c_wr_en_mask <= 1'b0;
                    c_index <= 8'b0; 
                    c_m_axis_tdata <= c_s_axis_tdata;
                    c_m_axis_tuser <= c_s_axis_tuser;
                    c_m_axis_tkeep <= c_s_axis_tkeep;
                    c_m_axis_tvalid <= c_s_axis_tvalid;
                    c_m_axis_tlast <= c_s_axis_tlast;
                end
            endcase
    
        end
    end
    //ram for key extract
    blk_mem_gen_2
    key_ram_38w_32d
    (
        .addra(c_index[4:0]),
        .clka(clk),
        .dina(key_off_entry_reg),
        .ena(1'b1),
        .wea(c_wr_en_off),

        //only [3:0] is needed for addressing
        .addrb(vlan_in[8:4]),
        .clkb(clk),
        .doutb(key_offset_w),
        .enb(1'b1)
    );

    blk_mem_gen_3
    mask_ram_193w_32d
    (
        .addra(c_index[4:0]),
        .clka(clk),
        .dina(key_mask_entry_reg),
        .ena(1'b1),
        .wea(c_wr_en_mask),

        //only [3:0] is needed for addressing
        .addrb(vlan_in[8:4]),
        .clkb(clk),
        .doutb(key_mask_out_w),
        .enb(1'b1)
    );
endgenerate

//==========================================================


endmodule
