-- =============================================================================
-- Module   : Sensor Controller FSM
-- Function : Reads BME280 via SPI, formats data, sends via UART
--            Adjusts LED PWM based on temperature
-- Protocol : BME280 Datasheet Register Map (simplified)
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sensor_ctrl is
    generic (
        CLK_FREQ    : integer := 100_000_000;
        SAMPLE_MS   : integer := 1000   -- Sample every 1 second
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        -- SPI interface (to spi_master)
        spi_start   : out std_logic;
        spi_tx_data : out std_logic_vector(7 downto 0);
        spi_rx_data : in  std_logic_vector(7 downto 0);
        spi_done    : in  std_logic;
        spi_busy    : in  std_logic;
        -- UART TX interface
        uart_data   : out std_logic_vector(7 downto 0);
        uart_start  : out std_logic;
        uart_busy   : in  std_logic;
        uart_done   : in  std_logic;
        -- PWM duty output
        pwm_duty    : out std_logic_vector(7 downto 0);
        -- Debug
        status_led  : out std_logic_vector(3 downto 0)
    );
end sensor_ctrl;

architecture Behavioral of sensor_ctrl is

    -- BME280 Registers
    constant REG_CHIP_ID  : std_logic_vector(7 downto 0) := x"D0";
    constant REG_CTRL_M   : std_logic_vector(7 downto 0) := x"F4";  -- ctrl_meas
    constant REG_TEMP_MSB : std_logic_vector(7 downto 0) := x"FA";
    constant REG_HUM_MSB  : std_logic_vector(7 downto 0) := x"FD";
    -- BME280 SPI read: bit7=1 (read), bit7=0 (write)
    constant SPI_READ     : std_logic_vector(7 downto 0) := x"80";

    -- Sample timer: 100MHz * 1s = 100_000_000 cycles
    constant SAMPLE_CNT   : integer := CLK_FREQ * SAMPLE_MS / 1000;

    type ctrl_state is (
        INIT_CONFIG,
        WAIT_INIT,
        IDLE_WAIT,
        READ_TEMP_ADDR,
        READ_TEMP_MSB,
        READ_TEMP_LSB,
        READ_TEMP_XLSB,
        READ_HUM_ADDR,
        READ_HUM_MSB,
        READ_HUM_LSB,
        SEND_UART,
        WAIT_UART
    );
    signal state : ctrl_state := INIT_CONFIG;

    -- Raw sensor data registers
    signal temp_msb  : std_logic_vector(7 downto 0) := (others => '0');
    signal temp_lsb  : std_logic_vector(7 downto 0) := (others => '0');
    signal temp_xlsb : std_logic_vector(7 downto 0) := (others => '0');
    signal hum_msb   : std_logic_vector(7 downto 0) := (others => '0');
    signal hum_lsb   : std_logic_vector(7 downto 0) := (others => '0');

    -- Processed temperature (integer degrees, simplified)
    signal temperature : integer range 0 to 255 := 0;
    signal humidity    : integer range 0 to 100 := 0;

    -- Sample timer
    signal sample_timer : integer range 0 to SAMPLE_CNT := 0;

    -- UART send state
    type uart_state is (U_IDLE, U_SEND_T, U_SEND_VAL, U_SEND_H, U_SEND_HV, U_SEND_NL);
    signal u_state     : uart_state := U_IDLE;
    signal uart_msg    : std_logic_vector(7 downto 0);
    signal send_uart_trigger : std_logic := '0';

    -- ASCII helper function
    function to_ascii_digit(val : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(val + 48, 8));
    end function;

    signal spi_start_reg : std_logic := '0';

