// posix-signals.c
//
// Compute the signal table information for UNIX systems.  This is used to
// generate the posix-signal-table--autogenerated.c file and the system-signals.h file.
//
// We assume that the  signals SIGHUP, SIGINT, SIGQUIT, SIGALRM, and SIGTERM
// are (at least) provided.
//
// We also define the pseudo-signals HEAPCLEANING_DONE and THREAD_SCHEDULER_TIMESLICE
// which Mythryl-level code can register handlers for just like real signals.
//
// For the actual C-level signal handler and related Mythryl/C signal support code see
//
//     src/c/machine-dependent/posix-signal.c 

#include "../mythryl-config.h"

#include "system-dependent-unix-stuff.h"
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include "header-file-autogeneration-stuff.h"
#include "generate-system-signals.h-for-posix-systems.h"



//////////////////////////////////////////////
// The POSIX/ANSI/BSD/Linux signals we support:
//										// SigTable is used in this file and also in   src/c/machine-dependent/posix-signal.c
Signal_Descriptor	SigTable[] = {						// Signal_Descriptor	is from   src/c/config/generate-system-signals.h-for-posix-systems.h


    #ifdef SIGALRM
	    { SIGALRM,	"SIGALRM",	"ALARM"},	// POSIX		// Alarm.  See also SIGVTALRM.
    #endif



    #ifdef SIGABRT								// We favor "SIGABRT" over "SIGIOT" because the former has 10X more Google hits.
	    { SIGABRT,	"SIGABRT",	"ABRT"},	// ANSI			// Abort.     On Linux == BSD4.2 SIGIOT.
    #elif SIGIOT
	    { SIGIOT,	"SIGABRT",	"ABRT"},	// BSD 4.2		// I/O Trap.  On Linux == ANSI SIGABRT (abort).
    #endif



    #ifdef SIGBUS
	    { SIGBUS,	"SIGBUS",	"BUS"},		// BSD 4.2		// BUS error.
    #endif



    #if defined(SIGCHLD)
	    { SIGCHLD,	"SIGCHLD",	"CHLD"},	// POSIX		// Child status has changed.
    #elif defined(SIGCLD)
	    { SIGCLD,	"SIGCHLD",	"CHLD"},	// SYS V		// "                      ".
    #endif



    #ifdef SIGCONT
	    { SIGCONT,	"SIGCONT",	"CONT"},	// POSIX		// Continue.
    #endif



    // For some reason uncommenting this and recompiling produces
    //     *** Internal error:  No signal_table entry for signal 8 ***
    // from
    //     src/lib/std/src/nj/runtime-signals-guts.pkg
    //
    // (See also SIGSEGV below.)
    //
    // I've got other fish to fry at the moment,
    // so I'm just leaving it commented out.		// XXX SUCKO FIXME
    //            -- 2012-12-08 CrT
    //
    // #ifdef SIGFPE
    //	{ SIGFPE,	"SIGFPE",	"FPE"},		// ANSI			// Floating-point exception.
    // #endif



    #ifdef SIGHUP
	    { SIGHUP,	"SIGHUP",	"HUP"},		// POSIX		// Hangup.
    #endif



    #ifdef SIGILL
	    { SIGILL,	"SIGILL",	"ILL"},		// ANSI			// Illegal instruction
    #endif



    #ifdef SIGINT
	    { SIGINT,	"SIGINT",	"INTERRUPT"},	// ANSI			// Interrupt.
    #endif



    #ifdef SIGIO								// "SIGIO" has 10X more Google hits than "SIGPOLL".
	    { SIGIO,	"SIGIO",	"IO"},		// BSD4.2		// I/O now possible.
    #elif SIGPOLL
	    { SIGPOLL,	"SIGIO",	"IO"},		// SYS V		// Pollable event occurred
    #endif



    // SIGIOT:  See SIGABRT.



    #ifdef SIGKILL
	    { SIGKILL,	"SIGKILL",	"KILL"},	// POSIX		// Kill, unblockable.
    #endif



    #ifdef SIGPIPE
	    { SIGPIPE,	"SIGPIPE",	"PIPE"},	// POSIX		// Broken pipe.
    #endif





    #ifdef SIGPROF
	    { SIGPROF,	"SIGPROF",	"PROF"},	// BSD 4.2		// Profiling alarm clock.
    #endif



    #ifdef SIGPWF
	    { SIGPWR,	"SIGPWR",	"PWR"},		// SYS V		// Power failure restart.
    #endif



    #ifdef SIGQUIT
	    { SIGQUIT,	"SIGQUIT",	"QUIT"},	// POSIX		// Quit.
    #endif



    // For some reason uncommenting this and recompiling produces
    //     *** Internal error:  No signal_table entry for signal 11 ***
    // from
    //     src/lib/std/src/nj/runtime-signals-guts.pkg
    //
    // (See also SIGFPE above.)
    //
    // I've got other fish to fry at the moment,
    // so I'm just leaving it commented out.		// XXX SUCKO FIXME
    //            -- 2012-12-08 CrT
    //
    // #ifdef SIGSEGV
    //	{ SIGSEGV,	"SIGSEGV",	"SEGV"},	// ANSI			// Segmentation violation. (Typically due to use of an invalid C pointer.)
    // #endif



    #ifdef SIGSTKFLT
	    { SIGSTKFLT, "SIGSTKFLT",	"STKFLT"},	// Linux		// Stack fault.
    #endif



    #ifdef SIGSTOP
	    { SIGSTOP,	"SIGSTOP",	"STOP"},	// POSIX		// Stop, unblockable.
    #endif



    #ifdef SIGSYS
	    { SIGSYS,	"SIGSYS",	"SYS"},		// Linux		// Bad system call.
    #endif



    #ifdef SIGTERM
	    { SIGTERM,	"SIGTERM",	"TERMINATE"},	// POSIX		// Polite (catchable) request to terminate. http://en.wikipedia.org/wiki/SIGTERM
    #endif



    #ifdef SIGTRAP
	    { SIGTRAP,	"SIGTRAP",	"TRAP"},	// POSIX		// Trace trap
    #endif



    #ifdef SIGTSTP
	    { SIGTSTP,	"SIGTSTP",	"TSTP"},	// POSIX		// Keyboard stop.
    #endif



    #ifdef SIGTTIN
	    { SIGTTIN,	"SIGTTIN",	"TTIN"},	// POSIX		// Background read from TTY.
    #endif



    #ifdef SIGTTOU
	    { SIGTTOU,	"SIGTTOU",	"TTOU"},	// POSIX		// Backround write to TTY.
    #endif


    #ifdef SIGURG
	    { SIGURG,	"SIGURG",	"URG"},		// BSD 4.2		// Urgent condition on socket.
    #endif



    #ifdef SIGUSR1
	    { SIGUSR1,	"SIGUSR1",	"USR1"},	// POSIX		// User-defined signal 1.
    #endif



    #ifdef SIGUSR2
	    { SIGUSR2,	"SIGUSR2",	"USR2"},	// POSIX		// User-defined signal 2.
    #endif


    #ifdef SIGVTALRM
	    { SIGVTALRM, "SIGVTALRM",	"VTALRM"},	// BSD 4.2		// Alarm.  See also SIGALRM.
    #endif



    #if defined(SIGWINCH)							// "SIGWINCH" gets 10X more Google hits than "SIGWINDOW".
	    { SIGWINCH,	"SIGWINCH",	"WINCH"},	// BSD 4.3		// Window size change.
    #elif defined(SIGWINDOW)
	    { SIGWINDOW, "SIGWINCH",	"WINCH"},
    #endif



    #if defined(SIGXCPU)
	    { SIGXCPU,	"SIGXCPU",	"XCPU"},	// BSD 4.2		// CPU limit exceeded.
    #endif



    #if defined(SIGXFSZ)
	    { SIGXFSZ,	"SIGXFSZ",	"XFSZ"},	// BSD 4.2		// File size limit exceeded.
    #endif
};
#define TABLE_SIZE	(sizeof(SigTable)/sizeof(Signal_Descriptor))



