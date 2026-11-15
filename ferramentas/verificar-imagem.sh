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
item "EmulationStation é o do fork arcadia (≥ 0c64beb)" "$([ -z "$faltam" ] && echo 0 || echo 1)" "$( [ -z "$faltam" ] && echo "binário $(file -b "$ES" | cut -d, -f2 | xargs) com as funções do fork; PKG_VERSION no repositório: $(grep -oP '^PKG_VERSION="\K[0-9a-f]{7}' "$REPO/packages/sx05re/emuelec-emulationstation/package.mk")" || echo "faltam:$faltam")"
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

# 6) coleções e ordem (DESIGN.md)
grep -q '<string name="CollectionSystemsAuto" value="recent,favorites,all" />' "$ESS" && grep -aq ArcadiaFavoriteSystems "$ES"
item "Coleções e ordem da tela inicial (DESIGN.md)" $? "recent,favorites,all; ordem consoles favoritos → Continuar jogando → Favoritos → demais (no binário)"
HIDE="$(grep -oP 'name="HideEmptySystems" value="\K[^"]+' "$ESS" 2>/dev/null)"
[ -n "$HIDE" ] || grep -aq ArcadiaHideEmpty "$ES"
item "Consoles e coleções sem jogos escondidos (exceto Continuar jogando/Favoritos)" $? "$( [ -n "$HIDE" ] && echo "HideEmptySystems=$HIDE" || (grep -aq ArcadiaHideEmpty "$ES" && echo "função no binário" || echo "não configurado"))"

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
