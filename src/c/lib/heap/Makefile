#
# the makefile for the runtime library
#

SHELL =		/bin/sh

INC_DIR =	../../h
CLIB_DIR =	../

INCLUDES =	-I$(INC_DIR) -I$(CLIB_DIR) -I../../o
GC_INCLUDES =	$(INCLUDES) -I../../heapcleaner

MAKE =		make
AR =		ar
ARFLAGS =	rcv
RANLIB =	ranlib

LIBRARY =	libmythryl-heap.a

VERSION =	v-dummy

OBJS =		libmythryl-heap.o

$(LIBRARY)	: $(VERSION) $(OBJS)
	rm -rf $(LIBRARY)
	$(AR) $(ARFLAGS) $(LIBRARY) $(OBJS)
	$(RANLIB) $(LIBRARY)

$(VERSION) :
	echo "$(VERSION)" > $(VERSION)

.c.o:	$(INC_DIR)/system-dependent-unix-stuff.h $(INC_DIR)/runtime-base.h $(INC_DIR)/runtime-values.h \
	$(INC_DIR)/make-strings-and-vectors-etc.h \
	$(CLIB_DIR)/raise-error.h 
	$(CC) $(CFLAGS) $(DEFS) $(GC_INCLUDES) -c $<

clean :
	@rm -f v-* *.o $(LIBRARY)

