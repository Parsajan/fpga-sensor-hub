-- =============================================================================
-- Testbench : tb_uart_rx  (ModelSim compatible - VHDL 93/2008)
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_uart_rx is
end tb_uart_rx;

architecture sim of tb_uart_rx is

    constant CLK_PERIOD  : time := 10 ns;
    constant BAUD_PERIOD : time := 8680 ns;

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal rx_pin   : std_logic := '1';
    signal rx_data  : std_logic_vector(7 downto 0);
    signal rx_valid : std_logic;

    function byte_to_hex(b : std_logic_vector(7 downto 0)) return string is
        constant HEX_CHARS : string(1 to 16) := "0123456789ABCDEF";
        variable result    : string(1 to 4)  := "0x00";
    begin
        result(3) := HEX_CHARS(to_integer(unsigned(b(7 downto 4))) + 1);
        result(4) := HEX_CHARS(to_integer(unsigned(b(3 downto 0))) + 1);
        return result;
    end function;

    component uart_rx is
        generic (CLK_FREQ  : integer;
                 BAUD_RATE : integer);
        port (clk      : in  std_logic;
              rst      : in  std_logic;
              rx_pin   : in  std_logic;
              rx_data  : out std_logic_vector(7 downto 0);
              rx_valid : out std_logic);
    end component;

    -- -----------------------------------------------------------------------
    -- Procedure: شبیه‌سازی ارسال یک بایت UART (LSB first)
    -- -----------------------------------------------------------------------
    procedure send_byte (
        constant data    : in  std_logic_vector(7 downto 0);
        signal   rx_line : out std_logic
    ) is
    begin
        rx_line <= '0';                  -- start bit
        wait for BAUD_PERIOD;
        for i in 0 to 7 loop            -- 8 data bits, LSB first
            rx_line <= data(i);
            wait for BAUD_PERIOD;
        end loop;
        rx_line <= '1';                  -- stop bit
        wait for BAUD_PERIOD;
    end procedure;

begin

    DUT : uart_rx
        generic map (CLK_FREQ  => 100_000_000,
                     BAUD_RATE => 115_200)
        port map (clk      => clk,
                  rst      => rst,
                  rx_pin   => rx_pin,
                  rx_data  => rx_data,
                  rx_valid => rx_valid);

    clk <= not clk after CLK_PERIOD / 2;

    stim_proc : process
    begin
        rst    <= '1';
        rx_pin <= '1';
        wait for 10 * CLK_PERIOD;
        rst <= '0';
        wait for 5 * CLK_PERIOD;

        -- ---- تست ۱: دریافت 0x55 ----
        report "--- test 1: send 0x55 ---";
        send_byte(x"55", rx_pin);
        wait until rx_valid = '1';
        assert rx_data = x"55"
            report "[FAIL] test1: expected 0x55 got " & byte_to_hex(rx_data)
            severity error;
        report "[PASS] test 1: received " & byte_to_hex(rx_data);
        wait for 10 * CLK_PERIOD;

        -- ---- تست ۲: دریافت 0x00 ----
        report "--- test 2: send 0x00 ---";
        send_byte(x"00", rx_pin);
        wait until rx_valid = '1';
        assert rx_data = x"00"
            report "[FAIL] test2: expected 0x00 got " & byte_to_hex(rx_data)
            severity error;
        report "[PASS] test 2: received " & byte_to_hex(rx_data);
        wait for 10 * CLK_PERIOD;

        -- ---- تست ۳: دریافت 0xFF ----
        report "--- test 3: send 0xFF ---";
        send_byte(x"FF", rx_pin);
        wait until rx_valid = '1';
        assert rx_data = x"FF"
            report "[FAIL] test3: expected 0xFF got " & byte_to_hex(rx_data)
            severity error;
        report "[PASS] test 3: received " & byte_to_hex(rx_data);
        wait for 10 * CLK_PERIOD;

        -- ---- تست ۴: نویز کوتاه (باید نادیده گرفته شود) ----
        report "--- test 4: glitch (50ns pulse, must be ignored) ---";
        rx_pin <= '0';
        wait for 50 ns;      -- کوتاه‌تر از HALF_BAUD = 4340 ns
        rx_pin <= '1';
        wait for BAUD_PERIOD * 3;
        assert rx_valid = '0'
            report "[FAIL] test4: glitch triggered rx_valid!"
            severity error;
        report "[PASS] test 4: glitch ignored correctly";

        -- ---- تست ۵: ارسال چند بایت پشت سر هم ----
        report "--- test 5: sequential bytes ---";
        send_byte(x"48", rx_pin);  -- H
        wait until rx_valid = '1';
        assert rx_data = x"48" report "[FAIL] 'H'" severity error;
        report "[PASS] received 0x48 (H)";

        send_byte(x"49", rx_pin);  -- I
        wait until rx_valid = '1';
        assert rx_data = x"49" report "[FAIL] 'I'" severity error;
        report "[PASS] received 0x49 (I)";

        send_byte(x"0D", rx_pin);  -- CR
        wait until rx_valid = '1';
        report "[PASS] received 0x0D (CR)";

        wait for 20 * CLK_PERIOD;
        report "=== ALL uart_rx TESTS PASSED ===";
        wait;
    end process;

end sim;
