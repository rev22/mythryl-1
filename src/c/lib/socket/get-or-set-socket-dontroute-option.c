// get-or-set-socket-dontroute-option.c


#include "../../mythryl-config.h"

#include "sockets-osdep.h"
#include INCLUDE_SOCKET_H
#include "runtime-base.h"
#include "runtime-values.h"
#include "raise-error.h"
#include "cfun-proto-list.h"
#include "socket-util.h"

/*
###        "The popular mind often pictures gigantic flying machines
###         speeding across the Atlantic carrying innumerable passengers
###         in a way analogous to our modern steamships.
###         It seems safe to say that such ideas are wholly visionary." 
###
###                    -- William H. Pickering, astronomer 1910
*/


// One of the library bindings exported via
//     src/c/lib/socket/cfun-list.h
// and thence
//     src/c/lib/socket/libmythryl-socket.c



Val   get_or_set_socket_dontroute_option   (Task* task,  Val arg)   {
    //==================================
    //
    // Mythryl type:  (Socket_Fd, Null_Or(Bool)) -> Bool
    //
    // This function gets bound as   ctl_dontroute   in:
    //
    //     src/lib/std/src/socket/socket-guts.pkg
												ENTER_MYTHRYL_CALLABLE_C_FN(__func__);

    Val result = get_or_set_boolean_socket_option (task, arg, SO_DONTROUTE);			// get_or_set_boolean_socket_option		def in    src/c/lib/socket/get-or-set-boolean-socket-option.c
	//
	// We do the RELEASE_MYTHRYL_HEAP/RECOVER_MYTHRYL_HEAP stuff in
	// get_or_set_boolean_socket_option().
												EXIT_MYTHRYL_CALLABLE_C_FN(__func__);
    return result;
}


// COPYRIGHT (c) 1995 AT&T Bell Laboratories.
// Subsequent changes by Jeff Prothero Copyright (c) 2010-2012,
// released per terms of SMLNJ-COPYRIGHT.

