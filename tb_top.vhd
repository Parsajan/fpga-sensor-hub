-- =============================================================================
-- Testbench : tb_top  (ModelSim compatible - VHDL 93/2008)
-- Integration test for the full sensor hub system
-- =============================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_top is
end tb_top;

architecture sim of tb_top is

    constant CLK_PERIOD  : time := 10 ns;
    constant BAUD_PERIOD : time := 8680 ns;

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '1';
    signal uart_tx_pin : std_logic;
    signal uart_rx_pin : std_logic := '1';
    signal spi_sclk    : std_logic;
    signal spi_mosi    : std_logic;
    signal spi_miso    : std_logic := '1';
    signal spi_cs_n    : std_logic;
    signal pwm_led     : std_logic;
    signal status_leds : std_logic_vector(3 downto 0);

    -- شمارنده‌های رویداد
    signal uart_byte_count : integer := 0;
    signal spi_xact_count  : integer := 0;

    function byte_to_hex(b : std_logic_vector(7 downto 0)) return string is
        constant HEX_CHARS : string(1 to 16) := "0123456789ABCDEF";
        variable result    : string(1 to 4)  := "0x00";
    begin
        result(3) := HEX_CHARS(to_integer(unsigned(b(7 downto 4))) + 1);
        result(4) := HEX_CHARS(to_integer(unsigned(b(3 downto 0))) + 1);
        return result;
    end function;

    component top is
        port (clk         : in  std_logic;
              rst         : in  std_logic;
              uart_tx_pin : out std_logic;
              uart_rx_pin : in  std_logic;
              spi_sclk    : out std_logic;
              spi_mosi    : out std_logic;
              spi_miso    : in  std_logic;
              spi_cs_n    : out std_logic;
              pwm_led     : out std_logic;
              status_leds : out std_logic_vector(3 downto 0));
    end component;

begin

    DUT : top
        port map (clk         => clk,
                  rst         => rst,
                  uart_tx_pin => uart_tx_pin,
                  uart_rx_pin => uart_rx_pin,
                  spi_sclk    => spi_sclk,
                  spi_mosi    => spi_mosi,
                  spi_miso    => spi_miso,
                  spi_cs_n    => spi_cs_n,
                  pwm_led     => pwm_led,
                  status_leds => status_leds);

    clk <= not clk after CLK_PERIOD / 2;

    -- -----------------------------------------------------------------------
    -- مدل BME280 SPI Slave (حلقه‌دار)
    -- -----------------------------------------------------------------------
    bme280_model : process
        variable rx_addr  : std_logic_vector(7 downto 0);
        variable response : std_logic_vector(7 downto 0);
    begin
        spi_miso <= '1';
        loop
            -- منتظر CS
            wait until spi_cs_n = '0';
            spi_xact_count <= spi_xact_count + 1;

            -- خواندن آدرس (8 بیت)
            rx_addr := (others => '0');
            for i in 7 downto 0 loop
                wait until rising_edge(spi_sclk);
                rx_addr(i) := spi_mosi;
            end loop;

            -- انتخاب پاسخ بر اساس آدرس
            if    rx_addr = x"D0" then response := x"60";  -- CHIP_ID
            elsif rx_addr = x"FA" then response := x"7D";  -- TEMP_MSB
            elsif rx_addr = x"FB" then response := x"00";  -- TEMP_LSB
            elsif rx_addr = x"FC" then response := x"00";  -- TEMP_XLSB
            elsif rx_addr = x"FD" then response := x"64";  -- HUM_MSB
            elsif rx_addr = x"FE" then response := x"00";  -- HUM_LSB
            else                        response := x"00";
            end if;

            report "[BME280] addr=" & byte_to_hex(rx_addr) &
                   " -> resp=" & byte_to_hex(response);

            -- ارسال پاسخ (8 بیت)
            for i in 7 downto 0 loop
                wait until rising_edge(spi_sclk);
                spi_miso <= response(i);
            end loop;

            wait until spi_cs_n = '1';
            spi_miso <= '1';
        end loop;
    end process;

    -- -----------------------------------------------------------------------
    -- مانیتور UART (حلقه‌دار)
    -- -----------------------------------------------------------------------
    uart_monitor : process
        variable rx_byte : std_logic_vector(7 downto 0);
        variable val     : integer;
    begin
        loop
            wait until uart_tx_pin = '0';   -- start bit
            wait for BAUD_PERIOD / 2;

            if uart_tx_pin = '0' then
                for i in 0 to 7 loop
                    wait for BAUD_PERIOD;
                    rx_byte(i) := uart_tx_pin;
                end loop;
                wait for BAUD_PERIOD;  -- stop bit

                uart_byte_count <= uart_byte_count + 1;
                val := to_integer(unsigned(rx_byte));

                -- نمایش کاراکترهای قابل چاپ
                if val >= 32 and val <= 126 then
                    report "[UART] byte=" & byte_to_hex(rx_byte) &
                           "  dec=" & integer'image(val) & " (printable)";
                else
                    report "[UART] byte=" & byte_to_hex(rx_byte) &
                           "  dec=" & integer'image(val) & " (control)";
                end if;
            end if;
        end loop;
    end process;

    -- -----------------------------------------------------------------------
    -- مانیتور status LEDs
    -- -----------------------------------------------------------------------
    led_monitor : process (status_leds)
    begin
        report "[LED] status_leds changed to: " &
               std_logic'image(status_leds(3)) &
               std_logic'image(status_leds(2)) &
               std_logic'image(status_leds(1)) &
               std_logic'image(status_leds(0));
    end process;

    -- -----------------------------------------------------------------------
    -- تحریک اصلی
    -- -----------------------------------------------------------------------
    stim_proc : process
    begin
        rst <= '1';
        wait for 20 * CLK_PERIOD;
        rst <= '0';
        report "[TB] reset released";

        -- بررسی idle state
        wait for 50 * CLK_PERIOD;
        assert uart_tx_pin = '1'
            report "[FAIL] UART TX must be idle (1)"
            severity error;
        assert spi_cs_n = '1'
            report "[FAIL] SPI CS_N must be idle (1)"
            severity error;
        report "[PASS] idle states ok";

        -- منتظر اولین SPI transaction
        report "[TB] waiting for first SPI transaction...";
        wait until spi_cs_n = '0';
        report "[PASS] first SPI CS_N went low";
        wait until spi_cs_n = '1';
        report "[PASS] first SPI transaction complete";

        -- منتظر اولین UART byte
        report "[TB] waiting for first UART byte...";
        wait until uart_tx_pin = '0';
        report "[PASS] first UART byte started";

        -- صبر برای دیدن چند transaction بیشتر
        for i in 1 to 3 loop
            wait until spi_cs_n = '0';
            wait until spi_cs_n = '1';
            report "[PASS] SPI transaction " & integer'image(i+1) & " complete";
        end loop;

        wait for 50 * CLK_PERIOD;
        report "=== INTEGRATION TEST COMPLETE ===";
        report "SPI transactions seen: " & integer'image(spi_xact_count);
        report "UART bytes sent: " & integer'image(uart_byte_count);
        wait;
    end process;

    -- -----------------------------------------------------------------------
    -- Timeout: بعد از 20ms شبیه‌سازی را متوقف کن
    -- -----------------------------------------------------------------------
    timeout_proc : process
    begin
        wait for 20 ms;
        report "[TIMEOUT] simulation limit reached" severity failure;
    end process;

end sim;
