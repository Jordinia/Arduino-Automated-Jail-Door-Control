;--------------------------------------
; Automated Jail Door Control (Master)
;--------------------------------------

#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global main

main:
  RCALL init_IO
  RCALL init_ADC
  RCALL I2C_init
  RCALL LCD_init
  RCALL delay_sec  
  RCALL LCD_start_message
  RCALL delay_sec

  LDI R28, 0x00   ; mode = 0 for command 
  LDI R27, 0x02   ; return home  
  RCALL LCD_sendChar
  RCALL delay_ms
  RCALL LCD_temp_message

  LDI R28, 0x00   ; mode = 0 for command 
  LDI R27, 0xC0   ; move cursor to line 2  
  RCALL LCD_sendChar
  RCALL delay_ms  
  RCALL LCD_light_message

again:
  LDI R30, 0x00      ; clear fire_alarm flag
  LDI R31, 0x00      ; clear night flag
  RCALL delay_sec
  RCALL Read_DHT11   ; subroutines for read DHT11
  RCALL read_ADC	   ; subroutines for reading photoresistor
  
  SBRC R31, 7
  RJMP again  
  RCALL read_button  ; subroutines for button input & it's output
  RJMP again ; loop back

;=================================================================
;       I/O Subroutines
;=================================================================
init_IO:
  LDI R21, 0xFF   ; output for door LED & motor pin D
  OUT DDRD, R21

  LDI R21, 0x01   ; input for button & output for LED pin B
  OUT DDRB, R21

  LDI R21, 0x00
  OUT PORTD, R21  ; default condition (close all door)
  RET

read_button:
  SBIC PINB, 5
  RCALL emergency_trigger_close
  SBIC PINB, 4
  RCALL door_A_trigger
  SBIC PINB, 3
  RCALL door_B_trigger
  SBIC PINB, 2
  RCALL door_C_trigger
  RET
  
emergency_trigger_open:
  IN R12, PORTD
  SBRS R12, 6
  SBI PORTD, 7
  SBRS R12, 3
  SBI PORTD, 4
  SBRS R12, 0
  SBI PORTD, 1
  RCALL delay_sec
  LDI R31, 0xFF
  OUT PORTD, R31
  RCALL motor_stop
  RET

emergency_trigger_close:
  IN R12, PORTD
  SBRC R12, 6
  SBI PORTB, 0
  SBRC R12, 3
  SBI PORTD, 5
  SBRC R12, 0
  SBI PORTD, 2
  RCALL delay_sec
  CBI PORTB, 0
  LDI R30, 0x00
  OUT PORTD, R30
  RET

door_A_trigger:
  IN R12, PORTD
  RCALL motor_A_trigger
  RCALL delay_sec
  RCALL motor_stop
  LDI R31, 0b01000000
  EOR R12, R31
  OUT PORTD, R12
  RET

door_B_trigger:
  IN R12, PORTD
  RCALL motor_B_trigger
  LDI R31, 0b00001000
  EOR R12, R31
  OUT PORTD, R12
  RET

door_C_trigger:
  IN R12, PORTD
  RCALL motor_C_trigger
  LDI R31, 0b00000001
  EOR R12, R31
  OUT PORTD, R12
  RET

motor_A_trigger:
  SBRS R12, 6
  RCALL motor_A_open
  SBRC R12, 6
  RCALL motor_A_close
  RET
motor_A_close:
  SBI PORTB, 0
  RET
motor_A_open:
  SBI PORTD, 7
  RET


motor_B_trigger:
  SBRS R12, 3
  RCALL motor_B_open
  SBRC R12, 3
  RCALL motor_B_close
  RET
motor_B_close:
  SBI PORTD, 5
  RCALL delay_sec
  CBI PORTD, 5
  RET
motor_B_open:
  SBI PORTD, 4
  RCALL delay_sec
  CBI PORTD, 4
  RET

motor_C_trigger:
  SBRS R12, 0
  RCALL motor_C_open
  SBRC R12, 0
  RCALL motor_C_close
  RET
motor_C_close:
  SBI PORTD, 2
  RCALL delay_sec
  CBI PORTD, 2
  RET
