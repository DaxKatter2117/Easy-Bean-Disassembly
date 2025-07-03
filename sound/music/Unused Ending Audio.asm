BGM_EndingUnused_Start:
	cType		ctMusic
	cFadeOut	$0000
	cTempo		$C5
	cChannel	BGM_EndingUnused_FM1
	cChannel	BGM_EndingUnused_FM2
	cChannel	BGM_EndingUnused_FM3
	cChannel	BGM_EndingUnused_FM4
	cChannel	BGM_EndingUnused_FM5
	cChannel	BGM_EndingUnused_DAC
	cChannel	BGM_EndingUnused_PSG1
	cChannel	BGM_EndingUnused_PSG2
	cChannel	BGM_EndingUnused_PSG3
	cChannel	BGM_EndingUnused_Noise

BGM_EndingUnused_FM1:
	cInsFM		patch4D
	cVolFM		$0F
	cRelease	$01
	cVibrato	$04, $0F
	cPan		cpCenter
	cNoteShift	$00, $00, $05
	cSustain
	cNote		cnF2, $32
	cSlide		$01
	cNote		cnF1, $60
	cNote		cnF1, $30
	cRelease	$01
	cNote		cnF1, $60
	cSlideStop
	cStop

BGM_EndingUnused_FM2:
	cInsFM		patch4E
	cVolFM		$0F
	cVibrato	$02, $02
	cPan		cpCenter
	cNoteShift	$00, $00, $00
	cSustain
	cNote		cnF1, $22
	cSlide		$01
	cNote		cnF0, $70
	cNote		cnF0, $30
	cRelease	$01
	cNote		cnF0, $60
	cSlideStop
	cStop

BGM_EndingUnused_FM3:
	cNote		cnRst, $03
	cInsFM		patch4E
	cVolFM		$0F
	cVibrato	$02, $02
	cPan		cpCenter
	cNoteShift	$00, $00, $00
	cSustain
	cNote		cnF1, $22
	cSlide		$01
	cNote		cnF0, $70
	cNote		cnF0, $30
	cRelease	$01
	cNote		cnF0, $60
	cSlideStop
	cStop

BGM_EndingUnused_FM4:
	cNote		cnRst, $07
	cInsFM		patch4E
	cVolFM		$0F
	cVibrato	$02, $02
	cPan		cpCenter
	cNoteShift	$00, $00, $00
	cSustain
	cNote		cnF1, $22
	cSlide		$01
	cNote		cnF0, $70
	cNote		cnF0, $30
	cRelease	$01
	cNote		cnF0, $60
	cSlideStop
	cStop

BGM_EndingUnused_FM5:
	cNote		cnRst, $0A
	cInsFM		patch4E
	cVolFM		$0F
	cVibrato	$02, $02
	cPan		cpCenter
	cNoteShift	$00, $00, $00
	cSustain
	cNote		cnF1, $22
	cSlide		$01
	cNote		cnF0, $70
	cNote		cnF0, $30
	cRelease	$01
	cNote		cnF0, $60
	cSlideStop
	cStop

BGM_EndingUnused_DAC:
	cRelease	$01
	cNote		cnRst, $0F
	cNote		cnE1, $1E
	cNote		cnRst, $32
	cNote		cnCs1, $32
	cStop

BGM_EndingUnused_PSG1:

BGM_EndingUnused_PSG2:

BGM_EndingUnused_PSG3:

BGM_EndingUnused_Noise:
	cStop
