-- =============================================================================
-- Testbench : tb_spi_master  (ModelSim compatible - VHDL 93/2008)
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_spi_master is
end tb_spi_master;

architecture sim of tb_spi_master is

    constant CLK_PERIOD  : time    := 10 ns;
    constant DATA_WIDTH  : integer := 8;

    signal clk     : std_logic := '0';
    signal rst     : std_logic := '1';
    signal start   : std_logic := '0';
    signal tx_data : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal rx_data : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal busy    : std_logic;
    signal done    : std_logic;
    signal sclk    : std_logic;
    signal mosi    : std_logic;
    signal miso    : std_logic := '1';
    signal cs_n    : std_logic;

    function byte_to_hex(b : std_logic_vector(7 downto 0)) return string is
        constant HEX_CHARS : string(1 to 16) := "0123456789ABCDEF";
        variable result    : string(1 to 4)  := "0x00";
    begin
        result(3) := HEX_CHARS(to_integer(unsigned(b(7 downto 4))) + 1);
        result(4) := HEX_CHARS(to_integer(unsigned(b(3 downto 0))) + 1);
        return result;
    end function;

    -- داده‌ای که slave می‌خواهد بفرستد (قابل تغییر از stim_proc)
    signal slave_response : std_logic_vector(7 downto 0) := x"60";

    component spi_master is
        generic (CLK_FREQ   : integer;
                 SPI_FREQ   : integer;
                 DATA_WIDTH : integer);
        port (clk     : in  std_logic;
              rst     : in  std_logic;
              start   : in  std_logic;
              tx_data : in  std_logic_vector(DATA_WIDTH-1 downto 0);
              rx_data : out std_logic_vector(DATA_WIDTH-1 downto 0);
              busy    : out std_logic;
              done    : out std_logic;
              sclk    : out std_logic;
              mosi    : out std_logic;
              miso    : in  std_logic;
              cs_n    : out std_logic);
    end component;

begin

    DUT : spi_master
        generic map (CLK_FREQ   => 100_000_000,
                     SPI_FREQ   => 1_000_000,
                     DATA_WIDTH => DATA_WIDTH)
        port map (clk     => clk,
                  rst     => rst,
                  start   => start,
                  tx_data => tx_data,
                  rx_data => rx_data,
                  busy    => busy,
                  done    => done,
                  sclk    => sclk,
                  mosi    => mosi,
                  miso    => miso,
                  cs_n    => cs_n);

    clk <= not clk after CLK_PERIOD / 2;

    -- -----------------------------------------------------------------------
    -- مدل SPI Slave (BME280 ساده شده)
    -- وقتی CS_N پایین می‌آید داده slave_response را می‌فرستد
    -- -----------------------------------------------------------------------
    spi_slave_model : process
        variable resp : std_logic_vector(7 downto 0);
        variable recv : std_logic_vector(7 downto 0);
    begin
        miso <= '1';
        loop
            -- منتظر CS فعال شود
            wait until cs_n = '0';
            resp := slave_response;  -- عکس فوری از مقدار فعلی
            recv := (others => '0');

            -- 8 بیت: rising edge -> MISO بفرست, falling edge -> MOSI بخوان
            for i in 7 downto 0 loop
                wait until rising_edge(sclk);
                miso <= resp(i);          -- MSB first
                wait until falling_edge(sclk);
                recv(i) := mosi;
            end loop;

            wait until cs_n = '1';
            miso <= '1';
            report "[SLAVE] received: " & byte_to_hex(recv) &
                   "  sent: " & byte_to_hex(resp);
        end loop;
    end process;

    -- -----------------------------------------------------------------------
    -- پروسس تحریک
    -- -----------------------------------------------------------------------
    stim_proc : process
    begin
        rst   <= '1';
        start <= '0';
        wait for 10 * CLK_PERIOD;
        rst <= '0';
        wait for 5 * CLK_PERIOD;

        -- بررسی حالت اولیه Mode 0
        assert cs_n = '1'
            report "[FAIL] CS_N must be '1' at idle"
            severity error;
        assert sclk = '0'
            report "[FAIL] SCLK must be '0' at idle (CPOL=0)"
            severity error;
        report "[PASS] initial state: CS_N='1', SCLK='0' (Mode 0 ok)";

        -- ---- تست ۱: ارسال 0xD0, دریافت 0x60 (BME280 CHIP_ID) ----
        report "--- test 1: send 0xD0, expect RX=0x60 ---";
        slave_response <= x"60";
        tx_data        <= x"D0";
        start          <= '1';
        wait for CLK_PERIOD;
        start          <= '0';

        -- CS باید پایین بیاید
        wait until cs_n = '0';
        report "[PASS] CS_N went low";

        -- صبر تا تمام شود
        wait until done = '1';

        assert rx_data = x"60"
            report "[FAIL] test1: expected 0x60 got " & byte_to_hex(rx_data)
            severity error;
        assert cs_n = '1'
            report "[FAIL] CS_N must go high after transaction"
            severity error;
        report "[PASS] test 1: RX = " & byte_to_hex(rx_data) & " (CHIP_ID ok)";

        wait for 20 * CLK_PERIOD;

        -- ---- تست ۲: dummy byte 0x00, slave می‌فرستد 0xFA ----
        report "--- test 2: send 0x00, expect RX=0xFA ---";
        slave_response <= x"FA";
        tx_data        <= x"00";
        start          <= '1';
        wait for CLK_PERIOD;
        start          <= '0';
        wait until done = '1';

        assert rx_data = x"FA"
            report "[FAIL] test2: expected 0xFA got " & byte_to_hex(rx_data)
            severity error;
        report "[PASS] test 2: RX = " & byte_to_hex(rx_data);

        wait for 20 * CLK_PERIOD;

        -- ---- تست ۳: busy flag ----
        report "--- test 3: busy flag ---";
        slave_response <= x"AA";
        tx_data        <= x"BB";
        start          <= '1';
        wait for CLK_PERIOD;
        start          <= '0';
        wait for 2 * CLK_PERIOD;
        assert busy = '1'
            report "[FAIL] test3: busy must be '1' during transfer"
            severity error;
        report "[PASS] busy='1' during transfer";
        wait until done = '1';
        wait for 2 * CLK_PERIOD;
        assert busy = '0'
            report "[FAIL] test3: busy must be '0' after done"
            severity error;
        report "[PASS] busy='0' after transfer";

        wait for 20 * CLK_PERIOD;
        report "=== ALL spi_master TESTS PASSED ===";
        wait;
    end process;

end sim;