/////////////////////////////////////////////////////////////////////
// I think the below signals are basically a sucky idea.
// They will always be anomalous one way or another -- for example
// trying to enter them in a signalset via sigaddset() from <signal.h>
// is likely to fail obscurely on some systems.  I think it would be
// better to have a facility which allows the caller to have delivery
// of some caller-selected standard signal faked up after each heapcleaning,
// rather than have a bogus heapcleaning signal. XXX SUCKO FIXME
//                                             -- 2012-12-08 CrT
//
// Run-time system generated signals.
// Note that the '-1' signal codes mean basically
// "append me to the end of the real posix signals",
// so if 'kill -l' shows 30 signals on your unix,
// the first '-1' below will be (pseudo-)signal 31.
//
// The '#define name' will be that visible at the C level via
//
//     src/c/o/system-signals.h
//
// The 'Mythryl' name will be that visible at the Mythryl level via
// mythryl_callable_c_library_interface::find_system_constant() --
// for example see src/lib/std/src/nj/runtime-signals-guts.pkg
//
static Signal_Descriptor    runtime_generated_signals__local []							// Signal_Descriptor	is from   src/c/config/generate-system-signals.h-for-posix-systems.h
=  	//		    ================================
    {
        //     Posix signal code    #define name                		Mythryl name   
        //     =================    ============                		============
	//
	    { -1,                   "RUNSIG_HEAPCLEANING_DONE",			"HEAPCLEANING_DONE" },		// RUNSIG_HEAPCLEANING_DONE here shows up as
														//     #define RUNSIG_HEAPCLEANING_DONE 30			in   src/c/o/system-signals.h
														// + as 'case' tags in get_signal_state + set_signal_state	in   src/c/machine-dependent/posix-signal.c
														//
														// HEAPCLEANING_DONE here shows up (only)			in   src/c/o/posix-signal-table--autogenerated.c
														// and								in   src/lib/std/src/nj/runtime-signals-guts.pkg


	    { -1,                   "RUNSIG_THREAD_SCHEDULER_TIMESLICE",	"THREAD_SCHEDULER_TIMESLICE" },	// RUNSIG_THREAD_SCHEDULER_TIMESLICE here shows up as
														//     #define RUNSIG_THREAD_SCHEDULER_TIMESLICE 31		in   src/c/o/system-signals.h
														// + as 'case' tags in get_signal_state + set_signal_state	in   src/c/machine-dependent/posix-signal.c
														//
														// THREAD_SCHEDULER_TIMESLICE here shows up (only)		in   src/c/o/posix-signal-table--autogenerated.c
														// and								in   src/lib/std/src/nj/runtime-signals-guts.pkg
    };

