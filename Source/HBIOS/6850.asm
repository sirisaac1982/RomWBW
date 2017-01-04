; -----------------------------------------------------------------------------
; Z80 SIO/2 Driver
;
; Based on Grant Searle's CPM BIOS
;
; Implements two serial ports for one SIO/2 chip. Uses Z80 IM2 and has an
; interrupt handler to buffer incoming characters.
;
; NOTE: If VFDTERMENABLE is set, then VFD will mirror the output on port A
;
; TODO: Probably should combine the separate code for ports A and B, and use
;       a single dispatch table.
; -----------------------------------------------------------------------------

SER_BUFSIZE	.EQU	150
SER_FULLSIZE	.EQU	140
SER_EMPTYSIZE	.EQU	5

; Port A use divide by 64 for 115200 on a 7.3728 Mhz clock
RTS_HIGH_A      .EQU     0D6H
RTS_LOW_A       .EQU     096H

ACIA_CTL        .EQU     080H
ACIA_DATA       .EQU     081H

SER_RESET       .EQU     03H

ACIA_IV         .EQU    2               ; Interrupt vector table entry to use

ACIA_PREINIT:
        LD      DE,ACIA_CFG_A
	LD	BC,ACIA_DISPATCH_A	; BC := DISPATCH ADDRESS
	CALL	CIO_ADDENT

        XOR	a

        LD	(serABufUsed),A
        LD	HL,serABuf
        LD	(serAInPtr),HL
        LD	(serARdPtr),HL

        LD        A, SER_RESET
        OUT       (ACIA_CTL),A
        LD        A,RTS_LOW_A
        OUT       (ACIA_CTL),A         ; Initialise ACIA

        LD	HL, INT_ACIA           ; Install ACIA interrupt handler
        LD	(HBX_IVT + ACIA_IV),HL

;		IM	1
;		EI				; Enable interrupts

                RET

ACIA_DISPATCH_A
	; DISPATCH TO FUNCTION HANDLER
	PUSH	HL			; SAVE HL FOR NOW
	LD	A,B			; GET FUNCTION
	AND	$0F			; ISOLATE LOW NIBBLE
	RLCA				; X 2 FOR WORD OFFSET INTO FUNCTION TABLE
	LD	HL,ACIA_FTBL_A		; START OF FUNC TABLE
	CALL	ADDHLA			; HL := ADDRESS OF ADDRESS OF FUNCTION
	LD	A,(HL)			; DEREF HL
	INC	HL			; ...
	LD	H,(HL)			; ...
	LD	L,A			; ... TO GET ADDRESS OF FUNCTION
	EX	(SP),HL			; RESTORE HL & PUT FUNC ADDRESS -> (SP)
	RET				; EFFECTIVELY A JP TO TGT ADDRESS

ACIA_FTBL_A
	.DW	ACIA_IN_A
	.DW	ACIA_OUT_A
	.DW	ACIA_IST_A
	.DW	ACIA_OST_A
	.DW	ACIA_INITDEV
	.DW	ACIA_QUERY
	.DW	ACIA_DEVICE

ACIA_INIT:
         XOR    A                       ; Signal success
         RET

; ----------------------------------------------------------------------------
; Interrupt Service Routine
; ----------------------------------------------------------------------------

ACIA_INT_HDLR:
                IN       A,(ACIA_CTL)
                AND      $01             ; Check if interupt due to read buffer full
                JR       Z,check2        ; if not, check the other port

                IN       A,(ACIA_DATA)
                PUSH     AF
                LD       A,(serABufUsed)
                CP       SER_BUFSIZE     ; If full then ignore
                JR       NZ,notFull
                POP      AF
                JR       check2

notFull:        LD       HL,(serAInPtr)
                INC      HL
                LD       A,L             ; Only need to check low byte becasuse buffer<256 bytes
                CP       (serABuf+SER_BUFSIZE) & $FF
                JR       NZ, notWrap
                LD       HL,serABuf
