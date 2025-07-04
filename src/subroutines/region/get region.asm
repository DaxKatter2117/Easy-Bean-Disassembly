; =============== S U B	R O U T	I N E =======================================
; Get region
; ---------------------------------------------------------------------------
					
	move.b	CONSOLE_VER,d0		; Get the region of the console
								; 76543210
								; RME VVVV
								; R = Region : 0 = JPN  | 1 = ENG
								; M = TV Mode: 0 = NTSC | 0 = PAL
								; VVVV = Version
					
	andi.b	#$C0,d0				; Removes bits 5-0 from the console byte,
								; leaving us with the the Region and TV Mode

; ---------------------------------------------------------------------------

	if DevLock=1			; Use original code
	bne		WrongRegion			; If region is wrong, then jump to WrongRegion
	endc

	nop
	nop
	nop
	nop
	move.b	#0,(bytecode_flag).l	; Set to 0 so the flag will be clear (the correct region)
	rts								; Return to Start

WrongRegion:					
	nop
	nop
	nop
	nop
	move.b	#$1,(bytecode_flag).l	; Set to 1 so the flag will not be clear (the wrong region)
												
	rts								; Return to Start