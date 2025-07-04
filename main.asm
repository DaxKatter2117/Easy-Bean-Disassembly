; --------------------------------------------------------------
;
;	Dr. Robotnik's Mean Bean Machine Disassembly
;	Original game by Compile & SEGA (1993)
;
;	Disassembled by Ralakimus, Neto, and RadioTails
;
;	Last Updated: 24/12/2021 (D/M/Y)
;
; --------------------------------------------------------------

	include	"include/errorhandler/Debugger.asm"
	include	"include/md.asm"
	include	"include/constants.asm"
	include	"include/ram.asm"
	include "include/cube2asm.asm"

	include	"include/macros - other.asm"
	include	"include/macros - bytecodes.asm"
	include "include/macros - dialog.asm"

	include	"include/Text Tables/Checksum Text.asm"
	include	"include/Text Tables/Stage Text.asm"
	include	"include/Text Tables/Name Text.asm"
	include	"include/Text Tables/Score Text.asm"
	
; --------------------------------------------------------------
; ROM settings
; --------------------------------------------------------------

	include	"settings.asm"

; --------------------------------------------------------------
; ROM header
; --------------------------------------------------------------

StartOfRom:
	include	"lib/header/vectors.asm"	; Vector table
	include	"lib/header/information.asm"	; ROM Information
EndOfHeader:

; --------------------------------------------------------------
; Program entry
; --------------------------------------------------------------

Entry:
	include "lib/program entry.asm"

; --------------------------------------------------------------
; Initialziation table
; --------------------------------------------------------------

	include "lib/initialziation table.asm"
	even

; --------------------------------------------------------------
; Game program
; --------------------------------------------------------------

GameProgram:
	include "src/game program.asm"
	
; --------------------------------------------------------------
; VSync
; --------------------------------------------------------------

VSync:
	lea	frame_count,a0
	move.w	(a0),d0

.Wait:
	cmp.w	(a0),d0
	beq.s	.Wait
	rts

; --------------------------------------------------------------
; Loads the default high score table into RAM
; --------------------------------------------------------------

LoadDefaultHighScores:
	lea	.DefaultScores,a1
	lea	high_scores,a2
	move.w	#$27,d0

.Load:
	move.l	(a1)+,(a2)+
	dbf	d0,.Load

	rts

; --------------------------------------------------------------

.DefaultScores:
	include	"resource/default settings/high scores.asm"
	even

; --------------------------------------------------------------
; Checks the high score table for broken entries and fixes them
; --------------------------------------------------------------

FixHighScores:
	lea	high_scores,a1
	moveq	#9,d0

.Loop:
	move.l	0(a1),d1
	bpl.s	.Store
	move.l	#$1B1B1BFF,d1

.Store:
	move.l	d1,(a1)
	lea	$10(a1),a1
	dbf	d0,.Loop

	rts

; --------------------------------------------------------------
; Initialize options
; --------------------------------------------------------------

LoadDefaultOptions:
	include	"resource/default settings/options.asm"

; --------------------------------------------------------------
; Wait for DMA to be over
; --------------------------------------------------------------

WaitDMA:
	nop
	nop
	nop
	nop
	move.w	VDP_CTRL,d0
	btst	#1,d0
	bne.s	WaitDMA
	rts

; --------------------------------------------------------------
; Initialize the game
; --------------------------------------------------------------

InitGame:
	lea	sound_test_enabled,a1
	jsr	sub_23566
	cmp.w	stack_base,d0
	beq.w	.Initialize

	lea	byte_FFFE00+2,a1
	jsr	sub_23566
	cmp.w	byte_FFFE00,d0
	beq.w	.Copy
	bsr.w	.sub_4BE

.Copy:
	lea	byte_FFFE00,a1
	lea	stack_base,a2
	move.w	#$2C-1,d0

.CopyLoop:
	move.l	(a1)+,(a2)+
	dbf	d0,.CopyLoop
	bra.w	.Initialize

; --------------------------------------------------------------

.sub_4BE:
	lea	stack_base,a0
	moveq	#0,d0
	move.w	#$100-1,d1

.Loop:
	move.l	d0,(a0)+
	dbf	d1,.Loop

	bsr.w	LoadDefaultHighScores
	bsr.w	LoadDefaultOptions

	move.w	#$FFFF,current_password
	jmp	sub_23536

; --------------------------------------------------------------

.Initialize:
	move.w	current_password,d2
	lea	RAM_START,a0
	moveq	#0,d0
	move.w	#$F000/4-1,d1

.ClearRAM:
	move.l	d0,(a0)+
	dbf	d1,.ClearRAM
	move.w	d2,current_password

	jsr	InitSound
	bsr.w	InitVDP
	bsr.w	InitBytecode
	jsr	InitSpriteDraw
	bsr.w	InitControllers
	jsr	DrawActors
	bsr.w	TransferSprites
	bsr.w	FixHighScores
	bsr.w	CopyPalToCRAM

	lea	vdp_reg_1,a0
	ori.b	#$40,(a0)
	move.w	#$8100,d0
	move.b	(a0),d0
	move.w	d0,VDP_CTRL

	rts

; --------------------------------------------------------------
; Exception
; --------------------------------------------------------------

Exception:
	DISABLE_INTS
	lea	(stack_base).l,sp
	jmp	(Entry).l

; --------------------------------------------------------------
; In the arcade version of Puyo Puyo, this function checked
; if a coin was inserted into the machine. Obviously, it
; was dummied out for the Mega Drive version.
; --------------------------------------------------------------

CheckCoinInserted:
	CLEAR_CARRY
	rts

; --------------------------------------------------------------
; V-BLANK routine
; --------------------------------------------------------------

VBlank:
;	DISABLE_INTS
	movem.l	d0-a6,-(sp)

	addq.w	#1,frame_count

.WaitDMA:
	move.w	VDP_CTRL,d0
	btst	#1,d0
	bne.s	.WaitDMA

	move.w	dma_slot,d2
	beq.w	.NoDMA
	lsr.w	#4,d2
	subq.w	#1,d2

	lea	dma_queue,a0
	lea	VDP_CTRL,a1

.DMALoop:
	move.w	#$8100,d0
	move.b	vdp_reg_1,d0
	ori.b	#$10,d0
	move.b	d0,vdp_reg_1
	move.w	d0,VDP_CTRL

	move.w	(a0)+,(a1)
	move.l	(a0)+,(a1)
	move.l	(a0)+,(a1)
	move.l	(a0)+,(a1)
	Z80_STOP
	move.w	(a0)+,(a1)

.WaitDMA2:
	move.w	VDP_CTRL,d0
	btst	#1,d0
	bne.s	.WaitDMA2
	
	move.w	#$8100,d0
	move.b	vdp_reg_1,d0
	andi.b	#~$10,d0
	move.b	d0,vdp_reg_1
	move.w	d0,VDP_CTRL

	Z80_START
	dbf	d2,.DMALoop

	clr.w	dma_slot
	move.w	#$8F02,VDP_CTRL
	move.b	#2,vdp_reg_f

.NoDMA:
	bsr.w	SetupHBlank
	bsr.w	HandleTime
	jsr	UpdateSound
	bsr.w	TransferSprites
	bsr.w	TransferVScroll
	bsr.w	TransferHScroll
	bsr.w	CopyPalToCRAM
	jsr	ProcPlaneCommands
	jsr	ProcEniTilemapQueue
	bsr.w	Random
	tst.w	use_plane_a_buffer
	beq.w	.End
	bsr.w	TransferPlaneABuffer

.End:
	movem.l	(sp)+,d0-a6
;	ENABLE_INTS
	rte

; --------------------------------------------------------------
; Transfer the plane A buffer to VRAM
; --------------------------------------------------------------

TransferPlaneABuffer:
	tst.w	dma_disabled
	bne.w	.ManualCopy
	DMA_COPY plane_a_buffer, $C000, $E00, VRAM
	rts

.ManualCopy:
	lea	plane_a_buffer,a1
	move.w	#$4000,VDP_CTRL
	move.w	#3,VDP_CTRL
	move.w	#$E00/2-1,d0

.Copy:
	move.w	(a1)+,VDP_DATA
	dbf	d0,.Copy

	rts

; --------------------------------------------------------------
; Handle time
; --------------------------------------------------------------

HandleTime:
	move.b	player_1_flags,d0
	or.b	player_2_flags,d0
	bmi.s	.TimeDisabled

	addq.w	#1,time_frames
	bcc.s	.SplitTime
	subq.w	#1,time_frames

.SplitTime:
	moveq	#0,d0
	move.w	time_frames,d0
	divu.w	#60,d0
	move.w	d0,time_total_secs
	
	moveq	#0,d0
	move.w	time_total_secs,d0
	divu.w	#60,d0
	move.l	d0,time_seconds

.TimeDisabled:
	rts

; --------------------------------------------------------------
; Setup H-BLANK (leftover from Puyo Puyo)
; --------------------------------------------------------------

SetupHBlank:
	clr.w	d0
	move.b	hblank_count,d0
	beq.w	DisableHBlank
	move.w	d0,hblank_counter

	move.l	#hblank_buffer_1,hblank_buffer_ptr
	tst.b	hblank_buffer_id
	beq.w	.Setup
	move.l	#hblank_buffer_2,hblank_buffer_ptr

.Setup:
	move.w	#$8000,d0
	move.b	vdp_reg_0,d0
	ori.b	#$10,d0
	move.w	d0,VDP_CTRL
	move.b	d0,vdp_reg_0
	
	move.w	#$8B00,d0
	move.b	vdp_reg_b,d0
	andi.b	#~4,d0
	move.b	d0,vdp_reg_b

	rts

; --------------------------------------------------------------
; H-BLANK routine (leftover from Puyo Puyo)
; --------------------------------------------------------------

HBlank:
	DISABLE_INTS
	tst.b	hblank_count
	beq.w	.End
	move.l	a0,-(sp)

	move.l	#$40000010,VDP_CTRL
	movea.l	hblank_buffer_ptr,a0
	move.w	(a0),VDP_DATA
	addq.w	#2,hblank_buffer_ptr+2
	
	subq.w	#1,hblank_counter
	bne.w	.EndRestore

	move.l	d0,-(sp)
	bsr.w	DisableHBlank
	move.l	(sp)+,d0

	move.l	#$40000010,VDP_CTRL
	move.w	#0,VDP_DATA

.EndRestore:
	move.l	(sp)+,a0

.End:
	ENABLE_INTS
	rte

; --------------------------------------------------------------
; Disable H-BLANK
; --------------------------------------------------------------

DisableHBlank:
	move.w	#$8000,d0
	move.b	vdp_reg_0,d0
	andi.b	#~$10,d0
	move.w	d0,VDP_CTRL
	move.b	d0,vdp_reg_0
	rts

; --------------------------------------------------------------
; Initialize the palette pointer list
; --------------------------------------------------------------

InitPalettePtrs:
	move.w	#4-1,d0
	lea	palette_pointers,a0
	lea	palette_buffer,a1

.LineLoop:
	tst.w	(a0)
	bne.w	.NextLine
	move.w	#-1,0(a0)
	move.l	a1,2(a0)

.NextLine:
	adda.l	#6,a0
	adda.l	#$20,a1
	dbf	d0,.LineLoop

	rts

; --------------------------------------------------------------
; Copy palette to CRAM
; --------------------------------------------------------------

CopyPalToCRAM:
	lea	palette_pointers,a2
	lea	palette_buffer,a3

	move.w	#4-1,d0
	moveq	#0,d1

.LineLoop:
	tst.w	(a2)
	beq.w	.NextLine
	clr.w	(a2)
	bsr.w	CopyPalLineToCRAM

.NextLine:
	adda.l	#6,a2
	adda.l	#$20,a3
	addi.b	#$20,d1

	dbf	d0,.LineLoop
	rts

; --------------------------------------------------------------
; Copy palette line to CRAM
; --------------------------------------------------------------
; PARAMETERS:
;	d1.w	- CRAM offset
;	a2.l	- Palette pointer list
;	a3.l	- Palette buffer
; --------------------------------------------------------------

CopyPalLineToCRAM:
	move.l	a3,-(sp)

	movea.l	2(a2),a4
	move.w	#$C000,d2
	move.b	d1,d2
	move.w	d2,VDP_CTRL
	move.w	#0,VDP_CTRL

	move.w	#$20/2-1,d2

.CopyPal:
	move.w	(a4),VDP_DATA
	move.w	(a4)+,(a3)+
	dbf	d2,.CopyPal

	move.l	(sp)+,a3
	rts

; --------------------------------------------------------------
; Transfer the sprite buffer to VRAM
; --------------------------------------------------------------

TransferSprites:
	tst.w	sprite_count
	bne.w	.CheckDMA
	rts

.CheckDMA:
	tst.w	dma_disabled
	bne.w	.ManualCopy

	lea	VDP_CTRL,a0
	move.w	#$8100,d0
	move.b	vdp_reg_1,d0
	ori.b	#$10,d0
	move.w	d0,(a0)

	move.w	#$9400,d0
	move.b	sprite_count,d0
	move.w	d0,(a0)
	move.w	#$9300,d0
	move.b	sprite_count+1,d0
	move.w	d0,(a0)
	move.w	#$9600|((sprite_buffer>>9)&$FF),(a0)
	move.w	#$9500|((sprite_buffer>>1)&$FF),(a0)
	move.w	#$9700|((sprite_buffer>>17)&$7F),(a0)
	move.w	#$7C00,(a0)
	move.w	#$82,dma_cmd_low
	Z80_STOP
	move.w	dma_cmd_low,(a0)
	move.w	#$8100,d0
	move.b	vdp_reg_1,d0
	move.w	d0,(a0)
	Z80_START

	clr.w	sprite_count
	rts

.ManualCopy:
	lea	sprite_buffer,a1
	move.w	#$7C00,VDP_CTRL
	move.w	#2,VDP_CTRL
	move.w	sprite_count,d0
	subq.w	#1,d0

.Copy:
	move.w	(a1)+,VDP_DATA
	dbf	d0,.Copy

	clr.w	sprite_count
	rts

; --------------------------------------------------------------
; Transfer the vertical scroll buffer to VRAM
; --------------------------------------------------------------

TransferVScroll:
	move.w	#$8B00,d0
	move.b	vdp_reg_b,d0
	move.w	d0,VDP_CTRL
	move.w	#$8C00,d0
	move.b	vdp_reg_c,d0
	move.w	d0,VDP_CTRL

	btst	#2,vdp_reg_b
	bne.w	.ColumnScroll

	move.l	#$40000010,VDP_CTRL
	move.w	vscroll_buffer,VDP_DATA
	move.w	vscroll_buffer+2,VDP_DATA

	rts

.ColumnScroll:
	tst.w	dma_disabled
	bne.w	.ManualCopy
	DMA_COPY vscroll_buffer, 0, $50, VSRAM
	rts

.ManualCopy:
	lea	vscroll_buffer,a1
	move.l	#$40000010,VDP_CTRL
	move.w	#$50/2-1,d0

.Copy:
	move.w	(a1)+,VDP_DATA
	dbf	d0,.Copy

	rts

; --------------------------------------------------------------
; Transfer the horizontal scroll buffer to VRAM
; --------------------------------------------------------------

TransferHScroll:
	btst	#1,vdp_reg_b
	bne.w	.RowScroll

	move.w	#$7800,VDP_CTRL
	move.w	#$2,VDP_CTRL
	move.w	hscroll_buffer,VDP_DATA
	move.w	hscroll_buffer+2,VDP_DATA

	rts

.RowScroll:
	tst.w	dma_disabled
	bne.w	.ManualCopy
	DMA_COPY hscroll_buffer, $B800, $400, VRAM
	rts

.ManualCopy:
	lea	hscroll_buffer,a1
	move.w	#$7800,VDP_CTRL
	move.w	#2,VDP_CTRL
	move.w	#$400/2-1,d0

.Copy:
	move.w	(a1)+,VDP_DATA
	dbf	d0,.Copy

	rts

; --------------------------------------------------------------
; Dead leftover code from Puyo Puyo. Appears to be old VRAM
; data buffering code that's also dead in Puyo Puyo.
; --------------------------------------------------------------

DeadVRAMBufCode:
	tst.b	vram_buffer_id
	bne.w	.DoTransfer
	rts

.DoTransfer:
	clr.b	vram_buffer_id

	DMA_COPY vram_buffer, $1000, $800, VRAM

	lea	vram_buffer,a1
	lea	hblank_buffer_1,a2
	move.w	vram_buffer_id,d0
	mulu.w	#$800,d0
	adda.l	d0,a2
	move.w	#$800/2-1,d0

.Copy:
	move.w	(a2)+,(a1)+
	dbf	d0,.Copy

	DMA_COPY vram_buffer, $2000, $800, VRAM

	lea	vram_buffer,a1
	lea	hblank_buffer_1,a2
	move.w	vram_buffer_id,d0
	addq.b	#8,d0
	andi.b	#$F,d0
	mulu.w	#$800,d0
	adda.l	d0,a2
	move.w	#$800/2-1,d0

.Copy2:
	move.w	(a2)+,(a1)+
	dbf	d0,.Copy2
	
	DMA_COPY vram_buffer, $2800, $800, VRAM

	rts

; --------------------------------------------------------------
; Clear scroll buffers
; --------------------------------------------------------------

ClearScroll:
	move.w	#$400/2-1,d0
	lea	hscroll_buffer,a1

.ClearHScroll:
	clr.w	(a1)+
	dbf	d0,.ClearHScroll

	move.w	#$50-1,d0		; Should be "$50/2-1"
	lea	vscroll_buffer,a1

.ClearVScroll:
	clr.w	(a1)+
	dbf	d0,.ClearVScroll

	rts

; --------------------------------------------------------------
; Enable shadow/highlight mode
; --------------------------------------------------------------

EnableSHMode:
	move.w	#$8C00,d0
	move.b	vdp_reg_c,d0
	ori.b	#8,d0
	move.b	d0,vdp_reg_c
	rts

; --------------------------------------------------------------
; Disable shadow/highlight mode
; --------------------------------------------------------------

DisableSHMode:
	move.w	#$8C00,d0
	move.b	vdp_reg_c,d0
	andi.b	#~8,d0
	move.b	d0,vdp_reg_c
	rts

; --------------------------------------------------------------
; Queue a list of plane commands
; --------------------------------------------------------------
; PARAMETERS:
;	d0.w	- Plane command list ID
; --------------------------------------------------------------

QueuePlaneCmdList:
	DISABLE_INTS
	movem.l	d1-d3/a2-a3,-(sp)

	move.b	#$FF,d2
	lea	PlaneCmdLists,a2
	lsl.w	#2,d0
	movea.l	(a2,d0.w),a3

	move.w	(a3)+,d0
	lea	plane_cmd_count,a2
	move.w	(a2),d1
	add.w	d0,d1

	cmpi.w	#(plane_cmd_queue_end-plane_cmd_queue)/4+1,d1
	bcs.w	.Queue
	clr.b	d2
	subi.w	#(plane_cmd_queue_end-plane_cmd_queue)/4,d1
	move.w	d1,d0
	move.w	#(plane_cmd_queue_end-plane_cmd_queue)/4,d1

.Queue:
	move.w	(a2),d3
	move.w	d1,(a2)+
	lsl.w	#2,d3
	adda.w	d3,a2

	subq.w	#1,d0
	bcs.s	.Done

.QueueLoop:
	move.l	(a3)+,(a2)+
	dbf	d0,.QueueLoop

.Done:
	move.b	d2,d0
	movem.l	(sp)+,d1-d3/a2-a3
	ENABLE_INTS
	subq.b	#1,d0
	rts

; --------------------------------------------------------------
; Queue plane command
; --------------------------------------------------------------
; PARAMETERS:
;	d0.l	- Plane command
; --------------------------------------------------------------

QueuePlaneCmd:
	cmpi.w	#(plane_cmd_queue_end-plane_cmd_queue)/4,plane_cmd_count
	bcs.s	.Queue
	SET_CARRY
	rts

.Queue:
	DISABLE_INTS
	movem.l	d1/a2,-(sp)

	lea	plane_cmd_count,a2
	move.w	(a2),d1
	addq.w	#1,(a2)
	lsl.w	#2,d1
	move.l	d0,2(a2,d1.w)

	movem.l	(sp)+,d1/a2
	ENABLE_INTS
	CLEAR_CARRY
	rts

; --------------------------------------------------------------
; Decompress Puyo compressed art
; --------------------------------------------------------------
; PARAMETERS:
;	d0.w	- VRAM address
;	a0.l	- Pointer to compressed art
; --------------------------------------------------------------

	include "lib/decompressions/puyo decompression.asm"

; --------------------------------------------------------------
; Initialize the VDP
; --------------------------------------------------------------

InitVDP:
	clr.w	d0
	bsr.w	SetupVDPRegs
	bsr.w	InitPalette
	rts

; --------------------------------------------------------------
; Setup VDP registers and enable display
; --------------------------------------------------------------
; PARAMETERS:
;	d0.w	- VDP register table ID
; --------------------------------------------------------------

SetupVDPRegs_DisplayOn:
	DISABLE_INTS

	bsr.w	SetupVDPRegs

	lea	vdp_reg_1,a0
	ori.b	#$40,(a0)
	move.w	#$8100,d0
	move.b	(a0),d0
	move.w	d0,VDP_CTRL

	ENABLE_INTS
	rts

; --------------------------------------------------------------
; Setup VDP registers
; --------------------------------------------------------------
; PARAMETERS:
;	d0.w	- VDP register table ID
; --------------------------------------------------------------

SetupVDPRegs:
	lsl.w	#2,d0
	movea.l	.VDPRegTables(pc,d0.w),a2

	lea	vdp_reg_0,a3
	move.w	#(vdp_reg_13-vdp_reg_0)-1,d0

.RegLoop:
	move.w	(a2)+,d1
	move.w	d1,VDP_CTRL
	move.b	d1,(a3)+
	dbf	d0,.RegLoop

	clr.l	vscroll_buffer
	clr.l	hscroll_buffer
	rts

; --------------------------------------------------------------

.VDPRegTables:
	dc.l	.Table0
	dc.l	.Table1
	dc.l	.Table2
	dc.l	.Table3

; --------------------------------------------------------------

.Table0:
	dc.w	$8004
	dc.w	$8124
	dc.w	$8230
	dc.w	$833C
	dc.w	$8407
	dc.w	$855E
	dc.w	$8600
	dc.w	$8700
	dc.w	$8800
	dc.w	$8900
	dc.w	$8A00
	dc.w	$8B03
	dc.w	$8C81
	dc.w	$8D2E
	dc.w	$8E00
	dc.w	$8F02
	dc.w	$9003
	dc.w	$9100
	dc.w	$9200

; --------------------------------------------------------------

.Table1:
	dc.w	$8004
	dc.w	$8124
	dc.w	$8230
	dc.w	$833C
	dc.w	$8407
	dc.w	$855E
	dc.w	$8600
	dc.w	$8700
	dc.w	$8800
	dc.w	$8900
	dc.w	$8A00
	dc.w	$8B00
	dc.w	$8C89
	dc.w	$8D2E
	dc.w	$8E00
	dc.w	$8F02
	dc.w	$9011
	dc.w	$9100
	dc.w	$9200

; --------------------------------------------------------------

.Table2:
	dc.w	$8004
	dc.w	$8124
	dc.w	$8230
	dc.w	$833C
	dc.w	$8407
	dc.w	$855E
	dc.w	$8600
	dc.w	$8700
	dc.w	$8800
	dc.w	$8900
	dc.w	$8A00
	dc.w	$8B00
	dc.w	$8C81
	dc.w	$8D2E
	dc.w	$8E00
	dc.w	$8F02
	dc.w	$9001
	dc.w	$918E
	dc.w	$9292

; --------------------------------------------------------------

.Table3:
	dc.w	$8004
	dc.w	$8124
	dc.w	$8230
	dc.w	$833C
	dc.w	$8407
	dc.w	$855E
	dc.w	$8600
	dc.w	$8700
	dc.w	$8800
	dc.w	$8900
	dc.w	$8A00
	dc.w	$8B00
	dc.w	$8C81
	dc.w	$8D2E
	dc.w	$8E00
	dc.w	$8F02
	dc.w	$9003
	dc.w	$9192
	dc.w	$9294

; --------------------------------------------------------------
; Palette fade actor variables
; --------------------------------------------------------------

pfLine		EQU	$08
pfData		EQU	$0E
pfFlag		EQU	$12
pfTimer		EQU	$26
pfSpeed		EQU	$28
pfSteps		EQU	$2A

; --------------------------------------------------------------
; Fade to palette with an amount of steps
; --------------------------------------------------------------
; PARAMETERS:
;	d0.w	- Palette line
;	d1.b	- Fade speed
;	d2.b	- Step count
;	a2.l	- Target palette
; --------------------------------------------------------------

FadeToPal_StepCount:
	lea	ActPalFade,a1
	bsr.w	FindActorSlot
	bcc.s	.Spawned
	rts

.Spawned:
	andi.b	#7,d2
	addq.b	#1,d2
	move.b	d2,pfSteps+1(a1)
	bra.w	FadeToPal_Setup

; --------------------------------------------------------------
; Fade to palette
; --------------------------------------------------------------
; PARAMETERS:
;	d0.w	- Palette line
;	d1.b	- Fade speed
;	a2.l	- Target palette
; --------------------------------------------------------------

FadeToPalette:
	lea	ActPalFade,a1
	bsr.w	FindActorSlot
	bcc.s	.Spawned
	rts

.Spawned:
	move.w	#8,pfSteps(a1)

; --------------------------------------------------------------

FadeToPal_Setup:
	andi.w	#3,d0
	move.w	d0,pfLine(a1)
	move.b	d1,pfSpeed+1(a1)

	mulu.w	#$82,d0
	lea	pal_fade_data,a3
	adda.l	d0,a3
	move.l	a3,pfData(a1)

	addq.w	#1,(a3)
	move.w	(a3),pfFlag(a1)

	move.l	a2,-(sp)

	moveq	#0,d0
	move.w	pfLine(a1),d0
	lsl.l	#5,d0
	lea	palette_buffer,a2
	adda.l	d0,a2
	adda.l	#2,a3
	bsr.w	ActPalFade_Split

	move.l	(sp)+,a2

	movea.l	pfData(a1),a3
	adda.l	#$32,a3
	bsr.w	ActPalFade_Split
	bsr.w	ActPalFade_GetAccums
	rts

; --------------------------------------------------------------
; Palette fade actor
; --------------------------------------------------------------

ActPalFade:
	move.w	pfFlag(a0),d0
	movea.l	pfData(a0),a2
	cmp.w	(a2),d0
	bne.w	ActorDeleteSelf

	addq.w	#1,pfTimer(a0)
	move.w	pfSpeed(a0),d0
	cmp.w	pfTimer(a0),d0
	bcs.s	.DoFade
	rts

.DoFade:
	clr.w	pfTimer(a0)
	bsr.w	ActPalFade_DoFade
	subq.w	#1,pfSteps(a0)
	beq.s	.Done
	rts

.Done:
	movea.l	pfData(a0),a2
	clr.w	(a2)
	bra.w	ActorDeleteSelf

; --------------------------------------------------------------
; Perform palette fading
; --------------------------------------------------------------
; PARAMETERS:
;	a0.l	- Pointer to palette fade actor data
; --------------------------------------------------------------

ActPalFade_DoFade:
	movea.l	pfData(a0),a2
	movea.l	a2,a3
	adda.l	#2,a2
	adda.l	#$32,a3

	move.w	#($10*3)-1,d0

.Fade:
	move.b	(a3,d0.w),d1
	add.b	d1,(a2,d0.w)
	dbf	d0,.Fade

	adda.l	#$30,a3
	bsr.w	ActPalFade_GetMDPal

	movea.l	pfData(a0),a2
	adda.l	#$62,a2
	move.w	pfLine(a0),d0
	bra.w	LoadPalette

; --------------------------------------------------------------
; Get accumulators for palette fading
; --------------------------------------------------------------
; PARAMETERS:
;	a1.l	- Pointer to palette fade actor slot
; --------------------------------------------------------------

ActPalFade_GetAccums:
	movea.l	pfData(a1),a2
	movea.l	a2,a3
	adda.l	#2,a2
	adda.l	#$32,a3

	move.w	#($10*3)-1,d0

.GetAccums:
	move.b	(a3),d1
	sub.b	(a2)+,d1
	asr.b	#3,d1
	move.b	d1,(a3)+

	dbf	d0,.GetAccums
	rts

; --------------------------------------------------------------
; Split palette for fading
; --------------------------------------------------------------
; PARAMETERS:
;	a2.l	- Palette buffer
;	a3.l	- Palette fade data colour buffer
; --------------------------------------------------------------

ActPalFade_Split:
	move.w	#$10-1,d0

.Split:
	move.b	(a2)+,d1
	lsl.b	#3,d1
	andi.b	#$70,d1
	move.b	d1,(a3)+
	
	move.b	(a2),d1
	lsl.b	#3,d1
	andi.b	#$70,d1
	move.b	d1,(a3)+
	
	move.b	(a2)+,d1
	lsr.b	#1,d1
	andi.b	#$70,d1
	move.b	d1,(a3)+

	dbf	d0,.Split
	rts

; --------------------------------------------------------------
; Get Mega Drive compatible palette from palette fade data
; --------------------------------------------------------------
; PARAMETERS:
;	a2.l	- Palette fade data colour buffer
;	a3.l	- Palette buffer
; --------------------------------------------------------------

ActPalFade_GetMDPal:
	move.w	#$10-1,d0

.Combine:
	bsr.w	ActPalFade_GetColChannel
	lsr.b	#3,d1
	andi.b	#$E,d1
	move.b	d1,(a3)+

	bsr.w	ActPalFade_GetColChannel
	move.b	d1,d2
	lsr.b	#3,d2
	andi.b	#$E,d2
	
	bsr.w	ActPalFade_GetColChannel
	lsl.b	#1,d1
	andi.b	#$E0,d1
	or.b	d2,d1
	move.b	d1,(a3)+

	dbf	d0,.Combine
	rts

; --------------------------------------------------------------
; Get colour channel from palette fade data
; --------------------------------------------------------------
; PARAMETERS:
;	a2.l	- Palette fade data colour buffer
; --------------------------------------------------------------

ActPalFade_GetColChannel:
	move.b	(a2)+,d1
	btst	#1,d1
	beq.s	.End
	addq.b	#4,d1

.End:
	rts

; --------------------------------------------------------------
; Initialize the palette buffer (interrupt safe)
; --------------------------------------------------------------

InitPalette_Safe:
	DISABLE_INTS

	bsr.w	InitPalette

	ENABLE_INTS
	rts

; --------------------------------------------------------------
; Initialize the palette buffer
; --------------------------------------------------------------

InitPalette:
	moveq	#0,d0
	lea	palette_buffer,a2
	move.w	#$80/4-1,d1

.ClearPal:
	move.l	d0,(a2)+
	dbf	d1,.ClearPal

; --------------------------------------------------------------
; Initialize the palette pointer list
; --------------------------------------------------------------

InitPalettePtrs2:
	lea	palette_pointers,a2

	move.w	#-1,(a2)+
	move.l	#palette_buffer,(a2)+
	move.w	#-1,(a2)+
	move.l	#palette_buffer+$20,(a2)+
	move.w	#-1,(a2)+
	move.l	#palette_buffer+$40,(a2)+
	move.w	#-1,(a2)+
	move.l	#palette_buffer+$60,(a2)+

	rts

; --------------------------------------------------------------
; Invert the palette
; --------------------------------------------------------------

InvertPalette:
	lea	palette_buffer,a2
	move.w	#$80/2-1,d0

.InvertLoop:
	move.w	(a2),d1
	eori.w	#$EEE,d1
	move.w	d1,(a2)+

	dbf	d0,.InvertLoop
	bra.s	InitPalettePtrs2

; --------------------------------------------------------------
; Load a palette
; --------------------------------------------------------------
; PARAMETERS
;	d0.w	- Palette line
;	a2.l	- Pointer to palette data
; --------------------------------------------------------------

LoadPalette:
	movem.l	d1/a3,-(sp)
	
	andi.w	#3,d0
	lsl.w	#1,d0
	move.w	d0,d1
	lsl.w	#1,d0
	add.w	d1,d0

	lea	palette_pointers,a3
	move.l	a2,2(a3,d0.w)
	move.w	#-1,(a3,d0.w)

	movem.l	(sp)+,d1/a3
	rts

; --------------------------------------------------------------
; Initialize controllers
; --------------------------------------------------------------

InitControllers:
	lea	p1_ctrl_hold,a1
	moveq	#0,d0
	move.l	d0,(a1)+
	move.l	d0,(a1)+
	move.l	d0,(a1)+
	move.b	#$10,pressed_time
	move.b	#3,unpressed_time

	Z80_STOP
	moveq	#$40,d0
	move.b	d0,PORT_A_CTRL
	move.b	d0,PORT_B_CTRL
	move.b	d0,PORT_C_CTRL
	Z80_START

	rts

; --------------------------------------------------------------
; Read controllers (interrupt and Z80 safe)
; --------------------------------------------------------------

ReadCtrls_Safe:
	DISABLE_INTS
	Z80_STOP

	bsr.w	ReadControllers

	Z80_START
	ENABLE_INTS
	rts

; --------------------------------------------------------------
; Read controllers
; --------------------------------------------------------------

ReadControllers:
	lea	p1_ctrl_hold,a0
	lea	PORT_A_DATA,a1
	bsr.w	ReadController
	lea	p2_ctrl_hold,a0
	lea	PORT_B_DATA,a1

; --------------------------------------------------------------
; Read a controller
; --------------------------------------------------------------
; PARAMETERS:
;	a0.l	- Pointer to controller read buffer
;	a1.l	- Pointer to I/O data port
; --------------------------------------------------------------

ReadController:
	move.b	#0,(a1)
	moveq	#$3C,d0		; 4(1,0) ; ..SA00.. mask
	moveq	#$3F,d1		; 4(1,0) ; ..CBRLDU mask
	and.b	(a1),d0
	move.b	#$40,(a1)
	add.b	d0,d0		; 4(1,0) ; .SA00...
	add.b	d0,d0		; 4(1,0) ; SA00....
	and.b	(a1),d1

	moveq	#$30,d2		; ..00....
	and.b	d0,d2		; check 0 bits
	beq.s	.Is3Button	; if they're 0 as expected, branch
; if not, it's likely a 2pad (SMS controller)
	or.b	#$30,d1		; mask out B and C, 2 = Start, 1 = A
.Is3Button:
	or.b	d1,d0		; SACBRLDU
	not.b	d0		; invert to active high; 0 = release, 1 = press

	move.b	0(a0),d1
	move.b	d0,0(a0)
	move.b	0(a0),1(a0)
	not.b	d1
	and.b	d1,1(a0)

	bsr.w	CtrlVertiTimes
;	bra.w	CtrlHorizTimes

; --------------------------------------------------------------
; Handle button press timers for left and right
; --------------------------------------------------------------

CtrlHorizTimes:
	andi.b	#$F3,2(a0)
	move.b	0(a0),d0
	move.b	3(a0),d1
	move.b	d1,d2
	ror.b	#4,d1
	eor.b	d0,d1
	andi.b	#$C,d1
	bne.s	.Pressed
	andi.b	#$3F,d2
	beq.s	.Unpressed
	subq.b	#1,3(a0)
	rts

.Unpressed:
	andi.b	#$C,d0
	or.b	d0,2(a0)
	move.b	unpressed_time,d0
	or.b	d0,3(a0)
	rts

.Pressed:
	andi.b	#$C,d0
	or.b	d0,2(a0)
	rol.b	#4,d0
	andi.b	#$C0,d0
	or.b	pressed_time,d0
	move.b	d0,3(a0)
	rts

; --------------------------------------------------------------
; Handle button press timers for up and down
; --------------------------------------------------------------

CtrlVertiTimes:
	andi.b	#$FC,2(a0)
	move.b	0(a0),d0
	move.b	4(a0),d1
	move.b	d1,d2
	ror.b	#6,d1
	eor.b	d0,d1
	andi.b	#3,d1
	bne.s	.Pressed
	andi.b	#$3F,d2
	beq.s	.Unpressed
	subq.b	#1,4(a0)
	rts

.Unpressed:
	andi.b	#3,d0
	or.b	d0,2(a0)
	move.b	unpressed_time,d0
	or.b	d0,4(a0)
	rts

.Pressed:
	andi.b	#3,d0
	or.b	d0,2(a0)
	rol.b	#6,d0
	andi.b	#$C0,d0
	or.b	pressed_time,d0
	move.b	d0,4(a0)
	rts

; --------------------------------------------------------------
; Generate a random number
; --------------------------------------------------------------
; RETURNS:
;	d0.l	- Random number
; --------------------------------------------------------------

Random:
	move.l	d1,-(sp)

	move.l	rng_seed,d1
	bne.s	.GotSeed
	move.l	#$2A6D365A,d1

.GotSeed:
	move.l	d1,d0
	asl.l	#2,d1
	add.l	d0,d1
	asl.l	#3,d1
	add.l	d0,d1
	move.w	d1,d0
	swap	d1
	add.w	d1,d0
	move.w	d0,d1
	swap	d1
	move.l	d1,rng_seed

	move.l	(sp)+,d1
	rts

; --------------------------------------------------------------
; Generate a random number within a boundary
; --------------------------------------------------------------
; PARAMETERS:
;	d1.w	- Exlusive boundary
; RETURNS:
;	d0.l	- Random number
; --------------------------------------------------------------

RandomBound:
	move.l	d1,-(sp)

	move.l	d0,d1
	bsr.s	Random
	mulu.w	d1,d0
	swap	d0

	move.l	(sp)+,d1
	rts

; --------------------------------------------------------------
; Get the cosine of a value
; --------------------------------------------------------------
; PARAMETERS:
;	d0.w	- Value
;	d1.w	- Multiplier
; RETURNS:
;	d0.l	- The cosine of the input value
; --------------------------------------------------------------

Cos:
	addi.b	#$40,d0

; --------------------------------------------------------------
; Get the sine of a value
; --------------------------------------------------------------
; PARAMETERS:
;	d0.w	- Value
;	d1.w	- Multiplier
; RETURNS:
;	d2.l	- The sine of the input value
; TRASHES:
;	d0.l	- Value with sign extension (movem.w)
; --------------------------------------------------------------

Sin:
	movem.w	d0,-(sp)

	clr.w	d2		; ML: if you can't immediately 
	move.b	d0,d2		; understand this, I don't blame
	add.b	d2,d2		; you whatsoever.
	move.w	SineTable(pc,d2.w),d2
;	andi.w	#$7F,d0		; ML: original for comparison
;	lsl.w	#1,d0		; (easier to read)
;	move.w	SineTable(pc,d0.w),d2
	mulu.w	d1,d2

	movem.w	(sp)+,d0

	or.b	d0,d0
	bpl.s	.End
	neg.l	d2

.End:
	rts
	
; --------------------------------------------------------------
; Sine table
; --------------------------------------------------------------

SineTable:
	dc.w	$0000, $0006, $000D, $0013, $0019, $001F, $0026, $002C
	dc.w	$0032, $0038, $003E, $0044, $004A, $0050, $0056, $005C
	dc.w	$0062, $0068, $006D, $0073, $0079, $007E, $0084, $0089
	dc.w	$008E, $0093, $0098, $009D, $00A2, $00A7, $00AC, $00B1
	dc.w	$00B5, $00B9, $00BE, $00C2, $00C6, $00CA, $00CE, $00D1
	dc.w	$00D5, $00D8, $00DC, $00DF, $00E2, $00E5, $00E7, $00EA
	dc.w	$00ED, $00EF, $00F1, $00F3, $00F5, $00F7, $00F8, $00FA
	dc.w	$00FB, $00FC, $00FD, $00FE, $00FF, $00FF, $0100, $0100
	dc.w	$0100, $0100, $0100, $00FF, $00FF, $00FE, $00FD, $00FC
	dc.w	$00FB, $00FA, $00F8, $00F7, $00F5, $00F3, $00F1, $00EF
	dc.w	$00ED, $00EA, $00E7, $00E5, $00E2, $00DF, $00DC, $00D8
	dc.w	$00D5, $00D1, $00CE, $00CA, $00C6, $00C2, $00BE, $00B9
	dc.w	$00B5, $00B1, $00AC, $00A7, $00A2, $009D, $0098, $0093
	dc.w	$008E, $0089, $0084, $007E, $0079, $0073, $006D, $0068
	dc.w	$0062, $005C, $0056, $0050, $004A, $0044, $003E, $0038
	dc.w	$0032, $002C, $0026, $001F, $0019, $0013, $000D, $0006

; --------------------------------------------------------------
; Leftover code from Puyo Puyo that applied the swirling
; effect on the clouds in Satan's introduction scene
; --------------------------------------------------------------

SpawnSatanCloudEffects:
	lea	ActSatanCloudEffects(pc),a1
	bsr.w	FindActorSlot
	bcc.s	@Spawned
	rts

@Spawned:
	move.w	#$8B00,d0
	move.b	vdp_reg_b,d0
	ori.b	#3,d0
	move.b	d0,vdp_reg_b
	rts

; --------------------------------------------------------------

ActSatanCloudEffects:
	lea	hscroll_buffer+(112*4),a2
	move.b	aField36(a0),d0
	clr.w	d1
	move.w	#$6F,d4
	move.w	vscroll_buffer+2,d3
	subi.w	#-$A1,d3
	bcs.s	loc_157A
	cmpi.w	#$70,d3
	bcc.s	loc_1596
	sub.w	d3,d4

.Clear:
	clr.w	-(a2)
	clr.w	-(a2)
	dbf	d3,.Clear
	subq.w	#1,d4
	bcc.s	loc_157A
	rts

loc_157A:
	bsr.w	Sin
	swap	d2
	asl.w	#1,d2
	move.w	d2,-(a2)
	clr.w	-(a2)
	addq.b	#2,d0
	addi.w	#$100,d1
	dbf	d4,loc_157A
	addq.b	#1,aField36(a0)
	rts

loc_1596:
	move.w	#$8B00,d0
	move.b	vdp_reg_b,d0
	andi.b	#$FC,d0
	move.b	d0,vdp_reg_b
	clr.b	byte_FF0136
	clr.w	hscroll_buffer+2
	bra.w	ActorDeleteSelf

; --------------------------------------------------------------
; Initialize bytecode
; --------------------------------------------------------------

InitBytecode:
	move.l	#Bytecode,bytecode_addr
	clr.b	bytecode_flag
	clr.b	bytecode_disabled
	rts

; --------------------------------------------------------------
; Run bytecode
; --------------------------------------------------------------

RunBytecode:
	tst.b	bytecode_disabled
	beq.s	.Run
	rts

.Run:
	clr.b	bytecode_done

	movea.l	bytecode_addr,a0
	move.w	(a0)+,d1
	move.w	(a0)+,d0
	move.l	a0,bytecode_addr

	add.w	d1,d1
	add.w	d1,d1
	movea.l	.Instructions(pc,d1.w),a0
	jsr	(a0)

	tst.b	bytecode_done
	beq.s	.Run
	rts

; --------------------------------------------------------------
; Bytecode instructions
; --------------------------------------------------------------
	
	include "lib/bytecode instructions.asm"

; --------------------------------------------------------------
; Game bytecode
; --------------------------------------------------------------

Bytecode:
	include "src/bytecode/game bytecode.asm"
	
; ---------------------------------------------------------------------------

PlayLevelIntroMusic:
	clr.w	d1
	move.b	(level).l,d1
	move.b	LevelIntroMusicIDs(pc,d1.w),d0
	jmp	(JmpTo_PlaySound).l

; ---------------------------------------------------------------------------
LevelIntroMusicIDs:
	dc.b 0			; Practise Stage 1
	dc.b 0			; Practise Stage 2
	dc.b 0			; Practise Stage 3
	dc.b BGM_INTRO_1	; Stage 1
	dc.b BGM_INTRO_1	; Stage 2
	dc.b BGM_INTRO_1	; Stage 3
	dc.b BGM_INTRO_1	; Stage 4
	dc.b BGM_INTRO_2	; Stage 5
	dc.b BGM_INTRO_2	; Stage 6
	dc.b BGM_INTRO_2	; Stage 7
	dc.b BGM_INTRO_2	; Stage 8
	dc.b BGM_INTRO_3	; Stage 9
	dc.b BGM_INTRO_3	; Stage 10
	dc.b BGM_INTRO_3	; Stage 11
	dc.b BGM_INTRO_3	; Stage 12
	dc.b BGM_FINAL_INTRO	; Stage 13
	dc.b 0
	dc.b 0
; ---------------------------------------------------------------------------
; START	OF FUNCTION CHUNK FOR HandleLevelMusic

PlayLevelMusic:
	clr.w	d1
	move.b	(level).l,d1
	move.b	LevelMusicIDs(pc,d1.w),d0
	cmp.b	(cur_level_music).l,d0
	bne.s	.NewID
	rts
; ---------------------------------------------------------------------------

.NewID:
	move.b	d0,(cur_level_music).l
	jmp	(JmpTo_PlaySound).l
; END OF FUNCTION CHUNK	FOR HandleLevelMusic
; ---------------------------------------------------------------------------
LevelMusicIDs:
	dc.b 0			; Practise Stage 1
	dc.b 0			; Practise Stage 2
	dc.b 0			; Practise Stage 3
	dc.b BGM_STAGE_1	; Stage 1
	dc.b BGM_STAGE_1	; Stage 2
	dc.b BGM_STAGE_1	; Stage 3
	dc.b BGM_STAGE_1	; Stage 4
	dc.b BGM_STAGE_2	; Stage 5
	dc.b BGM_STAGE_2	; Stage 6
	dc.b BGM_STAGE_2	; Stage 7
	dc.b BGM_STAGE_2	; Stage 8
	dc.b BGM_STAGE_3	; Stage 9
	dc.b BGM_STAGE_3	; Stage 10
	dc.b BGM_STAGE_3	; Stage 11
	dc.b BGM_STAGE_3	; Stage 12
	dc.b BGM_FINAL_STAGE	; Stage 13
	dc.b 0
	dc.b 0
; ---------------------------------------------------------------------------

PlayLevelWinMusic:
	clr.w	d1
	move.b	(level).l,d1
	move.b	LevelWinMusicIDs(pc,d1.w),d0
	cmp.b	(cur_level_music).l,d0
	bne.s	.NewID
	rts
; ---------------------------------------------------------------------------

.NewID:
	move.b	d0,(cur_level_music).l
	jmp	(JmpTo_PlaySound).l
; ---------------------------------------------------------------------------

LevelWinMusicIDs:
	dc.b 0			; Practise Stage 1
	dc.b 0			; Practise Stage 2
	dc.b 0			; Practise Stage 3
	dc.b BGM_WIN		; Stage 1
	dc.b BGM_WIN		; Stage 2
	dc.b BGM_WIN		; Stage 3
	dc.b BGM_WIN		; Stage 4
	dc.b BGM_WIN		; Stage 5
	dc.b BGM_WIN		; Stage 6
	dc.b BGM_WIN		; Stage 7
	dc.b BGM_WIN		; Stage 8
	dc.b BGM_WIN		; Stage 9
	dc.b BGM_WIN		; Stage 10
	dc.b BGM_WIN		; Stage 11
	dc.b BGM_WIN		; Stage 12
	dc.b BGM_FINAL_WIN	; Stage 13
	dc.b 0
	dc.b 0

; =============== S U B	R O U T	I N E =======================================

; << This controls the battle board art that Versus Mode loads!! >>

LoadLevelBGArt:
	lea	(ArtNem_GrassBoard).l,a0	; Insert your custom VS Battle Board Art Here)
	move.w	#0,d0

	DISABLE_INTS
	jsr	(NemDec).l
	ENABLE_INTS

	move.w	#$18,d0			; Input your custom PlaneID for your Versus Mode Board Here
	jmp	(QueuePlaneCmdList).l

; ---------------------------------------------------------------------------

LoadScenarioBGArt:
	clr.w	d0
	move.b	(level).l, d0
	lsl.w	#2, d0
	movea.l BoardIDs(pc,d0.w), a1
	jsr	(a1)
	move.w	#$0000,d0

	DISABLE_INTS
	jsr	(NemDec).l
	ENABLE_INTS

	clr.w	d0
	move.b	(level).l,d0
	move.b	PlaneIDs(pc,d0.w),d0

	jmp	(QueuePlaneCmdList).l
	even

BoardIDs:
	dc.l ArtBoardTiles1 ; Practise Stage 1
	dc.l ArtBoardTiles1 ; Practise Stage 2
	dc.l ArtBoardTiles1 ; Practise Stage 3
	dc.l ArtBoardTiles1 ; Stage 1
	dc.l ArtBoardTiles1 ; Stage 2
	dc.l ArtBoardTiles1 ; Stage 3
	dc.l ArtBoardTiles1 ; Stage 4
	dc.l ArtBoardTiles1 ; Stage 5
	dc.l ArtBoardTiles1 ; Stage 6
	dc.l ArtBoardTiles1 ; Stage 7
	dc.l ArtBoardTiles1 ; Stage 8
	dc.l ArtBoardTiles1 ; Stage 9
	dc.l ArtBoardTiles1 ; Stage 10
	dc.l ArtBoardTiles1 ; Stage 11
	dc.l ArtBoardTiles1 ; Stage 12
	dc.l ArtBoardTiles1 ; Stage 13
	even

PlaneIDs:
	dc.b 3 ; Practise Stage 1
	dc.b 3 ; Practise Stage 2
	dc.b 3 ; Practise Stage 3
	dc.b 3 ; Stage 1
	dc.b 3 ; Stage 2
	dc.b 3 ; Stage 3
	dc.b 3 ; Stage 4
	dc.b 3 ; Stage 5
	dc.b 3 ; Stage 6
	dc.b 3 ; Stage 7
	dc.b 3 ; Stage 8
	dc.b 3 ; Stage 9
	dc.b 3 ; Stage 10
	dc.b 3 ; Stage 11
	dc.b 3 ; Stage 12
	dc.b 3 ; Stage 13
	even

ArtBoardTiles1:	; General Grass Board
	lea	(ArtNem_GrassBoard).l,a0
	rts
	even

ArtBoardTiles2:	; Puyo Puyo Stone Board
	lea	(ArtNem_StoneBoard).l,a0
	rts
	even

; << Link your custom battle board art here for custom battle boards!! >>
;	Example;
;ArtBoardTiles3:
;	lea	(ArtNem_GHZBoard).l,a0	; Loads your art of choice into VRAM
;	rts
;	even				; Make sure to include this to avoid odd offset errors!!!

; =============== S U B	R O U T	I N E =======================================

FadeDemoBGPal:	
	clr.w	d0
	move.b	(level).l, d0	
	lsl.w	#2, d0
	movea.l PaletteIDs(pc,d0.w), a1
	jsr	(a1)
	move.b	#2,d0
	move.b	#0,d1
	jmp	(FadeToPalette).l	
	even

LoadDemoBGPal:	
	clr.w	d0
	move.b	(level).l, d0	
	lsl.w	#2, d0
	movea.l PaletteIDs(pc,d0.w), a1
	jsr	(a1)
	move.w	#2,d0
	jmp	(LoadPalette).l	
	even

PaletteIDs:
	dc.l BoardPalette1 ; Practise Stage 1
	dc.l BoardPalette1 ; Practise Stage 2
	dc.l BoardPalette1 ; Practise Stage 3
	dc.l BoardPalette1 ; Scenario/Demo Stage 1
	dc.l BoardPalette1 ; Scenario/Demo Stage 2
	dc.l BoardPalette1 ; Scenario/Demo Stage 3
	dc.l BoardPalette1 ; Scenario/Demo Stage 4
	dc.l BoardPalette1 ; Scenario/Demo Stage 5
	dc.l BoardPalette1 ; Scenario/Demo Stage 6
	dc.l BoardPalette1 ; Scenario/Demo Stage 7
	dc.l BoardPalette1 ; Scenario/Demo Stage 8
	dc.l BoardPalette1 ; Scenario/Demo Stage 9
	dc.l BoardPalette1 ; Scenario/Demo Stage 10
	dc.l BoardPalette1 ; Scenario/Demo Stage 11
	dc.l BoardPalette1 ; Scenario/Demo Stage 12
	dc.l BoardPalette1 ; Demo Stage 13
	even

BoardPalette1:	; General Grass Board
	lea	(Pal_GreenTealPuyos).l,a2
	rts
	even

BoardPalette2:	; Puyo Puyo Practise Board
	lea	(Pal_Options).l,a2
	rts
	even

BoardPalette3:	; Puyo Puyo Stone Board (Main)
	lea	(Pal_StoneBoard1_Puyo).l,a2
	rts
	even

BoardPalette4:	; Puyo Puyo Stone Board (Final)
	lea	(Pal_StoneBoard2_Puyo).l,a2
	rts
	even

; << Link your custom battle board palettes here for your custom battle boards!! >>
;	Example;
;BoardPalette5:
;	lea	(Pal_GreenPuyosGHZ).l,a2	; Loads your palette of choice
;	rts
;	even				; Make sure to include this to avoid odd offset errors!!!

; =============== S U B	R O U T	I N E =======================================

; Mean Bean Tsuu Cutscene FG Palette Loading System

; ---------------------------------------------------------------------------

LoadCutsceneFGPal:	
	clr.w	d0
	move.b	(level).l, d0	
	lsl.w	#2, d0
	movea.l CutsceneFG_PalIDs(pc,d0.w), a1
	jsr	(a1)
	move.b	#0,d0
	move.b	#0,d1
	jmp	(FadeToPalette).l	
	even

CutsceneFG_PalIDs:
	dc.l CutsceneFGPalette1 ; Practise Stage 1
	dc.l CutsceneFGPalette1 ; Practise Stage 2
	dc.l CutsceneFGPalette1 ; Practise Stage 3
	dc.l CutsceneFGPalette1 ; Scenario/Demo Stage 1
	dc.l CutsceneFGPalette1 ; Scenario/Demo Stage 2
	dc.l CutsceneFGPalette1 ; Scenario/Demo Stage 3
	dc.l CutsceneFGPalette1 ; Scenario/Demo Stage 4
	dc.l CutsceneFGPalette1 ; Scenario/Demo Stage 5
	dc.l CutsceneFGPalette1 ; Scenario/Demo Stage 6
	dc.l CutsceneFGPalette1 ; Scenario/Demo Stage 7
	dc.l CutsceneFGPalette1 ; Scenario/Demo Stage 8
	dc.l CutsceneFGPalette1 ; Scenario/Demo Stage 9
	dc.l CutsceneFGPalette1 ; Scenario/Demo Stage 10
	dc.l CutsceneFGPalette1 ; Scenario/Demo Stage 11
	dc.l CutsceneFGPalette1 ; Scenario/Demo Stage 12
	dc.l CutsceneFGPalette0 ; Demo Stage 13
	even

CutsceneFGPalette0:	; Robotnik's Lair Palette
	lea	(Pal_RobotnikLair).l,a2
	rts
	even

CutsceneFGPalette1:	; Mean Bean Hill Palette
	lea	(Pal_LevelIntroFG).l,a2
	rts
	even

; << Link your custom intro cutscene foreground palettes here for your custom cutscene backgrounds!! >>
;	Example;
;CutsceneFGPalette2:
;	lea	(Pal_GHZIntroFG).l,a2	; Loads your palette of choice
;	rts
;	even				; Make sure to include this to avoid odd offset errors!!!

; =============== S U B	R O U T	I N E =======================================

LoadCutsceneBGPal:	
	clr.w	d0
	move.b	(level).l, d0	
	lsl.w	#2, d0
	movea.l CutsceneBG_PalIDs(pc,d0.w), a1
	jsr	(a1)
	move.w	#1,d0
	move.b	#0,d1
	jmp	(FadeToPalette).l	
	even

CutsceneBG_PalIDs:
	dc.l CutsceneBGPalette1 ; Practise Stage 1
	dc.l CutsceneBGPalette1 ; Practise Stage 2
	dc.l CutsceneBGPalette1 ; Practise Stage 3
	dc.l CutsceneBGPalette1 ; Scenario/Demo Stage 1
	dc.l CutsceneBGPalette1 ; Scenario/Demo Stage 2
	dc.l CutsceneBGPalette1 ; Scenario/Demo Stage 3
	dc.l CutsceneBGPalette1 ; Scenario/Demo Stage 4
	dc.l CutsceneBGPalette1 ; Scenario/Demo Stage 5
	dc.l CutsceneBGPalette1 ; Scenario/Demo Stage 6
	dc.l CutsceneBGPalette1 ; Scenario/Demo Stage 7
	dc.l CutsceneBGPalette1 ; Scenario/Demo Stage 8
	dc.l CutsceneBGPalette1 ; Scenario/Demo Stage 9
	dc.l CutsceneBGPalette1 ; Scenario/Demo Stage 10
	dc.l CutsceneBGPalette1 ; Scenario/Demo Stage 11
	dc.l CutsceneBGPalette1 ; Scenario/Demo Stage 12
	dc.l CutsceneBGPalette0 ; Demo Stage 13
	even

CutsceneBGPalette0:	; Robotnik's Lair Palette
	lea	(Pal_GameIntroGrounder).l,a2
	rts
	even

CutsceneBGPalette1:	; Mean Bean Hill Palette
	lea	(Pal_LevelIntroBG).l,a2
	rts
	even

; << Link your custom intro cutscene background palettes here for your custom cutscene backgrounds!! >>
;	Example;
;CutsceneBGPalette2:
;	lea	(Pal_GHZIntroBG).l,a2	; Loads your palette of choice
;	rts
;	even				; Make sure to include this to avoid odd offset errors!!!

; =============== S U B	R O U T	I N E =======================================

CheckTutorialPalInit:
	cmpi.b	#3,(level).l
	bcc.s	.NotTutorial
	bsr.w	InitPalette_Safe

.NotTutorial:
	rts
; End of function CheckTutorialPalInit

; =============== S U B	R O U T	I N E =======================================

SetOpponent:
	moveq	#0,d0
	moveq	#0,d1
	move.b	(level).l,d0
	move.b	CutsceneFade_Flags(pc,d0.w), d1
	move.b	d1,(bytecode_flag).l
	move.b	(level).l,d0
	lea	(Opponents).l,a1
	move.b	(a1,d0.w),(opponent).l
	tst.b	(bytecode_flag).l
	bne.w	JmpToDisableHScroll
	rts
; End of function SetOpponent

JmpToDisableHScroll:
	jmp	(DisableLineHScroll).l

CutsceneFade_Flags:
	dc.b 1	; Practise Stage 1
	dc.b 1	; Practise Stage 2
	dc.b 1	; Practise Stage 3
	dc.b 0	; Scenario/Demo Stage 1
	dc.b 0	; Scenario/Demo Stage 2
	dc.b 0	; Scenario/Demo Stage 3
	dc.b 0	; Scenario/Demo Stage 4
	dc.b 0	; Scenario/Demo Stage 5
	dc.b 0	; Scenario/Demo Stage 6
	dc.b 0	; Scenario/Demo Stage 7
	dc.b 0	; Scenario/Demo Stage 8
	dc.b 0	; Scenario/Demo Stage 9
	dc.b 0	; Scenario/Demo Stage 10
	dc.b 0	; Scenario/Demo Stage 11
	dc.b 0	; Scenario/Demo Stage 12
	dc.b 1	; Demo Stage 13
	even
; ---------------------------------------------------------------------------
Opponents:
	dc.b OPP_SKELETON	; Puyo Puyo leftover
	dc.b OPP_NASU_GRAVE	; Puyo Puyo leftover
	dc.b OPP_MUMMY		; Puyo Puyo leftover
	dc.b OPP_ARMS
	dc.b OPP_FRANKLY
	dc.b OPP_HUMPTY
	dc.b OPP_COCONUTS
	dc.b OPP_DAVY
	dc.b OPP_SKWEEL
	dc.b OPP_DYNAMIGHT
	dc.b OPP_GROUNDER
	dc.b OPP_SPIKE
	dc.b OPP_SIR_FFUZZY
	dc.b OPP_DRAGON
	dc.b OPP_SCRATCH
	dc.b OPP_ROBOTNIK
; ---------------------------------------------------------------------------

InitDebugFlags:
	move.b	#$FF,(control_player_1).l
	move.b	#0,(control_puyo_drop).l
	move.b	#0,(skip_scenario_stages).l
	move.b	#0,(byte_FF195B).l
	rts
; ---------------------------------------------------------------------------

CheckFinalLevel:
	moveq	#0,d0
	moveq	#0,d1
	move.b	(level).l,d0
	move.b	OpponentScreen_Flags(pc,d0.w),d1
	move.b	d1,(bytecode_flag).l
	rts

OpponentScreen_Flags:
	dc.b 1	; Practise Stage 1
	dc.b 1	; Practise Stage 2
	dc.b 1	; Practise Stage 3
	dc.b 0	; Scenario/Demo Stage 1
	dc.b 0	; Scenario/Demo Stage 2
	dc.b 0	; Scenario/Demo Stage 3
	dc.b 0	; Scenario/Demo Stage 4
	dc.b 0	; Scenario/Demo Stage 5
	dc.b 0	; Scenario/Demo Stage 6
	dc.b 0	; Scenario/Demo Stage 7
	dc.b 0	; Scenario/Demo Stage 8
	dc.b 0	; Scenario/Demo Stage 9
	dc.b 0	; Scenario/Demo Stage 10
	dc.b 0	; Scenario/Demo Stage 11
	dc.b 0	; Scenario/Demo Stage 12
	dc.b 1	; Demo Stage 13
	even
; --------------------------------------------------------------
; Palette table
; --------------------------------------------------------------

Palettes:
	include "resource/palettes/palette table.asm"

; --------------------------------------------------------------
; Animation Frames - Has Bean
; --------------------------------------------------------------

	include "resource/anim/Has Bean/Has Bean - Start Match.asm"
	include "resource/anim/Has Bean/Has Bean - Movement.asm"

; --------------------------------------------------------------
; Initialize actors
; --------------------------------------------------------------

InitActors:
	move.w	#(actors_end-actors)/4-1,d1
	lea	actors,a0
	moveq	#0,d0

.ClearActors:
	move.l	d0,(a0)+
	dbf	d1,.ClearActors

	lea	pal_fade_data,a2
	move.w	#4-1,d0

.ClearPalFade:
	clr.w	(a2)
	adda.l	#$82,a2
	dbf	d0,.ClearPalFade

	rts

; --------------------------------------------------------------
; Run actors
; --------------------------------------------------------------

RunActors:
	move.b	player_1_flags,d0
	rol.b	#1,d0
	andi.b	#1,d0
	eori.b	#1,d0
	move.b	player_2_flags,d1
	rol.b	#2,d1
	andi.b	#2,d1
	eori.b	#2,d1
	or.b	d0,d1
	ori.b	#$C,d1

	lea	actors,a0
	move.w	#(actors_end-actors)/aSize-1,d0

.ActorLoop:
	move.b	aField0(a0),d2
	and.b	d1,d2
	beq.w	.NextActor

	movem.l	d0-d1,-(sp)
	movea.l	aAddr(a0),a1
	jsr	(a1)
	movem.l	(sp)+,d0-d1

.NextActor:
	adda.l	#aSize,a0
	dbf	d0,.ActorLoop

	rts

; --------------------------------------------------------------
; Find and initialize an actor slot
; --------------------------------------------------------------
; PARAMETERS:
;	d0.b	- Initial flags
;	a1.l	- Pointer to actor code
; RETURNS:
;	a1.l	- Pointer to actor slot
; --------------------------------------------------------------

FindActorSlot:
	bsr.w	FindActorSlotQuick
	bcc.s	.Loaded
	movem.l	d0/a0,-(sp)

	lea	actors,a0
	move.w	#(actors_end-actors)/aSize-1,d0

.FindSlot:
	btst	#7,aField1(a0)
	beq.s	.FoundSlot
	adda.l	#aSize,a0
	dbf	d0,.FindSlot

	movem.l	(sp)+,d0/a0
	SET_CARRY
	rts

.FoundSlot:
	move.l	a1,aAddr(a0)
	movea.l	a0,a1
	adda.l	#aDrawFlags,a0
	move.w	#(aSize-aDrawFlags)/2-1,d0

.ClearSlot:
	move.w	#0,(a0)+
	dbf	d0,.ClearSlot
	movem.l	(sp)+,d0/a0

.Loaded:
	ori.b	#$80,aField1(a1)
	CLEAR_CARRY
	rts

; --------------------------------------------------------------
; Find and initialize an actor slot (quick)
; --------------------------------------------------------------
; PARAMETERS:
;	d0.b	- Initial flags
;	a1.l	- Pointer to actor code
; RETURNS:
;	a1.l	- Pointer to actor slot
; --------------------------------------------------------------

FindActorSlotQuick:
	movem.l	d0/a0,-(sp)

	lea	actors,a0
	move.w	#(actors_end-actors)/aSize-1,d0

.FindSlot:
	tst.w	aField0(a0)
	beq.s	.FoundSlot
	adda.l	#aSize,a0
	dbf	d0,.FindSlot

	movem.l	(sp)+,d0/a0
	SET_CARRY
	rts

.FoundSlot:
	ori.w	#$FF00,d0
	move.w	d0,aField0(a0)
	move.l	a1,aAddr(a0)
	movea.l	a0,a1

	movem.l	(sp)+,d0/a0
	CLEAR_CARRY
	rts

; --------------------------------------------------------------
; Have an actor delete itself
; --------------------------------------------------------------
; PARAMETERS:
;	a0.l	- Pointer to actor slot
; --------------------------------------------------------------

ActorDeleteSelf:
	move.l	a2,-(sp)
	movea.l	a0,a2
	bra.w	DeleteActor

; --------------------------------------------------------------
; Delete an actor
; --------------------------------------------------------------
; PARAMETERS:
;	a1.l	- Pointer to actor slot
; --------------------------------------------------------------

ActorDeleteOther:
	move.l	a2,-(sp)
	movea.l	a1,a2

; --------------------------------------------------------------
; Delete an actor
; --------------------------------------------------------------
; PARAMETERS:
;	a2.l	- Pointer to actor slot
; --------------------------------------------------------------

DeleteActor:
	movem.l	d0-d1,-(sp)

	moveq	#0,d0
	move.w	#aSize/4-1,d1

.Clear:
	move.l	d0,(a2)+
	dbf	d1,.Clear

	movem.l	(sp)+,d0-d1
	move.l	(sp)+,a2
	rts

; --------------------------------------------------------------
; Set a bookmark in an actor's code and set delay timer
; --------------------------------------------------------------
; PARAMETERS:
;	a0.l	- Pointer to actor slot
; --------------------------------------------------------------

ActorBookmark_SetDelay:
	move.w	d0,aDelay(a0)
	move.l	(sp)+,aAddr(a0)
	rts

; --------------------------------------------------------------
; Set a bookmark in an actor's code (with delay timer)
; --------------------------------------------------------------
; PARAMETERS:
;	a0.l	- Pointer to actor slot
; --------------------------------------------------------------

ActorBookmark:
	tst.w	aDelay(a0)
	beq.w	.Bookmark
	subq.w	#1,aDelay(a0)
	beq.s	.Bookmark
	move.l	(sp)+,d0
	rts

.Bookmark:
	move.l	(sp)+,aAddr(a0)
	rts

; --------------------------------------------------------------
; Set a bookmark in an actor's code (with delay timer and
; controller checks for bypassing the delay)
; --------------------------------------------------------------
; PARAMETERS:
;	a0.l	- Pointer to actor slot
; --------------------------------------------------------------

ActorBookmark_Ctrl:
	move.b	p1_ctrl_press,d0
	or.b	p2_ctrl_press,d0
	andi.b	#$F0,d0
	bne.s	.Bookmark

	tst.w	aDelay(a0)
	beq.s	.Bookmark
	subq.w	#1,aDelay(a0)
	beq.s	.Bookmark
	move.l	(sp)+,d0
	rts

.Bookmark:
	clr.w	aDelay(a0)
	move.l	(sp)+,aAddr(a0)
	rts

; --------------------------------------------------------------
; Process an actor's animation script
; --------------------------------------------------------------
; PARAMETERS:
;	a0.l	- Pointer to actor slot
; --------------------------------------------------------------

ActorAnimate:
	tst.b	aAnimTime(a0)
	beq.s	.ChkStop
	subq.b	#1,aAnimTime(a0)
	rts

.ChkStop:
	movea.l	aAnim(a0),a2
	cmpi.b	#$FE,(a2)
	bcs.w	ActorParseAnim
	bne.s	.Jump

	SET_CARRY
	rts

.Jump:
	movea.l	2(a2),a3
	movea.l	a3,a2
	bsr.w	ActorParseAnim

	SET_CARRY
	rts

; --------------------------------------------------------------
; Parse an actor's animation script
; --------------------------------------------------------------
; PARAMETERS:
;	a0.l	- Pointer to actor slot
;	a2.l	- Pointer to animation script
; --------------------------------------------------------------

ActorParseAnim:
	move.b	(a2)+,d0
	cmpi.b	#$F0,d0
	bcs.s	.GetFrame
	bsr.w	ActorRandomAnimTime

.GetFrame:
	move.b	d0,aAnimTime(a0)
	move.b	(a2)+,d0
	move.b	d0,aFrame(a0)

	move.l	a2,aAnim(a0)
	CLEAR_CARRY
	rts

; --------------------------------------------------------------
; Get a random animation frame time
; --------------------------------------------------------------
; PARAMETERS:
;	d0.b	- Random time array ID
; RETURNS:
;	d0.b	- Random time
; --------------------------------------------------------------

ActorRandomAnimTime:
	clr.w	d1
	move.b	d0,d1
	lsl.b	#3,d1
	andi.b	#$38,d1

	bsr.w	Random
	andi.b	#7,d0

	clr.w	d2
	move.b	d0,d2
	add.w	d1,d2
	move.b	.AnimTimes(pc,d2.w),d0

	SET_CARRY
	rts

; --------------------------------------------------------------

.AnimTimes:
	dc.b	$30, $60, $02, $6C, $40, $46, $50, $5C
	dc.b	$30, $60, $20, $6C, $40, $46, $50, $5C
	dc.b	$00, $00, $00, $00, $00, $46, $50, $5C
	dc.b	$80, $A0, $60, $78, $BD, $AA, $B4, $C0
	dc.b	$00, $00, $00, $00, $20, $10, $0C, $30
	dc.b	$30, $60, $00, $6C, $40, $46, $50, $5C
	dc.b	$30, $60, $00, $6C, $40, $46, $50, $5C
	dc.b	$30, $60, $00, $6C, $40, $46, $50, $5C

; =============== S U B	R O U T	I N E =======================================


sub_3810:
	move.b	aDrawFlags(a0),d0
	bsr.w	sub_382A
	bsr.w	sub_386E
	bsr.w	sub_38B2
	bsr.w	sub_38E6
	andi	#$FFFE,sr
	rts
; End of function sub_3810


; =============== S U B	R O U T	I N E =======================================


sub_382A:
	btst	#1,d0
	bne.s	loc_3834
	rts
; ---------------------------------------------------------------------------

loc_3834:
	move.l	aX(a0),d1
	move.l	aField12(a0),d2
	add.l	d2,d1
	btst	#5,d0
	bne.s	loc_385A
	swap	d1
	cmpi.w	#128,d1
	bcs.s	loc_3860
	cmpi.w	#320+128,d1
	bcc.s	loc_3860
	swap	d1

loc_385A:
	move.l	d1,aX(a0)
	rts
; ---------------------------------------------------------------------------

loc_3860:
	movem.l	(sp)+,d0
	move.b	#0,d0
	SET_CARRY
	rts
; End of function sub_382A


; =============== S U B	R O U T	I N E =======================================


sub_386E:
	btst	#0,d0
	bne.s	loc_3878
	rts
; ---------------------------------------------------------------------------

loc_3878:
	move.l	aY(a0),d1
	move.l	aField16(a0),d2
	add.l	d2,d1
	btst	#4,d0
	bne.s	loc_389E
	swap	d1
	cmpi.w	#128,d1
	bcs.s	loc_38A4
	cmpi.w	#224+128,d1
	bcc.s	loc_38A4
	swap	d1

loc_389E:
	move.l	d1,aY(a0)
	rts
; ---------------------------------------------------------------------------

loc_38A4:
	movem.l	(sp)+,d0
	move.b	#$FF,d0
	SET_CARRY
	rts
; End of function sub_386E


; =============== S U B	R O U T	I N E =======================================


sub_38B2:
	btst	#3,d0
	bne.s	loc_38BC
	rts
; ---------------------------------------------------------------------------

loc_38BC:
	move.w	aX(a0),d1
	cmp.w	aField1E(a0),d1
	bcs.s	loc_38CE
	bne.s	loc_38DA
	rts
; ---------------------------------------------------------------------------

loc_38CE:
	moveq	#0,d1
	move.w	aField1A(a0),d1
	add.l	d1,aField12(a0)
	rts
; ---------------------------------------------------------------------------

loc_38DA:
	moveq	#0,d1
	move.w	aField1A(a0),d1
	sub.l	d1,aField12(a0)
	rts
; End of function sub_38B2


; =============== S U B	R O U T	I N E =======================================


sub_38E6:
	btst	#2,d0
	bne.s	loc_38F0
	rts
; ---------------------------------------------------------------------------

loc_38F0:
	move.w	aY(a0),d1
	cmp.w	aField20(a0),d1
	bcs.s	loc_3902
	bne.s	loc_390E
	rts
; ---------------------------------------------------------------------------

loc_3902:
	moveq	#0,d1
	move.w	aField1C(a0),d1
	add.l	d1,aField16(a0)
	rts
; ---------------------------------------------------------------------------

loc_390E:
	moveq	#0,d1
	move.w	aField1C(a0),d1
	sub.l	d1,aField16(a0)
	rts
; End of function sub_38E6

; =============== S U B	R O U T	I N E =======================================
; TODO - De-Hard Code this so that it's easier to adjust which characters have effects

PuyoLandEffects:
	cmpi.b	#OPP_FRANKLY,(opponent).l
	beq.s	.Shake
	cmpi.b	#OPP_DRAGON,(opponent).l
	bne.w	PlayPuyoLandSound

.Shake:
	tst.b	aPlayerID(a0)
	beq.w	PlayPuyoLandSound
	move.b	#SFX_PUYO_LAND_HARD,d0
	jsr	(PlaySound_ChkPCM).l
	move.l	a1,-(sp)
	lea	(ActShakeField).l,a1
	bsr.w	FindActorSlotQuick
	bcs.s	loc_3974
	move.w	#$400,aField38(a1)
	move.l	#(vscroll_buffer+$34),aAnim(a1)
	tst.b	(swap_controls).l
	beq.s	loc_3974
	move.l	#(vscroll_buffer+4),aAnim(a1)

loc_3974:
	move.l	(sp)+,a1
	rts
; End of function PuyoLandEffects


; =============== S U B	R O U T	I N E =======================================


ActShakeField:
	move.b	aField36(a0),d0
	move.w	aField38(a0),d1
	movea.l	aAnim(a0),a1
	move.w	#5,d3

loc_398A:
	andi.b	#$7F,d0
	bsr.w	Sin
	swap	d2
	move.w	d2,(a1)+
	clr.w	(a1)+
	addi.b	#$48,d0
	dbf	d3,loc_398A
	addi.b	#$28,aField36(a0)
	subi.w	#$20,aField38(a0)
	bcs.w	ActorDeleteSelf
	rts
; End of function ActShakeField


; =============== S U B	R O U T	I N E =======================================


PlayPuyoLandSound:
	move.b	#SFX_PUYO_LAND,d0
	cmpi.b	#OPP_ROBOTNIK,(opponent).l
	bne.s	loc_39C6
	move.b	#SFX_PUYO_LAND,d0

loc_39C6:
	jmp	(PlaySound_ChkPCM).l
; End of function PlayPuyoLandSound

; ---------------------------------------------------------------------------
; START	OF FUNCTION CHUNK FOR sub_5060

PlayPuyoMoveSound:
	move.b	#SFX_PUYO_MOVE,d0
	cmpi.b	#OPP_ROBOTNIK,(opponent).l
	bne.s	loc_39E0
	move.b	#SFX_PUYO_MOVE,d0

loc_39E0:
	jmp	(PlaySound_ChkPCM).l
; END OF FUNCTION CHUNK	FOR sub_5060
; ---------------------------------------------------------------------------
; START	OF FUNCTION CHUNK FOR sub_5384

PlayPuyoRotateSound:
	move.b	#SFX_PUYO_ROTATE,d0
	cmpi.b	#OPP_ROBOTNIK,(opponent).l
	bne.s	loc_39FA
	move.b	#SFX_PUYO_ROTATE,d0

loc_39FA:
	jmp	(PlaySound_ChkPCM).l
; END OF FUNCTION CHUNK	FOR sub_5384

; =============== S U B	R O U T	I N E =======================================


HandleLevelMusic:
	tst.b	(level_mode).l
	beq.s	.CheckPlayer
	rts
; ---------------------------------------------------------------------------

.CheckPlayer:
	tst.b	aPlayerID(a0)
	beq.s	.CheckDanger
	rts
; ---------------------------------------------------------------------------

.CheckDanger:
	cmpi.b	#BGM_DANGER,(cur_level_music).l
	beq.w	.CheckDangerOver
	cmpi.w	#60,(puyo_field_p1+pCount).l
	bcc.s	.InDanger
	rts
; ---------------------------------------------------------------------------

.InDanger:
	move.b	#BGM_DANGER,d0
	move.b	d0,(cur_level_music).l
	jmp	(JmpTo_PlaySound).l
; ---------------------------------------------------------------------------

.CheckDangerOver:
	cmpi.w	#54,(puyo_field_p1+pCount).l
	bcs.s	JmpTo_PlayLevelMusic
	rts
; ---------------------------------------------------------------------------

JmpTo_PlayLevelMusic:
	jmp	(PlayLevelMusic).l
; End of function HandleLevelMusic

; ---------------------------------------------------------------------------
MaxPuyoColours:
	dc.b PuyoColours_LessonCount-PuyoColours	; Practise Stage 1
	dc.b PuyoColours_LessonCount-PuyoColours	; Practise Stage 2
	dc.b PuyoColours_LessonCount-PuyoColours	; Practise Stage 3
	dc.b PuyoColours_NormalCount-PuyoColours	; Stage 1
	dc.b PuyoColours_NormalCount-PuyoColours	; Stage 2
	dc.b PuyoColours_NormalCount-PuyoColours	; Stage 3
	dc.b PuyoColours_NormalCount-PuyoColours	; Stage 4
	dc.b PuyoColours_NormalCount-PuyoColours	; Stage 5
	dc.b PuyoColours_NormalCount-PuyoColours	; Stage 6
	dc.b PuyoColours_NormalCount-PuyoColours	; Stage 7
	dc.b PuyoColours_NormalCount-PuyoColours	; Stage 8
	dc.b PuyoColours_NormalCount-PuyoColours	; Stage 9
	dc.b PuyoColours_NormalCount-PuyoColours	; Stage 10
	dc.b PuyoColours_NormalCount-PuyoColours	; Stage 11
	dc.b PuyoColours_NormalCount-PuyoColours	; Stage 12
	dc.b PuyoColours_NormalCount-PuyoColours	; Stage 13

; =============== S U B	R O U T	I N E =======================================

GenPuyoOrder:
	move.b	#PuyoColours_NormalCount-PuyoColours,d2
	cmpi.b	#1,(level_mode).l
	beq.s	loc_3A80
	clr.w	d1
	move.b	(level).l,d1
	move.b	MaxPuyoColours(pc,d1.w),d2

loc_3A80:
	move.w	#$100-1,d1
	clr.w	d0
	lea	(p1_puyo_order).l,a1
	lea	(PuyoColours).l,a2

.StoreP1Colours:
	move.b	(a2,d0.w),(a1)+
	addq.b	#1,d0
	cmp.b	d2,d0
	bcs.s	.NoP1ListReset
	clr.b	d0

.NoP1ListReset:
	dbf	d1,.StoreP1Colours

	move.w	#$100-1,d1
	lea	(p1_puyo_order).l,a1

.ShuffleP1Colours:
	jsr	(Random).l
	andi.w	#$FF,d0
	move.b	(a1,d0.w),d2
	move.b	(a1,d1.w),(a1,d0.w)
	move.b	d2,(a1,d1.w)
	dbf	d1,.ShuffleP1Colours

	move.w	#$100-1,d1
	lea	(p2_puyo_order).l,a2

.CopyP1ColoursToP2:
	move.b	(a1)+,(a2)+
	dbf	d1,.CopyP1ColoursToP2

	cmpi.b	#1,(level_mode).l
	beq.s	.DifferentP2Order
	rts
; ---------------------------------------------------------------------------

.DifferentP2Order:
	move.w	#$F8-1,d1
	clr.w	d0
	lea	(p2_puyo_order+8).l,a1
	lea	(PuyoColours).l,a2

.StoreP2Colours:
	move.b	(a2,d0.w),(a1)+
	addq.b	#1,d0
	cmpi.b	#PuyoColours_NormalCount-PuyoColours,d0
	bcs.s	.NoP2ListReset
	clr.b	d0

.NoP2ListReset:
	dbf	d1,.StoreP2Colours

	move.w	#$F8-1,d1
	lea	(p2_puyo_order+8).l,a1

.ShuffleP2Colours:
	move.w	#$F8,d0
	jsr	(RandomBound).l
	move.b	(a1,d0.w),d2
	move.b	(a1,d1.w),(a1,d0.w)
	move.b	d2,(a1,d1.w)
	dbf	d1,.ShuffleP2Colours
	rts
; End of function GenPuyoOrder

; ---------------------------------------------------------------------------
PuyoColours:
	dc.b PUYO_RED
	dc.b PUYO_GREEN
	dc.b PUYO_BLUE
	dc.b PUYO_YELLOW
PuyoColours_LessonCount:
	dc.b PUYO_PURPLE
PuyoColours_NormalCount:
	dc.b PUYO_GARBAGE	; Unused
	dc.b PUYO_TEAL		; Unused
	dc.b 0

; =============== S U B	R O U T	I N E =======================================


sub_3B3E:
	clr.w	d1
	move.b	$2B(a0),d1
	cmpi.b	#5,d1
	bcs.s	loc_3B50
	move.b	#4,d1

loc_3B50:
	lsl.w	#1,d1
	move.w	word_3B58(pc,d1.w),d0
	rts
; End of function sub_3B3E

; ---------------------------------------------------------------------------
word_3B58:
	dc.w $C
	dc.w 8
	dc.w 4
	dc.w 2
	dc.w 0

; --------------------------------------------------------------
; Mark the current level as finished and determine where
; to go next
; --------------------------------------------------------------
; BYTECODE FLAG:
;	00	- Next level
;	01	- Ending
;	02	- Lesson Mode ending (leftover from Puyo Puyo)
; --------------------------------------------------------------

LevelEnd:
	cmpi.b	#$F,(level).l
	bcc.s	.Ending
	addq.b	#1,(level).l
	clr.w	d0
	move.b	(opponent).l,d0
	lea	(opponents_defeated).l,a1
	move.b	#$FF,(a1,d0.w)
	move.b	#0,(bytecode_flag).l
	cmpi.b	#3,(level).l
	bne.s	.Exit
	move.b	#2,(bytecode_flag).l

.Exit:
	rts

.Ending:
	move.b	#1,(bytecode_flag).l
	rts

; =============== S U B	R O U T	I N E =======================================


sub_3BB0:
	lea	(sub_3BBA).l,a1
	bra.w	FindActorSlot
; End of function sub_3BB0


; =============== S U B	R O U T	I N E =======================================

sub_3BBA:
	move.b	#$FF,8(a0)
	move.l	#byte_3BF2,$32(a0)
	bsr.w	ActorBookmark
	bsr.w	ActorAnimate
	move.b	9(a0),d0
	cmp.b	8(a0),d0
	bne.s	loc_3BDE
	rts
; ---------------------------------------------------------------------------

loc_3BDE:
	move.b	d0,8(a0)
	move.w	#$8A00,d0
	move.b	8(a0),d0
	swap	d0
	jmp	(QueuePlaneCmd).l
; End of function sub_3BBA

; ---------------------------------------------------------------------------
byte_3BF2:
	dc.b $F3, 0
	dc.b 2,	4
	dc.b 4,	5
	dc.b 2,	4
	dc.b $FF, 0
	dc.l byte_3BF2
; ---------------------------------------------------------------------------

loc_3C00:
	move.w	#$CB1E,(word_FF198A).l
	tst.b	(swap_controls).l
	beq.s	loc_3C1A
	move.w	#$CC22,(word_FF198A).l

loc_3C1A:
	clr.w	(time_frames).l
	clr.w	(time_minutes).l
	clr.b	(byte_FF1965).l
	tst.b	(level_mode).l
	bne.s	loc_3C40
	clr.b	(cur_level_music).l
	bsr.w	JmpTo_PlayLevelMusic

loc_3C40:
	bsr.w	ClearScroll
	move.w	#$8B00,d0
	move.b	(vdp_reg_b).l,d0
	ori.b	#4,d0
	move.b	d0,(vdp_reg_b).l
	lea	(loc_3D1C).l,a1
	bsr.w	FindActorSlot
	move.b	#$F1,0(a1)
	move.b	#0,$2A(a1)
	move.b	#3,7(a1)
	move.l	(dword_FF195C).l,$A(a1)
	move.w	(dword_FF1960).l,$16(a1)
	movea.l	a1,a2
	lea	(loc_3D1C).l,a1
	bsr.w	FindActorSlot
	move.b	#$F2,0(a1)
	move.b	#1,$2A(a1)
	move.b	#3,7(a1)
	move.l	a1,$2E(a2)
	move.l	a2,$2E(a1)
	bsr.w	sub_5B54
	bsr.w	sub_3BB0
	jsr	(sub_1233A).l
	bsr.w	sub_3CDA
	cmpi.b	#2,(level_mode).l
	bne.s	locret_3CD8
	move.l	#$800F0000,d0
	jsr	(QueuePlaneCmd).l
	bsr.w	sub_9376

locret_3CD8:
	rts

; =============== S U B	R O U T	I N E =======================================


sub_3CDA:
	move.l	#$80000000,d0
	move.b	(level_mode).l,d1
	andi.b	#3,d1
	bne.s	loc_3CF4
	move.l	#$80060000,d0

loc_3CF4:
	jmp	(QueuePlaneCmd).l
; End of function sub_3CDA


; =============== S U B	R O U T	I N E =======================================


sub_3CFA:
	move.b	(level_mode).l,d2
	btst	#2,d2
	bne.s	locret_3D1A
	clr.w	d0
	move.b	$2A(a0),d0
	lea	(player_1_flags).l,a1
	move.b	#$7F,(a1,d0.w)

locret_3D1A:
	rts
; End of function sub_3CFA

; ---------------------------------------------------------------------------

loc_3D1C:
;	jsr	(sub_11EF2).l		; This controls the Lesson mode text spawning in Practise Stage 1
					; As the art for it was removed, garbage graphics spawn, so I commented it out.
	bsr.w	sub_44EA
	move.b	(byte_FF196A).l,d0
	cmp.b	$2A(a0),d0
	beq.s	loc_3D44
	btst	#1,(level_mode).l
	beq.s	loc_3D44
	bra.w	loc_813C
; ---------------------------------------------------------------------------

loc_3D44:
	clr.w	d0
	move.b	$2A(a0),d0
	lea	(puyos_popping).l,a1
	move.b	#0,(a1,d0.w)
	bsr.w	ResetPuyoField
	DISABLE_INTS
	ENABLE_INTS
	moveq	#0,d0
	bsr.w	sub_9C4A
	clr.w	d1
	bsr.w	sub_9502
	bsr.w	sub_94E0
	bset	#0,7(a0)
	bsr.w	sub_3F94
	bsr.w	ActorBookmark
	btst	#0,7(a0)
	beq.s	loc_3D8C
	rts
; ---------------------------------------------------------------------------

loc_3D8C:
	bsr.w	loc_9CF8
	bsr.w	sub_9BCE
	move.w	#1,d1
	bsr.w	sub_9502
	bsr.w	ActorBookmark
	btst	#1,7(a0)
	beq.s	loc_3DAC
	rts
; ---------------------------------------------------------------------------

loc_3DAC:
	bsr.w	sub_3CFA

loc_3DB0:
	clr.b	9(a0)
	lea	(byte_FF19B2).l,a1
	clr.w	d0
	move.b	$2A(a0),d0
	move.b	#0,(a1,d0.w)
	bsr.w	SpawnGarbage
	bsr.w	sub_9814
	bsr.w	ActorBookmark
	btst	#2,7(a0)
	beq.s	loc_3DDE
	rts
; ---------------------------------------------------------------------------

loc_3DDE:
	jsr	(sub_12BAA).l
	jsr	(sub_88A8).l
	bsr.w	sub_9332
	bsr.w	HandleLevelMusic
	bsr.w	ActorBookmark
	move.b	#0,(byte_FF1D0E).l
	jsr	(sub_12C8A).l
	bsr.w	ActorBookmark
	move.b	#$FF,(byte_FF1D0E).l
	jsr	(sub_12C8A).l
	bsr.w	ActorBookmark
	clr.w	d0
	move.b	$2A(a0),d0
	lea	(byte_FF1D0A).l,a1
	clr.b	(a1,d0.w)
	jsr	(sub_127BA).l
	tst.b	(control_puyo_drop).l
	beq.s	loc_3E40
	jsr	(nullsub_4).l

loc_3E40:
	bsr.w	ActorBookmark
	tst.b	(control_puyo_drop).l
	beq.s	loc_3E5C
	bsr.w	sub_56C0
	btst	#5,d0
	bne.s	loc_3E5C
	rts
; ---------------------------------------------------------------------------

loc_3E5C:
	bsr.w	sub_4E24
	bcs.w	loc_79FC
	jsr	(sub_11FA4).l
	bsr.w	ActorBookmark
	addq.b	#1,$26(a0)
	move.b	7(a0),d0
	andi.b	#3,d0
	beq.s	loc_3E96
	btst	#3,7(a0)
	bne.s	loc_3E8A
	rts
; ---------------------------------------------------------------------------

loc_3E8A:
	bclr	#3,7(a0)
	moveq	#1,d0
	bra.w	sub_9C4A
; ---------------------------------------------------------------------------

loc_3E96:
	bsr.w	ActorBookmark
	bsr.w	sub_5960
	move.w	d1,$26(a0)
	bsr.w	ActorBookmark
	DISABLE_INTS
	bsr.w	sub_5782
	ENABLE_INTS
	bsr.w	ActorBookmark
	tst.w	$26(a0)
	bne.s	loc_3EDA
	bsr.w	sub_3B3E
	bsr.w	ActorBookmark_SetDelay
	bsr.w	ActorBookmark
	tst.b	9(a0)
	beq.w	loc_3DB0
	bsr.w	sub_998A
	bra.w	loc_3DB0
; ---------------------------------------------------------------------------

loc_3EDA:
	lea	(byte_FF19B2).l,a1
	clr.w	d0
	move.b	$2A(a0),d0
	move.b	#$FF,(a1,d0.w)
	jsr	(sub_11ECE).l
	bsr.w	sub_58C8
	bsr.w	ActorBookmark
	bsr.w	sub_9A56
	bsr.w	sub_9A40
	bsr.w	ActorBookmark
	bsr.w	sub_49BA
	move.w	#$18,d0
	bsr.w	ActorBookmark_SetDelay
	bsr.w	sub_49D2
	bsr.w	ActorBookmark
	bsr.w	sub_9BBA
	bsr.w	CheckPuyoPop
	jsr	(SpawnGarbageGlow).l
	move.w	#$18,d0
	bsr.w	ActorBookmark_SetDelay
	bsr.w	ActorBookmark
	bsr.w	sub_4DB8
	bset	#4,7(a0)
	bsr.w	ActorBookmark
	btst	#4,7(a0)
	beq.s	loc_3F50
	bra.w	loc_4E14
; ---------------------------------------------------------------------------

loc_3F50:
	bsr.w	sub_9C4E
	bsr.w	sub_9CA2
	bsr.w	ActorBookmark
	addq.b	#1,9(a0)
	bcc.s	loc_3F6A
	move.b	#$FF,9(a0)

loc_3F6A:
	bra.w	loc_3E96
; ---------------------------------------------------------------------------
; START	OF FUNCTION CHUNK FOR sub_3F94

loc_3F6E:
	bclr	#0,7(a0)
	clr.w	d0
	move.b	(level).l,d0
	move.b	unk_3F84(pc,d0.w),8(a0)
	rts
; END OF FUNCTION CHUNK	FOR sub_3F94
; ---------------------------------------------------------------------------
unk_3F84:	; Does this control puyo drop speeds?
	dc.b   7	; Practise Stage 1
	dc.b   9	; Practise Stage 2
	dc.b  $B	; Practise Stage 3
	dc.b   8	; Stage 1
	dc.b   9	; Stage 2
	dc.b  $A	; Stage 3
	dc.b  $B	; Stage 4
	dc.b  $C	; Stage 5
	dc.b  $D	; Stage 6
	dc.b  $E	; Stage 7
	dc.b  $F	; Stage 8
	dc.b $11	; Stage 9
	dc.b $11	; Stage 10
	dc.b $12	; Stage 11
	dc.b $12	; Stage 12
	dc.b $13	; Stage 13

; =============== S U B	R O U T	I N E =======================================

sub_3F94:
	move.b	(level_mode).l,d0
	andi.b	#3,d0
	beq.s	loc_3F6E
	lea	(loc_3FE6).l,a1
	bsr.w	FindActorSlot
	bcc.s	loc_3FB0
	rts
; ---------------------------------------------------------------------------

loc_3FB0:
	move.b	#$FF,7(a1)
	move.b	$2A(a0),$2A(a1)
	move.l	a0,$2E(a1)
	clr.w	d0
	move.b	$2A(a0),d0
	lsl.w	#2,d0
	move.w	word_3FDE(pc,d0.w),$A(a1)
	move.w	word_3FE0(pc,d0.w),d2
	move.w	#5,$26(a1)
	movea.l	a1,a2
	bra.w	loc_41EC
; ---------------------------------------------------------------------------
word_3FDE:
	dc.w $A0

word_3FE0:
	dc.w $D4
	dc.w $180
	dc.w $14C
; ---------------------------------------------------------------------------

loc_3FE6:
	move.w	#$8000,d0
	move.b	$2A(a0),d0
	addq.b	#3,d0
	swap	d0
	clr.w	d0
	jsr	(QueuePlaneCmd).l
	move.w	#7,$28(a0)
	bsr.w	ActorBookmark
	move.w	#$8300,d0
	move.b	$2A(a0),d0
	swap	d0
	move.w	$28(a0),d0
	jsr	(QueuePlaneCmd).l
	subq.w	#1,$28(a0)
	bcs.s	loc_4022
	rts
; ---------------------------------------------------------------------------

loc_4022:
	clr.w	d0
	move.b	$2A(a0),d0
	lsl.w	#1,d0
	lea	(word_FF010E).l,a1
	move.w	(a1,d0.w),$26(a0)
	move.w	#$C0,$E(a0)
	move.w	#$8800,d0
	move.b	$2A(a0),d0
	swap	d0
	move.w	#$8000,d0
	move.b	$27(a0),d0
	jsr	(QueuePlaneCmd).l
	move.b	#SFX_RESULT_TIME,d0
	jsr	(PlaySound_ChkPCM).l
	bsr.w	ActorBookmark
	move.w	#$180,$28(a0)
	move.w	#$80,d4
	move.w	#$CC0A,d5
	move.w	#$8500,d6
	tst.b	$2A(a0)
	beq.s	loc_4084
	move.w	#$CC3A,d5
	move.w	#$A500,d6

loc_4084:
	bsr.w	ActorBookmark
	bsr.w	sub_56C0
	andi.b	#$F0,d0
	bne.s	loc_4112
	bsr.w	sub_56C0
	btst	#0,d0
	bne.s	loc_40AA
	btst	#1,d0
	bne.s	loc_40BA
	rts
; ---------------------------------------------------------------------------

loc_40AA:
	move.w	#$FFFF,d1
	tst.w	$26(a0)
	beq.w	locret_4110
	bra.w	loc_40C8
; ---------------------------------------------------------------------------

loc_40BA:
	move.w	#1,d1
	cmpi.w	#4,$26(a0)
	bcc.w	locret_4110

loc_40C8:
	cmpi.b	#2,(level_mode).l
	bne.s	loc_40D6
	asl.b	#1,d1

loc_40D6:
	move.w	#$8800,d0
	move.b	$2A(a0),d0
	swap	d0
	move.w	$26(a0),d0
	jsr	(QueuePlaneCmd).l
	add.w	d1,$26(a0)
	move.w	#$8800,d0
	move.b	$2A(a0),d0
	swap	d0
	move.w	#$8000,d0
	move.b	$27(a0),d0
	jsr	(QueuePlaneCmd).l
	move.b	#SFX_MENU_MOVE,d0
	jsr	(PlaySound_ChkPCM).l

locret_4110:
	rts
; ---------------------------------------------------------------------------

loc_4112:
	move.b	#SFX_MENU_SELECT,d0
	jsr	(PlaySound_ChkPCM).l
	clr.w	$28(a0)
	bsr.w	ActorBookmark
	move.w	#$18,$28(a0)
	bsr.w	ActorBookmark
	move.w	#$8800,d0
	move.b	$2A(a0),d0
	swap	d0
	move.w	$26(a0),d0
	move.w	$28(a0),d1
	andi.b	#2,d1
	ror.w	#2,d1
	or.w	d1,d0
	jsr	(QueuePlaneCmd).l
	subq.w	#1,$28(a0)
	beq.s	loc_4158
	rts
; ---------------------------------------------------------------------------

loc_4158:
	movea.l	$2E(a0),a1
	move.w	$26(a0),d0
	move.b	d0,$2B(a1)
	clr.b	8(a1)
	clr.w	d0
	move.b	$2A(a0),d0
	lsl.w	#1,d0
	lea	(word_FF010E).l,a1
	move.w	$26(a0),(a1,d0.w)
	clr.b	7(a0)
	bsr.w	ActorBookmark
	clr.w	$26(a0)
	bsr.w	ActorBookmark
	move.w	#$8300,d0
	move.b	$2A(a0),d0
	swap	d0
	move.w	$26(a0),d0
	jsr	(QueuePlaneCmd).l
	addq.w	#1,$26(a0)
	cmpi.w	#8,$26(a0)
	bcc.s	loc_41B0
	rts
; ---------------------------------------------------------------------------

loc_41B0:
	bsr.w	ActorBookmark
	move.w	#$8300,d0
	move.b	$2A(a0),d0
	swap	d0
	move.b	#$FF,d0
	jsr	(QueuePlaneCmd).l
	move.w	#$8000,d0
	move.b	$2A(a0),d0
	addq.b	#3,d0
	swap	d0
	move.w	#$FF00,d0
	jsr	(QueuePlaneCmd).l
	movea.l	$2E(a0),a1
	bclr	#0,7(a1)
	bra.w	ActorDeleteSelf
; ---------------------------------------------------------------------------

loc_41EC:
	move.w	#$B8,d1
	btst	#1,(level_mode).l
	bne.s	loc_4200
	move.w	#$B0,d1

loc_4200:
	lea	(loc_42FA).l,a1
	bsr.w	FindActorSlotQuick
	bcs.w	locret_4292
	move.b	$2A(a0),$2A(a1)
	move.l	a2,$2E(a1)
	move.b	#0,6(a1)
	move.b	#$30,8(a1)
	clr.w	d0
	tst.b	$2A(a1)
	beq.s	loc_4230
	move.b	#5,d0

loc_4230:
	move.b	d0,9(a1)
	move.w	d2,$A(a1)
	move.w	d1,$34(a1)
	move.w	d1,$E(a1)
	move.b	#$80,$36(a1)
	move.l	a0,-(sp)
	movea.l	a1,a0
	clr.w	d0
	bsr.w	sub_4294
	movea.l	(sp)+,a0
	movea.l	a1,a3
	lea	(loc_436A).l,a1
	bsr.w	FindActorSlotQuick
	bcs.s	locret_4292
	move.l	a2,$2E(a1)
	move.l	a3,$32(a1)
	move.b	#0,6(a1)
	move.b	#$21,8(a1)
	move.b	#0,9(a1)
	move.w	$A(a3),d2
	addi.w	#$10,d2
	move.w	d2,$A(a1)
	move.w	d1,$E(a1)
	addi.w	#$20,$E(a1)

locret_4292:
	rts
; End of function sub_3F94


; =============== S U B	R O U T	I N E =======================================


sub_4294:
	movem.l	d0/a0,-(sp)
	lsl.w	#2,d0
	tst.b	$2A(a0)
	bne.s	loc_42A8
	lea	((palette_buffer+$68)).l,a3
	bra.s	loc_42AE
; ---------------------------------------------------------------------------

loc_42A8:
	lea	((palette_buffer+$72)).l,a3

loc_42AE:
	move.l	(sp)+,d0
	mulu.w	#$A,d0
	lea	(PalTable_Difficulty).l,a0
	adda.w	d0,a0
	moveq	#4,d1

loc_42BE:
	move.w	(a0)+,(a3)+
	dbf	d1,loc_42BE
	movea.l	(sp)+,a0
	rts
; End of function sub_4294

; ---------------------------------------------------------------------------
PalTable_Difficulty:	; Difficulty Face Palettes!
	; Arms
	dc.w 6
	dc.w $2A
	dc.w $24C
	dc.w $48E
	dc.w $666

	; Frankly
	dc.w $404
	dc.w $A46
	dc.w $C8A
	dc.w $46
	dc.w $AC

	; Humpty
	dc.w $40
	dc.w $282
	dc.w $4A6
	dc.w $46
	dc.w $AC

	; Coconuts
	dc.w 4
	dc.w $48
	dc.w $48C
	dc.w $8CE
	dc.w $CE

	; Davy Sprocket
	dc.w $624
	dc.w $A48
	dc.w $E8A
	dc.w $64E
	dc.w $2CE
; ---------------------------------------------------------------------------

loc_42FA:
	move.w	#$10,d0
	bsr.w	ActorBookmark_SetDelay
	bsr.w	ActorBookmark
	move.b	#$80,6(a0)
	movea.l	$2E(a0),a1
	tst.b	7(a1)
	beq.w	ActorDeleteSelf
	clr.w	d0
	move.b	$27(a1),d0
	cmp.b	$28(a0),d0
	beq.w	locret_4368
	move.b	d0,$28(a0)
	move.b	d0,9(a0)
	tst.b	$2A(a0)
	beq.s	loc_4338
	addq.b	#5,9(a0)

loc_4338:
	move.w	d0,d1
	moveq	#$14,d2
	btst	#1,(level_mode).l
	bne.s	loc_434A
	moveq	#$18,d2

loc_434A:
	mulu.w	d2,d1
	add.w	$34(a0),d1
	move.w	d1,$E(a0)
	bsr.w	sub_4294
	move.b	#3,d0
	lea	((palette_buffer+$60)).l,a2
	jsr	(LoadPalette).l

locret_4368:
	rts
; ---------------------------------------------------------------------------

loc_436A:
	move.w	#$10,d0
	bsr.w	ActorBookmark_SetDelay
	bsr.w	ActorBookmark
	move.b	#$80,6(a0)
	movea.l	$2E(a0),a1
	tst.b	7(a1)
	beq.w	ActorDeleteSelf
	movea.l	$32(a0),a1
	clr.w	d0
	move.b	$28(a1),d0
	move.b	d0,9(a0)
	moveq	#$14,d2
	btst	#1,(level_mode).l
	bne.s	loc_43A6
	moveq	#$18,d2

loc_43A6:
	mulu.w	d2,d0
	add.w	$34(a1),d0
	move.w	d0,$E(a0)
	addi.w	#$20,$E(a0)
	rts

; =============== S U B	R O U T	I N E =======================================


sub_43B8:
	movea.l	$32(a0),a1
	move.b	$26(a1),d0
	move.b	$27(a1),d1
	movem.l	d0-d1,-(sp)
	move.w	$28(a1),$26(a1)
	move.w	$2A(a1),$28(a1)
	bsr.w	sub_43EA
	move.b	d0,$2A(a1)
	move.b	d1,$2B(a1)
	movem.l	(sp)+,d0-d1
	addq.w	#1,$1E(a1)
	rts
; End of function sub_43B8


; =============== S U B	R O U T	I N E =======================================


sub_43EA:
	move.b	(level_mode).l,d0
	andi.b	#3,d0
	beq.w	loc_448A
	cmpi.b	#1,d0
	beq.w	loc_44BA
	clr.w	d1
	move.b	$2B(a0),d1
	cmpi.b	#5,d1
	bcs.s	loc_4412
	move.b	#4,d1

loc_4412:
	clr.w	d0
	move.b	ExercisePuyoCount(pc,d1.w),d0
	move.l	d2,-(sp)
	move.w	d0,d1
	jsr	(RandomBound).l
	move.b	ExercisePuyoOrder(pc,d0.w),d2
	move.b	d2,d0
	exg	d0,d1
	jsr	(RandomBound).l
	move.b	ExercisePuyoOrder(pc,d0.w),d2
	move.b	d2,d0
	move.l	(sp)+,d2
	cmpi.b	#2,(level_mode).l
	beq.s	loc_4456
	rts
; ---------------------------------------------------------------------------
ExercisePuyoCount:	; Exercise Mode Level Puyo Counts
	dc.b   4
	dc.b   5
	dc.b   5
	dc.b   5
	dc.b   5
	dc.b   0

ExercisePuyoOrder:	; Order of Puyos in Exercise Mode
	dc.b   0
	dc.b   3
	dc.b   5
	dc.b   1
	dc.b   4
	dc.b   2
; ---------------------------------------------------------------------------

loc_4456:
	move.l	d2,-(sp)
	move.w	$20(a1),d2
	cmp.w	$1E(a1),d2
	bcc.s	loc_4484
	clr.w	$1E(a1)
	addi.w	#$C,$20(a1)
	bcc.s	loc_447A
	move.w	#$FFFF,$20(a1)

loc_447A:
	move.b	7(a1),d0
	addi.b	#$19,d0
	move.b	d0,d1

loc_4484:
	move.l	(sp)+,d2
	rts
; ---------------------------------------------------------------------------

loc_448A:
	movem.l	d2/a2,-(sp)
	clr.w	d2
	move.b	$20(a1),d2
	lea	(p1_puyo_order).l,a2
	tst.b	$2A(a0)
	beq.s	loc_44A8
	lea	(p2_puyo_order).l,a2

loc_44A8:
	move.b	(a2,d2.w),d0
	move.b	1(a2,d2.w),d1
	addq.b	#2,$20(a1)
	movem.l	(sp)+,d2/a2
	rts
; ---------------------------------------------------------------------------

loc_44BA:
	movem.l	d2/a2,-(sp)
	clr.w	d2
	move.b	$20(a1),d2
	lea	(p1_puyo_order).l,a2
	tst.b	$2B(a0)
	beq.s	loc_44D8
	lea	(p2_puyo_order).l,a2

loc_44D8:
	move.b	(a2,d2.w),d0
	move.b	1(a2,d2.w),d1
	addq.b	#2,$20(a1)
	movem.l	(sp)+,d2/a2
	rts
; End of function sub_43EA

; =============== S U B	R O U T	I N E =======================================

sub_44EA:
	clr.w	d3
	clr.w	d4

loc_44EE:
	lea	(nullsub_5).l,a1
	bsr.w	FindActorSlot
	bcc.s	loc_44FE
	rts
; ---------------------------------------------------------------------------

loc_44FE:
	move.l	a1,$32(a0)
	cmpi.b	#2,(level_mode).l
	bne.s	loc_4514
	move.w	#$FFFF,$20(a1)

loc_4514:
	move.b	(level_mode).l,d0
	or.b	$2A(a0),d0
	cmpi.b	#5,d0
	bne.w	*+4

loc_4526:
	move.w	#4,d2
	movem.l	d3-d4,-(sp)

loc_452E:
	bsr.w	sub_43EA
	move.b	d0,$26(a1,d2.w)
	move.b	d1,$27(a1,d2.w)
	subq.w	#2,d2
	bcc.s	loc_452E
	movea.l	a1,a2
	movem.l	(sp)+,d3-d4
	clr.w	d0
	move.b	(level_mode).l,d0
	andi.b	#3,d0
	lsl.b	#1,d0
	or.b	$2A(a0),d0
	move.b	(swap_controls).l,d1
	eor.b	d1,d0
	lsl.b	#2,d0
	move.w	word_45CA(pc,d0.w),d1
	move.w	word_45CC(pc,d0.w),d2
	add.w	d3,d1
	add.w	d4,d2
	lea	(loc_45EA).l,a1
	bsr.w	FindActorSlot
	bcc.s	loc_457C
	rts
; ---------------------------------------------------------------------------

loc_457C:
	move.l	a2,$2E(a1)
	move.b	#$80,6(a1)
	move.w	d1,$A(a1)
	move.w	d2,$E(a1)
	subi.w	#$10,d2
	move.b	#$FF,$36(a1)
	lea	(loc_45EA).l,a1
	bsr.w	FindActorSlot
	bcc.s	loc_45A8
	rts
; ---------------------------------------------------------------------------

loc_45A8:
	move.l	a2,$2E(a1)
	move.b	#$80,6(a1)
	move.b	#1,7(a1)
	move.w	d1,$A(a1)
	move.w	d2,$E(a1)
	move.b	#$FF,$36(a1)
	rts
; End of function sub_44EA

; =============== S U B	R O U T	I N E =======================================

nullsub_5:
	rts
; End of function nullsub_5

; ---------------------------------------------------------------------------
word_45CA:
	dc.w $108

word_45CC:
	dc.w $C6
	dc.w $138
	dc.w $C6
	dc.w $108
	dc.w $C6
	dc.w $138
	dc.w $C6
	dc.w $108
	dc.w $C6
	dc.w $138
	dc.w $C6
	dc.w $108
	dc.w $C6
	dc.w $138
	dc.w $C6
; ---------------------------------------------------------------------------

loc_45EA:
	movea.l	$2E(a0),a1
	clr.w	d1
	move.b	7(a0),d1
	move.b	$26(a1,d1.w),d0
	move.b	d0,8(a0)
	cmp.b	$36(a0),d0
	beq.s	loc_4610
	move.b	d0,$36(a0)
	clr.w	$22(a0)
	bsr.w	sub_4632

loc_4610:
	move.b	#$80,6(a0)
	tst.b	7(a0)
	beq.s	loc_462E
	cmpi.b	#$19,8(a0)
	bcs.s	loc_462E
	move.b	#0,6(a0)

loc_462E:
	bra.w	ActorAnimate

; =============== S U B	R O U T	I N E =======================================

sub_4632:
	move.l	#unk_465E,$32(a0)
	cmpi.b	#$19,8(a0)
	beq.s	loc_464A
	bcc.s	loc_4654
	rts
; ---------------------------------------------------------------------------

loc_464A:
	move.l	#unk_89AE,$32(a0)
	rts
; ---------------------------------------------------------------------------

loc_4654:
	move.l	#unk_4682,$32(a0)
	rts
; End of function sub_4632

; ---------------------------------------------------------------------------
; TODO: Document what these animations are for

unk_465E:
	dc.b $F0
	dc.b   0
	dc.b   1
	dc.b   2
	dc.b   0
	dc.b   0
	dc.b   2
	dc.b   3
	dc.b   0
	dc.b   0
	dc.b   1
	dc.b   2
	dc.b   0
	dc.b   0
	dc.b   2
	dc.b   3
	dc.b $FF
	dc.b   0
	dc.l unk_465E

unk_4674:
	dc.b   4
	dc.b   0
	dc.b   5
	dc.b   1
	dc.b   4
	dc.b   0
	dc.b   5
	dc.b   2
	dc.b $FF
	dc.b   0
	dc.l unk_4674

unk_4682:
	dc.b $F0
	dc.b   0
	dc.b   1
	dc.b   1
	dc.b   0
	dc.b   0
	dc.b   1
	dc.b   2
	dc.b   0
	dc.b   0
	dc.b   1
	dc.b   1
	dc.b   0
	dc.b   0
	dc.b   1
	dc.b   2
	dc.b $FF
	dc.b   0
	dc.l unk_4682

; =============== S U B	R O U T	I N E =======================================

SpawnGarbage:
	tst.w	aField14(a0)
	bne.s	loc_46A2
	rts
; ---------------------------------------------------------------------------

loc_46A2:
	bsr.w	GetPuyoField
	adda.l	#pPlaceablePuyos,a2
	lea	(garbage_puyo_data).l,a3
	bsr.w	SetGarbageOrder
	bsr.w	GetGarbageFreeSpace
	bsr.w	SetGarbageCounts
	sub.w	d7,aField14(a0)
	lea	(ActGarbagePuyo).l,a1
	bsr.w	FindActorSlot
	bcc.s	.Spawned
	rts
; ---------------------------------------------------------------------------

.Spawned:
	move.b	aField0(a0),aField0(a1)
	move.b	#1,aField20(a1)
	move.l	a0,aField2E(a1)
	movea.l	a1,a2
	move.b	aPlayerID(a0),aPlayerID(a1)
	bset	#2,aField7(a0)
	move.w	#2,d0
	tst.b	(level_mode).l
	bne.s	loc_4710
	cmpi.b	#3,(byte_FF0104).l
	bcc.s	loc_4710
	move.b	(byte_FF0104).l,d0

loc_4710:
	add.w	d0,d0
	move.w	word_4730(pc,d0.w),d3
	move.w	#5,d2
	bsr.w	GetPuyoFieldPos

loc_471E:
	tst.b	$C(a3,d2.w)
	beq.s	loc_472A
	bsr.w	sub_4736

loc_472A:
	dbf	d2,loc_471E
	rts
; End of function SpawnGarbage

; ---------------------------------------------------------------------------
word_4730:
	dc.w 3
	dc.w 2
	dc.w 0

; =============== S U B	R O U T	I N E =======================================

sub_4736:
	lea	(sub_486A).l,a1
	bsr.w	FindActorSlot
	bcc.s	loc_4746
	rts
; ---------------------------------------------------------------------------

loc_4746:
	move.b	0(a0),0(a1)
	move.b	$2A(a0),$2A(a1)
	move.b	#$85,6(a1)
	move.b	#6,8(a1)
	move.b	$C(a3,d2.w),d4
	addi.b	#$13,d4
	move.b	d4,9(a1)
	move.l	a2,$2E(a1)
	addq.w	#1,$26(a2)
	addq.b	#1,$20(a2)
	jsr	(sub_11E90).l
	move.w	d2,d4
	move.w	d4,$1A(a1)
	lsl.w	#4,d4
	add.w	d0,d4
	addq.w	#8,d4
	move.w	d4,$A(a1)
	move.w	#1,$1C(a1)
	move.w	#$FFFF,d4
	lsl.w	#4,d4
	add.w	d1,d4
	addq.w	#8,d4
	move.w	d4,$E(a1)
	subi.w	#$F,d4
	move.w	d4,$20(a1)
	move.w	d2,d4
	lsl.w	#1,d4
	move.w	word_47BA(pc,d4.w),d5
	move.w	d5,$1E(a1)
	move.w	d3,$16(a1)
	rts
; End of function sub_4736

; ---------------------------------------------------------------------------
word_47BA:
	dc.w $2400
	dc.w $2600
	dc.w $2000
	dc.w $2A00
	dc.w $2200
	dc.w $2800

; =============== S U B	R O U T	I N E =======================================

SetGarbageOrder:
	move.w	#5,d0

loc_47CA:
	move.b	d0,(a3,d0.w)
	dbf	d0,loc_47CA
	move.w	#5,d1

loc_47D6:
	move.w	#6,d0
	jsr	(RandomBound).l
	move.b	(a3,d0.w),d2
	move.b	(a3,d1.w),(a3,d0.w)
	move.b	d2,(a3,d1.w)
	dbf	d1,loc_47D6
	rts
; End of function SetGarbageOrder

; =============== S U B	R O U T	I N E =======================================

GetGarbageFreeSpace:
	move.w	#5,d0

loc_47F8:
	clr.b	d1
	move.w	d0,d2
	lsl.w	#1,d2
	move.w	#$C,d3

loc_4802:
	tst.b	(a2,d2.w)
	bne.s	loc_480C
	addq.b	#1,d1

loc_480C:
	addi.w	#$C,d2
	dbf	d3,loc_4802
	move.b	d1,6(a3,d0.w)
	dbf	d0,loc_47F8
	rts
; End of function GetGarbageFreeSpace

; =============== S U B	R O U T	I N E =======================================

SetGarbageCounts:
	move.w	#5,d0

loc_4822:
	clr.b	$C(a3,d0.w)
	dbf	d0,loc_4822
	move.w	aField14(a0),d0
	cmpi.w	#$1F,d0
	bcs.s	loc_483A
	move.w	#$1E,d0

loc_483A:
	subq.w	#1,d0
	clr.w	d1
	clr.w	d7

loc_4840:
	clr.w	d2
	move.b	(a3,d1.w),d2
	move.b	$C(a3,d2.w),d3
	cmp.b	6(a3,d2.w),d3
	bcc.s	loc_4858
	addq.b	#1,$C(a3,d2.w)
	addq.w	#1,d7

loc_4858:
	addq.b	#1,d1
	cmpi.b	#6,d1
	bcs.s	loc_4864
	clr.b	d1

loc_4864:
	dbf	d0,loc_4840
	rts
; End of function SetGarbageCounts

; =============== S U B	R O U T	I N E =======================================

sub_486A:
	bsr.w	sub_4948
	bcs.s	loc_4874
	rts
; ---------------------------------------------------------------------------

loc_4874:
	clr.w	d0
	move.b	9(a0),d0
	subi.w	#$14,d0

loc_487E:
	move.l	d0,-(sp)
	bsr.w	MarkPuyoSpot
	move.l	(sp)+,d0
	subq.w	#1,$1C(a0)
	dbf	d0,loc_487E
	movea.l	$2E(a0),a1
	subq.w	#1,$26(a1)
	move.b	9(a0),9(a1)
	bra.w	loc_502C
; End of function sub_486A

; =============== S U B	R O U T	I N E =======================================

ActGarbagePuyo:
	move.w	aField26(a0),aField28(a0)
	bsr.w	GetPuyoField
	andi.w	#$7F,d0
	move.w	d0,aField2C(a0)
	bsr.w	ActorBookmark

ActGarbagePuyo_Update:
	move.w	aField26(a0),d0
	cmp.w	aField28(a0),d0
	beq.s	loc_48EA
	move.w	d0,aField28(a0)
	move.w	aField20(a0),aField38(a0)
	btst	#0,aField7(a0)
	bne.s	loc_48EA
	move.b	#VOI_GARBAGE_1,d0
	jsr	(PlaySound_ChkPCM).l
	bset	#0,aField7(a0)

loc_48EA:
	move.b	aField36(a0),d0
	move.w	aField38(a0),d1
	move.w	aField2C(a0),d3
	move.w	#5,d4
	lea	(vscroll_buffer).l,a2

loc_4900:
	andi.b	#$7F,d0
	jsr	(Sin).l
	swap	d2
	move.w	d2,(a2,d3.w)
	addi.b	#$20,d0
	addq.w	#4,d3
	dbf	d4,loc_4900
	addi.b	#$18,aField36(a0)
	tst.w	aField38(a0)
	beq.s	loc_4930
	subi.w	#$40,aField38(a0)
	rts
; ---------------------------------------------------------------------------

loc_4930:
	tst.w	aField26(a0)
	beq.s	loc_493A
	rts
; ---------------------------------------------------------------------------

loc_493A:
	movea.l	aField2E(a0),a1
	bclr	#2,aField7(a1)
	bra.w	ActorDeleteSelf
; End of function ActGarbagePuyo

; =============== S U B	R O U T	I N E =======================================

sub_4948:
	move.l	aY(a0),d0
	move.l	aField16(a0),d1
	add.l	d0,d1
	move.l	d0,d2
	swap	d2
	move.l	d1,d3
	swap	d3
	sub.w	aField20(a0),d2
	sub.w	aField20(a0),d3
	eor.l	d2,d3
	btst	#4,d3
	beq.s	loc_4990
	move.b	#2,d0
	bsr.w	CheckPuyoLand2
	btst	#0,d0
	beq.s	loc_498C
	swap	d1
	andi.b	#$F8,d1
	move.w	d1,aY(a0)
	ori	#1,sr
	rts
; ---------------------------------------------------------------------------

loc_498C:
	addq.w	#1,aField1C(a0)

loc_4990:
	move.l	d1,aY(a0)
	moveq	#0,d0
	move.w	aField1E(a0),d0
	move.l	aField16(a0),d1
	add.l	d0,d1
	cmpi.l	#$80000,d1
	bcs.s	loc_49B0
	move.l	#$80000,d1

loc_49B0:
	move.l	d1,aField16(a0)
	andi	#$FFFE,sr
	rts
; End of function sub_4948


; =============== S U B	R O U T	I N E =======================================

sub_49BA:
	bsr.w	GetPuyoField
	movea.l	a2,a3
	adda.l	#pPuyosCopy,a3
	move.w	#(PUYO_FIELD_ROWS*PUYO_FIELD_COLS)-1,d0

loc_49CA:
	move.w	(a2)+,(a3)+
	dbf	d0,loc_49CA
	rts
; End of function sub_49BA

; =============== S U B	R O U T	I N E =======================================

sub_49D2:
	bsr.w	GetPuyoField
	adda.l	#pVisiblePuyos,a2
	movea.l	a2,a3
	adda.l	#pVisiblePuyos+(PUYO_FIELD_COLS*(PUYO_FIELD_ROWS-4)*2),a3
	movea.l	a3,a4
	adda.l	#pUnk1,a4
	clr.w	d0
	move.b	aDelay+1(a0),d1
	andi.b	#1,d1
	eori.b	#1,d1
	clr.b	d2
	sub.b	d1,d2

loc_49FE:
	move.b	(a3,d0.w),d1
	bmi.w	.Unaffected
	move.b	(a4,d0.w),d3
	and.b	d2,d3
	move.b	d3,(a2,d0.w)

.Unaffected:
	addq.w	#2,d0
	cmpi.w	#PUYO_FIELD_COLS*(PUYO_FIELD_ROWS-2)*2,d0
	bcs.s	loc_49FE
	DISABLE_INTS
	bsr.w	sub_5782
	ENABLE_INTS
	rts
; End of function sub_49D2

; =============== S U B	R O U T	I N E =======================================

CheckPuyoPop:
	bsr.w	GetPuyoField
	bsr.w	GetPuyoFieldPos
	addq.w	#8,d0
	move.w	d0,d2
	addq.w	#8,d1
	move.w	d1,d3
	adda.l	#pVisiblePuyos,a2
	movea.l	a2,a3
	adda.l	#pUnk1-pVisiblePuyos,a3
	movea.l	a3,a4
	adda.l	#pVisiblePuyosCopy-pUnk1,a4
	clr.w	d4
	clr.b	d5
	clr.w	d6

.CheckPuyos:
	move.b	(a3,d4.w),d7
	bmi.w	.Unaffected
	btst	#6,d7
	beq.w	.Popped

.Removed:
	bsr.w	SpawnGarbageRemove
	bra.w	.Unaffected
; ---------------------------------------------------------------------------

.Popped:
	bsr.w	SpawnPuyoPop

.Unaffected:
	addi.w	#$10,d2
	addq.b	#1,d5
	cmpi.b	#6,d5
	bcs.w	.NextPuyo
	clr.b	d5
	move.w	d0,d2
	addi.w	#$10,d3

.NextPuyo:
	addq.w	#2,d4
	cmpi.w	#$90,d4
	bcs.s	.CheckPuyos
	bra.s	loc_4ABC
; ---------------------------------------------------------------------------
;	Leftover from Puyo Puyo's system of handling Voices when Popping Puyos
	btst	#1,(level_mode).l
	bne.s	loc_4ABC
	clr.w	d1
	cmpi.b	#1,aFrame(a0)
	bne.s	loc_4ABC
	move.b	#VOI_EGGMOBILE,d0
	tst.b	aPlayerID(a0)
	beq.s	loc_4AB6
	move.b	#VOI_P1_COMBO_1,d0

loc_4AB6:
	jmp	(PlaySound_ChkPCM).l
; ---------------------------------------------------------------------------

loc_4ABC:
	clr.w	d1
	move.b	aFrame(a0),d1
	cmpi.b	#7,d1
	bcs.s	loc_4ACE
	move.b	#6,d1

loc_4ACE:
	move.b	PuyoPopSounds(pc,d1.w),d0
	jmp	(PlaySound_ChkPCM).l
; End of function CheckPuyoPop

; ---------------------------------------------------------------------------
PuyoPopSounds:
	dc.b SFX_PUYO_POP_1
	dc.b SFX_PUYO_POP_2
	dc.b SFX_PUYO_POP_3
	dc.b SFX_PUYO_POP_4
	dc.b SFX_PUYO_POP_5
	dc.b SFX_PUYO_POP_6
	dc.b SFX_PUYO_POP_7
	dc.b 0

; =============== S U B	R O U T	I N E =======================================

SpawnPuyoPop:
	lea	(ActPuyoPop).l,a1
	bsr.w	FindActorSlotQuick
	bcc.s	.Spawned
	rts
; ---------------------------------------------------------------------------

.Spawned:
	move.b	aField0(a0),aField0(a1)
	move.b	aPlayerID(a0),aPlayerID(a1)
	move.b	#$80,aDrawFlags(a1)
	move.b	#8,aFrame(a1)
	move.w	d2,aX(a1)
	move.w	d3,aY(a1)
	move.w	d2,(garbage_glow_x).l
	move.w	d3,(garbage_glow_y).l
	move.l	#Anim_PuyoPop,aAnim(a1)
	move.w	d6,aDelay(a1)
	addq.w	#4,d6
	andi.w	#$F,d6
	move.b	(a4,d4.w),d7
	lsr.b	#4,d7
	andi.b	#7,d7
	move.b	d7,aMappings(a1)
	rts
; End of function SpawnPuyoPop

; =============== S U B	R O U T	I N E =======================================

SpawnGarbageRemove:
	lea	(ActGarbageRemove).l,a1
	bsr.w	FindActorSlotQuick
	bcc.s	.Spawned
	rts
; ---------------------------------------------------------------------------

.Spawned:
	move.b	aField0(a0),aField0(a1)
	move.b	#$80,aDrawFlags(a1)
	move.b	#6,aMappings(a1)
	move.w	d2,aX(a1)
	move.w	d3,aY(a1)
	move.l	#Anim_GarbageRemove,aAnim(a1)
	rts
; End of function SpawnGarbageRemove


; =============== S U B	R O U T	I N E =======================================

ActPuyoPop:
	bsr.w	ActorBookmark
	bsr.w	ActPuyoPop_Pop
	bsr.w	ActorBookmark
	bsr.w	ActorAnimate
	bcs.w	ActorDeleteSelf
	rts
; End of function ActPuyoPop

; ---------------------------------------------------------------------------
Anim_PuyoPop:
	dc.b   8
	dc.b   8
	dc.b   1
	dc.b   4
	dc.b   1
	dc.b   5
	dc.b   1
	dc.b   6
	dc.b $FE
	dc.b   0

; =============== S U B	R O U T	I N E =======================================

ActPuyoPop_Pop:
	move.b	(level_mode).l,d2
	andi.b	#3,d2
	bne.w	ActPuyoPop_PopNormal
	tst.b	aPlayerID(a0)
	beq.w	ActPuyoPop_PopNormal
	clr.w	d0
	move.b	(opponent).l,d0
	lsl.b	#2,d0
	movea.l	off_4BB8(pc,d0.w),a1
	jmp	(a1)
; ---------------------------------------------------------------------------
off_4BB8:
	dc.l ActPuyoPop_PopNormal	; Practise Stage 1
	dc.l ActPuyoPop_PopNormal	; Practise Stage 2
	dc.l ActPuyoPop_PopNormal	; Practise Stage 3
	dc.l ActPuyoPop_PopNormal	; Stage 1
	dc.l ActPuyoPop_PopNormal	; Stage 2
	dc.l ActPuyoPop_PopNormal	; Stage 3
	dc.l ActPuyoPop_PopNormal	; Stage 4
	dc.l ActPuyoPop_PopNormal	; Stage 5
	dc.l ActPuyoPop_PopNormal	; Stage 6
	dc.l ActPuyoPop_PopNormal	; Stage 7
	dc.l ActPuyoPop_PopNormal	; Stage 8
	dc.l ActPuyoPop_PopNormal	; Stage 9
	dc.l ActPuyoPop_PopNormal	; Stage 10
	dc.l ActPuyoPop_PopNormal	; Stage 11
	dc.l ActPuyoPop_PopNormal	; Stage 12
	dc.l ActPuyoPop_PopNormal	; Stage 13
; ---------------------------------------------------------------------------
	lea	(loc_4C46).l,a1
	bsr.w	FindActorSlotQuick
	bcs.s	locret_4C44
	move.b	0(a0),0(a1)
	move.b	#$10,8(a1)
	bsr.w	Random
	andi.b	#3,d0
	addi.b	#$F,d0
	move.b	d0,9(a1)
	move.w	$A(a0),$A(a1)
	move.w	$E(a0),$E(a1)
	move.w	#$1400,$1C(a1)
	move.w	#$FFFE,$16(a1)
	move.w	#$FFFF,$20(a1)
	move.w	#$20,$26(a1)

locret_4C44:
	rts
; ---------------------------------------------------------------------------

loc_4C46:
	move.w	#4,d0
	bsr.w	ActorBookmark_SetDelay
	bsr.w	ActorBookmark
	move.b	#$85,6(a0)
	bsr.w	sub_3810
	subq.w	#1,$26(a0)
	beq.s	loc_4C66
	rts
; ---------------------------------------------------------------------------

loc_4C66:
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------
	move.b	#$20,d0
	move.w	#$180,d1
	move.w	#3,d3

loc_4C78:
	lea	(loc_4CCE).l,a1
	bsr.w	FindActorSlotQuick
	bcs.s	loc_4CC8
	move.b	0(a0),0(a1)
	move.b	#6,8(a1)
	move.b	#$F,9(a1)
	move.w	$A(a0),$A(a1)
	move.w	$E(a0),$E(a1)
	move.w	#$18,$26(a1)
	move.l	d0,-(sp)
	jsr	(Sin).l
	move.l	d2,$12(a1)
	jsr	(Cos).l
	move.l	d2,$16(a1)
	move.l	(sp)+,d0
	addi.b	#$40,d0

loc_4CC8:
	dbf	d3,loc_4C78
	rts
; ---------------------------------------------------------------------------

loc_4CCE:
	move.w	#4,d0
	bsr.w	ActorBookmark_SetDelay
	bsr.w	ActorBookmark
	move.b	#$83,6(a0)
	jsr	(sub_3810).l
	subq.w	#1,$26(a0)
	beq.s	loc_4CF0
	rts
; ---------------------------------------------------------------------------

loc_4CF0:
	move.w	#4,d0
	bsr.w	ActorBookmark_SetDelay
	bsr.w	ActorBookmark
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

ActPuyoPop_PopNormal:
	move.w	#3,d3
	move.w	#$400,d1

.SpawnPieces:
	lea	(ActPuyoPoppedPiece).l,a1
	bsr.w	FindActorSlotQuick
	bcs.s	.DoLoop
	move.b	aField0(a0),aField0(a1)
	move.b	aMappings(a0),aMappings(a1)
	move.b	#6,aFrame(a1)
	move.w	aX(a0),aX(a1)
	move.w	aY(a0),aY(a1)
	move.w	#$4000,aField1C(a1)
	move.w	#$FFFF,$20(a1)
	move.l	#Anim_PuyoPoppedPiece,aAnim(a1)
	move.b	d3,d2
	ror.b	#4,d2
	addi.b	#$64,d2
	bsr.w	Random
	andi.b	#7,d0
	add.b	d2,d0
	jsr	(Sin).l
	move.l	d2,aField12(a1)
	jsr	(Cos).l
	move.l	d2,aField16(a1)

.DoLoop:
	dbf	d3,.SpawnPieces
	rts
; End of function ActPuyoPop_Pop

; =============== S U B	R O U T	I N E =======================================

ActPuyoPoppedPiece:
	move.w	#4,d0
	bsr.w	ActorBookmark_SetDelay
	bsr.w	ActorBookmark
	move.b	#$87,aDrawFlags(a0)
	bsr.w	ActorAnimate
	bcs.w	ActorDeleteSelf
	bsr.w	sub_3810
	bcs.w	ActorDeleteSelf
	rts
; End of function ActPuyoPoppedPiece

; ---------------------------------------------------------------------------
Anim_PuyoPoppedPiece:
	dc.b 1, 6, 3, 5, 6, 4, 3, 5, 4, 6, $FE, 0

; =============== S U B	R O U T	I N E =======================================

ActGarbageRemove:
	bsr.w	ActorAnimate
	bcs.w	ActorDeleteSelf
	rts
; End of function ActGarbageRemove

; ---------------------------------------------------------------------------
Anim_GarbageRemove:
	dc.b	6, 0, 6, 1, 6, 2, 6, 3, $FE, 0

; =============== S U B	R O U T	I N E =======================================

sub_4DB8:
	bsr.w	GetPuyoField
	movea.l	a2,a3
	adda.l	#pPlaceablePuyos,a2
	adda.l	#pUnk6,a3
	move.w	#$9A,d0

loc_4DCE:
	move.w	d0,d1
	move.w	d0,d2
	clr.w	d3

loc_4DD4:
	clr.w	(a3,d1.w)
	addi.w	#$100,d3
	tst.b	(a2,d1.w)
	beq.s	loc_4E04
	move.w	(a2,d1.w),d4
	clr.b	(a2,d1.w)
	andi.w	#$FF00,d4
	move.w	d4,(a2,d2.w)
	subi.w	#$C,d2
	subi.w	#$100,d3
	beq.s	loc_4E04
	move.w	d3,(a3,d1.w)

loc_4E04:
	subi.w	#$C,d1
	bcc.s	loc_4DD4
	subq.w	#2,d0
	cmpi.w	#$90,d0
	bcc.s	loc_4DCE
	rts
; End of function sub_4DB8

; ---------------------------------------------------------------------------

loc_4E14:
	move.l	a0,d0
	swap	d0
	move.w	#$8900,d0
	swap	d0
	jmp	(QueuePlaneCmd).l

; =============== S U B	R O U T	I N E =======================================

sub_4E24:
	bsr.w	sub_43B8
	cmpi.b	#$19,d0
	beq.w	loc_8960
	cmpi.b	#$1A,d1
	beq.w	loc_8CC2
	movem.l	d0-d1,-(sp)
	bsr.w	GetPuyoField
	movem.l	(sp)+,d0-d1
	tst.b	$1C(a2)
	beq.s	loc_4E52
	ori	#1,sr
	rts
; ---------------------------------------------------------------------------

loc_4E52:
	lea	(loc_4F06).l,a1
	bsr.w	FindActorSlot
	move.b	0(a0),0(a1)
	move.l	a0,$2E(a1)
	move.l	#unk_4EFC,$32(a1)
	move.b	$2A(a0),$2A(a1)
	move.b	d0,8(a1)
	move.w	#2,$1A(a1)
	move.w	#2,$1C(a1)
	move.w	#0,$1E(a1)
	move.w	#0,$20(a1)
	ori.b	#1,7(a0)
	movea.l	a1,a2
	lea	(loc_5474).l,a1
	bsr.w	FindActorSlot
	move.b	0(a0),0(a1)
	move.l	a2,$2E(a1)
	move.l	#unk_4EE4,$32(a1)
	move.b	$2A(a0),$2A(a1)
	move.b	d1,8(a1)
	move.b	#0,$2B(a1)
	move.l	a1,$36(a2)
	ori.b	#2,7(a0)
	andi	#$FFFE,sr
	rts
; End of function sub_4E24

; ---------------------------------------------------------------------------
; TODO: Document this animation code

unk_4ED4:
	dc.b   1
	dc.b   2
	dc.b   0
	dc.b   0
	dc.b   2
	dc.b   3
	dc.b   0
	dc.b   0
	dc.b   1
	dc.b   2
	dc.b   0
	dc.b   0
	dc.b   2
	dc.b   3
	dc.b   0
	dc.b   0

unk_4EE4:
	dc.b $FE
	dc.b   0

unk_4EE6:
	dc.b   1
	dc.b   2
	dc.b   0
	dc.b   0
	dc.b   2
	dc.b   3
	dc.b   0
	dc.b   0
	dc.b   1
	dc.b   2
	dc.b   0
	dc.b   0
	dc.b   2
	dc.b   3
	dc.b   0
	dc.b   0
	dc.b $FF
	dc.b   0
	dc.l unk_4EFC

unk_4EFC:
	dc.b  $A
	dc.b   1
	dc.b   8
	dc.b   0
	dc.b $FF
	dc.b   0
	dc.l unk_4EFC
; ---------------------------------------------------------------------------

loc_4F06:
	bsr.w	sub_543C
	move.b	#$80,aDrawFlags(a0)
	bsr.w	ActorBookmark
	movea.l	aField2E(a0),a1
	btst	#0,aField7(a1)
	beq.s	loc_4F3A
	bsr.w	ActorAnimate
	bsr.w	sub_5060
	bsr.w	sub_5384
	bsr.w	sub_50DA
	bcs.s	loc_4F50
	bra.w	sub_543C
; ---------------------------------------------------------------------------

loc_4F3A:
	move.b	#0,aDrawFlags(a0)
	movea.l	aField36(a0),a1
	move.b	#0,aDrawFlags(a1)
	bsr.w	ActorBookmark
	rts
; ---------------------------------------------------------------------------

loc_4F50:
	bsr.w	sub_543C
	bsr.w	CheckPuyoLand
	ori.b	#4,d0
	move.b	d0,aField7(a0)
	btst	#0,d0
	bne.s	loc_4FA0
	move.w	$E(a0),d0
	subi.w	#$F,d0
	move.w	d0,$20(a0)
	move.w	#$3000,$1E(a0)
	move.w	#1,$16(a0)
	move.b	#0,9(a0)
	bsr.w	ActorBookmark
	bsr.w	sub_4948
	bcs.s	loc_4F94
	rts
; ---------------------------------------------------------------------------

loc_4F94:
	bsr.w	PlayPuyoLandSound
	move.l	#unk_4ED4,$32(a0)

loc_4FA0:
	clr.b	$22(a0)
	bsr.w	ActorBookmark
	bsr.w	ActorAnimate
	bcs.s	loc_4FB2
	rts
; ---------------------------------------------------------------------------

loc_4FB2:
	movea.l	$2E(a0),a1
	bclr	#0,7(a1)
	bsr.w	MarkPuyoSpot

loc_4FC0:
	move.b	#7,9(a0)
	move.w	#$18,d0
	bsr.w	ActorBookmark_SetDelay
	clr.w	d0
	move.b	$2A(a0),d0
	lea	(puyos_popping).l,a1
	tst.b	(a1,d0.w)
	bne.w	ActorDeleteSelf
	bsr.w	ActorBookmark
	move.b	#6,$26(a0)
	clr.b	$28(a0)
	bsr.w	ActorBookmark
	move.b	$2A(a0),d0
	lea	(puyos_popping).l,a1
	tst.b	(a1,d0.w)
	bne.w	ActorDeleteSelf
	addq.b	#1,$28(a0)
	cmpi.b	#4,$28(a0)
	bcc.s	loc_5016
	rts
; ---------------------------------------------------------------------------

loc_5016:
	clr.b	$28(a0)
	subq.w	#1,$A(a0)
	subq.w	#1,$E(a0)
	subq.b	#1,$26(a0)
	beq.w	ActorDeleteSelf
	rts
; ---------------------------------------------------------------------------
; START	OF FUNCTION CHUNK FOR sub_486A

loc_502C:
	cmpi.b	#$15,9(a0)
	bcc.w	ActorDeleteSelf
	addq.b	#6,9(a0)
	move.w	#$30,$26(a0)
	bsr.w	ActorBookmark
	move.b	$2A(a0),d0
	lea	(puyos_popping).l,a1
	tst.b	(a1,d0.w)
	bne.w	ActorDeleteSelf
	subq.w	#1,$26(a0)
	beq.w	ActorDeleteSelf
	rts
; END OF FUNCTION CHUNK	FOR sub_486A

; =============== S U B	R O U T	I N E =======================================

sub_5060:
	tst.w	$1E(a0)
	beq.s	loc_507E
	move.w	#8,d0
	btst	#7,$1E(a0)
	bne.s	loc_5078
	neg.w	d0

loc_5078:
	add.w	d0,$1E(a0)
	rts
; ---------------------------------------------------------------------------

loc_507E:
	btst	#3,7(a0)
	beq.s	loc_508A
	rts
; ---------------------------------------------------------------------------

loc_508A:
	bsr.w	sub_56C0
	btst	#2,d1
	bne.s	loc_50A0
	btst	#3,d1
	bne.s	loc_50B0
	rts
; ---------------------------------------------------------------------------

loc_50A0:
	move.b	#3,d0
	move.w	#$FFFF,d2
	move.w	#8,d3
	bra.w	loc_50BC
; ---------------------------------------------------------------------------

loc_50B0:
	move.b	#1,d0
	move.w	#1,d2
	move.w	#$FFF8,d3

loc_50BC:
	bsr.w	CheckPuyoLand2
	tst.b	d0
	beq.s	loc_50C8
	rts
; ---------------------------------------------------------------------------

loc_50C8:
	move.w	$1A(a0),d0
	add.w	d2,d0
	move.w	d0,$1A(a0)
	move.w	d3,$1E(a0)
	bra.w	PlayPuyoMoveSound
; End of function sub_5060

; =============== S U B	R O U T	I N E =======================================

sub_50DA:
	btst	#3,7(a0)
	bne.w	loc_51B4
	movea.l	$2E(a0),a1
	move.w	$1A(a1),d1
	cmpi.w	#$8001,d1
	bcc.w	loc_5222
	bsr.w	sub_56C0
	lsr.w	#8,d0
	andi.b	#$E,d0
	cmpi.b	#2,d0
	bne.s	loc_511A
	move.w	#$8000,d1
	move.w	(frame_count).l,d2
	lsl.b	#3,d2
	andi.b	#8,d2
	or.b	d2,7(a1)

loc_511A:
	move.w	$20(a0),d0
	add.w	d0,d1
	bcs.s	loc_516A
	move.w	d1,$20(a0)
	eor.w	d1,d0
	bpl.w	loc_5164
	bsr.w	CheckPuyoLand
	tst.b	d0
	beq.s	loc_5164
	move.b	d0,d2
	bsr.w	PuyoLandEffects
	btst	#0,d2
	beq.s	loc_514A
	bsr.w	sub_5288

loc_514A:
	btst	#1,d2
	beq.s	loc_5156
	bsr.w	sub_52AE

loc_5156:
	addq.w	#1,$26(a0)
	cmpi.w	#8,$26(a0)
	bcc.s	loc_51B4

loc_5164:
	andi	#$FFFE,sr
	rts
; ---------------------------------------------------------------------------

loc_516A:
	bsr.w	CheckPuyoLand
	tst.b	d0
	bne.s	loc_5182
	clr.w	$20(a0)
	addq.w	#1,$1C(a0)
	andi	#$FFFE,sr
	rts
; ---------------------------------------------------------------------------

loc_5182:
	tst.w	$28(a0)
	bne.s	loc_5194
	bsr.w	sub_51DA
	andi	#$FFFE,sr
	rts
; ---------------------------------------------------------------------------

loc_5194:
	subq.w	#1,$28(a0)
	beq.s	loc_51B4
	bsr.w	sub_56C0
	lsr.w	#8,d0
	andi.b	#$E,d0
	cmpi.b	#2,d0
	beq.s	loc_51B4
	andi	#$FFFE,sr
	rts
; ---------------------------------------------------------------------------

loc_51B4:
	bset	#3,7(a0)
	tst.w	$1E(a0)
	bne.s	loc_51D4
	movea.l	$36(a0),a1
	tst.b	$38(a1)

loc_51CA:
	bne.s	loc_51D4
	ori	#1,sr
	rts
; ---------------------------------------------------------------------------

loc_51D4:
	andi	#$FFFE,sr
	rts
; End of function sub_50DA

; =============== S U B	R O U T	I N E =======================================

sub_51DA:
	movea.l	aField2E(a0),a1
	cmpi.b	#8,aField2B(a1)
	clr.w	d0
	move.b	$1A(a0),d0
	bpl.w	loc_51F2
	move.b	#$7F,d0

loc_51F2:
	lsr.b	#3,d0
	neg.w	d0
	addi.w	#$20,d0
	move.w	d0,aField28(a0)
	rts
; End of function sub_51DA

; ---------------------------------------------------------------------------
	clr.w	d0
	move.b	aField2B(a1),d0
	subq.b	#8,d0
	lsr.b	#2,d0
	cmpi.b	#8,d0
	bcs.s	loc_5216
	move.b	#7,d0

loc_5216:
	neg.w	d0
	addi.w	#$11,d0
	move.w	d0,aField28(a0)
	rts
; ---------------------------------------------------------------------------
; START	OF FUNCTION CHUNK FOR sub_50DA

loc_5222:
	move.w	aField20(a0),d2
	add.w	d1,aField20(a0)
	bcs.s	loc_5230
	rts
; ---------------------------------------------------------------------------

loc_5230:
	bsr.w	CheckPuyoLand
	tst.b	d0
	bne.s	loc_524A
	addq.w	#1,aField1C(a0)
	andi.b	#$FE,aField21(a0)
	andi	#$FFFE,sr
	rts
; ---------------------------------------------------------------------------

loc_524A:
	cmpi.w	#$FFFF,d2
	beq.s	loc_527E
	move.b	d0,d2
	bsr.w	PuyoLandEffects
	btst	#0,d2
	beq.s	loc_5264
	bsr.w	sub_5288

loc_5264:
	btst	#1,d2
	beq.s	loc_5270
	bsr.w	sub_52AE

loc_5270:
	addq.w	#1,aField26(a0)
	cmpi.w	#8,aField26(a0)
	bcc.w	loc_51B4

loc_527E:
	move.w	#$FFFF,aField20(a0)
	bra.w	loc_5182
; END OF FUNCTION CHUNK	FOR sub_50DA

; =============== S U B	R O U T	I N E =======================================

sub_5288:
	cmpi.b	#$19,aMappings(a0)
	beq.w	locret_52AC
	move.l	#unk_8E92,aAnim(a0)
	cmpi.b	#$1A,aMappings(a0)
	beq.w	locret_52AC
	move.l	#unk_4EE6,aAnim(a0)

locret_52AC:
	rts
; End of function sub_5288

; =============== S U B	R O U T	I N E =======================================

sub_52AE:
	cmpi.b	#$19,aMappings(a0)
	beq.w	locret_52D4
	bcs.s	loc_52C8
	move.l	#unk_8E92,aAnim(a0)
	bra.w	locret_52D4
; ---------------------------------------------------------------------------

loc_52C8:
	movea.l	aField36(a0),a1
	move.l	#unk_4ED4,aAnim(a1)

locret_52D4:
	rts
; End of function sub_52AE


; =============== S U B	R O U T	I N E =======================================

CheckPuyoLand:
	move.b	#2,d0
	bsr.w	CheckPuyoLand2
	tst.b	d0
	beq.w	locret_52F2
	btst	#0,aField2B(a0)
	bne.w	locret_52F2
	ori.b	#3,d0

locret_52F2:
	rts
; End of function CheckPuyoLand

; =============== S U B	R O U T	I N E =======================================

CheckPuyoLand2:
	movem.l	d1-d7/a2,-(sp)
	move.b	#3,d7
	clr.w	d2
	move.b	d0,d2
	lsl.b	#2,d2
	clr.w	d3
	move.b	aField2B(a0),d3
	lsl.b	#2,d3
	move.w	aField1A(a0),d0
	add.w	word_5374(pc,d2.w),d0
	move.w	aField1C(a0),d1
	add.w	word_5376(pc,d2.w),d1
	cmpi.w	#6,d0
	bcc.s	loc_5344
	cmpi.w	#$E,d1
	bcc.s	loc_5344
	movem.l	d0-d1,-(sp)
	bsr.w	GetPuyoFieldTile
	move.b	(a2,d1.w),d4
	movem.l	(sp)+,d0-d1
	tst.b	d4
	bne.s	loc_5344
	andi.b	#$FE,d7

loc_5344:
	add.w	word_5374(pc,d3.w),d0
	add.w	word_5376(pc,d3.w),d1
	cmpi.w	#6,d0
	bcc.s	loc_536C
	cmpi.w	#$E,d1
	bcc.s	loc_536C
	bsr.w	GetPuyoFieldTile
	tst.b	(a2,d1.w)
	bne.s	loc_536C
	andi.b	#$FD,d7

loc_536C:
	move.b	d7,d0
	movem.l	(sp)+,d1-d7/a2
	rts
; End of function CheckPuyoLand2

; ---------------------------------------------------------------------------
word_5374:
	dc.w 0

word_5376:
	dc.w -1
	dc.w 1
	dc.w 0
	dc.w 0
	dc.w 1
	dc.w -1
	dc.w 0

; =============== S U B	R O U T	I N E =======================================

sub_5384:
	movea.l	aField36(a0),a1
	tst.b	aField38(a1)
	beq.w	*+4

loc_5390:
	btst	#3,7(a0)
	beq.s	loc_539C
	rts
; ---------------------------------------------------------------------------

loc_539C:
	bsr.w	sub_56C0
	bsr.w	sub_5712
	btst	#6,d0
	bne.s	loc_53B6
	btst	#5,d0
	bne.s	loc_53C2
	rts
; ---------------------------------------------------------------------------

loc_53B6:
	move.b	#$FF,d0
	move.b	#$F8,d1
	bra.w	loc_53CA
; ---------------------------------------------------------------------------

loc_53C2:
	move.b	#1,d0
	move.b	#8,d1

loc_53CA:
	add.b	aField2B(a0),d0
	andi.b	#3,d0
	move.b	d0,d2
	bsr.w	CheckPuyoLand2
	btst	#0,d0
	beq.s	loc_5416
	move.b	d2,d0
	eori.b	#2,d0
	bsr.w	CheckPuyoLand2
	btst	#0,d0
	beq.s	loc_53F4
	rts
; ---------------------------------------------------------------------------

loc_53F4:
	clr.w	d0
	move.b	d2,d0
	lsl.b	#2,d0
	move.w	word_542C(pc,d0.w),d3
	move.w	word_542E(pc,d0.w),d4
	add.w	d3,$1A(a0)
	add.w	d4,$1C(a0)
	tst.w	d4
	beq.s	loc_5416
	move.w	#$7FFE,aField20(a0)

loc_5416:
	move.b	aField2B(a0),d0
	ror.b	#2,d0
	move.b	d0,aField36(a1)
	move.b	d2,aField2B(a0)
	move.b	d1,aField38(a1)
	bra.w	PlayPuyoRotateSound
; End of function sub_5384

; ---------------------------------------------------------------------------
word_542C:
	dc.w 0

word_542E:
	dc.w 1
	dc.w -1
	dc.w 0
	dc.w 0
	dc.w -1
	dc.w 1
	dc.w 0

; =============== S U B	R O U T	I N E =======================================

sub_543C:
	bsr.w	GetPuyoFieldPos
	move.w	aField1A(a0),d2
	lsl.w	#4,d2
	add.w	d2,d0
	move.w	aField1E(a0),d2
	add.w	d2,d0
	addq.w	#8,d0
	move.w	d0,$A(a0)
	move.w	aField1C(a0),d2
	subq.w	#2,d2
	lsl.w	#4,d2
	add.w	d2,d1
	addq.w	#8,d1
	move.w	aField20(a0),d2
	rol.w	#4,d2
	andi.w	#8,d2
	add.w	d2,d1
	subq.w	#8,d1
	move.w	d1,aY(a0)
	rts
; End of function sub_543C

; ---------------------------------------------------------------------------

loc_5474:
	bsr.w	sub_5552
	move.b	#$80,6(a0)
	bsr.w	ActorBookmark
	bsr.w	ActorAnimate
	bsr.w	sub_5530
	bsr.w	sub_5552
	movea.l	$2E(a0),a1
	btst	#2,7(a1)
	bne.s	loc_549E
	rts
; ---------------------------------------------------------------------------

loc_549E:
	move.w	$1A(a1),d0
	move.w	$1C(a1),d1
	clr.w	d2
	move.b	$2B(a1),d2
	lsl.b	#2,d2
	lea	(word_5374).l,a2
	add.w	(a2,d2.w),d0
	add.w	2(a2,d2.w),d1
	move.w	d0,$1A(a0)
	move.w	d1,$1C(a0)
	move.l	$2E(a1),$2E(a0)
	move.b	7(a1),7(a0)
	bsr.w	ActorBookmark
	btst	#1,7(a0)
	bne.s	loc_5510
	move.w	$E(a0),d0
	subi.w	#$F,d0
	move.w	d0,$20(a0)
	move.w	#$3000,$1E(a0)
	move.w	#1,$16(a0)
	bsr.w	ActorBookmark
	bsr.w	sub_4948
	bcs.s	loc_5504
	rts
; ---------------------------------------------------------------------------

loc_5504:
	bsr.w	PlayPuyoLandSound
	move.l	#unk_4ED4,$32(a0)

loc_5510:
	bsr.w	ActorBookmark
	bsr.w	ActorAnimate
	bcs.s	loc_551E
	rts
; ---------------------------------------------------------------------------

loc_551E:
	movea.l	$2E(a0),a1
	bclr	#1,7(a1)
	bsr.w	MarkPuyoSpot
	bra.w	loc_4FC0

; =============== S U B	R O U T	I N E =======================================

sub_5530:
	move.b	$38(a0),d0
	bne.s	loc_553A
	rts
; ---------------------------------------------------------------------------

loc_553A:
	add.b	d0,$36(a0)
	move.b	$36(a0),d0
	andi.b	#$3F,d0
	beq.s	loc_554C
	rts
; ---------------------------------------------------------------------------

loc_554C:
	clr.b	$38(a0)
	rts
; End of function sub_5530

; =============== S U B	R O U T	I N E =======================================

sub_5552:
	movea.l	$2E(a0),a1
	move.b	$36(a0),d0
	move.w	#$1000,d1
	jsr	(Sin).l
	swap	d2
	add.w	$A(a1),d2
	move.w	d2,$A(a0)
	jsr	(Cos).l
	swap	d2
	neg.w	d2
	add.w	$E(a1),d2
	move.w	d2,$E(a0)
	rts
; End of function sub_5552

; =============== S U B	R O U T	I N E =======================================

MarkPuyoSpot:
	move.b	aPlayerID(a0),d0
	lea	(puyos_popping).l,a1
	tst.b	(a1,d0.w)
	beq.w	.MarkSpot
	rts
; ---------------------------------------------------------------------------

.MarkSpot:
	move.w	aField1A(a0),d0
	move.w	aField1C(a0),d1
	bsr.w	GetPuyoFieldTile
	move.b	aMappings(a0),d2
	lsl.b	#4,d2
	bset	#7,d2
	cmpi.b	#$E0,d2
	bne.w	.NotGarbage
	ori.b	#$D,d2

.NotGarbage:
	move.b	d2,(a2,d1.w)
	move.b	d2,1(a2,d1.w)
	cmpi.w	#2,aField1C(a0)
	bcs.w	.NoDraw
	move.w	d0,d1
	move.b	d2,d0
	DISABLE_INTS
	bsr.w	DrawPuyo
	ENABLE_INTS

.NoDraw:
	rts
; End of function MarkPuyoSpot

; =============== S U B	R O U T	I N E =======================================

ResetPuyoField:
	bsr.w	GetPuyoField
	move.w	#$53,d0

loc_55E4:
	move.w	#$FF,(a2)+
	dbf	d0,loc_55E4
	rts
; End of function ResetPuyoField

; ---------------------------------------------------------------------------
	tst.b	(byte_FF196B).l
	bne.s	loc_55FA
	rts
; ---------------------------------------------------------------------------

loc_55FA:
	move.l	a2,-(sp)
	suba.l	#$48,a2
	clr.w	d0
	move.b	(byte_FF196B).l,d0
	subq.b	#1,d0
	mulu.w	#$26,d0
	lea	(byte_5636).l,a1
	adda.w	d0,a1
	move.w	#$23,d0

loc_561E:
	move.b	(a1)+,(a2)+
	move.b	#$FF,(a2)+
	dbf	d0,loc_561E
	movea.l	$32(a0),a2
	move.w	(a1)+,$26(a2)
	move.l	(sp)+,a2
	rts
; ---------------------------------------------------------------------------
byte_5636:
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b $80
	dc.b $90
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b $80
	dc.b $90
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b $D0
	dc.b $80
	dc.b $90
	dc.b 0
	dc.b 0
	dc.b $D0
	dc.b $D0
	dc.b $80
	dc.b $90
	dc.b 0
	dc.b 0
	dc.b 5
	dc.w $300
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b $B0
	dc.b $C0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b $D0
	dc.b $B0
	dc.b $C0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b $D0
	dc.b $B0
	dc.b $C0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b $D0
	dc.b $B0
	dc.b $C0
	dc.b 0
	dc.b 0
	dc.b 5
	dc.w $400
	dc.b 0
	dc.b 0
	dc.b $C0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b $90
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b $80
	dc.b $90
	dc.b 0
	dc.b $B0
	dc.b 0
	dc.b 0
	dc.b $D0
	dc.b $80
	dc.b 0
	dc.b $B0
	dc.b 0
	dc.b $D0
	dc.b $80
	dc.b $90
	dc.b 0
	dc.b $C0
	dc.b $C0
	dc.b $D0
	dc.b $80
	dc.b $90
	dc.b $B0
	dc.b $B0
	dc.w $500

; =============== S U B	R O U T	I N E =======================================

GetCtrlData:
	move.w	(p1_ctrl_hold).l,d0
	tst.b	(swap_controls).l
	beq.w	locret_56BE
	move.w	(p2_ctrl_hold).l,d0

locret_56BE:
	rts
; End of function GetCtrlData

; =============== S U B	R O U T	I N E =======================================

sub_56C0:
	movem.l	d2/a2,-(sp)
	clr.w	d2
	move.b	$2A(a0),d2
	move.b	(swap_controls).l,d0
	eor.b	d0,d2
	mulu.w	#6,d2
	lea	(p1_ctrl_hold).l,a2
	move.w	(a2,d2.w),d0
	move.b	2(a2,d2.w),d1
	move.b	(level_mode).l,d2
	btst	#2,d2
	bne.s	loc_5706
	lsl.b	#1,d2
	or.b	$2A(a0),d2
	eori.b	#1,d2
	and.b	(control_player_1).l,d2
	bne.s	loc_570C

loc_5706:
	jsr	(sub_12E6C).l

loc_570C:
	movem.l	(sp)+,d2/a2
	rts
; End of function sub_56C0

; =============== S U B	R O U T	I N E =======================================

sub_5712:
	move.b	(level_mode).l,d2
	btst	#2,d2
	bne.w	locret_5778
	lsl.b	#1,d2
	or.b	$2A(a0),d2
	eori.b	#1,d2
	and.b	(control_player_1).l,d2
	beq.w	locret_5778
	movem.l	a2-a3,-(sp)
	clr.w	d1
	move.b	$2A(a0),d1
	move.b	(swap_controls).l,d2
	lea	(player_1_a).l,a2
	eor.b	d2,d1
	beq.s	loc_5756
	lea	(player_2_a).l,a2

loc_5756:
	lea	(byte_577A).l,a3
	clr.w	d1

loc_575E:
	move.b	(a3)+,d2
	bmi.w	loc_5770
	and.b	d0,d2
	beq.s	loc_576C
	or.b	(a2),d1

loc_576C:
	addq.l	#1,a2
	bra.s	loc_575E
; ---------------------------------------------------------------------------

loc_5770:
	move.b	(a3,d1.w),d0
	movem.l	(sp)+,a2-a3

locret_5778:
	rts
; End of function sub_5712

; ---------------------------------------------------------------------------
byte_577A:
	dc.b $40
	dc.b $10
	dc.b $20
	dc.b $FF
	dc.b 0
	dc.b $40
	dc.b $20
	dc.b $40

; =============== S U B	R O U T	I N E =======================================

sub_5782:
	bsr.w	GetPuyoField
	move.w	d0,d1
	moveq	#0,d2
	moveq	#0,d3

loc_578C:
	move.b	pVisiblePuyos(a2,d2.w),d0
	cmp.b	pVisiblePuyos+1(a2,d2.w),d0
	beq.s	loc_57A0
	move.b	d0,pVisiblePuyos+1(a2,d2.w)
	bsr.w	DrawPuyo

loc_57A0:
	addq.w	#4,d1
	addq.w	#1,d3
	cmpi.w	#6,d3
	bcs.s	loc_57B2
	clr.w	d3
	addi.w	#$E8,d1

loc_57B2:
	addq.w	#2,d2
	cmpi.w	#PUYO_FIELD_COLS*(PUYO_FIELD_ROWS-2)*2,d2
	bcs.s	loc_578C
	rts
; End of function sub_5782

; =============== S U B	R O U T	I N E =======================================

DrawPuyo:
	movem.l	d0-d3,-(sp)
	bsr.w	GetPuyoTileID
	move.w	#2,d3
	cmpi.w	#$83FE,d0
	bne.w	.Draw
	clr.w	d3

.Draw:
	move.w	d1,d2
	andi.w	#$3FFF,d2
	ori.w	#$4000,d2
	move.w	d2,VDP_CTRL
	move.w	d1,d2
	lsl.l	#2,d2
	swap	d2
	andi.w	#3,d2
	move.w	d2,VDP_CTRL
	move.w	d0,d2
	move.w	d2,VDP_DATA
	add.w	d3,d2
	move.w	d2,VDP_DATA
	move.w	d1,d2
	addi.w	#$80,d2
	andi.w	#$3FFF,d2
	ori.w	#$4000,d2
	move.w	d2,VDP_CTRL
	move.w	d1,d2
	lsl.l	#2,d2
	swap	d2
	andi.w	#3,d2
	move.w	d2,VDP_CTRL
	move.w	d0,d2
	addq.w	#1,d2
	move.w	d2,VDP_DATA
	add.w	d3,d2
	move.w	d2,VDP_DATA
	movem.l	(sp)+,d0-d3
	rts
; End of function DrawPuyo

; =============== S U B	R O U T	I N E =======================================

GetPuyoTileID:
	movem.l	d1-d4,-(sp)
	move.w	#$83FE,d1
	or.b	d0,d0
	beq.s	loc_589E
	move.w	#$8000,d1
	clr.b	d1
	clr.w	d2
	move.b	d0,d2
	lsr.b	#4,d2
	andi.b	#7,d2
	mulu.w	#$15,d2
	clr.w	d3
	move.b	d0,d3
	andi.b	#$F,d3
	or.b	d0,d0
	bmi.w	loc_5874
	move.b	byte_58C2(pc,d3.w),d4
	move.b	d4,d3

loc_5874:
	add.b	d3,d2
	lsl.w	#2,d2
	addi.w	#$100,d2
	or.w	d2,d1
	clr.w	d2
	move.b	d0,d2
	lsr.b	#3,d2
	andi.b	#$E,d2
	cmpi.b	#$C,d2
	bne.s	loc_589A
	move.b	d0,d2
	andi.b	#7,d2
	addq.b	#6,d2
	lsl.b	#1,d2

loc_589A:
	or.w	PuyoPalLines(pc,d2.w),d1

loc_589E:
	move.w	d1,d0
	movem.l	(sp)+,d1-d4
	rts
; End of function GetPuyoTileID

; ---------------------------------------------------------------------------
PuyoPalLines:
	dc.w 0
	dc.w 0
	dc.w $4000
	dc.w $4000
	dc.w $2000
	dc.w $2000
	dc.w $4000
	dc.w $4000
	dc.w $4000
	dc.w $4000
	dc.w $4000
	dc.w $4000
	dc.w $4000
	dc.w $4000

byte_58C2:
	dc.b 0
	dc.b 0
	dc.b $10
	dc.b $11
	dc.b $12
	dc.b $14

; =============== S U B	R O U T	I N E =======================================

sub_58C8:
	bsr.w	GetPuyoField
	adda.l	#pVisiblePuyos,a2
	movea.l	a2,a3
	adda.l	#pUnk1-pVisiblePuyos,a3
	clr.w	d0
	clr.b	d1

loc_58DE:
	move.b	(a2,d0.w),d3
	andi.b	#$60,d3
	cmpi.b	#$60,d3
	bne.s	loc_58F2
	bsr.w	sub_5908

loc_58F2:
	addq.b	#1,d1
	cmpi.b	#6,d1
	bcs.s	loc_58FE
	clr.b	d1

loc_58FE:
	addq.w	#2,d0
	cmpi.w	#PUYO_FIELD_COLS*(PUYO_FIELD_ROWS-2)*2,d0
	bcs.s	loc_58DE
	rts
; End of function sub_58C8


; =============== S U B	R O U T	I N E =======================================

sub_5908:
	move.w	#6,d2
	clr.b	d3

loc_590E:
	clr.w	d4
	move.b	d1,d4
	add.w	byte_5958(pc,d2.w),d4
	cmpi.w	#$FFFE,d4
	beq.s	loc_5942
	cmpi.w	#7,d4
	beq.s	loc_5942
	move.w	d0,d4
	add.w	byte_5958(pc,d2.w),d4
	cmpi.w	#$90,d4
	bcc.s	loc_5942
	move.b	(a3,d4.w),d5
	andi.b	#$C0,d5
	bne.s	loc_5942
	addq.b	#1,d3

loc_5942:
	subq.w	#2,d2
	bcc.s	loc_590E
	tst.b	d3
	bne.s	loc_594E
	rts
; ---------------------------------------------------------------------------

loc_594E:
	ori.b	#$40,d3
	move.b	d3,(a3,d0.w)
	rts
; End of function sub_5908

; ---------------------------------------------------------------------------
byte_5958:
	dc.b 0
	dc.b $C
	dc.b $FF
	dc.b $F4
	dc.b 0
	dc.b 2
	dc.b $FF
	dc.b $FE

; =============== S U B	R O U T	I N E =======================================

sub_5960:
	bsr.w	GetPuyoField
	adda.l	#pVisiblePuyos,a2
	movea.l	a2,a3
	adda.l	#pUnk1-pVisiblePuyos,a3
	movea.l	a3,a4
	adda.l	#pPuyosCopy-pUnk1,a4
	movea.l	a3,a5
	moveq	#0,d1
	move.w	#$23,d0

loc_5982:
	move.l	d1,(a5)+
	dbf	d0,loc_5982
	clr.w	d0
	clr.w	d1

loc_598C:
	tst.b	(a3,d0.w)
	bne.s	loc_59A6
	move.b	#$80,(a3,d0.w)
	move.b	(a2,d0.w),d3
	beq.s	loc_59A6
	cmpi.b	#$E0,d3
	bcc.s	loc_59A6
	bsr.s	sub_59B0

loc_59A6:
	addq.w	#2,d0
	cmpi.w	#PUYO_FIELD_COLS*(PUYO_FIELD_ROWS-2)*2,d0
	bcs.s	loc_598C
	rts
; End of function sub_5960

; =============== S U B	R O U T	I N E =======================================

sub_59B0:
	movem.l	d0-d1,-(sp)
	clr.w	d3
	move.w	#2,d4
	move.w	d0,(a4)

loc_59BC:
	moveq	#0,d5
	move.w	(a4,d3.w),d5
	lsr.w	#1,d5
	divu.w	#6,d5
	swap	d5
	move.b	d5,d2
	move.w	(a4,d3.w),d5
	andi.b	#$F0,(a2,d5.w)
	clr.b	d6
	move.w	#6,d7

loc_59DC:
	lsl.b	#1,d6
	clr.w	d0
	move.b	d2,d0
	add.w	byte_5A46(pc,d7.w),d0
	cmpi.w	#$FFFE,d0
	beq.s	loc_5A22
	cmpi.w	#7,d0
	beq.s	loc_5A22
	move.w	d5,d0
	add.w	byte_5A46(pc,d7.w),d0
	cmpi.w	#$90,d0
	bcc.s	loc_5A22
	move.b	(a2,d0.w),d1
	andi.b	#$F0,d1
	beq.s	loc_5A22
	cmp.b	(a2,d5.w),d1
	bne.s	loc_5A22
	addq.b	#1,d6
	tst.b	(a3,d0.w)
	bne.s	loc_5A22
	move.b	#$80,(a3,d0.w)
	move.w	d0,(a4,d4.w)
	addq.w	#2,d4

loc_5A22:
	subq.w	#2,d7
	bcc.s	loc_59DC
	or.b	d6,(a2,d5.w)
	addq.w	#2,d3
	cmp.w	d4,d3
	bcs.s	loc_59BC
	movem.l	(sp)+,d0-d1
	cmpi.w	#8,d4
	bcc.s	loc_5A66
	cmpi.w	#4,d4
	bcc.s	loc_5A4E
	rts
; ---------------------------------------------------------------------------
byte_5A46:
	dc.b 0
	dc.b $C
	dc.b $FF
	dc.b $F4
	dc.b 0
	dc.b 2
	dc.b $FF
	dc.b $FE
; ---------------------------------------------------------------------------

loc_5A4E:
	move.b	d4,d2
	subq.w	#2,d4
	lsr.b	#1,d2
	ori.b	#$80,d2

loc_5A58:
	move.w	(a4,d4.w),d3
	move.b	d2,(a3,d3.w)
	subq.w	#2,d4
	bcc.s	loc_5A58
	rts
; ---------------------------------------------------------------------------

loc_5A66:
	addq.w	#1,d1
	move.w	d4,d2
	subq.w	#2,d2

loc_5A6C:
	move.w	(a4,d2.w),d3
	move.b	d1,(a3,d3.w)
	subq.w	#2,d2
	bcc.s	loc_5A6C
	movea.l	a4,a5
	adda.l	#$A8,a5
	move.w	d1,d2
	subq.w	#1,d2
	lsl.w	#1,d2
	lsr.b	#1,d4
	move.b	(a2,d3.w),d5
	andi.b	#$70,d5
	move.b	d4,(a5,d2.w)
	move.b	d5,1(a5,d2.w)
	rts
; End of function sub_59B0

; =============== S U B	R O U T	I N E =======================================

GetPuyoFieldTile:
	movem.l	d2-d3,-(sp)
	move.w	d0,d2
	move.w	d1,d3
	bsr.w	GetPuyoField
	lsl.b	#1,d3
	move.w	d2,d1
	add.w	d3,d1
	add.w	d3,d1
	add.w	d3,d1
	lsl.b	#1,d1
	lsl.b	#2,d2
	subq.b	#4,d3
	lsl.w	#7,d3
	add.w	d2,d0
	add.w	d3,d0
	movem.l	(sp)+,d2-d3
	rts
; End of function GetPuyoFieldTile

; =============== S U B	R O U T	I N E =======================================

GetPuyoFieldID:
	movem.l	d0-d1,-(sp)
	move.b	$2A(a0),d0
	move.b	(swap_controls).l,d1
	eor.b	d1,d0
	movem.l	(sp)+,d0-d1
	rts
; End of function GetPuyoFieldID

; =============== S U B	R O U T	I N E =======================================

GetPuyoField:
	move.l	d1,-(sp)
	clr.w	d1
	move.b	(swap_controls).l,d1
	lsl.b	#1,d1
	or.b	aPlayerID(a0),d1
	lsl.b	#3,d1
	movea.l	off_5AFA(pc,d1.w),a2
	move.w	off_5AFA+4(pc,d1.w),d0
	move.l	(sp)+,d1
	rts
; End of function GetPuyoField

; ---------------------------------------------------------------------------
off_5AFA:
	dc.l puyo_field_p1
	dc.w $C104, 0
	dc.l puyo_field_p2
	dc.w $C134, 0
	dc.l puyo_field_p1
	dc.w $C134, 0
	dc.l puyo_field_p2
	dc.w $C104, 0

; =============== S U B	R O U T	I N E =======================================

GetPuyoFieldPos:
	clr.w	d1
	or.b	aPlayerID(a0),d1
	move.b	(swap_controls).l,d0
	eor.b	d0,d1
	lsl.b	#2,d1
	move.w	word_5B34(pc,d1.w),d0
	move.w	word_5B34+2(pc,d1.w),d1
	rts
; End of function GetPuyoFieldPos

; ---------------------------------------------------------------------------
word_5B34:
	dc.w 16+128,  16+128
	dc.w 208+128, 16+128
	dc.w 16+128,  16+128
	dc.w 208+128, 16+128
	dc.w 16+128,  16+128
	dc.w 208+128, 16+128
	dc.w 16+128,  16+128
	dc.w 208+128, 16+128

; =============== S U B	R O U T	I N E =======================================

sub_5B54:
	clr.w	(word_FF19A8).l
	lea	(loc_5BCE).l,a1
	bsr.w	FindActorSlot
	bcc.s	loc_5B6A
	rts
; ---------------------------------------------------------------------------

loc_5B6A:
	move.b	#$80,6(a1)
	move.b	#$19,8(a1)
	move.b	#9,9(a1)
	move.b	#$FF,$36(a1)
	move.l	a2,$2E(a1)
	clr.w	d0
	move.b	(level_mode).l,d0
	andi.b	#3,d0
	lsl.b	#3,d0
	move.w	word_5BAE(pc,d0.w),$A(a1)
	move.w	word_5BAE+2(pc,d0.w),$E(a1)
	move.w	word_5BAE+2(pc,d0.w),$20(a1)
	move.l	word_5BAE+4(pc,d0.w),$32(a1)
	rts
; End of function sub_5B54

; ---------------------------------------------------------------------------
word_5BAE:
	dc.w $140, $128
	dc.l byte_3316
	dc.w $120, $108
	dc.l byte_3316
	dc.w $120, $10C
	dc.l byte_3330
	dc.w $120, $108
	dc.l byte_3330
; ---------------------------------------------------------------------------

loc_5BCE:
	cmpi.b	#1,(level_mode).l
	bne.s	loc_5BF4
	movea.l	$2E(a0),a1
	movea.l	$2E(a1),a2
	move.b	7(a1),d0
	or.b	7(a2),d0
	btst	#0,d0
	beq.s	loc_5BF4
	rts
; ---------------------------------------------------------------------------

loc_5BF4:
	bsr.w	ActorBookmark
	bsr.w	ActorAnimate
	bcs.s	loc_5C4A
	move.b	(p1_ctrl_hold).l,d0
	or.b	(p2_ctrl_hold).l,d0
	andi.b	#$F0,d0
	beq.s	loc_5C18
	clr.w	$22(a0)

loc_5C18:
	cmpi.b	#$17,9(a0)
	beq.s	loc_5C24
	rts
; ---------------------------------------------------------------------------

loc_5C24:
	move.b	#SFX_LEVEL_START,d0
	jsr	(PlaySound_ChkPCM).l
	movea.l	$2E(a0),a1
	movea.l	$2E(a1),a2
	move.w	$14(a1),d0
	add.w	$14(a2),d0
	cmpi.w	#$25,d0
	bcc.s	loc_5C4A
	bsr.w	sub_5FAA

loc_5C4A:
	movea.l	$2E(a0),a1
	movea.l	$2E(a1),a2
	bclr	#1,7(a1)
	bclr	#1,7(a2)

loc_5C5E:
	bsr.w	ActorBookmark
	tst.b	(word_FF19A8).l
	bmi.w	loc_5D0C
	move.b	(player_1_flags).l,d0
	and.b	(player_2_flags).l,d0
	bmi.w	loc_5E86
	bsr.w	sub_5F6E
	bsr.w	ActorAnimate
	bcc.s	loc_5CC2
	tst.w	$26(a0)
	beq.s	loc_5CA0
	subq.w	#1,$26(a0)
	move.l	$2E(a0),d0
	move.l	d0,$32(a0)
	bra.w	loc_5CC2
; ---------------------------------------------------------------------------

loc_5CA0:
	bsr.w	sub_5EE8
	bsr.w	sub_5F26
	lsl.w	#2,d0
	lea	(off_3334).l,a1
	movea.l	(a1,d0.w),a2
	move.w	(a2)+,d0
	move.w	d0,$26(a0)
	move.l	a2,$32(a0)
	move.l	a2,$2E(a0)

loc_5CC2:
	clr.w	d0
	move.b	9(a0),d0
	cmp.b	$36(a0),d0
	beq.w	locret_5D02
	move.b	d0,$36(a0)
	cmpi.b	#$40,d0
	bcs.w	locret_5D02
	bne.s	loc_5CF0
	bset	#0,7(a0)
	move.w	#$20,$28(a0)
	bra.w	locret_5D02
; ---------------------------------------------------------------------------

loc_5CF0:
	subi.b	#$41,d0
	lsl.b	#1,d0
	move.w	unk_5D04(pc,d0.w),d1
	add.w	d1,$A(a0)
	bsr.w	sub_5F4C

locret_5D02:
	rts
; ---------------------------------------------------------------------------
unk_5D04:
	dc.b $FF
	dc.b $FE
	dc.b   0
	dc.b   2
	dc.b $FF
	dc.b $FC
	dc.b   0
	dc.b   4
; ---------------------------------------------------------------------------

loc_5D0C:
	lea	(loc_5D64).l,a1
	bsr.w	FindActorSlot
	bcc.s	loc_5D24
	clr.w	(word_FF19A8).l
	bra.w	loc_5C5E
; ---------------------------------------------------------------------------

loc_5D24:
	move.l	a0,$2E(a1)
	bsr.w	ActorBookmark
	tst.b	(word_FF19A8+1).l
	beq.s	loc_5D38
	rts
; ---------------------------------------------------------------------------

loc_5D38:
	andi.b	#$7F,6(a0)
	bsr.w	ActorBookmark
	tst.b	(word_FF19A8+1).l
	bne.s	loc_5D4E
	rts
; ---------------------------------------------------------------------------

loc_5D4E:
	ori.b	#$80,6(a0)
	bsr.w	ActorBookmark
	tst.b	(word_FF19A8+1).l
	beq.w	loc_5C5E
	rts
; ---------------------------------------------------------------------------

loc_5D64:
	move.l	#unk_5E7C,$32(a0)
	bsr.w	ActorBookmark
	movea.l	$2E(a0),a1
	bsr.w	ActorAnimate
	bcs.s	loc_5D84
	move.b	9(a0),9(a1)
	rts
; ---------------------------------------------------------------------------

loc_5D84:
	move.b	#5,6(a0)
	move.w	$A(a1),$A(a0)
	move.w	$A(a1),$36(a0)
	move.w	$E(a1),$E(a0)
	move.w	$E(a1),$38(a0)
	move.w	#$FFFF,$16(a0)
	move.w	#$A00,$1A(a0)
	move.w	#$1800,$1C(a0)
	move.b	#0,d0
	jsr	(PlaySound_ChkPCM).l
	bsr.w	ActorBookmark
	movea.l	$2E(a0),a1
	bsr.w	sub_3810
	bcs.s	loc_5DDC
	move.w	$A(a0),$A(a1)
	move.w	$E(a0),$E(a1)
	rts
; ---------------------------------------------------------------------------

loc_5DDC:
	clr.b	(word_FF19A8+1).l
	bsr.w	ActorBookmark
	tst.b	(word_FF19A8+1).l
	bne.s	loc_5DF2
	rts
; ---------------------------------------------------------------------------

loc_5DF2:
	move.b	#5,6(a0)
	move.w	$36(a0),$A(a0)
	clr.l	$16(a0)
	move.w	#$FFFF,$20(a0)
	move.w	#$1800,$1C(a0)
	move.l	#unk_5E6E,$32(a0)
	bsr.w	ActorBookmark
	movea.l	$2E(a0),a1
	bsr.w	sub_3810
	bsr.w	ActorAnimate
	move.b	9(a0),9(a1)
	move.w	$A(a0),$A(a1)
	move.w	$E(a0),d0
	move.w	d0,$E(a1)
	cmp.w	$38(a0),d0
	bcc.s	loc_5E44
	rts
; ---------------------------------------------------------------------------

loc_5E44:
	move.b	#$D,9(a1)
	move.w	$36(a0),$A(a1)
	move.w	$38(a0),$E(a1)
	move.b	#$FF,$36(a1)
	clr.w	(word_FF19A8).l
	move.b	#SFX_PUYO_LAND,d0
	bsr.w	PlaySound_ChkPCM
	bra.w	ActorDeleteSelf
; ---------------------------------------------------------------------------
; TODO: More Animation Documentation

unk_5E6E:
	dc.b   1
	dc.b  $D
	dc.b   1
	dc.b $24
	dc.b   1
	dc.b $26
	dc.b   1
	dc.b $25
	dc.b $FF
	dc.b   0
	dc.l unk_5E6E

unk_5E7C:
	dc.b   8
	dc.b   9
	dc.b $12
	dc.b  $C
	dc.b   2
	dc.b  $B
	dc.b   1
	dc.b  $D
	dc.b $FE
	dc.b   0
; ---------------------------------------------------------------------------

loc_5E86:
	lea	(loc_5EB6).l,a1
	bsr.w	FindActorSlot
	bcs.w	loc_5C5E
	move.l	a0,$2E(a1)
	move.l	#unk_5ED6,$32(a1)
	bsr.w	ActorBookmark
	move.b	(player_1_flags).l,d0
	and.b	(player_2_flags).l,d0
	bpl.w	loc_5C5E
	rts
; ---------------------------------------------------------------------------

loc_5EB6:
	move.b	(player_1_flags).l,d0
	and.b	(player_2_flags).l,d0
	bpl.w	ActorDeleteSelf
	bsr.w	ActorAnimate
	movea.l	$2E(a0),a1
	move.b	9(a0),9(a1)
	rts
; ---------------------------------------------------------------------------
; TODO: More Animation Documentation

unk_5ED6:
	dc.b $14
	dc.b $2B
	dc.b $16
	dc.b $2C
	dc.b $18
	dc.b $2B
	dc.b $12
	dc.b $2C
	dc.b $15
	dc.b $2B
	dc.b $17
	dc.b $2C
	dc.b $FF
	dc.b   0
	dc.l unk_5ED6

; =============== S U B	R O U T	I N E =======================================

sub_5EE8:
	eori.b	#2,7(a0)
	btst	#1,7(a0)
	beq.s	loc_5EFE
	move.w	#$1E,d0
	rts
; ---------------------------------------------------------------------------

loc_5EFE:
	move.w	#$1E,d0
	move.w	#0,d1
	move.b	(level_mode).l,d2
	andi.b	#3,d2
	bne.s	loc_5F1C
	move.w	#$16,d0
	move.w	#8,d1

loc_5F1C:
	jsr	(RandomBound).l
	add.w	d1,d0
	rts
; End of function sub_5EE8

; =============== S U B	R O U T	I N E =======================================

sub_5F26:
	cmpi.b	#4,d0
	bcs.s	loc_5F30
	rts
; ---------------------------------------------------------------------------

loc_5F30:
	move.l	#$8000,d1
	btst	#0,d0
	beq.s	loc_5F40
	neg.l	d1

loc_5F40:
	move.l	d1,$12(a0)
	move.b	#$82,6(a0)
	rts
; End of function sub_5F26

; =============== S U B	R O U T	I N E =======================================

sub_5F4C:
	cmpi.w	#$108,$A(a0)
	bcc.s	loc_5F5C
	move.w	#$108,$A(a0)

loc_5F5C:
	cmpi.w	#$139,$A(a0)
	bcs.s	locret_5F6C
	move.w	#$138,$A(a0)

locret_5F6C:
	rts
; End of function sub_5F4C

; =============== S U B	R O U T	I N E =======================================

sub_5F6E:
	btst	#0,7(a0)
	bne.s	loc_5F7A
	rts
; ---------------------------------------------------------------------------

loc_5F7A:
	move.w	$28(a0),d0
	lsl.b	#2,d0
	ori.b	#$80,d0
	move.w	#$1800,d1
	jsr	(Sin).l
	swap	d2
	add.w	$20(a0),d2
	move.w	d2,$E(a0)
	subq.w	#1,$28(a0)
	bmi.s	loc_5FA2
	rts
; ---------------------------------------------------------------------------

loc_5FA2:
	bclr	#0,7(a0)
	rts
; End of function sub_5F6E


; =============== S U B	R O U T	I N E =======================================

sub_5FAA:
	clr.w	(time_frames).l
	move.w	#$1F,d0

loc_5FB4:
	lea	(sub_602C).l,a1
	bsr.w	FindActorSlotQuick
	bcs.s	loc_6026
	move.b	#$83,6(a1)
	move.b	#6,8(a1)
	move.b	#$E,9(a1)
	move.w	$A(a0),$A(a1)
	move.w	$E(a0),$E(a1)
	move.w	#$FFFF,$20(a1)
	move.w	#$2000,$1C(a1)
	move.l	d0,-(sp)
	lsl.b	#3,d0
	move.b	d0,d3
	move.w	#$C0,d0
	jsr	(RandomBound).l

loc_5FFE:
	addi.w	#$280,d0
	move.w	d0,d1
	move.b	d3,d0
	jsr	(Sin).l
	move.l	d2,$12(a1)
	addq.b	#5,d0
	jsr	(Cos).l
	move.l	d2,$16(a1)
	move.w	#$14,$26(a1)
	move.l	(sp)+,d0

loc_6026:
	dbf	d0,loc_5FB4
	rts
; End of function sub_5FAA

; =============== S U B	R O U T	I N E =======================================

sub_602C:
	bsr.w	sub_3810
	bcs.w	ActorDeleteSelf
	subq.w	#1,$26(a0)
	rts
; End of function sub_602C

; ---------------------------------------------------------------------------
	move.b	#$87,6(a0)
	bsr.w	ActorBookmark
	bsr.w	sub_3810
	bcs.w	ActorDeleteSelf
	rts

; =============== S U B	R O U T	I N E =======================================

sub_604E:
	move.w	#1,(word_FF1124).l
	move.w	#$D688,d3
	move.w	#$C000,d2
	cmpi.b	#OPP_ROBOTNIK,(opponent).l
	beq.s	loc_6080
	move.w	#$6000,d0
	bra.s	loc_6084
; ---------------------------------------------------------------------------

loc_6070:
	move.w	#0,(word_FF1124).l
	move.w	#$C61E,d3
	move.w	#$E000,d2

loc_6080:
	move.w	#$8000,d0

loc_6084:
	move.b	#0,(byte_FF1121).l
	movem.l	d2-d3/a0,-(sp)
	clr.w	d1
	move.b	(opponent).l,d1
	lsl.w	#2,d1
	lea	(OpponentArt).l,a0
	movea.l	(a0,d1.w),a0
	DISABLE_INTS
	jsr	(NemDec).l
	ENABLE_INTS
	movem.l	(sp)+,d2-d3/a0
	clr.w	(word_FF198C).l
	lea	(sub_60F4).l,a1
	bsr.w	FindActorSlot
	bcs.s	locret_60F2
	move.l	a0,$2E(a1)
	move.w	#0,$28(a1)
	lsr.w	#5,d0
	move.w	d0,$2A(a1)
	move.w	d2,$A(a1)
	move.w	d3,$C(a1)
	move.b	#0,6(a1)
	bsr.w	sub_61E0
	movea.l	a1,a2
	bsr.w	sub_678E

locret_60F2:
	rts
; End of function sub_604E

; =============== S U B	R O U T	I N E =======================================

sub_60F4:
	move.w	#$FFFF,$26(a0)
	bsr.w	ActorBookmark
	tst.b	(word_FF1124).l
	beq.s	loc_610C
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_610C:
	move.w	(word_FF198C).l,d0
	cmp.w	$26(a0),d0
	beq.s	loc_6144
	move.w	d0,$26(a0)
	lea	(OpponentAnims).l,a1
	clr.w	d1
	move.b	(opponent).l,d1
	lsl.w	#2,d1
	movea.l	(a1,d1.w),a1
	add.w	$28(a0),d0
	lsl.w	#2,d0
	movea.l	(a1,d0.w),a1
	move.l	a1,$32(a0)
	clr.b	$22(a0)

loc_6144:
	tst.b	$22(a0)
	beq.s	loc_6150
	subq.b	#1,$22(a0)
	rts
; ---------------------------------------------------------------------------

loc_6150:
	movea.l	$32(a0),a2
	move.w	(a2)+,d0
	bge.s	loc_617E
	lea	(OpponentAnims).l,a2
	clr.w	d0
	move.b	(opponent).l,d0
	lsl.w	#2,d0
	movea.l	(a2,d0.w),a2
	move.w	$26(a0),d0
	lsl.w	#2,d0
	movea.l	(a2,d0.w),a2
	move.w	(a2)+,d0
	move.b	#$FF,$2C(a0)

loc_617E:
	addq.b	#1,$2C(a0)
	move.b	d0,$22(a0)
	movea.l	(a2)+,a1
	move.l	a2,$32(a0)
	move.l	a0,-(sp)
	move.w	$2A(a0),d0
	move.w	$A(a0),d1
	or.w	d1,d0
	move.w	#9,d1
	move.w	#6,d2
	movea.l	a1,a2
	movea.l	#0,a1
	movea.w	$C(a0),a1
	movea.l	a2,a0
	DISABLE_INTS
	jsr	(EniDec).l
	ENABLE_INTS
	movea.l	(sp)+,a0
	rts
; End of function sub_60F4

; =============== S U B	R O U T	I N E =======================================

sub_61C0:
	moveq	#0,d0
	move.b	(opponent).l,d0
	move.b	OpponentPalettes(pc,d0.w),d0
	lsl.w	#5,d0
	lea	(Palettes).l,a2
	adda.l	d0,a2
	move.b	#3,d0
	jmp	(LoadPalette).l
; End of function sub_61C0

; =============== S U B	R O U T	I N E =======================================

sub_61E0:
	moveq	#0,d0
	move.b	(opponent).l,d0
	move.b	OpponentPalettes(pc,d0.w),d0
	lsl.w	#5,d0
	lea	(Palettes).l,a2
	adda.l	d0,a2
	move.w	$A(a1),d0
	rol.w	#3,d0
	andi.b	#$B,d0
	jmp	(LoadPalette).l
; End of function sub_61E0

; ---------------------------------------------------------------------------
OpponentPalettes:
	dc.b (Pal_Scratch-Palettes)>>5		; Skeleton Tea - Puyo Puyo Leftover
	dc.b (Pal_Frankly-Palettes)>>5		; Frankly
	dc.b (Pal_Dynamight-Palettes)>>5	; Dynamight
	dc.b (Pal_Arms-Palettes)>>5		; Arms
	dc.b (Pal_Scratch-Palettes)>>5		; Nasu Grave - Puyo Puyo Leftover
	dc.b (Pal_Grounder-Palettes)>>5		; Grounder
	dc.b (Pal_DavySprocket-Palettes)>>5	; Davy Sprocket
	dc.b (Pal_Coconuts-Palettes)>>5		; Coconuts
	dc.b (Pal_Spike-Palettes)>>5		; Spike
	dc.b (Pal_SirFfuzzyLogik-Palettes)>>5	; Sir Ffuzzy-Logik
	dc.b (Pal_DragonBreath-Palettes)>>5	; Dragon Breath
	dc.b (Pal_Scratch-Palettes)>>5		; Scratch
	dc.b (Pal_Robotnik-Palettes)>>5		; Dr. Robotnik
	dc.b (Pal_Scratch-Palettes)>>5		; Mummy - Puyo Puyo Leftover
	dc.b (Pal_Humpty-Palettes)>>5		; Humpty
	dc.b (Pal_Skweel-Palettes)>>5		; Skweel
OpponentArt:
	dc.l ArtNem_Scratch		; Skeleton Tea - Puyo Puyo Leftover
	dc.l ArtNem_Frankly		; Frankly
	dc.l ArtNem_Dynamight		; Dynamight
	dc.l ArtNem_Arms		; Arms
	dc.l ArtNem_Scratch		; Nasu Grave - Puyo Puyo Leftover
	dc.l ArtNem_Grounder		; Grounder
	dc.l ArtNem_DavySprocket	; Davy Sprocket
	dc.l ArtNem_Coconuts		; Coconuts
	dc.l ArtNem_Spike		; Spike
	dc.l ArtNem_SirFfuzzyLogik	; Sir Ffuzzy-Logik
	dc.l ArtNem_DragonBreath	; Dragon Breath
	dc.l ArtNem_Scratch		; Scratch
	dc.l ArtNem_DrRobotnik		; Dr. Robotnik
	dc.l ArtNem_Scratch		; Mummy - Puyo Puyo Leftover
	dc.l ArtNem_Humpty		; Humpty
	dc.l ArtNem_Skweel		; Skweel

OpponentAnims:
	dc.l Scratch_Anims		; Skeleton Tea - Puyo Puyo Leftover
	dc.l Frankly_Anims		; Frankly
	dc.l Dynamight_Anims		; Dynamight
	dc.l Arms_Anims			; Arms
	dc.l Scratch_Anims		; Nasu Grave - Puyo Puyo Leftover
	dc.l Grounder_Anims		; Grounder
	dc.l Davy_Anims			; Davy Sprocket
	dc.l Coconuts_Anims		; Coconuts
	dc.l Spike_Anims		; Spike
	dc.l SirFfuzzy_Anims		; Sir Ffuzzy-Logik
	dc.l DragonBreath_Anims		; Dragon Breath
	dc.l Scratch_Anims		; Scratch
	dc.l Robotnik_Anims		; Dr. Robotnik
	dc.l Scratch_Anims		; Mummy - Puyo Puyo Leftover
	dc.l Humpty_Anims		; Humpty
	dc.l Skweel_Anims		; Skweel

	include	"resource/anim/Enemy/Arms.asm"
	even

	include	"resource/anim/Enemy/Frankly.asm"
	even

	include	"resource/anim/Enemy/Humpty.asm"
	even

	include	"resource/anim/Enemy/Coconuts.asm"
	even

	include	"resource/anim/Enemy/Davy Sprocket.asm"
	even

	include	"resource/anim/Enemy/Skweel.asm"
	even

	include	"resource/anim/Enemy/Dynamight.asm"
	even

	include	"resource/anim/Enemy/Grounder.asm"
	even

	include	"resource/anim/Enemy/Spike.asm"
	even

	include	"resource/anim/Enemy/Sir Ffuzzy-Logik.asm"
	even

	include	"resource/anim/Enemy/Dragon Breath.asm"
	even

	include	"resource/anim/Enemy/Scratch.asm"
	even

	include	"resource/anim/Enemy/Dr Robotnik.asm"
	even


; =============== S U B	R O U T	I N E =======================================


sub_678E:
	move.b	(level_mode).l,d0
	andi.b	#3,d0
	beq.s	loc_679E
	rts
; ---------------------------------------------------------------------------

loc_679E:
	moveq	#0,d0
	move.b	(opponent).l,d0
	lsl.w	#2,d0
	movea.l	Opp_AnimSpec(pc,d0.w),a1
	jmp	(a1)
; End of function sub_678E

; ---------------------------------------------------------------------------
Opp_AnimSpec:
	dc.l AnimSpec_Null
	dc.l AnimSpec_Frankly	; Frankly's Lightning Bolts
	dc.l AnimSpec_Null
	dc.l AnimSpec_Arms	; Arms Flashing Body
	dc.l AnimSpec_Null
	dc.l AnimSpec_Null
	dc.l AnimSpec_Null
	dc.l AnimSpec_Coconuts	; Coconut's Flashing Light
	dc.l AnimSpec_Null
	dc.l AnimSpec_SirFfuzzy	; Sir Fuzzy's Flashing Eyes
	dc.l AnimSpec_Null
	dc.l AnimSpec_Null
	dc.l AnimSpec_Null
	dc.l AnimSpec_Null
	dc.l AnimSpec_Humpty	; Humpty's Electric Wave
	dc.l AnimSpec_Null

; ---------------------------------------------------------------------------

AnimSpec_Null:
	rts
; ---------------------------------------------------------------------------

AnimSpec_Frankly:
	move.l	a0,-(sp)
	move.w	#$1E00,d0
	lea	(ArtNem_Frankly_Lightning).l,a0
	DISABLE_INTS
	jsr	(NemDec).l
	ENABLE_INTS
	movea.l	(sp)+,a0
	moveq	#5,d0
	lea	(unk_690A).l,a2

loc_6814:
	lea	(loc_685E).l,a1
	jsr	(FindActorSlot).l
	bcs.s	loc_6858
	move.w	(a2)+,$A(a1)
	move.w	(a2)+,$E(a1)
	move.w	(a2)+,$2A(a1)
	move.w	(a2)+,$2C(a1)
	move.b	#$2C,8(a1)
	move.b	(a2)+,9(a1)
	move.b	(a2)+,$28(a1)
	tst.w	(word_FF1124).l
	beq.s	loc_6858
	subi.w	#$58,$A(a1)
	subi.w	#$F8,$E(a1)
	addq.b	#4,9(a1)

loc_6858:
	dbf	d0,loc_6814
	rts
; ---------------------------------------------------------------------------

loc_685E:
	tst.b	(word_FF1124).l
	beq.s	loc_686C
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_686C:
	move.w	(word_FF198C).l,d0
	cmpi.w	#1,d0
	beq.s	loc_6886
	move.b	#0,6(a0)
	move.b	#0,$22(a0)
	rts
; ---------------------------------------------------------------------------

loc_6886:
	tst.b	$22(a0)
	beq.s	loc_68B4
	tst.b	$26(a0)
	beq.s	loc_6898
	subq.b	#1,$26(a0)
	rts
; ---------------------------------------------------------------------------

loc_6898:
	move.w	$2A(a0),d0
	add.w	d0,$A(a0)
	move.w	$2C(a0),d0
	add.w	d0,$E(a0)
	subq.b	#1,$22(a0)
	move.b	#$80,6(a0)
	rts
; ---------------------------------------------------------------------------

loc_68B4:
	lea	(unk_690A).l,a1
	clr.w	d0
	move.b	$28(a0),d0
	adda.w	d0,a1
	move.w	(a1)+,$A(a0)
	move.w	(a1),$E(a0)
	move.b	#$A,$22(a0)
	move.b	$32(a0),d0
	move.b	unk_6902(pc,d0.w),d1
	move.b	d1,$26(a0)
	addq.b	#1,d0
	andi.b	#7,d0
	move.b	d0,$32(a0)
	move.b	#0,6(a0)
	tst.w	(word_FF1124).l
	beq.s	locret_6900
	subi.w	#$58,$A(a0)
	subi.w	#$F8,$E(a0)

locret_6900:
	rts
; ---------------------------------------------------------------------------
unk_6902:
	dc.b $18
	dc.b $30
	dc.b   2
	dc.b $17
	dc.b $20
	dc.b   5
	dc.b $14
	dc.b $1A

unk_690A:
	dc.b   1
	dc.b   1
	dc.b   0
	dc.b $E2
	dc.b   0
	dc.b   2
	dc.b $FF
	dc.b $FE
	dc.b   1
	dc.b   0
	dc.b   0
	dc.b $F5
	dc.b   0
	dc.b $DF
	dc.b $FF
	dc.b $FE
	dc.b $FF
	dc.b $FE
	dc.b   0
	dc.b  $A
	dc.b   0
	dc.b $F3
	dc.b   0
	dc.b $F6
	dc.b $FF
	dc.b $FE
	dc.b   0
	dc.b   2
	dc.b   1
	dc.b $14
	dc.b   1
	dc.b $46
	dc.b   0
	dc.b $E0
	dc.b   0
	dc.b   2
	dc.b $FF
	dc.b $FE
	dc.b   1
	dc.b $1E
	dc.b   1
	dc.b $39
	dc.b   0
	dc.b $E3
	dc.b $FF
	dc.b $FE
	dc.b $FF
	dc.b $FE
	dc.b   2
	dc.b $28
	dc.b   1
	dc.b $42
	dc.b   0
	dc.b $F8
	dc.b   0
	dc.b   1
	dc.b   0
	dc.b   2
	dc.b   3
	dc.b $32
; ---------------------------------------------------------------------------

AnimSpec_Coconuts:
	lea	(loc_6954).l,a1
	jsr	(FindActorSlot).l
	rts
; ---------------------------------------------------------------------------

loc_6954:
	jsr	(ActorBookmark).l
	tst.b	(word_FF1124).l
	beq.s	loc_6968
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_6968:
	move.w	(word_FF198C).l,d0
	cmp.b	$2A(a0),d0
	beq.s	loc_697E
	move.w	#0,$26(a0)
	move.b	d0,$2A(a0)

loc_697E:
	lsl.w	#2,d0
	movea.l	off_6986(pc,d0.w),a1
	jmp	(a1)
; ---------------------------------------------------------------------------
off_6986:
	dc.l loc_69FE
	dc.l loc_69CE
	dc.l loc_6996
	dc.l loc_6A44
; ---------------------------------------------------------------------------

loc_6996:
	tst.b	(byte_FF1121).l
	bne.s	locret_69B0
	addq.b	#1,$26(a0)
	moveq	#0,d0
	move.b	$26(a0),d0
	move.b	d0,d1
	andi.b	#3,d1
	beq.s	loc_69B2

locret_69B0:
	rts
; ---------------------------------------------------------------------------

loc_69B2:
	andi.b	#$1C,d0
	cmpi.b	#$18,d0
	bne.s	loc_69C6
	move.b	#0,d0
	move.b	d0,$26(a0)

loc_69C6:
	lea	(word_6A4E).l,a1
	bra.s	loc_69FA
; ---------------------------------------------------------------------------

loc_69CE:
	tst.b	$22(a0)
	beq.s	loc_69DA
	subq.b	#1,$22(a0)
	rts
; ---------------------------------------------------------------------------

loc_69DA:
	move.b	#1,$22(a0)
	move.w	$26(a0),d0
	addq.w	#1,d0
	cmpi.w	#$12,d0
	bne.s	loc_69EE
	clr.w	d0

loc_69EE:
	move.w	d0,$26(a0)
	lsl.w	#2,d0
	lea	(word_6A66).l,a1

loc_69FA:
	adda.w	d0,a1
	bra.s	loc_6A04
; ---------------------------------------------------------------------------

loc_69FE:
	lea	(word_6A4A).l,a1

loc_6A04:
	tst.w	(word_FF1124).l
	beq.s	loc_6A28
	move.w	(a1)+,(palette_buffer+$54).l
	move.w	(a1),(palette_buffer+$58).l
	move.b	#2,d0
	lea	((palette_buffer+$40)).l,a2
	jmp	(LoadPalette).l
; ---------------------------------------------------------------------------

loc_6A28:
	move.w	(a1)+,(palette_buffer+$74).l
	move.w	(a1),(palette_buffer+$78).l
	move.b	#3,d0
	lea	((palette_buffer+$60)).l,a2
	jmp	(LoadPalette).l
; ---------------------------------------------------------------------------

loc_6A44:
	jmp	(sub_61C0).l
; ---------------------------------------------------------------------------
word_6A4A:
	dc.w $8E
	dc.w $6CE
word_6A4E:
	dc.w $8CE
	dc.w $EEE
	dc.w $46A
	dc.w $68C
	dc.w $24
	dc.w $24
	dc.w $E
	dc.w $E
	dc.w 8
	dc.w 8
	dc.w 2
	dc.w 2
word_6A66:
	dc.w $24
	dc.w $24
	dc.w $24
	dc.w $24
	dc.w $48
	dc.w $48
	dc.w $26A
	dc.w $26A
	dc.w $26A
	dc.w $48C
	dc.w $48C
	dc.w $6AE
	dc.w $6AE
	dc.w $8CE
	dc.w $8CE
	dc.w $AEE
	dc.w $8CE
	dc.w $EEE
	dc.w $8CE
	dc.w $EEE
	dc.w $8CE
	dc.w $EEE
	dc.w $8CE
	dc.w $EEE
	dc.w $8CE
	dc.w $AEE
	dc.w $6AE
	dc.w $8CE
	dc.w $48C
	dc.w $6AE
	dc.w $26A
	dc.w $48C
	dc.w $26A
	dc.w $26A
	dc.w $48
	dc.w $48
; ---------------------------------------------------------------------------

AnimSpec_Humpty:
	lea	(loc_6AFE).l,a1
	jsr	(FindActorSlot).l
	bcs.s	locret_6AFC
	move.w	#$102,$A(a1)
	move.w	#$E6,$E(a1)
	move.b	#$2D,8(a1)
	move.b	#0,9(a1)
	move.b	#0,6(a1)
	move.l	a2,$2E(a1)
	tst.w	(word_FF1124).l
	beq.s	locret_6AFC
	subi.w	#$58,$A(a1)
	subi.w	#$F8,$E(a1)
	addq.b	#8,9(a1)
	move.b	#4,$2A(a1)

locret_6AFC:
	rts
; ---------------------------------------------------------------------------

loc_6AFE:
	tst.b	(word_FF1124).l
	beq.s	loc_6B0C
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_6B0C:
	move.w	(word_FF198C).l,d0
	cmp.b	$2C(a0),d0
	beq.w	loc_6BA2
	move.b	d0,$2C(a0)
	lsl.w	#2,d0
	movea.l	off_6B26(pc,d0.w),a1
	jmp	(a1)
; ---------------------------------------------------------------------------
off_6B26:
	dc.l loc_6B36
	dc.l loc_6B90
	dc.l loc_6B74
	dc.l loc_6B90
; ---------------------------------------------------------------------------

loc_6B36:
	move.b	#0,9(a0)
	move.w	#0,$26(a0)
	move.w	#0,$28(a0)
	move.w	#0,$2A(a0)
	move.w	#$102,$A(a0)
	move.w	#$E6,$E(a0)
	tst.w	(word_FF1124).l
	beq.s	locret_6B72
	subi.w	#$58,$A(a1)
	subi.w	#$F8,$E(a1)
	addq.b	#4,9(a1)

locret_6B72:
	rts
; ---------------------------------------------------------------------------

loc_6B74:
	move.b	#0,$22(a0)
	move.l	#unk_6CAC,$32(a0)
	move.w	#$12B,$A(a0)
	move.w	#$FA,$E(a0)
	rts
; ---------------------------------------------------------------------------

loc_6B90:
	movea.l	$2E(a0),a1
	move.b	#0,$2C(a1)
	move.b	#0,6(a0)
	rts
; ---------------------------------------------------------------------------

loc_6BA2:
	lsl.w	#2,d0
	movea.l	off_6BAA(pc,d0.w),a1
	jmp	(a1)
; ---------------------------------------------------------------------------
off_6BAA:
	dc.l loc_6BBC
	dc.l loc_6CC2
	dc.l loc_6C9E
	dc.l locret_6BBA
; ---------------------------------------------------------------------------

locret_6BBA:
	rts
; ---------------------------------------------------------------------------

loc_6BBC:
	tst.b	$2A(a0)
	beq.s	loc_6BCE
	subq.b	#1,$2A(a0)
	move.b	#0,6(a0)
	rts
; ---------------------------------------------------------------------------

loc_6BCE:
	move.b	#$80,6(a0)
	addq.b	#1,$22(a0)
	cmpi.b	#3,$22(a0)
	bne.s	loc_6BEC
	eori.b	#1,9(a0)
	move.b	#0,$22(a0)

loc_6BEC:
	tst.b	$28(a0)
	beq.s	loc_6C18
	tst.w	(word_FF1124).l
	beq.s	loc_6C0A
	cmpi.w	#$AC,$A(a0)
	ble.s	loc_6C3C
	subq.w	#6,$A(a0)
	rts
; ---------------------------------------------------------------------------

loc_6C0A:
	cmpi.w	#$104,$A(a0)
	ble.s	loc_6C3C
	subq.w	#6,$A(a0)
	rts
; ---------------------------------------------------------------------------

loc_6C18:
	tst.w	(word_FF1124).l
	beq.s	loc_6C2E
	cmpi.w	#$C4,$A(a0)
	bgt.s	loc_6C3C
	addq.w	#6,$A(a0)
	rts
; ---------------------------------------------------------------------------

loc_6C2E:
	cmpi.w	#$11C,$A(a0)
	bgt.s	loc_6C3C
	addq.w	#6,$A(a0)
	rts
; ---------------------------------------------------------------------------

loc_6C3C:
	move.b	#0,6(a0)
	jsr	(Random).l
	andi.b	#$3F,d0
	move.b	d0,$2A(a0)
	andi.b	#1,d0
	beq.s	loc_6C7A
	tst.w	(word_FF1124).l
	beq.s	loc_6C6C
	move.w	#$C4,$A(a0)
	move.b	#1,$28(a0)
	rts
; ---------------------------------------------------------------------------

loc_6C6C:
	move.w	#$11C,$A(a0)
	move.b	#1,$28(a0)
	rts
; ---------------------------------------------------------------------------

loc_6C7A:
	tst.w	(word_FF1124).l
	beq.s	loc_6C90
	move.w	#$AC,$A(a0)
	move.b	#1,$28(a0)
	rts
; ---------------------------------------------------------------------------

loc_6C90:
	move.w	#$104,$A(a0)
	move.b	#0,$28(a0)
	rts
; ---------------------------------------------------------------------------

loc_6C9E:
	move.b	#$80,6(a0)
	jsr	(ActorAnimate).l
	rts
; ---------------------------------------------------------------------------
; TODO: Document Animation Code

unk_6CAC:
	dc.b $78
	dc.b   5
	dc.b   5
	dc.b   6
	dc.b   6
	dc.b   7
	dc.b   8
	dc.b   6
	dc.b   9
	dc.b   5
	dc.b   5
	dc.b   6
	dc.b   6
	dc.b   7
	dc.b   8
	dc.b   6
	dc.b $FF
	dc.b   0
	dc.l unk_6CAC
; ---------------------------------------------------------------------------

loc_6CC2:
	movea.l	$2E(a0),a1
	move.b	$2C(a1),d0
	cmpi.b	#2,d0
	beq.s	loc_6CDE
	cmpi.b	#8,d0
	beq.s	loc_6CDE
	move.b	#0,$26(a0)
	rts
; ---------------------------------------------------------------------------

loc_6CDE:
	tst.b	$26(a0)
	beq.s	loc_6CE6
	rts
; ---------------------------------------------------------------------------

loc_6CE6:
	move.b	#1,$26(a0)
	lea	(byte_6D6E).l,a2
	move.w	#2,d0

loc_6CF6:
	lea	(loc_6D50).l,a1
	jsr	(FindActorSlot).l
	bcs.s	loc_6D4A
	move.w	(a2)+,$2A(a1)
	move.w	(a2)+,$2C(a1)
	move.b	#$A,$28(a1)
	move.b	#$2D,8(a1)
	move.b	#2,9(a1)
	add.b	d0,9(a1)
	move.w	(a2)+,$A(a1)
	move.w	#$E2,$E(a1)
	move.b	#$80,6(a1)
	tst.w	(word_FF1124).l
	beq.s	loc_6D4A
	subi.w	#$58,$A(a1)
	subi.w	#$F8,$E(a1)
	addq.b	#8,9(a1)

loc_6D4A:
	dbf	d0,loc_6CF6
	rts
; ---------------------------------------------------------------------------

loc_6D50:
	subq.b	#1,$28(a0)
	bne.s	loc_6D5C
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_6D5C:
	move.w	$2A(a0),d0
	add.w	d0,$A(a0)
	move.w	$2C(a0),d0
	add.w	d0,$E(a0)
	rts
; ---------------------------------------------------------------------------
byte_6D6E:
	dc.b   0
	dc.b   2
	dc.b $FF
	dc.b $FE
	dc.b   1
	dc.b $25
	dc.b   0
	dc.b   0
	dc.b $FF
	dc.b $FC
	dc.b   1
	dc.b $1B
	dc.b $FF
	dc.b $FE
	dc.b $FF
	dc.b $FE
	dc.b   1
	dc.b $11
; ---------------------------------------------------------------------------

AnimSpec_SirFfuzzy:
	lea	(loc_6DCE).l,a1
	jsr	(FindActorSlot).l
	bcs.s	locret_6DCC
	move.w	#$110,$A(a1)
	move.w	#$E8,$E(a1)
	move.b	#$2F,8(a1)
	move.b	#0,9(a1)
	move.b	#0,6(a1)
	move.b	#$32,$22(a1)
	lea	(loc_6E46).l,a1
	jsr	(FindActorSlot).l
	bcs.s	locret_6DCC
	move.b	#$11,$22(a1)
	move.b	#0,6(a1)

locret_6DCC:
	rts
; ---------------------------------------------------------------------------

loc_6DCE:
	tst.b	(word_FF1124).l
	beq.s	loc_6DDC
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_6DDC:
	cmpi.w	#2,(word_FF198C).l
	beq.s	loc_6DFA
	move.b	#0,6(a0)
	move.b	#$32,$22(a0)
	move.b	#0,9(a0)
	rts
; ---------------------------------------------------------------------------

loc_6DFA:
	move.b	#$80,6(a0)
	subq.b	#1,$22(a0)
	beq.s	loc_6E08
	rts
; ---------------------------------------------------------------------------

loc_6E08:
	addq.w	#1,$26(a0)
	move.w	$26(a0),d1
	andi.w	#3,d1
	beq.s	loc_6E30
	moveq	#5,d0
	move.b	#2,9(a0)
	andi.b	#1,d1
	beq.s	loc_6E40
	move.b	#6,d0
	move.b	#1,9(a0)
	bra.s	loc_6E40
; ---------------------------------------------------------------------------

loc_6E30:
	move.b	#0,9(a0)
	jsr	(Random).l
	andi.b	#$3F,d0

loc_6E40:
	move.b	d0,$22(a0)
	rts
; ---------------------------------------------------------------------------

loc_6E46:
	jsr	(ActorBookmark).l
	tst.b	(word_FF1124).l
	beq.s	loc_6E5A
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_6E5A:
	tst.b	(byte_FF1121).l
	bne.s	locret_6E68
	subq.b	#1,$22(a0)
	beq.s	loc_6E6A

locret_6E68:
	rts
; ---------------------------------------------------------------------------

loc_6E6A:
	move.w	$26(a0),d1
	addq.b	#1,d1
	andi.b	#7,d1
	move.w	d1,$26(a0)
	move.w	(word_FF198C).l,d0
	cmpi.b	#3,d0
	bne.s	loc_6E8C
	lea	(unk_6F06).l,a1
	bra.s	loc_6EA2
; ---------------------------------------------------------------------------

loc_6E8C:
	lsl.w	#3,d0
	add.w	d1,d0
	move.b	unk_6EE2(pc,d0.w),d0
	move.b	d0,$22(a0)
	lsl.w	#2,d1
	lea	(unk_6F02).l,a1
	adda.w	d1,a1

loc_6EA2:
	tst.w	(word_FF1124).l
	beq.s	loc_6EC6
	move.w	(a1)+,(palette_buffer+$5A).l
	move.w	(a1),(palette_buffer+$44).l
	move.b	#2,d0
	lea	((palette_buffer+$40)).l,a2
	jmp	(LoadPalette).l
; ---------------------------------------------------------------------------

loc_6EC6:
	move.w	(a1)+,(palette_buffer+$7A).l
	move.w	(a1),(palette_buffer+$64).l
	move.b	#3,d0
	lea	((palette_buffer+$60)).l,a2
	jmp	(LoadPalette).l
; ---------------------------------------------------------------------------
unk_6EE2:
	dc.b $11
	dc.b   8
	dc.b  $A
	dc.b  $C
	dc.b  $E
	dc.b   5
	dc.b   5
	dc.b   5
	dc.b   5
	dc.b   5
	dc.b   5
	dc.b   5
	dc.b   5
	dc.b   2
	dc.b   2
	dc.b   2
	dc.b   2
	dc.b   2
	dc.b   2
	dc.b   2
	dc.b   2
	dc.b   2
	dc.b   2
	dc.b   2
	dc.b $11
	dc.b   8
	dc.b  $A
	dc.b  $C
	dc.b  $E
	dc.b   5
	dc.b   5
	dc.b   5

unk_6F02:	; Palette Cycling for Sir Ffuzzy
	dc.w $2AC
	dc.w $4EE

unk_6F06:
	dc.w $8A
	dc.w $CC
	dc.w $68
	dc.w $AA
	dc.w $46
	dc.w $88
	dc.w $24
	dc.w $66
	dc.w $46
	dc.w $88
	dc.w $68
	dc.w $AA
	dc.w $8A
	dc.w $CC
; ---------------------------------------------------------------------------

AnimSpec_Arms:
	lea	(loc_6F38).l,a1
	jsr	(FindActorSlot).l
	bcs.s	locret_6F36
	move.b	#1,$22(a1)

locret_6F36:
	rts
; ---------------------------------------------------------------------------

loc_6F38:
	jsr	(ActorBookmark).l
	tst.b	(word_FF1124).l
	beq.s	loc_6F4C
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_6F4C:
	tst.b	(byte_FF1121).l
	bne.s	locret_6F5A
	subq.b	#1,$22(a0)
	beq.s	loc_6F5C

locret_6F5A:
	rts
; ---------------------------------------------------------------------------

loc_6F5C:
	move.w	(word_FF198C).l,d0
	cmp.b	$2A(a0),d0
	beq.s	loc_6F72
	move.w	#0,$26(a0)
	move.b	d0,$2A(a0)

loc_6F72:
	cmpi.b	#3,d0
	beq.s	loc_6FB0
	move.b	#$E,d1
	move.b	#6,d2
	lea	(unk_6FF2).l,a1
	tst.b	d0
	beq.s	loc_6F98
	lea	(unk_700E).l,a1
	move.b	#4,d1
	move.b	#4,d2

loc_6F98:
	move.w	$26(a0),d0
	addq.b	#1,d0
	cmp.b	d1,d0
	bne.s	loc_6FA6
	move.b	#0,d0

loc_6FA6:
	move.w	d0,$26(a0)
	add.w	d0,d0
	adda.w	d0,a1
	bra.s	loc_6FBA
; ---------------------------------------------------------------------------

loc_6FB0:
	lea	(unk_7016).l,a1
	move.b	#0,d2

loc_6FBA:
	move.b	d2,$22(a0)
	tst.w	(word_FF1124).l
	beq.s	loc_6FDC
	move.w	(a1),(palette_buffer+$5C).l
	move.b	#2,d0
	lea	((palette_buffer+$40)).l,a2
	jmp	(LoadPalette).l
; ---------------------------------------------------------------------------

loc_6FDC:
	move.w	(a1),(palette_buffer+$7C).l
	move.b	#3,d0
	lea	((palette_buffer+$60)).l,a2
	jmp	(LoadPalette).l
; ---------------------------------------------------------------------------
unk_6FF2:	; Palette cycling for Arms
	dc.w $46
	dc.w $48
	dc.w $26A
	dc.w $48C
	dc.w $6AE
	dc.w $8CE
	dc.w $AEE
	dc.w $EEE
	dc.w $AEE
	dc.w $8CE
	dc.w $6AE
	dc.w $48C
	dc.w $26A
	dc.w $48

unk_700E:
	dc.w $EEE
	dc.w $8CE
	dc.w $48C
	dc.w $46

unk_7016:
	dc.w $EE

; ---------------------------------------------------------------------------

Passwords:
	include "resource/misc/List of Passwords.asm"

; =============== S U B	R O U T	I N E =======================================


sub_7078:
	eori.b	#1,$2A(a0)
	bsr.w	GetPuyoFieldPos
	eori.b	#1,$2A(a0)
	addi.w	#$10,d0
	move.w	d0,d3
	move.w	#3,d1

loc_7092:
	lea	(sub_7104).l,a1
	bsr.w	FindActorSlotQuick
	bcs.s	loc_70FE
	move.b	#$F,6(a1)
	move.b	#$25,8(a1)
	move.b	d1,9(a1)
	move.w	d1,d2
	lsl.w	#4,d2
	jsr	(Random).l
	andi.b	#$F,d0
	or.b	d0,d2
	move.w	d2,$26(a1)
	move.w	#$40,d0
	jsr	(RandomBound).l
	add.w	d3,d0
	move.w	d0,$A(a1)
	move.w	#$160,$E(a1)
	move.w	#$FFFC,$16(a1)
	move.w	#$FFFF,$20(a1)
	move.w	#$C00,$1C(a1)
	move.w	$A(a1),$1E(a1)
	move.w	#1,$12(a1)
	move.w	#$2000,$1A(a1)

loc_70FE:
	dbf	d1,loc_7092
	rts
; End of function sub_7078


; =============== S U B	R O U T	I N E =======================================


sub_7104:
	move.w	#$18,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark).l
	tst.w	$26(a0)
	beq.s	loc_7122
	subq.w	#1,$26(a0)
	rts
; ---------------------------------------------------------------------------

loc_7122:
	ori.b	#$80,6(a0)
	move.w	#$40,$26(a0)
	bsr.w	ActorBookmark
	bsr.w	sub_3810
	subq.w	#1,$26(a0)
	beq.s	loc_7140
	rts
; ---------------------------------------------------------------------------

loc_7140:
	move.b	#0,6(a0)
	move.w	#8,d0
	bsr.w	ActorBookmark_SetDelay
	bsr.w	ActorBookmark

loc_7152:
	clr.w	d0
	move.b	9(a0),d0
	lsl.w	#2,d0
	movea.l	off_71CC(pc,d0.w),a2
	move.w	#7,d3

loc_7162:
	lea	(loc_7270).l,a1
	bsr.w	FindActorSlotQuick
	bcs.s	loc_71BA
	move.b	#$87,6(a1)
	move.b	8(a0),8(a1)
	move.b	9(a0),9(a1)
	move.l	a2,$32(a1)
	move.w	$A(a0),$A(a1)
	move.w	$E(a0),$E(a1)
	move.w	#$FFFF,$20(a1)
	move.w	#$800,$1C(a1)
	move.b	d3,d0
	lsl.b	#5,d0
	move.w	#$100,d1
	jsr	(Sin).l
	move.l	d2,$12(a1)
	jsr	(Cos).l
	move.l	d2,$16(a1)

loc_71BA:
	dbf	d3,loc_7162
	move.b	#SFX_THUD,d0
	jsr	(PlaySound_ChkPCM).l
	bra.w	ActorDeleteSelf
; End of function sub_7104

; ---------------------------------------------------------------------------
off_71CC:
	dc.l unk_71DC
	dc.l unk_71E4
	dc.l unk_71EC
	dc.l unk_71F4

unk_71DC:
	dc.b   8
	dc.b   0
	dc.b $20
	dc.b   4
	dc.b $40
	dc.b   8
	dc.b $FE
	dc.b   0

unk_71E4:
	dc.b   8
	dc.b   1
	dc.b $20
	dc.b   5
	dc.b $40
	dc.b   9
	dc.b $FE
	dc.b   0

unk_71EC:
	dc.b   8
	dc.b   2
	dc.b $20
	dc.b   6
	dc.b $40
	dc.b  $A
	dc.b $FE
	dc.b   0

unk_71F4:
	dc.b   8
	dc.b   3
	dc.b $20
	dc.b   7
	dc.b $40
	dc.b  $B
	dc.b $FE
	dc.b   0
; ---------------------------------------------------------------------------

loc_71FC:
	lea	(word_725A).l,a2
	move.w	#$A0,d1
	tst.b	$2A(a0)
	bne.s	loc_7212
	move.w	#$160,d1

loc_7212:
	move.w	#3,d0

loc_7216:
	lea	(loc_7262).l,a1
	jsr	(FindActorSlotQuick).l
	bcs.s	loc_7254
	move.b	#$25,8(a1)
	move.b	d0,9(a1)
	move.l	d0,-(sp)
	jsr	(Random).l
	andi.w	#$3F,d0
	add.w	d1,d0
	move.w	d0,$A(a1)
	move.l	(sp)+,d0
	move.w	d0,d2
	lsl.w	#4,d2
	move.w	d2,$26(a1)
	move.w	(a2)+,$E(a1)

loc_7254:
	dbf	d0,loc_7216
	rts
; ---------------------------------------------------------------------------
word_725A:
	dc.w $A0
	dc.w $B8
	dc.w $B0
	dc.w $A8
; ---------------------------------------------------------------------------

loc_7262:
	tst.w	$26(a0)
	beq.w	loc_7152
	subq.w	#1,$26(a0)
	rts
; ---------------------------------------------------------------------------

loc_7270:
	bsr.w	sub_3810
	bcs.w	ActorDeleteSelf
	bsr.w	ActorAnimate
	bcs.w	ActorDeleteSelf
	rts

; =============== S U B	R O U T	I N E =======================================


sub_7282:
	move.w	#$800A,d0
	swap	d0
	move.b	$2A(a0),d0
	jmp	(QueuePlaneCmd).l
; End of function sub_7282


; =============== S U B	R O U T	I N E =======================================


sub_7292:
	lea	(loc_72A4).l,a1
	bra.w	FindActorSlot
; End of function sub_7292

; ---------------------------------------------------------------------------
	nop
	nop
	nop
	nop

loc_72A4:
	move.w	#$A,$26(a0)
	jsr	(ActorBookmark).l
	move.w	#$9B00,d0
	move.b	$27(a0),d0
	swap	d0
	jsr	(QueuePlaneCmd).l
	subq.w	#1,$26(a0)
	beq.s	loc_72CA
	rts
; ---------------------------------------------------------------------------

loc_72CA:
	jsr	(ActorBookmark).l
	move.w	#$800C,d0
	swap	d0
	move.w	#$F00,d0
	jmp	(QueuePlaneCmd).l

; =============== S U B	R O U T	I N E =======================================

sub_72E0:
	move.l	a0,-(sp)
	lea	(ArtPuyo_VSWinLose).l,a0
	move.w	#$4000,d0

	if PuyoCompression=0
	jsr	(PuyoDec).l
	else
	DISABLE_INTS
	jsr	(NemDec).l
	ENABLE_INTS
	endc

	lea	(ArtNem_AllRightOhNo).l,a0
	move.w	#$2000,d0
	DISABLE_INTS
	jsr	(NemDec).l
	ENABLE_INTS
	lea	(Palettes).l,a2
	adda.l	#(Pal_VsOhNo-Palettes),a2
	move.b	#3,d0
	jsr	(LoadPalette).l
	move.l	(sp)+,a0

	lea	(loc_75CE).l,a1
	bsr.w	FindActorSlot
	bcs.w	locret_7482
	move.b	#$80,6(a1)
	move.b	#$27,8(a1)
	move.l	a0,$2E(a1)
	move.b	$2A(a0),$2A(a1)
	eori.b	#1,$2A(a1)
	move.b	#$FF,7(a1)
	movea.l	a1,a2
	lea	(loc_7654).l,a1
	bsr.w	FindActorSlot
	bcs.w	locret_7482
	move.b	#$80,6(a1)
	move.b	#$27,8(a1)
	move.b	#$12,9(a1)
	move.w	#$4B,$28(a1)
	move.w	#$1F,$2A(a1)
	move.l	a2,$2E(a1)
	move.l	#byte_767E,$32(a1)
	moveq	#1,d1
	lea	(byte_7484).l,a3

loc_7398:
	lea	(loc_76B0).l,a1
	bsr.w	FindActorSlot
	bcs.w	locret_7482
	move.b	#0,6(a1)
	move.b	#$27,8(a1)
	move.b	#$15,9(a1)
	move.l	a2,$2E(a1)
	move.b	(a3)+,$29(a1)
	move.b	(a3)+,$2B(a1)
	jsr	(Random).l
	andi.b	#$3F,d0
	move.b	d0,$22(a1)
	dbf	d1,loc_7398
	lea	(sub_7752).l,a1
	bsr.w	FindActorSlot
	bcs.w	locret_7482
	move.b	#$93,6(a1)
	move.b	#$27,8(a1)
	move.b	#1,9(a1)
	move.l	a0,$2E(a1)
	move.b	$2A(a0),$2A(a1)
	move.b	#$FF,7(a1)
	move.l	#unk_7832,$32(a1)
	movea.l	a1,a2
	lea	(loc_7654).l,a1
	bsr.w	FindActorSlot
	bcs.w	locret_7482
	move.b	#$80,6(a1)
	move.b	#$27,8(a1)
	move.b	#$19,9(a1)
	move.w	#$4C,$28(a1)
	move.w	#$2F,$2A(a1)
	move.l	a2,$2E(a1)
	move.l	#unk_7692,$32(a1)
	moveq	#1,d1

loc_744A:
	lea	(loc_7840).l,a1
	bsr.w	FindActorSlot
	bcs.w	locret_7482
	move.b	#0,6(a1)
	move.b	#$27,8(a1)
	move.b	#$1E,9(a1)
	move.l	a2,$2E(a1)
	move.w	(a3)+,$28(a1)
	move.w	(a3)+,$2A(a1)
	move.l	(a3),$32(a1)
	move.l	(a3)+,$36(a1)
	dbf	d1,loc_744A

locret_7482:
	rts
; End of function sub_72E0

; ---------------------------------------------------------------------------
byte_7484:
	dc.b $2C
	dc.b 4
	dc.b $52
	dc.b 2
	dc.w $3C
	dc.w 2
	dc.l unk_78A4
	dc.w $FFFB
	dc.w $37
	dc.l unk_78AE

; =============== S U B	R O U T	I N E =======================================

sub_7498:
	move.w	#$1F,d0
	lea	(off_757E).l,a2

loc_74A2:
	lea	(sub_7522).l,a1
	jsr	(FindActorSlotQuick).l
	bcs.s	loc_751C
	move.l	a0,$2E(a1)
	move.b	8(a0),8(a1)
	move.w	$A(a0),$1E(a1)
	addi.w	#$30,$1E(a1)
	move.w	$20(a0),$20(a1)
	addi.w	#$18,$20(a1)
	move.b	d0,d1
	lsl.b	#4,d1
	move.b	d0,d2
	lsr.b	#1,d2
	andi.b	#8,d2
	or.b	d2,d1
	move.b	d1,$36(a1)
	move.w	d0,d1
	andi.b	#$10,d1
	move.w	#8,d2
	lsl.w	d2,d1
	addi.w	#$2000,d1
	move.w	d1,$38(a1)
	move.w	d0,d1
	lsl.b	#2,d1
	andi.b	#$C,d1
	move.l	(a2,d1.w),$32(a1)
	move.b	#1,$12(a1)
	cmpi.b	#$10,d0
	bcc.s	loc_751C
	move.b	#$FF,$12(a1)

loc_751C:
	dbf	d0,loc_74A2
	rts
; End of function sub_7498


; =============== S U B	R O U T	I N E =======================================


sub_7522:
	jsr	(ActorAnimate).l
	move.b	#$80,6(a0)
	jsr	(ActorBookmark).l
	movea.l	$2E(a0),a1
	tst.b	7(a1)
	beq.w	ActorDeleteSelf
	jsr	(ActorAnimate).l
	move.b	$36(a0),d0
	move.w	$38(a0),d1
	jsr	(Sin).l
	swap	d2
	add.w	$1E(a0),d2
	move.w	d2,$A(a0)
	addi.b	#$28,d0
	asr.w	#1,d1
	jsr	(Cos).l
	swap	d2
	add.w	$20(a0),d2
	move.w	d2,$E(a0)
	move.b	$12(a0),d0
	add.b	d0,$36(a0)
	rts
; End of function sub_7522

; ---------------------------------------------------------------------------
; TO-DO: Document Animation Table

off_757E:
	dc.l unk_7592
	dc.l unk_759E
	dc.l unk_75AA
	dc.l unk_75B6
	dc.l unk_75C2

unk_7592:
	dc.b   4
	dc.b   3
	dc.b   4
	dc.b   4
	dc.b   4
	dc.b   5
	dc.b $FF
	dc.b   0
	dc.l unk_7592

unk_759E:
	dc.b   4
	dc.b   8
	dc.b   4
	dc.b   7
	dc.b   4
	dc.b   6
	dc.b $FF
	dc.b   0
	dc.l unk_759E

unk_75AA:
	dc.b   4
	dc.b   9
	dc.b   4
	dc.b  $A
	dc.b   4
	dc.b  $B
	dc.b $FF
	dc.b   0
	dc.l unk_75AA

unk_75B6:
	dc.b   4
	dc.b  $E
	dc.b   4
	dc.b  $D
	dc.b   4
	dc.b  $C
	dc.b $FF
	dc.b   0
	dc.l unk_75B6

unk_75C2:
	dc.b   4
	dc.b  $F
	dc.b   4
	dc.b $10
	dc.b   4
	dc.b $11
	dc.b $FF
	dc.b   0
	dc.l unk_75C2
; ---------------------------------------------------------------------------

loc_75CE:
	bsr.w	GetPuyoFieldPos
	move.w	d0,$A(a0)
	addi.w	#$48,d1
	move.w	d1,$20(a0)
	bsr.w	sub_7498
	bsr.w	ActorBookmark
	movea.l	$2E(a0),a1
	btst	#2,7(a1)
	beq.w	ActorDeleteSelf
	btst	#1,7(a1)
	beq.s	loc_7620
	move.b	$36(a0),d0
	ori.b	#$80,d0
	move.w	#$1000,d1
	jsr	(Sin).l
	swap	d2
	add.w	$20(a0),d2
	move.w	d2,$E(a0)
	addq.b	#4,$36(a0)
	rts
; ---------------------------------------------------------------------------

loc_7620:
	move.b	#0,7(a0)
	move.b	#$80,6(a0)
	move.b	#$29,8(a0)
	move.l	#unk_8308,$32(a0)
	move.w	$20(a0),$E(a0)
	addi.w	#$30,$A(a0)
	subq.w	#8,$E(a0)
	bsr.w	ActorBookmark
	jmp	(ActorAnimate).l
; ---------------------------------------------------------------------------

loc_7654:
	movea.l	$2E(a0),a1
	tst.b	7(a1)
	beq.w	ActorDeleteSelf
	move.w	$A(a1),d0
	add.w	$28(a0),d0
	move.w	d0,$A(a0)
	move.w	$E(a1),d0
	add.w	$2A(a0),d0
	move.w	d0,$E(a0)
	jmp	(ActorAnimate).l
; ---------------------------------------------------------------------------
; TODO: Document Animation Code

byte_767E:
	dc.b $3C
	dc.b $12
	dc.b   8
	dc.b $13
	dc.b   5
	dc.b $12
	dc.b   5
	dc.b $14
	dc.b   5
	dc.b $13
	dc.b   5
	dc.b $12
	dc.b   5
	dc.b $13
	dc.b $FF
	dc.b   0
	dc.l byte_767E

unk_7692:
	dc.b $1E
	dc.b $19
	dc.b   7
	dc.b $1A
	dc.b   5
	dc.b $1B
	dc.b   4
	dc.b $1C
	dc.b   3
	dc.b $1B
	dc.b   3
	dc.b $1A
	dc.b   3
	dc.b $19
	dc.b   3
	dc.b $1D
	dc.b   3
	dc.b $19
	dc.b   3
	dc.b $1A
	dc.b   3
	dc.b $19
	dc.b   3
	dc.b $1D
	dc.b $FF
	dc.b   0
	dc.l unk_7692
; ---------------------------------------------------------------------------

loc_76B0:
	movea.l	$2E(a0),a1
	tst.b	7(a1)
	beq.w	ActorDeleteSelf
	move.w	$A(a1),d0
	add.w	$28(a0),d0
	move.w	d0,$A(a0)
	move.w	$E(a1),d0
	add.w	$2A(a0),d0
	move.w	d0,$E(a0)
	tst.b	$22(a0)
	beq.s	loc_76E0
	subq.b	#1,$22(a0)
	rts
; ---------------------------------------------------------------------------

loc_76E0:
	move.b	$26(a0),d0
	beq.s	loc_7714
	cmpi.b	#1,d0
	beq.s	loc_770C
	move.b	#0,$26(a0)
	move.b	#0,6(a0)
	jsr	(Random).l
	andi.b	#$3F,d0
	addi.b	#$44,d0
	move.b	d0,$22(a0)
	rts
; ---------------------------------------------------------------------------

loc_770C:
	move.b	#$16,9(a0)
	bra.s	loc_7720
; ---------------------------------------------------------------------------

loc_7714:
	move.b	#$80,6(a0)
	move.b	#$15,9(a0)

loc_7720:
	addq.b	#1,$26(a0)
	move.b	#5,$22(a0)
	rts

; =============== S U B	R O U T	I N E =======================================


sub_772C:
	movea.l	$2E(a0),a1
	btst	#2,7(a1)
	beq.s	loc_7746
	btst	#1,7(a1)
	beq.s	loc_7746
	rts
; ---------------------------------------------------------------------------

loc_7746:
	movem.l	(sp)+,d0
	clr.b	7(a0)
	bra.w	ActorDeleteSelf
; End of function sub_772C


; =============== S U B	R O U T	I N E =======================================


sub_7752:
	bsr.w	GetPuyoFieldPos
	subi.w	#$10,d0
	move.w	d0,$A(a0)
	addi.w	#-$30,d1
	move.w	d1,$E(a0)
	move.l	#(loc_FFFE+2),$12(a0)
	move.l	#$8000,$16(a0)
	move.w	#6,$28(a0)

loc_777C:
	move.w	#$20,$26(a0)
	bsr.w	ActorBookmark
	bsr.s	sub_772C
	tst.w	$26(a0)
	beq.s	loc_77A2
	jsr	(sub_3810).l
	jsr	(ActorAnimate).l
	subq.w	#1,$26(a0)
	rts
; ---------------------------------------------------------------------------

loc_77A2:
	tst.w	$28(a0)
	beq.s	loc_77BA
	subq.w	#1,$28(a0)
	move.l	$12(a0),d0
	neg.l	d0
	move.l	d0,$12(a0)
	bra.s	loc_777C
; ---------------------------------------------------------------------------

loc_77BA:
	move.l	$12(a0),d0
	neg.l	d0
	move.l	d0,$12(a0)
	move.w	#$10,d0
	bsr.w	ActorBookmark_SetDelay
	jsr	(sub_3810).l
	jsr	(ActorAnimate).l
	bsr.w	ActorBookmark

loc_77DC:
	bsr.w	ActorBookmark
	bsr.w	sub_772C
	cmpi.w	#$90,$E(a0)
	bcs.s	loc_77F4
	subq.w	#1,$E(a0)
	rts
; ---------------------------------------------------------------------------

loc_77F4:
	move.b	#$85,6(a0)
	clr.l	$16(a0)
	move.w	#$2000,$1C(a0)
	move.w	#$FFFF,$20(a0)
	bsr.w	ActorBookmark
	bsr.w	sub_772C
	jsr	(sub_3810).l
	jsr	(ActorAnimate).l
	cmpi.w	#$D0,$E(a0)
	bcc.s	loc_782A
	rts
; ---------------------------------------------------------------------------

loc_782A:
	move.w	#$D0,$E(a0)
	bra.s	loc_77DC
; End of function sub_7752

; ---------------------------------------------------------------------------
; TODO: Document Animation Code

unk_7832:
	dc.b $1E
	dc.b   1
	dc.b  $A
	dc.b $17
	dc.b   5
	dc.b   1
	dc.b  $D
	dc.b $18
	dc.b $FF
	dc.b   0
	dc.l unk_7832
; ---------------------------------------------------------------------------

loc_7840:
	movea.l	$2E(a0),a1
	tst.b	7(a1)
	beq.w	ActorDeleteSelf
	move.w	$A(a1),d0
	add.w	$28(a0),d0
	move.w	d0,$A(a0)
	move.w	$E(a1),d0
	add.w	$2A(a0),d0
	move.w	d0,$E(a0)
	tst.b	$2C(a0)
	bne.s	loc_7882
	cmpi.b	#$18,9(a1)
	bne.s	locret_7880
	cmpi.b	#$C,$22(a1)
	bne.s	locret_7880
	move.b	#1,$2C(a0)

locret_7880:
	rts
; ---------------------------------------------------------------------------

loc_7882:
	move.b	#$80,6(a0)
	jsr	(ActorAnimate).l
	bcc.s	locret_78A2
	move.b	#0,6(a0)
	clr.b	$2C(a0)
	move.l	$36(a0),d0
	move.l	d0,$32(a0)

locret_78A2:
	rts
; ---------------------------------------------------------------------------
; TODO: Document Animation Code

unk_78A4:
	dc.b   4
	dc.b $1E
	dc.b   5
	dc.b $1F
	dc.b   6
	dc.b $20
	dc.b   7
	dc.b $21
	dc.b $FE
	dc.b   0

unk_78AE:
	dc.b   4
	dc.b $22
	dc.b   5
	dc.b $23
	dc.b   6
	dc.b $24
	dc.b   7
	dc.b $25
	dc.b $FE
	dc.b   0

; =============== S U B	R O U T	I N E =======================================

sub_78B8:
	lea	(loc_78E8).l,a1
	jsr	(FindActorSlot).l
	bcc.s	loc_78CA
	rts
; ---------------------------------------------------------------------------

loc_78CA:
	move.l	a0,$2E(a1)
	move.b	#$27,8(a1)
	move.b	#2,9(a1)
	move.w	#$118,$A(a1)
	move.w	#$10C,$E(a1)
	rts
; End of function sub_78B8

; ---------------------------------------------------------------------------

loc_78E8:
	move.w	#$40,d0
	jsr	(RandomBound).l
	addi.w	#$20,d0
	move.w	d0,$26(a0)
	bsr.w	ActorBookmark
	tst.w	$26(a0)
	beq.s	loc_790C
	subq.w	#1,$26(a0)
	rts
; ---------------------------------------------------------------------------

loc_790C:
	move.b	#$80,6(a0)
	move.w	#$30,d0
	bsr.w	ActorBookmark_SetDelay
	bsr.w	ActorBookmark
	move.b	#0,6(a0)
	bra.s	loc_78E8

; =============== S U B	R O U T	I N E =======================================

sub_7926:
	bsr.w	GetPuyoField
	adda.l	#pVisiblePuyos,a2
	move.w	#(PUYO_FIELD_COLS*(PUYO_FIELD_ROWS-2)*2)-2,d0

loc_7934:
	move.b	(a2,d0.w),d1
	beq.s	loc_794E
	andi.b	#$70,d1
	cmpi.b	#$60,d1
	beq.s	loc_794E
	andi.b	#$F3,(a2,d0.w)

loc_794E:
	subq.w	#2,d0
	bcc.s	loc_7934
	DISABLE_INTS
	bsr.w	sub_5782
	ENABLE_INTS
	clr.w	d3
	lea	(loc_833E).l,a1
	bsr.w	FindActorSlot
	bcs.s	loc_7982
	addq.w	#1,d3
	move.l	a0,$2E(a1)
	move.l	#unk_837A,$32(a1)
	move.b	#$FF,8(a1)

loc_7982:
	bsr.w	GetPuyoField
	adda.l	#pVisiblePuyos,a2
	andi.w	#$7F,d0
	move.w	d0,d2
	bsr.w	GetPuyoFieldPos
	addi.w	#$17,d0
	lea	(unk_7A7C).l,a3
	move.w	#5,d1

loc_79A4:
	lea	(loc_8386).l,a1
	bsr.w	FindActorSlot
	bcs.s	loc_79E6
	bsr.w	sub_8250
	addq.w	#1,d3
	move.l	a0,$2E(a1)
	move.b	#4,6(a1)
	move.w	d0,$A(a1)
	move.w	#$2000,$1C(a1)
	move.w	#$FFFF,$20(a1)
	move.w	d2,$32(a1)
	move.w	d1,d4
	lsl.w	#1,d4
	move.w	(a3,d4.w),$24(a1)
	move.w	$C(a3,d4.w),$1A(a1)

loc_79E6:
	addi.w	#$A,d0
	addq.w	#4,d2
	adda.l	#2,a2
	dbf	d1,loc_79A4
	move.w	d3,$26(a0)
	rts
; End of function sub_7926

; ---------------------------------------------------------------------------

loc_79FC:
	cmpi.b	#1,(level_mode).l
	bcc.s	loc_7A12
	jsr	(StopSound).l
	bsr.w	ActorBookmark

loc_7A12:
	bsr.w	sub_7A94
	bsr.w	sub_7926
	bsr.w	ActorBookmark
	tst.w	$26(a0)
	beq.s	loc_7A28
	rts
; ---------------------------------------------------------------------------

loc_7A28:
	bsr.w	ResetPuyoField
	DISABLE_INTS
	bsr.w	sub_5782
	ENABLE_INTS
	bsr.w	ActorBookmark
	bsr.w	GetPuyoField
	andi.w	#$7F,d0
	move.w	#5,d1
	lea	(vscroll_buffer).l,a2

loc_7A4E:
	clr.l	(a2,d0.w)
	addq.w	#4,d0
	dbf	d1,loc_7A4E
	clr.w	d0
	move.b	(level_mode).l,d0
	andi.b	#3,d0
	lsl.b	#2,d0
	movea.l	off_7A6C(pc,d0.w),a2
	jmp	(a2)
; ---------------------------------------------------------------------------
off_7A6C:
	dc.l loc_7D78
	dc.l loc_7F70
	dc.l loc_80EE
	dc.l loc_80EE

unk_7A7C:
	dc.b   0
	dc.b $20
	dc.b   0
	dc.b $14
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b   0
	dc.b $10
	dc.b   0
	dc.b $24
	dc.b  $B
	dc.b   0
	dc.b   9
	dc.b   0
	dc.b   7
	dc.b   0
	dc.b   8
	dc.b   0
	dc.b  $A
	dc.b   0
	dc.b  $B
	dc.b   0

; =============== S U B	R O U T	I N E =======================================

sub_7A94:
	clr.w	d0
	move.b	(level_mode).l,d0
	lsl.b	#2,d0
	movea.l	off_7AA4(pc,d0.w),a2
	jmp	(a2)
; End of function sub_7A94

; ---------------------------------------------------------------------------
off_7AA4:
	dc.l loc_7ACE
	dc.l loc_7C50
	dc.l loc_7CAC
	dc.l loc_7CAC
	dc.l loc_7AB8
; ---------------------------------------------------------------------------

loc_7AB8:
	movea.l	$2E(a0),a1
	bsr.w	ActorDeleteOther
	clr.b	(bytecode_flag).l
	clr.b	(bytecode_disabled).l
	rts
; ---------------------------------------------------------------------------

loc_7ACE:
	move.w	#$FFFF,(puyos_popping).l
	clr.w	(player_1_flags).l
	move.b	$2A(a0),d0
	eori.b	#1,d0
	move.b	d0,(bytecode_flag).l
	move.b	d0,(byte_FF0115).l
	clr.w	d0
	move.b	$2A(a0),d0
	lsl.b	#1,d0
	ori.b	#1,d0
	move.w	d0,(word_FF198C).l
	clr.l	(dword_FF195C).l
	clr.w	(dword_FF1960).l
	tst.b	$2A(a0)
	bne.s	loc_7B2C
	movea.l	$2E(a0),a1
	bsr.w	ActorDeleteOther
	bsr.w	PlayerLose_ChkRobotnik
	move.b	#SFX_LOSE,d0
	jmp	(PlaySound_ChkPCM).l
; ---------------------------------------------------------------------------

loc_7B2C:
	jsr	(sub_DF74).l
	move.w	(time_total_secs).l,d0
	cmpi.w	#$3E8,d0
	bcs.s	loc_7B44
	move.w	#$3E7,d0

loc_7B44:
	move.w	d0,$16(a0)
	bsr.w	sub_7CF6
	move.w	d0,$12(a0)
	movea.l	$2E(a0),a1
	move.l	$A(a1),$A(a0)
	move.l	$A(a1),(dword_FF195C).l
	add.l	d0,(dword_FF195C).l
	cmpi.l	#$5F5E100,(dword_FF195C).l
	bcs.s	loc_7B80
	move.l	#$5F5E0FF,(dword_FF195C).l

loc_7B80:
	move.w	$16(a1),(dword_FF1960).l
	cmpi.b	#$F,(level).l
	beq.s	loc_7BB6
	cmpi.b	#2,(level).l
	beq.s	loc_7BB6

loc_7BA0:
	bsr.w	ActorDeleteOther
	bsr.w	sub_7292
	bsr.w	sub_7078
	bsr.w	PlayerWin_ChkRobotnik
	jmp	(PlayLevelWinMusic).l
; ---------------------------------------------------------------------------

loc_7BB6:
	movem.l	a0-a1,-(sp)
	movea.l	a1,a0
	move.l	(dword_FF195C).l,$A(a0)
	move.b	(level_mode).l,(high_score_table_id).l
	bsr.w	sub_C438
	movem.l	(sp)+,a0-a1
	bra.s	loc_7BA0

; =============== S U B	R O U T	I N E =======================================

PlayerWin_ChkRobotnik:
	move.b	(opponent).l,d0
	cmpi.b	#OPP_ROBOTNIK,d0
	bne.s	PlayerWin_NotRobotnik
	lea	(Play_RobonikLoseVoice).l,a1
	jmp	(FindActorSlotQuick).l
; ---------------------------------------------------------------------------

Play_RobonikLoseVoice:
	move.w	#$10,$26(a0)
	jsr	(ActorBookmark).l
	subq.w	#1,$26(a0)
	bpl.s	PlayerWin_NotRobotnik
	move.b	#VOI_ROBOTNIK_LOSE,d0
	jsr	(PlaySound_ChkPCM).l
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

PlayerWin_NotRobotnik:
	rts
; End of function PlayerWin_ChkRobotnik


; =============== S U B	R O U T	I N E =======================================

PlayerLose_ChkRobotnik:
	move.b	(opponent).l,d0
	cmpi.b	#OPP_ROBOTNIK,d0
	bne.s	PlayerLose_NotRobotnik
	lea	(Play_RobonikWinVoice).l,a1
	jmp	(FindActorSlotQuick).l
; ---------------------------------------------------------------------------

Play_RobonikWinVoice:
	move.w	#$20,$26(a0)
	jsr	(ActorBookmark).l
	subq.w	#1,$26(a0)
	bpl.s	PlayerLose_NotRobotnik
	move.b	#SFX_ROBOTNIK_LAUGH,d0
	jsr	(PlaySound_ChkPCM).l
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

PlayerLose_NotRobotnik:
	rts
; End of function PlayerLose_ChkRobotnik

; ---------------------------------------------------------------------------

loc_7C50:
	clr.w	d0
	move.b	$2A(a0),d0
	lea	(puyos_popping).l,a1
	move.b	#$FF,(a1,d0.w)
	clr.w	(player_1_flags).l
	movea.l	$2E(a0),a1
	bsr.w	ActorDeleteOther
	move.b	#SFX_LOSE,d0
	jsr	(PlaySound_ChkPCM).l
	move.b	#OPP_ARMS,(opponent).l
	clr.w	d0
	move.b	$2A(a0),d0
	eori.b	#1,d0
	lea	(byte_FF0128).l,a1
	addq.b	#1,(a1,d0.w)
	cmpi.b	#$64,(a1,d0.w)
	bcs.s	loc_7CA8
	clr.w	(a1)
	move.b	#1,(a1,d0.w)

loc_7CA8:
	bra.w	loc_71FC
; ---------------------------------------------------------------------------

loc_7CAC:
	clr.w	d0
	move.b	$2A(a0),d0
	lea	(puyos_popping).l,a1
	lea	(player_1_flags).l,a2
	move.b	#$FF,(a1,d0.w)
	clr.b	(a2,d0.w)
	move.b	#SFX_LOSE,d0
	jmp	(PlaySound_ChkPCM).l

; =============== S U B	R O U T	I N E =======================================

sub_7CD2:
	nop
	nop
	nop
	move.w	#$9800,d0
	swap	d0
	move.w	$16(a0),d0
	jsr	(QueuePlaneCmd).l
	nop
	nop
	move.b	#SFX_RESULT_TIME,d0
	jmp	(PlaySound_ChkPCM).l
; End of function sub_7CD2

; =============== S U B	R O U T	I N E =======================================

sub_7CF6:
	clr.w	d0
	move.b	(byte_FF0114).l,d0
	addq.b	#1,d0
	mulu.w	#$A,d0
	addi.w	#$6E,d0
	sub.w	$16(a0),d0
	bcc.s	loc_7D12
	clr.w	d0

loc_7D12:
	mulu.w	d0,d0
	mulu.w	#3,d0
	rts
; End of function sub_7CF6

; ---------------------------------------------------------------------------

loc_7D1A:
	moveq	#0,d0
	move.w	$12(a0),d0
	bne.s	loc_7D26
	rts
; ---------------------------------------------------------------------------

loc_7D26:
	cmp.w	$28(a0),d0
	bcs.s	loc_7D32
	move.w	$28(a0),d0

loc_7D32:
	sub.w	d0,$12(a0)
	jsr	(sub_9C4A).l
	move.b	$27(a0),d0
	andi.b	#3,d0
	bne.s	loc_7D52
	move.b	#SFX_5F,d0
	jsr	(PlaySound_ChkPCM).l

loc_7D52:
	move.w	#$9900,d0
	swap	d0
	move.w	$12(a0),d0
	jmp	(QueuePlaneCmd).l

; =============== S U B	R O U T	I N E =======================================

sub_7D62:
	moveq	#0,d0
	move.w	#$9E00,d0
	swap	d0
	jsr	(QueuePlaneCmd).l
	moveq	#SFX_PASSWORD,d0
	jmp	(PlaySound_ChkPCM).l
; End of function sub_7D62

; ---------------------------------------------------------------------------

loc_7D78:
	tst.b	$2A(a0)
	beq.w	loc_7EC2
	move.b	#0,$2A(a0)
	move.w	#$60,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark_Ctrl).l
	bsr.w	sub_7CD2
	move.w	#$20,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark).l
	tst.w	$12(a0)
	beq.s	loc_7E30
	move.w	#$9900,d0
	swap	d0
	move.w	$12(a0),d0
	jsr	(QueuePlaneCmd).l
	move.b	#SFX_RESULT_BONUS_2,d0
	jsr	(PlaySound_ChkPCM).l
	move.w	$12(a0),d0
	lsr.w	#7,d0
	bne.s	loc_7DDA
	move.w	#1,d0

loc_7DDA:
	move.w	d0,$28(a0)
	move.w	#$80,$26(a0)
	move.w	#$3C,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark).l
	bsr.w	sub_56C0
	andi.b	#$F0,d0
	bne.s	loc_7E14
	subq.w	#1,$26(a0)
	beq.s	loc_7E14
	cmpi.w	#$780,$26(a0)
	bcs.w	loc_7D1A
	rts
; ---------------------------------------------------------------------------

loc_7E14:
	moveq	#0,d0
	move.w	$12(a0),d0
	jsr	(sub_9C4A).l
	move.l	#$99000000,d0
	jsr	(QueuePlaneCmd).l
	bra.w	loc_7E56
; ---------------------------------------------------------------------------

loc_7E30:
	move.l	#$80050000,d0
	jsr	(QueuePlaneCmd).l
	move.b	#SFX_5E,d0
	jsr	(PlaySound_ChkPCM).l
	move.w	#$40,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark_Ctrl).l

loc_7E56:
	move.b	(level).l,d0
	cmpi.b	#$F,d0
	beq.s	loc_7E68
	bsr.w	sub_7D62
	bra.s	loc_7E9E
; ---------------------------------------------------------------------------

loc_7E68:
	move.l	#$80160000,d0
	jsr	(QueuePlaneCmd).l
	moveq	#SFX_PASSWORD,d0
	jsr	(PlaySound_ChkPCM).l
	move.w	#$78,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark).l
	clr.b	7(a0)
	bsr.w	ActorBookmark
	clr.b	(bytecode_disabled).l
	bra.w	ActorDeleteSelf
; ---------------------------------------------------------------------------

loc_7E9E:
	jsr	(ActorBookmark).l
	move.w	#$A,$24(a0)
	jsr	(ActorBookmark_Ctrl).l
	clr.b	7(a0)
	bsr.w	ActorBookmark
	clr.b	(bytecode_disabled).l
	bra.w	ActorDeleteSelf
; ---------------------------------------------------------------------------

loc_7EC2:
	move.b	#1,7(a0)
	bsr.w	sub_8298
	move.w	#$80,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark_Ctrl).l
	move.b	(level_mode).l,(high_score_table_id).l
	bsr.w	sub_C438
	bcc.s	loc_7EF2
	bsr.w	sub_BFA6

loc_7EF2:
	bsr.w	ActorBookmark
	btst	#1,7(a0)
	beq.s	loc_7F02
	rts
; ---------------------------------------------------------------------------

loc_7F02:
	bsr.w	ResetPuyoField
	DISABLE_INTS
	bsr.w	sub_5782
	ENABLE_INTS
	clr.b	7(a0)
	bsr.w	ActorBookmark
	clr.b	(bytecode_disabled).l
	bra.w	ActorDeleteSelf

; =============== S U B	R O U T	I N E =======================================

sub_7F24:
	lea	(sub_7F5A).l,a1
	jsr	(FindActorSlot).l
	bcs.w	locret_7F58
	move.l	a0,$2E(a1)
	move.b	#$19,8(a1)
	move.b	#$80,6(a1)
	move.w	#$120,$A(a1)
	move.w	#$108,$E(a1)
	move.l	#unk_7F62,$32(a1)

locret_7F58:
	rts
; End of function sub_7F24

; =============== S U B	R O U T	I N E =======================================

sub_7F5A:
	jsr	(ActorAnimate).l
	rts
; End of function sub_7F5A

; ---------------------------------------------------------------------------
; TODO: Document Animation Code

unk_7F62:
	dc.b  $C
	dc.b  $E
	dc.b  $A
	dc.b $35
	dc.b  $C
	dc.b  $F
	dc.b  $A
	dc.b $36
	dc.b $FF
	dc.b   0
	dc.l unk_7F62
; ---------------------------------------------------------------------------

loc_7F70:
	move.w	0(a0),d0
	move.b	$2A(a0),d1
	movem.l	d0-d1/a0,-(sp)
	jsr	(InitActors).l
	movem.l	(sp)+,d0-d1/a0
	move.w	d0,0(a0)
	move.b	d1,$2A(a0)
	bsr.w	ActorBookmark
	move.w	#$17,d0  ; VS Plane Mapping
	jsr	(QueuePlaneCmdList).l
	bsr.w	ActorBookmark
	bsr.w	ActorBookmark
	move.w	#4,d0
	bsr.w	ActorBookmark_SetDelay
	bsr.w	ActorBookmark
	move.w	#2,(word_FF198C).l
	move.b	#$E,7(a0)
	bsr.w	sub_72E0
	jsr	(sub_9794).l
	bsr.w	ActorBookmark
	bsr.w	sub_7F24
	clr.w	d0
	move.b	$2A(a0),d0
	lea	(byte_FF012A).l,a1
	subq.b	#1,(a1,d0.w)
	bne.w	loc_80D2
	bsr.w	sub_9308
	ori.b	#1,7(a0)
	bsr.w	sub_8298
	move.w	#$80,d0
	bsr.w	ActorBookmark_SetDelay
	bsr.w	ActorBookmark_Ctrl
	move.w	#$280,$28(a0)
	andi.b	#$F7,7(a0)
	move.w	#$80,d4
	move.w	#$CCA2,d5
	move.w	#$A500,d6
	jsr	(sub_95B0).l
	bsr.w	ActorBookmark
	jsr	(sub_78B8).l
	bsr.w	ActorBookmark
	bsr.w	sub_56C0
	btst	#7,d0
	beq.s	loc_8044
	jsr	(CheckCoinInserted).l
	bcs.s	loc_8044
	bra.w	loc_80B8
; ---------------------------------------------------------------------------

loc_8044:
	tst.w	$28(a0)
	beq.s	loc_8084
	subq.w	#1,$28(a0)
	andi.b	#$70,d0
	beq.s	loc_805E
	andi.b	#$C0,$29(a0)

loc_805E:
	bsr.w	sub_7282
	move.w	#$8008,d0
	jsr	(CheckCoinInserted).l
	bcs.s	loc_8074
	move.w	#$8009,d0

loc_8074:
	swap	d0
	move.w	#$F00,d0
	move.b	$2A(a0),d0
	jmp	(QueuePlaneCmd).l
; ---------------------------------------------------------------------------

loc_8084:
	bsr.w	sub_7282
	andi.b	#$FD,7(a0)
	move.w	#3,(word_FF198C).l
	bsr.w	ActorBookmark
	move.w	#$80,d0
	bsr.w	ActorBookmark_SetDelay
	bsr.w	ActorBookmark_Ctrl
	clr.b	(bytecode_disabled).l
	move.b	#$FF,(bytecode_flag).l
	bra.w	ActorDeleteSelf
; ---------------------------------------------------------------------------

loc_80B8:
	move.b	#SFX_MENU_SELECT,d0
	jsr	(PlaySound_ChkPCM).l
	clr.b	(bytecode_disabled).l
	clr.b	(bytecode_flag).l
	bra.w	ActorDeleteSelf
; ---------------------------------------------------------------------------

loc_80D2:
	move.w	#$100,d0
	bsr.w	ActorBookmark_SetDelay
	bsr.w	ActorBookmark_Ctrl
	clr.b	(bytecode_disabled).l
	clr.b	(bytecode_flag).l
	bra.w	ActorDeleteSelf
; ---------------------------------------------------------------------------

loc_80EE:
	move.b	#1,7(a0)
	bsr.w	sub_8298
	move.w	#$C0,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark).l
	move.b	#1,(high_score_table_id).l
	bsr.w	sub_C438
	bcc.s	loc_811C
	bsr.w	sub_BFA6

loc_811C:
	bsr.w	ActorBookmark
	btst	#1,7(a0)
	beq.s	loc_812C
	rts
; ---------------------------------------------------------------------------

loc_812C:
	bsr.w	ResetPuyoField
	DISABLE_INTS
	bsr.w	sub_5782
	ENABLE_INTS

loc_813C:
	move.w	#$1C0,$26(a0)
	bsr.w	ActorBookmark
	move.b	(byte_FF1965).l,d0
	eori.b	#3,d0
	beq.w	loc_81FC
	bsr.w	sub_56C0
	btst	#7,d0
	beq.s	loc_816E
	jsr	(CheckCoinInserted).l
	bcs.s	loc_816E
	bra.w	loc_81AE
; ---------------------------------------------------------------------------

loc_816E:
	subq.w	#1,$26(a0)
	bcc.s	loc_8188
	move.w	#0,$26(a0)
	move.b	$2A(a0),d0
	addq.b	#1,d0
	or.b	d0,(byte_FF1965).l

loc_8188:
	bsr.w	sub_7282
	move.w	#$8017,d0
	jsr	(CheckCoinInserted).l
	bcc.s	loc_819E
	move.b	#7,d0

loc_819E:
	swap	d0
	move.w	#$F00,d0
	move.b	$2A(a0),d0
	jmp	(QueuePlaneCmd).l
; ---------------------------------------------------------------------------

loc_81AE:
	move.b	$2A(a0),d0
	addq.b	#1,d0
	not.b	d0
	and.b	d0,(byte_FF1965).l
	move.b	#SFX_MENU_SELECT,d0
	jsr	(PlaySound_ChkPCM).l
	bclr	#0,7(a0)
	bsr.w	ActorBookmark
	move.w	#$8400,d0
	move.b	$2A(a0),d0
	swap	d0
	move.b	#5,d0
	jsr	(QueuePlaneCmd).l
	bsr.w	sub_8210
	bsr.w	ResetPuyoField
	DISABLE_INTS
	bsr.w	sub_5782
	ENABLE_INTS
	bra.w	loc_3D44
; ---------------------------------------------------------------------------

loc_81FC:
	clr.b	(bytecode_disabled).l
	bclr	#0,7(a0)
	bsr.w	ActorBookmark
	bra.w	ActorDeleteSelf

; =============== S U B	R O U T	I N E =======================================


sub_8210:
	clr.b	8(a0)
	clr.b	$2B(a0)
	clr.l	$A(a0)
	clr.l	$E(a0)
	clr.w	$16(a0)
	clr.w	$18(a0)
	movea.l	$32(a0),a1
	move.w	#$FFFF,$20(a1)
	clr.w	$1E(a1)
	clr.b	7(a1)
	move.w	#4,d2

loc_823E:
	bsr.w	sub_43EA
	move.b	d0,$26(a1,d2.w)
	move.b	d1,$27(a1,d2.w)
	subq.w	#2,d2
	bcc.s	loc_823E
	rts
; End of function sub_8210

; =============== S U B	R O U T	I N E =======================================

sub_8250:
	movem.l	d0-d2,-(sp)
	move.w	#$B,d0
	clr.w	d1
	clr.b	d2

loc_825C:
	move.b	(a2,d1.w),d2
	beq.s	loc_8270
	andi.b	#$70,d2
	cmpi.b	#$60,d2
	bne.s	loc_8286

loc_8270:
	addi.w	#$C,d1
	dbf	d0,loc_825C
	move.w	#5,d0
	jsr	(RandomBound).l
	move.b	unk_8292(pc,d0.w),d2

loc_8286:
	lsr.b	#4,d2
	move.b	d2,8(a1)
	movem.l	(sp)+,d0-d2
	rts
; End of function sub_8250

; ---------------------------------------------------------------------------
unk_8292:
	dc.b   0
	dc.b $10
	dc.b $30
	dc.b $40
	dc.b $50
	dc.b $20

; =============== S U B	R O U T	I N E =======================================

sub_8298:
	lea	(sub_82E0).l,a1
	bsr.w	FindActorSlot
	bcs.w	locret_82DE
	move.l	a0,$2E(a1)
	move.b	$2A(a0),$2A(a1)
	move.b	#$80,6(a1)
	move.b	#$29,8(a1)
	bsr.w	GetPuyoFieldPos
	addi.w	#$30,d0
	move.w	d0,$A(a1)
	addi.w	#$40,d1
	move.w	d1,$20(a1)
	move.w	#$168,$E(a1)
	move.l	#unk_8308,$32(a1)

locret_82DE:
	rts
; End of function sub_8298

; =============== S U B	R O U T	I N E =======================================

sub_82E0:
	movem.l	$2E(a0),a1
	btst	#0,7(a1)
	beq.w	ActorDeleteSelf
	bsr.w	ActorAnimate
	move.w	$20(a0),d0
	cmp.w	$E(a0),d0
	bcs.s	loc_8302
	rts
; ---------------------------------------------------------------------------

loc_8302:
	subq.w	#1,$E(a0)
	rts
; End of function sub_82E0

; ---------------------------------------------------------------------------
; TODO: Document Animation Code

unk_8308:
	dc.b $40
	dc.b   0
	dc.b   1
	dc.b   1
	dc.b   2
	dc.b   2
	dc.b   1
	dc.b   1
	dc.b $20
	dc.b   0
	dc.b   1
	dc.b   1
	dc.b   2
	dc.b   2
	dc.b   1
	dc.b   1
	dc.b   0
	dc.b   0
	dc.b   1
	dc.b   1
	dc.b   2
	dc.b   2
	dc.b   1
	dc.b   1
	dc.b $10
	dc.b   0
	dc.b   1
	dc.b   1
	dc.b   2
	dc.b   2
	dc.b   1
	dc.b   1
	dc.b $60
	dc.b   0
	dc.b   1
	dc.b   1
	dc.b   2
	dc.b   2
	dc.b   1
	dc.b   1
	dc.b   0
	dc.b   0
	dc.b   1
	dc.b   1
	dc.b   2
	dc.b   2
	dc.b   1
	dc.b   1
	dc.b $FF
	dc.b   0
	dc.l unk_8308
; ---------------------------------------------------------------------------

loc_833E:
	bsr.w	ActorAnimate
	bcs.s	loc_836E
	move.b	9(a0),d0
	cmp.b	8(a0),d0
	bne.s	loc_8354
	rts
; ---------------------------------------------------------------------------

loc_8354:
	move.b	d0,8(a0)
	movea.l	$2E(a0),a1
	swap	d0
	move.w	#$8400,d0
	move.b	$2A(a1),d0
	swap	d0
	jmp	(QueuePlaneCmd).l
; ---------------------------------------------------------------------------

loc_836E:
	movea.l	$2E(a0),a1
	subq.w	#1,$26(a1)
	bra.w	ActorDeleteSelf
; ---------------------------------------------------------------------------
; TODO: Document Animation Code

unk_837A:
	dc.b   6
	dc.b   0
	dc.b   5
	dc.b   1
	dc.b   4
	dc.b   2
	dc.b   3
	dc.b   3
	dc.b   2
	dc.b   4
	dc.b $FE
	dc.b   0
; ---------------------------------------------------------------------------

loc_8386:
	bsr.w	ActorBookmark
	move.l	$E(a0),d0
	add.l	$16(a0),d0
	move.l	d0,$E(a0)
	swap	d0
	cmpi.w	#$D0,d0
	bcc.s	loc_83BA
	bsr.w	sub_3810
	move.w	$E(a0),d0
	lea	(vscroll_buffer).l,a2
	move.w	$32(a0),d1
	neg.w	d0
	move.w	d0,(a2,d1.w)
	rts
; ---------------------------------------------------------------------------

loc_83BA:
	bsr.w	sub_83D2
	bcc.s	loc_83C6
	bsr.w	sub_83F6

loc_83C6:
	movea.l	$2E(a0),a1
	subq.w	#1,$26(a1)
	bra.w	ActorDeleteSelf

; =============== S U B	R O U T	I N E =======================================


sub_83D2:
	movea.l	$2E(a0),a1
	clr.w	d0
	move.b	(level_mode).l,d0
	lsl.b	#1,d0
	or.b	$2A(a1),d0
	move.b	unk_83EC(pc,d0.w),d1
	subq.b	#1,d1
	rts
; End of function sub_83D2

; ---------------------------------------------------------------------------
unk_83EC:
	dc.b   0
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0

; =============== S U B	R O U T	I N E =======================================


sub_83F6:
	btst	#1,(level_mode).l
	beq.w	*+4

loc_8402:
	move.w	#3,d0

loc_8406:
	lea	(loc_8490).l,a1
	bsr.w	FindActorSlotQuick
	bcc.s	loc_8416
	rts
; ---------------------------------------------------------------------------

loc_8416:
	move.w	#$FFFF,$20(a1)
	move.w	$1A(a0),$1C(a1)
	move.w	#$FFFD,$16(a1)
	move.b	8(a0),8(a1)
	move.w	#$15F,$E(a1)
	move.b	unk_848C(pc,d0.w),9(a1)
	move.w	$A(a0),$1E(a1)
	move.b	$B(a0),$36(a1)
	move.w	d0,d1
	lsl.w	#2,d1
	addq.w	#1,d1
	move.w	d1,$26(a1)
	dbf	d0,loc_8406
	movea.l	a1,a2
	lea	(loc_84D6).l,a1
	bsr.w	FindActorSlotQuick
	bcc.s	loc_8466
	rts
; ---------------------------------------------------------------------------

loc_8466:
	move.b	#$FF,7(a2)
	move.l	a2,$2E(a1)
	move.b	#$80,6(a1)
	move.b	#6,8(a1)
	move.b	#$11,9(a1)
	move.l	#unk_84F4,$32(a1)
	rts
; End of function sub_83F6

; ---------------------------------------------------------------------------
unk_848C:
	dc.b   8
	dc.b   4
	dc.b   5
	dc.b   6
; ---------------------------------------------------------------------------

loc_8490:
	subq.w	#1,$26(a0)
	beq.s	loc_849A
	rts
; ---------------------------------------------------------------------------

loc_849A:
	move.b	#$85,6(a0)
	bsr.w	ActorBookmark
	bsr.w	sub_3810
	bcs.s	loc_84CA
	move.b	$36(a0),d0
	move.w	#$1000,d1
	jsr	(Sin).l
	swap	d2
	add.w	$1E(a0),d2
	move.w	d2,$A(a0)
	addq.b	#5,$36(a0)
	rts
; ---------------------------------------------------------------------------

loc_84CA:
	clr.b	7(a0)
	bsr.w	ActorBookmark
	bra.w	ActorDeleteSelf
; ---------------------------------------------------------------------------

loc_84D6:
	movea.l	$2E(a0),a1
	tst.b	7(a1)
	beq.w	ActorDeleteSelf
	bsr.w	ActorAnimate
	move.w	$A(a1),$A(a0)
	move.w	$E(a1),$E(a0)
	rts
; ---------------------------------------------------------------------------
; TODO: Document Animation Code

unk_84F4:
	dc.b   3
	dc.b $11
	dc.b   1
	dc.b $12
	dc.b   2
	dc.b $13
	dc.b   1
	dc.b $12
	dc.b $FF
	dc.b   0
	dc.l unk_84F4

; --------------------------------------------------------------
; Initialize sound
; --------------------------------------------------------------

InitSound:
	jsr	LoadCubeDriver
	jsr	InitSoundQueue
	move.b	d0,sound_playing
	rts

; --------------------------------------------------------------
; Load the Cube sound driver
; --------------------------------------------------------------

LoadCubeDriver:
	move.w	#$100,Z80_BUS
	move.w	#0,Z80_RESET
	rept	14
	nop
	endr
	move.w	#$100,Z80_RESET

.WaitStop:
	btst	#0,Z80_BUS
	bne.s	.WaitStop

	Z80_STOP
	move.w	#$100,Z80_RESET
	rept	14
	nop
	endr

	lea	CubeDriver,a0
	lea	ZRAM_START,a1
	move.w	#CubeDriver_End-CubeDriver-1,d7

.LoadDriver:
	move.b	(a0)+,(a1)+
	dbf	d7,.LoadDriver

	move.w	#0,Z80_RESET
	Z80_START
	move.w	#$100,Z80_RESET
	rept	14
	nop
	endr

	rts

; --------------------------------------------------------------
; Update sound
; --------------------------------------------------------------

UpdateSound:
	moveq	#0,d0
	move.b	(sound_playing).l,d0
	bne.s	.DoPlay
	jsr	(ProcessSoundQueue).l
	move.b	d0,(sound_playing).l
	beq.s	.End

.DoPlay:
	move.w	#$100,Z80_BUS

.StopZ80:
	nop
	nop
	nop
	nop
	btst	#0,Z80_BUS
	bne.s	.StopZ80
	move.b	ZRAM_START+$1FFF,d1
	bne.s	.Active
	move.b	d0,ZRAM_START+$1FFF
	move.b	unk_8660(pc,d0.w),d1
	beq.s	.NoSound
	move.b	d1,ZRAM_START+$1FFE

.NoSound:
	move.b	#0,(sound_playing).l

.Active:
	move.w	#0,Z80_BUS

.StartZ80:
	nop
	nop
	nop
	nop
	btst	#0,Z80_BUS
	beq.s	.StartZ80

.End:
	rts
; End of function UpdateSound

; ---------------------------------------------------------------------------
unk_8660:
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $97
	dc.b $97
	dc.b $97
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0

; --------------------------------------------------------------
; Play a sound
; --------------------------------------------------------------
; PARAMETERS:
;	d0.b	- Sound ID
; --------------------------------------------------------------

JmpTo_PlaySound:
	jmp	PlaySound

; --------------------------------------------------------------
; Play a sound (checks if PCM is enabled)
; --------------------------------------------------------------
; PARAMETERS:
;	d0.b	- Sound ID
; --------------------------------------------------------------

PlaySound_ChkPCM:
	tst.b	d0
	bpl.s	JmpTo_PlaySound_2
	tst.b	disable_samples
	beq.s	JmpTo_PlaySound_2

	move.b	d0,d1
	andi.w	#$7F,d1
	move.b	SamplesAllowed(pc,d1.w),d1
	beq.s	PlaySound_End

JmpTo_PlaySound_2:
	jmp	PlaySound

PlaySound_End:
	rts

; --------------------------------------------------------------

SamplesAllowed:
	dc.b	0
	dc.b	0
	dc.b	0
	dc.b	0
	dc.b	0
	dc.b	0
	dc.b	0
	dc.b	1
	dc.b	0
	dc.b	0
	dc.b	0
	dc.b	1
	dc.b	1
	dc.b	0
	dc.b	0
	dc.b	1
	dc.b	1
	dc.b	1
	dc.b	1
	dc.b	1
	dc.b	1
	dc.b	1
	dc.b	1
	dc.b	1
	dc.b	1
	dc.b	1
	dc.b	1
	dc.b	1
	dc.b	1
	dc.b	1
	dc.b	1
	dc.b	1

; --------------------------------------------------------------
; Fade out sound
; --------------------------------------------------------------

FadeSound:
	move.b	#$FD,sound_playing
	rts

; --------------------------------------------------------------
; Stop all sound
; --------------------------------------------------------------

StopSound:
	move.l	d0,-(sp)

	move.b	#SFX_STOP,d0
	jsr	PlaySound
	move.b	#BGM_STOP,d0
	jsr	PlaySound

	move.l	(sp)+,d0
	rts

; --------------------------------------------------------------
; Pause sound
; --------------------------------------------------------------

PauseSound:
	move.b	#$FF,sound_playing
	rts

; --------------------------------------------------------------
; Unpause sound
; --------------------------------------------------------------

UnpauseSound:
	move.b	#$FF,sound_playing
	rts

; --------------------------------------------------------------
; Stop sound effects
; --------------------------------------------------------------

StopSFX:
	move.b	#$6F,sound_playing
	rts

; --------------------------------------------------------------

	rts

; --------------------------------------------------------------
; Play a sound
; --------------------------------------------------------------
; PARAMETERS:
;	d0.b	- Sound ID
; --------------------------------------------------------------

PlaySound:
	movem.l	d0-d1/a0,-(sp)
	
	tst.b	sound_queue_open
	beq.s	.End

	moveq	#0,d1
	lea	sound_queue,a0
	move.b	sound_queue_tail,d1
	move.b	d0,(a0,d1.w)

	addq.b	#1,d1
	move.b	d1,sound_queue_tail
	cmp.b	sound_queue_current,d1
	bne.s	.NotFull
	move.b	#0,sound_queue_open

.NotFull:
	move.b	#-1,sounds_queued

.End:
	movem.l	(sp)+,d0-d1/a0
	rts

; --------------------------------------------------------------
; Process the sound queue
; --------------------------------------------------------------
; RETURNS:
;	d0.b	- Sound ID
; --------------------------------------------------------------

ProcessSoundQueue:
	movem.l	d1/a0,-(sp)
	
	tst.b	sounds_queued
	beq.s	.End

	moveq	#0,d1
	lea	sound_queue,a0
	move.b	sound_queue_current,d1
	move.b	(a0,d1.w),d0

	addq.b	#1,d1
	move.b	d1,sound_queue_current
	cmp.b	sound_queue_tail,d1
	bne.s	.NotEmpty
	move.b	#0,sounds_queued

.NotEmpty:
	move.b	#-1,sound_queue_open

.End:
	movem.l	(sp)+,d1/a0
	rts

; --------------------------------------------------------------
; Initialize the sound queue
; --------------------------------------------------------------

InitSoundQueue:
	moveq	#0,d0
	move.b	d0,sound_queue_tail
	move.b	d0,sound_queue_current
	move.b	#-1,sound_queue_open
	move.b	d0,sounds_queued

	lea	sound_queue,a0
	moveq	#$100/$10-1,d7

.Clear:
	move.l	d0,(a0)+
	move.l	d0,(a0)+
	move.l	d0,(a0)+
	move.l	d0,(a0)+
	dbf	d7,.Clear

	rts

; =============== S U B	R O U T	I N E =======================================


sub_88A8:
	move.b	(level_mode).l,d0
	eori.b	#2,d0
	or.b	$2B(a0),d0
	bne.w	locret_890C
	movea.l	$32(a0),a1
	tst.b	7(a1)
	bmi.w	locret_890C
	cmpi.w	#2,$1E(a1)
	bcs.w	locret_890C
	jsr	(GetPuyoField).l
	movea.l	a2,a3
	adda.l	#pUnk2,a2
	adda.l	#pUnk3,a3
	cmpi.w	#$36,8(a2)
	bcc.s	loc_890E
	move.w	#(PUYO_FIELD_COLS-1)*2,d0
	clr.b	d1

loc_88F4:
	cmpi.b	#3,(a3,d0.w)
	bcc.s	loc_8900
	addq.b	#1,d1

loc_8900:
	subq.w	#2,d0
	bcc.s	loc_88F4
	cmpi.b	#2,d1
	bcc.s	loc_890E

locret_890C:
	rts
; ---------------------------------------------------------------------------

loc_890E:
	tst.b	7(a1)
	bne.s	loc_8924
	jsr	(Random).l
	andi.b	#1,d0
	move.b	d0,7(a1)

loc_8924:
	move.b	#$19,d0
	addi.b	#$41,7(a1)
	btst	#0,7(a1)
	beq.s	loc_893C
	move.b	#$1A,d0

loc_893C:
	move.b	d0,$28(a1)
	move.b	d0,$29(a1)
	clr.w	$1E(a1)
	rts
; End of function sub_88A8


; =============== S U B	R O U T	I N E =======================================


sub_894A:
	movea.l	$2E(a0),a1
	move.l	a0,-(sp)
	movea.l	a1,a0
	jsr	(sub_9C4A).l
	move.l	(sp)+,a0
	rts
; End of function sub_894A

; ---------------------------------------------------------------------------
; START	OF FUNCTION CHUNK FOR sub_4E24

loc_8960:
	lea	(loc_89D8).l,a1
	bsr.w	FindActorSlot
	move.b	0(a0),0(a1)
	move.l	a0,$2E(a1)
	move.b	$2A(a0),$2A(a1)
	move.b	#$19,8(a1)
	move.b	#$45,9(a1)
	move.w	#2,$1A(a1)
	move.w	#1,$1C(a1)
	move.w	#0,$1E(a1)
	move.w	#0,$20(a1)
	move.l	#unk_89AE,$32(a1)
	ori.b	#1,7(a0)
	rts
; END OF FUNCTION CHUNK	FOR sub_4E24
; ---------------------------------------------------------------------------
; TODO: Document Animation Code

unk_89AE:
	dc.b   4
	dc.b   0
	dc.b   5
	dc.b   1
	dc.b   4
	dc.b   0
	dc.b   5
	dc.b   2
	dc.b $FF
	dc.b   0
	dc.l unk_89AE

unk_89BC:
	dc.b   4
	dc.b   3
	dc.b   5
	dc.b   4
	dc.b   4
	dc.b   3
	dc.b   5
	dc.b   5
	dc.b $FF
	dc.b   0
	dc.l unk_89BC

unk_89CA:
	dc.b   4
	dc.b   6
	dc.b   5
	dc.b   7
	dc.b   4
	dc.b   6
	dc.b   5
	dc.b   8
	dc.b $FF
	dc.b   0
	dc.l unk_89CA
; ---------------------------------------------------------------------------

loc_89D8:
	bsr.w	sub_543C
	move.b	#$80,6(a0)
	tst.b	(word_FF19A8).l
	bne.s	loc_8A1E
	move.b	$2A(a0),d0
	ori.b	#$80,d0
	move.b	d0,(word_FF19A8).l
	move.b	#$FF,(word_FF19A8+1).l
	bsr.w	ActorBookmark
	tst.b	(word_FF19A8+1).l
	beq.s	loc_8A12
	rts
; ---------------------------------------------------------------------------

loc_8A12:
	move.w	#$10,d0
	bsr.w	ActorBookmark_SetDelay
	bsr.w	ActorBookmark

loc_8A1E:
	bsr.w	ActorBookmark
	movea.l	$2E(a0),a1
	btst	#0,7(a1)
	beq.w	loc_4F3A
	bsr.w	ActorAnimate
	cmpi.w	#3,$1C(a0)
	bcc.s	loc_8A44
	move.b	#$45,9(a0)

loc_8A44:
	bsr.w	sub_5060
	bsr.w	sub_50DA
	bcs.s	loc_8A54
	bra.w	sub_543C
; ---------------------------------------------------------------------------

loc_8A54:
	move.b	#SFX_PUYO_LAND,d0
	bsr.w	PlaySound_ChkPCM
	bsr.w	GetPuyoField
	move.w	$1A(a0),d0
	addq.w	#1,$1C(a0)
	move.w	$1C(a0),d1
	cmpi.w	#PUYO_FIELD_ROWS,d1
	bcc.w	loc_8B64
	mulu.w	#PUYO_FIELD_COLS,d1
	add.w	d1,d0
	lsl.w	#1,d0
	move.w	d0,$26(a0)
	move.b	(a2,d0.w),d1
	andi.b	#$F0,d1
	cmpi.b	#$E0,d1
	bcs.s	loc_8A94
	move.b	#$80,d1

loc_8A94:
	move.b	d1,$36(a0)
	move.w	#1,$16(a0)

loc_8A9E:
	move.w	#$10,$28(a0)
	bsr.w	ActorBookmark
	move.b	$29(a0),d0
	andi.b	#3,d0
	bne.s	loc_8ABC
	move.b	#SFX_4B,d0
	bsr.w	PlaySound_ChkPCM

loc_8ABC:
	bsr.w	ActorAnimate
	move.w	$12(a0),d0
	add.w	d0,$A(a0)
	move.w	$16(a0),d0
	add.w	d0,$E(a0)
	subq.w	#1,$28(a0)
	beq.s	loc_8ADA
	rts
; ---------------------------------------------------------------------------

loc_8ADA:
	bsr.w	GetPuyoField
	move.w	$26(a0),d0
	move.b	$36(a0),(a2,d0.w)
	DISABLE_INTS
	bsr.w	sub_5782
	ENABLE_INTS
	bsr.w	sub_8C06
	bcc.s	loc_8A9E
	movea.l	$2E(a0),a1
	bclr	#0,7(a1)
	move.b	#$AF,6(a0)
	move.l	#unk_8B56,$32(a0)
	move.w	#3,$12(a0)
	move.w	#0,$16(a0)
	move.w	#$1A00,$1A(a0)
	move.w	#$800,$1C(a0)
	move.w	$A(a0),$1E(a0)
	move.w	#0,$20(a0)
	tst.b	$2A(a0)
	beq.s	loc_8B44
	move.w	#$FFFE,$12(a0)

loc_8B44:
	bsr.w	ActorBookmark
	bsr.w	ActorAnimate
	bsr.w	sub_3810
	bcs.w	loc_8BE8
	rts
; ---------------------------------------------------------------------------
; TODO: Document Animation Code

unk_8B56:
	dc.b   1
	dc.b  $D
	dc.b   1
	dc.b $24
	dc.b   1
	dc.b $26
	dc.b   1
	dc.b $25
	dc.b $FF
	dc.b   0
	dc.l unk_8B56
; ---------------------------------------------------------------------------

loc_8B64:
	move.b	#$82,6(a0)
	move.w	#$FFFF,$12(a0)
	move.l	#unk_8BDC,$32(a0)
	tst.b	$2A(a0)
	beq.s	loc_8B8E
	move.w	#1,$12(a0)
	move.l	#unk_8BD0,$32(a0)

loc_8B8E:
	movea.l	$2E(a0),a1
	bclr	#0,7(a1)
	move.l	#$2710,d0
	bsr.w	sub_894A
	bsr.w	ActorBookmark
	bsr.w	ActorAnimate
	cmpi.b	#$43,9(a0)
	bcc.s	loc_8BB6
	rts
; ---------------------------------------------------------------------------

loc_8BB6:
	move.w	$12(a0),d0
	add.w	d0,$A(a0)
	move.w	$A(a0),d0
	subi.w	#$78,d0
	cmpi.w	#$150,d0
	bcc.s	loc_8BE8
	rts
; ---------------------------------------------------------------------------
; TODO: Document Animation Code

unk_8BD0:
	dc.b   8
	dc.b $37
	dc.b   8
	dc.b $38
	dc.b   6
	dc.b $44
	dc.b $FF
	dc.b   0
	dc.l unk_8BD0

unk_8BDC:
	dc.b   8
	dc.b $3B
	dc.b   8
	dc.b $3C
	dc.b   8
	dc.b $43
	dc.b $FF
	dc.b   0
	dc.l unk_8BDC
; ---------------------------------------------------------------------------

loc_8BE8:
	move.b	$2A(a0),d0
	ori.b	#$80,d0
	cmp.b	(word_FF19A8).l,d0
	bne.w	ActorDeleteSelf
	move.b	#$FF,(word_FF19A8+1).l
	bra.w	ActorDeleteSelf

; =============== S U B	R O U T	I N E =======================================


sub_8C06:
	bsr.w	GetPuyoField
	lea	(unk_8CAE).l,a1
	eori.b	#$80,7(a0)
	bsr.w	Random
	andi.w	#1,d0
	bsr.w	sub_8C5C
	bcs.s	loc_8C28
	rts
; ---------------------------------------------------------------------------

loc_8C28:
	cmpi.w	#$D,$1C(a0)
	bcc.s	loc_8C56
	addq.w	#1,$1C(a0)
	addi.w	#$C,$26(a0)
	move.w	#0,$12(a0)
	move.w	#1,$16(a0)
	move.l	#unk_89AE,$32(a0)
	andi	#$FFFE,sr
	rts
; End of function sub_8C06

; ---------------------------------------------------------------------------
; START	OF FUNCTION CHUNK FOR sub_8C5C

loc_8C56:
	ori	#1,sr
	rts
; END OF FUNCTION CHUNK	FOR sub_8C5C

; =============== S U B	R O U T	I N E =======================================


sub_8C5C:

; FUNCTION CHUNK AT 00008C56 SIZE 00000006 BYTES

	move.w	d0,d1
	mulu.w	#$A,d1
	move.w	$1A(a0),d2
	add.w	(a1,d1.w),d2
	cmpi.w	#6,d2
	bcc.s	loc_8C56
	move.w	$26(a0),d3
	add.w	4(a1,d1.w),d3
	move.b	(a2,d3.w),d4
	bpl.s	loc_8C56
	andi.b	#$F0,d4
	cmp.b	$36(a0),d4
	beq.s	loc_8C56
	move.w	d2,$1A(a0)
	move.w	d3,$26(a0)
	move.w	(a1,d1.w),$12(a0)
	move.w	2(a1,d1.w),$16(a0)
	move.l	6(a1,d1.w),$32(a0)
	andi	#$FFFE,sr
	rts
; End of function sub_8C5C

; ---------------------------------------------------------------------------
	ori	#1,sr
	rts
; ---------------------------------------------------------------------------
unk_8CAE:
	dc.b $FF
	dc.b $FF
	dc.b   0
	dc.b   0
	dc.b $FF
	dc.b $FE
	dc.l unk_89BC
	dc.b   0
	dc.b   1
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   2
	dc.l unk_89CA
; ---------------------------------------------------------------------------
; START	OF FUNCTION CHUNK FOR sub_4E24

loc_8CC2:
	lea	(loc_8D18).l,a1
	bsr.w	FindActorSlot
	move.b	0(a0),0(a1)
	move.l	a0,$2E(a1)
	move.b	$2A(a0),$2A(a1)
	move.b	#$1A,8(a1)
	move.b	#3,9(a1)
	move.w	#2,$1A(a1)
	move.w	#1,$1C(a1)
	move.w	#0,$1E(a1)
	move.w	#0,$20(a1)
	move.b	#1,$2B(a1)
	move.l	#unk_8D16,$32(a1)
	ori.b	#1,7(a0)
	rts
; END OF FUNCTION CHUNK	FOR sub_4E24
; ---------------------------------------------------------------------------
unk_8D16:	dc.b $FE
	dc.b   0
; ---------------------------------------------------------------------------

loc_8D18:
	bsr.w	sub_543C
	addq.w	#8,$A(a0)
	move.b	#$80,6(a0)
	bsr.w	ActorBookmark
	movea.l	$2E(a0),a1
	btst	#0,7(a1)
	beq.w	loc_4F3A
	bsr.w	ActorAnimate
	cmpi.w	#3,$1C(a0)
	bcc.s	loc_8D54
	cmpi.b	#3,9(a0)
	bcc.s	loc_8D54
	addq.b	#3,9(a0)

loc_8D54:
	bsr.w	sub_5060
	bsr.w	sub_50DA
	bcs.s	loc_8D6A
	bsr.w	sub_543C
	addq.w	#8,$A(a0)
	rts
; ---------------------------------------------------------------------------

loc_8D6A:
	bsr.w	ActorBookmark
	bsr.w	ActorAnimate
	bcs.s	loc_8D90
	cmpi.w	#3,$1C(a0)
	bcc.s	locret_8D8E
	cmpi.b	#3,9(a0)
	bcc.s	locret_8D8E
	addq.b	#3,9(a0)

locret_8D8E:
	rts
; ---------------------------------------------------------------------------

loc_8D90:
	bsr.w	GetPuyoField
	move.w	$1A(a0),d0
	lsl.w	#1,d0
	clr.w	(a2,d0.w)
	clr.w	2(a2,d0.w)
	clr.w	$C(a2,d0.w)
	clr.w	$E(a2,d0.w)
	move.b	#0,9(a0)
	cmpi.w	#PUYO_FIELD_ROWS-1,$1C(a0)
	bcs.s	loc_8DC8
	move.l	#$2EE0,d0
	bsr.w	sub_894A
	bra.w	loc_8E40
; ---------------------------------------------------------------------------

loc_8DC8:
	move.w	$1A(a0),d0
	move.w	$1C(a0),d1
	addq.w	#1,d1
	mulu.w	#PUYO_FIELD_COLS,d1
	add.w	d1,d0
	lsl.w	#1,d0
	move.w	d0,$26(a0)
	move.w	$E(a0),$36(a0)
	clr.w	$1E(a0)
	move.b	#$85,6(a0)
	move.w	#$1A00,$1C(a0)
	move.w	#$FFFF,$20(a0)
	bsr.w	ActorBookmark
	bsr.w	sub_3810
	cmpi.w	#6,$16(a0)
	bcs.s	loc_8E14
	move.l	#$60000,$16(a0)

loc_8E14:
	bsr.w	sub_8EA4
	cmpi.w	#$148,$E(a0)
	bcc.s	loc_8E24
	rts
; ---------------------------------------------------------------------------

loc_8E24:
	move.w	#$148,$E(a0)
	move.l	#unk_8E92,$32(a0)
	move.w	#$80,$26(a0)
	move.b	#SFX_CANCEL,d0
	bsr.w	PlaySound_ChkPCM

loc_8E40:
	bsr.w	sub_8FDA
	move.b	#$B7,6(a0)
	neg.l	$16(a0)
	move.w	#$3400,$1C(a0)
	move.w	#$FFFF,$20(a0)
	move.w	#$8000,$14(a0)
	tst.b	$2A(a0)
	bne.s	loc_8E6C
	neg.l	$12(a0)

loc_8E6C:
	bsr.w	ActorBookmark
	bsr.w	ActorAnimate
	bsr.w	sub_3810
	cmpi.w	#$170,$E(a0)
	bcc.s	loc_8E84
	rts
; ---------------------------------------------------------------------------

loc_8E84:
	movea.l	$2E(a0),a1
	bclr	#0,7(a1)
	bra.w	ActorDeleteSelf
; ---------------------------------------------------------------------------
; TODO: Document Animation Code

unk_8E92:
	dc.b   2
	dc.b   1
	dc.b   1
	dc.b   0
	dc.b   3
	dc.b   2
	dc.b   1
	dc.b   0
	dc.b   3
	dc.b   1
	dc.b   1
	dc.b   0
	dc.b   2
	dc.b   2
	dc.b   1
	dc.b   0
	dc.b $FE
	dc.b   0

; =============== S U B	R O U T	I N E =======================================

sub_8EA4:
	move.w	$E(a0),d0
	sub.w	$36(a0),d0
	lsr.w	#4,d0
	cmp.w	$1E(a0),d0
	bne.s	loc_8EB8
	rts
; ---------------------------------------------------------------------------

loc_8EB8:
	move.w	d0,$1E(a0)
	bsr.w	GetPuyoField
	move.w	$26(a0),d0
	move.l	d0,-(sp)
	bsr.w	sub_8EF6
	move.l	(sp)+,d0
	move.w	#$FF,(a2,d0.w)
	move.w	#$FF,2(a2,d0.w)
	addi.w	#$C,$26(a0)
	DISABLE_INTS
	bsr.w	sub_5782
	ENABLE_INTS
	move.b	#SFX_4A,d0
	bra.w	PlaySound_ChkPCM
; End of function sub_8EA4

; =============== S U B	R O U T	I N E =======================================

sub_8EF6:
	move.w	#1,d1
	moveq	#0,d5
	clr.w	d6
	movea.l	$2E(a0),a1
	move.b	$2B(a1),d6
	addq.b	#1,d6
	mulu.w	#$A,d6

loc_8F0C:
	move.b	(a2,d0.w),d2
	bpl.w	loc_8F76
	lsr.b	#4,d2
	andi.b	#7,d2
	cmpi.b	#6,d2
	beq.s	loc_8F76
	move.w	#1,d4

loc_8F26:
	lea	(loc_8F92).l,a1
	bsr.w	FindActorSlotQuick
	bcs.s	loc_8F70
	move.b	0(a0),0(a1)
	move.b	#$83,6(a1)
	move.b	d2,8(a1)
	move.b	#4,9(a1)
	move.w	$A(a0),$A(a1)
	move.w	$E(a0),$E(a1)
	move.w	d1,d3
	eori.b	#1,d3
	lsl.w	#4,d3
	add.w	d3,$A(a1)
	move.w	#8,$28(a1)
	move.l	#unk_8F84,$32(a1)

loc_8F70:
	dbf	d4,loc_8F26
	add.l	d6,d5

loc_8F76:
	addq.w	#2,d0
	dbf	d1,loc_8F0C
	move.l	d5,d0
	bsr.w	sub_894A
	rts
; End of function sub_8EF6

; ---------------------------------------------------------------------------
; TODO: Document Animation Code

unk_8F84:
	dc.b   3
	dc.b   4
	dc.b   1
	dc.b   5
	dc.b   2
	dc.b   6
	dc.b   1
	dc.b   5
	dc.b $FF
	dc.b   0
	dc.l unk_8F84
; ---------------------------------------------------------------------------

loc_8F92:
	tst.w	$26(a0)
	bne.s	loc_8FCA
	tst.w	$28(a0)
	beq.w	ActorDeleteSelf
	subq.w	#1,$28(a0)
	move.w	$28(a0),d1
	addq.w	#1,d1
	lsl.w	#1,d1
	move.w	d1,$26(a0)
	jsr	(Random).w
	move.w	#$200,d1
	jsr	(Sin).w
	move.l	d2,$12(a0)
	jsr	(Cos).w
	move.l	d2,$16(a0)

loc_8FCA:
	subq.w	#1,$26(a0)
	bsr.w	sub_3810
	bcs.w	ActorDeleteSelf
	bra.w	ActorAnimate

; =============== S U B	R O U T	I N E =======================================

sub_8FDA:
	bsr.w	GetPuyoField
	move.w	d0,d1
	andi.w	#$7F,d1
	move.w	$1A(a0),d2
	mulu.w	#PUYO_FIELD_COLS*2,d2
	move.w	#PUYO_FIELD_COLS-1,d0

loc_8FF0:
	lea	(loc_9066).l,a1
	bsr.w	FindActorSlot
	bcs.s	loc_9020
	move.b	0(a0),0(a1)
	move.b	#$80,$36(a1)
	move.w	d1,$26(a1)
	move.w	unk_902A(pc,d2.w),d3
	move.w	$16(a0),d4
	lsl.w	#1,d4
	addq.w	#4,d4
	mulu.w	d4,d3
	move.w	d3,$38(a1)

loc_9020:
	addq.w	#4,d1
	addq.w	#2,d2
	dbf	d0,loc_8FF0
	rts
; End of function sub_8FDA

; ---------------------------------------------------------------------------
unk_902A:
	dc.b   1
	dc.b   0
	dc.b   1
	dc.b   0
	dc.b   0
	dc.b $80
	dc.b   0
	dc.b $40
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $80
	dc.b   1
	dc.b   0
	dc.b   1
	dc.b   0
	dc.b   0
	dc.b $80
	dc.b   0
	dc.b $40
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $40
	dc.b   0
	dc.b $80
	dc.b   1
	dc.b   0
	dc.b   1
	dc.b   0
	dc.b   0
	dc.b $80
	dc.b   0
	dc.b $40
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $40
	dc.b   0
	dc.b $80
	dc.b   1
	dc.b   0
	dc.b   1
	dc.b   0
	dc.b   0
	dc.b $80
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $40
	dc.b   0
	dc.b $80
	dc.b   1
	dc.b   0
	dc.b   1
	dc.b   0
; ---------------------------------------------------------------------------

loc_9066:
	move.b	$36(a0),d0
	ori.b	#$80,d0
	move.w	$38(a0),d1
	jsr	(Sin).w
	swap	d2
	lea	(vscroll_buffer).l,a1
	move.w	$26(a0),d0
	move.w	d2,(a1,d0.w)
	subq.b	#4,$36(a0)
	bcs.w	ActorDeleteSelf
	rts
; ---------------------------------------------------------------------------
	move.l	#$800E0000,d0
	jsr	(QueuePlaneCmd).l
	lea	(loc_90B0).l,a1
	jsr	(FindActorSlot).l
	move.w	#$258,$26(a1)
	rts
; ---------------------------------------------------------------------------

loc_90B0:
	subq.w	#1,$26(a0)
	bcs.s	loc_90BA
	rts
; ---------------------------------------------------------------------------

loc_90BA:
	clr.b	(bytecode_disabled).l
	jmp	(ActorDeleteSelf).l

; =============== S U B	R O U T	I N E =======================================

CheckPause:
	include "src/subroutines/check pause/check pause.asm"

PausePuyoField:
	include "src/subroutines/check pause/pause field.asm"

UnpausePuyoField:
	include "src/subroutines/check pause/unpause field.asm"

GetSavedPuyoField:
	include "src/subroutines/check pause/load saved field.asm"

ActPause:
	include "src/actors/pause.asm"

; =============== S U B	R O U T	I N E =======================================


sub_9308:
	move.b	#4,(level).l
	move.b	#OPP_ARMS,(opponent).l
	move.b	(game_matches).l,d0
	bne.s	loc_9324
	addq.b	#1,d0

loc_9324:
	move.b	d0,(byte_FF012A).l
	move.b	d0,(byte_FF012B).l
	rts
; End of function sub_9308


; =============== S U B	R O U T	I N E =======================================

sub_9332:
	cmpi.b	#2,(level_mode).l
	bne.s	locret_9374
	tst.w	$16(a0)
	beq.s	locret_9374
	bsr.w	GetPuyoField
	adda.l	#pUnk2,a2
	tst.w	8(a2)
	bne.s	locret_9374
	move.b	#SFX_PUYO_POP_1,d0
	bsr.w	PlaySound_ChkPCM
	moveq	#0,d0
	move.b	$2B(a0),d0
	addq.b	#1,d0
	mulu.w	#$1F4,d0
	addi.w	#$1F40,d0
	bsr.w	sub_9C4A

locret_9374:
	rts
; End of function sub_9332


; =============== S U B	R O U T	I N E =======================================


sub_9376:
	DISABLE_INTS
	move.w	#$C726,d5
	jsr	(SetVRAMWrite).l
	addi.w	#$80,d5
	move.w	#$C1FC,VDP_DATA
	move.w	#$C1FE,VDP_DATA
	jsr	(SetVRAMWrite).l
	move.w	#$C1FD,VDP_DATA
	move.w	#$C1FF,VDP_DATA
	ENABLE_INTS
	rts
; End of function sub_9376


; =============== S U B	R O U T	I N E =======================================


sub_93B4:
	moveq	#0,d0
	move.b	(byte_FF0128).l,d0
	divu.w	#$14,d0
	move.w	#$C61E,d5
	lea	(unk_947C).l,a1
	bsr.w	sub_943E
	swap	d0
	move.w	#$282,d4
	move.w	#$C91E,d5
	bsr.w	sub_9406
	moveq	#0,d0
	move.b	(byte_FF0129).l,d0
	divu.w	#$14,d0
	move.w	#$C628,d5
	lea	(unk_94AE).l,a1
	bsr.w	sub_943E
	swap	d0
	move.w	#$27E,d4
	move.w	#$C930,d5
	bsr.w	sub_9406
	rts
; End of function sub_93B4


; =============== S U B	R O U T	I N E =======================================


sub_9406:
	subq.w	#1,d0
	bcs.w	locret_943C
	move.w	#$832A,d6
	clr.b	d2

loc_9412:
	DISABLE_INTS
	jsr	(SetVRAMWrite).l
	subi.w	#$80,d5
	move.w	d6,VDP_DATA
	ENABLE_INTS
	addq.b	#1,d2
	cmpi.b	#5,d2
	bcs.s	loc_9438
	add.w	d4,d5
	clr.b	d2

loc_9438:
	dbf	d0,loc_9412

locret_943C:
	rts
; End of function sub_9406


; =============== S U B	R O U T	I N E =======================================


sub_943E:
	DISABLE_INTS
	move.l	d0,-(sp)
	mulu.w	#$A,d0
	adda.w	d0,a1
	move.w	#1,d0
	move.w	#$8000,d6

loc_9454:
	jsr	(SetVRAMWrite).l
	addi.w	#$80,d5
	move.w	#4,d1

loc_9462:
	move.b	(a1)+,d6
	move.w	d6,VDP_DATA
	dbf	d1,loc_9462
	dbf	d0,loc_9454
	ENABLE_INTS
	move.l	(sp)+,d0
	rts
; End of function sub_943E

; ---------------------------------------------------------------------------
unk_947C:
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $EF
	dc.b $F0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $F1
	dc.b $F2
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $F3
	dc.b $F4
	dc.b $F5
	dc.b   0
	dc.b   0
	dc.b $F6
	dc.b $F7
	dc.b $F8
	dc.b   0
	dc.b   0
	dc.b $F3
	dc.b $F9
	dc.b $FA
	dc.b $F0
	dc.b   0
	dc.b $F6
	dc.b $FB
	dc.b $FC
	dc.b $FD
	dc.b   0
	dc.b $F3
	dc.b $F9
	dc.b $F9
	dc.b $FA
	dc.b $F0
	dc.b $F6
	dc.b $FB
	dc.b $FB
	dc.b $FE
	dc.b $FF

unk_94AE:
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $EF
	dc.b $F0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $F1
	dc.b $F2
	dc.b   0
	dc.b   0
	dc.b $F3
	dc.b $F4
	dc.b $F5
	dc.b   0
	dc.b   0
	dc.b $F6
	dc.b $F7
	dc.b $F8
	dc.b   0
	dc.b $F3
	dc.b $F9
	dc.b $FA
	dc.b $F0
	dc.b   0
	dc.b $F6
	dc.b $FB
	dc.b $FC
	dc.b $FD
	dc.b $F3
	dc.b $F9
	dc.b $F9
	dc.b $FA
	dc.b $F0
	dc.b $F6
	dc.b $FB
	dc.b $FB
	dc.b $FE
	dc.b $FF

; =============== S U B	R O U T	I N E =======================================

sub_94E0:
	cmpi.b	#2,(level_mode).l
	beq.s	loc_94EE
	rts
; ---------------------------------------------------------------------------

loc_94EE:
	move.w	#$9300,d0
	move.b	$2A(a0),d0
	swap	d0
	move.w	$16(a0),d0
	jmp	(QueuePlaneCmd).l
; End of function sub_94E0


; =============== S U B	R O U T	I N E =======================================

sub_9502:
	cmpi.b	#2,(level_mode).l
	beq.s	loc_9510
	rts
; ---------------------------------------------------------------------------

loc_9510:
	lea	(sub_9572).l,a1
	jsr	(FindActorSlot).l
	bcc.s	loc_9522
	rts
; ---------------------------------------------------------------------------

loc_9522:
	move.w	#$80,$12(a1)
	move.w	#$8500,$E(a1)
	move.w	#$C620,$A(a1)
	tst.b	$2A(a0)
	beq.s	loc_9548
	move.w	#$A500,$E(a1)
	move.w	#$C62C,$A(a1)

loc_9548:
	moveq	#0,d0
	move.b	$2B(a0),d0
	addq.b	#1,d0
	divu.w	#$A,d0
	tst.b	d0
	beq.s	loc_955E
	addq.b	#1,d0
	lsl.b	#1,d0

loc_955E:
	move.b	d0,$17(a1)
	swap	d0
	addq.b	#1,d0
	lsl.b	#1,d0
	move.b	d0,$F(a1)
	move.w	d1,$26(a1)
	rts
; End of function sub_9502


; =============== S U B	R O U T	I N E =======================================

sub_9572:
	lea	(dword_95AC).l,a1
	tst.w	$26(a0)
	beq.s	loc_9590
	btst	#2,$27(a0)
	bne.s	loc_9590
	lea	(dword_95A8).l,a1

loc_9590:
	bsr.w	sub_9728
	subq.w	#1,$26(a0)
	beq.s	loc_95A2
	bcs.s	loc_95A2
	rts
; ---------------------------------------------------------------------------

loc_95A2:
	jmp	(ActorDeleteSelf).l
; End of function sub_9572

; ---------------------------------------------------------------------------
dword_95A8:	dc.l $1FEFF
dword_95AC:	dc.l $10000

; =============== S U B	R O U T	I N E =======================================

sub_95B0:
	lea	(loc_95FE).l,a1
	jsr	(FindActorSlot).l
	bcc.s	loc_95C2
	rts
; ---------------------------------------------------------------------------

loc_95C2:
	move.l	a0,$2E(a1)
	move.w	d4,$12(a1)
	move.w	d6,$E(a1)
	move.w	d5,$A(a1)
	rts
; End of function sub_95B0

; ---------------------------------------------------------------------------
	lea	(loc_95FE).l,a1
	jsr	(FindActorSlot).l
	bcc.s	loc_95E6
	rts
; ---------------------------------------------------------------------------

loc_95E6:
	move.l	a0,$2E(a1)
	move.w	d4,$12(a1)
	move.w	d6,$E(a1)
	move.w	d5,$A(a1)
	move.b	#$FF,7(a1)
	rts
; ---------------------------------------------------------------------------

loc_95FE:
	movea.l	$2E(a0),a1
	move.w	$28(a1),d0
	beq.s	loc_964C
	andi.b	#$3F,d0
	beq.s	loc_9614
	rts
; ---------------------------------------------------------------------------

loc_9614:
	moveq	#0,d0
	move.w	$28(a1),d0
	lsr.w	#6,d0
	divu.w	#$A,d0
	tst.b	d0
	beq.s	loc_962A
	addq.b	#1,d0
	lsl.b	#1,d0

loc_962A:
	move.b	d0,$17(a0)
	swap	d0
	addq.b	#1,d0
	lsl.b	#1,d0
	move.b	d0,$F(a0)
	lea	(byte_965C).l,a1
	bsr.w	sub_9728
	move.b	#SFX_DIALOGUE,d0
	jmp	(PlaySound_ChkPCM).l
; ---------------------------------------------------------------------------

loc_964C:
	lea	(byte_9664).l,a1
	bsr.w	sub_9728
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------
byte_965C:
	dc.b   0
	dc.b   5
	dc.b $3C
	dc.b $26
	dc.b $2E
	dc.b $1E
	dc.b $FE
	dc.b $FF

byte_9664:
	dc.b   0
	dc.b   5
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $32
	dc.b $3C
	dc.b   1
	dc.b   0
	dc.b $3C
	dc.b $3C
	dc.b $85
	dc.b   0
; ---------------------------------------------------------------------------
	lea	(loc_96C4).l,a1
	jsr	(FindActorSlot).l
	bcc.s	loc_9686
	rts
; ---------------------------------------------------------------------------

loc_9686:
	move.w	d1,$12(a1)
	move.w	d6,$E(a1)
	move.w	d5,$A(a1)
	moveq	#0,d0
	move.b	(level).l,d0
	cmpi.b	#3,d0
	bcs.s	loc_96A4
	subq.b	#3,d0

loc_96A4:
	addq.b	#1,d0
	divu.w	#$A,d0
	tst.b	d0
	beq.s	loc_96B4
	addq.b	#1,d0
	lsl.b	#1,d0

loc_96B4:
	move.b	d0,$17(a1)
	swap	d0
	addq.b	#1,d0
	lsl.b	#1,d0
	move.b	d0,$F(a1)
	rts
; ---------------------------------------------------------------------------

loc_96C4:
	cmpi.b	#$F,(level).l
	beq.s	loc_96F2
	lea	(byte_9706).l,a1
	cmpi.b	#3,(level).l
	bcc.s	loc_96E8
	lea	(byte_9710).l,a1

loc_96E8:
	bsr.w	sub_9728
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_96F2:
	subq.w	#4,$A(a0)
	lea	(byte_971A).l,a1
	bsr.w	sub_9728
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------
byte_9706:
	dc.b   0
	dc.b   7
	dc.b $3A
	dc.b $3C
	dc.b $16
	dc.b $22
	dc.b $1E
	dc.b   0
	dc.b $FE
	dc.b $FF

byte_9710:
	dc.b   0
	dc.b   7
	dc.b $2C
	dc.b $1E
	dc.b $3A
	dc.b $3A
	dc.b $32
	dc.b $30
	dc.b   0
	dc.b $FF

byte_971A:
	dc.b   0
	dc.b  $B
	dc.b $20
	dc.b $26
	dc.b $30
	dc.b $16
	dc.b $2C
	dc.b   0
	dc.b   0
	dc.b $3A
	dc.b $3C
	dc.b $16
	dc.b $22
	dc.b $1E

; =============== S U B	R O U T	I N E =======================================

sub_9728:
	move.w	(a1)+,d0
	move.w	$A(a0),d5
	move.w	$E(a0),d6
	clr.b	d1
	tst.b	7(a0)
	beq.s	loc_9740
	move.b	#$6A,d1

loc_9740:
	move.b	(a1)+,d6
	cmpi.b	#$FF,d6
	bne.s	loc_974E
	move.b	$F(a0),d6

loc_974E:
	cmpi.b	#$FE,d6
	bne.s	loc_975A
	move.b	$17(a0),d6

loc_975A:
	tst.b	d6
	beq.s	loc_9762
	add.b	d1,d6

loc_9762:
	DISABLE_INTS
	jsr	(SetVRAMWrite).l
	add.w	$12(a0),d5
	move.w	d6,VDP_DATA
	addq.b	#1,d6
	jsr	(SetVRAMWrite).l
	sub.w	$12(a0),d5
	addq.w	#2,d5
	move.w	d6,VDP_DATA
	ENABLE_INTS
	dbf	d0,loc_9740
	rts
; End of function sub_9728


; =============== S U B	R O U T	I N E =======================================


sub_9794:
	moveq	#0,d0
	move.b	(byte_FF0128).l,d0
	move.w	#$C320,d5
	move.w	#$A500,d6
	bsr.w	sub_97C8
	moveq	#0,d0
	move.b	(byte_FF0129).l,d0
	move.w	#$C32C,d5
	move.w	#$A500,d6
	bsr.w	sub_97C8
	move.l	#$800D0000,d0
	jmp	(QueuePlaneCmd).l
; End of function sub_9794


; =============== S U B	R O U T	I N E =======================================


sub_97C8:
	divu.w	#$A,d0
	tst.b	d0
	beq.s	loc_97D4
	addq.b	#1,d0

loc_97D4:
	addi.l	#$10000,d0
	lsl.l	#1,d0
	bsr.w	sub_97E2
	swap	d0
; End of function sub_97C8

; =============== S U B	R O U T	I N E =======================================

sub_97E2:
	move.b	d0,d6
	DISABLE_INTS
	jsr	(SetVRAMWrite).l
	addi.w	#$80,d5
	move.b	d0,d6
	move.w	d6,VDP_DATA
	addq.b	#1,d6
	jsr	(SetVRAMWrite).l
	subi.w	#$7E,d5
	move.w	d6,VDP_DATA
	ENABLE_INTS
	rts
; End of function sub_97E2

; ---------------------------------------------------------------------------
	rts

; =============== S U B	R O U T	I N E =======================================

sub_9814:
	btst	#1,(level_mode).l
	bne.w	locret_98B2
	lea	(byte_FF19B2).l,a1
	clr.w	d0
	move.b	$2A(a0),d0
	eori.b	#1,d0
	tst.b	(a1,d0.w)
	bne.w	locret_98B2
	moveq	#0,d0
	move.w	$14(a0),d0
	move.b	$2A(a0),d4
	eori.b	#1,d4
	bra.w	loc_9858
; ---------------------------------------------------------------------------

loc_984A:
	bsr.w	sub_99AA
	andi.l	#$FFFF,d0
	move.b	$2A(a0),d4

loc_9858:
	tst.w	(puyos_popping).l
	bne.w	locret_98B2
	lea	(byte_FF19B0).l,a2
	tst.b	d4
	beq.s	loc_9874
	lea	(byte_FF19B1).l,a2

loc_9874:
	addq.b	#1,(a2)
	move.w	#$180,d1
	move.w	#$150,d2
	move.w	#$10,d3
	move.b	(swap_controls).l,d5
	eor.b	d5,d4
	beq.s	loc_989A
	move.w	#$C0,d1
	move.w	#$E0,d2
	move.w	#$FFF0,d3

loc_989A:
	divu.w	#6,d0
	clr.w	d4
	bsr.w	sub_98B4
	swap	d0
	cmpi.w	#6,d4
	bcc.w	locret_98B2
	bsr.w	sub_98F2

locret_98B2:
	rts
; End of function sub_9814


; =============== S U B	R O U T	I N E =======================================

sub_98B4:
	tst.w	d0
	beq.w	locret_98F0
	lea	(sub_9962).l,a1
	jsr	(FindActorSlotQuick).l
	bcs.s	loc_98E6
	bsr.w	sub_992E
	subq.w	#1,d0
	move.b	#5,9(a1)
	cmpi.w	#4,d0
	bcs.s	loc_98E6
	move.b	#6,9(a1)
	subq.w	#4,d0

loc_98E6:
	add.w	d3,d2
	addq.w	#1,d4
	cmpi.w	#6,d4
	bcs.s	sub_98B4

locret_98F0:
	rts
; End of function sub_98B4

; =============== S U B	R O U T	I N E =======================================

sub_98F2:
	subq.b	#1,d0
	bcs.w	locret_9922
	lea	(sub_9962).l,a1
	jsr	(FindActorSlotQuick).l
	bcs.w	locret_9922
	bsr.w	sub_992E
	move.b	d0,9(a1)
	cmpi.w	#$C0,d1
	bne.w	locret_9922
	lsl.w	#1,d0
	move.w	unk_9924(pc,d0.w),d1
	add.w	d1,$A(a1)

locret_9922:
	rts
; End of function sub_98F2

; ---------------------------------------------------------------------------
unk_9924:
	dc.b   0
	dc.b   4
	dc.b $FF
	dc.b $F8
	dc.b $FF
	dc.b $EC
	dc.b $FF
	dc.b $E0
	dc.b $FF
	dc.b $D4

; =============== S U B	R O U T	I N E =======================================

sub_992E:
	move.b	#$A2,6(a1)
	move.b	#2,8(a1)
	move.w	d1,$A(a1)
	move.w	#$88,$E(a1)
	moveq	#0,d5
	move.w	d2,d5
	sub.w	d1,d5
	swap	d5
	asr.l	#4,d5
	move.l	d5,$12(a1)
	move.w	#$10,$26(a1)
	move.l	a2,$32(a1)
	move.b	(a2),$28(a1)
	rts
; End of function sub_992E

; =============== S U B	R O U T	I N E =======================================

sub_9962:
	tst.w	$26(a0)
	beq.s	loc_9974
	jsr	(sub_3810).l
	subq.w	#1,$26(a0)

loc_9974:
	movea.l	$32(a0),a1
	move.b	$28(a0),d0
	cmp.b	(a1),d0
	bne.s	loc_9984
	rts
; ---------------------------------------------------------------------------

loc_9984:
	jmp	(ActorDeleteSelf).l
; End of function sub_9962

; =============== S U B	R O U T	I N E =======================================

sub_998A:
	btst	#1,(level_mode).l
	beq.s	loc_9998
	rts
; ---------------------------------------------------------------------------

loc_9998:
	bsr.w	sub_99AA
	move.w	d0,$14(a1)
	clr.w	d0
	swap	d0
	move.l	d0,$E(a0)
	rts
; End of function sub_998A

; =============== S U B	R O U T	I N E =======================================

sub_99AA:
	lea	(unk_99F8).l,a1
	move.w	(time_seconds).l,d0
	move.w	(time_minutes).l,d1
	beq.s	loc_99CE
	cmpi.b	#1,(level_mode).l
	bne.s	loc_99CE
	subq.w	#1,d1

loc_99CE:
	cmpi.w	#9,d1
	bcs.s	loc_99DA
	move.w	#8,d1

loc_99DA:
	lsr.w	#4,d0
	lsl.w	#2,d1
	or.w	d1,d0
	lsl.w	#1,d0

	; In the arcade version of Puyo Puyo, garbage drops would get
	; more intense as time went on in a stage. This was dummied
	; out in the Mega Drive version.
	;move.w	(a1,d0.w),d1
	move.w	#$46,d1

	moveq	#0,d0
	move.w	$10(a0),d0
	divu.w	d1,d0
	movea.l	$2E(a0),a1
	add.w	$14(a1),d0
	rts
; End of function sub_99AA

; ---------------------------------------------------------------------------
unk_99F8:
	dc.w $46
	dc.w $46
	dc.w $46
	dc.w $46
	dc.w $46
	dc.w $46
	dc.w $2F
	dc.w $23
	dc.w $1C
	dc.w $17
	dc.w $14
	dc.w $12
	dc.w $10
	dc.w  $E
	dc.w  $D
	dc.w  $C
	dc.w  $B
	dc.w  $A
	dc.w   9
	dc.w   9
	dc.w   8
	dc.w   7
	dc.w   6
	dc.w   5
	dc.w   4
	dc.w   4
	dc.w   3
	dc.w   3
	dc.w   2
	dc.w   2
	dc.w   1
	dc.w   1
	dc.w   1
	dc.w   1
	dc.w   1
	dc.w   1

; =============== S U B	R O U T	I N E =======================================

sub_9A40:
	move.l	a0,d0
	swap	d0
	move.b	$2A(a0),d0
	addi.b	#-$7A,d0
	rol.w	#8,d0
	swap	d0
	jmp	(QueuePlaneCmd).l
; End of function sub_9A40

; =============== S U B	R O U T	I N E =======================================

sub_9A56:
	bsr.w	GetPuyoField
	adda.l	#pUnk6,a2
	bsr.w	sub_9B7E
	bsr.w	sub_94E0
	clr.w	d0
	btst	#1,(level_mode).l
	beq.s	loc_9A86
	move.b	$2B(a0),d0
	cmpi.b	#$62,d0
	bcs.s	loc_9A86
	move.b	#$63,d0

loc_9A86:
	addq.b	#1,d0
	mulu.w	#$A,d0
	mulu.w	d2,d0
	move.w	d0,$12(a0)
	swap	d0
	tst.w	d0
	beq.s	loc_9AA0
	move.w	#$FFFF,$12(a0)

loc_9AA0:
	clr.w	$1E(a0)
	bsr.w	sub_9AC2
	bsr.w	sub_9AEE
	bsr.w	sub_9B34
	cmpi.w	#$3E8,$1E(a0)
	bcs.w	locret_9AC0
	move.w	#$3E7,$1E(a0)

locret_9AC0:
	rts
; End of function sub_9A56

; =============== S U B	R O U T	I N E =======================================

sub_9AC2:
	clr.w	d0
	move.b	9(a0),d0
	cmpi.b	#9,d0
	bcs.s	loc_9AD2
	move.b	#8,d0

loc_9AD2:
	lsl.b	#1,d0
	move.w	unk_9ADC(pc,d0.w),$1E(a0)
	rts
; End of function sub_9AC2

; ---------------------------------------------------------------------------
unk_9ADC:
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   8
	dc.b   0
	dc.b $10
	dc.b   0
	dc.b $20
	dc.b   0
	dc.b $40
	dc.b   0
	dc.b $80
	dc.b   1
	dc.b   0
	dc.b   2
	dc.b   0
	dc.b   4
	dc.b   0

; =============== S U B	R O U T	I N E =======================================

sub_9AEE:
	move.w	$26(a0),d0
	subq.w	#1,d0
	clr.w	d1
	clr.b	d2
	clr.w	d3

loc_9AFA:
	move.b	1(a2,d1.w),d3
	lsr.b	#4,d3
	andi.b	#7,d3
	bset	d3,d2
	addq.w	#2,d1
	dbf	d0,loc_9AFA
	move.w	#5,d0
	clr.w	d1

loc_9B12:
	ror.b	#1,d2
	bcc.s	loc_9B18
	addq.b	#2,d1

loc_9B18:
	dbf	d0,loc_9B12
	move.w	unk_9B26(pc,d1.w),d0
	add.w	d0,$1E(a0)
	rts
; End of function sub_9AEE

; ---------------------------------------------------------------------------
unk_9B26:
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   3
	dc.b   0
	dc.b   6
	dc.b   0
	dc.b  $C
	dc.b   0
	dc.b $18
	dc.b   0
	dc.b $30

; =============== S U B	R O U T	I N E =======================================

sub_9B34:
	move.w	$26(a0),d0
	subq.w	#1,d0
	clr.w	d1
	clr.w	d2

loc_9B3E:
	move.b	(a2,d1.w),d2
	cmpi.b	#$C,d2
	bcs.s	loc_9B4C
	move.b	#$B,d2

loc_9B4C:
	lsl.b	#1,d2
	move.w	unk_9B66(pc,d2.w),d3
	add.w	d3,$1E(a0)
	bcc.s	loc_9B5E
	move.w	#$FFFF,$1E(a0)

loc_9B5E:
	addq.w	#2,d1
	dbf	d0,loc_9B3E
	rts
; End of function sub_9B34

; ---------------------------------------------------------------------------
unk_9B66:
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   2
	dc.b   0
	dc.b   3
	dc.b   0
	dc.b   4
	dc.b   0
	dc.b   5
	dc.b   0
	dc.b   6
	dc.b   0
	dc.b   7
	dc.b   0
	dc.b  $A

; =============== S U B	R O U T	I N E =======================================

sub_9B7E:
	move.w	$26(a0),d0
	subq.w	#1,d0
	clr.w	d1
	clr.w	d2
	clr.w	d3

loc_9B8A:
	move.b	(a2,d1.w),d3
	add.w	d3,d2
	addq.w	#2,d1
	dbf	d0,loc_9B8A
	add.w	d2,$16(a0)
	cmpi.w	#$2710,$16(a0)
	bcs.s	loc_9BAA
	move.w	#$270F,$16(a0)

loc_9BAA:
	add.w	d2,$18(a0)
	bcc.w	locret_9BB8
	move.w	#$FFFF,$18(a0)

locret_9BB8:
	rts
; End of function sub_9B7E

; =============== S U B	R O U T	I N E =======================================

sub_9BBA:
	moveq	#0,d0
	move.w	aField12(a0),d0
	move.w	aField1E(a0),d1
	beq.s	loc_9BCA
	mulu.w	d1,d0

loc_9BCA:
	bra.w	sub_9C64
; End of function sub_9BBA

; =============== S U B	R O U T	I N E =======================================

sub_9BCE:
	clr.w	d0
	move.b	(level_mode).l,d0
	andi.b	#3,d0
	lsl.w	#2,d0
	movea.l	off_9BE2(pc,d0.w),a1
	jmp	(a1)
; End of function sub_9BCE

; ---------------------------------------------------------------------------
off_9BE2:
	dc.l locret_9BF2
	dc.l loc_9BF4
	dc.l loc_9C0E
	dc.l loc_9C0E
; ---------------------------------------------------------------------------

locret_9BF2:
	rts
; ---------------------------------------------------------------------------

loc_9BF4:
	clr.w	d0
	move.b	$2B(a0),d0
	lsl.w	#1,d0
	move.w	unk_9C04(pc,d0.w),$14(a0)
	rts
; ---------------------------------------------------------------------------
unk_9C04:
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $12
	dc.b   0
	dc.b $1E
; ---------------------------------------------------------------------------

loc_9C0E:
	movea.l	$32(a0),a1
	clr.w	d1
	move.b	$2B(a0),d1
	lsl.b	#2,d1
	andi.b	#$38,d1
	move.w	word_9C36(pc,d1.w),$20(a1)
	move.b	word_9C38(pc,d1.w),7(a1)
	move.l	dword_9C32(pc,d1.w),d0
	bra.w	sub_9C4A
; ---------------------------------------------------------------------------
dword_9C32:	dc.l 0

word_9C36:	dc.w $FFFF

word_9C38:
	dc.w 0
	dc.l $9C40
	dc.w $28
	dc.w 0
	dc.l $15F90
	dc.w $24
	dc.w $100

; =============== S U B	R O U T	I N E =======================================

sub_9C4A:
	bsr.w	sub_9C64
; End of function sub_9C4A

; =============== S U B	R O U T	I N E =======================================

sub_9C4E:
	move.l	a0,d0
	swap	d0
	move.b	$2A(a0),d0
	addi.b	#$81,d0
	rol.w	#8,d0
	swap	d0
	jmp	(QueuePlaneCmd).l
; End of function sub_9C4E

; =============== S U B	R O U T	I N E =======================================

sub_9C64:
	add.l	d0,aY(a0)
	tst.w	aY(a0)
	beq.s	loc_9C7C
	move.w	#0,aY(a0)
	move.w	#$FFFF,$10(a0)

loc_9C7C:
	move.l	aX(a0),d1
	add.l	d0,d1
	bcc.s	loc_9C8C
	move.l	#$5F5E0FF,d1

loc_9C8C:
	cmpi.l	#$5F5E100,d1
	bcs.s	loc_9C9C
	move.l	#$5F5E0FF,d1

loc_9C9C:
	move.l	d1,aX(a0)
	rts
; End of function sub_9C64

; =============== S U B	R O U T	I N E =======================================

sub_9CA2:
	move.w	$18(a0),d0
	cmp.w	$1C(a0),d0
	bcc.s	loc_9CB0
	rts
; ---------------------------------------------------------------------------

loc_9CB0:
	clr.w	$18(a0)
	addq.b	#1,8(a0)
	move.b	8(a0),d0
	andi.b	#7,d0
	bne.s	loc_9CF0
	move.b	(level_mode).l,d0
	andi.b	#3,d0
	beq.s	loc_9CF8
	move.b	#SFX_RESULT_BONUS,d0
	bsr.w	PlaySound_ChkPCM
	cmpi.b	#$62,$2B(a0)
	bcc.s	loc_9CF4
	addq.b	#1,$2B(a0)
	move.w	#$80,d1
	bsr.w	sub_9502

loc_9CF0:
	bra.w	loc_9CF8
; ---------------------------------------------------------------------------

loc_9CF4:
	bra.w	*+4
; ---------------------------------------------------------------------------

loc_9CF8:
	move.b	(level_mode).l,d0
	andi.b	#3,d0
	beq.s	loc_9D12
	cmpi.b	#1,d0
	beq.s	loc_9D42
	bra.w	loc_9D78
; ---------------------------------------------------------------------------

loc_9D12:
	clr.w	d0
	move.b	8(a0),d0
	sub.b	(byte_FF0104).l,d0
	bcc.s	loc_9D24
	clr.b	d0

loc_9D24:
	move.l	a1,-(sp)
	lea	(unk_9DC4).l,a1
	lsl.w	#2,d0
	move.w	(a1,d0.w),$1A(a0)
	move.w	2(a1,d0.w),$1C(a0)
	move.l	(sp)+,a1
	rts
; ---------------------------------------------------------------------------

loc_9D42:
	clr.w	d0
	move.b	8(a0),d0
	andi.b	#7,d0
	movem.l	d1/a1,-(sp)
	clr.w	d1
	move.b	$2B(a0),d1
	lsl.b	#2,d1
	andi.b	#$18,d1
	or.b	d1,d0
	lea	(unk_9E24).l,a1
	lsl.w	#2,d0
	move.w	(a1,d0.w),$1A(a0)
	move.w	2(a1,d0.w),$1C(a0)
	movem.l	(sp)+,d1/a1
	rts
; ---------------------------------------------------------------------------

loc_9D78:
	clr.w	d0
	move.b	8(a0),d0
	andi.b	#7,d0
	movem.l	d1/a1,-(sp)
	clr.w	d1
	move.b	$2B(a0),d1
	cmpi.b	#$D,d1
	bcs.s	loc_9D98
	move.b	#$C,d1

loc_9D98:
	or.b	unk_9DB6(pc,d1.w),d0
	lea	(unk_9E7C).l,a1
	lsl.w	#2,d0
	move.w	(a1,d0.w),$1A(a0)
	move.w	2(a1,d0.w),$1C(a0)
	movem.l	(sp)+,d1/a1
	rts
; End of function sub_9CA2

; ---------------------------------------------------------------------------
unk_9DB6:
	dc.b $48
	dc.b $50
	dc.b   0
	dc.b   8
	dc.b $10
	dc.b $18
	dc.b $20
	dc.b $28
	dc.b $30
	dc.b $38
	dc.b $38
	dc.b $38
	dc.b $40
	dc.b   0

unk_9DC4:
	dc.b   4
	dc.b   0
	dc.b   0
	dc.b $20
	dc.b   4
	dc.b   0
	dc.b   0
	dc.b $20
	dc.b   5
	dc.b   0
	dc.b   0
	dc.b $20
	dc.b   5
	dc.b   0
	dc.b   0
	dc.b $20
	dc.b   6
	dc.b   0
	dc.b   0
	dc.b $20
	dc.b   8
	dc.b   0
	dc.b   0
	dc.b $20
	dc.b  $A
	dc.b   0
	dc.b   0
	dc.b $20
	dc.b  $C
	dc.b   0
	dc.b   0
	dc.b $28
	dc.b $10
	dc.b   0
	dc.b   0
	dc.b $28
	dc.b $20
	dc.b   0
	dc.b   0
	dc.b $30
	dc.b $30
	dc.b   0
	dc.b   0
	dc.b $30
	dc.b $40
	dc.b   0
	dc.b   0
	dc.b $38
	dc.b $48
	dc.b   0
	dc.b   0
	dc.b $38
	dc.b $50
	dc.b   0
	dc.b   0
	dc.b $40
	dc.b $60
	dc.b   0
	dc.b   0
	dc.b $40
	dc.b $80
	dc.b   0
	dc.b $FF
	dc.b $FF
	dc.b $80
	dc.b   0
	dc.b $FF
	dc.b $FF
	dc.b $80
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $80
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $80
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $A0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $C0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $E0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $FE
	dc.b   0
	dc.b $FF
	dc.b $FF

unk_9E24:
	dc.b $10
	dc.b   0
	dc.b   0
	dc.b $20
	dc.b $16
	dc.b   0
	dc.b   0
	dc.b $20
	dc.b $1A
	dc.b   0
	dc.b   0
	dc.b $20
	dc.b $20
	dc.b   0
	dc.b   0
	dc.b $20
	dc.b $25
	dc.b   0
	dc.b   0
	dc.b $20
	dc.b $30
	dc.b   0
	dc.b   0
	dc.b $20
	dc.b $34
	dc.b   0
	dc.b   0
	dc.b $20
	dc.b $40
	dc.b   0
	dc.b $FF
	dc.b $FF
	dc.b $20
	dc.b   0
	dc.b   0
	dc.b $20
	dc.b $25
	dc.b   0
	dc.b   0
	dc.b $20
	dc.b $30
	dc.b   0
	dc.b   0
	dc.b $20
	dc.b $34
	dc.b   0
	dc.b   0
	dc.b $20
	dc.b $40
	dc.b   0
	dc.b   0
	dc.b $20
	dc.b $60
	dc.b   0
	dc.b   0
	dc.b $20
	dc.b $80
	dc.b   0
	dc.b $FF
	dc.b $FF
	dc.b $20
	dc.b   0
	dc.b   0
	dc.b $10
	dc.b $25
	dc.b   0
	dc.b   0
	dc.b $10
	dc.b $30
	dc.b   0
	dc.b   0
	dc.b $10
	dc.b $34
	dc.b   0
	dc.b   0
	dc.b $10
	dc.b $40
	dc.b   0
	dc.b   0
	dc.b $10
	dc.b $60
	dc.b   0
	dc.b   0
	dc.b $10
	dc.b $80
	dc.b   0
	dc.b $FF
	dc.b $FF

unk_9E7C:
	dc.b $10
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $16
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $20
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $30
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $34
	dc.b   0
	dc.b   0
	dc.b   8
	dc.b $40
	dc.b   0
	dc.b   0
	dc.b   8
	dc.b $60
	dc.b   0
	dc.b   0
	dc.b   8
	dc.b $60
	dc.b   0
	dc.b   0
	dc.b   8
	dc.b $20
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $20
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $30
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $30
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $34
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $34
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $40
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $40
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $40
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $40
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $60
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $60
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $80
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $80
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $80
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $80
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $30
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $30
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $34
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $34
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $40
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $40
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $60
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $60
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $60
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $60
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $80
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $80
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $80
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $80
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $80
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $80
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $34
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $34
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $40
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $40
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $60
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $60
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $80
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $80
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $80
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $80
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $A0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $A0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $C0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $C0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $E0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $E0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $80
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $80
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $A0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $A0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $C0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $C0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $E0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $FE
	dc.b   0
	dc.b   0
	dc.b   8
	dc.b $FE
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $FE
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $FE
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $FE
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $FE
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $FE
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $FE
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $FE
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b   8
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b   8
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b  $B
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b  $B
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b  $B
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $10
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $10
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $10
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b  $B
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b  $B
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b  $B
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b  $C
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b  $C
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b  $D
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $10
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $10
	dc.b   0
	dc.b   0
	dc.b   4

ArtNem_GroupedStars:
	incbin	"resource/artnem/VS/Grouped Stars.nem"
	even

Intro_SpecAnim:	; Special Animation flags for intro cutscnes
	dc.l SpecIntro_CoconutHead		; Coconut's head flashing
	dc.l SpecIntro_GrounderMove		; Grounder moving around in circles
	dc.l SpecIntro_SkweelMove		; Skweel moving left and right
	dc.l SpecIntro_SpawnRobotsOpen		; Spawn Scratch & Grounder in game intro
	dc.l SpecIntro_RobotnikShip		; Spawn Robotnik in his ship
	dc.l SpecIntro_SirFfuzzyEyes		; Sir Ffuzzy-Logik's flashing eyes
	dc.l SpecIntro_VanishGrounder		; Grounder vanishing in game intro
	dc.l SpecIntro_VanishScratch		; Scratch vanishing in the intro
	dc.l SpecIntro_RobotnikLaugh		; Dr. Robotnik laughing
	dc.l SpecIntro_SpawnRobotsRobotnik	; Spawn Scratch & Grounder in Robotnik Intro
	dc.l SpecIntro_SirFFuzzyWind		; Leaves blowing in Sir Ffuzzy-Logik's stage

; =============== S U B	R O U T	I N E =======================================

SpecIntro_RobotnikLaugh:
	move.l	#Anim_RobotnikLaugh,aAnim(a0)
	move.b	#0,$22(a0)
	rts
; End of function SpecIntro_RobotnikLaugh

; ---------------------------------------------------------------------------

	include	"resource/anim/Intro/Opening Cutscene.asm"
	even

; =============== S U B	R O U T	I N E =======================================

SpecIntro_VanishGrounder:
	move.b	#VOI_VANISH,d0
	jsr	(PlaySound_ChkPCM).l
	lea	(loc_A212).l,a1
	bsr.w	FindActorSlot
	bcc.s	loc_A1DA
	rts

; ---------------------------------------------------------------------------

loc_A1DA:
	move.w	#$62,$26(a1)
	move.l	#misc_buffer_2,$32(a1)
	rts
; End of function SpecIntro_VanishGrounder

; =============== S U B	R O U T	I N E =======================================

SpecIntro_VanishScratch:
	move.b	#VOI_VANISH,d0
	jsr	(PlaySound_ChkPCM).l
	lea	(loc_A25C).l,a1
	bsr.w	FindActorSlot
	bcc.s	loc_A202
	rts
; ---------------------------------------------------------------------------

loc_A202:
	move.w	#$62,$26(a1)
	move.l	#misc_buffer_1,$32(a1)
	rts
; End of function SpecIntro_VanishScratch

; ---------------------------------------------------------------------------

loc_A212:
	move.w	$28(a0),d1
	cmpi.w	#$100,d1
	bne.s	loc_A222
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_A222:
	addi.w	#$10,$28(a0)
	bsr.w	sub_A2A6
	lea	(dma_queue).l,a0
	adda.w	(dma_slot).l,a0
	move.w	#$8F02,(a0)+
	move.l	#$94039310,(a0)+
	move.l	#$96B79510,(a0)+
	move.w	#$977F,(a0)+
	move.l	#$58200080,(a0)
	addi.w	#$10,(dma_slot).l
	rts
; ---------------------------------------------------------------------------

loc_A25C:
	move.w	$28(a0),d1
	cmpi.w	#$100,d1
	bne.s	loc_A26C
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_A26C:
	addi.w	#$10,$28(a0)
	bsr.w	sub_A2A6
	lea	(dma_queue).l,a0
	adda.w	(dma_slot).l,a0
	move.w	#$8F02,(a0)+
	move.l	#$94039310,(a0)+
	move.l	#$96B49500,(a0)+
	move.w	#$977F,(a0)+
	move.l	#$52000080,(a0)
	addi.w	#$10,(dma_slot).l
	rts

; =============== S U B	R O U T	I N E =======================================

sub_A2A6:
	move.w	$26(a0),d0
	movea.l	$32(a0),a1
	lea	(unk_B224).l,a2
	adda.w	d1,a2

loc_A2B6:
	movea.l	a2,a3
	moveq	#3,d2

loc_A2BA:
	move.l	(a3)+,d3
	and.l	d3,(a1)+
	dbf	d2,loc_A2BA
	dbf	d0,loc_A2B6
	rts
; End of function sub_A2A6

; =============== S U B	R O U T	I N E =======================================

SpecIntro_RobotnikShip:
	move.b	#VOI_EGGMOBILE,d0
	jsr	(PlaySound_ChkPCM).l
	lea	(sub_A316).l,a1
	bsr.w	FindActorSlot
	bcc.s	loc_A2E2
	rts
; ---------------------------------------------------------------------------

loc_A2E2:
	move.l	a0,$2E(a1)
	move.b	#$B3,6(a1)
	move.w	$A(a0),$A(a1)
	move.w	$E(a0),$E(a1)
	move.l	#$FFFE0000,$12(a1)
	move.l	#$50000,$16(a1)
	move.b	#$2B,8(a1)
	move.b	#$1E,9(a1)
	rts
; End of function SpecIntro_RobotnikShip

; =============== S U B	R O U T	I N E =======================================

sub_A316:
	move.w	#$C,d0
	bsr.w	ActorBookmark_SetDelay
	bsr.w	ActorBookmark
	movea.l	$2E(a0),a1
	tst.b	7(a1)
	beq.w	ActorDeleteSelf
	bsr.w	sub_3810
	move.l	$16(a0),d0
	subi.l	#$1270,d0
	bmi.s	loc_A342
	move.l	d0,$16(a0)

loc_A342:
	move.w	$E(a0),$E(a1)
	move.w	$A(a0),d0
	move.w	d0,$A(a1)
	cmpi.w	#$120,d0
	ble.s	loc_A358
	rts
; ---------------------------------------------------------------------------

loc_A358:
	move.w	#$101,(word_FF1990).l
	move.w	#8,d0
	bsr.w	ActorBookmark_SetDelay
	bsr.w	ActorBookmark
	lea	(sub_A404).l,a1
	bsr.w	FindActorSlot
	bcc.s	loc_A37A
	bra.s	loc_A3A4
; ---------------------------------------------------------------------------

loc_A37A:
	movea.l	$2E(a0),a2
	move.l	a2,$2E(a1)
	move.l	#$FFFEA000,$12(a1)
	move.l	#$FFFC0000,$16(a1)
	move.b	#$33,6(a1)
	move.w	$A(a0),$A(a1)
	move.w	$E(a0),$E(a1)

loc_A3A4:
	move.l	#$FFFE0000,$12(a0)
	move.l	#$FFFF8000,$16(a0)
	move.b	#$B3,6(a0)
	move.w	#$27,d0
	bsr.w	ActorBookmark_SetDelay
	bsr.w	ActorBookmark
	move.b	#VOI_EGGMOBILE_LEAVE,d0
	jsr	(PlaySound_ChkPCM).l
	bsr.w	ActorBookmark
	movea.l	$2E(a0),a1
	tst.b	7(a1)
	beq.w	ActorDeleteSelf
	jsr	(sub_3810).l
	move.l	$16(a0),d0
	subi.l	#$2000,d0
	move.l	d0,$16(a0)
	move.w	$A(a0),d0
	cmpi.w	#$A8,d0
	bge.s	locret_A402
	bra.w	ActorDeleteSelf
; ---------------------------------------------------------------------------

locret_A402:
	rts
; End of function sub_A316

; =============== S U B	R O U T	I N E =======================================

sub_A404:
	jsr	(sub_3810).l
	move.l	$16(a0),d0
	addi.l	#$2000,d0
	move.l	d0,$16(a0)
	move.w	$A(a0),d0
	cmpi.w	#$C0,d0
	bge.s	loc_A430
	move.b	#SFX_67,d0
	jsr	(PlaySound_ChkPCM).l
	bra.w	ActorDeleteSelf
; ---------------------------------------------------------------------------

loc_A430:
	movea.l	$2E(a0),a1
	move.w	$A(a0),$A(a1)
	move.w	$E(a0),$E(a1)
	rts
; End of function sub_A404

; ---------------------------------------------------------------------------

SpecIntro_SpawnRobotsOpen:
	lea	(JmpTo_ActorAnimate).l,a1
	bsr.w	FindActorSlot
	bcs.w	locret_A4B2
	move.l	a0,$2E(a1)
	move.w	#$138,$A(a1)
	move.w	#$F8,$E(a1)
	move.b	#$28,8(a1)
	move.b	#0,9(a1)
	move.b	#$80,6(a1)
	move.l	#Anim_OpeningScratch,$32(a1)
	lea	(JmpTo_ActorAnimate).l,a1
	bsr.w	FindActorSlot
	bcs.w	locret_A4B2
	move.l	a0,$2E(a1)
	move.w	#$168,$A(a1)
	move.w	#$118,$E(a1)
	move.b	#$28,8(a1)
	move.b	#2,9(a1)
	move.l	#Anim_OpeningGrounder,$32(a1)
	move.b	#$80,6(a1)

locret_A4B2:
	rts

; =============== S U B	R O U T	I N E =======================================

SpecIntro_SpawnRobotsRobotnik:
	lea	(JmpTo_ActorAnimate).l,a1
	bsr.w	FindActorSlot
	bcs.w	locret_A524
	move.l	a0,$2E(a1)
	move.w	#$140,$A(a1)
	move.w	#$20,$E(a1)
	move.b	#$28,8(a1)
	move.b	#0,9(a1)
	move.b	#$80,6(a1)
	move.l	#Anim_OpeningScratch,$32(a1)
	lea	(JmpTo_ActorAnimate).l,a1
	bsr.w	FindActorSlot
	bcs.w	locret_A524
	move.l	a0,$2E(a1)
	move.w	#$170,$A(a1)
	move.w	#$40,$E(a1)
	move.b	#$28,8(a1)
	move.b	#2,9(a1)
	move.l	#Anim_OpeningGrounder,$32(a1)
	move.b	#$80,6(a1)

locret_A524:
	rts
; End of function SpecIntro_SpawnRobotsRobotnik

; =============== S U B	R O U T	I N E =======================================

; Attributes: thunk

JmpTo_ActorAnimate:
	jmp	(ActorAnimate).l
; End of function JmpTo_ActorAnimate

; ---------------------------------------------------------------------------

SpecIntro_SkweelMove:
	lea	(loc_A560).l,a1
	bsr.w	FindActorSlot
	bcs.w	locret_A55E
	move.l	a0,$2E(a1)
	move.w	$A(a0),$1E(a1)
	move.w	$E(a0),$20(a1)

locret_A55E:
	rts
; ---------------------------------------------------------------------------

loc_A560:
	movea.l	$2E(a0),a1
	tst.b	7(a1)
	beq.w	ActorDeleteSelf
	move.b	$36(a0),d0
	move.w	#$1C00,d1
	jsr	(Sin).l
	swap	d2
	add.w	$1E(a0),d2
	move.w	d2,$A(a1)
	subq.b	#1,$36(a0)
	rts
; ---------------------------------------------------------------------------

SpecIntro_GrounderMove:
	lea	(loc_A5F6).l,a1
	bsr.w	FindActorSlot
	bcs.s	loc_A5F0
	move.l	a0,$2E(a1)
	move.w	$A(a0),$1E(a1)
	move.w	$E(a0),$20(a1)
	movea.l	a1,a2
	moveq	#2,d1

loc_A5AC:
	lea	(loc_A692).l,a1
	bsr.w	FindActorSlot
	bcs.s	loc_A5F0
	move.l	a0,$2E(a1)
	move.l	a2,$32(a1)
	move.w	$A(a0),$1E(a1)
	move.w	$E(a0),$20(a1)
	move.b	#$80,6(a1)
	move.b	#$E,8(a1)
	move.b	#$A,9(a1)
	move.b	d1,$28(a1)
	move.b	d1,d0
	lsl.b	#3,d0
	addi.b	#$10,d0
	move.b	d0,$36(a1)

loc_A5F0:
	dbf	d1,loc_A5AC
	rts
; ---------------------------------------------------------------------------

loc_A5F6:
	movea.l	$2E(a0),a1
	tst.b	7(a1)
	beq.w	ActorDeleteSelf
	cmpi.b	#$80,$36(a0)
	bne.s	loc_A642
	tst.b	$28(a0)
	beq.s	loc_A63A
	tst.b	(word_FF1990+1).l
	bne.s	loc_A632
	tst.b	$2A(a0)
	beq.s	locret_A630
	subq.b	#4,$36(a0)
	move.b	#0,$28(a0)
	move.b	#0,$2A(a0)

locret_A630:
	rts
; ---------------------------------------------------------------------------

loc_A632:
	move.b	#1,$2A(a0)
	rts
; ---------------------------------------------------------------------------

loc_A63A:
	move.b	#1,$28(a0)
	rts
; ---------------------------------------------------------------------------

loc_A642:
	move.b	$36(a0),d0
	move.w	#$3800,d1
	jsr	(Sin).l
	swap	d2
	add.w	$1E(a0),d2
	move.w	d2,$A(a1)
	move.b	$36(a0),d0
	lsr.b	#1,d0
	move.w	#$800,d1
	jsr	(Sin).l
	swap	d2
	add.w	$20(a0),d2
	move.w	d2,$E(a1)
	subq.b	#4,$36(a0)
	clr.w	d0
	move.b	$36(a0),d0
	lsr.b	#5,d0
	move.b	unk_A68A(pc,d0.w),d0
	move.b	d0,9(a1)
	rts
; ---------------------------------------------------------------------------
unk_A68A:
	dc.b   0
	dc.b   5
	dc.b   4
	dc.b   3
	dc.b   3
	dc.b   2
	dc.b   1
	dc.b   0
; ---------------------------------------------------------------------------

loc_A692:
	movea.l	$2E(a0),a1
	tst.b	7(a1)
	beq.w	ActorDeleteSelf
	movea.l	$32(a0),a1
	tst.b	$28(a1)
	beq.s	loc_A6AA
	rts
; ---------------------------------------------------------------------------

loc_A6AA:
	move.b	$36(a0),d0
	move.w	#$3800,d1
	jsr	(Sin).l
	swap	d2
	add.w	$1E(a0),d2
	move.w	d2,$A(a0)
	addi.w	#$10,$A(a0)
	move.b	$36(a0),d0
	lsr.b	#1,d0
	move.w	#$800,d1
	jsr	(Sin).l
	swap	d2
	add.w	$20(a0),d2
	move.w	d2,$E(a0)
	addi.w	#$20,$E(a0)
	subq.b	#4,$36(a0)
	addq.b	#1,$26(a0)
	move.b	$26(a0),d0
	andi.w	#3,d0
	lsl.w	#2,d0
	movea.l	off_A700(pc,d0.w),a2
	jmp	(a2)
; ---------------------------------------------------------------------------
off_A700:
	dc.l loc_A710
	dc.l loc_A718
	dc.l loc_A710
	dc.l loc_A730
; ---------------------------------------------------------------------------

loc_A710:
	move.b	#0,6(a0)
	rts
; ---------------------------------------------------------------------------

loc_A718:
	move.b	#$80,6(a0)
	move.b	$28(a0),d0
	move.b	unk_A72C(pc,d0.w),d0
	move.b	d0,9(a0)
	rts
; ---------------------------------------------------------------------------
unk_A72C:
	dc.b   8
	dc.b   9
	dc.b  $A
	dc.b   0
; ---------------------------------------------------------------------------

loc_A730:
	move.b	#$80,6(a0)
	move.b	$28(a0),d0
	move.b	unk_A744(pc,d0.w),d0
	move.b	d0,9(a0)
	rts
; ---------------------------------------------------------------------------
unk_A744:
	dc.b   8
	dc.b   8
	dc.b   9
	dc.b   0
; ---------------------------------------------------------------------------

SpecIntro_CoconutHead:
	lea	(loc_A758).l,a1
	bsr.w	FindActorSlot
	move.l	a0,$2E(a1)
	rts
; ---------------------------------------------------------------------------

loc_A758:
	movea.l	$2E(a0),a1
	tst.b	7(a1)
	beq.w	ActorDeleteSelf
	addq.b	#1,$26(a0)
	move.b	$26(a0),d0
	move.b	d0,d1
	andi.b	#7,d1
	bne.s	locret_A7AC
	andi.b	#8,d0
	beq.s	loc_A78C
	move.w	#$AEE,(palette_buffer+$74).l
	move.w	#$AEE,(palette_buffer+$78).l
	bra.s	loc_A79C
; ---------------------------------------------------------------------------

loc_A78C:
	move.w	#$6C,(palette_buffer+$74).l
	move.w	#$28E,(palette_buffer+$78).l

loc_A79C:
	move.b	#3,d0
	lea	((palette_buffer+$60)).l,a2
	jsr	(LoadPalette).l

locret_A7AC:
	rts

; =============== S U B	R O U T	I N E =======================================

SpecIntro_SirFfuzzyEyes:
	lea	(sub_A7C4).l,a1
	bsr.w	FindActorSlot
	move.l	a0,$2E(a1)
	move.b	#4,$26(a1)
	rts
; End of function SpecIntro_SirFfuzzyEyes

; =============== S U B	R O U T	I N E =======================================

sub_A7C4:
	movea.l	$2E(a0),a1
	tst.b	7(a1)
	beq.w	ActorDeleteSelf
	tst.b	$26(a0)
	beq.s	loc_A7DC
	subq.b	#1,$26(a0)
	rts
; ---------------------------------------------------------------------------

loc_A7DC:
	move.b	#4,$26(a0)
	move.w	$28(a0),d0
	addq.w	#1,d0
	cmpi.b	#$1B,d0
	bne.s	loc_A7F0
	moveq	#0,d0

loc_A7F0:
	move.w	d0,$28(a0)
	add.w	d0,d0
	move.w	word_A810(pc,d0.w),d1
	move.w	d1,(palette_buffer+$7C).l
	move.b	#3,d0
	lea	((palette_buffer+$60)).l,a2
	jmp	(LoadPalette).l
; End of function sub_A7C4

; ---------------------------------------------------------------------------
word_A810:
	dc.w $68
	dc.w $6A
	dc.w $8A
	dc.w $8C
	dc.w $AE
	dc.w $CE
	dc.w $EE
	dc.w $2EE
	dc.w $4EE
	dc.w $6EE
	dc.w $8EE
	dc.w $AEE
	dc.w $CEE
	dc.w $EEE
	dc.w $EEE
	dc.w $CEE
	dc.w $AEE
	dc.w $8EE
	dc.w $6EE
	dc.w $4EE
	dc.w $2EE
	dc.w $EE
	dc.w $CE
	dc.w $AE
	dc.w $8C
	dc.w $8A
	dc.w $6A

; =============== S U B	R O U T	I N E =======================================

SpecIntro_SirFFuzzyWind:
	lea	(sub_A85C).l,a1
	bsr.w	FindActorSlotQuick
	move.l	a0,$2E(a1)
	move.w	#4,$26(a1)
	rts
; End of function SpecIntro_SirFFuzzyWind

; =============== S U B	R O U T	I N E =======================================

sub_A85C:
	subq.w	#1,$26(a0)
	bpl.s	locret_A8E0
	lea	(sub_A8E2).l,a1
	jsr	(FindActorSlot).l
	bcs.s	loc_A8D0
	move.l	#Anim_BlowingLeaves,$32(a1)
	move.b	#$B3,6(a1)
	move.b	#$12,8(a1)
	move.b	#3,9(a1)
	move.w	#$1C0,$A(a1)
	jsr	(Random).l
	andi.w	#$3F,d0
	addi.w	#$38,d0
	move.w	d0,$E(a1)
	moveq	#0,d0
	jsr	(Random).l
	andi.w	#7,d0
	swap	d0
	asr.l	#1,d0
	addi.l	#$20000,d0
	neg.l	d0
	move.l	d0,$12(a1)
	move.w	#$400,$1C(a1)
	move.w	#$10,$20(a1)
	move.w	#$C0,$26(a1)

loc_A8D0:
	jsr	(Random).l
	andi.w	#7,d0
	addq.w	#7,d0
	move.w	d0,$26(a0)

locret_A8E0:
	rts
; End of function sub_A85C

; =============== S U B	R O U T	I N E =======================================

sub_A8E2:
	move.b	#$BF,6(a0)
	jsr	(sub_3810).l
	jsr	(ActorAnimate).l
	move.w	$A(a0),d0
	cmpi.w	#$60,d0
	bmi.s	loc_A904
	subq.w	#1,$26(a0)
	bpl.s	locret_A8E0

loc_A904:
	jmp	(ActorDeleteSelf).l
; End of function sub_A8E2

; =============== S U B	R O U T	I N E =======================================

LoadOpponentIntro:
	moveq	#0,d0
	move.b	(opponent).l,d0
	cmpi.b	#OPP_ARMS,d0
	bne.s	.ChkRobotnik
	lea	(ArtNem_ArmsIntro2).l,a0
	move.w	#$6000,d0
	DISABLE_INTS
	jsr	(NemDec).l
	ENABLE_INTS
	bra.s	.GetArtPtr
; ---------------------------------------------------------------------------

.ChkRobotnik:
	cmpi.b	#$C,d0
	bne.s	.GetArtPtr
	lea	(ArtNem_RobotnikShip).l,a0
	move.w	#$3000,d0
	bra.s	.DoArtLoad
; ---------------------------------------------------------------------------

.GetArtPtr:
	moveq	#0,d0
	move.b	(opponent).l,d0
	lsl.w	#2,d0
	lea	(OpponentIntroArt).l,a1
	movea.l	(a1,d0.w),a0
	move.w	#$8000,d0

.DoArtLoad:
	DISABLE_INTS
	jsr	(NemDec).l
	ENABLE_INTS
	move.b	#$FF,(word_FF1990).l
	move.b	#0,(word_FF1990+1).l
	clr.w	d0
	move.b	(opponent).l,d0
	move.b	d0,d1
	addi.b	#9,d1
	cmpi.b	#OPP_ROBOTNIK+9,d1
	bne.s	loc_A9B0
	move.b	#$2B,d1
	lea	(ActRobotnikIntro).l,a1
	bsr.w	FindActorSlot
	bcc.s	loc_A9C0
	rts
; ---------------------------------------------------------------------------

loc_A9B0:
	lea	(ActOpponentIntro).l,a1
	bsr.w	FindActorSlot
	bcc.s	loc_A9C0
	rts
; ---------------------------------------------------------------------------

loc_A9C0:
	move.b	#$FF,aField7(a1)
	move.b	d1,aMappings(a1)
	move.b	#$80,aDrawFlags(a1)
	lsl.w	#2,d0
	move.w	IntroSpritePos(pc,d0.w),aX(a1)
	move.w	IntroSpritePos+2(pc,d0.w),aY(a1)
	movea.l	a1,a2
	rts
; End of function LoadOpponentIntro

; ---------------------------------------------------------------------------
IntroSpritePos:
	dc.w $110, $40			; Skeleton Tea - Puyo Leftover
	dc.w  $F8, $28			; Frankly
	dc.w $100,   8			; Dynamight
	dc.w  $E8, $20			; Arms
	dc.w  $E8, $40			; Nasu Grave - Puyo Leftover
	dc.w $100, $30			; Grounder
	dc.w  $F0, $20			; Davy Sprocket
	dc.w $108, $38			; Coconuts
	dc.w $100, $20			; Spike
	dc.w $100, $20			; Sir Ffuzzy-Logik
	dc.w  $F8, $20			; Dragon Breath
	dc.w $110, $20			; Scratch
	dc.w $1C0,-$C8			; Dr. Robotnik
	dc.w $110, $20			; Mummy - Puyo Leftover
	dc.w  $F8, $30			; Humpty
	dc.w $100, $20			; Skweel
	dc.w  $D0, $20			; Opening

OpponentIntroArt:
	dc.l ArtNem_CoconutsIntro	; Skeleton Tea - Puyo Leftover
	dc.l ArtNem_FranklyIntro
	dc.l ArtNem_DynamightIntro
	dc.l ArtNem_ArmsIntro
	dc.l ArtNem_CoconutsIntro	; Nasu Grave - Puyo Leftover
	dc.l ArtNem_GrounderIntro
	dc.l ArtNem_DavyIntro
	dc.l ArtNem_CoconutsIntro
	dc.l ArtNem_SpikeIntro
	dc.l ArtNem_SirLogikIntro
	dc.l ArtNem_DragonIntro
	dc.l ArtNem_ScratchIntro
	dc.l ArtNem_CoconutsIntro	; Mummy - Puyo Leftover
	dc.l ArtNem_CoconutsIntro	; Dr. Robotnik
	dc.l ArtNem_HumptyIntro
	dc.l ArtNem_SkweelIntro
	dc.l ArtNem_CoconutsIntro	; Robotnik in the Intro

; =============== S U B	R O U T	I N E =======================================

ActOpponentIntro:
	tst.w	(vscroll_buffer).l
	beq.w	ActOpponentIntro_Done
	move.w	aX(a0),(word_FF1994).l
	tst.b	(word_FF1990).l
	beq.s	loc_AACA
	clr.b	(word_FF1990).l
	clr.w	d0
	move.b	(word_FF1990+1).l,d0
	bpl.w	loc_AAAA
	lea	(Intro_SpecAnim).l,a1
	andi.b	#$7F,d0
	lsl.w	#2,d0
	movea.l	(a1,d0.w),a2
	jmp	(a2)
; ---------------------------------------------------------------------------

loc_AAAA:
	clr.w	d1
	move.b	(opponent).l,d1
	lea	(off_AC48).l,a1
	lsl.w	#2,d1
	movea.l	(a1,d1.w),a2
	lsl.w	#2,d0
	move.l	(a2,d0.w),aAnim(a0)
	clr.w	aAnimTime(a0)

loc_AACA:
	bra.w	ActorAnimate
; ---------------------------------------------------------------------------

ActOpponentIntro_Done:
	clr.b	7(a0)
	bsr.w	ActorBookmark
	bra.w	ActorDeleteSelf
; End of function ActOpponentIntro


; =============== S U B	R O U T	I N E =======================================

ActRobotnikIntro:
	lea	(Robotnik_IntroAnims).l,a1
	move.l	(a1),aAnim(a0)
	jsr	(ActorBookmark).l
	tst.w	(vscroll_buffer).l
	beq.s	ActOpponentIntro_Done
	move.w	aX(a0),(word_FF1994).l
	tst.b	(word_FF1990).l
	beq.s	loc_AB42
	clr.b	(word_FF1990).l
	clr.w	d0
	move.b	(word_FF1990+1).l,d0
	bpl.w	loc_AB28
	lea	(Intro_SpecAnim).l,a1
	andi.b	#$7F,d0
	lsl.w	#2,d0
	movea.l	(a1,d0.w),a2
	jmp	(a2)
; ---------------------------------------------------------------------------

loc_AB28:
	clr.w	d1
	move.b	(opponent).l,d1
	lea	(Robotnik_IntroAnims).l,a2
	lsl.w	#2,d0
	move.l	(a2,d0.w),aAnim(a0)
	clr.w	aAnimTime(a0)

loc_AB42:
	tst.b	aAnimTime(a0)
	beq.s	loc_AB50
	subq.b	#1,aAnimTime(a0)
	rts
; ---------------------------------------------------------------------------

loc_AB50:
	movea.l	aAnim(a0),a2
	cmpi.b	#$FE,(a2)
	beq.w	locret_ABC6
	cmpi.b	#$FF,(a2)
	bne.s	loc_AB68
	movea.l	2(a2),a2

loc_AB68:
	move.b	(a2)+,aAnimTime(a0)
	move.b	(a2)+,d0
	move.b	d0,9(a0)
	move.l	a2,aAnim(a0)
	lsl.w	#2,d0
	move.l	off_ABC8(pc,d0.w),d0
	move.l	a0,-(sp)
	lea	(dma_queue).l,a0
	adda.w	(dma_slot).l,a0
	move.w	#$8F02,(a0)+
	move.l	#$94059380,(a0)+
	lsr.l	#1,d0
	move.l	d0,d1
	lsr.w	#8,d0
	swap	d0
	move.w	d1,d0
	andi.w	#$FF,d0
	addi.l	#$96009500,d0
	swap	d1
	andi.w	#$7F,d1
	addi.w	#$9700,d1
	move.l	d0,(a0)+
	move.w	d1,(a0)+
	move.l	#$60000080,(a0)
	addi.w	#$10,(dma_slot).l
	movea.l	(sp)+,a0

locret_ABC6:
	rts
; End of function ActRobotnikIntro

; ---------------------------------------------------------------------------
off_ABC8:
	dc.l ArtUnc_Robotnik_0
	dc.l ArtUnc_Robotnik_1
	dc.l ArtUnc_Robotnik_2
	dc.l ArtUnc_Robotnik_3
	dc.l ArtUnc_Robotnik_4
	dc.l ArtUnc_Robotnik_5
	dc.l ArtUnc_Robotnik_6
	dc.l ArtUnc_Robotnik_7
	dc.l ArtUnc_Robotnik_8
	dc.l ArtUnc_Robotnik_9
	dc.l ArtUnc_Robotnik_10
	dc.l ArtUnc_Robotnik_11
	dc.l ArtUnc_Robotnik_12
	dc.l ArtUnc_Robotnik_13
	dc.l ArtUnc_Robotnik_14
	dc.l ArtUnc_Robotnik_15
	dc.l ArtUnc_Robotnik_16
	dc.l ArtUnc_Robotnik_17
	dc.l ArtUnc_Robotnik_18
	dc.l ArtUnc_Robotnik_19
	dc.l ArtUnc_Robotnik_20
	dc.l ArtUnc_Robotnik_21
	dc.l ArtUnc_Robotnik_22
	dc.l ArtUnc_Robotnik_23
	dc.l ArtUnc_Robotnik_13
	dc.l ArtUnc_Robotnik_14
	dc.l ArtUnc_Robotnik_15
	dc.l ArtUnc_Robotnik_16
	dc.l ArtUnc_Robotnik_18
	dc.l ArtNem_RobotnikShip
	dc.l ArtNem_RobotnikShip
	dc.l ArtUnc_Robotnik_0

off_AC48:
	dc.l Coconuts_IntroAnims	; Skeleton Tea - Puyo Leftover
	dc.l Frankly_IntroAnims
	dc.l Dynamight_IntroAnims
	dc.l Arms_IntroAnims
	dc.l Coconuts_IntroAnims	; Nasu Grave - Puyo Leftover
	dc.l Grounder_IntroAnims
	dc.l Davy_IntroAnims
	dc.l Coconuts_IntroAnims
	dc.l Spike_IntroAnims
	dc.l SirFfuzzy_IntroAnims
	dc.l DragonBreath_IntroAnims
	dc.l Scratch_IntroAnims
	dc.l Robotnik_IntroAnims
	dc.l Coconuts_IntroAnims	; Mummy - Puyo Leftover
	dc.l Humpty_IntroAnims
	dc.l Skweel_IntroAnims
	dc.l Robotnik_IntroAnims	; Opening Cutscene

	include	"resource/anim/Intro/Arms.asm"
	even

	include	"resource/anim/Intro/Frankly.asm"
	even

	include	"resource/anim/Intro/Humpty.asm"
	even

	include	"resource/anim/Intro/Coconuts.asm"
	even

	include	"resource/anim/Intro/Davy Sprocket.asm"
	even

	include	"resource/anim/Intro/Skweel.asm"
	even

	include	"resource/anim/Intro/Dynamight.asm"
	even

	include	"resource/anim/Intro/Grounder.asm"
	even

	include	"resource/anim/Intro/Spike.asm"
	even

	include	"resource/anim/Intro/Sir Ffuzzy-Logik.asm"
	even

	include	"resource/anim/Intro/Dragon Breath.asm"
	even

	include	"resource/anim/Intro/Scratch.asm"
	even

	include	"resource/anim/Intro/Dr Robotnik.asm"
	even

; ---------------------------------------------------------------------------

SetupLevelTransition:
	lea	(ActLevelTransitionFG).l,a1
	bsr.w	FindActorSlot
	lea	(ActLevelTransitionBG).l,a1
	bsr.w	FindActorSlot
	move.w	#$FF20,(vscroll_buffer).l
	move.w	#$FF60,(vscroll_buffer+2).l
	move.w	#$FFFF,(level_transition_flag).l
	rts

; =============== S U B	R O U T	I N E =======================================

ActLevelTransitionFG:
	tst.w	(level_transition_flag).l
	beq.w	ActLevelTrans_FGScroll
	rts
; ---------------------------------------------------------------------------

ActLevelTrans_FGScroll:
	move.w	#$FF20,aY(a0)
	move.l	#$40000,aField16(a0)
	move.w	#$38,aField26(a0)
	bsr.w	ActorBookmark
	cmpi.b	#3,(level).l
	bcs.w	ActLevelTrans_FGStop
	move.l	aField16(a0),d0
	add.l	d0,aY(a0)
	move.w	aY(a0),d0
	move.w	d0,(vscroll_buffer).l
	subq.w	#1,aField26(a0)
	beq.w	ActLevelTrans_FGStop
	rts
; ---------------------------------------------------------------------------

ActLevelTrans_FGStop:
	move.w	#0,(vscroll_buffer).l
	move.b	#SFX_PUYO_LAND,d0
	jsr	(PlaySound_ChkPCM).l
	clr.b	(bytecode_disabled).l
	bra.w	ActorDeleteSelf
; End of function ActLevelTransitionFG

; =============== S U B	R O U T	I N E =======================================

ActLevelTransitionBG:
	tst.w	(level_transition_flag).l
	beq.w	ActLevelTrans_BGScroll
	rts
; ---------------------------------------------------------------------------

ActLevelTrans_BGScroll:
	move.w	#$FF60,aY(a0)
	move.l	#$2DB6D,aField16(a0)
	move.w	#$38,aField26(a0)
	bsr.w	ActorBookmark
	cmpi.b	#3,(level).l
	bcs.w	ActLevelTrans_BGStop
	move.l	aField16(a0),d0
	add.l	d0,aY(a0)
	move.w	aY(a0),d0
	move.w	d0,(vscroll_buffer+2).l
	subq.w	#1,aField26(a0)
	beq.w	ActLevelTrans_BGStop
	rts
; ---------------------------------------------------------------------------

ActLevelTrans_BGStop:
	move.w	#0,(vscroll_buffer+2).l
	move.w	#$8B00,d0
	move.b	(vdp_reg_b).l,d0
	andi.b	#$FC,d0
	move.b	d0,(vdp_reg_b).l
	clr.w	(hscroll_buffer+2).l
	bra.w	ActorDeleteSelf
; End of function ActLevelTransitionBG

; =============== S U B	R O U T	I N E =======================================

LoadLevelIntro:
	lea	(ActLevelIntro).l,a1
	bsr.w	FindActorSlot
	clr.w	d0
	clr.w	d1
	move.b	(level).l,d0
	move.b	LairAssetFlags(pc,d0.w),d1
	move.b	d1,(use_lair_assets).l
	move.b	d1,d2
	lsr.b	#1,d2
	move.b	d2,(bytecode_flag).l
	lsl.w	#2,d1
	movea.l	off_B0CE(pc,d1.w),a2
	jmp	(a2)
; End of function LoadLevelIntro

; ---------------------------------------------------------------------------
LairAssetFlags:
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 1
	dc.b 1
	dc.b 0

off_B0CE:
	dc.l loc_B0F4
	dc.l loc_B0F4
; ---------------------------------------------------------------------------

loc_B0D6:
	clr.w	d0
	clr.w	d1
	move.b	(level).l,d0
	move.b	LairAssetFlags(pc,d0.w),d1
	lsl.w	#2,d1
	movea.l	off_B0EC(pc,d1.w),a2
	jmp	(a2)
; ---------------------------------------------------------------------------
off_B0EC:
	dc.l loc_B102
	dc.l loc_B102
; ---------------------------------------------------------------------------

loc_B0F4:
	move.w	#0,d0
	jsr	(QueuePlaneCmdList).l
	bra.w	loc_B152
; ---------------------------------------------------------------------------

loc_B102:
	move.b	#1,d0
	move.b	#0,d1
	lea	(Palettes).l,a2
	adda.l	#(Pal_IntroSky1_Puyo-Palettes),a2
	jsr	(FadeToPalette).l
	moveq	#0,d0
	move.b	(opponent).l,d0
	move.b	OpponentIntroPals(pc,d0.w),d0
	lsl.w	#5,d0
	lea	(Palettes).l,a2
	adda.l	d0,a2
	move.b	#3,d0
	move.b	#0,d1
	jmp	(FadeToPalette).l
; ---------------------------------------------------------------------------
OpponentIntroPals:
	dc.b (Pal_CoconutsIntro-Palettes)>>5		; Skeleton Tea - Puyo Leftover
	dc.b (Pal_FranklyIntro-Palettes)>>5
	dc.b (Pal_DynamightIntro-Palettes)>>5
	dc.b (Pal_ArmsIntro-Palettes)>>5
	dc.b (Pal_CoconutsIntro-Palettes)>>5		; Nasu Grave - Puyo Leftover
	dc.b (Pal_GrounderIntro-Palettes)>>5
	dc.b (Pal_DavySprocketIntro-Palettes)>>5
	dc.b (Pal_CoconutsIntro-Palettes)>>5
	dc.b (Pal_SpikeIntro-Palettes)>>5
	dc.b (Pal_SirFfuzzyLogikIntro-Palettes)>>5
	dc.b (Pal_DragonBreathIntro-Palettes)>>5
	dc.b (Pal_ScratchIntro-Palettes)>>5
	dc.b (Pal_CoconutsIntro-Palettes)>>5		; Dr. Robotnik
	dc.b (Pal_CoconutsIntro-Palettes)>>5		; Mummy - Puyo Leftover
	dc.b (Pal_HumptyIntro-Palettes)>>5
	dc.b (Pal_SkweelIntro-Palettes)>>5
	dc.b (Pal_CoconutsIntro-Palettes)>>5		; Opening Cutscene
	dc.b (Pal_Black-Palettes)>>5
; ---------------------------------------------------------------------------

loc_B152:
	tst.b	(use_lair_assets).l
	bne.s	locret_B1AA
	move.b	#0,(word_FF1126).l
	move.w	#$8B00,d0
	move.b	(vdp_reg_b).l,d0
	ori.b	#3,d0
	move.b	d0,(vdp_reg_b).l
	lea	(loc_B1AC).l,a1
	bsr.w	FindActorSlot
	bcs.w	locret_B1AA
	move.l	a1,(dword_FF112C).l
	move.l	#-$10000,$E(a1)
	move.l	#-$C000,$16(a1)
	move.l	#-$8000,$1E(a1)
	move.l	#-$4000,$26(a1)

locret_B1AA:
	rts
; ---------------------------------------------------------------------------

loc_B1AC:
	tst.b	(word_FF1126).l
	beq.s	loc_B1B6
	rts
; ---------------------------------------------------------------------------

loc_B1B6:
	moveq	#$A,d0
	moveq	#4-1,d1

loc_B1BE:
	move.l	4(a0,d0.w),d2
	add.l	d2,(a0,d0.w)
	addq.w	#8,d0
	dbf	d1,loc_B1BE

	lea	(hscroll_buffer).l,a2
	move.w	#(88-1)*4,d0
	move.w	(vscroll_buffer+2).l,d1
	subi.w	#$FF60,d1
	cmpi.w	#$58,d1
	bhs.w	ActorDeleteSelf
	subq.w	#1,d1
	bcs.s	loc_B1F8

loc_B1EE:
	clr.l	(a2,d0.w)
	subq.w	#4,d0
	dbf	d1,loc_B1EE

loc_B1F8:
	clr.w	d1
	moveq	#$22,d2

loc_B1FE:
	clr.w	d3
	move.b	unk_B220(pc,d1.w),d3

loc_B204:
	clr.w	(a2,d0.w)
	move.w	(a0,d2.w),2(a2,d0.w)
	subq.w	#4,d0
	dbcs	d3,loc_B204	; if lower then 0, end loop prematurely...
	bcs.s	locret_B21E	; ...then branch
	addq.w	#1,d1
	subq.w	#8,d2
	bra.s	loc_B1FE
; ---------------------------------------------------------------------------

locret_B21E:
	rts
; ---------------------------------------------------------------------------
unk_B220:	; 88 loops before all of them end
	dc.b 8-1
	dc.b 8-1
	dc.b 32-1
	dc.b 256-1

unk_B224:
	dc.b  $F
	dc.b $FF
	dc.b  $F
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b  $F
	dc.b $FF
	dc.b  $F
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b  $F
	dc.b $FF
	dc.b  $F
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b  $F
	dc.b $FF
	dc.b  $F
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b $F0
	dc.b $FF
	dc.b $F0
	dc.b $FF
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b $F0
	dc.b $FF
	dc.b $F0
	dc.b $FF
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b $FF
	dc.b $F0
	dc.b $FF
	dc.b $F0
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b $F0
	dc.b $F0
	dc.b $F0
	dc.b $F0
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b $FF
	dc.b $F0
	dc.b $FF
	dc.b $F0
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b $F0
	dc.b $F0
	dc.b $F0
	dc.b $F0
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b $F0
	dc.b $F0
	dc.b $F0
	dc.b $F0
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b   0
	dc.b $F0
	dc.b   0
	dc.b $F0
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b $F0
	dc.b $F0
	dc.b $F0
	dc.b $F0
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b   0
	dc.b $F0
	dc.b   0
	dc.b $F0
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b $F0
	dc.b   0
	dc.b $F0
	dc.b   0
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b $F0
	dc.b   0
	dc.b $F0
	dc.b   0
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b  $F
	dc.b   0
	dc.b  $F
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b  $F
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b  $F
	dc.b   0
	dc.b  $F
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b  $F
	dc.b   0
	dc.b  $F
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b  $F
	dc.b   0
	dc.b  $F
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0

; =============== S U B	R O U T	I N E =======================================

LoadSegaLogo:
	include "src/subroutines/sega logo/sega logo.asm"
	
; ---------------------------------------------------------------------------

loc_B4B6:
	move.b	#$FF,7(a0)
	move.l	#credit_staff_roll,aAnim(a0)
	move.w	#$300,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark).l
	tst.w	aField26(a0)
	beq.s	loc_B4E2
	subq.w	#1,aField26(a0)
	rts
; ---------------------------------------------------------------------------

loc_B4E2:
	movea.l	aAnim(a0),a1
	move.w	(a1)+,d0
	beq.s	loc_B500
	bmi.w	loc_B54E
	add.w	d0,d0
	move.w	d0,aField26(a0)
	movea.l	(a1)+,a2
	move.l	a1,aAnim(a0)
	bra.w	loc_B570
; ---------------------------------------------------------------------------

loc_B500:
	move.b	#0,7(a0)
	move.w	#$BB8,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark).l
	move.w	#$3F,(dword_FF1130).l
	jsr	(FadeSound).l
	move.w	#$12C,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark).l
	move.w	#$FFFF,(word_FF1134).l
	clr.b	(bytecode_disabled).l
	clr.b	(bytecode_flag).l
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_B54E:
	moveq	#0,d0
	move.b	(difficulty).l,d0
	lsl.w	#2,d0
	move.l	Credit_EndMsgID(pc,d0.w),aAnim(a0)
	rts
; ---------------------------------------------------------------------------
Credit_EndMsgID:
	dc.l CreditEnd_Hardest
	dc.l CreditEnd_Hard
	dc.l CreditEnd_Normal
	dc.l CreditEnd_Easy
; ---------------------------------------------------------------------------

loc_B570:
	lea	(byte_FF143E).l,a1
	move.w	#7,d0

loc_B57A:
	tst.b	(a1,d0.w)
	beq.s	loc_B588
	dbf	d0,loc_B57A
	rts
; ---------------------------------------------------------------------------

loc_B588:
	move.b	#$FF,(a1,d0.w)
	lea	loc_B60E(pc),a1
	jsr	(FindActorSlot).l
	bcc.s	loc_B5A0
	rts
; ---------------------------------------------------------------------------

loc_B5A0:
	move.l	a0,$32(a1)
	move.b	#$91,6(a1)
	move.b	#7,8(a1)
	move.b	d0,9(a1)
	move.w	d0,$26(a1)
	move.w	(a2)+,$A(a1)
	move.w	#$160,$E(a1)
	move.l	#$FFFF8000,$16(a1)
	lea	(byte_11258).l,a4
	lea	(byte_FF1446).l,a3
	mulu.w	#$A2,d0
	adda.l	d0,a3
	move.w	(a2)+,d0
	move.w	d0,(a3)+
	subq.w	#1,d0
	clr.w	d1

loc_B5E4:
	moveq	#0,d2
	move.b	(a2)+,d2
	move.b	(a4,d2.w),d2
	bne.s	loc_B5F2
	addq.w	#8,d1
	bra.s	loc_B5E4
; ---------------------------------------------------------------------------

loc_B5F2:
	ori.w	#$8500,d2
	move.w	#$120,(a3)+
	move.b	#0,(a3)+
	move.b	#0,(a3)+
	move.w	d2,(a3)+
	move.w	d1,(a3)+
	addq.w	#8,d1
	dbf	d0,loc_B5E4
	rts
; ---------------------------------------------------------------------------

loc_B60E:
	movea.l	$32(a0),a1
	tst.b	7(a1)
	beq.s	loc_B640
	jsr	(sub_3810).l
	cmpi.w	#$70,$E(a0)
	bcs.s	loc_B62C
	rts
; ---------------------------------------------------------------------------

loc_B62C:
	lea	(byte_FF143E).l,a1
	move.w	$26(a0),d0
	clr.b	(a1,d0.w)
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_B640:
	jsr	(ActorBookmark).l
	rts
; ---------------------------------------------------------------------------

	include "resource/anim/Credits/Credits End.asm"
	even

; ---------------------------------------------------------------------------

	include "resource/anim/Credits/Staff Roll.asm"
	even

; ---------------------------------------------------------------------------

loc_BA3C:
	move.b	#2,d0
	move.b	#0,d1
	move.b	#2,d2
	lea	(Palettes).l,a2
	adda.l	#(Pal_MainMenuShadow-Palettes),a2
	jsr	(FadeToPal_StepCount).l
	lea	(sub_BADA).l,a1
	jsr	(FindActorSlot).l
	bcc.s	loc_BA6C
	rts
; ---------------------------------------------------------------------------

loc_BA6C:
	jsr	(sub_BAB2).l
	move.b	#$80,6(a1)
	move.b	#$40,8(a1)
	move.b	#$3E,9(a1)
	move.w	#$C0,$A(a1)
	move.w	#$D0,$E(a1)
	move.b	(byte_FF0105).l,$27(a1)
	move.w	#0,$2A(a1)
	move.l	#byte_BC02,$32(a1)
	bra.w	loc_BD98
; ---------------------------------------------------------------------------

loc_BAAA:
	moveq	#$C,d0
	jmp	(QueuePlaneCmdList).l

; =============== S U B	R O U T	I N E =======================================


sub_BAB2:
	move.w	$26(a0),d0
	addi.w	#$C,d0
	jmp	(QueuePlaneCmdList).l
; End of function sub_BAB2


; =============== S U B	R O U T	I N E =======================================


sub_BAC0:
	moveq	#$10,d0
	jmp	(QueuePlaneCmdList).l
; End of function sub_BAC0


; =============== S U B	R O U T	I N E =======================================


sub_BAC8:
	move.w	$26(a0),d0
	andi.w	#1,d0
	addi.w	#$10,d0
	jmp	(QueuePlaneCmdList).l
; End of function sub_BAC8


; =============== S U B	R O U T	I N E =======================================


sub_BADA:
	move.w	#$100,d4
	move.w	#$D61C,d5
	move.w	#$8500,d6
	move.w	#$280,$28(a0)
	bsr.s	sub_BAB2
	jsr	(ActorBookmark).l
	jsr	(nullsub_3).l
	bsr.w	sub_BB50
	jsr	(ActorAnimate).l
	jsr	(GetCtrlData).l
	move.b	d0,d1
	andi.b	#$F0,d0
	bne.s	loc_BB62
	btst	#0,d1
	bne.s	loc_BB26
	btst	#1,d1
	bne.s	loc_BB36
	rts
; ---------------------------------------------------------------------------

loc_BB26:
	tst.w	$26(a0)
	beq.s	loc_BB4C
	subq.w	#1,$26(a0)
	bra.w	loc_BB44
; ---------------------------------------------------------------------------

loc_BB36:
	cmpi.w	#3,$26(a0)
	bcc.s	loc_BB4C
	addq.w	#1,$26(a0)

loc_BB44:
	move.b	#SFX_MENU_MOVE,d0
	bsr.w	PlaySound_ChkPCM

loc_BB4C:
	bra.w	sub_BAB2
; End of function sub_BADA

; =============== S U B	R O U T	I N E =======================================

sub_BB50:
	move.w	$26(a0),d0
	mulu.w	#$18,d0
	addi.w	#$D0,d0
	move.w	d0,$E(a0)
	rts
; End of function sub_BB50

; ---------------------------------------------------------------------------
; START	OF FUNCTION CHUNK FOR sub_BADA

loc_BB62:
	bsr.w	sub_BCC2
	bcc.s	loc_BB7A
	jsr	(nullsub_3).l
	move.b	#SFX_67,d0
	jmp	(PlaySound_ChkPCM).l
; ---------------------------------------------------------------------------

loc_BB7A:
	jsr	(nullsub_3).l
	move.b	$27(a0),(byte_FF0105).l
	move.b	#SFX_MENU_SELECT,d0
	bsr.w	PlaySound_ChkPCM
	clr.w	$28(a0)
	jsr	(ActorBookmark).l
	jsr	(nullsub_3).l
	move.w	#$10,$28(a0)
	jsr	(ActorBookmark).l
	jsr	(nullsub_3).l
	move.w	$28(a0),d0
	ror.b	#2,d0
	andi.b	#$80,d0
	move.b	d0,6(a0)
	subq.w	#1,$28(a0)
	beq.s	loc_BBCA
	rts
; ---------------------------------------------------------------------------

loc_BBCA:
	move.w	$26(a0),d0
	move.b	LevelModes(pc,d0.w),d1
	move.b	d1,(level_mode).l
	move.b	d1,(bytecode_flag).l
	beq.w	loc_BDFE
	cmpi.b	#3,d1
	beq.s	loc_BBF0
	clr.b	(swap_controls).l

loc_BBF0:
	clr.b	(bytecode_disabled).l
	jmp	(ActorDeleteSelf).l
; END OF FUNCTION CHUNK	FOR sub_BADA
; ---------------------------------------------------------------------------
LevelModes:
	dc.b 0
	dc.b 1
	dc.b 2
	dc.b 3
	dc.b 4
	dc.b 0

; TODO: Document Animation Code
byte_BC02:
	dc.b   4
	dc.b $3E
	dc.b   4
	dc.b $3F
	dc.b   4
	dc.b $3E
	dc.b   4
	dc.b $40
	dc.b   8
	dc.b $3E
	dc.b   4
	dc.b $3F
	dc.b   4
	dc.b $3E
	dc.b   4
	dc.b $40
	dc.b $3C
	dc.b $3E
	dc.b   4
	dc.b $3E
	dc.b   4
	dc.b $3F
	dc.b   4
	dc.b $3E
	dc.b   4
	dc.b $40
	dc.b   8
	dc.b $3E
	dc.b   4
	dc.b $3F
	dc.b   4
	dc.b $3E
	dc.b   4
	dc.b $40
	dc.b $3C
	dc.b $3E
	dc.b   4
	dc.b $3E
	dc.b   2
	dc.b $41
	dc.b   4
	dc.b $3E
	dc.b   2
	dc.b $41
	dc.b $50
	dc.b $3E
	dc.b   4
	dc.b $3F
	dc.b   4
	dc.b $3E
	dc.b   4
	dc.b $40
	dc.b   8
	dc.b $3E
	dc.b   4
	dc.b $3F
	dc.b   4
	dc.b $3E
	dc.b   4
	dc.b $40
	dc.b $3C
	dc.b $3E
	dc.b   4
	dc.b $3E
	dc.b   2
	dc.b $41
	dc.b $50
	dc.b $3E
	dc.b   4
	dc.b $3F
	dc.b   4
	dc.b $3E
	dc.b   4
	dc.b $40
	dc.b   8
	dc.b $3E
	dc.b   4
	dc.b $3F
	dc.b   4
	dc.b $3E
	dc.b   4
	dc.b $40
	dc.b $3C
	dc.b $3E
	dc.b $FF
	dc.b   0
	dc.l byte_BC02

; =============== S U B	R O U T	I N E =======================================

nullsub_3:
	rts
; End of function nullsub_3

; ---------------------------------------------------------------------------
	move.w	$2A(a0),d0
	jsr	(sub_BC82).l
	move.w	d0,$2A(a0)
	lea	((palette_buffer+$60)).l,a2
	move.w	d1,$1A(a2)
	move.w	d1,$1C(a2)
	moveq	#3,d0
	jmp	(LoadPalette).l

; =============== S U B	R O U T	I N E =======================================

sub_BC82:
	addq.w	#1,d0
	cmpi.w	#$15,d0
	bmi.s	loc_BC8C
	moveq	#0,d0

loc_BC8C:
	move.w	d0,d1
	add.w	d1,d1
	move.w	unk_BC96(pc,d1.w),d1
	rts
; End of function sub_BC82

; ---------------------------------------------------------------------------
unk_BC96:	; Unused Palette Cycling
	dc.w  $EE0
	dc.w  $CE2
	dc.w  $AE4
	dc.w  $8E6
	dc.w  $6E8
	dc.w  $4EA
	dc.w  $2EC
	dc.w   $EE
	dc.w  $2CE
	dc.w  $4AE
	dc.w  $68E
	dc.w  $86E
	dc.w  $A4E
	dc.w  $C2E
	dc.w  $E0E
	dc.w  $E2C
	dc.w  $E4A
	dc.w  $E68
	dc.w  $E86
	dc.w  $EA4
	dc.w  $EC2
	dc.w $FFFF

; =============== S U B	R O U T	I N E =======================================


sub_BCC2:
	cmpi.w	#1,$26(a0)
	bne.s	loc_BCDC
	bsr.w	sub_BCE2
	tst.b	d0
	beq.s	loc_BCDC
	ori	#1,sr
	rts
; ---------------------------------------------------------------------------

loc_BCDC:
	andi	#$FFFE,sr
	rts
; End of function sub_BCC2

; =============== S U B	R O U T	I N E =======================================

sub_BCE2:
	DISABLE_INTS
	move.w	#$100,Z80_BUS

loc_BCEE:
	nop
	nop
	nop
	nop
	btst	#0,Z80_BUS
	bne.s	loc_BCEE
	bsr.w	sub_BD24
	move.w	#0,Z80_BUS

loc_BD0C:
	nop
	nop
	nop
	nop
	btst	#0,Z80_BUS
	beq.s	loc_BD0C
	ENABLE_INTS
	rts
; End of function sub_BCE2

; =============== S U B	R O U T	I N E =======================================

sub_BD24:
	lea	PORT_A_DATA,a1
	bsr.w	sub_BD44
	lea	PORT_B_DATA,a1
	move.l	d0,-(sp)
	bsr.w	sub_BD44
	move.l	(sp)+,d1
	or.b	d1,d0
	rts
; End of function sub_BD24

; =============== S U B	R O U T	I N E =======================================

sub_BD44:
	move.b	#0,(a1)
	nop
	nop
	move.b	(a1),d0
	andi.b	#$F,d0
	move.b	#$40,(a1)
	nop
	nop
	move.b	(a1),d1
	lsl.b	#4,d1
	andi.b	#$F0,d1
	or.b	d1,d0
	moveq	#0,d1
	move.w	#3,d2

loc_BD6A:
	lsl.b	#1,d1
	move.l	d0,-(sp)
	andi.b	#$C0,d0
	beq.s	loc_BD7C
	ori.b	#1,d1

loc_BD7C:
	move.l	(sp)+,d0
	lsl.b	#2,d0
	dbf	d2,loc_BD6A
	move.b	#0,d0
	cmpi.b	#$D,d1
	beq.s	locret_BD96
	move.b	#$FF,d0

locret_BD96:
	rts
; End of function sub_BD44

; ---------------------------------------------------------------------------

loc_BD98:
	lea	loc_BDA4(pc),a1
	jmp	(FindActorSlot).l
; ---------------------------------------------------------------------------

loc_BDA4:
	addq.w	#1,$26(a0)
	move.w	$26(a0),d1
	lea	((hscroll_buffer+2)).l,a1
	lea	word_BDF4(pc),a2

loc_BDB8:
	move.w	(a2)+,d0
	bmi.s	locret_BDC8

loc_BDBC:
	move.w	d1,(a1)+
	addq.w	#2,a1
	dbf	d0,loc_BDBC
	asr.w	#1,d1
	bra.s	loc_BDB8
; ---------------------------------------------------------------------------

locret_BDC8:
	rts

; =============== S U B	R O U T	I N E =======================================


sub_BDCA:
	movem.l	d0-a6,-(sp)
	move.w	#$80,d0
	moveq	#0,d1
	lea	((hscroll_buffer+2)).l,a2

loc_BDDA:
	move.w	d1,(a2)+
	addq.w	#2,a2
	dbf	d0,loc_BDDA
	movea.l	(dword_FF112C).l,a1
	jsr	(ActorDeleteOther).l
	movem.l	(sp)+,d0-a6
	rts
; End of function sub_BDCA

; ---------------------------------------------------------------------------
word_BDF4:
	dc.w $28
	dc.w $18
	dc.w $18
	dc.w $20
	dc.w $FFFF
; ---------------------------------------------------------------------------
; START	OF FUNCTION CHUNK FOR sub_BADA

loc_BDFE:
	move.b	#$80,6(a0)
	move.w	#$220,$A(a0)
	move.w	#$D8,$E(a0)
	move.b	#OPP_FRANKLY,(opponent).l
	move.w	#$28,$26(a0)
	jsr	(ActorBookmark).l
	move.w	#$B7,d0
	lea	((hscroll_buffer+$40)).l,a1

loc_BE2E:
	subq.w	#8,(a1)+
	addq.w	#2,a1
	dbf	d0,loc_BE2E
	subq.w	#8,$A(a0)
	subq.w	#1,$26(a0)
	beq.s	loc_BE44
	rts
; ---------------------------------------------------------------------------

loc_BE44:
	jsr	(ActorBookmark).l
	jsr	(ActorAnimate).l
	jsr	(GetCtrlData).l
	andi.b	#$F0,d0
	bne.s	loc_BEB4
	jsr	(GetCtrlData).l
	btst	#0,d0
	bne.s	loc_BE76
	btst	#1,d0
	bne.s	loc_BE8E
	rts
; ---------------------------------------------------------------------------

loc_BE76:
	tst.w	$26(a0)
	beq.w	locret_BEB2
	move.w	#0,$26(a0)
	move.w	#$D8,$E(a0)
	bra.w	loc_BEA2
; ---------------------------------------------------------------------------

loc_BE8E:
	tst.w	$26(a0)
	bne.w	locret_BEB2
	move.w	#1,$26(a0)
	move.w	#$F0,$E(a0)

loc_BEA2:
	jsr	(sub_BAC8).l
	move.b	#SFX_MENU_MOVE,d0
	bsr.w	PlaySound_ChkPCM
	bra.s	loc_BE44
; ---------------------------------------------------------------------------

locret_BEB2:
	rts
; ---------------------------------------------------------------------------

loc_BEB4:
	move.b	#SFX_MENU_SELECT,d0
	bsr.w	PlaySound_ChkPCM
	clr.w	$28(a0)
	jsr	(ActorBookmark).l
	move.w	#$10,$28(a0)
	jsr	(ActorBookmark).l
	move.w	$28(a0),d0
	ror.b	#2,d0
	andi.b	#$80,d0
	move.b	d0,6(a0)
	subq.w	#1,$28(a0)
	beq.s	loc_BEEA
	rts
; ---------------------------------------------------------------------------

loc_BEEA:
	move.b	#1,(byte_FF0114).l 
	move.b	(com_level).l,(difficulty).l
	move.b	#3,(level).l			; Which Stage to start on in Story.
	bsr.w	sub_DF74
	bsr.w	ClearOpponentDefeats
	move.w	$26(a0),d0
	lsl.w	#2,d0
	move.b	#0,(level_mode).l
	move.b	d0,(bytecode_flag).l
	clr.b	(bytecode_disabled).l
	jsr	(ActorBookmark).l
	rts
; END OF FUNCTION CHUNK	FOR sub_BADA

; =============== S U B	R O U T	I N E =======================================

ClearOpponentDefeats:
	lea	(opponents_defeated).l,a2
	move.w	#3,d0
	moveq	#0,d1

loc_BF3A:
	move.l	d1,(a2)+
	dbf	d0,loc_BF3A
	rts
; End of function ClearOpponentDefeats

; ---------------------------------------------------------------------------
	lea	(loc_BF6A).l,a1
	jsr	(FindActorSlot).l
	bcs.w	locret_BF68
	move.l	a0,$2E(a1)
	move.b	#6,8(a1)
	move.b	#4,9(a1)
	move.w	#$A0,$A(a1)

locret_BF68:
	rts
; ---------------------------------------------------------------------------

loc_BF6A:
	movea.l	$2E(a0),a1
	tst.w	$26(a1)
	beq.s	loc_BF7E
	move.b	#0,6(a0)
	rts
; ---------------------------------------------------------------------------

loc_BF7E:
	move.b	#$80,6(a0)
	move.b	$36(a0),d0
	ori.b	#$80,d0
	move.w	#$400,d1
	jsr	(Sin).l
	swap	d2
	addi.w	#$118,d2
	move.w	d2,$E(a0)
	addq.b	#6,$36(a0)
	rts

; =============== S U B	R O U T	I N E =======================================

sub_BFA6:
	lea	(loc_C00A).l,a1
	jsr	(FindActorSlot).l
	bcc.s	loc_BFB8
	rts
; ---------------------------------------------------------------------------

loc_BFB8:
	move.l	a0,$2E(a1)
	move.b	#3,7(a0)
	move.w	d0,$A(a1)
	move.b	$2A(a0),$2A(a1)
	move.w	#$780,$28(a1)
	movem.l	d0/a0,-(sp)
	movea.l	a1,a0
	move.w	#$80,d4
	clr.w	d0
	move.b	(swap_controls).l,d0
	lsl.b	#1,d0
	or.b	$2A(a0),d0
	lsl.w	#2,d0
	move.w	word_BFFA(pc,d0.w),d5
	move.w	word_BFFC(pc,d0.w),d6
	movem.l	(sp)+,d0/a0
	rts
; End of function sub_BFA6

; ---------------------------------------------------------------------------
word_BFFA:	dc.w $CC0A

word_BFFC:
	dc.w $8500
	dc.w $CC3A
	dc.w $A500
	dc.w $CC3A
	dc.w $8500
	dc.w $CC0A
	dc.w $A500
; ---------------------------------------------------------------------------

loc_C00A:
	bsr.w	GetPuyoField
	move.w	d0,d5
	addi.w	#$606,d5
	lea	(unk_C156).l,a1
	bsr.w	sub_C1D0
	move.b	$B(a0),d0
	addi.b	#$21,d0
	bsr.w	sub_C1E8
	bsr.w	GetPuyoField
	move.w	d0,d5
	addi.w	#$702,d5
	lea	(unk_C15C).l,a1
	bsr.w	sub_C1D0
	move.b	#0,d0
	bsr.w	PlaySound_ChkPCM
	jsr	(ActorBookmark).l
	move.w	#4,d0

loc_C050:
	move.b	#1,$12(a0,d0.w)
	dbf	d0,loc_C050
	jsr	(ActorBookmark).l
	clr.b	d0
	bsr.w	sub_C168
	addq.b	#1,$26(a0)
	bsr.w	sub_56C0
	btst	#2,d0
	bne.s	loc_C0E2
	andi.b	#$70,d0
	bne.s	loc_C0CA
	btst	#1,d1
	bne.s	loc_C090
	btst	#0,d1
	bne.s	loc_C0AC
	rts
; ---------------------------------------------------------------------------

loc_C090:
	move.w	$E(a0),d0
	addq.b	#1,$12(a0,d0.w)
	cmpi.b	#$1B,$12(a0,d0.w)
	bcs.s	loc_C0BE
	move.b	#0,$12(a0,d0.w)
	bra.w	loc_C0BE
; ---------------------------------------------------------------------------

loc_C0AC:
	move.w	$E(a0),d0
	subq.b	#1,$12(a0,d0.w)
	bpl.w	loc_C0BE
	move.b	#$1A,$12(a0,d0.w)

loc_C0BE:
	clr.b	$26(a0)
	move.b	#SFX_MENU_MOVE,d0
	bra.w	PlaySound_ChkPCM
; ---------------------------------------------------------------------------

loc_C0CA:
	addq.w	#1,$E(a0)
	move.b	#SFX_MENU_SELECT,d0
	bsr.w	PlaySound_ChkPCM
	cmpi.w	#3,$E(a0)
	bcc.s	loc_C0F8
	rts
; ---------------------------------------------------------------------------

loc_C0E2:
	tst.w	$E(a0)
	bne.s	loc_C0EC
	rts
; ---------------------------------------------------------------------------

loc_C0EC:
	subq.w	#1,$E(a0)
	move.b	#SFX_MENU_MOVE,d0
	bra.w	PlaySound_ChkPCM
; ---------------------------------------------------------------------------

loc_C0F8:
	move.w	$A(a0),d0
	bsr.w	GetHighScoreEntry
	movea.l	$2E(a0),a2

loc_C104:
	move.l	6(a1),d1
	cmp.l	$A(a2),d1
	beq.s	loc_C126
	adda.l	#$10,a1
	addq.w	#1,$A(a0)
	cmpi.w	#5,$A(a0)
	bcs.s	loc_C104
	bra.w	loc_C12A
; ---------------------------------------------------------------------------

loc_C126:
	bsr.w	sub_C420

loc_C12A:
	clr.w	$28(a0)
	move.w	#$20,d0
	jsr	(ActorBookmark_SetDelay).l
	move.b	$25(a0),d0
	bsr.w	sub_C168
	jsr	(ActorBookmark).l
	movea.l	$2E(a0),a1
	bclr	#1,7(a1)
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------
unk_C156:
	dc.b $12
	dc.b   1
	dc.b  $E
	dc.b  $B
	dc.b   0
	dc.b $FF

unk_C15C:
	dc.b $19
	dc.b  $F
	dc.b $15
	dc.b $12
	dc.b   0
	dc.b  $E
	dc.b   1
	dc.b  $D
	dc.b   5
	dc.b $1B
	dc.b $FF
	dc.b   0

; =============== S U B	R O U T	I N E =======================================

sub_C168:
	move.l	d0,-(sp)
	bsr.w	GetPuyoField
	move.w	d0,d5
	addi.w	#$888,d5
	move.l	(sp)+,d2
	clr.w	d1

loc_C17C:
	move.b	$12(a0,d1.w),d0
	bsr.w	sub_C1A8
	btst	#0,d2
	beq.s	loc_C18E
	clr.b	d0

loc_C18E:
	movem.l	d1-d2,-(sp)
	bsr.w	sub_C1E8
	movem.l	(sp)+,d1-d2
	subi.w	#$7E,d5
	addq.w	#1,d1
	cmpi.w	#3,d1
	bcs.s	loc_C17C
	rts
; End of function sub_C168

; =============== S U B	R O U T	I N E =======================================

sub_C1A8:
	cmp.w	$E(a0),d1
	bcc.s	loc_C1B2
	rts
; ---------------------------------------------------------------------------

loc_C1B2:
	beq.s	loc_C1BC
	move.b	#$1C,d0
	rts
; ---------------------------------------------------------------------------

loc_C1BC:
	move.b	$26(a0),d3
	lsr.b	#3,d3
	andi.b	#1,d3
	eori.b	#1,d3
	neg.b	d3
	and.b	d3,d0
	rts
; End of function sub_C1A8

; =============== S U B	R O U T	I N E =======================================

sub_C1D0:
	move.b	(a1)+,d0
	bmi.s	locret_C1E6
	move.l	d5,-(sp)
	bsr.w	sub_C1E8
	move.l	(sp)+,d5
	addq.w	#2,d5
	bra.s	sub_C1D0
; ---------------------------------------------------------------------------

locret_C1E6:
	rts
; End of function sub_C1D0

; =============== S U B	R O U T	I N E =======================================

sub_C1E8:
	move.w	#$C500,d1
	move.w	d1,d2
	tst.b	d0
	beq.s	loc_C204
	addi.b	#$3F,d0
	cmpi.b	#$5F,d0
	bcs.s	loc_C204
	subi.b	#$29,d0

loc_C204:
	lsl.b	#1,d0
	move.b	d0,d1
	move.b	d0,d2
	addq.b	#1,d2
	cmpi.b	#$B6,d1
	bne.s	loc_C226
	move.b	d1,d2
	clr.b	d1
	move.b	(frame_count+1).l,d0
	lsr.b	#3,d0
	andi.b	#1,d0
	or.b	d0,d2

loc_C226:
	DISABLE_INTS
	jsr	(SetVRAMWrite).l
	addi.w	#$80,d5
	move.w	d1,VDP_DATA
	jsr	(SetVRAMWrite).l
	move.w	d2,VDP_DATA
	ENABLE_INTS
	rts
; End of function sub_C1E8

; =============== S U B	R O U T	I N E =======================================

sub_C24C:
	lea	(sub_C28A).l,a1
	jsr	(FindActorSlot).l
	bcc.s	loc_C25E
	rts
; ---------------------------------------------------------------------------

loc_C25E:
	move.l	a0,$2E(a1)
	move.b	#$FF,7(a0)
	move.w	d0,$A(a1)
	move.w	#$780,$28(a1)
	move.l	a0,-(sp)
	movea.l	a1,a0
	move.w	#$100,d4
	move.w	#$C80C,d5
	move.w	#$C500,d6
	move.l	(sp)+,a0
	rts
; End of function sub_C24C

; =============== S U B	R O U T	I N E =======================================

sub_C28A:
	move.b	#$FF,7(a0)
	bsr.w	sub_C4BA
	move.w	#4,d0

loc_C298:
	move.b	#1,$12(a0,d0.w)
	dbf	d0,loc_C298

loc_C2A2:
	move.l	#unk_C3DC,$32(a0)
	jsr	(ActorBookmark).l
	jsr	(ActorAnimate).l
	bcs.s	loc_C2BE
	bra.w	sub_C3F0
; ---------------------------------------------------------------------------

loc_C2BE:
	jsr	(ActorBookmark).l
	addq.b	#1,$26(a0)
	move.b	(p1_ctrl_press).l,d0
	or.b	(p2_ctrl_press).l,d0
	btst	#2,d0
	bne.w	loc_C374
	andi.b	#$70,d0
	bne.s	loc_C350
	move.b	(byte_FF110C).l,d0
	or.b	(byte_FF1112).l,d0
	btst	#1,d0
	bne.s	loc_C316
	btst	#0,d0
	bne.s	loc_C332
	move.b	$26(a0),d0
	lsl.b	#1,d0
	andi.b	#$20,d0
	ori.b	#$80,d0
	move.b	d0,9(a0)
	bra.w	sub_C3F0
; ---------------------------------------------------------------------------

loc_C316:
	move.w	$E(a0),d0
	addq.b	#1,$12(a0,d0.w)
	cmpi.b	#$1C,$12(a0,d0.w)
	bcs.s	loc_C344
	move.b	#0,$12(a0,d0.w)
	bra.w	loc_C344
; ---------------------------------------------------------------------------

loc_C332:
	move.w	$E(a0),d0
	subq.b	#1,$12(a0,d0.w)
	bpl.w	loc_C344
	move.b	#$1C,$12(a0,d0.w)

loc_C344:
	clr.b	$26(a0)
	move.b	#SFX_MENU_MOVE,d0
	bra.w	PlaySound_ChkPCM
; ---------------------------------------------------------------------------

loc_C350:
	move.b	#$80,9(a0)
	bsr.w	sub_C3F0
	addq.w	#1,$E(a0)
	move.b	#SFX_MENU_SELECT,d0
	bsr.w	PlaySound_ChkPCM
	cmpi.w	#3,$E(a0)
	bcc.s	loc_C3AA
	bra.w	loc_C2A2
; ---------------------------------------------------------------------------

loc_C374:
	tst.w	$E(a0)
	bne.s	loc_C37E
	rts
; ---------------------------------------------------------------------------

loc_C37E:
	move.l	#unk_C3E6,$32(a0)
	jsr	(ActorBookmark).l
	jsr	(ActorAnimate).l
	bcs.s	loc_C39A
	bra.w	sub_C3F0
; ---------------------------------------------------------------------------

loc_C39A:
	subq.w	#1,$E(a0)
	move.b	#SFX_MENU_MOVE,d0
	bsr.w	PlaySound_ChkPCM
	bra.w	loc_C2A2
; ---------------------------------------------------------------------------

loc_C3AA:
	move.w	$A(a0),d0
	bsr.w	GetHighScoreEntry
	bsr.w	sub_C420
	clr.b	7(a0)
	clr.w	$28(a0)
	move.w	#$20,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark).l
	movea.l	$2E(a0),a1
	clr.b	7(a1)
	jmp	(ActorDeleteSelf).l
; End of function sub_C28A

; ---------------------------------------------------------------------------
; TODO: Document Animation Code

unk_C3DC:
	dc.b   0
	dc.b   0
	dc.b   3
	dc.b $1F
	dc.b   3
	dc.b $A0
	dc.b   2
	dc.b $80
	dc.b $FE
	dc.b   0

unk_C3E6:
	dc.b   0
	dc.b $80
	dc.b   3
	dc.b $A0
	dc.b   3
	dc.b $1F
	dc.b   0
	dc.b   0
	dc.b $FE
	dc.b   0

; =============== S U B	R O U T	I N E =======================================

sub_C3F0:
	move.w	$A(a0),d0
	bsr.w	GetHighScoreEntry
	move.w	$E(a0),d0
	lsl.w	#2,d0
	add.w	d0,d5
	move.w	$E(a0),d1
	move.b	$12(a0,d1.w),d0
	move.b	9(a0),d1
	bmi.w	loc_C416
	move.b	d1,d0
	bra.w	sub_C800
; ---------------------------------------------------------------------------

loc_C416:
	andi.b	#$7F,d1
	add.b	d1,d0
	bra.w	sub_C800
; End of function sub_C3F0

; =============== S U B	R O U T	I N E =======================================

sub_C420:
	clr.w	d0

loc_C422:
	move.b	$12(a0,d0.w),(a1)+
	addq.w	#1,d0
	cmpi.w	#3,d0
	bcs.s	loc_C422
	move.b	#$FF,(a1)
	jmp	(sub_23536).l
; End of function sub_C420

; =============== S U B	R O U T	I N E =======================================

sub_C438:
	cmpi.b	#4,(high_score_table_id).l
	bcs.s	loc_C44A
	andi	#$FFFE,sr
	rts
; ---------------------------------------------------------------------------

loc_C44A:
	clr.w	d0
	bsr.w	GetHighScoreEntry
	movea.l	a1,a2
	clr.w	d0

loc_C454:
	move.l	6(a1),d1
	cmp.l	$A(a0),d1
	bcs.s	loc_C474
	adda.l	#$10,a1
	addq.w	#1,d0
	cmpi.w	#5,d0
	bcs.s	loc_C454
	andi	#$FFFE,sr
	rts
; ---------------------------------------------------------------------------

loc_C474:
	movem.l	d0/a1,-(sp)
	move.w	#3,d1
	sub.w	d0,d1
	bcs.s	loc_C49E
	movea.l	a2,a1
	adda.l	#$40,a1
	adda.l	#$50,a2

loc_C490:
	move.w	#7,d0

loc_C494:
	move.w	-(a1),-(a2)
	dbf	d0,loc_C494
	dbf	d1,loc_C490

loc_C49E:
	movem.l	(sp)+,d0/a1
	move.b	#$FF,0(a1)
	move.l	$A(a0),6(a1)
	move.w	$16(a0),$A(a1)
	ori	#1,sr
	rts
; End of function sub_C438

; =============== S U B	R O U T	I N E =======================================

sub_C4BA:
	move.w	$A(a0),d0
	bsr.w	GetHighScoreEntry
	move.w	#1,d0
	move.w	#$C8,d1

loc_C4CA:
	lea	(loc_C506).l,a1
	jsr	(FindActorSlot).l
	bcs.s	loc_C4F8
	move.b	#3,8(a1)
	move.l	#unk_C536,$32(a1)
	move.l	a0,$2E(a1)
	move.w	d0,$1E(a1)
	move.w	d1,$A(a1)
	move.w	d4,$E(a1)

loc_C4F8:
	addi.w	#$10,d1
	addq.w	#1,d0
	cmpi.w	#3,d0
	bcs.s	loc_C4CA
	rts
; End of function sub_C4BA

; ---------------------------------------------------------------------------

loc_C506:
	movea.l	$2E(a0),a1
	tst.b	7(a1)
	bne.s	loc_C518
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_C518:
	move.b	#$80,6(a0)
	move.w	$E(a1),d0
	cmp.w	$1E(a0),d0
	bcs.s	loc_C530
	move.b	#0,6(a0)

loc_C530:
	jmp	(ActorAnimate).l
; ---------------------------------------------------------------------------
; TODO: Document Animation Code

unk_C536:
	dc.b $F0
	dc.b   0
	dc.b   1
	dc.b   2
	dc.b   0
	dc.b   0
	dc.b   2
	dc.b   3
	dc.b   0
	dc.b   0
	dc.b   1
	dc.b   2
	dc.b   0
	dc.b   0
	dc.b   2
	dc.b   3
	dc.b $FF
	dc.b   0
	dc.l unk_C536
; ---------------------------------------------------------------------------

loc_C54C:
	jsr	(ClearScroll).l
	lea	(loc_C66A).l,a1
	jmp	(FindActorSlot).l

; =============== S U B	R O U T	I N E =======================================

sub_C55E:
	move.w	#4,d0

loc_C562:
	move.l	d0,-(sp)
	bsr.w	GetHighScoreEntry
	move.b	0(a1),$A(a0,d0.w)
	bpl.s	loc_C57A
	move.b	#$FF,$F(a0)

loc_C57A:
	bsr.w	sub_C7B2
	move.l	(sp)+,d0
	dbf	d0,loc_C562
	rts
; End of function sub_C55E

; =============== S U B	R O U T	I N E =======================================

sub_C588:
	moveq	#4,d0

loc_C58C:
	move.l	d0,-(sp)
	bsr.w	GetHighScoreEntry
	move.l	6(a1),d2
	jsr	(sub_1B350).l
	addi.w	#$14,d5
	move.w	#7,d3
	lea	(byte_FF1982).l,a1
	bsr.w	loc_C5EE
	move.l	(sp)+,d0
	dbf	d0,loc_C58C
	rts
; End of function sub_C588

; =============== S U B	R O U T	I N E =======================================

sub_C5BA:
	moveq	#4,d0

loc_C5BE:
	move.l	d0,-(sp)
	bsr.w	GetHighScoreEntry
	moveq	#0,d2
	move.w	$A(a1),d2
	jsr	(sub_1B350).l
	addi.w	#$30,d5
	move.w	#4,d3
	lea	((byte_FF1982+3)).l,a1
	bsr.w	loc_C5EE
	move.l	(sp)+,d0
	dbf	d0,loc_C5BE
	rts
; End of function sub_C5BA

; ---------------------------------------------------------------------------

loc_C5EE:
	clr.b	d1
	DISABLE_INTS

loc_C5F4:
	move.w	#$A500,d0
	move.b	(a1)+,d0
	beq.s	loc_C602
	move.b	#1,d1

loc_C602:
	add.b	d1,d0
	lsl.b	#1,d0
	jsr	(SetVRAMWrite).l
	addi.w	#$100,d5
	move.w	d0,VDP_DATA
	addq.b	#1,d0
	jsr	(SetVRAMWrite).l
	subi.w	#$FE,d5
	move.w	d0,VDP_DATA
	dbf	d3,loc_C5F4
	ENABLE_INTS
	rts

; =============== S U B	R O U T	I N E =======================================

GetHighScoreEntry:
	movem.l	d1-d2,-(sp)
	lea	(high_scores).l,a1
	move.w	d0,d1
	lsl.w	#4,d1
	clr.w	d2
	move.b	(high_score_table_id).l,d2
	mulu.w	#$50,d2
	add.w	d1,d2
	adda.l	d2,a1
	move.w	d0,d5
	mulu.w	#$300,d5
	addi.w	#$CA0C,d5
	move.w	d0,d4
	mulu.w	#$18,d4
	addi.w	#$D8,d4
	movem.l	(sp)+,d1-d2
	rts
; End of function GetHighScoreEntry

; ---------------------------------------------------------------------------

loc_C66A:
	move.w	#$140,d1
	move.w	#$13C,$26(a0)
	bsr.w	sub_C778
	bsr.w	sub_C7CA
	bsr.w	sub_C55E
	bsr.w	sub_C588
	bsr.w	sub_C5BA
	jsr	(ActorBookmark).l
	move.w	$26(a0),d1
	bsr.w	sub_C778
	subq.w	#4,$26(a0)
	bcs.s	loc_C6D0
	tst.b	$F(a0)
	bne.w	locret_C6CE
	move.b	(p1_ctrl_press).l,d0
	or.b	(p2_ctrl_press).l,d0
	andi.b	#$F0,d0
	beq.w	locret_C6CE
	tst.b	$2A(a0)
	bne.w	locret_C6CE
	clr.b	(bytecode_disabled).l
	move.b	#$FF,$2A(a0)

locret_C6CE:
	rts
; ---------------------------------------------------------------------------

loc_C6D0:
	move.b	#SFX_67,d0
	jsr	(PlaySound_ChkPCM).l
	tst.b	(bytecode_disabled).l
	beq.s	loc_C700
	moveq	#4,d0

loc_C6E8:
	move.l	d0,-(sp)
	tst.b	$A(a0,d0.w)
	bpl.s	loc_C6F8
	bsr.w	sub_C24C

loc_C6F8:
	move.l	(sp)+,d0
	dbf	d0,loc_C6E8

loc_C700:
	move.w	#$100,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark_Ctrl).l
	tst.b	7(a0)
	beq.s	loc_C71A
	rts
; ---------------------------------------------------------------------------

loc_C71A:
	tst.b	(byte_FF1973).l
	beq.s	loc_C764
	addq.b	#1,(high_score_table_id).l
	cmpi.b	#2,(high_score_table_id).l
	beq.s	loc_C764
	move.w	#$140,d1
	move.w	d1,$26(a0)
	jsr	(ActorBookmark).l
	move.w	$26(a0),d1
	subi.w	#$140,d1
	bsr.w	sub_C778
	subq.w	#4,$26(a0)
	beq.s	loc_C75A
	rts
; ---------------------------------------------------------------------------

loc_C75A:
	jsr	(ActorBookmark).l
	bra.w	loc_C66A
; ---------------------------------------------------------------------------

loc_C764:
	tst.b	$2A(a0)
	bne.s	loc_C772
	clr.b	(bytecode_disabled).l

loc_C772:
	jmp	(ActorDeleteSelf).l

; =============== S U B	R O U T	I N E =======================================

sub_C778:
	lea	((hscroll_buffer+$140)).l,a1
	move.w	#$6F,d0

loc_C782:
	move.w	d1,(a1)+
	move.w	#0,(a1)+
	dbf	d0,loc_C782
	rts
; End of function sub_C778

; ---------------------------------------------------------------------------
off_C78E:
	dc.l unk_C796
	dc.l unk_C7A4

unk_C796:
	dc.b $13
	dc.b   3
	dc.b   5
	dc.b  $E
	dc.b   1
	dc.b $12
	dc.b   9
	dc.b  $F
	dc.b   0
	dc.b  $D
	dc.b  $F
	dc.b   4
	dc.b   5
	dc.b $FF

unk_C7A4:
	dc.b   5
	dc.b $18
	dc.b   5
	dc.b $12
	dc.b   3
	dc.b   9
	dc.b $13
	dc.b   5
	dc.b   0
	dc.b  $D
	dc.b  $F
	dc.b   4
	dc.b   5
	dc.b $FF

; =============== S U B	R O U T	I N E =======================================

sub_C7B2:
	move.b	(a1)+,d0
	bmi.s	locret_C7C8
	move.l	d5,-(sp)
	bsr.w	sub_C800
	move.l	(sp)+,d5
	addq.w	#4,d5
	bra.s	sub_C7B2
; ---------------------------------------------------------------------------

locret_C7C8:
	rts
; End of function sub_C7B2

; =============== S U B	R O U T	I N E =======================================

sub_C7CA:
	moveq	#0,d0
	move.b	(high_score_table_id).l,d0
	lea	(off_C78E).l,a2
	lsl.w	#2,d0
	movea.l	(a2,d0.w),a1
	move.w	#$D90E,d5

loc_C7E2:
	move.b	(a1)+,d0
	bmi.s	locret_C7F6
	move.l	d5,-(sp)
	bsr.w	sub_C7F8
	move.l	(sp)+,d5
	addq.w	#4,d5
	bra.s	loc_C7E2
; ---------------------------------------------------------------------------

locret_C7F6:
	rts
; End of function sub_C7CA


; =============== S U B	R O U T	I N E =======================================

sub_C7F8:
	move.w	#$A400,d1
	bra.w	loc_C804
; End of function sub_C7F8

; =============== S U B	R O U T	I N E =======================================

sub_C800:
	move.w	#$C400,d1

loc_C804:
	move.l	d1,-(sp)
	move.b	d0,d1
	andi.b	#$F,d0
	lsl.b	#1,d0
	andi.b	#$30,d1
	lsl.w	#2,d1
	or.b	d1,d0
	move.l	(sp)+,d1
	move.b	d0,d1
	DISABLE_INTS
	jsr	(SetVRAMWrite).l
	addi.w	#$100,d5
	move.w	d1,VDP_DATA
	addq.w	#1,d1
	move.w	d1,VDP_DATA
	addi.w	#$1F,d1
	jsr	(SetVRAMWrite).l
	move.w	d1,VDP_DATA
	addq.w	#1,d1
	move.w	d1,VDP_DATA
	ENABLE_INTS
	rts
; End of function sub_C800

; =============== S U B	R O U T	I N E =======================================

sub_C858:
	lea	(byte_FF143E).l,a1
	move.w	#7,d0

loc_C862:
	clr.b	(a1)+
	dbf	d0,loc_C862
	lea	(loc_B4B6).l,a1
	jsr	(FindActorSlot).l
	lea	(loc_C882).l,a1
	jsr	(FindActorSlot).l
	rts
; End of function sub_C858

; ---------------------------------------------------------------------------

loc_C882:
	move.w	#0,$26(a0)
	move.w	#$F0,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark).l

loc_C898:
	move.w	$26(a0),d0
	lea	(word_6F3FE).l,a2
	jsr	(sub_C968).l
	moveq	#0,d0
	jsr	(LoadPalette).l
	lea	(word_6F85E).l,a2
	jsr	(sub_C968).l
	moveq	#1,d0
	jsr	(LoadPalette).l
	move.w	#$C,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark).l
	addq.w	#1,$26(a0)
	move.w	$26(a0),d0
	cmpi.w	#$1B,d0
	bne.s	loc_C898
	moveq	#2,d0
	lea	(unk_C948).l,a2
	jsr	(LoadPalette).l
	jsr	(sub_BDCA).l
	jsr	(sub_F794).l
	jsr	(ActorBookmark).l
	jsr	(sub_F7B8).l
	jsr	(ActorBookmark).l

loc_C90E:
	lea	(word_6F85E).l,a2
	jsr	(sub_C968).l
	moveq	#2,d0
	jsr	(LoadPalette).l
	move.w	#$1E,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark).l
	addq.w	#1,$26(a0)
	move.w	$26(a0),d0
	cmpi.w	#$23,d0
	bne.s	loc_C90E
	jsr	(ActorBookmark).l
	rts
; ---------------------------------------------------------------------------
unk_C948:
	dc.w $0200, $0200, $0200, $0200, $0200, $0200, $0200, $0200
	dc.w $0200, $0200, $0200, $0200, $0200, $0200, $0200, $0200

; =============== S U B	R O U T	I N E =======================================

sub_C968:
	move.w	$26(a0),d0
	asl.w	#5,d0
	adda.w	d0,a2
	rts
; End of function sub_C968

; =============== S U B	R O U T	I N E =======================================

sub_C972:
	clr.l	(hscroll_buffer).l
	bsr.w	DisableLineHScroll
	clr.b	(word_FF1990+1).l
	bsr.w	sub_EDD6
	movea.l	a1,a2
	lea	(loc_CB52).l,a1
	jsr	(FindActorSlot).l
	bcs.w	loc_CAE2
	lea	(sub_CAFC).l,a1
	jsr	(FindActorSlot).l
	bcs.w	loc_CAE2
	move.l	a2,$2E(a1)
	move.l	#$1D000,$12(a1)
	move.l	#-$70000,$16(a1)
	move.b	#$33,6(a1)
	move.w	$A(a2),$A(a1)
	move.w	$E(a2),$E(a1)
	lea	(loc_CBBC).l,a1
	jsr	(FindActorSlot).l
	bcs.w	loc_CAE2
	move.l	a2,$2E(a1)
	move.b	#$2B,8(a1)
	move.b	#$1D,9(a1)
	move.b	#$3F,6(a1)
	move.w	#$86,$A(a1)
	move.w	#$37,$E(a1)
	move.b	#1,$28(a1)
	move.w	#$119,$1E(a1)
	move.w	#$80,$20(a1)
	move.l	#0,$12(a1)
	move.l	#$18000,$16(a1)
	move.w	#$2000,$1A(a1)
	move.w	#$5000,$1C(a1)
	move.w	#$12A,$2A(a1)
	moveq	#7,d1
	lea	(unk_CD32).l,a2

loc_CA3C:
	lea	(loc_CCA6).l,a1
	jsr	(FindActorSlot).l
	bcs.w	loc_CAE2
	move.b	#$31,8(a1)
	move.b	#$80,6(a1)
	move.w	(a2)+,$A(a1)
	move.w	(a2)+,$E(a1)
	move.l	(a2)+,$32(a1)
	jsr	(Random).l
	andi.b	#$3F,d0
	move.b	d0,$26(a1)
	dbf	d1,loc_CA3C
	lea	(loc_CCDE).l,a1
	jsr	(FindActorSlot).l
	bcs.s	loc_CAE2
	move.b	#$31,8(a1)
	move.b	#$16,9(a1)
	move.b	#$80,6(a1)
	bsr.w	sub_CD08
	move.w	d0,$A(a1)
	move.w	d1,$E(a1)
	move.l	#unk_CD24,$32(a1)
	lea	(loc_CCCA).l,a1
	jsr	(FindActorSlot).l
	bcs.s	loc_CAE2
	move.b	#$31,8(a1)
	move.b	#$16,9(a1)
	bsr.w	sub_CD08
	move.w	d0,$A(a1)
	move.w	d1,$E(a1)
	move.l	#unk_CD24,$32(a1)
	move.b	#$F,$26(a1)

loc_CAE2:
	lea	(ArtNem_RobotnikShip).l,a0
	move.w	#$3000,d0
	DISABLE_INTS
	jsr	(NemDec).l
	ENABLE_INTS
	rts
; End of function sub_C972


; =============== S U B	R O U T	I N E =======================================

sub_CAFC:
	movea.l	$2E(a0),a1
	movea.l	$32(a1),a2
	cmpi.b	#$FE,(a2)
	beq.s	loc_CB0E
	rts
; ---------------------------------------------------------------------------

loc_CB0E:
	move.l	#unk_EFF2,$32(a1)
	jsr	(ActorBookmark).l
	jsr	(sub_3810).l
	movea.l	$2E(a0),a1
	move.l	$16(a0),d0
	addi.l	#$3200,d0
	move.l	d0,$16(a0)
	move.w	$E(a0),$E(a1)
	move.w	$A(a0),d0
	move.w	d0,$A(a1)
	cmpi.w	#$118,d0
	bge.w	loc_CB4C
	rts
; ---------------------------------------------------------------------------

loc_CB4C:
	jmp	(ActorDeleteSelf).l
; End of function sub_CAFC

; ---------------------------------------------------------------------------

loc_CB52:
	move.b	#SFX_MACHINE_DESTROYED,d0
	jsr	(PlaySound_ChkPCM).l
	move.w	#$82,$26(a0)
	jsr	(ActorBookmark).l
	subq.w	#1,$26(a0)
	beq.s	loc_CB70
	rts
; ---------------------------------------------------------------------------

loc_CB70:
	move.b	#SFX_MACHINE_DESTROYED,d0
	jsr	(PlaySound_ChkPCM).l
	move.w	#$82,$26(a0)
	jsr	(ActorBookmark).l
	subq.w	#1,$26(a0)
	beq.s	loc_CB8E
	rts
; ---------------------------------------------------------------------------

loc_CB8E:
	move.b	#SFX_MACHINE_DESTROYED,d0
	jsr	(PlaySound_ChkPCM).l
	move.w	#$C8,$26(a0)
	jsr	(ActorBookmark).l
	subq.w	#1,$26(a0)
	beq.s	loc_CBAC
	rts
; ---------------------------------------------------------------------------

loc_CBAC:
	move.b	#VOI_BEAN_CHEER,d0
	jsr	(PlaySound_ChkPCM).l
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_CBBC:
	subq.w	#1,$2A(a0)
	beq.s	loc_CBC4
	rts
; ---------------------------------------------------------------------------

loc_CBC4:
	move.b	#$BF,6(a0)
	jsr	(ActorBookmark).l
	jsr	(sub_3810).l
	cmpi.w	#$119,$A(a0)
	bge.s	loc_CBE0
	rts
; ---------------------------------------------------------------------------

loc_CBE0:
	move.b	#$85,6(a0)
	move.l	#$30000,$16(a0)
	move.w	#$4020,$1C(a0)
	move.w	#$BA,$20(a0)
	jsr	(ActorBookmark).l
	movea.l	$2E(a0),a1
	cmpi.w	#$119,$A(a1)
	beq.s	loc_CC0E
	rts
; ---------------------------------------------------------------------------

loc_CC0E:
	jsr	(ActorBookmark).l
	jsr	(sub_3810).l
	movea.l	$2E(a0),a1
	cmpi.w	#$1C0,$A(a0)
	blt.s	loc_CC32
	andi.b	#$7F,6(a0)
	andi.b	#$7F,6(a1)

loc_CC32:
	subq.b	#1,$28(a0)
	bne.s	loc_CC4C
	move.b	#3,$28(a0)
	move.w	$26(a0),d0
	addq.w	#1,d0
	andi.b	#7,d0
	move.w	d0,$26(a0)

loc_CC4C:
	lea	(byte_CC86).l,a2
	move.w	$26(a0),d0
	lsl.w	#2,d0
	adda.w	d0,a2
	move.l	(a2)+,d0
	add.l	d0,$A(a0)
	add.l	d0,$A(a1)
	move.w	$E(a0),$E(a1)
	cmpi.w	#$1C8,$A(a0)
	bge.s	loc_CC74
	rts
; ---------------------------------------------------------------------------

loc_CC74:
	clr.b	(bytecode_disabled).l
	clr.b	(bytecode_flag).l
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------
byte_CC86:
	dc.b   0
	dc.b   1
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $70
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $80
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   1
	dc.b $40
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $30
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $70
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $40
	dc.b   0
; ---------------------------------------------------------------------------

loc_CCA6:
	jsr	(ActorAnimate).l
	jsr	(ActorBookmark).l
	tst.b	$26(a0)
	beq.s	loc_CCBE
	subq.b	#1,$26(a0)
	rts
; ---------------------------------------------------------------------------

loc_CCBE:
	jsr	(ActorBookmark).l
	jmp	(ActorAnimate).l
; ---------------------------------------------------------------------------

loc_CCCA:
	subq.b	#1,$26(a0)
	beq.s	loc_CCD2
	rts
; ---------------------------------------------------------------------------

loc_CCD2:
	move.b	#$80,6(a0)
	jsr	(ActorBookmark).l

loc_CCDE:
	jsr	(ActorAnimate).l
	movea.l	$32(a0),a2
	cmpi.b	#$FE,(a2)
	beq.s	loc_CCF2
	rts
; ---------------------------------------------------------------------------

loc_CCF2:
	bsr.w	sub_CD08
	move.w	d0,$A(a0)
	move.w	d1,$E(a0)
	move.l	#unk_CD24,$32(a0)
	rts

; =============== S U B	R O U T	I N E =======================================

sub_CD08:
	jsr	(Random).l
	move.w	d0,d1
	andi.w	#$FF,d0
	addi.w	#$90,d0
	move.w	#9,d2
	lsr.w	d2,d1
	addi.w	#$80,d1
	rts
; End of function sub_CD08

; ---------------------------------------------------------------------------
; TOTO: Document Animation code

unk_CD24:
	dc.b   5
	dc.b $16
	dc.b   5
	dc.b $17
	dc.b   5
	dc.b $18
	dc.b   5
	dc.b $19
	dc.b   5
	dc.b $1A
	dc.b   5
	dc.b $1B
	dc.b $FE
	dc.b   0

unk_CD32:
	dc.b   0
	dc.b $90
	dc.b   1
	dc.b $30
	dc.l unk_CD72
	dc.b   0
	dc.b $B8
	dc.b   0
	dc.b $C0
	dc.l unk_CDB6
	dc.b   0
	dc.b $E0
	dc.b   1
	dc.b   0
	dc.l unk_CDE2
	dc.b   1
	dc.b   8
	dc.b   1
	dc.b $30
	dc.l unk_CE0A
	dc.b   1
	dc.b $30
	dc.b   1
	dc.b   0
	dc.l unk_CD94
	dc.b   1
	dc.b $58
	dc.b   0
	dc.b $C0
	dc.l unk_CDCC
	dc.b   1
	dc.b $80
	dc.b   1
	dc.b $10
	dc.l unk_CDF6
	dc.b   1
	dc.b $A8
	dc.b   1
	dc.b   0
	dc.l unk_CE22

unk_CD72:
	dc.b   5
	dc.b   0
	dc.b   5
	dc.b   1
	dc.b   5
	dc.b   2
	dc.b   5
	dc.b   1
	dc.b   5
	dc.b   0
	dc.b   5
	dc.b   1
	dc.b   5
	dc.b   2
	dc.b   5
	dc.b   1
	dc.b   5
	dc.b   0
	dc.b   5
	dc.b   1
	dc.b   5
	dc.b   2
	dc.b   5
	dc.b   3
	dc.b   5
	dc.b   1
	dc.b   5
	dc.b   0
	dc.b $FF
	dc.b   0
	dc.l unk_CD72

unk_CD94:
	dc.b $32
	dc.b   0
	dc.b   5
	dc.b   1
	dc.b   5
	dc.b   2
	dc.b   5
	dc.b   1
	dc.b  $A
	dc.b   0
	dc.b   4
	dc.b   1
	dc.b   4
	dc.b   2
	dc.b   4
	dc.b   1
	dc.b  $A
	dc.b   0
	dc.b   5
	dc.b   1
	dc.b   5
	dc.b   2
	dc.b   5
	dc.b   3
	dc.b   5
	dc.b   1
	dc.b   5
	dc.b   0
	dc.b $FF
	dc.b   0
	dc.l unk_CD94

unk_CDB6:
	dc.b $32
	dc.b   4
	dc.b   8
	dc.b   5
	dc.b   5
	dc.b   6
	dc.b   7
	dc.b   7
	dc.b   8
	dc.b   8
	dc.b   5
	dc.b   9
	dc.b   9
	dc.b   5
	dc.b   5
	dc.b   4
	dc.b $FF
	dc.b   0
	dc.l unk_CDB6

unk_CDCC:
	dc.b   5
	dc.b   4
	dc.b   8
	dc.b   5
	dc.b   5
	dc.b   6
	dc.b   7
	dc.b   7
	dc.b   8
	dc.b   8
	dc.b   5
	dc.b   9
	dc.b   9
	dc.b   5
	dc.b   5
	dc.b   4
	dc.b $FF
	dc.b   0
	dc.l unk_CDCC

unk_CDE2:
	dc.b $1E
	dc.b  $A
	dc.b   8
	dc.b  $B
	dc.b   5
	dc.b  $C
	dc.b   8
	dc.b  $D
	dc.b   5
	dc.b  $E
	dc.b   8
	dc.b  $B
	dc.b   5
	dc.b  $A
	dc.b $FF
	dc.b   0
	dc.l unk_CDE2

unk_CDF6:
	dc.b   5
	dc.b  $A
	dc.b   5
	dc.b  $B
	dc.b   5
	dc.b  $C
	dc.b   5
	dc.b  $D
	dc.b   5
	dc.b  $E
	dc.b   5
	dc.b  $B
	dc.b   5
	dc.b  $A
	dc.b $FF
	dc.b   0
	dc.l unk_CDF6

unk_CE0A:
	dc.b $32
	dc.b  $F
	dc.b   7
	dc.b $10
	dc.b   5
	dc.b $11
	dc.b   5
	dc.b $12
	dc.b   5
	dc.b $13
	dc.b   5
	dc.b $14
	dc.b   5
	dc.b $15
	dc.b   8
	dc.b $10
	dc.b   5
	dc.b  $F
	dc.b $FF
	dc.b   0
	dc.l unk_CE0A

unk_CE22:
	dc.b   5
	dc.b  $F
	dc.b   5
	dc.b $10
	dc.b   5
	dc.b $11
	dc.b   5
	dc.b $12
	dc.b   5
	dc.b $13
	dc.b   5
	dc.b $14
	dc.b   5
	dc.b $15
	dc.b   5
	dc.b $10
	dc.b   5
	dc.b  $F
	dc.b $FF
	dc.b   0
	dc.l unk_CE22

; ---------------------------------------------------------------------------

Password_LoadBG:
	include "src/subroutines/password/Load Background.asm"

; ---------------------------------------------------------------------------

MapEni_Password:
	incbin	"resource/mapeni/Background/Password.eni"
	even

; ---------------------------------------------------------------------------

Password_Checks:
	include "src/subroutines/password/Password Checks.asm"

; =============== S U B	R O U T	I N E =======================================

DrawOpponentScrBoxes:
	clr.w	d0
	move.b	(level).l,d0
	add.w	d0,d0
	lea	(OpponentScrBGBases).l,a1
	move.w	(a1,d0.w),d0
	andi.w	#$7FFF,d0
	DISABLE_INTS
	lea	(MapEni_OpponentScrBox).l,a0
	lea	($E000).l,a1
	move.w	#$B,d1
	move.w	#8,d2
	jsr	(EniDec).l
	move.w	#$8000,d0
	lea	(eni_tilemap_buffer).l,a1
	move.w	#$B,d1

.SetHiPrio:
	or.w	d0,(a1)+
	dbf	d1,.SetHiPrio
	move.w	#6,d1

.SetHiPrio2:
	or.w	d0,(a1)+
	adda.w	#$14,a1
	or.w	d0,(a1)+
	dbf	d1,.SetHiPrio2
	move.w	#$B,d1

.SetHiPrio3:
	or.w	d0,(a1)+
	dbf	d1,.SetHiPrio3
	clr.w	d0
	move.b	(level).l,d0
	move.b	OpponentScrBoxMap(pc,d0.w),d0
	move.w	#3,d1
	lea	(eni_tilemap_queue).l,a1
	move.w	#$E906,d2

.DrawBoxes:
	lsr.b	#1,d0
	bcc.s	.DrawBoxes_Next
	move.w	#1,(a1)+
	move.w	#$B,(a1)+
	move.w	#8,(a1)+
	move.w	d2,(a1)+

.DrawBoxes_Next:
	addi.w	#$1A,d2
	dbf	d1,.DrawBoxes
	ENABLE_INTS
	rts
; End of function DrawOpponentScrBoxes

; ---------------------------------------------------------------------------
OpponentScrBoxMap:
	dc.b %1100	; Practise Stage 1
	dc.b %1110	; Practise Stage 2
	dc.b %1110	; Practise Stage 3
	dc.b %1100	; Stage 1
	dc.b %1110	; Stage 2
	dc.b %1111	; Stage 3
	dc.b %1111	; Stage 4
	dc.b %1111	; Stage 5
	dc.b %1111	; Stage 6
	dc.b %1111	; Stage 7
	dc.b %1111	; Stage 8
	dc.b %1111	; Stage 9
	dc.b %1111	; Stage 10
	dc.b %1111	; Stage 11
	dc.b %111	; Stage 12
	dc.b %100	; Stage 13

MapEni_OpponentScrBox:
	incbin	"resource/mapeni/Background/Opponent's Screen.eni"
	even

; =============== S U B	R O U T	I N E =======================================

DrawOpponentScrBG:
	clr.w	d0
	move.b	(level).l,d0
	add.w	d0,d0
	move.w	OpponentScrBGBases(pc,d0.w),d1
	DISABLE_INTS
	moveq	#$4D,d0
	lea	(eni_tilemap_buffer).l,a1

.StoreBGTiles:
	move.w	d1,(a1)+
	addq.b	#1,d1
	dbf	d0,.StoreBGTiles
	lea	(eni_tilemap_queue).l,a1
	move.w	#$E004,d2
	moveq	#4,d0

.Row:
	moveq	#4,d1

.Section:
	move.w	#1,(a1)+
	move.w	#$C,(a1)+
	move.w	#5,(a1)+
	move.w	d2,(a1)+
	addi.w	#$1A,d2
	dbf	d1,.Section
	addi.w	#$57E,d2
	dbf	d0,.Row
	ENABLE_INTS
	rts
; End of function DrawOpponentScrBG

; ---------------------------------------------------------------------------
OpponentScrBGBases:		; Opponent Screen Palette Handler
	dc.w 0		; Practise Stage 1
	dc.w 0		; Practise Stage 2
	dc.w 0		; Practise Stage 3
	dc.w $C400	; Stage 1
	dc.w $C400	; Stage 2
	dc.w $C400	; Stage 3
	dc.w $C400	; Stage 4
	dc.w $C400	; Stage 5
	dc.w $A400	; Stage 6
	dc.w $A400	; Stage 7
	dc.w $A400	; Stage 8
	dc.w $8400	; Stage 9
	dc.w $8400	; Stage 10
	dc.w $8400	; Stage 11
	dc.w $8400	; Stage 12
	dc.w $E400	; Stage 13

; =============== S U B	R O U T	I N E =======================================

Level_DrawSmallText:
	move.l	#$97000000,d0 ; Stage #
	jsr	(QueuePlaneCmd).l
	move.l	#$9A000000,d0 ; 1P VS DR R
	jmp	(QueuePlaneCmd).l
; End of function Level_DrawSmallText

; =============== S U B	R O U T	I N E =======================================

SpawnOpponentScrActors:
	jsr	(EnableSHMode).l
	bsr.w	DisableLineHScroll
	lea	(ActOpponentScr).l,a1
	jsr	(FindActorSlot).l
	bcc.w	.Spawned
	rts
; ---------------------------------------------------------------------------

.Spawned:
	move.b	#$22,8(a1)
	move.b	#1,9(a1)
	move.w	#$F8,$A(a1)
	move.w	#$D0,$E(a1)
	move.w	#$FF88,(hscroll_buffer).l
	move.w	#$FF88,(hscroll_buffer+2).l
	clr.w	d1
	move.b	(level).l,d1
	clr.w	d0
	move.b	OpponentScrScrlFlags(pc,d1.w),d0
	bne.w	.NoScrlOffset
	tst.b	(byte_FF0115).l
	bne.w	.NoScrlOffset
	move.w	#$FFF0,(hscroll_buffer).l
	move.w	#$FFF0,(hscroll_buffer+2).l

.NoScrlOffset:
	bsr.w	DrawOpponentScrBG
	bra.w	loc_D7A0
; ---------------------------------------------------------------------------
OpponentScrScrlFlags:
	dc.b $FF	; Practise Stage 1
	dc.b   0	; Practise Stage 2
	dc.b   0	; Practise Stage 3
	dc.b $FF	; Stage 1
	dc.b   0	; Stage 2
	dc.b   0	; Stage 3
	dc.b   0	; Stage 4
	dc.b   0	; Stage 5
	dc.b   0	; Stage 6
	dc.b   0	; Stage 7
	dc.b   0	; Stage 8
	dc.b   0	; Stage 9
	dc.b   0	; Stage 10
	dc.b   0	; Stage 11
	dc.b   0	; Stage 12
	dc.b $FF	; Stage 13
; ---------------------------------------------------------------------------

ActOpponentScr:
	move.w	#$A0,aField26(a0)
	jsr	(ActorBookmark).l

ActOpponentScr_Update:
	tst.w	(word_FF1122).l
	bne.s	.NoInput
	jsr	(GetCtrlData).l
	andi.b	#$F0,d0
	bne.w	ActOpponentScr_Done

.NoInput:
	cmpi.w	#$FF88,(hscroll_buffer+2).l
	beq.w	.ScrollDone
	subq.w	#2,(hscroll_buffer).l
	subq.w	#2,(hscroll_buffer+2).l
	rts
; ---------------------------------------------------------------------------

.ScrollDone:
	subq.w	#1,aField26(a0)
	beq.w	ActOpponentScr_Done
	cmpi.w	#$80,aField26(a0)
	beq.w	.StartFlash
	bcs.w	.DoFlash
	rts
; ---------------------------------------------------------------------------

.DoFlash:
	move.w	aField26(a0),d0
	rol.b	#5,d0
	andi.b	#$80,d0
	move.b	d0,aDrawFlags(a0)
	rts
; ---------------------------------------------------------------------------

.StartFlash:
	move.b	#SFX_GARBAGE_1,d0
	jsr	(PlaySound_ChkPCM).l
	move.w	#$C73E,d5
	moveq	#0,d2
	clr.w	d0
	move.b	(level).l,d0
	subq.b	#2,d0
	cmpi.b	#$A,d0
	blt.s	.GetNumberTile
	move.w	#$8476,d2
	subi.b	#$A,d0

.GetNumberTile:
	addi.w	#$8475,d0
	lea	(.StageTextTiles).l,a2
	lea	(eni_tilemap_buffer).l,a1
	move.w	#1,d1

.DrawStageHdrLine:
	move.w	#5,d3

.DrawStageText:
	move.w	(a2)+,(a1)+
	dbf	d3,.DrawStageText
	move.w	d2,(a1)+
	tst.b	d2
	beq.s	.DrawStageNumber
	addi.w	#$A,d2

.DrawStageNumber:
	move.w	d0,(a1)+
	addi.w	#$A,d0
	dbf	d1,.DrawStageHdrLine
	lea	(eni_tilemap_queue).l,a1
	move.w	#1,(a1)+
	move.w	#7,(a1)+
	move.w	#1,(a1)+
	move.w	d5,(a1)+
	rts
; ---------------------------------------------------------------------------
.StageTextTiles:
	dc.w $8493
	dc.w $8494
	dc.w $8495
	dc.w $8496
	dc.w $8497
	dc.w 0
	dc.w $8498
	dc.w $8499
	dc.w $849A
	dc.w $849B
	dc.w $849C
	dc.w 0
; ---------------------------------------------------------------------------

ActOpponentScr_Done:
	clr.b	(bytecode_disabled).l
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_D7A0:
	lea	sub_D818(pc),a1
	jsr	(FindActorSlot).l
	clr.w	d0
	move.b	(level).l,d0
	lsl.w	#2,d0
	move.l	word_D7F8(pc,d0.w),d5
	move.l	d5,aField2C(a1)
	move.w	#$CA08,aField26(a1)
	DISABLE_INTS
	moveq	#4-1,d1

.loop:
	moveq	#0,d0
	move.b	d5,d0
	bmi.s	.null

	lea	dword_D916(pc),a2
	lsl.w	#4,d0
	adda.w	d0,a2
	move.w	$C(a2),d0
	movea.l	(a2),a0
	jsr	(NemDec).l

.null:
	lsr.l	#8,d5
	dbf	d1,.loop
	ENABLE_INTS
	rts
; End of function SpawnOpponentScrActors

; ---------------------------------------------------------------------------
; -1 means nothing is loaded
word_D7F8:	; Loads Opponent Art on Opponents Screen
	dc.b -1, -1, -1, -1	; Practise Stage 1
	dc.b -1, -1, -1, -1	; Practise Stage 2
	dc.b -1, -1, -1, -1	; Practise Stage 3
	dc.b  1,  3, -1, -1	; Stage 1
	dc.b $E,  1,  3, -1	; Stage 2
	dc.b  7, $E,  1,  3	; Stage 3
	dc.b  6,  7, $E,  1	; Stage 4
	dc.b $F,  6,  7, $E	; Stage 5
	dc.b  2, $F,  6,  7	; Stage 6
	dc.b  5,  2, $F,  6	; Stage 7
	dc.b  8,  5,  2, $F	; Stage 8
	dc.b  9,  8,  5,  2	; Stage 9
	dc.b $A,  9,  8,  5	; Stage 10
	dc.b $B, $A,  9,  8	; Stage 11
	dc.b -1, $B, $A,  9	; Stage 12
	dc.b -1, $C, -1, -1	; Stage 13

; =============== S U B	R O U T	I N E =======================================

sub_D818:
	jsr	(ActorBookmark).l
	jsr	(ActorBookmark).l
	cmpi.b	#4,aAnimTime(a0)
	bne.s	loc_D880
	clr.w	d0
	move.b	(level).l,d0
	add.w	d0,d0
	move.w	word_D860(pc,d0.w),d0
	bmi.s	loc_D85A
	move.w	d0,d1
	andi.w	#$FF,d1
	lsl.w	#5,d1
	lea	(Palettes).l,a2
	adda.l	d1,a2
	lsr.w	#8,d0
	clr.w	d1
	jsr	(FadeToPalette).l

loc_D85A:
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------
word_D860:	; Opponent screen palette override
	dc.b -1, -1
	dc.b -1, -1
	dc.b -1, -1
	dc.b  2, (Pal_Humpty-Palettes)>>5
	dc.b -1, -1
	dc.b -1, -1
	dc.b -1, -1
	dc.b -1, -1
	dc.b -1, -1
	dc.b -1, -1
	dc.b -1, -1
	dc.b -1, -1
	dc.b -1, -1
	dc.b -1, -1
	dc.b 0, (Pal_Spike-Palettes)>>5
	dc.b 3, (Pal_Spike-Palettes)>>5
; ---------------------------------------------------------------------------

loc_D880:
	addq.b	#1,aAnimTime(a0)
	move.l	aField2C(a0),d5
	move.l	d5,d1
	lsr.l	#8,d1
	move.l	d1,aField2C(a0)
	and.w	#$FF,d5
	tst.b	d5
	bmi.s	loc_D8FE
	lea	dword_D916(pc),a2
	move.w	d5,d6
	lsl.w	#4,d5
	adda.w	d5,a2
	move.w	aField26(a0),d4
	move.l	a0,-(sp)
	move.w	$E(a2),d0
	lea	(opponents_defeated).l,a3
	tst.b	(a3,d6.w)
	beq.s	loc_D8C4
	movea.l	8(a2),a0
	and.w	#$7FFF,d0
	bra.s	loc_D8C8
; ---------------------------------------------------------------------------

loc_D8C4:
	movea.l	4(a2),a0

loc_D8C8:
	move.w	#9,d1
	move.w	#6,d2
	movea.w	d4,a1
	jsr	(EniDec).l
	move.l	(sp)+,a0
	lea	(OpponentPalettes).l,a1
	moveq	#0,d1
	move.b	(a1,d6.w),d1
	lsl.w	#5,d1
	lea	(Palettes).l,a2
	adda.w	d1,a2
	moveq	#0,d0
	move.b	byte_D906(pc,d6.w),d0
	clr.w	d1
	jsr	(FadeToPalette).l

loc_D8FE:
	addi.w	#$1A,aField26(a0)
	rts
; End of function sub_D818

; ---------------------------------------------------------------------------
byte_D906:
	dc.b 0	; Skeleton Tea - Puyo Leftover
	dc.b 1	; Frankly
	dc.b 2	; Dynamight
	dc.b 0	; Arms
	dc.b 1	; Nasu Grave - Puyo Leftover
	dc.b 3	; Grounder
	dc.b 0	; Davy Sprocket
	dc.b 3	; Coconuts
	dc.b 0	; Spike
	dc.b 1	; Sir Ffuzzy-Logik
	dc.b 2	; Dragon Breath
	dc.b 3	; Scratch
	dc.b 0	; Dr. Robotnik
	dc.b 2	; Mummy - Puyo Leftover
	dc.b 2	; Humpty
	dc.b 1	; Skweel
	even

	; Load your custom opponents art into the opponents screen here

dword_D916:
	; Skeleton Tea - Puyo Leftover
	dc.l 0		; Art File
	dc.l 0		; Upcoming Opponent Frame
	dc.l 0		; Defeated Opponent Frame
	dc.w 0		; Palette Line (x$2000)
	dc.w 0		; $8000 + Palette Line (x$2000) + Palette Line (x$100)

;	Frankly
	dc.l ArtNem_Frankly
	dc.l MapEni_Frankly_0
	dc.l MapEni_Frankly_Defeated
	dc.w $2000
	dc.w $A100

	; Bean
	dc.l ArtNem_Dynamight
	dc.l MapEni_Dynamight_0
	dc.l MapEni_Dynamight_9
	dc.w $4000
	dc.w $C200

	; Arms
	dc.l ArtNem_Arms
	dc.l MapEni_Arms_8
	dc.l MapEni_Arms_Defeated
	dc.w 0
	dc.w $8000

	; Nasu Grave - Puyo Leftover
	dc.l 0
	dc.l 0
	dc.l 0
	dc.w 0
	dc.w 0

	; Grounder
	dc.l ArtNem_Grounder
	dc.l MapEni_Grounder_0
	dc.l MapEni_Grounder_Defeated
	dc.w $6000
	dc.w $E300

	; Davy Sprocket
	dc.l ArtNem_DavySprocket
	dc.l MapEni_DavySprocket_0
	dc.l MapEni_DavySprocket_Defeated
	dc.w 0
	dc.w $8000

	; Coconuts
	dc.l ArtNem_Coconuts
	dc.l MapEni_Coconuts_0
	dc.l MapEni_Coconuts_Defeated
	dc.w $6000
	dc.w $E300

	; Spike
	dc.l ArtNem_Spike
	dc.l MapEni_Spike_0
	dc.l MapEni_Spike_Defeated
	dc.w 0
	dc.w $8000

	; Sir Ffuzzy-Logik
	dc.l ArtNem_SirFfuzzyLogik
	dc.l MapEni_SirFfuzzyLogik_0
	dc.l MapEni_SirFfuzzyLogik_Defeated_2
	dc.w $2000
	dc.w $A100

	; Dragon Breath
	dc.l ArtNem_DragonBreath
	dc.l MapEni_DragonBreath_0
	dc.l MapEni_DragonBreath_Defeated
	dc.w $4000
	dc.w $C200

	; Scratch
	dc.l ArtNem_Scratch
	dc.l MapEni_Scratch_1
	dc.l MapEni_Scratch_Defeated
	dc.w $6000
	dc.w $E300

	; Dr. Robotnik
	dc.l ArtNem_DrRobotnik
	dc.l MapEni_DrRobotnik_0
	dc.l MapEni_DrRobotnik_Defeated
	dc.w 0
	dc.w $8000

	; Mummy - Puyo Leftover
	dc.l 0
	dc.l 0
	dc.l 0
	dc.w 0
	dc.w 0

	; Humpty
	dc.l ArtNem_Humpty
	dc.l MapEni_Humpty_0
	dc.l MapEni_Humpty_Defeated
	dc.w $4000
	dc.w $C200

	; Skweel
	dc.l ArtNem_Skweel
	dc.l MapEni_Skweel_0
	dc.l MapEni_Skweel_Defeated
	dc.w $2000
	dc.w $A100

; ---------------------------------------------------------------------------
	DISABLE_INTS
	move.w	#$CC08,d5
	bsr.w	sub_DA5A
	move.w	#$CC48,d5
	bsr.w	sub_DA5A
	move.w	#$E000,d5
	move.w	#7,d0
	move.w	#$41F0,d1

loc_DA36:
	jsr	(SetVRAMWrite).l
	addi.w	#$80,d5
	move.w	#$27,d2

loc_DA44:
	move.w	d1,VDP_DATA
	dbf	d2,loc_DA44
	addq.w	#1,d1
	dbf	d0,loc_DA36
	ENABLE_INTS
	rts

; =============== S U B	R O U T	I N E =======================================

sub_DA5A:
	jsr	(SetVRAMWrite).l
	addi.w	#$80,d5
	move.w	#$17,d0
	move.w	#$2160,d1

loc_DA6C:
	move.w	d1,VDP_DATA
	addq.w	#1,d1
	dbf	d0,loc_DA6C
	jsr	(SetVRAMWrite).l
	move.w	#$17,d0

loc_DA82:
	move.w	d1,VDP_DATA
	addq.w	#1,d1
	dbf	d0,loc_DA82
	rts
; End of function sub_DA5A

; =============== S U B	R O U T	I N E =======================================

sub_DA90:
	bsr.w	sub_DBAC
	bsr.w	sub_DBF4
	lea	(sub_DAC8).l,a1
	jsr	(FindActorSlot).l
	bcc.s	loc_DAAA
	rts
; ---------------------------------------------------------------------------

loc_DAAA:
	move.w	#1,$12(a1)
	move.w	#$A,$28(a1)
	move.b	#$FF,(bytecode_flag).l
	bsr.w	EnableLineHScroll
	bsr.w	sub_ED9C
	rts
; End of function sub_DA90

; =============== S U B	R O U T	I N E =======================================

sub_DAC8:
	jsr	(GetCtrlData).l
	btst	#7,d0
	beq.s	loc_DAE4
	jsr	(CheckCoinInserted).l
	bcs.s	loc_DAE4
	bra.w	loc_DB4A
; ---------------------------------------------------------------------------

loc_DAE4:
	andi.b	#$70,d0
	bne.s	loc_DAF4
	tst.w	$26(a0)
	bne.s	loc_DB30

loc_DAF4:
	subq.w	#1,$28(a0)
	bcs.s	loc_DB58
	move.w	#$9200,d0
	move.b	$29(a0),d0
	swap	d0
	jsr	(QueuePlaneCmd).l
	move.w	#$50,$26(a0)
	move.b	#SFX_MENU_MOVE,d0
	cmpi.w	#1,$28(a0)
	bne.s	loc_DB2A
	move.b	#SFX_ROBOTNIK_LAUGH_2,d0
	move.b	#$88,(word_FF1990+1).l

loc_DB2A:
	jsr	(PlaySound_ChkPCM).l

loc_DB30:
	subq.w	#1,$26(a0)
	bsr.w	sub_DB66
	bsr.w	loc_DBB8
	move.b	$27(a0),d0
	andi.b	#3,d0
	beq.w	loc_DBD2
	rts
; ---------------------------------------------------------------------------

loc_DB4A:
	move.b	#SFX_MENU_SELECT,d0
	bsr.w	PlaySound_ChkPCM
	clr.b	(bytecode_flag).l

loc_DB58:
	clr.b	(bytecode_disabled).l
	jsr	(ActorBookmark).l
	rts
; End of function sub_DAC8


; =============== S U B	R O U T	I N E =======================================

sub_DB66:
	lea	(hblank_buffer_1).l,a1
	addq.w	#1,(a1)
	move.w	(a1),d0
	move.w	#$B4,d1
	jsr	(Sin).l
	lea	2(a1),a1
	moveq	#0,d0
	move.w	#$6F,d1

loc_DB84:
	move.l	d0,(a1)+
	add.l	d2,d0
	dbf	d1,loc_DB84
	lea	((hblank_buffer_1+2)).l,a1
	lea	((hscroll_buffer+2)).l,a2
	move.w	#$6F,d1

loc_DB9C:
	move.w	(a1),(a2)+
	move.w	#0,(a2)+
	lea	4(a1),a1
	dbf	d1,loc_DB9C
	rts
; End of function sub_DB66

; =============== S U B	R O U T	I N E =======================================

sub_DBAC:
	lea	((hscroll_buffer+$302)).l,a1
	move.w	#$80,d0
	bra.s	loc_DBC2
; ---------------------------------------------------------------------------

loc_DBB8:
	lea	((hscroll_buffer+$302)).l,a1
	subq.w	#2,(a1)
	move.w	(a1),d0

loc_DBC2:
	move.w	#$F,d1

loc_DBC6:
	move.w	d0,(a1)+
	move.w	#0,(a1)+
	dbf	d1,loc_DBC6
	rts
; End of function sub_DBAC

; ---------------------------------------------------------------------------
; START	OF FUNCTION CHUNK FOR sub_DAC8

loc_DBD2:
	move.w	$2A(a0),d0
	jsr	(sub_BC82).l
	move.w	d0,$2A(a0)
	move.w	d1,(palette_buffer+$7E).l
	moveq	#3,d0
	lea	((palette_buffer+$60)).l,a2
	jmp	(LoadPalette).l
; END OF FUNCTION CHUNK	FOR sub_DAC8

; =============== S U B	R O U T	I N E =======================================

sub_DBF4:
	move.w	#7,d0

loc_DBF8:
	lea	(loc_DC44).l,a1
	jsr	(FindActorSlotQuick).l
	bcs.s	loc_DC2E
	move.b	#$83,6(a1)
	move.b	#$1F,8(a1)
	move.b	d0,9(a1)
	move.w	d0,d1
	lsl.w	#1,d1
	move.w	word_DC34(pc,d1.w),$1E(a1)
	lsl.b	#4,d1
	move.b	d1,$36(a1)
	move.w	#$A0,$38(a1)

loc_DC2E:
	dbf	d0,loc_DBF8
	rts
; End of function sub_DBF4

; ---------------------------------------------------------------------------
word_DC34:
	dc.w $C8
	dc.w $E0
	dc.w $F8
	dc.w $110
	dc.w $130
	dc.w $148
	dc.w $160
	dc.w $178
; ---------------------------------------------------------------------------

loc_DC44:
	move.b	$36(a0),d0
	move.w	$38(a0),d1
	jsr	(Sin).l
	asr.l	#8,d2
	addi.w	#$120,d2
	move.w	d2,$A(a0)
	addi.b	#$10,d0
	jsr	(Cos).l
	asr.l	#8,d2
	addi.w	#$F0,d2
	move.w	d2,$E(a0)
	addq.b	#2,$36(a0)
	subq.w	#1,$38(a0)
	bcs.s	loc_DC7E
	rts
; ---------------------------------------------------------------------------

loc_DC7E:
	clr.w	d0
	move.b	9(a0),d0
	lsl.w	#3,d0
	move.w	d0,$26(a0)
	clr.b	$36(a0)
	move.w	$1E(a0),d0
	subi.w	#$120,d0
	swap	d0
	asr.l	#7,d0
	move.l	d0,$12(a0)
	move.l	#$FFFF9000,$16(a0)
	jsr	(ActorBookmark).l
	tst.w	$26(a0)
	beq.s	loc_DCBA
	subq.w	#1,$26(a0)
	rts
; ---------------------------------------------------------------------------

loc_DCBA:
	move.w	#$80,$26(a0)
	move.l	$E(a0),$32(a0)
	jsr	(ActorBookmark).l
	move.l	$32(a0),$E(a0)
	jsr	(sub_3810).l
	move.l	$E(a0),$32(a0)
	subq.w	#1,$26(a0)
	beq.s	loc_DD00
	move.b	$27(a0),d0
	ori.b	#$80,d0
	move.w	#$7800,d1
	jsr	(Sin).l
	swap	d2
	add.w	d2,$E(a0)
	rts
; ---------------------------------------------------------------------------

loc_DD00:
	jsr	(ActorBookmark).l
	jsr	(CheckCoinInserted).l
	move.b	$36(a0),d0
	ori.b	#$80,d0
	move.w	#$1800,d1
	jsr	(Sin).l
	swap	d2
	addi.w	#$B8,d2
	move.w	d2,$E(a0)
	addq.b	#2,$36(a0)
	rts
; ---------------------------------------------------------------------------
	tst.b	9(a0)
	beq.s	loc_DD3C
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_DD3C:
	move.b	#0,6(a0)
	jsr	(ActorBookmark).l
	move.l	#$800B0F00,d0
	tst.b	(swap_controls).l
	beq.s	loc_DD5E
	move.l	#$80100F00,d0

loc_DD5E:
	jmp	(QueuePlaneCmd).l

; =============== S U B	R O U T	I N E =======================================

LoadTimerCtrlSkip:
	lea	(ActTimerCtrlSkip).l,a1
	jsr	(FindActorSlot).l
	bcc.w	.SetTimer
	rts
; ---------------------------------------------------------------------------

.SetTimer:
	move.w	#$A00,$26(a1)
	rts
; End of function LoadTimerCtrlSkip

; =============== S U B	R O U T	I N E =======================================

LoadCtrlWait:
	lea	(ActTimerCtrlSkip).l,a1
	jmp	(FindActorSlot).l
; End of function LoadCtrlWait

; =============== S U B	R O U T	I N E =======================================

ActTimerCtrlSkip:
	move.b	(p1_ctrl_press).l,d0
	or.b	(p2_ctrl_press).l,d0
	andi.b	#$F0,d0
	bne.w	.Skip
	tst.w	aField26(a0)
	bne.w	.ChkTimer
	rts
; ---------------------------------------------------------------------------

.ChkTimer:
	subq.w	#1,aField26(a0)
	beq.w	.NotSkipped
	rts
; ---------------------------------------------------------------------------

.Skip:
	move.b	#$FF,(bytecode_flag).l
	clr.b	(bytecode_disabled).l
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

.NotSkipped:
	clr.b	(bytecode_flag).l
	clr.b	(bytecode_disabled).l
	jmp	(ActorDeleteSelf).l
; End of function ActTimerCtrlSkip

; =============== S U B	R O U T	I N E =======================================

sub_DDD8:
	lea	(sub_DE0E).l,a1
	jsr	(FindActorSlotQuick).l
	bcc.s	loc_DDEA
	rts
; ---------------------------------------------------------------------------

loc_DDEA:
	move.b	#$80,6(a1)
	move.b	#$1C,8(a1)
	clr.w	d0
	move.b	(bytecode_flag).l,d0
	lsl.b	#2,d0
	move.w	word_DE30(pc,d0.w),$A(a1)
	move.w	word_DE32(pc,d0.w),$E(a1)
	rts
; End of function sub_DDD8

; =============== S U B	R O U T	I N E =======================================

sub_DE0E:
	jsr	(CheckCoinInserted).l
	bcs.s	loc_DE1E
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_DE1E:
	move.b	(frame_count+1).l,d0
	lsl.b	#2,d0
	andi.b	#$80,d0
	move.b	d0,6(a0)
	rts
; End of function sub_DE0E

; ---------------------------------------------------------------------------
word_DE30:	dc.w $EE

word_DE32:
	dc.w $100
	dc.w $8E
	dc.w $E0
	dc.w $8E
	dc.w $E0

; =============== S U B	R O U T	I N E =======================================

InitTitle:
	include "src/subroutines/title/Initiate Title.asm"

; =============== S U B	R O U T	I N E =======================================

sub_DF74:
	move.l	d0,-(sp)
	clr.w	d0
	move.b	(difficulty).l,d0
	move.b	unk_DF8E(pc,d0.w),(byte_FF0104).l
	move.l	(sp)+,d0
	rts
; End of function sub_DF74

; ---------------------------------------------------------------------------
unk_DF8E:
	dc.b   0
	dc.b   2
	dc.b   4
	dc.b   6

; =============== S U B	R O U T	I N E =======================================

InitTitleFlags:
	bsr.s	sub_DF74
	clr.l	(dword_FF195C).l
	clr.l	(dword_FF1960).l
	clr.w	(word_FF010E).l
	clr.w	(word_FF0110).l
	clr.w	(player_1_flags).l
	clr.w	(level).l
	clr.b	(byte_FF0115).l
	clr.b	(byte_FF0105).l
	clr.b	(word_FF1124).l
	clr.b	(swap_controls).l
	clr.w	(word_FF1126).l
	move.w	#$9003,d0
	move.w	d0,VDP_CTRL
	move.b	d0,(vdp_reg_10).l
	move.w	#$8B00,d0
	move.w	d0,VDP_CTRL
	move.b	d0,(vdp_reg_b).l
	move.w	#$11,d0
	lea	(opponents_defeated).l,a1

loc_E000:
	clr.b	(a1)+
	dbf	d0,loc_E000
	rts
; End of function InitTitleFlags

; =============== S U B	R O U T	I N E =======================================

ActTitleRobotnik:
	include "src/subroutines/title/Act Title Robotnik.asm"

; =============== S U B	R O U T	I N E =======================================

ActTitleRobotnikText:
	include "src/subroutines/title/Act Title Robotnik Text.asm"

; =============== S U B	R O U T	I N E =======================================

ActTitleHandler:
	include "src/subroutines/title/Act Title Handler.asm"

; =============== S U B	R O U T	I N E =======================================

EnableLineHScroll:
	move.w	#$8B00,d0
	move.b	(vdp_reg_b).l,d0
	ori.b	#3,d0
	move.b	d0,(vdp_reg_b).l
	rts
; End of function EnableLineHScroll

; =============== S U B	R O U T	I N E =======================================

DisableLineHScroll:
	move.w	#$8B00,d0
	move.b	(vdp_reg_b).l,d0
	andi.b	#$FC,d0
	move.b	d0,(vdp_reg_b).l
	jmp	(ClearScroll).l
; End of function DisableLineHScroll

; =============== S U B	R O U T	I N E =======================================

sub_ED62:
	move.w	#0,(word_FF1990).l
	lea	(sub_EE10).l,a1
	jsr	(FindActorSlot).l
	bcs.w	locret_ED9A
	move.b	#$2B,8(a1)
	move.b	#$80,6(a1)
	move.w	#$90,$A(a1)
	move.w	#$E0,$E(a1)
	move.l	#unk_EF22,$32(a1)

locret_ED9A:
	rts
; End of function sub_ED62

; =============== S U B	R O U T	I N E =======================================

sub_ED9C:
	move.w	#0,(word_FF1990).l
	lea	(sub_EE10).l,a1
	jsr	(FindActorSlot).l
	bcs.w	locret_EDD4
	move.b	#$1B,8(a1)
	move.b	#$80,6(a1)
	move.w	#$E8,$A(a1)
	move.w	#$90,$E(a1)
	move.l	#unk_EF8E,$32(a1)

locret_EDD4:
	rts
; End of function sub_ED9C

; =============== S U B	R O U T	I N E =======================================

sub_EDD6:
	move.w	#0,(word_FF1990).l
	lea	(sub_EE10).l,a1
	jsr	(FindActorSlot).l
	bcs.w	locret_EE0E
	move.b	#$2B,8(a1)
	move.b	#$80,6(a1)
	move.w	#$A0,$A(a1)
	move.w	#$E0,$E(a1)
	move.l	#unk_EFC6,$32(a1)

locret_EE0E:
	rts
; End of function sub_EDD6

; =============== S U B	R O U T	I N E =======================================

sub_EE10:
	jsr	(ActorBookmark).l
	move.b	(word_FF1990+1).l,d0
	bpl.w	loc_EE3A
	lea	(Intro_SpecAnim).l,a1
	andi.b	#$7F,d0
	lsl.w	#2,d0
	movea.l	(a1,d0.w),a2
	jsr	(a2)
	move.b	#0,(word_FF1990+1).l

loc_EE3A:
	tst.b	$22(a0)
	beq.s	loc_EE48
	subq.b	#1,$22(a0)
	rts
; ---------------------------------------------------------------------------

loc_EE48:
	movea.l	$32(a0),a2
	cmpi.b	#$FE,(a2)
	bne.s	loc_EE56
	rts
; ---------------------------------------------------------------------------

loc_EE56:
	cmpi.b	#$FF,(a2)
	bne.s	loc_EE62
	movea.l	2(a2),a2

loc_EE62:
	move.b	(a2)+,$22(a0)
	move.b	(a2)+,d0
	move.b	d0,9(a0)
	move.l	a2,$32(a0)
	lsl.w	#2,d0
	move.l	off_EEC2(pc,d0.w),d0
	move.l	a0,-(sp)
	lea	(dma_queue).l,a0
	adda.w	(dma_slot).l,a0
	move.w	#$8F02,(a0)+
	move.l	#$94059380,(a0)+
	lsr.l	#1,d0
	move.l	d0,d1
	lsr.w	#8,d0
	swap	d0
	move.w	d1,d0
	andi.w	#$FF,d0
	addi.l	#-$69FF6B00,d0
	swap	d1
	andi.w	#$7F,d1
	addi.w	#-$6900,d1
	move.l	d0,(a0)+
	move.w	d1,(a0)+
	move.l	#$60000080,(a0)
	addi.w	#$10,(dma_slot).l
	movea.l	(sp)+,a0
	rts
; End of function sub_EE10

; ---------------------------------------------------------------------------
off_EEC2:	
	dc.l ArtUnc_Robotnik_0
	dc.l ArtUnc_Robotnik_1
	dc.l ArtUnc_Robotnik_2
	dc.l ArtUnc_Robotnik_3
	dc.l ArtUnc_Robotnik_4
	dc.l ArtUnc_Robotnik_5
	dc.l ArtUnc_Robotnik_6
	dc.l ArtUnc_Robotnik_7
	dc.l ArtUnc_Robotnik_8
	dc.l ArtUnc_Robotnik_9
	dc.l ArtUnc_Robotnik_10
	dc.l ArtUnc_Robotnik_11
	dc.l ArtUnc_Robotnik_12
	dc.l ArtUnc_Robotnik_13
	dc.l ArtUnc_Robotnik_14
	dc.l ArtUnc_Robotnik_15
	dc.l ArtUnc_Robotnik_16
	dc.l ArtUnc_Robotnik_17
	dc.l ArtUnc_Robotnik_18
	dc.l ArtUnc_Robotnik_19
	dc.l ArtUnc_Robotnik_20
	dc.l ArtUnc_Robotnik_21
	dc.l ArtUnc_Robotnik_22
	dc.l ArtUnc_Robotnik_23

; TODO: Document Animation Code
unk_EF22:
	dc.b $32
	dc.b   0
	dc.b   6
	dc.b   1
	dc.b   6
	dc.b   2
	dc.b   6
	dc.b   3
	dc.b  $C
	dc.b   4
	dc.b $11
	dc.b   5
	dc.b   8
	dc.b   6
	dc.b $11
	dc.b   7
	dc.b   8
	dc.b   6
	dc.b $10
	dc.b   8
	dc.b   7
	dc.b   9
	dc.b   8
	dc.b  $A
	dc.b   7
	dc.b  $B
	dc.b $14
	dc.b  $C
	dc.b  $F
	dc.b   0
	dc.b   6
	dc.b   1
	dc.b   6
	dc.b   2
	dc.b   6
	dc.b   3
	dc.b  $C
	dc.b   4
	dc.b $11
	dc.b   5
	dc.b   8
	dc.b   6
	dc.b $11
	dc.b   7
	dc.b   8
	dc.b   6
	dc.b $11
	dc.b   8
	dc.b   8
	dc.b   0
	dc.b $15
	dc.b  $D
	dc.b   7
	dc.b  $E
	dc.b   7
	dc.b  $F
	dc.b   7
	dc.b $10
	dc.b $15
	dc.b  $D
	dc.b   7
	dc.b  $E
	dc.b   7
	dc.b  $F
	dc.b   7
	dc.b $10
	dc.b $15
	dc.b  $D
	dc.b $10
	dc.b   0
	dc.b   6
	dc.b   1
	dc.b   6
	dc.b   2
	dc.b   6
	dc.b   3
	dc.b   8
	dc.b   4
	dc.b   8
	dc.b   5
	dc.b  $A
	dc.b   6
	dc.b   8
	dc.b   4
	dc.b   8
	dc.b   5
	dc.b  $A
	dc.b   6
	dc.b   8
	dc.b   4
	dc.b  $C
	dc.b   5
	dc.b   5
	dc.b   6
	dc.b   8
	dc.b   4
	dc.b  $C
	dc.b   5
	dc.b   8
	dc.b   6
	dc.b  $A
	dc.b   0
	dc.b $FF
	dc.b   0
	dc.l unk_EF22

unk_EF8E:
	dc.b   4
	dc.b   0
	dc.b   4
	dc.b   1
	dc.b   4
	dc.b   2
	dc.b   4
	dc.b   3
	dc.b   4
	dc.b   4
	dc.b   4
	dc.b   5
	dc.b   4
	dc.b   6
	dc.b   4
	dc.b   7
	dc.b   4
	dc.b   6
	dc.b   4
	dc.b   8
	dc.b   4
	dc.b   9
	dc.b   4
	dc.b  $A
	dc.b   4
	dc.b  $B
	dc.b   4
	dc.b  $C
	dc.b   4
	dc.b   0
	dc.b   4
	dc.b  $D
	dc.b   4
	dc.b  $E
	dc.b   4
	dc.b  $F
	dc.b   4
	dc.b $10
	dc.b   4
	dc.b  $D
	dc.b   4
	dc.b  $E
	dc.b   4
	dc.b  $F
	dc.b   4
	dc.b $10
	dc.b   4
	dc.b  $D
	dc.b   4
	dc.b   0
	dc.b $FF
	dc.b   0
	dc.l unk_EF8E

unk_EFC6:
	dc.b $32
	dc.b   0
	dc.b   6
	dc.b   1
	dc.b   6
	dc.b   2
	dc.b   6
	dc.b   3
	dc.b  $C
	dc.b   4
	dc.b $11
	dc.b   5
	dc.b   8
	dc.b   6
	dc.b $11
	dc.b   7
	dc.b   8
	dc.b   6
	dc.b $10
	dc.b   8
	dc.b   7
	dc.b   9
	dc.b   8
	dc.b  $A
	dc.b   7
	dc.b  $B
	dc.b $14
	dc.b  $C
	dc.b   8
	dc.b  $A
	dc.b   9
	dc.b  $B
	dc.b $14
	dc.b  $C
	dc.b   9
	dc.b  $A
	dc.b  $A
	dc.b  $B
	dc.b $1E
	dc.b  $C
	dc.b  $A
	dc.b   0
	dc.b $FE
	dc.b   0

unk_EFF2:
	dc.b  $E
	dc.b  $E
	dc.b $12
	dc.b  $F
	dc.b $16
	dc.b $10
	dc.b   4
	dc.b $11
	dc.b   4
	dc.b $12
	dc.b $FE
	dc.b   0

; =============== S U B	R O U T	I N E =======================================

sub_EFFE:
	lea	(ArtNem_IntroBadniks).l,a0
	lea	(misc_buffer_1).l,a4
	DISABLE_INTS
	jsr	(NemDecRAM).l
	ENABLE_INTS
	move.b	#$10,(opponent).l
	move.w	#$DA,(word_FF1994).l
	lea	(ActLevelIntro).l,a1
	jsr	(FindActorSlot).l
	moveq	#0,d0
	move.w	d0,(vscroll_buffer).l
	move.w	d0,(hscroll_buffer).l
	move.l	d0,(dword_FF112C).l
	move.l	d0,(dword_FF1130).l
	move.w	#0,(use_lair_assets).l
	jsr	(sub_F13A).l
	bsr.w	sub_ED62
	lea	(sub_F074).l,a1
	jmp	(FindActorSlot).l
; End of function sub_EFFE

; ---------------------------------------------------------------------------

loc_F06C:
	bra.w	loc_F07E
; ---------------------------------------------------------------------------
	bra.w	loc_F086

; =============== S U B	R O U T	I N E =======================================

sub_F074:
	move.w	(dword_FF112C).l,d0
	jmp	loc_F06C(pc,d0.w)
; End of function sub_F074

; ---------------------------------------------------------------------------

loc_F07E:
	addq.w	#4,(dword_FF112C).l
	rts
; ---------------------------------------------------------------------------

loc_F086:
	addq.w	#4,(dword_FF1130).l
	moveq	#0,d0
	move.w	(dword_FF1130).l,d0
	move.b	(p1_ctrl_press).l,d0
	or.b	(p2_ctrl_press).l,d0
	andi.b	#$F0,d0
	beq.s	loc_F0B8
	clr.b	(bytecode_disabled).l
	clr.b	(bytecode_flag).l
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_F0B8:
	tst.b	(opponent).l
	bne.w	locret_F0F2
	clr.b	(bytecode_disabled).l
	move.b	(byte_FF1970).l,d0
	addq.b	#1,d0
	move.b	d0,(bytecode_flag).l
	andi.b	#1,d0
	move.b	d0,(byte_FF1970).l
	cmpi.b	#2,(bytecode_flag).l
	beq.s	loc_F0F4
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

locret_F0F2:
	rts
; ---------------------------------------------------------------------------

loc_F0F4:
	moveq	#0,d0
	move.b	(byte_FF1971).l,d0
	addq.b	#1,d0
	andi.b	#3,d0
	move.b	d0,(byte_FF1971).l
	addq.b	#3,d0
	move.b	d0,(level).l
	move.b	d0,(level).l
	lea	(byte_F12A).l,a1
	move.b	(a1,d0.w),(opponent).l
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------
byte_F12A:
	dc.b OPP_SKELETON	; Puyo Puyo leftover
	dc.b OPP_NASU_GRAVE	; Puyo Puyo leftover
	dc.b OPP_MUMMY		; Puyo Puyo leftover
	dc.b OPP_ARMS
	dc.b OPP_FRANKLY
	dc.b OPP_HUMPTY
	dc.b OPP_COCONUTS
	dc.b OPP_DAVY
	dc.b OPP_SKWEEL
	dc.b OPP_DYNAMIGHT
	dc.b OPP_GROUNDER
	dc.b OPP_SPIKE
	dc.b OPP_SIR_FFUZZY
	dc.b OPP_DRAGON
	dc.b OPP_SCRATCH
	dc.b OPP_ROBOTNIK

; =============== S U B	R O U T	I N E =======================================

sub_F13A:
	movem.l	d0-a6,-(sp)
	lea	(word_F456).l,a2
	lea	(off_F41E).l,a3
	moveq	#$D,d6

loc_F14C:
	movea.l	(a3)+,a1
	jsr	(FindActorSlot).l
	bcs.s	loc_F18A
	move.b	#$80,6(a1)
	move.b	#$40,8(a1)
	move.w	(a2)+,$A(a1)
	move.w	(a2)+,d2
	tst.b	(use_lair_assets).l
	beq.s	loc_F174
	addi.w	#-$E0,d2

loc_F174:
	move.w	d2,$E(a1)
	move.b	(a2)+,9(a1)
	move.b	(a2)+,$22(a1)
	move.l	(a2)+,$32(a1)
	move.w	#0,$26(a1)

loc_F18A:
	dbf	d6,loc_F14C
	lea	(sub_F1AE).l,a1
	jsr	(FindActorSlotQuick).l
	bcs.s	loc_F1A8
	move.w	#0,$26(a1)
	move.w	#0,$28(a1)

loc_F1A8:
	movem.l	(sp)+,d0-a6
	rts
; End of function sub_F13A


; =============== S U B	R O U T	I N E =======================================

sub_F1AE:
	addq.w	#1,$26(a0)
	move.w	$26(a0),d0
	andi.w	#1,d0
	bne.s	locret_F214
	addq.w	#1,$28(a0)
	DISABLE_INTS
	movem.l	d0-a6,-(sp)
	lea	VDP_DATA,a4
	move.w	$28(a0),d0
	andi.w	#$F,d0
	asl.w	#3,d0
	move.w	#$5E74,d5
	jsr	(SetVRAMWrite).l
	move.w	word_F216(pc,d0.w),(a4)
	move.w	word_F218(pc,d0.w),(a4)
	move.w	word_F216(pc,d0.w),(a4)
	move.w	word_F218(pc,d0.w),(a4)
	move.w	#$5E94,d5
	jsr	(SetVRAMWrite).l
	move.w	word_F21A(pc,d0.w),(a4)
	move.w	word_F21C(pc,d0.w),(a4)
	move.w	word_F21A(pc,d0.w),(a4)
	move.w	word_F21C(pc,d0.w),(a4)
	movem.l	(sp)+,d0-a6
	ENABLE_INTS

locret_F214:
	rts
; End of function sub_F1AE

; ---------------------------------------------------------------------------
word_F216:	dc.w $BB77

word_F218:	dc.w $7777

word_F21A:	dc.w $7777

word_F21C:	dc.w $7777
	dc.w $7BB7
	dc.w $7777
	dc.w $7777
	dc.w $7777
	dc.w $77BB
	dc.w $7777
	dc.w $7777
	dc.w $7777
	dc.w $777B
	dc.w $B777
	dc.w $7777
	dc.w $7777
	dc.w $7777
	dc.w $BB77
	dc.w $7777
	dc.w $7777
	dc.w $7777
	dc.w $7BB7
	dc.w $7777
	dc.w $7777
	dc.w $7777
	dc.w $77BB
	dc.w $7777
	dc.w $7777
	dc.w $7777
	dc.w $777B
	dc.w $B777
	dc.w $7777
	dc.w $7777
	dc.w $7777
	dc.w $BB77
	dc.w $7777
	dc.w $7777
	dc.w $7777
	dc.w $7BB7
	dc.w $7777
	dc.w $7777
	dc.w $7777
	dc.w $77BB
	dc.w $7777
	dc.w $7777
	dc.w $7777
	dc.w $777B
	dc.w $B777
	dc.w $7777
	dc.w $7777
	dc.w $7777
	dc.w $BB77
	dc.w $7777
	dc.w $7777
	dc.w $7777
	dc.w $7BB7
	dc.w $7777
	dc.w $7777
	dc.w $7777
	dc.w $77BB
	dc.w $B777
	dc.w $7777
	dc.w $7777
	dc.w $777B
; ---------------------------------------------------------------------------

loc_F296:
	jmp	(ActorAnimate).l
; ---------------------------------------------------------------------------
	rts
; ---------------------------------------------------------------------------

loc_F29E:
	subq.w	#1,$26(a0)
	bpl.s	locret_F2FE
	jsr	(Random).l
	andi.w	#$F,d0
	addi.w	#$F,d0
	move.w	d0,$26(a0)
	lea	(loc_F300).l,a1
	jsr	(FindActorSlot).l
	bcs.s	locret_F2FE
	move.w	$A(a0),$A(a1)
	move.w	$E(a0),$E(a1)
	move.w	#$78,$26(a1)
	move.b	#$B3,6(a1)
	move.b	#$40,8(a1)
	move.b	#$2E,9(a1)
	move.b	#2,$22(a1)
	move.l	#unk_F4EA,$32(a1)
	move.l	#$FFFF8000,$16(a1)

locret_F2FE:
	rts
; ---------------------------------------------------------------------------

loc_F300:
	move.b	#$BF,6(a0)
	jsr	(sub_3810).l
	jsr	(ActorAnimate).l
	subq.w	#1,$26(a0)
	bpl.s	locret_F2FE
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_F31E:
	addq.w	#1,$26(a0)
	move.w	$26(a0),d0
	andi.w	#$7F,d0
	bne.s	locret_F38C
	lea	(loc_F38E).l,a1
	jsr	(FindActorSlot).l
	bcs.s	locret_F38C
	move.w	$A(a0),$A(a1)
	move.w	$E(a0),$E(a1)
	move.w	#0,$12(a1)
	move.w	#$8000,$14(a1)
	move.w	#$96,$26(a1)
	move.b	#$40,8(a1)
	move.b	#8,$22(a1)
	move.b	#$23,9(a1)
	move.l	#unk_F56E,$32(a1)
	jsr	(Random).l
	andi.b	#1,d0
	beq.s	locret_F38C
	move.b	#$25,9(a1)
	move.l	#unk_F57C,$32(a1)

locret_F38C:
	rts
; ---------------------------------------------------------------------------

loc_F38E:
	move.b	#$83,6(a0)
	jsr	(sub_3810).l
	jsr	(ActorAnimate).l
	subq.w	#1,$26(a0)
	bpl.s	locret_F38C
	move.w	#$10E,$26(a0)
	jsr	(ActorBookmark).l
	jsr	(sub_3810).l
	jsr	(ActorAnimate).l
	subq.w	#1,$26(a0)
	bpl.s	locret_F38C
	move.l	#unk_F58A,$32(a0)
	move.w	#$F0,$26(a0)
	jsr	(ActorBookmark).l
	jsr	(sub_3810).l
	jsr	(ActorAnimate).l
	subq.w	#1,$26(a0)
	bpl.s	locret_F38C
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------
	move.l	#unk_F58A,$32(a0)
	move.w	#$96,$26(a0)
	jsr	(ActorBookmark).l
	jsr	(sub_3810).l
	jsr	(ActorAnimate).l
	subq.w	#1,$26(a0)
	bpl.w	locret_F38C
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------
off_F41E:
	dc.l loc_F29E
	dc.l loc_F296
	dc.l loc_F296
	dc.l loc_F296
	dc.l loc_F296
	dc.l loc_F296
	dc.l loc_F296
	dc.l loc_F296
	dc.l loc_F296
	dc.l loc_F296
	dc.l loc_F296
	dc.l loc_F296
	dc.l loc_F296
	dc.l loc_F31E
; TODO: Document Animation Code

word_F456:
	dc.w $164
	dc.w $A8
	dc.b 0
	dc.b 1
	dc.l unk_F4EA
	dc.w $110
	dc.w $130
	dc.b $36
	dc.b $10
	dc.l unk_F55C
	dc.w $17E
	dc.w $A0
	dc.b $19
	dc.b $30
	dc.l unk_F53C
	dc.w $EF
	dc.w $B3
	dc.b 1
	dc.b $20
	dc.l unk_F500
	dc.w $AC
	dc.w $BD
	dc.b 5
	dc.b $10
	dc.l unk_F512
	dc.w $BC
	dc.w $BA
	dc.b 6
	dc.b $28
	dc.l unk_F512
	dc.w $CE
	dc.w $BD
	dc.b 7
	dc.b $42
	dc.l unk_F512
	dc.w $13E
	dc.w $CD
	dc.b 6
	dc.b 8
	dc.l unk_F512
	dc.w $1A6
	dc.w $CD
	dc.b 5
	dc.b $15
	dc.l unk_F512
	dc.w $F2
	dc.w $C7
	dc.b $16
	dc.b $30
	dc.l unk_F51E
	dc.w $152
	dc.w $A0
	dc.b $10
	dc.b $20
	dc.l unk_F52C
	dc.w $1BA
	dc.w $A0
	dc.b $12
	dc.b $10
	dc.l unk_F52C
	dc.w $130
	dc.w $A8
	dc.b 0
	dc.b $30
	dc.l unk_F548
	dc.w $80
	dc.w $FC
	dc.b 0
	dc.b 1
	dc.l unk_F4E2

unk_F4E2:
	dc.b   1
	dc.b   0
	dc.b $FF
	dc.b   0
	dc.l unk_F4E2

unk_F4EA:
	dc.b   2
	dc.b $2E
	dc.b   3
	dc.b $2F
	dc.b   2
	dc.b $30
	dc.b   3
	dc.b $31
	dc.b   2
	dc.b $32
	dc.b   3
	dc.b $33
	dc.b   2
	dc.b $34
	dc.b   3
	dc.b $35
	dc.b $FF
	dc.b   0
	dc.l unk_F4EA

unk_F500:
	dc.b   3
	dc.b   4
	dc.b   4
	dc.b   1
	dc.b   5
	dc.b   2
	dc.b   3
	dc.b   3
	dc.b   4
	dc.b   2
	dc.b   5
	dc.b   1
	dc.b $FF
	dc.b   0
	dc.l unk_F500

unk_F512:
	dc.b   3
	dc.b   5
	dc.b   4
	dc.b   6
	dc.b   5
	dc.b   7
	dc.b $FF
	dc.b   0
	dc.l unk_F512

unk_F51E:
	dc.b   3
	dc.b $16
	dc.b   4
	dc.b $17
	dc.b   5
	dc.b $18
	dc.b   7
	dc.b $17
	dc.b $FF
	dc.b   0
	dc.l unk_F51E

unk_F52C:
	dc.b   3
	dc.b $10
	dc.b   4
	dc.b $11
	dc.b   5
	dc.b $12
	dc.b   4
	dc.b $13
	dc.b   5
	dc.b $14
	dc.b $FF
	dc.b   0
	dc.l unk_F52C

unk_F53C:
	dc.b   3
	dc.b $19
	dc.b   4
	dc.b $1A
	dc.b   5
	dc.b $1B
	dc.b $FF
	dc.b   0
	dc.l unk_F53C

unk_F548:
	dc.b   3
	dc.b $1C
	dc.b   3
	dc.b $1D
	dc.b   3
	dc.b $1E
	dc.b   3
	dc.b $1F
	dc.b   3
	dc.b $20
	dc.b   3
	dc.b $21
	dc.b $3C
	dc.b   0
	dc.b $FF
	dc.b   0
	dc.l unk_F548

unk_F55C:
	dc.b $1E
	dc.b $36
	dc.b $1C
	dc.b $37
	dc.b $32
	dc.b $38
	dc.b  $A
	dc.b $37
	dc.b $14
	dc.b $36
	dc.b $14
	dc.b $37
	dc.b $FF
	dc.b   0
	dc.l unk_F55C

unk_F56E:
	dc.b   7
	dc.b $22
	dc.b   8
	dc.b $23
	dc.b   7
	dc.b $24
	dc.b   8
	dc.b $23
	dc.b $FF
	dc.b   0
	dc.l unk_F56E

unk_F57C:
	dc.b   6
	dc.b $25
	dc.b   7
	dc.b $26
	dc.b   5
	dc.b $27
	dc.b   7
	dc.b $26
	dc.b $FF
	dc.b   0
	dc.l unk_F57C

unk_F58A:
	dc.b   7
	dc.b $28
	dc.b   8
	dc.b $29
	dc.b   7
	dc.b $2A
	dc.b   8
	dc.b $2B
	dc.b   7
	dc.b $2C
	dc.b   8
	dc.b $2D
	dc.b $FF
	dc.b   0
	dc.l unk_F58A

; ---------------------------------------------------------------------------
	rts
; ---------------------------------------------------------------------------
	rts
; ---------------------------------------------------------------------------

LoadLevelIntroArt:
	tst.b	(use_lair_assets).l
	bne.s	LevelIntro_LairBGLoad
	clr.w	d0
	move.b	(level).l, d0	
	add.w	d0,d0
	add.w	d0,d0
	jmp CutsceneBGIDs(pc,d0.w)

; ---------------------------------------------------------------------------

CutsceneBGIDs:
	bra.w	LevelIntro_Vanilla
	bra.w	LevelIntro_Vanilla
	bra.w	LevelIntro_Vanilla
	bra.w	LevelIntro_Vanilla
	bra.w	LevelIntro_Vanilla
	bra.w	LevelIntro_Vanilla
	bra.w	LevelIntro_Vanilla
	bra.w	LevelIntro_Vanilla
	bra.w	LevelIntro_Vanilla
	bra.w	LevelIntro_Vanilla
	bra.w	LevelIntro_Vanilla
	bra.w	LevelIntro_Vanilla
	bra.w	LevelIntro_Vanilla
	bra.w	LevelIntro_Vanilla
	bra.w	LevelIntro_Vanilla
	bra.w	LevelIntro_LairBGLoad

; ---------------------------------------------------------------------------

LevelIntro_LairBGLoad:
	lea	(ArtNem_Intro).l,a0
	move.w	#$4000,d0
	DISABLE_INTS
	jsr	(NemDec).l
	ENABLE_INTS
	lea	(ArtNem_IntroBadniks).l,a0
	move.w	#$1200,d0
	bra.w	NemDec_Safe

; ---------------------------------------------------------------------------

LevelIntro_Vanilla:
	lea	(ArtNem_LvlIntroBG).l,a0
	move.w	#$2000,d0
	bra.w	NemDec_Safe

; ---------------------------------------------------------------------------

; << Input your custom cutscene background art here >>
;	Example
;LevelIntro_GHZ:
;	lea	(ArtNem_GHZIntroBG).l,a0	; Art File
;	move.w	#$2000,d0			; VRAM Location
;	bra.w	NemDec_Safe

; ---------------------------------------------------------------------------

; =============== S U B	R O U T	I N E =======================================

LoadEndingBGArt:
	lea	(ArtNem_EndingBG).l,a0
	move.w	#$4000,d0

NemDec_Safe:
	DISABLE_INTS
	jsr	(NemDec).l
	ENABLE_INTS
	rts
; End of function LoadEndingBGArt

; =============== S U B	R O U T	I N E =======================================

sub_F5F6:
	tst.b	(use_lair_assets).l
	bne.s	LevelIntroMaps_LairMachine
	clr.w	d0
	move.b	(level).l,d0
	add.w	d0,d0
	add.w	d0,d0
	jmp	@loadcutscenemaps(pc,d0.w)

@loadcutscenemaps:
	bra.w	LevelIntroMaps_Vanilla1
	bra.w	LevelIntroMaps_Vanilla1
	bra.w	LevelIntroMaps_Vanilla1
	bra.w	LevelIntroMaps_Vanilla1
	bra.w	LevelIntroMaps_Vanilla1
	bra.w	LevelIntroMaps_Vanilla1
	bra.w	LevelIntroMaps_Vanilla1
	bra.w	LevelIntroMaps_Vanilla1
	bra.w	LevelIntroMaps_Vanilla1
	bra.w	LevelIntroMaps_Vanilla1
	bra.w	LevelIntroMaps_Vanilla1
	bra.w	LevelIntroMaps_Vanilla1
	bra.w	LevelIntroMaps_Vanilla1
	bra.w	LevelIntroMaps_Vanilla1
	bra.w	LevelIntroMaps_Vanilla1
	bra.w	LevelIntroMaps_LairMachine

; ---------------------------------------------------------------------------

LevelIntroMaps_LairMachine:
	lea	(MapEni_LairMachine).l,a0
	lea	($D200).l,a1
	move.w	#$200,d0
	move.w	#$27,d1
	move.w	#$12,d2
	lea	(MapPrio_LairMachine).l,a3
	bra.w	EniDec_PrioMap_Safe

; ---------------------------------------------------------------------------

LevelIntroMaps_Vanilla1:
	lea	($D200).l,a1
	lea	(MapEni_LvlIntroBG_0).l,a0
	move.w	#$8100,d0
	move.w	#$27,d1
	move.w	#$1B,d2
	bra.w	EniDec_Safe

; ---------------------------------------------------------------------------

; << Input the initial loaded custom cutscene foreground here >>
;	Example
;LevelIntroMaps_GHZ1:
;	lea	($D200).l,a1			; Position on the plane map
;	lea	(MapEni_GHZIntroBG_0).l,a0	; Mappings File to Use
;	move.w	#$8100,d0			; Leave this as $8100
;	move.w	#$27,d1				; Tile width - 1
;	move.w	#$1B,d2				; Tile Height - 1
;	bra.w	EniDec_Safe			; Call to the Enigma Decompression Routine

; =============== S U B	R O U T	I N E =======================================

sub_F640:
	tst.b	(use_lair_assets).l
	bne.s	LevelIntroMaps_LairWall
	clr.w	d0
	move.b	(level).l,d0
	add.w	d0,d0
	add.w	d0,d0
	jmp	@loadcutscenemaps2(pc,d0.w)

@loadcutscenemaps2:
	bra.w	LevelIntroMaps_Vanilla2
	bra.w	LevelIntroMaps_Vanilla2
	bra.w	LevelIntroMaps_Vanilla2
	bra.w	LevelIntroMaps_Vanilla2
	bra.w	LevelIntroMaps_Vanilla2
	bra.w	LevelIntroMaps_Vanilla2
	bra.w	LevelIntroMaps_Vanilla2
	bra.w	LevelIntroMaps_Vanilla2
	bra.w	LevelIntroMaps_Vanilla2
	bra.w	LevelIntroMaps_Vanilla2
	bra.w	LevelIntroMaps_Vanilla2
	bra.w	LevelIntroMaps_Vanilla2
	bra.w	LevelIntroMaps_Vanilla2
	bra.w	LevelIntroMaps_Vanilla2
	bra.w	LevelIntroMaps_Vanilla2
	bra.w	LevelIntroMaps_LairWall

LevelIntroMaps_LairWall:
	lea	(MapEni_LairWall).l,a0
	lea	($F600).l,a1
	move.w	#$6200,d0
	move.w	#$27,d1
	move.w	#$12,d2
	bra.w	EniDec_Safe

; ---------------------------------------------------------------------------

LevelIntroMaps_Vanilla2:
	lea	($F600).l,a1
	lea	(MapEni_LvlIntroBG_1).l,a0
	move.w	#$2100,d0
	move.w	#$1F,d1
	move.w	#$A,d2
	bra.w	EniDec_Safe
; ---------------------------------------------------------------------------

; << Input the initial loaded custom cutscene upper background here >>
;	Example
;LevelIntroMaps_GHZ2:
;	lea	($F580).l,a1			; Position on plane layer
;	lea	(MapEni_GHZIntroBG_1).l,a0	; Mapping File
;	move.w	#$2100,d0			; Leave this as $2100
;	move.w	#$1F,d1				; Tile Width - 1
;	move.w	#$A,d2				; Tile Height - 1
;	bra.w	EniDec_Safe			; Call to the Enigma Decompression Routine


; =============== S U B	R O U T	I N E =======================================


sub_F680:
	tst.b	(use_lair_assets).l
	bne.s	LevelIntroMaps_LairFloor
	clr.w	d0
	move.b	(level).l,d0
	add.w	d0,d0
	add.w	d0,d0
	jmp	@loadcutscenemaps3(pc,d0.w)

@loadcutscenemaps3:
	bra.w	LevelIntroMaps_Vanilla3
	bra.w	LevelIntroMaps_Vanilla3
	bra.w	LevelIntroMaps_Vanilla3
	bra.w	LevelIntroMaps_Vanilla3
	bra.w	LevelIntroMaps_Vanilla3
	bra.w	LevelIntroMaps_Vanilla3
	bra.w	LevelIntroMaps_Vanilla3
	bra.w	LevelIntroMaps_Vanilla3
	bra.w	LevelIntroMaps_Vanilla3
	bra.w	LevelIntroMaps_Vanilla3
	bra.w	LevelIntroMaps_Vanilla3
	bra.w	LevelIntroMaps_Vanilla3
	bra.w	LevelIntroMaps_Vanilla3
	bra.w	LevelIntroMaps_Vanilla3
	bra.w	LevelIntroMaps_Vanilla3
	bra.w	LevelIntroMaps_LairFloor

; ---------------------------------------------------------------------------

LevelIntroMaps_LairFloor:
	lea	(MapEni_LairFloor).l,a0
	lea	($DB80).l,a1
	move.w	#$200,d0
	move.w	#$27,d1
	move.w	#8,d2
	bra.w	EniDec_Safe

; ---------------------------------------------------------------------------

LevelIntroMaps_Vanilla3:
	lea	($F5C0).l,a1
	lea	(MapEni_LvlIntroBG_1).l,a0
	move.w	#$2100,d0
	move.w	#$1F,d1
	move.w	#$A,d2
	bra.w	EniDec_Safe

; ---------------------------------------------------------------------------

; << Input the extra custom cutscene upper background here >>
;	Example
;LevelIntroMaps_GHZ3:
;	lea	($F5C0).l,a1			; Position on plane layer
;	lea	(MapEni_GHZIntroBG_1).l,a0	; Mapping File
;	move.w	#$2100,d0			; Leave this as $2100
;	move.w	#$1F,d1				; Tile Width - 1
;	move.w	#$A,d2				; Tile Height - 1
;	bra.w	EniDec_Safe			; Call to the Enigma Decompression Routine

; =============== S U B	R O U T	I N E =======================================

sub_F6C0:
	tst.b	(use_lair_assets).l
	bne.s	LevelIntroMaps_LairCancel
	clr.w	d0
	move.b	(level).l,d0
	add.w	d0,d0
	add.w	d0,d0
	jmp	@loadcutscenemaps4(pc,d0.w)

@loadcutscenemaps4:
	bra.w	LevelIntroMaps_Vanilla4
	bra.w	LevelIntroMaps_Vanilla4
	bra.w	LevelIntroMaps_Vanilla4
	bra.w	LevelIntroMaps_Vanilla4
	bra.w	LevelIntroMaps_Vanilla4
	bra.w	LevelIntroMaps_Vanilla4
	bra.w	LevelIntroMaps_Vanilla4
	bra.w	LevelIntroMaps_Vanilla4
	bra.w	LevelIntroMaps_Vanilla4
	bra.w	LevelIntroMaps_Vanilla4
	bra.w	LevelIntroMaps_Vanilla4
	bra.w	LevelIntroMaps_Vanilla4
	bra.w	LevelIntroMaps_Vanilla4
	bra.w	LevelIntroMaps_Vanilla4
	bra.w	LevelIntroMaps_Vanilla4
	bra.w	LevelIntroMaps_LairCancel

; ---------------------------------------------------------------------------

LevelIntroMaps_Vanilla4:
	lea	($FB80).l,a1
	lea	(MapEni_LvlIntroBG_2).l,a0
	move.w	#$2100,d0
	move.w	#$27,d1
	move.w	#$A,d2
	bra.w	EniDec_Safe2

LevelIntroMaps_LairCancel:
	rts

; ---------------------------------------------------------------------------
; << Input the initial loaded custom cutscene lower background here >>
;	Example
;LevelIntroMaps_GHZ4:
;	lea	($FB00).l,a1			; Position on plane layer
;	lea	(MapEni_GHZIntroBG_2).l,a0	; Mapping File
;	move.w	#$2100,d0			; Leave this as $2100
;	move.w	#$27,d1				; Tile Width - 1
;	move.w	#$A,d2				; Tile Height - 1
;	bra.w	EniDec_Safe2			; Call to the Enigma Decompression Routine
;	rts

; =============== S U B	R O U T	I N E =======================================

LoadMainMenuMap:
	lea	($C306).l,a1
	lea	(MapEni_MainMenu).l,a0
	move.w	#$E190,d0
	move.w	#$21,d1
	move.w	#$13,d2
	bra.w	EniDec_Safe
; End of function LoadMainMenuMap

; =============== S U B	R O U T	I N E =======================================

LoadScenarioMenuMap:
	lea	($C65E).l,a1
	lea	(MapEni_ScenarioMenu).l,a0
	move.w	#$E190,d0
	move.w	#$19,d1
	move.w	#$B,d2
	bra.w	EniDec_Safe
; End of function LoadScenarioMenuMap

; =============== S U B	R O U T	I N E =======================================

sub_F71E:
	lea	($C000).l,a1
	lea	(MapEni_GameOverRobots).l,a0
	move.w	#$2A0,d0
	move.w	#$27,d1
	move.w	#$1B,d2
	lea	(byte_6A144).l,a3
	bra.w	EniDec_PrioMap_Safe
; End of function sub_F71E

; =============== S U B	R O U T	I N E =======================================

sub_F740:
	lea	($E000).l,a1
	lea	(MapEni_GameOverLight).l,a0
	move.w	#$22A0,d0
	move.w	#$27,d1
	move.w	#$E,d2
	bra.w	EniDec_Safe
; End of function sub_F740

; =============== S U B	R O U T	I N E =======================================

sub_F75C:
	lea	($E000).l,a1
	lea	(MapEni_HighScores).l,a0
	move.w	#$6280,d0
	move.w	#$27,d1
	move.w	#$1B,d2
; End of function sub_F75C

; =============== S U B	R O U T	I N E =======================================

EniDec_Safe:
	DISABLE_INTS
	jsr	(EniDec).l
	ENABLE_INTS
	rts
; End of function EniDec_Safe

; ---------------------------------------------------------------------------
; START	OF FUNCTION CHUNK FOR sub_F5F6

EniDec_PrioMap_Safe:
	DISABLE_INTS
	jsr	(EniDecPrioMap).l
	ENABLE_INTS
	rts
; END OF FUNCTION CHUNK	FOR sub_F5F6

; =============== S U B	R O U T	I N E =======================================

sub_F794:
	move.l	a0,-(sp)
	lea	($F600).l,a1
	lea	(MapEni_CreditsSky).l,a0
	move.w	#$4000,d0
	move.w	#$27,d1
	move.w	#9,d2
	bsr.s	EniDec_Safe
	move.l	(sp)+,a0
	rts
; End of function sub_F794

; =============== S U B	R O U T	I N E =======================================

sub_F7B8:
	move.l	a0,-(sp)
	lea	(ArtNem_CreditsSky).l,a0
	moveq	#0,d0
	jsr	(NemDec).l
	move.l	(sp)+,a0
	rts
; End of function sub_F7B8

; =============== S U B	R O U T	I N E =======================================

LoadMainMenuMountains:
	lea	($F300).l,a1
	lea	(MapEni_MainMenuMountains).l,a0
	move.w	#$2190,d0
	move.w	#$27,d1
	move.w	#9,d2
	bra.w	EniDec_Safe2
; ---------------------------------------------------------------------------

LoadMainMenuClouds1:
	lea	($E000).l,a1
	bra.w	LoadMainMenuClouds
; ---------------------------------------------------------------------------

LoadMainMenuClouds2:
	lea	($E040).l,a1
	bra.w	LoadMainMenuClouds
; ---------------------------------------------------------------------------

LoadMainMenuClouds3:
	lea	($E080).l,a1
	bra.w	LoadMainMenuClouds
; ---------------------------------------------------------------------------

LoadMainMenuClouds4:
	lea	($E0C0).l,a1

LoadMainMenuClouds:
	lea	(MapEni_MainMenuClouds).l,a0
	move.w	#$2190,d0
	move.w	#$1F,d1
	move.w	#$12,d2

EniDec_Safe2:
	DISABLE_INTS
	jsr	(EniDec).l
	ENABLE_INTS
	rts
; End of function LoadMainMenuMountains

; =============== S U B	R O U T	I N E =======================================

sub_F832:
	lea	(MapEni_LairDestroyed0).l,a0
	lea	($D200).l,a1
	bra.s	loc_F856
; ---------------------------------------------------------------------------

loc_F840:
	lea	(MapEni_LairDestroyed0).l,a0
	bra.w	loc_F850
; ---------------------------------------------------------------------------

LoadLairMachineMap:
	lea	(MapEni_LairMachine).l,a0

loc_F850:
	lea	($C000).l,a1

loc_F856:
	DISABLE_INTS
	move.w	#$200,d0
	move.w	#$27,d1
	move.w	#$12,d2
	lea	(MapPrio_LairMachine).l,a3
	jsr	(EniDecPrioMap).l
	ENABLE_INTS
	rts
; End of function sub_F832

; =============== S U B	R O U T	I N E =======================================

sub_F878:
	lea	(MapEni_LairDestroyed1).l,a0
	lea	($F600).l,a1
	bra.s	loc_F89A
; ---------------------------------------------------------------------------

loc_F886:
	lea	(MapEni_LairDestroyed1).l,a0
	bra.s	loc_F894
; ---------------------------------------------------------------------------

LoadLairWallMap:
	lea	(MapEni_LairWall).l,a0

loc_F894:
	lea	($E000).l,a1

loc_F89A:
	DISABLE_INTS
	move.w	#$6200,d0
	move.w	#$27,d1
	move.w	#$12,d2
	jsr	(EniDec).l
	ENABLE_INTS
	rts
; End of function sub_F878

; =============== S U B	R O U T	I N E =======================================

sub_F8B6:
	lea	(MapEni_LairDestroyed2).l,a0
	lea	($DB80).l,a1
	bra.s	loc_F8D8
; ---------------------------------------------------------------------------

loc_F8C4:
	lea	(MapEni_LairDestroyed2).l,a0
	bra.s	loc_F8D2
; ---------------------------------------------------------------------------

LoadLairFloorMap:
	lea	(MapEni_LairFloor).l,a0

loc_F8D2:
	lea	($E980).l,a1

loc_F8D8:
	DISABLE_INTS
	move.w	#$200,d0
	move.w	#$27,d1
	move.w	#8,d2
	jsr	(EniDec).l
	ENABLE_INTS
	rts
; End of function sub_F8B6

; =============== S U B	R O U T	I N E =======================================

sub_F8F4:
	moveq	#0,d0
	jmp	(QueuePlaneCmdList).l
; End of function sub_F8F4

; ---------------------------------------------------------------------------

; TODO: Change this to use a flag system for determining whether to load the lair in the BG or not

loc_F8FC:
	tst.b	(use_lair_assets).l
	bne.s	loc_F952
	lea	(loc_F942).l,a1
	jsr	(FindActorSlot).l
	bcs.s	locret_F940
	move.b	#$40,8(a1)
	move.b	#$39,9(a1)
	move.l	#Anim_CutsceneLair,$32(a1)
	move.b	#$80,6(a1)
	move.b	#$20,$22(a1)
	move.w	#$FFE0,$E(a1)
	move.w	#$F1,$A(a1)

locret_F940:
	rts

; ---------------------------------------------------------------------------

loc_F942:
	jmp	(ActorAnimate).l
; ---------------------------------------------------------------------------
	rts
; ---------------------------------------------------------------------------

Anim_CutsceneLair:
	dc.b   3
	dc.b $39
	dc.b $FF
	dc.b   0
	dc.l Anim_CutsceneLair
; ---------------------------------------------------------------------------

loc_F952:
	jmp	(sub_F13A).l
; ---------------------------------------------------------------------------

loc_F958:
	lea	(loc_F994).l,a1
	jsr	(FindActorSlot).l
	bcs.s	locret_F992
	move.b	#$40,8(a1)
	move.b	#$43,9(a1)
	move.l	#unk_F99C,$32(a1)
	move.b	#$80,6(a1)
	move.b	#$20,$22(a1)
	move.w	#$FFE0,$E(a1)
	move.w	#$F2,$A(a1)

locret_F992:
	rts
; ---------------------------------------------------------------------------

loc_F994:
	jmp	(ActorAnimate).l
; ---------------------------------------------------------------------------
	rts
; ---------------------------------------------------------------------------
; TODO: Document Animation Code

unk_F99C:
	dc.b   3
	dc.b $43
	dc.b $FF
	dc.b   0
	dc.l unk_F99C
; ---------------------------------------------------------------------------

loc_F9A4:
	lea	(loc_F9E0).l,a1
	jsr	(FindActorSlot).l
	bcs.s	locret_F9DE
	move.b	#$40,8(a1)
	move.b	#$44,9(a1)
	move.l	#unk_F9E8,$32(a1)
	move.b	#$80,6(a1)
	move.b	#3,$22(a1)
	move.w	#$FFC6,$E(a1)
	move.w	#$E2,$A(a1)

locret_F9DE:
	rts
; ---------------------------------------------------------------------------

loc_F9E0:
	jmp	(ActorAnimate).l
; ---------------------------------------------------------------------------
	rts
; ---------------------------------------------------------------------------
; TODO: Document Animation Code

unk_F9E8:
	dc.b   5
	dc.b $44
	dc.b   4
	dc.b $45
	dc.b   5
	dc.b $46
	dc.b   4
	dc.b $47
	dc.b   5
	dc.b $48
	dc.b $FF
	dc.b   0
	dc.l unk_F9E8
; ---------------------------------------------------------------------------

loc_F9F8:
	lea	(loc_FA04).l,a1
	jmp	(FindActorSlotQuick).l
; ---------------------------------------------------------------------------

loc_FA04:
	tst.b	(word_FF1126).l
	bne.w	locret_FA6C
	addq.w	#1,$26(a0)
	move.w	$26(a0),d0
	andi.w	#7,d0
	bne.s	locret_FA6C
	lea	(loc_FA6E).l,a1
	jsr	(FindActorSlot).l
	bcs.s	locret_FA6C
	move.b	#$40,8(a1)
	move.b	#$4F,9(a1)
	move.b	#$80,6(a1)
	move.b	#3,$22(a1)
	move.w	#0,$26(a1)
	jsr	(Random).l
	andi.w	#$1F,d0
	addi.w	#-$40,d0
	move.w	d0,$E(a1)
	jsr	(Random).l
	andi.w	#$1F,d0
	addi.w	#$E2,d0
	move.w	d0,$A(a1)

locret_FA6C:
	rts
; ---------------------------------------------------------------------------

loc_FA6E:
	tst.b	(word_FF1126).l
	bne.s	locret_FA98
	addq.w	#1,$28(a0)
	move.w	$28(a0),d1
	andi.w	#3,d1
	bne.s	locret_FA98
	moveq	#0,d0
	move.w	$26(a0),d0
	move.b	unk_FAA0(pc,d0.w),d0
	bmi.s	loc_FA9A
	move.b	d0,9(a0)
	addq.w	#1,$26(a0)

locret_FA98:
	rts
; ---------------------------------------------------------------------------

loc_FA9A:
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------
unk_FAA0:
	dc.b $4F
	dc.b $50
	dc.b $51
	dc.b $52
	dc.b $FF
	dc.b   0
	dc.b   0
	dc.b $7F
	dc.b   0
	dc.b $FF
	dc.b   1
	dc.b $FF
	dc.b   1
	dc.b $FF
; ---------------------------------------------------------------------------

loc_FAAE:
	move.w	#0,(word_FF1134).l
	move.w	#1,(word_FF1136).l
	lea	(loc_FBA0).l,a1
	jsr	(FindActorSlotQuick).l
	bcs.s	loc_FADA
	move.w	#$1E0,$26(a1)
	move.w	#$1FF,(dword_FF1130).l

loc_FADA:
	lea	(loc_FAE6).l,a1
	jmp	(FindActorSlotQuick).l
; ---------------------------------------------------------------------------

loc_FAE6:
	moveq	#0,d0
	move.l	d0,$26(a0)
	move.w	#$2D0,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark).l
	addi.w	#$80,$A(a0)
	addi.w	#$C0,$C(a0)
	addi.w	#$60,$E(a0)
	addi.w	#$100,$10(a0)
	move.b	$A(a0),d0
	lea	(unk_FCD6).l,a1
	bsr.w	sub_FB96
	move.w	(a1),(palette_buffer+$48).l
	move.b	$E(a0),d0
	lea	(unk_FCE6).l,a1
	bsr.w	sub_FB96
	move.w	(a1),(palette_buffer+$4C).l
	move.w	(dword_FF1130+2).l,d0
	lea	(unk_FD16).l,a1
	move.w	d0,d1
	asl.w	#3,d0
	add.w	d1,d1
	add.w	d1,d1
	add.w	d1,d0
	adda.w	d0,a1
	move.w	(a1)+,(palette_buffer+$46).l
	move.w	(a1)+,(palette_buffer+$54).l
	move.w	(a1)+,(palette_buffer+$58).l
	move.w	(a1)+,(palette_buffer+$5A).l
	move.w	(a1)+,(palette_buffer+$5C).l
	move.w	(a1)+,(palette_buffer+$5E).l
	lea	((palette_buffer+$40)).l,a2
	moveq	#2,d0
	jsr	(LoadPalette).l
	tst.w	(word_FF1134).l
	bne.s	loc_FB90
	rts
; ---------------------------------------------------------------------------

loc_FB90:
	jmp	(ActorDeleteSelf).l

; =============== S U B	R O U T	I N E =======================================

sub_FB96:
	andi.w	#7,d0
	add.w	d0,d0
	adda.w	d0,a1
	rts
; End of function sub_FB96

; ---------------------------------------------------------------------------

loc_FBA0:
	subq.w	#1,$26(a0)
	bpl.w	locret_FC98
	jsr	(ActorBookmark).l

loc_FBAE:
	jsr	(Random).l
	andi.w	#7,d0
	move.w	d0,(dword_FF1130+2).l
	jsr	(Random).l
	and.w	(dword_FF1130).l,d0
	addi.w	#$3C,d0
	move.w	d0,$26(a0)
	jsr	(ActorBookmark).l
	tst.w	(word_FF1134).l
	bne.w	loc_FC9A
	subq.w	#1,$26(a0)
	bpl.w	locret_FC98
	lea	(loc_FCA0).l,a1
	jsr	(FindActorSlot).l
	bcs.w	loc_FC92
	jsr	(Random).l
	andi.w	#$3F,d0
	subi.w	#$1F,d0
	addi.w	#$160,d0
	move.w	d0,$A(a1)
	jsr	(Random).l
	andi.w	#$1F,d0
	subi.w	#$F,d0
	addi.w	#-$50,d0
	move.w	d0,$E(a1)
	jsr	(Random).l
	andi.l	#3,d0
	add.w	d0,d0
	addi.l	#unk_FCBC,d0
	move.l	d0,$32(a1)
	move.b	#$40,8(a1)
	move.b	#$49,9(a1)
	move.b	#$80,6(a1)
	move.b	#1,$22(a1)
	move.w	#0,$26(a1)
	jsr	(Random).l
	andi.w	#$1FF,d0
	addi.w	#$100,d0
	move.w	d0,d1
	jsr	(Random).l
	andi.w	#$3F,d0
	addi.w	#$C9,d0
	move.w	d0,d7
	jsr	(Sin).l
	move.l	d2,$12(a1)
	move.w	d7,d0
	jsr	(Cos).l
	move.l	d2,$16(a1)

loc_FC92:
	jmp	(loc_FBAE).l
; ---------------------------------------------------------------------------

locret_FC98:
	rts
; ---------------------------------------------------------------------------

loc_FC9A:
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_FCA0:
	move.b	#$BF,6(a0)
	jsr	(sub_3810).l
	jsr	(ActorAnimate).l
	bcs.s	loc_FCB6
	rts
; ---------------------------------------------------------------------------

loc_FCB6:
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------
; TODO: Document Animation Code

unk_FCBC:
	dc.b   1
	dc.b $49
	dc.b   1
	dc.b $54
	dc.b   1
	dc.b $55
	dc.b   2
	dc.b $56
	dc.b   4
	dc.b $57
	dc.b   7
	dc.b $58
	dc.b   8
	dc.b $59
	dc.b   3
	dc.b $57
	dc.b   2
	dc.b $55
	dc.b   1
	dc.b $49
	dc.b $FF
	dc.b   0
	dc.l unk_FCBC

unk_FCD6:
	dc.b   4
	dc.b $22
	dc.b   2
	dc.b $22
	dc.b   4
	dc.b $22
	dc.b   4
	dc.b $42
	dc.b   4
	dc.b $22
	dc.b   4
	dc.b $24
	dc.b   4
	dc.b $22
	dc.b   4
	dc.b   2

unk_FCE6:
	dc.b   8
	dc.b $66
	dc.b   8
	dc.b $46
	dc.b   8
	dc.b $66
	dc.b  $A
	dc.b $64
	dc.b   8
	dc.b $66
	dc.b   8
	dc.b $46
	dc.b   8
	dc.b $66
	dc.b   8
	dc.b $64
	dc.b  $A
	dc.b   8
	dc.b  $A
	dc.b $28
	dc.b  $A
	dc.b   8
	dc.b  $A
	dc.b $28
	dc.b  $A
	dc.b   8
	dc.b  $A
	dc.b $28
	dc.b  $A
	dc.b   8
	dc.b  $A
	dc.b $28
	dc.b  $E
	dc.b $EE
	dc.b  $E
	dc.b $EC
	dc.b  $E
	dc.b $CE
	dc.b  $E
	dc.b $EE
	dc.b  $E
	dc.b $EC
	dc.b  $E
	dc.b $CE
	dc.b  $E
	dc.b $EE
	dc.b  $C
	dc.b $EE

unk_FD16:
	dc.b   4
	dc.b   0
	dc.b   6
	dc.b $40
	dc.b   8
	dc.b $64
	dc.b  $A
	dc.b $86
	dc.b  $C
	dc.b $A8
	dc.b  $E
	dc.b $EA
	dc.b   0
	dc.b $40
	dc.b   0
	dc.b $64
	dc.b   4
	dc.b $86
	dc.b   6
	dc.b $A8
	dc.b   8
	dc.b $CA
	dc.b  $A
	dc.b $EE
	dc.b   0
	dc.b   4
	dc.b   4
	dc.b   6
	dc.b   6
	dc.b $48
	dc.b   8
	dc.b $6A
	dc.b  $A
	dc.b $8C
	dc.b  $E
	dc.b $AE
	dc.b   4
	dc.b $40
	dc.b   6
	dc.b $64
	dc.b   8
	dc.b $86
	dc.b  $A
	dc.b $A8
	dc.b  $C
	dc.b $CA
	dc.b  $E
	dc.b $EC
	dc.b   0
	dc.b $44
	dc.b   4
	dc.b $66
	dc.b   6
	dc.b $88
	dc.b   8
	dc.b $AA
	dc.b  $A
	dc.b $CC
	dc.b  $C
	dc.b $EE
	dc.b   4
	dc.b   4
	dc.b   6
	dc.b $46
	dc.b   8
	dc.b $68
	dc.b  $A
	dc.b $8A
	dc.b  $C
	dc.b $AC
	dc.b  $E
	dc.b $CE
	dc.b   4
	dc.b   0
	dc.b   6
	dc.b   0
	dc.b   8
	dc.b $20
	dc.b  $A
	dc.b $40
	dc.b  $C
	dc.b $80
	dc.b  $E
	dc.b $E0
	dc.b   0
	dc.b $40
	dc.b   0
	dc.b $60
	dc.b   0
	dc.b $82
	dc.b   0
	dc.b $A4
	dc.b   0
	dc.b $C8
	dc.b   0
	dc.b $EE

; ---------------------------------------------------------------------------
	move.w	#$708,d0
	tst.b	(difficulty).l
	bne.s	locret_FDE6
	lea	(loc_FD94).l,a1
	jsr	(FindActorSlotQuick).l
	move.w	#$BB8,d0
	rts
; ---------------------------------------------------------------------------

loc_FD94:
	move.w	#0,(word_FF1136).l
	jsr	(ActorBookmark).l

loc_FDA2:
	lea	(loc_FE0C).l,a1
	jsr	(FindActorSlotQuick).l
	bcs.s	locret_FDE6
	move.w	(word_FF1136).l,d0
	move.w	d0,$28(a1)
	addq.w	#1,d0
	cmpi.w	#7,d0
	beq.s	loc_FDE8
	move.w	d0,(word_FF1136).l
	jsr	(Random).l
	andi.w	#$3F,d0
	addi.w	#$3F,d0
	move.w	d0,$26(a0)
	jsr	(ActorBookmark).l
	subq.w	#1,$26(a0)
	bmi.s	loc_FDA2

locret_FDE6:
	rts
; ---------------------------------------------------------------------------

loc_FDE8:
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------
unk_FDEE:
	dc.b   1
	dc.b $28

unk_FDF0:
	dc.b   0
	dc.b $E0
	dc.b   0
	dc.b $A0
	dc.b   0
	dc.b $B0
	dc.b   0
	dc.b $C0
	dc.b   0
	dc.b $C0
	dc.b   1
	dc.b   0
	dc.b   0
	dc.b $D0
	dc.b   1
	dc.b $40
	dc.b   0
	dc.b $B8
	dc.b   1
	dc.b $80
	dc.b   0
	dc.b $C8
	dc.b   1
	dc.b $B0
	dc.b   0
	dc.b $D8
	dc.b $FF
	dc.b $FF
; ---------------------------------------------------------------------------

loc_FE0C:
	move.l	#unk_FEFC,$32(a0)
	move.w	#$80,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark).l
	move.b	#$95,6(a0)
	move.b	#8,8(a0)
	move.b	#0,9(a0)
	move.w	$28(a0),d0
	asl.w	#2,d0
	move.w	unk_FDEE(pc,d0.w),$A(a0)
	move.w	unk_FDF0(pc,d0.w),$26(a0)
	move.w	#$FF90,$E(a0)
	move.w	#$FFFF,$20(a0)
	move.w	#$1000,$1C(a0)
	jsr	(ActorBookmark).l
	move.w	$1E(a0),$E(a0)
	jsr	(sub_3810).l
	jsr	(ActorAnimate).l
	move.w	$E(a0),$1E(a0)
	addi.w	#-$70,$E(a0)
	move.w	$1E(a0),d0
	cmp.w	$26(a0),d0
	bcc.s	loc_FE8C
	rts
; ---------------------------------------------------------------------------

loc_FE8C:
	move.l	#unk_FEE6,$32(a0)
	jsr	(Random).l
	andi.w	#3,d0
	asl.w	#6,d0
	addi.w	#$780,d0
	move.w	d0,$26(a0)
	move.b	#SFX_PUYO_LAND,d0
	jsr	(PlaySound_ChkPCM).l
	jsr	(ActorBookmark).l
	jsr	(ActorAnimate).l
	subq.w	#1,$26(a0)
	bpl.s	locret_FEE4
	move.l	#unk_FF2C,$32(a0)
	move.b	#$40,8(a0)
	move.b	#$64,9(a0)
	jsr	(ActorBookmark).l
	jmp	(ActorAnimate).l
; ---------------------------------------------------------------------------

locret_FEE4:
	rts
; ---------------------------------------------------------------------------
; TODO: Document Animation Code

unk_FEE6:
	dc.b   8
	dc.b   0
	dc.b   8
	dc.b   1
	dc.b  $C
	dc.b   2
	dc.b   8
	dc.b   1
	dc.b   8
	dc.b   0
	dc.b   8
	dc.b   3
	dc.b  $C
	dc.b   4
	dc.b   8
	dc.b   3
	dc.b $FF
	dc.b   0
	dc.l unk_FEE6

unk_FEFC:
	dc.b   1
	dc.b   5
	dc.b   1
	dc.b   6

unk_FF00:
	dc.b   1
	dc.b   7
	dc.b   1
	dc.b   8
	dc.b $FF
	dc.b   0
	dc.l unk_FEFC

unk_FF0A:
	dc.b $22
	dc.b $5B
	dc.b $26
	dc.b $5C
	dc.b $22
	dc.b $5B
	dc.b $26
	dc.b $5C
	dc.b $22
	dc.b $5B
	dc.b $30
	dc.b $5C
	dc.b   8
	dc.b $5D
	dc.b $20
	dc.b $5E
	dc.b   8
	dc.b $5F
	dc.b $FF
	dc.b   0
	dc.l unk_FF0A

unk_FF22:
	dc.b $18
	dc.b $60
	dc.b $18
	dc.b $61
	dc.b $FF
	dc.b   0
	dc.l unk_FF22

unk_FF2C:
	dc.b   8
	dc.b $64
	dc.b $10
	dc.b $63
	dc.b   4
	dc.b $65
	dc.b   4
	dc.b $66
	dc.b   4
	dc.b $65
	dc.b   4
	dc.b $66
	dc.b   4
	dc.b $65
	dc.b   4
	dc.b $66
	dc.b   2
	dc.b $65
	dc.b   2
	dc.b $66
	dc.b   8
	dc.b $63
	dc.b $10
	dc.b $64
	dc.b $FF
	dc.b   0
	dc.l unk_FF22

; =============== S U B	R O U T	I N E =======================================

sub_FF4A:
	lea	(loc_FFBE).l,a1
	jsr	(FindActorSlot).l
	bcc.s	loc_FF5C
	rts
; ---------------------------------------------------------------------------

loc_FF5C:
	move.l	d1,-(sp)
	lsl.w	#2,d0
	move.w	d0,d1
	cmpi.w	#$20,d1
	bcs.s	loc_FF70
	move.w	#$1C,d1

loc_FF70:
	lea	(unk_FF9E).l,a2
	move.w	(a2,d1.w),$28(a1)
	move.w	2(a2,d1.w),$2A(a1)
	move.l	(sp)+,d1
	move.b	#$69,8(a1)
	lea	(off_1007A).l,a2
	move.l	(a2,d0.w),$32(a1)
	move.l	a0,$2E(a1)
	rts
; End of function sub_FF4A

; ---------------------------------------------------------------------------
unk_FF9E:
	dc.b   0
	dc.b $80
	dc.b   0
	dc.b   1
	dc.b   0
	dc.b $80
	dc.b   0
	dc.b   1
	dc.b   0
	dc.b $80
	dc.b   0
	dc.b   1
	dc.b   0
	dc.b $80
	dc.b   0
	dc.b   1
	dc.b   0
	dc.b $80
	dc.b   0
	dc.b   0
	dc.b   1
	dc.b   0
	dc.b   0
	dc.b   3
	dc.b   1
	dc.b   0
	dc.b   0
	dc.b   1
	dc.b   0
	dc.b $80
	dc.b   0
	dc.b   1
; ---------------------------------------------------------------------------

loc_FFBE:
	tst.w	$26(a0)
	beq.s	loc_FFCC
	subq.w	#1,$26(a0)
	rts
; ---------------------------------------------------------------------------

loc_FFCC:
	movea.l	$32(a0),a1
	move.w	(a1)+,d0
	cmpi.b	#$FF,-2(a1)
	beq.s	loc_10006
	move.l	a1,$32(a0)
	bsr.w	sub_10058
	addq.b	#1,(byte_FF1129).l
	move.b	(byte_FF1129).l,d0
	andi.b	#1,d0
	bne.s	loc_FFFE
	move.b	8(a0),d0
	bsr.w	PlaySound_ChkPCM

loc_FFFE:
	move.w	$2A(a0),$26(a0)
	rts
; ---------------------------------------------------------------------------

loc_10006:
	andi.w	#$FF,d0
	move.w	(a1)+,d1

loc_1000C:
	move.l	a1,$32(a0)
	movea.l	off_10016(pc,d0.w),a1
	jmp	(a1)
; ---------------------------------------------------------------------------
off_10016:
	dc.l loc_10038
	dc.l loc_1003E

off_1001E:
	dc.l loc_10044
	dc.l loc_1004A

off_10026:
	dc.l loc_1002E
	dc.l loc_10052
; ---------------------------------------------------------------------------

loc_1002E:
	movea.l	$2E(a0),a1
	move.b	d1,7(a1)
	rts
; ---------------------------------------------------------------------------

loc_10038:
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_1003E:
	move.w	d1,$26(a0)
	rts
; ---------------------------------------------------------------------------

loc_10044:
	move.w	d1,$12(a0)
	rts
; ---------------------------------------------------------------------------

loc_1004A:
	move.w	d1,d0

loc_1004C:
	jmp	(QueuePlaneCmdList).l
; ---------------------------------------------------------------------------

loc_10052:
	move.b	d1,8(a0)
	rts

; =============== S U B	R O U T	I N E =======================================

sub_10058:
	DISABLE_INTS
	eori.w	#$8000,d0
	move.w	$12(a0),d5
	jsr	(SetVRAMWrite).l
	move.w	d0,VDP_DATA
	ENABLE_INTS
	addq.w	#2,$12(a0)
	rts
; End of function sub_10058

; ---------------------------------------------------------------------------
off_1007A:
	dc.l unk_1046E
	dc.l unk_1046E
	dc.l unk_1046E
	dc.l unk_1046E
	dc.l unk_1046E
	dc.l unk_1046E
	dc.l unk_10474
	dc.l unk_100E4
	dc.l unk_1015A
	dc.l unk_101EC
	dc.l unk_10238
	dc.l unk_102A4
	dc.l unk_10310
	dc.l unk_10380
	dc.l unk_10382
	dc.l 0
	dc.l unk_100D6
	dc.l unk_100D8
	dc.l unk_100DA
	dc.l unk_100DC
	dc.l unk_100DE
	dc.l unk_100E0
	dc.l unk_100E2

unk_100D6:
	dc.b $FF
	dc.b   0

unk_100D8:
	dc.b $FF
	dc.b   0

unk_100DA:
	dc.b $FF
	dc.b   0

unk_100DC:
	dc.b $FF
	dc.b   0

unk_100DE:
	dc.b $FF
	dc.b   0

unk_100E0:
	dc.b $FF
	dc.b   0

unk_100E2:
	dc.b $FF
	dc.b   0

unk_100E4:
	dc.b $FF
	dc.b  $C
	dc.b   0
	dc.b $2B
	dc.b $FF
	dc.b   8
	dc.b $C2
	dc.b $24
	dc.b   3
	dc.b $60
	dc.b   3
	dc.b $7A
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $57
	dc.b   3
	dc.b $50
	dc.b   3
	dc.b $51
	dc.b   3
	dc.b $5F
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $68
	dc.b   3
	dc.b $75
	dc.b   3
	dc.b $6B
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $5D
	dc.b   3
	dc.b $54
	dc.b   3
	dc.b $52
	dc.b   3
	dc.b $53
	dc.b   3
	dc.b $5F
	dc.b $FF
	dc.b   8
	dc.b $C3
	dc.b $24
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $74
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $7D
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $6F
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $69
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $68
	dc.b   3
	dc.b $75
	dc.b   3
	dc.b $7A
	dc.b $FF
	dc.b   8
	dc.b $C4
	dc.b $24
	dc.b   3
	dc.b $68
	dc.b   3
	dc.b $7A
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $6F
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $80
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $68
	dc.b   3
	dc.b $79
	dc.b   3
	dc.b $79
	dc.b   3
	dc.b $70
	dc.b   3
	dc.b $7D
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $32
	dc.b $FF
	dc.b   0

unk_1015A:
	dc.b $FF
	dc.b  $C
	dc.b   0
	dc.b $2B
	dc.b $FF
	dc.b   8
	dc.b $C2
	dc.b $24
	dc.b   3
	dc.b $60
	dc.b   3
	dc.b $7A
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $6F
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $69
	dc.b   3
	dc.b $7C
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $75
	dc.b   3
	dc.b $7A
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $76
	dc.b $FF
	dc.b   8
	dc.b $C3
	dc.b $24
	dc.b   3
	dc.b $79
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $68
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $6F
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $74
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $75
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $7E
	dc.b   3
	dc.b $68
	dc.b   3
	dc.b $80
	dc.b $FF
	dc.b   8
	dc.b $C4
	dc.b $24
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $79
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $6F
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $6F
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $79
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $68
	dc.b   3
	dc.b $7A
	dc.b $FF
	dc.b   8
	dc.b $C5
	dc.b $24
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $6F
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $80
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $6D
	dc.b   3
	dc.b $68
	dc.b   3
	dc.b $73
	dc.b   3
	dc.b $73
	dc.b   3
	dc.b $32
	dc.b $FF
	dc.b   0

unk_101EC:
	dc.b $FF
	dc.b  $C
	dc.b   0
	dc.b $2B
	dc.b $FF
	dc.b   8
	dc.b $C2
	dc.b $24
	dc.b   3
	dc.b $60
	dc.b   3
	dc.b $7A
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $4F
	dc.b   3
	dc.b $5A
	dc.b   3
	dc.b $62
	dc.b   3
	dc.b $59
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $7A
	dc.b   3
	dc.b $77
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $6B
	dc.b $FF
	dc.b   8
	dc.b $C3
	dc.b $24
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $6F
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $70
	dc.b   3
	dc.b $79
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $6B
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $7A
	dc.b   3
	dc.b $6A
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $75
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $32
	dc.b $FF
	dc.b   0

unk_10238:
	dc.b $FF
	dc.b  $C
	dc.b   0
	dc.b $2B
	dc.b $FF
	dc.b   8
	dc.b $C2
	dc.b $24
	dc.b   3
	dc.b $52
	dc.b   3
	dc.b $79
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $7C
	dc.b   3
	dc.b $77
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $6D
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $7C
	dc.b   3
	dc.b $79
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $79
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $74
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $79
	dc.b   3
	dc.b $6C
	dc.b $FF
	dc.b   8
	dc.b $C3
	dc.b $24
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $6E
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $6F
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $79
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $73
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $7B
	dc.b $FF
	dc.b   8
	dc.b $C4
	dc.b $24
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $6F
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $74
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $7A
	dc.b   3
	dc.b $6A
	dc.b   3
	dc.b $68
	dc.b   3
	dc.b $77
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $32
	dc.b $FF
	dc.b   0

unk_102A4:
	dc.b $FF
	dc.b  $C
	dc.b   0
	dc.b $2B
	dc.b $FF
	dc.b   8
	dc.b $C2
	dc.b $24
	dc.b   3
	dc.b $54
	dc.b   3
	dc.b $6D
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $7A
	dc.b   3
	dc.b $77
	dc.b   3
	dc.b $68
	dc.b   3
	dc.b $6A
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $79
	dc.b   3
	dc.b $7C
	dc.b   3
	dc.b $75
	dc.b   3
	dc.b $7A
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $7C
	dc.b   3
	dc.b $7B
	dc.b $FF
	dc.b   8
	dc.b $C3
	dc.b $24
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $6F
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $75
	dc.b $FF
	dc.b   4
	dc.b   0
	dc.b $20
	dc.b $FF
	dc.b   8
	dc.b $C3
	dc.b $2E
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $6F
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $80
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $6A
	dc.b   3
	dc.b $68
	dc.b   3
	dc.b $75
	dc.b   3
	dc.b $75
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $69
	dc.b   3
	dc.b $6C
	dc.b $FF
	dc.b   8
	dc.b $C4
	dc.b $24
	dc.b   3
	dc.b $7A
	dc.b   3
	dc.b $68
	dc.b   3
	dc.b $7D
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $6B
	dc.b   3
	dc.b $32
	dc.b $FF
	dc.b   0

unk_10310:
	dc.b $FF
	dc.b  $C
	dc.b   0
	dc.b $2B
	dc.b $FF
	dc.b   8
	dc.b $C2
	dc.b $24
	dc.b   3
	dc.b $51
	dc.b   3
	dc.b $79
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $74
	dc.b   3
	dc.b $68
	dc.b   3
	dc.b $75
	dc.b   3
	dc.b $80
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $6E
	dc.b   3
	dc.b $79
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $7C
	dc.b   3
	dc.b $77
	dc.b   3
	dc.b $7A
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $6D
	dc.b $FF
	dc.b   8
	dc.b $C3
	dc.b $24
	dc.b   3
	dc.b $69
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $68
	dc.b   3
	dc.b $75
	dc.b   3
	dc.b $7A
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $70
	dc.b   3
	dc.b $75
	dc.b   3
	dc.b $6A
	dc.b   3
	dc.b $79
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $68
	dc.b   3
	dc.b $7A
	dc.b   3
	dc.b $6C
	dc.b $FF
	dc.b   8
	dc.b $C4
	dc.b $24
	dc.b   3
	dc.b $80
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $7C
	dc.b   3
	dc.b $79
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $7A
	dc.b   3
	dc.b $6A
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $79
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $32
	dc.b $FF
	dc.b   0

unk_10380:
	dc.b $FF
	dc.b   0

unk_10382:
	dc.b $FF
	dc.b  $C
	dc.b   0
	dc.b $2B
	dc.b $FF
	dc.b   8
	dc.b $C2
	dc.b $24
	dc.b   3
	dc.b $62
	dc.b   3
	dc.b $68
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $6A
	dc.b   3
	dc.b $6F
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $7C
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $6D
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $79
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $6F
	dc.b   3
	dc.b $6C
	dc.b $FF
	dc.b   8
	dc.b $C3
	dc.b $24
	dc.b   3
	dc.b $79
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $6D
	dc.b   3
	dc.b $7C
	dc.b   3
	dc.b $6E
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $69
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $68
	dc.b   3
	dc.b $75
	dc.b   3
	dc.b $7A
	dc.b $FF
	dc.b   8
	dc.b $C4
	dc.b $24
	dc.b   3
	dc.b $7E
	dc.b   3
	dc.b $6F
	dc.b   3
	dc.b $70
	dc.b   3
	dc.b $6A
	dc.b   3
	dc.b $6F
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $6A
	dc.b   3
	dc.b $68
	dc.b   3
	dc.b $75
	dc.b   3
	dc.b $75
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $69
	dc.b   3
	dc.b $6C
	dc.b $FF
	dc.b   8
	dc.b $C5
	dc.b $24
	dc.b   3
	dc.b $6E
	dc.b   3
	dc.b $79
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $7C
	dc.b   3
	dc.b $77
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $6B
	dc.b   3
	dc.b $32
	dc.b   3
	dc.b $32
	dc.b   3
	dc.b $32
	dc.b $FF
	dc.b   4
	dc.b   0
	dc.b $80
	dc.b $FF
	dc.b  $C
	dc.b   0
	dc.b $2B
	dc.b $FF
	dc.b   8
	dc.b $C2
	dc.b $24
	dc.b   3
	dc.b $32
	dc.b   3
	dc.b $32
	dc.b   3
	dc.b $32
	dc.b   3
	dc.b $69
	dc.b   3
	dc.b $7C
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $74
	dc.b   3
	dc.b $7C
	dc.b   3
	dc.b $7A
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $7A
	dc.b   3
	dc.b $6A
	dc.b   3
	dc.b $68
	dc.b   3
	dc.b $77
	dc.b   3
	dc.b $6C
	dc.b $FF
	dc.b   8
	dc.b $C3
	dc.b $24
	dc.b   3
	dc.b $7E
	dc.b   3
	dc.b $70
	dc.b   3
	dc.b $7B
	dc.b   3
	dc.b $6F
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $68
	dc.b   3
	dc.b $30
	dc.b   3
	dc.b $75
	dc.b   3
	dc.b $6C
	dc.b   3
	dc.b $70
	dc.b   3
	dc.b $6E
	dc.b   3
	dc.b $6F
	dc.b   3
	dc.b $69
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $79
	dc.b   3
	dc.b $70
	dc.b   3
	dc.b $75
	dc.b   3
	dc.b $6E
	dc.b $FF
	dc.b   8
	dc.b $C4
	dc.b $24
	dc.b   3
	dc.b $6E
	dc.b   3
	dc.b $79
	dc.b   3
	dc.b $76
	dc.b   3
	dc.b $7C
	dc.b   3
	dc.b $77
	dc.b   3
	dc.b $32
	dc.b $FF
	dc.b   0

unk_1046E:
	dc.b $FF
	dc.b   8
	dc.b $C4
	dc.b $24
	dc.b $FF
	dc.b   0

unk_10474:
	dc.b $FF
	dc.b   8
	dc.b $C4
	dc.b $24
	dc.b $FF
	dc.b   0
; ---------------------------------------------------------------------------

loc_1047A:
	lea	(loc_10486).l,a1
	jmp	(FindActorSlot).l
; ---------------------------------------------------------------------------

loc_10486:
	move.b	(p1_ctrl_press).l,d0
	or.b	(p2_ctrl_press).l,d0
	andi.b	#$F0,d0
	bne.s	loc_1049C
	rts
; ---------------------------------------------------------------------------

loc_1049C:
	clr.b	(bytecode_disabled).l
	move.b	#2,(bytecode_flag).l
	jmp	(ActorDeleteSelf).l

; =============== S U B	R O U T	I N E =======================================

sub_104B0:
	lea	(sub_104E2).l,a1
	jsr	(FindActorSlotQuick).l
	bcc.s	loc_104C2
	rts
; ---------------------------------------------------------------------------

loc_104C2:
	move.b	#$80,6(a1)
	move.b	#8,8(a1)
	move.b	#9,9(a1)
	move.w	#$A0,$A(a1)
	move.w	#$FFE8,$E(a1)
	rts
; End of function sub_104B0

; =============== S U B	R O U T	I N E =======================================

sub_104E2:
	tst.b	(word_FF1124).l
	beq.s	locret_104F0
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

locret_104F0:
	rts
; End of function sub_104E2

; =============== S U B	R O U T	I N E =======================================

sub_104F2:
	move.l	a0,-(sp)
	move.b	(opponent).l,d0
	cmpi.b	#OPP_ARMS,d0
	bne.s	loc_10520
	lea	(ArtNem_ArmsIntro2).l,a0
	move.w	#$600,d0
	DISABLE_INTS
	jsr	(NemDec).l
	ENABLE_INTS
	moveq	#$12,d0
	bsr.w	sub_10DB2

loc_10520:
	moveq	#0,d0
	move.b	(opponent).l,d0
	cmpi.b	#OPP_ROBOTNIK,d0
	beq.s	loc_1054C
	lsl.w	#2,d0
	lea	(OpponentIntroArt).l,a1
	movea.l	(a1,d0.w),a0
	move.w	#$8000,d0
	DISABLE_INTS
	jsr	(NemDec).l
	ENABLE_INTS

loc_1054C:
	move.l	(sp)+,a0
	clr.w	d0
	move.b	(opponent).l,d0
	move.b	d0,d1
	addi.b	#9,d1
	cmpi.b	#OPP_ROBOTNIK+9,d1
	bne.s	loc_1057A
	move.b	#$2B,d1
	lea	(loc_10712).l,a1
	jsr	(FindActorSlotQuick).l
	bcc.s	loc_1058C
	rts
; ---------------------------------------------------------------------------

loc_1057A:
	lea	(loc_1066C).l,a1
	jsr	(FindActorSlotQuick).l
	bcc.s	loc_1058C
	rts
; ---------------------------------------------------------------------------

loc_1058C:
	move.l	a0,$2E(a1)
	move.b	#$B7,6(a1)
	move.b	#$FF,7(a1)
	move.b	d1,8(a1)
	move.w	#4,$1E(a1)
	move.w	#$34,$26(a1)
	move.w	#6,$12(a1)
	move.w	#$4000,$1C(a1)
	movea.l	a1,a2
	clr.w	d2
	move.b	(opponent).l,d2
	move.w	d2,d3
	lsl.w	#2,d3
	lea	(unk_10628).l,a3
	adda.w	d3,a3
	move.w	(a3)+,$A(a1)
	move.w	(a3),$E(a1)
	lea	(byte_10702).l,a3
	clr.w	d3
	move.b	(a3,d2.w),d3
	lea	(off_AC48).l,a3
	lsl.w	#2,d2
	movea.l	(a3,d2.w),a4
	lsl.w	#2,d3
	move.l	(a4,d3.w),$32(a1)

loc_105F6:
	moveq	#0,d0
	move.b	(opponent).l,d0
	move.b	OpponentIntroPals2(pc,d0.w),d0
	lsl.w	#5,d0
	lea	(Palettes).l,a2
	adda.l	d0,a2
	move.b	#3,d0
	jmp	(LoadPalette).l
; End of function sub_104F2

; ---------------------------------------------------------------------------
OpponentIntroPals2:	; For Role Call
	dc.b (Pal_CoconutsIntro-Palettes)>>5		; Skeleton Tea - Puyo Leftover
	dc.b (Pal_FranklyIntro-Palettes)>>5
	dc.b (Pal_DynamightIntro-Palettes)>>5
	dc.b (Pal_ArmsIntro-Palettes)>>5
	dc.b (Pal_CoconutsIntro-Palettes)>>5		; Nasu Grave - Puyo Leftover
	dc.b (Pal_GrounderIntro-Palettes)>>5
	dc.b (Pal_DavySprocketIntro-Palettes)>>5
	dc.b (Pal_CoconutsIntro-Palettes)>>5
	dc.b (Pal_SpikeIntro-Palettes)>>5
	dc.b (Pal_SirFfuzzyLogikIntro-Palettes)>>5
	dc.b (Pal_DragonBreathIntro-Palettes)>>5
	dc.b (Pal_ScratchIntro-Palettes)>>5
	dc.b (Pal_Black-Palettes)>>5			; Dr. Robotnik
	dc.b (Pal_CoconutsIntro-Palettes)>>5		; Mummy - Puyo Leftover
	dc.b (Pal_HumptyIntro-Palettes)>>5
	dc.b (Pal_SkweelIntro-Palettes)>>5
	dc.b (Pal_CoconutsIntro-Palettes)>>5		; Opening Cutscene
	dc.b (Pal_RedYellowPuyos-Palettes)>>5		; Has Bean

unk_10628:
	dc.b   0
	dc.b $30
	dc.b   0
	dc.b $40
	dc.b   0
	dc.b $38
	dc.b   0
	dc.b $28
	dc.b   0
	dc.b $40
	dc.b   0
	dc.b   8
	dc.b   0
	dc.b $28
	dc.b   0
	dc.b $20
	dc.b   0
	dc.b $30
	dc.b   0
	dc.b $40
	dc.b   0
	dc.b $38
	dc.b   0
	dc.b $30
	dc.b   0
	dc.b $30
	dc.b   0
	dc.b $30
	dc.b   0
	dc.b $30
	dc.b   0
	dc.b $38
	dc.b   0
	dc.b $30
	dc.b   0
	dc.b $28
	dc.b   0
	dc.b $30
	dc.b   0
	dc.b $28
	dc.b   0
	dc.b $30
	dc.b   0
	dc.b $28
	dc.b   0
	dc.b $30
	dc.b   0
	dc.b $28
	dc.b   0
	dc.b $28
	dc.b $FF
	dc.b $E8
	dc.b   0
	dc.b $30
	dc.b   0
	dc.b $20
	dc.b   0
	dc.b $30
	dc.b   0
	dc.b $30
	dc.b   0
	dc.b $30
	dc.b   0
	dc.b $20
	dc.b   0
	dc.b $28
	dc.b   0
	dc.b $20
; ---------------------------------------------------------------------------

loc_1066C:
	jsr	(ActorAnimate).l
	jsr	(ActorBookmark).l
	move.w	$1E(a0),d0
	add.w	d0,$A(a0)
	subq.w	#1,$26(a0)
	beq.s	loc_1068A
	rts
; ---------------------------------------------------------------------------

loc_1068A:
	jsr	(ActorBookmark).l
	jsr	(ActorAnimate).l
	movea.l	$32(a0),a2
	cmpi.b	#$FE,(a2)
	bne.s	loc_106C8
	clr.w	d2
	move.b	(opponent).l,d2
	lea	(byte_10702).l,a3
	clr.w	d3
	move.b	(a3,d2.w),d3
	lea	(off_AC48).l,a3
	lsl.w	#2,d2
	movea.l	(a3,d2.w),a4
	lsl.w	#2,d3
	move.l	(a4,d3.w),$32(a0)

loc_106C8:
	movea.l	$2E(a0),a1
	tst.b	7(a1)
	beq.s	loc_106D6
	rts
; ---------------------------------------------------------------------------

loc_106D6:
	move.w	#$20,$26(a0)
	jsr	(ActorBookmark).l
	jsr	(sub_3810).l
	subq.w	#1,$26(a0)
	beq.s	loc_106F2
	rts
; ---------------------------------------------------------------------------

loc_106F2:
	clr.b	7(a0)
	jsr	(ActorBookmark).l
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------
byte_10702:
	dc.b   0	; Skeleton Tea - Puyo Leftover
	dc.b   0	; Frankly
	dc.b   4	; Dynamight
	dc.b   1	; Arms
	dc.b   0	; Nasu Grave - Puyo Leftover
	dc.b   1	; Grounder
	dc.b   5	; Davy Sprocket
	dc.b   1	; Coconuts
	dc.b   0	; Spike
	dc.b   0	; Sir Ffuzzy-Logik
	dc.b   0	; Dragon Breath
	dc.b   2	; Scratch
	dc.b   2	; Dr. Robotnik
	dc.b   0	; Mummy - Puyo Leftover
	dc.b   0	; Humpty
	dc.b   0	; Skweel
; ---------------------------------------------------------------------------

loc_10712:
	move.w	#8,$E(a0)
	jsr	(sub_1077C).l
	jsr	(ActorBookmark).l
	move.w	$1E(a0),d0
	add.w	d0,$A(a0)
	subq.w	#1,$26(a0)
	beq.s	loc_10736
	rts
; ---------------------------------------------------------------------------

loc_10736:
	jsr	(ActorBookmark).l
	jsr	(sub_1077C).l
	movea.l	$2E(a0),a1
	tst.b	7(a1)
	beq.s	loc_10750
	rts
; ---------------------------------------------------------------------------

loc_10750:
	move.w	#$20,$26(a0)
	jsr	(ActorBookmark).l
	jsr	(sub_3810).l
	subq.w	#1,$26(a0)
	beq.s	loc_1076C
	rts
; ---------------------------------------------------------------------------

loc_1076C:
	clr.b	7(a0)
	jsr	(ActorBookmark).l
	jmp	(ActorDeleteSelf).l

; =============== S U B	R O U T	I N E =======================================

sub_1077C:
	tst.b	$22(a0)
	beq.s	loc_1078A
	subq.b	#1,$22(a0)
	rts
; ---------------------------------------------------------------------------

loc_1078A:
	movea.l	$32(a0),a2
	cmpi.b	#$FF,(a2)
	bne.s	loc_1079A
	movea.l	2(a2),a2

loc_1079A:
	move.b	(a2)+,$22(a0)
	move.b	(a2)+,d0
	move.b	d0,9(a0)
	move.l	a2,$32(a0)
	lsl.w	#2,d0
	lea	(off_ABC8).l,a1
	move.l	(a1,d0.w),d0
	move.l	a0,-(sp)
	lea	(dma_queue).l,a0
	adda.w	(dma_slot).l,a0
	move.w	#$8F02,(a0)+
	move.l	#$94059380,(a0)+
	lsr.l	#1,d0
	move.l	d0,d1
	lsr.w	#8,d0
	swap	d0
	move.w	d1,d0
	andi.w	#$FF,d0
	addi.l	#-$69FF6B00,d0
	swap	d1
	andi.w	#$7F,d1
	addi.w	#-$6900,d1
	move.l	d0,(a0)+
	move.w	d1,(a0)+
	move.l	#$60000080,(a0)
	addi.w	#$10,(dma_slot).l
	movea.l	(sp)+,a0
	rts
; End of function sub_1077C

; =============== S U B	R O U T	I N E =======================================

sub_10800:
	clr.w	d0
	move.b	(level).l,d0
	lea	(unk_10822).l,a1
	move.b	(a1,d0.w),(opponent).l
	lea	(loc_10834).l,a1
	jmp	(FindActorSlot).l
; End of function sub_10800

; ---------------------------------------------------------------------------
unk_10822:	dc.b $10
	dc.b OPP_SKELETON	; Puyo Puyo leftover
	dc.b OPP_NASU_GRAVE	; Puyo Puyo leftover
	dc.b OPP_MUMMY		; Puyo Puyo leftover
	dc.b OPP_ARMS
	dc.b OPP_FRANKLY
	dc.b OPP_HUMPTY
	dc.b OPP_COCONUTS
	dc.b OPP_DAVY
	dc.b OPP_SKWEEL
	dc.b OPP_DYNAMIGHT
	dc.b OPP_GROUNDER
	dc.b OPP_SPIKE
	dc.b OPP_SIR_FFUZZY
	dc.b OPP_DRAGON
	dc.b OPP_SCRATCH
	dc.b OPP_ROBOTNIK
	dc.b $11		; Has Bean
; ---------------------------------------------------------------------------

loc_10834:
	move.b	#1,(word_FF1126).l
	move.b	#$FF,7(a0)
	bsr.w	sub_1090A
	jsr	(ActorBookmark).l
	bsr.w	sub_1095A
	jsr	(ActorBookmark).l
	bsr.w	sub_1093A
	jsr	(ActorBookmark).l
	move.b	#0,(word_FF1126).l
	move.w	#$80,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark).l
	moveq	#0,d0
	move.b	(level).l,d0
	bsr.w	sub_10DB2
	move.w	#1,(word_FF198C).l
	move.w	#$A0,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark).l
	cmpi.b	#$11,(level).l
	bcs.s	loc_108B8
	move.w	#$100,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark).l

loc_108B8:
	clr.b	7(a0)
	move.w	#$24,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark).l
	move.w	#$101,(word_FF1124).l
	jsr	(ActorBookmark).l
	bsr.w	sub_10BF8
	clr.b	(bytecode_disabled).l
	clr.b	(bytecode_flag).l
	addq.b	#1,(level).l
	cmpi.b	#$12,(level).l
	bcc.s	loc_10904
	move.b	#1,(bytecode_flag).l

loc_10904:
	jmp	(ActorDeleteSelf).l

; =============== S U B	R O U T	I N E =======================================

sub_1090A:
	clr.w	d0
	move.b	(level).l,d0
	lea	(byte_1098C).l,a1
	clr.w	d1
	move.b	(a1,d0.w),d1
	bmi.w	locret_10938
	lsl.w	#2,d1
	lea	(off_1099E).l,a1
	movea.l	(a1,d1.w),a2
	move.l	a0,-(sp)
	jsr	(a2)
	move.l	(sp)+,a0

locret_10938:
	rts
; End of function sub_1090A

; =============== S U B	R O U T	I N E =======================================

sub_1093A:
	cmpi.b	#$10,(opponent).l
	bcc.w	locret_10958
	bsr.w	sub_104F2
	cmpi.b	#OPP_NASU_GRAVE,(opponent).l
	beq.s	locret_10958
	bsr.w	sub_104B0

locret_10958:
	rts
; End of function sub_1093A

; =============== S U B	R O U T	I N E =======================================

sub_1095A:
	cmpi.b	#$10,(opponent).l
	bcc.s	loc_1097A
	jsr	(sub_604E).l
	cmpi.b	#OPP_NASU_GRAVE,(opponent).l
	bne.s	loc_1097A
	bsr.w	sub_104B0

loc_1097A:
	cmpi.b	#OPP_ROBOTNIK,(opponent).l
	beq.s	loc_10986
	rts
; ---------------------------------------------------------------------------

loc_10986:
	jmp	(InitPalette_Safe).l
; End of function sub_1095A

; ---------------------------------------------------------------------------
byte_1098C:
	dc.b   0	; Practise Stage 1
	dc.b $FF	; Practise Stage 2
	dc.b $FF	; Practise Stage 3
	dc.b $FF	; Stage 1
	dc.b $FF	; Stage 2
	dc.b $FF	; Stage 3
	dc.b $FF	; Stage 4
	dc.b $FF	; Stage 5
	dc.b $FF	; Stage 6
	dc.b $FF	; Stage 7
	dc.b $FF	; Stage 8
	dc.b $FF	; Stage 9
	dc.b $FF	; Stage 10
	dc.b $FF	; Stage 11
	dc.b $FF	; Stage 12
	dc.b $FF	; Stage 1e
	dc.b   1
	dc.b   2

off_1099E:
	dc.l locret_109AA
	dc.l locret_109AA
	dc.l loc_109AC
; ---------------------------------------------------------------------------

locret_109AA:
	rts
; ---------------------------------------------------------------------------

loc_109AC:
	moveq	#$13,d0
	bsr.w	sub_10DB2
	lea	(loc_10AC8).l,a1
	jsr	(FindActorSlot).l
	movem.l	d2/a0,-(sp)
	lea	(ArtPuyo_LevelSprites).l,a0
	move.w	#$2000,d0

	if PuyoCompression=0
	jsr	(PuyoDec).l
	else
	DISABLE_INTS
	jsr	(NemDec).l
	ENABLE_INTS
	endc

	lea	(ArtNem_HasBeanShadow).l,a0
	move.w	#$400,d0
	DISABLE_INTS
	jsr	(NemDec).l
	ENABLE_INTS
	movem.l	(sp)+,d2/a0
	bsr.w	loc_105F6
	lea	(Palettes).l,a2
	adda.l	#(Pal_HasBeanShadow-Palettes),a2
	move.b	#2,d0
	jsr	(LoadPalette).l
	lea	(loc_10A14).l,a1
	jmp	(FindActorSlotQuick).l
; ---------------------------------------------------------------------------

loc_10A14:
	move.l	#unk_10ABA,$32(a0)
	move.w	#$80,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark).l
	move.b	#$95,6(a0)
	move.b	#8,8(a0)
	move.b	#0,9(a0)
	move.w	#$120,$A(a0)
	move.w	#$FF90,$E(a0)
	move.w	#$FFFF,$20(a0)
	move.w	#$1000,$1C(a0)
	jsr	(ActorBookmark).l
	move.w	$1E(a0),$E(a0)
	jsr	(sub_3810).l
	jsr	(ActorAnimate).l
	move.w	$E(a0),$1E(a0)
	addi.w	#-$70,$E(a0)
	cmpi.w	#$C0,$1E(a0)
	bcc.s	loc_10A86
	rts
; ---------------------------------------------------------------------------

loc_10A86:
	move.l	#unk_10AA4,$32(a0)
	move.b	#SFX_PUYO_LAND,d0
	jsr	(PlaySound_ChkPCM).l
	jsr	(ActorBookmark).l
	jmp	(ActorAnimate).l
; ---------------------------------------------------------------------------
; TODO: Document Animation Code

unk_10AA4:
	dc.b   8
	dc.b   0
	dc.b   8
	dc.b   1
	dc.b  $C
	dc.b   2
	dc.b   8
	dc.b   1
	dc.b   8
	dc.b   0
	dc.b   8
	dc.b   3
	dc.b  $C
	dc.b   4
	dc.b   8
	dc.b   3
	dc.b $FF
	dc.b   0
	dc.l unk_10AA4

unk_10ABA:
	dc.b   1
	dc.b   5
	dc.b   1
	dc.b   6
	dc.b   1
	dc.b   7
	dc.b   1
	dc.b   8
	dc.b $FF
	dc.b   0
	dc.l unk_10ABA
; ---------------------------------------------------------------------------

loc_10AC8:
	move.l	#unk_10B68,$32(a0)
	move.b	#8,8(a0)
	move.b	#$A,9(a0)
	move.w	#$110,$A(a0)
	move.w	#$54,$E(a0)
	move.w	#$B4,$26(a0)
	jsr	(ActorBookmark).l
	move.w	#$24,(palette_buffer+$72).l
	move.b	#3,d0
	lea	((palette_buffer+$60)).l,a2
	jsr	(LoadPalette).l
	jsr	(ActorBookmark).l
	subq.w	#1,$26(a0)
	beq.s	loc_10B1A
	rts
; ---------------------------------------------------------------------------

loc_10B1A:
	move.b	#$80,6(a0)
	jsr	(ActorBookmark).l
	moveq	#0,d3
	move.b	9(a0),d3
	jsr	(ActorAnimate).l
	cmp.b	9(a0),d3
	beq.s	locret_10B58
	subi.b	#$A,d3
	add.w	d3,d3
	move.w	word_10B5A(pc,d3.w),d0
	move.w	d0,(palette_buffer+$72).l
	move.b	#3,d0
	lea	((palette_buffer+$60)).l,a2
	jsr	(LoadPalette).l

locret_10B58:
	rts
; ---------------------------------------------------------------------------
word_10B5A:
	dc.w $26
	dc.w $48
	dc.w $4A
	dc.w $6A
	dc.w $6C
	dc.w $8C
	dc.w $8E
; TODO: Document Animation Code

unk_10B68:
	dc.b   3
	dc.b  $A
	dc.b   3
	dc.b  $B
	dc.b   3
	dc.b  $C
	dc.b   3
	dc.b  $D
	dc.b   3
	dc.b  $E
	dc.b   3
	dc.b  $F
	dc.b   3
	dc.b $10
	dc.b   3
	dc.b $11
	dc.b $FE
	dc.b   0
; ---------------------------------------------------------------------------
	clr.w	d0
	move.b	(level).l,d0
	lea	(byte_10BDA).l,a1
	clr.w	d1
	move.b	(a1,d0.w),d1
	bra.w	locret_10BD8
; ---------------------------------------------------------------------------
	move.b	#0,d0
	move.b	#0,d1
	lea	(Palettes).l,a2
	adda.l	#(Pal_RedYellowPuyos-Palettes),a2
	cmpi.b	#$11,(level).l
	beq.s	loc_10BB8
	adda.l	#(Pal_Characters_Puyo-Pal_RedYellowPuyos),a2

loc_10BB8:
	jsr	(FadeToPalette).l
	move.b	#2,d0
	move.b	#0,d1
	lea	(Palettes).l,a2
	adda.l	#(Pal_Characters_Puyo-Palettes),a2
	jsr	(FadeToPalette).l

locret_10BD8:
	rts
; ---------------------------------------------------------------------------
byte_10BDA:
	dc.b   0
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b   1
	dc.b   2

	dc.l loc_B102
	dc.l loc_B152
	dc.l loc_B102

; =============== S U B	R O U T	I N E =======================================

sub_10BF8:
	clr.w	d0
	move.b	(level).l,d0
	lea	(unk_10C78).l,a1
	tst.b	(a1,d0.w)
	beq.s	loc_10C38
	jsr	(InitPalette_Safe).l
	move.l	a0,-(sp)
	jsr	(InitActors).l
	move.l	(sp)+,a0
	jsr	(ClearScroll).l
	move.w	#$FF20,(vscroll_buffer).l
	move.w	#$FF60,(vscroll_buffer+2).l

loc_10C38:
	cmpi.b	#OPP_ROBOTNIK,(opponent).l
	beq.s	loc_10C56
	cmpi.b	#$11,(level).l
	bge.s	locret_10C76
	moveq	#$24,d0
	jsr	(QueuePlaneCmdList).l
	bra.s	loc_10C5E
; ---------------------------------------------------------------------------

loc_10C56:
	moveq	#0,d0
	jsr	(QueuePlaneCmdList).l

loc_10C5E:
	move.b	(level).l,d0
	cmpi.b	#$F,d0
	bne.s	locret_10C76
	lea	(loc_10C8A).l,a1
	jmp	(FindActorSlot).l
; ---------------------------------------------------------------------------

locret_10C76:
	rts
; End of function sub_10BF8

; ---------------------------------------------------------------------------
unk_10C78:
	dc.b   0	; Practise Stage 1
	dc.b   0	; Practise Stage 2
	dc.b   0	; Practise Stage 3
	dc.b   0	; Stage 1
	dc.b   0	; Stage 2
	dc.b   0	; Stage 3
	dc.b   0	; Stage 4
	dc.b   0	; Stage 5
	dc.b   0	; Stage 6
	dc.b   0	; Stage 7
	dc.b   0	; Stage 8
	dc.b   0	; Stage 9
	dc.b   0	; Stage 10
	dc.b   0	; Stage 11
	dc.b   0	; Stage 12
	dc.b $FF	; Stage 13
	dc.b $FF
	dc.b   0
; ---------------------------------------------------------------------------

loc_10C8A:
	move.l	a0,-(sp)
	movea.l	(dword_FF112C).l,a0
	jsr	(ActorDeleteSelf).l
	moveq	#0,d0
	lea	(hscroll_buffer).l,a1
	move.w	#$A0,d1

loc_10CA6:
	move.l	d0,(a1)+
	dbf	d1,loc_10CA6
	jsr	(QueuePlaneCmdList).l
	jsr	(InitPalette_Safe).l
	move.l	(sp)+,a0
	jsr	(ActorBookmark).l
	move.l	a0,-(sp)
	jsr	(sub_F8B6).l
	move.l	(sp)+,a0
	moveq	#4,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark).l
	move.l	a0,-(sp)
	move.b	#1,(use_lair_assets).l
	jsr	(LoadEndingBGArt).l
	move.l	(sp)+,a0
	jsr	(ActorBookmark).l
	move.l	a0,-(sp)
	jsr	(sub_F878).l
	move.l	(sp)+,a0
	jsr	(ActorBookmark).l
	move.l	a0,-(sp)
	jsr	(sub_F832).l
	move.l	(sp)+,a0
	jsr	(ActorBookmark).l
	move.l	a0,-(sp)
	jsr	(sub_10D8C).l
	move.l	(sp)+,a0
	jsr	(ActorBookmark).l
	move.b	#0,d0
	move.b	#0,d1
	lea	(Pal_RobotnikLair).l,a2
	jsr	(FadeToPalette).l
	move.b	#1,d0
	move.b	#0,d1
	lea	(Pal_GameIntroGrounder).l,a2
	jsr	(FadeToPalette).l
	move.b	#2,d0
	move.b	#0,d1
	lea	(Pal_Robotnik).l,a2
	jsr	(FadeToPalette).l
	move.b	#3,d0
	move.b	#0,d1
	lea	(Pal_GameIntroRobotnik).l,a2
	jsr	(FadeToPalette).l
	jmp	(ActorDeleteSelf).l

; =============== S U B	R O U T	I N E =======================================

sub_10D8C:
	movea.w	#$D688,a1
	move.w	#$C400,d0
	move.w	#9,d1
	move.w	#6,d2
	movea.l	#MapEni_DrRobotnik_0,a0
	DISABLE_INTS
	jsr	(EniDec).l
	ENABLE_INTS
	rts
; End of function sub_10D8C

; =============== S U B	R O U T	I N E =======================================

sub_10DB2:
	lsl.w	#2,d0
	lea	(RoleCallText).l,a1
	movea.l	(a1,d0.w),a2
	move.w	#$9100,d0
	swap	d0
	or.l	(a2),d0
	jsr	(QueuePlaneCmd).l
	lea	(sub_10DF2).l,a1
	jsr	(FindActorSlotQuick).l
	bcc.s	loc_10DDE
	rts
; ---------------------------------------------------------------------------

loc_10DDE:
	move.w	(a2)+,$28(a1)
	move.w	(a2)+,d0
	addi.w	#$82,d0
	move.w	d0,$2A(a1)
	move.l	a2,$2E(a1)
	rts
; End of function sub_10DB2


; =============== S U B	R O U T	I N E =======================================

sub_10DF2:
	addq.b	#1,$26(a0)
	move.b	$26(a0),d0
	andi.b	#7,d0
	beq.s	loc_10E04
	rts
; ---------------------------------------------------------------------------

loc_10E04:
	bsr.w	sub_10E18
	subq.w	#1,$28(a0)
	beq.s	loc_10E12
	rts
; ---------------------------------------------------------------------------

loc_10E12:
	jmp	(ActorDeleteSelf).l
; End of function sub_10DF2


; =============== S U B	R O U T	I N E =======================================

sub_10E18:
	clr.w	d1
	movea.l	$2E(a0),a1
	move.b	(a1)+,d1
	move.l	a1,$2E(a0)
	lea	(byte_11258).l,a1
	move.w	#$E500,d0
	move.b	(a1,d1.w),d0
	move.w	$2A(a0),d5
	DISABLE_INTS
	jsr	(SetVRAMWrite).l
	addi.w	#$80,d5
	move.w	d0,VDP_DATA
	ENABLE_INTS
	addq.w	#2,$2A(a0)
	move.b	#SFX_DIALOGUE,d0
	jmp	(PlaySound_ChkPCM).l
; End of function sub_10E18

; =============== S U B	R O U T	I N E =======================================

sub_10E5C:
	lea	(ArtNem_MainFont).l,a0
	lea	(hblank_buffer_1).l,a4
	jsr	(NemDecRAM).l
	move.w	#$45F,d0
	move.l	#$11111111,d1

loc_10E78:
	or.l	d1,(a4)+
	dbf	d0,loc_10E78
	lea	(dma_queue).l,a0
	adda.w	(dma_slot).l,a0
	move.w	#$8F02,(a0)+
	move.l	#$940893C0,(a0)+
	move.l	#$96A89500,(a0)+
	move.w	#$977F,(a0)+
	move.l	#$60000082,(a0)
	addi.w	#$10,(dma_slot).l
	rts
; End of function sub_10E5C

; ---------------------------------------------------------------------------

	include "resource/text/Role Call/Role Call.asm"
	even

; =============== S U B	R O U T	I N E =======================================

ActLevelIntro:
	move.l	a0,-(sp)
	lea	(ArtNem_MainFont).l,a0
	lea	(hblank_buffer_1).l,a4
	jsr	(NemDecRAM).l
	move.w	#$45F,d0
	move.l	#$11111111,d1

loc_10FFA:
	or.l	d1,(a4)+
	dbf	d0,loc_10FFA
	lea	(dma_queue).l,a0
	adda.w	(dma_slot).l,a0
	move.w	#$8F02,(a0)+
	move.l	#$940893C0,(a0)+
	move.l	#$96A89500,(a0)+
	move.w	#$977F,(a0)+
	move.l	#$40000080,(a0)
	addi.w	#$10,(dma_slot).l
	movea.l	(sp)+,a0
	clr.w	d0
	move.b	(opponent).l,d0
	lsl.w	#2,d0
	lea	(off_113FE).l,a1
	move.l	(a1,d0.w),aAnim(a0)
	jsr	(ActorBookmark).l

Actlevel_intro_update:
	tst.w	(word_FF1122).l
	bne.s	loc_11062
	jsr	(GetCtrlData).l
	andi.b	#$F0,d0
	bne.s	CutsceneCmd_EndScene

loc_11062:
	tst.w	aField26(a0)
	beq.s	loc_11070
	subq.w	#1,aField26(a0)
	rts
; ---------------------------------------------------------------------------

loc_11070:
	movea.l	aAnim(a0),a2
	clr.w	d0
	move.b	(a2)+,d0
	move.l	a2,aAnim(a0)
	or.b	d0,d0
	bpl.w	loc_111EE
	andi.b	#$7F,d0
	lsl.w	#2,d0
	movea.l	Cutscene_Commands(pc,d0.w),a3
	clr.w	d0
	move.b	(a2)+,d0
	move.l	a2,aAnim(a0)
	jmp	(a3)
; ---------------------------------------------------------------------------
Cutscene_Commands:
	dc.l CutsceneCmd_EndScene
	dc.l CutsceneCmd_NewText
	dc.l CutsceneCmd_CloseText
	dc.l CutsceneCmd_Pause
	dc.l CutsceneCmd_AnimArle	; Puyo Leftover
	dc.l CutsceneCmd_AnimOpp
	dc.l CutsceneCmd_NewLine
	dc.l CutsceneCmd_SameFrame
	dc.l 0
	dc.l CutsceneCmd_AddBlank
	dc.l PlaySound_ChkPCM
; ---------------------------------------------------------------------------

CutsceneCmd_EndScene:
	bsr.w	sub_11192
	jsr	(ActorBookmark).l
	cmpi.b	#$10,(opponent).l
	bne.s	loc_110E4
	move.b	#OPP_SKELETON,(opponent).l
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_110E4:
	clr.b	(bytecode_disabled).l
	jmp	(ActorDeleteSelf).l
; End of function ActLevelIntro

; =============== S U B	R O U T	I N E =======================================

CutsceneCmd_NewLine:
	subq.l	#1,aAnim(a0)
; End of function CutsceneCmd_NewLine

; START	OF FUNCTION CHUNK FOR CutsceneCmd_AddBlank

loc_110F4:
	clr.w	aX(a0)
	addq.w	#1,aX+2(a0)
	move.w	aX+2(a0),d0
	cmp.w	aY+2(a0),d0
	bcs.w	locret_1110C
	clr.w	aX+2(a0)

locret_1110C:
	rts
; END OF FUNCTION CHUNK	FOR CutsceneCmd_AddBlank

; =============== S U B	R O U T	I N E =======================================

CutsceneCmd_SameFrame:
	subq.l	#1,$32(a0)
	clr.w	$A(a0)
	clr.w	$C(a0)
	bsr.w	sub_111B0
	ori.w	#$8E00,d0
	swap	d0
	jmp	(QueuePlaneCmd).l
; End of function CutsceneCmd_SameFrame

; ---------------------------------------------------------------------------

CutsceneCmd_NewText:
	move.w	d0,d1
	andi.b	#$1F,d0
	lsr.b	#5,d1
	andi.b	#7,d1
	move.w	d0,aY(a0)
	move.w	d1,aY+2(a0)
	move.w	#2,aField14(a0)
	move.b	(a2)+,aField12(a0)
	move.b	(a2)+,aField13(a0)
	move.l	a2,aAnim(a0)
	clr.w	aX(a0)
	clr.w	aX+2(a0)
	bsr.w	sub_111B0
	cmpi.b	#OPP_ROBOTNIK,(opponent).l
	beq.s	loc_11170
	cmpi.b	#$10,(opponent).l
	bne.s	loc_11176

loc_11170:
	ori.w	#$9F00,d0
	bra.s	loc_1117A
; ---------------------------------------------------------------------------

loc_11176:
	ori.w	#$8C00,d0

loc_1117A:
	swap	d0
	jsr	(QueuePlaneCmd).l
	bsr.w	sub_112D8
	move.b	#$FF,7(a0)
	rts
; ---------------------------------------------------------------------------

CutsceneCmd_CloseText:
	subq.l	#1,$32(a0)

; =============== S U B	R O U T	I N E =======================================

sub_11192:
	tst.b	7(a0)
	bne.s	loc_1119C
	rts
; ---------------------------------------------------------------------------

loc_1119C:
	clr.b	7(a0)
	bsr.w	sub_111B0
	ori.w	#$8D00,d0
	swap	d0
	jmp	(QueuePlaneCmd).l
; End of function sub_11192

; =============== S U B	R O U T	I N E =======================================

sub_111B0:
	move.w	aField12(a0),d0
	swap	d0
	clr.w	d0
	move.w	aY+2(a0),d0
	lsl.w	#5,d0
	or.w	aY(a0),d0
	rts
; End of function sub_111B0

; =============== S U B	R O U T	I N E =======================================

CutsceneCmd_AddBlank:
	subq.l	#1,$32(a0)
	bra.w	loc_11246
; ---------------------------------------------------------------------------

CutsceneCmd_Pause:
	mulu.w	#$A,d0
	move.w	d0,$26(a0)
	rts
; ---------------------------------------------------------------------------

CutsceneCmd_AnimArle:
	ori.w	#$FF00,d0
	move.w	d0,(word_FF198E).l
	rts
; ---------------------------------------------------------------------------

CutsceneCmd_AnimOpp:
	ori.w	#$FF00,d0
	move.w	d0,(word_FF1990).l
	rts
; ---------------------------------------------------------------------------

loc_111EE:
	move.b	byte_11258(pc,d0.w),d0
	move.w	$A(a0),d1
	move.w	$C(a0),d2
	add.w	d2,d2
	addq.w	#1,d1
	addq.w	#1,d2
	lsl.w	#1,d1
	lsl.w	#7,d2
	move.w	$12(a0),d5
	add.w	d1,d5
	add.w	d2,d5
	ori.w	#$E000,d0
	DISABLE_INTS
	jsr	(SetVRAMWrite).l
	move.w	d0,VDP_DATA
	ENABLE_INTS
	move.w	#1,$26(a0)
	addq.b	#1,(byte_FF1128).l
	move.b	(byte_FF1128).l,d0
	andi.b	#1,d0
	bne.s	loc_11246
	move.b	#SFX_DIALOGUE,d0
	jsr	(PlaySound_ChkPCM).l

loc_11246:
	addq.w	#1,$A(a0)
	move.w	$A(a0),d0
	cmp.w	$E(a0),d0
	bcc.w	loc_110F4
	rts
; End of function CutsceneCmd_AddBlank

; ---------------------------------------------------------------------------

byte_11258:	; Main Font Table
	include "resource/font tables/Table - Main.asm"

; =============== S U B	R O U T	I N E =======================================

sub_112D8:
	move.w	$12(a0),d0
	move.w	d0,d1
	lsr.w	#1,d0
	andi.w	#$3F,d0
	lsr.w	#7,d1
	andi.w	#$3F,d1
	move.w	$E(a0),d2
	addq.w	#1,d2
	lsl.w	#3,d2
	move.w	$10(a0),d3
	lsl.w	#4,d3
	lsl.w	#3,d0
	addi.w	#$80,d0
	lsl.w	#3,d1
	addi.w	#$80,d1
	add.w	d0,d2
	add.w	d1,d3
	move.w	#3,d5

loc_1130C:
	lea	(loc_113D8).l,a1
	jsr	(FindActorSlotQuick).l
	bcs.s	loc_11368
	move.l	a0,$2E(a1)
	move.b	#$80,6(a1)
	move.b	#$20,8(a1)
	move.b	d5,9(a1)
	cmpi.b	#OPP_ROBOTNIK,(opponent).l
	beq.s	loc_11344
	cmpi.b	#$10,(opponent).l
	bne.s	loc_11348

loc_11344:
	addq.b	#5,9(a1)

loc_11348:
	move.w	d0,$A(a1)
	btst	#0,d5
	beq.s	loc_11358
	move.w	d2,$A(a1)

loc_11358:
	move.w	d1,$E(a1)
	btst	#1,d5
	beq.s	loc_11368
	move.w	d3,$E(a1)

loc_11368:
	dbf	d5,loc_1130C
	lea	(sub_113B8).l,a1
	jsr	(FindActorSlotQuick).l
	bcc.s	loc_1137E
	rts
; ---------------------------------------------------------------------------

loc_1137E:
	move.w	$14(a0),$14(a1)
	move.l	a0,$2E(a1)
	move.b	#$20,8(a1)
	move.b	#4,9(a1)
	cmpi.b	#OPP_ROBOTNIK,(opponent).l
	beq.s	loc_113A8
	cmpi.b	#$10,(opponent).l
	bne.s	loc_113AC

loc_113A8:
	addq.b	#5,9(a1)

loc_113AC:
	move.w	d3,$E(a1)
	move.b	#$80,6(a1)
	rts
; End of function sub_112D8

; =============== S U B	R O U T	I N E =======================================

sub_113B8:
	move.w	$14(a0),d0
	lea	(word_FF1992).l,a1
	move.w	(a1,d0.w),$A(a0)
	clr.w	d0
	move.b	(opponent).l,d0
	move.b	TextBox_ArrowLoc(pc,d0.w),d0
	add.w	d0,$A(a0)

loc_113D8:
	movea.l	$2E(a0),a1
	tst.b	7(a1)
	beq.s	loc_113E6
	rts
; ---------------------------------------------------------------------------

loc_113E6:
	jmp	(ActorDeleteSelf).l
; End of function sub_113B8

; ---------------------------------------------------------------------------
TextBox_ArrowLoc:
	dc.b   0	; Skeleton Tea - Puyo Leftover
	dc.b $28	; Frankly
	dc.b $28	; Dynamight
	dc.b $38	; Arms
	dc.b   0	; Nasu Grave - Puyo Leftover
	dc.b $28	; Grounder
	dc.b $10	; Davy Sprocket
	dc.b   0	; Coconuts
	dc.b $28	; Spike
	dc.b $28	; Sir Ffuzzy-Logik
	dc.b $28	; Dragon Breath
	dc.b   0	; Scratch
	dc.b $58	; Robotnik
	dc.b   0	; Mummy - Puyo Leftover
	dc.b $30	; Humpty
	dc.b   8	; Skweel
	dc.b   0	; Opening Cutscene
	dc.b   0	; Ending???

off_113FE:
	dc.l Introtext_Coconuts		; Skeleton Tea - Puyo Leftover
	dc.l Introtext_Frankly
	dc.l Introtext_Dynamight
	dc.l Introtext_Arms
	dc.l Introtext_Coconuts		; Nasu Grave - Puyo Leftover
	dc.l Introtext_Grounder
	dc.l Introtext_Davy
	dc.l Introtext_Coconuts
	dc.l Introtext_Spike
	dc.l Introtext_SirFfuzzy
	dc.l Introtext_DragonBreath
	dc.l Introtext_Scratch
	dc.l Introtext_Robotnik
	dc.l Introtext_Coconuts		; Mummy - Puyo Leftover
	dc.l Introtext_Humpty
	dc.l Introtext_Skweel
	dc.l Introtext_Opening

	include "resource/text/Dialog/arms intro.asm"
	even

	include "resource/text/Dialog/frankly intro.asm"
	even

	include "resource/text/Dialog/humpty intro.asm"
	even

	include "resource/text/Dialog/coconuts intro.asm"
	even

	include "resource/text/Dialog/davy sprocket intro.asm"
	even

	include "resource/text/Dialog/skweel intro.asm"
	even

	include "resource/text/Dialog/dynamight intro.asm"
	even

	include "resource/text/Dialog/grounder intro.asm"
	even

	include "resource/text/Dialog/spike intro.asm"
	even

	include "resource/text/Dialog/sir ffuzzy logik intro.asm"
	even

	include "resource/text/Dialog/dragon breath intro.asm"
	even

	include "resource/text/Dialog/scratch intro.asm"
	even

	include "resource/text/Dialog/robotnik intro.asm"
	even

	include "resource/text/Dialog/game intro.asm"
	even

; TODO: Convert Intro Text to Macro Format

; --------------------------------------------------------------
; Initialize sprite drawing
; --------------------------------------------------------------

InitSpriteDraw:
	clr.w	draw_order
	clr.w	sprite_count
	rts

; --------------------------------------------------------------
; Draw actors
; --------------------------------------------------------------

DrawActors:
	tst.w	sprite_count
	beq.s	.DoDraw
	rts

.DoDraw:
	lea	actors,a0
	moveq	#aSize,d2
	tst.w	draw_order
	beq.s	.StartDraw
	lea	actors_end-aSize,a0
	moveq	#-aSize,d2

.StartDraw:
	lea	sprite_buffer+8,a1
	lea	SpriteMappings,a2
	lea	sprite_layers+1,a4

	move.w	#(actors_end-actors)/aSize-1,d0
	move.w	#1,d1
	move.b	player_1_flags,d4
	rol.b	#1,d4
	andi.b	#1,d4
	eori.b	#1,d4
	move.b	player_2_flags,d5
	rol.b	#2,d5
	andi.b	#2,d5
	eori.b	#2,d5
	or.b	d5,d4
	ori.b	#$C,d4

.DrawLoop:
	move.b	aField0(a0),d5
	and.b	d4,d5
	beq.s	.NextActor
	
	btst	#7,aDrawFlags(a0)
	beq.s	.NextActor

	move.l	d2,-(sp)
	bsr.w	DrawActorSprite
	move.l	(sp)+,d2

.NextActor:
	adda.l	d2,a0
	dbf	d0,.DrawLoop

	bsr.w	SetSpriteLinks
	lsl.w	#2,d1
	move.w	d1,sprite_count
	not.w	draw_order
	rts

; --------------------------------------------------------------
; Set sprite links
; --------------------------------------------------------------
; PARAMETERS:
;	d1.w	- Sprite count
; --------------------------------------------------------------

SetSpriteLinks:
	lea	sprite_layers,a0
	lea	sprite_links,a1
	
	move.w	#5-1,d0
	move.b	#0,d2			; last linked sprite should be 0

.LayerLoop:
	move.w	d1,d3
	subq.w	#1,d3

.CheckLayer:
	cmp.b	(a0,d3.w),d0
	bne.s	.NextLayer
	move.b	d2,(a1,d3.w)		; write sprite link
	move.b	d3,d2			; copy next sprite index

.NextLayer:
	dbf	d3,.CheckLayer
	dbf	d0,.LayerLoop

	lea	sprite_buffer,a0
	move.w	d1,d0
	subq.w	#1,d0

.SetLinks:
	move.b	(a1)+,3(a0)
	addq.l	#8,a0
	dbf	d0,.SetLinks

	rts

; --------------------------------------------------------------
; Draw an actor
; --------------------------------------------------------------
; PARAMETERS:
;	d1.w	- Current sprite count
;	a0.l	- Pointer to actor slot
;	a1.l	- Pointer to sprite buffer
;	a2.l	- Pointer to sprite mappings data table
;	a4.l	- Pointer to sprite layer buffer
; --------------------------------------------------------------

DrawActorSprite:
	cmpi.w	#80,d1
	bhs.s	.NoDraw
	clr.w	d2
	move.b	aMappings(a0),d2
	add.w	d2,d2
	add.w	d2,d2
	movea.l	(a2,d2.w),a5

	clr.w	d2
	move.b	aFrame(a0),d2
	add.w	d2,d2
	add.w	d2,d2
	movea.l	(a5,d2.w),a3
	move.w	(a3)+,d2
	subq.w	#1,d2

; DrawActorSpritePiece:
.DrawPieces:
	addq.w	#1,d1

	move.w	(a3)+,d3
	add.w	aY(a0),d3
	sub.w	vscroll_buffer,d3
	move.w	d3,(a1)+

	move.b	(a3)+,(a1)+
	adda.l	#1,a1		; skip link (handled in SetSpriteLinks)
	move.b	(a3)+,(a4)+	; store sprite priority in buffer
	move.w	(a3)+,(a1)+

	move.w	(a3)+,d3
	add.w	aX(a0),d3
	bne.s	.SetX
	addq.w	#1,d3

.SetX:
	move.w	d3,(a1)+

	cmpi.w	#80,d1
	dbhs	d2,.DrawPieces	; if no more sprites can be rendered, end loop
;	bhs.s	.NoDraw
.NoDraw:
	rts

; =============== S U B	R O U T	I N E =======================================

sub_11E90:
	movem.l	d3-d4/a2,-(sp)
	move.b	d2,d3
	lsl.b	#1,d3
	lea	(byte_FF1D4E).l,a2
	tst.b	$2A(a0)
	beq.s	loc_11EAC
	lea	(byte_FF1D58).l,a2

loc_11EAC:
	move.b	8(a2),d4
	cmp.b	d4,d3
	bcs.s	loc_11EC8
	move.b	9(a2),d4
	cmp.b	d3,d4
	bcs.s	loc_11EC8
	movem.l	(sp)+,d3-d4/a2
	bra.w	sub_11ECE
; ---------------------------------------------------------------------------

loc_11EC8:
	movem.l	(sp)+,d3-d4/a2
	rts
; End of function sub_11E90

; =============== S U B	R O U T	I N E =======================================

sub_11ECE:
	move.l	a1,-(sp)
	lea	(byte_FF1D4E).l,a1
	tst.b	$2A(a0)
	beq.s	loc_11EE6
	lea	(byte_FF1D58).l,a1

loc_11EE6:
	move.b	#0,1(a1)
	move.l	(sp)+,a1
	rts
; End of function sub_11ECE

; =============== S U B	R O U T	I N E =======================================

; This code handles the loading of the lesson mode text in Practise Stage 1
; As the art assets for this have been removed in Mean Bean, said text loads
; garbage art tiles, as such, functionality has been removed for convenience

;sub_11EF2:
;	move.b	(level_mode).l,d2
;	or.b	(level).l,d2
;	or.b	$2A(a0),d2
;	bne.w	locret_11F48
;	lea	(sub_11F4A).l,a1
;	jsr	(FindActorSlotQuick).l
;	bcs.w	locret_11F48
;	move.b	0(a0),0(a1)
;	move.b	#$80,6(a1)
;	move.b	#$2A,8(a1)
;	move.b	#3,9(a1)
;	jsr	(GetPuyoFieldPos).l
;	addi.w	#$30,d0
;	move.w	d0,$A(a1)
;	move.w	#$D0,$E(a1)
;	move.w	#$D0,$26(a1)
;
;locret_11F48:
;	rts
;; End of function sub_11EF2

; =============== S U B	R O U T	I N E =======================================

;sub_11F4A:
;	subq.w	#1,$26(a0)
;	beq.w	loc_11F74
;	addq.b	#1,$28(a0)
;	andi.b	#$1F,$28(a0)
;	move.b	#$80,6(a0)
;	cmpi.b	#$18,$28(a0)
;	bcs.w	locret_11F72
;	move.b	#0,6(a0)

;locret_11F72:
;	rts
; ---------------------------------------------------------------------------

;loc_11F74:
;	move.b	#$85,6(a0)
;	move.w	#$FFFF,$20(a0)
;	move.w	#$3000,$1C(a0)
;	move.w	#1,$16(a0)
;	jsr	(ActorBookmark).l
;	jsr	(sub_3810).l
;	bcs.w	loc_11F9E
;	rts
; ---------------------------------------------------------------------------

;loc_11F9E:
;	jmp	(ActorDeleteSelf).l
; End of function sub_11F4A

; =============== S U B	R O U T	I N E =======================================

sub_11FA4:
	move.b	(level_mode).l,d2
	or.b	(level).l,d2
	or.b	$2A(a0),d2
	bne.w	locret_11FFC
	lea	(sub_12048).l,a1
	jsr	(FindActorSlot).l
	bcs.w	locret_11FFC
	move.b	0(a0),0(a1)
	move.l	a0,$2E(a1)
	move.b	d0,$26(a1)
	move.b	d1,$27(a1)
	move.b	$2A(a0),$2A(a1)
	move.w	#$15,$28(a1)
	cmp.b	d0,d1
	bne.s	loc_11FF2
	move.w	#$A,$28(a1)

loc_11FF2:
	move.b	#$FF,7(a1)
	bsr.w	sub_11FFE

locret_11FFC:
	rts
; End of function sub_11FA4

; =============== S U B	R O U T	I N E =======================================

sub_11FFE:
	lea	(byte_FF19B6).l,a1
	tst.b	$2A(a0)
	beq.s	loc_12012
	lea	(byte_FF1B60).l,a1

loc_12012:
	jsr	(GetPuyoField).l
	move.w	#PUYO_FIELD_COLS-1,d0
	move.w	#pVisiblePuyos+(PUYO_FIELD_COLS*$B*2),d1

loc_12020:
	move.w	d1,d2

loc_12022:
	tst.b	(a2,d2.w)
	beq.s	loc_12030
	subi.w	#PUYO_FIELD_COLS*2,d2
	bcc.s	loc_12022

loc_12030:
	move.w	d2,(a1)+
	subi.w	#PUYO_FIELD_COLS*2,d2
	move.w	d2,(a1)+
	addq.w	#2,d1
	dbf	d0,loc_12020
	adda.l	#(PUYO_FIELD_COLS*(PUYO_FIELD_ROWS-2)*2)+2,a1
	clr.w	(a1)
	rts
; End of function sub_11FFE

; =============== S U B	R O U T	I N E =======================================

sub_12048:
	bsr.w	sub_120E8
	bcs.s	loc_120D6
	bsr.w	sub_1213E
	jsr	(sub_5960).l
	bsr.w	sub_1216C
	adda.l	#$18,a1
	adda.l	#$18,a2
	move.w	#$47,d0
	clr.w	d1

loc_12070:
	move.w	d0,d2
	lsl.w	#1,d2
	tst.b	(a3,d2.w)
	bmi.w	loc_1208E
	tst.b	(a2,d2.w)
	beq.s	loc_1208E
	addq.w	#1,d1
	move.w	d1,d2
	lsl.w	#1,d2
	move.w	d0,(a1,d2.w)

loc_1208E:
	dbf	d0,loc_12070
	move.w	d1,(a1)
	beq.s	loc_1209C
	bsr.w	sub_12218

loc_1209C:
	subq.w	#1,$28(a0)
	bcs.s	loc_120A6
	rts
; ---------------------------------------------------------------------------

loc_120A6:
	move.b	#$FF,$2D(a0)
	clr.w	$28(a0)
	jsr	(ActorBookmark).l
	addi.w	#$C,$28(a0)
	move.b	$28(a0),d0
	cmp.b	$2C(a0),d0
	bcs.s	loc_120CC
	clr.b	$28(a0)

loc_120CC:
	bsr.w	sub_120E8
	bcs.s	loc_120D6
	rts
; ---------------------------------------------------------------------------

loc_120D6:
	move.b	#0,7(a0)
	jsr	(ActorBookmark).l
	jmp	(ActorDeleteSelf).l
; End of function sub_12048

; =============== S U B	R O U T	I N E =======================================

sub_120E8:
	movea.l	$2E(a0),a1
	move.b	7(a1),d0
	andi.b	#3,d0
	cmpi.b	#3,d0
	bne.s	loc_12138
	tst.b	(level_mode).l
	bne.s	loc_12116
	tst.w	(puyos_popping).l
	bne.s	loc_12138
	andi	#$FFFE,sr
	rts
; ---------------------------------------------------------------------------

loc_12116:
	tst.b	$2B(a0)
	bne.s	loc_12138
	clr.w	d0
	move.b	$2A(a0),d0
	lea	(puyos_popping).l,a1
	tst.b	(a1,d0.w)
	bne.s	loc_12138
	andi	#$FFFE,sr
	rts
; ---------------------------------------------------------------------------

loc_12138:
	ori	#1,sr
	rts
; End of function sub_120E8

; =============== S U B	R O U T	I N E =======================================

sub_1213E:
	bsr.w	sub_1218A
	tst.w	d0
	bmi.w	loc_12156
	move.b	$26(a0),d2
	lsl.b	#4,d2
	ori.b	#$80,d2
	move.b	d2,(a2,d0.w)

loc_12156:
	tst.w	d1
	bmi.w	locret_1216A
	move.b	$27(a0),d2
	lsl.b	#4,d2
	ori.b	#$80,d2
	move.b	d2,(a2,d1.w)

locret_1216A:
	rts
; End of function sub_1213E

; =============== S U B	R O U T	I N E =======================================

sub_1216C:
	bsr.w	sub_1218A
	tst.w	d0
	bmi.w	loc_1217C
	move.b	#0,(a2,d0.w)

loc_1217C:
	tst.w	d1
	bmi.w	locret_12188
	move.b	#0,(a2,d1.w)

locret_12188:
	rts
; End of function sub_1216C

; =============== S U B	R O U T	I N E =======================================

sub_1218A:
	jsr	(GetPuyoField).l
	lea	(byte_FF19B6).l,a1
	tst.b	$2A(a0)
	beq.s	loc_121A4
	lea	(byte_FF1B60).l,a1

loc_121A4:
	move.w	$28(a0),d2
	lsl.w	#2,d2
	move.w	word_121C0(pc,d2.w),d3
	lsl.w	#1,d3
	move.w	(a1,d3.w),d0
	move.w	word_121C2(pc,d2.w),d3
	lsl.w	#1,d3
	move.w	(a1,d3.w),d1
	rts
; End of function sub_1218A

; ---------------------------------------------------------------------------
word_121C0:	dc.w 0

word_121C2:
	dc.w 1
	dc.w 2
	dc.w 3
	dc.w 4
	dc.w 5
	dc.w 6
	dc.w 7
	dc.w 8
	dc.w 9
	dc.w $A
	dc.w $B
	dc.w 0
	dc.w 2
	dc.w 2
	dc.w 4
	dc.w 4
	dc.w 6
	dc.w 6
	dc.w 8
	dc.w 8
	dc.w $A
	dc.w 1
	dc.w 0
	dc.w 3
	dc.w 2
	dc.w 5
	dc.w 4
	dc.w 7
	dc.w 6
	dc.w 9
	dc.w 8
	dc.w $B
	dc.w $A
	dc.w 2
	dc.w 0
	dc.w 4
	dc.w 2
	dc.w 6
	dc.w 4
	dc.w 8
	dc.w 6
	dc.w $A
	dc.w 8

; =============== S U B	R O U T	I N E =======================================

sub_12218:
	bsr.w	sub_122A0
	bcc.s	loc_12222
	rts
; ---------------------------------------------------------------------------

loc_12222:
	lea	(byte_FF19CE).l,a2
	tst.b	$2A(a0)
	beq.s	loc_12236
	lea	(byte_FF1B78).l,a2

loc_12236:
	jsr	(GetPuyoFieldPos).l
	addq.w	#8,d0
	addq.w	#8,d1
	move.w	(a2)+,d2
	subq.w	#1,d2

loc_12244:
	lea	(sub_12300).l,a1
	jsr	(FindActorSlotQuick).l
	bcs.s	loc_1228A
	move.b	0(a0),0(a1)
	move.l	a0,$2E(a1)
	move.b	#$2A,8(a1)
	move.l	#unk_12294,$32(a1)
	move.b	$2C(a0),$26(a1)
	moveq	#0,d3
	move.w	(a2)+,d3
	divu.w	#6,d3
	lsl.l	#4,d3
	add.w	d1,d3
	move.w	d3,$E(a1)
	swap	d3
	add.w	d0,d3
	move.w	d3,$A(a1)

loc_1228A:
	dbf	d2,loc_12244
	addq.b	#1,$2C(a0)
	rts
; End of function sub_12218

; ---------------------------------------------------------------------------
; TODO: Document Animation Code

unk_12294:
	dc.b   1
	dc.b   0
	dc.b   1
	dc.b   1
	dc.b   1
	dc.b   2
	dc.b $FF
	dc.b   0
	dc.l unk_12294

; =============== S U B	R O U T	I N E =======================================

sub_122A0:
	movea.l	a1,a2
	adda.l	#$92,a2
	clr.w	d0

loc_122AA:
	move.w	(a2,d0.w),d1
	beq.s	loc_122DC
	move.l	a1,-(sp)
	move.b	#0,d2

loc_122BA:
	move.w	(a1)+,d3
	cmp.w	(a2,d0.w),d3
	beq.s	loc_122C8
	move.b	#$FF,d2

loc_122C8:
	addq.w	#2,d0
	dbf	d1,loc_122BA
	move.l	(sp)+,a1
	tst.b	d2
	bne.s	loc_122AA
	ori	#1,sr
	rts
; ---------------------------------------------------------------------------

loc_122DC:
	move.w	(a1),d1
	addq.w	#1,d1
	lsl.w	#1,d1
	add.w	d0,d1
	bcc.s	loc_122EA
	rts
; ---------------------------------------------------------------------------

loc_122EA:
	move.w	(a1),d1

loc_122EC:
	move.w	(a1)+,(a2,d0.w)
	addq.w	#2,d0
	dbf	d1,loc_122EC
	clr.w	(a2,d0.w)
	andi	#$FFFE,sr
	rts
; End of function sub_122A0

; =============== S U B	R O U T	I N E =======================================

sub_12300:
	movea.l	$2E(a0),a1
	tst.b	7(a1)
	beq.s	loc_12334
	jsr	(ActorAnimate).l
	move.b	#0,6(a0)
	tst.b	$2D(a1)
	beq.w	locret_12332
	move.b	$28(a1),d0
	cmp.b	$26(a0),d0
	bne.w	locret_12332
	move.b	#$80,6(a0)

locret_12332:
	rts
; ---------------------------------------------------------------------------

loc_12334:
	jmp	(ActorDeleteSelf).l
; End of function sub_12300

; =============== S U B	R O U T	I N E =======================================

sub_1233A:
	lea	(byte_FF1D4E).l,a2
	move.w	#9,d0
	clr.w	d1

loc_12346:
	move.w	d1,(a2)+
	dbf	d0,loc_12346
	move.b	(level_mode).l,d0
	andi.b	#3,d0
	beq.s	loc_1235C
	rts
; ---------------------------------------------------------------------------

loc_1235C:
	clr.w	(puyos_popping).l
	clr.w	(puyo_field_p2+pCount).l
	lea	(sub_12374).l,a1
	jmp	(FindActorSlot).l
; End of function sub_1233A

; =============== S U B	R O U T	I N E =======================================

sub_12374:
	tst.w	(puyos_popping).l
	bne.s	loc_1239C
	addq.w	#1,$26(a0)
	andi.w	#$7FFF,$26(a0)
	addq.w	#1,$28(a0)
	andi.w	#$7FFF,$28(a0)
	bsr.w	sub_12460
	bsr.w	sub_123AE
	rts
; ---------------------------------------------------------------------------

loc_1239C:
	addq.w	#1,(pal_fade_data+$186).l
	jsr	(sub_61C0).l
	jmp	(ActorDeleteSelf).l
; End of function sub_12374

; =============== S U B	R O U T	I N E =======================================

sub_123AE:
	move.b	#1,(byte_FF1121).l
	tst.w	$2A(a0)
	beq.s	loc_123F0
	subq.w	#1,$2A(a0)
	bne.w	locret_1244C
	moveq	#0,d0
	move.b	(opponent).l,d0
	lea	(OpponentPalettes).l,a1
	move.b	(a1,d0.w),d0
	lsl.w	#5,d0
	lea	(Palettes).l,a2
	adda.l	d0,a2
	move.b	#3,d0
	move.b	#0,d1
	jmp	(FadeToPalette).l
; ---------------------------------------------------------------------------

loc_123F0:
	move.w	(puyo_field_p2+pCount).l,d0
	lsr.w	#3,d0
	cmpi.w	#9,d0
	bcs.s	loc_12404
	move.w	#8,d0

loc_12404:
	lsl.w	#1,d0
	lea	(unk_1244E).l,a1
	move.w	(a1,d0.w),d1
	bmi.w	loc_12444
	cmp.w	$28(a0),d1
	bcc.w	locret_1244C
	clr.w	$28(a0)
	move.b	#3,d0
	move.b	#1,d1
	move.b	#3,d2
	lea	(Palettes).l,a2
	adda.l	#(Pal_White-Palettes),a2
	jsr	(FadeToPal_StepCount).l
	move.w	#$26,$2A(a0)

loc_12444:
	move.b	#0,(byte_FF1121).l

locret_1244C:
	rts
; End of function sub_123AE

; ---------------------------------------------------------------------------
unk_1244E:
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b   0
	dc.b $60
	dc.b   0
	dc.b $30

; =============== S U B	R O U T	I N E =======================================

sub_12460:
	move.w	(puyo_field_p2+pCount).l,d0
	lsr.w	#3,d0
	cmpi.w	#9,d0
	bcs.s	loc_12474
	move.w	#8,d0

loc_12474:
	lsl.w	#1,d0
	lea	(unk_124FE).l,a1
	move.w	(a1,d0.w),d1
	cmp.w	$26(a0),d1
	bcc.w	locret_124FC
	clr.w	$26(a0)
	lea	(loc_1251C).l,a1
	jsr	(FindActorSlotQuick).l
	bcs.w	locret_124FC
	move.b	#$25,8(a1)
	move.w	#$1800,$1C(a1)
	move.w	#$FFFF,$20(a1)
	jsr	(Random).l
	clr.w	d1
	move.b	d0,d1
	andi.b	#$7F,d1
	addi.w	#$240,d1
	andi.b	#$5F,d0
	addi.b	#-$70,d0
	move.l	#unk_12510,$32(a1)
	jsr	(Sin).l
	move.l	d2,$16(a1)
	asl.l	#4,d2
	swap	d2
	addi.w	#$110,d2
	move.w	d2,$E(a1)
	jsr	(Cos).l
	move.l	d2,$12(a1)
	asl.l	#4,d2
	swap	d2
	addi.w	#$120,d2
	move.w	d2,$A(a1)

locret_124FC:
	rts
; End of function sub_12460

; ---------------------------------------------------------------------------
unk_124FE:
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b $FF
	dc.b   0
	dc.b   3
	dc.b   0
	dc.b   2
	dc.b   0
	dc.b   1

; TODO: Document animation code

unk_12510:
	dc.b  $C
	dc.b  $A
	dc.b   6
	dc.b   6
	dc.b $FE
	dc.b   0

unk_12516:
	dc.b   3
	dc.b   6
	dc.b   3
	dc.b  $A
	dc.b $FE
	dc.b   0
; ---------------------------------------------------------------------------

loc_1251C:
	jsr	(ActorAnimate).l
	move.b	#$87,6(a0)
	jsr	(ActorBookmark).l
	jsr	(sub_3810).l
	jsr	(ActorAnimate).l
	bcs.s	loc_12540
	rts
; ---------------------------------------------------------------------------

loc_12540:
	move.l	#unk_12516,$32(a0)
	jsr	(ActorBookmark).l
	jsr	(ActorAnimate).l
	bcs.s	loc_1255A
	rts
; ---------------------------------------------------------------------------

loc_1255A:
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------
	rts

; =============== S U B	R O U T	I N E =======================================

sub_12562:
	move.l	d0,-(sp)
	move.w	#5,d0
	tst.b	$2A(a0)
	beq.s	loc_12578
	move.b	(opponent).l,d0

loc_12578:
	lsl.w	#2,d0
	movea.l	AIData_Pointers(pc,d0.w),a2
	move.l	(sp)+,d0
	rts
; End of function sub_12562

; ---------------------------------------------------------------------------
AIData_Pointers: ; AI?
	dc.l AIData_SkeletonT		; Puyo Leftover
	dc.l AIData_Frankly
	dc.l AIData_Dynamight
	dc.l AIData_Arms
	dc.l AIData_NasuGrave		; Puyo Leftover
	dc.l AIData_Grounder
	dc.l AIData_Davy
	dc.l AIData_Coconuts
	dc.l AIData_Spike
	dc.l AIData_SirFfuzzy
	dc.l AIData_DragonBreath
	dc.l AIData_Scratch
	dc.l AIData_Robotnik
	dc.l AIData_Mummy		; Puyo Leftover
	dc.l AIData_Humpty
	dc.l AIData_Skweel

AIData_SkeletonT:
	dc.b   0
	dc.b $C0
	dc.b   3
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $FF
	dc.b   0

AIData_NasuGrave:
	dc.b   0
	dc.b $40
	dc.b $FF
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $FF
	dc.b $83

AIData_Mummy:
	dc.b   0
	dc.b $10
	dc.b $FF
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $FF
	dc.b $83

AIData_Arms:
	dc.b   0
	dc.b $80
	dc.b $FF
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $FF
	dc.b $82 ; Rotate Beans

AIData_Frankly:
	dc.b   0
	dc.b $60
	dc.b $FF
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $FF
	dc.b $83 ; Rotate Beans

AIData_Humpty:
	dc.b   0
	dc.b $20
	dc.b   8
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $FF
	dc.b $83

AIData_Coconuts:
	dc.b   0
	dc.b   8
	dc.b   8
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $FF
	dc.b $83

AIData_Davy:
	dc.b $40
	dc.b   8
	dc.b $FF
	dc.b $30
	dc.b $24
	dc.b   0
	dc.b  $C
	dc.b $83

AIData_Skweel:
	dc.b   0
	dc.b   0
	dc.b $FF
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $FF
	dc.b $83

AIData_Dynamight:
	dc.b $20
	dc.b   0
	dc.b $FF
	dc.b $3C
	dc.b $30
	dc.b $6E
	dc.b $FF
	dc.b $83

AIData_Grounder:
	dc.b $10
	dc.b   0
	dc.b $FF
	dc.b $30
	dc.b $30
	dc.b $2C
	dc.b $FF
	dc.b $83

AIData_Spike:
	dc.b   0
	dc.b   0
	dc.b $FF
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $FF
	dc.b $83

AIData_SirFfuzzy:
	dc.b   0
	dc.b   0
	dc.b $FF
	dc.b $3C
	dc.b $30
	dc.b $2A
	dc.b $FF
	dc.b $83

AIData_DragonBreath:
	dc.b   0
	dc.b   0
	dc.b $FF
	dc.b $30
	dc.b $24
	dc.b $66
	dc.b $FF
	dc.b $83

AIData_Scratch:
	dc.b   0
	dc.b   0
	dc.b $FF
	dc.b $30
	dc.b $24
	dc.b   0
	dc.b   8
	dc.b $83

AIData_Robotnik:
	dc.b   0
	dc.b   0
	dc.b $FF
	dc.b $24
	dc.b $24
	dc.b   0
	dc.b   8
	dc.b $83

; =============== S U B	R O U T	I N E =======================================

nullsub_4:
	rts
; End of function nullsub_4

; =============== S U B	R O U T	I N E =======================================

sub_12646:
	move.b	(level_mode).l,d0
	btst	#2,d0
	bne.s	loc_1266E
	lsl.b	#1,d0
	or.b	$2A(a0),d0
	eori.b	#1,d0
	and.b	(control_player_1).l,d0
	beq.s	loc_1266E
	andi	#$FFFE,sr
	rts
; ---------------------------------------------------------------------------

loc_1266E:
	ori	#1,sr
	rts
; End of function sub_12646

; =============== S U B	R O U T	I N E =======================================

sub_12674:
	lea	(byte_FF1D4E).l,a6
	tst.b	$2A(a0)
	beq.s	loc_12688
	lea	(byte_FF1D58).l,a6

loc_12688:
	cmpi.w	#2,(time_minutes).l
	bcs.s	loc_1269E
	move.b	#1,0(a6)
	bra.w	loc_126D6
; ---------------------------------------------------------------------------

loc_1269E:
	tst.b	0(a6)
	bne.s	loc_126C0
	move.b	9(a4),d0
	cmp.b	3(a2),d0
	bcs.s	loc_126D6
	eori.b	#1,0(a6)
	clr.b	1(a6)
	bra.w	loc_126D6
; ---------------------------------------------------------------------------

loc_126C0:
	move.b	9(a4),d0
	cmp.b	4(a2),d0
	bcc.s	loc_126D6
	eori.b	#1,0(a6)
	bra.w	*+4
; ---------------------------------------------------------------------------

loc_126D6:
	clr.w	d0
	move.b	0(a6),d0
	rts
; End of function sub_12674

; =============== S U B	R O U T	I N E =======================================

sub_126DE:
	tst.b	$2A(a0)
	bne.s	loc_126E8
	rts
; ---------------------------------------------------------------------------

loc_126E8:
	clr.w	d0
	move.b	(opponent).l,d0
	lsl.b	#2,d0
	movea.l	SpecAI_Pointers(pc,d0.w),a6
	jmp	(a6)
; End of function sub_126DE

; ---------------------------------------------------------------------------
SpecAI_Pointers: ; AI Special
	dc.l SpecAI_Null	; Skeleton Tea - Puyo Leftover
	dc.l SpecAI_Frankly	; Frankly
	dc.l SpecAI_Null	; Dynamight
	dc.l SpecAI_Null	; Arms
	dc.l SpecAI_Null	; Nasu Grave - Puyo Leftover
	dc.l SpecAI_Null	; Grounder
	dc.l SpecAI_Null	; Davy Sprocket
	dc.l SpecAI_Coconuts	; Coconuts
	dc.l SpecAI_Null	; Spike
	dc.l SpecAI_Null	; Sir Ffuzzy-Logik
	dc.l SpecAI_Null	; Dragon Breath
	dc.l SpecAI_Null	; Scratch
	dc.l SpecAI_Null	; Robotnik
	dc.l SpecAI_Null	; Mummy - Puyo Leftover
	dc.l SpecAI_Null	; Humpty
	dc.l SpecAI_Null	; Skweel
; ---------------------------------------------------------------------------

SpecAI_Null:
	rts

; ---------------------------------------------------------------------------

SpecAI_Coconuts:
	move.b	0(a5),d0
	or.b	$A(a5),d0
	bne.s	loc_12748
	rts
; ---------------------------------------------------------------------------

loc_12748:
	move.b	#0,$20(a0)
	move.b	#0,$21(a0)
	move.b	0(a5),d0
	cmp.b	$A(a5),d0
	bcc.s	loc_12766
	move.b	#5,$20(a0)

loc_12766:
	movem.l	(sp)+,a6
	move.b	#0,$2C(a0)
	move.b	#$FF,$2D(a0)
	rts
; ---------------------------------------------------------------------------

SpecAI_Frankly:
	cmpi.w	#$18,8(a4)
	bcs.s	loc_12784
	rts
; ---------------------------------------------------------------------------

loc_12784:
	movem.l	(sp)+,a6
	move.w	#5,d0
	clr.b	d1

loc_1278E:
	move.w	d0,d2
	lsl.w	#1,d2
	move.b	(a5,d2.w),d3
	cmp.b	d1,d3
	bcs.s	loc_127A2
	move.b	d0,$20(a0)
	move.b	d3,d1

loc_127A2:
	dbf	d0,loc_1278E
	move.b	#0,$21(a0)
	move.b	#0,$2C(a0)
	move.b	#$FF,$2D(a0)
	rts

; =============== S U B	R O U T	I N E =======================================

sub_127BA:
	bsr.w	sub_12646
	bcs.s	loc_127C4
	rts
; ---------------------------------------------------------------------------

loc_127C4:
	jsr	(GetPuyoField).l
	movea.l	a2,a3
	movea.l	a2,a4
	movea.l	a2,a5
	bsr.w	sub_12562
	adda.l	#pUnk1,a3
	adda.l	#pUnk2,a4
	adda.l	#pUnk3,a5
	movea.l	$32(a0),a1
	bsr.w	sub_12674
	move.b	d0,d3
	bsr.w	sub_128B8
	bsr.w	sub_12FAE
	bsr.w	sub_126DE
	clr.w	d0
	lea	(byte_FF1D1E).l,a6

loc_12804:
	move.b	$26(a1),d1
	bsr.w	sub_12920
	move.w	d4,(a6)+
	move.b	$27(a1),d1
	bsr.w	sub_12920
	move.w	d4,(a6)+
	addq.w	#1,d0
	cmpi.w	#$C,d0
	bcs.s	loc_12804
	move.w	#$15,d0
	clr.w	d1
	clr.w	d2
	lea	(unk_12860).l,a1
	lea	(byte_FF1D1E).l,a6

loc_12834:
	move.w	(a1)+,d3
	move.w	(a1)+,d4
	clr.w	d5
	move.w	(a6,d3.w),d6
	beq.s	loc_1284C
	move.w	(a6,d4.w),d5
	beq.s	loc_1284C
	add.w	d6,d5

loc_1284C:
	cmp.w	d1,d5
	bcs.s	loc_12856
	move.w	d5,d1
	move.w	d0,d2

loc_12856:
	dbf	d0,loc_12834
	move.w	d2,d0
	bra.w	loc_12B14
; End of function sub_127BA

; ---------------------------------------------------------------------------
unk_12860:
	dc.b   0
	dc.b $2C
	dc.b   0
	dc.b $26
	dc.b   0
	dc.b $24
	dc.b   0
	dc.b $1E
	dc.b   0
	dc.b $1C
	dc.b   0
	dc.b $16
	dc.b   0
	dc.b $14
	dc.b   0
	dc.b  $E
	dc.b   0
	dc.b  $C
	dc.b   0
	dc.b   6
	dc.b   0
	dc.b $24
	dc.b   0
	dc.b $2E
	dc.b   0
	dc.b $1C
	dc.b   0
	dc.b $26
	dc.b   0
	dc.b $14
	dc.b   0
	dc.b $1E
	dc.b   0
	dc.b  $C
	dc.b   0
	dc.b $16
	dc.b   0
	dc.b   4
	dc.b   0
	dc.b  $E
	dc.b   0
	dc.b $28
	dc.b   0
	dc.b $2E
	dc.b   0
	dc.b $20
	dc.b   0
	dc.b $26
	dc.b   0
	dc.b $18
	dc.b   0
	dc.b $1E
	dc.b   0
	dc.b $10
	dc.b   0
	dc.b $16
	dc.b   0
	dc.b   8
	dc.b   0
	dc.b  $E
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   6
	dc.b   0
	dc.b $2C
	dc.b   0
	dc.b $2A
	dc.b   0
	dc.b $24
	dc.b   0
	dc.b $22
	dc.b   0
	dc.b $1C
	dc.b   0
	dc.b $1A
	dc.b   0
	dc.b $14
	dc.b   0
	dc.b $12
	dc.b   0
	dc.b  $C
	dc.b   0
	dc.b  $A
	dc.b   0
	dc.b   4
	dc.b   0
	dc.b   2

; =============== S U B	R O U T	I N E =======================================

sub_128B8:
	move.l	d0,-(sp)
	move.b	(a2,d0.w),d2
	bsr.w	sub_128EA
	bsr.w	sub_12906
	move.b	d0,$2C(a0)
	move.b	2(a2),d2
	bsr.w	sub_12906
	move.b	d0,$2D(a0)
	move.b	#0,$27(a0)
	move.b	#0,$26(a0)
	move.l	(sp)+,d0
	rts
; End of function sub_128B8

; =============== S U B	R O U T	I N E =======================================

sub_128EA:
	move.b	(byte_FF0104).l,d0
	subq.b	#2,d0
	bcc.s	loc_128F8
	clr.b	d0

loc_128F8:
	lsl.b	#4,d0
	add.b	d0,d2
	bcc.w	locret_12904
	move.b	#$FF,d2

locret_12904:
	rts
; End of function sub_128EA

; =============== S U B	R O U T	I N E =======================================

sub_12906:
	clr.w	d0
	move.b	d2,d0
	cmpi.b	#$FF,d0
	beq.w	locret_1291E
	lsr.b	#1,d2
	move.b	d2,d0
	jsr	(RandomBound).l
	add.b	d2,d0

locret_1291E:
	rts
; End of function sub_12906

; =============== S U B	R O U T	I N E =======================================

sub_12920:
	bsr.w	sub_1295E
	bsr.w	sub_12AA4
	bsr.w	sub_12982
	bsr.w	sub_129B8
	move.b	(byte_FF1D16).l,d4
	move.b	(byte_FF1D17).l,d5
	move.b	(byte_FF1D18).l,d6
	move.b	$2A(a0),d2
	ror.b	#1,d2
	eori.b	#$80,d2
	or.b	7(a2),d2
	bpl.w	loc_12958
	lsl.b	#3,d5
	lsl.b	#1,d6

loc_12958:
	add.b	d5,d4
	add.b	d6,d4
	rts
; End of function sub_12920

; =============== S U B	R O U T	I N E =======================================

sub_1295E:
	move.b	#0,d2
	tst.b	d3
	bne.s	loc_1296C
	move.b	5(a2),d2

loc_1296C:
	move.w	d0,d4
	lsr.w	#1,d4

loc_12970:
	lsl.b	#1,d2
	dbf	d4,loc_12970
	andi.b	#$80,d2
	move.b	d2,(byte_FF1D1D).l
	rts
; End of function sub_1295E

; =============== S U B	R O U T	I N E =======================================

sub_12982:
	move.b	(byte_FF1D16).l,d1
	subq.b	#1,d1
	cmpi.b	#3,d1
	bcc.w	locret_129B6
	addq.b	#3,(byte_FF1D16).l
	cmpi.b	#4,(byte_FF1D19).l
	bcc.w	locret_129B6
	clr.b	(byte_FF1D19).l
	clr.b	(byte_FF1D1B).l
	subq.b	#4,(byte_FF1D16).l

locret_129B6:
	rts
; End of function sub_12982

; =============== S U B	R O U T	I N E =======================================

sub_129B8:
	clr.b	(byte_FF1D17).l
	clr.b	(byte_FF1D18).l
	bsr.w	sub_129CE
	bsr.w	sub_12A54
	rts
; End of function sub_129B8

; =============== S U B	R O U T	I N E =======================================

sub_129CE:
	clr.w	d1
	move.b	(byte_FF1D19).l,d1
	subq.b	#1,d1
	bpl.w	loc_129DE
	rts
; ---------------------------------------------------------------------------

loc_129DE:
	cmpi.b	#4,d1
	bcs.s	loc_129EA
	move.b	#3,d1

loc_129EA:
	move.b	(byte_FF1D1A).l,d2
	cmpi.b	#5,d2
	bcs.s	loc_129FC
	move.b	#4,d2

loc_129FC:
	lsl.b	#2,d2
	or.b	d2,d1
	tst.b	(byte_FF1D1D).l
	beq.s	loc_12A0E
	addi.b	#$14,d1

loc_12A0E:
	move.b	byte_12A2C(pc,d1.w),(byte_FF1D17).l
	bpl.w	locret_12A2A
	move.b	(byte_FF1D19).l,d1
	lsl.b	#1,d1
	addq.b	#1,d1
	move.b	d1,(byte_FF1D17).l

locret_12A2A:
	rts
; End of function sub_129CE

; ---------------------------------------------------------------------------
byte_12A2C:
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   3
	dc.b   5
	dc.b   7
	dc.b $FF
	dc.b   2
	dc.b   4
	dc.b   6
	dc.b $FF
	dc.b   1
	dc.b   3
	dc.b   5
	dc.b $FF
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $FF
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   3
	dc.b   5
	dc.b   7
	dc.b   0
	dc.b   2
	dc.b   4
	dc.b   6
	dc.b   0
	dc.b   1
	dc.b   3
	dc.b   5
	dc.b   0
	dc.b   4
	dc.b   6
	dc.b   8
	dc.b   0

; =============== S U B	R O U T	I N E =======================================

sub_12A54:
	clr.w	d1
	move.b	(byte_FF1D1B).l,d1
	subq.b	#1,d1
	bpl.w	loc_12A64
	rts
; ---------------------------------------------------------------------------

loc_12A64:
	cmpi.b	#4,d1
	bcs.s	loc_12A70
	move.b	#3,d1

loc_12A70:
	move.b	(byte_FF1D1C).l,d2
	cmpi.b	#5,d2
	bcs.s	loc_12A82
	move.b	#4,d2

loc_12A82:
	lsl.b	#2,d2
	or.b	d2,d1
	move.b	byte_12A2C(pc,d1.w),(byte_FF1D18).l
	bpl.w	locret_12AA2
	move.b	(byte_FF1D1B).l,d1
	lsl.b	#1,d1
	addq.b	#1,d1
	move.b	d1,(byte_FF1D18).l

locret_12AA2:
	rts
; End of function sub_12A54

; =============== S U B	R O U T	I N E =======================================

sub_12AA4:
	move.w	d0,d5
	lsl.w	#3,d5
	move.w	d5,d6
	or.b	d1,d6
	clr.w	d1
	move.b	$C(a5,d6.w),d1
	andi.b	#$F,d1
	move.b	d1,(byte_FF1D16).l
	move.b	$C(a5,d6.w),d1
	lsr.b	#4,d1
	move.b	d1,(byte_FF1D19).l
	bsr.w	sub_12AEA
	move.b	d1,(byte_FF1D1A).l
	move.b	$C(a5,d6.w),d1
	lsr.b	#4,d1
	move.b	d1,(byte_FF1D1B).l
	bsr.w	sub_12AEA
	move.b	d1,(byte_FF1D1C).l
	rts
; End of function sub_12AA4

; =============== S U B	R O U T	I N E =======================================

sub_12AEA:
	clr.b	d1
	move.w	#5,d2

loc_12AF0:
	cmp.w	d5,d6
	beq.s	loc_12B02
	cmp.b	$C(a5,d5.w),d1
	bcc.s	loc_12B02
	move.b	$C(a5,d5.w),d1

loc_12B02:
	addq.w	#1,d5
	dbf	d2,loc_12AF0
	lsr.b	#4,d1
	addi.w	#$5A,d5
	addi.w	#$60,d6
	rts
; End of function sub_12AEA

; ---------------------------------------------------------------------------
; START	OF FUNCTION CHUNK FOR sub_127BA

loc_12B14:
	lsl.w	#1,d0
	move.b	byte_12B30(pc,d0.w),$20(a0)
	move.b	byte_12B31(pc,d0.w),$21(a0)
	move.b	7(a2),d0
	andi.b	#3,d0
	and.b	d0,$21(a0)
	rts
; END OF FUNCTION CHUNK	FOR sub_127BA
; ---------------------------------------------------------------------------
byte_12B30:	dc.b   0

byte_12B31:
	dc.b   0
	dc.b   1
	dc.b   0
	dc.b   2
	dc.b   0
	dc.b   3
	dc.b   0
	dc.b   4
	dc.b   0
	dc.b   5
	dc.b   0
	dc.b   0
	dc.b   2
	dc.b   1
	dc.b   2
	dc.b   2
	dc.b   2
	dc.b   3
	dc.b   2
	dc.b   4
	dc.b   2
	dc.b   5
	dc.b   2
	dc.b   0
	dc.b   1
	dc.b   1
	dc.b   1
	dc.b   2
	dc.b   1
	dc.b   3
	dc.b   1
	dc.b   4
	dc.b   1
	dc.b   1
	dc.b   3
	dc.b   2
	dc.b   3
	dc.b   3
	dc.b   3
	dc.b   4
	dc.b   3
	dc.b   5
	dc.b   3

; =============== S U B	R O U T	I N E =======================================

sub_12B5C:
	jsr	(GetPuyoField).l
	adda.l	#pUnk3,a2
	move.w	#(PUYO_FIELD_COLS-1)*2,d0
	lea	(unk_12B8C).l,a3

loc_12B72:
	move.w	(a3)+,d1
	beq.s	loc_12B86
	add.w	d0,d1
	tst.b	(a2,d1.w)
	bne.s	loc_12B72
	clr.b	(a2,d0.w)
	bra.s	loc_12B72
; ---------------------------------------------------------------------------

loc_12B86:
	subq.w	#2,d0
	bcc.s	loc_12B72
	rts
; End of function sub_12B5C

; ---------------------------------------------------------------------------
unk_12B8C:
	dc.b $FF
	dc.b $FE
	dc.b $FF
	dc.b $FC
	dc.b $FF
	dc.b $FA
	dc.b   0
	dc.b   0
	dc.b $FF
	dc.b $FE
	dc.b $FF
	dc.b $FC
	dc.b   0
	dc.b   0
	dc.b $FF
	dc.b $FE
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   2
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   2
	dc.b   0
	dc.b   4
	dc.b   0
	dc.b   0

; =============== S U B	R O U T	I N E =======================================

sub_12BAA:
	jsr	(GetPuyoField).l
	movea.l	a2,a3
	movea.l	a2,a4
	movea.l	a2,a5
	adda.l	#pVisiblePuyos,a2
	adda.l	#pUnk2,a3
	adda.l	#pUnk3,a4
	adda.l	#pUnk1,a5
	move.w	#9,d0

loc_12BD2:
	clr.b	(a3,d0.w)
	dbf	d0,loc_12BD2
	move.w	#$47,d0
	clr.w	d1
	clr.w	d2

loc_12BE2:
	move.b	(a2,d1.w),d2
	beq.s	loc_12BF6
	lsr.b	#4,d2
	andi.b	#7,d2
	addq.b	#1,(a3,d2.w)
	addq.w	#1,8(a3)

loc_12BF6:
	addq.w	#2,d1
	dbf	d0,loc_12BE2
	clr.w	d0

loc_12BFE:
	bsr.w	sub_12C14
	move.w	d1,(a4)+
	addq.w	#1,d0
	cmpi.w	#PUYO_FIELD_COLS,d0
	bcs.s	loc_12BFE
	bsr.w	sub_12B5C
	bra.w	loc_12C38
; End of function sub_12BAA

; =============== S U B	R O U T	I N E =======================================

sub_12C14:
	move.w	#$C00,d1
	move.w	d0,d2
	lsl.w	#1,d2
	addi.w	#$84,d2

loc_12C20:
	tst.b	(a2,d2.w)
	beq.s	loc_12C30
	subi.w	#$100,d1
	move.b	(a5,d2.w),d1

loc_12C30:
	subi.w	#$C,d2
	bcc.s	loc_12C20
	rts
; End of function sub_12C14

; ---------------------------------------------------------------------------
; START	OF FUNCTION CHUNK FOR sub_12BAA

loc_12C38:
	move.b	(level_mode).l,d0
	andi.b	#3,d0
	lsl.b	#1,d0
	or.b	$2A(a0),d0
	eori.b	#1,d0
	beq.s	loc_12C52
	rts
; ---------------------------------------------------------------------------

loc_12C52:
	jsr	(GetPuyoField).l
	adda.l	#pUnk2,a2
	movea.l	a2,a3
	adda.l	#-$36A,a3
	move.w	#2,d0
	cmpi.w	#$24,8(a2)
	bcc.s	loc_12C82
	subq.w	#1,d0
	cmpi.w	#$24,8(a3)
	bcc.s	loc_12C82
	subq.w	#1,d0

loc_12C82:
	move.w	d0,(word_FF198C).l
	rts
; END OF FUNCTION CHUNK	FOR sub_12BAA

; =============== S U B	R O U T	I N E =======================================

sub_12C8A:
	bsr.w	sub_12646
	bcs.s	loc_12C94
	rts
; ---------------------------------------------------------------------------

loc_12C94:
	jsr	(GetPuyoField).l
	movea.l	a2,a3
	movea.l	a2,a4
	movea.l	a2,a5
	adda.l	#pVisiblePuyos,a2
	adda.l	#pUnk1,a3
	adda.l	#pUnk3,a4
	adda.l	#pUnk4,a5
	tst.b	(byte_FF1D0E).l
	beq.s	loc_12CC8
	adda.l	#pUnk5-pUnk4,a5

loc_12CC8:
	clr.w	d0

loc_12CCA:
	bsr.w	sub_12CE2
	bsr.w	sub_12DC2
	adda.l	#8,a5
	addq.w	#1,d0
	cmpi.w	#PUYO_FIELD_ROWS-2,d0
	bcs.s	loc_12CCA
	rts
; End of function sub_12C8A

; =============== S U B	R O U T	I N E =======================================

sub_12CE2:
	move.w	d0,d1
	lsr.w	#1,d1
	move.w	d0,d2
	andi.w	#1,d2
	subq.w	#2,d2
	clr.w	d3
	move.w	d1,d4
	lsl.w	#1,d4
	clr.w	d5
	move.b	(a4,d4.w),d5
	add.w	d5,d2
	bmi.s	loc_12D1E
	bsr.w	sub_12D68
	bcs.s	loc_12D1E
	move.l	a1,-(sp)
	move.w	d1,d3
	lsl.w	#2,d3
	movea.l	off_12D2C(pc,d3.w),a1
	move.b	(a1,d2.w),d3
	move.l	(sp)+,a1
	ori.b	#$10,d3

loc_12D1E:
	move.w	#7,d4

loc_12D22:
	move.b	d3,(a5,d4.w)
	dbf	d4,loc_12D22
	rts
; End of function sub_12CE2

; ---------------------------------------------------------------------------
off_12D2C:
	dc.l unk_12D44
	dc.l unk_12D50
	dc.l unk_12D5C
	dc.l unk_12D50
	dc.l unk_12D50
	dc.l unk_12D44

unk_12D44:
	dc.b   4
	dc.b   5
	dc.b   6
	dc.b   7
	dc.b   8
	dc.b   9
	dc.b  $A
	dc.b  $B
	dc.b  $C
	dc.b  $D
	dc.b  $E
	dc.b  $F

unk_12D50:
	dc.b   2
	dc.b   5
	dc.b   6
	dc.b   7
	dc.b   8
	dc.b   9
	dc.b  $A
	dc.b  $B
	dc.b  $C
	dc.b  $D
	dc.b  $E
	dc.b  $F

unk_12D5C:
	dc.b   1
	dc.b   2
	dc.b   3
	dc.b   7
	dc.b   8
	dc.b   9
	dc.b  $A
	dc.b  $B
	dc.b  $C
	dc.b  $D
	dc.b  $E
	dc.b  $F

; =============== S U B	R O U T	I N E =======================================

sub_12D68:
	tst.b	(byte_FF1D0E).l
	bne.s	loc_12D78
	andi	#$FFFE,sr
	rts
; ---------------------------------------------------------------------------

loc_12D78:
	addq.w	#1,d2
	cmpi.w	#$C,d2
	bcc.s	loc_12DB8
	move.w	d2,d4
	mulu.w	#6,d4
	add.w	d1,d4
	lsl.w	#1,d4
	move.b	(a2,d4.w),d5
	andi.b	#$F0,d5
	addi.w	#$C,d4

loc_12D98:
	move.b	(a2,d4.w),d6
	andi.b	#$F0,d6
	cmp.b	d6,d5
	bne.s	loc_12DB2
	addi.w	#$C,d4
	addq.w	#1,d2
	cmpi.b	#$B,d2
	bcs.s	loc_12D98

loc_12DB2:
	andi	#$FFFE,sr
	rts
; ---------------------------------------------------------------------------

loc_12DB8:
	move.b	#$1F,d3
	ori	#1,sr
	rts
; End of function sub_12D68

; =============== S U B	R O U T	I N E =======================================

sub_12DC2:
	tst.b	0(a5)
	bne.s	loc_12DCC
	rts
; ---------------------------------------------------------------------------

loc_12DCC:
	move.w	d2,d3
	mulu.w	#6,d3
	add.w	d1,d3
	lsl.w	#1,d3
	move.w	#$FFFF,d4
	bsr.w	sub_12E36
	move.w	#1,d4
	bsr.w	sub_12E36
	bsr.w	*+4
; End of function sub_12DC2

; =============== S U B	R O U T	I N E =======================================

sub_12DEA:
	cmpi.w	#$B,d2
	bcc.w	locret_12E34
	move.w	#$C,d4
	add.w	d3,d4
	move.b	(a2,d4.w),d5
	beq.s	locret_12E34
	andi.b	#$70,d5
	cmpi.b	#$60,d5
	beq.s	locret_12E34
	move.b	(a2,d4.w),d5
	andi.b	#$C,d5
	move.b	2(a2,d4.w),d6
	lsl.b	#1,d6
	andi.b	#4,d6
	and.b	d5,d6
	bne.s	locret_12E34
	move.b	-2(a2,d4.w),d6
	lsl.b	#2,d6
	andi.b	#8,d6
	and.b	d5,d6
	bne.s	locret_12E34
	move.w	#6,d4
	bra.w	loc_12E44
; ---------------------------------------------------------------------------

locret_12E34:
	rts
; End of function sub_12DEA

; =============== S U B	R O U T	I N E =======================================

sub_12E36:
	move.w	d4,d5
	add.w	d1,d5
	cmpi.w	#6,d5
	bcs.s	loc_12E44
	rts
; ---------------------------------------------------------------------------

loc_12E44:
	lsl.w	#1,d4
	add.w	d3,d4
	clr.w	d5
	move.b	(a2,d4.w),d5
	beq.s	locret_12E6A
	lsr.b	#4,d5
	andi.b	#7,d5
	move.b	(a3,d4.w),d6
	andi.b	#3,d6
	bne.s	loc_12E64
	addq.b	#1,d6

loc_12E64:
	lsl.b	#4,d6
	add.b	d6,(a5,d5.w)

locret_12E6A:
	rts
; End of function sub_12E36

; =============== S U B	R O U T	I N E =======================================

sub_12E6C:
	andi.w	#$FD8F,d0
	andi.b	#$F3,d1
	movem.l	d2-d3/a1-a2,-(sp)
	movea.l	$2E(a0),a1
	lea	(byte_FF1D0A).l,a2
	tst.b	$2A(a1)
	beq.s	loc_12E90
	lea	(byte_FF1D0B).l,a2

loc_12E90:
	addq.b	#1,(a2)
	bne.s	loc_12E9A
	move.b	#$FF,(a2)

loc_12E9A:
	bsr.w	sub_12F82
	move.b	$20(a1),d2
	sub.b	$1B(a0),d2
	beq.s	loc_12ED6
	clr.w	d3
	rol.b	#1,d2
	andi.w	#1,d2
	or.b	byte_12F04(pc,d2.w),d1
	tst.b	$2A(a1)
	beq.s	loc_12ED6
	cmpi.b	#4,(level).l
	bcc.s	loc_12ED6
	tst.b	$27(a1)
	bmi.w	loc_12ED6
	bsr.w	sub_12F4A

loc_12ED6:
	move.b	$21(a1),d2
	sub.b	$2B(a0),d2
	beq.s	loc_12EF8
	clr.w	d3
	bset	#5,d0
	andi.b	#3,d2
	cmpi.b	#3,d2
	bne.s	loc_12EF8
	eori.b	#$60,d0

loc_12EF8:
	or.w	d3,d0
	bsr.w	sub_12F06
	movem.l	(sp)+,d2-d3/a1-a2
	rts
; End of function sub_12E6C

; ---------------------------------------------------------------------------
byte_12F04:	dc.b 8
	dc.b   4

; =============== S U B	R O U T	I N E =======================================

sub_12F06:
	move.b	d0,d2
	andi.b	#$70,d0
	beq.s	loc_12F18
	move.b	#$FF,(byte_FF1D0C).l

loc_12F18:
	btst	#9,d0
	beq.s	loc_12F2A
	move.b	#$80,(byte_FF1D0D).l
	rts
; ---------------------------------------------------------------------------

loc_12F2A:
	clr.w	d2
	move.b	d1,d2
	lsr.b	#2,d2
	andi.b	#3,d2
	move.b	byte_12F46(pc,d2.w),d3
	bne.s	loc_12F3E
	rts
; ---------------------------------------------------------------------------

loc_12F3E:
	move.b	d3,(byte_FF1D0D).l
	rts
; End of function sub_12F06

; ---------------------------------------------------------------------------
byte_12F46:
	dc.b   0
	dc.b $84
	dc.b $88
	dc.b   0

; =============== S U B	R O U T	I N E =======================================

sub_12F4A:
	cmpi.b	#$FF,(a2)
	bcs.s	loc_12F54
	rts
; ---------------------------------------------------------------------------

loc_12F54:
	move.l	d0,-(sp)
	move.b	(a2),d0
	andi.b	#$F,d0
	beq.s	loc_12F6A
	andi.b	#$F3,d1
	bra.w	loc_12F7C
; ---------------------------------------------------------------------------

loc_12F6A:
	jsr	(Random).l
	andi.b	#1,d0
	beq.s	loc_12F7C
	eori.b	#$C,d1

loc_12F7C:
	move.l	(sp)+,d0
	rts
; End of function sub_12F4A

; =============== S U B	R O U T	I N E =======================================

sub_12F82:
	move.b	$2C(a1),d2
	tst.b	$27(a1)
	beq.s	loc_12F92
	move.b	$2D(a1),d2

loc_12F92:
	cmp.b	$26(a1),d2
	bcc.s	loc_12FA4
	clr.b	$26(a1)
	eori.b	#$80,$27(a1)

loc_12FA4:
	clr.w	d3
	move.b	$27(a1),d3
	lsl.w	#2,d3
	rts
; End of function sub_12F82

; =============== S U B	R O U T	I N E =======================================

sub_12FAE:
	tst.b	6(a2)
	bmi.s	locret_12FCA
	tst.b	d3
	bne.s	locret_12FCA
	cmpi.b	#8,3(a6)
	bcc.s	loc_12FCC
	addq.b	#1,3(a6)

locret_12FCA:
	rts
; ---------------------------------------------------------------------------

loc_12FCC:
	tst.b	1(a6)
	beq.w	loc_13142
	bra.w	*+4		; TODO: uhh
; ---------------------------------------------------------------------------

loc_12FD8:
	movea.l	4(a6),a1
	move.b	(a1),d0
	lsr.b	#4,d0
	add.b	2(a6),d0
	move.b	d0,$20(a0)
	move.b	(a1)+,d0
	andi.b	#$F,d0
	move.b	d0,$21(a0)
	move.l	a1,4(a6)
	tst.b	(a1)
	bpl.w	loc_13000
	clr.b	1(a6)

loc_13000:
	movem.l	(sp)+,a1
	rts
; End of function sub_12FAE

; =============== S U B	R O U T	I N E =======================================

sub_13006:
	move.b	(a3)+,d1
	move.b	(a3)+,d2
	clr.w	d0
	move.b	#$FF,d4
	clr.b	d5

loc_13012:
	move.b	(a5,d0.w),d6
	cmp.b	d2,d6
	bcs.s	loc_1302E
	addq.b	#1,d5
	cmp.b	d4,d6
	beq.s	loc_1302E
	move.b	d0,8(a6)
	move.b	#1,d5
	move.b	d6,d4

loc_1302E:
	cmp.b	d1,d5
	beq.s	loc_13042
	addq.b	#2,d0
	cmpi.b	#$C,d0
	bcs.s	loc_13012
	ori	#1,sr
	rts
; ---------------------------------------------------------------------------

loc_13042:
	move.b	d0,9(a6)
	bsr.w	sub_13060
	move.b	#0,$21(a0)
	move.b	8(a6),d0
	lsr.b	#1,d0
	move.b	d0,2(a6)
	andi	#$FFFE,sr
	rts
; End of function sub_13006

; =============== S U B	R O U T	I N E =======================================

sub_13060:
	move.b	8(a6),d1
	clr.w	d2
	clr.b	d3

loc_13068:
	bsr.w	sub_1308E
	bcs.s	loc_13084
	move.b	(a5,d2.w),d4
	cmp.b	d3,d4
	bcs.s	loc_13084
	move.b	d4,d3
	move.b	d2,d4
	lsr.b	#1,d4
	move.b	d4,$20(a0)

loc_13084:
	addq.b	#2,d2
	cmpi.b	#$C,d2
	bcs.s	loc_13068
	rts
; End of function sub_13060

; =============== S U B	R O U T	I N E =======================================

sub_1308E:
	cmp.b	d1,d2
	bcs.s	loc_130A0
	cmp.b	d2,d0
	bcs.s	loc_130A0
	ori	#1,sr
	rts
; ---------------------------------------------------------------------------

loc_130A0:
	andi	#$FFFE,sr
	rts
; End of function sub_1308E

; ---------------------------------------------------------------------------
byte_130A6:
	dc.b 0
	dc.b 1
	dc.b 3
	dc.b 4
	dc.b 5
	dc.b 0

; =============== S U B	R O U T	I N E =======================================

sub_130AC:
	move.w	#4,d0
	lea	(byte_FF1D10).l,a2

loc_130B6:
	move.b	byte_130A6(pc,d0.w),(a2,d0.w)
	dbf	d0,loc_130B6
	bsr.w	sub_13120
	move.w	#$28,d0
	clr.w	d1

loc_130CA:
	move.b	(a3),d1
	lsr.b	#4,d1
	move.b	(a2,d1.w),(a1,d0.w)
	move.b	(a3)+,d1
	andi.b	#$F,d1
	move.b	(a2,d1.w),1(a1,d0.w)
	addq.b	#2,d0
	cmpi.w	#$2C,d0
	bcs.s	loc_130CA
	clr.w	d0
	move.b	$2A(a0),d0
	lsl.w	#8,d0
	move.b	$20(a1),d0
	lea	(p1_puyo_order).l,a4

loc_130FA:
	move.b	(a3)+,d1
	bmi.w	loc_1311A
	lsr.b	#4,d1
	move.b	(a2,d1.w),(a4,d0.w)
	move.b	-1(a3),d1
	andi.b	#$F,d1
	move.b	(a2,d1.w),1(a4,d0.w)
	addq.b	#2,d0
	bra.s	loc_130FA
; ---------------------------------------------------------------------------

loc_1311A:
	move.l	a3,4(a6)
	rts
; End of function sub_130AC

; =============== S U B	R O U T	I N E =======================================

sub_13120:
	move.w	#4,d1

loc_13124:
	move.w	#5,d0
	jsr	(RandomBound).l
	move.b	(a2,d0.w),d2
	move.b	(a2,d1.w),(a2,d0.w)
	move.b	d2,(a2,d1.w)
	dbf	d1,loc_13124
	rts
; End of function sub_13120

; ---------------------------------------------------------------------------
; START	OF FUNCTION CHUNK FOR sub_12FAE

loc_13142:
	move.l	a3,-(sp)
	clr.w	d0
	move.b	6(a2),d0
	jsr	(RandomBound).l
	lsl.w	#2,d0
	movea.l	off_1317C(pc,d0.w),a3
	bsr.w	sub_13006
	bcc.s	loc_13168
	move.l	(sp)+,a3
	clr.b	d3
	rts
; ---------------------------------------------------------------------------

loc_13168:
	bsr.w	sub_130AC
	move.b	#$FF,1(a6)
	move.l	(sp)+,a3
	move.l	(sp)+,a3
	rts
; END OF FUNCTION CHUNK	FOR sub_12FAE
; ---------------------------------------------------------------------------
off_1317C:
	dc.l byte_13226
	dc.l byte_13232
	dc.l byte_13240
	dc.l byte_1324E
	dc.l byte_131EA
	dc.l byte_131F8
	dc.l byte_13208
	dc.l byte_13218
	dc.l byte_131DA
	dc.l byte_131CA
	dc.l byte_131BA
	dc.l byte_131AC

byte_131AC:
	dc.b   3
	dc.b   5
	dc.b   0
	dc.b $22
	dc.b $10
	dc.b $10
	dc.b $11
	dc.b $FF
	dc.b $10
	dc.b   0
	dc.b $13
	dc.b $23
	dc.b $22
	dc.b $FF

byte_131BA:
	dc.b   3
	dc.b   6
	dc.b $22
	dc.b   1
	dc.b $10
	dc.b $31
	dc.b   0
	dc.b $21
	dc.b $FF
	dc.b $11
	dc.b   1
	dc.b $23
	dc.b $13
	dc.b   2
	dc.b $22
	dc.b $FF

byte_131CA:
	dc.b   3
	dc.b   6
	dc.b   0
	dc.b   1
	dc.b $12
	dc.b $34
	dc.b $10
	dc.b $12
	dc.b $FF
	dc.b   2
	dc.b $10
	dc.b $11
	dc.b $22
	dc.b $10
	dc.b   0
	dc.b $FF

byte_131DA:
	dc.b   3
	dc.b   6
	dc.b   0
	dc.b $23
	dc.b $12
	dc.b $10
	dc.b $10
	dc.b $31
	dc.b $FF
	dc.b   0
	dc.b $13
	dc.b $22
	dc.b $10
	dc.b $23
	dc.b $11
	dc.b $FF

byte_131EA:
	dc.b   3
	dc.b   5
	dc.b   0
	dc.b $11
	dc.b   2
	dc.b $31
	dc.b $10
	dc.b $FF
	dc.b $11
	dc.b $22
	dc.b   0
	dc.b   1
	dc.b $23
	dc.b $FF

byte_131F8:
	dc.b   3
	dc.b   5
	dc.b $11
	dc.b $21
	dc.b   0
	dc.b   3
	dc.b $40
	dc.b $21
	dc.b $FF
	dc.b $11
	dc.b $11
	dc.b   0
	dc.b $13
	dc.b   1
	dc.b $20
	dc.b $FF

byte_13208:
	dc.b   3
	dc.b   5
	dc.b   0
	dc.b $21
	dc.b   1
	dc.b   1
	dc.b $30
	dc.b $14
	dc.b $FF
	dc.b   1
	dc.b $13
	dc.b $11
	dc.b $11
	dc.b   2
	dc.b   0
	dc.b $FF

byte_13218:
	dc.b   3
	dc.b   5
	dc.b   1
	dc.b $22
	dc.b $10
	dc.b   1
	dc.b $10
	dc.b $FF
	dc.b $23
	dc.b $22
	dc.b   1
	dc.b $13
	dc.b   0
	dc.b $FF

byte_13226:
	dc.b   2
	dc.b   6
	dc.b   1
	dc.b   1
	dc.b   0
	dc.b $11
	dc.b $FF
	dc.b   0
	dc.b   1
	dc.b   0
	dc.b $10
	dc.b $FF

byte_13232:
	dc.b   2
	dc.b   6
	dc.b $20
	dc.b $10
	dc.b   1
	dc.b   1
	dc.b $13
	dc.b $FF
	dc.b $12
	dc.b $13
	dc.b   1
	dc.b   2
	dc.b $13
	dc.b $FF

byte_13240:
	dc.b   2
	dc.b   6
	dc.b   0
	dc.b   1
	dc.b $12
	dc.b $13
	dc.b $10
	dc.b $FF
	dc.b   2
	dc.b   0
	dc.b $12
	dc.b $13
	dc.b $10
	dc.b $FF

byte_1324E:
	dc.b   2
	dc.b   6
	dc.b   0
	dc.b $11
	dc.b   0
	dc.b $21
	dc.b $13
	dc.b $FF
	dc.b   1
	dc.b $10
	dc.b $13
	dc.b $13
	dc.b   0
	dc.b $FF

; =============== S U B	R O U T	I N E =======================================

sub_1325C:
	lea	(sub_13274).l,a1
	jsr	(FindActorSlot).l
	lea	(loc_132E4).l,a1
	jmp	(FindActorSlot).l
; End of function sub_1325C

; =============== S U B	R O U T	I N E =======================================

sub_13274:
	move.b	#$80,6(a0)
	move.b	#$26,8(a0)
	move.w	#$120,$A(a0)
	move.w	#$150,$E(a0)
	move.l	#byte_132BC,$32(a0)
	jsr	(ActorBookmark).l
	clr.w	d0
	move.b	(byte_FF1D0D).l,d0
	beq.s	loc_132B6
	andi.b	#$7F,d0
	move.l	off_132C0(pc,d0.w),$32(a0)
	clr.b	(byte_FF1D0D).l

loc_132B6:
	jmp	(ActorAnimate).l
; End of function sub_13274

; ---------------------------------------------------------------------------
; TODO: Document animation code

byte_132BC:
	dc.b   0
	dc.b   2
	dc.b $FE
	dc.b   0

off_132C0:
	dc.l byte_132CC
	dc.l byte_132D4
	dc.l byte_132DC

byte_132CC:
	dc.b   2
	dc.b   4
	dc.b $FF
	dc.b   0
	dc.l byte_132BC

byte_132D4:
	dc.b   8
	dc.b   3
	dc.b $FF
	dc.b   0
	dc.l byte_132BC

byte_132DC:
	dc.b   8
	dc.b   5
	dc.b $FF
	dc.b   0
	dc.l byte_132BC
; ---------------------------------------------------------------------------

loc_132E4:
	move.b	#$80,6(a0)
	move.b	#$26,8(a0)
	move.w	#$150,$A(a0)
	move.w	#$150,$E(a0)
	move.l	#byte_1332C,$32(a0)
	jsr	(ActorBookmark).l
	tst.b	(byte_FF1D0C).l
	beq.s	loc_13322
	move.l	#byte_13328,$32(a0)
	clr.b	(byte_FF1D0C).l

loc_13322:
	jmp	(ActorAnimate).l
; ---------------------------------------------------------------------------
byte_13328:
	dc.b 1
	dc.b 0
	dc.b 8
	dc.b 1
; TODO: Document animation code

byte_1332C:
	dc.b 0
	dc.b 0
	dc.b $FE
	dc.b 0
; ---------------------------------------------------------------------------

loc_13330:
	lea	(p1_puyo_order).l,a1
	lea	(unk_13342).l,a2

loc_1333C:
	move.b	(a2)+,(a1)+
	bpl.s	loc_1333C
	rts
; ---------------------------------------------------------------------------
unk_13342:	; Bean Colour Combinations

	; 0 = Red
	; 1 = Yellow
	; 2 = Teal
	; 3 = Green
	; 4 = Purple
	; 5 = Blue

	dc.b   1 ; 3rd Bean (Bottom)
	dc.b   0 ; 3rd Bean (Top)
	
	dc.b   1 ; 2nd Bean (Bottom)
	dc.b   3 ; 2nd Bean (Top)
	
	dc.b   4 ; 1st Bean (Bottom)
	dc.b   0 ; 1st Bean (Top)
	
	dc.b   0 ; 4th Bean (Bottom)
	dc.b   0 ; 4th Bean (Top)
	
	dc.b   3 ; 5th Bean (Bottom)
	dc.b   0 ; 5th Bean (Top)
	
	dc.b   5 ; 6TH
	dc.b   3
	
	dc.b   0 ; 7TH
	dc.b   4
	
	dc.b   3 ; 8TH
	dc.b   4
	
	dc.b   3 ; 9TH
	dc.b   0
	
	dc.b   0
	dc.b   0
	
	dc.b   0
	dc.b   4
	
	dc.b   5
	dc.b   5
	
	dc.b   0
	dc.b   0
	
	dc.b   5
	dc.b   5
	
	dc.b   5
	dc.b   5
	
	dc.b   1
	dc.b   1
	
	dc.b   5
	dc.b   5
	
	dc.b   3
	dc.b   3
	
	dc.b   3
	dc.b   4
	
	dc.b   3
	dc.b   5
	
	dc.b   5
	dc.b   5
	
	dc.b   4
	dc.b   5
	
	dc.b   1
	dc.b   1
	
	dc.b   1
	dc.b   4
	
	dc.b   1
	dc.b   0
	
	dc.b   0
	dc.b   0
	
	dc.b   4
	dc.b   0
	
	dc.b   1
	dc.b   4
	
	dc.b   1
	dc.b   5
	
	dc.b   1
	dc.b   5
	
	dc.b   1
	dc.b   4
	
	dc.b   4
	dc.b   4
	
	dc.b   5
	dc.b   5
	
	dc.b   0
	dc.b   0
	
	dc.b   5
	dc.b   0
	
	dc.b   5
	dc.b   0
	
	dc.b   4
	dc.b   5
	
	dc.b   3
	dc.b   4
	
	dc.b   3
	dc.b   4
	
	dc.b   4
	dc.b   5
	
	dc.b   3
	dc.b   3
	
	dc.b   3
	dc.b   4
	
	dc.b   3
	dc.b   4
	
	dc.b   3
	dc.b   4
	dc.b $FF
	dc.b   0
; ---------------------------------------------------------------------------

loc_1339C:
	move.w	#$CB3E,(word_FF198A).l
	clr.w	(word_FF196E).l
	clr.w	(time_frames).l
	clr.b	(byte_FF1965).l
	jsr	(ClearScroll).l
	move.w	#$8B00,d0
	move.b	(vdp_reg_b).l,d0
	ori.b	#4,d0
	move.b	d0,(vdp_reg_b).l
	lea	(loc_133FA).l,a1
	jsr	(FindActorSlot).l
	move.b	#0,$2A(a1)
	move.l	#$80010000,d0
	jsr	(QueuePlaneCmd).l
	jsr	(sub_3BB0).l
	jmp	(sub_1325C).l
; ---------------------------------------------------------------------------

loc_133FA:
	moveq	#0,d0
	jsr	(sub_9C4A).l
	jsr	(ResetPuyoField).l
	move.w	#0,d3
	move.w	#$FF38,d4
	jsr	(loc_44EE).l
	DISABLE_INTS
	jsr	(sub_5782).l
	ENABLE_INTS
	jsr	(ActorBookmark).l
	clr.b	(byte_FF0104).l
	move.b	#7,8(a0)
	jsr	(loc_9CF8).l
	jsr	(ActorBookmark).l

loc_13442:
	clr.w	(puyos_popping).l
	cmpi.b	#9,(word_FF196E+1).l
	bcs.s	loc_13476
	move.w	#$20,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark).l
	clr.b	(bytecode_flag).l
	clr.b	(bytecode_disabled).l
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_13476:
	clr.b	9(a0)
	bsr.w	sub_13610
	bsr.w	sub_1362C
	jsr	(SpawnGarbage).l
	jsr	(ActorBookmark).l
	btst	#2,7(a0)
	beq.s	loc_1349A
	rts
; ---------------------------------------------------------------------------

loc_1349A:
	jsr	(sub_4E24).l
	bcs.w	loc_1358A
	jsr	(ActorBookmark).l
	move.b	7(a0),d0
	andi.b	#3,d0
	beq.s	loc_134D0
	btst	#3,7(a0)
	bne.s	loc_134C2
	rts
; ---------------------------------------------------------------------------

loc_134C2:
	bclr	#3,7(a0)
	moveq	#1,d0
	jmp	(sub_9C4A).l
; ---------------------------------------------------------------------------

loc_134D0:
	jsr	(sub_5960).l
	move.w	d1,$26(a0)
	jsr	(ActorBookmark).l
	DISABLE_INTS
	jsr	(sub_5782).l
	ENABLE_INTS
	move.w	#2,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark).l
	tst.w	$26(a0)
	beq.w	loc_13442
	jsr	(sub_58C8).l
	jsr	(sub_9A56).l
	jsr	(sub_9A40).l
	jsr	(ActorBookmark).l
	jsr	(sub_49BA).l
	move.w	#$18,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(sub_49D2).l
	jsr	(ActorBookmark).l
	jsr	(CheckPuyoPop).l
	move.w	#$18,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark).l
	jsr	(sub_4DB8).l
	bset	#4,7(a0)
	jsr	(ActorBookmark).l
	btst	#4,7(a0)
	beq.s	loc_13572
	jmp	(loc_4E14).l
; ---------------------------------------------------------------------------

loc_13572:
	jsr	(sub_9BBA).l
	addq.b	#1,9(a0)
	bcc.s	loc_13586
	move.b	#$FF,9(a0)

loc_13586:
	bra.w	loc_134D0
; ---------------------------------------------------------------------------

loc_1358A:
	move.b	#$FF,(puyos_popping).l
	move.w	#5,(word_FF196E).l
	jsr	(sub_7926).l
	move.b	#SFX_LOSE,d0
	jsr	(PlaySound_ChkPCM).l
	jsr	(ActorBookmark).l
	tst.w	$26(a0)
	beq.s	loc_135BA
	rts
; ---------------------------------------------------------------------------

loc_135BA:
	jsr	(ResetPuyoField).l
	DISABLE_INTS
	jsr	(sub_5782).l
	ENABLE_INTS
	jsr	(GetPuyoField).l
	andi.w	#$7F,d0
	move.w	#5,d1
	lea	(vscroll_buffer).l,a2

loc_135E2:
	clr.l	(a2,d0.w)
	addq.w	#4,d0
	dbf	d1,loc_135E2
	move.w	#$E0,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorBookmark).l
	move.w	#$8400,d0
	swap	d0
	move.b	#5,d0
	jsr	(QueuePlaneCmd).l
	bra.w	loc_13442

; =============== S U B	R O U T	I N E =======================================

sub_13610:
	tst.b	(word_FF196E).l
	beq.s	loc_1361C
	rts
; ---------------------------------------------------------------------------

loc_1361C:
	clr.w	d0
	move.b	(word_FF196E+1).l,d0
	addq.b	#7,d0
	jmp	(sub_FF4A).l
; End of function sub_13610

; =============== S U B	R O U T	I N E =======================================

sub_1362C:
	clr.w	d0
	move.b	(word_FF196E+1).l,d0
	addq.b	#1,(word_FF196E+1).l
	lsl.w	#2,d0
	movea.l	off_13642(pc,d0.w),a1
	jmp	(a1)
; End of function sub_1362C

; ---------------------------------------------------------------------------
off_13642:
	dc.l loc_13666
	dc.l loc_136B6
	dc.l loc_13712
	dc.l loc_13756
	dc.l loc_1376A
	dc.l loc_1378C
	dc.l loc_137FE
	dc.l loc_138F0
	dc.l loc_138F6
; ---------------------------------------------------------------------------

loc_13666:
	lea	(loc_13686).l,a1
	jsr	(FindActorSlot).l
	bcc.s	loc_13678
	rts
; ---------------------------------------------------------------------------

loc_13678:
	move.l	a0,$2E(a1)
	move.l	#unk_136A2,$32(a1)
	rts
; ---------------------------------------------------------------------------

loc_13686:
	jsr	(ActorAnimate).l
	bcc.s	loc_13696
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_13696:
	movea.l	$2E(a0),a1
	move.b	9(a0),$20(a1)
	rts
; ---------------------------------------------------------------------------
; TODO: Document animation code

unk_136A2:
	dc.b $40
	dc.b   2
	dc.b $10
	dc.b   1
	dc.b $10
	dc.b   2
	dc.b  $C
	dc.b   3
	dc.b  $C
	dc.b   4
	dc.b $30
	dc.b   5
	dc.b  $C
	dc.b   4
	dc.b  $C
	dc.b   3
	dc.b   0
	dc.b   2
	dc.b $FE
	dc.b   0
; ---------------------------------------------------------------------------

loc_136B6:
	move.b	#2,$20(a0)
	lea	(loc_136DC).l,a1
	jsr	(FindActorSlot).l
	bcc.s	loc_136CE
	rts
; ---------------------------------------------------------------------------

loc_136CE:
	move.l	a0,$2E(a1)
	move.l	#unk_136F8,$32(a1)
	rts
; ---------------------------------------------------------------------------

loc_136DC:
	jsr	(ActorAnimate).l
	bcc.s	loc_136EC
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_136EC:
	movea.l	$2E(a0),a1
	move.b	9(a0),$21(a1)
	rts
; ---------------------------------------------------------------------------
; TODO: Document animation code

unk_136F8:
	dc.b $40
	dc.b   0
	dc.b $10
	dc.b   1
	dc.b $10
	dc.b   2
	dc.b $10
	dc.b   3
	dc.b $30
	dc.b   0
	dc.b   8
	dc.b   1
	dc.b   8
	dc.b   2
	dc.b   8
	dc.b   3
	dc.b   8
	dc.b   0
	dc.b   8
	dc.b   1
	dc.b   8
	dc.b   2
	dc.b   0
	dc.b   3
	dc.b $FE
	dc.b   0
; ---------------------------------------------------------------------------

loc_13712:
	move.b	#4,$20(a0)
	move.b	#3,$21(a0)

loc_1371E:
	lea	(loc_1373C).l,a1
	jsr	(FindActorSlot).l
	bcc.s	loc_13730
	rts
; ---------------------------------------------------------------------------

loc_13730:
	move.l	a0,$2E(a1)
	move.w	#$80,$26(a1)
	rts
; ---------------------------------------------------------------------------

loc_1373C:
	subq.w	#1,$26(a0)
	beq.s	loc_13746
	rts
; ---------------------------------------------------------------------------

loc_13746:
	movea.l	$2E(a0),a1
	move.b	#$80,$27(a1)
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_13756:
	move.b	#0,$27(a0)
	move.b	#3,$20(a0)
	move.b	#2,$21(a0)
	bra.s	loc_1371E
; ---------------------------------------------------------------------------

loc_1376A:
	move.b	#$80,$27(a0)
	addq.b	#1,(word_FF196E).l
	move.b	#4,(word_FF196E+1).l
	move.b	#2,$20(a0)
	move.b	#0,$21(a0)
	rts
; ---------------------------------------------------------------------------

loc_1378C:
	move.b	#0,$27(a0)
	jsr	(ResetPuyoField).l
	move.w	#$23,d0
	lea	(loc_137FE).l,a1

loc_137A2:
	move.b	#$FF,-(a2)
	move.b	-(a1),d1
	lsl.b	#4,d1
	move.b	d1,-(a2)
	dbf	d0,loc_137A2
	jsr	(sub_5960).l
	DISABLE_INTS
	jsr	(sub_5782).l
	ENABLE_INTS
	move.b	#0,$27(a0)
	move.b	#4,$20(a0)
	move.b	#0,$21(a0)
	bra.w	loc_1371E
; ---------------------------------------------------------------------------
	dc.b   0 ; Tutorial Load Puyos
	dc.b   9
	dc.b   0
	dc.b  $B
	dc.b   8
	dc.b   9
	dc.b   0
	dc.b   8
	dc.b  $C
	dc.b  $D
	dc.b   8
	dc.b   8
	dc.b   0
	dc.b  $C
	dc.b  $D
	dc.b   9
	dc.b   9
	dc.b   9
	dc.b   0
	dc.b  $C
	dc.b  $D
	dc.b  $D
	dc.b  $C
	dc.b   8
	dc.b   9
	dc.b  $C
	dc.b   9
	dc.b  $B
	dc.b  $C
	dc.b   8
	dc.b   8
	dc.b   8
	dc.b   8
	dc.b  $B
	dc.b  $B
	dc.b  $C
; ---------------------------------------------------------------------------

loc_137FE:
	move.b	#6,(word_FF196E+1).l
	clr.w	d0
	move.b	(word_FF196E).l,d0
	lsl.b	#2,d0
	addq.b	#1,(word_FF196E).l
	cmpi.b	#$1A,(word_FF196E).l
	bcs.s	loc_1382A
	move.w	#7,(word_FF196E).l

loc_1382A:
	move.b	byte_1386A(pc,d0.w),$20(a0)
	move.b	byte_1386B(pc,d0.w),$21(a0)
	move.b	#0,$27(a0)
	lea	(loc_138D2).l,a1
	jsr	(FindActorSlotQuick).l
	bcs.s	loc_13856
	move.l	a0,$2E(a1)
	move.b	byte_1386C(pc,d0.w),$27(a1)

loc_13856:
	clr.w	d1
	move.b	byte_1386D(pc,d0.w),d1
	bmi.w	locret_13868
	move.w	d1,d0
	jsr	(sub_FF4A).l

locret_13868:
	rts
; ---------------------------------------------------------------------------
byte_1386A:	dc.b 4

byte_1386B:	dc.b 0

byte_1386C:	dc.b $20

byte_1386D:
	dc.b $10
	dc.b 4
	dc.b 0
	dc.b $20
	dc.b $FF
	dc.b 3
	dc.b 2
	dc.b $40
	dc.b $11
	dc.b 3
	dc.b 1
	dc.b $20
	dc.b $12
	dc.b 3
	dc.b 0
	dc.b $20
	dc.b $FF
	dc.b 5
	dc.b 3
	dc.b $40
	dc.b $13
	dc.b 1
	dc.b 0
	dc.b 8
	dc.b $14
	dc.b 1
	dc.b 0
	dc.b 8
	dc.b $FF
	dc.b 1
	dc.b 1
	dc.b 8
	dc.b $FF
	dc.b 2
	dc.b 0
	dc.b 8
	dc.b $FF
	dc.b 2
	dc.b 0
	dc.b 8
	dc.b $FF
	dc.b 3
	dc.b 0
	dc.b 8
	dc.b $FF
	dc.b 3
	dc.b 0
	dc.b 8
	dc.b $FF
	dc.b 3
	dc.b 1
	dc.b 8
	dc.b $FF
	dc.b 4
	dc.b 0
	dc.b 8
	dc.b $FF
	dc.b 4
	dc.b 0
	dc.b $40
	dc.b $15
	dc.b 2
	dc.b 3
	dc.b $10
	dc.b $16
	dc.b 2
	dc.b 1
	dc.b $10
	dc.b $FF
	dc.b 3
	dc.b 2
	dc.b $10
	dc.b $FF
	dc.b 3
	dc.b 3
	dc.b $10
	dc.b $FF
	dc.b 2
	dc.b 3
	dc.b $10
	dc.b $FF
	dc.b 4
	dc.b 0
	dc.b $40
	dc.b $FF
	dc.b 5
	dc.b 2
	dc.b 0
	dc.b $FF
	dc.b 5
	dc.b 3
	dc.b 0
	dc.b $FF
	dc.b 4
	dc.b 1
	dc.b 0
	dc.b $FF
	dc.b 4
	dc.b 2
	dc.b 0
	dc.b $FF
; ---------------------------------------------------------------------------

loc_138D2:
	tst.w	$26(a0)
	beq.s	loc_138E0
	subq.w	#1,$26(a0)
	rts
; ---------------------------------------------------------------------------

loc_138E0:
	movea.l	$2E(a0),a1
	move.b	#$80,$27(a1)
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

loc_138F0:
	move.w	#$12,$14(a0)

loc_138F6:
	move.b	#8,(word_FF196E+1).l
	clr.w	d0
	move.b	(word_FF196E).l,d0
	lsl.b	#1,d0
	addq.b	#1,(word_FF196E).l
	cmpi.b	#4,(word_FF196E).l
	bcs.s	loc_13922
	move.b	#9,(word_FF196E+1).l

loc_13922:
	move.b	byte_13936(pc,d0.w),$20(a0)
	move.b	byte_13937(pc,d0.w),$21(a0)
	move.b	#$80,$27(a0)
	rts
; ---------------------------------------------------------------------------
byte_13936:	dc.b 1

byte_13937:
	dc.b 1
	dc.b 2
	dc.b 1
	dc.b 2
	dc.b 1
	dc.b 1
	dc.b 2
; ---------------------------------------------------------------------------
	nop
; ---------------------------------------------------------------------------
SpriteMappings:		; TODO: Split these into individual files and find what each mapping is used for
	dc.l off_14F9C		; $00
	dc.l off_15042
	dc.l off_150E8
	dc.l off_153C2
	dc.l off_15468
	dc.l off_1550E
	dc.l off_155B4
	dc.l off_14814
	dc.l off_19084
	dc.l IntroCoconuts_Mappings	; Intro Skeleton Tea - Puyo Leftover
	dc.l IntroFrankly_Mappings	; Intro Frankly
	dc.l IntroDynamight_Mappings	; Intro Dynamight
	dc.l IntroArms_Mappings		; Intro Arms
	dc.l IntroCoconuts_Mappings	; Intro Nasu Grave - Puyo Leftover
	dc.l IntroGrounder_Mappings	; Intro Grounder
	dc.l IntroDavy_Mappings		; Intro Davy Sprocket
	dc.l IntroCoconuts_Mappings	; Intro Coconuts
	dc.l IntroSpike_Mappings	; Intro Spike
	dc.l IntroSirFfuzzy_Mappings	; Intro Sir Ffuzzy-Logik
	dc.l IntroDragonBreath_Mappings	; Intro Dragon Breath
	dc.l IntroScratch_Mappings	; Intro Scratch
	dc.l IntroCoconuts_Mappings	; <Blank> (Robotnik is loaded elsewhere)
	dc.l IntroCoconuts_Mappings	; Intro Mummy - Puyo Leftover
	dc.l IntroHumpty_Mappings	; Intro Humpty
	dc.l IntroSkweel_Mappings	; Intro Skweel
	dc.l HasBean_Mappings		; Has Bean
	dc.l off_15CB0
	dc.l off_15D04
	dc.l off_14E00
	dc.l off_166D4
	dc.l off_14A70
	dc.l off_14A00
	dc.l off_14974
	dc.l off_14876
	dc.l off_14834
	dc.l off_14834
	dc.l off_13C00
	dc.l off_1476C
	dc.l off_14658
	dc.l off_142AC
	dc.l OpeningBadniks_Mappings	; Badniks in Opening Sequence/Robotnik Intro
	dc.l off_14F2A
	dc.l off_13A44
	dc.l IntroRobotnik_Mappings	; Robotnik
	dc.l off_176D8
	dc.l off_17AFE
	dc.l DifficultyFaces_Mappings	; Faces for Difficulty Options in VS/Exercise
	dc.l off_1801E
	dc.l DifficultyFaces_Mappings
	dc.l off_191D0
	dc.l off_19368
	dc.l IntroCoconuts_Mappings
	dc.l IntroCoconuts_Mappings
	dc.l IntroCoconuts_Mappings
	dc.l IntroCoconuts_Mappings
	dc.l IntroCoconuts_Mappings
	dc.l IntroCoconuts_Mappings
	dc.l IntroCoconuts_Mappings
	dc.l IntroCoconuts_Mappings
	dc.l IntroCoconuts_Mappings
	dc.l IntroCoconuts_Mappings
	dc.l IntroCoconuts_Mappings
	dc.l IntroCoconuts_Mappings
	dc.l IntroCoconuts_Mappings
	dc.l off_19610

; ---------------------------------------------------------------------------

	include	"resource/mapsprite/0A - Intro Frankly.asm"
	even

	include	"resource/mapsprite/0B - Intro Dynamight.asm"
	even

	include	"resource/mapsprite/0C - Intro Arms.asm"
	even

	include	"resource/mapsprite/0E - Intro Grounder.asm"
	even

	include	"resource/mapsprite/0F - Intro Davy Sprocket.asm"
	even

	include	"resource/mapsprite/10 - Intro Coconuts.asm"
	even

	include	"resource/mapsprite/11 - Intro Spike.asm"
	even

	include	"resource/mapsprite/12 - Intro Sir Ffuzzy-Logik.asm"
	even

	include	"resource/mapsprite/13 - Intro Dragon Breath.asm"
	even

	include	"resource/mapsprite/14 - Intro Scratch.asm"
	even

	include	"resource/mapsprite/2B - Intro Robotnik.asm"
	even

	include	"resource/mapsprite/17 - Intro Humpty.asm"
	even

	include	"resource/mapsprite/18 - Intro Skweel.asm"
	even

	include	"resource/mapsprite/28 - Opening Badniks.asm"
	even

; ---------------------------------------------------------------------------

	include	"resource/mapsprite/19 - Has Bean.asm"
	even

	include	"resource/mapsprite/30 - Difficulty Faces.asm"
	even

; ---------------------------------------------------------------------------

off_13A44:
	dc.l word_13A5C
	dc.l word_13A6E
	dc.l word_13A80
	dc.l word_13A92
	dc.l word_13AC4
	dc.l word_13AF6

word_13A5C:	dc.w 2
	dc.w $FFF8, $101, $2318, $FFF8
	dc.w $FFF8, $101, $2B18, 0

word_13A6E:	dc.w 2
	dc.w $FFF8, $101, $231A, $FFF8
	dc.w $FFF8, $101, $2B1A, 0

word_13A80:	dc.w 2
	dc.w $FFF8, $101, $2328, $FFF8
	dc.w $FFF8, $101, $2B28, 0

word_13A92:	dc.w 6
	dc.w 0,	$D00, $80, $FFD0
	dc.w 0,	$D00, $88, $FFF0
	dc.w 0,	$D00, $90, $10
	dc.w $18, $D00,	$C0, $FFD4
	dc.w $18, $D00,	$C8, $FFF4
	dc.w $18, $D00,	$D0, $14

word_13AC4:	dc.w 6
	dc.w 0,	$D00, $80, $FFD0
	dc.w 0,	$D00, $88, $FFF0
	dc.w 0,	$500, $90, $10
	dc.w $18, $D00,	$C0, $FFD0
	dc.w $18, $D00,	$C8, $FFF0
	dc.w $18, $D00,	$D0, $10

word_13AF6:	dc.w 2
	dc.w $FFF8, $103, $A318, $FFF8
	dc.w $FFF8, $103, $AB18, 0

; ---------------------------------------------------------------------------

off_13C00:	; That's a lot of sprites
	dc.l word_13D28
	dc.l word_13D32
	dc.l word_13D3C
	dc.l word_13D46
	dc.l word_13D50
	dc.l word_13D5A
	dc.l word_13D64
	dc.l word_13D76
	dc.l word_13D80
	dc.l word_13D8A
	dc.l word_13D94
	dc.l word_13D9E
	dc.l word_13DA8
	dc.l word_13DB2
	dc.l word_13DBC
	dc.l word_13DC6
	dc.l word_13DD0
	dc.l word_13DDA
	dc.l word_13DE4
	dc.l word_13DEE
	dc.l word_13DF8
	dc.l word_13E02
	dc.l word_13E14
	dc.l word_13E26
	dc.l word_13E30
	dc.l word_13E3A
	dc.l word_13E44
	dc.l word_13E4E
	dc.l word_13E58
	dc.l word_13E62
	dc.l word_13E6C
	dc.l word_13E76
	dc.l word_13E88
	dc.l word_13E92
	dc.l word_13EAC
	dc.l word_13ED6
	dc.l word_13F00
	dc.l word_13F12
	dc.l word_13F1C
	dc.l word_13F26
	dc.l word_13F30
	dc.l word_13F3A
	dc.l word_13F44
	dc.l word_13F4E
	dc.l word_13F58
	dc.l word_13F62
	dc.l word_13F6C
	dc.l word_13F76
	dc.l word_13F80
	dc.l word_13F8A
	dc.l word_13F94
	dc.l word_13F9E
	dc.l word_13FB8
	dc.l word_13FD2
	dc.l word_13FDC
	dc.l word_13FE6
	dc.l word_13FF0
	dc.l word_13FFA
	dc.l word_14044
	dc.l word_140A6
	dc.l word_14108
	dc.l word_14142
	dc.l word_1418C
	dc.l word_141CE
	dc.l word_14208
	dc.l word_14212
	dc.l word_1421C
	dc.l word_14226
	dc.l word_14230
	dc.l word_1423A
	dc.l word_14244
	dc.l word_1424E
	dc.l word_14258
	dc.l word_14262

word_13D28:	dc.w 1
	dc.w 0,	$A02, $423B, 0

word_13D32:	dc.w 1
	dc.w 0,	$A02, $4244, 0

word_13D3C:	dc.w 1
	dc.w 0,	$A02, $424D, 0

word_13D46:	dc.w 1
	dc.w 0,	$A02, $4256, 0

word_13D50:	dc.w 1
	dc.w 0,	$A02, $425F, 0

word_13D5A:	dc.w 1
	dc.w 0,	$A02, $4268, 0

word_13D64:	dc.w 2
	dc.w 0,	$602, $4271, 0
	dc.w 8,	$102, $4277, $10

word_13D76:	dc.w 1
	dc.w 8,	$902, $4279, 0

word_13D80:	dc.w 1
	dc.w 0,	$A02, $427F, 0

word_13D8A:	dc.w 1
	dc.w 0,	$A02, $4288, 0

word_13D94:	dc.w 1
	dc.w 0,	$A02, $4291, 0

word_13D9E:	dc.w 1
	dc.w 0,	$A02, $429A, 0

word_13DA8:	dc.w 1
	dc.w 8,	$902, $42A3, 0

word_13DB2:	dc.w 1
	dc.w 8,	$902, $42A9, 0

word_13DBC:	dc.w 1
	dc.w 0,	$A02, $42AF, 0

word_13DC6:	dc.w 1
	dc.w 0,	$402, $22B8, 0

word_13DD0:	dc.w 1
	dc.w 0,	$502, $22BA, 0

word_13DDA:	dc.w 1
	dc.w 8,	2, $22BE, 0

word_13DE4:	dc.w 1
	dc.w 0,	$102, $22BF, 0

word_13DEE:	dc.w 1
	dc.w 0,	$102, $22C1, 0

word_13DF8:	dc.w 1
	dc.w 8,	2, $22C3, 0

word_13E02:	dc.w 2
	dc.w 0,	$A02, $42C4, 0
	dc.w 8,	$102, $42CD, $18

word_13E14:	dc.w 2
	dc.w 0,	$A02, $42CF, 0
	dc.w 8,	$102, $42D8, $18

word_13E26:	dc.w 1
	dc.w 0,	$A02, $42DA, 0

word_13E30:	dc.w 1
	dc.w 0,	$302, $2E3, 0

word_13E3A:	dc.w 1
	dc.w 0,	$302, $2E7, 0

word_13E44:	dc.w 1
	dc.w 0,	$302, $2EB, 0

word_13E4E:	dc.w 1
	dc.w 0,	$302, $2EF, 0

word_13E58:	dc.w 1
	dc.w 0,	$A02, $62F3, 0

word_13E62:	dc.w 1
	dc.w 0,	$A02, $62FC, 0

word_13E6C:	dc.w 1
	dc.w 0,	$A02, $6305, 0

word_13E76:	dc.w 2
	dc.w $10, $902,	$30E, 8
	dc.w $18, 2, $314, 0

word_13E88:	dc.w 1
	dc.w $10, $D02,	$315, 0

word_13E92:	dc.w 3
	dc.w 8,	$C02, $31D, 0
	dc.w $10, $902,	$321, 0
	dc.w $18, 2, $31C, $18

word_13EAC:	dc.w 5
	dc.w 0,	$C02, $31D, 0
	dc.w 8,	$802, $327, 0
	dc.w $10, $502,	$32A, 8
	dc.w $18, 2, $322, 0
	dc.w $18, 2, $31C, $18

word_13ED6:	dc.w 5
	dc.w 0,	$502, $32E, $10
	dc.w 8,	$402, $332, 0
	dc.w $10, $502,	$334, 8
	dc.w $18, 2, $322, 0
	dc.w $18, 2, $31C, $18

word_13F00:	dc.w 2
	dc.w $10, $502,	$338, $10
	dc.w $18, $402,	$33C, 0

word_13F12:	dc.w 1
	dc.w 8,	$902, $633E, 0

word_13F1C:	dc.w 1
	dc.w 8,	$902, $6344, 0

word_13F26:	dc.w 1
	dc.w 0,	$A02, $634A, 0

word_13F30:	dc.w 1
	dc.w 0,	2, $238D, 0

word_13F3A:	dc.w 1
	dc.w 0,	2, $238E, 0

word_13F44:	dc.w 1
	dc.w 0,	2, $238F, 0

word_13F4E:	dc.w 1
	dc.w 0,	2, $2390, 0

word_13F58:	dc.w 1
	dc.w 0,	2, $2B8D, 0

word_13F62:	dc.w 1
	dc.b 0,	0, 0, 2
	dc.b $23, $91, 0, 0

word_13F6C:	dc.w 1
	dc.w 8,	2, $392, 0

word_13F76:	dc.w 1
	dc.w 0,	$102, $393, 0

word_13F80:	dc.w 1
	dc.w 0,	$502, $395, 0

word_13F8A:	dc.w 1
	dc.w 0,	$502, $399, 0

word_13F94:	dc.w 1
	dc.w 0,	$502, $39D, 0

word_13F9E:	dc.w 3
	dc.w 0,	$602, $3A1, 8
	dc.w 8,	2, $3A7, 0
	dc.w 8,	$102, $3A8, $18

word_13FB8:	dc.w 3
	dc.w 0,	$602, $3AA, 8
	dc.w 8,	$102, $3B0, 0
	dc.w 8,	$102, $3B2, $18

word_13FD2:	dc.w 1
	dc.w 0,	$E02, $3B4, 0

word_13FDC:	dc.w 1
	dc.w 8,	$902, $43C0, 0

word_13FE6:	dc.w 1
	dc.w 8,	$902, $43C6, 0

word_13FF0:	dc.w 1
	dc.w 0,	$A02, $43CC, 0

word_13FFA:	dc.w 9
	dc.w $18, $302,	$3D5, 8
	dc.w $20, $302,	$3D9, 0
	dc.w $28, $F02,	$3DD, $18
	dc.w $30, $302,	$3ED, $10
	dc.w $38, $202,	$3F1, 8
	dc.w $40, $102,	$3F4, 0
	dc.w $40, $202,	$3F6, $38
	dc.w $48, $D02,	$3F9, $18
	dc.w $50, 2, $401, $10

word_14044:	dc.w $C
	dc.w $18, $302,	$402, 8
	dc.w $20, $302,	$406, 0
	dc.w $20, $B02,	$40A, $18
	dc.w $28, $302,	$416, $10
	dc.w $28, $302,	$41A, $30
	dc.w $30, $202,	$41E, $38
	dc.w $38, $102,	$421, 8
	dc.w $38, 2, $423, $40
	dc.w $40, $102,	$424, 0
	dc.w $40, $902,	$426, $18
	dc.w $48, 2, $42C, $10
	dc.w $48, 2, $42D, $30

word_140A6:	dc.w $C
	dc.w $10, $702,	$42E, $18
	dc.w $18, $702,	$436, 8
	dc.w $18, $302,	$43E, $28
	dc.w $20, $302,	$442, 0
	dc.w $20, $702,	$446, $30
	dc.w $28, $102,	$44E, $40
	dc.w $30, $602,	$450, $18
	dc.w $38, $402,	$456, 8
	dc.w $38, $102,	$458, $28
	dc.w $40, $102,	$424, 0
	dc.w $40, 2, $45A, $10
	dc.w $40, 2, $44D, $30

word_14108:	dc.w 7
	dc.w 0,	$B02, $45B, $20
	dc.w 8,	$F02, $467, 0
	dc.w $20, $802,	$477, $20
	dc.w $28, $D02,	$47A, 0
	dc.w $28, 2, $482, $20
	dc.w $38, $402,	$483, 0
	dc.w $40, $102,	$424, 0

word_14142:	dc.w 9
	dc.w 0,	$B02, $485, $20
	dc.w 8,	$B02, $467, 0
	dc.w $10, $302,	$491, $18
	dc.w $20, $802,	$495, $20
	dc.w $28, $902,	$47A, 0
	dc.w $28, 2, $482, $20
	dc.w $30, 2, $481, $18
	dc.w $38, $402,	$483, 0
	dc.w $40, $102,	$424, 0

word_1418C:	dc.w 8
	dc.w 8,	$B02, $467, 0
	dc.w 8,	$B02, $498, $20
	dc.w $10, $302,	$491, $18
	dc.w $28, $902,	$47A, 0
	dc.w $28, 2, $482, $20
	dc.w $30, 2, $481, $18
	dc.w $38, $402,	$483, 0
	dc.w $40, $102,	$424, 0

word_141CE:	dc.w 7
	dc.w 0,	$F01, $4A4, $18
	dc.w 8,	$B01, $467, 0
	dc.w $20, $C01,	$476, $18
	dc.w $28, $D01,	$47A, 0
	dc.w $28, 1, $482, $20
	dc.w $38, $401,	$483, 0
	dc.w $40, $101,	$424, 0

word_14208:	dc.w 1
	dc.w $FFFC, 1, $44B4, $FFFC

word_14212:	dc.w 1
	dc.w $FFFC, 1, $44B5, $FFFC

word_1421C:	dc.w 1
	dc.w $FFFC, 1, $4CB4, $FFFC

word_14226:	dc.w 1
	dc.w $FFFC, 1, $4CB5, $FFFC

word_14230:	dc.w 1
	dc.w $FFFC, 1, $54B4, $FFFC

word_1423A:	dc.w 1
	dc.w $FFFC, 1, $54B5, $FFFC

word_14244:	dc.w 1
	dc.w $FFFC, 1, $5CB4, $FFFC

word_1424E:	dc.w 1
	dc.w $FFFC, 1, $5CB5, $FFFC

word_14258:	dc.w 1
	dc.w 0,	$402, $4B6, 0

word_14262:	dc.w 9
	dc.w 0,	$B03, $6353, $50
	dc.w 8,	$303, $635F, $48
	dc.w 8,	$103, $6363, $68
	dc.w $10, $703,	$6365, $30
	dc.w $18, $D03,	$636D, 0
	dc.w $18, $703,	$6375, $20
	dc.w $18, $103,	$637D, $40
	dc.w $28, $B03,	$637F, 8
	dc.w $38, $103,	$638B, $20

; ---------------------------------------------------------------------------

off_142AC:
	dc.l word_144E4
	dc.l word_1453E
	dc.l word_145A8
	dc.l word_145C2
	dc.l word_145CC
	dc.l word_145D6
	dc.l word_145E0
	dc.l word_145EA
	dc.l word_145F4
	dc.l word_145FE
	dc.l word_14608
	dc.l word_14612
	dc.l word_1461C
	dc.l word_14626
	dc.l word_14630
	dc.l word_1463A
	dc.l word_14644
	dc.l word_1464E
	dc.l word_14344
	dc.l word_1434E
	dc.l word_14358
	dc.l word_14362
	dc.l word_1436C
	dc.l word_14376
	dc.l word_143E8
	dc.l word_14452
	dc.l word_1445C
	dc.l word_14466
	dc.l word_14470
	dc.l word_1447A
	dc.l word_14484
	dc.l word_1448E
	dc.l word_14498
	dc.l word_144A2
	dc.l word_144B4
	dc.l word_144BE
	dc.l word_144C8
	dc.l word_144D2

word_14344:	dc.w 1
	dc.w 0,	$502, $8142, 0

word_1434E:	dc.w 1
	dc.w 0,	$502, $8146, 0

word_14358:	dc.w 1
	dc.w 0,	$502, $814A, 0

word_14362:	dc.w 1
	dc.w 0,	$501, $814E, 0

word_1436C:	dc.w 1
	dc.w 0,	$501, $8152, 0

word_14376:	dc.w $E
	dc.w 0,	$B02, $E156, $20
	dc.w 8,	$B02, $E19F, 8
	dc.w 8,	$302, $E16E, $38
	dc.w $10, $302,	$E1AB, 0
	dc.w $10, $302,	$E1AF, $40
	dc.w $10, $302,	$E1B3, $50
	dc.w $18, $302,	$E1B7, $48
	dc.w $18, $202,	$E1BB, $58
	dc.w $20, $B02,	$E1BE, $20
	dc.w $28, $902,	$E1CA, 8
	dc.w $28, $202,	$E19A, $38
	dc.w $30, $102,	$E1D0, $40
	dc.w $30, 2, $E1D2, $50
	dc.w $38, 2, $E193, $48

word_143E8:	dc.w $D
	dc.w 0,	$B02, $E156, $20
	dc.w 8,	$B02, $E162, 8
	dc.w 8,	$302, $E16E, $38
	dc.w $10, $302,	$E1D3, 0
	dc.w $10, $802,	$E1D7, $40
	dc.w $18, $302,	$E17A, $40
	dc.w $18, $602,	$E1DA, $50
	dc.w $20, $B02,	$E184, $20
	dc.w $20, $302,	$E190, $48
	dc.w $28, $902,	$E1E0, 8
	dc.w $28, $202,	$E19A, $38
	dc.w $30, 2, $E19D, $50
	dc.w $38, 2, $E19E, $40

word_14452:	dc.w 1
	dc.w 0,	$502, $E1E6, 0

word_1445C:	dc.w 1
	dc.w 0,	$502, $E1EA, 0

word_14466:	dc.w 1
	dc.w 0,	$502, $E1EE, 0

word_14470:	dc.w 1
	dc.w 0,	$502, $E1F2, 0

word_1447A:	dc.w 1
	dc.w 0,	$502, $E1F6, 0

word_14484:	dc.w 1
	dc.w 0,	$501, $E1FA, 0

word_1448E:	dc.w 1
	dc.w 0,	$501, $E1FE, 0

word_14498:	dc.w 1
	dc.w 0,	$501, $E202, 0

word_144A2:	dc.w 2
	dc.w 0,	$401, $E206, 0
	dc.w 8,	1, $E208, 0

word_144B4:	dc.w 1
	dc.w 0,	$501, $F1FA, 0

word_144BE:	dc.w 1
	dc.w 0,	$501, $F1FE, 0

word_144C8:	dc.w 1
	dc.w 0,	$501, $F202, 0

word_144D2:	dc.w 2
	dc.w 8,	$401, $F206, 0
	dc.w 0,	1, $F208, 0

word_144E4:	dc.w $B
	dc.w 0,	$B02, $8100, $18
	dc.w 8,	$702, $810C, 8
	dc.w 8,	$302, $8114, $30
	dc.w 8,	$E02, $8118, $40
	dc.w $10, $202,	$8124, 0
	dc.w $10, $302,	$8127, $38
	dc.w $20, $A02,	$812B, $18
	dc.w $20, $502,	$8134, $40
	dc.w $28, $602,	$8138, 8
	dc.w $28, $102,	$813E, $30
	dc.w $38, $402,	$8140, $18

word_1453E:	dc.w $D
	dc.w 0,	$B02, $E156, $20
	dc.w 8,	$B02, $E162, 8
	dc.w 8,	$302, $E16E, $38
	dc.w $10, $302,	$E172, 0
	dc.w $10, $C02,	$E176, $40
	dc.w $18, $302,	$E17A, $40
	dc.w $18, $602,	$E17E, $50
	dc.w $20, $B02,	$E184, $20
	dc.w $20, $302,	$E190, $48
	dc.w $28, $902,	$E194, 8
	dc.w $28, $202,	$E19A, $38
	dc.w $30, 2, $E19D, $50
	dc.w $38, 2, $E19E, $40

word_145A8:	dc.w 3
	dc.w 0,	$E01, $8254, $FFE4
	dc.w 0,	$E01, $8260, 4
	dc.w 0,	$601, $826C, $24

word_145C2:	dc.w 1
	dc.w $FFFC, 3, $82E2, $FFFC

word_145CC:	dc.w 1
	dc.w $FFFC, 3, $82E3, $FFFC

word_145D6:	dc.w 1
	dc.w $FFFC, 3, $82E4, $FFFC

word_145E0:	dc.w 1
	dc.w $FFFC, 3, $82E5, $FFFC

word_145EA:	dc.w 1
	dc.w $FFFC, 3, $82E6, $FFFC

word_145F4:	dc.w 1
	dc.w $FFFC, 3, $82E7, $FFFC

word_145FE:	dc.w 1
	dc.w $FFFC, 3, $82E8, $FFFC

word_14608:	dc.w 1
	dc.w $FFFC, 3, $82E9, $FFFC

word_14612:	dc.w 1
	dc.w $FFFC, 3, $82EA, $FFFC

word_1461C:	dc.w 1
	dc.w $FFFC, 3, $82EB, $FFFC

word_14626:	dc.w 1
	dc.w $FFFC, 3, $82EC, $FFFC

word_14630:	dc.w 1
	dc.w $FFFC, 3, $82ED, $FFFC

word_1463A:	dc.w 1
	dc.w $FFFC, 3, $82EE, $FFFC

word_14644:	dc.w 1
	dc.w $FFFC, 3, $82EF, $FFFC

word_1464E:	dc.w 1
	dc.w $FFFC, 3, $82F0, $FFFC

; ---------------------------------------------------------------------------

off_14658:
	dc.l word_14670
	dc.l word_1468A
	dc.l word_146A4
	dc.l word_146D6
	dc.l word_14708
	dc.l word_1473A

word_14670:	dc.w 3
	dc.w $FFE4, $600, $A4C0, $FFF0
	dc.w $FFE4, $600, $ACC0, 0
	dc.w $FFD8, $400, $E4CC, $FFF8

word_1468A:	dc.w 3
	dc.w $FFE4, $600, $A4C6, $FFF0
	dc.w $FFE4, $600, $ACC6, 0
	dc.w $FFD8, $400, $E4CE, $FFF8

word_146A4:	dc.w 6
	dc.w $FFE3, $503, $E4FC, $FFF8
	dc.w $FFF0, $502, $E4F4, $FFF8
	dc.w $FFE4, $502, $E4EC, $FFE8
	dc.w $FFE4, $502, $ECEC, 8
	dc.w $FFDC, $201, $E4E6, $FFFC
	dc.w $FFC5, $F00, $E4D0, $FFF0

word_146D6:	dc.w 6
	dc.w $FFE3, $503, $E4FC, $FFF8
	dc.w $FFF0, $502, $E4F4, $FFF8
	dc.w $FFE4, $502, $E4F0, $FFE8
	dc.w $FFE4, $502, $ECEC, 8
	dc.w $FFDC, $601, $E4E0, $FFF8
	dc.w $FFC5, $F00, $E4D0, $FFE8

word_14708:	dc.w 6
	dc.w $FFE3, $503, $E4FC, $FFF8
	dc.w $FFF0, $502, $E4F8, $FFF8
	dc.w $FFE4, $502, $E4EC, $FFE8
	dc.w $FFE4, $502, $ECEC, 8
	dc.w $FFDC, $201, $E4E9, $FFFC
	dc.w $FFC9, $F00, $E4D0, $FFF0

word_1473A:	dc.w 6
	dc.w $FFE3, $503, $E4FC, $FFF8
	dc.w $FFF0, $502, $E4F4, $FFF8
	dc.w $FFE4, $502, $E4EC, $FFE8
	dc.w $FFE4, $502, $ECF0, 8
	dc.w $FFDC, $601, $ECE0, $FFF8
	dc.w $FFC7, $F00, $E4D0, $FFF8

; ---------------------------------------------------------------------------

off_1476C:
	dc.l word_1479C
	dc.l word_147BA
	dc.l word_147D8
	dc.l word_147F6
	dc.l word_147A6
	dc.l word_147C4
	dc.l word_147E2
	dc.l word_14800
	dc.l word_147B0
	dc.l word_147CE
	dc.l word_147EC
	dc.l word_1480A

word_1479C:	dc.w 1
	dc.w $FFF8, $502, $831C, $FFF8

word_147A6:	dc.w 1
	dc.w $FFFC, 2, $8324, $FFFC

word_147B0:	dc.w 1
	dc.w $FFFC, 2, $8326, $FFFC

word_147BA:	dc.w 1
	dc.w $FFF8, $502, $8320, $FFF8

word_147C4:	dc.w 1
	dc.w $FFFC, 2, $8325, $FFFC

word_147CE:	dc.w 1
	dc.w $FFFC, 2, $8327, $FFFC

word_147D8:	dc.w 1
	dc.w $FFF8, $502, $A31C, $FFF8

word_147E2:	dc.w 1
	dc.w $FFFC, 2, $A324, $FFFC

word_147EC:	dc.w 1
	dc.w $FFFC, 2, $A326, $FFFC

word_147F6:	dc.w 1
	dc.w $FFF8, $502, $A320, $FFF8

word_14800:	dc.w 1
	dc.w $FFFC, 2, $A325, $FFFC

word_1480A:	dc.w 1
	dc.w $FFFC, 2, $A327, $FFFC

; ---------------------------------------------------------------------------

off_14834:
	dc.l word_14844
	dc.l word_14844
	dc.l word_14844
	dc.l word_14844

word_14844:	dc.w 6
	dc.w 0,	$F00, $E4F0, 0
	dc.w 0,	$F00, $E4F0, $20
	dc.w 0,	$700, $E4F0, $40
	dc.w $20, $E00,	$E4F0, 0
	dc.w $20, $E00,	$E4F0, $20
	dc.w $20, $600,	$E4F0, $40

; ---------------------------------------------------------------------------

off_14876:
	dc.l word_1488A
	dc.l word_148C4
	dc.l word_148E6
	dc.l word_14918
	dc.l word_1493A

word_1488A:	dc.w 7
	dc.w $FFF8, $102, $8588, $FFE4
	dc.w $FFF8, $102, $8580, $FFEC
	dc.w $FFF8, $102, $85A4, $FFF4
	dc.w $FFF8, $102, $8590, $FFFC
	dc.w $FFF8, $102, $8588, 4
	dc.w $FFF8, $102, $85A4, $C
	dc.w $FFF8, $102, $85A6, $14

word_148C4:	dc.w 4
	dc.w $FFF8, $102, $8588, $FFF0
	dc.w $FFF8, $102, $8580, $FFF8
	dc.w $FFF8, $102, $85A4, 0
	dc.w $FFF8, $102, $85B0, 8

word_148E6:	dc.w 6
	dc.w $FFF8, $102, $859A, $FFE8
	dc.w $FFF8, $102, $859C, $FFF0
	dc.w $FFF8, $102, $85A2, $FFF8
	dc.w $FFF8, $102, $8598, 0
	dc.w $FFF8, $102, $8580, 8
	dc.w $FFF8, $102, $8596, $10

word_14918:	dc.w 4
	dc.w $FFF8, $102, $858E, $FFF0
	dc.w $FFF8, $102, $8580, $FFF8
	dc.w $FFF8, $102, $85A2, 0
	dc.w $FFF8, $102, $8586, 8

word_1493A:	dc.w 7
	dc.w $FFF8, $102, $858E, $FFE4
	dc.w $FFF8, $102, $8580, $FFEC
	dc.w $FFF8, $102, $85A2, $FFF4
	dc.w $FFF8, $102, $8586, $FFFC
	dc.w $FFF8, $102, $8588, 4
	dc.w $FFF8, $102, $85A4, $C
	dc.w $FFF8, $102, $85A6, $14

; ---------------------------------------------------------------------------

off_14974:
	dc.l word_1499C
	dc.l word_149A6
	dc.l word_149B0
	dc.l word_149BA
	dc.l word_149C4
	dc.l word_149CE
	dc.l word_149D8
	dc.l word_149E2
	dc.l word_149EC
	dc.l word_149F6

word_1499C:	dc.w 1
	dc.w 0,	0, $E3F7, 0

word_149A6:	dc.w 1
	dc.w 0,	0, $E3F9, 0

word_149B0:	dc.w 1
	dc.w 0,	0, $E3FD, 0

word_149BA:	dc.w 1
	dc.w 0,	0, $E3FF, 0

word_149C4:	dc.w 1
	dc.w 0,	$100, $E3F5, 0

word_149CE:	dc.w 1
	dc.w 0,	1, $E1F7, 0

word_149D8:	dc.w 1
	dc.w 0,	1, $E1F9, 0

word_149E2:	dc.w 1
	dc.w 0,	1, $E1FD, 0

word_149EC:	dc.w 1
	dc.w 0,	1, $E1FF, 0

word_149F6:	dc.w 1
	dc.w 0,	$100, $E1F5, 0

; ---------------------------------------------------------------------------

off_14A00:
	dc.l word_14A20
	dc.l word_14A2A
	dc.l word_14A34
	dc.l word_14A3E
	dc.l word_14A48
	dc.l word_14A52
	dc.l word_14A5C
	dc.l word_14A66

word_14A20:	dc.w 1
	dc.w $FFF0, $A00, $E252, $FFF4

word_14A2A:	dc.w 1
	dc.w $FFF0, $A01, $E25B, $FFF4

word_14A34:	dc.w 1
	dc.w $FFF0, $A02, $E264, $FFF4

word_14A3E:	dc.w 1
	dc.w $FFF0, $A03, $E26D, $FFF4

word_14A48:	dc.w 1
	dc.w $FFF0, $A00, $E276, $FFF4

word_14A52:	dc.w 1
	dc.w $FFF0, $A01, $E27F, $FFF4

word_14A5C:	dc.w 1
	dc.w $FFF0, $A02, $E26D, $FFF4

word_14A66:	dc.w 1
	dc.w $FFF0, $A03, $E288, $FFF4

; ---------------------------------------------------------------------------

off_14A70:
	dc.l word_14A98
	dc.l word_14AA2
	dc.l word_14AAC
	dc.l word_14AB6
	dc.l word_14AC0
	dc.l word_14ACA
	dc.l word_14AD4
	dc.l word_14ADE
	dc.l word_14AE8
	dc.l word_14AF2

word_14A98:	dc.w 1
	dc.w $FFFC, $100, $856C, 0

word_14AA2:	dc.w 1
	dc.w $FFFC, $100, $856E, 0

word_14AAC:	dc.w 1
	dc.w $FFFC, $100, $8570, 0

word_14AB6:	dc.w 1
	dc.w $FFFC, $100, $8572, 0

word_14AC0:	dc.w 1
	dc.w $FFFC, $100, $8574, 0

word_14ACA:	dc.w 1
	dc.w $FFFC, $100, $8576, 0

word_14AD4:	dc.w 1
	dc.w $FFFC, $100, $8578, 0

word_14ADE:	dc.w 1
	dc.w $FFFC, $100, $857A, 0

word_14AE8:	dc.w 1
	dc.w $FFFC, $100, $857C, 0

word_14AF2:	dc.w 1
	dc.w $FFFC, $100, $857E, 0

; ---------------------------------------------------------------------------

off_14E00:
	dc.l word_14E96
	dc.l word_14EF0
	dc.l word_14E30
	dc.l word_14E42
	dc.l word_14E54
	dc.l word_14E1C
	dc.l word_14E26

word_14E1C:	dc.w 1
	dc.w $FFF8, 0, $C560, $FFF8

word_14E26:	dc.w 1
	dc.w $FFF8, 0, $AD60, $FFF8

word_14E30:	dc.w 2
	dc.w 1,	$C00, $85BA, 4
	dc.w 1,	0, $85BE, $24

word_14E42:	dc.w 2
	dc.w 1,	$C00, $85BA, 0
	dc.w 1,	0, $85BF, $20

word_14E54:	dc.w 8
	dc.w $FFFC, $100, $858A, $FFE8
	dc.w $FFFC, $100, $85A2, $FFF0
	dc.w $FFFC, $100, $8588, $FFF8
	dc.w $FFFC, $100, $8588, 0
	dc.w $FFFC, $100, $859E, $C
	dc.w $FFFC, $100, $8596, $14
	dc.w $FFFC, $100, $8580, $1C
	dc.w $FFFC, $100, $85B0, $24

word_14E96:	dc.w $B
	dc.w $FFFC, $100, $8590, 0
	dc.w $FFFC, $100, $859A, 8
	dc.w $FFFC, $100, $85A4, $10
	dc.w $FFFC, $100, $8588, $18
	dc.w $FFFC, $100, $85A2, $20
	dc.w $FFFC, $100, $85A6, $28
	dc.w $FFFC, $100, $8584, $34
	dc.w $FFFC, $100, $859C, $3C
	dc.w $FFFC, $100, $8590, $44
	dc.w $FFFC, $100, $859A, $4C
	dc.w 0,	$400, $85B8, $54

word_14EF0:	dc.w 7
	dc.w $FFF8, $100, $8524, $FFE0
	dc.w $FFF8, $100, $853E, $FFE8
	dc.w $FFF8, $100, $8538, $FFF0
	dc.w $FFF8, $100, $8538, $FFF8
	dc.w $FFF8, $100, $8546, 0
	dc.w $FFF8, $100, $853E, $10
	dc.w $FFF8, $100, $8534, $18

; ---------------------------------------------------------------------------

off_14F2A:
	dc.l word_14F36
	dc.l word_14F78
	dc.l word_14F8A

word_14F36:	dc.w 8
	dc.w $FFF8, $100, $A522, $FFDC
	dc.w $FFF8, $100, $A516, $FFE4
	dc.w $FFF8, $100, $A52E, $FFEC
	dc.w $FFF8, $100, $A51E, $FFF4
	dc.w $FFF8, $100, $A532, 4
	dc.w $FFF8, $100, $A540, $C
	dc.w $FFF8, $100, $A51E, $14
	dc.w $FFF8, $100, $A538, $1C

word_14F78:	dc.w 2
	dc.w $FFF8, $D00, $A54C, $FFDC
	dc.w $FFF8, $D00, $A554, 4

word_14F8A:	dc.w 2
	dc.w $FFF8, $D00, $A55C, $FFDC
	dc.w $FFF8, $D00, $A564, 4

; ---------------------------------------------------------------------------

off_14F9C:
	dc.l word_14FC0
	dc.l word_14FD2
	dc.l word_14FE4
	dc.l word_14FF6
	dc.l word_15008
	dc.l word_15012
	dc.l word_1501C
	dc.l word_15026
	dc.l word_15030

word_14FC0:	dc.w 2
	dc.w $FFF8, $501, $100,	$FFF8
	dc.w $FFFE, $503, $614C, $FFFE

word_14FD2:	dc.w 2
	dc.w $FFF8, $501, $148,	$FFF8
	dc.w $FFFE, $503, $614C, $FFFE

word_14FE4:	dc.w 2
	dc.w $FFF8, $501, $140,	$FFF8
	dc.w $FFFE, $503, $614C, $FFFE

word_14FF6:	dc.w 2
	dc.w $FFF8, $501, $144,	$FFF8
	dc.w $FFFE, $503, $614C, $FFFE

word_15008:	dc.w 1
	dc.w $FFF8, $502, $31C,	$FFF8

word_15012:	dc.w 1
	dc.w $FFFC, 2, $324, $FFFC

word_1501C:	dc.w 1
	dc.w $FFFC, 2, $326, $FFFC

word_15026:	dc.w 1
	dc.w $FFFE, $503, $614C, $FFFE

word_15030:	dc.w 2
	dc.w $FFF8, $501, $150,	$FFF8
	dc.w $FFFE, $503, $614C, $FFFE

; ---------------------------------------------------------------------------

off_15042:
	dc.l word_15066
	dc.l word_15078
	dc.l word_1508A
	dc.l word_1509C
	dc.l word_150AE
	dc.l word_150B8
	dc.l word_150C2
	dc.l word_150CC
	dc.l word_150D6

word_15066:	dc.w 2
	dc.w $FFF8, $501, $154,	$FFF8
	dc.w $FFFE, $503, $61A0, $FFFE

word_15078:	dc.w 2
	dc.w $FFF8, $501, $19C,	$FFF8
	dc.w $FFFE, $503, $61A0, $FFFE

word_1508A:	dc.w 2
	dc.w $FFF8, $501, $194,	$FFF8
	dc.w $FFFE, $503, $61A0, $FFFE

word_1509C:	dc.w 2
	dc.w $FFF8, $501, $198,	$FFF8
	dc.w $FFFE, $503, $61A0, $FFFE

word_150AE:	dc.w 1
	dc.w $FFF8, $502, $320,	$FFF8

word_150B8:	dc.w 1
	dc.w $FFFC, 2, $325, $FFFC

word_150C2:	dc.w 1
	dc.w $FFFC, 2, $327, $FFFC

word_150CC:	dc.w 1
	dc.w $FFFE, $503, $61A0, $FFFE

word_150D6:	dc.w 2
	dc.w $FFF8, $501, $1A4,	$FFF8
	dc.w $FFFE, $503, $61A0, $FFFE

; ---------------------------------------------------------------------------

off_150E8:
	dc.l word_1535C
	dc.l word_15366
	dc.l word_15370
	dc.l word_15382
	dc.l word_15394
	dc.l word_153AE
	dc.l word_153B8
	dc.l word_15154
	dc.l word_15176
	dc.l word_15198
	dc.l word_151BA
	dc.l word_151DC
	dc.l word_151FE
	dc.l word_15210
	dc.l word_15222
	dc.l word_15234
	dc.l word_15246
	dc.l word_15258
	dc.l word_1527A
	dc.l word_1529C
	dc.l word_152BE
	dc.l word_152E0
	dc.l word_15302
	dc.l word_15314
	dc.l word_15326
	dc.l word_15338
	dc.l word_1534A

word_15154:	dc.w 4
	dc.w $FFF8, 0, $81A8, $FFF8
	dc.w 0,	0, $91A8, $FFF8
	dc.w $FFF8, 0, $89A8, 0
	dc.w 0,	0, $99A8, 0

word_15176:	dc.w 4
	dc.w $FFF8, $400, $81A9, $FFF0
	dc.w 0,	$400, $91A9, $FFF0
	dc.w $FFF8, $400, $89A9, 0
	dc.w 0,	$400, $99A9, 0

word_15198:	dc.w 4
	dc.w $FFF0, $500, $81AB, $FFF0
	dc.w 0,	$500, $91AB, $FFF0
	dc.w $FFF0, $500, $89AB, 0
	dc.w 0,	$500, $99AB, 0

word_151BA:	dc.w 4
	dc.w $FFF0, $500, $81AF, $FFF0
	dc.w 0,	$500, $91AF, $FFF0
	dc.w $FFF0, $500, $89AF, 0
	dc.w 0,	$500, $99AF, 0

word_151DC:	dc.w 4
	dc.w $FFF8, 0, $81B3, $FFF8
	dc.w 0,	0, $91B3, $FFF8
	dc.w $FFF8, 0, $89B3, 0
	dc.w 0,	0, $99B3, 0

word_151FE:	dc.w 2
	dc.w $FFF8, $400, $81B4, $FFF8
	dc.w 0,	$400, $99B4, $FFF8

word_15210:	dc.w 2
	dc.w $FFF0, $D00, $81B6, $FFF0
	dc.w 0,	$D00, $99B6, $FFF0

word_15222:	dc.w 2
	dc.w $FFF0, $D00, $81BE, $FFF0
	dc.w 0,	$D00, $99BE, $FFF0

word_15234:	dc.w 2
	dc.w $FFF0, $D00, $81C6, $FFF0
	dc.w 0,	$D00, $99C6, $FFF0

word_15246:	dc.w 2
	dc.w $FFF0, $D00, $81CE, $FFF0
	dc.w 0,	$D00, $99CE, $FFF0

word_15258:	dc.w 4
	dc.w $FFF8, 0, $A1A8, $FFF8
	dc.w 0,	0, $B1A8, $FFF8
	dc.w $FFF8, 0, $A9A8, 0
	dc.w 0,	0, $B9A8, 0

word_1527A:	dc.w 4
	dc.w $FFF8, $400, $A1A9, $FFF0
	dc.w 0,	$400, $B1A9, $FFF0
	dc.w $FFF8, $400, $A9A9, 0
	dc.w 0,	$400, $B9A9, 0

word_1529C:	dc.w 4
	dc.w $FFF0, $500, $A1AB, $FFF0
	dc.w 0,	$500, $B1AB, $FFF0
	dc.w $FFF0, $500, $A9AB, 0
	dc.w 0,	$500, $B9AB, 0

word_152BE:	dc.w 4
	dc.w $FFF0, $500, $A1AF, $FFF0
	dc.w 0,	$500, $B1AF, $FFF0
	dc.w $FFF0, $500, $A9AF, 0
	dc.w 0,	$500, $B9AF, 0

word_152E0:	dc.w 4
	dc.w $FFF8, 0, $A1B3, $FFF8
	dc.w 0,	0, $B1B3, $FFF8
	dc.w $FFF8, 0, $A9B3, 0
	dc.w 0,	0, $B9B3, 0

word_15302:	dc.w 2
	dc.w $FFF8, $400, $A1B4, $FFF8
	dc.w 0,	$400, $B9B4, $FFF8

word_15314:	dc.w 2
	dc.w $FFF0, $D00, $A1B6, $FFF0
	dc.w 0,	$D00, $B9B6, $FFF0

word_15326:	dc.w 2
	dc.w $FFF0, $D00, $A1BE, $FFF0
	dc.w 0,	$D00, $B9BE, $FFF0

word_15338:	dc.w 2
	dc.w $FFF0, $D00, $A1C6, $FFF0
	dc.w 0,	$D00, $B9C6, $FFF0

word_1534A:	dc.w 2
	dc.w $FFF0, $D00, $A1CE, $FFF0
	dc.w 0,	$D00, $B9CE, $FFF0

word_1535C:	dc.w 1
	dc.w $FFF8, $500, $81DE, 0

word_15366:	dc.w 1
	dc.w $FFF8, $900, $81E2, 0

word_15370:	dc.w 2
	dc.w $FFF8, $900, $81E2, 0
	dc.w $FFF8, $500, $81DE, $18

word_15382:	dc.w 2
	dc.w $FFF8, $900, $81E2, 0
	dc.w $FFF8, $900, $81E2, $18

word_15394:	dc.w 3
	dc.w $FFF8, $900, $81E2, 0
	dc.w $FFF8, $900, $81E2, $18
	dc.w $FFF8, $500, $81DE, $30

word_153AE:	dc.w 1
	dc.w $FFF8, $500, $81DA, 0

word_153B8:	dc.w 1
	dc.w $FFF8, $500, $81D6, 0

; ---------------------------------------------------------------------------

off_153C2:
	dc.l word_153E6
	dc.l word_153F8
	dc.l word_1540A
	dc.l word_1541C
	dc.l word_1542E
	dc.l word_15438
	dc.l word_15442
	dc.l word_1544C
	dc.l word_15456

word_153E6:	dc.w 2
	dc.w $FFF8, $501, $41FC, $FFF8
	dc.w $FFFE, $503, $6248, $FFFE

word_153F8:	dc.w 2
	dc.w $FFF8, $501, $4244, $FFF8
	dc.w $FFFE, $503, $6248, $FFFE

word_1540A:	dc.w 2
	dc.w $FFF8, $501, $423C, $FFF8
	dc.w $FFFE, $503, $6248, $FFFE

word_1541C:	dc.w 2
	dc.w $FFF8, $501, $4240, $FFF8
	dc.w $FFFE, $503, $6248, $FFFE

word_1542E:	dc.w 1
	dc.w $FFF8, $502, $431C, $FFF8

word_15438:	dc.w 1
	dc.w $FFFC, 2, $4324, $FFFC

word_15442:	dc.w 1
	dc.w $FFFC, 2, $4326, $FFFC

word_1544C:	dc.w 1
	dc.w $FFFE, $503, $6248, $FFFE

word_15456:	dc.w 2
	dc.w $FFF8, $501, $424C, $FFF8
	dc.w $FFFE, $503, $6248, $FFFE

; ---------------------------------------------------------------------------

off_15468:
	dc.l word_1548C
	dc.l word_1549E
	dc.l word_154B0
	dc.l word_154C2
	dc.l word_154D4
	dc.l word_154DE
	dc.l word_154E8
	dc.l word_154F2
	dc.l word_154FC

word_1548C:	dc.w 2
	dc.w $FFF8, $501, $2250, $FFF8
	dc.w $FFFE, $503, $629C, $FFFE

word_1549E:	dc.w 2
	dc.w $FFF8, $501, $2298, $FFF8
	dc.w $FFFE, $503, $629C, $FFFE

word_154B0:	dc.w 2
	dc.w $FFF8, $501, $2290, $FFF8
	dc.w $FFFE, $503, $629C, $FFFE

word_154C2:	dc.w 2
	dc.w $FFF8, $501, $2294, $FFF8
	dc.w $FFFE, $503, $629C, $FFFE

word_154D4:	dc.w 1
	dc.w $FFF8, $502, $2320, $FFF8

word_154DE:	dc.w 1
	dc.w $FFFC, 2, $2325, $FFFC

word_154E8:	dc.w 1
	dc.w $FFFC, 2, $2327, $FFFC

word_154F2:	dc.w 1
	dc.w $FFFE, $503, $629C, $FFFE

word_154FC:	dc.w 2
	dc.w $FFF8, $501, $22A0, $FFF8
	dc.w $FFFE, $503, $629C, $FFFE

; ---------------------------------------------------------------------------

off_1550E:
	dc.l word_15532
	dc.l word_15544
	dc.l word_15556
	dc.l word_15568
	dc.l word_1557A
	dc.l word_15584
	dc.l word_1558E
	dc.l word_15598
	dc.l word_155A2

word_15532:	dc.w 2
	dc.w $FFF8, $501, $22A4, $FFF8
	dc.w $FFFE, $503, $62F0, $FFFE

word_15544:	dc.w 2
	dc.w $FFF8, $501, $22EC, $FFF8
	dc.w $FFFE, $503, $62F0, $FFFE

word_15556:	dc.w 2
	dc.w $FFF8, $501, $22E4, $FFF8
	dc.w $FFFE, $503, $62F0, $FFFE

word_15568:	dc.w 2
	dc.w $FFF8, $501, $22E8, $FFF8
	dc.w $FFFE, $503, $62F0, $FFFE

word_1557A:	dc.w 1
	dc.w $FFF8, $502, $231C, $FFF8

word_15584:	dc.w 1
	dc.w $FFFC, 2, $2324, $FFFC

word_1558E:	dc.w 1
	dc.w $FFFC, 2, $2326, $FFFC

word_15598:	dc.w 1
	dc.w $FFFE, $503, $62F0, $FFFE

word_155A2:	dc.w 2
	dc.w $FFF8, $501, $22F4, $FFF8
	dc.w $FFFE, $503, $62F0, $FFFE

; ---------------------------------------------------------------------------

off_155B4:
	dc.l word_15866
	dc.l word_15878
	dc.l word_1588A
	dc.l word_1589C
	dc.l word_156A0
	dc.l 0
	dc.l word_158AE
	dc.l word_158B8
	dc.l word_158C2
	dc.l word_158CC
	dc.l word_158FE
	dc.l 0
	dc.l word_158D6
	dc.l word_158E0
	dc.l word_158EA
	dc.l word_158F4
	dc.l word_156EA
	dc.l word_156F4
	dc.l word_15716
	dc.l word_15738
	dc.l word_1575A
	dc.l word_1576C
	dc.l word_1577E
	dc.l word_15798
	dc.l word_157BA
	dc.l 0
	dc.l word_157E4
	dc.l word_157EE
	dc.l word_15800
	dc.l word_1581A
	dc.l word_1583C
	dc.l 0
	dc.l word_1563C
	dc.l word_1566E

word_1563C:	dc.w 6
	dc.w $FFFC, $100, $8534, $FFE8
	dc.w $FFFC, $100, $8516, $FFF0
	dc.w $FFFC, $100, $853E, $FFF8
	dc.w $FFFC, $100, $853A, 0
	dc.w $FFFC, $100, $851E, 8
	dc.w $FFFC, $100, $851C, $10

word_1566E:	dc.w 6
	dc.w $FFFC, $100, $A534, $FFE8
	dc.w $FFFC, $100, $A516, $FFF0
	dc.w $FFFC, $100, $A53E, $FFF8
	dc.w $FFFC, $100, $A53A, 0
	dc.w $FFFC, $100, $A51E, 8
	dc.w $FFFC, $100, $A51C, $10

word_156A0:	dc.w 9
	dc.w $FFFC, 0, $8201, $24
	dc.w 0,	$F01, $8220, 0
	dc.w 0,	$F01, $8230, $20
	dc.w 0,	$F01, $8240, $40
	dc.w 0,	$B01, $8250, $60
	dc.w $20, $E01,	$8260, 0
	dc.w $20, $E01,	$826C, $20
	dc.w $20, $E01,	$8278, $40
	dc.w $20, $A01,	$8284, $60

word_156EA:	dc.w 1
	dc.w 0,	$D00, $E488, 0

word_156F4:	dc.w 4
	dc.w $FFF4, 0, $4314, $FFF8
	dc.w $FFF4, 0, $4B14, 0
	dc.w $FFFC, 3, $4315, $FFF0
	dc.w $FFFC, 3, $4B15, 8

word_15716:	dc.w 4
	dc.w $FFF4, 0, $4314, $FFF8
	dc.w $FFF4, 0, $4B14, 0
	dc.w $FFFE, 3, $4316, $FFF0
	dc.w $FFFE, 3, $4B16, 8

word_15738:	dc.w 4
	dc.w $FFF4, 0, $4314, $FFF8
	dc.w $FFF4, 0, $4B14, 0
	dc.w 0,	3, $4317, $FFF0
	dc.w 0,	3, $4B17, 8

word_1575A:	dc.w 2
	dc.w $FFF8, $502, $42F8, $FFF8
	dc.w $FFFE, $503, $6310, $FFFE

word_1576C:	dc.w 2
	dc.w $FFF8, $502, $42F8, $FFF8
	dc.w $FFE8, $502, $42F8, $FFF8

word_1577E:	dc.w 3
	dc.w $FFF8, $502, $42F8, $FFF8
	dc.w $FFE8, $502, $42F8, $FFF8
	dc.w $FFD8, $502, $42F8, $FFF8

word_15798:	dc.w 4
	dc.w $FFF8, $502, $42F8, $FFF8
	dc.w $FFE8, $502, $42F8, $FFF8
	dc.w $FFD8, $502, $42F8, $FFF8
	dc.w $FFC8, $502, $42F8, $FFF8

word_157BA:	dc.w 5
	dc.w $FFF8, $502, $42F8, $FFF8
	dc.w $FFE8, $502, $42F8, $FFF8
	dc.w $FFD8, $502, $42F8, $FFF8
	dc.w $FFC8, $502, $42F8, $FFF8
	dc.w $FFB8, $502, $42F8, $FFF8

word_157E4:	dc.w 2
	dc.w $FFFE, $503, $6310, $FFFE

word_157EE:	dc.w 2
	dc.w $FFFE, $503, $6310, $FFFE
	dc.w $FFEE, $503, $6310, $FFFE

word_15800:	dc.w 3
	dc.w $FFFE, $503, $6310, $FFFE
	dc.w $FFEE, $503, $6310, $FFFE
	dc.w $FFDE, $503, $6310, $FFFE

word_1581A:	dc.w 4
	dc.w $FFFE, $503, $6310, $FFFE
	dc.w $FFEE, $503, $6310, $FFFE
	dc.w $FFDE, $503, $6310, $FFFE
	dc.w $FFCE, $503, $6310, $FFFE

word_1583C:	dc.w 5
	dc.w $FFFE, $503, $6310, $FFFE
	dc.w $FFEE, $503, $6310, $FFFE
	dc.w $FFDE, $503, $6310, $FFFE
	dc.w $FFCE, $503, $6310, $FFFE
	dc.w $FFBE, $503, $6310, $FFFE

word_15866:	dc.w 2
	dc.w $FFF8, $502, $42F8, $FFF8
	dc.w $FFFE, $503, $6310, $FFFE

word_15878:	dc.w 2
	dc.w $FFF8, $502, $42FC, $FFF8
	dc.w $FFFE, $503, $6310, $FFFE

word_1588A:	dc.w 2
	dc.w $FFF8, $502, $4300, $FFF8
	dc.w $FFFE, $503, $6310, $FFFE

word_1589C:	dc.w 2
	dc.w $FFF8, $502, $4304, $FFF8
	dc.w $FFFE, $503, $6310, $FFFE

word_158AE:	dc.w 1
	dc.w $FFFE, $503, $6310, $FFFE

word_158B8:	dc.w 1
	dc.w $FFFE, $503, $6310, $FFFE

word_158C2:	dc.w 1
	dc.w $FFFE, $503, $6310, $FFFE

word_158CC:	dc.w 1
	dc.w $FFFE, $503, $6310, $FFFE

word_158D6:	dc.w 1
	dc.w $FFF8, $500, $E0F8, $FFF8

word_158E0:	dc.w 1
	dc.w $FFF8, $500, $E0FC, $FFF8

word_158EA:	dc.w 1
	dc.w $FFFC, 0, $832A, $FFFC

word_158F4:	dc.w 1
	dc.w $FFFC, 3, $832A, $FFFC

word_158FE:	dc.w 1
	dc.w $FFFC, 3, $32A, $FFFC

; ---------------------------------------------------------------------------

off_15CB0:
	dc.l word_15CC8
	dc.l word_15CD2
	dc.l word_15CDC
	dc.l word_15CE6
	dc.l word_15CF0
	dc.l word_15CFA

word_15CC8:	dc.w 1
	dc.w $FFF0, $E01, $C438, $FFF0

word_15CD2:	dc.w 1
	dc.w $FFF0, $E01, $C444, $FFF0

word_15CDC:	dc.w 1
	dc.w $FFE8, $F01, $C450, $FFF0

word_15CE6:	dc.w 1
	dc.w $FFF0, $E01, $4438, $FFF0

word_15CF0:	dc.w 1
	dc.w $FFF0, $E01, $4444, $FFF0

word_15CFA:	dc.w 1
	dc.w $FFE8, $F01, $4450, $FFF0

; ---------------------------------------------------------------------------

off_15D04:
	dc.l word_15D64
	dc.l word_15DCE
	dc.l word_15E28
	dc.l word_15EB2
	dc.l word_15F3C
	dc.l word_15FBE
	dc.l word_16048
	dc.l word_160CA
	dc.l word_16134
	dc.l word_161B6
	dc.l word_16240
	dc.l word_162BA
	dc.l word_1633C
	dc.l word_163BE
	dc.l word_16428
	dc.l word_16492
	dc.l word_16514
	dc.l word_15D64
	dc.l word_15D64
	dc.l word_15D64
	dc.l word_15D64
	dc.l word_1658E
	dc.l word_16618
	dc.l word_1667A

word_15D64:	dc.w $D
	dc.w $18, $B04,	$4100, $28
	dc.w $20, $704,	$410C, $18
	dc.w $20, $304,	$4114, $40
	dc.w $30, $304,	$4118, $10
	dc.w $38, $B04,	$411C, $28
	dc.w $40, $704,	$4128, $18
	dc.w $40, $304,	$4130, $40
	dc.w $48, $304,	$4134, 8
	dc.w $50, $204,	$4138, $10
	dc.w $58, $104,	$413B, $38
	dc.w $58, $104,	$413D, $48
	dc.w $60, $C04,	$413F, $18
	dc.w $60, 4, $4143, $40

word_15DCE:	dc.w $B
	dc.w $18, $704,	$4100, $28
	dc.w $20, $704,	$4108, $18
	dc.w $20, $904,	$4110, $38
	dc.w $28, $304,	$4116, $10
	dc.w $30, $704,	$411A, $38
	dc.w $38, $704,	$4122, $28
	dc.w $40, $704,	$412A, $18
	dc.w $48, $704,	$4132, 8
	dc.w $50, $604,	$413A, $38
	dc.w $58, $104,	$4140, $48
	dc.w $60, $C04,	$4142, $18

word_15E28:	dc.w $11
	dc.w $18, $F04,	$4100, $20
	dc.w $20, $304,	$4110, $18
	dc.w $20, $304,	$4114, $40
	dc.w $28, $704,	$4118, 8
	dc.w $28, $304,	$4120, $48
	dc.w $30, $204,	$4124, 0
	dc.w $30, $304,	$4127, $50
	dc.w $38, $F04,	$412B, $20
	dc.w $40, $304,	$413B, $18
	dc.w $40, $304,	$413F, $40
	dc.w $48, $704,	$4143, 8
	dc.w $50, $204,	$414B, $48
	dc.w $58, $104,	$414E, $20
	dc.w $58, $104,	$4150, $38
	dc.w $60, 4, $4152, $18
	dc.w $60, $404,	$4153, $28
	dc.w $60, 4, $4155, $40

word_15EB2:	dc.w $11
	dc.w $18, $304,	$4100, $38
	dc.w $18, $604,	$4104, $58
	dc.w $20, $F04,	$410A, $18
	dc.w $20, $704,	$411A, $40
	dc.w $28, $704,	$4122, 8
	dc.w $28, $104,	$412A, $50
	dc.w $30, 4, $412C, $58
	dc.w $38, $304,	$412D, $38
	dc.w $40, $E04,	$4131, $18
	dc.w $40, $704,	$413D, $40
	dc.w $48, $304,	$4145, $10
	dc.w $50, $204,	$4149, 8
	dc.w $58, $104,	$414C, 0
	dc.w $58, $504,	$414E, $18
	dc.w $58, $104,	$4152, $38
	dc.w $60, $404,	$4154, $28
	dc.w $60, $404,	$4156, $40

word_15F3C:	dc.w $10
	dc.w $10, $404,	$4100, $40
	dc.w $18, $704,	$4102, $48
	dc.w $20, $F04,	$410A, $18
	dc.w $20, $704,	$411A, $38
	dc.w $20, $104,	$4122, $58
	dc.w $28, $304,	$4124, $10
	dc.w $30, $204,	$4128, 8
	dc.w $38, $304,	$412B, $48
	dc.w $40, $E04,	$412F, $18
	dc.w $40, $704,	$413B, $38
	dc.w $48, $304,	$4143, $10
	dc.w $50, $204,	$4147, 8
	dc.w $58, $104,	$414A, 0
	dc.w $58, $504,	$414C, $18
	dc.w $58, $104,	$4150, $48
	dc.w $60, $C04,	$4152, $28

word_15FBE:	dc.w $11
	dc.w $20, $F04,	$4100, $20
	dc.w $20, $304,	$4110, $40
	dc.w $28, $304,	$4114, $18
	dc.w $28, $A04,	$4118, $48
	dc.w $30, $104,	$4121, $10
	dc.w $30, $204,	$4123, $60
	dc.w $38, $404,	$4126, $68
	dc.w $40, $E04,	$4128, $20
	dc.w $40, $704,	$4134, $40
	dc.w $40, 4, $413C, $68
	dc.w $48, $704,	$413D, $10
	dc.w $50, $204,	$4145, 8
	dc.w $58, $104,	$4148, 0
	dc.w $58, $104,	$414A, $20
	dc.w $58, $104,	$414C, $38
	dc.w $60, $404,	$414E, $28
	dc.w $60, $404,	$4150, $40

word_16048:	dc.w $10
	dc.w 0,	$604, $4100, $38
	dc.w $10, $304,	$4106, $48
	dc.w $18, $304,	$410A, $40
	dc.w $20, $F04,	$410E, $18
	dc.w $20, $304,	$411E, $38
	dc.w $28, $104,	$4122, $10
	dc.w $30, 4, $4124, $48
	dc.w $38, $304,	$4125, $40
	dc.w $40, $E04,	$4129, $10
	dc.w $40, $604,	$4135, $30
	dc.w $48, $304,	$413B, $48
	dc.w $50, $204,	$413F, 8
	dc.w $58, $104,	$4142, 0
	dc.w $58, $904,	$4144, $10
	dc.w $58, $504,	$414A, $38
	dc.w $60, $404,	$414E, $28

word_160CA:	dc.w $D
	dc.w $18, $F04,	$4100, $30
	dc.w $20, $704,	$4110, $20
	dc.w $20, $204,	$4118, $50
	dc.w $28, $304,	$411B, $18
	dc.w $30, $104,	$411F, $10
	dc.w $38, $F04,	$4121, $30
	dc.w $40, $604,	$4131, $20
	dc.w $48, $704,	$4137, $10
	dc.w $50, $204,	$413F, 8
	dc.w $58, $104,	$4142, 0
	dc.w $58, $104,	$4144, $20
	dc.w $58, $904,	$4146, $38
	dc.w $60, $404,	$414C, $28

word_16134:	dc.w $10
	dc.w 8,	$204, $4100, $40
	dc.w $10, $304,	$4103, $38
	dc.w $18, $304,	$4107, $30
	dc.w $20, $F04,	$410B, 8
	dc.w $20, $304,	$411B, $28
	dc.w $28, $104,	$411F, 0
	dc.w $30, $304,	$4121, $38
	dc.w $38, $304,	$4125, $30
	dc.w $40, $E04,	$4129, 8
	dc.w $40, $204,	$4135, $28
	dc.w $40, $304,	$4138, $40
	dc.w $50, $204,	$413C, $38
	dc.w $50, $204,	$413F, $48
	dc.w $58, $D04,	$4142, 0
	dc.w $60, $804,	$414A, $20
	dc.w $60, 4, $414D, $40

word_161B6:	dc.w $11
	dc.w 0,	$704, $4100, $38
	dc.w 8,	$304, $4108, $30
	dc.w $18, $304,	$410C, $28
	dc.w $20, $B04,	$4110, $10
	dc.w $20, $304,	$411C, $38
	dc.w $28, $204,	$4120, 8
	dc.w $28, $304,	$4123, $30
	dc.w $30, $304,	$4127, $40
	dc.w $38, $304,	$412B, $28
	dc.w $40, $A04,	$412F, $10
	dc.w $40, $304,	$4138, $38
	dc.w $48, $304,	$413C, 8
	dc.w $48, $104,	$4140, $30
	dc.w $48, $304,	$4142, $48
	dc.w $50, $204,	$4146, $40
	dc.w $58, $504,	$4149, $10
	dc.w $60, $C04,	$414D, $20

word_16240:	dc.w $F
	dc.w 8,	$F04, $4100, $18
	dc.w $10, $304,	$4110, $38
	dc.w $18, $104,	$4114, $10
	dc.w $18, $304,	$4116, $40
	dc.w $28, $F04,	$411A, $18
	dc.w $30, $304,	$412A, $38
	dc.w $38, $304,	$412E, $10
	dc.w $38, $304,	$4132, $40
	dc.w $48, $304,	$4136, 8
	dc.w $48, $D04,	$413A, $18
	dc.w $48, $304,	$4142, $48
	dc.w $50, $204,	$4146, $38
	dc.w $58, $904,	$4149, $10
	dc.w $58, $104,	$414F, $40
	dc.w $60, $404,	$4151, $28

word_162BA:	dc.w $10
	dc.w $18, $F04,	$4100, $18
	dc.w $18, $304,	$4110, $38
	dc.w $20, $304,	$4114, $40
	dc.w $28, 4, $4118, $10
	dc.w $30, $304,	$4119, $48
	dc.w $38, $F04,	$411D, $18
	dc.w $38, $304,	$412D, $38
	dc.w $40, $304,	$4131, $10
	dc.w $40, $304,	$4135, $40
	dc.w $48, $304,	$4139, 8
	dc.w $50, $204,	$413D, $48
	dc.w $58, $104,	$4140, $18
	dc.w $58, $104,	$4142, $38
	dc.w $60, 4, $4144, $10
	dc.w $60, $804,	$4145, $20
	dc.w $60, 4, $4148, $40

word_1633C:	dc.w $10
	dc.w $18, $F04,	$4100, $18
	dc.w $18, $304,	$4110, $38
	dc.w $20, $204,	$4114, $10
	dc.w $20, $304,	$4117, $40
	dc.w $30, $304,	$411B, $48
	dc.w $38, $F04,	$411F, $18
	dc.w $38, $304,	$412F, $38
	dc.w $40, $304,	$4133, $10
	dc.w $40, $304,	$4137, $40
	dc.w $48, $304,	$413B, 8
	dc.w $50, $204,	$413F, $48
	dc.w $58, $104,	$4142, $18
	dc.w $58, $104,	$4144, $38
	dc.w $60, 4, $4146, $10
	dc.w $60, $804,	$4147, $20
	dc.w $60, 4, $414A, $40

word_163BE:	dc.w $D
	dc.w $20, $F04,	$4100, $20
	dc.w $20, $304,	$4110, $40
	dc.w $28, $304,	$4114, $18
	dc.w $30, $304,	$4118, $10
	dc.w $38, $304,	$411C, $48
	dc.w $40, $F04,	$4120, $20
	dc.w $40, $304,	$4130, $40
	dc.w $48, $304,	$4134, 8
	dc.w $48, $304,	$4138, $18
	dc.w $50, $204,	$413C, $10
	dc.w $58, $104,	$413F, $48
	dc.w $60, $C04,	$4141, $20
	dc.w $60, 4, $4145, $40

word_16428:	dc.w $D
	dc.w $10, $F04,	$4100, $18
	dc.w $10, $B04,	$4110, $38
	dc.w $18, $104,	$411C, $10
	dc.w $18, $104,	$411E, $50
	dc.w $30, $E04,	$4120, $18
	dc.w $30, $B04,	$412C, $38
	dc.w $38, $304,	$4138, $10
	dc.w $48, $404,	$413C, $18
	dc.w $48, 4, $413E, $30
	dc.w $50, $104,	$413F, 8
	dc.w $50, 4, $4141, $18
	dc.w $50, $804,	$4142, $38
	dc.w $58, 4, $4145, $10

word_16492:	dc.w $10
	dc.w 0,	$504, $4100, $40
	dc.w 8,	$E04, $4104, $18
	dc.w 8,	$304, $4110, $38
	dc.w $10, $304,	$4114, $40
	dc.w $18, $604,	$4118, 8
	dc.w $20, $B04,	$411E, $20
	dc.w $20, $304,	$412A, $48
	dc.w $28, $304,	$412E, $18
	dc.w $28, $304,	$4132, $38
	dc.w $30, $304,	$4136, $40
	dc.w $40, $204,	$413A, $10
	dc.w $40, $804,	$413D, $20
	dc.w $40, 4, $4140, $48
	dc.w $48, $404,	$4141, $18
	dc.w $48, $404,	$4143, $30
	dc.w $50, 4, $4145, $18

word_16514:	dc.w $F
	dc.w 0,	$704, $4100, $38
	dc.w 8,	$D04, $4108, 0
	dc.w 8,	$B04, $4110, $20
	dc.w $18, $404,	$411C, $10
	dc.w $20, $304,	$411E, $18
	dc.w $20, $704,	$4122, $38
	dc.w $28, $B04,	$412A, $20
	dc.w $28, $304,	$4136, $48
	dc.w $40, 4, $413A, $18
	dc.w $40, $504,	$413B, $38
	dc.w $40, $104,	$413F, $50
	dc.w $48, $804,	$4141, $20
	dc.w $48, $104,	$4144, $48
	dc.w $50, $404,	$4146, $28
	dc.w $50, 4, $4148, $40

word_1658E:	dc.w $11
	dc.w $18, $F04,	$4100, $18
	dc.w $18, $304,	$4110, $38
	dc.w $20, $304,	$4114, $10
	dc.w $20, $304,	$4118, $40
	dc.w $30, 4, $411C, 8
	dc.w $30, $104,	$411D, $48
	dc.w $38, $F04,	$411F, $18
	dc.w $38, $304,	$412F, $38
	dc.w $40, $304,	$4133, $10
	dc.w $40, $304,	$4137, $40
	dc.w $48, $304,	$413B, 8
	dc.w $58, $504,	$413F, $18
	dc.w $58, $104,	$4143, $38
	dc.w $58, $104,	$4145, $48
	dc.w $60, 4, $4147, $10
	dc.w $60, $404,	$4148, $28
	dc.w $60, 4, $414A, $40

word_16618:	dc.w $C
	dc.w $18, $704,	$4100, $28
	dc.w $20, $B04,	$4108, $10
	dc.w $20, $704,	$4114, $38
	dc.w $30, $104,	$411C, 8
	dc.w $38, $704,	$411E, $28
	dc.w $38, 4, $4126, $48
	dc.w $40, $B04,	$4127, $10
	dc.w $40, $704,	$4133, $38
	dc.w $48, $304,	$413B, 8
	dc.w $48, $304,	$413F, $48
	dc.w $60, $C04,	$4143, $10
	dc.w $60, $804,	$4147, $30

word_1667A:	dc.w $B
	dc.w $20, $F04,	$4100, $10
	dc.w $20, $704,	$4110, $30
	dc.w $28, $304,	$4118, $40
	dc.w $30, $304,	$411C, 8
	dc.w $38, 4, $4120, $48
	dc.w $40, $F04,	$4121, $10
	dc.w $40, $704,	$4131, $30
	dc.w $48, $704,	$4139, $40
	dc.w $50, $204,	$4141, 8
	dc.w $60, $C04,	$4144, $10
	dc.w $60, $404,	$4148, $30

; ---------------------------------------------------------------------------

off_166D4:
	dc.l word_166FC
	dc.l word_16706
	dc.l word_16710
	dc.l word_1671A
	dc.l word_1673C
	dc.l word_1674E
	dc.l word_16760
	dc.l word_167D2
	dc.l word_16814
	dc.l word_16876

word_166FC:	dc.w 1
	dc.w 0,	$402, $2510, 0

word_16706:	dc.w 1
	dc.w 0,	$402, $2512, 0

word_16710:	dc.w 1
	dc.w $FFFA, $501, $514,	$FFF8

word_1671A:	dc.w 4
	dc.w 0,	$502, $518, 0
	dc.w 0,	$502, $D18, $10
	dc.w $10, $502,	$1518, 0
	dc.w $10, $502,	$1D18, $10

word_1673C:	dc.w 2
	dc.w $FFF9, $501, $51C,	$FFF8
	dc.w $FFFE, $503, $6520, $FFFD

word_1674E:	dc.w 2
	dc.w $FFF9, $501, $D1C,	$FFF8
	dc.w $FFFE, $503, $6D20, $FFFD

word_16760:	dc.w $E
	dc.w 0,	$501, $2548, 0
	dc.w 0,	$501, $2528, $10
	dc.w 0,	$501, $253C, $20
	dc.w 0,	$501, $254C, $30
	dc.w 0,	$501, $2524, $40
	dc.w 0,	$501, $252C, $50
	dc.w 0,	$501, $2550, $60
	dc.w 5,	$503, $6578, 5
	dc.w 5,	$503, $6558, $15
	dc.w 5,	$503, $656C, $25
	dc.w 5,	$503, $657C, $35
	dc.w 5,	$503, $6554, $45
	dc.w 5,	$503, $655C, $55
	dc.w 5,	$503, $6580, $65

word_167D2:	dc.w 8
	dc.w 0,	$501, $2548, 0
	dc.w 0,	$501, $2528, $10
	dc.w 0,	$501, $253C, $20
	dc.w 0,	$501, $254C, $30
	dc.w 5,	$503, $6578, 5
	dc.w 5,	$503, $6558, $15
	dc.w 5,	$503, $656C, $25
	dc.w 5,	$503, $657C, $35

word_16814:	dc.w $C
	dc.w 0,	$501, $2534, 0
	dc.w 0,	$501, $2538, $10
	dc.w 0,	$501, $253C, $20
	dc.w 0,	$501, $2540, $30
	dc.w 0,	$501, $2528, $40
	dc.w 0,	$501, $2544, $50
	dc.w 5,	$503, $6564, 5
	dc.w 5,	$503, $6568, $15
	dc.w 5,	$503, $656C, $25
	dc.w 5,	$503, $6570, $35
	dc.w 5,	$503, $6558, $45
	dc.w 5,	$503, $6574, $55

word_16876:	dc.w 8
	dc.w 0,	$501, $2524, 0
	dc.w 0,	$501, $2528, $10
	dc.w 0,	$501, $252C, $20
	dc.w 0,	$501, $2530, $30
	dc.w 5,	$503, $6554, 5
	dc.w 5,	$503, $6558, $15
	dc.w 5,	$503, $655C, $25
	dc.w 5,	$503, $6560, $35

; ---------------------------------------------------------------------------

off_176D8:
	dc.l word_176F8
	dc.l word_17702
	dc.l word_1770C
	dc.l word_17716
	dc.l word_17720
	dc.l word_1772A
	dc.l word_17734
	dc.l word_1773E

word_176F8:	dc.w 1
	dc.w 0,	$102, $E0F0, 0

word_17702:	dc.w 1
	dc.w 0,	$102, $E0F2, 0

word_1770C:	dc.w 1
	dc.w 0,	$102, $E0F4, 0

word_17716:	dc.w 1
	dc.w 0,	$102, $E0F6, 0

word_17720:	dc.w 1
	dc.w 0,	$100, $C0F0, 0

word_1772A:	dc.w 1
	dc.w 0,	$100, $C0F2, 0

word_17734:	dc.w 1
	dc.w 0,	$100, $C0F4, 0

word_1773E:	dc.w 1
	dc.w 0,	$100, $C0F6, 0

; ---------------------------------------------------------------------------

off_17AFE:
	dc.l word_17B32
	dc.l word_17B3C
	dc.l word_17B46
	dc.l word_17B50
	dc.l word_17B5A
	dc.l word_17B64
	dc.l word_17B76
	dc.l word_17B80
	dc.l word_17B92
	dc.l word_17B9C
	dc.l word_17BA6
	dc.l word_17BB0
	dc.l word_17BBA

word_17B32:	dc.w 1
	dc.w 0,	$802, $E4DE, 0

word_17B3C:	dc.w 1
	dc.w 0,	$802, $E4E1, 0

word_17B46:	dc.w 1
	dc.w 0,	$102, $E4E4, 0

word_17B50:	dc.w 1
	dc.w 0,	$102, $E4E6, 0

word_17B5A:	dc.w 1
	dc.w 0,	$102, $E4E8, 0

word_17B64:	dc.w 2
	dc.w 0,	$802, $E4EA, 0
	dc.w 8,	$402, $E4ED, 8

word_17B76:	dc.w 1
	dc.w 0,	$902, $E4EF, 0

word_17B80:	dc.w 2
	dc.w 0,	$502, $E4F5, 8
	dc.w 8,	2, $E4F9, 0

word_17B92:	dc.w 1
	dc.w 0,	$802, $C3DE, 0

word_17B9C:	dc.w 1
	dc.w 0,	$802, $C3E1, 0

word_17BA6:	dc.w 1
	dc.w 0,	$102, $C3E4, 0

word_17BB0:	dc.w 1
	dc.w 0,	$102, $C3E6, 0

word_17BBA:	dc.w 1
	dc.w 0,	$102, $C3E8, 0

; ---------------------------------------------------------------------------

off_1801E:
	dc.l word_1802A
	dc.l word_18034
	dc.l word_1803E

word_1802A:	dc.w 1
	dc.w 0,	$E02, $E4D7, 0

word_18034:	dc.w 1
	dc.w 0,	$E02, $E4E3, 0

word_1803E:	dc.w 1
	dc.w 0,	$E02, $E4EF, 0

; ---------------------------------------------------------------------------

off_19084:
	dc.l word_190CC
	dc.l word_190D6
	dc.l word_190E0
	dc.l word_190EA
	dc.l word_190F4
	dc.l word_190FE
	dc.l word_19108
	dc.l word_19112
	dc.l word_1911C
	dc.l word_19126
	dc.l word_19178
	dc.l word_19182
	dc.l word_1918C
	dc.l word_19196
	dc.l word_191A0
	dc.l word_191AA
	dc.l word_191B4
	dc.l word_191C6

word_190CC:	dc.w 1
	dc.w $FFF8, $502, $E330, $FFF8

word_190D6:	dc.w 1
	dc.w $FFF8, $502, $E38A, $FFF8

word_190E0:	dc.w 1
	dc.w $FFF8, $502, $E38E, $FFF8

word_190EA:	dc.w 1
	dc.w $FFF8, $502, $E392, $FFF8

word_190F4:	dc.w 1
	dc.w $FFF8, $502, $E396, $FFF8

word_190FE:	dc.w 1
	dc.w $FFF8, $502, $E340, $FFF8

word_19108:	dc.w 1
	dc.w $FFF8, $502, $E3A6, $FFF8

word_19112:	dc.w 1
	dc.w $FFF8, $502, $E3AA, $FFF8

word_1911C:	dc.w 1
	dc.w $FFF8, $502, $EBA6, $FFF8

word_19126:	dc.w $A
	dc.w 0,	$C00, $E014, 0
	dc.w 0,	$C00, $E814, $30
	dc.w $30, $C00,	$F014, 0
	dc.w $30, $C00,	$F814, $30
	dc.w 8,	$200, $E018, 0
	dc.w 8,	$200, $E818, $48
	dc.w $20, $100,	$E818, $48
	dc.w $20, $100,	$E018, 0
	dc.w $30, $400,	$F015, $20
	dc.w 0,	$400, $E015, $20

word_19178:	dc.w 1
	dc.w 2,	$403, $C020, $A

word_19182:	dc.w 1
	dc.w 1,	$403, $C022, 9

word_1918C:	dc.w 1
	dc.w 1,	$803, $C024, 6

word_19196:	dc.w 1
	dc.w 1,	$803, $C027, 5

word_191A0:	dc.w 1
	dc.w 1,	$803, $C02A, 4

word_191AA:	dc.w 1
	dc.w 1,	$C03, $C02D, 3

word_191B4:	dc.w 2
	dc.w 0,	$C03, $C031, 2
	dc.w 8,	$803, $C035, 2

word_191C6:	dc.w 1
	dc.w 0,	$D03, $C038, 0

; ---------------------------------------------------------------------------

off_191D0:
	dc.l word_19240
	dc.l word_1924A
	dc.l word_19254
	dc.l word_1925E
	dc.l word_19268
	dc.l word_19272
	dc.l word_1927C
	dc.l word_1928E
	dc.l word_19298
	dc.l word_192A2
	dc.l word_192B4
	dc.l word_192BE
	dc.l word_192C8
	dc.l word_192D2
	dc.l word_192DC
	dc.l word_192E6
	dc.l word_192F0
	dc.l word_192FA
	dc.l word_19304
	dc.l word_1930E
	dc.l word_19318
	dc.l word_19322
	dc.l word_1932C
	dc.l word_19336
	dc.l word_19340
	dc.l word_1934A
	dc.l word_19354
	dc.l word_1935E

word_19240:	dc.w 1
	dc.w 1,	$F03, $C400, 0

word_1924A:	dc.w 1
	dc.w 1,	$F03, $C410, 0

word_19254:	dc.w 1
	dc.w 1,	$B03, $C420, 4

word_1925E:	dc.w 1
	dc.w 0,	$B03, $C42C, 5

word_19268:	dc.w 1
	dc.w $48, $F03,	$C438, 0

word_19272:	dc.w 1
	dc.w $50, $E03,	$C448, 0

word_1927C:	dc.w 2
	dc.w $20, $F03,	$C454, 0
	dc.w $40, $403,	$C464, $A

word_1928E:	dc.w 1
	dc.w $10, $F03,	$C466, 0

word_19298:	dc.w 1
	dc.w 4,	$F03, $C476, 0

word_192A2:	dc.w 2
	dc.w $23, $B03,	$C486, 3
	dc.w $43, $403,	$C492, 8

word_192B4:	dc.w 1
	dc.w $20, $F03,	$E494, 0

word_192BE:	dc.w 1
	dc.w $20, $F03,	$E4A4, 0

word_192C8:	dc.w 1
	dc.w $C, $B03, $E4B4, 6

word_192D2:	dc.w 1
	dc.w 2,	$E03, $E4C0, 0

word_192DC:	dc.w 1
	dc.w $D, $F03, $E4CC, 0

word_192E6:	dc.w 1
	dc.w $1F, $F03,	$C4DC, 0

word_192F0:	dc.w 1
	dc.w $27, $E03,	$C4EC, 0

word_192FA:	dc.w 1
	dc.w $C, $B03, $C4F8, 2

word_19304:	dc.w 1
	dc.w $D, $A03, $C504, 3

word_1930E:	dc.w 1
	dc.w 0,	$A03, $C50D, 2

word_19318:	dc.w 1
	dc.w 7,	$E03, $C516, 0

word_19322:	dc.w 1
	dc.w $D, $E03, $C522, 0

word_1932C:	dc.w 1
	dc.w $C, 4, $E52E, $C

word_19336:	dc.w 1
	dc.w 4,	$E04, $E52F, 4

word_19340:	dc.w 1
	dc.w 0,	$F04, $E53B, 0

word_1934A:	dc.w 1
	dc.w 0,	$F04, $E54B, 0

word_19354:	dc.w 1
	dc.w 0,	$F04, $855B, 0

word_1935E:	dc.w 1
	dc.w 0,	$F04, $856B, 0

; ---------------------------------------------------------------------------

off_19368:
	dc.l word_193B8
	dc.l word_193D2
	dc.l word_193EC
	dc.l word_1940E
	dc.l word_19430
	dc.l word_19452
	dc.l word_19474
	dc.l word_1948E
	dc.l word_194A8
	dc.l word_194C2
	dc.l word_194DC
	dc.l word_194F6
	dc.l word_19510
	dc.l word_1952A
	dc.l word_1954C
	dc.l word_1956E
	dc.l word_19590
	dc.l word_195B2
	dc.l word_195CC
	dc.l word_195E6

word_193B8:	dc.w 3
	dc.w 0,	$F01, $8131, 0
	dc.w 0,	$F01, $8141, $20
	dc.w 0,	$F01, $8151, $40

word_193D2:	dc.w 3
	dc.w 0,	$F01, $8161, 0
	dc.w 0,	$F01, $8141, $20
	dc.w 0,	$F01, $8151, $40

word_193EC:	dc.w 4
	dc.w 8,	$501, $8171, 0
	dc.w 0,	$701, $8175, $10
	dc.w 0,	$F01, $8141, $20
	dc.w 0,	$F01, $8151, $40

word_1940E:	dc.w 4
	dc.w 8,	$901, $817D, 0
	dc.w 0,	$301, $8183, $18
	dc.w 0,	$F01, $8187, $20
	dc.w 0,	$F01, $8151, $40

word_19430:	dc.w 4
	dc.w 8,	$D01, $8197, 0
	dc.w 0,	$D01, $819F, $20
	dc.w $10, $D01,	$81A7, $20
	dc.w 0,	$F01, $8151, $40

word_19452:	dc.w 4
	dc.w 8,	$D01, $81AF, 0
	dc.w 0,	$701, $81B7, $20
	dc.w 0,	$701, $81BF, $30
	dc.w 0,	$F01, $81C7, $40

word_19474:	dc.w 3
	dc.w 8,	$501, $81D7, $10
	dc.w 8,	$D01, $81DB, $20
	dc.w 0,	$F01, $81E3, $40

word_1948E:	dc.w 3
	dc.w 8,	$D01, $81F3, 0
	dc.w 8,	$D01, $81FB, $20
	dc.w 0,	$F01, $8203, $40

word_194A8:	dc.w 3
	dc.w 8,	$901, $8213, 0
	dc.w 8,	$901, $8219, $28
	dc.w 8,	$D01, $821F, $40

word_194C2:	dc.w 3
	dc.w 8,	$D01, $8227, 0
	dc.w 8,	$D01, $822F, $20
	dc.w 8,	$D01, $8237, $40

word_194DC:	dc.w 3
	dc.w 8,	$D01, $823F, 0
	dc.w 8,	$501, $8247, $20
	dc.w 8,	$D01, $824B, $40

word_194F6:	dc.w 3
	dc.w 0,	$F01, $8253, 0
	dc.w 8,	$D01, $8263, $20
	dc.w 8,	$D01, $826B, $40

word_19510:	dc.w 3
	dc.w 0,	$F01, $8273, 0
	dc.w 8,	$D01, $8283, $20
	dc.w 8,	$101, $828B, $40

word_1952A:	dc.w 4
	dc.w 0,	$F01, $828D, 0
	dc.w 0,	$701, $829D, $20
	dc.w 8,	$501, $91FF, $30
	dc.w 8,	$D01, $82A5, $40

word_1954C:	dc.w 4
	dc.w 0,	$F01, $9131, 0
	dc.w 0,	$701, $82AD, $20
	dc.w 8,	$501, $91DF, $30
	dc.w 8,	$D01, $82B5, $40

word_1956E:	dc.w 4
	dc.w 0,	$F01, $9131, 0
	dc.w 0,	$F01, $82BD, $20
	dc.w 0,	$301, $82CD, $40
	dc.w 8,	$901, $9239, $48

word_19590:	dc.w 4
	dc.w 0,	$F01, $9131, 0
	dc.w 0,	$F01, $9141, $20
	dc.w 0,	$301, $82D1, $40
	dc.w 8,	$901, $9221, $48

word_195B2:	dc.w 3
	dc.w 0,	$F01, $9131, 0
	dc.w 0,	$F01, $9141, $20
	dc.w 0,	$F01, $82D5, $40

word_195CC:	dc.w 3
	dc.w 0,	$F01, $9131, 0
	dc.w 0,	$F01, $9141, $20
	dc.w 0,	$F01, $9151, $40

word_195E6:	dc.w 5
	dc.w 0,	$F01, $8100, 0
	dc.w 0,	$F01, $8110, $20
	dc.w 0,	$F01, $8120, $40
	dc.w $18, 1, $8130, $60
	dc.w 0,	$400, $82E5, $5C

; ---------------------------------------------------------------------------

off_19610:
	dc.l word_197AC
	dc.l word_197B6
	dc.l word_197C8
	dc.l word_197DA
	dc.l word_197EC
	dc.l word_197FE
	dc.l word_19808
	dc.l word_19812
	dc.l word_19826
	dc.l word_19826
	dc.l word_19830
	dc.l word_1983A
	dc.l word_19844
	dc.l word_1984E
	dc.l word_19858
	dc.l word_19862
	dc.l word_1986C
	dc.l word_19876
	dc.l word_19880
	dc.l word_1988A
	dc.l word_19894
	dc.l word_1989E
	dc.l word_198A8
	dc.l word_198B2
	dc.l word_198BC
	dc.l word_198C6
	dc.l word_198F0
	dc.l word_1991A
	dc.l word_19944
	dc.l word_1994E
	dc.l word_19958
	dc.l word_19962
	dc.l word_1996C
	dc.l word_19976
	dc.l word_19980
	dc.l word_1998A
	dc.l word_19994
	dc.l word_1999E
	dc.l word_199A8
	dc.l word_199B2
	dc.l word_199BC
	dc.l word_199CE
	dc.l word_199E0
	dc.l word_199F2
	dc.l word_19A04
	dc.l word_19A16
	dc.l word_19A28
	dc.l word_19A32
	dc.l word_19A3C
	dc.l word_19A46
	dc.l word_19A50
	dc.l word_19A5A
	dc.l word_19A64
	dc.l word_19A6E
	dc.l word_19A78
	dc.l word_19A8A
	dc.l word_19A9C
	dc.l word_19AAE
	dc.l word_19ACA
	dc.l word_19AD4
	dc.l word_19ADE
	dc.l word_19AE8
	dc.l word_19AF2
	dc.l word_19B04
	dc.l word_19B16
	dc.l word_19B28
	dc.l word_19B3A
	dc.l word_19AC0
	dc.l word_19B44
	dc.l word_19B56
	dc.l word_19B68
	dc.l word_19B7A
	dc.l word_19B8C
	dc.l word_19B9E
	dc.l word_19BA8
	dc.l word_19BB2
	dc.l word_19BBC
	dc.l word_19BC6
	dc.l word_19BD0
	dc.l word_19C2A
	dc.l word_19C34
	dc.l word_19C3E
	dc.l word_19C48
	dc.l word_19BDA
	dc.l word_19BE4
	dc.l word_19BEE
	dc.l word_19BF8
	dc.l word_19C02
	dc.l word_19C0C
	dc.l word_19C16
	dc.l word_19C20
	dc.l word_19C52
	dc.l word_19C5C
	dc.l word_19C66
	dc.l word_19C70
	dc.l word_19C7A
	dc.l word_19C84
	dc.l word_19C8E
	dc.l word_19C98
	dc.l word_19CA2
	dc.l word_19CAC
	dc.l word_19CB6
	dc.l word_19CC8

word_197AC:	dc.w 2		; Calls 2 Sprite pieces, but only one is listed
	dc.w 0,	3, $3FF, 0

word_197B6:	dc.w 2
	dc.w $FFE0, $A03, $637B, $FFF8
	dc.w $FFF8, $403, $6384, $FFF8

word_197C8:	dc.w 2
	dc.w $FFE0, $A03, $6386, $FFF8
	dc.w $FFF8, $403, $638F, $FFF8

word_197DA:	dc.w 2
	dc.w $FFE0, $A03, $391,	$FFF8
	dc.w $FFF8, $403, $39A,	$FFF8

word_197EC:	dc.w 2
	dc.w $FFE0, $A03, $370,	$FFF8
	dc.w $FFF8, $403, $379,	$FFF8

word_197FE:	dc.w 1
	dc.w $FFFC, 3, $239D, $FFFC

word_19808:	dc.w 1
	dc.w $FFFC, 3, $639E, $FFFC

word_19812:	dc.w 1
	dc.w $FFFC, 3, $639C, $FFFC

word_19826:	dc.w 1
	dc.w $FFFC, 3, $1FF, $FFFC

word_19830:	dc.w 1
	dc.w $FFFC, $F03, $1FB,	$FFF0

word_1983A:	dc.w 1
	dc.w 0,	$F03, $1FB, 0

word_19844:	dc.w 1
	dc.w 0,	$F03, $1FB, 0

word_1984E:	dc.w 1
	dc.w 0,	$F03, $1FB, 0

word_19858:	dc.w 1
	dc.w 0,	$F03, $1FB, 0

word_19862:	dc.w 1
	dc.w 0,	$F03, $1FB, 0

word_1986C:	dc.w 1
	dc.w $FFE0, $303, $3E5,	0

word_19876:	dc.w 1
	dc.w $FFE0, $303, $3E9,	0

word_19880:	dc.w 1
	dc.w $FFE0, $303, $3ED,	0

word_1988A:	dc.w 1
	dc.w $FFE0, $303, $3F1,	0

word_19894:	dc.w 1
	dc.w $FFE0, $303, $3F5,	0

word_1989E:	dc.w 1
	dc.w 0,	$F03, $1FB, 0

word_198A8:	dc.w 1
	dc.w 0,	3, $39F, 0

word_198B2:	dc.w 1
	dc.w 0,	3, $3A0, 1

word_198BC:	dc.w 1
	dc.w 1,	3, $3A1, 5

word_198C6:	dc.w 5
	dc.w 0,	$503, $63A2, 0
	dc.w 8,	$703, $63A6, $10
	dc.w $10, $303,	$63AE, 8
	dc.w $20, $903,	$63B2, $FFF0
	dc.w $30, $803,	$63B8, $FFF8

word_198F0:	dc.w 5
	dc.w 0,	$503, $63BB, 0
	dc.w 8,	$703, $63BF, $10
	dc.w $10, $303,	$63AE, 8
	dc.w $20, $903,	$63C7, $FFF0
	dc.w $30, $803,	$63CD, $FFF8

word_1991A:	dc.w 5
	dc.w 0,	$503, $63D0, 0
	dc.w 8,	$703, $63D4, $10
	dc.w $10, $303,	$63AE, 8
	dc.w $20, $903,	$63DC, $FFF0
	dc.w $30, $803,	$63E2, $FFF8

word_19944:	dc.w 1
	dc.w $FFFC, $403, $3F9,	$FFF0

word_1994E:	dc.w 1
	dc.w $FFF8, $903, $3FB,	$FFE8

word_19958:	dc.w 1
	dc.w $FFF4, $E03, $401,	$FFDC

word_19962:	dc.w 1
	dc.w $FFF4, $E03, $419,	$FFDC

word_1996C:	dc.w 1
	dc.w $FFF4, $E03, $40D,	$FFDC

word_19976:	dc.w 1
	dc.w $FFF4, $A03, $425,	$FFDC

word_19980:	dc.w 1
	dc.w $FFE0, $B03, $644C, $FFF4

word_1998A:	dc.w 1
	dc.w $FFE0, $B03, $6458, $FFF4

word_19994:	dc.w 1
	dc.w $FFE0, $B03, $6464, $FFF4

word_1999E:	dc.w 1
	dc.w $FFE0, $B03, $2470, $FFF4

word_199A8:	dc.w 1
	dc.w $FFE0, $B03, $247C, $FFF4

word_199B2:	dc.w 1
	dc.w $FFE0, $B03, $2488, $FFF4

word_199BC:	dc.w 2
	dc.w $FFF0, $903, $446,	$FFF4
	dc.w $FFE0, $903, $42E,	$FFF4

word_199CE:	dc.w 2
	dc.w $FFF0, $903, $446,	$FFF4
	dc.w $FFE0, $903, $434,	$FFF4

word_199E0:	dc.w 2
	dc.w $FFF0, $903, $446,	$FFF4
	dc.w $FFE0, $903, $43A,	$FFF4

word_199F2:	dc.w 2
	dc.w $FFF0, $903, $446,	$FFF4
	dc.w $FFE1, $903, $42E,	$FFF4

word_19A04:	dc.w 2
	dc.w $FFF0, $903, $446,	$FFF4
	dc.w $FFE1, $903, $434,	$FFF4

word_19A16:	dc.w 2
	dc.w $FFF0, $903, $446,	$FFF4
	dc.w $FFE1, $903, $43A,	$FFF4

word_19A28:	dc.w 1
	dc.w $FFFC, 3, $2495, $FFFC

word_19A32:	dc.w 1
	dc.w $FFFC, 3, $2494, $FFFC

word_19A3C:	dc.w 1
	dc.w $FFFC, 3, $2C95, $FFFC

word_19A46:	dc.w 1
	dc.w $FFFC, 3, $2C94, $FFFC

word_19A50:	dc.w 1
	dc.w $FFFC, 3, $3495, $FFFC

word_19A5A:	dc.w 1
	dc.w $FFFC, 3, $3494, $FFFC

word_19A64:	dc.w 1
	dc.w $FFFC, 3, $3C95, $FFFC

word_19A6E:	dc.w 1
	dc.w $FFFC, 3, $3C94, $FFFC

word_19A78:	dc.w 2
	dc.w $FFD0, $603, $2496, 8
	dc.w $FFE8, $A03, $249C, $FFF8

word_19A8A:	dc.w 2
	dc.w $FFC8, $A03, $24A5, $FFF8
	dc.w $FFE0, $B03, $24AE, $FFF8

word_19A9C:	dc.w 2
	dc.w $FFD0, $603, $2C96, $FFF0
	dc.w $FFE8, $A03, $2C9C, $FFF8

word_19AAE:	dc.w 2
	dc.w $FFE0, $F03, $A2E9, $FFEC
	dc.w $FFF0, $103, $A2F9, $C

word_19AC0:	dc.w 1
	dc.w $FFE0, $F03, $A2E9, $FFEC

word_19ACA:	dc.w 1
	dc.w $FFF8, $502, $E383, $FFF8

word_19AD4:	dc.w 1
	dc.w $FFF8, $502, $E387, $FFF8

word_19ADE:	dc.w 1
	dc.w $FFF8, $502, $E38B, $FFF8

word_19AE8:	dc.w 1
	dc.w $FFF8, $502, $E38F, $FFF8

word_19AF2:	dc.w 2
	dc.w $FFF8, $502, $8383, $FFF8
	dc.w 0,	$402, $C393, $FFF6

word_19B04:	dc.w 2
	dc.w $FFF8, $502, $8387, $FFF8
	dc.w 0,	$402, $C395, $FFF6

word_19B16:	dc.w 2
	dc.w $FFF8, $502, $838B, $FFF8
	dc.w 0,	$402, $C397, $FFF6

word_19B28:	dc.w 2
	dc.w $FFF8, $502, $838F, $FFF8
	dc.w 0,	$402, $C393, $FFF6

word_19B3A:	dc.w 1
	dc.w 0,	$402, $C30F, $FFF6

word_19B44:	dc.w 2
	dc.w $FFD8, $303, $24E0, $FFFC
	dc.w $FFF8, 3, $24E4, $FFFC

word_19B56:	dc.w 2
	dc.w $FFD8, $303, $24E5, $FFFC
	dc.w $FFF8, 3, $24E4, $FFFC

word_19B68:	dc.w 2
	dc.w $FFD8, $303, $24E9, $FFFC
	dc.w $FFF8, 3, $24ED, $FFFC

word_19B7A:	dc.w 2
	dc.w $FFD8, $303, $24EE, $FFFC
	dc.w $FFF8, 3, $24F2, $FFFC

word_19B8C:	dc.w 2
	dc.w $FFD8, $303, $24F3, $FFFC
	dc.w $FFF8, 3, $24F2, $FFFC

word_19B9E:	dc.w 1
	dc.w $FFFC, 3, $4097, $FFFC

word_19BA8:	dc.w 1
	dc.w $FFFC, 3, $4098, $FFFC

word_19BB2:	dc.w 1
	dc.w $FFFC, 3, $4099, $FFFC

word_19BBC:	dc.w 1
	dc.w $FFFC, 3, $409A, $FFFC

word_19BC6:	dc.w 1
	dc.w $FFFC, 3, $409B, $FFFC

word_19BD0:	dc.w 1
	dc.w $FFFC, 3, $409C, $FFFC

word_19BDA:	dc.w 1
	dc.w $FFFC, 3, $409D, $FFFC

word_19BE4:	dc.w 1
	dc.w $FFFC, 3, $409E, $FFFC

word_19BEE:	dc.w 1
	dc.w $FFFC, 3, $409F, $FFFC

word_19BF8:	dc.w 1
	dc.w $FFFC, 3, $40A0, $FFFC

word_19C02:	dc.w 1
	dc.w $FFFC, 3, $40A1, $FFFC

word_19C0C:	dc.w 1
	dc.w $FFFC, 3, $40A2, $FFFC

word_19C16:	dc.w 1
	dc.w $FFFC, 3, $40A3, $FFFC

word_19C20:	dc.w 1
	dc.w $FFFC, 3, $40A4, $FFFC

word_19C2A:	dc.w 1
	dc.w $FFFC, 2, $A080, $FFFC

word_19C34:	dc.w 1
	dc.w $FFF8, $502, $A081, $FFF8

word_19C3E:	dc.w 1
	dc.w $FFF8, $502, $A085, $FFF8

word_19C48:	dc.w 1
	dc.w $FFF8, $502, $A089, $FFF8

word_19C52:	dc.w 1
	dc.w $FFF8, $502, $E3AE, $FFF8

word_19C5C:	dc.w 1
	dc.w $FFF8, $902, $E3B2, $FFF0

word_19C66:	dc.w 1
	dc.w $FFF8, $902, $E3B8, $FFF0

word_19C70:	dc.w 1
	dc.w $FFF8, $502, $E3BE, $FFF8

word_19C7A:	dc.w 1
	dc.w $FFF8, $502, $E338, $FFF8

word_19C84:	dc.w 1
	dc.w $FFF8, $A02, $E3C2, $FFF8

word_19C8E:	dc.w 1
	dc.w $FFF8, $A02, $E3CB, $FFF8

word_19C98:	dc.w 1
	dc.w $FFF8, $500, $E396, $FFF8

word_19CA2:	dc.w 1
	dc.w $FFF8, $500, $E39A, $FFF8

word_19CAC:	dc.w 1
	dc.w $FFF8, $500, $E39E, $FFF8

word_19CB6:	dc.w 2
	dc.w $FFF0, $100, $E3A2, $FFF0
	dc.w $FFF8, $500, $E39A, $FFF8

word_19CC8:	dc.w 2
	dc.w $FFF0, $100, $E3A4, $FFF0
	dc.w $FFF8, $500, $E39A, $FFF8


; ---------------------------------------------------------------------------

off_14814:	; what the <quack> is this?
	dc.l byte_FF1446
	dc.l byte_FF14E8
	dc.l byte_FF158A
	dc.l byte_FF162C
	dc.l byte_FF16CE
	dc.l byte_FF1770
	dc.l byte_FF1812
	dc.l byte_FF18B4

; ---------------------------------------------------------------------------

Unreferenced_Unk_Mapping:	; figure out what this originally was?
	dc.l word_14BB4
	dc.l word_14BB4
	dc.l word_14BB4
	dc.l word_14BB4
	dc.l word_14BB4
	dc.l word_14BD6
	dc.l word_14BF8
	dc.l word_14BF8
	dc.l word_14BF8
	dc.l word_14BF8
	dc.l word_14BF8
	dc.l word_14BF8
	dc.l word_14BF8
	dc.l word_14BF8
	dc.l word_14BF8
	dc.l word_14BF8
	dc.l word_14BF8
	dc.l word_14BF8
	dc.l word_14BF8
	dc.l word_14C22
	dc.l word_14C44
	dc.l word_14C44
	dc.l word_14C44
	dc.l word_14C44
	dc.l word_14C44
	dc.l word_14C66
	dc.l word_14C70
	dc.l word_14C7A
	dc.l word_14C84
	dc.l word_14C96
	dc.l word_14CA8
	dc.l word_14CC2
	dc.l word_14CDC
	dc.l word_14CF6
	dc.l word_14D10
	dc.l word_14D22
	dc.l word_14D3C
	dc.l word_14D4E
	dc.l word_14D68
	dc.l word_14D82
	dc.l word_14D9C
	dc.l word_14DB6
	dc.l word_14DD0
	dc.l word_14DDA
	dc.l word_14DE4
	dc.l word_14DEE

word_14BB4:	dc.w 4
	dc.w $FFC8, $F02, $8300, $FFE8
	dc.w $FFC8, $302, $8310, 8
	dc.w $FFE8, $E02, $8314, $FFE8
	dc.w $FFE8, $202, $8320, 8

word_14BD6:	dc.w 4
	dc.w $FFC8, $B02, $8323, $FFD8
	dc.w $FFC8, $B02, $832F, $FFF0
	dc.w $FFE8, 2, $833B, $FFE8
	dc.w $FFE8, $E02, $833C, $FFF0

word_14BF8:	dc.w 5
	dc.w $FFC8, $E02, $83A6, $FFE0
	dc.w $FFC8, $202, $83B2, 0
	dc.w $FFE0, $202, $83B5, $FFE0
	dc.w $FFF8, $802, $83C4, $FFE0
	dc.w $FFF0, $902, $83C7, $FFF8

word_14C22:	dc.w 4
	dc.w $FFC8, $F02, $836B, $FFE0
	dc.w $FFC8, $702, $837B, 0
	dc.w $FFE8, $E02, $8383, $FFE0
	dc.w $FFE8, $602, $838F, 0

word_14C44:	dc.w 4
	dc.w $FFC8, $F02, $8348, $FFE8
	dc.w $FFC8, $702, $8358, 8
	dc.w $FFE8, $D02, $8360, $FFF0
	dc.w $FFF8, $802, $8368, $FFF0

word_14C66:	dc.w 1
	dc.w $FFD8, $101, $8397, 0

word_14C70:	dc.w 1
	dc.w $FFD8, $401, $8399, $FFF8

word_14C7A:	dc.w 1
	dc.w $FFD8, $401, $839B, $FFF8

word_14C84:	dc.w 2
	dc.w $FFD8, $100, $8395, 0
	dc.w $FFD8, 1, $839B, $FFF8

word_14C96:	dc.w 2
	dc.w $FFE0, $602, $83B8, $FFE8
	dc.w $FFE0, $902, $83BE, $FFF8

word_14CA8:	dc.w 3
	dc.w $FFE0, 1, $83F2, $FFF8
	dc.w $FFE0, $602, $83B8, $FFE8
	dc.w $FFE0, $902, $83BE, $FFF8

word_14CC2:	dc.w 3
	dc.w $FFD8, $401, $83E3, $FFF0
	dc.w $FFE0, $602, $83B8, $FFE8
	dc.w $FFE0, $902, $83BE, $FFF8

word_14CDC:	dc.w 3
	dc.w $FFD8, $901, $83D7, $FFF0
	dc.w $FFE0, $602, $83B8, $FFE8
	dc.w $FFE0, $902, $83BE, $FFF8

word_14CF6:	dc.w 3
	dc.w $FFD8, $901, $83DD, $FFF0
	dc.w $FFE0, $602, $83B8, $FFE8
	dc.w $FFE0, $902, $83BE, $FFF8

word_14D10:	dc.w 2
	dc.w $FFE0, $602, $83B8, $FFE8
	dc.w $FFE0, $902, $83EB, $FFF8

word_14D22:	dc.w 3
	dc.w $FFE0, $602, $83B8, $FFE8
	dc.w $FFE0, $902, $83EB, $FFF8
	dc.w $FFE0, 1, $83F1, $FFF8

word_14D3C:	dc.w 2
	dc.w $FFE0, $602, $83B8, $FFE8
	dc.w $FFE0, $902, $83E5, $FFF8

word_14D4E:	dc.w 3
	dc.w $FFE0, $602, $83B8, $FFE8
	dc.w $FFE0, $902, $83E5, $FFF8
	dc.w $FFE0, 1, $83F1, $FFF8

word_14D68:	dc.w 3
	dc.w $FFE0, $602, $83B8, $FFE8
	dc.w $FFE0, $902, $83EB, $FFF8
	dc.w $FFD8, $401, $83E3, $FFF0

word_14D82:	dc.w 3
	dc.w $FFE0, $602, $83B8, $FFE8
	dc.w $FFE0, $902, $83E5, $FFF8
	dc.w $FFD8, $401, $83E3, $FFF0

word_14D9C:	dc.w 3
	dc.w $FFE0, $602, $83B8, $FFE8
	dc.w $FFE0, $902, $83EB, $FFF8
	dc.w $FFD8, $501, $83CD, $FFF0

word_14DB6:	dc.w 3
	dc.w $FFE0, $602, $83D1, $FFE8
	dc.w $FFE0, $902, $83EB, $FFF8
	dc.w $FFD8, $501, $83CD, $FFF0

word_14DD0:	dc.w 1
	dc.w $FFD8, $101, $83A3, 0

word_14DDA:	dc.w 1
	dc.w $FFD8, $801, $83A0, $FFF8

word_14DE4:	dc.w 1
	dc.w $FFD8, $801, $839D, $FFF8

word_14DEE:	dc.w 2
	dc.w $FFD8, $101, $83A3, 0
	dc.w $FFD8, 0, $83A5, 0

; ---------------------------------------------------------------------------

Unreferenced_Unk_Sprite_01:	dc.w 2
	dc.w 0,	$802, $C3EA, 0
	dc.w 8,	$402, $C3ED, 8

Unreferenced_Unk_Sprite_02:	dc.w 1
	dc.w 0,	$902, $C3EF, 0

Unreferenced_Unk_Sprite_03:	dc.w 2
	dc.w 0,	$502, $C3F5, 8
	dc.w 8,	2, $C3F9, 0

; ---------------------------------------------------------------------------

Unreferenced_Unk_Sprite_04:	dc.w 1
	dc.w $FFFC, 3, $1FE, $FFFC

; ===========================================================================

StageTextStrings:	
	include "resource/Text/Stage/Stage.asm"

; =============== S U B	R O U T	I N E =======================================

ProcPlaneCommands:
	move.w	(plane_cmd_count).l,d0
	beq.w	locret_19F8E
	move.w	(plane_cmd_count).l,(word_FF0DE0).l
	clr.w	(plane_cmd_count).l
	clr.w	d2
	move.b	(vdp_reg_10).l,d2
	andi.b	#3,d2
	lsl.b	#1,d2
	move.w	word_19F90(pc,d2.w),d1
	subq.w	#1,d0
	lea	(plane_cmd_queue).l,a2

loc_19F78:
	movem.l	d0-d1/a2,-(sp)
	bsr.w	sub_19F98
	movem.l	(sp)+,d0-d1/a2
	adda.l	#4,a2
	dbf	d0,loc_19F78

locret_19F8E:
	rts
; End of function ProcPlaneCommands

; ---------------------------------------------------------------------------
word_19F90:
	dc.w $40
	dc.w $80
	dc.w $100
	dc.w $100

; =============== S U B	R O U T	I N E =======================================

sub_19F98:
	move.b	(a2),d2
	bpl.w	QueueLoadMap
	andi.w	#$7F,d2
	lsl.w	#2,d2
	movea.l	off_19FAA(pc,d2.w),a4
	jmp	(a4)
; ---------------------------------------------------------------------------
off_19FAA:
	dc.l SpecPlane80
	dc.l SpecPlane81
	dc.l SpecPlane82
	dc.l SpecPlane83
	dc.l SpecPlane84
	dc.l SpecPlane85
	dc.l SpecPlane86
	dc.l SpecPlane87
	dc.l SpecPlane88
	dc.l SpecPlane89
	dc.l SpecPlane8A
	dc.l SpecPlane8B
	dc.l SpecPlane8C
	dc.l SpecPlane8D
	dc.l SpecPlane8E
	dc.l SpecPlane8F
	dc.l SpecPlane90
	dc.l SpecPlane91
	dc.l SpecPlane92
	dc.l SpecPlane93
	dc.l SpecPlane94
	dc.l SpecPlane95
	dc.l SpecPlane96
	dc.l SpecPlane97
	dc.l SpecPlane98
	dc.l SpecPlane99
	dc.l SpecPlane9A
	dc.l SpecPlane9B
	dc.l SpecPlane9C
	dc.l SpecPlane9D
	dc.l SpecPlane9E
	dc.l SpecPlane9F
; ---------------------------------------------------------------------------

SpecPlane9D:
	move.w	#$44,d2
	lea	(StageTextStrings).l,a3
	movea.l	(a3,d2.w),a4
	move.w	(a4)+,d0
	move.w	2(a2),d4
	moveq	#0,d3

loc_1A040:
	andi.b	#1,d3
	adda.l	d3,a4
	clr.b	d3
	move.w	(a4)+,d5
	move.w	(a4)+,d2
	eor.w	d4,d2

loc_1A04E:
	move.b	(a4)+,d2
	addq.b	#1,d3
	cmpi.b	#$FF,d2
	beq.s	loc_1A078
	bsr.w	SetVRAMWrite
	add.w	d1,d5
	move.w	d2,VDP_DATA
	addq.b	#1,d2
	bsr.w	SetVRAMWrite
	sub.w	d1,d5
	addq.w	#2,d5
	move.w	d2,VDP_DATA
	bra.s	loc_1A04E
; ---------------------------------------------------------------------------

loc_1A078:
	dbf	d0,loc_1A040
	rts
; ---------------------------------------------------------------------------

SpecPlane9C:
	move.w	2(a2),d5
	lea	(word_1A0A0).l,a4
	clr.w	d0
	move.b	1(a2),d0
	mulu.w	#$C,d0
	adda.w	d0,a4
	move.w	#2,d3
	move.w	#1,d4
	bra.w	CopyTilemap
; ---------------------------------------------------------------------------
word_1A0A0:
	dc.w $424B
	dc.w $424C
	dc.w $424D
	dc.w $4257
	dc.w $4258
	dc.w $4259
	dc.w $424F
	dc.w $4250
	dc.w $4251
	dc.w $425B
	dc.w $425C
	dc.w $425D
	dc.w $4252
	dc.w $4253
	dc.w $4254
	dc.w $425E
	dc.w $425F
	dc.w $4260
	dc.w $4A51
	dc.w $4A50
	dc.w $4A4F
	dc.w $4A5D
	dc.w $4A5C
	dc.w $4A5B
	dc.w $4A4D
	dc.w $4A4C
	dc.w $4A4B
	dc.w $4A59
	dc.w $4A58
	dc.w $4A57
; ---------------------------------------------------------------------------

SpecPlane9B:
	move.w	#$C204,d2
	tst.b	(swap_controls).l
	beq.s	loc_1A0EE
	move.w	#$C234,d2

loc_1A0EE:
	clr.w	d5
	move.b	1(a2),d5
	subq.b	#1,d5
	lsl.w	#7,d5
	add.w	d2,d5
	lea	(word_1A12E).l,a4
	move.w	#$B,d3
	move.w	#1,d4
	bsr.w	CopyTilemap
	clr.w	d5
	move.b	1(a2),d5
	neg.b	d5
	addi.b	#$12,d5
	lsl.w	#7,d5
	add.w	d2,d5
	lea	(word_1A146).l,a4
	move.w	#$B,d3
	move.w	#1,d4
	bra.w	CopyTilemap
; ---------------------------------------------------------------------------
word_1A12E:
	dc.w $C1E8
	dc.w $C1E9
	dc.w $C1E9
	dc.w $C1E9
	dc.w $C1E9
	dc.w $C1E9
	dc.w $C1E9
	dc.w $C1E9
	dc.w $C1E9
	dc.w $C1E9
	dc.w $C1E9
	dc.w $C1EA

word_1A146:
	dc.w $C1EB
	dc.w $C1AB
	dc.w $C1AB
	dc.w $C1AB
	dc.w $C1AB
	dc.w $C1AB
	dc.w $C1AB
	dc.w $C1AB
	dc.w $C1AB
	dc.w $C1AB
	dc.w $C1AB
	dc.w $C1EC
	dc.w $C1ED
	dc.w $C1EE
	dc.w $C1EE
	dc.w $C1EE
	dc.w $C1EE
	dc.w $C1EE
	dc.w $C1EE
	dc.w $C1EE
	dc.w $C1EE
	dc.w $C1EE
	dc.w $C1EE
	dc.w $C1EF
; ---------------------------------------------------------------------------

SpecPlane9A:
	lea	(Str_1P).l,a1
	
	if DemoText=1
	tst.b	(level_mode).l
	beq.w	Keep1PText
	lea	(Str_Demo).l,a1
		
Keep1PText:
	endc
	
	move.w	#3,d0
	move.w	#$A500,d6
	move.w	#$C21E,d5
	tst.b	(swap_controls).l
	beq.s	loc_1A196
	move.w	#$C22A,d5

loc_1A196:
	bsr.w	DrawSmallText
	clr.w	d0
	move.b	(level).l,d0

	subi.b 	#3, d0
	mulu.w 	#4, d0
	lea	(Str_DrR), a1
	adda.w	d0, a1

	move.w	#3,d0
	move.w	#$A500,d6
	move.w	#$C21E,d5
	tst.b	(swap_controls).l
	bne.s	loc_1A1C2
	move.w	#$C22A,d5

loc_1A1C2:
	bsr.w	DrawSmallText
	rts
; ---------------------------------------------------------------------------

Str_1P:
	include	"resource/text/Stage/Scenario 1P.asm"
	even

Str_DrR:
	include	"resource/text/Stage/Scenario 2P.asm"
	even

Str_Demo:
	include	"resource/text/Stage/Demo 1P.asm"
	even

; ---------------------------------------------------------------------------

SpecPlane98:
	move.w	#$C506,d5
	move.w	#$A500,d6
	lea	(Str_PlayTime).l,a1
	move.w	#9,d0
	bsr.w	DrawPlayerText
	move.w	#$C606,d5
	move.w	#$A500,d6
	lea	(Str_PT_Seconds).l,a1
	move.w	#9,d0
	bsr.w	DrawPlayerText
	move.w	2(a2),d2
	move.w	#$C608,d5
	move.w	#$8500,d6
	bra.w	loc_1A3BA
; ---------------------------------------------------------------------------
Str_PlayTime:
	dc.b $9E	; P
	dc.b $96	; L
	dc.b $80	; A
	dc.b $B0	; Y
	dc.b 0
	dc.b $A6	; T
	dc.b $90	; I
	dc.b $98	; M
	dc.b $88	; E
	dc.b 0

Str_PT_Seconds:
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b 0
	dc.b $A4	; S
	dc.b $88	; E
	dc.b $84	; C
; ---------------------------------------------------------------------------

SpecPlane99:
	move.w	#$C706,d5
	move.w	#$A500,d6
	lea	(Str_Bonus).l,a1
	move.w	#9,d0
	bsr.w	DrawPlayerText
	move.w	#$C806,d5
	move.w	#$A500,d6
	lea	(Str_B_Points).l,a1
	move.w	#9,d0
	bsr.w	DrawPlayerText
	move.w	2(a2),d2
	move.w	#$C808,d5
	move.w	#$8500,d6
	bra.w	loc_1A3BA
; ---------------------------------------------------------------------------
Str_Bonus:
	dc.b $82	; B
	dc.b $9C	; O
	dc.b $9A	; N
	dc.b $A8	; U
	dc.b $A4	; S
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0

Str_B_Points:
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b $9E	; P
	dc.b $A6	; T
	dc.b $A4	; S
; ---------------------------------------------------------------------------

SpecPlane9E:
	move.w	#$C906,d5
	move.w	#$A500,d6
	lea	(Str_Password).l,a1
	move.w	#9,d0
	bsr.w	DrawPlayerText
	lea	(Passwords).l,a1
	moveq	#0,d1
	move.b	(level).l,d1
	subq.w	#3,d1
	bpl.s	loc_1A29A
	moveq	#0,d1

loc_1A29A:
	asl.w	#3,d1
	adda.w	d1,a1
	move.b	(difficulty).l,d1
	neg.w	d1
	subq.w	#1,d1
	andi.w	#3,d1
	add.w	d1,d1
	move.w	(a1,d1.w),d1
	move.w	d1,(current_password).l
	lea	(off_1A348).l,a3
	lea	(unk_1A330).l,a2
	moveq	#3,d0

loc_1A2C6:
	lea	(loc_1A318).l,a1
	jsr	(FindActorSlot).l
	bcs.s	loc_1A312
	rol.w	#4,d1
	move.b	d1,d2
	andi.w	#$F,d2
	move.b	byte_1A320(pc,d2.w),8(a1)
	move.b	byte_1A328(pc,d2.w),9(a1)
	asl.w	#2,d2
	move.l	off_1A348(pc,d2.w),$32(a1)
	move.b	#$80,6(a1)
	move.b	(a2)+,d2
	move.b	(a2)+,$22(a1)
	move.w	(a2)+,d2
	move.w	(a2)+,$E(a1)
	tst.b	(swap_controls).l
	beq.s	loc_1A30E
	addi.w	#$C0,d2

loc_1A30E:
	move.w	d2,$A(a1)

loc_1A312:
	dbf	d0,loc_1A2C6
	rts
; ---------------------------------------------------------------------------

loc_1A318:
	jmp	(ActorAnimate).l
; ---------------------------------------------------------------------------
	rts
; ---------------------------------------------------------------------------
byte_1A320:
	dc.b 0
	dc.b   1
	dc.b   5
	dc.b   4
	dc.b   3
	dc.b   6
	dc.b $19
	dc.b $FF

byte_1A328:
	dc.b 0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b  $A
	dc.b $FF

unk_1A330:
	dc.b   0
	dc.b $5D
	dc.b   0
	dc.b $A8
	dc.b   1
	dc.b $28
	dc.b   0
	dc.b $3E
	dc.b   0
	dc.b $B8
	dc.b   1
	dc.b $28
	dc.b   0
	dc.b $48
	dc.b   0
	dc.b $C8
	dc.b   1
	dc.b $28
	dc.b   0
	dc.b $23
	dc.b   0
	dc.b $D8
	dc.b   1
	dc.b $28
; TODO: Document Animation Code

off_1A348:
	dc.l unk_1A364
	dc.l unk_1A364
	dc.l unk_1A364
	dc.l unk_1A364
	dc.l unk_1A364
	dc.l unk_1A37A
	dc.l unk_1A384

unk_1A364:
	dc.b   3
	dc.b   2
	dc.b   1
	dc.b   0
	dc.b   2
	dc.b   3
	dc.b   1
	dc.b   0
	dc.b   3
	dc.b   2
	dc.b   1
	dc.b   0
	dc.b   2
	dc.b   3
	dc.b $3C
	dc.b   0
	dc.b $FF
	dc.b   0
	dc.l unk_1A364

unk_1A37A:
	dc.b $3C
	dc.b   0
	dc.b $3C
	dc.b   0
	dc.b $FF
	dc.b   0
	dc.l unk_1A37A

unk_1A384:
	dc.b $23
	dc.b  $A
	dc.b $23
	dc.b  $B
	dc.b $FF
	dc.b   0
	dc.l unk_1A384

Str_Password:
	dc.b   0
	dc.b $9E	; P
	dc.b $80	; A
	dc.b $A4	; S
	dc.b $A4	; S
	dc.b $AC	; W
	dc.b $9C	; O
	dc.b $A2	; R
	dc.b $86	; D
	dc.b   0

Str_AllClear:
	dc.b   0
	dc.b $80	; A
	dc.b $96	; L
	dc.b $96	; L
	dc.b   0
	dc.b $84	; C
	dc.b $96	; L
	dc.b $88	; E
	dc.b $80	; A
	dc.b $A2	; R
; ---------------------------------------------------------------------------
	dc.b $3A
	dc.b $3C
	dc.b $C9
	dc.b   6
	dc.b $3C
	dc.b $3C
	dc.b $A5
	dc.b   0
; ---------------------------------------------------------------------------
	lea	(Str_AllClear).l,a1
	move.w	#9,d0
	bsr.w	DrawPlayerText
	rts
; ---------------------------------------------------------------------------

loc_1A3BA:
	tst.b	(swap_controls).l
	beq.s	loc_1A3C8
	addi.w	#$30,d5

loc_1A3C8:
	clr.l	(stage_text_buffer).l
	move.b	#2,(stage_text_buffer+4).l
	lea	((stage_text_buffer+5)).l,a1

loc_1A3DC:
	andi.l	#$FFFF,d2
	beq.s	loc_1A3F6
	divu.w	#$A,d2
	swap	d2
	addq.b	#1,d2
	lsl.b	#1,d2
	move.b	d2,-(a1)
	swap	d2
	bra.s	loc_1A3DC
; ---------------------------------------------------------------------------

loc_1A3F6:
	lea	(stage_text_buffer).l,a1
	move.w	#4,d0
	bra.w	DrawSmallText
; ---------------------------------------------------------------------------

SpecPlane97:
	bsr.w	GetStageText
	bsr.w	DrawStageText
	bsr.w	DrawBGUnderStageText
	rts
; ---------------------------------------------------------------------------

GetStageText:
	cmpi.b	#$C,(level).l
	bcc.w	.DoubleDigit
	lea	(Str_Stage).l,a1
	bsr.w	BufferStageText
	move.b	(level).l,d0
	subq.b	#3,d0
	lea	((stage_text_buffer+6)).l,a1
	bra.w	BufferStageNumber
; ---------------------------------------------------------------------------

.DoubleDigit:
	lea	(Str_Stage1).l,a1
	bsr.w	BufferStageText
	move.b	(level).l,d0
	subi.b	#$D,d0
	lea	((stage_text_buffer+7)).l,a1
	bra.w	BufferStageNumber
; ---------------------------------------------------------------------------

BufferStageText:
	move.w	#7,d0
	lea	(stage_text_buffer).l,a2

.Loop:
	move.b	(a1)+,(a2)+
	dbf	d0,.Loop
	rts
; ---------------------------------------------------------------------------

BufferStageNumber:
	addi.b	#$37,d0
	lsl.b	#1,d0
	move.b	d0,(a1)
	rts
; ---------------------------------------------------------------------------
Str_Stage:
	dc.b $A4	; S
	dc.b $A6	; T
	dc.b $80	; A
	dc.b $8C	; G
	dc.b $88	; E
	dc.b 0
	dc.b 0
	dc.b 0

Str_Stage1:
	dc.b $A4	; S
	dc.b $A6	; T
	dc.b $80	; A
	dc.b $8C	; G
	dc.b $88	; E
	dc.b 0
	dc.b $6E	; 1
	dc.b 0
; ---------------------------------------------------------------------------

DrawStageText:
	move.w	#$C520,d5
	move.w	#$C500,d6
	move.w	#7,d0
	lea	(stage_text_buffer).l,a1
	bra.w	DrawSmallText
; ---------------------------------------------------------------------------

DrawBGUnderStageText: ; Story Under Tiles
	move.w	#$E520,d5
	move.w	#7,d3
	move.w	#1,d4
	move.w	#$C000,d6
	bsr.s LoadUnderTilesScenario
	bra.w	CopyTilemap8
; ---------------------------------------------------------------------------
; OUTPUT
; a4 = under stage text
LoadUnderTilesScenario:
	clr.w	d0
		
	move.b	(level).l, d0	
	add.w	d0, d0
	lea	@first(pc), a4
	add.w	@level(pc,d0.w), a4
	rts

@level:
	dc.w UnderGrassTiles-@first ; Practice Stage 1
	dc.w UnderGrassTiles-@first ; Practice Stage 2
	dc.w UnderGrassTiles-@first ; Practice Stage 3
	dc.w UnderGrassTiles-@first ; Stage 1
	dc.w UnderGrassTiles-@first ; Stage 2
	dc.w UnderGrassTiles-@first ; Stage 3
	dc.w UnderGrassTiles-@first ; Stage 4
	dc.w UnderGrassTiles-@first ; Stage 5
	dc.w UnderGrassTiles-@first ; Stage 6
	dc.w UnderGrassTiles-@first ; Stage 7
	dc.w UnderGrassTiles-@first ; Stage 8
	dc.w UnderGrassTiles-@first ; Stage 9
	dc.w UnderGrassTiles-@first ; Stage 10
	dc.w UnderGrassTiles-@first ; Stage 11
	dc.w UnderGrassTiles-@first ; Stage 12
	dc.w UnderGrassTiles-@first ; Stage 13
	even
@first:

UnderGrassTiles:
	dc.b $11
	dc.b $12
	dc.b $13
	dc.b $14
	dc.b $15
	dc.b $16
	dc.b $17
	dc.b $18
	dc.b $22
	dc.b $23
	dc.b $24
	dc.b $25
	dc.b $26
	dc.b $27
	dc.b $28
	dc.b $29
	even

UnderStoneTiles:
	dc.b $4F
	dc.b $4E
	dc.b $4F
	dc.b $4E
	dc.b $4F
	dc.b $4E
	dc.b $4F
	dc.b $4E
	dc.b $53
	dc.b $52
	dc.b $53
	dc.b $52
	dc.b $53
	dc.b $52
	dc.b $53
	dc.b $52
	even
	; < Insert 8x2 tile map bytes here for alternate undertile mappings >
	; example:

;UnderGHZTiles:
;	dc.b $35, $34, $35, $32, $33, $34, $35, $34
;	dc.b $27, $26, $27, $26, $27, $26, $27, $26
;	even

; ---------------------------------------------------------------------------

DrawPlayerText:
	tst.b	(swap_controls).l
	beq.w	DrawSmallText
	addi.w	#$30,d5

DrawSmallText:
	move.b	(a1)+,d6
	jsr	(SetVRAMWrite).l
	add.w	d1,d5
	move.w	d6,VDP_DATA
	addq.b	#1,d6
	jsr	(SetVRAMWrite).l
	sub.w	d1,d5
	addq.w	#2,d5
	move.w	d6,VDP_DATA
	dbf	d0,DrawSmallText
	rts
; ---------------------------------------------------------------------------

SpecPlane96:
	move.w	#$27,d3
	move.w	#0,d4
	move.w	2(a2),d5
	andi.w	#$FF00,d5
	addi.w	#$E000,d5
	clr.w	d0
	move.b	3(a2),d0
	mulu.w	#$50,d0
	lea	(byte_1FDEC).l,a4
	adda.w	d0,a4
	bra.w	CopyTilemap
; ---------------------------------------------------------------------------

SpecPlane93:
	move.w	#$C71E,d5
	move.w	#$8500,d6
	tst.b	1(a2)
	beq.s	loc_1A53C
	move.w	#$C72A,d5
	move.w	#$A500,d6

loc_1A53C:
	move.w	2(a2),d2
	lea	((byte_FF1982+4)).l,a3
	clr.l	(a3)+
	bsr.w	sub_1B396
	lea	((byte_FF1982+4)).l,a3
	move.w	#3,d0

loc_1A556:
	bsr.w	SetVRAMWrite
	add.w	d1,d5
	move.b	(a3)+,d6
	addq.b	#1,d6
	lsl.b	#1,d6
	move.w	d6,VDP_DATA
	addq.b	#1,d6
	bsr.w	SetVRAMWrite
	sub.w	d1,d5
	move.w	d6,VDP_DATA
	addq.w	#2,d5
	dbf	d0,loc_1A556
	rts
; ---------------------------------------------------------------------------

SpecPlane8B:
	move.w	#$10,d3
	move.w	#9,d4
	move.w	#$C716,d5
	bsr.w	SetVRAMWrite
	add.w	d1,d5
	move.w	#$C4D8,VDP_DATA
	move.w	d3,d0
	subq.w	#1,d0

loc_1A59C:
	move.w	#$C4D9,VDP_DATA
	dbf	d0,loc_1A59C
	move.w	#$C4DA,VDP_DATA
	move.w	d4,d0
	subq.w	#1,d0

loc_1A5B4:
	bsr.w	SetVRAMWrite
	move.w	#$C4DB,VDP_DATA
	move.w	d3,d2
	subq.w	#1,d2

loc_1A5C4:
	move.w	#$8500,VDP_DATA
	dbf	d2,loc_1A5C4
	move.w	#$C4DC,VDP_DATA
	add.w	d1,d5
	dbf	d0,loc_1A5B4
	bsr.w	SetVRAMWrite
	move.w	#$C4DD,VDP_DATA
	move.w	d3,d0
	subq.w	#1,d0

loc_1A5EE:
	move.w	#$C4DE,VDP_DATA
	dbf	d0,loc_1A5EE
	move.w	#$C4DF,VDP_DATA
	rts
; ---------------------------------------------------------------------------

SpecPlane92:
	moveq	#0,d0
	move.b	1(a2),d0
	moveq	#$46,d3
	mulu.w	d3,d0
	lea	(byte_66C9A).l,a3
	adda.w	d0,a3
	move.w	#$E70C,d5
	moveq	#6,d4

loc_1A61C:
	jsr	(SetVRAMWrite).l
	addi.w	#$80,d5
	moveq	#4,d3

loc_1A628:
	move.w	(a3)+,d0
	addi.w	#-$1E00,d0
	move.w	d0,VDP_DATA
	dbf	d3,loc_1A628
	dbf	d4,loc_1A61C
	rts
; ---------------------------------------------------------------------------

SpecPlane8F:
	move.w	#6,d3
	move.w	#2,d4
	move.w	#$DEB8,d5
	move.w	#$E100,d6
	lea	(unk_1A66A).l,a4
	tst.b	1(a2)
	beq.w	CopyTilemap8
	move.w	#$E900,d6
	lea	(unk_1A680).l,a4
	bra.w	CopyTilemap8
; ---------------------------------------------------------------------------
unk_1A66A:
	dc.b $FC
	dc.b $FC
	dc.b $CA
	dc.b $C8
	dc.b $F1
	dc.b $C0
	dc.b $FC
	dc.b $D5
	dc.b $D6
	dc.b $CD
	dc.b $CE
	dc.b $CF
	dc.b $D0
	dc.b $D1
	dc.b $DF
	dc.b $E5
	dc.b $DD
	dc.b $DE
	dc.b $DF
	dc.b $E0
	dc.b $E1
	dc.b   0

unk_1A680:
	dc.b $FC
	dc.b $C0
	dc.b $F1
	dc.b $C8
	dc.b $CA
	dc.b $FC
	dc.b $FC
	dc.b $D1
	dc.b $D0
	dc.b $CF
	dc.b $CE
	dc.b $CD
	dc.b $D6
	dc.b $D5
	dc.b $E1
	dc.b $E0
	dc.b $DF
	dc.b $DE
	dc.b $DD
	dc.b $E5
	dc.b $DF
	dc.b   0
; ---------------------------------------------------------------------------

SpecPlane8E:
	bsr.w	loc_1A7C4
	subq.w	#2,d3
	subq.w	#2,d4
	addi.w	#$82,d5
	move.w	#$83FB,d6
	bra.w	FillPlane
; ---------------------------------------------------------------------------

SpecPlane8C:
	bsr.w	loc_1A7C4
	movem.l	d3-d5,-(sp)
	lea	(plane_a_buffer).l,a1

loc_1A6B8:
	bsr.w	SetVRAMRead
	add.w	d1,d5
	move.w	d3,d0

loc_1A6C0:
	move.w	VDP_DATA,d2
	move.w	d2,(a1)+
	dbf	d0,loc_1A6C0
	dbf	d4,loc_1A6B8
	movem.l	(sp)+,d3-d5
	subq.w	#2,d3
	subq.w	#2,d4
	addq.w	#2,d5
	bsr.w	SetVRAMWrite
	subq.w	#2,d5
	add.w	d1,d5
	move.w	d3,d0

loc_1A6E4:
	move.w	#$E3F8,VDP_DATA
	dbf	d0,loc_1A6E4

loc_1A6F0:
	bsr.w	SetVRAMWrite
	add.w	d1,d5
	move.w	#$E3FA,VDP_DATA
	move.w	d3,d0

loc_1A700:
	move.w	#$E3FB,VDP_DATA
	dbf	d0,loc_1A700
	move.w	#$E3FC,VDP_DATA
	dbf	d4,loc_1A6F0
	addq.w	#2,d5
	bsr.w	SetVRAMWrite
	subq.w	#2,d5
	move.w	d3,d0

loc_1A722:
	move.w	#$E3FE,VDP_DATA
	dbf	d0,loc_1A722
	rts
; ---------------------------------------------------------------------------

SpecPlane9F:
	bsr.w	loc_1A7C4
	movem.l	d3-d5,-(sp)
	lea	(plane_a_buffer).l,a1

loc_1A73E:
	bsr.w	SetVRAMRead
	add.w	d1,d5
	move.w	d3,d0

loc_1A746:
	move.w	VDP_DATA,d2
	move.w	d2,(a1)+
	dbf	d0,loc_1A746
	dbf	d4,loc_1A73E
	movem.l	(sp)+,d3-d5
	subq.w	#2,d3
	subq.w	#2,d4
	addq.w	#2,d5
	bsr.w	SetVRAMWrite
	subq.w	#2,d5
	add.w	d1,d5
	move.w	d3,d0

loc_1A76A:
	move.w	#$E1F8,VDP_DATA
	dbf	d0,loc_1A76A

loc_1A776:
	bsr.w	SetVRAMWrite
	add.w	d1,d5
	move.w	#$E1FA,VDP_DATA
	move.w	d3,d0

loc_1A786:
	move.w	#$E1FB,VDP_DATA
	dbf	d0,loc_1A786
	move.w	#$E1FC,VDP_DATA
	dbf	d4,loc_1A776
	addq.w	#2,d5
	bsr.w	SetVRAMWrite
	subq.w	#2,d5
	move.w	d3,d0

loc_1A7A8:
	move.w	#$E1FE,VDP_DATA
	dbf	d0,loc_1A7A8
	rts
; ---------------------------------------------------------------------------

SpecPlane8D:
	bsr.w	loc_1A7C4
	lea	(plane_a_buffer).l,a4
	bra.w	CopyTilemap
; ---------------------------------------------------------------------------

loc_1A7C4:
	clr.w	d3
	move.b	1(a2),d3
	move.w	d3,d4
	andi.b	#$1F,d3
	lsr.b	#5,d4
	addq.w	#1,d3
	add.w	d4,d4
	move.w	2(a2),d5
	rts
; ---------------------------------------------------------------------------

SpecPlane8A:
	clr.w	d5
	move.b	1(a2),d5
	lsl.w	#7,d5
	addi.w	#$5F00,d5
	bsr.w	SetVRAMRead
	lea	VDP_DATA,a3
	lea	(RAM_START).l,a4
	move.w	#$3F,d0

loc_1A7FC:
	move.w	(a3),(a4)+
	dbf	d0,loc_1A7FC
	move.w	#$6580,d5
	bsr.w	SetVRAMWrite
	lea	(RAM_START).l,a4
	move.w	#$3F,d0

loc_1A814:
	move.w	(a4)+,(a3)
	dbf	d0,loc_1A814
	rts
; ---------------------------------------------------------------------------

SpecPlane89:
	lea	(RAM_START).l,a0
	moveq	#0,d0
	move.w	2(a2),d0
	adda.l	d0,a0
	bclr	#4,7(a0)
	jsr	(GetPuyoField).l
	movea.l	a2,a3
	movea.l	a2,a4
	addi.w	#$A14,d0
	adda.l	#pPlaceablePuyos,a2
	adda.l	#pUnk6,a3
	adda.l	#pPlaceablePuyosCopy,a4
	move.w	#(PUYO_FIELD_COLS*(PUYO_FIELD_ROWS-2)*2)-2,d2
	move.w	#5,d3
	move.w	#$16,d4

loc_1A85C:
	move.b	(a3,d2.w),d5
	beq.s	loc_1A86E
	bsr.w	loc_1A884
	bset	#4,7(a0)

loc_1A86E:
	subq.w	#4,d0
	dbf	d3,loc_1A87E
	move.w	#5,d3
	subi.w	#$E8,d0
	subq.w	#2,d4

loc_1A87E:
	subq.w	#2,d2
	bcc.s	loc_1A85C
	rts
; ---------------------------------------------------------------------------

loc_1A884:
	clr.w	d7
	lsl.b	#1,d5
	move.b	1(a3,d2.w),d6
	cmp.b	d5,d6
	bcs.s	loc_1A89C
	move.b	d6,d7
	sub.b	d5,d7
	addq.w	#1,d7
	move.b	d5,d6
	subq.b	#1,d6

loc_1A89C:
	clr.w	d1
	move.b	(a4,d2.w),d1
	lsr.b	#3,d1
	andi.b	#$C,d1
	movea.l	off_1A918(pc,d1.w),a5
	move.b	(a5,d7.w),d5
	bpl.w	loc_1A8BA
	clr.b	(a3,d2.w)
	rts
; ---------------------------------------------------------------------------

loc_1A8BA:
	clr.w	d1
	move.b	d6,d1
	lsl.w	#7,d1
	add.w	d0,d1
	add.b	d4,d6
	cmpi.b	#3,d6
	bcs.s	loc_1A8D0
	move.b	#2,d6

loc_1A8D0:
	tst.w	d7
	beq.s	loc_1A8DA
	move.b	#1,d6

loc_1A8DA:
	andi.w	#$FF,d6
	lsl.w	#2,d6
	movea.l	off_1A90C(pc,d6.w),a5
	swap	d0
	move.b	(a4,d2.w),d0
	move.b	d0,d7
	andi.b	#$70,d7
	cmpi.b	#$60,d7
	beq.s	loc_1A8FC
	or.b	d5,d7
	move.b	d7,d0

loc_1A8FC:
	jsr	(GetPuyoTileID).l
	jsr	(a5)
	swap	d0
	addq.b	#1,1(a3,d2.w)
	rts
; ---------------------------------------------------------------------------
off_1A90C:
	dc.l loc_1A9A2
	dc.l loc_1A988
	dc.l loc_1A972
off_1A918:
	dc.l unk_1A928
	dc.l unk_1A940
	dc.l unk_1A958
	dc.l unk_1A970
unk_1A928:
	dc.b   1
	dc.b   1
	dc.b   2
	dc.b   2
	dc.b   2
	dc.b   1
	dc.b   3
	dc.b   3
	dc.b   1
	dc.b   2
	dc.b   2
	dc.b   2
	dc.b   1
	dc.b   3
	dc.b   3
	dc.b   1
	dc.b   2
	dc.b   2
	dc.b   1
	dc.b   3
	dc.b   1
	dc.b   2
	dc.b $FF
	dc.b   0

unk_1A940:
	dc.b   1
	dc.b   2
	dc.b   2
	dc.b   2
	dc.b   2
	dc.b   1
	dc.b   3
	dc.b   1
	dc.b   2
	dc.b   1
	dc.b   3
	dc.b   1
	dc.b   2
	dc.b   1
	dc.b   3
	dc.b   1
	dc.b   2
	dc.b   1
	dc.b   3
	dc.b   1
	dc.b   2
	dc.b   1
	dc.b   3
	dc.b $FF

unk_1A958:
	dc.b   1
	dc.b   1
	dc.b   2
	dc.b   2
	dc.b   2
	dc.b   2
	dc.b   3
	dc.b   3
	dc.b   2
	dc.b   2
	dc.b   2
	dc.b   2
	dc.b   3
	dc.b   3
	dc.b   2
	dc.b   1
	dc.b   3
	dc.b   3
	dc.b   1
	dc.b   3
	dc.b   3
	dc.b   1
	dc.b $FF
	dc.b   0

unk_1A970:
	dc.b   1
	dc.b $FF
; ---------------------------------------------------------------------------

loc_1A972:
	move.w	d1,d5
	bsr.w	SetVRAMWrite
	move.w	#$83FE,VDP_DATA
	move.w	#$83FE,VDP_DATA

loc_1A988:
	move.w	d1,d5
	addi.w	#$80,d5
	bsr.w	SetVRAMWrite
	move.w	d0,d5
	move.w	d5,VDP_DATA
	addq.w	#2,d5
	move.w	d5,VDP_DATA

loc_1A9A2:
	move.w	d1,d5
	addi.w	#$100,d5
	bsr.w	SetVRAMWrite
	move.w	d0,d5
	addq.w	#1,d5
	move.w	d5,VDP_DATA
	addq.w	#2,d5
	move.w	d5,VDP_DATA
	rts
; ---------------------------------------------------------------------------

SpecPlane88:
	clr.w	d2
	move.b	1(a2),d2
	lsl.b	#2,d2
	lea	(off_1AC82).l,a4
	movea.l	(a4,d2.w),a3
	bsr.w	loc_1AB12
	move.w	2(a2),d6
	andi.w	#$8000,d6
	clr.w	d2
	move.b	3(a2),d2
	mulu.w	#$30,d2
	lea	(unk_1AA22).l,a4
	adda.w	d2,a4
	move.w	#1,d2
	btst	#1,(level_mode).l
	beq.s	loc_1AA04
	move.w	#3,d2

loc_1AA04:
	bsr.w	SetVRAMWrite
	add.w	d1,d5
	move.w	#5,d0

loc_1AA0E:
	move.w	(a4)+,d3
	or.w	d6,d3
	move.w	d3,VDP_DATA
	dbf	d0,loc_1AA0E
	dbf	d2,loc_1AA04
	rts
; ---------------------------------------------------------------------------
unk_1AA22:
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $64
	dc.b   4
	dc.b $66
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $65
	dc.b   4
	dc.b $67
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $68
	dc.b   4
	dc.b $6A
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $69
	dc.b   4
	dc.b $6B
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $6C
	dc.b   4
	dc.b $6E
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $6D
	dc.b   4
	dc.b $6F
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $E0
	dc.b   5
	dc.b $74
	dc.b   5
	dc.b $6C
	dc.b   5
	dc.b $6C
	dc.b   5
	dc.b $6C
	dc.b   5
	dc.b $6C
	dc.b   4
	dc.b $E1
	dc.b   5
	dc.b $75
	dc.b   5
	dc.b $6D
	dc.b   5
	dc.b $6D
	dc.b   5
	dc.b $6D
	dc.b   5
	dc.b $6D
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $70
	dc.b   4
	dc.b $72
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $71
	dc.b   4
	dc.b $73
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $74
	dc.b   4
	dc.b $76
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $75
	dc.b   4
	dc.b $77
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $E0
	dc.b   5
	dc.b $7E
	dc.b   5
	dc.b $6C
	dc.b   5
	dc.b $6C
	dc.b   5
	dc.b $6C
	dc.b   5
	dc.b $6C
	dc.b   4
	dc.b $E1
	dc.b   5
	dc.b $7F
	dc.b   5
	dc.b $6D
	dc.b   5
	dc.b $6D
	dc.b   5
	dc.b $6D
	dc.b   5
	dc.b $6D
; ---------------------------------------------------------------------------

loc_1AB12:
	btst	#1,(level_mode).l
	beq.s	loc_1AB34
	clr.w	d5
	move.b	3(a2),d5
	lsr.b	#1,d5
	lsl.w	#2,d5
	addq.b	#3,d5
	mulu.w	d1,d5
	addq.w	#2,d5
	add.w	0(a3),d5
	rts
; ---------------------------------------------------------------------------

loc_1AB34:
	clr.w	d5
	move.b	3(a2),d5
	mulu.w	#3,d5
	addq.b	#2,d5
	mulu.w	d1,d5
	addq.w	#2,d5
	add.w	0(a3),d5
	rts
; ---------------------------------------------------------------------------

SpecPlane83:
	clr.w	d2
	move.b	(level_mode).l,d2
	andi.b	#2,d2
	or.b	1(a2),d2
	lsl.b	#2,d2
	lea	(off_1AC82).l,a4
	movea.l	(a4,d2.w),a3
	tst.b	3(a2)
	bmi.w	loc_1AC44
	clr.w	d5
	move.b	3(a2),d5
	mulu.w	d1,d5
	add.w	0(a3),d5
	move.w	2(a3),d3
	move.w	4(a3),d4
	clr.w	d2
	move.b	3(a2),d2
	lsl.b	#1,d2
	sub.w	d2,d4
	move.w	6(a3),d6
	clr.w	d2
	move.b	3(a2),d2
	mulu.w	d3,d2
	lsl.w	#1,d2
	movea.l	8(a3),a4
	adda.w	d2,a4
	bsr.w	SetVRAMWrite
	add.w	d1,d5
	move.w	d3,d0
	addq.w	#1,d0

loc_1ABAA:
	move.w	d6,VDP_DATA
	dbf	d0,loc_1ABAA
	bsr.w	SetVRAMWrite
	add.w	d1,d5
	move.w	#$C4D8,VDP_DATA
	move.w	d3,d0
	subq.w	#1,d0

loc_1ABC6:
	move.w	#$C4D9,VDP_DATA
	dbf	d0,loc_1ABC6
	move.w	#$C4DA,VDP_DATA
	move.w	d4,d0
	subq.w	#1,d0
	bmi.w	loc_1AC0A

loc_1ABE2:
	bsr.w	SetVRAMWrite
	move.w	#$C4DB,VDP_DATA
	move.w	d3,d2
	subq.w	#1,d2

loc_1ABF2:
	move.w	(a4)+,VDP_DATA
	dbf	d2,loc_1ABF2
	move.w	#$C4DC,VDP_DATA
	add.w	d1,d5
	dbf	d0,loc_1ABE2

loc_1AC0A:
	bsr.w	SetVRAMWrite
	move.w	#$C4DD,VDP_DATA
	move.w	d3,d0
	subq.w	#1,d0

loc_1AC1A:
	move.w	#$C4DE,VDP_DATA
	dbf	d0,loc_1AC1A
	move.w	#$C4DF,VDP_DATA
	add.w	d1,d5
	bsr.w	SetVRAMWrite
	move.w	d3,d0
	addq.w	#1,d0

loc_1AC38:
	move.w	d6,VDP_DATA
	dbf	d0,loc_1AC38
	rts
; ---------------------------------------------------------------------------

loc_1AC44:
	move.w	4(a3),d5
	lsr.w	#1,d5
	addq.w	#1,d5
	mulu.w	d1,d5
	add.w	0(a3),d5
	move.w	6(a3),d6
	move.w	2(a3),d3
	bsr.w	SetVRAMWrite
	add.w	d1,d5
	move.w	d3,d0
	addq.w	#1,d0

loc_1AC64:
	move.w	d6,VDP_DATA
	dbf	d0,loc_1AC64
	bsr.w	SetVRAMWrite
	move.w	d3,d0
	addq.w	#1,d0

loc_1AC76:
	move.w	d6,VDP_DATA
	dbf	d0,loc_1AC76
	rts
; ---------------------------------------------------------------------------
off_1AC82:
	dc.l unk_1AC92
	dc.l unk_1AC9E
	dc.l unk_1ACAA
	dc.l unk_1ACB6

unk_1AC92:
	dc.b $C2
	dc.b $86
	dc.b   0
	dc.b   6
	dc.b   0
	dc.b  $E
	dc.b $80
	dc.b   0
	dc.l unk_1ACC2

unk_1AC9E:
	dc.b $C2
	dc.b $BA
	dc.b   0
	dc.b   6
	dc.b   0
	dc.b  $E
	dc.b $80
	dc.b   0
	dc.l unk_1ACC2

unk_1ACAA:
	dc.b $C2
	dc.b $86
	dc.b   0
	dc.b   6
	dc.b   0
	dc.b  $E
	dc.b $80
	dc.b   0
	dc.l unk_1AD6A

unk_1ACB6:
	dc.b $C2
	dc.b $BA
	dc.b   0
	dc.b   6
	dc.b   0
	dc.b  $E
	dc.b $80
	dc.b   0
	dc.l unk_1AD6A

unk_1ACC2:
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $64
	dc.b   4
	dc.b $66
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $65
	dc.b   4
	dc.b $67
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $68
	dc.b   4
	dc.b $6A
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $69
	dc.b   4
	dc.b $6B
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $6C
	dc.b   4
	dc.b $6E
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $6D
	dc.b   4
	dc.b $6F
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $70
	dc.b   4
	dc.b $72
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $71
	dc.b   4
	dc.b $73
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $74
	dc.b   4
	dc.b $76
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $75
	dc.b   4
	dc.b $77
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0

unk_1AD6A:
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $64
	dc.b   4
	dc.b $66
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $65
	dc.b   4
	dc.b $67
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $6C
	dc.b   4
	dc.b $6E
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $6D
	dc.b   4
	dc.b $6F
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $E0
	dc.b   5
	dc.b $74
	dc.b   5
	dc.b $6C
	dc.b   5
	dc.b $6C
	dc.b   5
	dc.b $6C
	dc.b   5
	dc.b $6C
	dc.b   4
	dc.b $E1
	dc.b   5
	dc.b $75
	dc.b   5
	dc.b $6D
	dc.b   5
	dc.b $6D
	dc.b   5
	dc.b $6D
	dc.b   5
	dc.b $6D
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $74
	dc.b   4
	dc.b $76
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $75
	dc.b   4
	dc.b $77
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   4
	dc.b $E0
	dc.b   5
	dc.b $7E
	dc.b   5
	dc.b $6C
	dc.b   5
	dc.b $6C
	dc.b   5
	dc.b $6C
	dc.b   5
	dc.b $6C
	dc.b   4
	dc.b $E1
	dc.b   5
	dc.b $7F
	dc.b   5
	dc.b $6D
	dc.b   5
	dc.b $6D
	dc.b   5
	dc.b $6D
	dc.b   5
	dc.b $6D
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
	dc.b   0
; ---------------------------------------------------------------------------

SpecPlane80:
	clr.w	d2
	move.b	1(a2),d2
	lsl.w	#2,d2
	lea	(StageTextStrings).l,a3
	movea.l	(a3,d2.w),a4
	move.b	2(a2),d4
	beq.s	loc_1AE42
	bmi.w	loc_1AE42
	move.b	(frame_count+1).l,d4
	andi.b	#$10,d4
	beq.s	loc_1AE42
	move.b	#$FF,d4

loc_1AE42:
	not.b	d4
	move.w	(a4)+,d0
	moveq	#0,d3

loc_1AE48:
	andi.b	#1,d3
	adda.l	d3,a4
	clr.b	d3
	move.w	(a4)+,d5
	bne.s	loc_1AE5A
	bsr.w	loc_1AE90

loc_1AE5A:
	move.w	(a4)+,d2

loc_1AE5C:
	move.b	(a4)+,d2
	addq.b	#1,d3
	cmpi.b	#$FF,d2
	beq.s	loc_1AE8A
	bsr.w	loc_1AEB4
	bsr.w	SetVRAMWrite
	add.w	d1,d5
	move.w	d2,VDP_DATA
	addq.b	#1,d2
	bsr.w	SetVRAMWrite
	sub.w	d1,d5
	addq.w	#2,d5
	move.w	d2,VDP_DATA
	bra.s	loc_1AE5C
; ---------------------------------------------------------------------------

loc_1AE8A:
	dbf	d0,loc_1AE48
	rts
; ---------------------------------------------------------------------------

loc_1AE90:
	movem.l	d0-d1,-(sp)
	move.w	#$C104,d5
	move.b	3(a2),d0
	move.b	(swap_controls).l,d1
	eor.b	d1,d0
	beq.s	loc_1AEAC
	move.w	#$C134,d5

loc_1AEAC:
	add.w	(a4)+,d5
	movem.l	(sp)+,d0-d1
	rts
; ---------------------------------------------------------------------------

loc_1AEB4:
	and.b	d4,d2
	cmpi.b	#$FE,d2
	beq.s	loc_1AEC0
	rts
; ---------------------------------------------------------------------------

loc_1AEC0:
	move.b	3(a2),d2
	addi.b	#$37,d2
	lsl.b	#1,d2
	rts
; ---------------------------------------------------------------------------

SpecPlane81:
	move.w	(word_FF198A).l,d5
	move.w	#$8500,d2
	bra.w	loc_1AEF0
; ---------------------------------------------------------------------------

SpecPlane82:
	move.w	#$CC22,d5
	tst.b	(swap_controls).l
	beq.s	loc_1AEEC
	move.w	#$CB1E,d5

loc_1AEEC:
	move.w	#$A500,d2

loc_1AEF0:
	move.l	d2,-(sp)
	lea	(RAM_START).l,a3
	moveq	#0,d3
	move.w	2(a2),d3
	move.l	$A(a3,d3.l),d2
	bsr.w	sub_1B350
	move.l	(sp)+,d2

loc_1AF0C:
	lea	(byte_FF1982).l,a3
	clr.w	d3
	bsr.w	SetVRAMWrite

loc_1AF18:
	bsr.w	loc_1AF48
	move.w	d2,VDP_DATA
	addq.w	#1,d3
	cmpi.w	#8,d3
	bcs.s	loc_1AF18
	clr.w	d3
	add.w	d1,d5
	bsr.w	SetVRAMWrite

loc_1AF32:
	bsr.w	loc_1AF48
	addq.b	#1,d2
	move.w	d2,VDP_DATA
	addq.w	#1,d3
	cmpi.w	#8,d3
	bcs.s	loc_1AF32
	rts
; ---------------------------------------------------------------------------

loc_1AF48:
	move.b	(a3,d3.w),d2
	bmi.w	loc_1AF56
	addq.b	#1,d2
	lsl.b	#1,d2
	rts
; ---------------------------------------------------------------------------

loc_1AF56:
	clr.w	d4
	move.b	d2,d4
	andi.b	#$7F,d4
	move.b	byte_1AF64(pc,d4.w),d2
	rts
; ---------------------------------------------------------------------------
byte_1AF64:	dc.b 0
	dc.b $4A
; ---------------------------------------------------------------------------

SpecPlane86:
	move.w	(word_FF198A).l,d5
	move.w	#$8500,d2
	bra.w	loc_1AF8A
; ---------------------------------------------------------------------------

SpecPlane87:
	move.w	#$A500,d2
	move.w	#$CC22,d5
	tst.b	(swap_controls).l
	beq.s	loc_1AF8A
	move.w	#$CB1E,d5

loc_1AF8A:
	move.l	d2,-(sp)
	lea	(byte_FF1982).l,a3
	move.w	#7,d2

loc_1AF98:
	move.b	#$80,(a3)+
	dbf	d2,loc_1AF98
	lea	(word_FF198A).l,a3
	lea	(RAM_START).l,a4
	moveq	#0,d3
	move.w	2(a2),d3
	move.w	$1E(a4,d3.l),d2
	beq.s	loc_1AFCA
	move.l	d3,-(sp)
	bsr.w	sub_1B396
	move.l	(sp)+,d3
	move.b	#$81,-(a3)

loc_1AFCA:
	moveq	#0,d2
	move.w	$12(a4,d3.l),d2
	divu.w	#10000,d2
	swap	d2
	bsr.w	sub_1B396
	move.l	(sp)+,d2
	bra.w	loc_1AF0C
; ---------------------------------------------------------------------------

SpecPlane84:
	bsr.w	loc_1B0AE
	lsl.b	#1,d2
	or.b	1(a2),d2
	move.b	(swap_controls).l,d0
	eor.b	d0,d2
	lsl.w	#2,d2
	lea	(off_1B0EA).l,a4
	movea.l	(a4,d2.w),a3
	clr.w	d2
	move.b	3(a2),d2
	move.w	4(a3),d0
	mulu.w	d0,d2
	movea.l	0(a3),a4
	adda.w	d2,a4
	move.w	8(a3),d6
	move.w	$A(a3),d3
	move.w	#1,d4
	move.w	$C(a3),d5
	bsr.w	loc_1B0A0
	tst.b	3(a2)
	beq.s	loc_1B03A
	cmpi.b	#5,3(a2)
	beq.s	loc_1B064
	rts
; ---------------------------------------------------------------------------

loc_1B03A:
	move.w	6(a3),d6
	move.w	#$B,d3
	move.w	#1,d4
	move.w	$10(a3),d5
	bsr.w	FillPlane
	move.w	6(a3),d6
	move.w	#$B,d3
	move.w	#$25,d4
	move.w	$E(a3),d5
	bsr.w	FillPlane
	rts
; ---------------------------------------------------------------------------

loc_1B064:
	move.w	4(a3),d3
	mulu.w	#6,d3
	movea.l	0(a3),a4
	adda.w	d3,a4
	move.w	6(a3),d6
	move.w	#$B,d3
	move.w	#1,d4
	move.w	$10(a3),d5
	bsr.w	loc_1B0A0
	move.w	6(a3),d6
	move.w	$A(a3),d3
	move.w	#1,d4
	move.w	$C(a3),d5
	movea.l	0(a3),a4
	bsr.w	loc_1B0A0
	rts
; ---------------------------------------------------------------------------

loc_1B0A0:
	cmpi.w	#$40,4(a3)
	bcs.w	CopyTilemap8
	bra.w	CopyTilemap

; ---------------------------------------------------------------------------
	
loc_1B0AE:
	clr.w	d2			; Clear D2
	move.b	(level_mode).l,d2	; Move "Mode" value into D2
						; 00 = Scenario Mode
						; 01 = VS Mode
						; 02 = Exercise Mode
						; 03 = ?
						; 04 = Tutorial Mode	
	
	beq.w	ScenarioFall		; If Scenario Mode, jump to ScenarioFall
	
	bra	ModeFall		; Else jump to ModeFall
	
; ---------------------------------------------------------------------------

ScenarioFall:
	clr.w	d0				; Clear D0
	move.b	(level).l,d0			; Move Stage # into D0
;	subi.b	#3, d0
	move.b	byte_Scenario(pc,d0.w),d2	; D2 contains "Crumbling Tile Mappings" number to use 
	rts
	
ModeFall:
	clr.w	d0				; Clear D0
	move.b	(level_mode).l,d0		; Move Stage # into D0
	subi.b  #1,d0
	move.b	byte_Mode(pc,d0.w),d2		; D2 contains "Crumbling Tile Mappings" number to use 
	rts
	
; ---------------------------------------------------------------------------
byte_Scenario:		; Crumbling tile mappings to use in Scenario Mode		
	dc.b 0	; Practise Stage 1
	dc.b 0	; Practise Stage 2
	dc.b 0	; Practise Stage 3
	dc.b 0	; Stage 1
	dc.b 0	; Stage 2
	dc.b 0	; Stage 3
	dc.b 0	; Stage 4
	dc.b 0	; Stage 5
	dc.b 0	; Stage 6
	dc.b 0	; Stage 7
	dc.b 0	; Stage 8
	dc.b 0	; Stage 9
	dc.b 0	; Stage 10
	dc.b 0	; Stage 11
	dc.b 0	; Stage 12
	dc.b 0	; Stage 13
	even

byte_Mode:		; Crumbling tile mappings to use in Other Modes	

	dc.b 0 ; VS
	dc.b 0 ; Exercise
	dc.b 0 ; ?
	dc.b 0 ; Tutorial
	even

off_1B0EA: ; Crumbling tile mappings (when beans fall)

	dc.l Grass1P ; Grass - 1P Side
	dc.l Grass2P ; Grass - 2P Side

	dc.l Stone1P ; Stone - 1P Side
	dc.l Stone2P ; Stone - 2P Side

	; Add your pointers to the crumble tile mappings below
;	dc.l GHZ1P
;	dc.l GHZ2P

	include "resource/mapunc/Crumble Tiles/Grass/Grass1P.asm"
	even

	include "resource/mapunc/Crumble Tiles/Grass/Grass2P.asm"
	even

	include "resource/mapunc/Crumble Tiles/Stone/Stone1P.asm"
	even

	include "resource/mapunc/Crumble Tiles/Stone/Stone2P.asm"
	even

;	< include your crumble tile mapping pointers here>
; ---------------------------------------------------------------------------

SpecPlane85:
	rts
; ---------------------------------------------------------------------------

SpecPlane90:
	rts
; ---------------------------------------------------------------------------
	clr.w	d2
	move.b	(opponent).l,d2
	lsl.b	#2,d2
	lea	(off_1B632).l,a4
	movea.l	(a4,d2.w),a3
	move.b	1(a2),d2
	lsl.b	#2,d2
	movea.l	(a3,d2.w),a4
	move.w	(a4)+,d3
	move.w	(a4)+,d4
	move.w	(a4)+,d5
	addi.w	#$FEE,d5
	move.w	#$8000,d6
	bra.w	CopyTilemap8
; ---------------------------------------------------------------------------

SpecPlane94:
	clr.w	d2
	move.b	(opponent).l,d2
	lsl.b	#2,d2
	lea	(off_1B632).l,a4
	movea.l	(a4,d2.w),a3
	move.b	1(a2),d2
	lsl.b	#2,d2
	movea.l	(a3,d2.w),a4
	move.w	(a4)+,d3
	move.w	(a4)+,d4
	move.w	(a4)+,d5
	move.w	#$8100,d6
	bra.w	CopyTilemap8
; ---------------------------------------------------------------------------

SpecPlane95:
	rts
; ---------------------------------------------------------------------------

SpecPlane91:
	clr.w	d3
	move.b	1(a2),d3
	subq.w	#1,d3
	move.w	2(a2),d5
	bsr.w	SetVRAMWrite
	add.w	d1,d5
	move.w	#$E011,VDP_DATA
	move.w	d3,d0

loc_1B1D0:
	move.w	#$E012,VDP_DATA
	dbf	d0,loc_1B1D0
	move.w	#$E811,VDP_DATA
	bsr.w	SetVRAMWrite
	add.w	d1,d5
	move.w	#$E013,VDP_DATA
	move.w	d3,d0

loc_1B1F4:
	move.w	#$E500,VDP_DATA
	dbf	d0,loc_1B1F4
	move.w	#$E813,VDP_DATA
	bsr.w	SetVRAMWrite
	add.w	d1,d5
	move.w	#$F011,VDP_DATA
	move.w	d3,d0

loc_1B218:
	move.w	#$F012,VDP_DATA
	dbf	d0,loc_1B218
	move.w	#$F811,VDP_DATA
	rts
; ---------------------------------------------------------------------------

QueueLoadMap:
	movea.l	(a2),a3
	move.w	(a3)+,d2
	clr.w	d3
	move.b	(a3)+,d3
	subq.b	#1,d3
	clr.w	d4
	move.b	(a3)+,d4
	subq.b	#1,d4
	move.w	(a3)+,d5
	movea.l	off_1B246(pc,d2.w),a4
	jmp	(a4)
; End of function sub_19F98

; ---------------------------------------------------------------------------
off_1B246:
	dc.l QueueFillPlane
	dc.l QueueCopyMap8
	dc.l QueueCopyMapDirect
	dc.l QueueCopyTwoMaps
	dc.l QueueCopyMapPalMap
	dc.l QueueCopyMap16
; ---------------------------------------------------------------------------

QueueFillPlane:
	move.w	(a3)+,d6

; =============== S U B	R O U T	I N E =======================================

FillPlane:
	bsr.w	SetVRAMWrite
	clr.w	d0
	move.w	d3,d0

loc_1B268:
	move.w	d6,VDP_DATA
	dbf	d0,loc_1B268
	add.w	d1,d5
	dbf	d4,FillPlane
	rts
; End of function FillPlane

; =============== S U B	R O U T	I N E =======================================

QueueCopyMap8:
	movea.l	(a3)+,a4
	move.w	(a3)+,d6
; End of function QueueCopyMap8

; START	OF FUNCTION CHUNK FOR sub_19F98

CopyTilemap8:
	bsr.w	SetVRAMWrite
	clr.w	d0
	move.w	d3,d0

.Tile:
	move.b	(a4)+,d6
	move.w	d6,VDP_DATA
	dbf	d0,.Tile
	add.w	d1,d5
	dbf	d4,CopyTilemap8
	rts
; END OF FUNCTION CHUNK	FOR sub_19F98

; =============== S U B	R O U T	I N E =======================================

QueueCopyMapDirect:
	movea.l	(a3)+,a4
; End of function QueueCopyMapDirect

; =============== S U B	R O U T	I N E =======================================

CopyTilemap:
	bsr.w	SetVRAMWrite
	clr.w	d0
	move.w	d3,d0

loc_1B2A4:
	move.w	(a4)+,VDP_DATA
	dbf	d0,loc_1B2A4
	add.w	d1,d5
	dbf	d4,CopyTilemap
	rts
; End of function CopyTilemap

; =============== S U B	R O U T	I N E =======================================

QueueCopyMap16:
	movea.l	(a3)+,a4
	move.w	(a3)+,d6

loc_1B2BA:
	bsr.w	SetVRAMWrite
	clr.w	d0
	move.w	d3,d0

loc_1B2C2:
	move.w	(a4)+,d2
	add.w	d6,d2
	move.w	d2,VDP_DATA
	dbf	d0,loc_1B2C2
	add.w	d1,d5
	dbf	d4,loc_1B2BA
	rts
; End of function QueueCopyMap16

; =============== S U B	R O U T	I N E =======================================

QueueCopyTwoMaps:
	movea.l	(a3)+,a4
	movea.l	(a3)+,a5
	move.w	(a3)+,d6
	move.w	(a3)+,d2

loc_1B2E0:
	bsr.w	SetVRAMWrite
	clr.w	d0
	move.w	d3,d0

loc_1B2E8:
	bsr.w	sub_1B2F8
	dbf	d0,loc_1B2E8
	add.w	d1,d5
	dbf	d4,loc_1B2E0
	rts
; End of function QueueCopyTwoMaps

; =============== S U B	R O U T	I N E =======================================

sub_1B2F8:
	move.b	(a4)+,d6
	move.b	(a5)+,d2
	beq.s	loc_1B308
	move.w	d2,VDP_DATA
	rts
; ---------------------------------------------------------------------------

loc_1B308:
	move.w	d6,VDP_DATA
	rts
; End of function sub_1B2F8

; =============== S U B	R O U T	I N E =======================================

QueueCopyMapPalMap:
	movea.l	(a3)+,a4
	movea.l	(a3)+,a5
	move.w	(a3)+,d6
	clr.b	d2

loc_1B318:
	bsr.w	SetVRAMWrite
	swap	d5
	clr.w	d0
	move.w	d3,d0

loc_1B322:
	andi.b	#3,d2
	bne.s	loc_1B32E
	move.b	(a5)+,d7
	ror.w	#1,d7

loc_1B32E:
	ror.w	#2,d7
	move.w	d7,d5
	andi.w	#$6000,d5
	or.w	d6,d5
	move.b	(a4)+,d5
	move.w	d5,VDP_DATA
	addq.b	#1,d2
	dbf	d0,loc_1B322
	swap	d5
	add.w	d1,d5
	dbf	d4,loc_1B318
	rts
; End of function QueueCopyMapPalMap

; =============== S U B	R O U T	I N E =======================================

sub_1B350:
	divu.w	#10000,d2
	lea	(word_FF198A).l,a3
	move.w	#2,d3
	move.l	d2,d4
	swap	d4

loc_1B362:
	andi.l	#$FFFF,d4
	divu.w	#10,d4
	swap	d4
	move.b	d4,-(a3)
	swap	d4
	dbf	d3,loc_1B362
	move.b	d4,-(a3)
	move.w	#2,d3
	move.w	d2,d4

loc_1B37E:
	andi.l	#$FFFF,d4
	divu.w	#10,d4
	swap	d4
	move.b	d4,-(a3)
	swap	d4
	dbf	d3,loc_1B37E
	move.b	d4,-(a3)
	rts
; End of function sub_1B350

; =============== S U B	R O U T	I N E =======================================

sub_1B396:
	andi.l	#$FFFF,d2
	beq.w	locret_1B3AC
	divu.w	#10,d2
	swap	d2
	move.b	d2,-(a3)
	swap	d2
	bra.s	sub_1B396
; ---------------------------------------------------------------------------

locret_1B3AC:
	rts
; End of function sub_1B396

; =============== S U B	R O U T	I N E =======================================

SetVRAMWrite:
	move.w	d5,d7
	andi.w	#$3FFF,d7
	ori.w	#$4000,d7
	move.w	d7,VDP_CTRL
	move.w	d5,d7
	rol.w	#2,d7
	andi.w	#3,d7
	move.w	d7,VDP_CTRL
	rts
; End of function SetVRAMWrite

; =============== S U B	R O U T	I N E =======================================

SetVRAMRead:
	move.w	d5,d7
	andi.w	#$3FFF,d7
	move.w	d7,VDP_CTRL
	move.w	d5,d7
	rol.w	#2,d7
	andi.w	#3,d7
	move.w	d7,VDP_CTRL
	rts
; End of function SetVRAMRead

; ---------------------------------------------------------------------------

	include "resource/mapunc/Crumble Tiles/Grass/CrumbleGrass.asm"
	even

	include "resource/mapunc/Crumble Tiles/Stone/CrumbleStone.asm"
	even

	include "resource/mapunc/Crumble Tiles/Stone/CrumbleStoneAlt.asm"
	even

; ---------------------------------------------------------------------------

off_1B632:	; Leftover Puyo Opponent Art (Potentially remove?)
	dc.l SkeletonT_PlaneMaps	;	Skeleton Tea
	dc.l Suketoudara_PlaneMaps	;	Suketoudara
	dc.l Zombie_PlaneMaps		;	Zombie
	dc.l Draco_PlaneMaps		;	Draco Centauros
	dc.l NasuGrave_PlaneMaps	;	Nasu Grave
	dc.l Witch_PlaneMaps		;	Witch
	dc.l Sasoriman_PlaneMaps	;	Sasoriman
	dc.l Harpy_PlaneMaps		;	Harpy
	dc.l ZohDaimaoh_PlaneMaps	;	Zoh Daimaoh
	dc.l Schezo_PlaneMaps		;	Schezo Wegey
	dc.l Minotauros_PlaneMaps	;	Minotauros
	dc.l Rulue_PlaneMaps		;	Rulue
	dc.l Satan_PlaneMaps		;	Satan
	dc.l Mummy_PlaneMaps		;	Mummy
	dc.l Sukiyapotes_PlaneMaps	;	Sukiyapotes
	dc.l Panotty_PlaneMaps		;	Panotty
	dc.l SkeletonT_PlaneMaps	;	Skeleton Tea (Duplicate)

; ---------------------------------------------------------------------------

word_1B59A:
	dc.w 9
	dc.w 6
	dc.w $C61E
	dc.b 0,	1, 2, 3, 4, 5, 6, 7, 8,	9, $20,	$21, $22, $23, $24, $25
	dc.b $26, $27, $28, $29, $40, $41, $42,	$43, $44, $45, $46, $47, $48, $49, $60,	$61
	dc.b $62, $63, $64, $65, $66, $67, $68,	$69, $80, $81, $82, $83, $84, $85, $86,	$87
	dc.b $88, $89, $A0, $A1, $A2, $A3, $A4,	$A5, $A6, $A7, $A8, $A9, $C0, $C1, $C2,	$C3
	dc.b $C4, $C5, $C6, $C7, $C8, $C9

word_1B5E6:
	dc.w 9
	dc.w 6
	dc.w $C61E
	dc.b $16, $17, $18, $19, $1A, $1B, $1C,	$1D, $1E, $1F, $36, $37, $38, $39, $3A,	$3B
	dc.b $3C, $3D, $3E, $3F, $56, $57, $58,	$59, $5A, $5B, $5C, $5D, $5E, $5F, $76,	$77
	dc.b $78, $79, $7A, $7B, $7C, $7D, $7E,	$7F, $96, $97, $98, $99, $9A, $9B, $9C,	$9D
	dc.b $9E, $9F, $B6, $B7, $B8, $B9, $BA,	$BB, $BC, $BD, $BE, $BF, $D6, $D7, $D8,	$D9
	dc.b $DA, $DB, $DC, $DD, $DE, $DF

; ---------------------------------------------------------------------------

Mummy_PlaneMaps:
	dc.l word_1B59A
	dc.l word_1B5E6
	dc.l word_1B6A6
	dc.l word_1B6B4
	dc.l word_1B6C2
	dc.l word_1B6D0
	dc.l word_1B6DE
	dc.l word_1B6EC
	dc.l word_1B6FA
	dc.l word_1B718
	dc.l word_1B736
	dc.l word_1B754

word_1B6A6:
	dc.w 3
	dc.w 1
	dc.w $C724
	dc.b $43, $44, $45, $46, $63, $64, $65,	$66

word_1B6B4:
	dc.w 3
	dc.w 1
	dc.w $C724
	dc.b $A, $B, $C, $D, $2A, $2B, $2C, $2D

word_1B6C2:
	dc.w 3
	dc.w 1
	dc.w $C724
	dc.b $4A, $4B, $4C, $4D, $6A, $6B, $6C,	$6D

word_1B6D0:
	dc.w 3
	dc.w 1
	dc.w $C724
	dc.b $E, $F, $10, $11, $2E, $2F, $30, $31

word_1B6DE:
	dc.w 3
	dc.w 1
	dc.w $C724
	dc.b $4E, $4F, $50, $51, $6E, $6F, $70,	$71

word_1B6EC:
	dc.w 3
	dc.w 1
	dc.w $C724
	dc.b $8E, $8F, $90, $91, $AE, $AF, $B0,	$B1

word_1B6FA:
	dc.w 7
	dc.w 2
	dc.w $C720
	dc.b $41, $42, $8A, $8B, $8C, $8D, $47,	$48, $12, $13, $AA, $AB, $AC, $AD, $14,	$15
	dc.b $32, $33, $83, $84, $85, $86, $34,	$35

word_1B718:
	dc.w 7
	dc.w 2
	dc.w $C720
	dc.b $41, $42, $CA, $CB, $CC, $CD, $47,	$48, $52, $53, $EA, $EB, $EC, $ED, $54,	$55
	dc.b $72, $73, $83, $84, $85, $86, $74,	$75

word_1B736:
	dc.w 7
	dc.w 2
	dc.w $C720
	dc.b $41, $42, $CA, $CB, $CC, $CD, $47,	$48, $92, $93, $EA, $EB, $EC, $ED, $94,	$95
	dc.b $B2, $B3, $83, $84, $85, $86, $B4,	$B5

word_1B754:
	dc.w 9
	dc.w 6
	dc.w $C61E
	dc.b $16, $17, $18, $19, $1A, $1B, $F6,	$F7, $D4, $D5, $36, $37, $38, $39, $3A,	$3B
	dc.b $D2, $D3, $F4, $F5, $56, $CE, $CF,	$59, $D0, $D1, $F2, $F3, $5E, $5F, $76,	$EE
	dc.b $EF, $79, $F0, $F1, $7C, $7D, $7E,	$7F, $96, $97, $98, $99, $9A, $9B, $9C,	$9D
	dc.b $9E, $9F, $B6, $B7, $B8, $B9, $BA,	$BB, $BC, $BD, $BE, $BF, $D6, $D7, $D8,	$D9
	dc.b $DA, $DB, $DC, $DD, $DE, $DF

; ---------------------------------------------------------------------------

Sukiyapotes_PlaneMaps:
	dc.l word_1B59A
	dc.l word_1B5E6
	dc.l word_1B7D8
	dc.l word_1B7EE
	dc.l word_1B804
	dc.l word_1B83A
	dc.l word_1B870
	dc.l word_1B8D0
	dc.l word_1B8D8
	dc.l word_1B8E0
	dc.l word_1B8E8
	dc.l word_1B8F0
	dc.l word_1B8F8
	dc.l word_1B8A6

word_1B7D8:	dc.w 4
	dc.w 2
	dc.w $C6A2
	dc.b $A, $B, $C, $D, $E, $2A, $2B, $2C,	$2D, $2E, $4A, $4B, $4C, $4D, $4E, 0

word_1B7EE:	dc.w 4
	dc.w 2
	dc.w $C6A2
	dc.b $22, $6B, $6C, $6D, $6E, $8A, $8B,	$8C, $8D, $8E, $AA, $AB, $AC, $AD, $AE,	0

word_1B804:	dc.w 7
	dc.w 5
	dc.w $C6A0
	dc.b $21, $E0, $E1, $E2, $E3, $E4, $27,	$28, $41, $E5, $E6, $E7, $E8, $E9, $47,	$48
	dc.b $61, $EA, $EB, $EC, $ED, $EE, $67,	$68, $81, $82, $83, $CE, $CF, $86, $87,	$88
	dc.b $A1, $A2, $A3, $A4, $A5, $A6, $A7,	$A8, $C1, $C2, $C3, $C4, $C5, $C6, $C7,	$C8

word_1B83A:	dc.w 7
	dc.w 5
	dc.b $C6, $A0, $21, $E0, $E1, $E2, $E3,	$E4, $27, $28, $41, $E5, $E6, $E7, $E8,	$E9
	dc.b $47, $48, $61, $EA, $EB, $EC, $ED,	$EE, $67, $68, $6F, $70, $83, $CE, $CF,	$86
	dc.b $14, $15, $8F, $90, $A3, $A4, $A5,	$A6, $34, $35, $AF, $B0, $C3, $C4, $C5,	$C6
	dc.b $54, $55

word_1B870:	dc.w 7
	dc.w 5
	dc.w $C6A0
	dc.b $21, $E0, $E1, $E2, $E3, $E4, $27,	$28, $41, $E5, $E6, $E7, $E8, $E9, $47,	$48
	dc.b $61, $EA, $EB, $EC, $ED, $EE, $67,	$68, $71, $72, $83, $CE, $CF, $86, $74,	$75
	dc.b $91, $92, $A3, $A4, $A5, $A6, $94,	$95, $B1, $B2, $C3, $C4, $C5, $C6, $B4,	$B5

word_1B8A6:	dc.w 6
	dc.w 4
	dc.w $C624
	dc.b $19, $1A, $F, $10,	$11, $12, $13, $39, $3A, $2F, $30, $31,	$32, $33, $59, $5A
	dc.b $4F, $50, $51, $52, $53, $D4, $D5,	$7B, $7C, $7D, $7E, $7F, $F4, $F5, $9B,	$9C
	dc.b $9D, $9E, $9F, 0

word_1B8D0:	dc.w 1
	dc.w 0
	dc.w $C826
	dc.b $84, $85

word_1B8D8:	dc.w 1
	dc.w 0
	dc.w $C826
	dc.b $CA, $CB

word_1B8E0:	dc.w 1
	dc.w 0
	dc.w $C826
	dc.b $CC, $CD

word_1B8E8:	dc.w 1
	dc.w 0
	dc.w $C826
	dc.b $CE, $CF

word_1B8F0:	dc.w 1
	dc.w 0
	dc.w $C826
	dc.b $D0, $D1

word_1B8F8:	dc.w 1
	dc.w 0
	dc.w $C826
	dc.b $D2, $D3

; ---------------------------------------------------------------------------

Panotty_PlaneMaps:
	dc.l word_1B59A
	dc.l word_1B5E6
	dc.l word_1B93C
	dc.l word_1B94C
	dc.l word_1B95C
	dc.l word_1B96E
	dc.l word_1B980
	dc.l word_1B992
	dc.l word_1B9D4
	dc.l word_1BA16
	dc.l word_1BA58
	dc.l word_1BA9A
	dc.l word_1BADC
	dc.l word_1BAF4
	dc.l word_1BB0C

word_1B93C:	dc.w 4
	dc.w 1
	dc.w $C822
	dc.b $AA, $AB, $AC, $AD, $AE, $CA, $CB,	$CC, $CD, $CE

word_1B94C:	dc.w 4
	dc.w 1
	dc.w $C822
	dc.b $EA, $EB, $EC, $ED, $EE, $E5, $E6,	$E7, $E8, $E9

word_1B95C:	dc.w 5
	dc.w 1
	dc.w $C822
	dc.b $E0, $E1, $E2, $E3, $E4, $87, $E5,	$E6, $E7, $E8, $E9, $A7

word_1B96E:	dc.w 5
	dc.w 1
	dc.w $C822
	dc.b $E0, $FA, $FB, $FC, $E4, $87, $E5,	$E6, $E7, $E8, $E9, $A7

word_1B980:	dc.w 5
	dc.w 1
	dc.w $C822
	dc.b $E0, $FD, $FE, $FF, $E4, $87, $E5,	$E6, $E7, $E8, $E9, $A7

word_1B992:	dc.w 9
	dc.w 5
	dc.w $C61E
	dc.b 0,	1, 2, 3, 4, 5, 6, 7, 8,	9, $20,	$21, $22, $23, $24, $25
	dc.b $26, $27, $28, $29, $40, $41, $42,	$EF, $44, $F0, $46, $47, $48, $49, $60,	$61
	dc.b $F1, $F2, $64, $F3, $F4, $67, $68,	$69, $80, $81, $F5, $F6, $F7, $F8, $F9,	$87
	dc.b $88, $89, $A0, $A1, $E5, $E6, $E7,	$E8, $E9, $A7, $A8, $A9

word_1B9D4:	dc.w 9
	dc.w 5
	dc.w $C61E
	dc.b 0,	1, 2, 3, 4, 5, 6, 7, $14, $15, $20, $91, $22, $23, $24,	$25
	dc.b $26, $27, $34, $35, $40, $B1, $42,	$EF, $44, $F0, $46, $47, $54, $55, $60,	$D1
	dc.b $F1, $F2, $64, $F3, $F4, $67, $74,	$75, $80, $81, $F5, $D3, $D4, $D5, $F9,	$87
	dc.b $88, $89, $A0, $A1, $E5, $E6, $E7,	$E8, $E9, $A7, $A8, $A9

word_1BA16:	dc.w 9
	dc.w 5
	dc.w $C61E
	dc.b 0,	1, 2, 3, 4, 5, 6, 7, $14, $15, $20, $90, $22, $23, $24,	$25
	dc.b $26, $27, $12, $13, $50, $51, $42,	$EF, $44, $F0, $46, $47, $32, $33, $70,	$71
	dc.b $F1, $F2, $64, $F3, $F4, $67, $52,	$53, $80, $81, $F5, $F6, $F7, $F8, $F9,	$87
	dc.b $88, $89, $A0, $A1, $E5, $E6, $E7,	$E8, $E9, $A7, $A8, $A9

word_1BA58:	dc.w 9
	dc.w 5
	dc.w $C61E
	dc.b 0,	1, 2, 3, 4, 5, 6, 7, $14, $15, $20, $90, $22, $23, $24,	$25
	dc.b $26, $27, $12, $13, $10, $11, $42,	$EF, $44, $F0, $46, $47, $94, $95, $30,	$31
	dc.b $F1, $F2, $64, $F3, $F4, $67, $B4,	$B5, $80, $81, $F5, $D3, $D4, $D5, $F9,	$87
	dc.b $88, $89, $A0, $A1, $E5, $E6, $E7,	$E8, $E9, $A7, $A8, $A9

word_1BA9A:	dc.w 9
	dc.w 5
	dc.w $C61E
	dc.b 0,	1, 2, 3, 4, 5, 6, 7, $14, $15, $8F, $90, $22, $23, $24,	$25
	dc.b $26, $27, $72, $73, $AF, $B0, $42,	$EF, $44, $F0, $46, $47, $92, $93, $CF,	$D0
	dc.b $F1, $F2, $64, $F3, $F4, $67, $B2,	$B3, $80, $81, $F5, $D3, $D4, $D5, $F9,	$87
	dc.b $88, $89, $A0, $A1, $E5, $E6, $E7,	$E8, $E9, $A7, $A8, $A9

word_1BADC:	dc.w 5
	dc.w 2
	dc.w $C7A0
	dc.b $4C, $4D, $4E, $7A, $7B, $7C, $97,	$98, $99, $9A, $C, $D, $B7, $B8, $B9, $BA
	dc.b $2C, $2D

word_1BAF4:	dc.w 5
	dc.w 2
	dc.w $C7A0
	dc.b $77, $4A, $4B, $7A, $7B, $7C, $97,	$6A, $6B, $A, $B, $9C, $B7, $B8, $B9, $2A
	dc.b $2B, $BC

word_1BB0C:	dc.w 5
	dc.w 2
	dc.w $C7A0
	dc.b $77, $78, $2F, $7A, $7B, $7C, $97,	$98, $4F, $E, $F, $9C, $B7, $B8, $6F, $2E
	dc.b $BB, $BC

; ---------------------------------------------------------------------------

SkeletonT_PlaneMaps:
	dc.l word_1B59A
	dc.l word_1B5E6
	dc.l word_1BB5C
	dc.l word_1BB6E
	dc.l word_1BB80
	dc.l word_1BBA2
	dc.l word_1BBC4
	dc.l word_1BBE6
	dc.l word_1BBF2
	dc.l word_1BBFE
	dc.l word_1BC0A
	dc.l word_1BC16
	dc.l word_1BC22
	dc.l word_1BC2E

word_1BB5C:	dc.w 5
	dc.w 1
	dc.w $C724
	dc.b $43, $44, $45, $46, $47, $48, $63,	$64, $65, $66, $67, $68

word_1BB6E:	dc.w 5
	dc.w 1
	dc.w $C724
	dc.b $43, $44, $45, $46, $B4, $B5, $94,	$95, $65, $66, $67, $68

word_1BB80:	dc.w 6
	dc.w 3
	dc.w $C7A4
	dc.b $63, $64, $65, $66, $14, $15, $34,	$D, $E,	$F, $10, $11, $12, $13,	$2D, $2E
	dc.b $2F, $30, $31, $32, $33, $4D, $4E,	$4F, $50, $51, $52, $53

word_1BBA2:	dc.w 6
	dc.w 3
	dc.w $C7A4
	dc.b $63, $64, $65, $66, $54, $55, $34,	$6D, $6E, $6F, $70, $71, $72, $73, $8D,	$8E
	dc.b $8F, $90, $91, $92, $93, $AD, $AE,	$AF, $B0, $B1, $B2, $B3

word_1BBC4:	dc.w 6
	dc.w 3
	dc.w $C7A4
	dc.b $63, $64, $65, $66, $74, $75, $34,	$CD, $CE, $CF, $D0, $D1, $D2, $D3, $ED,	$EE
	dc.b $EF, $F0, $F1, $F2, $F3, $F7, $F8,	$F9, $FA, $FB, $FC, $FD

word_1BBE6:	dc.w 2
	dc.w 1
	dc.w $C61E
	dc.b 0,	1, 2, $20, $21,	$22

word_1BBF2:	dc.w 2
	dc.w 1
	dc.w $C61E
	dc.b $A, $B, $C, $2A, $2B, $2C

word_1BBFE:	dc.w 2
	dc.w 1
	dc.w $C61E
	dc.b $4A, $4B, $4C, $6A, $6B, $6C

word_1BC0A:	dc.w 2
	dc.w 1
	dc.w $C61E
	dc.b $8A, $8B, $8C, $AA, $AB, $AC

word_1BC16:	dc.w 2
	dc.w 1
	dc.w $C61E
	dc.b $CA, $CB, $CC, $EA, $EB, $EC

word_1BC22:	dc.w 2
	dc.w 1
	dc.w $C61E
	dc.b $E0, $E1, $E2, $E3, $E4, $E5

word_1BC2E:	dc.w 2
	dc.w 1
	dc.w $C61E
	dc.b $E6, $E7, $E8, $F4, $F5, $F6

; ---------------------------------------------------------------------------

Suketoudara_PlaneMaps:
	dc.l word_1B59A
	dc.l word_1B5E6
	dc.l word_1BC66
	dc.l word_1BC76
	dc.l word_1BC86
	dc.l word_1BC96
	dc.l word_1BCAE
	dc.l word_1BCC6
	dc.l word_1BCDE
	dc.l word_1BCEE
	dc.l word_1BD0C

word_1BC66:	dc.w 4
	dc.w 1
	dc.w $C7A0
	dc.b $61, $62, $63, $64, $65, $81, $82,	$83, $84, $85

word_1BC76:	dc.w 4
	dc.w 1
	dc.w $C7A0
	dc.b $A, $B, $C, $D, $E, $2A, $2B, $2C,	$2D, $2E

word_1BC86:	dc.w 4
	dc.w 1
	dc.w $C7A0
	dc.b $4A, $4B, $4C, $4D, $4E, $6A, $6B,	$6C, $6D, $6E

word_1BC96:	dc.w 5
	dc.w 2
	dc.w $C71E
	dc.b $10, $11, $12, $13, $14, $15, $30,	$31, $32, $33, $34, $35, $80, $81, $82,	$83
	dc.b $84, $85

word_1BCAE:	dc.w 5
	dc.w 2
	dc.w $C71E
	dc.b $10, $11, $12, $13, $14, $15, $50,	$51, $52, $53, $54, $55, $70, $71, $72,	$73
	dc.b $74, $75

word_1BCC6:	dc.w 5
	dc.w 2
	dc.w $C71E
	dc.b $10, $11, $12, $13, $14, $15, $90,	$91, $92, $93, $94, $95, $B0, $B1, $B2,	$B3
	dc.b $B4, $B5

word_1BCDE:	dc.w 4
	dc.w 1
	dc.w $C6A0
	dc.b $D0, $D1, $D2, $D3, $D4, $F0, $F1,	$F2, $F3, $F4

word_1BCEE:	dc.w 5
	dc.w 3
	dc.w $C7A0
	dc.b $61, $62, $63, $64, $65, $66, $81,	$82, $83, $84, $85, $86, $A1, $A2, $A3,	$A4
	dc.b $A5, $A6, $C1, $C2, $C3, $C4, $C5,	$C6

word_1BD0C:	dc.w 5
	dc.w 3
	dc.w $C7A0
	dc.b $8A, $8B, $8C, $8D, $8E, $8F, $AA,	$AB, $AC, $AD, $AE, $AF, $CA, $CB, $CC,	$CD
	dc.b $CE, $CF, $EA, $EB, $EC, $ED, $EE,	$EF

; ---------------------------------------------------------------------------

Zombie_PlaneMaps:
	dc.l word_1B59A
	dc.l word_1B5E6
	dc.l word_1BD4A
	dc.l word_1BD5C
	dc.l word_1BD6E
	dc.l word_1BD80
	dc.l word_1BDB8
	dc.l word_1BDC8

word_1BD4A:	dc.w 3
	dc.w 2
	dc.w $C7A6
	dc.b $64, $65, $66, $67, $84, $85, $86,	$87, $A4, $A5, $A6, $A7

word_1BD5C:	dc.w 3
	dc.w 2
	dc.w $C7A6
	dc.b $11, $12, $13, $14, $31, $32, $33,	$34, $51, $52, $53, $54

word_1BD6E:	dc.w 3
	dc.w 2
	dc.w $C7A6
	dc.b $71, $72, $73, $74, $91, $92, $93,	$94, $B1, $B2, $B3, $B4

word_1BD80:	dc.w 6
	dc.w 6
	dc.w $C624
	dc.b $A, $B, $C, $D, $E, $F, $10, $2A, $2B, $2C, $2D, $2E, $2F,	$30, $4A, $4B
	dc.b $4C, $4D, $4E, $4F, $50, $6A, $6B,	$6C, $6D, $6E, $6F, $70, $8A, $8B, $8C,	$8D
	dc.b $8E, $8F, $90, $AA, $AB, $AC, $AD,	$AE, $AF, $B0, $CA, $CB, $CC, $CD, $CE,	$CF
	dc.b $D0, 0

word_1BDB8:	dc.w 2
	dc.w 2
	dc.w $C7A6
	dc.b $6B, $6C, $6D, $8B, $8C, $8D, $AB,	$AC, $AD, 0

word_1BDC8:	dc.w 2
	dc.w 2
	dc.w $C7A6
	dc.b $D1, $D2, $D3, $F1, $F2, $F3, $F4,	$F5, $F6, 0

; ---------------------------------------------------------------------------

Draco_PlaneMaps:
	dc.l word_1B59A
	dc.l word_1B5E6
	dc.l word_1BE1C
	dc.l word_1BE32
	dc.l word_1BE48
	dc.l word_1BE5E
	dc.l word_1BE68
	dc.l word_1BE72
	dc.l word_1BE7C
	dc.l word_1BE86
	dc.l word_1BE90
	dc.l word_1BE9A
	dc.l word_1BEB0
	dc.l word_1BEC6
	dc.l word_1BEDC
	dc.l word_1BEE6
	dc.l word_1BEF0

word_1BE1C:	dc.w 4
	dc.w 2
	dc.w $C6A2
	dc.b $22, $23, $24, $25, $26, $42, $43,	$44, $45, $46, $62, $63, $64, $65, $66,	0

word_1BE32:	dc.w 4
	dc.w 2
	dc.w $C6A2
	dc.b $22, $23, $24, $25, $26, $A, $B, $C, $D, $E, $2A, $2B, $2C, $2D, $2E, 0

word_1BE48:	dc.w 4
	dc.w 2
	dc.w $C6A2
	dc.b $22, $23, $24, $25, $26, $4A, $4B,	$4C, $4D, $4E, $6A, $6B, $6C, $6D, $6E,	0

word_1BE5E:	dc.w 1
	dc.w 1
	dc.w $C824
	dc.b $83, $84, $A3, $A4

word_1BE68:	dc.w 1
	dc.w 1
	dc.w $C824
	dc.b $F, $10, $A3, $A4

word_1BE72:	dc.w 1
	dc.w 1
	dc.w $C824
	dc.b $2F, $30, $A3, $A4

word_1BE7C:	dc.w 1
	dc.w 1
	dc.w $C824
	dc.b $8A, $8B, $A3, $A4

word_1BE86:	dc.w 1
	dc.w 1
	dc.w $C824
	dc.b $AA, $AB, $A3, $A4

word_1BE90:	dc.w 1
	dc.w 1
	dc.w $C824
	dc.b $CA, $CB, $A3, $A4

word_1BE9A:	dc.w 4
	dc.w 2
	dc.w $C6A2
	dc.b $11, $12, $13, $14, $15, $31, $32,	$33, $34, $35, $51, $52, $53, $54, $55,	0

word_1BEB0:	dc.w 4
	dc.w 2
	dc.w $C6A2
	dc.b $71, $72, $73, $74, $75, $91, $92,	$93, $94, $95, $B1, $B2, $B3, $B4, $B5,	0

word_1BEC6:	dc.w 4
	dc.w 2
	dc.w $C6A2
	dc.b $71, $72, $73, $74, $75, $D1, $D2,	$D3, $D4, $D5, $6A, $6B, $6C, $6D, $6E,	0

word_1BEDC:	dc.w 1
	dc.w 1
	dc.w $C824
	dc.b $8C, $8D, $A3, $A4

word_1BEE6:	dc.w 1
	dc.w 1
	dc.w $C824
	dc.b $AC, $AD, $A3, $A4

word_1BEF0:	dc.w 1
	dc.w 1
	dc.w $C824
	dc.b $CC, $CD, $EC, $ED

; ---------------------------------------------------------------------------

NasuGrave_PlaneMaps:
	dc.l word_1B59A
	dc.l word_1B5E6
	dc.l word_1BF22
	dc.l word_1BF5E
	dc.l word_1BF9A
	dc.l word_1BFB8
	dc.l word_1C018
	dc.l word_1BFD6
	dc.l word_1BFEC
	dc.l word_1C002

word_1BF22:	dc.w 8
	dc.w 5
	dc.w $C6A0
	dc.b $21, $22, $23, $24, $25, $26, $27,	$28, $29, $41, $42, $43, $44, $45, $46,	$47
	dc.b $48, $49, $61, $62, $63, $64, $65,	$66, $67, $68, $69, $81, $82, $83, $84,	$85
	dc.b $86, $87, $88, $89, $A1, $A2, $A3,	$A4, $A5, $A6, $A7, $A8, $A9, $C1, $C2,	$C3
	dc.b $C4, $C5, $C6, $C7, $C8, $C9

word_1BF5E:	dc.w 8
	dc.w 5
	dc.w $C6A0
	dc.b $10, $11, $12, $24, $25, $26, $27,	$28, $29, $30, $31, $32, $44, $45, $46,	$47
	dc.b $48, $49, $50, $51, $63, $64, $65,	$66, $13, $14, $15, $70, $71, $83, $84,	$85
	dc.b $86, $33, $34, $35, $A1, $A2, $A3,	$A4, $A5, $52, $53, $54, $55, $C1, $C2,	$C3
	dc.b $C4, $C5, $72, $73, $74, $75

word_1BF9A:	dc.w 5
	dc.w 3
	dc.w $C6A2
	dc.b $22, $E0, $E1, $25, $26, $27, $A, $B, $C, $D, $E, $F, $2A,	$2B, $2C, $2D
	dc.b $2E, $2F, $82, $83, $84, $4D, $4E,	$4F

word_1BFB8:	dc.w 5
	dc.w 3
	dc.w $C6A2
	dc.b $4A, $4B, $4C, $25, $26, $27, $6A,	$6B, $6C, $6D, $6E, $6F, $8A, $8B, $8C,	$8D
	dc.b $8E, $8F, $AA, $AB, $AC, $AD, $AE,	$AF

word_1BFD6:	dc.w 3
	dc.w 3
	dc.w $C724
	dc.b $90, $91, $92, $93, $CA, $CB, $CC,	$CD, $EA, $EB, $EC, $ED, $F0, $F1, $F2,	$F3

word_1BFEC:	dc.w 3
	dc.w 3
	dc.w $C724
	dc.b $5B, $5C, $5D, $5E, $7B, $7C, $7D,	$7E, $9B, $9C, $9D, $9E, $BB, $BC, $BD,	$BE

word_1C002:	dc.w 3
	dc.w 3
	dc.w $C724
	dc.b $90, $91, $92, $93, $B0, $B1, $B2,	$B3, $D0, $D1, $D2, $D3, $F0, $F1, $F2,	$F3

word_1C018:	dc.w 9
	dc.w 6
	dc.w $C61E
	dc.b $16, $17, $18, $19, $1A, $1B, $1C,	$1D, $1E, $1F, $36, $37, $38, $39, $3A,	$3B
	dc.b $3C, $3D, $3E, $3F, $56, $37, $37,	$57, $58, $59, $5A, $37, $37, $5F, $76,	$37
	dc.b $37, $77, $78, $79, $7A, $37, $37,	$7F, $96, $37, $37, $97, $98, $99, $9A,	$37
	dc.b $37, $9F, $B6, $37, $37, $B7, $B8,	$B9, $BA, $37, $37, $BF, $D6, $D7, $D8,	$D9
	dc.b $DA, $DB, $DC, $DD, $DE, $DF

; ---------------------------------------------------------------------------

Witch_PlaneMaps:
	dc.l word_1B59A
	dc.l word_1B5E6
	dc.l word_1C0A8
	dc.l word_1C0C0
	dc.l word_1C0D8
	dc.l word_1C0F0
	dc.l word_1C0F8
	dc.l word_1C100
	dc.l word_1C108
	dc.l word_1C11A
	dc.l word_1C12C
	dc.l word_1C13E
	dc.l word_1C146
	dc.l word_1C14E
	dc.l word_1C156
	dc.l word_1C15E
	dc.l word_1C166

word_1C0A8:	dc.w 5
	dc.w 2
	dc.w $C6A2
	dc.b $22, $23, $24, $25, $26, $27, $42,	$43, $44, $45, $46, $47, $62, $63, $64,	$65
	dc.b $66, $67

word_1C0C0:	dc.w 5
	dc.w 2
	dc.w $C6A2
	dc.b $A, $B, $C, $D, $E, $F, $2A, $2B, $2C, $2D, $2E, $2F, $4A,	$4B, $4C, $4D
	dc.b $4E, $4F

word_1C0D8:	dc.w 5
	dc.w 2
	dc.w $C6A2
	dc.b $6A, $6B, $6C, $6D, $6E, $6F, $8A,	$8B, $8C, $8D, $8E, $8F, $AA, $AB, $AC,	$AD
	dc.b $AE, $AF

word_1C0F0:	dc.w 1
	dc.w 0
	dc.w $C826
	dc.b $84, $85

word_1C0F8:	dc.w 1
	dc.w 0
	dc.w $C826
	dc.b $CA, $CB

word_1C100:	dc.w 1
	dc.w 0
	dc.w $C826
	dc.b $EA, $EB

word_1C108:	dc.w 5
	dc.w 1
	dc.w $C722
	dc.b $10, $11, $12, $13, $14, $15, $30,	$31, $32, $33, $34, $35

word_1C11A:	dc.w 5
	dc.w 1
	dc.w $C722
	dc.b $50, $51, $52, $53, $54, $55, $70,	$71, $72, $73, $74, $75

word_1C12C:	dc.w 5
	dc.w 1
	dc.w $C722
	dc.b $90, $91, $92, $93, $94, $95, $AA,	$AB, $AC, $AD, $AE, $AF

word_1C13E:	dc.w 1
	dc.w 0
	dc.w $C826
	dc.b $B0, $B1

word_1C146:	dc.w 1
	dc.w 0
	dc.w $C826
	dc.b $D0, $D1

word_1C14E:	dc.w 1
	dc.w 0
	dc.w $C826
	dc.b $F0, $F1

word_1C156:	dc.w 1
	dc.w 0
	dc.w $C826
	dc.b $B2, $B3

word_1C15E:	dc.w 1
	dc.w 0
	dc.w $C826
	dc.b $D2, $D3

word_1C166:	dc.w 1
	dc.w 0
	dc.w $C826
	dc.b $F2, $F3

; ---------------------------------------------------------------------------

Sasoriman_PlaneMaps:
	dc.l word_1B59A
	dc.l word_1B5E6
	dc.l word_1C18E
	dc.l word_1C1A6
	dc.l word_1C1BE
	dc.l word_1C1D6
	dc.l word_1C1F8
	dc.l word_1C210

word_1C18E:	dc.w 5
	dc.w 2
	dc.w $C7A0
	dc.b $61, $62, $63, $64, $65, $66, $81,	$82, $83, $84, $85, $86, $A1, $A2, $A3,	$A4
	dc.b $A5, $A6

word_1C1A6:	dc.w 5
	dc.w 2
	dc.w $C7A0
	dc.b $A, $B, $C, $D, $E, $F, $2A, $2B, $2C, $2D, $2E, $2F, $4A,	$4B, $4C, $4D
	dc.b $4E, $4F

word_1C1BE:	dc.w 5
	dc.w 2
	dc.w $C7A0
	dc.b $A, $B, $C, $D, $E, $F, $6A, $6B, $6C, $6D, $6E, $6F, $8A,	$8B, $8C, $8D
	dc.b $8E, $8F

word_1C1D6:	dc.w 6
	dc.w 3
	dc.w $C7A0
	dc.b $10, $11, $12, $13, $14, $15, $90,	$30, $31, $32, $33, $34, $35, $B0, $50,	$51
	dc.b $52, $53, $54, $55, $D0, $70, $71,	$72, $73, $74, $75, $F0

word_1C1F8:	dc.w 5
	dc.w 2
	dc.w $C7A0
	dc.b $AA, $AB, $AC, $AD, $AE, $AF, $CA,	$CB, $CC, $CD, $CE, $CF, $EA, $EB, $EC,	$ED
	dc.b $EE, $EF

word_1C210:	dc.w 5
	dc.w 2
	dc.w $C7A0
	dc.b $AA, $AB, $AC, $AD, $AE, $AF, $6A,	$6B, $6C, $6D, $6E, $6F, $8A, $8B, $8C,	$8D
	dc.b $8E, $8F

; ---------------------------------------------------------------------------

Harpy_PlaneMaps:
	dc.l word_1B59A
	dc.l word_1B5E6
	dc.l word_1C260
	dc.l word_1C272
	dc.l word_1C284
	dc.l word_1C296
	dc.l word_1C2A2
	dc.l word_1C2AE
	dc.l word_1C2BA
	dc.l word_1C2C6
	dc.l word_1C2D2
	dc.l word_1C2DE
	dc.l word_1C2F0
	dc.l word_1C302

word_1C260:	dc.w 5
	dc.w 1
	dc.w $C724
	dc.b $43, $44, $45, $46, $47, $48, $63,	$64, $65, $66, $67, $68

word_1C272:	dc.w 5
	dc.w 1
	dc.w $C724
	dc.b $A, $B, $C, $D, $E, $F, $2A, $2B, $2C, $2D, $2E, $2F

word_1C284:	dc.w 5
	dc.w 1
	dc.w $C724
	dc.b $4A, $4B, $4C, $4D, $4E, $4F, $6A,	$6B, $6C, $6D, $6E, $6F

word_1C296:	dc.w 2
	dc.w 1
	dc.w $C826
	dc.b $84, $85, $86, $A4, $A5, $A6

word_1C2A2:	dc.w 2
	dc.w 1
	dc.w $C826
	dc.b $10, $11, $12, $30, $31, $32

word_1C2AE:	dc.w 2
	dc.w 1
	dc.w $C826
	dc.b $50, $51, $52, $70, $71, $72

word_1C2BA:	dc.w 2
	dc.w 1
	dc.w $C826
	dc.b $13, $14, $15, $33, $34, $35

word_1C2C6:	dc.w 2
	dc.w 1
	dc.w $C826
	dc.b $53, $54, $55, $73, $74, $75

word_1C2D2:	dc.w 2
	dc.w 1
	dc.w $C826
	dc.b $93, $94, $95, $B3, $B4, $B5

word_1C2DE:	dc.w 5
	dc.w 1
	dc.w $C724
	dc.b $8A, $8B, $8C, $8D, $8E, $8F, $AA,	$AB, $AC, $AD, $AE, $AF

word_1C2F0:	dc.w 5
	dc.w 1
	dc.w $C724
	dc.b $CA, $CB, $CC, $CD, $CE, $CF, $2A,	$2B, $2C, $2D, $2E, $2F

word_1C302:	dc.w 5
	dc.w 1
	dc.w $C724
	dc.b $EA, $EB, $EC, $ED, $EE, $EF, $6A,	$6B, $6C, $6D, $6E, $6F

; ---------------------------------------------------------------------------

ZohDaimaoh_PlaneMaps:
	dc.l word_1B59A
	dc.l word_1B5E6
	dc.l word_1C340
	dc.l word_1C35E
	dc.l word_1C37C
	dc.l word_1C39A
	dc.l word_1C3C4
	dc.l word_1C3EE
	dc.l word_1C418
	dc.l word_1C44E
	dc.l word_1C484

word_1C340:	dc.w 5
	dc.w 3
	dc.w $C6A2
	dc.b $22, $23, $24, $25, $26, $27, $42,	$43, $44, $45, $46, $47, $62, $63, $64,	$65
	dc.b $66, $67, $82, $83, $84, $85, $86,	$87

word_1C35E:	dc.w 5
	dc.w 3
	dc.w $C6A2
	dc.b $22, $23, $24, $C,	$D, $E,	$42, $43, $44, $2C, $2D, $2E, $A, $B, $64, $4C
	dc.b $4D, $4E, $2A, $2B, $84, $85, $86,	$87

word_1C37C:	dc.w 5
	dc.w 3
	dc.w $C6A2
	dc.b $22, $23, $24, $6C, $6D, $6E, $42,	$43, $44, $8C, $8D, $8E, $4A, $4B, $64,	$AC
	dc.b $AD, $AE, $6A, $6B, $84, $85, $86,	$87

word_1C39A:	dc.w 6
	dc.w 4
	dc.w $C71E
	dc.b $40, $41, $42, $43, $44, $45, $46,	$60, $61, $62, $63, $64, $65, $66, $80,	$81
	dc.b $82, $83, $84, $85, $86, $A0, $A1,	$A2, $A3, $A4, $A5, $A6, $C0, $C1, $C2,	$C3
	dc.b $C4, $C5, $C6, 0

word_1C3C4:	dc.w 6
	dc.w 4
	dc.w $C71E
	dc.b $40, $41, $42, $43, $44, $45, $46,	$F, $10, $11, $12, $13,	$14, $15, $2F, $30
	dc.b $31, $32, $33, $34, $35, $4F, $50,	$51, $52, $53, $54, $55, $6F, $70, $71,	$72
	dc.b $73, $74, $75, 0

word_1C3EE:	dc.w 6
	dc.w 4
	dc.w $C71E
	dc.b $8F, $90, $91, $92, $93, $94, $95,	$AF, $B0, $B1, $B2, $B3, $B4, $B5, $CF,	$D0
	dc.b $D1, $D2, $D3, $D4, $D5, $EF, $F0,	$F1, $F2, $F3, $F4, $F5, $F6, $F7, $F8,	$F9
	dc.b $FA, $FB, $FC, 0

word_1C418:	dc.w 7
	dc.w 5
	dc.w $C69E
	dc.b $20, $21, $22, $23, $24, $6C, $6D,	$6E, $40, $41, $42, $43, $8A, $8B, $8D,	$8E
	dc.b $60, $61, $62, $63, $AA, $AB, $AD,	$AE, $80, $81, $82, $83, $84, $85, $86,	$87
	dc.b $A0, $A1, $A2, $A3, $A4, $A5, $A6,	$A7, $C0, $C1, $C2, $C3, $C4, $C5, $C6,	$C7

word_1C44E:	dc.w 7
	dc.w 5
	dc.w $C69E
	dc.b $20, $21, $22, $23, $24, $6C, $6D,	$6E, $40, $41, $42, $43, $8A, $8B, $8D,	$8E
	dc.b $F, $10, $11, $12,	$AA, $AB, $AD, $AE, $2F, $30, $31, $32,	$33, $34, $35, $87
	dc.b $4F, $50, $51, $52, $53, $54, $55,	$A7, $6F, $70, $71, $72, $73, $74, $75,	$C7

word_1C484:	dc.w 7
	dc.w 5
	dc.w $C69E
	dc.b $20, $21, $22, $23, $24, $6C, $6D,	$6E, $8F, $90, $91, $92, $8A, $8B, $8D,	$8E
	dc.b $AF, $B0, $B1, $B2, $AA, $AB, $AD,	$AE, $CF, $D0, $D1, $D2, $D3, $D4, $D5,	$87
	dc.b $EF, $F0, $F1, $F2, $F3, $F4, $F5,	$A7, $F6, $F7, $F8, $F9, $FA, $FB, $FC,	$C7

; ---------------------------------------------------------------------------

Schezo_PlaneMaps:
	dc.l word_1B59A
	dc.l word_1B5E6
	dc.l word_1C50E
	dc.l word_1C524
	dc.l word_1C53A
	dc.l word_1C550
	dc.l word_1C566
	dc.l word_1C57C
	dc.l word_1C592
	dc.l word_1C5A8
	dc.l word_1C5BE
	dc.l word_1C5D4
	dc.l word_1C5DE
	dc.l word_1C5E8
	dc.l word_1C5F2
	dc.l word_1C5FC
	dc.l word_1C606
	dc.l word_1C610
	dc.l word_1C61A
	dc.l word_1C624
	dc.l word_1C62E

word_1C50E:	dc.w 4
	dc.w 2
	dc.w $C6A2
	dc.b $22, $23, $24, $25, $26, $42, $43,	$44, $45, $46, $62, $63, $64, $65, $66,	0

word_1C524:	dc.w 4
	dc.w 2
	dc.w $C6A2
	dc.b $A, $B, $C, $D, $E, $2A, $2B, $2C,	$2D, $2E, $4A, $4B, $4C, $65, $66, 0

word_1C53A:	dc.w 4
	dc.w 2
	dc.w $C6A2
	dc.b $A, $B, $C, $D, $E, $6A, $6B, $6C,	$6D, $6E, $8A, $8B, $8C, $65, $66, 0

word_1C550:	dc.w 4
	dc.w 2
	dc.w $C6A2
	dc.b $F, $10, $11, $12,	$13, $2F, $30, $31, $32, $33, $4F, $50,	$51, $14, $15, 0

word_1C566:	dc.w 4
	dc.w 2
	dc.w $C6A2
	dc.b $6F, $70, $71, $72, $73, $8F, $90,	$91, $92, $93, $AF, $B0, $B1, $14, $15,	0

word_1C57C:	dc.w 4
	dc.w 2
	dc.w $C6A2
	dc.b $6F, $70, $71, $72, $73, $CF, $D0,	$D1, $D2, $D3, $EF, $F0, $F1, $14, $15,	0

word_1C592:	dc.w 4
	dc.w 2
	dc.w $C6A2
	dc.b $F, $10, $11, $12,	$13, $2F, $30, $31, $32, $33, $4F, $50,	$51, $D4, $D5, 0

word_1C5A8:	dc.w 4
	dc.w 2
	dc.w $C6A2
	dc.b $6F, $70, $71, $72, $73, $8F, $90,	$91, $92, $93, $AF, $B0, $B1, $D4, $D5,	0

word_1C5BE:	dc.w 4
	dc.w 2
	dc.w $C6A2
	dc.b $6F, $70, $71, $72, $73, $CF, $D0,	$D1, $D2, $D3, $EF, $F0, $F1, $D4, $D5,	0

word_1C5D4:	dc.w 1
	dc.w 1
	dc.w $C7A8
	dc.b $65, $66, $85, $86

word_1C5DE:	dc.w 1
	dc.w 1
	dc.w $C7A8
	dc.b $AA, $AB, $CA, $CB

word_1C5E8:	dc.w 1
	dc.w 1
	dc.w $C7A8
	dc.b $AC, $AD, $CC, $CD

word_1C5F2:	dc.w 1
	dc.w 1
	dc.w $C7A8
	dc.b $14, $15, $34, $35

word_1C5FC:	dc.w 1
	dc.w 1
	dc.w $C7A8
	dc.b $54, $55, $74, $75

word_1C606:	dc.w 1
	dc.w 1
	dc.w $C7A8
	dc.b $94, $95, $B4, $B5

word_1C610:	dc.w 1
	dc.w 1
	dc.w $C7A8
	dc.b $D4, $D5, $F4, $F5

word_1C61A:	dc.w 2
	dc.w 0
	dc.w $C7A6
	dc.b $7A, $7B, $7C, 0

word_1C624:	dc.w 2
	dc.w 0
	dc.w $C7A6
	dc.b $E0, $E1, $E2, 0

word_1C62E:	dc.w 2
	dc.w 0
	dc.w $C7A6
	dc.b $E3, $E4, $E5, 0

; ---------------------------------------------------------------------------

Minotauros_PlaneMaps:
	dc.l word_1B59A
	dc.l word_1B5E6
	dc.l word_1C660
	dc.l word_1C66C
	dc.l word_1C678
	dc.l word_1C684
	dc.l word_1C690
	dc.l word_1C6AA
	dc.l word_1C6E6
	dc.l word_1C6FC

word_1C660:	dc.w 1
	dc.w 2
	dc.w $C6AC
	dc.b $27, $28, $47, $48, $67, $68

word_1C66C:	dc.w 1
	dc.w 2
	dc.w $C6AC
	dc.b $A, $B, $2A, $2B, $4A, $4B

word_1C678:	dc.w 1
	dc.w 2
	dc.w $C6AC
	dc.b $C, $D, $2C, $2D, $4C, $4D

word_1C684:	dc.w 1
	dc.w 2
	dc.w $C6AC
	dc.b $E, $F, $2E, $2F, $4E, $4F

word_1C690:	dc.w 4
	dc.w 3
	dc.w $C7A8
	dc.b $6A, $6B, $6C, $6D, $6E, $8A, $8B,	$8C, $8D, $8E, $AA, $AB, $AC, $AD, $AE,	$CA
	dc.b $CB, $CC, $CD, $CE

word_1C6AA:	dc.w 8
	dc.w 5
	dc.w $C620
	dc.b 1,	2, 3, 4, 5, 6, 7, $13, $14, $21, $22, $23, $24,	$25, $26, $27
	dc.b $33, $34, $41, $42, $43, $44, $45,	$46, $47, $53, $54, $61, $62, $63, $64,	$65
	dc.b $66, $67, $68, $69, $10, $11, $12,	$84, $85, $86, $87, $88, $89, $30, $31,	$32
	dc.b $A4, $A5, $A6, $A7, $A8, $A9

word_1C6E6:	dc.w 3
	dc.w 3
	dc.w $C72A
	dc.b $46, $2E, $2F, $49, $66, $4E, $4F,	$69, $86, $87, $88, $89, $A6, $A7, $A8,	$A9

word_1C6FC:	dc.w 3
	dc.w 3
	dc.w $C72A
	dc.b $46, $2E, $71, $72, $66, $4E, $91,	$92, $AF, $B0, $B1, $B2, $CF, $D0, $D1,	$D2

; ---------------------------------------------------------------------------

Rulue_PlaneMaps:
	dc.l word_1B59A
	dc.l word_1B5E6
	dc.l word_1C756
	dc.l word_1C76E
	dc.l word_1C786
	dc.l word_1C79E
	dc.l word_1C7B6
	dc.l word_1C7CE
	dc.l word_1C7E6
	dc.l word_1C7F0
	dc.l word_1C7FA
	dc.l word_1C804
	dc.l word_1C80E
	dc.l word_1C818
	dc.l word_1C822
	dc.l word_1C82E
	dc.l word_1C83A

word_1C756:	dc.w 5
	dc.w 2
	dc.w $C6A2
	dc.b $22, $23, $24, $25, $26, $27, $42,	$43, $44, $45, $46, $47, $62, $63, $64,	$65
	dc.b $66, $67

word_1C76E:	dc.w 5
	dc.w 2
	dc.w $C6A2
	dc.b $A, $B, $C, $D, $E, $F, $2A, $2B, $2C, $2D, $2E, $2F, $4A,	$4B, $4C, $4D
	dc.b $4E, $4F

word_1C786:	dc.w 5
	dc.w 2
	dc.w $C6A2
	dc.b $A, $B, $C, $D, $E, $F, $6A, $6B, $6C, $6D, $6E, $6F, $8A,	$8B, $8C, $8D
	dc.b $8E, $8F

word_1C79E:	dc.w 5
	dc.w 2
	dc.w $C6A2
	dc.b $10, $11, $12, $13, $14, $15, $30,	$31, $32, $33, $34, $35, $50, $51, $52,	$53
	dc.b $54, $55

word_1C7B6:	dc.w 5
	dc.w 2
	dc.w $C6A2
	dc.b $10, $11, $12, $13, $14, $15, $70,	$71, $72, $73, $74, $75, $4A, $4B, $4C,	$4D
	dc.b $4E, $4F

word_1C7CE:	dc.w 5
	dc.w 2
	dc.w $C6A2
	dc.b $10, $11, $12, $13, $14, $15, $90,	$91, $92, $93, $94, $95, $8A, $8B, $8C,	$8D
	dc.b $8E, $8F

word_1C7E6:	dc.w 1
	dc.w 1
	dc.w $C7A4
	dc.b $63, $64, $83, $84

word_1C7F0:	dc.w 1
	dc.w 1
	dc.w $C7A4
	dc.b $63, $64, $AA, $AB

word_1C7FA:	dc.w 1
	dc.w 1
	dc.w $C7A4
	dc.b $CA, $CB, $EA, $EB

word_1C804:	dc.w 1
	dc.w 1
	dc.w $C7A4
	dc.b $51, $52, $AC, $AD

word_1C80E:	dc.w 1
	dc.w 1
	dc.w $C7A4
	dc.b $51, $52, $AE, $AF

word_1C818:	dc.w 1
	dc.w 1
	dc.w $C7A4
	dc.b $CE, $CF, $EE, $EF

word_1C822:	dc.w 2
	dc.w 1
	dc.w $C7A4
	dc.b $51, $52, $53, $CC, $CD, $85

word_1C82E:	dc.w 2
	dc.w 1
	dc.w $C7A4
	dc.b $51, $52, $53, $B0, $B1, $B2

word_1C83A:	dc.w 2
	dc.w 1
	dc.w $C7A4
	dc.b $D0, $D1, $D2, $F0, $F1, $F2

; ---------------------------------------------------------------------------

Satan_PlaneMaps:
	dc.l word_1B59A
	dc.l word_1B5E6
	dc.l word_1C88A
	dc.l word_1C89C
	dc.l word_1C8AE
	dc.l word_1C8C0
	dc.l word_1C8CC
	dc.l word_1C8D8
	dc.l word_1C8E4
	dc.l word_1C8F0
	dc.l word_1C8FC
	dc.l word_1C908
	dc.l word_1C914
	dc.l word_1C920
	dc.l word_1C92C
	dc.l word_1C93C
	dc.l word_1C94C

word_1C88A:	dc.w 5
	dc.w 1
	dc.w $C722
	dc.b $42, $43, $44, $45, $46, $47, $62,	$63, $64, $65, $66, $67

word_1C89C:	dc.w 5
	dc.w 1
	dc.w $C722
	dc.b $A, $B, $C, $D, $E, $F, $2A, $2B, $2C, $2D, $2E, $2F

word_1C8AE:	dc.w 5
	dc.w 1
	dc.w $C722
	dc.b $4A, $4B, $4C, $4D, $4E, $4F, $6A,	$6B, $6C, $6D, $6E, $6F

word_1C8C0:	dc.w 2
	dc.w 1
	dc.w $C824
	dc.b $83, $84, $85, $A3, $A4, $A5

word_1C8CC:	dc.w 2
	dc.w 1
	dc.w $C824
	dc.b $8A, $8B, $8C, $AA, $AB, $AC

word_1C8D8:	dc.w 2
	dc.w 1
	dc.w $C824
	dc.b $8D, $8E, $8F, $AD, $AE, $AF

word_1C8E4:	dc.w 2
	dc.w 1
	dc.w $C824
	dc.b $10, $11, $12, $30, $31, $32

word_1C8F0:	dc.w 2
	dc.w 1
	dc.w $C824
	dc.b $50, $51, $52, $70, $71, $72

word_1C8FC:	dc.w 2
	dc.w 1
	dc.w $C824
	dc.b $90, $91, $92, $B0, $B1, $B2

word_1C908:	dc.w 2
	dc.w 1
	dc.w $C824
	dc.b $13, $14, $15, $33, $34, $35

word_1C914:	dc.w 2
	dc.w 1
	dc.w $C824
	dc.b $53, $54, $55, $73, $74, $75

word_1C920:	dc.w 2
	dc.w 1
	dc.w $C824
	dc.b $93, $94, $95, $B3, $B4, $B5

word_1C92C:	dc.w 4
	dc.w 1
	dc.w $C7A4
	dc.b $79, $7A, $7B, $7C, $7D, $99, $9A,	$9B, $9C, $9D

word_1C93C:	dc.w 4
	dc.w 1
	dc.w $C7A4
	dc.b $CA, $CB, $CC, $CD, $CE, $EA, $EB,	$EC, $ED, $EE

word_1C94C:	dc.w 4
	dc.w 1
	dc.w $C7A4
	dc.b $CF, $D0, $D1, $D2, $D3, $EF, $F0,	$F1, $F2, $F3	

; ---------------------------------------------------------------------------

PlaneCmdLists: 		; List of Plane Mappings (uncompressed)
	dc.l word_1D3BE ; 0 =  
	dc.l word_1D54A ; 1 = 
	dc.l word_1D630 ; 2 = 

	; PUYO PUYO SCENARIO MODE PLANE MAPPINGS
	dc.l Grass_Maps ; 3 = SCENARIO / VS / TUTORIAL BG 1
	dc.l Exercise_Maps ; 4 = 
	dc.l Stone_Maps ; 5 = STONE (PUYO)
	dc.l word_1D052 ; 6 = 
	dc.l word_1D010 ; 7 = 
	dc.l word_1D002 ; 8 = 
	dc.l word_1CFA8 ; 9 = 
	dc.l word_1CF04 ; 10 = 
	dc.l word_1CF96 ; 11 = 
	dc.l word_1CAD4 ; 12 = 
	dc.l word_1CB16 ; 13 = 
	dc.l word_1CB58 ; 14 = 
	dc.l word_1CB9A ; 15 = 
	dc.l word_1CBDC ; 16 = 
	dc.l word_1CBFE ; 17 = 
	dc.l word_1CC20 ; 18 = Game Over Continue Text?
	dc.l word_1CCDE ; 19 = Something else Game Over related
	dc.l word_1D02A ; 20 = 

	; EXTRA GAME MODE MAPPINGS
	dc.l Tutorial_Maps 		; 21 = 
	dc.l Exercise_Maps		; 22 = EXERCISE
	dc.l Versus_GameOver_Maps	; 23 = VS (during Game Over)
	dc.l Versus_Maps 		; 24 = 

	; THESE SLOTS CAN BE USED FOR EXTRA BATTLE BOARDS/PLANE MAPS
	dc.l 0 			; 25 = 
	dc.l 0 			; 26 = 
	dc.l 0 			; 27 = 
	dc.l 0 			; 28 = 
	dc.l 0 			; 29 = 
	dc.l word_1D044 ; 30 = 
	dc.l Puyo_MainMenu_Maps ; 31 = 
	dc.l word_1CE8C ; 32 = 
	dc.l word_1CE8C ; 33 = 
	dc.l word_1CE8C ; 34 = 
	dc.l word_1CE62 ; 35 = 
	dc.l word_1CA36 ; 36 = 
	dc.l CreditsSky_Maps ; 37 = 
	dc.l 0 			; 38 = 
	dc.l 0 			; 39 = 
	dc.l 0 			; 40 = 
	dc.l 0 			; 41 = 
	dc.l TutorialBox_Maps ; 42 = TUTORIAL BG 2
	dc.l word_1CE54 ; 43 = 
	dc.l word_1D34E ; 44 = 
	dc.l word_1D358 ; 45 = 
	dc.l word_1D37A ; 46 = 
	dc.l word_1D39C ; 47 = 
	dc.l word_1D540 ; 48 = 
	dc.l word_1D630 ; 49 = 

; ===========================================================================

	include "resource/mapunc/Boards/MiscBoardData.asm"
	even

; ---------------------------------------------------------------------------
;	Battle Board Mappings (inc. Tutorial)

	include "resource/mapunc/Boards/Grass/GrassMaps.asm"
	even

	include "resource/mapunc/Boards/Stone/StoneMaps.asm"
	even

	include "resource/mapunc/Boards/Tutorial/TutorialMaps.asm"
	even

	include "resource/mapunc/Boards/Tutorial/TutorialMaps (Box).asm"
	even

	include "resource/mapunc/Boards/Exercise/ExerciseMaps.asm"
	even

	include "resource/mapunc/Boards/Versus/VersusMaps.asm"
	even

	include "resource/mapunc/Boards/Versus/VersusMaps (Game Over).asm"
	even

; ---------------------------------------------------------------------------
;	These are either the practice or versus stage maps from Puyo Puyo. They're unreferenced.
	include "resource/mapunc/Puyo/Plane Maps/PracticeMaps.asm"
	even

; ===========================================================================
; ===========================================================================

CreditsSky_Maps:	dc.w 1
	dc.l word_1CA2A

word_1CA2A:	dc.w $14
	dc.b $28
	dc.b $B
	dc.w $D200
	dc.l MapEni_CreditsSky
	dc.w $2000

; ===========================================================================

word_1CA36:	dc.w 2
	dc.l word_1CA40
	dc.l word_1CA4C

word_1CA40:	dc.w 4
	dc.b $A
	dc.b 7
	dc.w $D688
	dc.l byte_1CA58
	dc.w $8100

word_1CA4C:	dc.w 4
	dc.b $12
	dc.b 3
	dc.w $D722
	dc.l byte_1CA9E
	dc.w $8100

byte_1CA58:
	dc.b	0, 0, 0, 0, 0, 0, 0, 0, $E, $F
	dc.b	0, 0, 0, 0, 0, 0, 0, $18, $19, $1A
	dc.b	0, 0, 0, 0, 0, 0, 0, $25, $26, $27
	dc.b	0, 0, 0, 0, 0, 0, 0, $33, $34, $27
	dc.b	0, 0, 0, 0, 0, 0, $43, $44, $45, $27
	dc.b	0, 0, 0, 0, 0, $55, $56, $57, $58, $59
	dc.b	0, 0, 0, 0, 0, $6C, $6D, $6E, $6F, $70

byte_1CA9E:
	dc.b	$1E, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b	0, 0, 0, 0, 0, 0, $1F, $20, $21

	dc.b	$2A, $2B, 0, 0, 0, 0, 0, 0, 0
	dc.b	0, 0, 0, 0, 0, $2C, $2D, $2E, $2F

	dc.b	$38, $39, 0, 0, 0, 0, 0, 0, 0
	dc.b	0, 0, 0, 0, $3A, $3B, $3C, $3D, $17

; ===========================================================================

word_1CAD4:	dc.w 4
	dc.l word_1CAE6
	dc.l word_1CAF2
	dc.l word_1CAFE
	dc.l word_1CB0A

word_1CAE6:	dc.w $14
	dc.b $18
	dc.b 3
	dc.w $C912
	dc.l byte_22172
	dc.w $E190

word_1CAF2:	dc.w $14
	dc.b $18
	dc.b 3
	dc.w $CC12
	dc.l byte_22202
	dc.w $8190

word_1CAFE:	dc.w $14
	dc.b $19
	dc.b 3
	dc.w $CF10
	dc.l byte_22292
	dc.w $8190

word_1CB0A:	dc.w $14
	dc.b $E
	dc.b 3
	dc.w $D210
	dc.l byte_22328
	dc.w $8190

; ---------------------------------------------------------------------------

word_1CB16:	dc.w 4
	dc.l word_1CB28
	dc.l word_1CB34
	dc.l word_1CB40
	dc.l word_1CB4C

word_1CB28:	dc.w $14
	dc.b $18
	dc.b 3
	dc.w $C912
	dc.l byte_22172
	dc.w $8190

word_1CB34:	dc.w $14
	dc.b $18
	dc.b 3
	dc.w $CC12
	dc.l byte_22202
	dc.w $E190

word_1CB40:	dc.w $14
	dc.b $19
	dc.b 3
	dc.w $CF10
	dc.l byte_22292
	dc.w $8190

word_1CB4C:	dc.w $14
	dc.b $E
	dc.b 3
	dc.w $D210
	dc.l byte_22328
	dc.w $8190

; ---------------------------------------------------------------------------

word_1CB58:	dc.w 4
	dc.l word_1CB6A
	dc.l word_1CB76
	dc.l word_1CB82
	dc.l word_1CB8E

word_1CB6A:	dc.w $14
	dc.b $18
	dc.b 3
	dc.w $C912
	dc.l byte_22172
	dc.w $8190

word_1CB76:	dc.w $14
	dc.b $18
	dc.b 3
	dc.w $CC12
	dc.l byte_22202
	dc.w $8190

word_1CB82:	dc.w $14
	dc.b $19
	dc.b 3
	dc.w $CF10
	dc.l byte_22292
	dc.w $E190

word_1CB8E:	dc.w $14
	dc.b $E
	dc.b 3
	dc.w $D210
	dc.l byte_22328
	dc.w $8190

; ---------------------------------------------------------------------------

word_1CB9A:	dc.w 4
	dc.l word_1CBAC
	dc.l word_1CBB8
	dc.l word_1CBC4
	dc.l word_1CBD0

word_1CBAC:	dc.w $14
	dc.b $18
	dc.b 3
	dc.w $C912
	dc.l byte_22172
	dc.w $8190

word_1CBB8:	dc.w $14
	dc.b $18
	dc.b 3
	dc.w $CC12
	dc.l byte_22202
	dc.w $8190

word_1CBC4:	dc.w $14
	dc.b $19
	dc.b 3
	dc.w $CF10
	dc.l byte_22292
	dc.w $8190

word_1CBD0:	dc.w $14
	dc.b $E
	dc.b 3
	dc.w $D210
	dc.l byte_22328
	dc.w $E190

; ---------------------------------------------------------------------------

byte_22172:
	dc.b	1, $70, 1, $71, 1, $72, 1, $73, 1, $74, 1, $75
	dc.b	1, $76, 1, $77, 1, $78, 1, $79, 1, $7A, 1, $7B
	dc.b	1, $7C, 1, $72, 1, $7D, 1, $7E, 1, $7F, 1, $80
	dc.b	1, $72, 1, $7D, 1, $81, 1, $82, 1, $74, 1, $83

	dc.b	1, $84, 1, $85, 1, $86, 1, $87, 1, $88, 1, $89
	dc.b	1, $8A, 1, $8B, 1, $8C, 1, $8D, 1, $8E, 1, $8F
	dc.b	1, $90, 1, $86, 1, $91, 1, $92, 1, $93, 1, $94
	dc.b	1, $86, 1, $91, 1, $95, 1, $96, 1, $88, 1, $97

	dc.b	1, $98, 1, $99, 1, $9A, 0, $DD, 1, $9B, 1, $9C
	dc.b	0, $C1, 1, $9D, 0, $C1, 1, $9E, 1, $9F, 1, $9F
	dc.b	1, $A0, 1, $9A, 0, $DD, 1, $A1, 9, $A1, 1, $A2
	dc.b	1, $9A, 0, $DD, 1, $9B, 0, $DD, 1, $9B, 1, $A0

byte_22202:
	dc.b	1, $A3, 1, $A4, 1, $A5, 1, $A6, 1, $A7, 1, $A8
	dc.b	1, $A9, 1, $70, 1, $AA, 0, 0, 0, 0, 1, $AB
	dc.b	1, $AC, 1, $A5, 1, $A6, 1, $7E, 1, $7F, 1, $80
	dc.b	1, $72, 1, $7D, 1, $81, 1, $82, 1, $74, 1, $83

	dc.b	1, $AD, $11, $A4, 1, $AE, 1, $AF, $11, $7E, 1, $B0
	dc.b	1, $B1, 1, $84, 1, $B2, 1, $B3, 0, 0, 1, $B4
	dc.b	1, $B5, 1, $AE, 1, $AF, 1, $92, 1, $93, 1, $94
	dc.b	1, $86, 1, $91, 1, $95, 1, $B6, 1, $88, 1, $97

	dc.b	8, $C1, 9, $A1, 1, $B7, 0, 0, 0, 0, 1, $B8
	dc.b	$19, $7E, 1, $98, 1, $99, 1, $B9, 0, 0, 1, $BA
	dc.b	1, $A0, 1, $B7, 0, 0, 1, $A1, 9, $A1, 1, $A2
	dc.b	1, $9A, 0, $DD, 1, $9B, 0, $DD, 1, $9B, 1, $A0

byte_22292:
	dc.b	0, $D1, 1, $74, 1, $BB, 1, $BC, 1, $BD, 1, $74, 1, $BE
	dc.b	1, $7A, 1, $BF, 1, $72, 1, $C0, 1, $C1, 1, $70
	dc.b	1, $C2, 1, $74, 1, $83, 1, $7E, 1, $7F, 1, $80
	dc.b	1, $72, 1, $7D, 1, $81, 1, $82, 1, $74, 1, $83

	dc.b	1, $C3, 1, $88, 1, $C4, 1, $C5, 1, $C6, 1, $88, 1, $C7
	dc.b	1, $8E, 1, $C8, 1, $86, 1, $C9, 1, $CA, 1, $84
	dc.b	1, $CB, 1, $88, 1, $97, 1, $92, 1, $93, 1, $94
	dc.b	1, $86, 1, $91, 1, $95, 1, $B6, 1, $88, 1, $97
	
	dc.b	0, 0, 1, $9B, 1, $9C, 0, $C1, 1, $CC, 1, $9B, 1, $9F
	dc.b	1, $9F, 1, $A0, 1, $9A, 1, $CD, 1, $A0, 1, $98
	dc.b	1, $99, 1, $9B, 1, $A0, 1, $A1, 9, $A1, 1, $A2
	dc.b	1, $9A, 0, $DD, 1, $9B, 0, $DD, 1, $9B, 1, $A0

byte_22328:
	dc.b $10, $E2, 1, $72, 1, $7D, 1, $A5, 1, $CE, 1, $CF, 1, $D0
	dc.b 1, $7C, 1, $72, 1, $D1, 1, $D2, 1, $D3, 1, $70, 1, $AA

	dc.b 1, $D4, 1, $86, 1, $91, 1, $AE, 1, $AF, 1, $D5, 1, $D6
	dc.b 1, $90, 1, $86, 1, $D7, 1, $D8, 1, $D9, 1, $84, 1, $B2

	dc.b 0, 0, 1, $9A, 1, $DA, 1, $B7, 0, 0, 9, $B9, 1, $DB
	dc.b 1, $A0, 1, $9A, 1, $DC, 1, $DD, 1, $CC, 1, $98, 1, $DE

; ===========================================================================

word_1CBDC:	dc.w 2
	dc.l word_1CBE6
	dc.l word_1CBF2

word_1CBE6:	dc.w $14
	dc.b $A
	dc.b 3
	dc.w $CA6C
	dc.l byte_2237C
	dc.w $E190

word_1CBF2:	dc.w $14
	dc.b $10
	dc.b 3
	dc.w $CD6A
	dc.l byte_223B8
	dc.w $8190

; ---------------------------------------------------------------------------

word_1CBFE:	dc.w 2
	dc.l word_1CC08
	dc.l word_1CC14

word_1CC08:	dc.w $14
	dc.b $A
	dc.b 3
	dc.w $CA6C
	dc.l byte_2237C
	dc.w $8190

word_1CC14:	dc.w $14
	dc.b $10
	dc.b 3
	dc.w $CD6A
	dc.l byte_223B8
	dc.w $E190

; ---------------------------------------------------------------------------

byte_2237C:
	dc.b	1, $70, 1, $DF, 1, $CF, 1, $E0, 1, $78
	dc.b	1, $79, 1, $7A, 1, $E1, 1, $CF, 1, $E0

	dc.b	1, $84, 1, $B2, 1, $D5, 1, $E2, 1, $8C
	dc.b	1, $8D, 1, $8E, 1, $E3, 1, $D5, 1, $E4
	
	dc.b	1, $98, 1, $99, 9, $B9, 0, $E2, 0, $C1
	dc.b	1, $9E, 1, $9F, 1, $A0, 9, $B9, 0, 0

byte_223B8:
	dc.b $10, $E2, 1, $72, 1, $E5, 1, $72, 1, $D1, 1, $D2, 1, $D3, 1, $CF
	dc.b 1, $D0, 1, $E6, 1, $76, 1, $E7, 1, $E8, 1, $E9, 1, $74, 1, $83

	dc.b 1, $D4, 1, $86, 1, $EA, 1, $86, 1, $D7, 1, $D8, 1, $D9, 1, $D5
	dc.b 1, $D6, 1, $EB, 1, $8A, 1, $EC, 1, $ED, 1, $EE, 1, $88, 1, $97

	dc.b 0, 0, 1, $EF, 0, $DD, 1, $9A, 1, $DC, 1, $DD, 1, $CC, 9, $B9
	dc.b 1, $F0, 1, $F1, 0, $C1, 1, $B7, 1, $F2, 1, $99, 1, $9B, 1, $A0

; ===========================================================================

word_1CC20:	dc.w 1
	dc.l word_1CC26

word_1CC26:	dc.w $14
	dc.b $2B
	dc.b 2
	dc.w $EC00
	dc.l byte_1CC32
	dc.w $E2A0

byte_1CC32:
	dc.b	2, $A6, 2, $A7, 2, $A8, $A, $A8, 0, 0, 2, $A9, 2, $AA, 2, $A8
	dc.b	$A, $A8, 2, $AB, 2, $AB, 0, 0, 2, $AC, $A, $AC, 2, $AD
	dc.b	$A, $AD, 2, $AE, 2, $AF, 2, $B0, 2, $B1, 0, 0, 2, $B0
	dc.b	2, $B1, 2, $A8, $A, $A8, 0, 0, 2, $A8, 2, $B2, 2, $A8
	dc.b	$A, $A8, 2, $AE, 2, $AF, 2, $B0, 2, $B1, 2, $B3, 2, $AE
	dc.b	2, $AF, 2, $AB, 2, $AB, 2, $B4, 2, $B5, 2, $B6, 2, $B7

	dc.b	$12, $A6, $12, $A7, $12, $A8, $1A, $A8, 0, 0, 2, $B8, 2, $B9, $12, $A8
	dc.b	$1A, $A8, 2, $BA, $A, $BA, 0, 0, 2, $BB, $A, $BB, 2, $BC
	dc.b	$A, $BC, 2, $BD, 2, $BE, 2, $B8, 2, $B9, 0, 0, 2, $B8
	dc.b	2, $B9, $12, $A8, $1A, $A8, 0, 0, $12, $A8, $12, $B2, $12, $A8
	dc.b	$1A, $A8, 2, $BD, 2, $BE, 2, $B8, 2, $B9, $12, $B3, 2, $BD
	dc.b	2, $BE, 2, $BA, $A, $BA, $12, $B4, $12, $B5, 2, $BF, 2, $C0

; ===========================================================================

word_1CCDE:	dc.w 1
	dc.l word_1CCE4

word_1CCE4:	dc.w 0
	dc.b $40
	dc.b $F
	dc.w $E000
	dc.w $23EC

; ===========================================================================

word_1CE54:	dc.w 1
	dc.l word_1CE5A

word_1CE5A:	dc.w 0
	dc.b $16
	dc.b $11
	dc.w $C120
	dc.w $8000

; ===========================================================================

word_1CE62:	dc.w 3
	dc.l word_1CE70
	dc.l word_1CE78
	dc.l word_1CE80

word_1CE70:	dc.w 0
	dc.b $40
	dc.b $1C
	dc.w $C000
	dc.w $8000

word_1CE78:	dc.w 0
	dc.b $40
	dc.b $1C
	dc.w $E000
	dc.w 0

word_1CE80:	dc.w 4
	dc.b $C
	dc.b 4
	dc.w $C61C
	dc.l byte_21DE4
	dc.w $8000

byte_21DE4:
	dc.b 	1, 2, 3, 4, 5, 6, 7, 8, 9, $A, $B, 0
	dc.b	$C, $D, $E, $F, $10, $11, $12, $13, $14, $15, $16, $17
	dc.b	$18, $19, $1A, $1B, $1C, $1D, $1E, $1F, $20, $21, $22, $23
	dc.b	$24, $25, $26, $27, $28, $29, $2A, $2B, $2C, $2D, $2E, $2F

; ===========================================================================

word_1CE8C:	dc.w 8
	dc.l word_1CEAE
	dc.l word_1CEB6
	dc.l word_1CEC0
	dc.l word_1CECA
	dc.l word_1CED4
	dc.l word_1CEE0
	dc.l word_1CEEC
	dc.l word_1CEF8

word_1CEAE:	dc.w 0
	dc.b $80
	dc.b $20
	dc.w $C000
	dc.w $500

word_1CEB6:	dc.w 8
	dc.b $28
	dc.b 4
	dc.w $E000
	dc.l byte_2006C

word_1CEC0:	dc.w 8
	dc.b $28
	dc.b $C
	dc.w $E400
	dc.l byte_1FDEC

word_1CECA:	dc.w 8
	dc.b $28
	dc.b $C
	dc.w $F000
	dc.l byte_1FDEC

word_1CED4:	dc.w 4
	dc.b 8
	dc.b 7
	dc.w $C608
	dc.l byte_201AC
	dc.w $E300

word_1CEE0:	dc.w 4
	dc.b 8
	dc.b 7
	dc.w $C618
	dc.l byte_201E4
	dc.w $E300

word_1CEEC:	dc.w 4
	dc.b 8
	dc.b 7
	dc.w $C628
	dc.l byte_2021C
	dc.w $E300

word_1CEF8:	dc.w 4
	dc.b 8
	dc.b 7
	dc.w $C638
	dc.l byte_20254
	dc.w $E300

; ---------------------------------------------------------------------------

byte_1FDEC:
	dc.b	$42, 2, $42, $16, $42, $17, $42, $18, $42, $19, $42, $1A, $42, 2, $42, $16
	dc.b	$42, $17, $42, $1B, $42, $19, $42, $1A, $42, 2, $42, $16, $42, $17, $42, $1B
	dc.b	$42, $19, $42, $1A, $42, 2, $42, $16, $42, $17, $42, $1B, $42, $19, $42, $1A
	dc.b	$42, 2, $42, $16, $42, $17, $42, $1B, $42, $19, $42, $1A, $42, 2, $42, $16
	dc.b	$42, $17, $42, $1B, $42, $19, $42, $1A, $42, 2, $42, $16, $42, $17, $42, $1B
	dc.b	$42, $1C, $42, $1D, $42, $1E, $42, $1F, $42, $1C, $42, $1C, $42, $1C, $42, $1D
	dc.b	$42, $1E, $42, $1F, $42, $1C, $42, $1C, $42, $1C, $42, $1D, $42, $1E, $42, $1F
	dc.b	$42, $1C, $42, $1C, $42, $1C, $42, $1D, $42, $1E, $42, $1F, $42, $1C, $42, $1C
	dc.b	$42, $1C, $42, $1D, $42, $1E, $42, $1F, $42, $1C, $42, $1C, $42, $1C, $42, $1D
	dc.b	$42, $1E, $42, $1F, $42, $1C, $42, $1C, $42, $1C, $42, $1D, $42, $1E, $42, $1F
	dc.b	$42, $20, $42, $21, $42, $22, $42, $23, $42, $24, $42, $25, $42, $26, $42, $27
	dc.b	$42, $22, $42, $28, $42, $29, $42, $25, $42, $26, $42, $27, $42, $22, $42, $28
	dc.b	$42, $29, $42, $25, $42, $26, $42, $27, $42, $22, $42, $28, $42, $29, $42, $25
	dc.b	$42, $26, $42, $27, $42, $22, $42, $28, $42, $29, $42, $25, $42, $26, $42, $27
	dc.b	$42, $22, $42, $28, $42, $29, $42, $25, $42, $26, $42, $27, $42, $22, $42, $28
	dc.b	$42, $2A, $42, $2B, $42, $2C, $42, $2D, $42, $2E, $42, $2F, $42, $30, $42, $2B
	dc.b	$42, $31, $42, $2D, $42, $2E, $42, $2F, $42, $30, $42, $2B, $42, $31, $42, $2D
	dc.b	$42, $2E, $42, $2F, $42, $30, $42, $2B, $42, $31, $42, $2D, $42, $2E, $42, $2F
	dc.b	$42, $30, $42, $2B, $42, $31, $42, $2D, $42, $2E, $42, $2F, $42, $30, $42, $2B
	dc.b	$42, $31, $42, $2D, $42, $2E, $42, $2F, $42, $30, $42, $2B, $42, $31, $42, $2D
	dc.b	$42, $32, $42, $33, $42, $34, $42, $35, $42, $36, $42, $37, $42, $38, $42, $33
	dc.b	$42, $34, $42, $35, $42, $36, $42, $37, $42, $38, $42, $33, $42, $34, $42, $35
	dc.b	$42, $36, $42, $37, $42, $38, $42, $33, $42, $34, $42, $35, $42, $36, $42, $37
	dc.b	$42, $38, $42, $33, $42, $34, $42, $35, $42, $36, $42, $37, $42, $38, $42, $33
	dc.b	$42, $34, $42, $35, $42, $36, $42, $37, $42, $38, $42, $33, $42, $34, $42, $35
	dc.b	$42, $39, $42, $3A, $42, $3B, $42, $3C, $42, $3D, $42, $3E, $42, $39, $42, $3A
	dc.b	$42, $3B, $42, $3C, $42, $3D, $42, $3E, $4A, $3D, $42, $3A, $42, $3B, $42, $3C
	dc.b	$42, $3D, $42, $3E, $42, $39, $42, $3A, $42, $3B, $42, $3C, $42, $3D, $42, $3E
	dc.b	$42, $39, $42, $3A, $42, $3B, $42, $3C, $42, $3D, $42, $3E, $42, $39, $42, $3A
	dc.b	$42, $3B, $42, $3C, $42, $3D, $42, $3E, $42, $39, $42, $3A, $42, $3B, $42, $3C
	dc.b	$42, $3F, $42, $40, $42, $41, $42, $42, $42, $43, $42, $44, $42, $3F, $42, $40
	dc.b	$42, $41, $42, $42, $42, $43, $42, $44, $42, $3F, $42, $40, $42, $41, $42, $42
	dc.b	$42, $43, $42, $44, $42, $3F, $42, $40, $42, $41, $42, $42, $42, $43, $42, $44
	dc.b	$42, $3F, $42, $40, $42, $41, $42, $42, $42, $43, $42, $44, $42, $3F, $42, $40
	dc.b	$42, $41, $42, $42, $42, $43, $42, $44, $42, $3F, $42, $40, $42, $41, $42, $42
	dc.b	$42, $45, $42, $46, $42, $47, $4A, $46, $4A, $45, $42, $48, $42, $45, $42, $46
	dc.b	$42, $47, $4A, $46, $4A, $45, $42, $48, $42, $45, $42, $49, $42, $47, $4A, $46
	dc.b	$4A, $45, $42, $48, $42, $45, $42, $49, $42, $47, $4A, $46, $4A, $45, $42, $48
	dc.b	$42, $45, $42, $46, $42, $47, $4A, $46, $4A, $45, $42, $48, $42, $45, $42, $46
	dc.b	$42, $47, $4A, $46, $4A, $45, $42, $48, $42, $45, $42, $46, $42, $47, $4A, $46

byte_2006C:
	dc.b	$42, $4A, $42, $4B, $42, $4C, $42, $4D, $4A, $4A, $42, $4E, $42, $4A, $42, $4F
	dc.b	$42, $50, $42, $51, $4A, $4A, $42, $4E, $42, $4A, $42, $52, $42, $53, $42, $54
	dc.b	$4A, $4A, $42, $4E, $42, $4A, $4A, $51, $4A, $50, $4A, $4F, $4A, $4A, $42, $4E
	dc.b	$42, $4A, $4A, $4D, $4A, $4C, $4A, $4B, $4A, $4A, $42, $4E, $42, $4A, $42, $4B
	dc.b	$42, $4C, $42, $4D, $4A, $4A, $42, $4E, $42, $4A, $42, $4F, $42, $50, $42, $51
	dc.b	$42, $56, $42, $57, $42, $58, $42, $59, $4A, $56, $42, $5A, $42, $56, $42, $5B
	dc.b	$42, $5C, $42, $5D, $4A, $56, $42, $5A, $42, $56, $42, $5E, $42, $5F, $42, $60
	dc.b	$4A, $56, $42, $5A, $42, $56, $4A, $5D, $4A, $5C, $4A, $5B, $4A, $56, $42, $5A
	dc.b	$42, $56, $4A, $59, $4A, $58, $4A, $57, $4A, $56, $42, $5A, $42, $56, $42, $57
	dc.b	$42, $58, $42, $59, $4A, $56, $42, $5A, $42, $56, $42, $5B, $42, $5C, $42, $5D
	dc.b	$42, $62, $42, $63, $42, $64, $4A, $63, $4A, $62, $42, $65, $42, $62, $42, $63
	dc.b	$42, $66, $4A, $63, $4A, $62, $42, $65, $42, $62, $42, $63, $42, $67, $4A, $63
	dc.b	$4A, $62, $42, $65, $42, $62, $42, $68, $42, $69, $4A, $63, $4A, $62, $42, $65
	dc.b	$42, $62, $42, $63, $42, $6A, $4A, $63, $4A, $62, $42, $65, $42, $62, $42, $63
	dc.b	$42, $69, $4A, $63, $4A, $62, $42, $65, $42, $62, $42, $63, $42, $6A, $4A, $63
	dc.b	$42, $6B, $52, $3A, $52, $3B, $52, $3C, $4A, $6B, $42, $6C, $42, $6B, $52, $3A
	dc.b	$52, $3B, $52, $3C, $4A, $6B, $42, $6C, $42, $6B, $52, $3A, $52, $3B, $52, $3C
	dc.b	$4A, $6B, $42, $6C, $42, $6B, $52, $3A, $52, $3B, $52, $3C, $4A, $6B, $42, $6C
	dc.b	$42, $6B, $52, $3A, $52, $3B, $52, $3C, $4A, $6B, $42, $6C, $42, $6B, $52, $3A
	dc.b	$52, $3B, $52, $3C, $4A, $6B, $42, $6C, $42, $6B, $52, $3A, $52, $3B, $52, $3C

byte_201AC:
	dc.b	0, 1, 2, 3, 4, 0, 0, 0
	dc.b	0, 9, $A, $B, $C, 0, 0, 0
	dc.b	0, 0, $13, $14, $15, 0, 0, 0
	dc.b	$1B, $1C, $1D, $1E, $1F, $20, $21, $22
	dc.b	$29, $2A, $2B, $2C, $2D, $2E, $2F, $30
	dc.b	$39, $3A, $3B, $3C, $3D, $3E, $3F, $40
	dc.b	0, 0, $49, $4A, $4B, $4C, 0, 0

byte_201E4:
	dc.b 0,	0, 5, 6, 7, 8, 0, 0, 0,	0, $D, $E, $F, $10, $11, $12
	dc.b 0,	0, 0, $16, $17,	$18, $19, $1A, 0, $23, $24, $25, $26, $27, $28,	0
	dc.b $31, $32, $33, $34, $35, $36, $37,	$38, $41, $42, $43, $44, $45, $46, $47,	$48
	dc.b $4D, $4E, $4F, $50, $51, $52, $53,	$54

byte_2021C:
	dc.b	0, 1, 2, 3, 4, 0, 0, 0
	dc.b	0, 9, $A, $B, $C, 0, 0, 0
	dc.b	0, 0, $13, $14, $15, 0, 0, 0
	dc.b	$1B, $1C, $1D, $1E, $1F, $20, $21, $22
	dc.b	$29, $2A, $2B, $2C, $2D, $2E, $2F, $30
	dc.b	$39, $3A, $3B, $3C, $3D, $3E, $3F, $40
	dc.b	0, 0, $49, $4A, $4B, $4C, 0, 0

byte_20254:
	dc.b	0, 0, 5, 6, 7, 8, 0, 0
	dc.b	0, 0, $D, $E, $F, $10, $11, $12
	dc.b	0, 0, 0, $16, $17, $18, $19, $1A
	dc.b	0, $23, $24, $25, $26, $27, $28, 0
	dc.b	$31, $32, $33, $34, $35, $36, $37, $38
	dc.b	$41, $42, $43, $44, $45, $46, $47, $48
	dc.b	$4D, $4E, $4F, $50, $51, $52, $53, $54

; ===========================================================================

word_1CF96:	dc.w 1
	dc.l word_1CF9C

word_1CF9C:	dc.w 4
	dc.b $20
	dc.b $14
	dc.w $C208
	dc.l byte_1FB6C
	dc.w $8100

; ---------------------------------------------------------------------------

byte_1FB6C:
	dc.b $DF, $DF, $DF, $DF, $DF, $DF, $DF,	$DF, $DF, $DF, $DF, $DF, $DF, $E0, $DF,	$DF
	dc.b $DF, $DF, $DF, $DF, $DF, $DF, $DF,	$DF, $E1, $DF, $E2, $DF, $DF, $DF, $DF,	$DF

	dc.b $DF, $DF, $DF, $DF, $DF, $DF, $DF,	$DF, $DF, $DF, $DF, $DF, $DF, $DF, $DF,	$DF
	dc.b $DF, $DF, $DF, $DF, $DF, $DF, $DF,	$E3, $DF, $E4, $DF, $DF, $DF, $DF, $E5,	$DF

	dc.b $DF, $DF, $DF, $DF, $DF, $DF, $DF,	$DF, $DF, $DF, $DF, $DF, $DF, $DF, $E6,	$DF
	dc.b $E7, $DF, $E8, $E9, $DF, $EA, $DF,	$DF, $DF, $DF, $DF, $DF, $DF, $DF, $DF,	$DF

	dc.b $DF, $DF, $DF, $DF, $DF, $DF, $DF,	$DF, $DF, $DF, $DF, $DF, $E6, $DF, $DF,	$E2
	dc.b $EB, $DF, $DF, $EC, $ED, $DF, $DF,	$E5, $DF, $DF, $DF, $DF, $DF, $DF, $DF,	$DF

	dc.b $DF, $DF, $DF, $DF, $EE, $DF, $E1,	$EF, $DF, $F0, $F1, $DF, $EA, $DF, $DF,	$DF
	dc.b $DF, $DF, $E8, $DF, $DF, $ED, $F2,	$F3, $E2, $E5, $DF, $DF, $DF, $DF, $DF,	$DF

	dc.b $DF, $DF, $DF, $F4, $F5, $EA, $DF,	$DF, $DF, $DF, $DF, $F6, $DF, $DF, $E4,	$DF
	dc.b $DF, $DF, $DF, $DF, $F7, $DF, $DF,	$DF, $DF, $DF, $DF, $DF, $DF, $DF, $DF,	$DF

	dc.b $DF, $DF, $DF, $F8, $F9, $DF, $DF,	$DF, $FA, $FB, $E0, $FC, $DF, $EA, $DF,	$DF
	dc.b $F4, $F4, $DF, $DF, $DF, $DF, $DF,	$DF, $DF, $DF, $DF, $DF, $E2, $DF, $DF,	$DF

	dc.b $DF, $DF, $DF, $DF, $DF, $DF, $DF,	$FD, $DF, $E3, $DF, $DF, $DF, $DF, $DF,	$DF
	dc.b $DF, $E3, $DF, $DF, $DF, $DF, $DF,	$DF, $DF, $DF, $DF, $DF, $DF, $DF, $DF,	$DF

	dc.b $DF, $DF, $DF, $DF, $DF, $DF, $DF,	$DF, $DF, $DF, $DF, $DF, $DF, $DF, $DF,	$DF
	dc.b $FD, $DF, $DF, $DF, $DF, $DF, $DF,	$DF, $DF, $DF, $DF, $DF, $DF, $DF, $DF,	$DF

	dc.b $DF, $DF, $DF, $DF, $DF, $DF, $E2,	$DF, $FE, $DF, $DF, $DF, $DF, $DF, $DF,	$DF
	dc.b $DF, $EA, $DF, $DF, $DF, $DF, $DF,	$DF, $DF, $DF, $DF, $DF, $DF, $DF, $DF,	$DF

	dc.b $DF, $DF, $DF, $DF, $DF, $DF, $DF,	$DF, $DF, $DF, $DF, $DF, $DF, $DF, $DF,	$DF
	dc.b $DF, $DF, $DF, $DF, $DF, $DF, $DF,	$DF, $DF, $DF, $DF, $DF, $DF, $DF, $DF,	$DF

	dc.b $DF, $DF, $DF, $DF, $DF, $E1, $E3,	$DF, $DF, $F2, $DF, $DF, $DF, $DF, $DF,	$DF
	dc.b $DF, $DF, $DF, $DF, $DF, $DF, $DF,	$DF, $DF, $DF, $DF, $DF, $DF, $DF, $DF,	$DF

	dc.b $DF, $DF, $DF, $DF, $DF, $DF, $DF,	$DF, $DF, $DF, $DF, $DF, $DF, $DF, $DF,	$DF
	dc.b $DF, $DF, $DF, $DF, $DF, $DF, $DF,	$DF, $DF, $DF, $DF, $DF, $DF, $DF, $DF,	$DF

	dc.b 1,	2, 3, 4, 5, 6, 7, 8, 9,	$A, $B,	$C, $D,	$E, $F,	$10
	dc.b $11, $12, $13, $14, $15, $16, $17,	$18, $19, $1A, $1B, $1C, $1D, $1E, $1F,	$20

	dc.b $21, $22, $23, $24, $25, $26, $27,	$28, $29, $2A, $2B, $2C, $2D, $2E, $2F,	$30
	dc.b $31, $32, $33, $34, $35, $36, $37,	$38, $39, $3A, $3B, $3C, $3D, $3E, $3F,	$40

	dc.b $41, $42, $43, $44, $45, $46, $47,	$48, $49, $4A, $4B, $4C, $4D, $4E, $4F,	$50
	dc.b $51, $52, $53, $54, $55, $56, $57,	$58, $59, $5A, $5B, $5C, $5D, $5E, $5F,	$60

	dc.b $61, $62, $63, $64, $65, $66, $67,	$68, $69, $6A, $6B, $6C, $6D, $6E, $6F,	$70
	dc.b $71, $72, $73, $74, $75, $76, $77,	$78, $79, $7A, $7B, $7C, $7D, $7E, $7F,	$80

	dc.b $81, $82, $83, $84, $85, $86, $87,	$88, $89, $8A, $8B, $8C, $8D, $8E, $8F,	$90
	dc.b $91, $92, $93, $94, $95, $96, $97,	$98, $99, $9A, $9B, $9C, $9D, $9E, $9F,	$A0

	dc.b $A1, $A2, $A3, $A4, $A5, $A6, $A7,	$A8, $A9, $AA, $AB, $AC, $AD, $AE, $AF,	$B0
	dc.b $B1, $B2, $B3, $B4, $B5, $B6, $B7,	$B8, $B9, $BA, $BB, $BC, $BD, $BE, $BF,	$C0

	dc.b $C1, $C2, $C3, $C4, $C5, $C6, $C7,	$C8, $C9, $CA, $CB, $CC, $CD, $CE, $CF,	$D0
	dc.b $D1, $D2, $D3, 4, $D4, $D5, $D6, $D7, 4, $D8, $D9,	$DA, $DB, $DC, $DD, $DE

; ===========================================================================

word_1D002:	dc.w 1
	dc.l word_1D008

word_1D008:	dc.w 0
	dc.b $80
	dc.b $1C
	dc.w $C000
	dc.w $8500

; ===========================================================================

word_1D010:	dc.w 2
	dc.l word_1D01A
	dc.l word_1D022

word_1D01A:	dc.w 0
	dc.b $80
	dc.b $1C
	dc.w $C000
	dc.w $8500

word_1D022:	dc.w 0
	dc.b $80
	dc.b $1C
	dc.w $E000
	dc.w $500

; ===========================================================================

word_1D02A:	dc.w 2
	dc.l word_1D034
	dc.l word_1D03C

word_1D034:	dc.w 0
	dc.b $80
	dc.b $1C
	dc.w $C000
	dc.w $8000

word_1D03C:	dc.w 0
	dc.b $80
	dc.b $1C
	dc.w $E000
	dc.w 0

; ===========================================================================

word_1D044:	dc.w 1
	dc.l word_1D04A

word_1D04A:	dc.w 0
	dc.b $38
	dc.b $1C
	dc.w $C000
	dc.w 0

; ===========================================================================

word_1D052:	dc.w 7
	dc.l word_1D078
	dc.l word_1D088
	dc.l word_1D094
	dc.l word_1D0A0
	dc.l word_1D0AC
	dc.l word_1D080
	dc.l word_1D070

word_1D070:	dc.w 0
	dc.b $40
	dc.b $1C
	dc.w $C000
	dc.w $1F8

word_1D078:	dc.w 0
	dc.b $28
	dc.b 4
	dc.w $E400
	dc.w 1

word_1D080:	dc.w 0
	dc.b $28
	dc.b 2
	dc.w $ED00
	dc.w $101

word_1D088:	dc.w 4
	dc.b $20
	dc.b $C
	dc.w $E400
	dc.l byte_1EF40
	dc.w 0

word_1D094:	dc.w 4
	dc.b 8
	dc.b 8
	dc.w $E640
	dc.l byte_1F0C0
	dc.w 0

word_1D0A0:	dc.w 4
	dc.b $20
	dc.b 6
	dc.w $EA00
	dc.l byte_1F100
	dc.w $100

word_1D0AC:	dc.w 4
	dc.b 8
	dc.b 6
	dc.w $EA40
	dc.l byte_1F1C0
	dc.w $100

; ---------------------------------------------------------------------------

byte_1EF40:
	dc.b	1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 3, 1, 1, 1, 1, 1
	dc.b	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 4, 1, 1, 1, 1
	dc.b	1, 1, 1, 1, 1, 1, 1, 1, 5, 6, 7, 8, 9, 1, 1, 1
	dc.b	1, 1, 1, 1, 1, $A, $B, $C, $D, $E, $F, $10, $11, $12, 1, 1
	dc.b	1, 1, 1, 1, 1, 1, 1, 1, $13, $14, $15, $16, 1, 1, 1, 1
	dc.b	1, 1, 1, 1, 1, $17, $18, $19, $1A, $1B, $1C, $1D, $1E, $1F, $20, 1
	dc.b	1, 1, 1, 1, 1, 1, 1, 1, $21, $22, $23, $24, 1, 1, 1, 1
	dc.b	1, 1, 1, 1, $25, $26, $27, $28, $29, $2A, $2B, $2C, $2D, $2E, $2F, 1
	dc.b	$35, $36, $37, $38, $30, $31, $32, $33, $34, $35, $36, $37, $38, $30, $31, $39
	dc.b	$3A, $3B, $3C, $3D, $3E, $3F, $40, $41, $42, $43, $44, $45, $46, $47, $48, $49
	dc.b	$51, $52, $53, $54, $4C, $4D, $4E, $4F, $50, $51, $52, $53, $54, $4C, $4D, $55
	dc.b	$56, $57, $58, $59, $5A, $5B, $5C, $5D, $5E, $5F, $60, $61, $62, $63, $64, $65
	dc.b	$6C, $6D, $6E, $6F, $68, $68, $69, $6A, $6B, $6C, $6D, $6E, $6F, $68, $68, $68
	dc.b	$70, $71, $72, $73, $74, $75, $76, $77, $78, $79, $7A, $7B, $7C, $7D, $7E, $68
	dc.b	$68, $68, $80, $68, $68, $68, $68, $68, $68, $68, $68, $80, $68, $68, $81, $82
	dc.b	$83, $84, $85, $86, $87, $88, $89, $8A, $8B, $8C, $8D, $8E, $8F, $90, $68, $91
	dc.b	$68, $68, $68, $68, $68, $68, $68, $68, $68, $68, $68, $68, $68, $95, $96, $97
	dc.b	$98, $99, $9A, $9B, $9C, $9D, $9E, $9F, $A0, $A1, $A2, $A3, $A4, $A5, $A6, $A7
	dc.b	$68, $68, $68, $68, $68, $68, $AC, $AD, $AE, $AF, $68, $68, $68, $B0, $B1, $B2
	dc.b	$B3, $B4, $B5, $B6, $B7, $B8, $B9, $BA, $BB, $BC, $BD, $BE, $BF, $C0, $C1, $C2
	dc.b	$68, $68, $68, $68, $68, $C7, $C8, $C9, $CA, $CB, $68, $68, $68, $CC, $CD, $CE
	dc.b	$CF, $D0, $D1, $D2, $D3, $D4, $D5, $D6, $D7, $D8, $D9, $DA, $DB, $DC, $DD, $DE
	dc.b	$68, $68, $68, $68, $68, $E3, $E4, $E5, $E6, $E7, $E8, $68, $E9, $EA, $EB, $EC
	dc.b	$ED, $EE, $EF, $F0, $F1, $F2, $F3, $F4, $F5, $F6, $F7, $F8, $F9, $FA, $FB, $FC

byte_1F0C0:
	dc.b	$4A, $4B, $32, $33, $34, $35, $36, $37, $66, $67, $4E, $4F, $50, $51, $52, $53
	dc.b	$68, $7F, $69, $6A, $6B, $6C, $6D, $6E, $92, $93, $94, $68, $68, $68, $68, $80
	dc.b	$A8, $A9, $AA, $AB, $68, $68, $68, $68, $C3, $C4, $C5, $C6, $68, $68, $68, $68
	dc.b	$DF, $E0, $E1, $E2, $68, $68, $68, $68, $FD, $FE, $FF, $68, $68, $68, $68, $68

byte_1F100:
	dc.b	1, 1, 1, 1, 1, 2, 3, 4, 5, 6, 7, 1, 8, 9, $A, $B
	dc.b	$C, $D, 1, $E, $F, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $1A
	dc.b	1, 1, 1, 1, 1, 1, $1E, $1F, $20, $21, $22, $23, $24, $25, 1, $26
	dc.b	$27, $28, $29, $2A, $2B, $2C, $2D, $2E, $2F, $30, $31, $32, $33, $34, $35, $36
	dc.b	1, 1, 1, 1, 1, 1, 1, $3A, $3B, $3C, $3D, $3E, 1, $3F, $40, $41
	dc.b	$42, $43, $44, 1, $45, $46, $47, $48, $49, $4A, $4B, $4C, $4D, $4E, 1, $1E
	dc.b	1, 1, 1, 1, 1, 1, 1, $4F, $50, $51, $52, $53, 1, 1, $54, $42
	dc.b	$42, $55, $56, 1, 1, 1, 1, 1, 1, 1, $57, $58, $59, $5A, 1, 1
	dc.b	1, 1, 1, 1, 1, 1, 1, 1, $1E, $1E, 1, 1, 1, 1, $5B, $5C
	dc.b	$5D, $5E, $5F, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
	dc.b	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
	dc.b	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1

byte_1F1C0:
	dc.b	$1B, $1C, $1D, 1, 1, 1, 1, 1, $37, $38, $39, 1, 1, 1, 1, 1
	dc.b	$1E, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
	dc.b	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1

; ===========================================================================

word_1CF04:	dc.w $A
	dc.l word_1CF2E
	dc.l word_1CF36
	dc.l word_1CF3E
	dc.l word_1CF46
	dc.l word_1CF52
	dc.l word_1CF5E
	dc.l word_1CF6A
	dc.l word_1CF72
	dc.l word_1CF7E
	dc.l word_1CF8A

word_1CF2E:	dc.w 0
	dc.b $40
	dc.b $1C
	dc.w $C000
	dc.w $80FF

word_1CF36:	dc.w 0
	dc.b $20
	dc.b 3
	dc.w $C708
	dc.w $8000

word_1CF3E:	dc.w 0
	dc.b $40
	dc.b $1C
	dc.w $E000
	dc.w 0

word_1CF46:	dc.w 4
	dc.b $20
	dc.b 7
	dc.w $C888
	dc.l byte_1FA8C
	dc.w $8100

word_1CF52:	dc.w 4
	dc.b $20
	dc.b 9
	dc.w $C208
	dc.l byte_1F8EC
	dc.w $8000

word_1CF5E:	dc.w 4
	dc.b $20
	dc.b 1
	dc.w $C688
	dc.l byte_1F8CC
	dc.w $8000

word_1CF6A:	dc.w 0
	dc.b $40
	dc.b 9
	dc.w $E200
	dc.w $F

word_1CF72:	dc.w 4
	dc.b $20
	dc.b 4
	dc.w $E680
	dc.l byte_1F84C
	dc.w 0

word_1CF7E:	dc.w 4
	dc.b $20
	dc.b 4
	dc.w $E6C0
	dc.l byte_1F84C
	dc.w 0

word_1CF8A:	dc.w 4
	dc.b $20
	dc.b 4
	dc.w $E688
	dc.l byte_1F84C
	dc.w 0

; ---------------------------------------------------------------------------

byte_1F84C:
	dc.b $F, $F, $F, $F, $F, $F, $F, $F, $F, $F, $C5, $C6, $C7, $C8, $C9, $CA
	dc.b $F, $F, $F, $F, $F, $F, $F, $F, $F, $F, $F, $F, $F, $F, $F, $F

	dc.b $D3, $D3, $D3, $D3, $D3, $D3, $D3,	$D3, $D4, $D5, $D6, $D7, $D8, $D8, $D9,	$DA
	dc.b $DB, $DC, $D3, $D3, $D3, $D3, $D3,	$D3, $D3, $D3, $D3, $D3, $D3, $D3, $D3,	$D3

	dc.b $DD, $DD, $DD, $DD, $DD, $DD, $DD,	$DE, $DF, $D8, $D8, $D8, $D8, $D8, $D8,	$D8
	dc.b $E0, $E1, $E2, $DD, $DD, $DD, $DD,	$DD, $DD, $DD, $DD, $DD, $DD, $DD, $DD,	$DD

	dc.b $E3, $E3, $E3, $E3, $E3, $E3, $E3,	$E4, $E5, $D8, $D8, $D8, $D8, $D8, $D8,	$D8
	dc.b $D8, $E0, $E6, $E3, $E3, $E3, $E3,	$E3, $E3, $E3, $E3, $E3, $E3, $E3, $E3,	$E3

byte_1F8CC:
	dc.b	$C0, $C1, $C2, $C3, $C4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b	0, 0, 0, 0, 0, 0, 0, $CB, $CC, $CD, $CE, $CF, $D0, $D1, $D2, $F

; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------

word_1CFA8:	dc.w 6
	dc.l word_1CFC2
	dc.l word_1CFCA
	dc.l word_1CFD2
	dc.l word_1CFDE
	dc.l word_1CFEA
	dc.l word_1CFF6

word_1CFC2:	dc.w 0
	dc.b $80
	dc.b $1C
	dc.w $C000
	dc.w 0

word_1CFCA:	dc.w 0
	dc.b $80
	dc.b $1C
	dc.w $E000
	dc.w 0

word_1CFD2:	dc.w 4
	dc.b $18
	dc.b $10
	dc.w $C820
	dc.l byte_1F66C
	dc.w $2200

word_1CFDE:	dc.w 4
	dc.b $18
	dc.b 4
	dc.w $D820
	dc.l byte_1F7EC
	dc.w $2300

word_1CFEA:	dc.w 4
	dc.b $20
	dc.b $D
	dc.w $E408
	dc.l byte_1F8EC
	dc.w 0

word_1CFF6:	dc.w 4
	dc.b $20
	dc.b 7
	dc.w $F108
	dc.l byte_1FA8C
	dc.w $100

; ---------------------------------------------------------------------------

byte_1F66C:
	dc.b	0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 0, 0, 0
	dc.b	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5
	dc.b	6, 7, 8, 9, $A, $B, $C, 0, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b	0, 0, 0, 0, 0, $D, $E, $F, $10, $11, $12, $13, $14, $15, $16, $17
	dc.b	$18, 0, 0, 0, 0, 0, 0, 0, 0, 0, $19, $1A, $1B, $1C, $1D, $1E
	dc.b	$1F, $20, $21, $22, $23, $24, $25, $26, $27, $28, 0, 0, 0, 0, 0, 0
	dc.b	0, 0, $29, $2A, $2B, $2C, $2D, $2E, $2F, $30, $31, $32, $33, $34, $35, $36
	dc.b	$37, $38, 0, 0, 0, 0, 0, 0, 0, 0, $39, $3A, $3B, $3C, $3D, $3E
	dc.b	$3F, $40, $41, $42, $43, $44, $45, $46, $47, 0, 0, 0, 0, 0, 0, 0
	dc.b	0, 0, $48, $49, $4A, $4B, $4C, $4D, $4E, $4F, $50, $51, $52, $53, $54, $55
	dc.b	$56, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, $57, $58, $59, $5A, $5B
	dc.b	$5C, $5D, $5E, $5F, $60, $61, $62, $63, $64, 0, 0, 0, 0, 0, 0, 0
	dc.b	0, 0, $65, $66, $67, $68, $69, $6A, $6B, $6C, $6D, $6E, $6F, $70, $71, $72
	dc.b	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, $73, $74, $75, $76, $77, $78
	dc.b	$79, $7A, $7B, $7C, $7D, $7E, $7F, $80, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b	0, 0, $81, $82, $83, $84, $85, $86, $87, $88, $89, $8A, $8B, $8C, $8D, $8E
	dc.b	$8F, $90, 0, 0, $91, $92, $93, $94, 0, 0, 0, $95, $96, $97, $98, $99
	dc.b	$9A, $9B, $9C, $9D, $9E, $9F, $A0, $A1, $A2, $A3, $A4, 0, $A5, $A6, $A7, $A8
	dc.b	0, 0, 0, $A9, $AA, $AB, $AC, $AD, $AE, $AF, $B0, $B1, $B2, $B3, $B4, $B5
	dc.b	$B6, $B7, $B8, 0, $B9, $BA, $5E, $BB, 0, 0, 0, 0, $BC, $BD, $5E, $BE
	dc.b	$BF, $C0, $C1, $C2, $C3, $C4, $C5, $C6, $C7, $9C, $C8, $C9, $CA, $CB, $CC, $CD
	dc.b	0, 0, 0, 0, $CE, $CF, $D0, $D1, $D2, $D3, $C0, $C0, $D4, $D5, $D6, $D7
	dc.b	$D8, $9C, $D9, $DA, $DB, $DC, $DD, 0, 0, 0, 0, 0, $DE, $DF, $E0, $E1
	dc.b	$E2, $E3, $C0, $E4, $E5, $E6, $E7, $E8, $E9, $EA, $EB, $EC, $ED, $EE, $EF, 0

byte_1F7EC:
	dc.b	0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, $A, $B, $C
	dc.b	$D, 0, $E, $F, $10, $11, 0, 0, 0, 0, 0, 0, 0, $12, $13, $14
	dc.b	$15, $16, $17, $18, $19, $1A, $1B, $1C, $1D, 0, 0, 0, 0, 0, 0, 0
	dc.b	0, 0, 0, 0, 0, 0, 0, $1E, $1F, $20, $21, $22, $23, $24, $25, $26
	dc.b	$27, $28, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, $29, $2A
	dc.b	$2B, $2C, $2D, $2E, $2F, $30, $31, $32, $33, $34, $35, 0, 0, 0, 0, 0

; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------

byte_1F8EC:
	dc.b	1, 2, 3, 4, 5, 6, 7, 8, 9, $A, $B, $C, $D, $E, $F, $F
	dc.b	$F, $F, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $1A, $1B, $1C, $1D
	dc.b	$1E, $1F, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $F, $F, $F, $F
	dc.b	$F, $F, $2A, $2B, $2C, $2D, $2E, $2F, $30, $31, $32, $33, $34, $35, $36, $37
	dc.b	$38, $39, $3A, $3B, $3C, $3D, $3E, $3F, $40, $41, $42, $43, $44, $F, $F, $F
	dc.b	$F, $F, $F, $F, $45, $46, $47, $48, $49, $4A, $4B, $4C, $4D, $4E, $4F, $50
	dc.b	$51, $52, $53, $54, $55, $56, $57, $58, $59, $5A, $5B, $5C, $5D, $F, $F, $F
	dc.b	$F, $F, $5E, $5F, $60, $61, $62, $63, $64, $65, $66, $67, $68, $69, $6A, $6B
	dc.b	$6C, $F, $6D, $F, $6E, $6F, $70, $71, $72, $73, $74, $F, $F, $F, $F, $F
	dc.b	$75, $76, $77, $78, $79, $7A, $7B, $7C, $7D, $7E, $7F, $80, $81, $82, $83, $84
	dc.b	$F, $F, $85, $F, $F, $F, $F, $86, $F, $F, $F, $F, $F, $F, $F, $87
	dc.b	$88, $89, $8A, $8B, $F, $8C, $8D, $8E, $8F, $90, $91, $92, $93, $94, $95, $F
	dc.b	$F, $96, $97, $98, $99, $9A, $9B, $F, $F, $F, $F, $F, $F, $F, $F, $F
	dc.b	$F, $F, $F, $F, $F, $9C, $9D, $9E, $9F, $A0, $F, $A1, $A2, $F, $F, $F
	dc.b	$A3, $A4, $A5, $A6, $A7, $A8, $A9, $AA, $F, $F, $F, $F, $F, $F, $F, $F
	dc.b	$F, $F, $F, $F, $F, $F, $F, $F, $F, $AB, $AC, $AD, $AE, $AF, $B0, $B1
	dc.b	$B2, $B3, $B4, $B5, $F, $F, $F, $F, $F, $F, $F, $F, $F, $F, $F, $F
	dc.b	$F, $F, $F, $F, $F, $F, $B6, $B7, $B8, $B9, $BA, $BB, $BC, $BD, $BE, $BF
	dc.b	$C0, $C1, $C2, $C3, $C4, $F, $F, $F, $F, $F, $C5, $C6, $C7, $C8, $C9, $CA
	dc.b	$F, $F, $F, $F, $F, $F, $F, $CB, $CC, $CD, $CE, $CF, $D0, $D1, $D2, $F
	dc.b	$D3, $D3, $D3, $D3, $D3, $D3, $D3, $D3, $D4, $D5, $D6, $D7, $D8, $D8, $D9, $DA
	dc.b	$DB, $DC, $D3, $D3, $D3, $D3, $D3, $D3, $D3, $D3, $D3, $D3, $D3, $D3, $D3, $D3
	dc.b	$DD, $DD, $DD, $DD, $DD, $DD, $DD, $DE, $DF, $D8, $D8, $D8, $D8, $D8, $D8, $D8
	dc.b	$E0, $E1, $E2, $DD, $DD, $DD, $DD, $DD, $DD, $DD, $DD, $DD, $DD, $DD, $DD, $DD
	dc.b	$E3, $E3, $E3, $E3, $E3, $E3, $E3, $E4, $E5, $D8, $D8, $D8, $D8, $D8, $D8, $D8
	dc.b	$D8, $E0, $E6, $E3, $E3, $E3, $E3, $E3, $E3, $E3, $E3, $E3, $E3, $E3, $E3, $E3

byte_1FA8C:
	dc.b	1, 2, 3, 4, 5, 6, 7, 8, 9, $A, $B, $C, $D, $E, $F, $10
	dc.b	$11, $12, $13, $14, $15, $16, $17, $18, $19, $1A, $1B, $1C, $1D, $1E, $1F, $20
	dc.b	$21, $22, $23, $24, $25, $26, $27, $28, $29, $2A, $2B, $2C, $2D, $2E, $2F, $30
	dc.b	$31, $32, $33, $34, $35, $36, $37, $38, $39, $3A, $3B, $3C, $3D, $3E, $3F, $40
	dc.b	$41, $42, $43, $44, $45, $46, $47, $48, $49, $4A, $4B, $4C, $4D, $4E, $4F, $50
	dc.b	$51, $52, $53, $54, $55, $56, $57, $58, $59, $5A, $5B, $5C, $5D, $5E, $5F, $60
	dc.b	$61, $62, $63, $64, $65, $66, $67, $68, $69, $6A, $6B, $6C, $6D, $6E, $6F, $70
	dc.b	$71, $72, $73, $74, $75, $76, $77, $78, $79, $7A, $7B, $7C, $7D, $7E, $7F, $80
	dc.b	$81, $82, $83, $84, $85, $86, $87, $88, $89, $8A, $8B, $8C, $8D, $8E, $8F, $90
	dc.b	$91, $92, $93, $94, $95, $96, $97, $98, $99, $9A, $9B, $9C, $9D, $9E, $9F, $A0
	dc.b	$A1, $A2, $A3, $A4, $A5, $A6, $A7, $A8, $A9, $AA, $AB, $AC, $AD, $AE, $AF, $B0
	dc.b	$B1, $B2, $B3, $B4, $B5, $B6, $B7, $B8, $B9, $BA, $BB, $BC, $BD, $BE, $BF, $C0
	dc.b	$C1, $C2, $C3, $C4, $C5, $C6, $C7, $C8, $C9, $CA, $CB, $CC, $CD, $CE, $CF, $D0
	dc.b	$D1, $D2, $D3, 4, $D4, $D5, $D6, $D7, 4, $D8, $D9, $DA, $DB, $DC, $DD, $DE

; ===========================================================================

;	include "resource/mapunc/Puyo/Plane Maps/MainMenu.asm"
;	even

Puyo_MainMenu_Maps:	dc.w $11
	dc.l word_1CD32
	dc.l word_1CD3A
	dc.l word_1CD46
	dc.l word_1CD52
	dc.l word_1CD5A
	dc.l word_1CD66
	dc.l word_1CD72
	dc.l word_1CD7E
	dc.l word_1CD8A
	dc.l word_1CD96
	dc.l word_1CDA2
	dc.l word_1CDAE
	dc.l word_1CDBA
	dc.l word_1CDC6
	dc.l word_1CDD2
	dc.l word_1CDDE
	dc.l word_1CDEA

word_1CD32:	dc.w 0
	dc.b $50
	dc.b $1C
	dc.w $C000
	dc.w $8000

word_1CD3A:	dc.w 4
	dc.b $20
	dc.b $E
	dc.w $EE00
	dc.l byte_1DF5A
	dc.w $100

word_1CD46:	dc.w 4
	dc.b 8
	dc.b $E
	dc.w $EE40
	dc.l byte_1E15A
	dc.w $100

word_1CD52:	dc.w 0
	dc.b $80
	dc.b $E
	dc.w $E000
	dc.w $295

word_1CD5A:	dc.w 4
	dc.b $B
	dc.b 5
	dc.w $E004
	dc.l Map_Puyo_CloudB
	dc.w $200

word_1CD66:	dc.w 4
	dc.b $C
	dc.b 4
	dc.w $E438
	dc.l Map_Puyo_CloudA
	dc.w $200

word_1CD72:	dc.w 4
	dc.b $B
	dc.b 5
	dc.w $E934
	dc.l Map_Puyo_CloudB
	dc.w $200

word_1CD7E:	dc.w 4
	dc.b $C
	dc.b 4
	dc.w $E904
	dc.l Map_Puyo_CloudA
	dc.w $200

word_1CD8A:	dc.w 4
	dc.b $B
	dc.b 5
	dc.w $E352
	dc.l Map_Puyo_CloudB
	dc.w $200

word_1CD96:	dc.w 4
	dc.b $C
	dc.b 4
	dc.w $E988
	dc.l Map_Puyo_CloudA
	dc.w $200

word_1CDA2:	dc.w 4
	dc.b $B
	dc.b 5
	dc.w $E970
	dc.l Map_Puyo_CloudB
	dc.w $200

word_1CDAE:	dc.w 4
	dc.b $C
	dc.b 4
	dc.w $E568
	dc.l Map_Puyo_CloudA
	dc.w $200

word_1CDBA:	dc.w 4
	dc.b $B
	dc.b 5
	dc.w $E2A4
	dc.l Map_Puyo_CloudB
	dc.w $200

word_1CDC6:	dc.w 4
	dc.b $C
	dc.b 4
	dc.w $EAC8
	dc.l Map_Puyo_CloudA
	dc.w $200

word_1CDD2:	dc.w 4
	dc.b $B
	dc.b 5
	dc.w $E8AC
	dc.l Map_Puyo_CloudB
	dc.w $200

word_1CDDE:	dc.w 4
	dc.b $C
	dc.b 4
	dc.w $E4BC
	dc.l Map_Puyo_CloudA
	dc.w $200

word_1CDEA:	dc.w 4
	dc.b $1E
	dc.b $16
	dc.w $C30A
	dc.l Map_Puyo_MainMenu
	dc.w $E000

; ---------------------------------------------------------------------------

Map_Puyo_MainMenu:
	dc.b	0, 0, 0, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0, 0, 0
	dc.b	3, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

	dc.b	0, 5, 6, 7, 8, 9, $A, $B, $C, 7, 8, 9, $D, 7, 8
	dc.b	$E, $F, 7, 8, 9, $D, $10, $C, 7, 8, 9, $D, $11, $12, 0

	dc.b	0, $13, $14, $15, $16, $17, $18, $19, $1A, $15, $16, $17, $18, $15, $16
	dc.b	$17, $18, $15, $16, $17, $18, $1B, $1C, $15, $16, $17, $18, $1D, $1E, 0

	dc.b	0, $1F, $20, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21
	dc.b	$21, $21, $21, $21, $21, $21, $22, $23, $21, $21, $21, $21, $24, $25, 0

	dc.b	0, $26, $27, $21, $80, $81, $82, $83, $84, $85, $86, $87, $88, $89, $8A
	dc.b	$8B, $8C, $8D, $8E, $8F, $90, $91, $92, $93, $94, $95, $96, $28, $27, 0

	dc.b	0, $29, $2A, $2B, $A0, $A1, $A2, $A3, $A4, $A5, $A6, $A7, $A8, $A9, $AA
	dc.b	$AB, $AC, $AD, $AE, $AF, $B0, $B1, $B2, $B3, $B4, $B5, $B6, $2C, $2D, 0

	dc.b	0, $2E, $2F, $30, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21
	dc.b	$21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $31, $32, 0

	dc.b	$33, $34, $35, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21
	dc.b	$21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $36, $35, 0

	dc.b	$37, $38, $39, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21
	dc.b	$21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $3A, $39, 0

	dc.b	0, $29, $2D, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21
	dc.b	$21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $3B, $3C, $3D, $3E

	dc.b	0, $2E, $32, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21
	dc.b	$21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $3F, $40, $41, $42

	dc.b	0, $43, $35, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21
	dc.b	$21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $36, $35, 0

	dc.b	0, $44, $39, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21
	dc.b	$21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $3A, $39, 0

	dc.b	0, $45, $46, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21
	dc.b	$21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $47, $46, 0

	dc.b	0, $48, $25, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21
	dc.b	$21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $49, $4A, $4B

	dc.b	0, $43, $35, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21
	dc.b	$21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $36, $4C, $4D

	dc.b	0, $44, $39, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21
	dc.b	$21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $3A, $39, 0

	dc.b	0, $4E, $4F, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21
	dc.b	$21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $50, $4F, 0

	dc.b	0, $51, $52, $21, $21, $21, $21, $21, $21, $21, $53, $54, $21, $21, $21
	dc.b	$21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $21, $55, $56, 0

	dc.b	0, $57, $58, 7, 8, 9, $D, 7, 8, 9, $59, $5A, $C, 7, 8
	dc.b	9, $D, 7, 8, 9, $D, $10, $C, 9, $D, $10, $C, $5B, $5C, 0

	dc.b	0, $5D, $5E, $5F, $60, $61, $62, $63, $64, $61, $62, $65, $66, $5F, $61
	dc.b	$62, $62, $5F, $60, $61, $62, $65, $63, $64, $62, $65, $66, $67, $68, 0

	dc.b	0, 0, 0, 0, 0, 0, 0, $69, $6A, 0, 0, 0, 0, 0, 0
	dc.b	0, 0, 0, 0, 0, 0, 0, $69, $6A, 0, 0, 0, 0, 0, 0

; ---------------------------------------------------------------------------

word_1D34E:	dc.w 2
	dc.l word_1D428
	dc.l word_1D434

; ---------------------------------------------------------------------------

word_1D358:	dc.w 8
	dc.l word_1D428
	dc.l word_1D434
	dc.l word_1D440
	dc.l word_1D44C
	dc.l word_1D458
	dc.l word_1D462
	dc.l word_1D46C
	dc.l word_1D478

; ---------------------------------------------------------------------------

word_1D440:	dc.w 4
	dc.b $20
	dc.b 9
	dc.w $DA00
	dc.l byte_1E1DA
	dc.w $6200

word_1D44C:	dc.w 4
	dc.b 8
	dc.b 9
	dc.w $DA40
	dc.l byte_1E2FA
	dc.w $6200

word_1D458:	dc.w 8
	dc.b 2
	dc.b 3
	dc.w $DD00
	dc.l byte_1E342

word_1D462:	dc.w 8
	dc.b 2
	dc.b 4
	dc.w $DCCC
	dc.l byte_1E34E

word_1D46C:	dc.w 4
	dc.b $20
	dc.b 3
	dc.w $DE80
	dc.l byte_1E35E
	dc.w $E100

word_1D478:	dc.w 4
	dc.b 8
	dc.b 3
	dc.w $DEC0
	dc.l byte_1E3BE
	dc.w $E100

; ---------------------------------------------------------------------------

byte_1E1DA:
	dc.b	$5D, $5E, $5F, 1, 2, 3, 4, $60, $61, 5, $62, $63, $64, $65, $66, $60
	dc.b	$5D, $67, $68, $69, $6A, $6B, $67, $6C, $6D, $5D, $6E, $6F, $70, $5D, $71, 5
	dc.b	$72, $C, $D, $E, $F, $10, $11, $12, $13, $B, $73, $74, $75, $76, $77, $77
	dc.b	$78, $77, $64, $79, $7A, $7B, $77, $7C, $77, $77, $7D, $7E, $7F, $14, $15, $16
	dc.b	$1E, $1F, $20, $21, $22, $23, $24, $25, $26, $27, $32, $7E, $80, $7B, $81, $82
	dc.b	$83, $58, $84, $85, $86, $87, $88, $89, $88, $6C, $80, $8A, $8B, $28, $29, $2A
	dc.b	$62, $33, $34, $35, $36, $37, $38, $39, $3A, $63, 5, $4A, $88, $50, $4F, $4F
	dc.b	$4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4A, $8C, $3B, $3C, $3D
	dc.b	$64, $82, $8C, $67, $8D, $47, $8E, $57, $4A, $89, $50, $4F, $4F, $4F, $4F, $4F
	dc.b	$4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $50, $44, $45, $46
	dc.b	$77, $8F, $90, $45, $51, $91, $87, $6C, $92, $4F, $4F, $4F, $4F, $4F, $4F, $4F
	dc.b	$4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F
	dc.b	0, $5C, $7C, $6C, $44, $57, $50, $93, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F
	dc.b	$4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F
	dc.b	0, 0, $94, $64, $88, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F
	dc.b	$4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F
	dc.b	0, 0, $77, $92, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F
	dc.b	$4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F, $4F

byte_1E2FA:
	dc.b	6, 7, 8, 9, $A, $B, $77, $60, $17, $18, $19, $1A, $1B, $1C, $1D, $5D
	dc.b	$2B, $2C, $2D, $2E, $2F, $30, $31, $32, $3E, $3F, $40, $33, $41, $42, $43, $77
	dc.b	$47, $48, $49, $4A, $4B, $4C, $4D, $4E, $50, $44, $51, $52, $53, $54, $55, 0
	dc.b	$4F, $50, $56, $57, $58, $59, 0, 0, $4F, $4F, $5A, $5B, $5C, $55, 0, 0
	dc.b	$4F, $4F, $4F, $50, $5C, $54, 0, 0

byte_1E342:
	dc.b	$E1, $C0, $E2, $5C, $E1, $C1, $E1, $C2, $E1, $C3, $E1, $C4

byte_1E34E:
	dc.b	$E2, $55, $E1, $CA, $E1, $EB, $E1, $EC, $E1, $ED, $E1, $EE, $E1, $EF, $E1, $F0

byte_1E35E:
	dc.b	$C5, $C6, $C7, $C8, $C9, $C0, $FC, $FC, $FC, $FC, $FC, $FC, $FC, $FC, $FC, $FC
	dc.b	$FC, $FC, $FC, $FC, $CA, $C8, $C9, $C0, $FC, $FC, $FC, $FC, $FC, $FC, $CA, $C8
	dc.b	$CB, $CC, $CD, $CE, $CF, $D0, $D1, $D2, $D3, $D4, $D5, $D6, $D7, $D8, $D9, $DA
	dc.b	$D3, $D4, $D5, $D6, $CD, $CE, $CF, $D0, $D1, $D2, $D3, $D4, $D5, $D6, $CD, $CE
	dc.b	$DB, $DC, $DD, $DE, $DF, $E0, $E1, $E2, $E3, $E4, $DF, $E5, $E6, $E7, $E8, $E9
	dc.b	$E3, $E4, $DF, $E5, $DD, $DE, $DF, $E0, $E1, $EA, $E3, $E4, $DF, $E5, $DD, $DE

byte_1E3BE:
	dc.b	$F1, $C0, $FC, $FC, $F2, $F3, $F4, $F5, $CF, $D0, $D1, $D2, $F6, $F7, $F8, $F9
	dc.b	$DF, $E0, $E1, $EA, $E3, $E4, $FA, $FB

; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------

word_1D428:	dc.w 4
	dc.b $20
	dc.b $10
	dc.w $D200
	dc.l byte_1DF5A
	dc.w $2100

word_1D434:	dc.w 4
	dc.b 8
	dc.b $10
	dc.w $D240
	dc.l byte_1E15A
	dc.w $2100

; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------

byte_1DF5A:
	dc.b	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
	dc.b	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
	dc.b	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
	dc.b	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
	dc.b	1, 1, 2, 3, 2, 4, 5, 6, 1, 1, 1, 1, 1, 1, 1, 1
	dc.b	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2
	dc.b	7, 8, 9, $A, $B, $C, $D, $E, $F, $10, 1, 1, 1, 1, 1, 1
	dc.b	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 7, $11, 8, 9
	dc.b	$16, $17, $18, $19, $1A, $B, $1B, $1C, $1D, $1E, $1F, 1, 1, 1, 1, 1
	dc.b	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, $20, $12, $16, $21, $17
	dc.b	$23, $26, $E, $23, $27, $28, $29, $2A, $2B, $2C, $D, $2D, 1, 1, 1, 1
	dc.b	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, $2E, $23, $2F, $13, $30, $31
	dc.b	$35, $36, $C, $D, $37, $38, $39, $27, $3A, $3B, $3C, $3D, 1, 1, 1, 1
	dc.b	1, 1, 1, 1, 1, 1, 1, 1, 1, $3E, $F, $A, $23, $26, $3F, $23
	dc.b	$D, $23, $22, $2C, $43, $36, $C, $44, $34, $1C, $29, $1C, $45, 1, 1, 1
	dc.b	1, 1, 1, 1, 1, 1, 1, 1, 1, $11, $46, $18, $35, $E, $D, $23
	dc.b	$48, $49, $4A, $4B, $22, $4C, $4D, $4E, $22, $4F, $2A, $29, $50, $51, 1, 1
	dc.b	1, 1, 1, 1, 1, 1, 1, 1, $2E, $B, $52, $23, $18, $4B, $48, $49
	dc.b	$55, $56, $57, $58, $59, $29, $3C, $D, $5A, $23, $47, $5B, $5C, $5D, 1, 1
	dc.b	1, 1, 1, 1, 1, 1, 1, $5E, $49, $1A, $3F, $5F, $60, $55, $56, $E
	dc.b	$63, $55, $64, $65, $49, $66, $67, $68, $69, $32, $24, $28, $6A, $2D, 1, 1
	dc.b	1, 1, 1, 1, 1, 1, 1, $3E, $4D, $5A, $63, $6B, $64, $6C, $6D, $57
	dc.b	$D, $6C, $70, $47, $71, $72, $73, $74, $75, $59, $76, $3A, $1F, $5D, 1, 1
	dc.b	1, 1, 1, 1, 1, 1, 1, $77, $38, $32, $2A, $D, $78, $79, $7A, $73
	dc.b	$48, $7F, $80, $81, $82, $83, $84, $85, $86, $7E, $2C, $53, $87, 1, 1, 1
	dc.b	1, 1, 1, 1, 1, 1, 1, $88, $F, $B, $49, $66, $7F, $89, $8A, $8B
	dc.b	$56, $E, $1C, $94, $95, $96, $97, $98, $7F, $4B, $99, $9A, 1, 1, 1, 1
	dc.b	1, 1, 1, 1, 1, 1, 1, 1, $9B, $9C, $9D, $9C, $28, $9E, $9F, $A0
	dc.b	$A7, $A8, $A9, $AA, $AB, $AC, $AD, $AE, $A7, $A8, $AF, $B0, $B0, $B0, $B0, $B0
	dc.b	$B0, $B0, $B0, $B0, $B0, $B0, $B0, $B0, $B0, $B0, $B0, $B0, $A7, $B1, $A8, $A9
	dc.b	$B8, $B8, $B8, $B9, $BA, $BB, $BC, $B8, $B8, $B8, $B8, $B8, $B8, $B8, $B8, $B8
	dc.b	$B8, $B8, $B8, $B8, $B8, $B8, $B8, $B8, $B8, $B8, $B8, $B8, $B8, $B8, $B8, $B8

byte_1E15A:
	dc.b	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
	dc.b	3, 2, 4, 5, 6, 1, 1, 1, $12, $B, $13, $14, $A, $F, $15, $10
	dc.b	$22, $19, $23, $B, $1B, $1C, $24, $25, $32, $1D, $27, $28, $29, $33, $2B, $34
	dc.b	$18, $40, $37, $38, $39, $41, $3A, $42, $47, $2C, $43, $36, $C, $44, $34, $1C
	dc.b	$4A, $53, $22, $4C, $4D, $4E, $54, $4F, $32, $59, $29, $3C, $61, $22, $29, $62
	dc.b	$58, $1E, $6E, $6F, $54, $E, $69, $24, $65, $71, $7B, $7C, $44, $7D, $7E, $76
	dc.b	$8C, $8D, $8E, $8F, $90, $91, $92, $93, $A1, $A2, $A3, $A4, $A5, $A6, $4B, $38
	dc.b	$B2, $B3, $B4, $B5, $B6, $AE, $A9, $B7, $B8, $BD, $BE, $83, $BF, $B8, $B8, $B8

; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------

word_1D37A:	dc.w 8
	dc.l word_1D484
	dc.l word_1D48C
	dc.l word_1D498
	dc.l word_1D4A4
	dc.l word_1D4B0
	dc.l word_1D4BC
	dc.l word_1D4C8
	dc.l word_1D4D4

; ---------------------------------------------------------------------------

word_1D48C:	dc.w 4
	dc.b $B
	dc.b 5
	dc.w $F480
	dc.l Map_Puyo_CloudB
	dc.w $2200

word_1D498:	dc.w 4
	dc.b $B
	dc.b 5
	dc.w $F518
	dc.l Map_Puyo_CloudB
	dc.w $2200

word_1D4A4:	dc.w 4
	dc.b $B
	dc.b 5
	dc.w $F534
	dc.l Map_Puyo_CloudB
	dc.w $2200

word_1D4B0:	dc.w 4
	dc.b $B
	dc.b 5
	dc.w $F4D2
	dc.l Map_Puyo_CloudB
	dc.w $2200

word_1D4BC:	dc.w 4
	dc.b $B
	dc.b 5
	dc.w $F568
	dc.l Map_Puyo_CloudB
	dc.w $2200

word_1D4C8:	dc.w 4
	dc.b $B
	dc.b 5
	dc.w $F780
	dc.l Map_Puyo_CloudB
	dc.w $2200

word_1D4D4:	dc.w 4
	dc.b $B
	dc.b 5
	dc.w $F79C
	dc.l Map_Puyo_CloudB
	dc.w $2200

; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------

word_1D3BE:	dc.w 2
	dc.l word_1D484
	dc.l word_1D420

; ---------------------------------------------------------------------------

word_1D420:	dc.w 0
	dc.b $40
	dc.b $40
	dc.w $C000
	dc.w $2200

; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------

word_1D484:	dc.w 0
	dc.b $40
	dc.b $40
	dc.w $E000
	dc.w $2200

; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------

word_1D39C:	dc.w 8
	dc.l word_1D4E0
	dc.l word_1D4EC
	dc.l word_1D4F8
	dc.l word_1D504
	dc.l word_1D510
	dc.l word_1D51C
	dc.l word_1D528
	dc.l word_1D534

; ---------------------------------------------------------------------------

word_1D4E0:	dc.w 4
	dc.b $B
	dc.b 5
	dc.w $F832
	dc.l Map_Puyo_CloudB
	dc.w $2200

word_1D4EC:	dc.w 4
	dc.b $B
	dc.b 5
	dc.w $F7CC
	dc.l Map_Puyo_CloudB
	dc.w $2200

word_1D4F8:	dc.w 4
	dc.b $B
	dc.b 5
	dc.w $F864
	dc.l Map_Puyo_CloudB
	dc.w $2200

word_1D504:	dc.w 4
	dc.b $C
	dc.b 4
	dc.w $FB04
	dc.l Map_Puyo_CloudA
	dc.w $2200

word_1D510:	dc.w 4
	dc.b $C
	dc.b 4
	dc.w $FAA4
	dc.l Map_Puyo_CloudA
	dc.w $2200

word_1D51C:	dc.w 4
	dc.b $C
	dc.b 4
	dc.w $FABE
	dc.l Map_Puyo_CloudA
	dc.w $2200

word_1D528:	dc.w 4
	dc.b $C
	dc.b 4
	dc.w $FB5C
	dc.l Map_Puyo_CloudA
	dc.w $2200

word_1D534:	dc.w 4
	dc.b 3
	dc.b 2
	dc.w $FC78
	dc.l byte_1E43E
	dc.w $2200

; ---------------------------------------------------------------------------

byte_1E43E:
	dc.b	$E6, $E7, $E8, $E9, $EA, $EB

; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------

Map_Puyo_CloudB:
	dc.b	0, 0, 0, $BB, $BC, $BD, $BE, $BF, $C0, $C1, 0, 0, $C2, $C3, $C4, $A2
	dc.b	$C5, $C6, $C7, $C8, $C9, $CA, $CB, $CC, $CD, $CE, $CF, $D0, $D1, $D2, $D3, $D4
	dc.b	$D5, $D6, $D7, $D8, $D9, $DA, $DB, $DC, $DD, $DE, $DF, $B1, 0, $E0, $E1, $E2
	dc.b	$E3, $E4, $E5, $B8, $B9, $BA, 0, 0

Map_Puyo_CloudA:
	dc.b	0, $96, $97, $98, $99, $9A, $9B, $9C, $9D, $9E, 0, 0, $9F, $A0, $A1, $A2
	dc.b	$A2, $A2, $A2, $A2, $A2, $A3, $A4, $A5, $A6, $A7, $A8, $A9, $AA, $AB, $AC, $AD
	dc.b	$AE, $AF, $B0, $B1, 0, $B2, $B3, $B4, $B5, $B6, $B7, $B8, $B9, $BA, 0, 0

; ===========================================================================

word_1D540:	dc.w 2
	dc.l word_1D5A4
	dc.l word_1D5B0

; ---------------------------------------------------------------------------

word_1D54A:	dc.w $C
	dc.l word_1D58C
	dc.l word_1D598
	dc.l word_1D5A4
	dc.l word_1D5B0
	dc.l word_1D5BC
	dc.l word_1D5C8
	dc.l word_1D5D4
	dc.l word_1D5DC
	dc.l word_1D5E6
	dc.l word_1D5F2
	dc.l word_1D57C
	dc.l word_1D584

word_1D57C:	dc.w 0
	dc.b $28
	dc.b 4
	dc.w $C000
	dc.w $A100

word_1D584:	dc.w 0
	dc.b $28
	dc.b 8
	dc.w $E000
	dc.w $2100

word_1D58C:	dc.w 4
	dc.b $20
	dc.b 8
	dc.w $DC10
	dc.l byte_1E444
	dc.w $A100

word_1D598:	dc.w 4
	dc.b 8
	dc.b 8
	dc.w $DC00
	dc.l byte_1E544
	dc.w $A100

word_1D5A4:	dc.w 4
	dc.b $15
	dc.b $14
	dc.w $D226
	dc.l byte_1E584
	dc.w $A100

word_1D5B0:	dc.w 4
	dc.b $13
	dc.b $14
	dc.w $D200
	dc.l byte_1E728
	dc.w $A200

word_1D5BC:	dc.w 4
	dc.b $20
	dc.b $C
	dc.w $F600
	dc.l byte_1E8A4
	dc.w $6200

word_1D5C8:	dc.w 4
	dc.b 8
	dc.b $C
	dc.w $F640
	dc.l byte_1EA24
	dc.w $6200

word_1D5D4:	dc.w 0
	dc.b $28
	dc.b 8
	dc.w $FC00
	dc.w $62BC

word_1D5DC:	dc.w 8
	dc.b $A
	dc.b 3
	dc.w $FABC
	dc.l byte_1EA84

word_1D5E6:	dc.w 4
	dc.b 3
	dc.b 6
	dc.w $D6A6
	dc.l byte_1D5FE
	dc.w $2100

word_1D5F2:	dc.w 4
	dc.b 4
	dc.b 8
	dc.w $D59C
	dc.l byte_1D610
	dc.w $2200

; ---------------------------------------------------------------------------

byte_1E444:
	dc.b	1, 2, 3, 4, 5, 6, 6, 6, 7, 8, 7, 8, 7, 9, $A, 9
	dc.b	$A, $B, $A, $C, $D, $E, $F, $10, $11, 6, $12, $13, $14, $15, $16, $D
	dc.b	$17, $18, $19, $1A, $1B, $18, $19, $1C, $1B, $18, $19, $1C, $1D, $1E, $1F, $20
	dc.b	$21, $1F, $22, $23, $21, $1F, $24, $25, $26, $27, $28, $29, $21, $1F, $23, $2A
	dc.b	$2B, $2C, $2D, $2E, $2B, $2C, $2D, $2E, $2B, $2C, $2D, $2E, $2B, $2B, $2C, $2E
	dc.b	$2B, $2C, $2D, $2E, $2B, $2C, $2D, $2E, $2B, $2C, $2D, $2E, $2B, $2C, $2D, $2E
	dc.b	$2F, $30, $31, $32, $2F, $30, $31, $32, $2F, $33, $34, $33, $31, $32, $2F, $30
	dc.b	$31, $32, $2F, $2F, $30, $31, $32, $2F, $30, $31, $32, $2F, $30, $31, $32, $2F
	dc.b	$35, $36, $36, $35, $36, $37, $35, $36, $38, $39, $3A, $3B, $35, $36, $38, $39
	dc.b	$3B, $3A, $39, $38, $36, $35, $37, $35, $36, $35, $36, $3A, $35, $36, $35, $36
	dc.b	$3C, $3C, $3C, $3C, $3C, $3C, $3C, $3C, $3C, $3C, $3C, $3C, $3C, $3C, $3C, $3C
	dc.b	$3C, $3C, $3C, $3C, $3C, $3C, $3C, $3C, $3C, $3C, $3C, $3C, $3C, $3C, $3C, $3C
	dc.b	$3D, $3E, $3E, $3D, $3E, $3F, $3D, $3E, $40, $40, $41, $42, $43, $44, $45, $43
	dc.b	$42, $41, $40, $40, $3E, $3D, $3F, $3D, $3E, $3D, $3E, $41, $3D, $3E, $3D, $3E
	dc.b	$4A, $4A, $4A, $4A, $4A, $4A, $4A, $4A, $4A, $4A, $4A, $4A, $4A, $4A, $4A, $4A
	dc.b	$4A, $4A, $4A, $4A, $4A, $4A, $4A, $4A, $4A, $4A, $4A, $4A, $4A, $4A, $4A, $4A

byte_1E544:
	dc.b	$A, $4B, $4C, $4D, $4E, $4F, $50, $51, $52, $53, $54, $55, $56, $57, $58, $1C
	dc.b	$2B, $59, $5A, $5B, $2B, $2C, $2D, $2E, $33, $31, $32, $2F, $34, $33, $31, $32
	dc.b	$35, $36, $37, $35, $36, $38, $35, $36, $3C, $3C, $3C, $3C, $3C, $3C, $3C, $3C
	dc.b	$3D, $3E, $3F, $3D, $3E, $40, $3D, $3E, $4A, $4A, $4A, $4A, $4A, $4A, $4A, $4A

byte_1E584:
	dc.b	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, $5E, $5F, $60
	dc.b	$61, $62, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b	0, 0, $65, $66, $67, $68, $69, 0, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b	0, 0, 0, 0, 0, 0, 0, $65, $66, $6C, $68, $69, 0, 0, 0, 0
	dc.b	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, $65, $66, $67, $6F
	dc.b	$69, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b	0, $71, $72, $67, $6F, $69, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b	$74, $75, 0, 0, 0, 0, $5E, $5F, $76, $77, $78, 0, 0, 0, 0, 0
	dc.b	0, 0, 0, 0, 0, $7A, $7B, $7C, 0, 0, 0, $7D, $7E, $7F, $80, $81
	dc.b	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, $83, $84, $85, 0, 0, 0
	dc.b	$86, $87, $67, $88, $89, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, $8B
	dc.b	$8C, $8D, 0, 0, 0, $5E, $5F, $60, $61, $62, 0, 0, 0, $46, $47, 0
	dc.b	0, 0, 0, 0, $8F, $90, $91, 0, 0, 0, $65, $66, $6C, $68, $69, 0
	dc.b	0, 0, $6A, $6B, 0, 0, 0, 0, 0, $92, $93, $8D, 0, 0, 0, $71
	dc.b	$72, $67, $6F, $69, 0, 0, 0, $94, $64, 0, 0, 0, 0, 0, $95, $8C
	dc.b	$96, 0, 0, 0, $65, $66, $6C, $68, $69, 0, 0, 0, $97, $5D, 0, 0
	dc.b	0, 0, 0, $83, $98, $99, 0, 0, 0, $71, $72, $67, $6F, $69, 0, 0
	dc.b	$9A, $82, $64, $9B, 0, 0, 0, 0, $8B, $9C, $91, $9D, $9E, 0, $5E, $5F
	dc.b	$60, $61, $62, 0, $9F, $A0, $A1, $6B, $A2, $A3, $A4, $A5, 0, $92, $93, $8D
	dc.b	$A6, $A7, $A8, $65, $66, $6C, $68, $69, $A9, $AA, $AB, $AC, $AD, $AE, $AF, $B0
	dc.b	$B1, $B2, $95, $8C, $B3, $B4, $B5, $B6, $71, $72, $67, $6F, $69, $B7, $B5, $B6
	dc.b	$B8, $B9, $BA, $BB, $BC, $BD, $BE, $BF, $C0, $C1, $C2, $C3, $C4, $C5, $C6, $C7
	dc.b	$C8, $C9, $CA, $CB, $CC, $CD, $CE, $CF, $D0, $CB, $D1, $D2, $D3, $D4, $D5, $D6
	dc.b	$D7, $D8, $D9, $DA, $DB, $DC, $DD, $DE, 6, 6, $DF, $E0, $E1, $E2, $E3, $E4
	dc.b	$E5, $E6, $E7, $E8, $E9, $EA, $EB, $EC, $ED, $EE, $EF, 6, 6, 6, 6, $F0
	dc.b	$F1, $F2, $F3, $F4, $F5, $F6, $F7, $F8, $F9, $FA, $FB, $FC, $FD, $FE, $FF, $FE
	dc.b	$FF, $FE, $FF, $FE

byte_1E728:
	dc.b	0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 0, 0, 0, 0
	dc.b	0, 0, 0, 0, 0, 0, 0, 0, 8, 9, $A, 4, 5, 6, 7, 0
	dc.b	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, $B, 9, $C, 4, 5
	dc.b	6, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, $D, $E
	dc.b	$F, 4, 5, 6, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b	0, $10, $11, $12, 4, 5, 6, 7, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b	0, 0, 0, 0, $13, $14, $15, 4, 5, $16, 7, 0, 0, 0, 0, 0
	dc.b	0, 0, 0, 0, 0, 0, 0, $17, 9, $18, 4, 5, 6, 7, 0, 0
	dc.b	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, $19, $1A, $1B, $1C, $1D, $1E
	dc.b	$1F, 0, 0, 0, $20, 0, 0, 0, 0, 0, 0, 0, 0, $21, $22, $23
	dc.b	$24, $25, $26, $1F, 0, 0, 0, $27, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b	$28, 9, $29, $2A, 5, 6, 7, 0, 0, 0, $2B, 0, $20, 0, 0, 0
	dc.b	0, 0, 0, $17, 9, $18, 4, 5, 6, 7, 0, 0, 0, $2C, 0, $27
	dc.b	0, 0, 0, 0, 0, 0, $13, $14, $15, 4, 5, $16, 7, 0, 0, 0
	dc.b	$2D, 0, $2D, 0, $2E, 0, 0, 0, 0, $10, $11, $12, 4, 5, 6, 7
	dc.b	0, 0, 0, $2D, 0, $2C, 0, $2F, $30, $31, $32, 0, $D, $E, $F, 4
	dc.b	5, 6, 7, 0, 0, 0, $33, 0, $2D, 0, $34, $35, $36, $37, 0, $B
	dc.b	9, $C, 4, 5, 6, 7, 0, 0, $38, $39, 0, $2C, 0, $3A, $3B, $3C
	dc.b	$3D, $3E, 8, 9, $A, 4, 5, 6, 7, $3F, $40, $41, $42, $43, $44, $45
	dc.b	$46, $46, $47, $48, $49, 1, 2, 3, 4, 5, 6, 7, $4A, $4B, $4C, $4D
	dc.b	$4E, $4F, $50, $46, $46, $51, $52, $53, $19, $1A, $1B, $1C, $1D, $1E, $1F, $54
	dc.b	$55, $56, $57, $58, $59, $5A, $46, $5B, $5C, $5D, $5E, $5F, $60, $61, $62, $63
	dc.b	$64, $65, $66, $46, $46, $67, $68, $69, $6A, $6B, $6C, $6D, $6E, $6F, $70, $71
	dc.b	$72, $73, $74, $75, $76, $46, $46, $46, $46, $6B, $77, $78

byte_1E8A4:
	dc.b	$79, $79, $79, $79, $79, $79, $79, $79, $79, $79, $79, $79, $79, $79, $79, $79
	dc.b	$79, $79, $79, $79, $79, $79, $79, $79, $79, $79, $79, $79, $79, $79, $79, $79
	dc.b	$7A, $7A, $7A, $7A, $7A, $7A, $7A, $7A, $7A, $7A, $7A, $7A, $7A, $7A, $7A, $7A
	dc.b	$7A, $7A, $7A, $7A, $7A, $7A, $7A, $7A, $7A, $7A, $7A, $7A, $7A, $7A, $7A, $7A
	dc.b	$7B, $7B, $7B, $7B, $7B, $7B, $7B, $7B, $7B, $7B, $7B, $7B, $7B, $7B, $7B, $7B
	dc.b	$7B, $7B, $7B, $7B, $7B, $7B, $7B, $7B, $7B, $7B, $7B, $7B, $7B, $7B, $7B, $7B
	dc.b	$7C, $7C, $7C, $7C, $7C, $7C, $7C, $7C, $7C, $7C, $7C, $7C, $7C, $7C, $7C, $7C
	dc.b	$7C, $7C, $7C, $7C, $7C, $7C, $7C, $7C, $7C, $7C, $7C, $7C, $7C, $7C, $7C, $7C
	dc.b	$7D, $7D, $7D, $7D, $7D, $7D, $7D, $7D, $7D, $7D, $7D, $7D, $7D, $7D, $7D, $7D
	dc.b	$7D, $7D, $7D, $7D, $7D, $7D, $7D, $7D, $7D, $7D, $7D, $7D, $7D, $7D, $7D, $7D
	dc.b	$7E, $7E, $7E, $7E, $7E, $7E, $7E, $7E, $7E, $7E, $7E, $7E, $7E, $7E, $7E, $7E
	dc.b	$7E, $7F, $80, $81, $82, $83, $84, $85, $86, $7E, $7E, $7E, $7E, $7E, $7E, $7E
	dc.b	$87, $87, $87, $87, $87, $87, $87, $87, $87, $87, $87, $87, $87, $87, $87, $87
	dc.b	$88, $89, $8A, $8B, $8C, $8D, $8E, $8F, $90, $91, $87, $87, $87, $87, $87, $87
	dc.b	$92, $92, $92, $92, $92, $92, $92, $92, $92, $92, $92, $92, $92, $92, $93, $94
	dc.b	$95, $96, $97, $98, $99, $9A, $9B, $9C, $9D, $9E, $9F, $A0, $92, $92, $92, $92
	dc.b	$A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $A2, $A3, $A4, $A5
	dc.b	$A6, $A7, $A8, $A9, $AA, $AB, $AC, $AD, $AE, $AF, $B0, $B1, $B2, $B3, $A1, $A1
	dc.b	$B4, $B4, $B4, $B4, $B4, $B4, $B4, $B4, $B4, $B5, $B6, $B7, $B8, $B9, $BA, $BB
	dc.b	$BC, $BD, $BE, $BF, $C0, $BC, $BC, $BC, $BC, $BC, $BC, $BC, $BC, $C1, $B7, $B6
	dc.b	$C2, $C2, $C2, $C2, $C2, $C2, $C3, $C4, $C5, $C6, $BC, $BC, $BC, $BC, $BC, $BC
	dc.b	$BC, $BC, $BC, $BC, $BC, $BC, $BC, $BC, $BC, $BC, $BC, $BC, $BC, $BC, $BC, $BC
	dc.b	$C7, $C8, $C9, $CA, $CB, $CC, $BC, $BC, $BC, $BC, $BC, $BC, $BC, $BC, $BC, $BC
	dc.b	$BC, $BC, $BC, $BC, $BC, $BC, $BC, $BC, $BC, $BC, $BC, $BC, $BC, $BC, $BC, $BC

byte_1EA24:
	dc.b	$79, $79, $79, $79, $79, $79, $79, $79, $7A, $7A, $7A, $7A, $7A, $7A, $7A, $7A
	dc.b	$7B, $7B, $7B, $7B, $7B, $7B, $7B, $7B, $7C, $7C, $7C, $7C, $7C, $7C, $7C, $7C
	dc.b	$7D, $7D, $7D, $7D, $7D, $7D, $7D, $7D, $7E, $7E, $7E, $7E, $7E, $7E, $7E, $7E
	dc.b	$87, $87, $87, $87, $87, $87, $87, $87, $92, $92, $92, $92, $92, $92, $92, $92
	dc.b	$A1, $A1, $A1, $A1, $A1, $A1, $A1, $A1, $B5, $B4, $B4, $B4, $B4, $B4, $B4, $B4
	dc.b	$C6, $C5, $C4, $C3, $C2, $C2, $C2, $C2, $BC, $BC, $BC, $BC, $CC, $CB, $CA, $C9

byte_1EA84:
	dc.b	$6A, $B7, $6A, $B6, $6A, $B5, $6A, $B4, $62, $B4, $62, $B4, $62, $B4, $62, $B4
	dc.b	$62, $B4, $62, $B4, $62, $BC, $62, $BC, $6A, $C6, $6A, $C5, $6A, $C4, $6A, $C3
	dc.b	$62, $C2, $62, $C2, $62, $C2, $62, $C2, $62, $BC, $62, $BC, $62, $BC, $62, $BC
	dc.b	$62, $BC, $62, $BC, $6A, $CC, $6A, $CB, $6A, $CA, $6A, $C9

byte_1D5FE:
	dc.b	$46, $47, 0, $6A, $6B, 0, $94, $64, 0, $97, $5D, 0, $82, $64, $9B, $A1
	dc.b	$6B, $A2

byte_1D610:
	dc.b	0, $20, 0, 0, 0, $27, 0, 0, 0, $2B, 0, $20, 0, $2C, 0, $27
	dc.b	0, $2D, 0, $2D, 0, $2D, 0, $2C, 0, $33, 0, $2D, $38, $39, 0, $2C

; ===========================================================================

word_1D630:	dc.w 7
	dc.l word_1D64E
	dc.l word_1D656
	dc.l word_1D662
	dc.l word_1D66E
	dc.l word_1D67A
	dc.l word_1D686
	dc.l word_1D692

word_1D64E:	dc.w 0
	dc.b $40
	dc.b $E
	dc.w $D200
	dc.w $A200

word_1D656:	dc.w 4
	dc.b $20
	dc.b $F
	dc.w $D890
	dc.l byte_1EAC0
	dc.w $A100

word_1D662:	dc.w 4
	dc.b 8
	dc.b $E
	dc.w $D900
	dc.l byte_1ECA0
	dc.w $A100

word_1D66E:	dc.w 4
	dc.b $20
	dc.b $E
	dc.w $F640
	dc.l byte_1ED10
	dc.w $2200

word_1D67A:	dc.w 4
	dc.b $20
	dc.b $E
	dc.w $F610
	dc.l byte_1ED10
	dc.w $2200

word_1D686:	dc.w 4
	dc.b 8
	dc.b $E
	dc.w $F600
	dc.l byte_1EED0
	dc.w $2200

word_1D692:	dc.w 0
	dc.b $40
	dc.b 6
	dc.w $FD00
	dc.w $22AE

; ---------------------------------------------------------------------------

byte_1EAC0:
	dc.b	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 0, 0, 0, 0
	dc.b	0, 0, 3, 4, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0
	dc.b	6, 7, 8, 6, 9, $A, $B, $C, $D, $E, $F, $10, $11, $12, $13, 9
	dc.b	$A, $14, $15, $16, $17, 7, 8, 6, 9, $18, $19, $1A, $C, $D, $1B, $A
	dc.b	$1C, $1D, $1E, $1F, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $2A, $2B
	dc.b	$2C, $2D, $2E, $2F, $30, $31, $32, $33, $34, $35, $36, $37, $38, $39, $3A, $3B
	dc.b	$3C, $3D, $3E, $3F, $40, $41, $42, $43, $44, $45, $46, $47, $48, $49, $4A, $4B
	dc.b	$4C, $4D, $4E, $4F, $50, $51, $52, $53, $54, $55, $56, $57, $58, $59, $5A, $5B
	dc.b	$5C, $5D, $5E, $5D, $5F, $60, $61, $62, $63, $64, $65, $66, $67, $68, $62, $61
	dc.b	$69, $6A, $6B, $6C, $6D, $6E, $6F, $70, $71, $72, $73, $74, $75, $76, $77, $78
	dc.b	$79, $7A, $79, $79, $79, $7B, $79, $7B, $79, $7C, $7D, $7E, $7F, $7B, $79, $79
	dc.b	$79, $80, $81, $82, $83, $79, $79, $79, $84, $85, $86, $87, $88, $89, $8A, $8B
	dc.b	$79, $8C, $79, $8C, $8D, $8E, $8D, $8E, $79, $8C, $79, $8C, $79, $8C, $79, $8C
	dc.b	$79, $8F, $90, $91, $92, $8C, $8C, $79, $8C, $93, $94, $95, $96, $97, $98, $99
	dc.b	$8D, $8E, $8D, $8E, $9A, $9B, $9C, $9D, $9E, $8E, $8D, $7A, $8D, $8E, $8D, $8E
	dc.b	$8D, $8E, $8D, $8E, $8D, $8E, $8D, $8E, $8D, $8E, $9F, $A0, $A1, $A2, $A3, $A4
	dc.b	$A5, $A6, $A5, $A6, $A7, $A8, $A9, $AA, $8D, $A6, $A5, $A6, $AB, $A6, $AB, $A6
	dc.b	$AC, $A6, $AB, $A6, $AB, $AC, $AB, $A6, $AB, $A6, $AB, $A6, $AD, $AE, $AF, $B0
	dc.b	$7A, $B1, $B2, $B2, $B3, $B1, $B1, $B2, $B3, $B1, $B2, $B3, $B1, $B1, $B2, $B3
	dc.b	$B1, $7A, $B2, $B1, $B3, $B1, $B2, $B4, $B3, $B5, $B2, $B1, $8C, $79, $B3, $B1
	dc.b	$B6, $B7, $B8, $B8, $B6, $7A, $B7, $B6, $B8, $B6, $B8, $B6, $7A, $B7, $B8, $B6
	dc.b	$B7, $B7, $B8, $B6, $B7, $B8, $B7, $B9, $B6, $B7, $B9, $B6, $BA, $BB, $B6, $B7
	dc.b	$BC, $BD, $BD, $BE, $BF, $BD, $BC, $BD, $BD, $BC, $BD, $BD, $BC, $BD, $BD, $BE
	dc.b	$C0, $BD, $BC, $BD, $BD, $BC, $BD, $BD, $BC, $BD, $BD, $BC, $C1, $C2, $BC, $C3
	dc.b	$C4, $C5, $C6, $C3, $C5, $C6, $C4, $C5, $C6, $C4, $C5, $C6, $B5, $C5, $C6, $C4
	dc.b	$C7, $C6, $C4, $C5, $C6, $C4, $B5, $C6, $C8, $C9, $CA, $C4, $C5, $C6, $C4, $C5
	dc.b	$CB, $CC, $CD, $CB, $CC, $CD, $CB, $CC, $C8, $C9, $CA, $CD, $CB, $CC, $CD, $CB
	dc.b	$CC, $CD, $B5, $CC, $CD, $CB, $CC, $CD, $CE, $CF, $D0, $CB, $CC, $CD, $CB, $CC
	dc.b	$D1, $D2, $D3, $D4, $D0, $D5, $D1, $D2, $CE, $CF, $D0, $D5, $D1, $D2, $D3, $D4
	dc.b	$C3, $D5, $D1, $D2, $B5, $D4, $D0, $D5, $D1, $D2, $D3, $D4, $D0, $D5, $D1, $7A

byte_1ECA0:
	dc.b	$13, 9, $A, $B, $13, 9, 7, 8, $1E, $1C, $D6, $D7, $D8, $1C, $D9, $DA
	dc.b	$DB, $DB, $DC, $DD, $DE, $DF, $E0, $E1, $E2, $E3, $E4, $E2, $E3, $E4, $E2, $E3
	dc.b	$79, $79, $79, $79, $79, $79, $79, $79, $79, $79, $8C, $79, $79, $79, $8C, $79
	dc.b	$8D, $8D, $8E, $8D, $8D, $8D, $8E, $8D, $A5, $A5, $A6, $A5, $A5, $A5, $A6, $A5
	dc.b	$B2, $B3, $B1, $B2, $B2, $7A, $B1, $B2, $B8, $7A, $B7, $B8, $B8, $B6, $B7, $B8
	dc.b	$BD, $BC, $BD, $BD, $BD, $BC, $BD, $BD, $C6, $C6, $C4, $C5, $BE, $C0, $C5, $C6
	dc.b	$CD, $CD, $CB, $CC, $C4, $C7, $CC, $CD, $D3, $D3, $B5, $D2, $D3, $D1, $D2, $D3

byte_1ED10:
	dc.b	1, 2, 3, 4, 5, 6, 7, 8, 9, $A, $B, $C, $D, 1, 2, 3
	dc.b	4, 5, 6, 7, 8, 9, $A, $B, $C, $D, 1, 2, 3, 4, 5, 6
	dc.b	$E, $F, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $1A, $E, $F, $10
	dc.b	$11, $12, $13, $14, $15, $16, $17, $18, $19, $1A, $E, $F, $10, $11, $12, $13
	dc.b	$1B, $1C, $1D, $1E, $1F, $20, $21, $22, $23, $24, $25, $26, $27, $1B, $1C, $1D
	dc.b	$1E, $1F, $20, $21, $22, $23, $24, $25, $26, $27, $1B, $1C, $1D, $1E, $1F, $20
	dc.b	$28, $29, $2A, $2B, $2C, $2D, $2E, $2F, $30, $31, $32, $33, $34, $28, $29, $2A
	dc.b	$2B, $2C, $2D, $2E, $2F, $30, $31, $32, $33, $34, $28, $29, $2A, $2B, $2C, $2D
	dc.b	$35, $36, $37, $38, $39, $3A, $3B, $3C, $3D, $3E, $3F, $40, $41, $35, $36, $37
	dc.b	$38, $39, $3A, $3B, $3C, $3D, $3E, $3F, $40, $41, $35, $36, $37, $38, $39, $3A
	dc.b	$42, $43, $44, $45, $46, $47, $48, $49, $4A, $4B, $4C, $4D, $4E, $42, $43, $44
	dc.b	$45, $46, $47, $48, $49, $4A, $4B, $4C, $4D, $4E, $42, $43, $44, $45, $46, $47
	dc.b	$4F, $50, $51, $52, $53, $54, $55, $56, $57, $58, $59, $5A, $5B, $4F, $50, $51
	dc.b	$52, $53, $54, $55, $56, $57, $58, $59, $5A, $5B, $4F, $50, $51, $52, $53, $54
	dc.b	$66, $5D, $5E, $5F, $60, $61, $62, $63, $64, $65, $66, $5D, $5E, $5F, $60, $61
	dc.b	$62, $63, $64, $65, $66, $5D, $5E, $5F, $60, $61, $62, $63, $64, $65, $66, $5D
	dc.b	$5C, $67, $68, $69, $6A, $6B, $6C, $6D, $6E, $6F, $5C, $67, $68, $69, $6A, $6B
	dc.b	$6C, $6D, $6E, $6F, $5C, $67, $68, $69, $6A, $6B, $6C, $6D, $6E, $6F, $5C, $67
	dc.b	$70, $71, $72, $73, $74, $75, $76, $77, $78, $79, $70, $71, $72, $73, $74, $75
	dc.b	$76, $77, $78, $79, $70, $71, $72, $73, $74, $75, $76, $77, $78, $79, $70, $71
	dc.b	$7A, $7B, $7C, $7D, $7E, $7F, $80, $81, $82, $83, $7A, $7B, $7C, $7D, $7E, $7F
	dc.b	$80, $81, $82, $83, $7A, $7B, $7C, $7D, $7E, $7F, $80, $81, $82, $83, $7A, $7B
	dc.b	$92, $85, $86, $87, $88, $89, $8A, $8B, $8C, $8D, $8E, $8F, $90, $91, $92, $85
	dc.b	$86, $87, $88, $89, $8A, $8B, $8C, $8D, $8E, $8F, $90, $91, $92, $85, $86, $87
	dc.b	$84, $93, $94, $95, $96, $97, $98, $99, $9A, $9B, $9C, $99, $9D, $9B, $84, $93
	dc.b	$94, $95, $96, $97, $98, $99, $9A, $9B, $9C, $99, $9D, $9B, $84, $93, $94, $95
	dc.b	$9E, $9F, $A0, $A1, $A2, $A3, $A4, $A5, $A6, $A7, $A8, $A9, $AA, $AB, $9E, $9F
	dc.b	$A0, $A1, $A2, $A3, $A4, $A5, $A6, $A7, $A8, $A9, $AA, $AB, $9E, $9F, $A0, $A1

byte_1EED0:
	dc.b	6, 7, 8, 9, $A, $B, $C, $D, $13, $14, $15, $16, $17, $18, $19, $1A
	dc.b	$20, $21, $22, $23, $24, $25, $26, $27, $2D, $2E, $2F, $30, $31, $32, $33, $34
	dc.b	$3A, $3B, $3C, $3D, $3E, $3F, $40, $41, $47, $48, $49, $4A, $4B, $4C, $4D, $4E
	dc.b	$54, $55, $56, $57, $58, $59, $5A, $5B, $5E, $5F, $60, $61, $62, $63, $64, $65
	dc.b	$68, $69, $6A, $6B, $6C, $6D, $6E, $6F, $72, $73, $74, $75, $76, $77, $78, $79
	dc.b	$7C, $7D, $7E, $7F, $80, $81, $82, $83, $8A, $8B, $8C, $8D, $8E, $8F, $90, $91
	dc.b	$98, $99, $9A, $9B, $9C, $99, $9D, $9B, $A4, $A5, $A6, $A7, $A8, $A9, $AA, $AB

; ---------------------------------------------------------------------------

Str_DevLockPriv:	
	include "resource/text/Region/Wrong Region Private.asm"	
	even

; =============== S U B	R O U T	I N E =======================================

GetRegion:
	include "src/subroutines/region/get region.asm" 

; =============== S U B	R O U T	I N E =======================================

DeveloperLock:
	include "src/subroutines/devlock/developer check.asm" 

ActDeveloperCheck:
	include "src/actors/developer check.asm"

DevLock_Print:
	include "src/subroutines/devlock/developer check print.asm" 

; =============== S U B	R O U T	I N E =======================================


SoundTest_SetupPlanes:
	move.b	#$FF,(use_plane_a_buffer).l
	move.w	#$E000,d5
	move.w	#$1B,d0
	move.w	#$406C,d6

loc_22646:
	DISABLE_INTS
	jsr	(SetVRAMWrite).l
	addi.w	#$80,d5
	move.w	#$27,d1

loc_22658:
	move.w	d6,VDP_DATA
	eori.b	#1,d6
	dbf	d1,loc_22658
	ENABLE_INTS
	eori.b	#2,d6
	dbf	d0,loc_22646
	bra.w	Options_ClearPlaneA
; End of function SoundTest_SetupPlanes

; ---------------------------------------------------------------------------

SpawnSoundTestActor:
	lea	(ActSoundTest).l,a1
	jmp	(FindActorSlot).l

; =============== S U B	R O U T	I N E =======================================

ChecksumError:
	include "src/subroutines/checksum/checksum error.asm" 

; ---------------------------------------------------------------------------

Str_ChecksumWarning:
	include "resource/text/checksum/Checksum - Line 1.asm" 
	even
Str_ChecksumIncorrect:
	include "resource/text/checksum/Checksum - Line 2.asm" 
	even

; =============== S U B	R O U T	I N E =======================================

ActChecksumError:
	include "src/actors/checksum error.asm" 

; =============== S U B	R O U T	I N E =======================================

ActSoundTest:
	move.w	#2,d0
	bsr.w	Options_DrawStrings
	bsr.w	sub_228EC
	jsr	(ActorBookmark).l

ActSoundTest_Update:
	bsr.w	sub_22956
	move.b	(p1_ctrl_press).l,d0
	or.b	(p2_ctrl_press).l,d0
	btst	#7,d0
	bne.w	.Exit
	btst	#4,d0
	bne.w	.StopSound
	andi.b	#$60,d0
	bne.w	.PlaySound
	move.b	(byte_FF110C).l,d0
	or.b	(byte_FF1112).l,d0
	btst	#0,d0
	bne.w	.Up
	btst	#1,d0
	bne.w	.Down
	btst	#3,d0
	bne.w	.Right
	btst	#2,d0
	bne.w	.Left
	rts
; ---------------------------------------------------------------------------

.Up:
	subq.w	#1,aField26(a0)
	bcc.w	.UpEnd
	move.w	#5,aField26(a0)

.UpEnd:
	rts
; ---------------------------------------------------------------------------

.Down:
	addq.w	#1,aField26(a0)
	cmpi.w	#6,aField26(a0)
	bcs.w	.DownEnd
	move.w	#0,aField26(a0)

.DownEnd:
	rts
; ---------------------------------------------------------------------------

.StopSound:
	jmp	(StopSound).l
; ---------------------------------------------------------------------------

.Exit:
	clr.b	(use_plane_a_buffer).l
	clr.b	(bytecode_disabled).l
	jmp	(ActorDeleteSelf).l
; ---------------------------------------------------------------------------

.Right:
	move.b	#1,d1
	bra.w	.MoveSelection
; ---------------------------------------------------------------------------

.Left:
	move.b	#-1,d1

.MoveSelection:
	move.w	aField26(a0),d0
	lea	(.MaxSoundSels).l,a1
	move.b	(a1,d0.w),d2
	cmpi.b	#3,d0
	bne.s	.ChkUnderflow
	move.b	CONSOLE_VER,d7
	andi.b	#$C0,d7
	bne.s	.ChkUnderflow
	move.b	#$1A,d2

.ChkUnderflow:
	add.b	d1,aField12(a0,d0.w)
	bpl.w	.ChkOverflow
	move.b	d2,aField12(a0,d0.w)
	subq.b	#1,aField12(a0,d0.w)

.ChkOverflow:
	move.b	aField12(a0,d0.w),d3
	cmp.b	d2,d3
	bcs.w	.loc_2282A
	clr.b	aField12(a0,d0.w)

.loc_2282A:
	subq.w	#3,d0
	bcs.w	.End
	bsr.w	SoundTest_SelNonSFX

.End:
	rts
; ---------------------------------------------------------------------------
.MaxSoundSels:
	dc.b $32
	dc.b $32
	dc.b $32
	dc.b $19
	dc.b $17
	dc.b 4
; ---------------------------------------------------------------------------

.PlaySound:
	move.w	aField26(a0),d1
	clr.w	d0
	move.b	aField12(a0,d1.w),d0
	subq.w	#3,d1
	bcc.w	.PlayNonSFX

.PlaySFX:
	addi.b	#$41,d0
	jmp	(JmpTo_PlaySound_2).l
; ---------------------------------------------------------------------------

.PlayNonSFX:
	lsl.w	#2,d0
	lsl.w	#2,d1
	lea	(ST_Select_NoSFX).l,a1
	movea.l	(a1,d1.w),a2
	movea.l	(a2,d0.w),a1
	move.b	(a1),d0
	movea.l	SoundTest_PlayTypes(pc,d1.w),a1
	jmp	(a1)
; End of function ActSoundTest

; ---------------------------------------------------------------------------
SoundTest_PlayTypes:
	dc.l SoundTest_PlayBGM
	dc.l SoundTest_PlayVoice
	dc.l SoundTest_PlayCmd
; ---------------------------------------------------------------------------

SoundTest_PlayBGM:
	jmp	(JmpTo_PlaySound).l
; ---------------------------------------------------------------------------

SoundTest_PlayVoice:
	jmp	(JmpTo_PlaySound_2).l
; ---------------------------------------------------------------------------

SoundTest_PlayCmd:
	jmp	(PlaySound_ChkPCM).l
; ---------------------------------------------------------------------------
	clr.w	d0
	move.b	$17(a0),d0
	mulu.w	#3,d0
	move.b	byte_228D6(pc,d0.w),(byte_FF012C).l
	move.b	byte_228D7(pc,d0.w),(byte_FF012D).l
	move.b	byte_228D8(pc,d0.w),(byte_FF012E).l
	cmpi.b	#$F4,(byte_FF012C).l
	bne.w	locret_228D4
	clr.w	d0
	move.b	$15(a0),d0
	lsl.w	#2,d0
	lea	(ST_BGM_Index).l,a1
	movea.l	(a1,d0.w),a2
	move.b	(a2),(byte_FF012E).l

locret_228D4:
	rts
; ---------------------------------------------------------------------------
byte_228D6:	dc.b $F1

byte_228D7:	dc.b 0

byte_228D8:
	dc.b 0
	dc.b $F2
	dc.b 0
	dc.b 0
	dc.b $F3
	dc.b $80
	dc.b 0
	dc.b $F4
	dc.b $80
	dc.b $1A
	dc.b $F5
	dc.b $80
	dc.b 0
	dc.b $F6
	dc.b 0
	dc.b 0
	dc.b $F7
	dc.b 0
	dc.b 0
	dc.b 0

; =============== S U B	R O U T	I N E =======================================


sub_228EC:
	moveq	#2,d0

loc_228F0:
	move.l	d0,-(sp)
	bsr.w	SoundTest_SelNonSFX
	move.l	(sp)+,d0
	dbf	d0,loc_228F0
	rts
; End of function sub_228EC

; =============== S U B	R O U T	I N E =======================================

SoundTest_SelNonSFX:
	move.w	d0,d1
	lsl.w	#2,d1
	lea	(ST_Select_NoSFX).l,a1
	movea.l	(a1,d1.w),a2
	move.b	$15(a0,d0.w),d1
	lsl.w	#2,d1
	movea.l	(a2,d1.w),a1
	addq.l	#1,a1
	move.w	d0,d5
	lsl.w	#8,d5
	addi.w	#$5A4,d5
	move.w	#$A200,d6
	movem.l	d5-d6/a1,-(sp)
	lea	(asc_2293E).l,a1
	bsr.w	Options_Print
	movem.l	(sp)+,d5-d6/a1
	bra.w	Options_Print
; End of function SoundTest_SelNonSFX

; ---------------------------------------------------------------------------
asc_2293E:	dc.b "                      "
	dc.b $FF
	dc.b 0

; =============== S U B	R O U T	I N E =======================================

sub_22956:
	move.w	#5,d0
	move.w	#$79C,d5
	move.w	#$A200,d6

loc_22962:
	bsr.w	sub_229C2
	bsr.w	sub_22980
	movem.l	d0-d5,-(sp)
	bsr.w	Options_Print
	movem.l	(sp)+,d0-d5
	subi.w	#$100,d5
	dbf	d0,loc_22962
	rts
; End of function sub_22956

; =============== S U B	R O U T	I N E =======================================

sub_22980:
	lea	(stage_text_buffer).l,a1
	move.w	#$2020,(a1)
	move.b	#$FF,2(a1)
	cmp.w	$26(a0),d0
	bne.s	loc_229A6
	btst	#0,(frame_count+1).l
	beq.s	loc_229A6
	rts
; ---------------------------------------------------------------------------

loc_229A6:
	move.b	d1,d2
	lsr.b	#4,d2
	andi.b	#$F,d1
	addq.b	#1,d2
	addq.b	#1,d1
	move.b	d2,0(a1)
	move.b	d1,1(a1)
	move.b	#$FF,2(a1)
	rts
; End of function sub_22980

; =============== S U B	R O U T	I N E =======================================

sub_229C2:
	clr.w	d1
	move.b	$12(a0,d0.w),d1
	move.w	d0,d2
	subq.w	#3,d2
	bcs.s	loc_229E6
	lsl.w	#2,d2
	lea	(ST_Select_NoSFX).l,a1
	movea.l	(a1,d2.w),a2
	lsl.w	#2,d1
	movea.l	(a2,d1.w),a1
	move.b	(a1)+,d1
	rts
; ---------------------------------------------------------------------------

loc_229E6:
	addi.b	#$41,d1
	rts
; End of function sub_229C2

; ---------------------------------------------------------------------------
ST_Select_NoSFX:
	dc.l ST_BGM_Index
	dc.l ST_Voice_Index
	dc.l ST_Command_Index

ST_BGM_Index:
	dc.l ST_BGM_Title
	dc.l ST_BGM_Menu
	dc.l ST_BGM_Password
	dc.l ST_BGM_Stage_Intro_A
	dc.l ST_BGM_Stage_Intro_B
	dc.l ST_BGM_Stage_Intro_C
	dc.l ST_BGM_Stage_Intro_D
	dc.l ST_BGM_Stage_BGM_A
	dc.l ST_BGM_Stage_BGM_B
	dc.l ST_BGM_Stage_BGM_C
	dc.l ST_BGM_Stage_BGM_D
	dc.l ST_BGM_Versus
	dc.l ST_BGM_Exercise
	dc.l ST_BGM_Role_Call
	dc.l ST_BGM_Credits
	dc.l ST_BGM_Danger
	dc.l ST_BGM_Game_Over
	dc.l ST_BGM_Win
	dc.l ST_BGM_Final_Win
	dc.l ST_BGM_Proto_Title
	dc.l ST_BGM_Puyo_Brave
	dc.l ST_BGM_Puyo_Theme
	dc.l ST_BGM_Unused_Stage_BGM
	dc.l ST_BGM_Puyo_Win
	dc.l ST_BGM_Unused_Ending
	dc.l ST_BGM_Silence

ST_BGM_Title:
	dc.b 1,	"Title", $20, $FF
	even

ST_BGM_Menu:
	dc.b 2,	"Menu", $20, $FF
	even

ST_BGM_Password:
	dc.b 3,	"Password", $20, $FF
	even

ST_BGM_Stage_Intro_A:
	dc.b 4, "Stage Intro A", $20, $FF
	even

ST_BGM_Stage_Intro_B:
	dc.b 5, "Stage Intro B", $20, $FF
	even

ST_BGM_Stage_Intro_C:
	dc.b 6,	"Stage Intro C", $20, $FF
	even

ST_BGM_Stage_Intro_D:
	dc.b 7,	"Stage Intro D", $20, $FF
	even

ST_BGM_Stage_BGM_A:
	dc.b 8,	"Stage BGM A", $20, $FF
	even

ST_BGM_Stage_BGM_B:
	dc.b 9,	"Stage BGM B", $20, $FF
	even

ST_BGM_Stage_BGM_C:
	dc.b $A, "Stage BGM C", $20, $FF
	even

ST_BGM_Stage_BGM_D:
	dc.b $B, "Stage BGM D", $20, $FF
	even

ST_BGM_Versus:
	dc.b $C, "Versus", $20, $FF
	even

ST_BGM_Exercise:
	dc.b $D, "Exercise", $20, $FF
	even

ST_BGM_Role_Call
	dc.b $E, "Role Call", $20, $FF
	even

ST_BGM_Credits:
	dc.b $F, "Credits", $20, $FF
	even

ST_BGM_Danger:
	dc.b $10, "Danger", $20, $FF
	even

ST_BGM_Game_Over:
	dc.b $11, "Game Over", $20, $FF
	even

ST_BGM_Win:
	dc.b $12, "Win", $20, $FF
	even

ST_BGM_Final_Win:
	dc.b $13, "Final Win", $20, $FF
	even

ST_BGM_Proto_Title:
	dc.b $14, "Proto Title", $20, $FF
	even

ST_BGM_Puyo_Brave:
	dc.b $15, "Brave of Puyo Puyo", $20, $FF
	even

ST_BGM_Puyo_Theme:
	dc.b $16, "Theme of Puyo Puyo", $20, $FF
	even

ST_BGM_Unused_Stage_BGM:
	dc.b $17, "Unused Stage BGM", $20, $FF
	even

ST_BGM_Puyo_Win:
	dc.b $18, "Puyo Win", $20, $FF
	even

ST_BGM_Unused_Ending:
	dc.b $19, "Unused Ending", $20, $FF
	even

ST_BGM_Silence:
	dc.b $1A, "Silence", $20, $FF
	even

ST_Voice_Index:
	dc.l ST_Voice_81
	dc.l ST_Voice_82
	dc.l ST_Voice_83
	dc.l ST_Voice_84
	dc.l ST_Voice_85
	dc.l ST_Voice_86
	dc.l ST_Voice_87
	dc.l ST_Voice_88
	dc.l ST_Voice_89
	dc.l ST_Voice_8A
	dc.l ST_Voice_8B
	dc.l ST_Voice_8C
	dc.l ST_Voice_8D
	dc.l ST_Voice_8E
	dc.l ST_Voice_8F
	dc.l ST_Voice_90
	dc.l ST_Voice_91
	dc.l ST_Voice_92
	dc.l ST_Voice_93
	dc.l ST_Voice_94
	dc.l ST_Voice_95
	dc.l ST_Voice_96
	dc.l ST_Voice_97

ST_Voice_81:
	dc.b $81, "P1 Combo 1", $20, $FF
	even

ST_Voice_82:
	dc.b $82, "P1 Combo 2", $20, $FF
	even

ST_Voice_83:
	dc.b $83, "P1 Combo 3", $20, $FF
	even

ST_Voice_84:
	dc.b $84, "P1 Combo 4", $20, $FF
	even

ST_Voice_85:
	dc.b $85, "P2 Combo 1", $20, $FF
	even

ST_Voice_86:
	dc.b $86, "P2 Combo 2", $20, $FF
	even

ST_Voice_87:
	dc.b $87, "Eggmobile", $20, $FF
	even

ST_Voice_88:
	dc.b $88, "Garbage 1", $20, $FF
	even

ST_Voice_89:
	dc.b $89, "Garbage 2", $20, $FF
	even

ST_Voice_8A:
	dc.b $8A, "Garbage 3", $20, $FF
	even

ST_Voice_8B:
	dc.b $8B, $20, $20, $FF
	even

ST_Voice_8C:
	dc.b $8C, $20, $20, $FF
	even

ST_Voice_8D:
	dc.b $8D, "P2 Combo 3", $20, $FF
	even

ST_Voice_8E:
	dc.b $8E, "P2 Combo 4", $20, $FF
	even

ST_Voice_8F:
	dc.b $8F, $20, $20, $FF
	even

ST_Voice_90:
	dc.b $90, "Robotnik Lose", $20, $FF
	even

ST_Voice_91:
	dc.b $91, "Bean Cheer", $20, $FF
	even

ST_Voice_92:
	dc.b $92, "Thunder 1", $20, $FF
	even

ST_Voice_93:
	dc.b $93, "Thunder 2", $20, $FF
	even

ST_Voice_94:
	dc.b $94, "Thunder 3", $20, $FF
	even

ST_Voice_95:
	dc.b $95, "Thunder 4", $20, $FF
	even

ST_Voice_96:
	dc.b $96, "Eggmobile Leave", $20, $FF
	even

ST_Voice_97:
	dc.b $97, "Vanish", $20, $FF
	even

ST_Voice_98:
	dc.b $98, $20, $20, $FF
	even

ST_Voice_99:
	dc.b $99, $20, $20, $FF
	even

ST_Voice_9A:
	dc.b $9A, $20, $20, $FF
	even

ST_Voice_9B:
	dc.b $9B, $20, $20, $FF
	even

ST_Command_Index:
	dc.l ST_Command_MusClear
	dc.l ST_Command_FadeOut
	dc.l ST_Command_Pause
	dc.l ST_Command_SEClear

ST_Command_MusClear:
	dc.b $FE, "music clear", $FF
	even

ST_Command_FadeOut:
	dc.b $FD, "fade out", $FF
	even

ST_Command_Pause:
	dc.b $FF, "pause on off", $FF
	even

ST_Command_SEClear:
	dc.b $6F, "se clear", $FF
	even

ST_Command_Rebirth:
	dc.b $F5, "rebirth", $FF
	even

	dc.b $F6
aPauseOn:	dc.b "pause on"
	dc.b $FF
	even

	dc.b $F7
aPauseOff:	dc.b "pause off"
	dc.b $FF
	even

; =============== S U B	R O U T	I N E =======================================

Options_SetupPlanes:
	move.b	#$FF,(use_plane_a_buffer).l
	move.w	#$E000,d5
	move.w	#$1B,d0
	move.w	#$6C,d6

.Row:
	DISABLE_INTS
	jsr	(SetVRAMWrite).l
	addi.w	#$80,d5
	move.w	#$27,d1

.Tile:
	move.w	d6,VDP_DATA
	eori.b	#1,d6
	dbf	d1,.Tile
	ENABLE_INTS
	eori.b	#2,d6
	dbf	d0,.Row
	bra.w	Options_ClearPlaneA
; End of function Options_SetupPlanes

; =============== S U B	R O U T	I N E =======================================

SpawnOptionsActor:
	lea	(ActOptions).l,a1
	jsr	(FindActorSlot).l
	bcc.w	.Spawned
	rts
; ---------------------------------------------------------------------------

.Spawned:
	rts
; End of function SpawnOptionsActor

; =============== S U B	R O U T	I N E =======================================

Options_ClearPlaneA:
	lea	(plane_a_buffer).l,a1
	move.w	#$6FF,d0

.Clear:
	move.w	#$8500,(a1)+
	dbf	d0,.Clear
	rts
; End of function Options_ClearPlaneA

; =============== S U B	R O U T	I N E =======================================

Options_DrawStrings:
	move.l	d0,-(sp)
	bsr.s	Options_ClearPlaneA
	move.l	(sp)+,d0
	lsl.w	#2,d0
	movea.l	OptionsModeStrings(pc,d0.w),a2
	move.w	(a2)+,d0
	subq.w	#1,d0

.Loop:
	movea.l	(a2)+,a1
	movem.l	d0/a2,-(sp)
	move.w	(a1)+,d5
	move.w	(a1)+,d6
	bsr.w	Options_Print
	movem.l	(sp)+,d0/a2
	dbf	d0,.Loop
	rts
; End of function Options_DrawStrings

; ---------------------------------------------------------------------------
OptionsModeStrings:
	dc.l	OptionsStrings
	dc.l InputTestStrings
	dc.l SoundTestStrings

InputTestStrings:	dc.w $C
	dc.l OptStr_InputTest
	dc.l OptStr_PressStartAndA
	dc.l OptStr_Pads
	dc.l OptStr_ButtonA
	dc.l OptStr_ButtonB
	dc.l OptStr_ButtonC
	dc.l OptStr_ButtonUp
	dc.l OptStr_ButtonDown
	dc.l OptStr_ButtonRight
	dc.l OptStr_ButtonLeft
	dc.l OptStr_ToExit
	dc.l OptStr_Start

OptStr_InputTest:
	dc.w $11E
	dc.w $A200
	dc.b "input test"
	dc.b $FF
	even

OptStr_PressStartAndA:
	dc.w $B88
	dc.w $A200
	dc.b "press start button and a button"
	dc.b $FF
	even

OptStr_ToExit:
	dc.w $CBA
	dc.w $A200
	dc.b "to exit"
	dc.b $FF
	even

OptStr_Pads:
	dc.w $222
	dc.w $E200
	dc.b "pad1  pad2"
	dc.b $FF
	even

OptStr_Start:
	dc.w $316
	dc.w $8200
	dc.b "start:"
	dc.b $FF
	even

OptStr_ButtonA:
	dc.w $410
	dc.w $8200
	dc.b "button a:"
	dc.b $FF
	even

OptStr_ButtonB:
	dc.w $510
	dc.w $8200
	dc.b "button b:"
	dc.b $FF
	even

OptStr_ButtonC:
	dc.w $610
	dc.w $8200
	dc.b "button c:"
	dc.b $FF
	even

OptStr_ButtonUp:
	dc.w $790
	dc.w $8200
	dc.b "      up:"
	dc.b $FF
	even

OptStr_ButtonDown:
	dc.w $890
	dc.w $8200
	dc.b "    down:"
	dc.b $FF
	even

OptStr_ButtonRight:
	dc.w	$990
	dc.w $8200
	dc.b "   right:"
	dc.b $FF
	even

OptStr_ButtonLeft:
	dc.w $A90
	dc.w $8200
	dc.b "    left:"
	dc.b $FF
	even

OptionsStrings:	dc.w $A
	dc.l OptStr_Options
	dc.l OptStr_Players
	dc.l OptStr_PressStartExit
	dc.l OptStr_AssignA
	dc.l OptStr_AssignB
	dc.l OptStr_AssignC
	dc.l OptStr_COMLevel
	dc.l OptStr_VSMode
	dc.l OptStr_Sampling
	dc.l OptStr_KeyAssign

OptStr_Options:
	dc.w $120
	dc.w $A200
	dc.b "options"
	dc.b $FF
	even

OptStr_Players:
	dc.w $312
	dc.w $E200
	dc.b "player 1       player 2"
	dc.b $FF
	even

OptStr_PressStartExit:
	dc.w $C8E
	dc.w $A200
	dc.b "press start button to exit"
	dc.b $FF
	even

OptStr_AssignA:
	dc.w $40C
	dc.w $E200
	dc.b "a:              a:"
	dc.b $FF
	even

OptStr_AssignB:
	dc.w $50C
	dc.w $E200
	dc.b "b:              b:"
	dc.b $FF
	even

OptStr_AssignC:
	dc.w $60C
	dc.w $E200
	dc.b "c:              c:"
	dc.b $FF
	even

OptStr_COMLevel:
	dc.w $78C
	dc.w $E200
	dc.b "vs.com level   :"
	dc.b $FF
	even

OptStr_VSMode:
	dc.w $88C
	dc.w $E200
	dc.b "1p vs.2p mode  :"
	dc.b $FF
	even

OptStr_Sampling:
	dc.w $98C
	dc.w $E200
	dc.b "sampling       :"
	dc.b $FF
	even

OptStr_KeyAssign:
	dc.w $21A
	dc.w $E200
	dc.b "key assignment"
	dc.b $FF
	even

SoundTestStrings:	dc.w 8
	dc.l OptStr_SoundTest
	dc.l OptStr_PressStartExit2
	dc.l OptStr_Sound1
	dc.l OptStr_Sound2
	dc.l OptStr_Sound3
	dc.l OptStr_BGM
	dc.l OptStr_Voice
	dc.l OptStr_SndCmd

OptStr_SoundTest:
	dc.w $11C
	dc.w $8200
	dc.b "sound test"
	dc.b $FF
	even

OptStr_PressStartExit2:
	dc.w $C8E
	dc.w $E200
	dc.b "press start button to exit"
	dc.b $FF
	even

OptStr_Sound1:
	dc.w $292
	dc.w $E200
	dc.b "se1:"
	dc.b $FF
	even

OptStr_Sound2:
	dc.w $392
	dc.w $E200
	dc.b "se2:"
	dc.b $FF
	even

OptStr_Sound3:
	dc.w $492
	dc.w $E200
	dc.b "se3:"
	dc.b $FF
	even

OptStr_BGM:
	dc.w $592
	dc.w $E200
	dc.b "bgm:"
	dc.b $FF
	even

OptStr_Voice:
	dc.w $68E
	dc.w $E200
	dc.b "voice:"
	dc.b $FF
	even

OptStr_SndCmd:
	dc.w $78A
	dc.w $E200
	dc.b "command:"
	dc.b $FF
	even

; =============== S U B	R O U T	I N E =======================================

Options_PrintSelect:
	move.w	#$8200,d6
	btst	#0,$26(a0)
	beq.w	Options_Print
	cmp.b	$2C(a0),d0
	bne.s	loc_22F46
	move.w	#$C200,d6
	bra.w	Options_Print
; ---------------------------------------------------------------------------

loc_22F46:
	cmp.b	$2D(a0),d0
	bne.w	Options_Print
	move.w	#$A200,d6
; End of function Options_PrintSelect


; =============== S U B	R O U T	I N E =======================================

Options_Print:
	lea	((plane_a_buffer+2)).l,a2
	lea	(Options_CharConv).l,a3
	clr.w	d0

.Loop:
	move.b	(a1)+,d0
	bmi.w	.Done
	move.b	(a3,d0.w),d6
	move.w	d6,-2(a2,d5.w)
	addq.w	#2,d5
	bra.s	.Loop
; ---------------------------------------------------------------------------

.Done:
	rts
; End of function Options_Print

; =============== S U B	R O U T	I N E =======================================

Options_PrintRaw:
	lea	((plane_a_buffer+2)).l,a2

.Loop:
	move.b	(a1)+,d0
	bmi.w	.Done
	lsl.b	#1,d0
	move.b	d0,d6
	move.w	d6,-2(a2,d5.w)
	addq.b	#1,d6
	move.w	d6,$7E(a2,d5.w)
	addq.w	#2,d5
	bra.s	.Loop
; ---------------------------------------------------------------------------

.Done:
	rts
; End of function Options_PrintRaw

; ---------------------------------------------------------------------------
Options_CharConv:
	dc.b $11
	dc.b $12
	dc.b $13
	dc.b $14
	dc.b $15
	dc.b $16
	dc.b $17
	dc.b $18
	dc.b $19
	dc.b $1A
	dc.b $1B
	dc.b $1C
	dc.b $1D
	dc.b $1E
	dc.b $1F
	dc.b $20
	dc.b $21
	dc.b $11
	dc.b $11
	dc.b $11
	dc.b $11
	dc.b $11
	dc.b $11
	dc.b $11
	dc.b $11
	dc.b $11
	dc.b $11
	dc.b $11
	dc.b $11
	dc.b $11
	dc.b $11
	dc.b $11
	dc.b $11
	dc.b 7
	dc.b $11
	dc.b $36
	dc.b $37
	dc.b $11
	dc.b $11
	dc.b 9
	dc.b $11
	dc.b $11
	dc.b $11
	dc.b $11
	dc.b 1
	dc.b 8
	dc.b 2
	dc.b $11
	dc.b $12
	dc.b $13
	dc.b $14
	dc.b $15
	dc.b $16
	dc.b $17
	dc.b $18
	dc.b $19
	dc.b $1A
	dc.b $1B
	dc.b 4
	dc.b 5
	dc.b $11
	dc.b $11
	dc.b $11
	dc.b 6
	dc.b $11
	dc.b $1C
	dc.b $1D
	dc.b $1E
	dc.b $1F
	dc.b $20
	dc.b $21
	dc.b $22
	dc.b $23
	dc.b $24
	dc.b $25
	dc.b $26
	dc.b $27
	dc.b $28
	dc.b $29
	dc.b $2A
	dc.b $2B
	dc.b $2C
	dc.b $2D
	dc.b $2E
	dc.b $2F
	dc.b $30
	dc.b $31
	dc.b $32
	dc.b $33
	dc.b $34
	dc.b $35
	dc.b $11
	dc.b $11
	dc.b $11
	dc.b $11
	dc.b $11
	dc.b $11
	dc.b $1C
	dc.b $1D
	dc.b $1E
	dc.b $1F
	dc.b $20
	dc.b $21
	dc.b $22
	dc.b $23
	dc.b $24
	dc.b $25
	dc.b $26
	dc.b $27
	dc.b $28
	dc.b $29
	dc.b $2A
	dc.b $2B
	dc.b $2C
	dc.b $2D
	dc.b $2E
	dc.b $2F
	dc.b $30
	dc.b $31
	dc.b $32
	dc.b $33
	dc.b $34
	dc.b $35
	dc.b $11
	dc.b $11
	dc.b $11
	dc.b $11
	dc.b $11
; ---------------------------------------------------------------------------
; START	OF FUNCTION CHUNK FOR OptionsCtrl

ActOptions:
	move.w	#0,d0
	bsr.w	Options_DrawStrings
	jsr	(ActorBookmark).l

ActOptions_Update:
	addq.b	#1,aField26(a0)
	bsr.w	PrintMainOptions
	move.b	(p1_ctrl_press).l,d0
	or.b	(p2_ctrl_press).l,d0
	btst	#7,d0
	bne.w	.Exit
	move.w	#0,d0
	move.b	(p1_ctrl_press).l,d1
	bsr.w	OptionsCtrl
	move.w	#1,d0
	move.b	(p2_ctrl_press).l,d1
	bsr.w	OptionsCtrl
	rts
; ---------------------------------------------------------------------------

.Exit:
	bsr.w	sub_23536
	clr.b	(use_plane_a_buffer).l
	move.b	#0,(bytecode_flag).l
	clr.b	(bytecode_disabled).l
	jmp	(ActorDeleteSelf).l
; END OF FUNCTION CHUNK	FOR OptionsCtrl

; =============== S U B	R O U T	I N E =======================================

OptionsCtrl:
	move.b	#2,d2
	cmp.b	(swap_controls).l,d0
	bne.w	.CheckButtons
	move.b	#6,d2
	tst.w	(sound_test_enabled).l
	beq.w	.CheckButtons
	move.b	#7,d2

.CheckButtons:
	btst	#0,d1
	bne.w	.Up
	btst	#1,d1
	bne.w	.Down
	btst	#2,d1
	bne.w	.Left
	btst	#3,d1
	bne.w	.Right
	andi.b	#$70,d1
	bne.w	.Select
	rts
; ---------------------------------------------------------------------------

.Up:
	subq.b	#1,aField2C(a0,d0.w)
	bcc.w	.UpSound
	move.b	d2,aField2C(a0,d0.w)

.UpSound:
	move.b	#SFX_MENU_MOVE,d0
	jmp	(PlaySound_ChkPCM).l
; ---------------------------------------------------------------------------

.Down:
	addq.b	#1,aField2C(a0,d0.w)
	cmp.b	aField2C(a0,d0.w),d2
	bcc.w	.DownSound
	clr.b	aField2C(a0,d0.w)

.DownSound:
	move.b	#SFX_MENU_MOVE,d0
	jmp	(PlaySound_ChkPCM).l
; ---------------------------------------------------------------------------

.Left:
	move.b	#-1,d1
	bra.w	.ChangeOption
; ---------------------------------------------------------------------------

.Right:
	move.b	#1,d1

.ChangeOption:
	clr.w	d2
	move.b	aField2C(a0,d0.w),d2
	lsl.w	#2,d2
	movea.l	.Options(pc,d2.w),a1
	jmp	(a1)
; ---------------------------------------------------------------------------
.Options:
	dc.l .KeyAssign
	dc.l .KeyAssign
	dc.l .KeyAssign
	dc.l .COMLevel
	dc.l .VSMode
	dc.l .Sampling
	dc.l .Nothing
	dc.l .Nothing
; ---------------------------------------------------------------------------

.KeyAssign:
	lea	(player_1_a).l,a1
	tst.w	d0
	beq.w	.loc_23140
	lea	(player_2_a).l,a1

.loc_23140:
	clr.w	d2
	move.b	aField2C(a0,d0.w),d2
	move.b	(a1,d2.w),d3
	add.b	d1,d3
	bpl.w	.loc_23154
	move.b	#2,d3

.loc_23154:
	cmpi.b	#3,d3
	bcs.w	.loc_2315E
	clr.b	d3

.loc_2315E:
	move.b	d3,(a1,d2.w)
	move.b	#0,d0
	jmp	(PlaySound_ChkPCM).l
; ---------------------------------------------------------------------------

.COMLevel:
	addq.b	#1,(com_level).l
	tst.b	d1
	bmi.w	.loc_2317E
	subq.b	#2,(com_level).l

.loc_2317E:
	andi.b	#3,(com_level).l
	move.b	#0,d0
	jmp	(PlaySound_ChkPCM).l
; ---------------------------------------------------------------------------

.VSMode:
	move.b	(game_matches).l,d2
	subq.b	#1,d2
	add.b	d1,d2
	andi.b	#7,d2
	addq.b	#1,d2
	move.b	d2,(game_matches).l
	move.b	#0,d0
	jmp	(PlaySound_ChkPCM).l
; ---------------------------------------------------------------------------

.Sampling:
	eori.b	#$FF,(disable_samples).l
	move.b	#0,d0
	jmp	(PlaySound_ChkPCM).l
; ---------------------------------------------------------------------------

.Nothing:
	rts
; ---------------------------------------------------------------------------

.Select:
	cmpi.b	#6,aField2C(a0,d0.w)
	beq.s	.InputTest
	cmpi.b	#7,aField2C(a0,d0.w)
	beq.s	.SoundTest
	rts
; ---------------------------------------------------------------------------

.InputTest:
	move.b	#0,d0
	jsr	(PlaySound_ChkPCM).l
	movem.l	(sp)+,d0
	bra.w	ActInputTest
; ---------------------------------------------------------------------------

.SoundTest:
	move.b	#0,d0
	jsr	(PlaySound_ChkPCM).l
	movem.l	(sp)+,d0
	clr.b	(use_plane_a_buffer).l
	move.b	#1,(bytecode_flag).l
	clr.b	(bytecode_disabled).l
	jmp	(ActorDeleteSelf).l
; End of function OptionsCtrl

; =============== S U B	R O U T	I N E =======================================

PrintMainOptions:
	bsr.w	PrintP1CtrlOption
	bsr.w	PrintP2CtrlOption
	bsr.w	sub_232D4
	bsr.w	PrintVSModeOption
	bsr.w	PrintSamplingOption
	bsr.w	PrintInputTest
	bsr.w	sub_233F8
	rts
; End of function PrintMainOptions

; =============== S U B	R O U T	I N E =======================================

PrintP1CtrlOption:
	lea	(player_1_a).l,a2
	move.w	#$2C,d4
	move.w	#$410,d5
	move.w	#$C200,d6
	bra.w	loc_2325A
; End of function PrintP1CtrlOption

; =============== S U B	R O U T	I N E =======================================

PrintP2CtrlOption:
	lea	(player_2_a).l,a2
	move.w	#$2D,d4
	move.w	#$430,d5
	move.w	#$A200,d6

loc_2325A:
	btst	#0,aField26(a0)
	bne.s	loc_23268
	move.w	#$8200,d6

loc_23268:
	swap	d6
	move.w	#$8200,d6
	clr.w	d3

loc_23270:
	clr.w	d0
	move.b	(a2)+,d0
	lsl.w	#2,d0
	movea.l	PlayerCtrlOptStrings(pc,d0.w),a1
	movem.l	d3-d6/a2,-(sp)
	cmp.b	(a0,d4.w),d3
	bne.s	loc_23288
	swap	d6

loc_23288:
	bsr.w	Options_Print
	movem.l	(sp)+,d3-d6/a2
	addi.w	#$100,d5
	addq.w	#1,d3
	cmpi.w	#3,d3
	bcs.s	loc_23270
	rts
; End of function PrintP2CtrlOption

; ---------------------------------------------------------------------------
PlayerCtrlOptStrings:
	dc.l OptStr_DontUse
	dc.l OptStr_TurnLeft
	dc.l OptStr_TurnRight
OptStr_DontUse:
	dc.b "don't use   ", $FF
	even

OptStr_TurnLeft:
	dc.b "turn left  $", $FF
	even

OptStr_TurnRight:
	dc.b "turn right #", $FF
	even

; =============== S U B	R O U T	I N E =======================================

sub_232D4:
	move.w	#$7AE,d5
	clr.w	d0
	move.b	(com_level).l,d0
	lsl.w	#2,d0
	movea.l	COMLevelStrings(pc,d0.w),a1
	move.b	#3,d0
	bra.w	Options_PrintSelect
; End of function sub_232D4

; ---------------------------------------------------------------------------
COMLevelStrings:
	dc.l OptStr_Hardest
	dc.l OptStr_Hard
	dc.l OptStr_Normal
	dc.l OptStr_Easy

OptStr_Hardest:	
	dc.b "hardest", $FF
	even
OptStr_Hard:
	dc.b "hard   ", $FF
	even

OptStr_Normal:
	dc.b "normal ", $FF
	even

OptStr_Easy:
	dc.b "easy   ", $FF
	even

; =============== S U B	R O U T	I N E =======================================

PrintVSModeOption:
	move.w	#$8AE,d5
	clr.w	d0
	move.b	(game_matches).l,d0
	beq.w	.PrintMatchCount
	subq.b	#1,d0

.PrintMatchCount:
	lsl.w	#2,d0
	movea.l	VSModeMatches(pc,d0.w),a1
	move.l	d0,-(sp)
	move.w	#$C200,d6
	bsr.w	Options_Print
	move.l	(sp)+,d0
	lea	(OptStr_GameMatch).l,a1
	move.w	#$8B0,d5
	cmpi.w	#$14,d0
	blt.s	.PrintGameMatch
	move.w	#$8B2,d5

.PrintGameMatch:
	move.b	#4,d0
	bra.w	Options_PrintSelect
; End of function PrintVSModeOption

; ---------------------------------------------------------------------------
OptStr_GameMatch:
	dc.b " game match ", $FF
	even

VSModeMatches:
	dc.l VSMode_1Match
	dc.l VSMode_3Match
	dc.l VSMode_5Match
	dc.l VSMode_7Match
	dc.l VSMode_9Match
	dc.l VSMode_11Match
	dc.l VSMode_13Match
	dc.l VSMode_15Match

VSMode_1Match:
	dc.b 2,	$20, $FF
	even

VSMode_3Match:
	dc.b 4,	$20, $FF
	even

VSMode_5Match:
	dc.b 6,	$20, $FF
	even

VSMode_7Match:
	dc.b 8,	$20, $FF
	even

VSMode_9Match:
	dc.b $A, $20, $FF
	even

VSMode_11Match:
	dc.b 2,	2, $FF
	even

VSMode_13Match:
	dc.b 2,	4, $FF
	even

VSMode_15Match:
	dc.b 2,	6, $FF
	even

; =============== S U B	R O U T	I N E =======================================

PrintSamplingOption:
	move.b	#5,d0
	move.w	#$9AE,d5
	lea	(OptStr_On).l,a1
	tst.b	(disable_samples).l
	beq.s	loc_233CE
	lea	(OptStr_Off).l,a1

loc_233CE:
	bra.w	Options_PrintSelect
; End of function PrintSamplingOption

; ---------------------------------------------------------------------------
OptStr_On:
	dc.b "on "
	dc.b $FF
	even
OptStr_Off:
	dc.b "off"
	dc.b $FF
	even

; =============== S U B	R O U T	I N E =======================================

PrintInputTest:
	move.b	#6,d0
	move.w	#$A9E,d5
	lea	(OptStr_InputTest2).l,a1
	bra.w	Options_PrintSelect
; End of function PrintInputTest

; ---------------------------------------------------------------------------
OptStr_InputTest2:
	dc.b "input test"
	dc.b $FF
	even

; =============== S U B	R O U T	I N E =======================================

sub_233F8:
	tst.w	(sound_test_enabled).l
	beq.w	locret_23414
	move.b	#7,d0
	move.w	#$B9E,d5
	lea	(OptStr_SoundTest2).l,a1
	bsr.w	Options_PrintSelect

locret_23414:
	rts
; End of function sub_233F8

; ---------------------------------------------------------------------------
OptStr_SoundTest2:
	dc.b "sound test"
	dc.b $FF
	even
; ---------------------------------------------------------------------------
; START	OF FUNCTION CHUNK FOR OptionsCtrl

ActInputTest:
	move.w	#1,d0
	bsr.w	Options_DrawStrings
	jsr	(ActorBookmark).l

ActInputTest_Update:
	bsr.w	sub_23468
	move.b	(p1_ctrl_hold).l,d0
	andi.b	#$C0,d0
	eori.b	#$C0,d0
	beq.s	loc_2345A
	move.b	(p2_ctrl_hold).l,d0
	andi.b	#$C0,d0
	eori.b	#$C0,d0
	beq.s	loc_2345A
	rts
; ---------------------------------------------------------------------------

loc_2345A:
	move.b	#0,d0
	jsr	(PlaySound_ChkPCM).l
	bra.w	ActOptions
; END OF FUNCTION CHUNK	FOR OptionsCtrl

; =============== S U B	R O U T	I N E =======================================

sub_23468:
	move.b	(p1_ctrl_hold).l,d0
	lsl.w	#8,d0
	move.b	(p2_ctrl_hold).l,d0
	lea	(word_234B6).l,a2
	move.w	#$F,d1

loc_23480:
	move.w	(a2)+,d5
	lea	(byte_234AE).l,a1
	move.w	#$E500,d6
	ror.l	#1,d0
	bcs.s	loc_2349C
	lea	(byte_234B2).l,a1
	move.w	#$C500,d6

loc_2349C:
	movem.l	d0-d1/a2,-(sp)
	bsr.w	Options_PrintRaw
	movem.l	(sp)+,d0-d1/a2
	dbf	d1,loc_23480
	rts
; End of function sub_23468

; ---------------------------------------------------------------------------
byte_234AE:	dc.b $19, $18, $FF, 0

byte_234B2:	dc.b $2C, $2D, $FF, 0

word_234B6:	dc.w $7B0, $8B0, $AB0, $9B0, $530, $630, $430, $330
	dc.w $7A4, $8A4, $AA4, $9A4, $524, $624, $424, $324

; =============== S U B	R O U T	I N E =======================================

CheckChecksum:
	include "src/subroutines/checksum/check checksum.asm" 

; ---------------------------------------------------------------------------

LockoutBypassCode:
	include "resource/misc/Lockout Bypass Code.asm"

; =============== S U B	R O U T	I N E =======================================

SetDemoOpponent:
	include	"src/subroutines/Demo/SetDemoOpponent.asm"
	even

; =============== S U B	R O U T	I N E =======================================

sub_23536:
	movem.l	d0-d3/a1-a2,-(sp)
	lea	(sound_test_enabled).l,a1
	bsr.w	sub_23566
	move.w	d0,(stack_base).l
	lea	(stack_base).l,a1
	lea	(byte_FFFE00).l,a2
	move.w	#$2B,d0

loc_2355A:
	move.l	(a1)+,(a2)+
	dbf	d0,loc_2355A
	movem.l	(sp)+,d0-d3/a1-a2
	rts
; End of function sub_23536

; =============== S U B	R O U T	I N E =======================================

sub_23566:
	move.w	#$56,d2
	clr.w	d0

loc_2356C:
	move.w	(a1)+,d1
	eor.w	d1,d0
	lsr.w	#1,d0
	bcc.s	loc_2357A
	eori.w	#$8810,d0

loc_2357A:
	dbf	d2,loc_2356C
	ror.w	#8,d0
	not.w	d0
	rts
; End of function sub_23566

; ---------------------------------------------------------------------------
ComboVoices:	dc.b 0
	dc.b VOI_P1_COMBO_1
	dc.b VOI_P1_COMBO_2
	dc.b VOI_P1_COMBO_3
	dc.b VOI_P1_COMBO_4
	dc.b VOI_P1_COMBO_4
	dc.b VOI_P1_COMBO_4
	dc.b VOI_P1_COMBO_4
	dc.b 0
	dc.b VOI_P2_COMBO_1
	dc.b VOI_P2_COMBO_2
	dc.b VOI_P2_COMBO_3
	dc.b VOI_P2_COMBO_4
	dc.b VOI_P2_COMBO_4
	dc.b VOI_P2_COMBO_4
	dc.b VOI_P2_COMBO_4

; =============== S U B	R O U T	I N E =======================================

SpawnGarbageGlow:
	btst	#1,(level_mode).l
	bne.w	.End
	movem.l	d0-a6,-(sp)
	moveq	#0,d0
	move.b	aFrame(a0),d0
	beq.s	.SpawnGlow
	cmpi.b	#6,d0
	bmi.s	.GetVoice
	moveq	#4,d0

.GetVoice:
	lea	(ComboVoices).l,a1
	tst.b	aPlayerID(a0)
	beq.s	.PlayVoice
	lea	8(a1),a1

.PlayVoice:
	move.b	(a1,d0.w),d0
	jsr	(PlaySound_ChkPCM).l

.SpawnGlow:
	movem.l	(sp)+,d0-a6
	lea	(ActGarbageGlow).l,a1
	jsr	(FindActorSlot).l
	bcs.w	.End
	move.b	aField0(a0),aField0(a1)
	move.l	a0,aField2E(a1)
	move.b	#2,aMappings(a1)
	move.l	#byte_2374C,aAnim(a1)
	tst.b	aPlayerID(a0)
	beq.w	.SetGlowPosition
	move.l	#byte_2377A,aAnim(a1)

.SetGlowPosition:
	move.w	(garbage_glow_x).l,$A(a1)
	move.w	(garbage_glow_y).l,$E(a1)
	move.b	aFrame(a0),aField2B(a1)
	move.b	aPlayerID(a0),aPlayerID(a1)

.End:
	rts
; End of function SpawnGarbageGlow

; =============== S U B	R O U T	I N E =======================================

ActGarbageGlow:
	tst.b	aField2B(a0)
	beq.w	loc_2371C
	jsr	(ActorAnimate).l
	move.b	#$83,6(a0)
	jsr	(ActorBookmark).l
	move.w	#8,d0
	jsr	(ActorBookmark_SetDelay).l
	jsr	(ActorAnimate).l
	jsr	(ActorBookmark).l
	move.w	#$1F,$26(a0)
	move.l	#$1800000,d0
	jsr	(GetPuyoFieldID).l
	beq.s	loc_23674
	move.l	#$C00000,d0

loc_23674:
	sub.l	$A(a0),d0
	asr.l	#5,d0
	move.l	d0,$12(a0)
	move.l	#$880000,d0
	sub.l	$E(a0),d0
	asr.l	#5,d0
	move.l	d0,$16(a0)
	move.w	$A(a0),$1E(a0)
	jsr	(ActorBookmark).l
	jsr	(ActorAnimate).l
	move.w	$1E(a0),$A(a0)
	jsr	(sub_3810).l
	move.w	$A(a0),$1E(a0)
	move.b	#$80,d0
	jsr	(GetPuyoFieldID).l
	beq.s	loc_236C4
	eori.b	#$80,d0

loc_236C4:
	move.b	$27(a0),d1
	lsl.b	#2,d1
	or.b	d1,d0
	move.w	#$6000,d1
	jsr	(Sin).l
	swap	d2
	add.w	d2,$A(a0)
	subq.w	#1,$26(a0)
	bcs.s	loc_236E6
	rts
; ---------------------------------------------------------------------------

loc_236E6:
	move.l	#byte_2375E,aAnim(a0)
	tst.b	aPlayerID(a0)
	beq.s	loc_236FE
	move.l	#byte_2378C,aAnim(a0)

loc_236FE:
	clr.w	d1
	move.b	aField2B(a0),d1
	subq.b	#1,d1
	cmpi.b	#4,d1
	bcs.s	loc_23712
	move.b	#3,d1

loc_23712:
	move.b	GarbageSounds(pc,d1.w),d0
	jsr	(PlaySound_ChkPCM).l

loc_2371C:
	move.l	a0,-(sp)
	movea.l	aField2E(a0),a1
	movea.l	a1,a0
	jsr	(loc_984A).l
	move.l	(sp)+,a0
	jsr	(ActorBookmark).l
	jsr	(ActorAnimate).l
	bcs.s	loc_23742
	rts
; ---------------------------------------------------------------------------

loc_23742:
	jmp	(ActorDeleteSelf).l
; End of function ActGarbageGlow

; ---------------------------------------------------------------------------
GarbageSounds:
	dc.b SFX_GARBAGE_1
	dc.b SFX_GARBAGE_2
	dc.b SFX_GARBAGE_3
	dc.b SFX_GARBAGE_4
; TODO: Document Animation Code

byte_2374C:
	dc.b 0
	dc.b 7
	dc.b 0
	dc.b 8
	dc.b 0
	dc.b 9
	dc.b 1
	dc.b $A
	dc.b 0
	dc.b 9
	dc.b 0
	dc.b 8
	dc.b $FF
	dc.b 0
	dc.l byte_2374C

byte_2375E:
	dc.b 2
	dc.b 7
	dc.b 1
	dc.b 8
	dc.b 1
	dc.b 9
	dc.b 6
	dc.b $A
	dc.b 0
	dc.b 9
	dc.b 0
	dc.b 8
	dc.b 0
	dc.b 7
	dc.b 3
	dc.b $B
	dc.b 3
	dc.b $C
	dc.b 3
	dc.b $D
	dc.b 3
	dc.b $E
	dc.b 3
	dc.b $F
	dc.b 3
	dc.b $10
	dc.b $FE
	dc.b 0

byte_2377A:
	dc.b 0
	dc.b $11
	dc.b 0
	dc.b $12
	dc.b 0
	dc.b $13
	dc.b 1
	dc.b $14
	dc.b 0
	dc.b $13
	dc.b 0
	dc.b $12
	dc.b $FF
	dc.b 0
	dc.l byte_2377A

byte_2378C:
	dc.b 2
	dc.b $11
	dc.b 1
	dc.b $12
	dc.b 1
	dc.b $13
	dc.b 6
	dc.b $14
	dc.b 0
	dc.b $13
	dc.b 0
	dc.b $12
	dc.b 0
	dc.b $11
	dc.b 3
	dc.b $15
	dc.b 3
	dc.b $16
	dc.b 3
	dc.b $17
	dc.b 3
	dc.b $18
	dc.b 3
	dc.b $19
	dc.b 3
	dc.b $1A
	dc.b $FE
	dc.b 0

; =============== S U B	R O U T	I N E =======================================

	; Nemesis Decompression	
	if FastNemesis=0
	include "lib/decompressions/nemesis decompression - original.asm"
	else
	include "lib/decompressions/nemesis decompression - improved.asm"
	endc

; =============== S U B	R O U T	I N E =======================================

	; Enigma Decompression	
	include "lib/decompressions/enigma decompression.asm"

; =============== S U B	R O U T	I N E =======================================

ProcEniTilemapQueue:
	move.l	#$800000,d4
	move.b	(vdp_reg_10).l,d0
	andi.b	#2,d0
	beq.s	.LoadStart
	move.l	#$1000000,d4

.LoadStart:
	lea	(eni_tilemap_queue).l,a1
	lea	VDP_CTRL,a2
	lea	VDP_DATA,a3

.PlaneLoop:
	tst.w	(a1)
	beq.w	.End
	lea	(eni_tilemap_buffer).l,a0
	move.w	#0,(a1)+
	move.w	(a1)+,d1
	move.w	(a1)+,d2
	move.w	(a1)+,d0
	swap	d0
	andi.l	#$3FFF0000,d0
	ori.l	#$40000003,d0

.LineLoop:
	move.l	d0,(a2)
	move.w	d1,d3

.TileLoop:
	move.w	(a0)+,(a3)
	dbf	d3,.TileLoop
	add.l	d4,d0
	dbf	d2,.LineLoop
	bra.s	.PlaneLoop
; ---------------------------------------------------------------------------

.End:
	rts
; End of function ProcEniTilemapQueue

; =============== S U B	R O U T	I N E =======================================

ClearPlaneA_DMA:
	lea	VDP_CTRL,a0
	move.w	#$8F01,VDP_CTRL
	move.b	#1,(vdp_reg_f).l
	move.l	#$94409300,(a0)
	move.w	#$9780,(a0)
	move.w	#$4000,(a0)
	move.w	#$83,(a0)
	move.w	#0,-4(a0)

.WaitDMA:
	move.w	(a0),d7
	andi.w	#2,d7
	bne.s	.WaitDMA
	move.w	#$8F02,VDP_CTRL
	move.b	#2,(vdp_reg_f).l
	rts
; End of function ClearPlaneA_DMA

; =============== S U B	R O U T	I N E =======================================

ClearPlaneA:
	DISABLE_INTS
	move.w	#$4000,VDP_CTRL
	move.w	#3,VDP_CTRL
	lea	VDP_DATA,a1
	move.w	#$1FF,d1
	moveq	#0,d0
	bsr.w	MassFill
	ENABLE_INTS
	rts
; End of function ClearPlaneA

; =============== S U B	R O U T	I N E =======================================

ClearPlaneB:
	DISABLE_INTS
	move.w	#$6000,VDP_CTRL
	move.w	#3,VDP_CTRL
	lea	VDP_DATA,a1
	move.w	#$1FF,d1
	moveq	#0,d0
	bsr.w	MassFill
	ENABLE_INTS
	rts
; End of function ClearPlaneB

; =============== S U B	R O U T	I N E =======================================

ClearPlaneB_DMA:
	lea	VDP_CTRL,a0
	move.w	#$8F01,VDP_CTRL
	move.b	#1,(vdp_reg_f).l
	move.l	#$94109300,(a0)
	move.w	#$9780,(a0)
	move.w	#$7000,(a0)
	move.w	#$83,(a0)
	move.w	#0,-4(a0)

.WaitDMA:
	move.w	(a0),d7
	andi.w	#2,d7
	bne.s	.WaitDMA
	move.w	#$8F02,VDP_CTRL
	move.b	#2,(vdp_reg_f).l
	rts
; End of function ClearPlaneB_DMA

; =============== S U B	R O U T	I N E =======================================

MassFill:
	move.l	d0,(a1)
	move.l	d0,(a1)
	move.l	d0,(a1)
	move.l	d0,(a1)
	dbf	d1,MassFill
	rts
; End of function MassFill

; ---------------------------------------------------------------------------
;	ALIGN	$10000, $FF
ArtUnc_Robotnik_0:
	incbin	"resource/artunc/Robotnik/Robotnik 0.unc"
	even
	
ArtUnc_Robotnik_1:
	incbin	"resource/artunc/Robotnik/Robotnik 1.unc"
	even
	
ArtUnc_Robotnik_2:
	incbin	"resource/artunc/Robotnik/Robotnik 2.unc"
	even
	
ArtUnc_Robotnik_3:
	incbin	"resource/artunc/Robotnik/Robotnik 3.unc"
	even
	
ArtUnc_Robotnik_4:
	incbin	"resource/artunc/Robotnik/Robotnik 4.unc"
	even
	
ArtUnc_Robotnik_5:
	incbin	"resource/artunc/Robotnik/Robotnik 5.unc"
	even
	
ArtUnc_Robotnik_6:
	incbin	"resource/artunc/Robotnik/Robotnik 6.unc"
	even
	
ArtUnc_Robotnik_7:
	incbin	"resource/artunc/Robotnik/Robotnik 7.unc"
	even
	
ArtUnc_Robotnik_8:
	incbin	"resource/artunc/Robotnik/Robotnik 8.unc"
	even
	
ArtUnc_Robotnik_9:
	incbin	"resource/artunc/Robotnik/Robotnik 9.unc"
	even
	
ArtUnc_Robotnik_10:
	incbin	"resource/artunc/Robotnik/Robotnik 10.unc"
	even
	
ArtUnc_Robotnik_11:
	incbin	"resource/artunc/Robotnik/Robotnik 11.unc"
	even
	
ArtUnc_Robotnik_12:
	incbin	"resource/artunc/Robotnik/Robotnik 12.unc"
	even
	
ArtUnc_Robotnik_13:
	incbin	"resource/artunc/Robotnik/Robotnik 13.unc"
	even
	
ArtUnc_Robotnik_14:
	incbin	"resource/artunc/Robotnik/Robotnik 14.unc"
	even
	
ArtUnc_Robotnik_15:
	incbin	"resource/artunc/Robotnik/Robotnik 15.unc"
	even
	
ArtUnc_Robotnik_16:
	incbin	"resource/artunc/Robotnik/Robotnik 16.unc"
	even
	
ArtUnc_Robotnik_17:
	incbin	"resource/artunc/Robotnik/Robotnik 17.unc"
	even
	
ArtUnc_Robotnik_18:
	incbin	"resource/artunc/Robotnik/Robotnik 18.unc"
	even
	
ArtUnc_Robotnik_19:
	incbin	"resource/artunc/Robotnik/Robotnik 19.unc"
	even
	
ArtUnc_Robotnik_20:
	incbin	"resource/artunc/Robotnik/Robotnik 20.unc"
	even
	
ArtNem_RobotnikShip:
	incbin	"resource/artnem/Intro/Robotnik's Ship.nem"
	even
	
; ---------------------------------------------------------------------------

ArtNem_Scratch:
	incbin	"resource/artnem/Enemy/Scratch.nem"
	even
	
MapEni_Scratch_0:	
	incbin	"resource/mapeni/Enemy/Scratch/Scratch 0.eni"
	even
	
MapEni_Scratch_1:	
	incbin	"resource/mapeni/Enemy/Scratch/Scratch 1.eni"
	even
	
MapEni_Scratch_2:
	incbin	"resource/mapeni/Enemy/Scratch/Scratch 2.eni"
	even
	
MapEni_Scratch_3:
	incbin	"resource/mapeni/Enemy/Scratch/Scratch 3.eni"
	even
	
MapEni_Scratch_4:
	incbin	"resource/mapeni/Enemy/Scratch/Scratch 4.eni"
	even
	
MapEni_Scratch_5:
	incbin	"resource/mapeni/Enemy/Scratch/Scratch 5.eni"
	even
	
MapEni_Scratch_Defeated:
	incbin	"resource/mapeni/Enemy/Scratch/Scratch Defeated.eni"
	even
	
; ---------------------------------------------------------------------------

ArtNem_Frankly:
	incbin	"resource/artnem/Enemy/Frankly.nem"
	even
	
MapEni_Frankly_0:	
	incbin	"resource/mapeni/Enemy/Frankly/Frankly 0.eni"
	even
	
MapEni_Frankly_1:
	incbin	"resource/mapeni/Enemy/Frankly/Frankly 1.eni"
	even
	
MapEni_Frankly_2:
	incbin	"resource/mapeni/Enemy/Frankly/Frankly 2.eni"
	even
	
MapEni_Frankly_3:
	incbin	"resource/mapeni/Enemy/Frankly/Frankly 3.eni"
	even
	
MapEni_Frankly_4:
	incbin	"resource/mapeni/Enemy/Frankly/Frankly 4.eni"
	even
	
MapEni_Frankly_Defeated:
	incbin	"resource/mapeni/Enemy/Frankly/Frankly Defeated.eni"
	even

ArtNem_Frankly_Lightning:
	incbin	"resource/artnem/Enemy/Frankly Lightning.nem"
	even
	
; ---------------------------------------------------------------------------
	
ArtNem_Coconuts:
	incbin	"resource/artnem/Enemy/Coconuts.nem"
	even
	
MapEni_Coconuts_0:	
	incbin	"resource/mapeni/Enemy/Coconuts/Coconuts 0.eni"
	even

MapEni_Coconuts_1:	
	incbin	"resource/mapeni/Enemy/Coconuts/Coconuts 1.eni"
	even

MapEni_Coconuts_2:	
	incbin	"resource/mapeni/Enemy/Coconuts/Coconuts 2.eni"
	even

MapEni_Coconuts_3:
	incbin	"resource/mapeni/Enemy/Coconuts/Coconuts 3.eni"
	even

MapEni_Coconuts_4:	
	incbin	"resource/mapeni/Enemy/Coconuts/Coconuts 4.eni"
	even

MapEni_Coconuts_5:	
	incbin	"resource/mapeni/Enemy/Coconuts/Coconuts 5.eni"
	even

MapEni_Coconuts_6:	
	incbin	"resource/mapeni/Enemy/Coconuts/Coconuts 6.eni"
	even

MapEni_Coconuts_Defeated:	
	incbin	"resource/mapeni/Enemy/Coconuts/Coconuts Defeated.eni"
	even
	
; ---------------------------------------------------------------------------

ArtNem_Dynamight:
	incbin	"resource/artnem/Enemy/Dynamight.nem"
	even
	
MapEni_Dynamight_0:	
	incbin	"resource/mapeni/Enemy/Dynamight/Dynamight 0.eni"
	even
	
MapEni_Dynamight_1:		
	incbin	"resource/mapeni/Enemy/Dynamight/Dynamight 1.eni"
	even
	
MapEni_Dynamight_2:	
	incbin	"resource/mapeni/Enemy/Dynamight/Dynamight 2.eni"
	even
	
MapEni_Dynamight_3:		
	incbin	"resource/mapeni/Enemy/Dynamight/Dynamight 3.eni"
	even
	
MapEni_Dynamight_4:		
	incbin	"resource/mapeni/Enemy/Dynamight/Dynamight 4.eni"
	even
	
MapEni_Dynamight_5:	
	incbin	"resource/mapeni/Enemy/Dynamight/Dynamight 5.eni"
	even
	
MapEni_Dynamight_6:	
	incbin	"resource/mapeni/Enemy/Dynamight/Dynamight 6.eni"
	even
	
MapEni_Dynamight_7:	
	incbin	"resource/mapeni/Enemy/Dynamight/Dynamight 7.eni"
	even
	
MapEni_Dynamight_8:		
	incbin	"resource/mapeni/Enemy/Dynamight/Dynamight 8.eni"
	even
	
MapEni_Dynamight_9:
	incbin	"resource/mapeni/Enemy/Dynamight/Dynamight 9.eni"
	even
	
MapEni_Dynamight_Defeated:	
	incbin	"resource/mapeni/Enemy/Dynamight/Dynamight Defeated.eni"
	even
	
; ---------------------------------------------------------------------------

ArtNem_Grounder:
	incbin	"resource/artnem/Enemy/Grounder.nem"
	even
	
MapEni_Grounder_0:
	incbin	"resource/mapeni/Enemy/Grounder/Grounder 0.eni"
	even
	
MapEni_Grounder_1:
	incbin	"resource/mapeni/Enemy/Grounder/Grounder 1.eni"
	even

MapEni_Grounder_2:
	incbin	"resource/mapeni/Enemy/Grounder/Grounder 2.eni"
	even

MapEni_Grounder_3:
	incbin	"resource/mapeni/Enemy/Grounder/Grounder 3.eni"
	even

MapEni_Grounder_4:
	incbin	"resource/mapeni/Enemy/Grounder/Grounder 4.eni"
	even

MapEni_Grounder_5:
	incbin	"resource/mapeni/Enemy/Grounder/Grounder 5.eni"
	even

MapEni_Grounder_6:
	incbin	"resource/mapeni/Enemy/Grounder/Grounder 6.eni"
	even

MapEni_Grounder_Defeated:
	incbin	"resource/mapeni/Enemy/Grounder/Grounder Defeated.eni"
	even
	
; ---------------------------------------------------------------------------

ArtNem_DavySprocket:
	incbin	"resource/artnem/Enemy/Davy Sprocket.nem"
	even
	
MapEni_DavySprocket_0:
	incbin	"resource/mapeni/Enemy/Davy Sprocket/Davy Sprocket 0.eni"
	even

MapEni_DavySprocket_1:
	incbin	"resource/mapeni/Enemy/Davy Sprocket/Davy Sprocket 1.eni"
	even

MapEni_DavySprocket_2:
	incbin	"resource/mapeni/Enemy/Davy Sprocket/Davy Sprocket 2.eni"
	even

MapEni_DavySprocket_3:
	incbin	"resource/mapeni/Enemy/Davy Sprocket/Davy Sprocket 3.eni"
	even

MapEni_DavySprocket_4:
	incbin	"resource/mapeni/Enemy/Davy Sprocket/Davy Sprocket 4.eni"
	even

MapEni_DavySprocket_5:
	incbin	"resource/mapeni/Enemy/Davy Sprocket/Davy Sprocket 5.eni"
	even

MapEni_DavySprocket_Defeated:
	incbin	"resource/mapeni/Enemy/Davy Sprocket/Davy Sprocket Defeated.eni"
	even
	
; ---------------------------------------------------------------------------

ArtNem_Spike:
	incbin	"resource/artnem/Enemy/Spike.nem"
	even
	
MapEni_Spike_0:	
	incbin	"resource/mapeni/Enemy/Spike/Spike 0.eni"
	even
	
MapEni_Spike_1:	
	incbin	"resource/mapeni/Enemy/Spike/Spike 1.eni"
	even

MapEni_Spike_2:	
	incbin	"resource/mapeni/Enemy/Spike/Spike 2.eni"
	even

MapEni_Spike_3:	
	incbin	"resource/mapeni/Enemy/Spike/Spike 3.eni"
	even

MapEni_Spike_4:	
	incbin	"resource/mapeni/Enemy/Spike/Spike 4.eni"
	even

MapEni_Spike_5:
	incbin	"resource/mapeni/Enemy/Spike/Spike 5.eni"
	even

MapEni_Spike_6:
	incbin	"resource/mapeni/Enemy/Spike/Spike 6.eni"
	even

MapEni_Spike_Defeated:
	incbin	"resource/mapeni/Enemy/Spike/Spike Defeated.eni"
	even

; ---------------------------------------------------------------------------

ArtNem_DragonBreath:
	incbin	"resource/artnem/Enemy/Dragon Breath.nem"
	even
	
MapEni_DragonBreath_0:
	incbin	"resource/mapeni/Enemy/Dragon Breath/Dragon Breath 0.eni"
	even

MapEni_DragonBreath_1:
	incbin	"resource/mapeni/Enemy/Dragon Breath/Dragon Breath 1.eni"
	even

MapEni_DragonBreath_2:
	incbin	"resource/mapeni/Enemy/Dragon Breath/Dragon Breath 2.eni"
	even

MapEni_DragonBreath_3:	
	incbin	"resource/mapeni/Enemy/Dragon Breath/Dragon Breath 3.eni"
	even

MapEni_DragonBreath_4:
	incbin	"resource/mapeni/Enemy/Dragon Breath/Dragon Breath 4.eni"
	even

MapEni_DragonBreath_5:	
	incbin	"resource/mapeni/Enemy/Dragon Breath/Dragon Breath 5.eni"
	even

MapEni_DragonBreath_6:
	incbin	"resource/mapeni/Enemy/Dragon Breath/Dragon Breath 6.eni"
	even

MapEni_DragonBreath_7:
	incbin	"resource/mapeni/Enemy/Dragon Breath/Dragon Breath 7.eni"
	even

MapEni_DragonBreath_Defeated:	
	incbin	"resource/mapeni/Enemy/Dragon Breath/Dragon Breath Defeated.eni"
	even
	
; ---------------------------------------------------------------------------

ArtNem_Humpty:
	incbin	"resource/artnem/Enemy/Humpty.nem"
	even
	
MapEni_Humpty_0:	
	incbin	"resource/mapeni/Enemy/Humpty/Humpty 0.eni"
	even

MapEni_Humpty_1:	
	incbin	"resource/mapeni/Enemy/Humpty/Humpty 1.eni"
	even

MapEni_Humpty_2:
	incbin	"resource/mapeni/Enemy/Humpty/Humpty 2.eni"
	even

MapEni_Humpty_3:
	incbin	"resource/mapeni/Enemy/Humpty/Humpty 3.eni"
	even

MapEni_Humpty_4:
	incbin	"resource/mapeni/Enemy/Humpty/Humpty 4.eni"
	even

MapEni_Humpty_5:	
	incbin	"resource/mapeni/Enemy/Humpty/Humpty 5.eni"
	even

MapEni_Humpty_6:
	incbin	"resource/mapeni/Enemy/Humpty/Humpty 6.eni"
	even

MapEni_Humpty_7:	
	incbin	"resource/mapeni/Enemy/Humpty/Humpty 7.eni"
	even

MapEni_Humpty_8:
	incbin	"resource/mapeni/Enemy/Humpty/Humpty 8.eni"
	even

MapEni_Humpty_Defeated:
	incbin	"resource/mapeni/Enemy/Humpty/Humpty Defeated.eni"
	even
	
; ---------------------------------------------------------------------------

ArtNem_DrRobotnik:
	incbin	"resource/artnem/Enemy/Dr Robotnik.nem"
	even
	
MapEni_DrRobotnik_0:
	incbin	"resource/mapeni/Enemy/Dr Robotnik/Dr Robotnik 0.eni"
	even

MapEni_DrRobotnik_1:
	incbin	"resource/mapeni/Enemy/Dr Robotnik/Dr Robotnik 1.eni"
	even

MapEni_DrRobotnik_2:
	incbin	"resource/mapeni/Enemy/Dr Robotnik/Dr Robotnik 2.eni"
	even

MapEni_DrRobotnik_3:
	incbin	"resource/mapeni/Enemy/Dr Robotnik/Dr Robotnik 3.eni"
	even

MapEni_DrRobotnik_4:
	incbin	"resource/mapeni/Enemy/Dr Robotnik/Dr Robotnik 4.eni"
	even

MapEni_DrRobotnik_5:
	incbin	"resource/mapeni/Enemy/Dr Robotnik/Dr Robotnik 5.eni"
	even

MapEni_DrRobotnik_6:
	incbin	"resource/mapeni/Enemy/Dr Robotnik/Dr Robotnik 6.eni"
	even

MapEni_DrRobotnik_Defeated:	
	incbin	"resource/mapeni/Enemy/Dr Robotnik/Dr Robotnik Defeated.eni"
	even
	
; ---------------------------------------------------------------------------

ArtNem_Skweel:
	incbin	"resource/artnem/Enemy/Skweel.nem"
	even
	
MapEni_Skweel_0:
	incbin	"resource/mapeni/Enemy/Skweel/Skweel 0.eni"
	even

MapEni_Skweel_1:
	incbin	"resource/mapeni/Enemy/Skweel/Skweel 1.eni"
	even

MapEni_Skweel_2:
	incbin	"resource/mapeni/Enemy/Skweel/Skweel 2.eni"
	even

MapEni_Skweel_3:
	incbin	"resource/mapeni/Enemy/Skweel/Skweel 3.eni"
	even

MapEni_Skweel_4:
	incbin	"resource/mapeni/Enemy/Skweel/Skweel 4.eni"
	even

MapEni_Skweel_5:
	incbin	"resource/mapeni/Enemy/Skweel/Skweel 5.eni"
	even

MapEni_Skweel_6:
	incbin	"resource/mapeni/Enemy/Skweel/Skweel 6.eni"
	even

MapEni_Skweel_7:
	incbin	"resource/mapeni/Enemy/Skweel/Skweel 7.eni"
	even

MapEni_Skweel_8:
	incbin	"resource/mapeni/Enemy/Skweel/Skweel 8.eni"
	even

MapEni_Skweel_9:	
	incbin	"resource/mapeni/Enemy/Skweel/Skweel 9.eni"
	even

MapEni_Skweel_10:
	incbin	"resource/mapeni/Enemy/Skweel/Skweel 10.eni"
	even

MapEni_Skweel_11:
	incbin	"resource/mapeni/Enemy/Skweel/Skweel 11.eni"
	even

MapEni_Skweel_Defeated:
	incbin	"resource/mapeni/Enemy/Skweel/Skweel Defeated.eni"
	even
	
; ---------------------------------------------------------------------------

ArtNem_SirFfuzzyLogik:
	incbin	"resource/artnem/Enemy/Sir Ffuzzy Logik.nem"
	even
	
MapEni_SirFfuzzyLogik_0:
	incbin	"resource/mapeni/Enemy/Sir Ffuzzy Logik/Sir Ffuzzy Logik 0.eni"
	even

MapEni_SirFfuzzyLogik_1:
	incbin	"resource/mapeni/Enemy/Sir Ffuzzy Logik/Sir Ffuzzy Logik 1.eni"
	even

MapEni_SirFfuzzyLogik_2:
	incbin	"resource/mapeni/Enemy/Sir Ffuzzy Logik/Sir Ffuzzy Logik 2.eni"
	even

MapEni_SirFfuzzyLogik_3:
	incbin	"resource/mapeni/Enemy/Sir Ffuzzy Logik/Sir Ffuzzy Logik 3.eni"
	even

MapEni_SirFfuzzyLogik_4:
	incbin	"resource/mapeni/Enemy/Sir Ffuzzy Logik/Sir Ffuzzy Logik 4.eni"
	even

MapEni_SirFfuzzyLogik_5:
	incbin	"resource/mapeni/Enemy/Sir Ffuzzy Logik/Sir Ffuzzy Logik 5.eni"
	even

MapEni_SirFfuzzyLogik_6:	
	incbin	"resource/mapeni/Enemy/Sir Ffuzzy Logik/Sir Ffuzzy Logik 6.eni"
	even

MapEni_SirFfuzzyLogik_7:	
	incbin	"resource/mapeni/Enemy/Sir Ffuzzy Logik/Sir Ffuzzy Logik 7.eni"
	even

MapEni_SirFfuzzyLogik_8:
	incbin	"resource/mapeni/Enemy/Sir Ffuzzy Logik/Sir Ffuzzy Logik 8.eni"
	even
	
MapEni_SirFfuzzyLogik_Defeated_0:
	incbin	"resource/mapeni/Enemy/Sir Ffuzzy Logik/Sir Ffuzzy Logik Defeated 0.eni"
	even

MapEni_SirFfuzzyLogik_Defeated_1:	
	incbin	"resource/mapeni/Enemy/Sir Ffuzzy Logik/Sir Ffuzzy Logik Defeated 1.eni"
	even

MapEni_SirFfuzzyLogik_Defeated_2:
	incbin	"resource/mapeni/Enemy/Sir Ffuzzy Logik/Sir Ffuzzy Logik Defeated 2.eni"
	even
	
; ---------------------------------------------------------------------------

ArtNem_Arms:
	incbin	"resource/artnem/Enemy/Arms.nem"
	even
	
MapEni_Arms_0:
	incbin	"resource/mapeni/Enemy/Arms/Arms 0.eni"
	even

MapEni_Arms_1:
	incbin	"resource/mapeni/Enemy/Arms/Arms 1.eni"
	even

MapEni_Arms_2:
	incbin	"resource/mapeni/Enemy/Arms/Arms 2.eni"
	even

MapEni_Arms_3:
	incbin	"resource/mapeni/Enemy/Arms/Arms 3.eni"
	even

MapEni_Arms_4:
	incbin	"resource/mapeni/Enemy/Arms/Arms 4.eni"
	even

MapEni_Arms_5:
	incbin	"resource/mapeni/Enemy/Arms/Arms 5.eni"
	even

MapEni_Arms_6:	
	incbin	"resource/mapeni/Enemy/Arms/Arms 6.eni"
	even

MapEni_Arms_7:
	incbin	"resource/mapeni/Enemy/Arms/Arms 7.eni"
	even

MapEni_Arms_Defeated:	
	incbin	"resource/mapeni/Enemy/Arms/Arms Defeated.eni"
	even

MapEni_Arms_8:	
	incbin	"resource/mapeni/Enemy/Arms/Arms 8.eni"
	even
	
; ---------------------------------------------------------------------------

ArtNem_IntroBadniks:
	incbin	"resource/artnem/Opening/Intro Badniks.nem"
	even
	
ArtNem_OpponentScreen:
	incbin	"resource/artnem/Background/Opponent's Screen.nem"
	even
	
ArtNem_Password:
	incbin	"resource/artnem/Background/Password.nem"
	even
	
ArtNem_RoleCallTextbox:
	incbin	"resource/artnem/Ending/Role Call Textbox.nem"
	even
	
ArtNem_MainFont:
	incbin	"resource/artnem/Font/Font - Main.nem"
	even
	
ArtNem_CoconutsIntro:
	incbin	"resource/artnem/Intro/Coconuts Intro.nem"
	even
	
ArtNem_FranklyIntro:
	incbin	"resource/artnem/Intro/Frankly Intro.nem"
	even
	
ArtNem_DavyIntro:
	incbin	"resource/artnem/Intro/Davy Intro.nem"
	even
	
ArtNem_DynamightIntro:
	incbin	"resource/artnem/Intro/Dynamight Intro.nem"
	even
	
ArtNem_ArmsIntro:
	incbin	"resource/artnem/Intro/Arms Intro 1.nem"
	even
	
ArtNem_ArmsIntro2:
	incbin	"resource/artnem/Intro/Arms Intro 2.nem"
	even
	
ArtNem_DragonIntro:
	incbin	"resource/artnem/Intro/Dragon Intro.nem"
	even
	
ArtNem_SpikeIntro:
	incbin	"resource/artnem/Intro/Spike Intro.nem"
	even
	
ArtNem_SirLogikIntro:
	incbin	"resource/artnem/Intro/Sir Ffuzzy Intro.nem"
	even
	
ArtNem_HumptyIntro:
	incbin	"resource/artnem/Intro/Humpty Intro.nem"
	even
ArtNem_GrounderIntro:
	incbin	"resource/artnem/Intro/Grounder Intro.nem"
	even
	
ArtNem_AllRightOhNo:
	incbin	"resource/artnem/VS/All Right - Oh No.nem"
	even
	
ArtNem_SkweelIntro:
	incbin	"resource/artnem/Intro/Skweel Intro.nem"
	even
	
ArtNem_ScratchIntro:
	incbin	"resource/artnem/Intro/Scratch Intro.nem"
	even

; ---------------------------------------------------------------------------
	
ArtNem_LvlIntroBG:	
	incbin	"resource/artnem/Background/Level Intro.nem"
	even
	
MapEni_LvlIntroBG_0:
	incbin	"resource/mapeni/Intro/Level Intro 0.eni"
	even
	
MapEni_LvlIntroBG_1:
	incbin	"resource/mapeni/Intro/Level Intro 1.eni"
	even
		
MapEni_LvlIntroBG_2:	
	incbin	"resource/mapeni/Intro/Level Intro 2.eni"
	even
	
; ---------------------------------------------------------------------------

ArtNem_Intro:	
	incbin	"resource/artnem/Opening/Intro.nem"
	even
	
MapEni_LairMachine:
	incbin	"resource/mapeni/Lair/Robotnik's Lair - Machine.eni"
	even
	
MapEni_LairWall:
	incbin	"resource/mapeni/Lair/Robotnik's Lair - Wall.eni"
	even
	
MapEni_LairFloor:
	incbin	"resource/mapeni/Lair/Robotnik's Lair - Floor.eni"
	even

MapPrio_LairMachine:
	dc.b 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	1, 1, 1, 1, 1, 1, 1, 0,	0, 0, 0, 0, 0, 1, 1
	dc.b 0,	0, 0, 1, 1, 1, 1, 1, 1,	1, 1, 1, 1, 1, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	1, 1, 1, 1, 1, 1, 1
	dc.b 0,	0, 0, 0, 0, 0, 1, 1, 0,	0, 0, 1, 1, 1, 1, 1
	dc.b 1,	1, 1, 1, 1, 1, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	1, 1, 1, 1, 1, 1, 1, 0,	0, 0, 0, 0, 0, 1, 1
	dc.b 0,	0, 0, 1, 1, 1, 1, 1, 1,	1, 1, 1, 1, 1, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	1, 1, 1, 1, 1, 1, 1
	dc.b 0,	0, 0, 0, 0, 0, 1, 1, 0,	0, 0, 0, 1, 1, 1, 1
	dc.b 1,	1, 1, 1, 1, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	1, 1, 1, 1, 1, 1, 1, 0,	0, 0, 0, 0, 0, 1, 1
	dc.b 0,	0, 0, 0, 1, 1, 1, 1, 1,	1, 1, 1, 1, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	1, 1, 1, 1, 1, 1, 1
	dc.b 0,	0, 0, 0, 0, 0, 1, 1, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	
; ---------------------------------------------------------------------------
	
ArtNem_EndingBG:
	incbin	"resource/artnem/Background/Ending.nem"
	even
	
MapEni_LairDestroyed0:	
	incbin	"resource/mapeni/Lair/Robotnik's Lair - Destroyed 0.eni"
	even
	
MapEni_LairDestroyed1:
	incbin	"resource/mapeni/Lair/Robotnik's Lair - Destroyed 1.eni"
	even

MapEni_LairDestroyed2:
	incbin	"resource/mapeni/Lair/Robotnik's Lair - Destroyed 2.eni"
	even
	
; ---------------------------------------------------------------------------

ArtNem_CreditsLair:
	incbin	"resource/artnem/Ending/Credits - Lair.nem"
	even
	
ArtNem_GameOver:
	incbin	"resource/artnem/Font/Font - Game Over.nem"
	even
	
byte_66C9A:	
	dc.b 0, 0, 0, 1, 0, 1, 0, 1, 8, 0, 0, $A, 0, $B, 0, $C
	dc.b 8, $B, 8, $A, 0, $A, 0, $14, 0, 6, 8, $14, 8, $A, 0, $A
	dc.b 0, $14, 0, 6, 8, $14, 8, $A, 0, $A, 0, $14, 0, 6, 8, $14
	dc.b 8, $A, 0, $A, $10, $B, $10, $C, $18, $B, 8, $A, $10, 0, $10, 1
	dc.b $10, 1, $10, 1, $18, 0, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6
	dc.b 0, $D, 0, $E, 0, $F, 0, $10, 0, 6, 0, 6, 0, $15, 0, $F
	dc.b 0, $10, 0, 6, 0, 6, 0, $15, 0, $F, 0, $10, 0, 6, 0, 6
	dc.b 0, $15, 0, $F, 0, $10, 0, 6, 0, 6, 0, $15, 0, $F, 0, $10
	dc.b 0, 6, 0, 6, 0, $37, $10, 1, $10, 5, 0, 6, 0, 0, 0, 1
	dc.b 0, 1, 0, 1, 8, 0, 0, $A, 0, $B, 0, $C, 8, $B, 8, $A
	dc.b 0, $16, 0, $17, 0, $18, 0, $19, 0, $1A, 0, 6, 0, $18, 0, $22
	dc.b 0, $23, 0, $24, 0, $18, 0, $22, 0, $23, 0, $29, 0, 6, 0, $31
	dc.b 0, $F, 0, $32, 0, $33, $18, $16, 0, $34, $10, 1, $10, 1, $10, 1
	dc.b 8, $34, 0, 0, 0, 1, 0, 1, 0, 1, 8, 0, 0, $A, 0, $B
	dc.b 0, $C, 8, $B, 8, $A, 0, $1B, 0, $1C, 0, $1D, 0, $1E, 0, $1F
	dc.b 0, 6, 0, $25, 0, $26, 0, $F, 0, $27, 0, $2A, 0, $2B, 0, $2C
	dc.b 0, $2D, 8, $A, 0, $A, $10, $B, $10, $C, $18, $B, 8, $A, $10, 0
	dc.b $10, 1, $10, 1, $10, 1, $18, 0, 0, 6, 0, 7, 0, 8, 0, 1
	dc.b 0, 9, 0, 6, 0, $11, 0, $12, 0, $F, 0, $13, 0, 7, 0, $20
	dc.b 0, $21, 0, $F, 0, $13, 0, $11, $18, $20, 0, $28, 0, $F, 0, $13
	dc.b $18, $1A, 0, $2E, 0, $2F, 0, $F, 0, $30, 0, $34, $10, 1, 0, $35
	dc.b 0, $F, 0, $36, 0, 6, 0, 6, 0, $37, $10, 1, $10, 9, $10, $34
	dc.b 0, 1, 0, 1, 0, 1, $18, $34, 0, $A, 0, $B, 0, $38, 0, $38
	dc.b 0, $39, 0, $A, $10, $B, 0, $3B, 0, $3C, 0, $3D, 8, $39, 0, $44
	dc.b 0, $45, 0, $2D, 8, $A, 0, $2A, 0, $2B, 0, 6, 8, $14, 8, $A
	dc.b 0, $A, $10, $B, $10, $C, $18, $B, 8, $A, $10, 0, $10, 1, $10, 1
	dc.b $10, 1, $18, 0, 0, 0, 0, 1, 0, 1, 0, 1, 8, 0, 0, $A
	dc.b 0, $B, 0, $C, 8, $B, 8, $A, 0, $A, 0, $14, 0, $3E, 0, $3F
	dc.b 0, $40, 0, $A, 8, $1E, 0, $46, 0, $F, 0, $47, 0, $A, $18, $19
	dc.b $10, $43, $10, $19, 8, $A, 0, $A, $10, $B, $10, $C, $18, $B, 8, $A
	dc.b $10, 0, $10, 1, $10, 1, $10, 1, $18, 0, $10, $34, 0, 1, 0, 1
	dc.b 0, 1, $18, $34, 8, $39, 0, $38, 0, $3A, 0, $F, 0, $1F, 0, 6
	dc.b 0, 6, 0, $41, 0, $F, 0, $42, 0, 6, 0, $48, 0, $49, 0, $4A
	dc.b 0, $4B, 0, 6, 0, $41, 0, $F, 0, $42, 0, 6, 0, $48, 0, $49
	dc.b 0, $4A, 0, $4B, 0, 6, 0, $50, $10, 1, 0, $51, 0, 6, 0, 6
	dc.b 0, 0, 0, 1, 0, 1, 0, 1, 8, 0, 0, $A, 0, $B, 0, $C
	dc.b 8, $B, 8, $A, 8, $1F, $10, $B, $10, $C, $18, $B, 0, $1F, 0, $4C
	dc.b 0, $F, 0, $4D, 0, $F, 8, $4C, 0, $A, 0, $4E, 0, $4F, 8, $4E
	dc.b 8, $A, 0, $A, $10, $B, $10, $C, $18, $B, 8, $A, $10, 0, $10, 1
	dc.b $10, 1, $10, 1, $18, 0, 0, 0, 0, 1, 0, 1, 0, 1, 8, 0
	dc.b 0, $A, 0, $B, 0, $C, 8, $B, 8, $A, 0, $A, 8, $19, 0, $43
	dc.b 0, $19, 8, $A, $18, $47, 0, $F, $18, $46, $10, $1E, 8, $A, $18, $40
	dc.b $18, $3F, $18, $3E, 8, $14, 8, $A, 0, $A, $10, $B, $10, $C, $18, $B
	dc.b 8, $A, $10, 0, $10, 1, $10, 1, $10, 1, $18, 0, 0, 0, 0, 1
	dc.b 0, 1, 0, 1, 8, 0, 0, $A, 0, $B, 0, $C, 8, $B, 8, $A
	dc.b 0, $A, 8, $19, 0, $43, 0, $19, 8, $A, $18, $47, 0, $F, $18, $46
	dc.b $10, $1E, 8, $A, $18, $40, $18, $3F, $18, $3E, 8, $14, 8, $A, 0, $A
	dc.b $10, $B, $10, $C, $18, $B, 8, $A, $10, 0, $10, 1, $10, 1, $10, 1
	dc.b $18, 0
	
ArtNem_GameOverBG:
	incbin	"resource/artnem/Background/Game Over.nem"
	even
	
MapEni_GameOverRobots:	
	incbin	"resource/mapeni/Game Over/Background - Robots.eni"
	even
	
MapEni_GameOverLight:
	incbin	"resource/mapeni/Game Over/Background - Light.eni"
	even
	
byte_6A144:	
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 1, 1, 1, 1,	1, 1, 1, 1, 1, 1, 1
	dc.b 1,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 1, 1, 1
	dc.b 1,	1, 1, 1, 1, 1, 1, 1, 1,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 1, 1, 1, 1,	1, 1, 1, 1, 1, 1, 1
	dc.b 1,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 1, 1, 1
	dc.b 1,	1, 1, 1, 1, 1, 1, 1, 1,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 1, 1, 1, 1,	1, 1, 1, 1, 1, 1, 1
	dc.b 1,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 1, 1, 1
	dc.b 1,	1, 1, 1, 1, 1, 1, 1, 1,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	dc.b 0,	0, 0, 0, 0, 0, 0, 0, 0,	0, 0, 0, 0, 0, 0, 0
	
ArtNem_MainMenu:
	incbin	"resource/artnem/Background/Main Menu.nem"
	even
	
MapEni_MainMenu:
	incbin	"resource/mapeni/Menu/Main Menu.eni"
	even
	
MapEni_ScenarioMenu:
	incbin	"resource/mapeni/Menu/Scenario Menu.eni"
	even
	
MapEni_MainMenuClouds:
	incbin	"resource/mapeni/Menu/Clouds.eni"
	even
	
MapEni_MainMenuMountains:
	incbin	"resource/mapeni/Menu/Mountains.eni"
	even
	
ArtNem_HighScores:
	incbin	"resource/artnem/Background/High Scores.nem"
	even
	
MapEni_HighScores:
	incbin	"resource/mapeni/Background/High Scores.eni"
	even
	
ArtNem_CreditsSky:
	incbin	"resource/artnem/Ending/Credits - Sky.nem"
	even
	
MapEni_CreditsSky:	
	incbin	"resource/mapeni/Ending/Credits - Sky.eni"
	even
	
ArtNem_CreditsSmoke:
	incbin	"resource/artnem/Ending/Credits - Smoke.nem"
	even
	
ArtNem_CreditsExplosion:
	incbin	"resource/artnem/Ending/Credits - Explosion.nem"
	even
	
word_6F3FE:	
	dc.w 0,	0, $884, $862, $ACA, $6A8, $486, $264, $6AE, $62, $A4, $4C8, $26, $4A, $28C, $EEE
	dc.w 0,	0, $884, $862, $ACA, $6A8, $486, $264, $6AE, $62, $A4, $4C8, $26, $4A, $28C, $EEE
	dc.w 0,	0, $884, $862, $ACA, $6A8, $486, $264, $6AE, $62, $A4, $4C8, $26, $4A, $28C, $EEE
	dc.w 0,	0, $884, $862, $ACA, $6A8, $486, $264, $6AE, $62, $A4, $4C8, $26, $4A, $28C, $EEE
	dc.w 0,	0, $884, $862, $ACA, $6A8, $486, $264, $6AE, $62, $A4, $4C8, $26, $4A, $28C, $EEE
	dc.w 0,	0, $884, $862, $ACA, $6A8, $486, $264, $6AE, $62, $A4, $4C8, $26, $4A, $28C, $EEE
	dc.w 0,	0, $884, $862, $ACA, $6A8, $486, $264, $6AE, $62, $A4, $2C8, $26, $4A, $28C, $EEE
	dc.w 0,	0, $884, $862, $8CA, $6A8, $486, $264, $6AE, $62, $A4, $2C8, $26, $4A, $28C, $EEE
	dc.w 0,	0, $884, $862, $8CA, $6A8, $486, $264, $6AE, $62, $A4, $2C8, $26, $4A, $28C, $EEE
	dc.w 0,	0, $662, $642, $6A8, $486, $464, $242, $48C, $42, $84, $A8, $26, $4A, $26A, $EEE
	dc.w 0,	0, $662, $642, $6A8, $486, $464, $242, $48C, $42, $84, $A8, $26, $4A, $26A, $EEE
	dc.w 0,	0, $662, $642, $6A8, $486, $464, $242, $48C, $42, $84, $A8, $26, $4A, $26A, $EEE
	dc.w 0,	0, $662, $642, $6A8, $486, $464, $242, $48C, $42, $84, $A8, $26, $4A, $26A, $EEE
	dc.w 0,	0, $662, $642, $6A8, $486, $464, $242, $48C, $42, $84, $A8, $26, $4A, $26A, $EEE
	dc.w 0,	0, $662, $642, $6A8, $486, $464, $242, $68C, $242, $284, $2A8, $26, $4A, $26A, $EEE
	dc.w 0,	0, $662, $642, $6A6, $684, $462, $242, $68C, $242, $284, $2A8, $26, $4A, $26A, $EEE
	dc.w 0,	0, $662, $642, $6A6, $684, $462, $242, $68C, $242, $484, $4A8, $26, $248, $46A,	$EEE
	dc.w 0,	0, $642, $622, $6A6, $682, $662, $442, $88C, $442, $684, $4A8, $24, $448, $66A,	$EEE
	dc.w 0,	0, $642, $622, $8A6, $682, $662, $442, $88A, $442, $884, $8A8, $222, $646, $868, $EEE
	dc.w 0,	0, $642, $622, $8A6, $682, $662, $442, $88A, $442, $884, $8A8, $222, $646, $868, $EEE
	dc.w 0,	0, $642, $622, $884, $664, $642, $422, $A8A, $442, $884, $AA8, $222, $646, $868, $EEE
	dc.w 0,	0, $842, $822, $884, $662, $640, $420, $A8A, $442, $864, $A86, $222, $646, $868, $EEE
	dc.w 0,	0, $842, $822, $864, $642, $640, $420, $A88, $422, $862, $A84, $200, $644, $866, $EEE
	dc.w 0,	0, $842, $822, $862, $642, $640, $420, $A66, $422, $862, $A84, $200, $622, $844, $EEE
	dc.w 0,	0, $842, $822, $862, $642, $640, $420, $A66, $422, $862, $A84, $200, $622, $844, $EEE
	dc.w 0,	0, $842, $822, $862, $642, $640, $420, $A66, $422, $862, $A84, $200, $622, $844, $EEE
	dc.w 0,	0, $842, $822, $862, $642, $640, $420, $A66, $422, $862, $A84, $200, $622, $844, $EEE
	dc.w 0,	0, $842, $822, $862, $642, $640, $420, $A66, $422, $862, $A84, $200, $622, $844, $EEE
	dc.w 0,	0, $842, $822, $862, $642, $640, $420, $A66, $422, $862, $A84, $200, $622, $844, $EEE
	dc.w 0,	0, $842, $822, $862, $642, $640, $420, $A66, $422, $862, $A84, $200, $622, $844, $EEE
	dc.w 0,	0, $842, $822, $862, $642, $640, $420, $A66, $422, $862, $A84, $200, $622, $844, $EEE
	dc.w 0,	0, $842, $822, $862, $642, $640, $420, $A66, $422, $862, $A84, $200, $622, $844, $EEE
	dc.w 0,	0, $842, $822, $862, $642, $640, $420, $A66, $422, $862, $A84, $200, $622, $844, $EEE
	dc.w 0,	0, $842, $822, $862, $642, $640, $420, $A66, $422, $862, $A84, $200, $622, $844, $EEE
	dc.w 0,	0, $842, $822, $862, $642, $640, $420, $A66, $422, $862, $A84, $200, $622, $844, $EEE

word_6F85E:
	dc.w 0,	0, $222, $666, $AAA, $200, $200, $200, $EEE, $E84, $EA4, $EAA, $E84, $EC6, $EEA, $EEE
	dc.w 0,	0, $222, $666, $AAA, $200, $200, $200, $EEE, $C84, $CA4, $EAA, $C84, $CC6, $EEA, $EEE
	dc.w 0,	0, $222, $666, $AAA, $200, $200, $200, $EEE, $C86, $AA8, $EAA, $A88, $ACA, $CEC, $EEE
	dc.w 0,	0, $222, $666, $AAA, $200, $200, $200, $EEE, $C86, $8AA, $EAA, $88A, $ACA, $CCC, $EEE
	dc.w 0,	0, $222, $666, $AAA, $200, $200, $200, $EEE, $C86, $6AC, $EAA, $68C, $8CC, $ACE, $EEE
	dc.w 0,	0, $222, $666, $AAC, $200, $200, $200, $AEE, $C86, $6AE, $EAA, $68E, $6CE, $ACE, $EEE
	dc.w 0,	0, $222, $666, $AAC, $200, $200, $200, $8CE, $C86, $4AE, $EAA, $48E, $4CE, $8CE, $EEE
	dc.w 0,	0, $222, $666, $AAC, $200, $200, $200, $8CE, $C86, $2AE, $EAA, $48E, $2CE, $6CE, $EEE
	dc.w 0,	0, $222, $666, $AAC, $200, $200, $200, $6CE, $C86, $AE,	$EAA, $28E, $2CE, $6CE,	$EEE
	dc.w 0,	0, $224, $668, $AAC, $200, $200, $200, $4CE, $C66, $6E,	$EAA, $24E, $8E, $4AE, $EEE
	dc.w 0,	0, $224, $668, $AAC, $200, $200, $200, $4AE, $C66, $24E, $EAA, $44C, $6E, $28E,	$EEE
	dc.w 0,	0, $224, $668, $AAC, $200, $200, $200, $4AE, $C66, $44C, $EAA, $42A, $24E, $6E,	$EEE
	dc.w 0,	0, $224, $668, $AAC, $200, $200, $200, $26C, $A66, $22A, $6AC, $428, $22C, $26E, $EEE
	dc.w 0,	0, $224, $668, $AAC, $200, $200, $200, $26C, $A66, $428, $A8A, $426, $22A, $24E, $EEE
	dc.w 0,	0, $224, $666, $AAC, $200, $200, $200, $26C, $A66, $426, $C8A, $424, $42A, $24E, $EEE
	dc.w 0,	0, $224, $666, $AAA, $200, $200, $200, $26C, $A66, $424, $C8A, $422, $428, $24C, $EEE
	dc.w 0,	0, $222, $666, $AAC, $200, $200, $200, $24A, $A66, $422, $88A, $420, $426, $22A, $EEE
	dc.w 0,	0, $222, $666, $AAA, $200, $200, $200, $448, $844, $602, $A68, $400, $624, $428, $EEE
	dc.w 0,	0, $222, $666, $A88, $200, $200, $200, $626, $844, $600, $A68, $400, $624, $426, $EEE
	dc.w 0,	0, $422, $866, $A88, $200, $200, $200, $426, $844, $400, $A68, $400, $422, $226, $ECC
	dc.w 0,	0, $422, $866, $A88, $200, $200, $200, $426, $622, $200, $846, $200, $402, $226, $ECC
	dc.w 0,	0, $422, $844, $866, $200, $200, $200, $426, $420, $200, $644, $200, $402, $424, $CAA
	dc.w 0,	0, $422, $844, $866, $200, $200, $200, $424, $400, $200, $624, $200, $400, $422, $CAA
	dc.w 0,	0, $422, $844, $866, $200, $200, $200, $800, $400, $200, $620, $200, $400, $600, $CAA
	dc.w 0,	0, $422, $844, $866, $200, $200, $200, $800, $400, $200, $620, $200, $200, $400, $CAA
	dc.w 0,	0, $422, $844, $866, $200, $200, $200, $400, $400, $200, $620, $200, $200, $200, $CAA
	dc.w 0,	0, $422, $844, $866, $200, $200, $200, $200, $400, $200, $620, $200, $200, $200, $CAA
	dc.w 0,	0, $200, $200, $200, $200, $200, $200, $200, $200, $200, $200, $200, $200, $200, $CAA
	dc.w 0,	0, $200, $200, $200, $400, $200, $222, $200, $200, $200, $200, $200, $200, $200, $CAA
	dc.w 0,	0, $200, $200, $420, $400, $200, $444, $200, $200, $200, $200, $200, $200, $200, $CAA
	dc.w 0,	0, $200, $200, $420, $600, $200, $666, $200, $200, $200, $200, $200, $200, $200, $CAA
	dc.w 0,	0, $200, $200, $640, $602, $200, $888, $200, $200, $200, $200, $200, $200, $200, $CAA
	dc.w 0,	0, $200, $200, $642, $804, $200, $AAA, $200, $200, $200, $200, $200, $200, $200, $CAA
	dc.w 0,	0, $200, $200, $864, $A06, $220, $CCC, $200, $400, $200, $420, $200, $200, $200, $CAA
	dc.w 0,	0, $422, $400, $866, $A08, $222, $EEE, $200, $400, $640, $620, $864, $A86, $CA8, $EEA
	dc.w 0,	0, $842, $822, $862, $642, $640, $420, $A66, $422, $862, $A84, $200, $622, $844, $EEE
	dc.w 0,	0, $422, $844, $866, $A08, $222, $CCC, $200, $400, $200, $620, $200, $200, $200, $CAA
	
;	ALIGN	$10000, $FF
	
; --------------------------------------------------------------
	
	if PuyoCompression=0 ; Puyo Graphics use Compile Compression
	
ArtPuyo_LevelBG:
	incbin	"resource/artpuyo/Compression - Compile/Stage - Background.cmp"
	even
					
ArtPuyo_VSWinLose:
	incbin	"resource/artpuyo/Compression - Compile/VS Win Lose.cmp"
	even
					
ArtPuyo_LevelIntro:
	incbin	"resource/artpuyo/Compression - Compile/Stage - Cutscene.cmp"
	even
					
ArtPuyo_LessonMode:
	incbin	"resource/artpuyo/Compression - Compile/Lesson Mode.cmp"
	even
					
ArtPuyo_LevelFonts:
	incbin	"resource/artpuyo/Compression - Compile/Font - Stage.cmp"
	even
					
ArtPuyo_OldRoleCallFont:
	incbin	"resource/artpuyo/Compression - Compile/Font - Puyo Cast.cmp"
	even
					
ArtPuyo_DemoMode:
	incbin	"resource/artpuyo/Compression - Compile/Tutorial.cmp"
	even
					
ArtPuyo_OldFont:
	incbin	"resource/artpuyo/Compression - Compile/Font - Puyo Options.cmp"
	even
					
ArtPuyo_Harpy:
	incbin	"resource/artpuyo/Compression - Compile/Harpy.cmp"
	even
					
ArtPuyo_LevelSprites:
	incbin	"resource/artpuyo/Compression - Compile/Stage - Sprites.cmp"
	even
					
ArtPuyo_BestRecord:
	incbin	"resource/artpuyo/Compression - Compile/Best Records.cmp"
	even
					
ArtPuyo_BestRecordModes:
	incbin	"resource/artpuyo/Compression - Compile/Record Modes.cmp"
	even
					
ArtPuyo_OldGameOver:
	incbin	"resource/artpuyo/Compression - Compile/Puyo Game Over.cmp"
	even
					
; --------------------------------------------------------------

	else	; Puyo Graphics use Nemesis Compression

ArtPuyo_LevelBG:
	incbin	"resource/artpuyo/Compression - Nemesis/Stage - Background.nem"
	even
					
ArtPuyo_VSWinLose:
	incbin	"resource/artpuyo/Compression - Nemesis/VS Win Lose.nem"
	even
					
ArtPuyo_LevelIntro:
	incbin	"resource/artpuyo/Compression - Nemesis/Stage - Cutscene.nem"
	even
					
ArtPuyo_LessonMode:
	incbin	"resource/artpuyo/Compression - Nemesis/Lesson Mode.nem"
	even
					
ArtPuyo_LevelFonts:
	incbin	"resource/artpuyo/Compression - Nemesis/Font - Stage.nem"
	even
					
ArtPuyo_OldRoleCallFont:
	incbin	"resource/artpuyo/Compression - Nemesis/Font - Puyo Cast.nem"
	even
					
ArtPuyo_DemoMode:
	incbin	"resource/artpuyo/Compression - Nemesis/Tutorial.nem"
	even
					
ArtPuyo_OldFont:
	incbin	"resource/artpuyo/Compression - Nemesis/Font - Puyo Options.nem"
	even
					
ArtPuyo_Harpy:
	incbin	"resource/artpuyo/Compression - Nemesis/Harpy.nem"
	even
					
ArtPuyo_LevelSprites:
	incbin	"resource/artpuyo/Compression - Nemesis/Stage - Sprites.nem"
	even
					
ArtPuyo_BestRecord:
	incbin	"resource/artpuyo/Compression - Nemesis/Best Records.nem"
	even
					
ArtPuyo_BestRecordModes:
	incbin	"resource/artpuyo/Compression - Nemesis/Record Modes.nem"
	even
					
ArtPuyo_OldGameOver:
	incbin	"resource/artpuyo/Compression - Nemesis/Puyo Game Over.nem"
	even
	
	endc	
	
; --------------------------------------------------------------

;	ALIGN	$10000, $FF

; --------------------------------------------------------------	
	
ArtNem_TitleLogo:
	incbin	"resource/artnem/Title/Title Logo.nem"
	even

MapEni_TitleLogo:
	incbin	"resource/mapeni/Title/Logo.eni"
	even
	
MapEni_TitleRobotnik:
	incbin	"resource/mapeni/Title/Robotnik.eni"
	even
	
ArtNem_EndingSprites:
	incbin	"resource/artnem/Ending/Ending Sprites.nem"
	even
	
ArtNem_SegaLogo:
	incbin	"resource/artnem/Title/Sega Logo.nem"
	even
	
ArtNem_DifficultyFaces:
	incbin	"resource/artnem/VS/Difficulty Faces 1.nem"
	even
	
ArtNem_DifficultyFaces2:
	incbin	"resource/artnem/VS/Difficulty Faces 2.nem"
	even
	
ArtUnc_Robotnik_21:
	incbin	"resource/artunc/Robotnik/Robotnik 21.unc"
	even
	
ArtUnc_Robotnik_22:
	incbin	"resource/artunc/Robotnik/Robotnik 22.unc"
	even
	
ArtUnc_Robotnik_23:
	incbin	"resource/artunc/Robotnik/Robotnik 23.unc"
	even
	
ArtNem_HasBeanShadow:
	incbin	"resource/artnem/Ending/Has Bean's Shadow.nem"
	even

; --------------------------------------------------------------

ArtNem_GrassBoard:
	incbin	"resource/artnem/Boards/Grass.nem"
	even

ArtNem_StoneBoard:
	incbin	"resource/artnem/Boards/Stone.nem"
	even

; --------------------------------------------------------------

	ALIGN	$B0000, $FF

; --------------------------------------------------------------
; Sound data
; --------------------------------------------------------------

	include  "sound/sound.asm"

; ==============================================================

; --------------------------------------------------------------
; Splash screen
; --------------------------------------------------------------

	if SplashScreen=1

SHC:	
	include "src/subroutines/splash screen/sonic hacking contest.asm"
	endc

;	ALIGN	$100000, $FF ; Set ROM Size to 1MB

; ==============================================================
; --------------------------------------------------------------
; Debugging modules
; --------------------------------------------------------------

	include	"include/errorhandler/ErrorHandler.asm"

; --------------------------------------------------------------
; WARNING!
;	DO NOT put any data from now on! DO NOT use ROM padding!
;	Symbol data should be appended here after ROM is compiled
;	by ConvSym utility, otherwise debugger modules won't be able
;	to resolve symbol names.
; --------------------------------------------------------------

EndOfRom:
	END

; ==============================================================