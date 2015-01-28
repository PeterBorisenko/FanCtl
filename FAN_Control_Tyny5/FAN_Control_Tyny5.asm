/*
 * FAN_Control_Tyny5.asm
 *
 *  Created: 25.01.2015 19:15:53
 *   Author: Disgust
 */ 

.INCLUDE "tn5def.inc"
	
	.def		ADCresult=	R17			
	.def		Tcur=		R18			;; Current temperature
	.def		Tprev=		R19			;; Previous temperature
	.def		Scur=		R20			;; Current fan speed
	.def		Stat=		R21			;; Flag: 0x00 - Idle, 0x01 - Cooling
	.equ		Load=		PINB0
	.equ		Fan=		PINB1
	.equ		Thrm=		PINB2

.DSEG

	

.CSEG

;=====================================	CONSTANTS
	.equ		Smin=	10		
	.equ		Smax=	240		
	.equ		Step=	0x0F
								;;	ADC values with thermistor NTCLG100E2104/104, R4= 10K
	.equ		Tmin=	40		;; ADC value at t= 40C
	.equ		Tmax=	152		;; ADC value at t= 100C

;=====================================	INTERRUPTS
	.org $0000
		rjmp init ; Reset vector
	.org ADCCaddr
		rjmp get_Result ; ADC vector

;=====================================
init:
	; Clock

	; Memory
	ldi		R16,		(RAMEND&0xFF)					; Set stackptr to ram end
	out		SPL,		R16
	ldi		R16,		(RAMEND >> 8)&0xFF
	out		SPH,		R16
	; I/O Ports
	sbi		DDRB,		Fan								;	PWM - PB1 - is output
	sbi		DDRB,		Load							;	PB0	-	is output
	cbi		DDRB,		Thrm							;	ADC2 - is input
	; Timer
	ldi		R16,		(0b01 << WGM00)|(0b10 << COM0B0);	WGM3:0	=	0x05	- Fast PWM Mode wth 8-bit resolution
	out		TCCR0A,		R16
	ldi		R16,		(0b001 << CS00)|(0b01 << WGM02)	;	Non-inverting PWM on pin OCR0B
	out		TCCR0B,		R16							
	ldi		Scur,		Smin
	; ADC
	ldi		R16,		0b10
	out		ADMUX,		R16
	ldi		R16,		(1 << ADEN)|(0b111 << ADPS0)|(1 << ADIE)
	out		ADCSRA,		R16
	ldi		R16,		(1 << SM0)
	out		SMCR,		R16						;	Sleep mode is ADC noise reduction

set_Speed:
	out		OCR0BL,		Scur

measure_Start:
	sbi		ADCSRA,		ADSC
	sei
waitForResult:
	rjmp	waitForResult

get_Result:
	;sbi		ADCSRA,		ADIF	--	optimised
	in		R16,		SMCR
	cbr		R16,		SE
	out		SMCR,		R16
	in		ADCresult,	ADCL
	;; rjmp	calculation -- optimised

calculation:
	mov		Tprev,		Tcur
	mov		Tcur,		ADCresult
	sbrc	Stat,		0x01
	rjmp	comprasion_2
	;; rjmp		comprasion_1 -- optimised

comprasion_1:
	sbi		PORTB,		Load
	ldi		R16,		Tmin
	cp		R16,		Tcur
	brlo	speed_Up		; if Tmin < Tcur
	;; else
	rjmp		measure_Start

comprasion_2:
	cp		Tprev,		Tcur
	brlo		test_Smax	; if Tprev < Tcur
	cp		Tcur,		Tprev
	brlo		speed_Down	; if Tcur < Tprev
	;; else
	rjmp		measure_Start

test_Smin:
	mov		R16,		Scur
	cpi		R16,		Smin
	breq	set_measure_low
	rjmp	measure_Start

test_Smax:
	clc
	mov		R16,		Scur
	cpi		R16,		Smax
	brsh	OVERHEAT
	
speed_Up:
	clc
	ldi		Stat,		0x01
	ldi		R16,		Step
	add		Scur,		R16
	rjmp	set_Speed

speed_Down:
	clc
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

