// prim.intel32.asm
//
// This file contains asm-coded functions "callable" directly
// from Mythryl via the runtime::asm API defined in
//
//     src/lib/core/init/runtime.api
//
// These assembly code functions may then request services from
// the C level by passing one of the request codes defined in
//
//     src/c/h/asm-to-c-request-codes.h
//
// to
//
//     src/c/main/run-mythryl-code-and-runtime-eventloop.c
//
// which then dispatches on them to various fns throughout the C runtime.
//
//
//
// Motivation and theory of operation:
// ===================================
//
// The C layer and the Mythryl layer use completely different register conventions.
//
// The C layer follows host gcc conventions, which on x86 means
//
// 	Caller save registers: eax, ecx, edx
// 	Callee save registers: ebx, esi, edi, and ebp.
//	Save frame pointer (ebx) first to match standard function prelude
// 	Floating point state is caller-save.
// 	Arguments passed on stack.  Rightmost argument pushed first.
// 	Word-sized result returned in %eax.
//	On Darwin, stack frame must be multiple of 16 bytes
//
// The Mythryl layer, by contrast, follows completely different rules:
//
//      EAX - temp1 (see the code generator, intel32/intel32.pkg)
//      EBX - misc0
//      ECX - misc1
//      EDX - misc2
//      ESI - standard fate (fate, see runtime-base.h)
//      EBP - standard argument (argument)
//      EDI - heap_allocation_pointer		Heap memory is allocated by advancing this pointer.
//      ESP - C stack pointer			Never pushed or popped during normal Mythryl code execution.
//      EIP - program counter (program_counter)
//
//      The C stack (pointed to by ESP) is never pushed or popped at all
//      during normal execution of Mythryl code.  (Mythryl allocates all
//      closures on the heap, closures being the closest Mythryl analogue
//      to C stackframes.)  Mythryl *does* make use of an 8KB scratch area
//      on top of the C stack, accessed via ESP, in particular to hold
//      values such as heap_allocation_limit which are kept in registers
//      on architectures with more general-purpose registers than X86,
//      also more generally to hold codetemps spilled by the regor.
//
//      The general model is that every function takes and returns exactly
//      one argument (often a tuple containing sub-arguments), which is
//      handled by putting the function (technically, closure) called
//	in ESI and its argument in EBP.
//
//      (In practice, whenever the calling and called fn are both known, the
//      compiler makes strenuous efforts to pass everything in registers and
//      avoid explicitly constructing the argument tuple. But the ESI/EBP
//      model is the one the compiler falls back to whenever its lacks enough
//      information to do something more efficient.  The application programmer
//      can always trust that the result of running the code will, performance
//      aside, look exactly as though the ESI/EBP model had been used throughout.)
//
// The problem to be solved in this file is that gcc-compiled C fns know
// how to call other gcc-compiled fns, and Mythryl-compiled Mythryl fns know
// how to call other Mythryl-compiled fns, but in general C doesn't know how
// to call Mythryl and Mythryl doesn't know how to call C. [1]  So the assembly
// code in this file handles the transitions between these two worlds.
//
// Our general model is that C code calls Mythryl which runs and then returns to C.
//
// In particular, Mythryl 'calls' to the C layer are actually implemented by doing
// a return instruction with the request code as the "return result" of the call to
// Mythryl.  Since Mythryl state is all in the heap, not on the C stack, doing a
// 'return' doesn't lose us much state, and picking up Mythryl execution again via
// another 'call' is pretty simple.
//
// (Note that Mythryl code, being stackless and based on "continuation passing style",
// does not really have the call/return distinction anyhow -- everything is a call,
// a return is just a call to some "continuation" aka "fate" passed in as an arg.
// Given that calls and returns are treated as equivalent, doing a "call" to C via
// a "return" instruction doesn't seem particularly odd in context.)
//
// When running at the C level, we use a  Task  record to hold the state of the
// Mythryl-level computation, in particular its registers.
//
// The conceptually critical execution path is:
//
//    system_run_mythryl_task_and_runtime_eventloop__may_heapclean() in   src/c/main/run-mythryl-code-and-runtime-eventloop.c
//    does
//
//        int request =  asm_run_mythryl_task (Task* task);
//
//    Code in this file then:
//        1) Pushes the callee-save C registers
//        2)  Pushes 8K of scratch space on the C stack.
//        3)   Loads the data registers per the given 'task' record.
//        4)   Loads the program counter from the 'task' record via a jump.
//        5)     Mythryl code executes until it is time to make a 'call' to the C level by doing a 'return' with return address set to 'set_request'.
//               Any arguments are passed as a tuple in the Mythryl argument register EBP.
//        6)   Saves the Mythryl registers back into the given 'task' record. The argument tuple thus winds up as task->argument
//	  7)  Pops the 8K scratch buffer.
//	  8) Pops the callee-save C registers.
//        9) 'returns' the request code
//
//    system_run_mythryl_task_and_runtime_eventloop__may_heapclean()
//        handles the request (fetching any needed args from task->argument)
//        and then loops around and repeats the cycle, with any return values
//        hacked into task->argument and thus restored into EBP by step 3) above,
//        making them available at the Mythryl level.
//
// This file also includes code to support signal handling, boostrapping (find_cfun),
// and implement a few speed-critical fns (make_typeagnostic_rw_vector_asm,
// make_float64_rw_vector_asm, make_unt8_rw_vector, make_string, make_vector_asm).


////////////////////////////////////////////////////////////////////////
// Note [1]  Matthias Blume's 'NLFFIGEN' project supports calling C directly
//           from Mythryl, but it came along late and is not normally used
//           by core code in the system.

////////////////////////////////////////////////////////////////////////
// History:	
//     This was derived from I386.prim.s, by Mark Leone (mleone@cs.cmu.edu)
//     Completely rewritten and changed to use assyntax.h, by Lal George.


/*
###             "He who doesn't hack assembly
###              language as a youth has no heart.
###              He who does as an adult has no brain."
###
###                           --- John Moore
*/

		
#include "assyntax.h"
#include "runtime-base.h"
#include "asm-base.h"
#include "runtime-values.h"
#include "heap-tags.h"
#include "asm-to-c-request-codes.h"
#include "runtime-configuration.h"
	
