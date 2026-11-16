#!/bin/bash
# Arcádia — conferência automática de uma imagem compilada (sem gravar cartão).
# Abre o .img.gz, monta as partições (somente leitura) e o SYSTEM (squashfs) e confere
# os itens da configuração de fábrica. Gera relatório em português (OK/FALHOU).
#
# Uso (no Ubuntu do WSL):
#   bash verificar-imagem.sh [imagem.img.gz]
# Padrão: /mnt/d/Adube Sistemas/Console de Jogo/imagens-compiladas/Arcadia-Amlogic-ng.aarch64-<EE_VERSION>-Generic.img.gz
# Relatório: imagens-compiladas/logs/verificacao-<imagem>-<data>.md
# Precisa de: sudo (losetup/mount dentro do WSL), squashfs-tools, python3.

set -u
PROJETO="/mnt/d/Adube Sistemas/Console de Jogo"
REPO="$PROJETO/console-retro-os"
VERSAO="$(tr -d '[:space:]' < "$REPO/packages/sx05re/emuelec/config/EE_VERSION" 2>/dev/null)"
IMG="${1:-$PROJETO/imagens-compiladas/Arcadia-Amlogic-ng.aarch64-${VERSAO}-Generic.img.gz}"
NOME="$(basename "$IMG" .img.gz)"
RELATORIO="$PROJETO/imagens-compiladas/logs/verificacao-${NOME}-$(TZ=America/Sao_Paulo date +%Y-%m-%d_%H%M).md"
TRAB="$(mktemp -d /tmp/verificar-arcadia.XXXX)"
OK=0; FALHA=0; LINHAS=()

item() {   # item "<descrição>" <0=ok|1=falha> "<detalhe>"
  if [ "$2" -eq 0 ]; then OK=$((OK+1)); LINHAS+=("| ✅ OK | $1 | $3 |"); echo "OK      - $1 ($3)"
  else FALHA=$((FALHA+1)); LINHAS+=("| ❌ FALHOU | $1 | $3 |"); echo "FALHOU  - $1 ($3)"; fi
}
limpar() {
  sudo umount "$TRAB/sys" "$TRAB/boot" 2>/dev/null
  [ -n "${LOOP:-}" ] && sudo losetup -d "$LOOP" 2>/dev/null
  rm -rf "$TRAB"
}
trap limpar EXIT

command -v unsquashfs >/dev/null || sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q squashfs-tools >/dev/null
[ -f "$IMG" ] || { echo "Imagem não encontrada: $IMG"; exit 2; }
echo "== Conferindo $NOME"

# 1) imagem e partições
gunzip -c "$IMG" > "$TRAB/imagem.img" || { echo "falha ao descompactar"; exit 2; }
LOOP="$(sudo losetup -fP --show "$TRAB/imagem.img")"
mkdir -p "$TRAB/boot" "$TRAB/sys"
sudo mount -o ro "${LOOP}p1" "$TRAB/boot"
B="$TRAB/boot"
sudo mount -o ro,loop "$B/SYSTEM" "$TRAB/sys" 2>/dev/null || { mkdir -p "$TRAB/sysx"; unsquashfs -q -d "$TRAB/sysx" "$B/SYSTEM" >/dev/null 2>&1; }
S="$TRAB/sys"; [ -d "$TRAB/sysx" ] && S="$TRAB/sysx"

