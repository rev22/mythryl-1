#
# the makefile for the C libraries
#
# Currently, this is only used to clean the library directories.
#

CFLAGS =	-O -std=c99 -Wall
ARFLAGS =	rcv
RANLIB =	ranlib

VERSION =	v-dummy

LIBS =		posix-os/libmythryl-posix-os.a \
		heap/libmythryl-heap.a \
		kludge/libmythryl-kludge.a \
		signal/libmythryl-signal.a \
		space-and-time-profiling/libmythryl-space-and-time-profiling.a \
		socket/libmythryl-socket.a \
		time/libmythryl-time.a \
		date/libmythryl-date.a \
		math/libmythryl-math.a \
		hostthread/libmythryl-hostthread.a \
		posix-error/libmythryl-posix-error.a \
		posix-file-system/libmythryl-posix-file-system.a \
		posix-io/libmythryl-posix-io.a \
		posix-process-environment/libmythryl-posix-process-environment.a \
		posix-process/libmythryl-posix-process.a \
		posix-passwd/libmythryl-posix-passwd-db.a \
		posix-tty/libmythryl-posix-tty.a \
		ccalls/libmythryl-ccalls.a \
		dynamic-loading/libmythryl-dynamic-loading.a

LIB_DIRS =	posix-os \
		heap \
		kludge \
		signal \
		socket \
		space-and-time-profiling \
		time \
		date \
		math \
		hostthread \
		posix-error \
		posix-file-system \
		posix-io \
		posix-process-environment \
		posix-process \
		posix-passwd \
		posix-tty \
		ccalls \
		dynamic-loading


# include directories for this level
#
OBJS_DIR =	../o
INC_DIR =	../h
INCLUDES =	-I$(OBJS_DIR) -I$(INC_DIR)

#
# Include directories for the library sub-directories
#
LIB_OBJS_DIR =	../../o
LIB_INC_DIR =	../../h
LIB_INCLUDES =	-I$(LIB_OBJS_DIR) -I$(LIB_INC_DIR) -I..

#
# Arguments to recursive make
#
LIB_MK_ARGS =		VERSION="$(VERSION)" \
			MAKE="$(MAKE)" \
			CC="$(CC)" CFLAGS="$(CFLAGS)" DEFS="$(DEFS)" \
			AR="$(AR)" ARFLAGS="$(ARFLAGS)" \
			RANLIB="$(RANLIB)" \
			INCLUDES="$(LIB_INCLUDES)"

###################################################################################
# Do not edit this or following lines --- they are autobuilt.  (patchname="defs")
# Do not edit this or preceding lines --- they are autobuilt.
###################################################################################

# This doesn't appear to get used,
# instead our subdirectories get
# compiled via direct invocations
# from src/c/o/Makefile:
#
all:	$(VERSION) 
	-for dir in $(LIB_DIRS); do \
	  (cd $$dir; echo "src/c/lib/Makefile building $$dir"; $(MAKE) $(LIB_MK_ARGS)) ; \
	done

$(VERSION):
	echo "$(VERSION)" > $(VERSION)

clean:
	@-for dir in $(LIB_DIRS); do \
	  (cd $$dir; $(MAKE) MAKE="$(MAKE)" clean) ; \
	done
	@rm -f v-* *.o

