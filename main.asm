;
; HVAC Project.asm
;
; Created: 5/19/2026 6:28:55 PM
; Author : Hp
;



; REGISTER ALIASES
; -------------------------------------------------------
.def V0   = r16       ; general purpose
.def V1   = r17       ; DHT temp result / ADC low
.def V2   = r18       ; DHT humidity result / ADC high
.def V3   = r19       ; loop counter
.def T1   = r20       ; temperature value
.def H1   = r21       ; humidity value
.def MQH  = r22       ; gas sensor ADC high byte
.def CSH  = r23       ; current sensor ADC high byte
.def TMP  = r24       ; scratch register
.def TMP2 = r25       ; scratch register 2

; -------------------------------------------------------
; LCD PIN MAPPING (PORTC)
; LCD D4-D7 -> PC4-PC7
; LCD RS    -> PC0
; LCD EN    -> PC1
; LCD RW    -> PC2 (tied LOW, write only)
; -------------------------------------------------------
.equ LCD_RS  = PC0
.equ LCD_EN  = PC1
.equ LCD_RW  = PC2

; -------------------------------------------------------
; OTHER PIN MAPPING
; PB0 = Alarm LED / Buzzer
; PB1 = Status LED
; PB3 = Fan PWM (OC0)
; PD2 = DHT22 data
; PB5 = Servo (OC1A)
; ADC0 = MQ gas sensor
; ADC1 = Current sensor
; -------------------------------------------------------

.org 0x00
    rjmp RESET

; -------------------------------------------------------
; RESET — INIT EVERYTHING
; -------------------------------------------------------
RESET:
    ; Stack pointer
    ldi V0, high(RAMEND)
    out SPH, V0
    ldi V0, low(RAMEND)
    out SPL, V0

    ; --- ADC INIT ---
    ldi V0, (1<<REFS0)
    out ADMUX, V0
    ldi V0, (1<<ADEN)|(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0)
    out ADCSRA, V0

    ; --- TIMER0: Fan PWM (Fast PWM, non-inverting, prescaler 8) ---
    ldi V0, (1<<WGM00)|(1<<WGM01)|(1<<COM01)|(1<<CS01)
    out TCCR0, V0
    ldi V0, 0
    out OCR0, V0

    ; --- TIMER1: Servo PWM (Fast PWM 16-bit, ICR1 top, prescaler 8) ---
    ldi V0, (1<<WGM11)|(1<<COM1A1)
    out TCCR1A, V0
    ldi V0, (1<<WGM13)|(1<<WGM12)|(1<<CS11)
    out TCCR1B, V0
    ldi V0, low(20000)
    out ICR1L, V0
    ldi V0, high(20000)
    out ICR1H, V0
    ldi V0, low(1500)
    out OCR1AL, V0
    ldi V0, high(1500)
    out OCR1AH, V0

    ; --- OUTPUT PINS: PB0 (alarm), PB1 (LED), PB3 (fan PWM), PB5 (servo) ---
    ldi V0, (1<<PB0)|(1<<PB1)|(1<<PB3)|(1<<PB5)
    out DDRB, V0

    ; --- LCD INIT: PORTC all output ---
    ldi V0, 0xFF
    out DDRC, V0
    ldi V0, 0x00
    out PORTC, V0

    ; small startup delay
    rcall DELAY_200MS
    rcall DELAY_200MS

    ; --- initialise LCD ---
    rcall LCD_INIT

    ; splash screen
    rcall LCD_CLEAR
    ldi ZH, high(STR_TITLE<<1)
    ldi ZL, low(STR_TITLE<<1)
    rcall LCD_PRINT_PGMEM
    rcall DELAY_200MS
    rcall DELAY_200MS
    rcall DELAY_200MS

; -------------------------------------------------------
; MAIN LOOP
; -------------------------------------------------------
MAIN:
    ; read DHT22
    rcall READ_DHT22
    mov T1, V1        ; temperature
    mov H1, V2        ; humidity

    ; read MQ gas sensor (ADC channel 0)
    ldi V0, 0
    rcall ADC_READ
    mov MQH, V2       ; high byte = rough magnitude

    ; read current sensor (ADC channel 1)
    ldi V0, 1
    rcall ADC_READ
    mov CSH, V2

    ; ---------- DECISION LOGIC ----------
    cpi MQH, 1
    brge GAS_FAULT

    cpi CSH, 3
    brge CUR_FAULT

    cpi T1, 30
    brge HIGH_TEMP

    ; --- NORMAL STATE ---
    ldi V0, 80
    out OCR0, V0                  ; fan low speed
    ldi V0, low(1000)
    out OCR1AL, V0
    clr V0
    out OCR1AH, V0                ; servo neutral
    cbi PORTB, PB0                ; alarm off
    cbi PORTB, PB1                ; status LED off
    rcall DISPLAY_NORMAL
    rjmp LOOP_END

