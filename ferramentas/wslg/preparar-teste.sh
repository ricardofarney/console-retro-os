#!/bin/bash
# Arcádia — prepara no Ubuntu (WSL) um ambiente igual ao de fábrica da imagem para testar
# o EmulationStation do fork em janela (WSLg). Só para testes no PC.
#
# Uso: bash preparar-teste.sh [--zerar]
#   --zerar  apaga o estado do teste (favoritos, saves, gamelists alterados) e começa do zero
#
# Cria (dentro do Ubuntu): /emuelec/{configs,themes,logs}, /storage/roms/{nes,megadrive,gbc,savestates}
# e a "home" do teste em ~/es-arcadia/.emulationstation.
set -e
PROJETO="/mnt/d/Adube Sistemas/Console de Jogo"
REPO="$PROJETO/console-retro-os"
PREVIA="$PROJETO/arcadia-preview/roms"
AQUI="$REPO/ferramentas/wslg"
HOME_TESTE="$HOME/es-arcadia"

if [ "${1:-}" = "--zerar" ]; then
  rm -rf "$HOME_TESTE" /storage/roms/savestates/* 2>/dev/null || true
  for s in nes megadrive gbc; do rm -f "/storage/roms/$s/gamelist.xml"; done
fi

sudo mkdir -p /emuelec/configs /emuelec/themes /emuelec/logs /storage/roms/savestates
sudo chown -R "$USER:$USER" /emuelec /storage

# configuração de fábrica (a mesma que vai na imagem)
tr -d '\r' < "$REPO/packages/sx05re/emuelec/config/emuelec/configs/emuelec.conf" > /emuelec/configs/emuelec.conf
mkdir -p "$HOME_TESTE/.emulationstation"
[ -f "$HOME_TESTE/.emulationstation/es_settings.cfg" ] || cp "$REPO/packages/sx05re/emuelec-emulationstation/config/es_settings.cfg" "$HOME_TESTE/.emulationstation/es_settings.cfg"
tr -d '\r' < "$AQUI/es_systems-teste.cfg" > "$HOME_TESTE/.emulationstation/es_systems.cfg"
tr -d '\r' < "$AQUI/es_input-teste.cfg" > "$HOME_TESTE/.emulationstation/es_input.cfg"

# tema exatamente como vai na imagem (pacote es-theme-arcadia copia temas/arcadia sem o LEIA-ME)
rm -rf /emuelec/themes/arcadia && mkdir -p /emuelec/themes/arcadia
cp -r "$REPO/temas/arcadia/." /emuelec/themes/arcadia/ && rm -f /emuelec/themes/arcadia/LEIA-ME.md

# jogos homebrew da prévia (com fichas em português e capa do Miniplanets)
for s in nes megadrive gbc; do
  mkdir -p "/storage/roms/$s"
  find "$PREVIA/$s" -maxdepth 1 -type f \( -name '*.nes' -o -name '*.bin' -o -name '*.gbc' \) -exec cp -n {} "/storage/roms/$s/" \;
  [ -d "$PREVIA/$s/images" ] && cp -rn "$PREVIA/$s/images" "/storage/roms/$s/"
  [ -f "/storage/roms/$s/gamelist.xml" ] || cp "$PREVIA/$s/gamelist.xml" "/storage/roms/$s/gamelist.xml"
done

# lançador de jogos do teste
tr -d '\r' < "$AQUI/lancar-jogo.sh" > "$HOME/arcadia-teste/lancar-jogo.sh"; chmod +x "$HOME/arcadia-teste/lancar-jogo.sh"
echo "Ambiente de teste pronto em $HOME_TESTE (ES), /emuelec e /storage/roms."
