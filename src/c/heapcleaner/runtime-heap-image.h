// runtime-heap-image.h
//
// The definitions and typedefs that describe
// the layout of a Mythryl heap image in a file.
//
// This can be either an exported heap
// or a pickled datastructure.
//
// These files have the following basic layout:
//
//  Image header
//  Heap/Pickle header
//  External reference table
//  Image
//
// where the format of Image depends on the kind (heap vs. pickle).


#ifndef RUNTIME_HEAP_IMAGE_H
#define RUNTIME_HEAP_IMAGE_H

#include "sizes-of-some-c-types--autogenerated.h"
#include "task.h"
#include "heap.h"

// Tag to identify image byte order:
//
#define ORDER		0x00112233

// Yeap image version identifier (date in mmddyyyy form):
//
#define IMAGE_MAGIC	0x09082004

// Pickle heap image version identifier (date in 00mmddyy form):
//
#define PICKLE_MAGIC	0x00070995

// The kind of heap image:
//
#define EXPORT_HEAP_IMAGE	1
#define EXPORT_FN_IMAGE		2
#define NORMAL_DATASTRUCTURE_PICKLE		3
#define UNBOXED_PICKLE		4		// A pickled unboxed value.

#define SHEBANG_SIZE 256
typedef struct {				// The magic number and other version info.
    //
    char     shebang[ SHEBANG_SIZE ];		//
    Unt1    byte_order;			// ORDER tag.
    Unt1    magic;				// Magic number.
    Unt1    kind;				// EXPORT_HEAP_IMAGE, etc.
    char     arch[  12 ];			// Exporting machine's architecture.
    char     opsys[ 12 ];			// Exporting machine's operating system.
    //
} Heapfile_Header;


// Header for a heap image:
//
typedef struct {
    //
    int pthread_count;						// The number of Pthreads.
    int active_agegroups;					// The number of heap generations.
    int smallchunk_sibs_count;					// The number of small-chunk sibs (one each for pairs, records, strings, vectors).
    int hugechunk_sibs_count;					// The number of hugechunk kinds (currently 1 -- codechunks).
    int hugechunk_ramregion_count;				// The number of hugechunk regions in the exporting address space.
    int oldest_agegroup_keeping_idle_fromspace_buffers;		// The oldest agegroup retaining fromspace buffer, instead of freeing it after cleaning.
    //
    Punt agegroup0_buffer_bytesize;			// The size of the agegroup0 allocation buffers used by the runtime.
    //
    Val	pervasive_package_pickle_list;				// Contents of PERVASIVE_PACKAGE_PICKLE_LIST_REFCELL_GLOBAL.
    Val	runtime_pseudopackage;					// The run-time system compilation unit root.
    Val	math_package;						// The asmcoded Math package root (if defined).
    //
} Heap_Header;

// Header for a pickled-datastructure image:
//
typedef struct {
    Unt1    smallchunk_sibs_count;				// The number of small-chunk sib buffers (one each for pairs, records, strings and vectors).
    Unt1    hugechunk_sibs_count;				// The number of hugechunk kinds. (Currently just 1, for codechunks.)
    Unt1    hugechunk_ramregion_count;				// The number of hugechunk multipage-ram-regions in the exporting address space.
    Bool     contains_code;					// TRUE iff the pickle contains code.
    Val	     root_chunk;					// The pickle's root chunk.
} Pickle_Header;

// Header for the extern table:
//
typedef struct {
    int		externs_count;					// The number of external symbols.
    int		externs_bytesize;				// The size (in bytes) of the string table area.
} Externs_Header;


// Image of a Mythryl Pthread.
// The live registers are those specified
// by RET_MASK plus the current_thread,
// exception_fate and pc:
//
typedef struct {
    //
    Val	posix_interprocess_signal_handler;	// The contents of POSIX_INTERPROCESS_SIGNAL_HANDLER_REFCELL_GLOBAL.
    Val	stdArg;
    Val	stdCont;
    Val	stdClos;
    Val	pc;
    Val	exception_fate;
    Val	current_thread;
    Val	calleeSave[ CALLEE_SAVED_REGISTERS_COUNT ];
    //
} Pthread_Image;


// The heap header consists of 'active_agegroups' agegroup descriptions,
// each of which consists of (smallchunk_sibs_count+hugechunk_sibs_count) Sib_Header records.
// After the agegroup descriptors, there are hugechunk_ramregion_count Hugechunk_Region_Header
// records.  The page aligned heap image follows the heap header.
//

