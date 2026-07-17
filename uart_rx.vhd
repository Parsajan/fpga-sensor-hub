-- =============================================================================
-- Module   : UART Receiver
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rx is
    generic (
        CLK_FREQ  : integer := 100_000_000;
        BAUD_RATE : integer := 115_200
    );
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        rx_pin   : in  std_logic;
        rx_data  : out std_logic_vector(7 downto 0);
        rx_valid : out std_logic
    );
end uart_rx;

architecture Behavioral of uart_rx is

    constant BAUD_DIV      : integer := CLK_FREQ / BAUD_RATE;
    constant HALF_BAUD_DIV : integer := BAUD_DIV / 2;

    type state_type is (IDLE, START, DATA, STOP);
    signal state : state_type := IDLE;

    signal baud_cnt  : integer range 0 to BAUD_DIV - 1 := 0;
    signal bit_cnt   : integer range 0 to 7 := 0;
    signal shift_reg : std_logic_vector(7 downto 0) := (others => '0');

    -- Input synchronizer (2 FF for metastability)
    signal rx_sync1, rx_sync2 : std_logic := '1';

begin

    -- Double-flop synchronizer
    sync_proc : process(clk)
    begin
        if rising_edge(clk) then
            rx_sync1 <= rx_pin;
            rx_sync2 <= rx_sync1;
        end if;
    end process;

    -- UART RX FSM
    rx_fsm : process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state    <= IDLE;
                rx_valid <= '0';
                baud_cnt <= 0;
                bit_cnt  <= 0;
            else
                rx_valid <= '0';

                case state is

                    when IDLE =>
                        if rx_sync2 = '0' then  -- Falling edge = start bit
                            baud_cnt <= 0;
                            state    <= START;
                        end if;

                    when START =>
                        -- Sample at middle of start bit
                        if baud_cnt = HALF_BAUD_DIV - 1 then
                            if rx_sync2 = '0' then  -- Valid start bit
                                baud_cnt <= 0;
                                bit_cnt  <= 0;
                                state    <= DATA;
                            else
                                state <= IDLE;  -- False trigger
                            end if;
                        else
                            baud_cnt <= baud_cnt + 1;
                        end if;

                    when DATA =>
                        if baud_cnt = BAUD_DIV - 1 then
                            baud_cnt  <= 0;
                            shift_reg <= rx_sync2 & shift_reg(7 downto 1);  -- LSB first
                            if bit_cnt = 7 then
                                state <= STOP;
                            else
                                bit_cnt <= bit_cnt + 1;
                            end if;
                        else
                            baud_cnt <= baud_cnt + 1;
                        end if;

                    when STOP =>
                        if baud_cnt = BAUD_DIV - 1 then
                            if rx_sync2 = '1' then  -- Valid stop bit
                                rx_data  <= shift_reg;
                                rx_valid <= '1';
                            end if;
                            baud_cnt <= 0;
                            state    <= IDLE;
                        else
                            baud_cnt <= baud_cnt + 1;
                        end if;

                end case;
            end if;
        end if;
    end process;

end Behavioral;
