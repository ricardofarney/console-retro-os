#!/bin/bash
# Arcádia — prova no PC (WSLg) de que o RetroArch carrega o override de multitap gerado
# pelo arcadia-multijogador.sh e que o núcleo aceita o tipo de controle.
#
# Usa os núcleos da imagem (mesmos commits do build) compilados para o PC em
# ~/arcadia-teste/nucleos-mj e o RetroArch do Ubuntu. Os "jogos" são arquivos de teste
# com o nome oficial (No-Intro/Redump) — o override é escolhido pelo NOME do arquivo.
#
# Uso (dentro do Ubuntu do WSL):
#   testar-retroarch.sh provar          (todos os casos + relatório em imagens-compiladas\logs)
#   testar-retroarch.sh preparar
#   testar-retroarch.sh abrir <plataforma> <núcleo> <arquivo do jogo>
#   testar-retroarch.sh cmd <COMANDO...> | tecla <tecla...> | foto <arquivo.png> | fechar | log

T="${HOME}/arcadia-teste-ra-mj"
REPO="/mnt/d/Adube Sistemas/Console de Jogo/console-retro-os"
MJ="${REPO}/ferramentas/multijogador"
NUCLEOS="${HOME}/arcadia-teste/nucleos-mj"

export ARCADIA_MJ_LISTAS="${T}/listas" ARCADIA_MJ_CONFIG="${T}/config" \
       ARCADIA_MJ_COREOPTS="${T}/core-options.cfg" ARCADIA_MJ_LOG="${T}/gerador.log"

janela() { xdotool search --onlyvisible --class retroarch 2>/dev/null | tail -1; }

