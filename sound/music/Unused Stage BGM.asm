BGM_StageUnused_Start:
	cType		ctMusic
	cFadeOut	$0000
	cTempo		$C3
	cChannel	BGM_StageUnused_FM1
	cChannel	BGM_StageUnused_FM2
	cChannel	BGM_StageUnused_FM3
	cChannel	BGM_StageUnused_FM4
	cChannel	BGM_StageUnused_FM5
	cChannel	BGM_StageUnused_DAC
	cChannel	BGM_StageUnused_PSG1
	cChannel	BGM_StageUnused_PSG2
	cChannel	BGM_StageUnused_PSG3
	cChannel	BGM_StageUnused_Noise

BGM_StageUnused_FM1:
	cLoopStart
		cRelease	$01
		cVibrato	$02, $0A
		cPan		cpCenter
		cNoteShift	$00, $00, $00
		cNote		cnRst, $50
		cNote		cnRst
		cNote		cnRst
		cNote		cnRst
		cLoopCnt	$02
			cInsFM		patch0D
			cVolFM		$0C
			cNote		cnC2, $0A
			cNote		cnDs2
			cNote		cnC2, $05
			cNote		cnDs2, $0A
			cNote		cnC2, $05
			cNote		cnDs2, $0A
			cNote		cnC2, $05
			cNote		cnF2, $0F
			cNote		cnDs2, $0A
			cNote		cnC2
			cNote		cnDs2
			cNote		cnC2, $05
			cNote		cnDs2, $0A
			cNote		cnC2, $05
			cNote		cnDs2, $0A
			cNote		cnC2, $05
			cNote		cnFs2, $0F
			cNote		cnF2, $0A
		cLoopCntEnd
		cNote		cnC2, $0A
		cNote		cnDs2
		cNote		cnC2, $05
		cNote		cnDs2, $0A
		cNote		cnC2, $05
		cNote		cnDs2, $0A
		cNote		cnC2, $05
		cNote		cnF2, $0F
		cNote		cnDs2, $0A
		cNote		cnRst, $50
		cLoopCnt	$01
			cNote		cnF2, $0A
			cNote		cnGs2
			cNote		cnF2, $05
			cNote		cnGs2, $0A
			cNote		cnF2, $05
			cNote		cnGs2, $0A
			cNote		cnF2, $05
			cNote		cnAs2, $0F
			cNote		cnGs2, $0A
			cNote		cnF2
			cNote		cnGs2
			cNote		cnF2, $05
			cNote		cnGs2, $0A
			cNote		cnF2, $05
			cNote		cnGs2, $0A
			cNote		cnF2, $05
			cNote		cnB2, $0F
			cNote		cnAs2, $0A
		cLoopCntEnd
		cNote		cnC2, $0A
		cNote		cnDs2
		cNote		cnC2, $05
		cNote		cnDs2, $0A
		cNote		cnC2, $05
		cNote		cnDs2, $0A
		cNote		cnC2, $05
		cNote		cnF2, $0F
		cNote		cnDs2, $0A
		cNote		cnC2
		cNote		cnDs2
		cNote		cnC2, $05
		cNote		cnDs2, $0A
		cNote		cnC2, $05
		cNote		cnDs2, $0A
		cNote		cnC2, $05
		cNote		cnFs2, $0F
		cNote		cnF2, $0A
		cNote		cnC2
		cNote		cnDs2
		cNote		cnC2, $05
		cNote		cnDs2, $0A
		cNote		cnC2, $05
		cNote		cnDs2, $0A
		cNote		cnC2, $05
		cNote		cnF2, $0F
		cNote		cnDs2, $0A
		cNote		cnRst, $50
		cLoopCnt	$02
			cNote		cnC2, $0A
			cNote		cnDs2
			cNote		cnC2, $05
			cNote		cnDs2, $0A
			cNote		cnC2, $05
			cNote		cnDs2, $0A
			cNote		cnC2, $05
			cNote		cnF2, $0F
			cNote		cnDs2, $0A
			cNote		cnC2
			cNote		cnDs2
			cNote		cnC2, $05
			cNote		cnDs2, $0A
			cNote		cnC2, $05
			cNote		cnDs2, $0A
			cNote		cnC2, $05
			cNote		cnFs2, $0F
			cNote		cnF2, $0A
		cLoopCntEnd
		cNote		cnC2, $0A
		cNote		cnDs2
		cNote		cnC2, $05
		cNote		cnDs2, $0A
		cNote		cnC2, $05
		cNote		cnDs2, $0A
		cNote		cnC2, $05
		cNote		cnF2, $0F
		cNote		cnDs2, $0A
		cNote		cnRst, $50
	cLoopEnd
	cStop

