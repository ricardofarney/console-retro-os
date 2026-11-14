# SPDX-License-Identifier: GPL-2.0-or-later
# Arcadia: submodulo ext/eigen do yabasanshiroSA_1_5 (so descompactado, nao compilado).
# O projeto de origem apagou a branch pi4; o codigo vem como arquivo do commit e este
# pacote fornece o submodulo no commit exato que ele usava.

PKG_NAME="eigen-yabasanshiro"
PKG_VERSION="c34a9130bc585b288703bd9716d7efae194974e2"
PKG_SHA256="f89ca2fc1cad93c7184d5f0472076c73d7182d9dca04809ba673f5a594242a3d"
PKG_LICENSE="MPL-2.0"
PKG_SITE="https://github.com/libigl/eigen"
PKG_URL="${PKG_SITE}/archive/${PKG_VERSION}.tar.gz"
PKG_SOURCE_DIR="eigen-${PKG_VERSION}"
PKG_DEPENDS_TARGET="toolchain"
PKG_LONGDESC="Eigen (headers) usado pelo nanogui-sdl do yabasanshiroSA_1_5"
PKG_TOOLCHAIN="manual"
