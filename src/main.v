// main.v
// Top-level for POV display with WS2812 and break-beam angle locking

module main(
    input  wire clk,          // 100 MHz board clock
    input  wire break_din,    // IR break-beam sensor input
    output wire ws2812_dout,  // data out to WS2812 strip
    output wire [0:0] LED     // debug LED
);
    // Debug: mirror raw break-beam input on LED
    assign LED = break_din;

    // Texture dimensions
    localparam LED_COUNT  = 52;   // number of LEDs on strip
    localparam TEX_WIDTH  = 256;  // columns around the circle

    // ------------------------------------------------------------
    // 1) Debounce / synchronize break-beam signal into clk domain
    // ------------------------------------------------------------
    wire break_clean;

    breakbeam_sync_debounce deb (
        .clk      (clk),
        .din_raw  (break_din),
        .din_clean(break_clean)
    );

    // ------------------------------------------------------------
    // 2) Generate angular position theta (0..63) from break-beam
    // ------------------------------------------------------------
    wire [5:0] theta;   // 6-bit angle index (64 steps per revolution)

    theta_from_breakbeam #(
        .THETA_BITS (6),
        .PERIOD_BITS(24)   // increase to 26/28 if you want slower RPM support
    ) angle_gen (
        .clk        (clk),
        .reset      (1'b0),        // tie to a real reset if you have one
        .break_clean(break_clean),
        .theta      (theta)
    );

    // ------------------------------------------------------------
    // 3) Use theta + next_px_num to address the texture ROM
    // ------------------------------------------------------------
    wire [5:0] next_px_num;  // from neopixel_controller: which LED index

    // Scale theta (0..63) → column (0..255)
    wire [13:0] theta_scaled = theta * TEX_WIDTH;  // 6+8 bits = 14 bits
    wire [$clog2(TEX_WIDTH)-1:0] col;
    assign col = theta_scaled >> 6;  // divide by 64

    // ROM interface
    wire [23:0] pixel_color;
    wire [$clog2(TEX_WIDTH*LED_COUNT)-1:0] rom_addr;
    assign rom_addr = next_px_num * TEX_WIDTH + col;

    ROM #(
        .DATA_WIDTH   (24),
        .ADDRESS_WIDTH($clog2(TEX_WIDTH*LED_COUNT)),
        .DEPTH        (TEX_WIDTH*LED_COUNT),
        .MEMFILE      ("texture.mem")
    ) rom (
        .clk    (clk),
        .addr   (rom_addr),
        .dataOut(pixel_color)
    );

    // ------------------------------------------------------------
    // 4) Neopixel controller (VHDL entity)
    //    No changes needed here, just feed it pixel_color
    // ------------------------------------------------------------
    neopixel_controller #(
        .px_count_width (6),
        .px_num         (LED_COUNT),
        .bits_per_pixel (24)
    ) strip (
        .clk        (clk),
        .rst        (1'b0),
        .start      (1'b1),
        .pixel      (pixel_color),
        .next_px_num(next_px_num),
        .signal_out (ws2812_dout)
    );

    // IMPORTANT: the old fixed timer-based theta increment has been removed.

endmodule