/*
 *  LCD.asm
 *
 *  Created: 11/15/2022 3:03:43 PM
 *  Author: jimmyliu
 */ 

.include "m2560def.inc"

/*
.def temp = r18
.def temp2 = r19
.def one_digit = r20
.def ten_digit = r21
*/

.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

.equ CMD_CLEAR_DISPLAY = 0b00000001
.equ CMD_CURSOR_RETURN_HOME = 0b00000010

.equ CMD_DISPLAY_ON = 0b00001100
.equ CMD_DISPLAY_OFF = 0b00001000
.equ CMD_CURSOR_ON = 0b00001010
.equ CMD_CURSOR_OFF = 0b00001000
.equ CMD_BLINK_ON = 0b00001001
.equ CMD_BLINK_OFF = 0b00001000

.macro do_lcd_command
	ldi r16, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

.macro do_lcd_data
	ldi r16, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro do_lcd_data_r
	mov r16, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro lcd_set
	sbi PORTA, @0
.endmacro

.macro lcd_clr
	cbi PORTA, @0
.endmacro

.macro separate_digit	;a number /10,save the ten_digit in divide
    clr ten_digit
    loopd10:
		inc ten_digit
		subi @0,10
		brcc loopd10
		subi @0,-10
		dec ten_digit       ;get the ten_digit finally
        mov one_digit, @0     ;get the one_digit finally
.endmacro

.macro output_equal			;output equal sign multiple times
    loop:
        ldi temp2, 61
        do_lcd_data temp2
        dec @0
        brne loop
.endmacro

.macro output_space			;output space multiple times
    loop:
        ldi temp2, 32
        do_lcd_data temp2
        dec @0
        brne loop
.endmacro

lcd_simulation:
	push r16

	do_lcd_command CMD_CLEAR_DISPLAY

	lds r16, num_west
	call lcd_write_register

	do_lcd_data '|'

	lds r16, num_passing
	call lcd_write_register

	do_lcd_data '|'

	lds r16, num_east
	call lcd_write_register

	pop r16

	ret

/*
LCD_display:
    ;Prologue
    push temp
    push temp2
    push one_digit
    push ten_digit
    ;Body    
    ;display the west queue length on LCD
    lds temp, num_west      ;load the length of west queue from data space to register
	separate_digit temp     ;separate the queue length digit into two single digit
    subi one_digit, -48     ;convert number into character
	subi ten_digit, -48     
	do_lcd_data ten_digit   ;display ten_digit on LCD
    do_lcd_data one_digit   ;display one_digit on LCD
    ;display "|" on LCD
    ldi temp, 124 
    do_lcd_data temp
    ;display space on LCD
    ldi temp, 2
    output_space temp
    ;display "<<===" or "===>>" on LCD
    lds temp, traffic_flow
    cpi temp, 2
    breq display_west_dir
    lds temp, traffic_flow
    cpi temp, 1
    breq display_east_dir
display_west_dir:
    ldi temp, 60
	do_lcd_data temp        
    do_lcd_data temp
    ;display multiple equal signs
    lds temp, num_passing
    output_equal temp     
    rjmp continue
display_east_dir:
    ;display multiple equal signs
    lds temp, num_passing
    output_equal temp
    ldi temp, 62
	do_lcd_data temp        
    do_lcd_data temp
    rjmp continue
continue:
    ;display multiple space
    ldi temp, 10
    lds temp2, num_passing
    sub temp, temp2
    output_space temp  
    ;display "|" on LCD
    ldi temp, 124       
    do_lcd_data temp
    ;display the east queue length on LCD
    lds temp, num_east      ;load the length of west queue from data space to register
	separate_digit temp     ;separate the queue length digit into two single digit
    subi one_digit, -48     ;convert number into character
	subi ten_digit, -48     ;convert number into character
	do_lcd_data ten_digit   ;display ten_digit on LCD
    do_lcd_data one_digit   ;display one_digit on LCD
    rjmp end
    ;End of function body
end:        
    ;Epilogue
    pop ten_digit
    pop one_digit
    pop temp2
    pop temp
    ret
    ;End of epilogue

*/

;----------------------------------------------------------------------

lcd_write_register:
	push r17
	push r18

	mov r18, r16

	clr r17

	conversion_start:
	cpi r18, 10
	brlo output_digit	; go to output the remainder
	subi r18, 10
	inc r17
	rjmp conversion_start

	output_digit:
	subi r18, -'0'
	do_lcd_data_r r18
	cpi r17, 0			
	breq conversion_end
	mov r18, r17
	rjmp conversion_start
	conversion_end:
	
	pop r18
	pop r17

	ret

lcd_command:
	out PORTF, r16
	nop
	lcd_set LCD_E
	nop
	nop
	nop
	lcd_clr LCD_E
	nop
	nop
	nop
	ret

lcd_data:
	out PORTF, r16
	lcd_set LCD_RS
	nop
	nop
	nop
	lcd_set LCD_E
	nop
	nop
	nop
	lcd_clr LCD_E
	nop
	nop
	nop
	lcd_clr LCD_RS
	ret

lcd_wait:
	push r16
	clr r16
	out DDRF, r16
	out PORTF, r16
	lcd_set LCD_RW
lcd_wait_loop:
	nop
	lcd_set LCD_E
	nop
	nop
    nop
	in r16, PINF
	lcd_clr LCD_E
	sbrc r16, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser r16
	out DDRF, r16
	pop r16
	ret

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
sleep_1ms:
	push r30
	push r31
	ldi r31, high(DELAY_1MS)
	ldi r30, low(DELAY_1MS)
delayloop_1ms:
	sbiw r31:r30, 1
	brne delayloop_1ms
	pop r31
	pop r30
	ret
sleep_5ms:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ret

	sleep_10ms:
	rcall sleep_5ms
	rcall sleep_5ms
	ret

sleep_50ms:
	rcall sleep_10ms
	rcall sleep_10ms
	rcall sleep_10ms
	rcall sleep_10ms
	rcall sleep_10ms
	ret

sleep_100ms:
	rcall sleep_50ms
	rcall sleep_50ms
	ret

sleep_250ms:
	rcall sleep_100ms
	rcall sleep_100ms
	rcall sleep_50ms
	ret

sleep_1s:
	rcall sleep_100ms
	rcall sleep_100ms
	rcall sleep_100ms
	rcall sleep_100ms
	rcall sleep_100ms

	rcall sleep_100ms
	rcall sleep_100ms
	rcall sleep_100ms
	rcall sleep_100ms
	rcall sleep_100ms
	ret