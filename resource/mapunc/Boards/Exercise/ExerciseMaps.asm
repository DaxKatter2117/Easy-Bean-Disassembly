Exercise_Maps:	dc.w $C
	dc.l Exercise_Maps_FG1
	dc.l Exercise_Maps_FG2
	dc.l Exercise_Maps_FG3
	dc.l Exercise_Maps_FG4
	dc.l Exercise_Maps_BG1
	dc.l Exercise_Maps_BG2
	dc.l Exercise_Maps_BG3
	dc.l Exercise_Maps_BG4
	dc.l Exercise_Maps_XFG1
	dc.l Exercise_Maps_XFG2
	dc.l word_1D0B8
	dc.l word_1D0C0

Exercise_Maps_FG1:	dc.w 4
	dc.b $20
	dc.b $E
	dc.w $C000
	dc.l Maps_Exercise_FG1
	dc.w $C000

Exercise_Maps_FG2:	dc.w 4
	dc.b 8
	dc.b $E
	dc.w $C040
	dc.l Maps_Exercise_FG2
	dc.w $C000

Exercise_Maps_FG3:	dc.w 4
	dc.b $20
	dc.b $E
	dc.w $C700
	dc.l Maps_Exercise_FG3
	dc.w $C000

Exercise_Maps_FG4:	dc.w 4
	dc.b 8
	dc.b $E
	dc.w $C740
	dc.l Maps_Exercise_FG4
	dc.w $C000

Exercise_Maps_BG1:	dc.w 4
	dc.b $20
	dc.b $E
	dc.w $E000
	dc.l Maps_Exercise_BG1
	dc.w $4000

Exercise_Maps_BG2:	dc.w 4
	dc.b 8
	dc.b $E
	dc.w $E040
	dc.l Maps_Exercise_BG2
	dc.w $4000

Exercise_Maps_BG3:	dc.w 4
	dc.b $20
	dc.b $E
	dc.w $E700
	dc.l Maps_Exercise_BG3
	dc.w $4000

Exercise_Maps_BG4:	dc.w 4
	dc.b 8
	dc.b $E
	dc.w $E740
	dc.l Maps_Exercise_BG4
	dc.w $4000

Exercise_Maps_XFG1:	dc.w 4
	dc.b $20
	dc.b 2
	dc.w $E000
	dc.l Maps_Exercise_FG1
	dc.w $4000

Exercise_Maps_XFG2:	dc.w 4
	dc.b 8
	dc.b 2
	dc.w $E040
	dc.l Maps_Exercise_FG2
	dc.w $4000

; ---------------------------------------------------------------------------

Maps_Exercise_FG1:
	incbin	"resource/mapunc/Boards/Exercise/FG1.bin"
	even

Maps_Exercise_FG2:
	incbin	"resource/mapunc/Boards/Exercise/FG2.bin"
	even

Maps_Exercise_FG3:
	incbin	"resource/mapunc/Boards/Exercise/FG3.bin"
	even

Maps_Exercise_FG4:
	incbin	"resource/mapunc/Boards/Exercise/FG4.bin"
	even

Maps_Exercise_BG1:
	incbin	"resource/mapunc/Boards/Exercise/BG1.bin"
	even

Maps_Exercise_BG2:
	incbin	"resource/mapunc/Boards/Exercise/BG2.bin"
	even

Maps_Exercise_BG3:
	incbin	"resource/mapunc/Boards/Exercise/BG3.bin"
	even

Maps_Exercise_BG4:
	incbin	"resource/mapunc/Boards/Exercise/BG4.bin"
	even

; ---------------------------------------------------------------------------
