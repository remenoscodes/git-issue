prefix = /usr/local
bindir = $(prefix)/bin

SCRIPTS = $(wildcard bin/git-issue*)
VERSION = $(shell sed -n 's/^VERSION="\(.*\)"/\1/p' bin/git-issue)

all:
	@echo "git-issue $(VERSION)"
	@echo "  make install          Install to $(bindir)"
	@echo "  make install prefix=~ Install to ~/bin"
	@echo "  make uninstall        Remove from $(bindir)"
	@echo "  make test             Run all tests"

install:
	install -d $(DESTDIR)$(bindir)
	install -m 755 $(SCRIPTS) $(DESTDIR)$(bindir)/

uninstall:
	rm -f $(DESTDIR)$(bindir)/git-issue $(DESTDIR)$(bindir)/git-issue-*

test:
	@sh t/test-issue.sh
	@sh t/test-bridge.sh
	@sh t/test-merge.sh

clean:
	rm -rf t/tmp-*

.PHONY: all install uninstall test clean
