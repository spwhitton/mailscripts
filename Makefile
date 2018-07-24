MANPAGES=mdmv.1

all: $(MANPAGES)

%.1: %.1.pod
	pod2man --section=1 --date="Debian Project" --center="User Commands" \
		--name=$(subst .1,,$@) \
		$^ $@