BGM_StageUnused_FM2:
	cLoopStart
		cRelease	$01
		cVibrato	$02, $0A
		cPan		cpCenter
		cNoteShift	$00, $00, $00
		cLoopCnt	$0B
			cNote		cnRst, $50
		cLoopCntEnd
		cInsFM		patch01
		cVolFM		$0A
		cNote		cnC4, $78
		cNote		cnFs4, $0C
		cNote		cnRst, $03
		cNote		cnF4, $0C
		cNote		cnRst, $03
		cNote		cnDs4, $08
		cNote		cnRst, $02
		cNote		cnC4, $50
		cNote		cnRst
		cNote		cnC4, $78
		cNote		cnFs4, $0C
		cNote		cnRst, $03
		cNote		cnF4, $0C
		cNote		cnRst, $03
		cNote		cnDs4, $08
		cNote		cnRst, $02
		cNote		cnC4, $50
		cNote		cnRst
		cNote		cnG4
		cNote		cnD5
		cNote		cnG5
		cNote		cnGs5
		cNote		cnRst
		cNote		cnRst
		cNote		cnRst
		cNote		cnRst
	cLoopEnd
	cStop

BGM_StageUnused_FM3:
	cLoopStart
		cRelease	$01
		cVibrato	$02, $0A
		cLoopCnt	$05
			cNote		cnRst, $50
		cLoopCntEnd
		cInsFM		patch1F
		cVolFM		$0B
		cRelease	$05
		cNote		cnGs4, $05
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnRst, $50
		cNote		cnRst
		cNote		cnRst
		cNote		cnRst
		cNote		cnRst
		cNote		cnRst
		cNote		cnGs4, $05
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnRst, $50
		cNote		cnRst
		cNote		cnRst
		cNote		cnRst
		cNote		cnRst
		cNote		cnRst
		cNote		cnGs4, $05
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnRst, $50
		cNote		cnD4, $05
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnD4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
		cNote		cnGs4
	cLoopEnd
	cStop

BGM_StageUnused_FM4:
	cNote		cnRst, $07
	cLoopStart
		cRelease	$01
		cVibrato	$02, $0A
		cPan		cpCenter
		cNoteShift	$00, $02, $00
		cLoopCnt	$0B
			cNote		cnRst, $50
		cLoopCntEnd
		cInsFM		patch01
		cVolFM		$07
		cNote		cnC4, $78
		cNote		cnFs4, $0C
		cNote		cnRst, $03
		cNote		cnF4, $0C
		cNote		cnRst, $03
		cNote		cnDs4, $08
		cNote		cnRst, $02
		cNote		cnC4, $50
		cNote		cnRst
		cNote		cnC4, $78
		cNote		cnFs4, $0C
		cNote		cnRst, $03
		cNote		cnF4, $0C
		cNote		cnRst, $03
		cNote		cnDs4, $08
		cNote		cnRst, $02
		cNote		cnC4, $50
		cNote		cnRst
		cNote		cnG4
		cNote		cnD5
		cNote		cnG5
		cNote		cnGs5
		cNote		cnRst
		cNote		cnRst
		cNote		cnRst
		cNote		cnRst
	cLoopEnd
	cStop

BGM_StageUnused_FM5:
	cNote		cnRst, $0D
	cLoopStart
		cRelease	$01
		cVibrato	$02, $0A
		cPan		cpCenter
		cNoteShift	$00, $04, $00
		cLoopCnt	$0B
			cNote		cnRst, $50
		cLoopCntEnd
		cInsFM		patch01
		cVolFM		$06
		cNote		cnC4, $78
		cNote		cnFs4, $0C
		cNote		cnRst, $03
		cNote		cnF4, $0C
		cNote		cnRst, $03
		cNote		cnDs4, $08
		cNote		cnRst, $02
		cNote		cnC4, $50
		cNote		cnRst
		cNote		cnC4, $78
		cNote		cnFs4, $0C
		cNote		cnRst, $03
		cNote		cnF4, $0C
		cNote		cnRst, $03
		cNote		cnDs4, $08
		cNote		cnRst, $02
		cNote		cnC4, $50
		cNote		cnRst
		cNote		cnG4
		cNote		cnD5
		cNote		cnG5
		cNote		cnGs5
		cNote		cnRst
		cNote		cnRst
		cNote		cnRst
		cNote		cnRst
	cLoopEnd
	cStop

