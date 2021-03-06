;======================================================================
;	N8 VDU DRIVER FOR SBC PROJECT
;
;	WRITTEN BY: DOUGLAS GOODALL
;	UPDATED BY: WAYNE WARTHEN -- 4/7/2013
;======================================================================
;
; TODO:
;   - IMPLEMENT SET CURSOR STYLE (VDASCS) FUNCTION?
;   - IMPLEMENT ALTERNATE DISPLAY MODES?
;   - IMPLEMENT DYNAMIC READ/WRITE OF CHARACTER BITMAP DATA?
;
;======================================================================
; TMS DRIVER - CONSTANTS
;======================================================================
;
TMS_CMDREG	.EQU	N8_BASE + $19	; READ STATUS / WRITE REG SEL
TMS_DATREG	.EQU	N8_BASE + $18	; READ/WRITE DATA
;
TMS_ROWS	.EQU	24
TMS_COLS	.EQU	40
;
TERMENABLE	.SET	TRUE		; INCLUDE TERMINAL PSEUDODEVICE DRIVER
;
; BELOW WAS TUNED FOR N8 AT 18MHZ WITH 3 IO WAIT STATES
; WILL NEED TO BE MODIFIED FOR DIFFERENT ACCESS SPEEDS
; IF YOU SEE SCREEN CORRUPTION, ADJUST THIS!!!
;
#DEFINE		TMS_IODELAY	NOP \ NOP \ NOP \ NOP \ NOP \ NOP \ NOP \ NOP
;
;======================================================================
; TMS DRIVER - INITIALIZATION
;======================================================================
;
TMS_INIT:
	CALL	NEWLINE			; FORMATTING
	PRTS("TMS: IO=0x$")
	LD	A,TMS_DATREG
	CALL	PRTHEXBYTE
;
	CALL 	TMS_CRTINIT		; SETUP THE TMS CHIP REGISTERS
	CALL	TMS_LOADFONT		; LOAD FONT DATA FROM ROM TO TMS STRORAGE
	CALL	TMS_VDARES
	CALL	PPK_INIT		; INITIALIZE KEYBOARD DRIVER
;
	; ADD OURSELVES TO VDA DISPATCH TABLE
	LD	B,0			; PHYSICAL UNIT IS ZERO
	LD	C,VDADEV_TMS		; DEVICE TYPE
	LD	DE,0			; UNIT DATA BLOB ADDRESS
	CALL	VDA_ADDENT		; ADD ENTRY, A := UNIT ASSIGNED
;
	; INITIALIZE EMULATION
	LD	C,A			; C := ASSIGNED VIDEO DEVICE NUM
	LD	DE,TMS_DISPATCH		; DE := DISPATCH ADDRESS
	CALL	TERM_ATTACH		; DO IT
;
	XOR	A			; SIGNAL SUCCESS
	RET
;	
;======================================================================
; TMS DRIVER - CHARACTER I/O (CIO) DISPATCHER AND FUNCTIONS
;======================================================================
;
TMS_DISPCIO:
	JP	PANIC
TMS_CIODISPADR	.EQU	$ - 2
;	
;======================================================================
; TMS DRIVER - VIDEO DISPLAY ADAPTER (VDA) DISPATCHER AND FUNCTIONS
;======================================================================
;
TMS_DISPATCH:
	LD	A,B		; GET REQUESTED FUNCTION
	AND	$0F		; ISOLATE SUB-FUNCTION

	JP	Z,TMS_VDAINI	; $40
	DEC	A
	JP	Z,TMS_VDAQRY	; $41
	DEC	A
	JP	Z,TMS_VDARES	; $42
	DEC	A
	JP	Z,TMS_VDADEV	; $43
	DEC	A
	JP	Z,TMS_VDASCS	; $44
	DEC	A
	JP	Z,TMS_VDASCP	; $45
	DEC	A
	JP	Z,TMS_VDASAT	; $46
	DEC	A
	JP	Z,TMS_VDASCO	; $47
	DEC	A
	JP	Z,TMS_VDAWRC	; $48
	DEC	A
	JP	Z,TMS_VDAFIL	; $49
	DEC	A
	JP	Z,TMS_VDACPY	; $4A
	DEC	A
	JP	Z,TMS_VDASCR	; $4B
	DEC	A
	JP	Z,PPK_STAT	; $4C
	DEC	A
	JP	Z,PPK_FLUSH	; $4D
	DEC	A
	JP	Z,PPK_READ	; $4E
	CALL	PANIC

