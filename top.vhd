-- =============================================================================
-- Project  : FPGA Embedded Sensor Hub
-- Module   : Top Level
-- Board    : Basys3 (Xilinx Artix-7 XC7A35T)
-- Purpose  : BME280 sensor reader with UART logging and PWM LED
--
-- PIN MAP (Basys3):
--   clk      -> W5   (100 MHz onboard clock)
--   rst      -> T18  (Center button BTNC)
--   uart_tx  -> A18  (USB-UART TX - JA1 or USB connector)
--   uart_rx  -> B18  (USB-UART RX)
--   sclk     -> JA4
--   mosi     -> JA1
--   miso     -> JA2
--   cs_n     -> JA3
--   pwm_led  -> V17  (LD0)
--   status   -> U16..V14 (LD1-LD4)
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
    port (
        -- Board pins
        clk         : in  std_logic;   -- 100 MHz
        rst         : in  std_logic;   -- Active-high reset (BTNC)
        -- UART
        uart_tx_pin : out std_logic;
        uart_rx_pin : in  std_logic;
        -- SPI to BME280
        spi_sclk    : out std_logic;
        spi_mosi    : out std_logic;
        spi_miso    : in  std_logic;
        spi_cs_n    : out std_logic;
        -- LEDs
        pwm_led     : out std_logic;           -- Brightness = temperature
        status_leds : out std_logic_vector(3 downto 0)  -- Debug state
    );
end top;

architecture Structural of top is

    -- Internal signals
    signal spi_start_s   : std_logic;
    signal spi_tx_data_s : std_logic_vector(7 downto 0);
    signal spi_rx_data_s : std_logic_vector(7 downto 0);
    signal spi_busy_s    : std_logic;
    signal spi_done_s    : std_logic;

    signal uart_tx_data_s  : std_logic_vector(7 downto 0);
    signal uart_tx_start_s : std_logic;
    signal uart_tx_busy_s  : std_logic;
    signal uart_tx_done_s  : std_logic;

    signal pwm_duty_s : std_logic_vector(7 downto 0);

    -- Component declarations
    component uart_tx is
        generic (CLK_FREQ : integer; BAUD_RATE : integer);
        port (clk, rst, tx_start : in std_logic;
              tx_data : in std_logic_vector(7 downto 0);
              tx_busy, tx_done, tx_pin : out std_logic);
    end component;

    component uart_rx is
        generic (CLK_FREQ : integer; BAUD_RATE : integer);
        port (clk, rst, rx_pin : in std_logic;
              rx_data : out std_logic_vector(7 downto 0);
              rx_valid : out std_logic);
    end component;

    component spi_master is
        generic (CLK_FREQ, SPI_FREQ, DATA_WIDTH : integer);
        port (clk, rst, start, miso : in std_logic;
              tx_data : in  std_logic_vector(7 downto 0);
              rx_data : out std_logic_vector(7 downto 0);
              busy, done, sclk, mosi, cs_n : out std_logic);
    end component;

    component pwm_gen is
        generic (CLK_FREQ, PWM_FREQ, RESOLUTION : integer);
        port (clk, rst : in std_logic;
              duty     : in  std_logic_vector(7 downto 0);
              pwm_out  : out std_logic);
    end component;

    component sensor_ctrl is
        generic (CLK_FREQ, SAMPLE_MS : integer);
        port (
            clk, rst, spi_done, spi_busy, uart_busy, uart_done : in std_logic;
            spi_rx_data : in  std_logic_vector(7 downto 0);
            spi_start   : out std_logic;
            spi_tx_data : out std_logic_vector(7 downto 0);
            uart_data   : out std_logic_vector(7 downto 0);
            uart_start  : out std_logic;
            pwm_duty    : out std_logic_vector(7 downto 0);
            status_led  : out std_logic_vector(3 downto 0)
        );
    end component;

begin

    -- UART Transmitter
    u_uart_tx : uart_tx
        generic map (CLK_FREQ => 100_000_000, BAUD_RATE => 115_200)
        port map (
            clk      => clk,
            rst      => rst,
            tx_data  => uart_tx_data_s,
            tx_start => uart_tx_start_s,
            tx_busy  => uart_tx_busy_s,
            tx_done  => uart_tx_done_s,
            tx_pin   => uart_tx_pin
        );

    -- SPI Master
    u_spi : spi_master
        generic map (CLK_FREQ => 100_000_000, SPI_FREQ => 1_000_000, DATA_WIDTH => 8)
        port map (
            clk     => clk,
            rst     => rst,
            start   => spi_start_s,
            tx_data => spi_tx_data_s,
            rx_data => spi_rx_data_s,
            busy    => spi_busy_s,
            done    => spi_done_s,
            sclk    => spi_sclk,
            mosi    => spi_mosi,
            miso    => spi_miso,
            cs_n    => spi_cs_n
        );

    -- PWM Generator for LED
    u_pwm : pwm_gen
        generic map (CLK_FREQ => 100_000_000, PWM_FREQ => 1_000, RESOLUTION => 8)
        port map (
            clk     => clk,
            rst     => rst,
            duty    => pwm_duty_s,
            pwm_out => pwm_led
        );

    -- Sensor Controller (main brain)
    u_ctrl : sensor_ctrl
        generic map (CLK_FREQ => 100_000_000, SAMPLE_MS => 1000)
        port map (
            clk         => clk,
            rst         => rst,
            spi_start   => spi_start_s,
            spi_tx_data => spi_tx_data_s,
            spi_rx_data => spi_rx_data_s,
            spi_done    => spi_done_s,
            spi_busy    => spi_busy_s,
            uart_data   => uart_tx_data_s,
            uart_start  => uart_tx_start_s,
            uart_busy   => uart_tx_busy_s,
            uart_done   => uart_tx_done_s,
            pwm_duty    => pwm_duty_s,
            status_led  => status_leds
        );

end Structural;
