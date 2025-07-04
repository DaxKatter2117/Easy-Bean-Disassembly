Versus_Maps:	dc.w 9
	dc.l Versus_Maps_FG1
	dc.l Versus_Maps_FG2
	dc.l Versus_Maps_FG3
	dc.l Versus_Maps_FG4
	dc.l Versus_Maps_BG1
	dc.l Versus_Maps_BG2
	dc.l Versus_Maps_BG3
	dc.l Versus_Maps_BG4
	dc.l word_1D0B8

Versus_Maps_FG1:	dc.w 4
	dc.b $20
	dc.b $E
	dc.w $C000
	dc.l Maps_Versus_FG1
	dc.w $C000

Versus_Maps_FG2:	dc.w 4
	dc.b 8
	dc.b $E
	dc.w $C040
	dc.l Maps_Versus_FG2
	dc.w $C000

Versus_Maps_FG3:	dc.w 4
	dc.b $20
	dc.b $E
	dc.w $C700
	dc.l Maps_Versus_FG3
	dc.w $C000

Versus_Maps_FG4:	dc.w 4
	dc.b 8
	dc.b $E
	dc.w $C740
	dc.l Maps_Versus_FG4
	dc.w $C000

Versus_Maps_BG1:	dc.w 4
	dc.b $20
	dc.b $E
	dc.w $E000
	dc.l Maps_Versus_BG1
	dc.w $4000

Versus_Maps_BG2:	dc.w 4
	dc.b 8
	dc.b $E
	dc.w $E040
	dc.l Maps_Versus_BG2
	dc.w $4000

Versus_Maps_BG3:	dc.w 4
	dc.b $20
	dc.b $E
	dc.w $E700
	dc.l Maps_Versus_BG3
	dc.w $4000

Versus_Maps_BG4:	dc.w 4
	dc.b 8
	dc.b $E
	dc.w $E740
	dc.l Maps_Versus_BG4
	dc.w $4000

; ---------------------------------------------------------------------------

Maps_Versus_FG1:
	incbin	"resource/mapunc/Boards/Versus/FG1.bin"
	even

Maps_Versus_FG2:
	incbin	"resource/mapunc/Boards/Versus/FG2.bin"
	even

Maps_Versus_FG3:
	incbin	"resource/mapunc/Boards/Versus/FG3.bin"
	even

Maps_Versus_FG4:
	incbin	"resource/mapunc/Boards/Versus/FG4.bin"
	even

Maps_Versus_BG1:
	incbin	"resource/mapunc/Boards/Versus/BG1.bin"
	even

Maps_Versus_BG2:
	incbin	"resource/mapunc/Boards/Versus/BG2.bin"
	even

Maps_Versus_BG3:
	incbin	"resource/mapunc/Boards/Versus/BG3.bin"
	even

Maps_Versus_BG4:
	incbin	"resource/mapunc/Boards/Versus/BG4.bin"
	even

; ---------------------------------------------------------------------------