#if defined(OPSYS_DARWIN)
    //
    // Note: although the MacOS assembler claims to be the GNU assembler,
    // it appears to be an old version (1.38), which uses different
    // alignment directives.			[ This comment might date from the 1990s... -- 2012-10-10 CrT ]
    //	
    #undef ALIGNTEXT4
    #undef ALIGNDATA4
    #define ALIGNTEXT4	.align 2
    #define ALIGNDATA4	.align 2
#endif


// The 386 registers are used as follows:
//


// Stack frame:
//
#define temp			EAX
#define misc0			EBX
#define misc1			ECX
#define misc2			EDX
#define stdfate			ESI				// Needs to match   stdfate		     in   src/lib/compiler/back/low/main/intel32/backend-lowhalf-intel32-g.pkg
#define stdarg			EBP				// Needs to match   stdarg		     in   src/lib/compiler/back/low/main/intel32/backend-lowhalf-intel32-g.pkg

#define heap_allocation_pointer	EDI				// We allocate ram just by advancing this pointer.  We use this very heavily -- every 10 instructions or so.
								// Needs to match   heap_allocation_pointer  in   src/lib/compiler/back/low/main/intel32/backend-lowhalf-intel32-g.pkg

#define stackptr		ESP				// Needs to match   stackptr		     in   src/lib/compiler/back/low/main/intel32/backend-lowhalf-intel32-g.pkg

// Other register uses:	
//
#define creturn 		EAX

// Stack frame:
//								// REGOFF(a,b) == *(a+b)
#define tempmem			REGOFF(0,ESP)
#define base_pointer		REGOFF(4,ESP)			// Needs to match   base_pointer                  in   src/lib/compiler/back/low/main/intel32/backend-lowhalf-intel32-g.pkg
#define exnfate			REGOFF(8,ESP)			// Needs to match   exception_handler_register    in   src/lib/compiler/back/low/main/intel32/backend-lowhalf-intel32-g.pkg

#define heap_allocation_limit	REGOFF(12,ESP)			// heapcleaner gets run when heap_allocation_pointer reaches this point.
								// Needs to match   heap_allocation_limit    in   src/lib/compiler/back/low/main/intel32/backend-lowhalf-intel32-g.pkg

#define program_counter		REGOFF(16,ESP)			// Needs?to match   heapcleaner_link	     in   src/lib/compiler/back/low/main/intel32/backend-lowhalf-intel32-g.pkg

#define unused_1		REGOFF(20,ESP)

#define heap_changelog_ptr	REGOFF(24,ESP)			// Every (pointer) update to the heap gets logged to this heap-allocated cons-cell list.
								// (The heapcleaner scans this list to detect intergenerational pointers.)
								// Needs to match   heap_changelog_pointer   in   src/lib/compiler/back/low/main/intel32/backend-lowhalf-intel32-g.pkg

#define current_thread_ptr	REGOFF(28,ESP)

#define run_heapcleaner_ptr	REGOFF(32,ESP)			// Needs to match   run_heapcleaner__offset  in  src/lib/compiler/back/low/main/intel32/machine-properties-intel32.pkg
								// This ptr is used to invoke the heapcleaner by code generated in   src/lib/compiler/back/low/main/nextcode/emit-treecode-heapcleaner-calls-g.pkg
								// This ptr is set by asm_run_mythryl_task (below) to point to call_heapcleaner_asm (below) which returns a REQUEST_HEAPCLEANING to
								// run_mythryl_task_and_runtime_eventloop__may_heaplcean ()  in   src/c/main/run-mythryl-code-and-runtime-eventloop.c
								// which will call   clean_heap	()            in   src/c/heapcleaner/call-heapcleaner.c
#define unused_2		REGOFF(36,ESP)
#define eaxSpill		REGOFF(40,ESP) 			// eax=0
#define	ecxSpill		REGOFF(44,ESP)			// ecx=1
#define	edxSpill		REGOFF(48,ESP)			// edx=2
#define	ebxSpill		REGOFF(52,ESP)			// ebx=3
#define	espSpill		REGOFF(56,ESP)			// esp=4
#define	ebpSpill		REGOFF(60,ESP)			// ebp=5
#define	esiSpill		REGOFF(64,ESP)			// esi=6
#define	ediSpill		REGOFF(68,ESP)			// edi=7
#define stdlink			REGOFF(72,ESP)
#define	stdclos			REGOFF(76,ESP)

#define espsave		REGOFF(500,ESP)
#define reqsave		REGOFF(504,ESP)				// I don't understand the layout of the 8192-byte stackframe, but we use this slot only briefly right before popping it, so this should be safe. -- 2012-10-10 CrT

#define task_offset 176						// 			Must    match   task_offset            in   src/lib/compiler/back/low/main/intel32/machine-properties-intel32.pkg
#define task_ptr	REGOFF(task_offset, ESP)
#define freg8           184					// Doubleword aligned
#define	freg9           192
#define freg31          368					// 152 + (31-8)*8
#define	fpTempMem	376					// freg31 + 8
#define SpillAreaStart	512					// Starting offset.	Must    match   initial_spill_offset   in   src/lib/compiler/back/low/main/intel32/machine-properties-intel32.pkg
#define LIB7_FRAME_SIZE	(8192)					// 			Must(?) match   spill_area_size        in   src/lib/compiler/back/low/main/intel32/machine-properties-intel32.pkg

#define	via

	SEG_DATA
	ALIGNDATA4

//	GLOBL CSYM(LIB7_intel32Frame)
// LABEL(CSYM(LIB7_intel32Frame)) 					// Pointer to the ml frame (gives C access to heap_allocation_limit)
	D_LONG 0		


#include "task-and-hostthread-struct-field-offsets--autogenerated.h"



#define cresult	EAX


// MOVE_FROM_VIA_TO copies one memory location to another, using a specified temporary.

#define MOVE_FROM_VIA_TO(src,tmp,dest)	\
	MOV_L(src, tmp);	\
	MOV_L(tmp, dest)

#define CONTINUE				\
	JMP(CODEPTR(stdfate))