TMS_VDAINI:
	; RESET VDA
	; CURRENTLY IGNORES VIDEO MODE AND BITMAP DATA
	CALL	TMS_VDARES		; RESET VDA
	XOR	A			; SIGNAL SUCCESS
	RET

TMS_VDAQRY:
	LD	C,$00		; MODE ZERO IS ALL WE KNOW
	LD	D,TMS_ROWS	; ROWS
	LD	E,TMS_COLS	; COLS
	LD	HL,0		; EXTRACTION OF CURRENT BITMAP DATA NOT SUPPORTED YET
	XOR	A		; SIGNAL SUCCESS
	RET

TMS_VDARES:
	LD	DE,0			; ROW = 0, COL = 0
	CALL	TMS_XY			; SEND CURSOR TO TOP LEFT
	LD	A,' '			; BLANK THE SCREEN
	LD	DE,TMS_ROWS * TMS_COLS	; FILL ENTIRE BUFFER
	CALL	TMS_FILL		; DO IT
	LD	DE,0			; ROW = 0, COL = 0
	CALL	TMS_XY			; SEND CURSOR TO TOP LEFT
	XOR	A
	DEC	A
	LD	(TMS_CURSAV),A
	CALL	TMS_SETCUR		; SET CURSOR
	
	XOR	A			; SIGNAL SUCCESS
	RET
	
TMS_VDADEV:
	LD	D,VDADEV_TMS	; D := DEVICE TYPE
	LD	E,0		; E := PHYSICAL UNIT IS ALWAYS ZERO
	XOR	A		; SIGNAL SUCCESS
	RET
	
TMS_VDASCS:
	CALL	PANIC		; NOT IMPLEMENTED (YET)
	
TMS_VDASCP:
	CALL	TMS_CLRCUR
	CALL	TMS_XY		; SET CURSOR POSITION
	CALL	TMS_SETCUR
	XOR	A		; SIGNAL SUCCESS
	RET
	
TMS_VDASAT:
	XOR	A		; NOT POSSIBLE, JUST SIGNAL SUCCESS
	RET
	
TMS_VDASCO:
	XOR	A		; NOT POSSIBLE, JUST SIGNAL SUCCESS
	RET
	
TMS_VDAWRC:
	CALL	TMS_CLRCUR	; CURSOR OFF
	LD	A,E		; CHARACTER TO WRITE GOES IN A
	CALL	TMS_PUTCHAR	; PUT IT ON THE SCREEN
	CALL	TMS_SETCUR
	XOR	A		; SIGNAL SUCCESS
	RET
	
TMS_VDAFIL:
	CALL	TMS_CLRCUR
	LD	A,E		; FILL CHARACTER GOES IN A
	EX	DE,HL		; FILL LENGTH GOES IN DE
	CALL	TMS_FILL	; DO THE FILL
	CALL	TMS_SETCUR
	XOR	A		; SIGNAL SUCCESS
	RET

TMS_VDACPY:
	CALL	TMS_CLRCUR
	; LENGTH IN HL, SOURCE ROW/COL IN DE, DEST IS TMS_POS
	; BLKCPY USES: HL=SOURCE, DE=DEST, BC=COUNT
	PUSH	HL		; SAVE LENGTH
	CALL	TMS_XY2IDX	; ROW/COL IN DE -> SOURCE ADR IN HL
	POP	BC		; RECOVER LENGTH IN BC
	LD	DE,(TMS_POS)	; PUT DEST IN DE
	CALL	TMS_BLKCPY	; DO A BLOCK COPY
	CALL	TMS_SETCUR
	XOR	A
	RET
	
TMS_VDASCR:
	CALL	TMS_CLRCUR
TMS_VDASCR0:
	LD	A,E		; LOAD E INTO A
	OR	A		; SET FLAGS
	JR	Z,TMS_VDASCR2	; IF ZERO, WE ARE DONE
	PUSH	DE		; SAVE E
	JP	M,TMS_VDASCR1	; E IS NEGATIVE, REVERSE SCROLL
	CALL	TMS_SCROLL	; SCROLL FORWARD ONE LINE
	POP	DE		; RECOVER E
	DEC	E		; DECREMENT IT
	JR	TMS_VDASCR0	; LOOP
