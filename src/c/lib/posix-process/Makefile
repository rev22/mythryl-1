#
# A template makefile for a C function library
#

SHELL =		/bin/sh

INC_DIR =	../../h
CLIB_DIR =	../

INCLUDES =	-I$(INC_DIR) -I$(CLIB_DIR) -I../../o

MAKE =		make
AR =		ar
ARFLAGS =	rcv
RANLIB =	ranlib

LIBRARY =	libmythryl-posix-process.a

VERSION =	v-dummy

OBJS =	libmythryl-posix-process.o \
        osval.o \
        fork.o \
        exec.o \
        execp.o \
        exece.o \
        waitpid.o \
        exit.o \
        kill.o \
        alarm.o \
        pause.o \
        sleep.o

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

