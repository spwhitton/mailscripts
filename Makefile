MANPAGES=mdmv.1 mbox2maildir.1 \
	notmuch-slurp-debbug.1 notmuch-extract-patch.1 maildir-import-patch.1 \
	mbox-extract-patch.1 \
	imap-dl.1 \
	email-extract-openpgp-certs.1 \
	email-print-mime-structure.1 \
	notmuch-import-patch.1 \
	gmi2email.1
COMPLETIONS=completions/bash/email-print-mime-structure completions/bash/imap-dl

all: $(MANPAGES) $(COMPLETIONS)

check:
	./tests/email-print-mime-structure.sh
	mypy --strict ./email-print-mime-structure
	mypy --strict ./imap-dl

clean:
	rm -f $(MANPAGES)
	rm -rf completions .mypy_cache

%.1: %.1.pod
	pod2man --section=1 --date="Debian Project" --center="User Commands" \
		--utf8 \
		--name=$(subst .1,,$@) \
		$^ $@

completions/bash/%:
	mkdir -p completions/bash
	register-python-argcomplete3 $(notdir $@) >$@.tmp
	mv $@.tmp $@