BGM_StageUnused_DAC:
	cLoopStart
		cNote		cnC0, $0A
		cNote		cnC0
		cNote		cnDs0, $0F
		cNote		cnCs0, $05
		cNote		cnC0, $0A
		cNote		cnC0
		cNote		cnE0, $14
		cNote		cnC0, $0A
		cNote		cnC0
		cNote		cnDs0, $0F
		cNote		cnCs0, $05
		cNote		cnC0, $0A
		cNote		cnC0
		cNote		cnE0, $14
		cNote		cnC0, $0A
		cNote		cnC0
		cNote		cnDs0, $0F
		cNote		cnCs0, $05
		cNote		cnC0, $0A
		cNote		cnC0
		cNote		cnE0, $14
		cNote		cnD0, $05
		cNote		cnD0
		cNote		cnD0
		cNote		cnD0
		cNote		cnD0, $0A
		cNote		cnDs0, $05
		cNote		cnDs0
		cNote		cnDs0, $0A
		cNote		cnE0, $05
		cNote		cnE0
		cNote		cnE0
		cNote		cnE0
		cNote		cnE0, $0A
		cLoopCnt	$02
			cNote		cnC0, $0A
			cNote		cnC0
			cNote		cnDs0, $0F
			cNote		cnCs0, $05
			cNote		cnC0, $0A
			cNote		cnC0
			cNote		cnE0, $14
			cNote		cnC0, $0A
			cNote		cnC0
			cNote		cnDs0, $0F
			cNote		cnCs0, $05
			cNote		cnC0, $0A
			cNote		cnC0
			cNote		cnE0, $14
		cLoopCntEnd
		cNote		cnC0, $0A
		cNote		cnC0
		cNote		cnDs0, $0F
		cNote		cnCs0, $05
		cNote		cnC0, $0A
		cNote		cnC0
		cNote		cnE0, $14
		cNote		cnD0, $05
		cNote		cnD0
		cNote		cnD0
		cNote		cnD0
		cNote		cnD0, $0A
		cNote		cnDs0, $05
		cNote		cnDs0
		cNote		cnDs0, $0A
		cNote		cnE0, $05
		cNote		cnE0
		cNote		cnE0
		cNote		cnE0
		cNote		cnE0, $0A
		cLoopCnt	$02
			cNote		cnC0, $0A
			cNote		cnC0
			cNote		cnDs0, $0F
			cNote		cnCs0, $05
			cNote		cnC0, $0A
			cNote		cnC0
			cNote		cnE0, $14
			cNote		cnC0, $0A
			cNote		cnC0
			cNote		cnDs0, $0F
			cNote		cnCs0, $05
			cNote		cnC0, $0A
			cNote		cnC0
			cNote		cnE0, $14
		cLoopCntEnd
		cNote		cnC0, $0A
		cNote		cnC0
		cNote		cnDs0, $0F
		cNote		cnCs0, $05
		cNote		cnC0, $0A
		cNote		cnC0
		cNote		cnE0, $14
		cNote		cnD0, $05
		cNote		cnD0
		cNote		cnD0
		cNote		cnD0
		cNote		cnD0, $0A
		cNote		cnDs0, $05
		cNote		cnDs0
		cNote		cnDs0, $0A
		cNote		cnE0, $05
		cNote		cnE0
		cNote		cnE0
		cNote		cnE0
		cNote		cnE0, $0A
		cLoopCnt	$02
			cNote		cnC0, $0A
			cNote		cnC0
			cNote		cnDs0, $0F
			cNote		cnCs0, $05
			cNote		cnC0, $0A
			cNote		cnC0
			cNote		cnE0, $14
			cNote		cnC0, $0A
			cNote		cnC0
			cNote		cnDs0, $0F
			cNote		cnCs0, $05
			cNote		cnC0, $0A
			cNote		cnC0
			cNote		cnE0, $14
		cLoopCntEnd
		cNote		cnC0, $0A
		cNote		cnC0
		cNote		cnDs0, $0F
		cNote		cnE0, $05
		cNote		cnC0, $0A
		cNote		cnC0
		cNote		cnE0, $14
		cNote		cnD0, $05
		cNote		cnD0
		cNote		cnD0
		cNote		cnD0
		cNote		cnD0, $0A
		cNote		cnDs0, $05
		cNote		cnDs0
		cNote		cnDs0, $0A
		cNote		cnE0, $05
		cNote		cnE0
		cNote		cnE0
		cNote		cnE0
		cNote		cnE0, $0A
	cLoopEnd
	cStop

BGM_StageUnused_PSG1:
	cStop

BGM_StageUnused_PSG2:
	cStop

BGM_StageUnused_PSG3:
	cStop

BGM_StageUnused_Noise:
	cLoopStart
		cInsVolPSG	$0F, $0E
		cNote		cnG0, $05
		cInsVolPSG	$0F, $0B
		cNote		cnG0, $05
		cNote		cnG0
		cNote		cnG0
	cLoopEnd
	cStop
