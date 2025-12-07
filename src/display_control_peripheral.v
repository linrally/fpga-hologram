// display_control_peripheral.v
// Memory-mapped display control peripheral for CPU-driven menu system
//
// Memory Map (base address: 0xFFFF1000):
//   0xFFFF1000 - DISP_MODE      (RW): Display mode: 0=globe, 1=cube
//   0xFFFF1004 - DISP_BRIGHTNESS (RW): Brightness: 0-255 (0=off, 255=full)
//   0xFFFF1008 - DISP_EFFECT    (RW): Color effect: 0=normal, 1=grayscale, 2=sepia, 3=inverted, 4=rainbow
//   0xFFFF100C - DISP_SPEED     (RW): Speed offset: 0-255 (affects column offset, not used in current design)
//   0xFFFF1010 - BTN_STATUS     (R):  Button status: bit0=BTNU, bit1=BTND, bit2=BTNC (active high when pressed)
//   0xFFFF1014 - MENU_SEL       (RW): Current menu selection (0-4)
//   0xFFFF1018 - LED_OUT        (RW): LED output for menu feedback (bits [15:0] for 16 LEDs)
//
// Pixel Processing Pipeline:
//   Input pixel → Brightness adjustment → Color effect → Output pixel

module display_control_peripheral(
    input  wire        clk,
    input  wire        reset,
    
    // CPU memory-mapped interface
    input  wire [31:0] cpu_addr,
    input  wire [31:0] cpu_data_in,
    input  wire        cpu_wren,
    input  wire        cpu_rden,
    output reg  [31:0] cpu_data_out,
    
    // Button inputs (raw, will be debounced internally)
    input  wire        btn_up,      // BTNU
    input  wire        btn_down,    // BTND
    input  wire        btn_center, // BTNC
    
    // Pixel processing pipeline
    input  wire [23:0] pixel_in,    // Raw pixel from ROM
    output reg  [23:0] pixel_out,   // Processed pixel (brightness + effect applied)
    
    // Control outputs
    output reg         disp_mode,    // 0=globe, 1=cube
    output reg  [7:0]  disp_brightness,
    output reg  [2:0]  disp_effect,
    output reg  [3:0]  menu_sel,
    output reg  [15:0] led_out
);

    // Memory-mapped register addresses
    localparam DISP_MODE      = 32'hFFFF1000;
    localparam DISP_BRIGHTNESS = 32'hFFFF1004;
    localparam DISP_EFFECT     = 32'hFFFF1008;
    localparam DISP_SPEED      = 32'hFFFF100C;
    localparam BTN_STATUS      = 32'hFFFF1010;
    localparam MENU_SEL        = 32'hFFFF1014;
    localparam LED_OUT         = 32'hFFFF1018;
    
    // Internal registers
    reg [7:0]  brightness_reg;
    reg [2:0]  effect_reg;
    reg [7:0]  speed_reg;
    reg [3:0]  menu_sel_reg;
    reg [15:0] led_out_reg;
    
    // Button debouncing (similar to breakbeam_sync_debounce)
    reg btn_up_sync0, btn_up_sync1;
    reg btn_down_sync0, btn_down_sync1;
    reg btn_center_sync0, btn_center_sync1;
    
    reg [11:0] btn_up_cnt, btn_down_cnt, btn_center_cnt;
    reg btn_up_stable, btn_down_stable, btn_center_stable;
    reg btn_up_clean, btn_down_clean, btn_center_clean;
    
    // Button edge detection (for single-press detection)
    reg btn_up_prev, btn_down_prev, btn_center_prev;
    wire btn_up_press, btn_down_press, btn_center_press;
    
    // Debounce buttons
    always @(posedge clk) begin
        if (reset) begin
            btn_up_sync0 <= 1'b0;
            btn_up_sync1 <= 1'b0;
            btn_down_sync0 <= 1'b0;
            btn_down_sync1 <= 1'b0;
            btn_center_sync0 <= 1'b0;
            btn_center_sync1 <= 1'b0;
            btn_up_stable <= 1'b0;
            btn_down_stable <= 1'b0;
            btn_center_stable <= 1'b0;
            btn_up_clean <= 1'b0;
            btn_down_clean <= 1'b0;
            btn_center_clean <= 1'b0;
            btn_up_cnt <= 12'h0;
            btn_down_cnt <= 12'h0;
            btn_center_cnt <= 12'h0;
        end else begin
            // Synchronize
            btn_up_sync0 <= btn_up;
            btn_up_sync1 <= btn_up_sync0;
            btn_down_sync0 <= btn_down;
            btn_down_sync1 <= btn_down_sync0;
            btn_center_sync0 <= btn_center;
            btn_center_sync1 <= btn_center_sync0;
            
            // Debounce UP
            if (btn_up_sync1 != btn_up_stable) begin
                btn_up_cnt <= btn_up_cnt + 1;
                if (&btn_up_cnt) begin
                    btn_up_stable <= btn_up_sync1;
                    btn_up_cnt <= 12'h0;
                end
            end else begin
                btn_up_cnt <= 12'h0;
            end
            btn_up_clean <= btn_up_stable;
            
            // Debounce DOWN
            if (btn_down_sync1 != btn_down_stable) begin
                btn_down_cnt <= btn_down_cnt + 1;
                if (&btn_down_cnt) begin
                    btn_down_stable <= btn_down_sync1;
                    btn_down_cnt <= 12'h0;
                end
            end else begin
                btn_down_cnt <= 12'h0;
            end
            btn_down_clean <= btn_down_stable;
            
            // Debounce CENTER
            if (btn_center_sync1 != btn_center_stable) begin
                btn_center_cnt <= btn_center_cnt + 1;
                if (&btn_center_cnt) begin
                    btn_center_stable <= btn_center_sync1;
                    btn_center_cnt <= 12'h0;
                end
            end else begin
                btn_center_cnt <= 12'h0;
            end
            btn_center_clean <= btn_center_stable;
        end
    end
    
    // Edge detection for button presses
    always @(posedge clk) begin
        if (reset) begin
            btn_up_prev <= 1'b0;
            btn_down_prev <= 1'b0;
            btn_center_prev <= 1'b0;
        end else begin
            btn_up_prev <= btn_up_clean;
            btn_down_prev <= btn_down_clean;
            btn_center_prev <= btn_center_clean;
        end
    end
    
    assign btn_up_press = btn_up_clean & ~btn_up_prev;
    assign btn_down_press = btn_down_clean & ~btn_down_prev;
    assign btn_center_press = btn_center_clean & ~btn_center_prev;
    
    // CPU write interface
    always @(posedge clk) begin
        if (reset) begin
            disp_mode <= 1'b0;
            brightness_reg <= 8'd255;  // Full brightness by default
            effect_reg <= 3'd0;        // Normal effect
            speed_reg <= 8'd128;      // Normal speed
            menu_sel_reg <= 4'd0;
            led_out_reg <= 16'h0001;   // LED 0 on by default
        end else if (cpu_wren) begin
            case (cpu_addr)
                DISP_MODE: begin
                    disp_mode <= cpu_data_in[0];
                end
                DISP_BRIGHTNESS: begin
                    brightness_reg <= cpu_data_in[7:0];
                end
                DISP_EFFECT: begin
                    effect_reg <= cpu_data_in[2:0];
                end
                DISP_SPEED: begin
                    speed_reg <= cpu_data_in[7:0];
                end
                MENU_SEL: begin
                    menu_sel_reg <= cpu_data_in[3:0];
                end
                LED_OUT: begin
                    led_out_reg <= cpu_data_in[15:0];
                end
            endcase
        end
    end
    
    // CPU read interface
    always @(*) begin
        cpu_data_out = 32'h0;
        if (cpu_rden) begin
            case (cpu_addr)
                DISP_MODE:      cpu_data_out = {31'h0, disp_mode};
                DISP_BRIGHTNESS: cpu_data_out = {24'h0, brightness_reg};
                DISP_EFFECT:    cpu_data_out = {29'h0, effect_reg};
                DISP_SPEED:     cpu_data_out = {24'h0, speed_reg};
                BTN_STATUS:     cpu_data_out = {29'h0, btn_center_clean, btn_down_clean, btn_up_clean};
                MENU_SEL:       cpu_data_out = {28'h0, menu_sel_reg};
                LED_OUT:        cpu_data_out = {16'h0, led_out_reg};
                default:        cpu_data_out = 32'h0;
            endcase
        end
    end
    
    // Update output registers
    always @(posedge clk) begin
        if (reset) begin
            disp_brightness <= 8'd255;
            disp_effect <= 3'd0;
            menu_sel <= 4'd0;
            led_out <= 16'h0001;
        end else begin
            disp_brightness <= brightness_reg;
            disp_effect <= effect_reg;
            menu_sel <= menu_sel_reg;
            led_out <= led_out_reg;
        end
    end
    
    // Pixel processing pipeline: Brightness adjustment
    wire [15:0] r_bright, g_bright, b_bright;
    wire [7:0] r_in, g_in, b_in;
    assign {r_in, g_in, b_in} = pixel_in;
    
    // Multiply by brightness (0-255) and divide by 255
    // Simplified: multiply by brightness, then shift right by 8
    assign r_bright = (r_in * brightness_reg) >> 8;
    assign g_bright = (g_in * brightness_reg) >> 8;
    assign b_bright = (b_in * brightness_reg) >> 8;
    
    wire [7:0] r_after_bright, g_after_bright, b_after_bright;
    assign r_after_bright = (r_bright > 255) ? 8'd255 : r_bright[7:0];
    assign g_after_bright = (g_bright > 255) ? 8'd255 : g_bright[7:0];
    assign b_after_bright = (b_bright > 255) ? 8'd255 : b_bright[7:0];
    
    // Color effects
    reg [7:0] r_effect, g_effect, b_effect;
    always @(*) begin
        case (effect_reg)
            3'd0: begin // Normal
                r_effect = r_after_bright;
                g_effect = g_after_bright;
                b_effect = b_after_bright;
            end
            3'd1: begin // Grayscale (luminance: 0.299*R + 0.587*G + 0.114*B)
                // Simplified: (R + G + B) / 3, or weighted average
                wire [9:0] gray = (r_after_bright * 3 + g_after_bright * 6 + b_after_bright * 1) / 10;
                r_effect = gray[7:0];
                g_effect = gray[7:0];
                b_effect = gray[7:0];
            end
            3'd2: begin // Sepia (warm brown tone)
                wire [9:0] r_sepia = (r_after_bright * 4 + g_after_bright * 3 + b_after_bright * 1) / 8;
                wire [9:0] g_sepia = (r_after_bright * 3 + g_after_bright * 4 + b_after_bright * 1) / 8;
                wire [9:0] b_sepia = (r_after_bright * 2 + g_after_bright * 2 + b_after_bright * 1) / 5;
                r_effect = (r_sepia > 255) ? 8'd255 : r_sepia[7:0];
                g_effect = (g_sepia > 255) ? 8'd255 : g_sepia[7:0];
                b_effect = (b_sepia > 255) ? 8'd255 : b_sepia[7:0];
            end
            3'd3: begin // Inverted
                r_effect = 8'd255 - r_after_bright;
                g_effect = 8'd255 - g_after_bright;
                b_effect = 8'd255 - b_after_bright;
            end
            3'd4: begin // Rainbow shift (simple hue rotation based on column)
                // For now, just add a color tint (can be enhanced later)
                r_effect = (r_after_bright + g_after_bright) / 2;
                g_effect = (g_after_bright + b_after_bright) / 2;
                b_effect = (b_after_bright + r_after_bright) / 2;
            end
            default: begin
                r_effect = r_after_bright;
                g_effect = g_after_bright;
                b_effect = b_after_bright;
            end
        endcase
    end
    
    // Output processed pixel
    always @(posedge clk) begin
        pixel_out <= {r_effect, g_effect, b_effect};
    end

endmodule

