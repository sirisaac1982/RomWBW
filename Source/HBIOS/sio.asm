SER_BUFSIZE	.EQU	150
SER_FULLSIZE	.EQU	140
SER_EMPTYSIZE	.EQU	5


RTS_HIGH	.EQU	0E8H
RTS_LOW		.EQU	0EAH

SIOA_D		.EQU	$80
SIOA_C		.EQU	SIOA_D+2 ;$02
SIOB_D		.EQU	SIOA_D+1 ;$01
SIOB_C		.EQU	SIOA_D+3 ;$03

SIO_IV          .EQU    2

SIO_PREINIT:
	LD	BC,SIO_DISPATCH	; BC := DISPATCH ADDRESS
	CALL	CIO_ADDENT
        RET

SIO_DISPATCH:
	; DISPATCH TO FUNCTION HANDLER
	PUSH	HL			; SAVE HL FOR NOW
	LD	A,B			; GET FUNCTION
	AND	$0F			; ISOLATE LOW NIBBLE
	RLCA				; X 2 FOR WORD OFFSET INTO FUNCTION TABLE
	LD	HL,SIO_FTBL		; START OF FUNC TABLE
	CALL	ADDHLA			; HL := ADDRESS OF ADDRESS OF FUNCTION
	LD	A,(HL)			; DEREF HL
	INC	HL			; ...
	LD	H,(HL)			; ...
	LD	L,A			; ... TO GET ADDRESS OF FUNCTION
	EX	(SP),HL			; RESTORE HL & PUT FUNC ADDRESS -> (SP)
	RET				; EFFECTIVELY A JP TO TGT ADDRESS

SIO_FTBL:
	.DW	SIO_IN_A
	.DW	SIO_OUT_A
	.DW	SIO_IST_A
	.DW	SIO_OST_A
	.DW	SIO_INITDEV
	.DW	SIO_QUERY
	.DW	SIO_DEVICE

SIO_INIT:
;	Initialise SIO
		LD	A,$00
		OUT	(SIOA_C),A
		LD	A,$18
		OUT	(SIOA_C),A

		LD	A,$04
		OUT	(SIOA_C),A
		LD	A,$C4
		OUT	(SIOA_C),A

		LD	A,$01
		OUT	(SIOA_C),A
		LD	A,$18
		OUT	(SIOA_C),A

		LD	A,$03
		OUT	(SIOA_C),A
		LD	A,$E1
		OUT	(SIOA_C),A

		LD	A,$05
		OUT	(SIOA_C),A
		LD	A,RTS_LOW
		OUT	(SIOA_C),A

		LD	A,$00
		OUT	(SIOB_C),A
		LD	A,$18
		OUT	(SIOB_C),A

		LD	A,$04
		OUT	(SIOB_C),A
		LD	A,$C4
		OUT	(SIOB_C),A

		LD	A,$01
		OUT	(SIOB_C),A
		LD	A,$18
		OUT	(SIOB_C),A

		LD	A,$02
		OUT	(SIOB_C),A
		LD	A,SIO_IV		; INTERRUPT VECTOR ADDRESS
		OUT	(SIOB_C),A

		LD	A,$03
		OUT	(SIOB_C),A
		LD	A,$E1
		OUT	(SIOB_C),A

		LD	A,$05
		OUT	(SIOB_C),A
		LD	A,RTS_LOW
		OUT	(SIOB_C),A

		LD	(serABufUsed),A
		LD	(serBBufUsed),A
		LD	HL,serABuf
		LD	(serAInPtr),HL
		LD	(serARdPtr),HL

		LD	HL,serBBuf
		LD	(serBInPtr),HL
		LD	(serBRdPtr),HL

;	LD	HL,serialInt		; ADDress of serial interrupt.
;	LD	($40),HL

		; Interrupt vector in page FF
;		LD	A,$FF
;		LD	I,A

                LD	HL,serialInt
                LD	(HBX_IVT + SIO_IV),HL

		IM	2
		EI				; Enable interrupts

                RET