TMS_VDASCR1:
	CALL	TMS_RSCROLL	; SCROLL REVERSE ONE LINE
	POP	DE		; RECOVER E
	INC	E		; INCREMENT IT
	JR	TMS_VDASCR0	; LOOP
TMS_VDASCR2:
	CALL	TMS_SETCUR
	XOR	A
	RET
;
;======================================================================
; TMS DRIVER - PRIVATE DRIVER FUNCTIONS
;======================================================================
;
;----------------------------------------------------------------------
; SET TMS9918 REGISTER VALUE
;   TMS_SET WRITES VALUE IN A TO VDU REGISTER SPECIFIED IN C
;----------------------------------------------------------------------
;
TMS_SET:
	OUT	(TMS_CMDREG),A		; WRITE IT
	TMS_IODELAY
	LD	A,C			; GET THE DESIRED REGISTER
	OR	$80			; SET BIT 7 
	OUT	(TMS_CMDREG),A		; SELECT THE DESIRED REGISTER
	TMS_IODELAY
	RET
;
;----------------------------------------------------------------------
; SET TMS9918 READ/WRITE ADDRESS
;   TMS_WR SETS TMS9918 TO BEGIN WRITING TO ADDRESS SPECIFIED IN HL
;   TMS_RD SETS TMS9918 TO BEGIN READING TO ADDRESS SPECIFIED IN HL
;----------------------------------------------------------------------
;
TMS_WR:
	PUSH	HL
	SET	6,H			; SET WRITE BIT
	CALL	TMS_RD
	POP	HL
	RET
;
TMS_RD:
	LD	A,L
	OUT	(TMS_CMDREG),A
	TMS_IODELAY
	LD	A,H
	OUT	(TMS_CMDREG),A
	TMS_IODELAY
	RET
;
;----------------------------------------------------------------------
; MOS 8563 DISPLAY CONTROLLER CHIP INITIALIZATION
;----------------------------------------------------------------------
;
TMS_CRTINIT:
	; SET WRITE ADDRESS TO $0
	LD	HL,0
	CALL	TMS_WR
;
	; FILL ENTIRE RAM CONTENTS
	LD	DE,$4000
TMS_CRTINIT1:
	XOR	A
	OUT	(TMS_DATREG),A
	TMS_IODELAY			; DELAY
	DEC	DE
	LD	A,D
	OR	E
	JR	NZ,TMS_CRTINIT1
;
	; INITIALIZE VDU REGISTERS
    	LD 	C,0			; START WITH REGISTER 0
	LD	B,TMS_INIT9918LEN	; NUMBER OF REGISTERS TO INIT
    	LD 	HL,TMS_INIT9918		; HL = POINTER TO THE DEFAULT VALUES
TMS_CRTINIT2:
	LD	A,(HL)			; GET VALUE
	CALL	TMS_SET			; WRITE IT
	INC	HL			; POINT TO NEXT VALUE
	INC	C			; POINT TO NEXT REGISTER
	DJNZ	TMS_CRTINIT2		; LOOP
    	RET
;
;----------------------------------------------------------------------
; LOAD FONT DATA
;----------------------------------------------------------------------
;
TMS_LOADFONT:
	; SET WRITE ADDRESS TO $800
	LD	HL,$800
	CALL	TMS_WR
;
	; FILL $800 BYTES FROM FONTDATA
	LD	HL,TMS_FONTDATA
	LD	DE,$100 * 8
TMS_LOADFONT1:
	LD	B,8
TMS_LOADFONT2:
	LD	A,(HL)
	PUSH	AF
	INC	HL
	DJNZ	TMS_LOADFONT2
;
	LD	B,8
TMS_LOADFONT3:
	POP	AF
	OUT	(TMS_DATREG),A
	TMS_IODELAY			; DELAY
	DEC	DE
	DJNZ	TMS_LOADFONT3
;
	LD	A,D
	OR	E
	JR	NZ,TMS_LOADFONT1
;
	RET
