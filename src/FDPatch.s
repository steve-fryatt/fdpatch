REM >FDPatchSrc
REM
REM FilerDirPatch Module
REM (c) Stephen Fryatt, 2001
REM
REM Needs ExtBasAsm to assemble.
REM 26/32 bit neutral

version$="1.10"
save_as$="FDPatch"

LIBRARY "<Reporter$Dir>.AsmLib"

PRINT "Assemble debug? (Y/N)"
REPEAT
 g%=GET
UNTIL (g% AND &DF)=ASC("Y") OR (g% AND &DF)=ASC("N")
debug%=((g% AND &DF)=ASC("Y"))

ON ERROR PRINT REPORT$;" at line ";ERL : END

REM --------------------------------------------------------------------------------------------------------------------
REM Set up workspace

workspace_size%=0 : REM This is updated.

task_handle%=FNworkspace(workspace_size%,4)
block%=FNworkspace(workspace_size%,256)

REM --------------------------------------------------------------------------------------------------------------------

DIM time% 5, date% 256
?time%=3
SYS "OS_Word",14,time%
SYS "Territory_ConvertDateAndTime",-1,time%,date%,255,"(%dy %m3 %ce%yr)" TO ,date_end%
?date_end%=13

REM --------------------------------------------------------------------------------------------------------------------

code_space%=4000
DIM code% code_space%

pass_flags%=%11100

IF debug% THEN PROCReportInit(200)


