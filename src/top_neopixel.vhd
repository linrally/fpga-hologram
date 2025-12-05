library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_neopixel is
    Port (
        clk_100mhz : in  STD_LOGIC;   -- 100 MHz system clock (Nexys A7)
        btn_start  : in  STD_LOGIC;   -- pushbutton to start a frame
        btn_reset  : in  STD_LOGIC;   -- pushbutton reset (active high)
        led_data   : out STD_LOGIC    -- goes to DIN of WS2812B strip (through level shifter)
    );
end top_neopixel;

architecture Behavioral of top_neopixel is

    --------------------------------------------------------------------
    -- Component declaration from blaz-r/fpga-neopixel
    --------------------------------------------------------------------
    component neopixel_controller is
        generic(
            px_count_width : integer := 6;   -- log2(num_leds)
            px_num         : integer := 60;  -- num of LEDs
            bits_per_pixel : integer := 24;  -- 24 bits: G,R,B for WS2812B
            one_high_time  : integer := 80;  -- 0.8us high for '1' @ 100 MHz
            zero_high_time : integer := 40   -- 0.4us high for '0' @ 100 MHz
        );
        port(
            clk        : in  STD_LOGIC;
            rst        : in  STD_LOGIC;
            start      : in  STD_LOGIC;
            pixel      : in  STD_LOGIC_VECTOR (0 to bits_per_pixel-1);
            next_px_num: out UNSIGNED(px_count_width-1 downto 0);
            signal_out : out STD_LOGIC
        );
    end component;

    --------------------------------------------------------------------
    -- Signals
    --------------------------------------------------------------------
    signal rst_sync      : STD_LOGIC;
    signal start_sync    : STD_LOGIC;
    signal pixel_bits    : STD_LOGIC_VECTOR(0 to 23);      -- G[7:0], R[7:0], B[7:0]
    signal next_px_idx   : UNSIGNED(5 downto 0);           -- enough for 0..47 (2^6 = 64)
    signal G, R, B       : STD_LOGIC_VECTOR(7 downto 0);
    
    -- Simple 2-FF synchronizers for buttons
    signal btn_reset_ff1, btn_reset_ff2 : STD_LOGIC := '0';
    signal btn_start_ff1, btn_start_ff2 : STD_LOGIC := '0';
    
    -- Edge detection for start button
    signal start_sync_prev : STD_LOGIC := '0';
    
    -- Test signal for oscilloscope verification
    signal test_counter : unsigned(26 downto 0) := (others => '0');
    signal test_output  : STD_LOGIC := '0';
    signal neopixel_out : STD_LOGIC;  -- Internal signal for neopixel output

begin

    --------------------------------------------------------------------
    -- Simple 2-FF sync for reset button
    -- Nexys A7 buttons are active LOW (pressed = 0), so we invert
    --------------------------------------------------------------------
    process(clk_100mhz)
    begin
        if rising_edge(clk_100mhz) then
            btn_reset_ff1 <= btn_reset;
            btn_reset_ff2 <= btn_reset_ff1;
        end if;
    end process;
    rst_sync <= not btn_reset_ff2;  -- Invert: button pressed (0) = reset active (1)

    --------------------------------------------------------------------
    -- Simple 2-FF sync for start button with edge detection
    -- Nexys A7 buttons are active LOW (pressed = 0)
    -- Detect falling edge (button press) and generate pulse
    --------------------------------------------------------------------
    process(clk_100mhz)
    begin
        if rising_edge(clk_100mhz) then
            btn_start_ff1 <= btn_start;
            btn_start_ff2 <= btn_start_ff1;
            start_sync_prev <= btn_start_ff2;
        end if;
    end process;
    
    -- Hold start signal while button is pressed (inverted: button LOW = start HIGH)
    -- Nexys A7 buttons are active LOW, so invert to get active HIGH start signal
    start_sync <= not btn_start_ff2;

    --------------------------------------------------------------------
    -- Generate color per LED index
    -- Pattern: First 16 LEDs = RED, Next 16 LEDs = GREEN, Last 16 LEDs = BLUE
    -- Total: 48 LEDs (16 + 16 + 16)
    -- LED indices: 0-15 = RED, 16-31 = GREEN, 32-47 = BLUE
    --------------------------------------------------------------------
    process(next_px_idx)
        variable idx : integer;
    begin
        idx := to_integer(next_px_idx);
        
        -- First 16 LEDs (0-15): RED
        if idx < 16 then
            R <= (others => '1');       -- Red = 255 (full brightness)
            G <= (others => '0');       -- Green = 0
            B <= (others => '0');       -- Blue = 0
        -- Next 16 LEDs (16-31): GREEN
        elsif idx < 32 then
            R <= (others => '0');       -- Red = 0
            G <= (others => '1');       -- Green = 255 (full brightness)
            B <= (others => '0');       -- Blue = 0
        -- Last 16 LEDs (32-47): BLUE
        else
            R <= (others => '0');       -- Red = 0
            G <= (others => '0');       -- Green = 0
            B <= (others => '1');       -- Blue = 255 (full brightness)
        end if;
        
        -- WS2812B data format: G[7:0], R[7:0], B[7:0] (MSB first for each byte)
        pixel_bits(0  to 7)  <= G;      -- Bits 0-7:   Green (G7..G0)
        pixel_bits(8  to 15) <= R;      -- Bits 8-15:  Red (R7..R0)
        pixel_bits(16 to 23) <= B;      -- Bits 16-23: Blue (B7..B0)
    end process;

    --------------------------------------------------------------------
    -- Test Signal Generator: Simple 1 Hz square wave for oscilloscope
    -- This generates a slow square wave that's easy to see on a scope
    -- Toggles between 0V and 3.3V every 0.5 seconds
    --------------------------------------------------------------------
    process(clk_100mhz)
    begin
        if rising_edge(clk_100mhz) then
            if rst_sync = '1' then
                test_counter <= (others => '0');
                test_output <= '0';
            else
                test_counter <= test_counter + 1;
                if test_counter = 50000000 then  -- 50M cycles = 0.5s @ 100MHz
                    test_output <= not test_output;
                    test_counter <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Instantiate neopixel_controller
    -- Configured for 48 WS2812B LEDs @ 100 MHz
    --------------------------------------------------------------------
    neopixel_inst : neopixel_controller
        generic map(
            px_count_width => 6,        -- log2(48) = 6 (2^6 = 64 > 48)
            px_num         => 48,       -- your strip length
            bits_per_pixel => 24,      -- WS2812B uses 24-bit RGB
            one_high_time  => 80,      -- 0.8us @ 100 MHz = 80 cycles
            zero_high_time => 40       -- 0.4us @ 100 MHz = 40 cycles
        )
        port map(
            clk         => clk_100mhz,
            rst         => rst_sync,
            start       => start_sync,  -- pulse to start frame transmission
            pixel       => pixel_bits,
            next_px_num => next_px_idx,
            signal_out  => neopixel_out
        );

    --------------------------------------------------------------------
    -- OUTPUT SELECTION: Test mode vs Normal mode
    --------------------------------------------------------------------
    -- led_data <= test_output;  -- TEST MODE: 1 Hz square wave (easy to see on scope)
    led_data <= neopixel_out;  -- NORMAL MODE: Neopixel signal

end Behavioral;