// 2011-02-01 CrT: I'm guessing 'JB(9f)'  branches to 9: with 'f' for 'forward',
//                 and that     'JMP(1b)' branches to 1: with 'b' for 'backward'.
#define CHECKLIMIT							\
 1:;									\
	MOVE_FROM_VIA_TO(stdlink, temp, program_counter);		\
	CMP_L(heap_allocation_limit, heap_allocation_pointer);		\
	JB(9f);								\
	CALL(CSYM(call_heapcleaner_asm));				\
	JMP(1b);							\
 9:

// *********************************************************************
	SEG_TEXT
	ALIGNTEXT4

// This address will be placed in the fate register
// before invoking a Mythryl signal handler.
//
ALIGNED_ENTRY( return_from_signal_handler_asm)
	MOV_L( CONST(HEAP_VOID), stdlink)
	MOV_L( CONST(HEAP_VOID), stdclos)
	MOV_L( CONST(HEAP_VOID), program_counter)
	MOV_L( CONST(REQUEST_RETURN_FROM_SIGNAL_HANDLER), temp)
	JMP(CSYM(set_request))


// This address will occupy the third and last slot
// in the argument tuple handed to a Mythryl signal handler.
// Here we pick up execution from where we were
// before we went off to handle an interprocess signal:
// This is a standard two-argument function, thus the closure is in fate.
//
ENTRY( resume_after_handling_signal )
	MOV_L( CONST( REQUEST_RESUME_AFTER_RUNNING_SIGNAL_HANDLER ), temp)
	JMP( CSYM(set_request))

// return_from_software_generated_periodic_event_handler_asm:
// The return fate for the Mythryl
// software generated periodic events handler.
//
ALIGNED_ENTRY( return_from_software_generated_periodic_event_handler_asm )
	MOV_L( CONST(HEAP_VOID), stdlink)
	MOV_L( CONST(HEAP_VOID), stdclos)
	MOV_L( CONST(HEAP_VOID), program_counter)
	MOV_L( CONST(REQUEST_RETURN_FROM_SOFTWARE_GENERATED_PERIODIC_EVENT_HANDLER), temp)
	JMP(CSYM(set_request))

// Here we pick up execution from where we were
// before we went off to handle a software generated
// periodic event:
//
ENTRY( resume_after_handling_software_generated_periodic_event )
	MOV_L(CONST(REQUEST_RESUME_AFTER_RUNNING_SOFTWARE_GENERATED_PERIODIC_EVENT_HANDLER), temp)
	JMP( CSYM(set_request) )

// Exception handler for Mythryl functions called from C.
// We delegate uncaught-exception handling to
//     handle_uncaught_exception  in  src/c/main/runtime-exception-stuff.c
// We get invoked courtesy of being stuffed into
//     task->exception_fate
// in  src/c/main/run-mythryl-code-and-runtime-eventloop.c
// and src/c/heapcleaner/import-heap.c
//
ALIGNED_ENTRY(handle_uncaught_exception_closure_asm)
	MOVE_FROM_VIA_TO(stdlink,temp,program_counter)
	MOV_L(CONST(REQUEST_HANDLE_UNCAUGHT_EXCEPTION), temp)
	JMP(CSYM(set_request))


// Here to return to                                     run_mythryl_task_and_runtime_eventloop__may_heapclean  in   src/c/main/run-mythryl-code-and-runtime-eventloop.c
// and thence to whoever called it.  If the caller was   load_and_run_heap_image__may_heapclean			in   src/c/main/load-and-run-heap-image.c
// this will return us to                                main							in   src/c/main/runtime-main.c
// which will print stats
// and exit(), but                   if the caller was   no_args_entry or some_args_entry       		in   src/c/lib/ccalls/ccalls-fns.c
// then we may have some scenario
// where C calls Mythryl which calls C which ...
// and we may just be unwinding one level.
//    The latter can only happen with the
// help of the src/lib/c-glue-old/ stuff,
// which is currently non-operational.
//
// run_mythryl_task_and_runtime_eventloop__may_heapclean is also called by
//     src/c/hostthread/hostthread-on-posix-threads.c
//     src/c/hostthread/hostthread-on-sgi.c
//     src/c/hostthread/hostthread-on-solaris.c
// but that stuff is also non-operational (I think) and
// we're not supposed to return to caller in those cases.
//
// We get slotted into task->fate by   save_c_state				in   src/c/main/runtime-state.c 
// and by                              run_mythryl_function__may_heapclean	in   src/c/main/run-mythryl-code-and-runtime-eventloop.c
// and by                              import_heap_image__may_heapclean		in   src/c/heapcleaner/import-heap.c
// and by                              pth__pthread_create			in   src/c/hostthread/hostthread-on-posix-threads.c
//
ALIGNED_ENTRY(return_to_c_level_asm)
	MOV_L(CONST(HEAP_VOID),stdlink)
	MOV_L(CONST(HEAP_VOID),stdclos)
	MOV_L(CONST(HEAP_VOID),program_counter)
	MOV_L(CONST(REQUEST_RETURN_TO_C_LEVEL), temp)
	JMP(CSYM(set_request))



// Request a fault.  The floating point coprocessor must be reset
// (thus trashing the FP registers) since we do not know whether a 
// value has been pushed into the temporary "register".	 This is OK 
// because no floating point registers will be live at the start of 
// the exception handler.
//
ENTRY(request_fault)
	CALL(CSYM(FPEEnable))          // Does not trash any general regs.
	MOVE_FROM_VIA_TO(stdlink,temp,program_counter)
	MOV_L(CONST(REQUEST_FAULT), temp)
	JMP(CSYM(set_request))

// find_cfun : (String, String) -> Cfunction			// (library-name, function-name) -> Cfunction -- see comments in   src/c/heapcleaner/mythryl-callable-cfun-hashtable.c
//
// We get called (only) from:
//
//     src/lib/std/src/unsafe/mythryl-callable-c-library-interface.pkg	
//
// We pass the buck via    REQUEST_FIND_CFUN	in    src/c/main/run-mythryl-code-and-runtime-eventloop.c
// to                      get_mythryl_callable_c_function		in    src/c/lib/mythryl-callable-c-libraries.c
//
ALIGNED_ENTRY(find_cfun_asm)
	CHECKLIMIT
	MOV_L(CONST(REQUEST_FIND_CFUN), temp)
	JMP(CSYM(set_request))

