`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/09/11 11:14:21
// Design Name: 
// Module Name: UPHI_Rebuild
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module UPHI_Rebuild#(
    parameter TAICHI_CHOOSE     = 1,
    parameter UPHI_ADDR_WIDTH   = 13,
    parameter UPHI_VOL_WIDTH    = 8,
    parameter UPHI_OFFSET_WIDTH = 8,
    parameter UPHI_MIRROR_WIDTH = 2,
    parameter UPHI_ADDRGAP_WIDTH = 12,
    parameter integer UPHI_VOL_NUM = 720
)
(
    input                               clk_in,
    input                               rst_in,
    input                               opa_sign,    
    input  signed[UPHI_ADDRGAP_WIDTH-1:0]      addr_gap,
    input                               gap_done,
    input signed[UPHI_OFFSET_WIDTH-1:0]       offset_in,
    input signed[UPHI_OFFSET_WIDTH-1:0]       offset1,
    input                               mirror1,
    input                               enable,
    input                               uphi_start,
    output                              uphi_active,
    (*mark_debug = "true"*)output [UPHI_VOL_WIDTH-1:0]         uphi_vol,
    output [1:0]                        uphi_read_cnt
    );
    parameter YANG              = 1;
    parameter YIN               = 0;
    parameter OFFSET_GAP_WIDTH = 20;
    (*mark_debug = "true" *)reg [2:0]uphi_state;
    parameter [2:0]IDLE = 3'b000,
        MIRROR = 3'b001,
        OFFSET = 3'b010,
        REVERSE = 3'b011,
        READ   = 3'b100,
        END    = 3'b101,
        WAIT   = 3'B110;
    (*mark_debug = "true"*)reg                        TAICHI;
    wire                       uphi_table_clk = clk_in;
    (*mark_debug = "true"*) reg [UPHI_ADDR_WIDTH-1:0] invalid_start;
    (*mark_debug = "true"*) reg [UPHI_ADDR_WIDTH-1:0] invalid_end;
    (*mark_debug = "true"*)reg                        uphi_table_ena;
    (*mark_debug = "true"*)reg  [UPHI_ADDR_WIDTH-1:0]  uphi_table_addr;
    (*mark_debug = "true"*)wire [UPHI_VOL_WIDTH-1:0]   uphi_table_vol;
    reg [UPHI_ADDR_WIDTH-1:0]  uphi_vol_cnt;
    (*mark_debug = "true"*)reg signed [OFFSET_GAP_WIDTH-1:0]        uphi_offset_gap;
    reg [1:0]                  uphi_addr_cnt;
    (*mark_debug = "true"*)reg                        uphi_procedure_cplt;
    reg                        uphi_read_done;
    reg                        rom_ena;
    reg                        [UPHI_ADDR_WIDTH-1:0]prev_addr;
    reg                        [UPHI_OFFSET_WIDTH-1:0]offset_counter;
    reg                        force_ff_enable;
    	reg                               offset_ctrl;
    reg signed [UPHI_OFFSET_WIDTH-1:0]       uphi_offset;  
    (*mark_debug = "true"*)reg  signed[UPHI_OFFSET_WIDTH-1:0]       offset_inuse;
    reg signed [UPHI_OFFSET_WIDTH-1:0]       uphi_offset_past;  
    reg                               offset_updated;
    reg [UPHI_MIRROR_WIDTH-1:0]       uphi_mirror;
    (*mark_debug = "true"*)reg                               offset_start;
    reg                               uphi_offset_gap_flag;
    reg                               gap_ff0;
    reg                               gap_ff1;
    reg                               ena_ff0;
    reg                               ena_ff1;
    ///
    reg [UPHI_ADDR_WIDTH-1:0]         uphi_reverse_addr;
    reg                               uphi_reverse_active;
    reg                               reverse_flag;
    reg                               uphi_reverse_done;
    reg [UPHI_ADDR_WIDTH-1:0]         uphi_reverse_cnt;
    wire       ena_risedge;
    wire       gap_risedge;
    assign uphi_active = rom_ena;
    assign uphi_read_cnt = uphi_addr_cnt;
    assign uphi_reading = (uphi_state == READ)?1'd1:1'd0;
    (*mark_debug = "true"*)wire is_invalid_addr = (uphi_vol_cnt >= invalid_start) && 
                      (uphi_vol_cnt < invalid_end+1);

    assign uphi_vol = is_invalid_addr ? 
                  8'hFF : uphi_table_vol;
    blk_mem_gen_0 uphi_table
    (
        .clka(uphi_table_clk),
        .ena(rom_ena),
        .addra(uphi_table_addr),
        .douta(uphi_table_vol)
     );
    function integer clogb2 (input integer bit_depth);              
	   begin                                                           
	       for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
	       bit_depth = bit_depth >> 1;                                 
	   end                                                           
	endfunction
    //     ?   ?  
    function [UPHI_ADDRGAP_WIDTH-1:0] abs(input signed [UPHI_ADDRGAP_WIDTH-1:0] val);
        abs = val[UPHI_ADDRGAP_WIDTH-1] ? (~val + 1) : val; //     ?    ?
    endfunction
    assign gap_risedge = gap_ff0 && !gap_ff1;
    always@(posedge clk_in or negedge rst_in)
    begin
        if(!rst_in)begin
            gap_ff0 <= 'd0;
            gap_ff1 <= 'd0;
        end
        else begin
            gap_ff0 <= gap_done;
            gap_ff1 <= gap_ff0;
        end
    end
    assign ena_risedge = ena_ff0 && !ena_ff1;
    always@(posedge clk_in or negedge rst_in)
    begin
        if(!rst_in)begin
            ena_ff0 <= 'd0;
            ena_ff1 <= 'd0;
        end
        else begin
            ena_ff0 <= enable;
            ena_ff1 <= ena_ff0;
        end
    end
    always@(posedge clk_in or negedge rst_in)begin
        if(!rst_in || uphi_procedure_cplt)begin
            offset_ctrl <= 'd0;
        end
        else if(uphi_offset != uphi_offset_past)begin
            offset_ctrl <= 'd1;
        end
    end
    always@(posedge clk_in or negedge rst_in)begin
        if(!rst_in)begin
            uphi_offset_past <= 'd0;
        end
        else if(offset_updated)begin
            uphi_offset_past <= uphi_offset;
        end
    end
    always@(posedge clk_in or negedge rst_in)
    begin
        if(!rst_in)begin
            uphi_offset <= 'd0;
            offset_updated <= 'd0;
        end
        else if(ena_risedge)begin
            uphi_offset <= offset1;
            offset_updated <= 'd1;
        end
        else begin
            uphi_offset <= uphi_offset;
            offset_updated <= offset_updated;
            
        end
    end
    always@(posedge clk_in or negedge rst_in)
    begin
        if(!rst_in)begin
            offset_inuse <= 'd0;
        end
        else if(offset_ctrl)begin
            offset_inuse <= offset1;
        end
        else begin
            offset_inuse <= offset_in;
        end
    end
    always@(posedge clk_in or negedge rst_in)
    begin
        if(!rst_in)begin
            uphi_mirror <= 'd0;
        end
        else if(enable)begin
            uphi_mirror <= mirror1;
        end
        else begin
            uphi_mirror <= uphi_mirror;
        end
    end
    always@(posedge clk_in or negedge rst_in)
    begin
        if(!rst_in)begin
            TAICHI <= YIN;
        end
        else if(uphi_mirror)begin
            TAICHI <= YANG;
        end
        else if(~uphi_mirror)begin
            TAICHI <= YIN;
        end
    end
    always@(posedge clk_in or negedge rst_in)
    begin
        if(!rst_in)begin
            reverse_flag <= 'd0;
        end
        else if(gap_risedge)begin
            reverse_flag <= 'd1;
        end
        else begin
            reverse_flag <= 'd0;
        end
    end
    always@(posedge clk_in or negedge rst_in)
    begin
        if(!rst_in || uphi_procedure_cplt)begin
            uphi_offset_gap <= 'd0;
            uphi_offset_gap_flag <= 'd0;
        end
        else if(uphi_table_ena && gap_risedge)begin
            uphi_offset_gap <= offset_inuse*addr_gap;
            uphi_offset_gap_flag <= 'd1;
        end
    end
    always@(posedge clk_in or negedge rst_in)
    begin
        if(!rst_in || gap_risedge)begin
            uphi_reverse_addr <= 'd0;
        end
        else if(uphi_reverse_active && uphi_reverse_addr >= 'd0 && opa_sign == 'd0)begin
            uphi_reverse_addr <= uphi_reverse_addr + addr_gap;
        end
        else if(uphi_reverse_active && uphi_reverse_addr >= 'd0 && opa_sign == 'd1)begin
            uphi_reverse_addr <= uphi_reverse_addr - addr_gap;
        end
        else begin
            uphi_reverse_addr <= uphi_reverse_addr;
        end
    end
    always@(posedge clk_in or negedge rst_in)
    begin
        if(!rst_in || reverse_flag)begin
            uphi_reverse_cnt <= 'd0;
        end
        else begin
            uphi_reverse_cnt <= uphi_reverse_cnt + 1;
        end
    end
    always@(posedge clk_in or negedge rst_in)
    begin
        if(!rst_in || gap_risedge)begin
            uphi_reverse_done <= 'd0;
        end
        else if(uphi_reverse_cnt == UPHI_VOL_NUM-2 && uphi_reverse_active)begin
            uphi_reverse_done <= 'd1;
        end
        else begin
            uphi_reverse_done <= 'd0;
        end
    end
    always@(posedge clk_in or negedge rst_in)
    begin
        if(!rst_in || gap_risedge)begin
            uphi_reverse_active <= 'd0;
        end
        else if(reverse_flag)begin
            uphi_reverse_active <= 'd1;
        end
        else if(uphi_reverse_cnt == UPHI_VOL_NUM-1)begin
            uphi_reverse_active <= 'd0;
        end
    end
    
    always@(posedge clk_in or negedge rst_in) begin
        if(!rst_in || ena_risedge)begin
            prev_addr <= 'd0;  //     prev_addr   ?   ? ��
        end
        else if(uphi_table_ena)begin
            prev_addr <= uphi_table_addr;  //     ??    ?
        end
    end
    

    always@(posedge clk_in or negedge rst_in)
    begin
        if(!rst_in || uphi_addr_cnt == 3)begin
            uphi_addr_cnt <= 'd0;
        end
        else if(uphi_table_ena && uphi_reading)begin
            uphi_addr_cnt <= uphi_addr_cnt + 1;
        end
        else begin
            uphi_addr_cnt <= uphi_addr_cnt;
        end
    end
     reg reverse_start;
    always@(posedge clk_in or negedge rst_in)
    begin
        if(!rst_in || ena_risedge)begin
            uphi_table_addr <= 'd0;
        end
        else if(uphi_table_ena && offset_start)begin
             if (uphi_offset_gap[OFFSET_GAP_WIDTH-1]) begin
            //    ?        ?   ?   ?
            uphi_table_addr <= uphi_table_addr + (~uphi_offset_gap+1);
        end else begin
            //     ?        ?    
            uphi_table_addr <= uphi_table_addr - uphi_offset_gap;
        end
        end
        else if(uphi_table_ena && uphi_reverse_done && reverse_start)begin
            uphi_table_addr <= uphi_reverse_addr;
        end
        else if(uphi_table_ena && uphi_addr_cnt == 3 && TAICHI == YANG && uphi_table_addr >= 'd0 && opa_sign == 'd0)begin
            uphi_table_addr <= uphi_table_addr + addr_gap;
        end
        else if(uphi_table_ena && uphi_addr_cnt == 3 && TAICHI == YANG && uphi_table_addr >= 'd0 && opa_sign == 'd1)begin
            uphi_table_addr <= uphi_table_addr - addr_gap;
        end
        else if(uphi_table_ena && uphi_addr_cnt == 3 && TAICHI == YIN && uphi_table_addr >= 'd0 && opa_sign == 'd0)begin
            uphi_table_addr <= uphi_table_addr - addr_gap;
        end
        else if(uphi_table_ena && uphi_addr_cnt == 3 && TAICHI == YIN && uphi_table_addr >= 'd0 && opa_sign == 'd1)begin
            uphi_table_addr <= uphi_table_addr + addr_gap;
        end
        else begin
            uphi_table_addr <= uphi_table_addr;
        end
    end





//   ��        ? 
always @(posedge clk_in or negedge rst_in) begin
    if (!rst_in) begin
        invalid_start <= 0;
        invalid_end   <= 0;
    end else if (offset_start) begin  // ? ?       ?    
        if (uphi_offset_gap[OFFSET_GAP_WIDTH-1]) begin  //     ? ?    ? 
            //     n��     ? n    ?  ��
            invalid_start <= UPHI_VOL_NUM - (~offset_inuse+1);
            invalid_end   <= UPHI_VOL_NUM - 1;
        end else begin  //     ? ?    ? 
            //     n��       n    ?  ��
            invalid_start <= 0;
            invalid_end   <= $unsigned(offset_inuse) - 1;
        end
        
        //     ��      ?    >    ?    
        if ($unsigned(offset_inuse) >= UPHI_VOL_NUM) begin
            invalid_start <= 0;
            invalid_end   <= UPHI_VOL_NUM - 1;  // ?    ?  ��
        end
        else if($unsigned(offset_inuse) <= 0)begin
            invalid_start <= 1;
            invalid_end   <= 0;  // ?    ?  ��
        end
    end
end

    always@(posedge clk_in or negedge rst_in)
    begin
        if(!rst_in || ena_risedge)begin
            uphi_vol_cnt <= 'd0;
        end
        else if(uphi_table_ena && uphi_addr_cnt == 3)begin
            uphi_vol_cnt <= uphi_vol_cnt + 1;
        end
        else begin
            uphi_vol_cnt <= uphi_vol_cnt;
        end
    end
    always@(posedge clk_in or negedge rst_in)
    begin
        if(!rst_in || ena_risedge)begin
            uphi_read_done <= 'd0;
        end
        else if(uphi_vol_cnt == UPHI_VOL_NUM-1 && uphi_addr_cnt == 3)begin
            uphi_read_done <= 'd1;
        end
    end
   
    always@(posedge clk_in or negedge rst_in)
    begin
        if(!rst_in)begin
            uphi_state      <= IDLE;
            offset_start    <= 'd0;
            uphi_table_ena  <= 'd0;
            uphi_procedure_cplt <= 'd0;
            rom_ena <= 'd0;
            reverse_start <= 'd0;
        end
        else begin
        case(uphi_state)
        IDLE:begin
            uphi_procedure_cplt <= 'd0;
            if(ena_risedge)begin
                uphi_table_ena  <= 'd1;
                uphi_state      <= MIRROR;
            end
            else begin
                uphi_table_ena <= 'd0;
                uphi_state <= IDLE;
            end
        end
        MIRROR:begin
            if(TAICHI == YANG)begin
                uphi_state <= OFFSET;
            end
            else if(TAICHI == YIN)begin
                uphi_state <= REVERSE;
            end
        end
        REVERSE:begin
            if(uphi_reverse_done)begin
                reverse_start <= 'd0;
                uphi_state <= OFFSET;
            end
            else begin
                reverse_start <= 'd1;
                uphi_state <= REVERSE;
            end
        end    
        OFFSET:begin
            if(uphi_offset_gap_flag)begin
                offset_start <= 'd1;
                uphi_state <= WAIT;
            end
            else begin
                offset_start <= 'd0;
                uphi_state <= OFFSET;
            end
        end
        WAIT:begin
            offset_start <= 'd0;
            if(uphi_start)
                uphi_state <= READ;
            else
                uphi_state <= WAIT;
        end
        READ:begin
            rom_ena <= 'd1;
            if(uphi_read_done && uphi_addr_cnt == 3)begin
                uphi_table_ena <= 'd0;
                rom_ena <= 'd0;
                uphi_state <= END;
            end
            else begin
                uphi_table_ena <= uphi_table_ena;
                uphi_state <= READ;
            end
        end
        END:begin
            uphi_procedure_cplt <= 'd1;
            uphi_state <= IDLE;
        end
        default:begin 
            uphi_state <= IDLE;
        end
        endcase
        end
    end 
endmodule
