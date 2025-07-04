TutorialBox_Maps:	dc.w 7
	dc.l word_1CE14
	dc.l word_1CE1C
	dc.l word_1CE24
	dc.l word_1CE2C
	dc.l word_1CE38
	dc.l word_1CE44
	dc.l word_1CE4C

word_1CE14:	dc.w 0
	dc.b $17
	dc.b $19
	dc.w $C11E
	dc.w $8000

word_1CE1C:	dc.w 0
	dc.b $16
	dc.b $11
	dc.w $E120
	dc.w $63FD

word_1CE24:	dc.w 0
	dc.b $15
	dc.b $10
	dc.w $E1A2
	dc.w $63FC

word_1CE2C:	dc.w 4
	dc.b 1
	dc.b $11
	dc.w $E11E
	dc.l byte_21E14
	dc.w $4000

word_1CE38:	dc.w 4
	dc.b $17
	dc.b 8
	dc.w $E99E
	dc.l byte_21E26
	dc.w $4000

word_1CE44:	dc.w 0
	dc.b $E
	dc.b 6
	dc.w $EA20
	dc.w $63FD

word_1CE4C:	dc.w 0
	dc.b $D
	dc.b 5
	dc.w $EAA2
	dc.w $63FC

; ---------------------------------------------------------------------------

byte_21E14:
	incbin	"resource/mapunc/Boards/Tutorial/BOX1.bin"
	even

byte_21E26:
	incbin	"resource/mapunc/Boards/Tutorial/BOX2.bin"
	even

; ---------------------------------------------------------------------------
