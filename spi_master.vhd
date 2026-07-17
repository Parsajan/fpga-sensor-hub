-- =============================================================================
-- Module   : SPI Master Controller
-- Mode     : CPOL=0, CPHA=0 (Mode 0)
-- Target   : BME280 Temperature/Humidity/Pressure Sensor
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spi_master is
    generic (
        CLK_FREQ  : integer := 100_000_000;
        SPI_FREQ  : integer := 1_000_000;   -- 1 MHz SPI clock
        DATA_WIDTH: integer := 8
    );
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        -- Control interface
        start    : in  std_logic;
        tx_data  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        rx_data  : out std_logic_vector(DATA_WIDTH-1 downto 0);
        busy     : out std_logic;
        done     : out std_logic;
        -- SPI pins
        sclk     : out std_logic;
        mosi     : out std_logic;
        miso     : in  std_logic;
        cs_n     : out std_logic
    );
end spi_master;

architecture Behavioral of spi_master is

    constant CLK_DIV : integer := CLK_FREQ / (2 * SPI_FREQ);  -- Half-period count

    type state_type is (IDLE, ASSERT_CS, TRANSFER, DEASSERT_CS);
    signal state : state_type := IDLE;

    signal clk_cnt   : integer range 0 to CLK_DIV - 1 := 0;
    signal bit_cnt   : integer range 0 to DATA_WIDTH - 1 := 0;
    signal sclk_reg  : std_logic := '0';
    signal shift_tx  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal shift_rx  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal clk_edge  : std_logic := '0';

begin

    sclk <= sclk_reg;

    -- SPI clock divider
    clk_div_proc : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' or state = IDLE then
                clk_cnt  <= 0;
                clk_edge <= '0';
            elsif clk_cnt = CLK_DIV - 1 then
                clk_cnt  <= 0;
                clk_edge <= '1';
                sclk_reg <= not sclk_reg;
            else
                clk_cnt  <= clk_cnt + 1;
                clk_edge <= '0';
            end if;
        end if;
    end process;

    -- SPI FSM
    spi_fsm : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state    <= IDLE;
                cs_n     <= '1';
                mosi     <= '1';
                busy     <= '0';
                done     <= '0';
                bit_cnt  <= 0;
            else
                done <= '0';

                case state is

                    when IDLE =>
                        cs_n     <= '1';
                        sclk_reg <= '0';
                        busy     <= '0';
                        if start = '1' then
                            shift_tx <= tx_data;
                            state    <= ASSERT_CS;
                            busy     <= '1';
                        end if;

                    when ASSERT_CS =>
                        cs_n    <= '0';     -- Activate chip select
                        bit_cnt <= DATA_WIDTH - 1;
                        state   <= TRANSFER;

                    when TRANSFER =>
                        mosi <= shift_tx(DATA_WIDTH-1);    -- MSB first

                        if clk_edge = '1' then
                            if sclk_reg = '0' then          -- Rising edge: sample MISO
                                shift_rx <= shift_rx(DATA_WIDTH-2 downto 0) & miso;
                            else                            -- Falling edge: shift MOSI
                                shift_tx <= shift_tx(DATA_WIDTH-2 downto 0) & '0';
                                if bit_cnt = 0 then
                                    state <= DEASSERT_CS;
                                else
                                    bit_cnt <= bit_cnt - 1;
                                end if;
                            end if;
                        end if;

                    when DEASSERT_CS =>
                        cs_n    <= '1';
                        rx_data <= shift_rx;
                        done    <= '1';
                        state   <= IDLE;

                end case;
            end if;
        end if;
    end process;

end Behavioral;
