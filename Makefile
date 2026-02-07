prefix = /usr/local
bindir = $(prefix)/bin

SCRIPTS = $(wildcard bin/git-issue*)

install:
	install -d $(DESTDIR)$(bindir)
	install -m 755 $(SCRIPTS) $(DESTDIR)$(bindir)/

uninstall:
	rm -f $(DESTDIR)$(bindir)/git-issue $(DESTDIR)$(bindir)/git-issue-*

test:
	sh t/test-issue.sh
	sh t/test-bridge.sh

.PHONY: install uninstall test
