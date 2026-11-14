#!/bin/bash
# Compila a imagem do console-retro-os para o Super Console X2 Pro (S905X2 / Amlogic-ng)
# Roda dentro do Ubuntu 22.04 (WSL2) como usuário "console".
# Uso: bash compilar.sh
set -o pipefail

REPO="$HOME/console-retro-os"
LOGDIR="$HOME/build-logs"
SAIDA_WIN="/mnt/d/Adube Sistemas/Console de Jogo/builds"
DATA="$(TZ=America/Sao_Paulo date +%Y-%m-%d_%H%M)"
LOG="$LOGDIR/build-$DATA.log"
STATUS="$LOGDIR/status.txt"

mkdir -p "$LOGDIR"
echo "EM ANDAMENTO desde $(TZ=America/Sao_Paulo date '+%d/%m/%Y %H:%M') - log: $LOG" > "$STATUS"

if [ ! -d "$REPO/.git" ]; then
  git clone https://github.com/ricardofarney/console-retro-os.git "$REPO"
  git -C "$REPO" remote add upstream https://github.com/EmuELEC/EmuELEC.git
  git -C "$REPO" remote set-url --push upstream DISABLE
fi
cd "$REPO" || exit 1
git checkout dev && git pull --ff-only

export PROJECT=Amlogic-ce DEVICE=Amlogic-ng ARCH=aarch64 DISTRO=EmuELEC
INICIO=$(date +%s)
make image 2>&1 | tee "$LOG"
RC=$?
FIM=$(date +%s)
DUR=$(( (FIM - INICIO) / 60 ))

if [ $RC -eq 0 ]; then
  mkdir -p "$SAIDA_WIN"
  cp -v target/*.img.gz target/*.tar target/*.sha256 "$SAIDA_WIN"/ 2>/dev/null
  echo "OK em $(TZ=America/Sao_Paulo date '+%d/%m/%Y %H:%M') - duracao ${DUR} min - arquivos em $SAIDA_WIN" > "$STATUS"
else
  echo "FALHOU (codigo $RC) em $(TZ=America/Sao_Paulo date '+%d/%m/%Y %H:%M') - duracao ${DUR} min - ver $LOG" > "$STATUS"
fi
cp "$LOG" "$STATUS" "/mnt/d/Adube Sistemas/Console de Jogo/wsl/" 2>/dev/null
exit $RC
