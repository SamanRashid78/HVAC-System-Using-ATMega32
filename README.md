# HVAC Control System — ATmega32 / AVR Assembly

An embedded HVAC controller written in AVR Assembly for the ATmega32 microcontroller. Monitors temperature, humidity, and gas levels in real time and drives actuators automatically based on threshold logic. Displays live readings and system status on a 16x2 LCD.

---

## What It Does

The system continuously reads three sensors and responds in one of four states:

| State | Condition | Fan | Servo | Alarm | LCD |
|---|---|---|---|---|---|
| Normal | Temp < 30°C, no gas, normal current | Low (31%) | Neutral | Off | T/H readings |
| High Temp | Temp ≥ 30°C | High (78%) | Open vent | On | HIGH TEMP warning |
| Gas Fault | Gas sensor triggered | Full (100%) | Fully open | On | EVACUATE NOW |
| Current Fault | Overcurrent detected | Full (100%) | Fully open | On | Check Circuit |

---

## Hardware

| Component | Pin |
|---|---|
| DHT22 (temp/humidity) | PD2 |
| MQ gas sensor | ADC0 (PA0) |
| Current sensor (ACS712) | ADC1 (PA1) |
| DC Fan (PWM via L293D) | PB3 (OC0) |
| Servo motor | PB5 (OC1A) |
| Alarm LED / Buzzer | PB0 |
| Status LED | PB1 |
| LCD RS | PC0 |
| LCD EN | PC1 |
| LCD D4–D7 | PC4–PC7 |

---

## How It Works

1. ATmega32 initialises ADC, Timer0 (fan PWM), Timer1 (servo PWM), and the LCD
2. Main loop reads DHT22 for temperature and humidity
3. MQ sensor and current sensor read via ADC
4. Control logic checks thresholds and sets fan duty cycle, servo position, and alarm state
5. LCD updates each cycle showing sensor values and current system state

---

## Files

```
hvac-atmega32/
├── main.asm          ← full AVR Assembly source
├── HVAC Project.hex   ← compiled hex (flash directly to ATmega32)
├── HVAC Project.pdsprj← Proteus simulation project
├──  HVAC Project.atsln ← Atmel Studio 7 Solution File
├── circuit.png ← Screenshot of the proteus circuit
└── README.md
```

---

## How to Run

**Simulation (Proteus):**
1. Open `HVAC Project.pdsprj` in Proteus 8
2. Load `HVAC Project.hex` into the ATmega32 component
3. Run simulation

**Physical hardware:**
1. Open `main.asm` in Atmel Studio 7
2. Build project (F7)
3. Flash hex to ATmega32 via USBasp or AVRISP mkII

---

## Tools Used

- Atmel Studio 7 (AVR Assembly)
- Proteus 8 (simulation)
- ATmega32 microcontroller
- AVR instruction set (ATmega32)

## What I Learned

- Bare-metal peripheral control: ADC, Timer PWM, GPIO in Assembly
- 4-bit LCD driver implementation from scratch using HD44780 protocol
- DHT22 single-wire protocol timing at register level
- Multi-condition FSM design in embedded systems
