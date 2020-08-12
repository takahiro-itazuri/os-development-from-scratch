;/****************************************************
; File: stage1.asm
; Description: Bootloader (Stage 1)
;****************************************************/

[BITS 16]

		ORG	0x7c00

;=====================================================
; BIOS parameter blocks (FAT12)
;=====================================================

		JMP	Stage1		; Jump instruction
BS_jmpBoot2	DB	0x90
BS_OEMName	DB	"ZuriOS  "	; OEM Name

BPB_BytsPerSec	DW	0x0200		; The number of bytes per sector
BPB_SecPerClus	DB	0x01		; The number of sectors per cluster
BPB_RsvdSecCnt	DW	0x0001		; The number of reserved sectors
BPB_NumFATs	DB	0x02		; The number of FATs
BPB_RootEntCnt	DW	0x00E0		; The number of file name entries
BPB_TotSec16	DW	0x0B40		; The total number of sectors		(0x0B40 = 2880)
BPB_Meida	DB	0xF0		; The media descriptor			(0xF0 = Removable Media)
BPB_FATSz16	DW	0x0009		; The number of sectors per FAT		(FAT12/FAT16 only)
BPB_SecPerTrk	DW	0x0012		; The number of sectors per track	(0x12 = 18)
BPB_NumHeads	DW	0x0002		; The number of heads
BPB_HiddSec	DD	0x00000000	; The number of hidden sectors
BPB_TotSec32	DD	0x00000000	; The total number of sectors		(use if larger than 65536)
BS_DrvNum	DB	0x00		; Drive number				(0x00 for a floppy disk)
BS_Reserved1	DB	0x00		; Reserved
BS_BootSig	DB	0x29		; Signature				(either 0x28 or 0x29)
BS_VolID	DD	0x19941226	; Volume seriral number
BS_VolLab	DB	"ZuriFD     "	; Volume label
BS_FilSysType	DB	"FAT12   "	; Filesystem ID				(either FAT12 or FAT16)


;=====================================================
; Bootstrap Code
;=====================================================
Stage1:
		CLI

; Initialization
		XOR	AX, AX
		XOR	BX, BX
		XOR	CX, CX
		XOR	DX, DX

		MOV	DS, AX
		MOV	ES, AX
		MOV	FS, AX
		MOV	GS, AX

		MOV	SS, AX
		MOV	SP, 0x7c00

; Display Message
		MOV	SI, InitMsg
		CALL	DisplayMessage

; Read FAT
		CALL	ResetFD
		CALL	LoadFat
		CALL	LoadRoot

		HLT


InitMsg		DB	"Hello ZuriOS!", 0x0a, 0x0d, 0x00



;=====================================================
; Subroutines
;=====================================================

;/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
; DisplayMessage
; Input:
; 	SI: Address of message
;/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
DisplayMessage:
		PUSH	AX
		PUSH	BX
StartDispMsg:
		LODSB				; Load [DS:SI] into AL and then increment SI.
		OR	AL, AL
		JZ	EndDispMsg
		MOV	AH, 0x0E
		MOV	BH, 0x00
		MOV	BL, 0x15
		INT	0x10
		JMP	StartDispMsg
EndDispMsg:
		POP	BX
		POP	AX
		RET



;/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
; ResetFD
;/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
ResetFD:
		MOV	AH, 0x00		; Initialization mode
		MOV	DL, BYTE [BS_DrvNum]	; Drive number
		INT	0x13			; Interrupt
		JC	ResetFDFail
		RET
ResetFDFail:
		MOV	SI, ResetFDFailMsg
		CALL	DisplayMessage
		HLT

ResetFDFailMsg:	DB	"Reset FD Failed...", 0x00


;/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
; ReadSector
; Input:
; 	AX: Logical Sector Number To Read
; 	BX: Memory Address To Load
;/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
ReadSector:
		MOV	DI, 0x0005		; 5 retries
ReadSecLoop:
		PUSH	AX
		PUSH	BX
		PUSH	CX
		CALL	LBA2CHS
		MOV	AH, 0x02		; Read mode
		MOV	AL, 0x01		; Read one sector
		MOV	CH, BYTE [CylinderNo]	; Cylinder number
		MOV	CL, BYTE [SectorNo]	; Sector number
		MOV	DH, BYTE [HeadNo]	; Head number
		MOV	DL, BYTE [BS_DrvNum]	; Drive number
		INT	0x13			; Interrupt
		JNC	ReadSecSuccess
		
		XOR	AX, AX
		INT	0x13
		POP	CX
		POP	BX
		POP	AX
		DEC	DI
		JNZ	ReadSecLoop
		
