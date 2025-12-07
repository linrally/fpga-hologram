// theta_from_breakbeam.v
// Compute an angular index theta (0..2^THETA_BITS-1) from break-beam pulses.

module theta_from_breakbeam #(
    parameter integer THETA_BITS  = 6,   // number of bits for theta (64 steps)
    parameter integer PERIOD_BITS = 24   // bits for period counter (clocks/rev)
)(
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    break_clean,   // debounced beam signal
    output reg  [THETA_BITS-1:0]   theta = {THETA_BITS{1'b0}}
);
    localparam integer THETA_STEPS = (1 << THETA_BITS);

    // Count clocks between beam pulses (one revolution period)
    reg [PERIOD_BITS-1:0] period_counter  = {PERIOD_BITS{1'b0}};
    reg [PERIOD_BITS-1:0] period_avg      = {PERIOD_BITS{1'b0}};  // smoothed period

    // Derived: clocks per theta step
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

            // increment period counter always (time since last edge)
            period_counter <= period_counter + 1'b1;

            // Detect rising edge of beam → completed one revolution
            if (break_clean && !prev_beam) begin
                // Reset angle at the beam position
                theta <= {THETA_BITS{1'b0}};

                // Initialize or update exponential moving average
                if (period_avg == {PERIOD_BITS{1'b0}}) begin
                    // first revolution: just seed the average
                    period_avg <= period_counter;
                end else begin
                    // EMA: avg = (7/8)*avg + (1/8)*new
                    period_avg <= (period_avg - (period_avg >> 3))
                                  + (period_counter >> 3);
                end

                // Derive clocks_per_step from the (previous) avg.
                // One-rev lag is fine; it smooths speed changes.
                clocks_per_step <= period_avg >> THETA_BITS;

                // Reset counters for next revolution
                period_counter <= {PERIOD_BITS{1'b0}};
                step_counter   <= {PERIOD_BITS{1'b0}};
            end else begin
                // Between pulses, walk theta according to clocks_per_step
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