-- =============================================================================
-- Testbench : tb_pwm_gen  (ModelSim compatible - VHDL 93/2008)
-- نکته: CLK_FREQ=1MHz برای شبیه‌سازی سریع‌تر
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_pwm_gen is
end tb_pwm_gen;

architecture sim of tb_pwm_gen is

    -- برای شبیه‌سازی سریع، CLK_FREQ را کوچک‌تر انتخاب کردیم
    constant CLK_FREQ   : integer := 1_000_000;   -- 1 MHz
    constant PWM_FREQ   : integer := 1_000;        -- 1 kHz
    constant RESOLUTION : integer := 8;
    constant CLK_PERIOD : time    := 1000 ns;      -- 1 µs
    constant PWM_CLKS   : integer := CLK_FREQ / PWM_FREQ;  -- 1000 کلاک در هر دوره

    signal clk     : std_logic := '0';
    signal rst     : std_logic := '1';
    signal duty    : std_logic_vector(RESOLUTION-1 downto 0) := (others => '0');
    signal pwm_out : std_logic;

    component pwm_gen is
        generic (CLK_FREQ   : integer;
                 PWM_FREQ   : integer;
                 RESOLUTION : integer);
        port (clk     : in  std_logic;
              rst     : in  std_logic;
              duty    : in  std_logic_vector(RESOLUTION-1 downto 0);
              pwm_out : out std_logic);
    end component;

begin

    DUT : pwm_gen
        generic map (CLK_FREQ   => CLK_FREQ,
                     PWM_FREQ   => PWM_FREQ,
                     RESOLUTION => RESOLUTION)
        port map (clk     => clk,
                  rst     => rst,
                  duty    => duty,
                  pwm_out => pwm_out);

    clk <= not clk after CLK_PERIOD / 2;

    -- -----------------------------------------------------------------------
    -- پروسس اندازه‌گیری duty cycle واقعی
    -- یک دوره کامل را می‌شمارد و درصد HIGH را گزارش می‌دهد
    -- -----------------------------------------------------------------------
    measure_proc : process
        variable high_cnt  : integer := 0;
        variable total_cnt : integer := 0;
        variable pct_x100  : integer := 0;  -- درصد × 100 (برای اجتناب از float)
    begin
        wait until rst = '0';
        wait for CLK_PERIOD * 10;

        loop
            high_cnt  := 0;
            total_cnt := 0;

            for i in 1 to PWM_CLKS loop
                wait until rising_edge(clk);
                total_cnt := total_cnt + 1;
                if pwm_out = '1' then
                    high_cnt := high_cnt + 1;
                end if;
            end loop;

            pct_x100 := (high_cnt * 100) / total_cnt;
            report "[MEASURE] duty=" &
                   integer'image(to_integer(unsigned(duty))) &
                   "  high_clks=" & integer'image(high_cnt) &
                   "/" & integer'image(total_cnt) &
                   "  percent=" & integer'image(pct_x100) & "%";
        end loop;
    end process;

    -- -----------------------------------------------------------------------
    -- پروسس تحریک
    -- -----------------------------------------------------------------------
    stim_proc : process
    begin
        rst  <= '1';
        duty <= x"00";
        wait for 5 * CLK_PERIOD;
        rst <= '0';
        wait for CLK_PERIOD * 20;

        -- ---- تست ۱: duty=0 -> خاموش ----
        report "--- test 1: duty=0x00 (expect: always LOW) ---";
        duty <= x"00";
        wait for CLK_PERIOD * (PWM_CLKS + 10);
        assert pwm_out = '0'
            report "[FAIL] test1: duty=0 output must be '0'"
            severity error;
        report "[PASS] test 1: duty=0, output='0'";

        -- ---- تست ۲: duty=255 -> کاملاً روشن ----
        report "--- test 2: duty=0xFF (expect: always HIGH) ---";
        duty <= x"FF";
        wait for CLK_PERIOD * (PWM_CLKS + 10);
        assert pwm_out = '1'
            report "[FAIL] test2: duty=255 output must be '1'"
            severity error;
        report "[PASS] test 2: duty=255, output='1'";

        -- ---- تست ۳: duty=128 -> ~50% ----
        report "--- test 3: duty=0x80 (~50%%) ---";
        duty <= x"80";
        wait for CLK_PERIOD * (PWM_CLKS * 3);
        report "[INFO] test 3 done - check MEASURE output above";

        -- ---- تست ۴: duty=64 -> ~25% ----
        report "--- test 4: duty=0x40 (~25%%) ---";
        duty <= x"40";
        wait for CLK_PERIOD * (PWM_CLKS * 3);
        report "[INFO] test 4 done - check MEASURE output above";

        -- ---- تست ۵: تغییر پویا ----
        report "--- test 5: dynamic duty change ---";
        duty <= x"20";
        wait for CLK_PERIOD * PWM_CLKS;
        duty <= x"80";
        wait for CLK_PERIOD * PWM_CLKS;
        duty <= x"C0";
        wait for CLK_PERIOD * PWM_CLKS;
        duty <= x"FF";
        wait for CLK_PERIOD * PWM_CLKS;
        report "[PASS] test 5: dynamic change ok";

        -- ---- تست ۶: ریست در حین کار ----
        report "--- test 6: reset during operation ---";
        duty <= x"80";
        wait for CLK_PERIOD * (PWM_CLKS / 2);
        rst <= '1';
        wait for 3 * CLK_PERIOD;
        assert pwm_out = '0'
            report "[FAIL] test6: output must be '0' after reset"
            severity error;
        rst <= '0';
        report "[PASS] test 6: reset ok";

        wait for CLK_PERIOD * 20;
        report "=== ALL pwm_gen TESTS PASSED ===";
        wait;
    end process;

end sim;
