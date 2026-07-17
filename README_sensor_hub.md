# FPGA Embedded Sensor Hub — BME280 over SPI (VHDL)

A fully synthesizable embedded sensor acquisition system implemented in VHDL, targeting the Basys3 (Artix-7) development board. The design reads temperature and humidity data from a **BME280** sensor via SPI, streams formatted readings to a host PC over UART, and drives an LED with PWM brightness proportional to the measured temperature — all orchestrated by a hierarchical, multi-FSM architecture.

---

## System Architecture

```
                        ┌──────────────────────────────────────────────────┐
                        │                   top.vhd                         │
                        │                                                    │
  [BME280 Sensor] ──SPI──►  spi_master  ◄──►  sensor_ctrl  ──►  uart_tx ──► [Host PC]
                        │        ▲              (Main FSM)                   │
                        │        │                  │                        │
                        │    SPI signals        pwm_duty                     │
                        │                           ▼                        │
                        │                      pwm_gen ──► pwm_led (LD0)    │
                        │                                                    │
                        │   status_leds (LD1–LD4) ◄── FSM state debug       │
                        └──────────────────────────────────────────────────┘
```

The top level (`top.vhd`) uses **structural architecture** — all modules are instantiated as components and connected via internal signals. No logic lives in the top level itself.

---

## Key Features

| Feature | Detail |
|---|---|
| **Sensor** | BME280 — Temperature, Humidity, Pressure (Bosch) |
| **Interface** | SPI Mode 0 (CPOL=0, CPHA=0), 1 MHz clock |
| **UART Output** | 115200 baud, 8N1 — streams `T:XXC` formatted readings |
| **PWM LED** | 8-bit resolution, 1 kHz — brightness tracks temperature |
| **Sampling Rate** | Configurable via `SAMPLE_MS` generic (default: 1 second) |
| **Architecture** | Structural top-level, behavioral sub-modules |
| **Language** | VHDL (IEEE 1076-2008) |
| **Target** | Basys3 — Xilinx Artix-7 XC7A35T, 100 MHz clock |

---

## Module Breakdown

### `sensor_ctrl.vhd` — Main Controller (Dual FSM)
The brain of the system. Contains two concurrent FSMs:

**Control FSM** — manages the full sensor acquisition sequence:
```
INIT_CONFIG → WAIT_INIT → IDLE_WAIT → READ_TEMP_ADDR → READ_TEMP_MSB
           → READ_TEMP_LSB → READ_TEMP_XLSB → READ_HUM_ADDR
           → READ_HUM_MSB → READ_HUM_LSB → SEND_UART → (back to IDLE_WAIT)
```
- Configures BME280 at startup (ctrl_meas register: normal mode, oversampling ×1)
- Issues SPI transactions byte-by-byte following BME280's register map
- Derives PWM duty cycle directly from raw temperature MSB
- Triggers UART transmission after each complete sensor read

**UART FSM** — serializes formatted output independently:
```
U_IDLE → U_SEND_T → U_SEND_VAL → U_SEND_H → U_SEND_HV → U_SEND_NL
```
- Sends ASCII string: `T:XX\r\n`
- Uses an internal `to_ascii_digit()` function for integer-to-ASCII conversion
- Decoupled from the main FSM via a `send_uart_trigger` handshake signal

### `spi_master.vhd` — Generic SPI Master (Mode 0)
Full-duplex 8-bit SPI controller with configurable clock frequency.

- **Clock divider:** `CLK_DIV = CLK_FREQ / (2 × SPI_FREQ)` — calculated at elaboration
- **4-state FSM:** `IDLE → ASSERT_CS → TRANSFER → DEASSERT_CS`
- Samples MISO on rising edge, shifts MOSI on falling edge (Mode 0 compliant)
- Exposes `busy` and `done` strobes for clean handshaking with `sensor_ctrl`

### `pwm_gen.vhd` — Parameterized PWM Generator
8-bit resolution PWM with fully generic frequency and clock.

- `PERIOD = CLK_FREQ / PWM_FREQ` — computed at synthesis
- `duty_level = (duty × PERIOD) / 255` — linear scaling
- Default: 1 kHz PWM @ 100 MHz → 100,000 counts per period

### `uart_tx.vhd` / `uart_rx.vhd` — UART Transceivers
Standard 8N1 UART with generics for clock frequency and baud rate.

