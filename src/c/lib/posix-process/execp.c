// execp.c



#include "../../mythryl-config.h"

#include "runtime-base.h"
#include "runtime-values.h"
#include "make-strings-and-vectors-etc.h"
#include "raise-error.h"
#include "cfun-proto-list.h"

#if HAVE_UNISTD_H
    #include <unistd.h>
#endif


// One of the library bindings exported via
//     src/c/lib/posix-process/cfun-list.h
// and thence
//     src/c/lib/posix-process/libmythryl-posix-process.c



Val   _lib7_P_Process_execp   (Task* task,  Val arg)   {
    //=====================
    //
    // Mythryl type:  (String, List(String)) -> X
    //
    // Overlay a new process image; resolve file to pathname using PATH
    //
    // This fn gets bound as   execp   in:
    //
    //     src/lib/std/src/psx/posix-process.pkg

									    ENTER_MYTHRYL_CALLABLE_C_FN(__func__);

    Val file   =  GET_TUPLE_SLOT_AS_VAL( arg, 0 );
    Val arglst =  GET_TUPLE_SLOT_AS_VAL( arg, 1 );


    // Use the heap for temp space for the argv[] vector:
    //
    char** cp =  (char**) (task->heap_allocation_pointer);

    #ifdef SIZES_C_64_MYTHRYL_32
	// 8-byte align it:
	//
	cp = (char**)  ROUND_UP_TO_POWER_OF_TWO( (Unt2)cp, POINTER_BYTESIZE );
    #endif

    char** argv = cp;
    //
    for (Val p = arglst;  p != LIST_NIL;  p = LIST_TAIL(p)) {
        *cp++ = HEAP_STRING_AS_C_STRING(LIST_HEAD(p));
    }
    *cp++ = 0;							// Terminate the argv[].

    int status =  execvp( HEAP_STRING_AS_C_STRING(file), argv );
    //
    Val result = RETURN_STATUS_EXCEPT_RAISE_SYSERR_ON_NEGATIVE_STATUS__MAY_HEAPCLEAN(task, status, NULL);

									    EXIT_MYTHRYL_CALLABLE_C_FN(__func__);
    return result;
}

// COPYRIGHT (c) 1995 by AT&T Bell Laboratories.
// Subsequent changes by Jeff Prothero Copyright (c) 2010-2012,
// released per terms of SMLNJ-COPYRIGHT.

