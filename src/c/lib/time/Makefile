#
# the makefile for the Time library
#

SHELL =		/bin/sh

INC_DIR =	../../h
CLIB_DIR =	../

INCLUDES =	-I$(INC_DIR) -I$(CLIB_DIR) -I../../o

MAKE =		make
AR =		ar
ARFLAGS =	rcv
RANLIB =	ranlib

LIBRARY =	libmythryl-time.a

VERSION =	v-dummy

OBJS =		libmythryl-time.o \
		gettime.o \
		timeofday.o

$(LIBRARY)	: $(VERSION) $(OBJS)
	rm -rf $(LIBRARY)
	$(AR) $(ARFLAGS) $(LIBRARY) $(OBJS)
	$(RANLIB) $(LIBRARY)

$(VERSION) :
	echo "$(VERSION)" > $(VERSION)

.c.o:	$(INC_DIR)/system-dependent-unix-stuff.h $(INC_DIR)/runtime-base.h $(INC_DIR)/runtime-values.h \
	$(CLIB_DIR)/raise-error.h cfun-proto-list.h cfun-list.h
	$(CC) $(CFLAGS) $(DEFS) $(INCLUDES) -c $<

clean :
	@rm -f v-* *.o $(LIBRARY)