motor_C_open:
  SBI PORTD, 1
  RCALL delay_sec
  CBI PORTD, 1
  RET

  
motor_stop:
  CBI PORTB, 0
  CBI PORTD, 1
  CBI PORTD, 2
  CBI PORTD, 4
  CBI PORTD, 5
  CBI PORTD, 7
  RET




;=================================================================
;                     Read Photoresistor Data
; Photoresistor Pin -> Analog Pin 0 (PC0)
;=================================================================

init_ADC:
  SBI DDRC, 0 ;set pin PC0 as i/p for ADC0
  LDI R20, 0xC0 ;internal 2.56V, right-justified data, ADC0
  STS ADMUX, R20
  LDI R20, 0x87 ;enable ADC, ADC prescaler CLK/128
  STS ADCSRA, R20
  RET
read_ADC:
    LDI   R20, 0xC7       ;set ADSC in ADCSRA to start conversion
    STS   ADCSRA, R20
    ;-------------------------------------------------------------------
wait_ADC:
    LDS   R21, ADCSRA     ;check ADIF flag in ADCSRA
    SBRS  R21, 4          ;skip jump when conversion is done (flag set)
    RJMP  wait_ADC        ;loop until ADIF flag is set
    ;------------------------------------------------------------------
    LDI   R17, 0xD7       ;set ADIF flag again
    STS   ADCSRA, R17     ;so that controller clears ADIF
    ;------------------------------------------------------------------
    LDS   R15, ADCL       ;get low-byte result from ADCL
    LDS   R13, ADCH       ;get high-byte result from ADCH

    MOV   R12, R15        ; move ADCL result to unused register
    RCALL LCD_disp_light  ; display to LCD

    SBRC R31, 1
    RJMP again
    RCALL determine_if_light
    ;-----------------------------------------------------------------
    RET

;=================================================================
;  	For Determining the Photoresistor Intensity
;	  Uses REGISTER to store result 
;=================================================================

determine_if_light:
  MOV R31, R15
	CPI R31, 0x10
	BRSH open_door_unlocked

open_door_locked:
  RCALL emergency_trigger_close
  LDI R31, 0xFF
	RET
open_door_unlocked:
  RET
  

;=================================================================
;                     Read DHT11 Data
; DHT11 Pin -> Digital Pin 9 (PB1)
;=================================================================

Read_DHT11:
  ;------------------Send Signal Start-------------------
  SBI DDRB, 1 ;pin PB1 as o/p
  CBI PORTB, 1 ;first, send low pulse
  RCALL delay_20ms ;for 20ms
  SBI PORTB, 1 ;then send high pulse
  CBI DDRB, 1 ;pin PB1 as i/p

  ;------------------Wait for respond-------------------
  w1: SBIC PINB, 1
  RJMP w1 ;wait for DHT11 low pulse
  w2: SBIS PINB, 1
  RJMP w2 ;wait for DHT11 high pulse
  w3: SBIC PINB, 1
  RJMP w3 ;wait for DHT11 low pulse
  
  ;-------------------Read DHT11-------------------  
  RCALL DHT11_reading ;read integer humidity (1st byte of 40-bit data)
  RCALL DHT11_reading ;read decimal humidity (2nd byte of 40-bit data)
  RCALL DHT11_reading ;read integer temp (3rd byte of 40-bit data)
  MOV R29, R18    ; for LCD data register
  RCALL DHT11_reading ;read decimal temp (4th byte of 40-bit data)
  RCALL LCD_disp_temp
  RCALL fire_alert
  RET

fire_alert:
  CPI R29, 0x28
  BRSH fire_trigger_open
  RET

fire_trigger_open:
  LDI R30, 0xFF
  RCALL emergency_trigger_open
  RET

;=================================================================
;   For Reading the DHT11
;=================================================================
DHT11_reading:
  LDI R17, 8 ;set counter for receiving 8 bits
  CLR R18 ;clear data register
  ;-------------------------------------------------------
w4:
  SBIS PINB, 1
  RJMP w4 ;detect data bit (high pulse)
  RCALL delay_timer0 ;wait 50us & then check bit value
  ;-------------------------------------------------------
  SBIS PINB, 1 ;if received bit=1, skip next inst
  RJMP skp ;else, received bit=0, jump to skp
  SEC ;set carry flag (C=1)
  ROL R18 ;shift in 1 into LSB data register
  RJMP w5 ;jump & wait for low pulse
