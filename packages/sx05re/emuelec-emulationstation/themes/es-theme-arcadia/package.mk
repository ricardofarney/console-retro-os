# SPDX-License-Identifier: GPL-2.0-or-later
# Arcádia — tema do EmulationStation (estilo "colorido por console", ver docs/DESIGN.md)
# Fonte: pasta temas/arcadia deste repositório (sem download).

PKG_NAME="es-theme-arcadia"
PKG_VERSION="0.2"
PKG_REV="1"
PKG_ARCH="any"
PKG_LICENSE="GPL-2.0-or-later"
PKG_SITE="https://github.com/ricardofarney/console-retro-os"
PKG_URL=""
PKG_DEPENDS_TARGET="toolchain"
PKG_SECTION="emuelec"
PKG_SHORTDESC="Arcádia: tema do EmulationStation em português, colorido por console"
PKG_TOOLCHAIN="manual"
# recompila o pacote sempre que algo em temas/arcadia mudar
PKG_NEED_UNPACK="${ROOT}/temas/arcadia"

makeinstall_target() {
  mkdir -p ${INSTALL}/usr/config/emulationstation/themes/arcadia
  cp -r ${ROOT}/temas/arcadia/* ${INSTALL}/usr/config/emulationstation/themes/arcadia/
  rm -f ${INSTALL}/usr/config/emulationstation/themes/arcadia/LEIA-ME.md
}
