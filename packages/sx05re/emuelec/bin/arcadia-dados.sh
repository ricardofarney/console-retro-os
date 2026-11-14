#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Arcádia — proteção dos dados do usuário (saves, favoritos e configurações).
#
# Uso:
#   arcadia-dados.sh backup             cópia datada antes de atualizar (mantém as 3 últimas)
#   arcadia-dados.sh migrar-gamelists   garante os gamelist.xml em /storage/roms/<sistema>/
#
# O backup NÃO usa o nome ee_backup_config.tar.gz de propósito: esse arquivo é
# restaurado automaticamente no boot pelo emuelec_autostart.sh.

DESTINO="/storage/roms/backup/arcadia"
LOG="/emuelec/logs/arcadia-dados.log"
MANTER=3

registrar() { echo "$(date '+%d/%m/%Y %H:%M:%S') $*" | tee -a "${LOG}"; }

backup() {
  mkdir -p "${DESTINO}"
  local arquivo="${DESTINO}/antes-da-atualizacao-$(date '+%Y-%m-%d_%H%M').tar.gz"
  local itens=""
  for i in \
    /storage/.config/emuelec/configs \
    /storage/.config/emulationstation/es_settings.cfg \
    /storage/.config/emulationstation/es_input.cfg \
    /storage/.config/emulationstation/collections \
    /storage/.config/emulationstation/gamelists \
    /storage/.config/emulationstation/themesettings \
    /storage/.config/retroarch/retroarch.cfg \
    /storage/.config/retroarch/config \
    /storage/.config/ppsspp \
    /storage/.cache/bluetooth \
    /storage/.cache/hostname \
    /storage/.cache/timezone \
    /storage/.cache/services ; do
    [ -e "${i}" ] && itens="${itens} ${i}"
  done
  # shellcheck disable=SC2086
  if tar -czf "${arquivo}" ${itens} 2>/dev/null; then
    registrar "backup criado: ${arquivo}"
  else
    registrar "AVISO: backup incompleto: ${arquivo}"
  fi
  # mantém só os ${MANTER} mais recentes
  ls -1t "${DESTINO}"/antes-da-atualizacao-*.tar.gz 2>/dev/null | tail -n +$((MANTER + 1)) | while read -r velho; do
    rm -f "${velho}" && registrar "backup antigo removido: ${velho}"
  done
  sync
}

migrar_gamelists() {
  # O EmulationStation usa /storage/roms/<sistema>/gamelist.xml quando existe;
  # gamelists antigos em ~/.emulationstation/gamelists passam para junto das roms
  # (que nenhuma atualização apaga). O original fica como gamelist.xml.migrado.
  local base="/storage/.config/emulationstation/gamelists"
  [ -d "${base}" ] || return 0
  for g in "${base}"/*/gamelist.xml; do
    [ -f "${g}" ] || continue
    local sistema; sistema="$(basename "$(dirname "${g}")")"
    local alvo="/storage/roms/${sistema}/gamelist.xml"
    if [ -d "/storage/roms/${sistema}" ] && [ ! -f "${alvo}" ]; then
      cp -p "${g}" "${alvo}" && mv "${g}" "${g}.migrado" && registrar "gamelist migrado: ${sistema}"
    fi
  done
}

case "${1}" in
  backup) backup ;;
  migrar-gamelists) migrar_gamelists ;;
  *) echo "uso: $0 backup | migrar-gamelists"; exit 1 ;;
esac