skp:
  LSL R18 ;shift in 0 into LSB data register
  ;-------------------------------------------------------
w5:
  SBIC PINB, 1
  RJMP w5 ;wait for DHT11 low pulse
  ;-------------------------------------------------------
  DEC R17 ;decrement counter
  BRNE w4 ;go back & detect next bit
  RET ;return to calling subroutine


;=================================================================
;     LCD Subroutines
;=================================================================
LCD_start_message:
  LDI R28, 1   ; mode = 1 for data 
  LDI R27, 'S'
  RCALL LCD_sendChar
  LDI R28, 1   ; mode = 1 for data 
  LDI R27, 'T'
  RCALL LCD_sendChar
  LDI R28, 1   ; mode = 1 for data 
  LDI R27, 'A'
  RCALL LCD_sendChar
  LDI R28, 1   ; mode = 1 for data 
  LDI R27, 'R'
  RCALL LCD_sendChar
  LDI R28, 1   ; mode = 1 for data 
  LDI R27, 'T'
  RCALL LCD_sendChar
  RCALL delay_sec
  LDI R28, 0x00   ; mode = 0 for command 
  LDI R27, 0x01   ; clear LCD
  RCALL LCD_sendChar
  RET
;=================================================================
LCD_temp_message:
  LDI R28, 1   ; mode = 1 for data 
  LDI R27, 'T'
  RCALL LCD_sendChar
  LDI R28, 1   ; mode = 1 for data 
  LDI R27, 'E'
  RCALL LCD_sendChar
  LDI R28, 1   ; mode = 1 for data 
  LDI R27, 'M'
  RCALL LCD_sendChar
  LDI R28, 1   ; mode = 1 for data 
  LDI R27, 'P'
  RCALL LCD_sendChar
  LDI R28, 1   ; mode = 1 for data 
  LDI R27, ':'
  RCALL LCD_sendChar
  LDI R28, 1   ; mode = 1 for data 
  LDI R27, ' '
  RCALL LCD_sendChar
  RET

LCD_light_message:
  LDI R28, 1   ; mode = 1 for data 
  LDI R27, 'L'
  RCALL LCD_sendChar
  LDI R28, 1   ; mode = 1 for data 
  LDI R27, 'I'
  RCALL LCD_sendChar
  LDI R28, 1   ; mode = 1 for data 
  LDI R27, 'G'
  RCALL LCD_sendChar
  LDI R28, 1   ; mode = 1 for data 
  LDI R27, 'H'
  RCALL LCD_sendChar
  LDI R28, 1   ; mode = 1 for data 
  LDI R27, 'T'
  RCALL LCD_sendChar
  LDI R28, 1   ; mode = 1 for data 
  LDI R27, ':'
  RCALL LCD_sendChar
  LDI R28, 1   ; mode = 1 for data 
  LDI R27, ' '
  RCALL LCD_sendChar
  RET

;=================================================================
LCD_init:
  ;initialize LCD for 4-bit data
  LDI R28, 0x00   ; mode = 0 for command 
  LDI R27, 0x33   
  RCALL LCD_sendChar
  RCALL delay_ms
  
  LDI R28, 0x00   ; mode = 0 for command 
  LDI R27, 0x32
  RCALL LCD_sendChar
  RCALL delay_ms
  ;-------------------------------------------------
  LDI R28, 0x00   ; mode = 0 for command 
  LDI R27, 0x28   ; LCD 2 lines, 5x7 matrix
  RCALL LCD_sendChar
  RCALL delay_ms
  ;-------------------------------------------------
  LDI R28, 0x00   ; mode = 0 for command 
  LDI R27, 0x0C   ; display ON, cursor OFF
  RCALL LCD_sendChar
  ;-------------------------------------------------
  LDI R28, 0x00   ; mode = 0 for command 
  LDI R27, 0x01   ; clear LCD
  RCALL LCD_sendChar
  RCALL delay_ms
  ;-------------------------------------------------
  LDI R28, 0x00   ; mode = 0 for command 
  LDI R27, 0x06   ; shift cursor right
  RCALL LCD_sendChar
  ;-------------------------------------------------
  RET

