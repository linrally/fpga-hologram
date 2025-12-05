module ws2812_driver #(
    parameter LED_COUNT = 8
)(
	input clk, 			// 50 MHz
	input start,
	input reset,
	input [LED_COUNT*24-1:0] data,
	output reg dout,
	output reg busy
);

	localparam T0H = 17;  
	localparam T1H = 35;
	localparam TOTAL = 63;

	localparam IDLE = 0;
	localparam SEND = 1;
	localparam TRESET = 2;

	reg [5:0] bit_idx = 0;
	reg [15:0] led_idx = 0;
	reg [23:0] shift_reg = 24'd0;
	reg [11:0]  timer = 0;

	reg [2:0] cur_state  = IDLE;
	reg [2:0] next_state = IDLE;

	// State register with synchronous reset
	always @ (posedge clk) begin
		if (reset) begin
			cur_state  <= IDLE;
			next_state <= IDLE;
		end else begin
			cur_state <= next_state;
		end
	end

	always @(posedge clk) begin
		case (cur_state)
			IDLE: begin
				dout <= 0;
				busy <= 0;
				if (start) begin
						busy <= 1;
						led_idx <= 0;
						bit_idx <= 23;              
						shift_reg <= data[0 +: 24];   
						next_state <= SEND;
						timer <= 0;
				end
			end

			SEND: begin
				busy <= 1;
				if (shift_reg[23] == 1'b1) begin
					dout <= (timer < T1H);
				end else begin
					dout <= (timer < T0H);
				end

				timer <= timer + 1;

				if (timer == TOTAL) begin
					timer <= 0;
					shift_reg <= {shift_reg[22:0], 1'b0}; // shift left
					
					if (bit_idx == 0) begin
						// next LED
						bit_idx <= 23;
						led_idx <= led_idx + 1;

						if (led_idx == LED_COUNT-1) begin // all LEDs done
							next_state <= TRESET;
							dout  <= 0;
						end else begin
							shift_reg <= data[((led_idx + 1) * 24) +: 24];
						end
					end else begin
						bit_idx <= bit_idx - 1;
					end
				end
			end

			TRESET: begin 
				busy <= 1;
				dout <= 0;

				if (timer >= 5000) begin // 100us reset time; requires >= 50us
						timer <= 0;
						busy  <= 0;
						next_state <= IDLE;
				end

				timer <= timer + 1;
			end

		endcase
	end
endmodule;
