// pipe.c


#include "../../mythryl-config.h"

#include "runtime-base.h"
#include "runtime-values.h"
#include "make-strings-and-vectors-etc.h"
#include "raise-error.h"
#include "cfun-proto-list.h"

#include <stdio.h>
#include <string.h>

#if HAVE_UNISTD_H
    #include <unistd.h>
#endif



// One of the library bindings exported via
//     src/c/lib/posix-io/cfun-list.h
// and thence
//     src/c/lib/posix-io/libmythryl-posix-io.c



Val   _lib7_P_IO_pipe   (Task* task,  Val arg)   {
    //===============
    //
    // Mythryl type:   Void -> (Int, Int)
    //
    // Create a pipe and return its input and output descriptors.
    //
    // This fn gets bound as   pipe'   in:
    //
    //     src/lib/std/src/psx/posix-io.pkg
    //     src/lib/std/src/psx/posix-io-64.pkg

									    ENTER_MYTHRYL_CALLABLE_C_FN(__func__);

    int         status;
    int         fds[2];

    RELEASE_MYTHRYL_HEAP( task->hostthread, __func__, NULL );
	//
	status =  pipe(fds);
	//
    RECOVER_MYTHRYL_HEAP( task->hostthread, __func__ );
// printf("Created pipe %d -> %d   -- pipe.c thread id %lx\n", fds[0], fds[1], pth__get_hostthread_id);	fflush(stdout);

    Val result;

    if (status == -1)  result = RAISE_SYSERR__MAY_HEAPCLEAN(task, -1, NULL);
    else  	       result = make_two_slot_record( task,  TAGGED_INT_FROM_C_INT(fds[0]), TAGGED_INT_FROM_C_INT(fds[1]) );

									    EXIT_MYTHRYL_CALLABLE_C_FN(__func__);
    return result;
}


// COPYRIGHT (c) 1995 by AT&T Bell Laboratories.
// Subsequent changes by Jeff Prothero Copyright (c) 2010-2012,
// released per terms of SMLNJ-COPYRIGHT.