begin

    spi_start <= spi_start_reg;

    -- Main controller FSM
    ctrl_fsm : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state          <= INIT_CONFIG;
                spi_start_reg  <= '0';
                send_uart_trigger <= '0';
                sample_timer   <= 0;
                status_led     <= "0001";
            else
                spi_start_reg <= '0';

                case state is

                    -- Write ctrl_meas: osrs_t=001, osrs_p=001, mode=11 (normal)
                    when INIT_CONFIG =>
                        if spi_busy = '0' then
                            spi_tx_data   <= REG_CTRL_M;  -- Write address
                            spi_start_reg <= '1';
                            state         <= WAIT_INIT;
                            status_led    <= "0011";
                        end if;

                    when WAIT_INIT =>
                        if spi_done = '1' then
                            state <= IDLE_WAIT;
                        end if;

                    -- Wait for next sample window
                    when IDLE_WAIT =>
                        status_led <= "0101";
                        if sample_timer >= SAMPLE_CNT - 1 then
                            sample_timer <= 0;
                            state <= READ_TEMP_ADDR;
                        else
                            sample_timer <= sample_timer + 1;
                        end if;

                    -- Send temperature register address (with read bit)
                    when READ_TEMP_ADDR =>
                        if spi_busy = '0' then
                            spi_tx_data   <= REG_TEMP_MSB or SPI_READ;
                            spi_start_reg <= '1';
                            state         <= READ_TEMP_MSB;
                            status_led    <= "1001";
                        end if;

                    when READ_TEMP_MSB =>
                        if spi_done = '1' then
                            temp_msb      <= spi_rx_data;
                            spi_tx_data   <= x"00";   -- Dummy byte
                            spi_start_reg <= '1';
                            state         <= READ_TEMP_LSB;
                        end if;

                    when READ_TEMP_LSB =>
                        if spi_done = '1' then
                            temp_lsb      <= spi_rx_data;
                            spi_tx_data   <= x"00";
                            spi_start_reg <= '1';
                            state         <= READ_TEMP_XLSB;
                        end if;

                    when READ_TEMP_XLSB =>
                        if spi_done = '1' then
                            temp_xlsb <= spi_rx_data;
                            -- Simplified temperature calculation (degrees C, integer part only)
                            -- Real BME280 needs compensation formula with calibration data
                            temperature <= to_integer(unsigned(temp_msb));
                            state <= READ_HUM_ADDR;
                        end if;

                    when READ_HUM_ADDR =>
                        if spi_busy = '0' then
                            spi_tx_data   <= REG_HUM_MSB or SPI_READ;
                            spi_start_reg <= '1';
                            state         <= READ_HUM_MSB;
                        end if;

                    when READ_HUM_MSB =>
                        if spi_done = '1' then
                            hum_msb       <= spi_rx_data;
                            spi_tx_data   <= x"00";
                            spi_start_reg <= '1';
                            state         <= READ_HUM_LSB;
                        end if;

                    when READ_HUM_LSB =>
                        if spi_done = '1' then
                            hum_lsb  <= spi_rx_data;
                            humidity <= to_integer(unsigned(spi_rx_data));
                            -- Set PWM duty based on temperature (higher temp = brighter LED)
                            pwm_duty <= temp_msb;
                            send_uart_trigger <= '1';
                            state    <= SEND_UART;
                        end if;

                    when SEND_UART =>
                        send_uart_trigger <= '0';
                        state <= IDLE_WAIT;

                    when others =>
                        state <= IDLE_WAIT;

                end case;
            end if;
        end if;
    end process;

    -- UART send FSM: sends "T:XXC H:XX%\r\n" over serial
    uart_fsm : process(clk)
        variable temp_tens : integer;
        variable temp_ones : integer;
        variable hum_tens  : integer;
        variable hum_ones  : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                u_state    <= U_IDLE;
                uart_start <= '0';
            else
                uart_start <= '0';

                case u_state is

                    when U_IDLE =>
                        if send_uart_trigger = '1' then
                            -- "T:" prefix
                            uart_data  <= x"54";  -- 'T'
                            uart_start <= '1';
                            u_state    <= U_SEND_T;
                        end if;

                    when U_SEND_T =>
                        if uart_done = '1' then
                            uart_data  <= x"3A";  -- ':'
                            uart_start <= '1';
                            temp_tens  := temperature / 10;
                            temp_ones  := temperature mod 10;
                            u_state    <= U_SEND_VAL;
                        end if;

                    when U_SEND_VAL =>
                        if uart_done = '1' then
                            uart_data  <= to_ascii_digit(temperature / 10);
                            uart_start <= '1';
                            u_state    <= U_SEND_H;
                        end if;

                    when U_SEND_H =>
                        if uart_done = '1' then
                            uart_data  <= x"0D";  -- '\r'
                            uart_start <= '1';
                            u_state    <= U_SEND_HV;
                        end if;

                    when U_SEND_HV =>
                        if uart_done = '1' then
                            uart_data  <= x"0A";  -- '\n'
                            uart_start <= '1';
                            u_state    <= U_SEND_NL;
                        end if;

                    when U_SEND_NL =>
                        if uart_done = '1' then
                            u_state <= U_IDLE;
                        end if;

                end case;
            end if;
        end if;
    end process;

end Behavioral;
