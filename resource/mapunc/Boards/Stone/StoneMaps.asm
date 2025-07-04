Stone_Maps:	dc.w 6
	dc.l Stone_Maps_FG1
	dc.l Stone_Maps_FG2
	dc.l Stone_Maps_BG1
	dc.l Stone_Maps_BG2
	dc.l word_1D0B8
	dc.l word_1D0C0

Stone_Maps_FG1:	dc.w 4
	dc.b $20
	dc.b $1C
	dc.w $C000
	dc.l Maps_Stone_FG1 
	dc.w $C000

Stone_Maps_FG2:	dc.w 4
	dc.b 8
	dc.b $1C
	dc.w $C040
	dc.l Maps_Stone_FG2
	dc.w $C000

Stone_Maps_BG1:	dc.w 4
	dc.b $20
	dc.b $1C
	dc.w $E000
	dc.l Maps_Stone_BG1
	dc.w $4000

Stone_Maps_BG2:	dc.w 4
	dc.b 8
	dc.b $1C
	dc.w $E040
	dc.l Maps_Stone_BG2
	dc.w $4000

; ---------------------------------------------------------------------------

Maps_Stone_FG1:
	incbin	"resource/mapunc/Boards/Stone/FG1.bin"
	even

Maps_Stone_FG2:
	incbin	"resource/mapunc/Boards/Stone/FG2.bin"
	even

Maps_Stone_BG1:
	incbin	"resource/mapunc/Boards/Stone/BG1.bin"
	even

Maps_Stone_BG2:
	incbin	"resource/mapunc/Boards/Stone/BG2.bin"
	even

; ---------------------------------------------------------------------------