# 2) EmulationStation do fork + textos pt-BR
ES="$S/usr/bin/emulationstation"; MO="$(find "$S/usr/config/emuelec/configs/locale/pt_BR" -name emulationstation2.mo 2>/dev/null | head -1)"
faltam=""; for k in ArcadiaMenuSimples ArcadiaFavoriteSystems FavoriteSystems "CONTINUE WHERE I LEFT OFF" "START FROM THE BEGINNING"; do grep -aq "$k" "$ES" || faltam="$faltam [$k]"; done
item "EmulationStation é o do fork arcadia (≥ 6ad7cae)" "$([ -z "$faltam" ] && echo 0 || echo 1)" "$( [ -z "$faltam" ] && echo "binário $(file -b "$ES" | cut -d, -f2 | xargs) com as funções do fork; PKG_VERSION no repositório: $(grep -oP '^PKG_VERSION="\K[0-9a-f]{7}' "$REPO/packages/sx05re/emuelec-emulationstation/package.mk")" || echo "faltam:$faltam")"
faltam=""; for k in "CONTINUAR DE ONDE PAREI" "COMEÇAR DO INÍCIO" "FAVORITAR CONSOLE" "MODO AVANÇADO" "DESLIGAR COM SEGURANÇA" "ONDE VOCÊ QUER COMEÇAR?"; do grep -aq "$k" "$MO" 2>/dev/null || faltam="$faltam [$k]"; done
item "Textos novos em pt-BR no EmulationStation" "$([ -z "$faltam" ] && echo 0 || echo 1)" "$( [ -z "$faltam" ] && echo "6 textos conferidos no emulationstation2.mo" || echo "faltam:$faltam")"