ALIGNED_ENTRY(make_package_literals_via_bytecode_interpreter_asm)
	CHECKLIMIT
	MOV_L(CONST(REQUEST_MAKE_PACKAGE_LITERALS_VIA_BYTECODE_INTERPRETER), temp)
	JMP(CSYM(set_request))



// Invoke a C-level function (obtained from find_cfun above) from the Mythryl level.
// We get called (only) from
//
//     src/lib/std/src/unsafe/mythryl-callable-c-library-interface.pkg
//
ALIGNED_ENTRY(call_cfun_asm)					// See call_cfun in src/lib/core/init/runtime.pkg
	CHECKLIMIT
	MOV_L(CONST(REQUEST_CALL_CFUN), temp)
	JMP(CSYM(set_request))

// This is the entry point called from Mythryl to start a heapcleaning.
//						Allen 6/5/1998
ENTRY(call_heapcleaner_asm)
	POP_L(program_counter)
	MOV_L(CONST(REQUEST_HEAPCLEANING), temp)
	//
	// FALL INTO set_request

// ----------------------------------------------------------------------
ENTRY(set_request)
	// valid request in temp.
	// We'll save temp and load it with task_ptr.
	// Save registers:
	MOV_L( temp, reqsave)
	MOV_L( task_ptr, temp)
	MOV_L( heap_allocation_pointer, REGOFF( heap_allocation_pointer_byte_offset_in_task_struct, temp))
	MOV_L( stdarg,			REGOFF(                argument_byte_offset_in_task_struct, temp))
	MOV_L( stdfate,			REGOFF(                    fate_byte_offset_in_task_struct, temp))

#define	temp2 heap_allocation_pointer
	// Note that we have left Mythryl code:
	//
	MOV_L( REGOFF( hostthread_byte_offset_in_task_struct, temp), temp2)
	MOV_L( CONST(0), REGOFF( executing_mythryl_code_byte_offset_in_hostthread_struct, temp2))

	MOV_L( misc0,  REGOFF( callee_saved_register_0_byte_offset_in_task_struct, temp))
	MOV_L( misc1,  REGOFF( callee_saved_register_1_byte_offset_in_task_struct, temp))
	MOV_L( misc2,  REGOFF( callee_saved_register_2_byte_offset_in_task_struct, temp))

	// Save vregs before the stack frame is popped:
	//
	MOVE_FROM_VIA_TO(  heap_allocation_limit,	temp2,  REGOFF( heap_allocation_limit_byte_offset_in_task_struct, temp ))
	MOVE_FROM_VIA_TO(  exnfate,			temp2,  REGOFF(        exception_fate_byte_offset_in_task_struct, temp )) 
	MOVE_FROM_VIA_TO(  stdclos,			temp2,  REGOFF(       current_closure_byte_offset_in_task_struct, temp ))
	MOVE_FROM_VIA_TO(  stdlink,			temp2,  REGOFF(         link_register_byte_offset_in_task_struct, temp ))
	MOVE_FROM_VIA_TO(  program_counter,		temp2,  REGOFF(       program_counter_byte_offset_in_task_struct, temp ))
	MOVE_FROM_VIA_TO(  heap_changelog_ptr,		temp2,  REGOFF(        heap_changelog_byte_offset_in_task_struct, temp ))
	MOVE_FROM_VIA_TO(  current_thread_ptr,		temp2,  REGOFF(        current_thread_byte_offset_in_task_struct, temp ))
#undef	temp2	
	
	// Return val of function is request code:
	//
	MOV_L( reqsave, creturn)
	
	// Pop the stack frame and return to  run_mythryl_task_and_runtime_eventloop__may_heapclean()  in  src/c/main/run-mythryl-code-and-runtime-eventloop.c
#if defined(OPSYS_DARWIN)
	LEA_L( REGOFF( LIB7_FRAME_SIZE+12, ESP), ESP)
#else
	MOV_L( espsave, ESP)
#endif

	// Restore the gcc-specified "callee-save" registers:
	//
	POP_L(EDI)
	POP_L(ESI)
	POP_L(EBX)
	POP_L(EBP)

	RET

// ----------------------------------------------------------------------
	SEG_TEXT
	ALIGNTEXT4
ENTRY(asm_run_mythryl_task)				// Main external entrypoint in file, typically called by  system_run_mythryl_task_and_runtime_eventloop__may_heapclean()   in  src/c/main/run-mythryl-code-and-runtime-eventloop.c
	MOV_L (REGOFF(4,ESP), temp)			// Get argument (Task*)

	// Push the gcc-specified "callee-save" registers:
	//
	PUSH_L(EBP)
	PUSH_L(EBX)
	PUSH_L(ESI)
	PUSH_L(EDI)

#if defined(OPSYS_DARWIN)
        // MacOS X frames must be 16-byte aligned.
        // We have 20 bytes on the stack for the
	// return program_counter and callee-saves,
        // so we need a 12-byte pad:
        //
	SUB_L (CONST(LIB7_FRAME_SIZE+12), ESP)
#else
	// Align sp on 8 byte boundary.
	// We assume that the stack starts out
	// being at least word aligned, but who knows ...
	//
	MOV_L (ESP,EBX)
	OR_L  (CONST(4), ESP)		
	SUB_L (CONST(4), ESP)				// Stack grows toward address zero -- a push decreases the stack pointers.
	SUB_L (CONST(LIB7_FRAME_SIZE), ESP)
	MOV_L (EBX,espsave)
#endif
	
#define temp2	EBX
        // Initialize the Mythryl stackframe:
	//
	MOVE_FROM_VIA_TO(  REGOFF(         exception_fate_byte_offset_in_task_struct, temp),  temp2,  exnfate)
	MOVE_FROM_VIA_TO(  REGOFF(  heap_allocation_limit_byte_offset_in_task_struct, temp),  temp2,  heap_allocation_limit)
	MOVE_FROM_VIA_TO(  REGOFF(         heap_changelog_byte_offset_in_task_struct, temp),  temp2,  heap_changelog_ptr)
	MOVE_FROM_VIA_TO(  REGOFF(         current_thread_byte_offset_in_task_struct, temp),  temp2,  current_thread_ptr)
	LEA_L(CSYM(call_heapcleaner_asm), temp2)
	MOV_L(temp2, run_heapcleaner_ptr)
	MOV_L(temp, task_ptr)

	// vregs:
	MOVE_FROM_VIA_TO(REGOFF(        link_register_byte_offset_in_task_struct, temp),  temp2, stdlink)
	MOVE_FROM_VIA_TO(REGOFF(      current_closure_byte_offset_in_task_struct, temp),  temp2, stdclos)

	// program_counter:
	MOVE_FROM_VIA_TO(REGOFF(      program_counter_byte_offset_in_task_struct, temp),  temp2, program_counter)
