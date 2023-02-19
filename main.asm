
; Makrodefinitioner:
.EQU LED1 = PORTB0
.EQU LED2 = PORTB1

.EQU BUTTON1 = PORTB5
.EQU BUTTON2 = PORTB4
.EQU BUTTON3 = PORTB3

.EQU TIMER0_MAX_COUNT = 18
.EQU TIMER1_MAX_COUNT = 6	
.EQU TIMER2_MAX_COUNT = 12	

.EQU RESET_vect = 0x00	.
.EQU PCINT0_vect = 0x06

.EQU TIMER2_OVF_vect = 0x12
.EQU TIMER1_COMPA_vect = 0x16
.EQU TIMER0_OVF_vect = 0x20

;/********************************************************************************
;* DSEG: Här lagras statiska variabler med mera.
;********************************************************************************/
.DSEG
.ORG SRAM_START
	timer0_counter: .byte 1
	timer1_counter: .byte 1
	timer2_counter: .byte 1


;/********************************************************************************
;* CSEG: Här lagras programkoden
;********************************************************************************/
.CSEG
.ORG RESET_vect
	RJMP main


.ORG PCINT0_vect
	RJMP ISR_PCINT0

.ORG TIMER2_OVF_vect
	RJMP ISR_TIMER2_OVF

.ORG TIMER1_COMPA_vect
	RJMP ISR_TIMER1_COMPA

.ORG TIMER0_OVF_vect
	RJMP ISR_TIMER0_OVF

;/********************************************************************************
;* PCI-avbrottsrutiner: Kollar vilken knapp som är nedtryckt samt stänger av 
;*						avbrott för debounce skydd i 300 ms.
;********************************************************************************/
ISR_PCINT0:
	CLR R25
	STS PCICR, R25					
	LDI R16, (1 << TOIE0)
    STS TIMSK0, R16					
check_button1:
	IN R24, PINB
	ANDI R24, (1 << BUTTON1)
    BREQ check_button2
	CAll timer1_toggle
	RETI
check_button2:
    IN R24, PINB
    ANDI R24, (1 << BUTTON2)
    BREQ check_button3
	CALL timer2_toggle
	RETI
check_button3:
    IN R24, PINB
    ANDI R24, (1 << BUTTON3)
    BREQ ISR_PCINT0_end
	CALL system_reset
ISR_PCINT0_end:
	RETI

;/********************************************************************************
;* Avbrottsrutin för Timer 2: Används för blinkhastighet (200 ms) för lysdiod 2.
;********************************************************************************/
ISR_TIMER2_OVF:
	LDS R24, timer2_counter
	INC R24
	CPI R24, TIMER2_MAX_COUNT
	BRLO ISR_TIMER2_OVF_end
	LDI R18, (1 << LED2)
	OUT PINB, R18
	CLR R24
ISR_TIMER2_OVF_end:
	STS timer2_counter, R24	
	RETI

;/********************************************************************************
;* Avbrottsrutin för Timer 1: Används för blinkhastighet (100 ms) för lysdiod 1. 
;********************************************************************************/
ISR_TIMER1_COMPA:
	LDS R24, timer1_counter
	INC R24
	CPI R24, TIMER1_MAX_COUNT
	BRLO ISR_TIMER1_COMPA_end
	LDI R17, (1 << LED1)
	OUT PINB, R17
	CLR R24
ISR_TIMER1_COMPA_end:
	STS timer1_counter, R24
	RETI

;/********************************************************************************
;* Avbrottsrutin för Timer 0: Används för debounce-skyddet som är 300 ms.
;********************************************************************************/
ISR_TIMER0_OVF:
	LDS R24, timer0_counter
	INC R24
	CPI R24, TIMER0_MAX_COUNT
	BRLO ISR_TIMER0_OVF_end
	LDI R20, (1 << PCIE0)
	STS PCICR, R20
	CLR R24
	STS TIMSK0, R24

ISR_TIMER0_OVF_end:
	STS timer0_counter, R24
	RETI  

main:

;/********************************************************************************
;Setup: Aktiverar lysdioder och knappar samt avbrott för knapparna och timerna.
;********************************************************************************/
setup:
init_ports:														 
	LDI R16, (1 << LED1) | (1 << LED2)							;Initierar lysdioder
	OUT DDRB, R16
	LDI R17, (1 << BUTTON1) | (1 << BUTTON2) | (1 << BUTTON3)	; Initierar knappar
	OUT PORTB, R17

init_interrupts:
	LDI R16, (1 << PCIE0)										;Initierar PCI-avbrott för knapparna
	STS PCICR, R16
	STS PCMSK0, R17

init_timer:
	LDI R18, (1 << CS02) | (1 << CS00)							;Initierar Timer0
	OUT TCCR0B, R18
	

	LDI R16, (1 << CS12) | (1 << CS10) | (1 << WGM12)			;Initierar Timer1
	STS TCCR1B, R16
	LDI R17, 0x01
	LDI R16, 0x00
	STS OCR1AH, R17
	STS OCR1AL, R16

	LDI R16, (1 << CS22) | (1 << CS21) | (1 << CS20)			;Initierar Timer2
	STS TCCR2B, R16
	SEI

;Main loop:
main_loop:
	RJMP main_loop

;/********************************************************************************
;* System_reset: Rutin för reset-knappen. Här nollställs Lysdioder och deras Timers
;********************************************************************************/
system_reset:
	IN R24, PORTB
	ANDI R24, ~((1 << LED1) | (1 << LED2))
	OUT PORTB, R24
	CLR R24
	STS TIMSK1, R24
	STS TIMSK2, R24
	STS timer1_counter, R24
	STS timer2_counter, R24
	RET

;/********************************************************************************
;* Timer1_toggle: Togglar Timer 1 för blinkning av Lysdiod 1.
;********************************************************************************/
timer1_toggle:
	LDS R24, TIMSK1
	ANDI R24, (1 << OCIE1A)
	BREQ timer1_toggle_enable 
timer1_toggle_disable:
    IN R24, PORTB
    ANDI R24, ~(1 << LED1)
    OUT PORTB, R24
    CLR R24
    RJMP timer1_toggle_end
timer1_toggle_enable:
    LDI R24, (1 << OCIE1A)
timer1_toggle_end:
    STS TIMSK1, R24
    RET

;/********************************************************************************
;* Timer2_toggle: Togglar Timer 2 för blinkning av Lysdiod 2.
;********************************************************************************/
timer2_toggle:
	LDS R24, TIMSK2
	ANDI R24, (1 << TOIE2)
	BREQ timer2_toggle_enable 
timer2_toggle_disable:
    IN R24, PORTB
    ANDI R24, ~(1 << LED2)
    OUT PORTB, R24
    CLR R24
    RJMP timer2_toggle_end
timer2_toggle_enable:
    LDI R24, (1 << TOIE2)
timer2_toggle_end:
    STS TIMSK2, R24
    RET


