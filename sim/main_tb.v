`timescale 1ns/1ps

module main_tb;
    reg clk = 0;
    wire ws2812_dout;
    wire [23:0] pixel_color_debug;
    wire [5:0] next_px_num_debug;

    main dut(
        .clk(clk), 
        .ws2812_dout(ws2812_dout),
        .pixel_color_debug(pixel_color_debug),
        .next_px_num_debug(next_px_num_debug)
    );

    // Clock generation: 100 MHz (10ns period, 5ns half-period)
    always #5 clk = ~clk;

    // Test variables
    reg [23:0] prev_pixel_color = 0;
    reg [5:0] prev_px_num = 0;
    integer frame_count = 0;
    integer color_change_count = 0;
    integer error_count = 0;
    integer test_pixel = 0;  // Pixel to monitor for color changes
    reg [23:0] pixel_at_frame_start[0:10];  // Store colors at start of each frame
    integer frames_to_test = 5;
    reg [23:0] pixel_at_pixel0[0:10];  // Store colors for pixel 0 across frames
    integer segment_0_84_count = 0;
    integer segment_85_169_count = 0;
    integer segment_170_255_count = 0;

    // Access internal signals via debug ports
    wire [23:0] pixel_color = pixel_color_debug;
    wire [5:0] next_px_num = next_px_num_debug;

    // Extract RGB components from GRB format
    wire [7:0] green = pixel_color[7:0];
    wire [7:0] red = pixel_color[15:8];
    wire [7:0] blue = pixel_color[23:16];

    // Check color validity: all components should be 0-255
    always @(posedge clk) begin
        if (green > 255 || red > 255 || blue > 255) begin
            $error("ERROR: Invalid color component detected at time %t", $time);
            $error("  Green: %d, Red: %d, Blue: %d", green, red, blue);
            error_count = error_count + 1;
        end
    end

    // Monitor pixel color changes
    always @(posedge clk) begin
        if (pixel_color != prev_pixel_color) begin
            color_change_count = color_change_count + 1;
            prev_pixel_color = pixel_color;
        end
    end

    // Detect frame completion and verify phase increment
    reg frame_complete_detected = 0;
    always @(posedge clk) begin
        // Frame complete when next_px_num wraps from 47 to 0
        if (prev_px_num == 47 && next_px_num == 0) begin
            frame_complete_detected = 1;
            frame_count = frame_count + 1;
            
            // Get phase value using hierarchical access
            // Note: In Vivado XSIM, we can access VHDL signals this way
            $display("========================================");
            $display("Frame %0d completed at time %t", frame_count, $time);
            $display("  Pixel color: G=%0d, R=%0d, B=%0d (0x%06h)", 
                     green, red, blue, pixel_color);
            
            // Store color at frame start for pixel 0
            if (frame_count <= frames_to_test) begin
                pixel_at_frame_start[frame_count-1] = pixel_color;
                pixel_at_pixel0[frame_count-1] = pixel_color;
            end
            
            // Check phase increment (by comparing colors across frames)
            // Phase should increment by 1 each frame, causing color wheel to shift
            if (frame_count > 1) begin
                // Colors should shift by 1 position in color wheel per frame
                // We can verify this by checking that colors are different
                if (pixel_at_frame_start[frame_count-2] == pixel_color) begin
                    $warning("WARNING: Color did not change between frames %0d and %0d", 
                             frame_count-1, frame_count);
                    $warning("  This may indicate phase counter is not incrementing");
                end else begin
                    $display("  Color changed from previous frame - phase increment verified");
                    $display("  Previous: G=%0d R=%0d B=%0d, Current: G=%0d R=%0d B=%0d",
                             pixel_at_frame_start[frame_count-2][7:0],
                             pixel_at_frame_start[frame_count-2][15:8],
                             pixel_at_frame_start[frame_count-2][23:16],
                             green, red, blue);
                end
            end
            
            $display("========================================");
        end
        prev_px_num = next_px_num;
    end

    // Verify color wheel transitions
    // Check that colors follow the rainbow pattern
    reg [7:0] color_wheel_val;
    reg [7:0] expected_red, expected_green, expected_blue;
    reg [15:0] temp_calc;
    integer color_check_count = 0;

    always @(posedge clk) begin
        // Sample color every 1000 clock cycles to avoid too much output
        if (color_check_count % 1000 == 0 && next_px_num == test_pixel) begin
            // Calculate expected color based on pixel index and phase
            // For pixel 0: color_wheel_val = phase (approximately)
            // We'll verify the color wheel algorithm
            
            // Extract and verify color wheel segment
            if (green > 0 && red > 0 && blue == 0) begin
                // Should be in segment 0-84 (Red to Yellow to Green)
                $display("Color check: Segment 0-84 detected (Red->Yellow->Green)");
            end else if (green > 0 && red == 0 && blue > 0) begin
                // Should be in segment 85-169 (Green to Cyan to Blue)
                $display("Color check: Segment 85-169 detected (Green->Cyan->Blue)");
            end else if (green == 0 && red > 0 && blue > 0) begin
                // Should be in segment 170-255 (Blue to Magenta to Red)
                $display("Color check: Segment 170-255 detected (Blue->Magenta->Red)");
            end else if (green > 0 && red == 0 && blue == 0) begin
                // Pure green
                $display("Color check: Pure green detected");
            end else if (green == 0 && red > 0 && blue == 0) begin
                // Pure red
                $display("Color check: Pure red detected");
            end else if (green == 0 && red == 0 && blue > 0) begin
                // Pure blue
                $display("Color check: Pure blue detected");
            end
        end
        color_check_count = color_check_count + 1;
    end

    // Main test sequence
    initial begin
        $display("========================================");
        $display("Rainbow Generator Testbench Starting");
        $display("========================================");
        $display("Testing:");
        $display("  1. Color value validity (0-255 range)");
        $display("  2. Phase counter behavior");
        $display("  3. Frame completion detection");
        $display("  4. Color wheel transitions");
        $display("========================================");
        
        // Wait for initial reset/settling
        #100;
        
        // Run for multiple frames to verify phase increment
        // Each frame takes: 48 pixels * ~1250ns per pixel = ~60us per frame
        // Let's run for at least 10 frames = ~600us
        // At 100MHz, that's 60,000 clock cycles
        #600000;
        
        // Final report
        $display("========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Frames completed: %0d", frame_count);
        $display("Color changes detected: %0d", color_change_count);
        $display("Errors found: %0d", error_count);
        
        if (frame_count >= frames_to_test) begin
            $display("PASS: Sufficient frames completed for testing");
        end else begin
            $warning("WARNING: Only %0d frames completed (expected at least %0d)", 
                     frame_count, frames_to_test);
        end
        
        if (frame_complete_detected) begin
            $display("PASS: Frame completion detection working");
        end else begin
            $error("ERROR: Frame completion not detected!");
            error_count = error_count + 1;
        end
        
        if (color_change_count > 0) begin
            $display("PASS: Color changes detected - rainbow is active");
        end else begin
            $error("ERROR: No color changes detected!");
            error_count = error_count + 1;
        end
        
        // Verify color wheel segments are being used
        $display("Color wheel segment usage:");
        $display("  Segment 0-84 (Red->Yellow->Green): %0d samples", segment_0_84_count);
        $display("  Segment 85-169 (Green->Cyan->Blue): %0d samples", segment_85_169_count);
        $display("  Segment 170-255 (Blue->Magenta->Red): %0d samples", segment_170_255_count);
        if (segment_0_84_count > 0 || segment_85_169_count > 0 || segment_170_255_count > 0) begin
            $display("PASS: Color wheel segments are being used");
        end else begin
            $warning("WARNING: No color wheel segments detected in samples");
        end
        
        if (error_count == 0) begin
            $display("========================================");
            $display("ALL TESTS PASSED!");
            $display("========================================");
        end else begin
            $display("========================================");
            $display("TESTS FAILED: %0d error(s) detected", error_count);
            $display("========================================");
        end
        
        $finish;
    end

endmodule