#undef	temp2

	// Load Mythryl registers:
	//
	MOV_L( REGOFF( heap_allocation_pointer_byte_offset_in_task_struct, temp), heap_allocation_pointer)
	MOV_L( REGOFF(                    fate_byte_offset_in_task_struct, temp), stdfate)
	MOV_L( REGOFF(                argument_byte_offset_in_task_struct, temp), stdarg)
	MOV_L( REGOFF( callee_saved_register_0_byte_offset_in_task_struct, temp), misc0)
	MOV_L( REGOFF( callee_saved_register_1_byte_offset_in_task_struct, temp), misc1)
	MOV_L( REGOFF( callee_saved_register_2_byte_offset_in_task_struct, temp), misc2)

	MOV_L( ESP, REGOFF( mythryl_stackframe__ptr_for__c_signal_handler_byte_offset_in_task_struct, temp) )	// Mythryl-stackframe pointer for c_signal_handler.
//	MOV_L( ESP, CSYM(LIB7_intel32Frame) )										// Stackframe pointer for c_signal_handler.

	PUSH_L(misc2)								// Free up a register.
	PUSH_L(temp)								// Save task temporarily.

#define	tmpreg	misc2

	// Note that we are entering Mythryl:
	//
	MOV_L( REGOFF( hostthread_byte_offset_in_task_struct, temp), temp)	// temp is now hostthread.
#define hostthread	temp
	MOV_L( CONST(1), REGOFF( executing_mythryl_code_byte_offset_in_hostthread_struct, hostthread ))

	// Handle signals:
	//
	MOV_L( REGOFF( all_posix_signals_seen_count_byte_offset_in_hostthread_struct, hostthread), tmpreg)
	CMP_L( REGOFF( all_posix_signals_done_count_byte_offset_in_hostthread_struct, hostthread), tmpreg)
	
#undef  tmpreg
	JNE(pending)

restore_and_run_mythryl_code:
	POP_L(temp)									// Restore temp to task.
	POP_L(misc2)
	
run_mythryl_code:
	CMP_L( heap_allocation_limit, heap_allocation_pointer )
	JMP( CODEPTR( REGOFF( program_counter_byte_offset_in_task_struct, temp) ))	// Jump to Mythryl code.


pending:
											// Currently handling signal?

	CMP_L(CONST(0), REGOFF( mythryl_handler_for_interprocess_signal_is_running_byte_offset_in_hostthread_struct, hostthread ))   
	JNE( restore_and_run_mythryl_code )
											// Handler trap is now pending.
	movl	IMMED(1), interprocess_signal_pending_byte_offset_in_hostthread_struct( hostthread ) 

	// Must restore here because heap_allocation_limit is on stack  		// XXX
	//
	POP_L(temp)									// Restore temp to task
	POP_L(misc2)

	MOV_L( heap_allocation_pointer, heap_allocation_limit )
	JMP(run_mythryl_code)								// Jump to Mythryl code.
#undef  hostthread

// ----------------------------------------------------------------------
// make_typeagnostic_rw_vector : (Int, X) -> Rw_Vector(X)
// Allocate a new Rw_Vector and initialize with given value.
// This can trigger cleaning.
//
ALIGNED_ENTRY(make_typeagnostic_rw_vector_asm)
	CHECKLIMIT
	MOV_L (REGIND(stdarg), temp)						// temp := length in words.
	SAR_L (CONST(1), temp)							// temp := length untagged.
	CMP_L (CONST(MAX_AGEGROUP0_ALLOCATION_SIZE_IN_WORDS), temp)		// Is this a small chunk?
	JGE (3f)

#define temp1 misc0
#define temp2 misc1
	PUSH_L(misc0)								// Save misc0.
	PUSH_L(misc1)								// Save misc1.
	
	MOV_L (temp, temp1)
	SAL_L (CONST(TAGWORD_LENGTH_FIELD_SHIFT),temp1)				// Build tagword in temp1.
	OR_L (CONST(MAKE_BTAG(RW_VECTOR_DATA_BTAG)),temp1)
	MOV_L (temp1,REGIND(heap_allocation_pointer))				// Store tagword.
	ADD_L (CONST(4),heap_allocation_pointer)				// heap_allocation_pointer++
	MOV_L (heap_allocation_pointer, temp1)					// temp1 := array data ptr
	MOV_L (REGOFF(4,stdarg), temp2)						// temp2 := initial value
2:	
	MOV_L (temp2, REGIND(heap_allocation_pointer))				// Initialize array.
	ADD_L (CONST(4), heap_allocation_pointer)
	SUB_L (CONST(1), temp)
	JNE (2b)

	// Allocate Rw_Vector header:
	//
	MOV_L (CONST(TYPEAGNOSTIC_RW_VECTOR_TAGWORD), REGIND(heap_allocation_pointer))				// Tagword in temp.
	ADD_L (CONST(4), heap_allocation_pointer)						// heap_allocation_pointer++
	MOV_L (REGIND(stdarg), temp)						// temp := length
	MOV_L (heap_allocation_pointer, stdarg)						// result = header addr
	MOV_L (temp1, REGIND(heap_allocation_pointer))						// Store pointer to data.
	MOV_L (temp, REGOFF(4,heap_allocation_pointer))					// Store length.
	ADD_L (CONST(8), heap_allocation_pointer)

	POP_L (misc1)
	POP_L (misc0)
	CONTINUE
#undef  temp1
#undef  temp2
3:
	MOVE_FROM_VIA_TO(stdlink, temp, program_counter)
	MOV_L(CONST(REQUEST_MAKE_TYPEAGNOSTIC_RW_VECTOR), temp)
	JMP(CSYM(set_request))
	