;
;----------------------------------------------------------------------
; VIRTUAL CURSOR MANAGEMENT
;   TMS_SETCUR CONFIGURES AND DISPLAYS CURSOR AT CURRENT CURSOR LOCATION
;   TMS_CLRCUR REMOVES THE CURSOR
;
; VIRTUAL CURSOR IS GENERATED BY DYNAMICALLY CHANGING FONT GLYPH
; FOR CHAR 255 TO BE THE INVERSE OF THE GLYPH OF THE CHARACTER UNDER
; THE CURRENT CURSOR POSITION.  THE CHARACTER CODE IS THEN SWITCH TO
; THE VALUE 255 AND THE ORIGINAL VALUE IS SAVED.  WHEN THE DISPLAY
; NEEDS TO BE CHANGED THE PROCESS IS UNDONE.  IT IS ESSENTIAL THAT
; ALL DISPLAY CHANGES BE BRACKETED WITH CALLS TO TMS_CLRCUR PRIOR TO
; CHANGES AND TMS_SETCUR AFTER CHANGES.
;----------------------------------------------------------------------
;
TMS_SETCUR:
	PUSH	HL			; PRESERVE HL
	PUSH	DE			; PRESERVE DE
	LD	HL,(TMS_POS)		; GET CURSOR POSITION
	CALL	TMS_RD			; SETUP TO READ VDU BUF
	IN	A,(TMS_DATREG)		; GET REAL CHAR UNDER CURSOR
	TMS_IODELAY			; DELAY
	PUSH	AF			; SAVE THE CHARACTER
	CALL	TMS_WR			; SETUP TO WRITE TO THE SAME PLACE
	LD	A,$FF			; REPLACE REAL CHAR WITH 255
	OUT	(TMS_DATREG),A		; DO IT
	TMS_IODELAY			; DELAY
	POP	AF			; RECOVER THE REAL CHARACTER
	LD	B,A			; PUT IT IN B
	LD	A,(TMS_CURSAV)		; GET THE CURRENTLY SAVED CHAR
	CP	B			; COMPARE TO CURRENT
	JR	Z,TMS_SETCUR3		; IF EQUAL, BYPASS EXTRA WORK
	LD	A,B			; GET REAL CHAR BACK TO A
	LD	(TMS_CURSAV),A		; SAVE IT
	; GET THE GLYPH DATA FOR REAL CHARACTER
	LD	HL,0			; ZERO HL
	LD	L,A			; HL IS NOW RAW CHAR INDEX
	LD	B,3			; LEFT SHIFT BY 3 BITS
TMS_SETCUR0:	; MULT BY 8 FOR FONT INDEX
	SLA	L			; SHIFT LSB INTO CARRY
	RL	H			; SHFT MSB FROM CARRY
	DJNZ	TMS_SETCUR0		; LOOP 3 TIMES
	LD	DE,$800			; OFFSET TO START OF FONT TABLE
	ADD	HL,DE			; ADD TO FONT INDEX
	CALL	TMS_RD			; SETUP TO READ GLYPH
	LD	B,8			; 8 BYTES
	LD	HL,TMS_BUF		; INTO BUFFER
TMS_SETCUR1:	; READ GLYPH LOOP
	IN	A,(TMS_DATREG)		; GET NEXT BYTE
	TMS_IODELAY			; IO DELAY
	LD	(HL),A			; SAVE VALUE IN BUF
	INC	HL			; BUMP BUF POINTER
	DJNZ	TMS_SETCUR1		; LOOP FOR 8 BYTES
;
	; NOW WRITE INVERTED GLYPH INTO FONT INDEX 255
	LD	HL,$800 + (255 * 8)	; LOC OF GLPYPH DATA FOR CHAR 255
	CALL	TMS_WR			; SETUP TO WRITE THE INVERTED GLYPH
	LD	B,8			; 8 BYTES PER GLYPH
	LD	HL,TMS_BUF		; POINT TO BUFFER
TMS_SETCUR2:	; WRITE INVERTED GLYPH LOOP
	LD	A,(HL)			; GET THE BYTE
	INC	HL			; BUMP THE BUF POINTER
	XOR	$FF			; INVERT THE VALUE
	OUT	(TMS_DATREG),A		; WRITE IT TO VDU
	TMS_IODELAY			; IO DELAY
	DJNZ	TMS_SETCUR2		; LOOP FOR ALL 8 BYTES OF GLYPH
;
TMS_SETCUR3:	; RESTORE REGISTERS AND RETURN
	POP	DE			; RECOVER DE
	POP	HL			; RECOVER HL
	RET				; RETURN
