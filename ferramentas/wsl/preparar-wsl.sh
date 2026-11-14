#!/bin/bash
# Prepara o Ubuntu 22.04 (WSL2) para compilar o console-retro-os (EmuELEC)
set -e
export DEBIAN_FRONTEND=noninteractive

# Usuário de build sem senha (sudo liberado); senha pode ser definida depois com: sudo passwd console
if ! id console >/dev/null 2>&1; then
  useradd -m -s /bin/bash -G sudo console
  passwd -l console >/dev/null
fi
echo 'console ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/console
chmod 440 /etc/sudoers.d/console

# Usuário padrão do WSL e fuso de Brasília
cat > /etc/wsl.conf <<'EOF'
[user]
default=console

[boot]
systemd=true

[interop]
appendWindowsPath=false
EOF
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
echo America/Sao_Paulo > /etc/timezone

apt-get update
apt-get -y dist-upgrade
apt-get install -y gcc make git unzip wget xz-utils libsdl2-dev libsdl2-mixer-dev libfreeimage-dev \
  libfreetype6-dev libcurl4-openssl-dev rapidjson-dev libasound2-dev libgl1-mesa-dev build-essential \
  libboost-all-dev cmake fonts-droid-fallback libvlc-dev libvlccore-dev vlc-bin texinfo premake4 golang \
  libssl-dev curl patchelf xmlstarlet default-jre xsltproc libvpx-dev rdfind tzdata xfonts-utils lzop \
  bc patchutils bzip2 gzip zstd perl gawk gperf zip diffutils file g++ python3 libc6-dev libncurses5-dev \
  libjson-perl libxml-parser-perl libparse-yapp-perl locales sudo ccache
locale-gen en_US.UTF-8 pt_BR.UTF-8
update-locale LANG=en_US.UTF-8
echo "PREPARACAO-OK"
