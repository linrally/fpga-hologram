module debounce (
    input  wire clk,
    input  wire din_raw,   
    output reg  din_clean  
);
    // synchronizer - prevents metastability by capturing the signal with two flip-flops
    // https://www.chipverify.com/verilog/verilog-debounce-circuit
    // required because the breakbeam signal is asynchronous to the clk domain
    reg sync_0 = 1'b0;
    reg sync_1 = 1'b0;
    always @(posedge clk) begin
        sync_0 <= din_raw;
        sync_1 <= sync_0;
    end

    // debounce counter - counts the number of clk cycles the signal has been stable
    localparam integer CNT_WIDTH = 12;  // ~ 2^12 / 100MHz ≈ 41 µs; small but enough
    reg [CNT_WIDTH-1:0] cnt = {CNT_WIDTH{1'b0}};
    reg stable_state = 1'b0;

    always @(posedge clk) begin
        if (sync_1 != stable_state) begin
            cnt <= cnt + 1;
            if (&cnt) begin
                stable_state <= sync_1;
                cnt <= {CNT_WIDTH{1'b0}};
            end
        end else begin
            cnt <= {CNT_WIDTH{1'b0}};
        end

        din_clean <= stable_state;
    end

endmodule
