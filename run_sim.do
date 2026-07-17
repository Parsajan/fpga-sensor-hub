# =============================================================================
# run_sim.do  --  ModelSim Tcl script (Windows compatible)
# =============================================================================

quietly set StdArithNoWarnings 1
quietly set NumericStdNoWarnings 1

# ایجاد کتابخانه
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work
# =============================================================================
echo ">>> Compiling source files..."

if {[catch {vcom -93 src/uart_tx.vhd}     msg]} { echo "FAIL: uart_tx.vhd -> $msg";     return }
if {[catch {vcom -93 src/uart_rx.vhd}     msg]} { echo "FAIL: uart_rx.vhd -> $msg";     return }
if {[catch {vcom -93 src/spi_master.vhd}  msg]} { echo "FAIL: spi_master.vhd -> $msg";  return }
if {[catch {vcom -93 src/pwm_gen.vhd}     msg]} { echo "FAIL: pwm_gen.vhd -> $msg";     return }
if {[catch {vcom -93 src/sensor_ctrl.vhd} msg]} { echo "FAIL: sensor_ctrl.vhd -> $msg"; return }
if {[catch {vcom -93 src/top.vhd}         msg]} { echo "FAIL: top.vhd -> $msg";         return }

echo ">>> Source files OK"

# =============================================================================
# کامپایل testbench‌ها
# =============================================================================
echo ">>> Compiling testbenches..."

if {[catch {vcom -93 tb/tb_uart_tx.vhd}    msg]} { echo "FAIL: tb_uart_tx.vhd -> $msg";    return }
if {[catch {vcom -93 tb/tb_uart_rx.vhd}    msg]} { echo "FAIL: tb_uart_rx.vhd -> $msg";    return }
if {[catch {vcom -93 tb/tb_spi_master.vhd} msg]} { echo "FAIL: tb_spi_master.vhd -> $msg"; return }
if {[catch {vcom -93 tb/tb_pwm_gen.vhd}    msg]} { echo "FAIL: tb_pwm_gen.vhd -> $msg";    return }
if {[catch {vcom -93 tb/tb_top.vhd}        msg]} { echo "FAIL: tb_top.vhd -> $msg";        return }

echo ">>> Testbenches OK"
echo ""

# =============================================================================

proc run_uart_tx {} {
    vsim -t 1ns work.tb_uart_tx

    add wave -divider "--- INPUTS ---"
    add wave -label CLK      sim:/tb_uart_tx/clk
    add wave -label RST      sim:/tb_uart_tx/rst
    add wave -label TX_DATA  -radix hex     sim:/tb_uart_tx/tx_data
    add wave -label TX_START sim:/tb_uart_tx/tx_start
    add wave -divider "--- OUTPUTS ---"
    add wave -label TX_BUSY  sim:/tb_uart_tx/tx_busy
    add wave -label TX_DONE  sim:/tb_uart_tx/tx_done
    add wave -label TX_PIN   sim:/tb_uart_tx/tx_pin
    add wave -divider "--- DUT INTERNALS ---"
    add wave -label STATE    sim:/tb_uart_tx/DUT/state
    add wave -label BAUD_CNT -radix decimal sim:/tb_uart_tx/DUT/baud_cnt
    add wave -label BIT_CNT  -radix decimal sim:/tb_uart_tx/DUT/bit_cnt
    add wave -label SHIFT    -radix binary  sim:/tb_uart_tx/DUT/shift_reg
    add wave -label TICK     sim:/tb_uart_tx/DUT/baud_tick

    configure wave -namecolwidth 120
    configure wave -valuecolwidth 80
    run 5ms
    wave zoom full
    echo ">>> tb_uart_tx done. Check waveform and transcript."
}

proc run_uart_rx {} {
    vsim -t 1ns work.tb_uart_rx

    add wave -divider "--- INPUTS ---"
    add wave -label CLK      sim:/tb_uart_rx/clk
    add wave -label RST      sim:/tb_uart_rx/rst
    add wave -label RX_PIN   sim:/tb_uart_rx/rx_pin
    add wave -divider "--- OUTPUTS ---"
    add wave -label RX_DATA  -radix hex sim:/tb_uart_rx/rx_data
    add wave -label RX_VALID sim:/tb_uart_rx/rx_valid
    add wave -divider "--- DUT INTERNALS ---"
    add wave -label SYNC1    sim:/tb_uart_rx/DUT/rx_sync1
    add wave -label SYNC2    sim:/tb_uart_rx/DUT/rx_sync2
    add wave -label STATE    sim:/tb_uart_rx/DUT/state
    add wave -label BAUD_CNT -radix decimal sim:/tb_uart_rx/DUT/baud_cnt
    add wave -label BIT_CNT  -radix decimal sim:/tb_uart_rx/DUT/bit_cnt
    add wave -label SHIFT    -radix binary  sim:/tb_uart_rx/DUT/shift_reg

    configure wave -namecolwidth 120
    run 10ms
    wave zoom full
    echo ">>> tb_uart_rx done."
}

