----------------------------------------------------------------------------------------
--  Rainbow Cycle Generator
--  Generates a cycling rainbow pattern for WS2812B LEDs
--  Uses a standard color wheel algorithm (0-255 range)
----------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity rainbow_generator is
    Generic(
        px_num : integer := 48;              -- Number of LEDs
        px_count_width : integer := 6);      -- Width of pixel count
    Port (
        clk : in STD_LOGIC;                  -- 100 MHz clock
        reset : in STD_LOGIC;                -- Reset signal
        next_px_num : in unsigned(px_count_width-1 downto 0);  -- Current pixel index (0 to px_num-1)
        pixel_bits : out STD_LOGIC_VECTOR(23 downto 0));       -- GRB output for WS2812B
end rainbow_generator;

architecture Behavioral of rainbow_generator is
    -- Phase counter: increments when frame completes (next_px_num wraps)
    signal phase : unsigned(7 downto 0) := (others => '0');
    signal prev_px_num : unsigned(px_count_width-1 downto 0) := (others => '0');
    signal frame_complete : STD_LOGIC := '0';
    
    -- Color wheel value for current LED
    signal color_wheel_value : unsigned(7 downto 0);
    
    -- RGB components (0-255 each)
    signal red_component : unsigned(7 downto 0);
    signal green_component : unsigned(7 downto 0);
    signal blue_component : unsigned(7 downto 0);
    
begin
    -- Detect frame completion: when next_px_num wraps from (px_num-1) to 0
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                prev_px_num <= (others => '0');
                frame_complete <= '0';
            else
                prev_px_num <= next_px_num;
                -- Frame complete when we go from last pixel to first pixel
                if (prev_px_num = to_unsigned(px_num - 1, px_count_width)) and 
                   (next_px_num = to_unsigned(0, px_count_width)) then
                    frame_complete <= '1';
                else
                    frame_complete <= '0';
                end if;
            end if;
        end if;
    end process;
    
    -- Phase counter: increment on frame completion
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                phase <= (others => '0');
            elsif frame_complete = '1' then
                phase <= phase + 1;  -- Wrap automatically (8-bit)
            end if;
        end if;
    end process;
    
    -- Calculate color wheel value: (LED_index + phase) mod 256
    color_wheel_value <= (resize(unsigned(next_px_num), 8) + phase);
    
    -- Color wheel algorithm:
    -- 0-84:   Red → Yellow → Green   (Red: 255→0, Green: 0→255, Blue: 0)
    -- 85-169: Green → Cyan → Blue     (Red: 0, Green: 255→0, Blue: 0→255)
    -- 170-255: Blue → Magenta → Red   (Red: 0→255, Green: 0, Blue: 255→0)
    -- Using integer math: v*3 approximates v*255/85 for segments
    process(color_wheel_value)
        variable v : unsigned(7 downto 0);
        variable segment : unsigned(7 downto 0);
        variable temp : unsigned(15 downto 0);  -- For intermediate calculations
    begin
        v := color_wheel_value;
        
        if v < 85 then
            -- Segment 0-84: Red → Yellow → Green
            -- Red: 255 down to 0 (at v=0: 255, at v=84: 0)
            -- Green: 0 up to 255 (at v=0: 0, at v=84: 255)
            -- Blue: 0
            -- Formula: Red = 255 - (v * 3), Green = v * 3
            -- Max v=84: v*3=252, so both values stay in 0-255 range
            temp := v * 3;
            green_component <= temp(7 downto 0);  -- v*3, max 252
            temp := 255 - (v * 3);
            red_component <= temp(7 downto 0);    -- 255 - v*3, min 3
            blue_component <= to_unsigned(0, 8);
            
        elsif v < 170 then
            -- Segment 85-169: Green → Cyan → Blue
            -- Red: 0
            -- Green: 255 down to 0 (at v=85: 255, at v=169: 0)
            -- Blue: 0 up to 255 (at v=85: 0, at v=169: 255)
            segment := v - 85;  -- 0 to 84
            temp := segment * 3;
            blue_component <= temp(7 downto 0);   -- segment*3, max 252
            temp := 255 - (segment * 3);
            green_component <= temp(7 downto 0);  -- 255 - segment*3, min 3
            red_component <= to_unsigned(0, 8);
            
        else
            -- Segment 170-255: Blue → Magenta → Red
            -- Red: 0 up to 255 (at v=170: 0, at v=255: 255)
            -- Green: 0
            -- Blue: 255 down to 0 (at v=170: 255, at v=255: 0)
            segment := v - 170;  -- 0 to 85
            temp := segment * 3;
            red_component <= temp(7 downto 0);    -- segment*3, max 255 (when segment=85)
            temp := 255 - (segment * 3);
            blue_component <= temp(7 downto 0);  -- 255 - segment*3, min 0
            green_component <= to_unsigned(0, 8);
        end if;
    end process;
    
    -- Output format for WS2812B: GRB (Green, Red, Blue)
    -- pixel_bits(0 to 7) = Green
    -- pixel_bits(8 to 15) = Red
    -- pixel_bits(16 to 23) = Blue
    pixel_bits(0 to 7) <= std_logic_vector(green_component);
    pixel_bits(8 to 15) <= std_logic_vector(red_component);
    pixel_bits(16 to 23) <= std_logic_vector(blue_component);
    
end Behavioral;