FOR pass%=pass_flags% TO pass_flags% OR %10 STEP %10
L%=code%+code_space%
O%=code%
P%=0
IF debug% THEN PROCReportStart(pass%)
[OPT pass%
EXT 1
          EQUD      0                   ; Offset to task code
          EQUD      init_code           ; Offset to initialisation code
          EQUD      final_code          ; Offset to finalisation code
          EQUD      0                   ; Offset to service-call handler
          EQUD      title_string        ; Offset to title string
          EQUD      help_string         ; Offset to help string
          EQUD      0                   ; Offset to command table
          EQUD      0                   ; SWI Chunk number
          EQUD      0                   ; Offset to SWI handler code
          EQUD      0                   ; Offset to SWI decoding table
          EQUD      0                   ; Offset to SWI decoding code
          EQUD      0                   ; MessageTrans file
          EQUD      module_flags        ; Offset to module flags

; ======================================================================================================================

.module_flags
          EQUD      1                   ; 32-bit compatible

; ======================================================================================================================

.title_string
          EQUZ      "FilerDirPatch"
          ALIGN

.help_string
          EQUS      "Filer Dir Patch"
          EQUB      9
          EQUS      version$
          EQUS      " "
          EQUS      $date%
          EQUZ      " © Stephen Fryatt, 2001"
          ALIGN

; ======================================================================================================================

.init_code
          STMFD     R13!,{R14}

; Claim 296 bytes of workspace for ourselves and store the pointer in our private workspace.
; This space is used for everything; both the module 'back-end' and the WIMP task.

          MOV       R0,#6
          MOV       R3,#workspace_size%
          SWI       "XOS_Module"
          BVS       init_exit
          STR       R2,[R12]
          MOV       R12,R2

; Initialise the workspace that was just claimed.


; Enumerate the tasks and apply a filter to the filer.

          MOV       R0,#0
          STR       R0,[R12,#task_handle%]

.init_find_loop
          ADRW      R1,block%
          MOV       R2,#16
          SWI       "XTaskManager_EnumerateTasks"

          ADRW      R3,block%
          TEQ       R1,R3
          BEQ       init_find_loop_end

          LDR       R3,[R3,#4]
          ADR       R4,task_name

.init_find_compare_loop
          LDRB      R5,[R3],#1
          LDRB      R6,[R4],#1
          TEQ       R5,R6
          BNE       init_find_loop_end
          TEQ       R6,#0
          BNE       init_find_compare_loop

          LDR       R3,[R12,#block%]
          STR       R3,[R12,#task_handle%]

          B         init_find_loop_exit

.init_find_loop_end
          CMP       R0,#0
          BGE       init_find_loop

.init_find_loop_exit
          LDR       R3,[R12,#task_handle%]
          TEQ       R3,#0                                   ; If task handle is zero, there wasn't a Filer running...
          BEQ       init_exit                               ; Currently we continue to run but register no filter. ;-(

.init_register_filter
          ADR       R0,title_string
          ADR       R1,filter_code
          MOV       R2,R12
          LDR       R4,poll_mask

          SWI       "XFilter_RegisterPostFilter"

.init_exit
          LDMFD     R13!,{PC}

; ----------------------------------------------------------------------------------------------------------------------

.poll_mask
          EQUD      &FFFFFFFF EOR (1<<6)+(1<<9)

.task_name
          EQUZ      "Filer"
          ALIGN

; ----------------------------------------------------------------------------------------------------------------------
.final_code
          STMFD     R13!,{R14}
          LDR       R12,[R12]

.final_deregister_filter
          LDR       R3,[R12,#task_handle%]
          TEQ       R3,#0
          BEQ       final_release_workspace

          ADR       R0,title_string
          ADR       R1,filter_code
          MOV       R2,R12
          LDR       R4,poll_mask
          SWI       "XFilter_DeRegisterPostFilter"

.final_release_workspace
          TEQ       R12,#0
          BEQ       final_exit
          MOV       R0,#7
          MOV       R2,R12
          SWI       "XOS_Module"

.final_exit
          LDMFD     R13!,{PC}

; ======================================================================================================================

.filter_code
          STMFD     R13!,{R0-R5,R14}

.filter_mouse_click
          TEQ       R0,#6
          BNE       filter_menu_selection

          ; Test if the menu button was clicked.

          LDR       R2,[R1,#8]
          TEQ       R2,#2
          BNE       filter_exit

          ; Get the window information

          LDR       R3,[R1,#12]
          ADRW      R2,block%
          STR       R3,[R2,#0]

          ORR       R1,R2,#1
          SWI       "XWimp_GetWindowInfo"

          LDR       R3,[R2,#76]
          MOV       R4,R2

.filter_mouse_loop1
          LDRB      R5,[R3],#1
          STRB      R5,[R4],#1

          TEQ       R5,#0
          BNE       filter_mouse_loop1

          SUB       R4,R4,#1
          MOV       R5,#ASC(".")
          STRB      R5,[R4],#1

          ADR       R3,directory_name

.filter_mouse_loop2
          LDRB      R5,[R3],#1
          STRB      R5,[R4],#1

          TEQ       R5,#0
          BNE       filter_mouse_loop2

          B         filter_exit

.filter_menu_selection
          TEQ       R0,#9
          BNE       filter_exit

          LDR       R2,[R1,#0]
          TEQ       R2,#5
          BNE       filter_exit

          LDR       R2,[R1,#4]
          MVN       R0,#NOT-1
          TEQ       R2,R0
          BNE       filter_exit

          MOV       R0,#8
          ADRW      R1,block%
          MOV       R2,#0
          SWI       "XOS_File"

.filter_exit
          LDMFD     R13!,{R0-R5,R14}
          TEQ       PC,PC
          MOVNES    PC,R14
          MSR       CPSR_f,#0
          MOV       PC,R14

; ----------------------------------------------------------------------------------------------------------------------

.directory_name
          EQUZ      "Directory"
          ALIGN

; ======================================================================================================================
]
IF debug% THEN
[OPT pass%
          FNReportGen
]
ENDIF
NEXT pass%

SYS "OS_File",10,"<Basic$Dir>."+save_as$,&FFA,,code%,code%+P%

END



DEF FNworkspace(RETURN size%,dim%)
LOCAL ptr%
ptr%=size%
size%+=dim%
=ptr%

