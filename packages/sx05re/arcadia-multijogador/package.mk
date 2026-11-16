# SPDX-License-Identifier: GPL-2.0-or-later
# Arcádia — multitap automático por jogo (até 4 jogadores, ver docs/MULTIJOGADOR.md)
# Fonte: pasta ferramentas/multijogador deste repositório (sem download).

PKG_NAME="arcadia-multijogador"
PKG_VERSION="1.0"
PKG_REV="1"
PKG_ARCH="any"
PKG_LICENSE="GPL-2.0-or-later"
PKG_SITE="https://github.com/ricardofarney/console-retro-os"
PKG_URL=""
PKG_DEPENDS_TARGET="toolchain"
PKG_SECTION="emuelec"
PKG_SHORTDESC="Arcádia: liga o multitap só nos jogos de 3 ou mais jogadores"
PKG_TOOLCHAIN="manual"
# recompila o pacote sempre que algo em ferramentas/multijogador mudar
PKG_NEED_UNPACK="${ROOT}/ferramentas/multijogador"

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/bin ${INSTALL}/usr/share/arcadia/multijogador
  cp ${ROOT}/ferramentas/multijogador/arcadia-multijogador.sh ${INSTALL}/usr/bin/
  sed -i 's/\r$//' ${INSTALL}/usr/bin/arcadia-multijogador.sh
  chmod 0755 ${INSTALL}/usr/bin/arcadia-multijogador.sh
  for f in ${ROOT}/ferramentas/multijogador/listas/*.txt; do
    sed 's/\r$//' "${f}" > ${INSTALL}/usr/share/arcadia/multijogador/$(basename "${f}")
  done
}
