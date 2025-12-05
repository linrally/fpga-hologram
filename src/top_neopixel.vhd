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
    
    -- Edge detection for start button (single pulse)
    signal start_sync_prev : STD_LOGIC := '0';
    signal start_pulse     : STD_LOGIC := '0';

begin

    --------------------------------------------------------------------
    -- Simple 2-FF sync for reset button (active high)
    --------------------------------------------------------------------
    process(clk_100mhz)
    begin
        if rising_edge(clk_100mhz) then
            btn_reset_ff1 <= btn_reset;
            btn_reset_ff2 <= btn_reset_ff1;
        end if;
    end process;
    rst_sync <= btn_reset_ff2;

    --------------------------------------------------------------------
    -- Simple 2-FF sync for start button with edge detection
    -- Generates a single pulse when button is pressed
    --------------------------------------------------------------------
    process(clk_100mhz)
    begin
        if rising_edge(clk_100mhz) then
            btn_start_ff1 <= btn_start;
            btn_start_ff2 <= btn_start_ff1;
            start_sync_prev <= btn_start_ff2;
        end if;
    end process;
    
    -- Generate pulse on rising edge
    start_pulse <= btn_start_ff2 and not start_sync_prev;
    start_sync <= start_pulse;

    --------------------------------------------------------------------
    -- Generate color per LED index
    -- next_px_idx tells us which LED the controller is currently asking for.
    -- Simple test pattern: first 16 red, next 16 green, last 16 blue.
    --------------------------------------------------------------------
    process(next_px_idx)
        variable idx : integer;
    begin
        idx := to_integer(next_px_idx);
        if idx < 16 then                -- first third: RED
            R <= (others => '1');       -- 255
            G <= (others => '0');
            B <= (others => '0');
        elsif idx < 32 then             -- second third: GREEN
            R <= (others => '0');
            G <= (others => '1');       -- 255
            B <= (others => '0');
        else                            -- last third: BLUE
            R <= (others => '0');
            G <= (others => '0');
            B <= (others => '1');       -- 255
        end if;
        
        -- WS2812B expects order G, R, B, MSB first.
        pixel_bits(0  to 7)  <= G;      -- G7..G0
        pixel_bits(8  to 15) <= R;      -- R7..R0
        pixel_bits(16 to 23) <= B;      -- B7..B0
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
            signal_out  => led_data
        );

end Behavioral;