ReadSecFail:
		MOV	SI, ReadSecFailMsg
		CALL	DisplayMessage
		HLT

ReadSecSuccess:
		POP	CX
		POP	BX
		POP	AX
		RET

ReadSecFailMsg	DB	"ReadSector Failed...", 0x00


;/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
; LBA2CHS
; Input:
; 	AX: Secter number (LBA)
; Output:
; 	SectorNo: Sector number (CHS)
; 	HeadNo: Head number (CHS)
; 	CylinderNo: Cylinder number (CHS)
;/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
LBA2CHS:
		; Secter number (CHS)
		XOR	DX, DX
		DIV	WORD [BPB_SecPerTrk]	; AX / BPB_SecPerTrk -> AX: Quotient, DX: Remainder
		INC	DL
		MOV	BYTE [SectorNo], DL

		; Head number (CHS), Cylinder number (CHS)
		XOR	DX, DX
		DIV	WORD [BPB_NumHeads]	; AX / BPB_NumHeads -> AX: Quotient, DX: Remainder
		MOV	BYTE [HeadNo], DL
		MOV	BYTE [CylinderNo], AL

		RET

SectorNo	DB	0x00
HeadNo		DB	0x00
CylinderNo	DB	0x00


;/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
; Load FAT From Floppy
;/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
FatMemAddr	DW	0x7E00

LoadFat:
		MOV	BX, WORD [FatMemAddr]		; Set the memory address for FAT into BX
		MOV	AX, WORD [BPB_FATSz16]		; Set the size of FAT into AX
		MUL	BYTE [BPB_NumFATs]		; Calculate the total size of FAT
		XCHG	AX, CX				; Set the total size of FAT into CX
		MOV	AX, WORD [BPB_RsvdSecCnt]	; Set the first sector of FAT into AX
ReadFat:
		CALL	ReadSector
		ADD	BX, WORD [BPB_BytsPerSec]
		INC	AX
		DEC	CX
		JCXZ	FatLoaded
		JMP	ReadFat
FatLoaded:
		MOV	SI, FatLoadedMsg
		CALL	DisplayMessage
		RET

FatLoadedMsg	DB	"FAT Loaded!", 0x0a, 0x0d, 0x00



;/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
; Load Root Directory From Floppy
;/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/
RootMemAddr	DW	0xA200

LoadRoot:
		MOV	BX, WORD [RootMemAddr]
		XCHG	AX, CX				; Save the start sector number into CX
		MOV	AX, 0x0020			; Set the entry size (32 byte)
		MUL	WORD [BPB_RootEntCnt]		; Calculate the total size in byte
		ADD	AX, WORD [BPB_BytsPerSec]
		DEC	AX
		DIV	WORD [BPB_BytsPerSec]		; Calculate the number of sectors
		XCHG	AX, CX				; AX: The start sector number
							; CX: The number of sectors to read
ReadRoot:
		CALL	ReadSector
		ADD	BX, WORD [BPB_BytsPerSec]
		INC	AX
		DEC	CX
		JCXZ	RootLoaded
		JMP	ReadRoot
RootLoaded:
		MOV	SI, RootLoadedMsg
		CALL	DisplayMessage
		RET

RootLoadedMsg	DB	"Root Directory Loaded!", 0x0a, 0x0d, 0x00


		TIMES	510 - ($ - $$) DB 0
		DW	0xAA55



;=====================================================
; Memory Layout
; 0x00000000 ~ 0x000003FF: Interrupt Vector Table
; 0x00000400 ~ 0x000004FF: BIOS Data
; 0x00000500 ~ 0x00007BFF: Boot Loader (Stage 2)
; 0x00007C00 ~ 0x00007DFF: Boot Loader (Stage 1)
; 0x00007E00 ~ 0x0000A1FF: FAT
; 0x0000A200 ~ 0x0000BDFF: Root Directory
; 0x0000BE00 ~ 0x0009FFFF: Unused
; 0x000A0000 ~ 0x000AFFFF: VRAM
; 0x000B0000 ~ 0x000B7FFF: VRAM (Gray Scale)
; 0x000B8000 ~ 0x000BFFFF: VRAM (Color)
; 0x000C0000 ~ 0x000C7FFF: BIOS Video
; 0x000C8000 ~ 0x000EFFFF: BIOS (Auxiliary)
; 0x000F0000 ~ 0x000FFFFF: BIOS
; 0x00100000 ~           : OS Kernel
;=====================================================
