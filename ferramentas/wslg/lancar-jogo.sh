#!/bin/bash
# Arcádia — lançador de jogos do teste no WSL (faz o papel do emuelecRunEmu.sh/setsettings.sh do aparelho).
# Recebe: <sistema> <núcleo> <rom> [-autosave 0|1] [-state_slot N] [-state_file F]
# e abre o RetroArch com o mesmo comportamento de salvamento da imagem:
#   savestate em /storage/roms/savestates/<sistema>; carrega o save só com -autosave 1 e
#   salva ao sair com -autosave 1 ou global.autosave=1 (como o setsettings.sh da imagem).
# pasta do próprio lançador (o ES roda com HOME=~/es-arcadia, então não dá para usar $HOME)
AQUI="$(dirname "$(readlink -f "$0")")"
SISTEMA="$1"; NUCLEO="$2"; ROM="$3"; shift 3
ARGS="$*"
# igual ao emuelecRunEmu.sh/setsettings.sh do aparelho: sem -autosave vale 0
AUTOSAVE=0; SLOT=0; ARQUIVO=""
while [ $# -gt 0 ]; do
  case "$1" in
    -autosave) AUTOSAVE="$2"; shift 2 ;;
    -state_slot) SLOT="$2"; shift 2 ;;
    -state_file) ARQUIVO="$2"; shift 2 ;;
    *) shift ;;
  esac
done
case "$NUCLEO" in
  fceumm) SO="$AQUI/cores/fceumm_libretro.so" ;;
  *) SO="/usr/lib/x86_64-linux-gnu/libretro/${NUCLEO}_libretro.so" ;;
esac
DIR="/storage/roms/savestates/$SISTEMA"; mkdir -p "$DIR"
CFG="$AQUI/retroarch-jogo.cfg"
CARREGAR=$([ "$AUTOSAVE" = "1" ] && echo true || echo false)
# salvar ao sair segue o global.autosave do emuelec.conf (Arcádia: "COMEÇAR DO INÍCIO" também salva)
GLOBAL="$(grep -oP '^global.autosave=\K\S+' /emuelec/configs/emuelec.conf)"
SALVAR=$([ "$AUTOSAVE" = "1" ] || [ "$GLOBAL" = "1" ] && echo true || echo false)
cat > "$CFG" <<EOF
savestate_directory = "$DIR"
savefile_directory = "$(dirname "$ROM")"
savestate_auto_save = "$SALVAR"
savestate_auto_load = "$CARREGAR"
savestate_thumbnail_enable = "true"
state_slot = "$SLOT"
autosave_interval = "10"
video_fullscreen = "false"
config_save_on_exit = "false"
EOF
echo "$(date '+%d/%m/%Y %H:%M:%S') $SISTEMA $NUCLEO $(basename "$ROM") autosave=$AUTOSAVE slot=$SLOT arquivo=$ARQUIVO args=[$ARGS]" >> /emuelec/logs/lancar-jogo.log
# no WSLg o RetroArch abriria pelo Wayland; força X11 para a janela poder ser capturada/controlada (xdotool)
unset WAYLAND_DISPLAY
exec retroarch --verbose -L "$SO" "$ROM" --appendconfig "$CFG" >> /emuelec/logs/retroarch.log 2>&1