# 3) tema
ESS="$S/usr/config/emulationstation/es_settings.cfg"; T="$S/usr/config/emulationstation/themes/arcadia"
grep -q '<string name="ThemeSet" value="arcadia" />' "$ESS" && [ -f "$T/theme.xml" ] && [ -f "$T/splash.xml" ]
item "Tema arcadia presente e padrão" $? "ThemeSet=$(grep -oP 'name="ThemeSet" value="\K[^"]+' "$ESS"); $(ls "$T/logos" 2>/dev/null | grep -c png) cards"

# 4) idioma e fuso
EC="$S/usr/config/emuelec/configs/emuelec.conf"
grep -qx 'system.language=pt_BR' "$EC" && grep -qx 'system.timezone=America/Sao_Paulo' "$EC"
item "Idioma pt_BR e fuso America/Sao_Paulo" $? "$(grep -E '^system.(language|timezone)=' "$EC" | tr '\n' ' ')"

# 5) salvamento automático + escolha de save
grep -qx 'global.autosave=1' "$EC" && grep -q 'savestate_auto_save = "true"' "$S/usr/bin/setsettings.sh" && grep -q '<bool name="ShowSaveStates" value="true" />' "$ESS" && grep -q 'autosave_interval = "10"' "$S/usr/config/retroarch/retroarch.cfg" 2>/dev/null
item "Salvamento automático e ShowSaveStates de fábrica" $? "global.autosave=1, setsettings padrão true, ShowSaveStates=true, autosave_interval=10"
# janela "ONDE VOCÊ QUER COMEÇAR?" ao abrir jogo com save; "COMEÇAR DO INÍCIO" continua salvando ao sair
grep -qx 'global.savestates=2' "$EC" && grep -q 'write_bool "savestate_auto_save" "${2}"' "$S/usr/bin/setsettings.sh"
item "Escolha \"ONDE VOCÊ QUER COMEÇAR?\" ao abrir jogo com save" $? "global.savestates=$(grep -oP '^global.savestates=\K\S+' "$EC"); COMEÇAR DO INÍCIO salva ao sair: $(grep -q 'write_bool "savestate_auto_save" "${2}"' "$S/usr/bin/setsettings.sh" && echo sim || echo não)"

# 6) coleções e ordem (DESIGN.md)
grep -q '<string name="CollectionSystemsAuto" value="recent,favorites,all" />' "$ESS" && grep -aq ArcadiaFavoriteSystems "$ES"
item "Coleções e ordem da tela inicial (DESIGN.md)" $? "recent,favorites,all; ordem consoles favoritos → Continuar jogando → Favoritos → demais (no binário)"
# o ES já esconde consoles sem jogos quando LoadEmptySystems não está ligado (padrão false);
# Continuar jogando e Favoritos aparecem mesmo vazios (comprovado no teste do WSLg, docs/TESTE-WSLG.md)
VAZIOS="$(grep -oP 'name="LoadEmptySystems" value="\K[^"]+' "$ESS" 2>/dev/null)"
[ "$VAZIOS" != "true" ] && grep -aq LoadEmptySystems "$ES"
item "Consoles sem jogos escondidos (exceto Continuar jogando/Favoritos)" $? "LoadEmptySystems=${VAZIOS:-padrão (false)}"
# ficha do jogo: "Lançamento" só aparece com data (sem "Desconhecido")
grep -q '{game:releaseyear}' "$T/theme.xml" && grep -q '<datetime name="md_releasedate"><visible>false</visible>' "$T/theme.xml"
item "Ficha do jogo sem \"Lançamento: Desconhecido\"" $? "ano por {game:releaseyear}, linha some sem data"

# 6b) desempenho no S905X2 (docs/DESEMPENHO-S905X2.md)
RCO="$S/usr/config/retroarch/retroarch-core-options.cfg"
grep -qx 'global.shaderset=none' "$EC" && grep -q '^mupen64plus-43screensize = "320x240"' "$RCO" && grep -q '^pcsx_rearmed_neon_enhancement_enable = "disabled"' "$RCO"
item "Padrões de desempenho do S905X2" $? "shaders desligados; N64 320x240 + repetição de quadro; PS1 resolução nativa; vídeo $(grep -oP '^ee_videomode=\K\S+' "$EC")"

# 7) senha do root
SH="$S/usr/cache/shadow"; HASH="$(sudo grep '^root:' "$SH" 2>/dev/null | cut -d: -f2)"   # arquivo com permissão 000
python3 -W ignore -c "import crypt,sys; h=sys.argv[1]; sys.exit(0 if h and h not in ('*','!') and crypt.crypt('emuelec',h)!=h else 1)" "$HASH"
item "Senha do root diferente da padrão \"emuelec\"" $? "$( [ -n "$HASH" ] && echo "hash ${HASH:0:3}… presente; 'emuelec' não confere" || echo "sem hash")"

# 8) atualização
UC="$S/usr/bin/updatecheck.sh"
grep -q 'raw.githubusercontent.com/ricardofarney/console-retro-os/dev/atualizacao/versoes.txt' "$UC" && grep -q 'github.com/ricardofarney/console-retro-os/releases/download/v' "$UC" && grep -q 'UFILE="Arcadia-' "$UC" && grep -q 'versao_mais_nova' "$UC"
item "Atualização pelas Releases de ricardofarney/console-retro-os" $? "versoes.txt + releases do fork, arquivo Arcadia-*, comparação X.Y.Z; versão da imagem $(cat "$S/usr/config/EE_VERSION")"

# 9) proteção de saves e favoritos
! grep -q '^[^#]*clearconfig EMUS' "$UC" && [ -x "$S/usr/bin/arcadia-dados.sh" ] && grep -q 'arcadia-dados.sh backup' "$S/usr/bin/batocera/emuelec-upgrade" && grep -q 'arcadia-dados.sh migrar-gamelists' "$S/usr/bin/emuelec_autostart.sh"
item "Proteção de saves e favoritos nas atualizações" $? "sem clearconfig EMUS; backup antes de atualizar; gamelists migrados no boot"

# 10) device trees do S905X2
D2="$B/device_trees/g12a_s905x2_2g.dtb"; D1="$B/device_trees/g12a_s905x2_2g_1gbit.dtb"
[ -f "$D2" ] && [ -f "$D1" ]
item "device_trees com g12a_s905x2_2g.dtb e g12a_s905x2_2g_1gbit.dtb" $? "$(ls "$B/device_trees" 2>/dev/null | grep -c dtb) DTBs na imagem; s905x2: $(ls "$B/device_trees" 2>/dev/null | grep -i s905x2 | tr '\n' ' ')"

# 11) multijogador: até 4 jogadores, multitap só nos jogos de 3+ (docs/MULTIJOGADOR.md)
MJ="$S/usr/bin/arcadia-multijogador.sh"; ML="$S/usr/share/arcadia/multijogador"
QTD=""; for c in snes megadrive psx; do QTD="$QTD $c=$(grep -vc '^#' "$ML/$c.txt" 2>/dev/null)"; done
MODS=""; for m in joydev xpad hidp hid-sony; do find "$S/usr/lib" -name "$m.ko*" 2>/dev/null | grep -q . && MODS="$MODS $m"; done
MAXU="$(grep -oP '^input_max_users = "?\K[0-9]+' "$S/usr/config/retroarch/retroarch.cfg" | tail -1)"
# teste a seco com o gerador e as listas da própria imagem
TMJ="$(mktemp -d)"
ARCADIA_MJ_LISTAS="$ML" ARCADIA_MJ_CONFIG="$TMJ" ARCADIA_MJ_COREOPTS="$S/usr/config/retroarch/retroarch-core-options.cfg" ARCADIA_MJ_LOG="$TMJ/log" \
  bash "$MJ" snes "/storage/roms/snes/Super Bomberman 2 (USA).sfc" snes9x_libretro
ARCADIA_MJ_LISTAS="$ML" ARCADIA_MJ_CONFIG="$TMJ" ARCADIA_MJ_COREOPTS="$S/usr/config/retroarch/retroarch-core-options.cfg" ARCADIA_MJ_LOG="$TMJ/log" \
  bash "$MJ" snes "/storage/roms/snes/Super Mario World (USA).sfc" snes9x_libretro
GERA="$(grep -c 'input_libretro_device_p2 = "257"' "$TMJ/Snes9x/Super Bomberman 2 (USA).cfg" 2>/dev/null)"; [ -e "$TMJ/Snes9x/Super Mario World (USA).cfg" ] && GERA="smw"
rm -rf "$TMJ"
[ -x "$MJ" ] && [ "$(grep -vc '^#' "$ML/snes.txt")" -ge 50 ] && [ "$(grep -vc '^#' "$ML/megadrive.txt")" -ge 50 ] && [ "$(grep -vc '^#' "$ML/psx.txt")" -ge 50 ] \
  && grep -q 'arcadia-multijogador.sh "${PLATFORM}" "${ROMNAME}" "${EMU}"' "$S/usr/bin/emuelecRunEmu.sh" \
  && [ "${MAXU:-0}" -ge 4 ] && [ "$MODS" = " joydev xpad hidp hid-sony" ] && [ "$GERA" = "1" ] \
  && grep -aq ArcadiaOrdemConexao "$ES" && grep -aq "PLAYER ORDER" "$ES" && grep -aq "ORDEM DOS JOGADORES" "$MO"
item "Multijogador: até 4 controles e multitap automático nos jogos de 3+" $? "listas:$QTD; input_max_users=$MAXU; módulos:$MODS; teste a seco: Super Bomberman 2 → porta 2 = 257, Super Mario World sem arquivo ($GERA); ES com \"Ordem dos jogadores\" e ordem de conexão"

# relatório
{
  echo "# Verificação da imagem $NOME"
  echo
  echo "Gerado em $(TZ=America/Sao_Paulo date '+%d/%m/%Y %H:%M') (horário de Brasília) por \`ferramentas/verificar-imagem.sh\`."
  echo "Imagem: \`$(basename "$IMG")\` — SHA-256 \`$(sha256sum "$IMG" | cut -c1-64)\`"
  echo
  echo "**Resultado: $OK OK, $FALHA FALHOU**"
  echo
  echo "| Situação | Item | Detalhe |"
  echo "|---|---|---|"
  printf '%s\n' "${LINHAS[@]}"
} > "$RELATORIO"
echo "== $OK OK, $FALHA FALHOU — relatório: $RELATORIO"
[ "$FALHA" -eq 0 ]
