# Makefile.in
#
# The makefile for the "hostthread" (multicore) support library
#
# This makefile is/wouldbe invoked by the rule
#
#    $(CLIB_DIR)/hostthread/libmythryl-hostthread.a:  sizes-of-some-c-types--autogenerated.h
#	    (cd $(CLIB_DIR)/hostthread; $(MAKE)  $(LIB_MK_ARGS) libmythryl-hostthread.a)
#
# in
#
#     src/c/o/Makefile
#
# which derives from
#
#     src/c/o/Makefile.in
#
#

MAKE =		make
AR =		ar
ARFLAGS =	rcv
RANLIB =	ranlib

VERSION =	v-dummy

LIB =		libmythryl-hostthread.a

INC_DIR =	../h
INCLUDES =	-I$(INC_DIR)


# Each version of the multicore-support library has its own list of .o files:
#
SGI_OBJS	    =	hostthread-on-sgi.o
POSIX_THREADS_OBJS  =	hostthread-on-posix-threads.o



$(LIB) :	$(VERSION) $(OBJS)
	@rm -rf $(LIB)
	$(AR) $(ARFLAGS) $(LIB) $(OBJS)
	$(RANLIB) $(LIB)

$(VERSION) :
	echo "$(VERSION)" > $(VERSION)

hostthread-on-posix-threads.o:	hostthread-on-posix-threads.c \
		$(INC_DIR)/runtime-base.h $(INC_DIR)/runtime-configuration.h \
		$(INC_DIR)/runtime-values.h $(INC_DIR)/heap-tags.h \
		$(INC_DIR)/runtime-globals.h
	$(CC) -c $(CFLAGS) $(DEFS) $(INCLUDES) hostthread-on-posix-threads.c

clean :
	@rm -f v-* *.o $(LIB)