// A sib header.  Agegroups use this for both
// their regular sibs and their hugechunk sib:
//
typedef struct {
    int	   age;						// Agegroup of this sib:  0 <= age < heap->active_agegroups.
    int	   chunk_ilk;					// Sib buffer contents -- one of  RECORD_ILK, PAIR_ILK, STRING_ILK, VECTOR_ILK   from   src/c/h/sibid.h
    Unt1  offset;					// File position at which this sib buffer starts.
    //
    union {						// Additional info.
	struct {					// Info for regular sibs.
	    Punt  base_address;				// Base address of this sib buffer in the exporting address space.
	    Punt  bytesize;			// Size of the live data in this sib buffer.
	    Punt  rounded_bytesize;		// Padded size of this sib buffer in the image file.
	}  o;
	struct {					// Info for the hugechunk sib buffer.
	    int   hugechunk_count;			// Number of hugechunks in this agegroup.
	    int	  hugechunk_quanta_count;			// Number of hugechunk pages required.
	}  bo;						// "bo" == "big object" (old name for hugechunk -- should rename, maybe to "hc". XXX BUGGO FIXME)
    }		info;
} Sib_Header;


// hugechunk region header -- A descriptor of a
// hugechunk region in the exporting address space.
//
typedef struct {
    Punt	base_address;		// Base address of this hugechunk region in the exporting address space.
					// Note that this is the address of the header, not of the first page.
    Punt	first_ram_quantum;	// Address of the first ram quantum of the region in the exporting address space.
    Punt	bytesize;		// Total size of this hugechunk region, including the header.
    //
} Hugechunk_Region_Header;

// hugechunk header:
//
typedef struct {
    //
    int		age;			// The agegroup of this hugechunk.
    int		huge_ilk;		// Ilk of this hugechunk. Currently always CODE__HUGE_ILK		def in    src/c/h/sibid.h
    //
    Punt	base_address;		// Base address of this hugechunk in the exporting address space.
    Punt	bytesize;		// Size of this hugechunk.
    //
} Hugechunk_Header;


// External references.
//
#define IS_EXTERNAL_TAG( w )	(IS_TAGWORD( w ) && (GET_BTAG_FROM_TAGWORD( w ) == EXTERNAL_REFERENCE_IN_EXPORTED_HEAP_IMAGE_BTAG))
#define EXTERNAL_ID(     w )	GET_LENGTH_IN_WORDS_FROM_TAGWORD( w )

// Pointer tagging operations:  When saving and loading
// heapgraphs on disk in
//
//     src/c/heapcleaner/datastructure-unpickler.c
//     src/c/heapcleaner/datastructure-pickler.c
//     
// we pack a pointer's kind and its address together
// in one word, where 'kind' is one of
//
//     NEW_KIND / RECORD_KIND / PAIR_KIND / STRING_KIND	/ VECTOR_KIND / CODE_KIND
//
// from    src/c/h/sibid.h
//
#define HIO_ID_BITS			8								// Used only in this header.
#define HIO_ADDR_BITS			(BITS_PER_WORD - HIO_ID_BITS)					// Used only in this header.
#define HIO_ADDR_MASK			((1 << HIO_ADDR_BITS) - 1)					// Used only in this header.

#define HIO_TAG_PTR(kind,offset)	PTR_CAST( Val, ((kind)<<HIO_ADDR_BITS)|(Punt)(offset))		// Used in      src/c/heapcleaner/datastructure-pickler.c   +   src/c/heapcleaner/datastructure-pickler-cleaner.c
#define HIO_GET_ID(p)			(HEAP_POINTER_AS_UNT(p) >> HIO_ADDR_BITS)			// Used only in src/c/heapcleaner/datastructure-unpickler.c
#define HIO_GET_OFFSET(p)		(HEAP_POINTER_AS_UNT(p) &  HIO_ADDR_MASK)			// Used only in src/c/heapcleaner/datastructure-unpickler.c	

#endif // RUNTIME_HEAP_IMAGE_H




// COPYRIGHT (c) 1992 by AT&T Bell Laboratories.
// Subsequent changes by Jeff Prothero Copyright (c) 2010-2011,
// released under Gnu Public Licence version 3.

