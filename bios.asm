TITLE BIOS ----- 06/10/85 BIOS ROUTINES
.286C
.LIST
CODE	SEGMENT	BYTE PUBLIC

	PUBLIC	EQUIPMENT_1
	PUBLIC	MEMORY_SIzE_DET_1
	PUBLIC	NMI_INT_1

	EXTRN	C8042:NEAR	; POST SEND 8042 COMMAND ROUTINE
	EXTRN	CMOS_READ:NEAR	; READ CMOS LOCATION ROUTINE
	EXTRN	D1:NEAR		; "PARITY CHECK 1" MESSAGE
	EXTRN	D2:NEAR		; "PARITY CHECK 2" MESSAGE
	EXTRN	D2A:NEAR	; "?????" UNKNOWN ADDRESS MESSAGE
	EXTRN	DDS:NEAR	; LOAD (DS) WITH DATA SEGMENT SELECTOR
	EXTRN	OBF_42:NEAR	; POST WAIT 8042 RESPONSE ROUTINE
	EXTRN	PRT_HEX:NEAR	; DISPLAY CHARACTER ROUTINE
	EXTRN	PRT_SEG:NEAR	; DISPLAY FIVE CHARACTER ADDRESS ROUTINE	EXTRN	P_MSG:NEAR	; DISPLAY MESSAGE STRING ROUTINE

;--- INT 12 H -----------------------------------------------------------------
; MEMORY_SIZE_DETERMINE							: 
;	THIS ROUTINE RETURNS THE AMOUNT OF MEMORY IN THE SYSTEM AS		:
;	DETERMINED BY THE POST ROUTINES. (UP TO 640K) 				:
;	NOTE THAT THE SYSTEM MAY NOT BE ABLE TO USE I/O MEMORY UNLESS		:
;	THERE IS A FULL COMPLEMENT OF 512K BYTES ON THE PLANAR.			:
; INPUT									:
;	NO REGISTERS							:
;	THE @MEMORY_SIZE VARIABLE IS SET DURING POWER ON DIAGNOSTICS		:
;	ACCORDING TO THE FOLLOWING ASSUMPTIONS:						:
;									:
;       1. CONFIGURATION RECORD IN NON-VOLATILE MEMORY EQUALS THE ACTUAL	:
;          MEMORY SIZE INSTALLED.							:
;									:
;       2. ALL INSTALLED MEMORY IS FUNCTIONAL. IF THE MEMORY TEST DURING	:
;          POST INDICATES LESS, THEN THIS VALUE BECOMES THE DEFAULT.		:
;          IF NON-VOLATILE MEMORY IS NOT VALID (NOT INITIALIZED OR BATTERY	:
;          FAILURE) THEN ACTUAL MEMORY DETERMINED BECOMES THE DEFAULT.		:
;									:
;       3. ALL MEMORY FROM 0 TO 640K MUST BE CONTIGUOUS.				:
;									:
; OUTPUT									:
;       	(AX) = NUMBER OF CONTIGUOUS 1K BLOCKS OF MEMORY				:
;------------------------------------------------------------------------------
	ASSUME CS:CODE,DS:DATA

MEMORY_SIZE_DET_1  PROC FAR
	STI			; INTERRUPTS BACK ON
	PUSH	DS		; SAVE SEGMENT
	CALL	DDS		; ESTABLISH ADDRESSING
	MOV	AX,@MEMORY_SIZE	; GET VALUE
	POP	DS		; RECOVER SEGMENT
	IRET			; RETURN TO CALLER
MEMORY_SIZE_DET_1  ENDP

