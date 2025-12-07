// breakbeam_sync_debounce.v
// Synchronize and lightly debounce an IR break-beam signal.

module breakbeam_sync_debounce (
    input  wire clk,
    input  wire din_raw,   // asynchronous sensor input
    output reg  din_clean  // debounced, synchronized version
);
    // 2-FF synchronizer to bring signal into clk domain
    reg sync_0 = 1'b0;
    reg sync_1 = 1'b0;
    always @(posedge clk) begin
        sync_0 <= din_raw;
        sync_1 <= sync_0;
    end

    // Simple debounce: require N consecutive samples before changing state
    localparam integer CNT_WIDTH = 12;  // ~ 2^12 / 100MHz ≈ 41 µs; small but enough
    reg [CNT_WIDTH-1:0] cnt = {CNT_WIDTH{1'b0}};
    reg stable_state = 1'b0;

    always @(posedge clk) begin
        if (sync_1 != stable_state) begin
            // counting how long the signal has been different
            cnt <= cnt + 1;
            if (&cnt) begin
                // counter saturated: accept new state
                stable_state <= sync_1;
                cnt <= {CNT_WIDTH{1'b0}};
            end
        end else begin
            // no difference: reset counter
            cnt <= {CNT_WIDTH{1'b0}};
        end

        din_clean <= stable_state;
    end

endmodule
