#!/bin/bash

# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2020-present Shanti Gilbert (https://github.com/shantigilbert)

. /etc/profile

# Arcádia: atualizações pelas Releases do fork (docs/ATUALIZACOES.md)
# versoes.txt: uma linha por canal, "<versão>;stable" e "<versão>;beta"
UPDINFO="https://raw.githubusercontent.com/ricardofarney/console-retro-os/dev/atualizacao/versoes.txt"
UPDURL="https://github.com/ricardofarney/console-retro-os/releases/download/v"
TEST_UPDURL="${UPDURL}"
BUILDATE=$(cat /usr/buildate)
arguments="$@"

if [[ "${arguments}" == *"forceupdate"* ]]; then
systemctl stop emustation
ee_console enable
clear /dev/tty0
    
while pgrep -f emulationstation; do
    clear /dev/tty0
    echo "Aguardando o EmulationStation fechar..." > /dev/tty0
    sleep 1
done

fi

UPDTYPE=$(get_ee_setting updates.type)
[[ -z "${UPDTYPE}" ]] && UPDTYPE="stable"
[[ "${UPDTYPE}" != "stable" ]] && UPDURL="${TEST_UPDURL}"

function do_cleanup() {
	rm -rf /storage/.update/* > /dev/null 2>&1
}

function no_update() {
	echo "no"
	do_cleanup
if [[ "${arguments}" == *"forceupdate"* ]]; then
    ee_console disable
    systemctl start emustation
fi
	exit 1
}

function forced_update() {
ee_console enable
	echo "Baixando ${UPDURL} para /storage/.update/${UFILE}" > /dev/tty0
	touch "/storage/.update/${UFILE}"
	wget "${UPDURL}" -O "/storage/.update/${UFILE}" || echo "Exit code: $?" > /dev/tty0

# Try to download an sha256 checksum
	echo "Baixando o arquivo de verificação (sha256)" > /dev/tty0
    wget -q "${UPDURL}.sha256" -O "/storage/.update/${UFILE}.sha256"

if test -e "/storage/.update/${UFILE}.sha256"; then
	echo "Conferindo o arquivo..." > /dev/tty0
    DISTMD5=$(cat "/storage/.update/${UFILE}.sha256" | cut -d ' ' -f 1)
    CURRMD5=$(sha256sum "/storage/.update/${UFILE}" | cut -d ' ' -f 1)

    if test "${DISTMD5}" = "${CURRMD5}"; then
        echo "Arquivo conferido, continuando" > /dev/tty0
    else
        text_viewer -e -w -t "Arquivo corrompido!" -f 24 -m "O arquivo baixado não confere (esperado +${DISTMD5}+, obtido +${CURRMD5}+).\n\nATUALIZAÇÃO CANCELADA."
        no_update
	exit 1
    fi

else
    echo "Sem arquivo de verificação; o download não será conferido." > /dev/tty0
fi
    echo "Aplicando a atualização" > /dev/tty0
	sync
	systemctl stop emustation

while pgrep -f emulationstation; do
    clear /dev/tty0
    echo "Aguardando o EmulationStation fechar..." > /dev/tty0
    sleep 1
done

	# Arcádia: a atualização forçada não apaga mais as configurações (antes: emuelec-utils clearconfig EMUS);
	# faz uma cópia de segurança datada em /storage/roms/backup/arcadia/
	arcadia-dados.sh backup
	systemctl reboot
	exit 0
}

function check_update() { 
if [[ "${arguments}" == *"canupdate"* ]]; then
	echo "${UPDATEVERP}"
elif [[ "${arguments}" == *"geturl"* ]]; then	
	echo "${UPDURL}"
elif [[ "${arguments}" == *"getsize"* ]]; then
    USIZE=$(wget "${UPDURL}" --spider --server-response -O - 2>&1 | sed -ne '/Content-Length:/{s/.*: //;p}' | tail -1)	
	echo "${USIZE}"
fi
}

#make sure there is no old update
do_cleanup

# To avoid curl error "(23) Failed writing body", we download the full page to /tmp/eeupd and use cat to read it then delete it
curl -s ${UPDINFO} -o /tmp/eeupd

UPDDATA=$(cat /tmp/eeupd | grep "${UPDTYPE}")
rm /tmp/eeupd
[ -z "${UPDDATA}" ] && no_update

OLDIFS=${IFS}
IFS=';' read -r -a updinfo <<< "${UPDDATA}"
IFS=${OLDIFS}

UVER="${updinfo[0]}"
UFILE="Arcadia-${EE_DEVICE}.aarch64-${UVER}"

if [[ "${EE_DEVICE}" == "OdroidGoAdvance" ]]; then
    UFILE+="-odroidgo2.tar"
elif [[ "${EE_DEVICE}" == "GameForce" ]]; then
    UFILE+="-chi.tar"
elif [[ "${EE_DEVICE}" == "RK356x" ]]; then
    UFILE+="-rk356x.tar"
else
    UFILE+=".tar"
fi

UPDURL+="${UVER}/${UFILE}"

#check if file exists
if ! curl --head --fail --silent "${UPDURL}" >/dev/null; then
if [[ "${arguments}" == *"forceupdate"* ]]; then
text_viewer -e -w -t "ERRO!" -f 24 -m "O arquivo de atualização não existe ou o aparelho está sem internet. ATUALIZAÇÃO CANCELADA.\n\nO EmulationStation será reiniciado."
no_update
fi
    no_update
fi

CVER=$(cat /usr/config/EE_VERSION)
[[ -z "${CVER}" ]] && no_update
if $(echo "${CVER}" | grep -q "TEST"); then
    CVER=$(echo "${CVER}" | sed "s|-TEST-||")
fi

UVER=$(echo "${UVER}" | sed "s|-TEST-||")
[[ -z "${UVER}" ]] && no_update

UPDATEVERP="${UVER}"

# Arcádia: versões no formato X.Y.Z (ex.: 1.0.0, 1.2.10); "sort -V" compara número a número
versao_mais_nova() {
    [ "${1}" != "${2}" ] && [ "$(printf '%s\n%s\n' "${1}" "${2}" | sort -V | tail -n 1)" = "${1}" ]
}


# if you use forceupdate as an argument you can forcibly download the latest STABLE release and call an update
if [[ "${arguments}" == *"forceupdate"* ]]; then
    text_viewer -y -w -t "Atualização forçada" -f 24 -m "Será baixada a versão mais recente do Arcádia (canal estável ou beta, conforme a configuração).\n\nSuas configurações, favoritos e saves são preservados (cópia de segurança em /storage/roms/backup/arcadia).\n\nO console reinicia se o download terminar bem. Continuar?"
    if [[ $? == 21 ]]; then
        forced_update
    else
        echo "Atualização forçada cancelada."
        no_update
	exit 1
    fi
else
    if versao_mais_nova "${UVER}" "${CVER}" ; then 
        check_update
    else 
        no_update
    fi 
fi
