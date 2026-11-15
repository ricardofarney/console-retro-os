#!/bin/bash
# Arcádia — simula no Ubuntu (WSL) a atualização feita pelo aparelho, com os scripts REAIS da imagem
# (emuelec-upgrade, updatecheck.sh e arcadia-dados.sh), sem aparelho e sem tocar no GitHub público.
#
# Uso: bash simular-atualizacao.sh <versão-instalada> <versão-nova> [pasta-com-os-arquivos-publicados]
#   ex.: bash simular-atualizacao.sh 1.0.0 1.0.1-teste
#   pasta padrão: imagens-compiladas/publicar/v<versão-nova> (a mesma que o publicar-versao.ps1 envia)
#
# Como funciona:
#   - monta um "aparelho de mentira" em ~/arcadia-sim-atualizacao (EE_VERSION, /storage com saves,
#     favoritos, consoles favoritos e configurações);
#   - copia os scripts da imagem trocando só os caminhos absolutos (/storage, /usr/config...) e os
#     endereços do GitHub por um servidor local (127.0.0.1), que serve o versoes.txt e os arquivos
#     da versão nova exatamente como a página de Releases serviria;
#   - roda o que o menu ATUALIZAÇÕES roda: "emuelec-upgrade canupdate" e depois "emuelec-upgrade";
#   - confere: detectou a versão, baixou, conferiu o SHA-256, recusou um arquivo corrompido, fez a
#     cópia de segurança e NÃO apagou nem alterou nenhum arquivo do usuário.
# Sai com 0 só se tudo passar. Relatório: imagens-compiladas/logs/simulacao-atualizacao-<data>.md
set -u
ATUAL="${1:?versão instalada}"; NOVA="${2:?versão nova}"
PROJETO="/mnt/d/Adube Sistemas/Console de Jogo"
REPO="$PROJETO/console-retro-os"; BIN="$REPO/packages/sx05re/emuelec/bin"
PUB="${3:-$PROJETO/imagens-compiladas/publicar/v$NOVA}"
R="$HOME/arcadia-sim-atualizacao"; PORTA=8765; URL="http://127.0.0.1:$PORTA"
ARQ="Arcadia-Amlogic-ng.aarch64-$NOVA.tar"
DATA="$(TZ=America/Sao_Paulo date '+%Y-%m-%d_%H%M')"
REL="$PROJETO/imagens-compiladas/logs/simulacao-atualizacao-$DATA.md"
OK=0; FALHA=0; LINHAS=""
item() { if [ "$2" = 0 ]; then OK=$((OK+1)); s="✅"; else FALHA=$((FALHA+1)); s="❌"; fi
         LINHAS="$LINHAS| $s | $1 | $3 |"$'\n'; echo "$s $1 — $3"; }

[ -f "$PUB/$ARQ" ] && [ -f "$PUB/$ARQ.sha256" ] || { echo "Arquivos da versão $NOVA não encontrados em $PUB"; exit 2; }

# ---------- 1. aparelho de mentira ----------
rm -rf "$R"; mkdir -p "$R"/{bin,usr/config,logs,servidor/download/v"$NOVA"}
S="$R/storage"
mkdir -p "$S"/.config/emulationstation/collections "$S"/.config/emuelec/configs "$S"/.config/retroarch \
         "$S"/roms/nes "$S"/roms/savestates/nes "$S"/.update
echo "$ATUAL" > "$R/usr/config/EE_VERSION"; date +%Y%m%d > "$R/usr/buildate"
tr -d '\r' < "$REPO/packages/sx05re/emuelec/config/emuelec/configs/emuelec.conf" > "$S/.config/emuelec/configs/emuelec.conf"
cat > "$S/.config/emulationstation/es_settings.cfg" <<'EOF'
<?xml version="1.0"?>
<config>
	<string name="FavoriteSystems" value="nes,megadrive" />
	<string name="ThemeSet" value="arcadia" />
</config>
EOF
cat > "$S/roms/nes/gamelist.xml" <<'EOF'
<?xml version="1.0"?>
<gameList>
	<game><path>./Nova the Squirrel.nes</path><name>Nova the Squirrel</name><favorite>true</favorite><playcount>3</playcount></game>