;--- INT 11 H -----------------------------------------------------------------
; EQUIPMENT DETERMINATION							:
;       THIS ROUTINE ATTEMPTS TO DETERMINE WHAT OPTIONAL				:
;       DEVICES ARE ATTACHED TO THE SYSTEM.						:
; INPUT									:
;       NO REGISTERS							:
;       THE @EQUIP_FLAG VARIABLE IS SET DURING THE POWER ON				:
;       DIAGNOSTICS USING THE FOLLOWING HARDWARE ASSUMPTIONS:			:
;       PORT 03FA = INTERRUPT ID REGISTER OF 8250 (PRIMARY)				:
;            02FA = INTERRUPT ID REGISTER OF 8250 (SECONDARY)			:
;               BITS 7-3 ARE ALWAYS 0							:
;       PORT 0378 = OUTPUT PORT OF PRINTER (PRIMARY)					:
;            0278 = OUTPUT PORT OF PRINTER (SECONDARY)				:
;            03BC = OUTPUT PORT OF PRINTER (MONOCHROME-PRINTER)			:
; OUTPUT									:
;       (AX) IS SET, BIT SIGNIFICANT, TO INDICATE ATTACHED I/O			:
;       BIT 15,14 = NUMBER OF PRINTERS ATTACHED						:
;       BIT 13 = INTERNAL MODEM INSTALLED							:
;       BIT 12 NOT USED							:
;       BIT 11,10,9 = NUMBER OF RS232 CARDS ATTACHED					:
;       BIT 8 = NOT USED							:
;       BIT 7,6 = NUMBER OF DISKETTE DRIVES						:
;               00=1, 01=2 ONLY IF BIT 0 = 1						:
;       BIT 5,4 = INITIAL VIDEO MODE							:
;                       00 - UNUSED							:
;                       01 - 40X25 BW USING COLOR CARD				:
;                       10 - 80X25 BW USING COLOR CARD				:
;                       11 - 80X25 BW USING BW CARD					:
;       BIT 3 = NOT USED							:
;       BIT 2 = NOT USED							:
;       BIT 1 = MATH COPROCESSOR							:
;       BIT 0 = 1 (IPL DISKETTE INSTALLED)						:
;       NO OTHER REGISTERS AFFECTED							:
;------------------------------------------------------------------------------

EQUIPMENT_1	PROC FAR	; ENTRY POINT FOR ORG 0F84DH
	STI			; INTERRUPTS BACK ON
	PUSH	DS		; SAVE SEGMENT REGISTER
	CALL	DDS		; ESTABLISH ADDRESSING
	MOV	AX,@EQUIP_FLAG	; GET THE CURRENT SETTINGS
	POP	DS		; RECOVER SEGMENT
	IRET			; RETURN TO CALLER
EQUIPMENT_1	ENDP


;-- HARDWARE INT 02 H -- ( NMI LEVEL ) ----------------------------------------
; NON-MASKABLE INTERRUPT ROUTINE (REAL MODE)						:
;       THIS ROUTINE WILL PRINT A "PARITY CHECK 1 OR 2" MESSAGE AND ATTEMPT	:
;       TO FIND THE STORAGE LOCATION IN BASE 64OK CONTAINING THE BAD PARITY.	:
;       IF FOUND, THE SEGMENT ADDRESS WILL BE PRINTED.  IF NO PARITY ERROR	:
;       CAN BE FOUND (INTERMITTENT READ PROBLEM)  ?????  WILL BE DISPLAYED	:
;       WHERE THE ADDRESS WOULD NORMALLY GO.						:
;									:
;       PARITY CHECK 1 = PLANAR BOARD MEMORY FAILURE.					:
;       PARITY CHECK 2 = OFF PLANAR BOARD MEMORY FAILURE.				:
;------------------------------------------------------------------------------

NMI_INT_1  PROC	NEAR
	PUSH	AX		; SAVE ORIGINAL CONTENTS OF (AX)

	IN	AL,PORT_B	; READ STATUS PORT
	TEST	AL,PARITY_ERR	; PARITY CHECK OR I/O CHECK ?
	JNZ	NMI_1		; GO TO ERROR HALTS IF HARDWARE ERROR

	MOV	AL,CMCS_REG_D	; ELSE ?? - LEAVE NMI ON
	CALL	CMOS_READ	; TOGGLE NMI USING COMMON READ ROUTINE
	POP	AX		; RESTORE ORIGINAL CONTENTS OF (AX)
	IRET			; EXIT NMI HANDLER BACK TO PROGRAM


