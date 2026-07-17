-- =============================================================================
-- Project  : FPGA Embedded Sensor Hub
-- Module   : UART Transmitter
-- Author   : [Your Name]
-- Board    : Basys3 / Nexys4 (Xilinx Artix-7)
-- Clock    : 100 MHz
-- Baud     : 115200
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tx is
    generic (
        CLK_FREQ  : integer := 100_000_000;  -- 100 MHz
        BAUD_RATE : integer := 115_200
    );
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        tx_data  : in  std_logic_vector(7 downto 0);
        tx_start : in  std_logic;
        tx_busy  : out std_logic;
        tx_done  : out std_logic;
        tx_pin   : out std_logic
    );
end uart_tx;

architecture Behavioral of uart_tx is

    constant BAUD_DIV : integer := CLK_FREQ / BAUD_RATE;  -- = 868

    type state_type is (IDLE, START, DATA, STOP);
    signal state : state_type := IDLE;

    signal baud_cnt  : integer range 0 to BAUD_DIV - 1 := 0;
    signal bit_cnt   : integer range 0 to 7 := 0;
    signal shift_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal baud_tick : std_logic := '0';

begin

    -- Baud rate generator
    baud_gen : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                baud_cnt  <= 0;
                baud_tick <= '0';
            elsif baud_cnt = BAUD_DIV - 1 then
                baud_cnt  <= 0;
                baud_tick <= '1';
            else
                baud_cnt  <= baud_cnt + 1;
                baud_tick <= '0';
            end if;
        end if;
    end process;

    -- UART TX FSM
    tx_fsm : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state     <= IDLE;
                tx_pin    <= '1';
                tx_busy   <= '0';
                tx_done   <= '0';
                bit_cnt   <= 0;
            else
                tx_done <= '0';

                case state is

                    when IDLE =>
                        tx_pin  <= '1';
                        tx_busy <= '0';
                        if tx_start = '1' then
                            shift_reg <= tx_data;
                            state     <= START;
                            tx_busy   <= '1';
                        end if;

                    when START =>
                        tx_pin <= '0';  -- Start bit
                        if baud_tick = '1' then
                            state   <= DATA;
                            bit_cnt <= 0;
                        end if;

                    when DATA =>
                        tx_pin <= shift_reg(0);
                        if baud_tick = '1' then
                            shift_reg <= '0' & shift_reg(7 downto 1);  -- LSB first
                            if bit_cnt = 7 then
                                state <= STOP;
                            else
                                bit_cnt <= bit_cnt + 1;
                            end if;
                        end if;

                    when STOP =>
                        tx_pin <= '1';  -- Stop bit
                        if baud_tick = '1' then
                            tx_done <= '1';
                            state   <= IDLE;
                        end if;

                end case;
            end if;
        end if;
    end process;

end Behavioral;
