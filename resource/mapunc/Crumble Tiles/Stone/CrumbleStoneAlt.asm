CrumbleStoneAlt:	; Different set of crumbling tile mappings that might be unreferenced? (16x2 format)
	; FRAME 1
	dc.b	$1B, $18, $15, $14, $15, $16, $17, $18
	dc.b	$19, $15, $16, $1A, $1B, $18, $15, $1A
	dc.b	$3B, $38, $35, $34, $35, $36, $37, $38
	dc.b	$39, $35, $36, $3A, $3B, $38, $35, $34
	; FRAME 2
	dc.b	$1B, $18, $15, $14, $15, $1C, $FF, $FF
	dc.b	$FF, $FF, $13, $1A, $1B, $18, $15, $1A
	dc.b	$3B, $38, $35, $34, $35, $3C, $13, $18
	dc.b	$19, $1C, $33, $3A, $3B, $38, $35, $34
	; FRAME 3
	dc.b	$1B, $18, $15, $1C, $FF, $FF, $FF, $FF
	dc.b	$FF, $FF, $FF, $FF, $13, $18, $15, $1A
	dc.b	$3B, $38, $35, $3C, $13, $1C, $FF, $FF
	dc.b	$FF, $FF, $13, $1C, $33, $38, $35, $34
	; FRAME 4
	dc.b	$1B, $1C, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00, $13, $1A
	dc.b	$3B, $3C, $13, $1C, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $13, $1C, $33, $34
	; FRAME 5
	dc.b	$1B, $1C, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00, $13, $1A
	dc.b	$3B, $3C, $00, $00, $00, $00, $00, $00
	dc.b	$00, $00, $00, $00, $00, $00, $33, $34
	; DUPE FRAME 1
	dc.b	$1B, $18, $15, $14, $15, $16, $17, $18
	dc.b	$19, $15, $16, $1A, $1B, $18, $15, $1A
	dc.b	$3B, $38, $35, $34, $35, $36, $37, $38
	dc.b	$39, $35, $36, $3A, $3B, $38, $35, $34
	; TOP TILES
	dc.b	$13, $14, $15, $16, $17, $16, $1C, $05, $02, $0A, $01, $02
	dc.b	$33, $34, $35, $36, $37, $36, $3C, $05, $01, $02, $06, $05
