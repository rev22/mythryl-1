// getcwd.c


#include "../../mythryl-config.h"

#include <stdio.h>

#include "system-dependent-unix-stuff.h"
#include "runtime-base.h"
#include "runtime-values.h"
#include "make-strings-and-vectors-etc.h"
#include "raise-error.h"
#include "cfun-proto-list.h"

#if HAVE_UNISTD_H
    #include <unistd.h>
#endif

#if HAVE_LIMITS_H
    #include <limits.h>
#endif

#include <errno.h>

#if HAVE_SYS_PARAM_H
    #include <sys/param.h>
#endif



// One of the library bindings exported via
//     src/c/lib/posix-file-system/cfun-list.h
// and thence
//     src/c/lib/posix-file-system/libmythryl-posix-file-system.c



Val   _lib7_P_FileSys_getcwd   (Task* task,  Val arg)   {
    //======================
    //
    // Mythryl type:  Void -> String
    //
    // Get current working directory pathname.
    //
    // Should this be written to avoid the extra copy?		XXX BUGGO FIXME
    //
    // This fn gets bound as   current_directory   in:
    //
    //     src/lib/std/src/psx/posix-file.pkg
    //     src/lib/std/src/psx/posix-file-system-64.pkg

									    ENTER_MYTHRYL_CALLABLE_C_FN(__func__);

    char  path[ MAXPATHLEN ];

    RELEASE_MYTHRYL_HEAP( task->hostthread, __func__, NULL );
	//
	char* status = getcwd(path, MAXPATHLEN);
	//
    RECOVER_MYTHRYL_HEAP( task->hostthread, __func__ );

    if (status != NULL)    return make_ascii_string_from_c_string__may_heapclean (task, path, NULL);

    if (errno != ERANGE)   return RAISE_SYSERR__MAY_HEAPCLEAN(task, status, NULL);

    int   buflen = 2*MAXPATHLEN;
    char* buf    = MALLOC( buflen );

    if (buf == NULL)      return RAISE_ERROR__MAY_HEAPCLEAN(task, "no malloc memory", NULL);

    while (status == NULL) {
	//
	RELEASE_MYTHRYL_HEAP( task->hostthread, __func__, NULL );
	    //
            status = getcwd(buf, buflen);
	    //
    	RECOVER_MYTHRYL_HEAP( task->hostthread, __func__ );
	//
	//
        FREE (buf);
	//
        if (errno != ERANGE)    return RAISE_SYSERR__MAY_HEAPCLEAN(task, status, NULL);
	//
        buflen = 2*buflen;
        buf    = MALLOC( buflen );
	//
        if (buf == NULL)	return RAISE_ERROR__MAY_HEAPCLEAN(task, "no malloc memory", NULL);
    }
      
    Val result = make_ascii_string_from_c_string__may_heapclean (task, buf, NULL);
    //
    FREE( buf );
    //  
									    EXIT_MYTHRYL_CALLABLE_C_FN(__func__);
    return result;
}


// COPYRIGHT (c) 1995 by AT&T Bell Laboratories.
// Subsequent changes by Jeff Prothero Copyright (c) 2010-2012,
// released per terms of SMLNJ-COPYRIGHT.

