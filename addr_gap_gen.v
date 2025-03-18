`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/09/27 17:00:01
// Design Name: 
// Module Name: addr_gap_gen
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


module addr_gap_gen(
    input clk,
    input rstn,
    input enable,
    (*mark_debug = "true" *)input [31:0]angle_opa,
    (*mark_debug = "true" *)output [11:0]addr_gap,
    (*mark_debug = "true" *)output [7:0]offset_out,
    (*mark_debug = "true" *)output gap_done,
    (*mark_debug = "true" *)output opa_sign
    );
    reg reg_gap_done;
    reg reg_gap_done_ff1;
    reg reg_gap_done_ff2;
    reg reg_opa_sign;
    (*mark_debug = "true" *)reg signed [31:0]ram_gap_addr;
    reg [10:0]gap_addr_real;
    reg gap_addr_ok;
    wire [10:0]addr_gap_in;
    (*mark_debug = "true" *)wire [7:0]offset_out_neg;
    (*mark_debug = "true" *)wire [7:0]offset_out_pos;
    assign offset_out = (ram_gap_addr[23] == 0)?offset_out_pos : offset_out_neg;
    blk_mem_gen_2 addr_gap_rom(
        .clka(clk),
        .addra(gap_addr_real),
        .douta(addr_gap)
        );
    offset_restore offset_rest(
        .clka(clk),           
        .addra(gap_addr_real),
        .douta(offset_out_pos)      
        );    
    offset_restore_neg offset_rest_neg(
        .clka(clk),           
        .addra(gap_addr_real),
        .douta(offset_out_neg)      
        );            
    always@(posedge clk or negedge rstn)begin
        if(~rstn)
            ram_gap_addr <= 'd0;
        else 
            ram_gap_addr <= angle_opa;
    end
    always@(posedge clk or negedge rstn)begin
        if(~rstn)begin
            gap_addr_real <= 'd0;
            gap_addr_ok <= 'd0;
            reg_opa_sign <= 'd0;
        end
        else if(enable)begin
            if(ram_gap_addr[23] == 0)begin
                gap_addr_real[10:0] <=  ram_gap_addr;
                reg_opa_sign <= 'd0;
                gap_addr_ok <= 'd1;
            end
            else if(ram_gap_addr[23] == 1)begin
                gap_addr_real[10:0] <=  ~(ram_gap_addr - 1);
                reg_opa_sign <= 'd1;
                gap_addr_ok <= 'd1;
            end
        end
        else begin
                gap_addr_ok <= 'd0;
        end   
    end
    always@(posedge clk or negedge rstn)begin
        if(~rstn)begin
            reg_gap_done_ff1 <= 'd0;
        end
        else if(gap_addr_ok)begin
            reg_gap_done_ff1 <= 'd1;
        end
        else begin
            reg_gap_done_ff1 <= 'd0;
        end
    end
    always@(posedge clk or negedge rstn)begin
        if(~rstn)begin
            reg_gap_done_ff2 <= 'd0;
        end
        else if(reg_gap_done_ff1)begin
            reg_gap_done_ff2 <= 'd1;
        end
        else begin
            reg_gap_done_ff2 <= 'd0;
        end
    end
    always@(posedge clk or negedge rstn)begin
        if(~rstn)begin
            reg_gap_done <= 'd0;
        end
        else if(reg_gap_done_ff2)begin
            reg_gap_done <= 'd1;
        end
        else begin
            reg_gap_done <= 'd0;
        end
    end
    assign opa_sign = reg_opa_sign;
    assign gap_done = reg_gap_done;
    assign addr_gap_in = gap_addr_ok ? gap_addr_real:'d0;
endmodule
