// setsigmask.c
//
// This gets bound in:
//
//     src/lib/std/src/nj/interprocess-signals-guts.pkg


#include "../../mythryl-config.h"

#include "runtime-base.h"
#include "runtime-values.h"
#include "system-dependent-signal-stuff.h"
#include "cfun-proto-list.h"



// One of the library bindings exported via
//     src/c/lib/signal/cfun-list.h
// and thence
//     src/c/lib/signal/libmythryl-signal.c



Val   _lib7_Sig_setsigmask   (Task* task,  Val arg)   {
    //====================
    //
    // Mythryl type:   Null_Or(List(System_Constant)) -> Void
    //
    // Mask the listed signals.
    //
    // This fn gets bound as   set_sig_mask   in:
    //
    //     src/lib/std/src/nj/interprocess-signals-guts.pkg

									    ENTER_MYTHRYL_CALLABLE_C_FN(__func__);

    set_signal_mask( task, arg );						// set_signal_mask() is implemented in   src/c/machine-dependent/interprocess-signals.c	
    //
									    EXIT_MYTHRYL_CALLABLE_C_FN(__func__);
    return HEAP_VOID;
}


// COPYRIGHT (c) 1995 by AT&T Bell Laboratories.
// Subsequent changes by Jeff Prothero Copyright (c) 2010-2012,
// released per terms of SMLNJ-COPYRIGHT.