HIGH_TEMP:
    ldi V0, 200
    out OCR0, V0                  ; fan high speed
    ldi V0, low(2000)
    out OCR1AL, V0
    clr V0
    out OCR1AH, V0                ; servo open vent
    sbi PORTB, PB0                ; alarm on
    sbi PORTB, PB1                ; status LED on
    rcall DISPLAY_HIGH_TEMP
    rjmp LOOP_END

GAS_FAULT:
    ldi V0, 255
    out OCR0, V0                  ; fan full speed
    ldi V0, low(2400)
    out OCR1AL, V0
    clr V0
    out OCR1AH, V0                ; servo fully open
    sbi PORTB, PB0
    sbi PORTB, PB1
    rcall DISPLAY_GAS_FAULT
    rjmp LOOP_END

CUR_FAULT:
    ldi V0, 255
    out OCR0, V0
    ldi V0, low(2400)
    out OCR1AL, V0
    clr V0
    out OCR1AH, V0
    sbi PORTB, PB0
    sbi PORTB, PB1
    rcall DISPLAY_CUR_FAULT
    rjmp LOOP_END

LOOP_END:
    rcall DELAY_200MS
    rjmp MAIN

; -------------------------------------------------------
; DISPLAY ROUTINES
; -------------------------------------------------------

; Normal: Line1 "T:XXC  H:XX%"  Line2 "Status: NORMAL"
DISPLAY_NORMAL:
    rcall LCD_CLEAR
    ; Line 1 — temperature and humidity
    ldi ZH, high(STR_T<<1)
    ldi ZL, low(STR_T<<1)
    rcall LCD_PRINT_PGMEM
    mov V0, T1
    rcall LCD_PRINT_BYTE_DEC
    ldi V0, 'C'
    rcall LCD_CHAR
    ldi V0, ' '
    rcall LCD_CHAR
    ldi ZH, high(STR_H<<1)
    ldi ZL, low(STR_H<<1)
    rcall LCD_PRINT_PGMEM
    mov V0, H1
    rcall LCD_PRINT_BYTE_DEC
    ldi V0, '%'
    rcall LCD_CHAR
    ; Line 2
    rcall LCD_LINE2
    ldi ZH, high(STR_NORMAL<<1)
    ldi ZL, low(STR_NORMAL<<1)
    rcall LCD_PRINT_PGMEM
    ret

; High temp: Line1 "T:XXC HIGH!" Line2 "Fan: FULL"
DISPLAY_HIGH_TEMP:
    rcall LCD_CLEAR
    ldi ZH, high(STR_T<<1)
    ldi ZL, low(STR_T<<1)
    rcall LCD_PRINT_PGMEM
    mov V0, T1
    rcall LCD_PRINT_BYTE_DEC
    ldi V0, 'C'
    rcall LCD_CHAR
    ldi ZH, high(STR_HIGH<<1)
    ldi ZL, low(STR_HIGH<<1)
    rcall LCD_PRINT_PGMEM
    rcall LCD_LINE2
    ldi ZH, high(STR_FAN_FULL<<1)
    ldi ZL, low(STR_FAN_FULL<<1)
    rcall LCD_PRINT_PGMEM
    ret

; Gas fault: Line1 "GAS DETECTED!" Line2 "EVACUATE NOW!"
DISPLAY_GAS_FAULT:
    rcall LCD_CLEAR
    ldi ZH, high(STR_GAS<<1)
    ldi ZL, low(STR_GAS<<1)
    rcall LCD_PRINT_PGMEM
    rcall LCD_LINE2
    ldi ZH, high(STR_EVACUATE<<1)
    ldi ZL, low(STR_EVACUATE<<1)
    rcall LCD_PRINT_PGMEM
    ret

; Current fault: Line1 "OVERCURRENT!" Line2 "Check circuit"
DISPLAY_CUR_FAULT:
    rcall LCD_CLEAR
    ldi ZH, high(STR_OVERCUR<<1)
    ldi ZL, low(STR_OVERCUR<<1)
    rcall LCD_PRINT_PGMEM
    rcall LCD_LINE2
    ldi ZH, high(STR_CHECKCIR<<1)
    ldi ZL, low(STR_CHECKCIR<<1)
    rcall LCD_PRINT_PGMEM
    ret

