;--------------------------------------
; Automated Jail Door Control (Master)
;--------------------------------------

#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global main

main:
  RCALL init_serial
  RCALL I2C_init
  RCALL LCD_init
  RCALL delay_sec  
  RCALL LCD_start_message
  RCALL delay_sec

  LDI R28, 0x00   ; mode = 0 for command 
  LDI R27, 0xC0  
  RCALL LCD_sendChar
  RCALL delay_ms

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

again:
  RCALL delay_sec 
  RCALL Read_DHT11   ; subroutine for read DHT11
  RCALL Read_Photoresistor	; subroutine for reading photoresistor
  RJMP again ; loop back

;=================================================================
;                     Read Photoresistor Data
; Photoresistor Pin -> Analog Pin 0 (PC0)
;=================================================================

Read_Photoresistor:
	CBI DDRC, 0 ; set pin PC0 as i/p for ADC0 
	LDI R20, 0xC0 ; internal 2.56V, right-justified data, ADC0 
	STS ADMUX, R20 
	LDI R20, 0x87 ; enable ADC, ADC prescaler CLK/128 
	STS ADCSRA, R20 

read_ADC: 
	LDI R20, 0xC7 ;set ADSC in ADCSRA to start conversion 
	STS ADCSRA, R20 

wait_ADC: 
	LDS R21, ADCSRA ;check ADIF flag in ADCSRA 
	SBRS R21, 4 ;skip jump when conversion is done (flag set) 
	RJMP wait_ADC ;loop until ADIF flag is set 
	
	LDI R17, 0xD7 ;set ADIF flag again 
	STS ADCSRA, R17 ;so that controller clears ADIF 
	 
	LDS R19, ADCH ;get high-byte result from ADCH 
	RCALL determine_if_light
	RET

;=================================================================
;  	For Determining the Photoresistor Intensity
;	Uses R29 to store result 
;=================================================================

determine_if_light:
	CPI R19, 0x02
	BRSH open_door_unlocked

open_door_locked:
  CBI PORTD, 7 ; temporary solution
	;LDI R29, 0b00000000
	RJMP return_to_photoresistor
open_door_unlocked:
  SBI PORTD, 7 ; temporary solution
	;LDI R29, 0b00001111

return_to_photoresistor:
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
  MOV R19, R18 
  MOV R30, R18
  RCALL DHT11_reading ;read decimal temp (4th byte of 40-bit data)
  RCALL DHT11_print
  RCALL LCD_disp_temp
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
;   Print DHT11 to S. Monitor
;=================================================================
DHT11_print:
  MOV R16, R19
  RCALL ASCII_MSD
  RCALL LCD_buffer 
  STS UDR0, R16 

  MOV R16, R19
  RCALL ASCII_LSD 
  RCALL LCD_buffer 
  STS UDR0, R16 

  ;--------------Print New line---------------
  LDI R16, 0x0A 
  RCALL LCD_buffer 
  STS UDR0, R16 

  ;--------------Print Carriage Return---------------
  LDI R16, 0x0D 
  RCALL LCD_buffer 
  STS UDR0, R16 
  
  RET



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

  MOV R14, R30    ; copy result to R14
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

  LDI R28, 0x00   ; mode = 0 for command 
  LDI R27, 0xC6   ; move cursor to line 2 position 6
  RCALL LCD_sendChar

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
l17: LDI R22, 80
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