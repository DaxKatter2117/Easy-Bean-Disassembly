; =============== S U B	R O U T	I N E =======================================
; Region lockout
; ---------------------------------------------------------------------------
	
	lea (Str_DevLockPriv).l,a2
	move.w	#$C500,d5
	moveq	#1,d0
	moveq	#$27,d1
	move.w	#$500,d6
	jsr	(DevLock_Print).l
	lea	(ActDeveloperCheck).l,a1
	jmp	(FindActorSlot).l

CheckInitDone:
	tst.b	(init_done).l
	beq.s	DoLock
	move.b	#1,(bytecode_flag).l
	
DoLock:
	rts