; -------------------------------------------------------
; LCD DRIVER — 4-BIT MODE, HD44780 COMPATIBLE
; PORTC: RS=PC0, EN=PC1, RW=PC2, D4-D7=PC4-PC7
; -------------------------------------------------------

LCD_INIT:
    rcall DELAY_200MS         ; wait for LCD power on

    ; send 0x03 three times to force 8-bit reset sequence
    ldi V0, 0x03
    rcall LCD_SEND_NIBBLE_CMD
    rcall DELAY_1MS
    rcall DELAY_1MS
    rcall DELAY_1MS
    rcall DELAY_1MS
    rcall DELAY_1MS

    ldi V0, 0x03
    rcall LCD_SEND_NIBBLE_CMD
    rcall DELAY_1MS
    rcall DELAY_1MS

    ldi V0, 0x03
    rcall LCD_SEND_NIBBLE_CMD
    rcall DELAY_1MS

    ; switch to 4-bit mode
    ldi V0, 0x02
    rcall LCD_SEND_NIBBLE_CMD
    rcall DELAY_1MS

    ; function set: 4-bit, 2 lines, 5x8 font
    ldi V0, 0x28
    rcall LCD_CMD
    ; display on, cursor off, blink off
    ldi V0, 0x0C
    rcall LCD_CMD
    ; clear display
    ldi V0, 0x01
    rcall LCD_CMD
    rcall DELAY_1MS
    rcall DELAY_1MS
    ; entry mode: increment, no shift
    ldi V0, 0x06
    rcall LCD_CMD
    ret

; send command byte to LCD
LCD_CMD:
    ; RS = 0 (command), send high nibble then low nibble
    mov TMP, V0
    swap TMP
    andi TMP, 0x0F
    rcall LCD_SEND_NIBBLE_CMD
    mov TMP, V0
    andi TMP, 0x0F
    rcall LCD_SEND_NIBBLE_CMD
    rcall DELAY_1MS
    ret

; send data byte to LCD (character)
LCD_CHAR:
    mov TMP, V0
    swap TMP
    andi TMP, 0x0F
    rcall LCD_SEND_NIBBLE_DATA
    mov TMP, V0
    andi TMP, 0x0F
    rcall LCD_SEND_NIBBLE_DATA
    rcall DELAY_US_40
    ret

; send high nibble as COMMAND (RS=0)
LCD_SEND_NIBBLE_CMD:
    ; build PORTC value: D7-D4 = TMP bits 3-0, RS=0, EN=0
    mov V0, TMP
    swap V0
    andi V0, 0xF0         ; shift data to upper nibble
    out PORTC, V0         ; set data, RS=0, EN=0
    ori V0, (1<<LCD_EN)
    out PORTC, V0         ; EN high
    rcall DELAY_US_40
    andi V0, ~(1<<LCD_EN)
    out PORTC, V0         ; EN low
    rcall DELAY_US_40
    ret

; send nibble as DATA (RS=1)
LCD_SEND_NIBBLE_DATA:
    mov V0, TMP
    swap V0
    andi V0, 0xF0
    ori V0, (1<<LCD_RS)   ; RS = 1 for data
    out PORTC, V0
    ori V0, (1<<LCD_EN)
    out PORTC, V0         ; EN high
    rcall DELAY_US_40
    andi V0, ~(1<<LCD_EN)
    out PORTC, V0         ; EN low
    rcall DELAY_US_40
    ret

; clear LCD
LCD_CLEAR:
    ldi V0, 0x01
    rcall LCD_CMD
    rcall DELAY_1MS
    rcall DELAY_1MS
    ret

; move cursor to start of line 2
LCD_LINE2:
    ldi V0, 0xC0
    rcall LCD_CMD
    ret

; print null-terminated string from program memory
; Z register holds address (<<1 shifted)
LCD_PRINT_PGMEM:
LCD_PGMEM_LOOP:
    lpm V0, Z+
    cpi V0, 0
    breq LCD_PGMEM_DONE
    rcall LCD_CHAR
    rjmp LCD_PGMEM_LOOP
LCD_PGMEM_DONE:
    ret

; print byte value in decimal (0-255) to LCD
; V0 = value to print
LCD_PRINT_BYTE_DEC:
    mov TMP, V0

    ; hundreds
    clr TMP2
