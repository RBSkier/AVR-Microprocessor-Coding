/*

code for the keypad goes in this file

*/

.include "m2560def.inc"

// -----------------------------------------------
// DEFINITIONS

.equ PORTLDIR =0xF0			; use PortL for input/output from keypad
.equ INITCOLMASK = 0xEF		; scan from the leftmost column, the value to mask output
.equ INITROWMASK = 0x01		; scan from the bottom row
.equ ROWMASK  =0x0F			; low four bits are output from the keypad. This value mask the high 4 bits.

.def temp0	= r20		
.def temp1  = r21
.def temp2	= r22

// -------------------------------------------------

// ------------------------------------------------
// FUNCTIONS

KEYPAD_RESET:
	push r16
	
	; set data direction register
	; need to use 'sts' instead of 'out' for memory mapped registers
	ldi r16, PORTLDIR
	sts DDRL, r16

	pop r16
	ret

keypad_read_input:
	/*
	.def row    = r16		; current row number
	.def col    = r17		; current column number
	.def rmask  = r18		; mask for current row
	.def cmask	= r19		; mask for current column

	.def temp1	= r20		
	.def temp2  = r21
	.def temp3	= r22
	*/

	push r16
	push r17
	push r18
	push r19

  kri_main:
	ldi r19, INITCOLMASK		; initial column mask
	clr	r17						; initial column

	// additional sleep to make sure we don't 
	// get duplicate keypresses
	rcall sleep_100ms
	rcall sleep_50ms

  kri_colloop:
	cpi r17, 4
	breq kri_main
	sts	PORTL, r19				; set column to mask value (one column off)

	ldi temp0, 0xFF
  kri_delay:
	dec temp0
	brne kri_delay

	lds	temp0, PINL				; read PORTL
	andi temp0, ROWMASK
	cpi temp0, 0xF				; check if any rows are on
	breq kri_nextcol
								; if yes, find which row is on
	ldi r18, INITROWMASK		; initialise row check
	clr	r16						; initial row
  kri_rowloop:
	cpi r16, 4
	breq kri_nextcol
	mov temp1, temp0
	and temp1, r18				; check masked bit
	breq kri_convert 				; if bit is clear, convert the bitcode
	inc r16						; else move to the next row
	lsl r18					; shift the mask to the next bit
	jmp kri_rowloop

  kri_nextcol:
	lsl r19					; else get new mask by shifting and 
	inc r17						; increment column value
	jmp kri_colloop					; and check the next column

  kri_convert:
  	cpi r17,3
	breq kri_letters			
	cpi r16, 3					; if row is 3 we have a symbol or 0
	breq kri_symbols
	cpi r16, 2
	breq kri_none
	mov temp0, r16				; otherwise we have a number in 14-19
	lsl temp0
	add temp0, r16				; temp1 = row * 3
	add temp0, r17				; add the column address to get the value
	subi temp0, -14  			
	jmp kri_convert_end

  kri_none:
    ldi temp0,0
	jmp kri_convert_end          ;keypad button named"7""8""9" are not used

  kri_letters:
	ldi temp0, 0
	jmp kri_convert_end

  kri_symbols:
	cpi r17, 0					; check if we have a star
	breq kri_star
	ldi temp0,0
	jmp kri_convert_end
  kri_star:
	ldi temp0, '*'				; set to star
	jmp kri_convert_end


  kri_convert_end:
	; load keypress into the return register
	mov r31, temp0

	pop r19
	pop r18
	pop r17
	pop r16
	ret