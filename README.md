# FPGA Embedded Sensor Hub
### VHDL | Basys3 (Artix-7) | BME280 | UART | SPI | PWM

---

## معرفی پروژه

یک سیستم embedded کامل روی FPGA که:
- دما و رطوبت را از سنسور **BME280** از طریق **SPI** می‌خواند
- داده‌ها را هر 1 ثانیه از طریق **UART** به PC ارسال می‌کند
- روشنایی LED را با **PWM** بر اساس دما کنترل می‌کند

---

## ساختار پروژه

```
fpga_sensor_hub/
├── src/
│   ├── top.vhd          ← Top-level integration
│   ├── sensor_ctrl.vhd  ← Main FSM controller
│   ├── spi_master.vhd   ← SPI Mode 0 master
│   ├── uart_tx.vhd      ← UART transmitter (115200 baud)
│   ├── uart_rx.vhd      ← UART receiver
│   └── pwm_gen.vhd      ← 8-bit PWM generator
├── tb/
│   └── uart_tx_tb.vhd   ← UART testbench
├── constraints/
│   └── basys3.xdc       ← Pin assignments (Basys3)
└── README.md
```

---

## مشخصات فنی

| ماژول       | پارامتر          | مقدار       |
|-------------|------------------|-------------|
| Clock       | System clock     | 100 MHz     |
| UART        | Baud rate        | 115200 bps  |
| SPI         | Clock speed      | 1 MHz       |
| PWM         | Frequency        | 1 kHz       |
| PWM         | Resolution       | 8-bit       |
| Sampling    | Sensor read rate | 1 Hz        |
| FPGA Target | Board            | Basys3      |
| FPGA Target | Device           | XC7A35T-1   |

---

## سخت‌افزار مورد نیاز

- Digilent Basys3 (یا Nexys4)
- BME280 breakout board (مثلاً از Adafruit یا SparkFun)
- 4 سیم jumper برای اتصال Pmod JA

### اتصال BME280 به Pmod JA

| BME280 Pin | Pmod JA | FPGA Pin |
|------------|---------|----------|
| VCC        | VCC (3.3V) | -     |
| GND        | GND     | -        |
| SDI (MOSI) | JA1     | J1       |
| SDO (MISO) | JA2     | L2       |
| CSB (CS)   | JA3     | J2       |
| SCK        | JA4     | G2       |

---

## راه‌اندازی در Vivado

```tcl
# ایجاد پروژه
create_project sensor_hub ./vivado -part xc7a35tcpg236-1

# اضافه کردن فایل‌های سورس
add_files {src/top.vhd src/sensor_ctrl.vhd src/spi_master.vhd}
add_files {src/uart_tx.vhd src/uart_rx.vhd src/pwm_gen.vhd}
add_files -fileset constrs_1 constraints/basys3.xdc

# تنظیم top module
set_property top top [current_fileset]

# Run synthesis & implementation
launch_runs synth_1 -jobs 4
launch_runs impl_1 -to_step write_bitstream -jobs 4
```

---

## تست با PC

پس از برنامه‌ریزی FPGA، با ترمینال به UART وصل شوید:

```bash
# Linux
screen /dev/ttyUSB1 115200

# یا با Python
python3 -c "
import serial
s = serial.Serial('/dev/ttyUSB1', 115200)
while True:
    line = s.readline().decode()
    print(line, end='')
"
```

خروجی مورد انتظار:
```
T:25C H:60%
T:25C H:61%
T:26C H:59%
```

---

## آنچه در رزومه بنویسید

> Designed a complete FPGA-based embedded sensor hub in VHDL on Xilinx Artix-7 (Basys3),
> implementing SPI master controller for BME280 environmental sensor, UART serial interface
> at 115200 bps, 8-bit PWM generator for LED control, and a hierarchical FSM-based
> architecture. Verified design with ModelSim testbenches and achieved timing closure
> at 100 MHz system clock.

---

## ایده‌های توسعه (v2)

- [ ] اضافه کردن SD Card logging (SPI)
- [ ] نمایش روی 7-segment display
- [ ] AXI4-Lite interface (آماده برای Zynq)
- [ ] چند سنسور موازی (Multi-CS SPI)
- [ ] FIFO buffer برای داده‌ها
- [ ] I2C در کنار SPI
