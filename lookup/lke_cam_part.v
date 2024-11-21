`timescale 1ns / 1ps

module lke_cam_part #(
    parameter C_S_AXIS_DATA_WIDTH = 512,
    parameter C_S_AXIS_TUSER_WIDTH = 128,
    parameter STAGE_ID = 0,
    parameter PHV_LEN = 48*8+32*8+16*8+256,
    parameter KEY_LEN = 48*2+32*2+16*2+5,
    parameter ACT_LEN = 625,
    parameter LOOKUP_ID = 2,
    parameter C_VLANID_WIDTH = 12,
    parameter NUM_OF_STAGES = 5
)
(
    input clk,
    input rst_n,

    //output from key extractor
    input [KEY_LEN-1:0]           extract_key,
    input                         key_valid,
	input 					      phv_valid,
    input [PHV_LEN-1:0]           phv_in,
	output										ready_out,

    // output to the ram part
	output reg [PHV_LEN-1:0]					phv_out,
	output reg									phv_out_valid,
	output reg [3:0]							match_addr_out,
	output reg									if_match,
	input										ready_in,

    //control path
    input [C_S_AXIS_DATA_WIDTH-1:0]			    c_s_axis_tdata,
	input [C_S_AXIS_TUSER_WIDTH-1:0]		    c_s_axis_tuser,
	input [C_S_AXIS_DATA_WIDTH/8-1:0]		    c_s_axis_tkeep,
	input									    c_s_axis_tvalid,
	input									    c_s_axis_tlast,

    output reg [C_S_AXIS_DATA_WIDTH-1:0]		c_m_axis_tdata,
	output reg [C_S_AXIS_TUSER_WIDTH-1:0]		c_m_axis_tuser,
	output reg [C_S_AXIS_DATA_WIDTH/8-1:0]		c_m_axis_tkeep,
	output reg 								    c_m_axis_tvalid,
	output reg 							    	c_m_axis_tlast

);

/********intermediate variables declared here********/
wire [3:0]		match_addr;
wire			match;

// input registers
reg [KEY_LEN-1:0]               extract_key_ff;
reg                             key_valid_ff;
reg [PHV_LEN-1:0]               phv_in_ff;
reg                             ready_in_ff;
reg [C_S_AXIS_DATA_WIDTH-1:0]   c_s_axis_tdata_ff;
reg [C_S_AXIS_TUSER_WIDTH-1:0]  c_s_axis_tuser_ff;
reg [C_S_AXIS_DATA_WIDTH/8-1:0] c_s_axis_tkeep_ff;
reg                             c_s_axis_tvalid_ff;
reg                             c_s_axis_tlast_ff;
// output registers
reg                             ready_out_ff;
reg [PHV_LEN-1:0]               phv_out_ff;
reg                             phv_out_valid_ff;
reg [3:0]                       match_addr_out_ff;
reg                             if_match_ff;
reg [C_S_AXIS_DATA_WIDTH-1:0]   c_m_axis_tdata_ff;
reg [C_S_AXIS_TUSER_WIDTH-1:0]  c_m_axis_tuser_ff;
reg [C_S_AXIS_DATA_WIDTH/8-1:0] c_m_axis_tkeep_ff;
reg                             c_m_axis_tvalid_ff;
reg                             c_m_axis_tlast_ff;

reg [PHV_LEN-1:0] phv_reg;
reg [2:0] lookup_state;

wire [11:0] vlan_id;

assign vlan_id = phv_in_ff[140:129];

wire [204:0] dbg_input;

assign dbg_input = {vlan_id[3:0], vlan_id[11:4], extract_key_ff};

/********intermediate variables declared here********/

//here, the output should be controlled.
localparam IDLE_S = 3'd0,
           WAIT1_S = 3'd1,
           WAIT2_S = 3'd2,
           TRANS_S = 3'd3,
		   HALT_S = 3'd4,
		   EMPTY1_S = 3'd5,
		   OUTPUT_S = 3'd6;

assign ready_out = lookup_state!=HALT_S;

always @(posedge clk) begin
    if (~rst_n) begin
        // input registers
        extract_key_ff <= 0;
        key_valid_ff <= 0;
        phv_in_ff <= 0;
        ready_in_ff <= 0;
        c_s_axis_tdata_ff <= 0;
        c_s_axis_tuser_ff <= 0;
        c_s_axis_tkeep_ff <= 0;
        c_s_axis_tvalid_ff <= 0;
        c_s_axis_tlast_ff <= 0;
        
        // output registers
        ready_out_ff <= 0;
        phv_out_ff <= 0;
        phv_out_valid_ff <= 0;
        match_addr_out_ff <= 0;
        if_match_ff <= 0;
        c_m_axis_tdata_ff <= 0;
        c_m_axis_tuser_ff <= 0;
        c_m_axis_tkeep_ff <= 0;
        c_m_axis_tvalid_ff <= 0;
        c_m_axis_tlast_ff <= 0;
    end
    else begin
        // input registers
        extract_key_ff <= extract_key;
        key_valid_ff <= key_valid;
        phv_in_ff <= phv_in;
        ready_in_ff <= ready_in;
        c_s_axis_tdata_ff <= c_s_axis_tdata;
        c_s_axis_tuser_ff <= c_s_axis_tuser;
        c_s_axis_tkeep_ff <= c_s_axis_tkeep;
        c_s_axis_tvalid_ff <= c_s_axis_tvalid;
        c_s_axis_tlast_ff <= c_s_axis_tlast;
        
        // output registers
        ready_out_ff <= ready_out;
        phv_out_ff <= phv_out;
        phv_out_valid_ff <= phv_out_valid;
        match_addr_out_ff <= match_addr_out;
        if_match_ff <= if_match;
        c_m_axis_tdata_ff <= c_m_axis_tdata;
        c_m_axis_tuser_ff <= c_m_axis_tuser;
        c_m_axis_tkeep_ff <= c_m_axis_tkeep;
        c_m_axis_tvalid_ff <= c_m_axis_tvalid;
        c_m_axis_tlast_ff <= c_m_axis_tlast;
    end
end

always @(posedge clk or negedge rst_n) begin

    if (~rst_n) begin
        phv_reg <= 0;
        lookup_state <= IDLE_S;

        phv_out <= 0;
		phv_out_valid <= 0;
		match_addr_out <= 0;
		if_match <= 0;

		// ready_out <= 1'b1;
    end

    else begin
        case(lookup_state)
            IDLE_S: begin
                if (key_valid_ff == 1'b1) begin
					// ready_out <= 1'b0;
                    phv_reg <= phv_in_ff;
                    lookup_state <= WAIT1_S;
                end
                else begin
					phv_out_valid <= 0;
					if_match <= 0;
					// ready_out <= 1'b1;
                    lookup_state <= IDLE_S;
                end
            end

            WAIT1_S: begin
				if (ready_in_ff) begin
					phv_out <= phv_reg;
					phv_out_valid <= 1'b1;

					if(match == 1'b0) begin // CAM miss
						if_match <= 0;
						match_addr_out <= 4'hf;
                	end
                	else begin // CAM hit
						if_match <= 1;
						match_addr_out <= match_addr;
                	end
                	lookup_state <= IDLE_S;
					// ready_out <= 1'b1;
				end
				else begin
					lookup_state <= HALT_S;
				end
            end
			HALT_S: begin
				if (ready_in_ff) begin
					phv_out <= phv_reg;
					phv_out_valid <= 1'b1;

					if(match == 1'b0) begin // CAM miss
						if_match <= 0;
						match_addr_out <= 4'hf;
                	end
                	else begin // CAM hit
						if_match <= 1;
						match_addr_out <= match_addr;
                	end
                	lookup_state <= IDLE_S;
					// ready_out <= 1'b1;
				end
			end
        endcase
    end
end

//======================================================================



//======================================================================
/****control path*****/
wire [7:0]          mod_id; //module ID
//4'b0 for tcam entry;
//NOTE: we don't need tcam entry mask
//4'b2 for action table entry;
wire [3:0]          resv; //recog between tcam and action
wire [15:0]         control_flag; //dst udp port num


reg  [7:0]          c_index_cam; //table index(addr)

reg                 c_wr_en_cam; //enable table write(wena)

reg  [7:0]          c_index_act;
reg                 c_wr_en_act;
reg  [ACT_LEN-1:0]  act_entry_tmp;             
reg                 continous_flag;
reg [204:0]         cam_entry_reg;


reg [2:0]           c_state;


localparam IDLE_C = 0,
           PARSE_C = 1,
           CAM_TMP_ENTRY = 2,
           SU_CAM_TMP_ENTRY = 3,
           ACT_TMP_ENTRY_WAIT = 4,
           ACT_TMP_ENTRY_WAIT_2 = 5,
           ACT_TMP_ENTRY = 6,
		   FLUSH_REST_C = 7;

generate 
    assign mod_id = c_s_axis_tdata_ff[368+:8];
    assign resv   = c_s_axis_tdata_ff[376+:4];
    assign control_flag = c_s_axis_tdata_ff[335:320];
    //LE to BE switching
    wire[C_S_AXIS_DATA_WIDTH-1:0] c_s_axis_tdata_swapped;

	assign c_s_axis_tdata_swapped = {	c_s_axis_tdata_ff[0+:8],
										c_s_axis_tdata_ff[8+:8],
										c_s_axis_tdata_ff[16+:8],
										c_s_axis_tdata_ff[24+:8],
										c_s_axis_tdata_ff[32+:8],
										c_s_axis_tdata_ff[40+:8],
										c_s_axis_tdata_ff[48+:8],
										c_s_axis_tdata_ff[56+:8],
										c_s_axis_tdata_ff[64+:8],
										c_s_axis_tdata_ff[72+:8],
										c_s_axis_tdata_ff[80+:8],
										c_s_axis_tdata_ff[88+:8],
										c_s_axis_tdata_ff[96+:8],
										c_s_axis_tdata_ff[104+:8],
										c_s_axis_tdata_ff[112+:8],
										c_s_axis_tdata_ff[120+:8],
										c_s_axis_tdata_ff[128+:8],
										c_s_axis_tdata_ff[136+:8],
										c_s_axis_tdata_ff[144+:8],
										c_s_axis_tdata_ff[152+:8],
										c_s_axis_tdata_ff[160+:8],
										c_s_axis_tdata_ff[168+:8],
										c_s_axis_tdata_ff[176+:8],
										c_s_axis_tdata_ff[184+:8],
										c_s_axis_tdata_ff[192+:8],
										c_s_axis_tdata_ff[200+:8],
										c_s_axis_tdata_ff[208+:8],
										c_s_axis_tdata_ff[216+:8],
										c_s_axis_tdata_ff[224+:8],
										c_s_axis_tdata_ff[232+:8],
										c_s_axis_tdata_ff[240+:8],
										c_s_axis_tdata_ff[248+:8],
                                        c_s_axis_tdata_ff[256+:8],
                                        c_s_axis_tdata_ff[264+:8],
                                        c_s_axis_tdata_ff[272+:8],
                                        c_s_axis_tdata_ff[280+:8],
                                        c_s_axis_tdata_ff[288+:8],
                                        c_s_axis_tdata_ff[296+:8],
                                        c_s_axis_tdata_ff[304+:8],
                                        c_s_axis_tdata_ff[312+:8],
                                        c_s_axis_tdata_ff[320+:8],
                                        c_s_axis_tdata_ff[328+:8],
                                        c_s_axis_tdata_ff[336+:8],
                                        c_s_axis_tdata_ff[344+:8],
                                        c_s_axis_tdata_ff[352+:8],
                                        c_s_axis_tdata_ff[360+:8],
                                        c_s_axis_tdata_ff[368+:8],
                                        c_s_axis_tdata_ff[376+:8],
                                        c_s_axis_tdata_ff[384+:8],
                                        c_s_axis_tdata_ff[392+:8],
                                        c_s_axis_tdata_ff[400+:8],
                                        c_s_axis_tdata_ff[408+:8],
                                        c_s_axis_tdata_ff[416+:8],
                                        c_s_axis_tdata_ff[424+:8],
                                        c_s_axis_tdata_ff[432+:8],
                                        c_s_axis_tdata_ff[440+:8],
                                        c_s_axis_tdata_ff[448+:8],
                                        c_s_axis_tdata_ff[456+:8],
                                        c_s_axis_tdata_ff[464+:8],
                                        c_s_axis_tdata_ff[472+:8],
                                        c_s_axis_tdata_ff[480+:8],
                                        c_s_axis_tdata_ff[488+:8],
                                        c_s_axis_tdata_ff[496+:8],
                                        c_s_axis_tdata_ff[504+:8]
                                        };
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            c_index_cam <= 0;
            c_wr_en_cam <= 0;

            c_index_act <= 0;
            c_wr_en_act <= 0;

            act_entry_tmp <= 0;
            cam_entry_reg <= 0;
            continous_flag <= 0;

            c_m_axis_tdata <= 0;
            c_m_axis_tuser <= 0;
            c_m_axis_tkeep <= 0;
            c_m_axis_tvalid <= 0;
            c_m_axis_tlast <= 0;

            c_state <= IDLE_C;

        end

        else begin
            case(c_state)
                IDLE_C: begin
                    if(c_s_axis_tvalid_ff) begin
                        if(mod_id[7:3] == STAGE_ID && mod_id[2:0] == LOOKUP_ID 
								&& control_flag == 16'hf2f1
								&& resv == 4'b0) begin // TCAM entry
                            c_wr_en_cam <= 1'b0;
                            c_index_cam <= c_s_axis_tdata_ff[384+:8];
                            c_state <= CAM_TMP_ENTRY;
                        end
                        //not for lookup
                        else begin
                            c_index_cam <= 0;
                            c_wr_en_cam <= 0;

                            c_index_act <= 0;
                            c_wr_en_act <= 0;

                            act_entry_tmp <= 0;
                            continous_flag <= 0;

                            c_m_axis_tdata <= c_s_axis_tdata_ff;
                            c_m_axis_tuser <= c_s_axis_tuser_ff;
                            c_m_axis_tkeep <= c_s_axis_tkeep_ff;
                            c_m_axis_tvalid <= c_s_axis_tvalid_ff;
                            c_m_axis_tlast <= c_s_axis_tlast_ff;

                            c_state <= IDLE_C;
                        end
                    end
                    //stay halt
                    else begin
                        c_index_cam <= 0;
                        c_wr_en_cam <= 0;

                        c_index_act <= 0;
                        c_wr_en_act <= 0;

                        act_entry_tmp <= 0;
                        continous_flag <= 0;

                        c_m_axis_tdata <= 0;
                        c_m_axis_tuser <= 0;
                        c_m_axis_tkeep <= 0;
                        c_m_axis_tvalid <= 0;
                        c_m_axis_tlast <= 0;

                        c_state <= IDLE_C;
                    end
                end

                CAM_TMP_ENTRY: begin
                    if(c_s_axis_tvalid_ff) begin
                        cam_entry_reg <= c_s_axis_tdata_swapped[511 -: 205];
                        c_wr_en_cam <= 1'b1;
                        if(c_s_axis_tlast_ff) begin
                            c_state <= IDLE_C;
                        end
                        else begin
                            c_state <= SU_CAM_TMP_ENTRY;
                        end
                    end
                    else begin
                        c_wr_en_cam <= 1'b0;
                    end
                end

                SU_CAM_TMP_ENTRY: begin
                    if(c_s_axis_tvalid_ff) begin
                        cam_entry_reg <= c_s_axis_tdata_swapped[511 -: 205];
                        c_wr_en_cam <= 1'b1;
                        c_index_cam <= c_index_cam + 1'b1;
                        if(c_s_axis_tlast_ff) begin
                            c_state <= IDLE_C;
                        end
                        else begin
                            c_state <= SU_CAM_TMP_ENTRY;
                        end
                    end
                    else begin
                        c_wr_en_cam <= 1'b0;
                    end
                end
            endcase
        end
    end

	if (STAGE_ID == NUM_OF_STAGES-1) begin
		// tcam1 for lookup
    	cam_top # ( 
    	    .C_DEPTH			(16),
    	    // .C_WIDTH			(256),
    	    .C_WIDTH			(205),
    	    .C_MEM_INIT			(0)
    	    // .C_MEM_INIT_FILE	("./cam_init_file.mif")
    	)
    	cam_0
    	(
    	    .CLK				(clk),
    	    .CMP_DIN			({vlan_id[3:0], vlan_id[11:4], extract_key_ff}),
    	    //.CMP_DATA_MASK		({4'b1111, extract_mask}),
    	    .CMP_DATA_MASK      (),
			.BUSY				(),
    	    .MATCH				(match),
    	    .MATCH_ADDR			(match_addr[3:0]),

    	    //.WE				(lookup_din_en),
    	    //.WR_ADDR			(lookup_din_addr),
    	    //.DATA_MASK		(lookup_din_mask),  
    	    //.DIN				(lookup_din),

    	    .WE                 (c_wr_en_cam),
    	    .WR_ADDR            (c_index_cam[3:0]),
    	    .DATA_MASK          (),  //TODO do we need ternary matching?
    	    .DIN                (cam_entry_reg),
    	    .EN					(1'b1)
    	);
	end
	else begin
		// tcam1 for lookup
    	cam_top # ( 
    	    .C_DEPTH			(16),
    	    // .C_WIDTH			(256),
    	    .C_WIDTH			(205),
    	    .C_MEM_INIT			(0)
    	    // .C_MEM_INIT_FILE	("./cam_init_file.mif")
    	)
    	cam_0
    	(
    	    .CLK				(clk),
    	    .CMP_DIN			({vlan_id[3:0], vlan_id[11:4], extract_key_ff}),
    	    //.CMP_DATA_MASK		({4'b0000, extract_mask}),
    	    .CMP_DATA_MASK      (),
    	    .BUSY				(),
    	    .MATCH				(match),
    	    .MATCH_ADDR			(match_addr[3:0]),

    	    //.WE				(lookup_din_en),
    	    //.WR_ADDR			(lookup_din_addr),
    	    //.DATA_MASK		(lookup_din_mask),  
    	    //.DIN				(lookup_din),

    	    .WE                 (c_wr_en_cam),
    	    .WR_ADDR            (c_index_cam[3:0]),
    	    .DATA_MASK          (),  //TODO do we need ternary matching?
    	    .DIN                (cam_entry_reg),
    	    .EN					(1'b1)
    	);
	end
endgenerate

endmodule

