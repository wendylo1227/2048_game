`timescale 1ns / 1ps
module Top(
    input sys_clk_in,
    input sys_rst_n,

    // 5 顆按鍵：上、下、左、右、中間
    input [4:0] btn_pin,

    output vga_hs_pin,
    output vga_vs_pin,
    output [3:0] vga_R_Data_pin,
    output [3:0] vga_G_Data_pin,
    output [3:0] vga_B_Data_pin
   
);
    wire music_beat_clk;  // ? 音樂專用節拍
    wire clk_bufg; // 用於全局分佈的緩衝時鐘 [cite: 229]
    wire VGA_clk;
    wire game_clk; // 比較慢的 clock，用來讀按鍵 + 更新 2048 [cite: 230]
    wire [9:0] xpos;
    wire [9:0] ypos;
    
    
    // 實例化 BUFG (全局時鐘緩衝器)
    BUFG sys_clk_bufg (
        .I (sys_clk_in), // 輸入系統時鐘
        .O (clk_bufg)    // 輸出緩衝後的時鐘
    ); 
    
    
    // 40MHz VGA clock (PLL/MMCM)
    Vga_40MH Vga_40MH(
        .clk_in1(clk_bufg), // *** 使用緩衝後的時鐘 ***
        .resetn(sys_rst_n),
        .clk_out1(VGA_clk),
        .locked()
    ); 
    
    
    // 時脈分頻 (計數器實現的慢速分頻器)
    Divider_Clock #(
        .Custom_Outputclk_0(),
        .Custom_Outputclk_1(),
        .Custom_Outputclk_2()
    ) u_Divider_Clock (
        .clkin(clk_bufg), // *** 使用緩衝後的時鐘 ***
        .rst_n(sys_rst_n),
        .clkout_1K(),
        .clkout_100(),
        .clkout_10(game_clk),    // 這個當作遊戲更新 clock（約 10Hz）
        .clkout_1(),
        .clkout_music(music_beat_clk), // ? 新增接腳
        .clkout_Custom_0(),
        .clkout_Custom_1(),
        .clkout_Custom_2()
    ); 
    
    // VGA 時序
    VGAControll VGA(
        .VGA_clk(VGA_clk),
        .rst_n(sys_rst_n),
        .hsync(vga_hs_pin),
        .vsync(vga_vs_pin),
        .xpos(xpos),
        .ypos(ypos)
    ); 
    
    // 2048 畫面 + 遊戲邏輯
    Pattern u_Pattern(
        .VGA_clk(VGA_clk),
        .game_clk(game_clk),
        .rst_n(sys_rst_n),
        .xpos(xpos),
        .ypos(ypos),

        // 按鍵
        .btn_up   (btn_pin[4]),
        .btn_down (btn_pin[1]),
        .btn_left (btn_pin[3]),
        .btn_right(btn_pin[0]),
        .btn_start(btn_pin[2]), 

        .R(vga_R_Data_pin),
        .G(vga_G_Data_pin),
        .B(vga_B_Data_pin)
    );
    
    
endmodule 