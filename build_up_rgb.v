`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/09/23 20:47:02
// Design Name: 
// Module Name: build_up_rgb
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


module build_up_rgb#(
    parameter UPHI_VOL_WIDTH    = 8,
    parameter RGB_NUM_WIDTH     = 10,
    parameter RGB_24B_NUM_WIDTH = 8
)
(
    input                       clk,
    input                       rstn,
    input                       uphi_active,
    input [1:0]                 uphi_read_cnt,
    input [UPHI_VOL_WIDTH-1:0]  uphi_vol ,
    output                      uphi_start,
    /////////////////////rgb_fit////////////////////////////
    output [7:0]                rgb_fit_addr,
    output                      rgb_fit_valid,
    output                      sync_rgb_fit,
    output [23:0]               rgb_fit_out   
    );
    (*mark_debug = "true"*)reg [7:0]                   rgb_fit_add;
    (*mark_debug = "true"*)reg                         rgb_data_sync;
    reg [23:0]                  rgb_data_out;
    reg [23:0]                  rgb_data;
    (*mark_debug = "true"*)reg [RGB_NUM_WIDTH-1:0]     rgb_cnt;
    reg [RGB_NUM_WIDTH-1:0]     rgb_data_cnt;
    reg [RGB_24B_NUM_WIDTH-1:0] rgb_data_num;
    reg [1:0]                   rgb_read_cnt;
    reg                         uphi_start_reg;
    assign rgb_fit_addr = rgb_fit_add;
    assign rgb_fit_valid = rgb_data_sync;
    assign sync_rgb_fit = rgb_data_sync;
    assign uphi_start = uphi_start_reg;
    reg [RGB_24B_NUM_WIDTH-1:0]  rgb_24b_cnt;
    parameter [2:0]IDLE = 3'b000,
    BUILD_UP = 3'b001,
    SEND = 3'b010,
    END = 3'b011;
    reg [2:0]   rgb_state;
    reg         bud_start;
    reg         bud_active;
    reg         bud_done;
    reg         send_start;
    reg         send_active;
    reg         send_done;
    
    wire         ena;
    reg         wea;
    reg [RGB_24B_NUM_WIDTH-1:0]        addra;
    (*mark_debug = "true"*)wire [23:0]                         ram_data_out;
    assign rgb_fit_out = ram_data_out;
    always@(posedge clk or negedge rstn)begin
        if(~rstn)begin
            rgb_state <= IDLE;
            send_start <= 'd0;
            bud_start <= 'd0;
            uphi_start_reg <= 'd0;
        end
        else begin
        case(rgb_state)
            IDLE:begin
                uphi_start_reg <= 'd1;
                rgb_state <= BUILD_UP;
            end
            BUILD_UP:begin
                if(bud_done)begin
                    uphi_start_reg <= 'd0;
                    rgb_state <= SEND;
                end
                else begin
                    rgb_state <= BUILD_UP; 
                    if(~bud_start && ~bud_active)begin
                        bud_start <= 'd1;
                    end
                    else begin
                        bud_start <= 'd0;
                    end
                end
            end
            SEND:
                if(send_done)begin
                    send_start <= 'd0;
                    rgb_state <= END;
                end
                else begin
                    rgb_state <= SEND; 
                    if(~send_start && ~send_active)begin
                        send_start <= 'd1;
                    end
                    else begin
                        send_start <= 'd0;
                    end
                end
            END:rgb_state <= IDLE;
            default:rgb_state <= IDLE;
        endcase
        end
    end
    always@(posedge clk or negedge rstn)begin
        if(~rstn || bud_start || (rgb_cnt >= 'd2 && uphi_read_cnt == 'd3) )begin
            rgb_cnt <= 'd0;
        end
        else if(uphi_active && uphi_read_cnt == 'd3)begin
            rgb_cnt <= rgb_cnt + 1;
        end
        else begin
            rgb_cnt <= rgb_cnt;
        end
    end
    always@(posedge clk or negedge rstn)begin
        if(~rstn || bud_start)
            rgb_data_out <= 'd0;
        else if(uphi_active && uphi_read_cnt == 'd3)
            rgb_data_out[(23-rgb_cnt*8)-:8] <= uphi_vol;
    end
    always@(posedge clk or negedge rstn)begin
        if(~rstn || bud_start)
            rgb_data_cnt <= 'd0;
        else if(rgb_data_cnt == 'd3 && uphi_read_cnt == 'd3)
            rgb_data_cnt <= 'd1;
        else if(uphi_active && uphi_read_cnt == 'd3)
            rgb_data_cnt <= rgb_data_cnt + 1;
    end
    always@(posedge clk or negedge rstn)begin
        if(~rstn || bud_start)begin
            rgb_fit_add <= 'd0;
        end
        else if(rgb_data_sync)begin
            rgb_fit_add <= rgb_fit_add + 1'd1;
        end
    end
    always@(posedge clk or negedge rstn)begin
        if(~rstn || bud_start || (rgb_data_num == 240-1 && rgb_data_cnt == 'd3 && uphi_read_cnt == 'd3) || send_start || (send_active && rgb_data_num == 240-1))
            rgb_data_num <= 'd0;
        else if(rgb_data_cnt == 'd3 && uphi_read_cnt == 'd3)
            rgb_data_num <= rgb_data_num + 1;
        else if(send_active && rgb_data_num != 240-1)
            rgb_data_num <= rgb_data_num + 1;
    end
    always@(posedge clk or negedge rstn)begin
        if(~rstn || bud_start || rgb_read_cnt == 'd3 || (addra == 240-1 && rgb_read_cnt == 'd3))
            rgb_read_cnt <= 'd0;
        else if(send_active && rgb_data_num != 240)
            rgb_read_cnt <= rgb_read_cnt + 1;
    end
    always@(posedge clk or negedge rstn)begin
        if(~rstn || bud_start)
            wea <= 'd0;
        else if(rgb_data_cnt == 'd2 && uphi_read_cnt == 'd3)
            wea <= 1;
        else if(rgb_data_cnt == 'd3 && uphi_read_cnt == 'd3)
            wea <= 0;
    end
    assign ena = send_active ? 'd1:wea;
    // // 参数化配置（根据原IP核设置调整）
   
    // parameter DATA_WIDTH = 24;       // 数据位宽（24位RGB）

    // // 定义分布式RAM存储数组
    // reg [DATA_WIDTH-1:0] ram [0:(1<<RGB_24B_NUM_WIDTH)-1];
    // // 同步读写逻辑
    // always @(posedge clk) begin
    //     if (ena) begin               // 使能有效时才操作
    //         if (wea) begin           // 写使能有效时写入数据
    //             ram[addra] <= rgb_data_out;
    //         end
    //         ram_data_out <= ram[addra];     // 始终读取当前地址数据（同步输出）
    //     end
    // end
    blk_mem_gen_1 rgb_24b_ram(
        .clka(clk),
        .ena(ena),
        .wea(wea),
        .addra(addra),
        .dina(rgb_data_out),
        .douta(ram_data_out)
    );
    always@(posedge clk or negedge rstn)begin
        if(~rstn || bud_start || (addra == 240-1 && rgb_data_cnt == 'd3 && uphi_read_cnt == 'd3) || (addra == 240-1 && rgb_read_cnt == 'd3))
            addra <= 'd0;
        else if(uphi_active && rgb_data_cnt == 'd3 && uphi_read_cnt == 'd3)
            addra <= addra + 1;
        else if(send_active && rgb_data_num != 240-1)
            addra <= addra + 1;
    end

    always@(posedge clk or negedge rstn)begin
        if(~rstn)
            bud_active <= 'd0;
        else if(bud_start)
            bud_active <= 'd1;
        else if(bud_done)
            bud_active <= 'd0;
      end
    always@(posedge clk or negedge rstn)begin
        if(~rstn || bud_start)
            bud_done <= 'd0;
        else if(addra == 240-1 && wea && rgb_data_cnt == 'd3 && uphi_read_cnt == 'd3)
            bud_done <= 'd1;
        else
            bud_done <= 'd0;
      end
    always@(posedge clk or negedge rstn)begin
        if(~rstn)
            send_active <= 'd0;
        else if(send_start)
            send_active <= 'd1;
        else if(send_done)
            send_active <= 'd0;
      end
    always@(posedge clk or negedge rstn)begin
        if(~rstn || send_start)
            send_done <= 'd0;
        else if(addra == 240-2 && ~wea)
            send_done <= 'd1;
        else
            send_done <= 'd0;
      end
    always@(posedge clk or negedge rstn)begin
        if(~rstn || send_start)
            rgb_data_sync <= 'd0;
        else if(send_active)
            rgb_data_sync <= 'd1;
        else
            rgb_data_sync <= 'd0;
    end
            
endmodule
