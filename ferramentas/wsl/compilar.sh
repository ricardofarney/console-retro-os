#!/bin/bash
# Arcádia — compila a imagem para o Super Console X2 Pro (S905X2 / Amlogic-ng).
# Roda dentro do Ubuntu 22.04 (WSL2) como usuário "console".
#
# Fluxo:
#   1. ~/arcadia-build é só a ÁREA DE COMPILAÇÃO (sistema de arquivos do Linux).
#   2. O código vem SEMPRE do repositório da pasta do projeto (somente commits):
#      D:\Adube Sistemas\Console de Jogo\console-retro-os  (branch dev)
#   3. As imagens geradas são copiadas para:
#      D:\Adube Sistemas\Console de Jogo\imagens-compiladas
#
# Uso: bash compilar.sh            (branch dev)
#      BRANCH=outra bash compilar.sh
set -o pipefail

PROJETO_WIN="/mnt/d/Adube Sistemas/Console de Jogo"
REPO_PROJETO="$PROJETO_WIN/console-retro-os"
SAIDA="$PROJETO_WIN/imagens-compiladas"
AREA="$HOME/arcadia-build"
LOGDIR="$HOME/arcadia-logs"
BRANCH="${BRANCH:-dev}"
DATA="$(TZ=America/Sao_Paulo date +%Y-%m-%d_%H%M)"
LOG="$LOGDIR/build-$DATA.log"
STATUS="$LOGDIR/status.txt"
agora() { TZ=America/Sao_Paulo date '+%d/%m/%Y %H:%M'; }

mkdir -p "$LOGDIR" "$SAIDA/logs"
echo "EM ANDAMENTO desde $(agora) - branch $BRANCH - log: $LOG" > "$STATUS"
cp "$STATUS" "$SAIDA/logs/status.txt" 2>/dev/null

git config --global --get-all safe.directory | grep -qxF "$REPO_PROJETO" \
  || git config --global --add safe.directory "$REPO_PROJETO"

# git nunca pede usuário/senha (um repositório removido travava o download por horas)
export GIT_TERMINAL_PROMPT=0
# submódulos do ECWolf migraram do Bitbucket (fora do ar) para o GitHub oficial
git config --global url."https://github.com/ECWolfEngine/".insteadOf "https://bitbucket.org/ecwolf/"

# 1) Área de compilação sincronizada a partir do repositório do projeto
if [ ! -d "$AREA/.git" ]; then
  git clone "$REPO_PROJETO" "$AREA" || exit 1
fi
cd "$AREA" || exit 1
git remote set-url origin "$REPO_PROJETO"
# A verificação de alterações não commitadas é feita no Windows pelo compilar.ps1
# (o git do Linux é lento em /mnt/d e veria os finais de linha CRLF como alteração)
if [ "${ARCADIA_NAO_COMMITADO:-0}" = "1" ]; then
  echo "AVISO: há alterações NÃO commitadas no repositório do projeto; elas NÃO entram neste build." | tee -a "$LOG"
fi
git fetch --prune origin || exit 1
git checkout -B "$BRANCH" "origin/$BRANCH" || exit 1
git reset --hard "origin/$BRANCH"
echo "Compilando commit $(git log -1 --format='%h %s')" | tee -a "$LOG"

export PROJECT=Amlogic-ce DEVICE=Amlogic-ng ARCH=aarch64 DISTRO=EmuELEC
# Arcadia: nome da imagem = Arcadia-<device>.<arch>-<versao> (versao em packages/sx05re/emuelec/config/EE_VERSION)
VERSAO_ARCADIA="$(tr -d '[:space:]' < packages/sx05re/emuelec/config/EE_VERSION)"
export CUSTOM_IMAGE_NAME="Arcadia-${DEVICE}.${ARCH}-${VERSAO_ARCADIA}"
echo "Imagem: ${CUSTOM_IMAGE_NAME}" | tee -a "$LOG"
export CCACHE_DIR="$HOME/.ccache-arcadia"
INICIO=$(date +%s)

# 2) Baixar TODAS as fontes antes de compilar (mostra de uma vez os links quebrados)
FALHAS="$LOGDIR/fontes-com-falha.txt"
echo "Baixando fontes de todos os pacotes..." | tee -a "$LOG"
JOBS=8 tools/download-tool --all 2>&1 | tee -a "$LOG" | grep -aE "Cannot get .* sources" | sort -u > "$FALHAS"
if [ -s "$FALHAS" ]; then
  echo "FALHOU no download de $(wc -l < "$FALHAS") pacote(s) em $(agora) - ver imagens-compiladas\\logs\\fontes-com-falha.txt" > "$STATUS"
  cat "$FALHAS" | tee -a "$LOG"
  cp "$LOG" "$STATUS" "$FALHAS" "$SAIDA/logs/" 2>/dev/null
  exit 3
fi

# Senhas (vêm do compilar.ps1, lidas de docs/SENHAS-LOCAIS.md, que fica fora do Git)
if [ -z "${ARCADIA_ROOT_PASSWORD}" ] || [ -z "${ARCADIA_SAMBA_PASSWORD}" ]; then
  echo "AVISO: senhas locais não encontradas; a imagem sairá com as senhas padrão (root emuelec / samba arcadia)." | tee -a "$LOG"
fi
export ARCADIA_ROOT_PASSWORD ARCADIA_SAMBA_PASSWORD
# os pacotes que gravam as senhas não percebem a troca sozinhos: recompila-os quando mudarem
HASH_SENHAS="$(printf '%s|%s' "${ARCADIA_ROOT_PASSWORD}" "${ARCADIA_SAMBA_PASSWORD}" | sha256sum | cut -c1-16)"
if [ "$(cat "$LOGDIR/.senhas.hash" 2>/dev/null)" != "$HASH_SENHAS" ]; then
  echo "Senhas mudaram: recompilando busybox e samba." | tee -a "$LOG"
  ./scripts/clean busybox >/dev/null 2>&1; ./scripts/clean samba >/dev/null 2>&1
  echo "$HASH_SENHAS" > "$LOGDIR/.senhas.hash"
fi

# 3) Build (ccache fora da pasta de build, para sobreviver a limpezas)
make image 2>&1 | tee -a "$LOG"
RC=$?
DUR=$(( ($(date +%s) - INICIO) / 60 ))

# 4) Copiar resultado para a pasta do projeto
if [ $RC -eq 0 ]; then
  cp -v target/*.img.gz target/*.tar target/*.sha256 "$SAIDA"/ 2>&1 | tee -a "$LOG"
  echo "OK em $(agora) - duracao ${DUR} min - commit $(git log -1 --format=%h) - imagens em D:\\Adube Sistemas\\Console de Jogo\\imagens-compiladas" > "$STATUS"
else
  echo "FALHOU (codigo $RC) em $(agora) - duracao ${DUR} min - ver imagens-compiladas\\logs\\build-$DATA.log" > "$STATUS"
fi
cp "$LOG" "$STATUS" "$SAIDA/logs/" 2>/dev/null
exit $RC