;==============================================================
LCD_disp_temp:
  LDI R28, 0x00   ; mode = 0 for command 
  LDI R27, 0x87   ; move cursor to line 1 position 6
  RCALL LCD_sendChar

  MOV R14, R29    ; copy result to R14
  MOV R16, R14    
  RCALL ASCII_MSD ; convert high-nibble to ASCII
  LDI R28, 1      ; mode = 1 for data 
  MOV R27, R16
  RCALL LCD_sendChar
  
  MOV R16, R14
  RCALL ASCII_LSD ; convert low-nibble to ASCII
  LDI R28, 1      ; mode = 1 for data 
  MOV R27, R16
  RCALL LCD_sendChar

  RET

LCD_disp_light:
  LDI R28, 0x00   ; mode = 0 for command 
  LDI R27, 0xC7   ; move cursor to line 2 position 6
  RCALL LCD_sendChar

  LDI R20, 48
  ADD R13, R20
  LDI R28, 1      ; mode = 1 for data 
  MOV R27, R13
  RCALL LCD_sendChar

  MOV R14, R12    ; copy result to R14
  MOV R16, R14    
  RCALL ASCII_MSD ; convert high-nibble to ASCII
  LDI R28, 1      ; mode = 1 for data 
  MOV R27, R16
  RCALL LCD_sendChar
  
  MOV R16, R14
  RCALL ASCII_LSD ; convert low-nibble to ASCII
  LDI R28, 1      ; mode = 1 for data 
  MOV R27, R16
  RCALL LCD_sendChar

  RET

;==============================================================
PCF8574_sendByte:
  RCALL I2C_start   ; send START condition
  LDI R24, 0x4E     ; send write address of PCF8574
  RCALL I2C_write
  MOV R24, R25      ; send data byte
  RCALL I2C_write
  RCALL I2C_stop    ; send STOP condition
  RET
;=============================================================
send4Bits:
  MOV R25, R26
  RCALL PCF8574_sendByte
  MOV R19, R26
  ORI R19, 0b00000100
  MOV R25, R19
  RCALL PCF8574_sendByte
  RCALL delay_short

  MOV R19, R26
  ANDI R19, ~(0b00000100)
  MOV R25, R19
  RCALL PCF8574_sendByte
  RCALL delay_ms
  RET

;==============================================================
LCD_sendChar:
  MOV R18, R27
  ANDI R27, 0xF0    ; get high-nibble
  OR R27, R28       ; ORed with MODE
  MOV R26, R27
  RCALL send4Bits

  MOV R27, R18
  LSL R27
  LSL R27
  LSL R27
  LSL R27
  ANDI R27, 0xF0    ; get low-nibble

  OR R27, R28       ; ORed with MODE
  MOV R26, R27
  RCALL send4Bits  
  RET
;=================================================================



;=================================================================
;     I2C Subroutines
;=================================================================
I2C_init:
    LDI   R21, 0
    STS   TWSR, R21       ;prescaler = 0
    LDI   R21, 72
    STS   TWBR, R21       ;SCK freq = 100kHz
    LDI   R21, (1<<TWEN)
    STS   TWCR, R21       ;enable TWI
    RET
;==============================================================
I2C_start:
    LDI   R21, (1<<TWINT)|(1<<TWSTA)|(1<<TWEN)
    STS   TWCR, R21       ;transmit START condition
    ;----------------------------------------------------------
wt1:LDS   R21, TWCR
    SBRS  R21, TWINT      ;TWI interrupt = 1?
    RJMP  wt1             ;no, wait for end of transmission
    ;----------------------------------------------------------
    RET
;==============================================================
I2C_write:
    STS   TWDR, R24       ;copy byte in R24 into data register
    LDI   R21, (1<<TWINT)|(1<<TWEN)
    STS   TWCR, R21       ;transmit byte
    ;----------------------------------------------------------
wt2:LDS   R21, TWCR
    SBRS  R21, TWINT
    RJMP  wt2             ;wait for end of transmission
    ;----------------------------------------------------------
    RET
