#
# Makefile for the Gtk library glue layer
#
# We get invoked by:
#     src/c/o/Makefile.in

SHELL =		/bin/sh

IDIR =	../../../../c/h
CDIR =	../../../../c/lib

INCS =	-I$(IDIR) -I$(CDIR) -I../../../../c/o

AR =		ar
ARFLAGS =	rcv
RANLIB =	ranlib

LIBRARY =	libmythryl-gtk.a

VERSION =	v-dummy

OBJS =		libmythryl-gtk.o

# NOTE: 'pkg-config' is the preferred mechanism on Debian Linux;
#       if your distro does not support it, have it you may need
#       to tweak the below lines by hand to get them to compile + link:
#
# Hrm: Can't figure out where we should be putting:   `pkg-config --libs gtk+-2.0`

$(LIBRARY)	: $(VERSION) $(OBJS)
	rm -rf $(LIBRARY)
	$(AR) $(ARFLAGS) $(LIBRARY) $(OBJS)
	$(RANLIB) $(LIBRARY)

$(VERSION) :
	echo "$(VERSION)" > $(VERSION)

.c.o:	$(INC_DIR)/system-dependent-unix-stuff.h $(INC_DIR)/runtime-base.h $(INC_DIR)/runtime-values.h $(CLIB_DIR)/raise-error.h cfun-proto-list.h cfun-list.h
	$(CC) $(CFLAGS) $(DEFS) $(INCS) `pkg-config --cflags gtk+-2.0` -c $<

# This gets invoked mainly via
#     clean:
# target in src/c/lib/Makefile
#
clean :
	@rm -f v-* *.o $(LIBRARY)