;
;
;
TMS_CLRCUR:	; REMOVE VIRTUAL CURSOR FROM SCREEN
	PUSH	HL			; SAVE HL
	LD	HL,(TMS_POS)		; POINT TO CURRENT CURSOR POS
	CALL	TMS_WR			; SET UP TO WRITE TO VDU
	LD	A,(TMS_CURSAV)		; GET THE REAL CHARACTER
	OUT	(TMS_DATREG),A		; WRITE IT
	TMS_IODELAY			; IO DELAY
	POP	HL			; RECOVER HL
	RET				; RETURN
;
;----------------------------------------------------------------------
; SET CURSOR POSITION TO ROW IN D AND COLUMN IN E
;----------------------------------------------------------------------
;
TMS_XY:
	CALL	TMS_XY2IDX		; CONVERT ROW/COL TO BUF IDX
	LD	(TMS_POS),HL		; SAVE THE RESULT (DISPLAY POSITION)
	RET
;
;----------------------------------------------------------------------
; CONVERT XY COORDINATES IN DE INTO LINEAR INDEX IN HL
; D=ROW, E=COL
;----------------------------------------------------------------------
;
TMS_XY2IDX:
	LD	A,E			; SAVE COLUMN NUMBER IN A
	LD	H,D			; SET H TO ROW NUMBER
	LD	E,TMS_COLS		; SET E TO ROW LENGTH
	CALL	MULT8			; MULTIPLY TO GET ROW OFFSET
	LD	E,A			; GET COLUMN BACK
	ADD	HL,DE			; ADD IT IN
	RET				; RETURN
;
;----------------------------------------------------------------------
; WRITE VALUE IN A TO CURRENT VDU BUFFER POSTION, ADVANCE CURSOR
;----------------------------------------------------------------------
;
TMS_PUTCHAR:
	PUSH	AF			; SAVE CHARACTER
	LD	HL,(TMS_POS)		; LOAD CURRENT POSITION INTO HL
	CALL	TMS_WR			; SET THE WRITE ADDRESS
	POP	AF			; RECOVER CHARACTER TO WRITE
	OUT	(TMS_DATREG),A		; WRITE THE CHARACTER
	LD	HL,(TMS_POS)		; LOAD CURRENT POSITION INTO HL
	INC	HL
	LD	(TMS_POS),HL
	RET
;
;----------------------------------------------------------------------
; FILL AREA IN BUFFER WITH SPECIFIED CHARACTER AND CURRENT COLOR/ATTRIBUTE
; STARTING AT THE CURRENT FRAME BUFFER POSITION
;   A: FILL CHARACTER
;   DE: NUMBER OF CHARACTERS TO FILL
;----------------------------------------------------------------------
;
TMS_FILL:
	LD	C,A			; SAVE THE CHARACTER TO WRITE
	LD	HL,(TMS_POS)		; SET STARTING POSITION
	CALL	TMS_WR			; SET UP FOR WRITE
;
TMS_FILL1:
	LD	A,C			; RECOVER CHARACTER TO WRITE
	OUT	(TMS_DATREG),A
	TMS_IODELAY
	DEC	DE
	LD	A,D
	OR	E
	JR	NZ,TMS_FILL1
;
	RET
;
;----------------------------------------------------------------------
; SCROLL ENTIRE SCREEN FORWARD BY ONE LINE (CURSOR POSITION UNCHANGED)
;----------------------------------------------------------------------
;
TMS_SCROLL:
	LD	HL,0			; SOURCE ADDRESS OF CHARACER BUFFER
	LD	C,TMS_ROWS - 1		; SET UP LOOP COUNTER FOR ROWS - 1
;
TMS_SCROLL0:	; READ LINE THAT IS ONE PAST CURRENT DESTINATION
	PUSH	HL			; SAVE CURRENT DESTINATION
	LD	DE,TMS_COLS
	ADD	HL,DE			; POINT TO NEXT ROW SOURCE
	CALL	TMS_RD			; SET UP TO READ
	LD	DE,TMS_BUF
	LD	B,TMS_COLS
TMS_SCROLL1:
	IN	A,(TMS_DATREG)
	TMS_IODELAY
	LD	(DE),A
	INC	DE
	DJNZ	TMS_SCROLL1
	POP	HL			; RECOVER THE DESTINATION