NMI_1:					; HARDWARE ERROR
	PUSH	AX			; SAVE INITIAL CHECK MASK IN (AL)
	MOV	AL,CMOS_REG_D+NMI	; MASK TRAP (NMI) INTERRUPTS OFF
	OUT	CMOS_PORT,AL
	MOV	AL,DIS_KBD		; DISABLE THE KEYBOARD
	CALL	C8042			; SEND COMMAND TO ADAPTER
	CALL	DDS			; ADDRESS DATA SEGMENT
	MOV	AH,0			; INITIALIZE AND BET MODE FOR VIDEO
	MOV	AL,@CRT_MODE		; GET CURRENT MODE
	INT	10H			; CALL VIDEO_IO TO CLEAR SCREEN

;-----	DISPLAY "PARITY CHECK ?" ERROR MESSAGES
	POP	AX		; RECOVER INITIAL CHECK STATUS
	MOV	SI,OFFSET DI	; PLANAR ERROR, ADDRESS "PARITY CHECK 1"
	TEST	AL,PARITY_CHECK	; CHECK FOR PLANAR ERROR
	JZ	NMI_2		; SKIP IF NOT

	PUSH	AX		; SAVE STATUS
	CALL	P_MSG		; DISPLAY "PARITY CHECK 1" MESSAGE
	POP	AX		; AND RECOVER STATUS
NMI_2:
	MOV	SI,OFFSET D2	; ADDRESS OF "PARITY CHECK 2" MESSAGE
	TEST	AL,IO_CHECK	; I/O PARITY CHECK ?
	JZ	NMI_3		; SKIP IF CORRECT ERROR DISPLAYED
	CALL	P_MSG		; DISPLAY "PARITY CHECK 2" ERROR

;-----	TEST FOR HOT NMI ON PLANAR PARITY LINE
NMI_3:
	IN	AL,PORT_B
	OR	AL,RAM_PAR_OFF	; TOGGLE PARITY CHECK ENABLES
	OUT	PORT_B,AL
	AND	AL,RAM_PAR_ON	; TO CLEAR THE PENDING CHECK
	OUT 	PORT_B,AL

	CLD			; SET DIRECTION FLAG TO INCREMENT
	SUB	DX,DX		; POINT (DX) AT START OF REAL MEMORY
	SUB	SI,SI		; SET (SI) TO START OF	(DS:)
	IN	AL,PORT_B	; READ CURRENT PARITY CHECK LATCH
	TEST	AL,PARITY_ERR	; CHECK FOR HOT NMI SOURCE
	JNZ	NMI_5		; SKIP IF ERROR NOT RESET (DISPLAY ???)

;-----	SEE IF LOCATION THAT CAUSED PARITY CHECK CAN BE FOUND IN BASE MEMORY

	MOV	BX,@MEMORY_SIZE	; GET BASE MEMORY SIZE WORD
NMI_4:
	MOV	DS,DX		; POINT TO 64K SEGMENT
	MOV	CX,4000H*2	; SET WORD COUNT FOR 64 KB SCAN
	REP	LODSW		; READ 64 KB OF MEMORY
	IN	AL,PORT_B	; READ PARITY CHECK LATCHES
	TEST	AL,PARITY_ERR	; CHECK FOR ANY PARITY ERROR PENDING
	JNZ	NMI_6		; GO PRINT SEGMENT ADDRESS IF ERROR

	ADD	DH,010H		; POINT TO NEXT 64K BLOCK
	SUB	AX,16D*4	; DECREMENT COUNT OF 1024 BYTE SEGMENTS
	JA	NMI_4		; LOOP TILL ALL 64K SEGMENTS DONE

NMI_5:	MOV	SI,OFFSET D2A	; PRINT ROW OF ????? IF PARITY
	CALL	P_MSG		; CHECK COULD NOT BE RE-CREATED
	CLI
	HLT			; HALT SYSTEM


NMI_6:	CALL	PRT_SEG		; PRINT SEGMENT VALUE (IN DX)
	MOV	AL,'('		; PRINT (S)
	CALL	PRT_HEX
	MOV	AL,'S'
	CALL	PRT_HEX
	MOV	AL,')'
	CALL	PRT_HEX
	CLI			; HALT SYSTEM
	HLT

NMI_INT_1  ENDP

	CODE	ENDS
	END