;==============================================================
I2C_stop:
    LDI   R21, (1<<TWINT)|(1<<TWSTO)|(1<<TWEN)
    STS   TWCR, R21       ;transmit STOP condition
    RET

;=================================================================
;                   USART Subroutines
; BaudRate -> 19200
;=================================================================
init_serial:
  CLR R24
  STS UCSR0A, R24 ;clear UCSR0A register
  STS UBRR0H, R24 ;clear UBRR0H register
  LDI R24, 51 ;& store in UBRR0L 51 value
  STS UBRR0L, R24 ;to set baud rate 19200
  LDI R24, 1<<RXEN0 | 1<<TXEN0 ;enable RXB & TXB
  STS UCSR0B, R24
  LDI R24, 1<<UCSZ00 | 1<<UCSZ01;asynch, no parity, 1 stop, 8 bits
  STS UCSR0C, R24
  RET

LCD_buffer:
  LDS R27, UCSR0A
  SBRS R27, UDRE0 ;test data buffer if data can be sent
  RJMP LCD_buffer
  RET

ASCII_MSD:
  MOV R23, R16 ;save copy of result
  ANDI R16, 0xF0 ;extract & swap high-nibble
  SWAP R16
  SUBI R16, -48 ;R16 = R16 - (48) = R16 + 48
  MOV R28, R16 ;save a copy of high-byte result
  SUBI R28, 58 ;if +ve
  BRPL A_F_D1 ;branch & add 7 to get ASCII A to F
  l11: RET
ASCII_LSD:
  MOV R16, R23 ;restore copy of result
  ANDI R16, 0x0F ;extract low-nibble
  SUBI R16, -48 ;R16 = R16 - (48) = R16 + 48
  MOV R28, R16 ;save a copy of high-byte result
  SUBI R28, 58 ;if +ve
  BRPL A_F_D0 ;branch & add 7 to get ASCII A to F
  l12: RET
A_F_D1:
  SUBI R16, -7 ;R16 = R16 - (7) = R16 + 7
  RJMP l11
A_F_D0:
  SUBI R16, -7 ;R16 = R16 - (7) = R16 + 7
  RJMP l12


;=================================================================
;   Delay Subroutines 
;=================================================================
delay_3000ms: ;delay 3 seconds
 LDI R20, 255
l6: LDI R21, 255
l7: LDI R22, 246
l8: DEC R22
  BRNE l8
  DEC R21
  BRNE l7
  DEC R20
  BRNE l6
  RET

delay_sec: ;1s delay
    LDI R20, 255
l16: LDI R21, 255
l17: LDI R22, 60
l18: DEC R22
    BRNE l18
    DEC R21
    BRNE l17
    DEC R20
    BRNE l16
    RET

delay_20ms: ;delay 20ms
  LDI R21, 255
  l3: LDI R22, 210
  l4: LDI R23, 2
  l5: DEC R23
  BRNE l5
  DEC R22
  BRNE l4
  DEC R21
  BRNE l3
  RET

delay_ms:
      LDI   R21, 40
l24:   RCALL delay_us
      DEC   R21
      BRNE  l24
      RET

delay_short:
      NOP
      NOP
      RET
;------------------------
delay_us:
      LDI   R20, 90
l23:  RCALL delay_short
      DEC   R20
      BRNE  l23
      RET
;-----------------------

delay_timer0: ;50 usec delay via Timer 0
  ;---------------------------------------------------------
  CLR R20
  OUT TCNT0, R20 ;initialize timer0 with count=0
  LDI R20, 100
  OUT OCR0A, R20 ;OCR0 = 100
  LDI R20, 0b00001010
  OUT TCCR0B, R20 ;timer0: CTC mode, prescaler 8
  ;---------------------------------------------------------
l2: IN R20, TIFR0 ;get TIFR0 byte & check
  SBRS R20, OCF0A ;if OCF0=1, skip next instruction
  RJMP l2 ;else, loop back & check OCF0 flag
  ;---------------------------------------------------------
  CLR R20
  OUT TCCR0B, R20 ;stop timer0
  ;---------------------------------------------------------
  LDI R20, (1<<OCF0A)
  OUT TIFR0, R20 ;clear OCF0 flag
  RET