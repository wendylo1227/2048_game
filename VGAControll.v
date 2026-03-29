`timescale 1ns / 1ps
module VGAControll(
  input VGA_clk,
  input rst_n,
  output reg hsync,
  output reg vsync,
  output [9:0] xpos,
  output [9:0] ypos
 );
 
 // 800 x 600 @ 60Hz
    parameter H_sync_end   = 128;   // HSYNC 低電位寬度
    parameter H_sysc_Total = 1055;  // 0 ~ 1055 共 1056 個 clock
    parameter H_Show_Start = 216;   // 128(sync) + 88(back porch)
    parameter V_sync_end   = 4;     // VSYNC 低電位寬度
    parameter V_sysc_Total = 627;   // 0 ~ 627 共 628 條
    parameter V_Show_Start = 27;    // 4(sync) + 23(back porch)
 
 reg [10:0] x_cnt;
 reg [9:0] y_cnt;
 
 always @(posedge VGA_clk or negedge rst_n)
 begin
        if (!rst_n)
            x_cnt <= 11'd0;
        else if (x_cnt == H_sysc_Total)   // H_sysc_Total 已經設成 1055
            x_cnt <= 11'd0;
        else 
            x_cnt <= x_cnt + 1'b1;
    end

 
 always@(posedge VGA_clk or negedge rst_n) 
 begin
        if(!rst_n)
            y_cnt <= 10'd0;
        else if (y_cnt == V_sysc_Total)
            y_cnt <= 10'd0;
        else if (x_cnt == H_sysc_Total)
            y_cnt <= y_cnt + 1'b1;
    end

  
 always@(posedge VGA_clk or negedge rst_n)
 begin
  if(!rst_n)
   hsync <= 1'b0;
  else if(x_cnt == 11'd0)
   hsync <= 1'b0;
  else if(x_cnt == H_sync_end)
   hsync <= 1'b1;
 end
 
 always@(posedge VGA_clk or negedge rst_n) 
 begin
        if(!rst_n)
            vsync <= 1'b0;
        else if(y_cnt == 10'd0)
            vsync <= 1'b0;
        else if(y_cnt == V_sync_end)
            vsync <= 1'b1;
    end

 assign xpos = x_cnt - H_Show_Start;
 assign ypos = y_cnt - V_Show_Start;

endmodule