proc run_spi {} {
    vsim -t 1ns work.tb_spi_master

    add wave -divider "--- CONTROL ---"
    add wave -label CLK     sim:/tb_spi_master/clk
    add wave -label RST     sim:/tb_spi_master/rst
    add wave -label START   sim:/tb_spi_master/start
    add wave -label TX_DATA -radix hex sim:/tb_spi_master/tx_data
    add wave -label RX_DATA -radix hex sim:/tb_spi_master/rx_data
    add wave -label BUSY    sim:/tb_spi_master/busy
    add wave -label DONE    sim:/tb_spi_master/done
    add wave -divider "--- SPI BUS ---"
    add wave -label SCLK    sim:/tb_spi_master/sclk
    add wave -label MOSI    sim:/tb_spi_master/mosi
    add wave -label MISO    sim:/tb_spi_master/miso
    add wave -label CS_N    sim:/tb_spi_master/cs_n
    add wave -divider "--- DUT INTERNALS ---"
    add wave -label STATE    sim:/tb_spi_master/DUT/state
    add wave -label SHIFT_TX -radix binary  sim:/tb_spi_master/DUT/shift_tx
    add wave -label SHIFT_RX -radix binary  sim:/tb_spi_master/DUT/shift_rx
    add wave -label BIT_CNT  -radix decimal sim:/tb_spi_master/DUT/bit_cnt
    add wave -label CLK_EDGE sim:/tb_spi_master/DUT/clk_edge

    configure wave -namecolwidth 120
    run 1ms
    wave zoom full
    echo ">>> tb_spi_master done."
}

proc run_pwm {} {
    vsim -t 1ns work.tb_pwm_gen

    add wave -label CLK      sim:/tb_pwm_gen/clk
    add wave -label RST      sim:/tb_pwm_gen/rst
    add wave -label DUTY     -radix unsigned sim:/tb_pwm_gen/duty
    add wave -label PWM_OUT  sim:/tb_pwm_gen/pwm_out
    add wave -divider "--- DUT INTERNALS ---"
    add wave -label COUNTER  -radix decimal sim:/tb_pwm_gen/DUT/counter
    add wave -label DUTY_LVL -radix decimal sim:/tb_pwm_gen/DUT/duty_level

    configure wave -namecolwidth 120
    run 30ms
    wave zoom full
    echo ">>> tb_pwm_gen done."
}

proc run_integration {} {
    echo ">>> Integration test - this may take a few seconds..."
    vsim -t 1ns work.tb_top

    add wave -divider "--- SYSTEM ---"
    add wave -label CLK         sim:/tb_top/clk
    add wave -label RST         sim:/tb_top/rst
    add wave -label STATUS_LEDS -radix binary sim:/tb_top/status_leds
    add wave -divider "--- UART ---"
    add wave -label UART_TX     sim:/tb_top/uart_tx_pin
    add wave -label UART_BYTES  -radix decimal sim:/tb_top/uart_byte_count
    add wave -divider "--- SPI ---"
    add wave -label SPI_SCLK    sim:/tb_top/spi_sclk
    add wave -label SPI_MOSI    sim:/tb_top/spi_mosi
    add wave -label SPI_MISO    sim:/tb_top/spi_miso
    add wave -label SPI_CS_N    sim:/tb_top/spi_cs_n
    add wave -label SPI_COUNT   -radix decimal sim:/tb_top/spi_xact_count
    add wave -divider "--- LED ---"
    add wave -label PWM_LED     sim:/tb_top/pwm_led

    configure wave -namecolwidth 130
    run 5ms
    wave zoom full
    echo ">>> tb_top done."
}

proc run_all {} {
    echo ">>> Running all unit tests..."
    run_uart_tx
    run_uart_rx
    run_spi
    run_pwm
    echo ">>> All unit tests done."
}

# =============================================================================
echo "  ================================================"
echo "  Compilation successful! Commands:"
echo ""
echo "    run_uart_tx      -> UART TX test"
echo "    run_uart_rx      -> UART RX test"
echo "    run_spi          -> SPI Master test"
echo "    run_pwm          -> PWM test"
echo "    run_integration  -> full system test"
echo "    run_all          -> all unit tests"
echo "  ================================================"