notWrap:        LD       (serAInPtr),HL
                POP      AF
                LD       (HL),A
                LD       A,(serABufUsed)
                INC      A
                LD       (serABufUsed),A
                CP       SER_FULLSIZE
                JR       C,check2
                LD       A,RTS_HIGH_A
                OUT      (ACIA_CTL),A

check2:         RET

; ----------------------------------------------------------------------------
; PORT A
; ----------------------------------------------------------------------------

; input character from port A

ACIA_IN_A:       PUSH    HL

waitForCharA:   CALL    ACIA_IST_A
                JR	Z, waitForCharA
		LD	HL,(serARdPtr)
		INC	HL
		LD	A,L
		CP	serAInMask
		JR	NZ, notRdWrapA
		LD	HL,serABuf
notRdWrapA:
		DI
		LD	(serARdPtr),HL

		LD	A,(serABufUsed)
		DEC	A
		LD	(serABufUsed),A

		CP	SER_EMPTYSIZE
                JR       NC,rts1
                LD       A,RTS_LOW_A
                OUT      (ACIA_CTL),A
rts1:
		LD	A,(HL)
		EI

		POP	HL

                LD      E, A                    ; CHAR READ TO E
                XOR	A			; SIGNAL SUCCESS

		RET

; output character to port A

ACIA_OUT_A:
#IF (VFDTERMENABLE)
                CALL    VFDTERM_PUTC
#ENDIF
conoutA1:
                CALL	ACIA_OST_A	; See if SIO channel A is finished transmitting
		JR	Z,conoutA1	; Loop until SIO flag signals ready
                LD      A, E            ; char to output is in E
		OUT	(ACIA_DATA),A	; OUTput the character
        	XOR	A	        ; SIGNAL SUCCESS
		RET

; check output status A

ACIA_OST_A:
		IN   	A,(ACIA_CTL)	; Status byte D2=TX Buff Empty, D0=RX char ready
                BIT     1, A
                JP      Z, CIO_IDLE
                XOR	A	       	; ZERO ACCUM
                INC	A	       	; ACCUM := 1 TO SIGNAL 1 BUFFER POSITION
        	RET

; check input status A

ACIA_IST_A:
		LD	A,(serABufUsed)
                CP      $00
	        JP	Z,CIO_IDLE	; NOT READY, RETURN VIA IDLE PROCESSING
                XOR	A		; ZERO ACCUM
                INC	A		; ACCUM := 1 TO SIGNAL 1 CHAR WAITING
		RET

;------------------------------------------------------------------------------
; COMMON
;------------------------------------------------------------------------------

ACIA_QUERY:
	LD	E,(IY + 4)		; FIRST CONFIG BYTE TO E
	LD	D,(IY + 5)		; SECOND CONFIG BYTE TO D
	XOR	A			; SIGNAL SUCCESS
	RET				; DONE

ACIA_DEVICE:
	LD	D,CIODEV_SIO	; D := DEVICE TYPE
	LD	E,(IY)		; E := PHYSICAL UNIT
	XOR	A		; SIGNAL SUCCESS
	RET

ACIA_INITDEV:
        XOR     A               ; SIGNAL SUCCESS
        RET

; Note: bug in assembler causes .ds to not generate output, thus screwing up
;   offsets in the binary. Do a DW 75 times to yield 150 bytes.

;serABuf:	.ds	SER_BUFSIZE	; SIO A Serial buffer
serABuf:        .DW     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                .DW     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
                .DW     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
serAInPtr	.DW	00h
serARdPtr	.DW	00h
serABufUsed	.DB	00h

serAInMask      .EQU     serAInPtr&$FF

; configuration block
ACIA_CFG_A       .DB     0
                .DB	0				; SIO TYPE
                .DB	ACIA_DATA			; IO PORT BASE (RBR, THR)
                .DB	ACIA_CTL       			; LINE STATUS PORT (LSR)
                .DW	DEFSERCFG			; LINE CONFIGURATION
                .FILL	2,$FF				; FILLER