; ISR

serialInt:	PUSH	AF
		PUSH	HL

		; Check if there is a char in channel A
		; If not, there is a char in channel B
		SUB	A
		OUT 	(SIOA_C),A
		IN   	A,(SIOA_C)	; Status byte D2=TX Buff Empty, D0=RX char ready
		RRCA			; Rotates RX status into Carry Flag,
		JR	NC, serialIntB

serialIntA:
		LD	HL,(serAInPtr)
		INC	HL
		LD	A,L
		CP	serAInMask
		JR	NZ, notAWrap
		LD	HL,serABuf
notAWrap:
		LD	(serAInPtr),HL
		IN	A,(SIOA_D)
		LD	(HL),A

		LD	A,(serABufUsed)
		INC	A
		LD	(serABufUsed),A
		CP	SER_FULLSIZE
		JR	C,rtsA0
	        LD   	A,$05
		OUT  	(SIOA_C),A
	        LD   	A,RTS_HIGH
		OUT  	(SIOA_C),A
rtsA0:
		POP	HL
		POP	AF
		EI
		RETI

serialIntB:
		LD	HL,(serBInPtr)
		INC	HL
		LD	A,L
		CP	serBInMask
		JR	NZ, notBWrap
		LD	HL,serBBuf
notBWrap:
		LD	(serBInPtr),HL
		IN	A,(SIOB_D)
		LD	(HL),A

		LD	A,(serBBufUsed)
		INC	A
		LD	(serBBufUsed),A
		CP	SER_FULLSIZE
		JR	C,rtsB0
	        LD   	A,$05
		OUT  	(SIOB_C),A
	        LD   	A,RTS_HIGH
		OUT  	(SIOB_C),A
rtsB0:
		POP	HL
		POP	AF
		EI
		RETI

; input character from port A

SIO_IN_A:       PUSH    HL

waitForCharA:
		LD	A,(serABufUsed)
		CP	$00
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
		JR	NC,rtsA1
	        LD   	A,$05
		OUT  	(SIOA_C),A
	        LD   	A,RTS_LOW
		OUT  	(SIOA_C),A
rtsA1:
		LD	A,(HL)
		EI

		POP	HL

		RET	; Char ready in A

; output character to port A

SIO_OUT_A:
		PUSH	AF

conoutA1:	CALL	SIO_IST_A	; See if SIO channel A is finished transmitting
		JR	Z,conoutA1	; Loop until SIO flag signals ready
		POP	AF		; RETrieve character
		OUT	(SIOA_D),A	; OUTput the character
		RET

; check output status A

SIO_OST_A:
		SUB	A
		OUT 	(SIOA_C),A
		IN   	A,(SIOA_C)	; Status byte D2=TX Buff Empty, D0=RX char ready
		RRCA			; Rotates RX status into Carry Flag,
		BIT  	1,A		; Set Zero flag if still transmitting character
        	RET

; check input status A

SIO_IST_A:
		LD	A,(serABufUsed)
		CP	$0
		RET

SIO_QUERY:
	LD	E,0
	LD	D,0
	XOR	A			; SIGNAL SUCCESS
	RET				; DONE

SIO_DEVICE:
	LD	D,CIODEV_UART	; D := DEVICE TYPE
	LD	E,(IY)		; E := PHYSICAL UNIT
	XOR	A		; SIGNAL SUCCESS
	RET

SIO_INITDEV:
        RET

serABuf:	.ds	SER_BUFSIZE	; SIO A Serial buffer
serAInPtr	.DW	00h
serARdPtr	.DW	00h
serABufUsed	.DB	00h
serBBuf:	.ds	SER_BUFSIZE	; SIO B Serial buffer
serBInPtr	.DW	00h
serBRdPtr	.DW	00h
serBBufUsed	.DB	00h

serAInMask      .EQU     serAInPtr&$FF
serBInMask      .EQU     serBInPtr&$FF