// make_float64_rw_vector : Int -> Float64_Rw_Vector
//
ALIGNED_ENTRY(make_float64_rw_vector_asm)
	CHECKLIMIT
#define temp1 misc0
        PUSH_L(misc0)								// Free temp1.
	MOV_L(stdarg,temp)							// temp := length
	SAR_L(CONST(1),temp)							// temp := untagged length
	SHL_L(CONST(1),temp)							// temp := length in words
	CMP_L(CONST(MAX_AGEGROUP0_ALLOCATION_SIZE_IN_WORDS),temp)
	JGE(2f)

	OR_L(CONST(4),heap_allocation_pointer)					// Align heap_allocation_pointer.	// 64-bit issue	;  this aligns for 32-bit tagword followed by 64-bit float value; unecessary on 64-bit system.

	// Allocate the data chunk:
	//
	MOV_L(temp, temp1)
	SHL_L(CONST(TAGWORD_LENGTH_FIELD_SHIFT),temp1)  			// temp1 := tagword
	OR_L(CONST(MAKE_BTAG(EIGHT_BYTE_ALIGNED_NONPOINTER_DATA_BTAG)),temp1)
	MOV_L(temp1,REGIND(heap_allocation_pointer))				// Store tagword
	ADD_L(CONST(4), heap_allocation_pointer)				// heap_allocation_pointer++
	MOV_L(heap_allocation_pointer, temp1)					// temp1 := data chunk
	SHL_L(CONST(2),temp)							// temp := length in bytes
	ADD_L(temp, heap_allocation_pointer)					// heap_allocation_pointer += length

	// Allocate the header chunk:
	//
	MOV_L(CONST(FLOAT64_RW_VECTOR_TAGWORD),REGIND(heap_allocation_pointer))	// Header tagword.
	ADD_L(CONST(4), heap_allocation_pointer)				// heap_allocation_pointer++
	MOV_L(temp1, REGIND(heap_allocation_pointer))				// header data field
	MOV_L(stdarg, REGOFF(4,heap_allocation_pointer))			// header length field
	MOV_L(heap_allocation_pointer, stdarg)					// stdarg := header chunk
	ADD_L(CONST(8), heap_allocation_pointer)				// heap_allocation_pointer += 2

	POP_L(misc0)								// Restore temp1.
	CONTINUE
2:
	POP_L(misc0)								// Restore temp1.
	MOVE_FROM_VIA_TO(stdlink, temp, program_counter)
	MOV_L(CONST(REQUEST_ALLOCATE_VECTOR_OF_EIGHT_BYTE_FLOATS), temp)
	JMP(CSYM(set_request))
#undef temp1


// make_unt8_rw_vector : Int -> Unt8_Rw_Vector
//
ALIGNED_ENTRY(make_unt8_rw_vector_asm)
	CHECKLIMIT
	MOV_L(stdarg,temp)							// temp := length(tagged int)
	SAR_L(CONST(1),temp)							// temp := length(untagged)
	ADD_L(CONST(3),temp)
	SAR_L(CONST(2),temp)							// temp := length(words)
	CMP_L(CONST(MAX_AGEGROUP0_ALLOCATION_SIZE_IN_WORDS),temp)		// small chunk?
	JMP(2f)
	JGE(2f)									// XXXXX

#define	temp1	misc0
	PUSH_L(misc0)

	// Allocate the data chunk:
	//
	MOV_L(temp, temp1)							// temp1 :=  tagword.
	SHL_L(CONST(TAGWORD_LENGTH_FIELD_SHIFT),temp1)
	OR_L(CONST(MAKE_BTAG(FOUR_BYTE_ALIGNED_NONPOINTER_DATA_BTAG)),temp1)
	MOV_L(temp1, REGIND(heap_allocation_pointer))				// Store tagword.
	ADD_L(CONST(4), heap_allocation_pointer)				// heap_allocation_pointer++
	MOV_L(heap_allocation_pointer, temp1)					// temp1 := data chunk
	SHL_L(CONST(2), temp)							// temp := length in bytes
	ADD_L(temp, heap_allocation_pointer)					// heap_allocation_pointer += length

	// Allocate the header chunk:
	//
	MOV_L(CONST(UNT8_RW_VECTOR_TAGWORD), REGIND(heap_allocation_pointer))	// Header tagword.
	ADD_L(CONST(4),heap_allocation_pointer)					// heap_allocation_pointer++
	MOV_L(temp1, REGIND(heap_allocation_pointer))				// header data field
	MOV_L(stdarg, REGOFF(4,heap_allocation_pointer))			// header length field
	MOV_L(heap_allocation_pointer, stdarg)					// stdarg := header chunk
	ADD_L(CONST(8),heap_allocation_pointer)					// heap_allocation_pointer := 2
	POP_L(misc0)
	CONTINUE
#undef  temp1
2:
	MOVE_FROM_VIA_TO(stdlink, temp, program_counter)
	MOV_L(CONST(REQUEST_ALLOCATE_BYTE_VECTOR), temp)
	JMP(CSYM(set_request))


// make_string : Int -> String
//
ALIGNED_ENTRY(make_string_asm)
	CHECKLIMIT
	MOV_L(stdarg,temp)
	SAR_L(CONST(1),temp)							// temp := length(untagged)
	ADD_L(CONST(4),temp)		
	SAR_L(CONST(2),temp)							// temp := length(words)
	CMP_L(CONST(MAX_AGEGROUP0_ALLOCATION_SIZE_IN_WORDS),temp)
	JGE(2f)

	PUSH_L(misc0)								// Free misc0.