#define RUNTIME_GENERATED_SIGNAL_COUNT  (sizeof(runtime_generated_signals__local) / sizeof(Signal_Descriptor))

Runtime_System_Signal_Table*   sort_runtime_system_signal_table   () {
    //
    Signal_Descriptor**  signals =   MALLOC_VEC( Signal_Descriptor*, TABLE_SIZE + RUNTIME_GENERATED_SIGNAL_COUNT);

    // Insertion-sort the signal table by increasing signal number.
    // If there are duplicate definitions of a sig value
    // the first is kept and the rest are dropped.
    // We need this because some systems alias signals.
    //
    int n = 0;
    for (int i = 0;  i < TABLE_SIZE;  i++) {
	//
        // Invariant: signals[0..n-1] is sorted
        //
	Signal_Descriptor* p =  &SigTable[ i ];

	int  j;
	for (j = 0;  j < n;  j++) {
	    //
	    if (signals[j]->sig == p->sig)		break;	      // A duplicate -- drop it.

	    if (signals[j]->sig > p->sig) {
	        //
                // Insert the signal at position j:
                //
		for (int k = n;  k >= j;  k--)   signals[k] = signals[k-1];
		//
		signals[j] = p;
		n++;
		break;
	    }
	}
	if (j == n) {
	    signals[n++] = p;
	}
    }

    // At this point 'n' is the number of system signals and
    // signals[n-1]->sig is the largest system signal code.
    //

    // Add the run-time system signals to the table:
    //
    for (int i = 0, j = n;  i < RUNTIME_GENERATED_SIGNAL_COUNT;  i++, j++) {
	//
	signals[j] =  &runtime_generated_signals__local[i];
	//
	signals[j]->sig =  signals[n-1]->sig + i+1;
    }

    Runtime_System_Signal_Table*  signal_db
	=
	MALLOC_CHUNK( Runtime_System_Signal_Table );

    signal_db->sigs	= signals;
    signal_db->posix_signal_kinds	= n;
    signal_db->runtime_generated_signal_kinds	= RUNTIME_GENERATED_SIGNAL_COUNT;
    signal_db->lowest_valid_posix_signal_number	= signals[0]->sig;
    signal_db->highest_valid_posix_signal_number	= signals[n-1]->sig;

    return signal_db;

}


// COPYRIGHT (c) 1995 by AT&T Bell Laboratories.
// Subsequent changes by Jeff Prothero Copyright (c) 2010-2012,
// released under Gnu Public Licence version 3.


