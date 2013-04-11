%.1: %.txt
	stx2any -T man $< >$@

%.ps: %.1
	groff -mandoc $< >$@

MANPAGES=my.1 build-an-executable-mythryl-heap-image.1 mythryl-gtk-slave.1 mythryl-ld.1 mythryl-runtime-intel32.1 mythryl.1 mythryld.1

all: $(MANPAGES)

clean:
	rm -rf *.ps

maintainer-clean:
	rm -rf $(MANPAGES)