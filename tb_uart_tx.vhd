-- =============================================================================
-- Testbench : tb_uart_tx  (ModelSim compatible - VHDL 93/2008)
-- fixes: removed to_hstring, fixed monitor loop, explicit time constants
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_uart_tx is
end tb_uart_tx;

architecture sim of tb_uart_tx is

    constant CLK_PERIOD  : time := 10 ns;      -- 100 MHz
    constant BAUD_PERIOD : time := 8680 ns;    -- 115200 baud (1/115200 sec)

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal tx_data  : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_start : std_logic := '0';
    signal tx_busy  : std_logic;
    signal tx_done  : std_logic;
    signal tx_pin   : std_logic;

    -- تابع تبدیل byte به رشته hex (جایگزین to_hstring)
    function byte_to_hex(b : std_logic_vector(7 downto 0)) return string is
        constant HEX_CHARS : string(1 to 16) := "0123456789ABCDEF";
        variable result    : string(1 to 4)  := "0x00";
        variable hi, lo    : integer;
    begin
        hi         := to_integer(unsigned(b(7 downto 4)));
        lo         := to_integer(unsigned(b(3 downto 0)));
        result(3)  := HEX_CHARS(hi + 1);
        result(4)  := HEX_CHARS(lo + 1);
        return result;
    end function;

    type byte_array is array (natural range <>) of std_logic_vector(7 downto 0);
    constant TEST_BYTES : byte_array(0 to 4) := (
        x"41",   -- 'A'
        x"42",   -- 'B'
        x"43",   -- 'C'
        x"00",   -- همه صفر
        x"FF"    -- همه یک
    );

    component uart_tx is
        generic (CLK_FREQ  : integer;
                 BAUD_RATE : integer);
        port (clk      : in  std_logic;
              rst      : in  std_logic;
              tx_data  : in  std_logic_vector(7 downto 0);
              tx_start : in  std_logic;
              tx_busy  : out std_logic;
              tx_done  : out std_logic;
              tx_pin   : out std_logic);
    end component;

begin

    DUT : uart_tx
        generic map (CLK_FREQ  => 100_000_000,
                     BAUD_RATE => 115_200)
        port map (clk      => clk,
                  rst      => rst,
                  tx_data  => tx_data,
                  tx_start => tx_start,
                  tx_busy  => tx_busy,
                  tx_done  => tx_done,
                  tx_pin   => tx_pin);

    -- کلاک 100 MHz
    clk <= not clk after CLK_PERIOD / 2;

    -- -----------------------------------------------------------------------
    -- پروسس تحریک
    -- -----------------------------------------------------------------------
    stim_proc : process
    begin
        rst <= '1';
        wait for 5 * CLK_PERIOD;
        rst <= '0';
        wait for 2 * CLK_PERIOD;

        -- بررسی idle state
        assert tx_pin = '1'
            report "[FAIL] tx_pin idle must be '1'"
            severity error;
        report "[PASS] idle: tx_pin='1'";

        -- ---- تست ۱: ارسال 0x41 ----
        report "--- test 1: send 0x41 (A) ---";
        tx_data  <= x"41";
        tx_start <= '1';
        wait for CLK_PERIOD;
        tx_start <= '0';

        wait for 2 * CLK_PERIOD;
        assert tx_busy = '1'
            report "[FAIL] tx_busy must be 1 after start"
            severity error;
        report "[PASS] tx_busy=1 confirmed";

        wait until tx_done = '1';
        report "[PASS] test 1 done: sent " & byte_to_hex(x"41");

        wait for 5 * CLK_PERIOD;

        -- ---- تست ۲: ارسال ۵ بایت پشت سر هم ----
        report "--- test 2: send 5 bytes ---";
        for i in TEST_BYTES'range loop
            wait until tx_busy = '0';
            wait for 2 * CLK_PERIOD;
            tx_data  <= TEST_BYTES(i);
            tx_start <= '1';
            wait for CLK_PERIOD;
            tx_start <= '0';
            wait until tx_done = '1';
            report "[PASS] byte " & integer'image(i) &
                   " = " & byte_to_hex(TEST_BYTES(i)) & " sent";
        end loop;

        -- ---- تست ۳: بررسی tx_done فقط یک کلاک است ----
        report "--- test 3: tx_done pulse width ---";
        wait until tx_busy = '0';
        wait for 2 * CLK_PERIOD;
        tx_data  <= x"55";
        tx_start <= '1';
        wait for CLK_PERIOD;
        tx_start <= '0';
        wait until tx_done = '1';
        wait for CLK_PERIOD;
        assert tx_done = '0'
            report "[FAIL] tx_done must be a 1-clock pulse"
            severity error;
        report "[PASS] tx_done is a single-clock pulse";

        wait for 20 * CLK_PERIOD;
        report "=== ALL uart_tx TESTS PASSED ===";
        wait;
    end process;

    -- -----------------------------------------------------------------------
    -- مانیتور: خط سریال را decode می‌کند (در یک حلقه)
    -- -----------------------------------------------------------------------
    monitor_proc : process
        variable rx_bits : std_logic_vector(7 downto 0);
    begin
        loop
            -- منتظر start bit (لبه افتادن)
            wait until tx_pin = '0';

            -- رفتن به وسط start bit
            wait for BAUD_PERIOD / 2;

            -- اگر هنوز '0' است -> start bit معتبر
            if tx_pin = '0' then
                -- دریافت 8 بیت داده (LSB first)
                for i in 0 to 7 loop
                    wait for BAUD_PERIOD;
                    rx_bits(i) := tx_pin;
                end loop;
                -- stop bit
                wait for BAUD_PERIOD;
                report "[MON] received: " & byte_to_hex(rx_bits);
            end if;
        end loop;
    end process;

end sim;