</gameList>
EOF
head -c 40960 /dev/urandom > "$S/roms/nes/Nova the Squirrel.nes"
head -c 8192  /dev/urandom > "$S/roms/nes/Nova the Squirrel.srm"
head -c 46548 /dev/urandom > "$S/roms/savestates/nes/Nova the Squirrel.state.auto"
head -c 58010 /dev/urandom > "$S/roms/savestates/nes/Nova the Squirrel.state.auto.png"
echo "retroarch.cfg do usuário" > "$S/.config/retroarch/retroarch.cfg"
echo "<collection/>" > "$S/.config/emulationstation/collections/custom-minha.cfg"
manifesto() { (cd "$S" && find . -type f ! -path './.update/*' ! -path './roms/backup/*' -print0 | sort -z | xargs -0 sha256sum); }
manifesto > "$R/antes.txt"

# ---------- 2. "GitHub" local ----------
printf '%s;stable\n' "$NOVA" > "$R/servidor/versoes.txt"
ln -s "$PUB/$ARQ" "$R/servidor/download/v$NOVA/$ARQ"
cp "$PUB/$ARQ.sha256" "$R/servidor/download/v$NOVA/$ARQ.sha256"
python3 -m http.server "$PORTA" --bind 127.0.0.1 --directory "$R/servidor" > "$R/logs/servidor.log" 2>&1 &
SRV=$!; trap 'kill $SRV 2>/dev/null' EXIT
for i in $(seq 1 40); do curl -sf "$URL/versoes.txt" >/dev/null && break; sleep 0.25; done

# ---------- 3. scripts reais da imagem, só com caminhos trocados ----------
cat > "$R/bin/profile" <<EOF
export EE_DEVICE=Amlogic-ng
get_ee_setting() { grep -oP "^\$1=\\K.*" "$S/.config/emuelec/configs/emuelec.conf" 2>/dev/null; }
text_viewer() { echo "[text_viewer] \$*"; return 0; }
ee_console() { :; }
systemctl() { echo "[systemctl \$*] (simulado)"; }
export -f get_ee_setting text_viewer ee_console systemctl
EOF
adaptar() {  # $1 = script de origem, $2 = destino
  tr -d '\r' < "$1" | sed \
    -e "s#^\. /etc/profile#. $R/bin/profile#" \
    -e "s#https://raw.githubusercontent.com/ricardofarney/console-retro-os/dev/atualizacao/versoes.txt#$URL/versoes.txt#" \
    -e "s#https://github.com/ricardofarney/console-retro-os/releases/download/v#$URL/download/v#" \
    -e "s#/usr/config/EE_VERSION#$R/usr/config/EE_VERSION#g" -e "s#/usr/buildate#$R/usr/buildate#g" \
    -e "s#/emuelec/logs#$R/logs#g" -e "s#/storage/#$S/#g" > "$2"
  chmod +x "$2"
}
adaptar "$BIN/updatecheck.sh" "$R/bin/updatecheck.sh"
adaptar "$BIN/batocera/emuelec-upgrade" "$R/bin/emuelec-upgrade"
adaptar "$BIN/arcadia-dados.sh" "$R/bin/arcadia-dados.sh"
export PATH="$R/bin:$PATH"
grep -q "$URL/versoes.txt" "$R/bin/updatecheck.sh" && ! grep -qE 'raw.githubusercontent.com|releases/download' "$R/bin/updatecheck.sh" "$R/bin/emuelec-upgrade"
item "Scripts da imagem adaptados só nos caminhos" $? "updatecheck.sh, emuelec-upgrade, arcadia-dados.sh (de packages/sx05re/emuelec/bin)"

# ---------- 4. o que o menu ATUALIZAÇÕES faz ----------
DET="$(emuelec-upgrade canupdate 2>&1 | tail -1)"; RC=$?
[ "$DET" = "$NOVA" ]
item "Detecta a versão nova ($ATUAL → $NOVA)" $? "emuelec-upgrade canupdate respondeu \"$DET\""
TAM="$(updatecheck.sh getsize 2>/dev/null | tail -1)"; [[ "$TAM" =~ ^[0-9]+$ ]] || TAM=0
[ "$TAM" = "$(stat -Lc %s "$PUB/$ARQ")" ]
item "Informa o tamanho do download" $? "$TAM bytes ($(( TAM / 1024 / 1024 )) MB)"

