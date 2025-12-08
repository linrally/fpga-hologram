module angle_mapper #(
    parameter integer THETA_BITS  = 6,   // number of bits for theta (64 steps)
    parameter integer PERIOD_BITS = 28   // bits for period counter (clocks/rev)
)(
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    break_clean,   // debounced beam signal
    output reg  [THETA_BITS-1:0]   theta = {THETA_BITS{1'b0}}
);
    localparam integer THETA_STEPS = (1 << THETA_BITS);

    reg [PERIOD_BITS-1:0] period_counter  = {PERIOD_BITS{1'b0}};
    reg [PERIOD_BITS-1:0] period_avg      = {PERIOD_BITS{1'b0}};

    reg [PERIOD_BITS-1:0] clocks_per_step = {PERIOD_BITS{1'b0}};
    reg [PERIOD_BITS-1:0] step_counter    = {PERIOD_BITS{1'b0}};

    reg prev_beam = 1'b0;

    always @(posedge clk) begin
        if (reset) begin
            theta           <= {THETA_BITS{1'b0}};
            period_counter  <= {PERIOD_BITS{1'b0}};
            period_avg      <= {PERIOD_BITS{1'b0}};
            clocks_per_step <= {PERIOD_BITS{1'b0}};
            step_counter    <= {PERIOD_BITS{1'b0}};
            prev_beam       <= 1'b0;
        end else begin
            prev_beam <= break_clean;

            if (period_counter != {PERIOD_BITS{1'b1}})
                period_counter <= period_counter + 1'b1;

            if (break_clean && !prev_beam) begin
                theta <= {THETA_BITS{1'b0}};

                // we use exponential moving average to update the period
                // takes some time to stabilize
                if (period_avg == {PERIOD_BITS{1'b0}}) begin
                    period_avg <= period_counter;
                end else begin
                    // EMA: avg = (7/8)*avg + (1/8)*new
                    period_avg <= (period_avg - (period_avg >> 3))
                                  + (period_counter >> 3);
                end

                clocks_per_step <= period_avg >> THETA_BITS;

                period_counter <= {PERIOD_BITS{1'b0}};
                step_counter   <= {PERIOD_BITS{1'b0}};
            end else begin // between pulses, walk theta according to clocks_per_step
                if (clocks_per_step != {PERIOD_BITS{1'b0}}) begin
                    step_counter <= step_counter + 1'b1;
                    if (step_counter >= clocks_per_step) begin
                        step_counter <= {PERIOD_BITS{1'b0}};
                        theta <= theta + 1'b1;  // wraps naturally
                    end
                end
            end
        end
    end

endmodule