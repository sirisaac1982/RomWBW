; SMB standard
FDMEDIA         .EQU    FDM144          ; FDM720, FDM144, FDM360, FDM120 (ONLY RELEVANT IF FDENABLE = TRUE)
FDMEDIAALT      .EQU    FDM720          ; ALTERNATE MEDIA TO TRY, SAME CHOICES AS ABOVE (ONLY RELEVANT IF FDMAUTO = TRUE)
FDMAUTO         .EQU    TRUE            ; SELECT BETWEEN MEDIA OPTS ABOVE AUTOMATICALLY

FDSPECIAL       .EQU    FALSE           ; Use special mode instead oF AT/ESA mode

VFDTERMENABLE   .EQU    FALSE	        ; Enable VFD Terminal

SIOENABLE       .EQU    FALSE           ; Z80 SIO/2 Disable
ACIAENABLE      .EQU    TRUE            ; Z80 ACIA Enable
INTTYPE         .EQU    IT_Z80IM1       ; INTERRUPT HANDLING TYPE (IT_NONE, IT_SIMH, IT_Z180, IT_CTC, ...)