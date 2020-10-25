; Copyright 2001-2013, Stephen Fryatt (info@stevefryatt.org.uk)
;
; This file is part of FilerDirPatch:
;
;   http://www.stevefryatt.org.uk/software/
;
; Licensed under the EUPL, Version 1.2 only (the "Licence");
; You may not use this work except in compliance with the
; Licence.
;
; You may obtain a copy of the Licence at:
;
;   http://joinup.ec.europa.eu/software/page/eupl
;
; Unless required by applicable law or agreed to in
; writing, software distributed under the Licence is
; distributed on an "AS IS" basis, WITHOUT WARRANTIES
; OR CONDITIONS OF ANY KIND, either express or implied.
;
; See the Licence for the specific language governing
; permissions and limitations under the Licence.

; FDPatch.s
;
; FilerDirPatch Module Source
;
; REM 26/32 bit neutral

	GET	$Include/AsmSWINames

; ---------------------------------------------------------------------------------------------------------------------
; Set up the Module Workspace

WS_BlockSize		*	256

			^	0
WS_TaskHandle		#	4
WS_Block		#	WS_BlockSize

WS_Size			*	@

; ======================================================================================================================
; Module Header

	AREA	Module,CODE,READONLY
	ENTRY

ModuleHeader
	DCD	0				; Offset to task code
	DCD	InitCode			; Offset to initialisation code
	DCD	FinalCode			; Offset to finalisation code
	DCD	0				; Offset to service-call handler
	DCD	TitleString			; Offset to title string
	DCD	HelpString			; Offset to help string
	DCD	0				; Offset to command table
	DCD	0				; SWI Chunk number
	DCD	0				; Offset to SWI handler code
	DCD	0				; Offset to SWI decoding table
	DCD	0				; Offset to SWI decoding code
	DCD	0				; MessageTrans file
	DCD	ModuleFlags			; Offset to module flags

; ======================================================================================================================

ModuleFlags
	DCD	1				; 32-bit compatible

; ======================================================================================================================

TitleString
	DCB	"FilerDirPatch",0
	ALIGN

HelpString
	DCB	"Filer Dir Patch",9,$BuildVersion," (",$BuildDate,") ",169," Stephen Fryatt, 2001-",$BuildDate:RIGHT:4,0
	ALIGN

; ======================================================================================================================

InitCode
	STMFD	R13!,{R14}

; Claim 296 bytes of workspace for ourselves and store the pointer in our private workspace.
; This space is used for everything; both the module 'back-end' and the WIMP task.

	MOV	R0,#6
	MOV	R3,#WS_Size
	SWI	XOS_Module
	BVS	InitExit
	STR	R2,[R12]
	MOV	R12,R2

; Initialise the workspace that was just claimed.

	MOV	R0,#0
	STR	R0,[R12,#WS_TaskHandle]

; Enumerate the tasks and apply a filter to the filer.

InitFindLoop
	ADD	R1,R12,#WS_Block
	MOV	R2,#16
	SWI	XTaskManager_EnumerateTasks

	ADD	R3,R12,#WS_Block
	TEQ	R1,R3
	BEQ	InitFindLoopEnd

	LDR	R3,[R3,#4]
	ADR	R4,FilterTaskName

InitFindCompareLoop
	LDRB	R5,[R3],#1
	LDRB	R6,[R4],#1
	TEQ	R5,R6
	BNE	InitFindLoopEnd
	TEQ	R6,#0
	BNE	InitFindCompareLoop

	LDR	R3,[R12,#WS_Block]
	STR	R3,[R12,#WS_TaskHandle]

	B	InitFindLoopExit

InitFindLoopEnd
	CMP	R0,#0
	BGE	InitFindLoop

InitFindLoopExit
	LDR	R3,[R12,#WS_TaskHandle]
	TEQ	R3,#0					; If task handle is zero, there wasn't a Filer running...
	BEQ	InitExit				; Currently we continue to run but register no filter. ;-(

InitRegisterFilter
	ADR	R0,TitleString
	ADR	R1,FilterCode
	MOV	R2,R12
	LDR	R4,FilterPollMask

	SWI	XFilter_RegisterPostFilter

InitExit
	LDMFD	R13!,{PC}

; ----------------------------------------------------------------------------------------------------------------------

FilterPollMask
	DCD	&FFFFFFFF :EOR: ((1<<6)+(1<<9))

FilterTaskName
	DCB	"Filer",0
	ALIGN

; ----------------------------------------------------------------------------------------------------------------------

FinalCode
	STMFD	R13!,{R14}
	LDR	R12,[R12]

FinalDeregisterFilter
	LDR	R3,[R12,#WS_TaskHandle]
	TEQ	R3,#0
	BEQ	FinalReleaseWorkspace

	ADR	R0,TitleString
	ADR	R1,FilterCode
	MOV	R2,R12
	LDR	R4,FilterPollMask
	SWI	XFilter_DeRegisterPostFilter

FinalReleaseWorkspace
	TEQ	R12,#0
	BEQ	FinalExit
	MOV	R0,#7
	MOV	R2,R12
	SWI	XOS_Module
FinalExit
	LDMFD	R13!,{PC}

; ======================================================================================================================

FilterCode
	STMFD	R13!,{R0-R5,R14}

FilterMouseClick
	TEQ	R0,#6
	BNE	FilterMenuSelection

	; Test if the menu button was clicked.

	LDR	R2,[R1,#8]
	TEQ	R2,#2
	BNE	FilterExit

	; Get the window information

	LDR	R3,[R1,#12]
	ADD	R2,R12,#WS_Block
	STR	R3,[R2,#0]

	ORR	R1,R2,#1
	SWI	XWimp_GetWindowInfo

	LDR	R3,[R2,#76]
	MOV	R4,R2

FilterMouseLoop1
	LDRB	R5,[R3],#1
	STRB	R5,[R4],#1

	TEQ	R5,#0
	BNE	FilterMouseLoop1

	SUB	R4,R4,#1
	MOV	R5,#"."
	STRB	R5,[R4],#1

	ADR	R3,DirectoryName

FilterMouseLoop2
	LDRB	R5,[R3],#1
	STRB	R5,[R4],#1

	TEQ	R5,#0
	BNE	FilterMouseLoop2

	B	FilterExit

FilterMenuSelection
	TEQ	R0,#9
	BNE	FilterExit

	LDR	R2,[R1,#0]
	TEQ	R2,#5
	BNE	FilterExit

	LDR	R2,[R1,#4]
	MOV	R0,#-1
	TEQ	R2,R0
	BNE	FilterExit

	MOV	R0,#8
	ADD	R1,R12,#WS_Block
	MOV	R2,#0
	SWI	XOS_File

FilterExit
	LDMFD	R13!,{R0-R5,R14}
	TEQ	R0,R0
	TEQ	PC,PC
	MOVNES	PC,R14
	MSR	CPSR_f,#0
	MOV	PC,R14

; ----------------------------------------------------------------------------------------------------------------------

DirectoryName
	DCB	"Directory",0
	ALIGN
          
	END

