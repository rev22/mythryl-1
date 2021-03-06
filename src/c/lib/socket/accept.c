// accept.c

#include "../../mythryl-config.h"

#include <stdio.h>
#include <string.h>
#include <errno.h>

#include "sockets-osdep.h"
#include INCLUDE_SOCKET_H
#include "runtime-base.h"
#include "runtime-values.h"
#include "make-strings-and-vectors-etc.h"
#include "raise-error.h"
#include "cfun-proto-list.h"



// One of the library bindings exported via
//     src/c/lib/socket/cfun-list.h
// and thence
//     src/c/lib/socket/libmythryl-socket.c



Val   _lib7_Sock_accept   (Task* task,  Val arg)   {
    //=================
    //
    // Mythryl type:   Socket -> (Socket, Address)
    //
    // This fn gets bound as   accept'   in:
    //
    //     src/lib/std/src/socket/socket-guts.pkg

									    ENTER_MYTHRYL_CALLABLE_C_FN(__func__);

    int		socket = TAGGED_INT_TO_C_INT( arg );				// Last use of 'arg'.
    char	address_buf[  MAX_SOCK_ADDR_BYTESIZE ];
    socklen_t	address_len = MAX_SOCK_ADDR_BYTESIZE;
    int		new_socket;

    RELEASE_MYTHRYL_HEAP( task->hostthread, __func__, NULL );
	//
        do {
	    new_socket = accept (socket, (struct sockaddr*) address_buf, &address_len);
	    //	
        } while (new_socket < 0 && errno == EINTR);			/* Restart if interrupted by a SIGALRM or SIGCHLD or whatever.	*/
	//
    RECOVER_MYTHRYL_HEAP( task->hostthread, __func__ );

    Val result;

    if (new_socket == -1) {
        //
									    EXIT_MYTHRYL_CALLABLE_C_FN(__func__);
	result =  RAISE_SYSERR__MAY_HEAPCLEAN( task, new_socket, NULL);
        //
    } else {
        //
	Val data    =  make_biwordslots_vector_sized_in_bytes__may_heapclean(	task, address_buf,                  address_len, NULL );
	Val address =  make_vector_header(					task, UNT8_RO_VECTOR_TAGWORD, data, address_len);

	result =  make_two_slot_record(task,  TAGGED_INT_FROM_C_INT( new_socket ), address);

    }
									    EXIT_MYTHRYL_CALLABLE_C_FN(__func__);
    return result;
}


// COPYRIGHT (c) 1995 AT&T Bell Laboratories.
// Subsequent changes by Jeff Prothero Copyright (c) 2010-2012,
// released per terms of SMLNJ-COPYRIGHT.

