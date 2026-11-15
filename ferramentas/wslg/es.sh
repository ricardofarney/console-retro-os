#!/bin/bash
# Arcádia — controla o EmulationStation do teste (WSLg).
#   es.sh abrir            abre o ES do fork em janela 1280x720 com a home do teste
#   es.sh fechar           fecha o ES (como o usuário fecharia; salva configurações)
#   es.sh tecla <tecla> [segundos]   envia uma tecla só para a janela do ES (xdotool); segundos = segurar
#   es.sh foto <arquivo.png>         captura a janela do ES
#   es.sh janela           mostra o id da janela
ES_DIR="$HOME/arcadia-es-teste/src"
HOME_TESTE="$HOME/es-arcadia"
export DISPLAY="${DISPLAY:-:0}"

janela() { xdotool search --onlyvisible --class emulationstation 2>/dev/null | tail -1; }

case "$1" in
  abrir)
    pkill -x emulationstation 2>/dev/null; sleep 1
    cd "$ES_DIR" || exit 1
    # como o emustation-config do aparelho: idioma vem do system.language do emuelec.conf
    L="$(grep -oP '^system.language=\K\S+' /emuelec/configs/emuelec.conf)"; L="${L:-en_US}"
    export LANG="$L.UTF-8" LANGUAGE="$L"
    HOME="$HOME_TESTE" nohup ./emulationstation --windowed --resolution 1280 720 > "$HOME/arcadia-logs/es-wslg.log" 2>&1 &
    for i in $(seq 1 40); do sleep 0.5; [ -n "$(janela)" ] && break; done
    echo "janela: $(janela)"
    ;;
  fechar)
    W=$(janela); [ -n "$W" ] && xdotool windowclose "$W" 2>/dev/null
    for i in $(seq 1 20); do sleep 0.5; pgrep -x emulationstation >/dev/null || break; done
    pkill -x emulationstation 2>/dev/null; echo "fechado"
    ;;
  tecla)
    W=$(janela); [ -z "$W" ] && { echo "ES não está aberto"; exit 1; }
    xdotool windowactivate --sync "$W" 2>/dev/null; xdotool windowfocus --sync "$W" 2>/dev/null
    if [ -n "${3:-}" ]; then xdotool keydown --window "$W" "$2"; sleep "$3"; xdotool keyup --window "$W" "$2"
    else xdotool key --window "$W" "$2"; fi
    ;;
  foto)
    W=$(janela); [ -z "$W" ] && { echo "ES não está aberto"; exit 1; }
    import -window "$W" "$2" 2>/dev/null && echo "foto: $2"
    ;;
  janela) janela ;;
  *) echo "uso: es.sh abrir|fechar|tecla <tecla> [s]|foto <arq>|janela"; exit 1 ;;
esac
