library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_neopixel_tb is
end top_neopixel_tb;

architecture Behavioral of top_neopixel_tb is

    component top_neopixel is
        Port (
            clk_100mhz : in  STD_LOGIC;
            btn_start  : in  STD_LOGIC;
            btn_reset  : in  STD_LOGIC;
            led_data   : out STD_LOGIC
        );
    end component;

    -- Test signals
    signal clk_100mhz : STD_LOGIC := '0';
    signal btn_start  : STD_LOGIC := '0';
    signal btn_reset  : STD_LOGIC := '0';
    signal led_data   : STD_LOGIC;

    -- Clock period: 10 ns for 100 MHz
    constant CLK_PERIOD : time := 10 ns;
    -- Simulation duration: 2 seconds to see test signal toggle
    constant SIM_TIME : time := 2 sec;

begin

    -- Unit Under Test
    UUT: top_neopixel
        port map (
            clk_100mhz => clk_100mhz,
            btn_start  => btn_start,
            btn_reset  => btn_reset,
            led_data   => led_data
        );

    -- Clock generation process
    CLK_GEN: process
    begin
        while now < SIM_TIME loop
            clk_100mhz <= '0';
            wait for CLK_PERIOD/2;
            clk_100mhz <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    -- Stimulus process
    -- Note: Nexys A7 buttons are active LOW (pressed = 0, not pressed = 1)
    -- So btn_reset = '0' means reset is active, btn_start = '0' means start is active
    STIM: process
    begin
        -- Initialize: reset active (button pressed = LOW), start inactive (button not pressed = HIGH)
        btn_reset <= '0';  -- Button pressed = reset active
        btn_start <= '1';  -- Button not pressed = start inactive
        
        -- Wait a few clock cycles for initialization
        wait for CLK_PERIOD * 10;
        
        -- Release reset (button not pressed = HIGH)
        btn_reset <= '1';  -- Button not pressed = reset inactive
        wait for CLK_PERIOD * 10;
        
        -- Wait a bit before starting
        wait for 100 ms;
        
        -- Press start button to trigger neopixel frame transmission
        -- Button pressed = LOW, which becomes start = HIGH in the design
        btn_start <= '0';  -- Button pressed = start active
        wait for 10 ms;    -- Hold button for a short time
        btn_start <= '1';  -- Release button = start inactive
        
        -- Wait to observe neopixel signal transmission
        -- Frame transmission takes: 48 LEDs * 24 bits * 1.25us = ~1.44ms
        -- Plus 100us latch time = ~1.54ms total
        wait for 5 ms;
        
        -- Test another frame transmission
        btn_start <= '0';  -- Press start button again
        wait for 10 ms;
        btn_start <= '1';  -- Release
        
        -- Wait to observe
        wait for 5 ms;
        
        -- Test reset button (press reset = button LOW)
        btn_reset <= '0';  -- Button pressed = reset active
        wait for CLK_PERIOD * 100;
        btn_reset <= '1';  -- Release reset
        wait for CLK_PERIOD * 100;
        
        -- Continue observing for remainder of simulation
        wait for 500 ms;
        
        report "Simulation completed successfully";
        wait;
    end process;

    -- Monitor process to check signal transitions
    MONITOR: process
        variable last_value : STD_LOGIC := '0';
        variable toggle_count : integer := 0;
    begin
        wait for CLK_PERIOD * 100;  -- Wait for initial setup
        
        while now < SIM_TIME loop
            wait for CLK_PERIOD;
            if led_data /= last_value then
                toggle_count := toggle_count + 1;
                report "led_data toggled at time " & time'image(now) & 
                       " to value " & std_logic'image(led_data);
                last_value := led_data;
            end if;
        end loop;
        
        report "Total toggles observed: " & integer'image(toggle_count);
        wait;
    end process;

end Behavioral;


