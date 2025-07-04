; --------------------------------------------------------------
; Region check
; --------------------------------------------------------------
					
	if DevLock=0			; If region lock is off, then skip code	
	BJMP	BC_Checksum		; Run checksum
	endc

	BRUN	CheckInitDone
	BJSET	BC_NoLock

BC_DoLock:
	BVDP	1
	BRUN	DisableSHMode
	BNEM	$A000, ArtNem_MainFont
	BPCMD	0
	BFRMEND
	BRUN	DeveloperLock
	BFRMEND
	BPAL	Pal_RedYellowPuyos, 0
	BDISABLE
	BFADE	Pal_Black, 0, 0
	BFADE	Pal_Black, 1, 0
	BFADE	Pal_Black, 2, 0
	BFADE	Pal_Black, 3, 0
	BFADEW
	BRUN	InitActors
	BJMP	BC_Checksum

BC_NoLock:
	BRUN	InitPalette_Safe
	BRUN	InitDebugFlags
	BJMP	BC_Sega