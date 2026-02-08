#!/bin/sh
#
# git-native-issue installer
# Usage: ./install.sh [PREFIX]
#
# Installs git-native-issue to PREFIX/bin (default: /usr/local)
# Installs man pages to PREFIX/share/man/man1
#

set -e

PREFIX="${1:-/usr/local}"

echo "Installing git-native-issue to $PREFIX/bin"

# Check we're in the git-native-issue source directory
if ! test -f bin/git-issue
then
	echo "error: must run from git-native-issue source directory" >&2
	exit 1
fi

# Create directories
mkdir -p "$PREFIX/bin"
mkdir -p "$PREFIX/share/man/man1"

# Install binaries
for script in bin/git-issue*
do
	install -m 755 "$script" "$PREFIX/bin/"
	echo "  installed $(basename "$script")"
done

# Install man pages
if test -d doc
then
	for man in doc/*.1
	do
		install -m 644 "$man" "$PREFIX/share/man/man1/"
		echo "  installed $(basename "$man")"
	done
fi

echo ""
echo "✓ git-native-issue installed successfully!"
echo ""
echo "Try: git issue create \"Test installation\""
echo ""
echo "To uninstall, run:"
echo "  rm $PREFIX/bin/git-issue*"
echo "  rm $PREFIX/share/man/man1/git-issue*.1"
