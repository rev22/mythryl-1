// localtime.c

#include "../../mythryl-config.h"

#include <stdio.h>
#include <time.h>

#include "runtime-base.h"
#include "make-strings-and-vectors-etc.h"
#include "cfun-proto-list.h"
#include "raise-error.h"

// One of the library bindings exported via
//     src/c/lib/date/cfun-list.h
// and thence
//     src/c/lib/date/libmythryl-date.c



Val   _lib7_Date_local_time   (Task* task,  Val arg) {
    //=====================
    //
    // Mythryl type:  one_word_int::Int -> (Int, Int, Int, Int, Int, Int, Int, Int, Int)
    //
    // Takes a local time value (in seconds), and converts it to a 9-tuple with
    // the fields:  tm_sec, tm_min, tm_hour, tm_mday, tm_mon, tm_year, tm_wday,
    // tm_yday, and tm_isdst.
    //
    // This fn gets bound to   local_time'   in:
    //
    //     src/lib/std/src/date.pkg

									    ENTER_MYTHRYL_CALLABLE_C_FN(__func__);

    time_t t =  (time_t)  INT1_LIB7toC( arg );

    RELEASE_MYTHRYL_HEAP( task->hostthread, __func__, NULL );
	//
        struct tm*  tm =  localtime( &t );
	//
    RECOVER_MYTHRYL_HEAP( task->hostthread, __func__ );

    if (tm == NULL)   RAISE_SYSERR__MAY_HEAPCLEAN( task, 0, NULL );

    set_slot_in_nascent_heapchunk(task, 0, MAKE_TAGWORD(PAIRS_AND_RECORDS_BTAG, 9));
    set_slot_in_nascent_heapchunk(task, 1, TAGGED_INT_FROM_C_INT(tm->tm_sec));
    set_slot_in_nascent_heapchunk(task, 2, TAGGED_INT_FROM_C_INT(tm->tm_min));
    set_slot_in_nascent_heapchunk(task, 3, TAGGED_INT_FROM_C_INT(tm->tm_hour));
    set_slot_in_nascent_heapchunk(task, 4, TAGGED_INT_FROM_C_INT(tm->tm_mday));
    set_slot_in_nascent_heapchunk(task, 5, TAGGED_INT_FROM_C_INT(tm->tm_mon));
    set_slot_in_nascent_heapchunk(task, 6, TAGGED_INT_FROM_C_INT(tm->tm_year));
    set_slot_in_nascent_heapchunk(task, 7, TAGGED_INT_FROM_C_INT(tm->tm_wday));
    set_slot_in_nascent_heapchunk(task, 8, TAGGED_INT_FROM_C_INT(tm->tm_yday));
    set_slot_in_nascent_heapchunk(task, 9, TAGGED_INT_FROM_C_INT(tm->tm_isdst));

    Val result = commit_nascent_heapchunk(task, 9);
									    EXIT_MYTHRYL_CALLABLE_C_FN(__func__);
    return result;
}


// COPYRIGHT (c) 1995 AT&T Bell Laboratories.
// Subsequent changes by Jeff Prothero Copyright (c) 2010-2012,
// released per terms of SMLNJ-COPYRIGHT.

