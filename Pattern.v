`timescale 1ns / 1ps
module Pattern(
    input        VGA_clk,     // 像素時脈
    input        game_clk,    // 遊戲更新時脈（建議 ~10Hz）
    input        rst_n,
    input  [9:0] xpos,
    input  [9:0] ypos,
    input        btn_up,
    input        btn_down,
    input        btn_left,
    input        btn_right,
    input        btn_start,
    output [3:0] R,
    output [3:0] G,
    output [3:0] B
);
	// =========================
    // Start 畫面參數
    // =========================
    localparam [9:0] TITLE_X0 = 10'd250;
    localparam [9:0] TITLE_Y0 = 10'd140;
    
    localparam [9:0] CHAR_W = 10'd24;
    localparam [9:0] CHAR_H = 10'd36;
    localparam [9:0] THICK  = 10'd4;
    localparam [9:0] GAP    = 10'd10;
    
    // =========================
    // 基本參數
    // =========================
    localparam H_RES = 10'd800;
    localparam V_RES = 10'd600;

    reg [3:0] r_reg, g_reg, b_reg;
    assign R = r_reg;
    assign G = g_reg;
    assign B = b_reg;

    wire inside_screen = (xpos < H_RES) && (ypos < V_RES);
	localparam [3:0] START_BG_R = 4'd0;
    localparam [3:0] START_BG_G = 4'd0;
    localparam [3:0] START_BG_B = 4'd2;
    
    localparam [3:0] START_TXT_R = 4'd15;
    localparam [3:0] START_TXT_G = 4'd15;
    localparam [3:0] START_TXT_B = 4'd15;

    // =========================
    // 棋盤資料：board[row][col] 存 exponent
    // 0: 空, 1:2, 2:4, 3:8, 4:16, ...
    // =========================
    reg [5:0] board[0:3][0:3];

    // pseudo-random（給新 tile 用）
    reg [15:0] lfsr;
    wire       lfsr_fb = lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];

    // 分數：24-bit
    reg [31:0] score;

    // 遊戲狀態
    reg game_running;
    reg game_over_flag;

    // 按鍵邊緣偵測（在 game_clk domain）
    reg btn_up_d, btn_down_d, btn_left_d, btn_right_d, btn_start_d;
    wire up_pulse    = btn_up    & ~btn_up_d;
    wire down_pulse  = btn_down  & ~btn_down_d;
    wire left_pulse  = btn_left  & ~btn_left_d;
    wire right_pulse = btn_right & ~btn_right_d;
    wire start_pulse = btn_start & ~btn_start_d;

    integer r, c;
    integer ee;
    // =========================
    // exponent -> 十進位 3 位（Tile 裡顯示的值 2,4,8,16…）
    // =========================
    function [15:0] exp_to_dec4;
    input [5:0] e;
    integer v;
    reg [3:0] th, h, t, o;
    integer tmp;
    begin
        if (e == 0) begin
            th = 4'hF; h = 4'hF; t = 4'hF; o = 4'hF;
        end else begin
            v = (1 << e);
            if (v > 9999) v = 9999; // 要更大也行，但tile放得下就好

            if (v < 10) begin
                th=4'hF; h=4'hF; t=4'hF; o=v;
            end else if (v < 100) begin
                th=4'hF; h=4'hF; t=(v/10)%10; o=v%10;
            end else if (v < 1000) begin
                th=4'hF; h=(v/100)%10;
                tmp=v%100; t=(tmp/10)%10; o=tmp%10;
            end else begin
                th=(v/1000)%10;
                tmp=v%1000;
                h=(tmp/100)%10;
                tmp=tmp%100;
                t=(tmp/10)%10;
                o=tmp%10;
            end
        end
        exp_to_dec4 = {th, h, t, o};
    end
endfunction



    // =========================
    // 分數 score -> 十進位 6 位 (d5 d4 d3 d2 d1 d0)
    // =========================
    function [23:0] score_to_dec6;
        input [31:0] s;
        integer v;
        reg [3:0] d0, d1, d2, d3, d4, d5;
        begin
            v  = s;
            d0 = v % 10;  v = v / 10;
            d1 = v % 10;  v = v / 10;
            d2 = v % 10;  v = v / 10;
            d3 = v % 10;  v = v / 10;
            d4 = v % 10;  v = v / 10;
            d5 = v % 10;
            score_to_dec6 = {d5, d4, d3, d2, d1, d0};
        end
    endfunction

    // =========================
    // 3x5 點陣字型（0~F）
    // bit0 在字串最右下角，bit14 在最左上角
    // 取的時候用 pattern[14 - idx] 對齊
    // =========================
    function [14:0] hex_digit_pattern;
        input [3:0] d;
        begin
            case (d)
                4'h0: hex_digit_pattern = 15'b111_101_101_101_111; // 0
                4'h1: hex_digit_pattern = 15'b010_010_010_010_010; // 1
                4'h2: hex_digit_pattern = 15'b111_001_111_100_111; // 2
                4'h3: hex_digit_pattern = 15'b111_001_111_001_111; // 3
                4'h4: hex_digit_pattern = 15'b101_101_111_001_001; // 4
                4'h5: hex_digit_pattern = 15'b111_100_111_001_111; // 5
                4'h6: hex_digit_pattern = 15'b111_100_111_101_111; // 6
                4'h7: hex_digit_pattern = 15'b111_001_001_001_001; // 7
                4'h8: hex_digit_pattern = 15'b111_101_111_101_111; // 8
                4'h9: hex_digit_pattern = 15'b111_101_111_001_111; // 9
                4'hA: hex_digit_pattern = 15'b111_101_111_101_101; // A
                4'hB: hex_digit_pattern = 15'b110_101_110_101_110; // b
                4'hC: hex_digit_pattern = 15'b111_100_100_100_111; // C
                4'hD: hex_digit_pattern = 15'b110_101_101_101_110; // d
                4'hE: hex_digit_pattern = 15'b111_100_111_100_111; // E
                4'hF: hex_digit_pattern = 15'b111_100_111_100_100; // F
                default: hex_digit_pattern = 15'b000_000_000_000_000;
            endcase
        end
    endfunction

    // =========================
    // 一列往左移 + 合併 + 回傳此列增加分數
    // =========================
    task move_line_left;
    input  [5:0] a0, a1, a2, a3;
    output [5:0] b0, b1, b2, b3;
    output [31:0] add_score;
    output        moved;

    reg [5:0] tmp [0:3];
    reg [5:0] tmp2[0:3];
    reg       merged[0:3];   // ★ 新增
    integer i, j;

    begin
        add_score = 32'd0;

        // init
        for (i=0;i<4;i=i+1) begin
            tmp[i]    = 0;
            tmp2[i]   = 0;
            merged[i] = 0;
        end

        // 第一次壓縮
        j = 0;
        if (a0!=0) begin tmp[j]=a0; j=j+1; end
        if (a1!=0) begin tmp[j]=a1; j=j+1; end
        if (a2!=0) begin tmp[j]=a2; j=j+1; end
        if (a3!=0) begin tmp[j]=a3; j=j+1; end

        // ★ 正確合併（禁止二次合併）
        for (i=0;i<3;i=i+1) begin
            if (tmp[i]!=0 && tmp[i]==tmp[i+1] && !merged[i]) begin
                tmp[i]   = tmp[i] + 1;
                tmp[i+1] = 0;
                merged[i]= 1;
                add_score = add_score + (32'd1 << tmp[i]);
            end
        end

        // 第二次壓縮
        j = 0;
        for (i=0;i<4;i=i+1) begin
            if (tmp[i]!=0) begin
                tmp2[j] = tmp[i];
                j=j+1;
            end
        end

        b0 = tmp2[0];
        b1 = tmp2[1];
        b2 = tmp2[2];
        b3 = tmp2[3];

        moved = (b0!=a0)||(b1!=a1)||(b2!=a2)||(b3!=a3);
    end
endtask


    // =========================
    // 隨機放一顆 2 或 4
    // =========================
    task add_random_tile_pos;
        output integer rr_out, cc_out;
        integer i, idx, start_idx;
        begin
            rr_out = -1;
            cc_out = -1;
            start_idx = lfsr[3:0];
    
            for (i = 0; i < 16; i = i + 1) begin
                idx = (start_idx + i) & 4'hF;
                if (board_next[idx/4][idx%4] == 0) begin
                    rr_out = idx / 4;
                    cc_out = idx % 4;
                    disable add_random_tile_pos;
                end
            end
        end
    endtask

    // =========================
    // 是否還有合法移動
    // =========================
    task has_any_move;
        output reg can_move;
        integer rr, cc;
        begin
            can_move = 1'b0;

            // 有空格就可以動
            for (rr = 0; rr < 4; rr = rr + 1) begin
                for (cc = 0; cc < 4; cc = cc + 1) begin
                    if (board[rr][cc] == 0)
                        can_move = 1'b1;
                end
            end

            // 相鄰一樣也可以動
            for (rr = 0; rr < 4; rr = rr + 1) begin
                for (cc = 0; cc < 4; cc = cc + 1) begin
                    if (cc < 3 && board[rr][cc] == board[rr][cc+1] && board[rr][cc] != 0)
                        can_move = 1'b1;
                    if (rr < 3 && board[rr][cc] == board[rr+1][cc] && board[rr][cc] != 0)
                        can_move = 1'b1;
                end
            end
        end
    endtask

    // =========================
// 遊戲主邏輯（game_clk）【最終穩定版】
// =========================
reg [5:0] board_next [0:3][0:3];

reg any_moved;
reg line_moved;
reg [5:0]  b0, b1, b2, b3;
reg [31:0] line_score;
reg [31:0] add_score_total;
reg        can_move_now;

integer r, c;
integer rr, cc;
integer found;
integer new_rr, new_cc;

always @(posedge game_clk or negedge rst_n) begin
    if (!rst_n) begin
        for (r = 0; r < 4; r = r + 1)
            for (c = 0; c < 4; c = c + 1)
                board[r][c] <= 6'd0;

        lfsr           <= 16'h1;
        btn_up_d       <= 1'b0;
        btn_down_d     <= 1'b0;
        btn_left_d     <= 1'b0;
        btn_right_d    <= 1'b0;
        btn_start_d    <= 1'b0;
        game_running   <= 1'b0;
        game_over_flag <= 1'b0;
        score          <= 32'd0;

    end else begin
        // =================================
        // input / LFSR
        // =================================
        lfsr <= {lfsr[14:0], lfsr_fb};

        btn_up_d     <= btn_up;
        btn_down_d   <= btn_down;
        btn_left_d   <= btn_left;
        btn_right_d  <= btn_right;
        btn_start_d  <= btn_start;

        // =================================
        // Start：重新開局
        // =================================
        if ((start_pulse) || (game_over_flag&&start_pulse)) begin
            for (r = 0; r < 4; r = r + 1)
                for (c = 0; c < 4; c = c + 1)
                    board[r][c] <= 6'd0;
        
            game_running   <= 1'b1;
            game_over_flag <= 1'b0;
            score          <= 32'd0;
        
            board[0][0] <= 6'd1;
            board[0][1] <= 6'd1;
        end
         else if (game_running) begin
            // =================================
            // board → board_next
            // =================================
            for (r = 0; r < 4; r = r + 1)
                for (c = 0; c < 4; c = c + 1)
                    board_next[r][c] = board[r][c];

            any_moved       = 1'b0;
            add_score_total = 32'd0;

            // =================================
            // 左移
            // =================================
            if (left_pulse) begin
                for (r = 0; r < 4; r = r + 1) begin
                    move_line_left(
                        board[r][0], board[r][1], board[r][2], board[r][3],
                        b0, b1, b2, b3,
                        line_score, line_moved
                    );
                    board_next[r][0] = b0;
                    board_next[r][1] = b1;
                    board_next[r][2] = b2;
                    board_next[r][3] = b3;

                    if (line_moved) any_moved = 1'b1;
                    add_score_total = add_score_total + line_score;
                end
            end
            // =================================
            // 右移
            // =================================
            else if (right_pulse) begin
                for (r = 0; r < 4; r = r + 1) begin
                    move_line_left(
                        board[r][3], board[r][2], board[r][1], board[r][0],
                        b0, b1, b2, b3,
                        line_score, line_moved
                    );
                    board_next[r][0] = b3;
                    board_next[r][1] = b2;
                    board_next[r][2] = b1;
                    board_next[r][3] = b0;

                    if (line_moved) any_moved = 1'b1;
                    add_score_total = add_score_total + line_score;
                end
            end
            // =================================
            // 上移
            // =================================
            else if (up_pulse) begin
                for (c = 0; c < 4; c = c + 1) begin
                    move_line_left(
                        board[0][c], board[1][c], board[2][c], board[3][c],
                        b0, b1, b2, b3,
                        line_score, line_moved
                    );
                    board_next[0][c] = b0;
                    board_next[1][c] = b1;
                    board_next[2][c] = b2;
                    board_next[3][c] = b3;

                    if (line_moved) any_moved = 1'b1;
                    add_score_total = add_score_total + line_score;
                end
            end
            // =================================
            // 下移
            // =================================
            else if (down_pulse) begin
                for (c = 0; c < 4; c = c + 1) begin
                    move_line_left(
                        board[3][c], board[2][c], board[1][c], board[0][c],
                        b0, b1, b2, b3,
                        line_score, line_moved
                    );
                    board_next[0][c] = b3;
                    board_next[1][c] = b2;
                    board_next[2][c] = b1;
                    board_next[3][c] = b0;

                    if (line_moved) any_moved = 1'b1;
                    add_score_total = add_score_total + line_score;
                end
            end

            // =================================
            // commit board + 新 tile
            // =================================            
            if (any_moved) begin
                score <= score + add_score_total;

                // 先 commit
                for (r = 0; r < 4; r = r + 1)
                    for (c = 0; c < 4; c = c + 1)
                        board[r][c] <= board_next[r][c];

                // 決定位置
                add_random_tile_pos(new_rr, new_cc);
            
                // ★ 只在這裡加新 tile
                if (new_rr != -1) begin
                    board[new_rr][new_cc] <= (lfsr[4] ? 6'd1 : 6'd2);
                end
            end

            // =================================
            // Game Over 檢查（用 board_next）
            // =================================
            has_any_move(can_move_now);
            if (!can_move_now) begin
                game_running   <= 1'b0;
                game_over_flag <= 1'b1;
            end
        end
    end
end



    // =========================
    // VGA：棋盤 + 背景
    // =========================
    localparam [3:0] BG_R = 4'd1;
    localparam [3:0] BG_G = 4'd1;
    localparam [3:0] BG_B = 4'd3;

    // 棋盤框
    localparam BOARD_X0   = 10'd200;
    localparam BOARD_Y0   = 10'd120;
    localparam CELL_SIZE  = 10'd100;
    localparam BOARD_SIZE = 10'd400;

    wire inside_board = (xpos >= BOARD_X0) && (xpos < BOARD_X0 + BOARD_SIZE) &&
                        (ypos >= BOARD_Y0) && (ypos < BOARD_Y0 + BOARD_SIZE);

    wire [9:0] local_x = xpos - BOARD_X0;
    wire [9:0] local_y = ypos - BOARD_Y0;

    wire [1:0] cell_c = local_x / CELL_SIZE;
    wire [1:0] cell_r = local_y / CELL_SIZE;

    wire [9:0] cell_x = local_x % CELL_SIZE;
    wire [9:0] cell_y = local_y % CELL_SIZE;

    wire on_grid = (cell_x < 10'd4) || (cell_y < 10'd4);

    // 目前格子的 exponent
    reg [5:0] cell_exp;
    always @* begin
    if (inside_board) begin
        // 根據 (xpos, ypos) 計算當前格子的 (r, c) 索引
        cell_exp = board[cell_r][cell_c];  // 先假設 cell_exp = board[rr][cc]
        
        // 這裡加入對 board[r][c] 是否為 0 的判斷
        if (board[cell_r][cell_c] != 0) begin
            // 確保值不為 0 才顯示數字
            cell_exp = board[cell_r][cell_c];
        end else begin
            // 空格，顯示為背景
            cell_exp = 6'd0;
        end
    end else begin
        // 如果不在棋盤範圍內，顯示為背景
        cell_exp = 6'd0;
    end
end


    // exponent → 顏色
    function [11:0] tile_color;
        input [5:0] e;
        begin
            case (e)
                0:  tile_color = 12'hCCB; // empty
                1:  tile_color = 12'hEDB; // 2
                2:  tile_color = 12'hECC; // 4
                3:  tile_color = 12'hF76; // 8
                4:  tile_color = 12'hF63; // 16
                5:  tile_color = 12'hF65; // 32
                6:  tile_color = 12'hF43; // 64
                7:  tile_color = 12'hED7; // 128
                8:  tile_color = 12'hED6; // 256
                9:  tile_color = 12'hEC5; // 512
                10: tile_color = 12'hEC3; // 1024
                11: tile_color = 12'hEC2; // 2048
                12: tile_color = 12'h58E; // 4096
                13: tile_color = 12'hF97; // 8192
                14: tile_color = 12'hD43; // 16384
                15: tile_color = 12'h5BE; // 32768
                16: tile_color = 12'h368; // 65536
                default: tile_color = 12'h259; // 131072
            endcase
        end
    endfunction

    wire [11:0] cell_rgb = tile_color(cell_exp);
    wire [3:0]  cell_R   = cell_rgb[11:8];
    wire [3:0]  cell_G   = cell_rgb[7:4];
    wire [3:0]  cell_B   = cell_rgb[3:0];

    localparam [3:0] BOARD_R = 4'd4;
    localparam [3:0] BOARD_G = 4'd4;
    localparam [3:0] BOARD_B = 4'd5;

    localparam [3:0] GRID_R = 4'd2;
    localparam [3:0] GRID_G = 4'd2;
    localparam [3:0] GRID_B = 4'd2;

    // =========================
    // Tile 內的數字（自動置中 + 有空隙）
    // =========================
    localparam DIG_W     = 10'd15;   // 單一數字寬度
    localparam DIG_H     = 10'd25;   // 高度
    localparam DIG_TOP   = 10'd35;   // 距離 tile 上緣
    localparam DIG_SPACE = 10'd4;    // 數字間空隙

    wire [15:0] dec4 = exp_to_dec4(cell_exp);
    wire [3:0] d_th = dec4[15:12];
    wire [3:0] d_h  = dec4[11:8];
    wire [3:0] d_t  = dec4[7:4];
    wire [3:0] d_o  = dec4[3:0];


    reg tile_digit_on;

    integer td_ndig;
    integer td_group_w, td_group_left;
    integer td_relx, td_rely;
    integer td_seg, td_segx;
    integer td_gx, td_gy, td_idx;
    reg [3:0]  td_digit;
    reg [14:0] td_pat;

    always @* begin
    tile_digit_on = 1'b0;

    if (inside_board && !on_grid && cell_exp != 0) begin
        // =================================================
        // 判斷是幾位數（支援到 4 位）
        // =================================================
        if      (d_th != 4'hF)
            td_ndig = 4;
        else if (d_h  != 4'hF)
            td_ndig = 3;
        else if (d_t  != 4'hF)
            td_ndig = 2;
        else if (d_o  != 4'hF)
            td_ndig = 1;
        else
            td_ndig = 0;

        if (td_ndig > 0) begin
            // =================================================
            // 數字群組置中
            // =================================================
            td_group_w    = td_ndig * DIG_W + (td_ndig - 1) * DIG_SPACE;
            td_group_left = (CELL_SIZE - td_group_w) / 2;

            if (cell_x >= td_group_left &&
                cell_x <  td_group_left + td_group_w &&
                cell_y >= DIG_TOP &&
                cell_y <  DIG_TOP + DIG_H) begin

                td_relx = cell_x - td_group_left;
                td_rely = cell_y - DIG_TOP;

                td_seg  = td_relx / (DIG_W + DIG_SPACE);
                td_segx = td_relx % (DIG_W + DIG_SPACE);

                if (td_segx < DIG_W) begin
                    td_digit = 4'hF;

                    // =================================================
                    // 依位數選 digit
                    // =================================================
                    if (td_ndig == 4) begin
                        if      (td_seg == 0) td_digit = d_th;
                        else if (td_seg == 1) td_digit = d_h;
                        else if (td_seg == 2) td_digit = d_t;
                        else if (td_seg == 3) td_digit = d_o;
                    end
                    else if (td_ndig == 3) begin
                        if      (td_seg == 0) td_digit = d_h;
                        else if (td_seg == 1) td_digit = d_t;
                        else if (td_seg == 2) td_digit = d_o;
                    end
                    else if (td_ndig == 2) begin
                        if      (td_seg == 0) td_digit = d_t;
                        else if (td_seg == 1) td_digit = d_o;
                    end
                    else if (td_ndig == 1) begin
                        if (td_seg == 0) td_digit = d_o;
                    end

                    // =================================================
                    // 3x5 font 繪製
                    // =================================================
                    if (td_digit != 4'hF) begin
                        td_gx = td_segx / 5;
                        td_gy = td_rely / 5;

                        if (td_gx < 3 && td_gy < 5) begin
                            td_idx = td_gy * 3 + td_gx;
                            td_pat = hex_digit_pattern(td_digit);
                            if (td_pat[14 - td_idx])
                                tile_digit_on = 1'b1;
                        end
                    end
                end
            end
        end
    end
end


    // =========================
    // 分數顯示：十進位 6 位，彼此有空格
    // =========================
    localparam SCORE_NDIG    = 6;
    localparam SCORE_DIG_W   = 10'd12;   // 單一 digit 畫圖寬度
    localparam SCORE_SPACE   = 10'd6;    // digit 間空白
    localparam SCORE_DIG_H   = 10'd25;
    localparam SCORE_X0      = 10'd220;  // 整排左上角
    localparam SCORE_Y0      = 10'd40;
    localparam SCORE_TOTAL_W = SCORE_NDIG * (SCORE_DIG_W + SCORE_SPACE) - SCORE_SPACE;

    wire inside_score_area =
        (ypos >= SCORE_Y0) && (ypos < SCORE_Y0 + SCORE_DIG_H) &&
        (xpos >= SCORE_X0) && (xpos < SCORE_X0 + SCORE_TOTAL_W);

    // score -> 6 個十進位 digit
    wire [23:0] score_dec = score_to_dec6(score);
    wire [3:0] sc5 = score_dec[23:20];
    wire [3:0] sc4 = score_dec[19:16];
    wire [3:0] sc3 = score_dec[15:12];
    wire [3:0] sc2 = score_dec[11:8];
    wire [3:0] sc1 = score_dec[7:4];
    wire [3:0] sc0 = score_dec[3:0];

    reg score_digit_on;
    integer sd_dx, sd_dy;
    integer sd_relx, sd_rely;
    integer sd_seg, sd_segx;
    integer sd_gx, sd_gy, sd_idx;
    reg [3:0]  sd_digit;
    reg [14:0] sd_pat;

    always @* begin
        score_digit_on = 1'b0;

        if (inside_score_area) begin
            sd_dx = xpos - SCORE_X0;
            sd_dy = ypos - SCORE_Y0;

            sd_relx = sd_dx;
            sd_rely = sd_dy;

            // 在第幾個 digit
            sd_seg  = sd_relx / (SCORE_DIG_W + SCORE_SPACE);
            sd_segx = sd_relx % (SCORE_DIG_W + SCORE_SPACE);

            if (sd_seg < SCORE_NDIG && sd_segx < SCORE_DIG_W) begin
                case (sd_seg)
                    0: sd_digit = sc5;
                    1: sd_digit = sc4;
                    2: sd_digit = sc3;
                    3: sd_digit = sc2;
                    4: sd_digit = sc1;
                    default: sd_digit = sc0;
                endcase

                // 轉成 3x5 點陣
                sd_gx = sd_segx / 4;   // 12/3 ? 4
                sd_gy = sd_rely / 5;

                if (sd_gx >= 0 && sd_gx < 3 && sd_gy >= 0 && sd_gy < 5) begin
                    sd_idx = sd_gy * 3 + sd_gx;
                    sd_pat = hex_digit_pattern(sd_digit);
                    if (sd_pat[14 - sd_idx])
                        score_digit_on = 1'b1;
                end
            end
        end
    end

	// =======================================
    // 5x7 pixel font (only G A M E S T R)
    // =======================================
    function draw_char;
        input [9:0] x, y;
        input [9:0] x0, y0;
        input [7:0] ch;
        input [3:0] scale; // 放大倍率
        reg on;
        integer px, py;
        begin
            on = 0;
            px = (x - x0) / scale;
            py = (y - y0) / scale;
    
            case (ch)
                "G": on = (px==0)||(py==0)||(py==6)||(px==4&&py>=3)||(py==3&&px>=2);
                "A": on = (px==0)||(px==4)||(py==0)||(py==3);
                "M": on = (px==0)||(px==4)||(px==py)||(px==4-py);
                "E": on = (px==0)||(py==0)||(py==3)||(py==6);
                "S": on = (py==0)||(py==3)||(py==6)||(px==0&&py<3)||(px==4&&py>3);
                "T": on = (py==0)||(px==2);
                "R": on = (px==0)||(py==0)||(py==3)||(px==4&&py<3)||(px==py-2);
                "O": on = (px==0)||(px==4)||(py==0)||(py==6);
                "V": on = (px==0&&py<6)||(px==4&&py<6)||(py==6&&px==2);

                default: on = 0;
            endcase
    
            draw_char = on &&
                (px>=0 && px<5 && py>=0 && py<7);
        end
    endfunction
	localparam SCALE = 6;

    localparam TEXT_CHARS = 10;
    localparam CHAR_PIX_W = 5*SCALE + 10;
    localparam TEXT_WIDTH = TEXT_CHARS * CHAR_PIX_W;
    localparam TEXT_HEIGHT = 7 * SCALE;
    
    localparam TXT_X = (H_RES - TEXT_WIDTH) / 2;
    localparam TXT_Y = (V_RES - TEXT_HEIGHT) / 2;
    
	// =========================
    // GAME START 文字組合邏輯
    // =========================
    wire draw_game_start =
        draw_char(xpos,ypos, TXT_X +  0*(5*SCALE+10), TXT_Y, "G", SCALE) ||
        draw_char(xpos,ypos, TXT_X +  1*(5*SCALE+10), TXT_Y, "A", SCALE) ||
        draw_char(xpos,ypos, TXT_X +  2*(5*SCALE+10), TXT_Y, "M", SCALE) ||
        draw_char(xpos,ypos, TXT_X +  3*(5*SCALE+10), TXT_Y, "E", SCALE) ||
    
        draw_char(xpos,ypos, TXT_X +  5*(5*SCALE+10), TXT_Y, "S", SCALE) ||
        draw_char(xpos,ypos, TXT_X +  6*(5*SCALE+10), TXT_Y, "T", SCALE) ||
        draw_char(xpos,ypos, TXT_X +  7*(5*SCALE+10), TXT_Y, "A", SCALE) ||
        draw_char(xpos,ypos, TXT_X +  8*(5*SCALE+10), TXT_Y, "R", SCALE) ||
        draw_char(xpos,ypos, TXT_X +  9*(5*SCALE+10), TXT_Y, "T", SCALE);

    // 星空背景
    wire star =
    ((xpos * 37 + ypos * 13) & 10'h1FF) == 10'h1AA;
    
    // =========================
    // GAME OVER 文字組合邏輯（用同一套 draw_char）
    // =========================
    wire draw_game_over =
        draw_char(xpos,ypos, TXT_X +  0*(5*SCALE+10), TXT_Y, "G", SCALE) ||
        draw_char(xpos,ypos, TXT_X +  1*(5*SCALE+10), TXT_Y, "A", SCALE) ||
        draw_char(xpos,ypos, TXT_X +  2*(5*SCALE+10), TXT_Y, "M", SCALE) ||
        draw_char(xpos,ypos, TXT_X +  3*(5*SCALE+10), TXT_Y, "E", SCALE) ||
    
        draw_char(xpos,ypos, TXT_X +  5*(5*SCALE+10), TXT_Y, "O", SCALE) ||
        draw_char(xpos,ypos, TXT_X +  6*(5*SCALE+10), TXT_Y, "V", SCALE) ||
        draw_char(xpos,ypos, TXT_X +  7*(5*SCALE+10), TXT_Y, "E", SCALE) ||
        draw_char(xpos,ypos, TXT_X +  8*(5*SCALE+10), TXT_Y, "R", SCALE);

    
        // ============================================================
        // VGA 顏色輸出（Start / Playing / Game Over）
        // ============================================================
        always @(posedge VGA_clk or negedge rst_n) begin
            if (!rst_n) begin
                r_reg <= 4'd0;
                g_reg <= 4'd0;
                b_reg <= 4'd0;
            end
            else if (!inside_screen) begin
                r_reg <= 4'd0;
                g_reg <= 4'd0;
                b_reg <= 4'd0;
            end
    
    // ========================================================
    // Game Over 畫面（最高優先）
    // ========================================================
    else if (game_over_flag) begin
        // 黑底
        r_reg <= 4'd0;
        g_reg <= 4'd0;
        b_reg <= 4'd0;

        // GAME OVER 字樣（紅色）
        if (draw_game_over) begin
            r_reg <= 4'd15;
            g_reg <= 4'd0;
            b_reg <= 4'd0;
        end
    end

    // ========================================================
    // Start 起始畫面
    // ========================================================
    else if (!game_running) begin
        // 背景色
        r_reg <= START_BG_R;
        g_reg <= START_BG_G;
        b_reg <= START_BG_B;

        // 星空背景
        if (star) begin
            r_reg <= 4'd8;
            g_reg <= 4'd8;
            b_reg <= 4'd8;
        end

        // GAME START 字樣
        if (draw_game_start) begin
            r_reg <= START_TXT_R;
            g_reg <= START_TXT_G;
            b_reg <= START_TXT_B;
        end
    end

    // ========================================================
    // 遊戲進行中
    // ========================================================
    else begin
        // 背景
        r_reg <= BG_R;
        g_reg <= BG_G;
        b_reg <= BG_B;

        // 分數底色
        if (inside_score_area) begin
            r_reg <= 4'd4;
            g_reg <= 4'd4;
            b_reg <= 4'd6;
        end

        // 分數數字（白）
        if (score_digit_on) begin
            r_reg <= 4'd15;
            g_reg <= 4'd15;
            b_reg <= 4'd15;
        end

        // 棋盤底板
        if (inside_board) begin
            r_reg <= BOARD_R;
            g_reg <= BOARD_G;
            b_reg <= BOARD_B;
        end

        // 格線
        if (inside_board && on_grid) begin
            r_reg <= GRID_R;
            g_reg <= GRID_G;
            b_reg <= GRID_B;
        end

        // tile 顏色
        if (inside_board && !on_grid && cell_exp != 0) begin
            r_reg <= cell_R;
            g_reg <= cell_G;
            b_reg <= cell_B;
        end

        // tile 裡面的數字（黑色）
        if (tile_digit_on) begin
            r_reg <= 4'd0;
            g_reg <= 4'd0;
            b_reg <= 4'd0;
        end
    end
end

endmodule
