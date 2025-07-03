BGM_IntroB_Start:
	cType		ctMusic
	cFadeOut	$0000
	cTempo		$B9
	cChannel	BGM_IntroB_FM1
	cChannel	BGM_IntroB_FM2
	cChannel	BGM_IntroB_FM3
	cChannel	BGM_IntroB_FM4
	cChannel	BGM_IntroB_FM5
	cChannel	BGM_IntroB_DAC
	cChannel	BGM_IntroB_PSG1
	cChannel	BGM_IntroB_PSG2
	cChannel	BGM_IntroB_PSG3
	cChannel	BGM_IntroB_Noise

BGM_IntroB_FM1:
	cLoopStart
		cInsFM		patch0E
		cVolFM		$0C
		cRelease	$01
		cVibrato	$02, $0A
		cPan		cpCenter
		cNote		cnA1, $04
		cNote		cnRst, $08
		cNote		cnA1, $04
		cNote		cnRst, $08
		cNote		cnA2, $04
		cNote		cnRst, $10
		cNote		cnA2, $04
		cNote		cnA1
		cNote		cnRst
		cNote		cnA2
		cNote		cnA1
		cNote		cnRst, $08
		cNote		cnA2, $04
		cNote		cnRst, $08
		cNote		cnRst
		cNote		cnA1, $04
	cLoopEnd
	cStop

BGM_IntroB_FM2:
	cInsFM		patch0E
	cVolFM		$0C
	cRelease	$01
	cVibrato	$02, $0A
	cPan		cpRight
	cNote		cnRst, $0C
	cLoopStart
		cNote		cnA1, $04
		cNote		cnRst, $08
		cNote		cnA1, $04
		cNote		cnRst, $08
		cNote		cnA2, $04
		cNote		cnRst, $10
		cNote		cnA2, $04
		cNote		cnA1
		cNote		cnRst
		cNote		cnA2
		cNote		cnA1
		cNote		cnRst, $08
		cNote		cnA2, $04
		cNote		cnRst, $08
		cNote		cnRst
		cNote		cnA1, $04
	cLoopEnd
	cStop

BGM_IntroB_FM3:
	cInsFM		patch0E
	cVolFM		$0C
	cRelease	$01
	cVibrato	$02, $0A
	cPan		cpLeft
	cNote		cnRst, $48
	cLoopStart
		cNote		cnA1, $04
		cNote		cnRst, $08
		cNote		cnA1, $04
		cNote		cnRst, $08
		cNote		cnA2, $04
		cNote		cnRst, $10
		cNote		cnA2, $04
		cNote		cnA1
		cNote		cnRst
		cNote		cnA2
		cNote		cnA1
		cNote		cnRst, $08
		cNote		cnA2, $04
		cNote		cnRst, $08
		cNote		cnRst
		cNote		cnA1, $04
	cLoopEnd
	cStop

BGM_IntroB_FM4:
	cStop

BGM_IntroB_FM5:
	cStop

BGM_IntroB_DAC:
	cLoopStart
		cNote		cnC0, $18
		cNote		cnCs0, $14
		cNote		cnC0, $0C
		cNote		cnC0, $10
		cNote		cnCs0, $14
		cNote		cnC0, $04
		cNote		cnC0, $18
		cNote		cnCs0, $14
		cNote		cnC0, $0C
		cNote		cnCs0, $04
		cNote		cnC0, $0C
		cNote		cnCs0, $14
		cNote		cnCs0, $04
	cLoopEnd
	cStop

BGM_IntroB_PSG1:
	cStop

BGM_IntroB_PSG2:
	cStop

BGM_IntroB_PSG3:
	cStop

BGM_IntroB_Noise:
	cLoopStart
		cInsVolPSG	$0F, $0D
		cRelease	$01
		cNote		cnG0, $0C
		cNote		cnG0, $08
		cNote		cnG0, $04
	cLoopEnd
	cStop
