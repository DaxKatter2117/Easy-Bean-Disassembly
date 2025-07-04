; --------------------------------------------------------------
; ROM settings
; --------------------------------------------------------------
				
EnableSRAM:			equ 0	; Change to 1 to enable SRAM
BackupSRAM:			equ 1
AddressSRAM:		equ 3	; 0 = odd+even
							; 2 = even only
							; 3 = odd only
							
ConsoleHeader:		equ 0	; 0 = Header says "SEGA MEGA DRIVE"
							; 1 = Header says "SEGA GENESIS"

PuyoCompression:	equ 0   ; 0 = Puyo Art uses Compile Compression
							; 1 = Puyo Art uses Nemesis Compression
							
FastNemesis:		equ 0   ; 0 = Use the orginal Nemesis Decompression routine
							; 1 = Use a faster Nemesis Decompression routine
							
DevLock:			equ 0   ; 0 = Only work on USA Console
							; 1 = Work on any Console

LoadChecksum:		Equ 0   ; 0 = Check the Checksum
							; 1 = Skip the Checksum
							
ChecksumScreen:		Equ 0   ; 0 = The Checksum Screen can be skipped
							; 1 = The Checksum Screen will always be displayed

DemoText:			equ 0   ; 0 = During Demo, text says "1P"
							; 1 = During Demo, text says "DEMO"

SplashScreen:		equ 0   ; 0 = Skip Sonic Hacking Contest Splash Screen
							; 1 = Use Sonic Hacking Contest Splash Screen