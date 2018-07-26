MANPAGES=mdmv.1 mbox2maildir.1 notmuch-slurp-debbug.1 notmuch-extract-patch.1

all: $(MANPAGES)

clean:
	rm -f $(MANPAGES)

%.1: %.1.pod
	pod2man --section=1 --date="Debian Project" --center="User Commands" \
		--name=$(subst .1,,$@) \
		$^ $@