;	
	; WRITE THE BUFFERED LINE TO CURRENT DESTINATION
	CALL	TMS_WR			; SET UP TO WRITE
	LD	DE,TMS_BUF
	LD	B,TMS_COLS
TMS_SCROLL2:
	LD	A,(DE)
	OUT	(TMS_DATREG),A
	TMS_IODELAY
	INC	DE
	DJNZ	TMS_SCROLL2
;
	; BUMP TO NEXT LINE
	LD	DE,TMS_COLS
	ADD	HL,DE
	DEC	C			; DECREMENT ROW COUNTER
	JR	NZ,TMS_SCROLL0		; LOOP THRU ALL ROWS
;
	; FILL THE NEWLY EXPOSED BOTTOM LINE
	CALL	TMS_WR
	LD	A,' '
	LD	B,TMS_COLS
TMS_SCROLL3:
	OUT	(TMS_DATREG),A
	TMS_IODELAY
	DJNZ	TMS_SCROLL3
;
	RET
;
;----------------------------------------------------------------------
; REVERSE SCROLL ENTIRE SCREEN BY ONE LINE (CURSOR POSITION UNCHANGED)
;----------------------------------------------------------------------
;
TMS_RSCROLL:
	LD	HL,TMS_COLS * (TMS_ROWS - 1)
	LD	C,TMS_ROWS - 1
;
TMS_RSCROLL0:	; READ THE LINE THAT IS ONE PRIOR TO CURRENT DESTINATION
	PUSH	HL			; SAVE THE DESTINATION ADDRESS
	LD	DE,-TMS_COLS
	ADD	HL,DE			; SET SOURCE ADDRESS
	CALL	TMS_RD			; SET UP TO READ
	LD	DE,TMS_BUF		; POINT TO BUFFER
	LD	B,TMS_COLS		; LOOP FOR EACH COLUMN
TMS_RSCROLL1:
	IN	A,(TMS_DATREG)		; GET THE CHAR
	TMS_IODELAY			; RECOVER
	LD	(DE),A			; SAVE IN BUFFER
	INC	DE			; BUMP BUFFER POINTER
	DJNZ	TMS_RSCROLL1		; LOOP THRU ALL COLS
	POP	HL			; RECOVER THE DESTINATION ADDRESS
;
	; WRITE THE BUFFERED LINE TO CURRENT DESTINATION
	CALL	TMS_WR			; SET THE WRITE ADDRESS
	LD	DE,TMS_BUF		; POINT TO BUFFER
	LD	B,TMS_COLS		; INIT LOOP COUNTER
TMS_RSCROLL2:
	LD	A,(DE)			; LOAD THE CHAR
	OUT	(TMS_DATREG),A		; WRITE TO SCREEN
	TMS_IODELAY			; DELAY
	INC	DE			; BUMP BUF POINTER
	DJNZ	TMS_RSCROLL2		; LOOP THRU ALL COLS
;
	; BUMP TO THE PRIOR LINE
	LD	DE,-TMS_COLS		; LOAD COLS (NEGATIVE)
	ADD	HL,DE			; BACK UP THE ADDRESS
	DEC	C			; DECREMENT ROW COUNTER
	JR	NZ,TMS_RSCROLL0		; LOOP THRU ALL ROWS
;
	; FILL THE NEWLY EXPOSED BOTTOM LINE
	CALL	TMS_WR
	LD	A,' '
	LD	B,TMS_COLS
TMS_RSCROLL3:
	OUT	(TMS_DATREG),A
	TMS_IODELAY
	DJNZ	TMS_RSCROLL3
;
	RET
;
;----------------------------------------------------------------------
; BLOCK COPY BC BYTES FROM HL TO DE
;----------------------------------------------------------------------
;
TMS_BLKCPY:
	; SAVE DESTINATION AND LENGTH
	PUSH	BC		; LENGTH
	PUSH	DE		; DEST
;
	; READ FROM THE SOURCE LOCATION
TMS_BLKCPY1:
	CALL	TMS_RD		; SET UP TO READ FROM ADDRESS IN HL
	LD	DE,TMS_BUF	; POINT TO BUFFER
	LD	B,C
TMS_BLKCPY2:
	IN	A,(TMS_DATREG)	; GET THE NEXT BYTE
	TMS_IODELAY		; DELAY
	LD	(DE),A		; SAVE IN BUFFER
	INC	DE		; BUMP BUF PTR
	DJNZ	TMS_BLKCPY2	; LOOP AS NEEDED