#define	temp1	misc0

	MOV_L(temp, temp1)
	SHL_L(CONST(TAGWORD_LENGTH_FIELD_SHIFT),temp1)				// Build tagword in temp1.
	OR_L(CONST(MAKE_BTAG(FOUR_BYTE_ALIGNED_NONPOINTER_DATA_BTAG)), temp1)
	MOV_L(temp1, REGIND(heap_allocation_pointer))				// Store the data pointer.
	ADD_L(CONST(4),heap_allocation_pointer)					// heap_allocation_pointer++

	MOV_L(heap_allocation_pointer, temp1)					// temp1 := data chunk
	SHL_L(CONST(2),temp)							// temp := length in bytes
	ADD_L(temp, heap_allocation_pointer)					// heap_allocation_pointer += length
	MOV_L(CONST(0),REGOFF(-4,heap_allocation_pointer))			// Zero out the last word.

	// Allocate the header chunk
	//
	MOV_L(CONST(STRING_TAGWORD), temp)					// Header tagword.
	MOV_L(temp, REGIND(heap_allocation_pointer))
	ADD_L(CONST(4), heap_allocation_pointer)				// heap_allocation_pointer++
	MOV_L(temp1, REGIND(heap_allocation_pointer))				// Header data field.
	MOV_L(stdarg, REGOFF(4,heap_allocation_pointer))			// Header length field.
	MOV_L(heap_allocation_pointer, stdarg)					// stdarg := header chunk
	ADD_L(CONST(8), heap_allocation_pointer)		
	
	POP_L(misc0)								// Restore misc0.
#undef  temp1
	CONTINUE
2:
	MOVE_FROM_VIA_TO(stdlink, temp, program_counter)
	MOV_L(CONST(REQUEST_ALLOCATE_STRING), temp)
	JMP(CSYM(set_request))

// make_vector_asm:  (Int, List(X)) -> Vector(X)				// (length_in_slots, initializer_list) -> result_vector
//
//	Create a vector and initialize from given list.
//
//	Caller guarantees that length_in_slots is
//      positive and also the length of the list.
//	For a sample client call see
//          fun vector
//	in
//	    src/lib/core/init/pervasive.pkg
//
ALIGNED_ENTRY(make_vector_asm)
	CHECKLIMIT
	PUSH_L(misc0)
	PUSH_L(misc1)
#define	temp1	misc0
#define temp2   misc1	
	MOV_L( REGIND(stdarg), temp)						// temp := length(tagged)
	MOV_L( temp, temp1)
	SAR_L( CONST(1), temp1)							// temp1 := length(untagged)
	CMP_L( CONST( MAX_AGEGROUP0_ALLOCATION_SIZE_IN_WORDS ), temp1)		// Is this a small chunk (i.e., one allowed in the arena)?
	JGE(3f)									// branch if so.

	// Allocate data chunk:
	//	
	SHL_L( CONST( TAGWORD_LENGTH_FIELD_SHIFT ), temp1)			// Build tagword in temp1.
	OR_L(  CONST( MAKE_BTAG( RO_VECTOR_DATA_BTAG )), temp1)
	MOV_L( temp1, REGIND( heap_allocation_pointer ))			// Store tagword.
	ADD_L( CONST(4), heap_allocation_pointer)				// heap_allocation_pointer++
	MOV_L( REGOFF(4, stdarg), temp1)					// temp1 := list
	MOV_L( heap_allocation_pointer, stdarg)					// stdarg := vector

2:
	MOV_L( REGIND(temp1), temp2)						// temp2 := head(temp1)
	MOV_L( temp2, REGIND( heap_allocation_pointer ))			// Store word in vector.
	ADD_L( CONST(4), heap_allocation_pointer)				// heap_allocation_pointer++
	MOV_L( REGOFF(4,temp1), temp1)						// temp1 := tail(temp1)
	CMP_L( CONST(HEAP_NIL), temp1)						// temp1 = NIL?
	JNE(2b)									// Loop if not.

	// Allocate header chunk:
	//	
	MOV_L( CONST( TYPEAGNOSTIC_RO_VECTOR_TAGWORD ), temp1)			// Tagword in temp1.
	MOV_L( temp1, REGIND(heap_allocation_pointer))				// Store tagword.
	ADD_L( CONST(4), heap_allocation_pointer)				// heap_allocation_pointer++
	MOV_L( stdarg, REGIND(heap_allocation_pointer))				// Header data field.
	MOV_L( temp, REGOFF(4,heap_allocation_pointer))				// Header length.
	MOV_L( heap_allocation_pointer, stdarg)					// result = header chunk
	ADD_L( CONST(8), heap_allocation_pointer)				// heap_allocation_pointer += 2

	POP_L( misc1 )
	POP_L( misc0 )
	CONTINUE
3:
	POP_L(misc1)
	POP_L(misc0)
	MOVE_FROM_VIA_TO(stdlink, temp, program_counter)
	MOV_L(CONST(REQUEST_MAKE_TYPEAGNOSTIC_RO_VECTOR), temp)
	JMP(CSYM(set_request))
#undef  temp1
#undef  temp2	
	
// try_lock: Spin_Lock -> Bool. 
//    "low-level test-and-set style primitive for mutual-exclusion among 
//     processors.	For now, we only provide a uni-processor trivial version."
//
// This is an ancient mutex left-over from 1992 multi-processor
// support:  See src/src/A.HOSTTHREAD-SUPPORT.OVERVIEW.
// If re-implementing this in assembly, look up Reppy's recent Manticore
// work:  See http://mythryl.org/pub/pml/
//   In particular, he points out that spinning on an atomic test-and-set
// instruction is horribly expensive because it totally saturates the the
// available bus bandwidth -- slowing down all the other cores which are
// still trying to do useful work -- so it is much better to test intermittently
// with a vanilla memory read, spacing them out with NOPs or whatever to conserve
// memory bandwidth, and only execute the atomic test-and-set instruction when
// it is likely to succeed.
//    -- 2011-11-01 CrT
//
ALIGNED_ENTRY(try_lock_asm)
#if (MAX_PROCS > 1)
#  error prim.intel32.asm:  try_lock:  multiple processors not supported
#else // (MAX_PROCS == 1)
	MOV_L(REGIND(stdarg), temp)				// Get old value of lock.
	MOV_L(CONST(1), REGIND(stdarg))				// Set the lock to HEAP_FALSE.
	MOV_L(temp, stdarg)					// Return old value of lock.
	CONTINUE
#endif

// unlock :  Release a spinlock.
//
// This is an ancient mutex left-over from 1992 multi-processor
// support: See src/src/A.HOSTTHREAD-SUPPORT.OVERVIEW.    -- 2011-11-01 CrT
//
ALIGNED_ENTRY(unlock_asm)
#if (MAX_PROCS > 1)
    #error prim.intel32.asm:  unlock_lock:  multiple processors not supported