case "${1}" in
  preparar)
    rm -rf "${T}"
    mkdir -p "${T}/fotos" "${T}/listas" "${T}/config" "${T}/roms/snes" "${T}/roms/megadrive" "${T}/roms/psx" "${T}/bios"
    tr -d '\r' < "${MJ}/arcadia-multijogador.sh" > "${T}/arcadia-multijogador.sh"
    for f in "${MJ}"/listas/*.txt; do tr -d '\r' < "${f}" > "${T}/listas/$(basename "${f}")"; done
    tr -d '\r' < "${REPO}/packages/sx05re/emuelec/config/retroarch/retroarch-core-options.cfg" > "${T}/core-options.cfg"
    cat > "${T}/retroarch.cfg" <<EOF
rgui_config_directory = "${T}/config"
core_options_path = "${T}/core-options.cfg"
game_specific_options = "true"
auto_overrides_enable = "true"
input_max_users = "5"
menu_driver = "rgui"
video_fullscreen = "false"
config_save_on_exit = "false"
savestate_auto_load = "false"
savestate_auto_save = "false"
system_directory = "${T}/bios"
audio_enable = "false"
pause_nonactive = "false"
input_autodetect_enable = "false"
input_menu_toggle = "f1"
input_exit_emulator = "escape"
video_context_driver = "x"
video_driver = "gl"
network_cmd_enable = "true"
network_cmd_port = "55355"
screenshot_directory = "${T}/fotos"
video_gpu_screenshot = "true"
auto_screenshot_filename = "false"
EOF
    # arquivos de teste: o conteúdo não importa para o override (vale o nome)
    head -c 1048576 /dev/zero > "${T}/roms/snes/Super Bomberman 2 (USA).sfc"
    head -c 1048576 /dev/zero > "${T}/roms/snes/Super Mario World (USA).sfc"
    # Mega Drive: o Genesis Plus GX precisa de uma ROM que rode de verdade; usa o homebrew
    # de distribuição liberada da prévia (Miniplanets) com os nomes oficiais
    HB="/mnt/d/Adube Sistemas/Console de Jogo/arcadia-preview/_jogos-teste/megadrive/Miniplanets.bin"
    for n in "NBA Jam (USA, Europe) (Rev 1).md" "NHL '94 (USA, Europe).md" "Gauntlet IV (USA, Europe) (August 1993).md" "Sonic The Hedgehog 2 (World) (Rev A).md"; do
      cp "${HB}" "${T}/roms/megadrive/${n}"
    done
    head -c 2352000 /dev/zero > "${T}/roms/psx/CTR - Crash Team Racing (USA).bin"
    printf 'FILE "CTR - Crash Team Racing (USA).bin" BINARY\n  TRACK 01 MODE2/2352\n    INDEX 01 00:00:00\n' > "${T}/roms/psx/CTR - Crash Team Racing (USA).cue"
    echo "preparado em ${T}"
    ;;
  abrir)
    PLAT="${2}"; NUC="${3}"; ROM="${T}/roms/${4}"
    # 5º argumento opcional: outro .so (ex.: o núcleo do próprio Ubuntu)
    SO="${5:-${NUCLEOS}/${NUC}_libretro.so}"
    bash "${T}/arcadia-multijogador.sh" "${PLAT}" "${ROM}" "${NUC}_libretro"
    cat "${T}/gerador.log"
    unset WAYLAND_DISPLAY
    setsid nohup retroarch --verbose --config "${T}/retroarch.cfg" -L "${SO}" "${ROM}" > "${T}/retroarch.log" 2>&1 < /dev/null &
    for _ in $(seq 1 20); do [ -n "$(janela)" ] && break; sleep 0.5; done
    sleep 2
    echo "janela: $(janela)"
    ;;
  tecla)
    shift; W="$(janela)"
    [ -n "${W}" ] || { echo "janela do RetroArch não encontrada"; exit 1; }
    xdotool windowactivate --sync "${W}" 2>/dev/null; xdotool windowfocus --sync "${W}" 2>/dev/null
    for k in "$@"; do xdotool key --window "${W}" "${k}"; sleep 0.4; done
    ;;
  cmd)
    # comandos de rede do RetroArch (MENU_TOGGLE, MENU_UP, MENU_DOWN, MENU_A, MENU_B ...)
    shift
    for c in "$@"; do
      python3 -c 'import socket,sys; socket.socket(socket.AF_INET,socket.SOCK_DGRAM).sendto(sys.argv[1].encode(),("127.0.0.1",55355))' "${c}"
      sleep 0.4
    done
    ;;
  foto)
    W="$(janela)"; sleep 0.5
    [ -n "${W}" ] || { echo "janela do RetroArch não encontrada"; exit 1; }
    import -window "${W}" "${2}" 2>/dev/null && echo "foto: ${2}"
    ;;
  fechar)
    pkill -x retroarch; sleep 1
    ;;
  log)
    grep -a -i "override\|core options\|options found\|libretro_device\|Content loading\|failed\|error" "${T}/retroarch.log" | head -30
    ;;
  provar)
    # roda todos os casos e grava o relatório em imagens-compiladas\logs
    SAIDA="/mnt/d/Adube Sistemas/Console de Jogo/imagens-compiladas/logs"
    REL="${SAIDA}/teste-retroarch-multijogador-$(TZ=America/Sao_Paulo date +%Y-%m-%d_%H%M).md"
    # o Genesis Plus GX da imagem compilado para o PC fecha sozinho no RetroArch 1.7.3 do
    # Ubuntu (até sem override); para ver a conexão do adaptador usa-se o núcleo do Ubuntu,
    # que tem os mesmos códigos de controle (1025 = 4-WayPlay, 1537 = Teamplayer)
    GPGX_UBUNTU=/usr/lib/x86_64-linux-gnu/libretro/genesis_plus_gx_libretro.so
    S="$0"; OK=0; FALHA=0; LINHAS=""
    L="${T}/retroarch.log"
    item() { if eval "${2}"; then OK=$((OK+1)); r="OK"; else FALHA=$((FALHA+1)); r="FALHOU"; fi
             LINHAS+="| ${1} | ${r} |"$'\n'; echo "${r}: ${1}"; }
    rodar() { pkill -x retroarch; sleep 1; bash "${S}" abrir "$@" > /dev/null; sleep 4; pkill -x retroarch; sleep 1; }
    bash "${S}" preparar > /dev/null
    rodar snes snes9x "snes/Super Bomberman 2 (USA).sfc"
    item "Super Nintendo (snes9x): Super Bomberman 2 carrega o override e conecta 'Multitap' na porta 2"       "grep -aq 'game-specific overrides found at .*Super Bomberman 2 (USA).cfg' '${L}' && grep -aq 'Connecting to port 257: Multitap (ID: 2)' '${L}'"
    rodar snes snes9x "snes/Super Mario World (USA).sfc"
    item "Super Nintendo (snes9x): Super Mario World fica sem override e sem multitap (o núcleo lista 'Multitap (ID: 257)' entre os tipos aceitos)"       "grep -aq 'no game-specific overrides found' '${L}' && ! grep -aq 'Connecting to port 257' '${L}' && grep -aq 'Multitap (ID: 257)' '${L}'"
    rodar megadrive genesis_plus_gx "megadrive/NBA Jam (USA, Europe) (Rev 1).md" "${GPGX_UBUNTU}"
    item "Mega Drive (Genesis Plus GX): NBA Jam conecta 'MD Joypad 3 Button + Teamplayer' na porta 1"       "grep -aq 'Connecting to port 1537: MD Joypad 3 Button + Teamplayer (ID: 1)' '${L}'"
    rodar genesis genesis_plus_gx "megadrive/NHL '94 (USA, Europe).md" "${GPGX_UBUNTU}"
    item "Mega Drive (Genesis Plus GX): NHL '94 conecta o 4-WayPlay nas portas 1 e 2"       "[ \"\$(grep -ac 'Connecting to port 1025: MD Joypad 3 Button + 4-WayPlay' '${L}')\" = 2 ]"
    rodar megadrive genesis_plus_gx "megadrive/Sonic The Hedgehog 2 (World) (Rev A).md" "${GPGX_UBUNTU}"
    item "Mega Drive (Genesis Plus GX): Sonic 2 fica sem override e sem adaptador" \
      "grep -aq 'no game-specific overrides found' '${L}' && ! grep -aq 'Connecting to port 1537' '${L}' && ! grep -aq 'Connecting to port 1025' '${L}'"
    rodar megadrive picodrive "megadrive/Gauntlet IV (USA, Europe) (August 1993).md"
    item "Mega Drive (PicoDrive): Gauntlet IV usa as opções do jogo, com 'team player' aceito"       "grep -aq 'game-specific core options found at .*Gauntlet IV' '${L}' && grep -q 'picodrive_input1 = \"team player\"' '${T}/config/PicoDrive/Gauntlet IV (USA, Europe) (August 1993).opt'"
    rodar psx pcsx_rearmed "psx/CTR - Crash Team Racing (USA).cue"
    item "PlayStation (PCSX ReARMed): CTR usa as opções do jogo; o RetroArch regrava o .opt mantendo 'port 1'"       "grep -aq 'game-specific core options found at .*CTR - Crash Team Racing' '${L}' && grep -aq 'Saved core options file to .*CTR - Crash Team Racing' '${L}' && grep -q 'pcsx_rearmed_multitap = \"port 1\"' '${T}/config/PCSX-ReARMed/CTR - Crash Team Racing (USA).opt'"
    {
      echo "# Teste do multitap no RetroArch (WSLg) — $(TZ=America/Sao_Paulo date '+%d/%m/%Y %H:%M') (horário de Brasília)"
      echo
      echo "Script: \`ferramentas/multijogador/testar-retroarch.sh provar\`. RetroArch $(retroarch --version 2>&1 | grep -o 'v[0-9.]*' | head -1) do Ubuntu; núcleos snes9x, PicoDrive e PCSX ReARMed dos mesmos commits da imagem, compilados para o PC."
      echo
      echo "**${OK} OK, ${FALHA} falha(s).**"
      echo
      echo "| Item | Resultado |"
      echo "|---|---|"
      printf '%s' "${LINHAS}"
    } > "${REL}"
    echo "RESULTADO: ${OK} OK, ${FALHA} falha(s) — ${REL}"
    [ "${FALHA}" = 0 ]
    ;;
  *) echo "uso: testar-retroarch.sh preparar|abrir|cmd|tecla|foto|fechar|log|provar"; exit 1 ;;
esac
