// libmythryl-math.c

#include "../../mythryl-config.h"

#include "runtime-base.h"
#include "mythryl-callable-c-libraries.h"
#include "cfun-proto-list.h"


// This file defines the "mapth" library of Mythryl-callable
// C functions, accessible at the Mythryl level via:
//
//     my  atan64:  Float -> Float
//         =
//	   mythryl_callable_c_library_interface::find_c_function { lib_name => "math", fun_name => "atan64" };
// 
// or such -- although it appears no functions currently do so (?!) with the exception of
//
//     ci::find_c_function { lib_name => "math", fun_name => "get_or_set_rounding_mode" };
// in
//     src/lib/std/src/ieee-float.pkg
//
#define CFUNC(NAME, NAME2, FUNC, LIB7TYPE)	CFUNC_BIND(NAME, NAME2, FUNC, LIB7TYPE)
static Mythryl_Name_With_C_Function CFunTable[] = {
#include "cfun-list.h"										// Actual function list is in src/c/lib/math/cfun-list.h
	CFUNC_NULL_BIND
    };
#undef CFUNC


// The Math library:
//
// Our record                Libmythryl_Math
// gets compiled into        src/c/lib/mythryl-callable-c-libraries-list.h
// and thus ultimately       mythryl_callable_c_libraries__local []
// in                        src/c/lib/mythryl-callable-c-libraries.c
//
Mythryl_Callable_C_Library	    Libmythryl_Math = {						// Mythryl_Callable_C_Library		def in    src/c/h/mythryl-callable-c-libraries.h
    //                              ===============
    CLIB_NAME,
    CLIB_VERSION,
    CLIB_DATE,
    NULL,
    CFunTable
};



// COPYRIGHT (c) 1994 AT&T Bell Laboratories.
// Subsequent changes by Jeff Prothero Copyright (c) 2010-2012,
// released per terms of SMLNJ-COPYRIGHT.

