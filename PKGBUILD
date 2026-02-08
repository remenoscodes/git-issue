# Maintainer: Emerson Soares <remenoscodes@gmail.com>

pkgname=git-issue
pkgver=1.0.1
pkgrel=1
pkgdesc="Distributed issue tracking system built on Git"
arch=('any')
url="https://github.com/remenoscodes/git-issue"
license=('GPL2')
depends=('git' 'jq')
makedepends=()
optdepends=(
    'github-cli: for GitHub bridge functionality'
)
source=("${pkgname}-${pkgver}.tar.gz::https://github.com/remenoscodes/git-issue/releases/download/v${pkgver}/git-issue-v${pkgver}.tar.gz")
sha256sums=('0539533d62a3049d8bb87d1db91d80b8da09d29026294a6e04f4f50f1fd3b437')

package() {
    cd "${srcdir}/git-issue-v${pkgver}"

    # Install binaries
    install -d "${pkgdir}/usr/bin"
    install -m755 bin/git-issue* "${pkgdir}/usr/bin/"

    # Install documentation
    install -d "${pkgdir}/usr/share/doc/${pkgname}"
    install -m644 README.md "${pkgdir}/usr/share/doc/${pkgname}/"
    install -m644 ISSUE-FORMAT.md "${pkgdir}/usr/share/doc/${pkgname}/"
    install -m644 LICENSE "${pkgdir}/usr/share/doc/${pkgname}/"

    # Install man pages if they exist
    if [ -d doc ]; then
        install -d "${pkgdir}/usr/share/man/man1"
        install -m644 doc/*.1 "${pkgdir}/usr/share/man/man1/" 2>/dev/null || true
    fi
}

check() {
    cd "${srcdir}/git-issue-v${pkgver}"

    # Basic sanity checks
    [ -f bin/git-issue ] || return 1
    [ -x bin/git-issue ] || return 1

    # Check version
    ./bin/git-issue version | grep -q "${pkgver}" || return 1
}
