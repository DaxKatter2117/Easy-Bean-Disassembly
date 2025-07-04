CreditEnd_Hardest:
	dc.w $10
	dc.l StrCredit_Thanks
	dc.w $30
	dc.l StrCredit_ForPlaying
	dc.w $C
	dc.l StrCredit_SegaCopyright
	dc.w $50
	dc.l StrCredit_Compile
	dc.w 0

CreditEnd_Hard:
	dc.w $10
	dc.l StrCredit_LetsTry
	dc.w $28
	dc.l StrCredit_Hardest
	dc.w $C
	dc.l StrCredit_SegaCopyright
	dc.w $50
	dc.l StrCredit_Compile
	dc.w 0

CreditEnd_Normal:
	dc.w $10
	dc.l StrCredit_LetsTry
	dc.w $28
	dc.l StrCredit_Hard
	dc.w $C
	dc.l StrCredit_SegaCopyright
	dc.w $50
	dc.l StrCredit_Compile
	dc.w 0

CreditEnd_Easy:
	dc.w $10
	dc.l StrCredit_LetsTry
	dc.w $28
	dc.l StrCredit_Normal
	dc.w $C
	dc.l StrCredit_SegaCopyright
	dc.w $50
	dc.l StrCredit_Compile
	dc.w 0

StrCredit_Thanks:
	dc.w $D8
	dc.w 9
	dc.b "Thank you"
	even

StrCredit_ForPlaying:
	dc.w $108
	dc.w $C
	dc.b "for playing."
	even

StrCredit_Compile:
	dc.w $E8
	dc.w $E
	dc.b "@ 1993 COMPILE"
	even

StrCredit_SegaCopyright:
	dc.w $F4
	dc.w $B
	dc.b "@ 1993 |}~"
	even

StrCredit_LetsTry:
	dc.w $D0
	dc.w 9
	dc.b "Let's try"
	even

StrCredit_Hardest:
	dc.w $100
	dc.w $E
	dc.b "hardest level."
	even

StrCredit_Hard:
	dc.w $118
	dc.w $B
	dc.b "hard level."
	even

StrCredit_Normal:
	dc.w $108
	dc.w $D
	dc.b "normal level."
	even