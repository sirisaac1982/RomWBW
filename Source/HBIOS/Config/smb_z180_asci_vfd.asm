; SMB with SIO/2 and VFD
CPUOSC          .EQU    18432000        ; CPU OSC FREQ - must be compatible w/ baud rate divisor
Z180_CLKDIV     .EQU    1               ; CPU clock multiplier: 0=OSC/2, 1=OSC, 2=OSC*2

FDMEDIA         .EQU    FDM144          ; FDM720, FDM144, FDM360, FDM120 (ONLY RELEVANT IF FDENABLE = TRUE)
FDMEDIAALT      .EQU    FDM720          ; ALTERNATE MEDIA TO TRY, SAME CHOICES AS ABOVE (ONLY RELEVANT IF FDMAUTO = TRUE)
FDMAUTO         .EQU    TRUE            ; SELECT BETWEEN MEDIA OPTS ABOVE AUTOMATICALLY

FDSPECIAL       .EQU    FALSE           ; Use special mode instead oF AT/ESA mode

VFDTERMENABLE   .EQU    TRUE	; Enable VFD Terminal

SMB_Z180        .EQU    TRUE
Z180_BASE       .EQU    $C0

ASCIENABLE      .EQU    TRUE

ACIAENABLE      .EQU    FALSE           ; Z80 ACIA Enable
SIOENABLE       .EQU    FALSE           ; Z80 SIO/2 Enable
INTTYPE         .EQU    IT_Z180       ; INTERRUPT HANDLING TYPE (IT_NONE, IT_SIMH, IT_Z180, IT_CTC, ...)

#INCLUDE "z180.inc"