;
	; WRITE TO THE DESTINATION LOCATION
	POP	HL		; RECOVER DESTINATION INTO HL
	CALL	TMS_WR		; SET UP TO WRITE
	LD	DE,TMS_BUF	; POINT TO BUFFER
	POP	BC		; GET LOOP COUNTER BACK
	LD	B,C
TMS_BLKCPY3:
	LD	A,(DE)		; GET THE CHAR FROM BUFFER
	OUT	(TMS_DATREG),A	; WRITE TO VDU
	TMS_IODELAY		; DELAY
	INC	DE		; BUMP BUF PTR
	DJNZ	TMS_BLKCPY3	; LOOP AS NEEDED
;
	RET
;
;==================================================================================================
;   TMS DRIVER - DATA
;==================================================================================================
;
TMS_POS		.DW 	0	; CURRENT DISPLAY POSITION
TMS_CURSAV	.DB	0	; SAVES ORIGINAL CHARACTER UNDER CURSOR
TMS_BUF		.FILL	256,0	; COPY BUFFER
;
;==================================================================================================
;   TMS DRIVER - TMS9918 REGISTER INITIALIZATION
;==================================================================================================
;
; Control Registers (write CMDREG):
;
; Reg	Bit 7	Bit 6	Bit 5	Bit 4	Bit 3	Bit 2	Bit 1	Bit 0	Description
; 0	-	-	-	-	-	-	M2	EXTVID
; 1	4/16K	BL	GINT	M1	M3	-	SI	MAG
; 2	-	-	-	-	PN13	PN12	PN11	PN10
; 3	CT13	CT12	CT11	CT10	CT9	CT8	CT7	CT6
; 4	-	-	-	-	-	PG13	PG12	PG11
; 5	-	SA13	SA12	SA11	SA10	SA9	SA8	SA7
; 6	-	-	-	-	-	SG13	SG12	SG11
; 7	TC3	TC2	TC1	TC0	BD3	BD2	BD1	BD0
;
; Status (read CMDREG):
;
; 	Bit 7	Bit 6	Bit 5	Bit 4	Bit 3	Bit 2	Bit 1	Bit 0	Description
; 	INT	5S	C	FS4	FS3	FS2	FS1	FS0
;
; M1,M2,M3	Select screen mode
; EXTVID	Enables external video input.
; 4/16K		Selects 16kB RAM if set. No effect in MSX1 system.
; BL		Blank screen if reset; just backdrop. Sprite system inactive
; SI		16x16 sprites if set; 8x8 if reset
; MAG		Sprites enlarged if set (sprite pixels are 2x2)
; GINT		Generate interrupts if set
; PN*		Address for pattern name table
; CT*		Address for colour table (special meaning in M2)
; PG*		Address for pattern generator table (special meaning in M2)
; SA*		Address for sprite attribute table
; SG*		Address for sprite generator table
; TC*		Text colour (foreground)
; BD*		Back drop (background). Sets the colour of the border around
; 		the drawable area. If it is 0, it is black (like colour 1).
; FS*		Fifth sprite (first sprite that's not displayed). Only valid
; 		if 5S is set.
; C		Sprite collision detected
; 5S		Fifth sprite (not displayed) detected. Value in FS* is valid.
; INT		Set at each screen update, used for interrupts.
;
TMS_INIT9918:
	.DB	$00		; REG 0 - NO EXTERNAL VID
	.DB	$50		; REG 1 - ENABLE SCREEN, SET MODE 1
	.DB	$00		; REG 2 - PATTERN NAME TABLE := 0
	.DB	$00		; REG 3 - NO COLOR TABLE
	.DB	$01		; REG 4 - SET PATTERN GENERATOR TABLE TO $800
	.DB	$00		; REG 5 - SPRITE ATTRIBUTE IRRELEVANT
	.DB	$00		; REG 6 - NO SPRITE GENERATOR TABLE
	.DB	$F0		; REG 7 - WHITE ON BLACK
;
TMS_INIT9918LEN	.EQU	$ - TMS_INIT9918
;
;==================================================================================================
;   TMS DRIVER - FONT DATA
;==================================================================================================
;
TMS_FONTDATA:
#INCLUDE "TMS_font.inc"
;
#INCLUDE "ppk.asm"