LCD_HUND:
    cpi TMP, 100
    brlt LCD_HUND_DONE
    subi TMP, 100
    inc TMP2
    rjmp LCD_HUND
LCD_HUND_DONE:
    ; only print hundreds if non-zero
    tst TMP2
    breq LCD_TENS_START
    ldi V0, '0'
    add V0, TMP2
    rcall LCD_CHAR

LCD_TENS_START:
    ; tens
    clr TMP2
LCD_TENS:
    cpi TMP, 10
    brlt LCD_TENS_DONE
    subi TMP, 10
    inc TMP2
    rjmp LCD_TENS
LCD_TENS_DONE:
    ; only print tens if non-zero or hundreds was printed
    tst TMP2
    breq LCD_UNITS
    ldi V0, '0'
    add V0, TMP2
    rcall LCD_CHAR

LCD_UNITS:
    ldi V0, '0'
    add V0, TMP
    rcall LCD_CHAR
    ret

; -------------------------------------------------------
; ADC READ
; V0 = channel (0-7)
; returns: V1 = ADC low, V2 = ADC high
; -------------------------------------------------------
ADC_READ:
    mov TMP, V0
    andi TMP, 0x07
    in TMP2, ADMUX
    andi TMP2, 0xF8
    or TMP2, TMP
    out ADMUX, TMP2
    sbi ADCSRA, ADSC
WAITADC:
    in TMP, ADCSRA
    sbrc TMP, ADSC
    rjmp WAITADC
    in V1, ADCL
    in V2, ADCH
    ret

; -------------------------------------------------------
; DHT22 READ
; returns: V1 = temperature (integer part), V2 = humidity
; reads 2 bytes each, no checksum (simplified)
; -------------------------------------------------------
READ_DHT22:
    ; start signal: pull low 1ms, release
    sbi DDRD, PD2
    cbi PORTD, PD2
    rcall DELAY_1MS
    sbi PORTD, PD2
    cbi DDRD, PD2
    rcall DELAY_US_40

    ; wait for DHT response
    rcall DHT_WL
    rcall DHT_WH

    clr V1
    clr V2

    ; read TEMPERATURE byte (8 bits)
    ldi V3, 8
READ_TEMP_BIT:
    rcall DHT_WH
    rcall DELAY_US_40
    lsl V1
    sbis PIND, PD2
    rjmp TEMP_SKIP
    ori V1, 1
TEMP_SKIP:
    rcall DHT_WL
    dec V3
    brne READ_TEMP_BIT

    ; read HUMIDITY byte (8 bits)
    ldi V3, 8
READ_HUM_BIT:
    rcall DHT_WH
    rcall DELAY_US_40
    lsl V2
    sbis PIND, PD2
    rjmp HUM_SKIP
    ori V2, 1
HUM_SKIP:
    rcall DHT_WL
    dec V3
    brne READ_HUM_BIT
    ret

; wait for DHT line to go HIGH
DHT_WH:
    sbis PIND, PD2
    rjmp DHT_WH
    ret

; wait for DHT line to go LOW
DHT_WL:
    sbic PIND, PD2
    rjmp DHT_WL
    ret

; -------------------------------------------------------
; DELAYS (assumes 8 MHz clock)
; -------------------------------------------------------
DELAY_1MS:
    ldi V0, 250
MS1:
    ldi V3, 4
MS2:
    dec V3
    brne MS2
    dec V0
    brne MS1
    ret

DELAY_US_40:
    ldi V0, 40
U40:
    dec V0
    brne U40
    ret

DELAY_200MS:
    ldi V0, 200
D200:
    rcall DELAY_1MS
    dec V0
    brne D200
    ret

; -------------------------------------------------------
; STRING TABLE (program memory)
; -------------------------------------------------------
STR_TITLE:   .db "  HVAC SYSTEM  ", 0
STR_T:       .db "T:", 0
STR_H:       .db "  H:", 0
STR_NORMAL:  .db "Status: NORMAL  ", 0
STR_HIGH:    .db "C HIGH!  ", 0
STR_FAN_FULL:.db "Fan: FULL SPEED ", 0
STR_GAS:     .db "GAS DETECTED!   ", 0
STR_EVACUATE:.db "EVACUATE NOW!   ", 0
STR_OVERCUR: .db "OVERCURRENT!    ", 0
STR_CHECKCIR:.db "Check Circuit   ", 0