emuelec-upgrade > "$R/logs/upgrade.log" 2>&1 < /dev/null; RC=$?
grep -q "valid checksum." "$R/logs/upgrade.log" && ! grep -q "invalid checksum" "$R/logs/upgrade.log" && [ $RC -eq 0 ]
item "Baixa e confere o SHA-256" $? "$(grep -E 'url:|checksum' "$R/logs/upgrade.log" | sed "s#$URL#(servidor local)#" | tr '\n' ' ')"
! grep -q "syntax error" "$R/logs/upgrade.log" && grep -q "downloading >>>" "$R/logs/upgrade.log"
item "Percentual do download na tela" $? "$(grep -o 'downloading >>> [0-9]*%' "$R/logs/upgrade.log" | tr '\n' ' ')"
cmp -s "$S/.update/$ARQ" "$PUB/$ARQ"
item "Arquivo baixado idêntico ao publicado" $? "$S/.update/$ARQ ($(sha256sum "$S/.update/$ARQ" | cut -c1-16)…)"
ls "$S"/roms/backup/arcadia/antes-da-atualizacao-*.tar.gz >/dev/null 2>&1
BK="$(ls -1t "$S"/roms/backup/arcadia/antes-da-atualizacao-*.tar.gz 2>/dev/null | head -1)"
item "Cópia de segurança antes de atualizar" $? "$(basename "${BK:-nenhuma}"): $(tar -tzf "${BK:-/dev/null}" 2>/dev/null | grep -cv '/$') arquivos (es_settings, emuelec.conf, coleções, retroarch.cfg…)"

# ---------- 5. arquivo corrompido tem de ser recusado ----------
rm -f "$S/.update/"*
echo "0000000000000000000000000000000000000000000000000000000000000000  $ARQ" > "$R/servidor/download/v$NOVA/$ARQ.sha256"
emuelec-upgrade > "$R/logs/upgrade-corrompido.log" 2>&1 < /dev/null; RC=$?
grep -q "invalid checksum" "$R/logs/upgrade-corrompido.log" && [ $RC -ne 0 ]
item "Recusa arquivo que não confere" $? "código de saída $RC; $(grep -o 'invalid checksum' "$R/logs/upgrade-corrompido.log" | head -1)"
cp "$PUB/$ARQ.sha256" "$R/servidor/download/v$NOVA/$ARQ.sha256"

# ---------- 6. não oferece atualização quando não há versão nova ----------
echo "$NOVA" > "$R/usr/config/EE_VERSION"
DET2="$(emuelec-upgrade canupdate 2>&1 | tail -1)"
[ "$DET2" = "no" ]; item "Já atualizado: não oferece de novo" $? "instalada $NOVA → \"$DET2\""
echo "9.9.9" > "$R/usr/config/EE_VERSION"
DET3="$(emuelec-upgrade canupdate 2>&1 | tail -1)"
[ "$DET3" = "no" ]; item "Não oferece versão mais velha" $? "instalada 9.9.9 → \"$DET3\""
echo "$ATUAL" > "$R/usr/config/EE_VERSION"

# ---------- 7. nada do usuário apagado ou alterado ----------
manifesto > "$R/depois.txt"
diff -q "$R/antes.txt" "$R/depois.txt" >/dev/null
item "Saves, favoritos, consoles favoritos e configurações intactos" $? "$(wc -l < "$R/antes.txt") arquivos com o mesmo SHA-256 antes e depois (gamelist com favorito, FavoriteSystems=nes,megadrive, .srm, .state.auto, emuelec.conf, coleções, retroarch.cfg)"

# ---------- relatório ----------
{
  echo "# Simulação de atualização $ATUAL → $NOVA — $(TZ=America/Sao_Paulo date '+%d/%m/%Y %H:%M')"
  echo; echo "**$OK OK, $FALHA FALHOU** — arquivos de \`$PUB\`"; echo
  echo "| | Item | Detalhe |"; echo "|---|---|---|"; printf '%s' "$LINHAS"
  echo; echo '```'; cat "$R/logs/upgrade.log"; echo '```'
} > "$REL"
echo; echo "$OK OK, $FALHA FALHOU — relatório: $REL"
[ "$FALHA" -eq 0 ]
