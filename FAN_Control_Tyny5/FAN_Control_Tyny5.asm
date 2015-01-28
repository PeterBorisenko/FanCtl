/*
 * FAN_Control_Tyny5.asm
 *
 *  Created: 25.01.2015 19:15:53
 *   Author: Disgust
 */ 

.INCLUDE "tn5def.inc"
	
	.def		ADCresult=	R17
	.def		Tcur=		R18
	.def		Tprev=		R19
	.def		Scur=		R20
	.def		Stat=		R21
	.equ		Load=		PINB0
	.equ		Fan=		PINB1
	.equ		Thrm=		PINB2

.DSEG

	

.CSEG

;=====================================	CONSTANTS
	.equ		Smin=	0		
	.equ		Smax=	240		
	.equ		Step=	0x0F
								;;	ADC values with thermistor NTCLG100E2104/104, R4= 10K
	.equ		Tmin=	40		;; ADC value at t= 40C
	.equ		Tmax=	152		;; ADC value at t= 100C

;=====================================	INTERRUPTS
	.org $0000
		rjmp init ; Reset vector
	.org ADCCaddr
		rjmp wake ; ADC vector

;=====================================
init:
	; Memory
	ldi		R16,		(RAMEND&0xFF)					; Set stackptr to ram end
	out		SPL,		R16
	ldi		R16,		(RAMEND >> 8)&0xFF
	out		SPH,		R16
	; I/O Ports
	sbi		DDRB,		Fan							;	PWM - PB1 - is output
	sbi		DDRB,		Load							;	PB0	-	is output
	cbi		DDRB,		Thrm							;	ADC2 - is input
	; Timer
	ldi		R16,		(0b01 << WGM00)					;	WGM3:0	=	0x05	- Fast PWM Mode wth 8-bit resolution
	out		TCCR0A,		R16
	ldi		R16,		(0b001 << CS00)|(0b01 << WGM02)
	out		TCCR0B,		R16
	; ADC
	ldi		R16,		0b10
	out		ADMUX,		R16
	ldi		R16,		(1 << ADEN)|(0b100 << ADPS0)
	out		ADCSRA,		R16
	;sbi	SMCR,		(1 << SM0)						;	Sleep mode is ADC noise reduction


set_Speed:
	out		OCR0BL,		Scur

measure_Start:
	sbi		ADCSRA,		ADSC
	;sbi		SMCR,		SE
	sleep

waitForResult:
	in		R16,		ADCSRA
	sbrs	R16,		ADIF
	rjmp	waitForResult
	;; in		ADCresult,	ADCL -- optimised

wake:
	;cbi	SMCR,		SE
	in		ADCresult,	ADCL	
	;sbi	SMCR,		(1 << SE)
	;; rjmp	calculation -- optimised

calculation:
	mov		Tcur,		Tprev
	mov		ADCresult,	Tcur
	sbrc	Stat,		0x01
	rjmp	comprasion_2
	;; rjmp		comprasion_1 -- optimised

comprasion_1:
	sbi		PORTB,		Load
	mov		R16,		Tcur
	cpi		R16,		Tmin
	;; if >
	; rjmp		speed_Up
	;; else
	; rjmp		measure_Start

comprasion_2:
	mov		R16,		Tcur
	cp		R16,		Tprev
	;; if >
	; rjmp		test_Smax
	mov		R16,		Tprev
	cp		R16,		Tcur
	;; if >
	; rjmp		speed_Down
	;; else
	; rjmp		measure_Start

test_Smin:
	mov		R16,		Scur
	cpi		R16,		Smin
	breq	set_measure_low
	rjmp	measure_Start

test_Smax:
	mov		R16,		Scur
	cpi		R16,		Smax
	brsh	OVERHEAT
	
speed_Up:
	ldi		Stat,		0x01
	ldi		R16,		Step
	add		Scur,		R16
	rjmp	set_Speed

speed_Down:
	subi	Scur,		Step
	out		OCR0BL,		Scur								; set speed inline -- optimised
	rjmp	test_Smin

set_measure_low:
	ldi		Stat,		0x00
	rjmp	measure_Start

OVERHEAT:
	;; Load disconnect or LED on
	cbi		PORTB, Load
	rjmp	measure_Start

.org	0x0000
