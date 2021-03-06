// name-val.h
//
//
// Header file for handling string-to-int lookup.


#ifndef _NAME_VAL_
#define _NAME_VAL_

#include <windows.h>

typedef DWORD data_t;
  
typedef struct {
  char*      name;
  data_t     data;
} name_val_t;

extern name_val_t *nv_lookup (char *, name_val_t *, int);

#endif // _NAME_VAL__



// COPYRIGHT (c) 1996 Bell Laboratories, Lucent Technologies
// Subsequent changes by Jeff Prothero Copyright (c) 2010-2012,
// released per terms of SMLNJ-COPYRIGHT.