- Baud counter: `WAIT_COUNT = CLK_FREQ / BAUD_RATE`
- `uart_tx` exposes `tx_busy` and `tx_done` for FSM-level flow control
- `uart_rx` available for future bidirectional command interface

---

## Pin Mapping (Basys3)

| Signal | FPGA Pin | Description |
|---|---|---|
| `clk` | W5 | 100 MHz onboard oscillator |
| `rst` | T18 | Center button (BTNC), active-high |
| `uart_tx_pin` | A18 | USB-UART TX |
| `uart_rx_pin` | B18 | USB-UART RX |
| `spi_sclk` | JA4 | SPI clock to BME280 |
| `spi_mosi` | JA1 | SPI data out |
| `spi_miso` | JA2 | SPI data in |
| `spi_cs_n` | JA3 | Chip select (active-low) |
| `pwm_led` | V17 | LD0 — brightness = temperature |
| `status_leds` | U16–V14 | LD1–LD4 — FSM state debug |

---

## Generics Reference

| Generic | Module | Default | Description |
|---|---|---|---|
| `CLK_FREQ` | all | 100_000_000 | System clock in Hz |
| `BAUD_RATE` | uart_tx/rx | 115_200 | Serial baud rate |
| `SPI_FREQ` | spi_master | 1_000_000 | SPI clock in Hz (max BME280: 10 MHz) |
| `DATA_WIDTH` | spi_master | 8 | SPI transaction width in bits |
| `SAMPLE_MS` | sensor_ctrl | 1000 | Sensor sampling interval in ms |
| `PWM_FREQ` | pwm_gen | 1_000 | PWM carrier frequency in Hz |
| `RESOLUTION` | pwm_gen | 8 | PWM bit depth (256 steps) |

---

## UART Output Format

Data is streamed as ASCII at 115200 baud. Each sample produces one line:

```
T:25C
T:26C
```

Connect with any serial terminal (PuTTY, minicom, screen) at **115200 8N1**.

---

## BME280 Register Map Used

| Register | Address | Purpose |
|---|---|---|
| `CHIP_ID` | 0xD0 | Verify sensor identity (returns 0x60) |
| `ctrl_meas` | 0xF4 | Set oversampling and power mode |
| `temp_msb` | 0xFA | Temperature raw data [19:12] |
| `temp_lsb` | 0xFB | Temperature raw data [11:4] |
| `temp_xlsb`| 0xFC | Temperature raw data [3:0] |
| `hum_msb` | 0xFD | Humidity raw data [15:8] |
| `hum_lsb` | 0xFE | Humidity raw data [7:0] |

> **Note:** This design reads raw ADC values. Full temperature compensation (using the BME280 calibration registers and the compensation formula from the datasheet) is a planned extension.

---

## Simulation

The testbench (`uart_tx_tb.vhd`) verifies the UART transmitter timing and framing.

**Run with ModelSim / QuestaSim:**
```bash
vlib work
vcom pwm_gen.vhd spi_master.vhd uart_rx.vhd uart_tx.vhd \
     sensor_ctrl.vhd top.vhd uart_tx_tb.vhd
vsim -t 1ns tb_uart_tx
run -all
```

---

## File Structure

```
├── top.vhd           # Structural top-level — instantiates all modules
├── sensor_ctrl.vhd   # Main controller: dual FSM (acquisition + UART formatting)
├── spi_master.vhd    # Generic SPI Mode 0 master
├── pwm_gen.vhd       # Parameterized 8-bit PWM generator
├── uart_tx.vhd       # UART transmitter (8N1)
├── uart_rx.vhd       # UART receiver (8N1)
└── uart_tx_tb.vhd    # UART transmitter testbench
```

---

## Planned Extensions

- Full BME280 compensation formula (calibration register readout + fixed-point arithmetic)
- Pressure channel integration (3-byte burst read from 0xF7)
- Bidirectional UART: accept sample rate commands from host PC
- Data logging over SPI to external Flash

---

## Target Platform

- **Board:** Basys3 (Xilinx Artix-7 XC7A35T)
- **Toolchain:** Vivado 2023.x
- **Simulation:** ModelSim / QuestaSim
- **Clock:** 100 MHz system clock

---

## Author

**Parsa hoseinzadeh** — Embedded Systems & FPGA Design Engineer  
[LinkedIn](https://linkedin.com/in/parsa-hoseinzadeh-86a158166) | [GitHub](https://github.com/Parsajan)
