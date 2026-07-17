-- =============================================================================
-- Module   : PWM Generator (8-bit resolution)
-- Use case : Status LED brightness / Fan speed control
-- Freq     : ~390 Hz PWM @ 100 MHz, 8-bit resolution
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pwm_gen is
    generic (
        CLK_FREQ  : integer := 100_000_000;
        PWM_FREQ  : integer := 1_000;        -- 1 kHz
        RESOLUTION: integer := 8             -- bits
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        duty      : in  std_logic_vector(RESOLUTION-1 downto 0);  -- 0=off, 255=full
        pwm_out   : out std_logic
    );
end pwm_gen;

architecture Behavioral of pwm_gen is

    constant PERIOD : integer := CLK_FREQ / PWM_FREQ;  -- Clock cycles per PWM period
    constant MAX_DUTY: integer := 2**RESOLUTION - 1;

    signal counter    : integer range 0 to PERIOD - 1 := 0;
    signal duty_level : integer range 0 to PERIOD - 1 := 0;

begin

    -- Convert duty cycle (0-255) to clock cycles
    duty_level <= (to_integer(unsigned(duty)) * PERIOD) / MAX_DUTY;

    -- PWM counter and output
    pwm_proc : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                counter <= 0;
                pwm_out <= '0';
            else
                if counter >= PERIOD - 1 then
                    counter <= 0;
                else
                    counter <= counter + 1;
                end if;

                -- High when counter < duty_level
                if counter < duty_level then
                    pwm_out <= '1';
                else
                    pwm_out <= '0';
                end if;
            end if;
        end if;
    end process;

end Behavioral;