#else // (MAX_PROCS == 1)
	MOV_L(CONST(3), REGIND(stdarg))				// Store HEAP_TRUE into lock.
	MOV_L(CONST(1), stdarg)					// Return Void.
	CONTINUE
#endif


// ******************** Floating point functions. ********************

#define FPOP	fstp %st	// Pop the floating point register stack.


// Temporary storage for the old and new floating point control
// word.  We don't use the stack to for this, since doing so would 
// change the offsets of the pseudo-registers.
	DATA
	ALIGN4
old_controlwd:	
	.word	0
new_controlwd:	
	.word	0
	TEXT
	ALIGN4


// Initialize the 80387 floating point coprocessor.  First, the floating
// point control word is initialized (undefined fields are left
// unchanged).	Rounding control is set to "nearest" (although floor_a
// needs "toward negative infinity").  Precision control is set to
// "double".  The precision, underflow, denormal 
// overflow, zero divide, and invalid operation exceptions
// are masked.  Next, seven of the eight available entries on the
// floating point register stack are claimed (see intel32/intel32.pkg).
//
// NB: This cannot trash any registers because it's called from request_fault.
//
ENTRY(FPEEnable)
	FINIT
	SUB_L(CONST(4), ESP)			// Temp space.	Keep stack aligned.
	FSTCW(REGIND(ESP))			// Store FP control word.
						// Keep undefined fields, clear others.
	AND_W(CONST(0xf0c0), REGIND(ESP))
	OR_W(CONST(0x023f), REGIND(ESP))	// Set fields (see above).
	FLDCW(REGIND(ESP))			// Install new control word.
	ADD_L(CONST(4), ESP)
	RET

#if (defined(OPSYS_LINUX) || defined(OPSYS_CYGWIN) || defined(OPSYS_SOLARIS))
ENTRY(fegetround)
	SUB_L(CONST(4), ESP)			// Allocate temporary space.
	FSTCW(REGIND(ESP))			// Store fp control word.
	SAR_L(CONST(10),REGIND(ESP))		// Rounding mode is at bit 10 and 11.
	AND_L(CONST(3), REGIND(ESP))		// Mask two bits.
	MOV_L(REGIND(ESP),EAX)			// Return rounding mode.
	ADD_L(CONST(4), ESP)			// Deallocate space.
	RET
  	
ENTRY(fesetround)
	SUB_L(CONST(4), ESP)			// Allocate temporary space
	FSTCW(REGIND(ESP))			// Store fp control word.
	AND_W(CONST(0xf3ff), REGIND(ESP))	// Clear rounding field.
	MOV_L(REGOFF(8,ESP), EAX)		// New rounding mode.
	SAL_L(CONST(10), EAX)			// Move to right place.
	OR_L(EAX,REGIND(ESP))			// New control word.
	FLDCW(REGIND(ESP))			// Load new control word.
	ADD_L(CONST(4), ESP)			// Deallocate space.
	RET
#endif


// floor : real -> int
// Return the nearest integer that is less or equal to the argument.
//	 Caller's responsibility to make sure arg is in range.

ALIGNED_ENTRY(floor_asm)
	FSTCW(old_controlwd)			// Get FP control word.
	MOV_W(old_controlwd, AX)
	AND_W(CONST(0xf3ff), AX)		// Clear rounding field.
	OR_W(CONST(0x0400), AX)			// Round towards neg. infinity.
	MOV_W(AX, new_controlwd)
	FLDCW(new_controlwd)			// Install new control word.

	FLD_D(REGIND(stdarg))
	SUB_L(CONST(4), ESP)
	FISTP_L(REGIND(ESP))			// Round, store, and pop.
	POP_L(stdarg)
	SAL_L(CONST(1), stdarg)			// Tag the resulting integer.
	INC_L(stdarg)

	FLDCW(old_controlwd)			// Restore old FP control word.
	CONTINUE

// logb : real -> int
// Extract the unbiased exponent pointed to by stdarg.
// Note: Using fxtract, and fistl does not work for inf's and nan's.
//
ALIGNED_ENTRY(logb_asm)
	MOV_L(REGOFF(4,stdarg),temp)		// msb for little endian arch
	SAR_L(CONST(20), temp)			// throw out 20 bits
	AND_L(CONST(0x7ff),temp)		// clear all but 11 low bits
	SUB_L(CONST(1023), temp)		// unbias
	SAL_L(CONST(1), temp)			// room for tag bit
	ADD_L(CONST(1), temp)			// tag bit
	MOV_L(temp, stdarg)
	CONTINUE
	

// scalb : (real * int) -> real
// Scale the first argument by 2 raised to the second argument.	 Raise
// Float("underflow") or Float("overflow") as appropriate.
// NB: We assume the first floating point "register" is
// caller-save, so we can use it here (see intel32/intel32.pkg).

ALIGNED_ENTRY(scalb_asm)
	CHECKLIMIT
	PUSH_L(REGOFF(4,stdarg))				// Get copy of scalar.				64-bit issue
	SAR_L(CONST(1), REGIND(ESP))				// Untag it.
	FILD_L(REGIND(ESP))					// Load it ...
//	fstp	%st(1)						// ... into 1st FP reg.
	MOV_L(REGIND(stdarg), temp)				// Get pointer to real.
	FLD_D(REGIND(temp))					// Load it into temp.

	FSCALE							// Multiply exponent by scalar.
	MOV_L(CONST(FLOAT64_TAGWORD), REGIND(heap_allocation_pointer))
	FSTP_D(REGOFF(4,heap_allocation_pointer))		// Store resulting float.			64-bit issue
	ADD_L(CONST(4), heap_allocation_pointer)		// Allocate word for tag.			64-bit issue
	MOV_L(heap_allocation_pointer, stdarg)			// Return a pointer to the float.
	ADD_L(CONST(8), heap_allocation_pointer)		// Allocate room for float.
	FSTP_D(REGIND(ESP))			
	ADD_L(CONST(4), ESP)					// Discard copy of scalar.			64-bit issue
	CONTINUE



// COPYRIGHT (c) 1995 AT&T Bell Laboratories.
// Subsequent changes by Jeff Prothero Copyright (c) 2010-2012,
// released per terms of SMLNJ-COPYRIGHT.

