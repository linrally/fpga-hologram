// pov_peripheral.v
// Memory-mapped POV display peripheral for CPU-driven rendering
//
// Memory Map (all addresses are 32-bit aligned):
//   0xFFFF0000 - POV_COL_ADDR   (write): Column index to update [0-255]
//   0xFFFF0004 - POV_PIXEL_DATA (write): 24-bit RGB pixel data (bits [23:0])
//   0xFFFF0008 - POV_WRITE      (write): Write trigger (any write latches POV_PIXEL_DATA into framebuffer at POV_COL_ADDR)
//   0xFFFF000C - POV_STATUS     (read):  Current column index (bits [7:0])
//   0xFFFF0010 - POV_CTRL       (read/write): Control register (reserved for future use)
//
// Interface:
//   - CPU writes to POV_COL_ADDR, then POV_PIXEL_DATA, then POV_WRITE to update a column
//   - The peripheral tracks the current angular position (theta) and outputs the
//     framebuffer entry for the current column to the LED path
//   - The framebuffer has 256 columns (one per angular position)

module pov_peripheral(
    input  wire        clk,
    input  wire        reset,
    
    // CPU memory-mapped interface
    input  wire [31:0] cpu_addr,      // CPU address bus
    input  wire [31:0] cpu_data_in,   // CPU write data
    input  wire        cpu_wren,      // CPU write enable
    input  wire        cpu_rden,      // CPU read enable (from lw instruction)
    output reg  [31:0] cpu_data_out,  // CPU read data
    
    // Angular position input (from theta_from_breakbeam)
    input  wire [5:0]  theta,         // 6-bit theta (0-63)
    
    // POV output
    output reg  [23:0] pixel_color    // Current column's RGB color
);

    // Memory-mapped register addresses (relative to base 0xFFFF0000)
    localparam POV_COL_ADDR   = 32'hFFFF0000;
    localparam POV_PIXEL_DATA = 32'hFFFF0004;
    localparam POV_WRITE      = 32'hFFFF0008;
    localparam POV_STATUS     = 32'hFFFF000C;
    localparam POV_CTRL       = 32'hFFFF0010;
    
    localparam N_COLS = 256;  // Number of angular columns
    
    // Internal registers
    reg [7:0]  col_addr_reg;      // Column address register
    reg [23:0] pixel_data_reg;    // Pixel data register
    reg [7:0]  ctrl_reg;           // Control register (reserved)
    
    // Framebuffer: 256 columns, 24 bits per column
    reg [23:0] framebuffer [0:N_COLS-1];
    
    // Convert theta (0-63) to column index (0-255)
    // theta is 6 bits, column is 8 bits
    // Scale: col = (theta * 256) / 64 = theta * 4
    wire [7:0] current_col;
    assign current_col = {theta, 2'b00};  // theta << 2
    
    // Initialize framebuffer to black
    integer i;
    initial begin
        for (i = 0; i < N_COLS; i = i + 1) begin
            framebuffer[i] = 24'h000000;
        end
        col_addr_reg = 8'h00;
        pixel_data_reg = 24'h000000;
        ctrl_reg = 8'h00;
        cpu_data_out = 32'h00000000;
        pixel_color = 24'h000000;
    end
    
    // CPU write interface
    always @(posedge clk) begin
        if (reset) begin
            col_addr_reg <= 8'h00;
            pixel_data_reg <= 24'h000000;
            ctrl_reg <= 8'h00;
        end else if (cpu_wren) begin
            case (cpu_addr)
                POV_COL_ADDR: begin
                    col_addr_reg <= cpu_data_in[7:0];
                end
                POV_PIXEL_DATA: begin
                    pixel_data_reg <= cpu_data_in[23:0];
                end
                POV_WRITE: begin
                    // Write trigger: latch pixel_data_reg into framebuffer at col_addr_reg
                    if (col_addr_reg < N_COLS) begin
                        framebuffer[col_addr_reg] <= pixel_data_reg;
                    end
                end
                POV_CTRL: begin
                    ctrl_reg <= cpu_data_in[7:0];
                end
            endcase
        end
    end
    
    // CPU read interface
    always @(posedge clk) begin
        if (reset) begin
            cpu_data_out <= 32'h00000000;
        end else if (cpu_rden) begin
            case (cpu_addr)
                POV_STATUS: begin
                    cpu_data_out <= {24'h000000, current_col};
                end
                POV_CTRL: begin
                    cpu_data_out <= {24'h000000, ctrl_reg};
                end
                default: begin
                    cpu_data_out <= 32'h00000000;
                end
            endcase
        end
    end
    
    // Output current column's color (combinational read from framebuffer)
    always @(posedge clk) begin
        if (reset) begin
            pixel_color <= 24'h000000;
        end else begin
            pixel_color <= framebuffer[current_col];
        end
    end

endmodule

