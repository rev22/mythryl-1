#
# the makefile for the Signals library
#

SHELL =		/bin/sh

INC_DIR =	../../h
CLIB_DIR =	../

INCLUDES =	-I$(INC_DIR) -I$(CLIB_DIR) -I../../o

MAKE =		make
AR =		ar
ARFLAGS =	rcv
RANLIB =	ranlib

LIBRARY =	libmythryl-signal.a

VERSION =	v-dummy

OBJS =		libmythryl-signal.o \
		get-signal-mask.o \
		get-signal-state.o \
		set-signal-state.o \
		signal-is-supported-by-host-os.o \
		ascii-signal-name-to-portable-signal-id.o \
		maximum-valid-portable-signal-id.o \
		pause.o \
		set-signal-mask.o

$(LIBRARY)	: $(VERSION) $(OBJS)
	rm -rf $(LIBRARY)
	$(AR) $(ARFLAGS) $(LIBRARY) $(OBJS)
	$(RANLIB) $(LIBRARY)

$(VERSION) :
	echo "$(VERSION)" > $(VERSION)

.c.o:	$(INC_DIR)/system-dependent-unix-stuff.h $(INC_DIR)/runtime-base.h $(INC_DIR)/runtime-values.h \
	$(INC_DIR)/system-dependent-signal-stuff.h \
	$(CLIB_DIR)/raise-error.h cfun-proto-list.h cfun-list.h
	$(CC) $(CFLAGS) $(DEFS) $(INCLUDES) -c $<

clean :
	@rm -f v-* *.o $(LIBRARY)

