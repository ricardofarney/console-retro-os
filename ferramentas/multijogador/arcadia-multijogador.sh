#!/bin/bash
# Arcádia — multitap automático por jogo (docs/MULTIJOGADOR.md)
#
# Chamado pelo emuelecRunEmu.sh antes de abrir o RetroArch:
#   arcadia-multijogador.sh <plataforma> <caminho do jogo> <núcleo, ex.: snes9x_libretro>
#
# Se o jogo está na lista de jogos de 3 ou mais jogadores do console
# (/usr/share/arcadia/multijogador/<console>.txt), grava um override do RetroArch
# só para esse jogo:
#   - config/<Núcleo>/<jogo>.cfg  tipo de controle (snes9x, Genesis Plus GX)
#   - config/<Núcleo>/<jogo>.opt  opção do núcleo (PicoDrive, PCSX ReARMed)
# Jogos fora da lista não recebem nada: continuam com 1 ou 2 controles normais.
# Arquivos criados aqui ficam registrados em config/.arcadia-multijogador; se um jogo
# sair da lista, o próprio script retira o arquivo que ele criou.
#
# Variáveis para teste fora do aparelho (ferramentas/multijogador/testar-gerador.sh):
#   ARCADIA_MJ_LISTAS, ARCADIA_MJ_CONFIG, ARCADIA_MJ_COREOPTS, ARCADIA_MJ_LOG

LISTAS="${ARCADIA_MJ_LISTAS:-/usr/share/arcadia/multijogador}"
CFGDIR="${ARCADIA_MJ_CONFIG:-/storage/.config/retroarch/config}"
COREOPTS="${ARCADIA_MJ_COREOPTS:-/storage/.config/retroarch/retroarch-core-options.cfg}"
LOG="${ARCADIA_MJ_LOG:-/emuelec/logs/arcadia-multijogador.log}"
REGISTRO="${CFGDIR}/.arcadia-multijogador"
MARCA="# Arcadia multijogador: gerado automaticamente (docs/MULTIJOGADOR.md)"

PLATAFORMA="${1,,}"
JOGO="${2}"
NUCLEO="${3}"

log() { echo "$(TZ=America/Sao_Paulo date '+%d/%m/%Y %H:%M:%S') ${*}" >> "${LOG}" 2>/dev/null; }
: > "${LOG}" 2>/dev/null

# mesma normalização do montar-listas.py: sem extensão, sem (…) e […], minúsculas,
# & = and, sem "the" no início nem ", the", só letras e números
chave_de() {
    printf '%s' "${1}" | sed -E 's/\([^)]*\)//g; s/\[[^]]*\]//g' | tr 'A-Z' 'a-z' \
        | sed -E 's/&/and/g; s/^[[:space:]]*the[[:space:]]+//; s/,[[:space:]]*the([[:space:]]|-|$)/\1/g; s/[^a-z0-9]//g'
}

# grava/atualiza "chave = "valor"" num arquivo de configuração
definir() {
    local arq="${1}" k="${2}" v="${3}"
    if grep -q "^${k}[[:space:]]*=" "${arq}" 2>/dev/null; then
        sed -i "s|^${k}[[:space:]]*=.*|${k} = \"${v}\"|" "${arq}"
    else
        echo "${k} = \"${v}\"" >> "${arq}"
    fi
}

registrado() { grep -qxF "${1}" "${REGISTRO}" 2>/dev/null; }
registrar() { registrado "${1}" || echo "${1}" >> "${REGISTRO}"; }
desregistrar() {
    [ -f "${REGISTRO}" ] || return 0
    grep -vxF "${1}" "${REGISTRO}" > "${REGISTRO}.tmp"
    mv -f "${REGISTRO}.tmp" "${REGISTRO}"
}

case "${PLATAFORMA}" in
    snes|sfc|snesh|snesmsu1|superfamicom) CONSOLE="snes" ;;
    megadrive|genesis|megadrive-japan) CONSOLE="megadrive" ;;
    psx) CONSOLE="psx" ;;
    *) log "plataforma ${PLATAFORMA}: sem multitap automático"; exit 0 ;;
esac

# núcleo -> nome da biblioteca (pasta do override) e tipo de ajuste
case "${NUCLEO%_libretro}" in
    snes9x) LIB="Snes9x"; TIPO="cfg" ;;
    snes9x2010) LIB="Snes9x 2010"; TIPO="cfg" ;;
    genesis_plus_gx|genesis_plus_gx_cart_special) LIB="Genesis Plus GX"; TIPO="cfg" ;;
    genesis_plus_gx_wide) LIB="Genesis Plus GX Wide"; TIPO="cfg" ;;
    picodrive) LIB="PicoDrive"; TIPO="opt" ;;
    pcsx_rearmed|pcsx_rearmed_32b) LIB="PCSX-ReARMed"; TIPO="opt" ;;
    *) log "núcleo ${NUCLEO}: sem multitap automático"; exit 0 ;;
esac

NOME="${JOGO##*/}"
NOME="${NOME%.*}"
CHAVE="$(chave_de "${NOME}")"
ARQ="${CFGDIR}/${LIB}/${NOME}.${TIPO}"
LINHA="$(grep -m1 "^${CHAVE}|" "${LISTAS}/${CONSOLE}.txt" 2>/dev/null)"

if [ -z "${LINHA}" ]; then
    # fora da lista: retira um override antigo só se foi este script que o criou
    if registrado "${ARQ}"; then
        rm -f "${ARQ}"
        desregistrar "${ARQ}"
        log "${NOME}: saiu da lista, override retirado (${ARQ})"
    else
        log "${NOME} (chave ${CHAVE}): 1 ou 2 jogadores, nada a fazer"
    fi
    exit 0
fi

IFS='|' read -r _ TITULO JOGADORES MODO <<< "${LINHA}"
mkdir -p "${CFGDIR}/${LIB}"

if [ "${TIPO}" = "cfg" ]; then
    # tipo de controle por porta (valores conferidos no código dos núcleos)
    case "${CONSOLE}:${MODO}" in
        snes:multitap)        P1="";     P2="257" ;;   # Super Multitap na porta 2 (jogadores 2 a 5)
        megadrive:teamplayer) P1="1537"; P2="" ;;      # Team Player na porta 1 (jogadores 1 a 4)
        megadrive:4wayplay)   P1="1025"; P2="1025" ;;  # EA 4 Way Play (usa as duas portas)
        *) log "${NOME}: modo ${MODO} sem ajuste para ${LIB}"; exit 0 ;;
    esac
    if [ ! -f "${ARQ}" ] || registrado "${ARQ}" || grep -qF "${MARCA}" "${ARQ}"; then
        {
            echo "${MARCA}"
            echo "# ${TITULO}: até ${JOGADORES} jogadores (${MODO})"
            [ -n "${P1}" ] && echo "input_libretro_device_p1 = \"${P1}\""
            [ -n "${P2}" ] && echo "input_libretro_device_p2 = \"${P2}\""
        } > "${ARQ}"
        registrar "${ARQ}"
    else
        # override feito pela pessoa: mantém tudo e só acerta o tipo de controle
        [ -n "${P1}" ] && definir "${ARQ}" "input_libretro_device_p1" "${P1}"
        [ -n "${P2}" ] && definir "${ARQ}" "input_libretro_device_p2" "${P2}"
    fi
else
    # opção do núcleo por jogo: o RetroArch usa o .opt do jogo NO LUGAR das opções
    # do núcleo, então o arquivo nasce como cópia delas + a opção do multitap
    case "${LIB}:${MODO}" in
        PicoDrive:teamplayer) PREFIXO="picodrive_"; K="picodrive_input1"; V="team player" ;;
        PicoDrive:4wayplay)   PREFIXO="picodrive_"; K="picodrive_input1"; V="4way play" ;;
        PCSX-ReARMed:multitap) PREFIXO="pcsx_rearmed_"; K="pcsx_rearmed_multitap"; V="port 1" ;;
        *) log "${NOME}: modo ${MODO} sem ajuste para ${LIB}"; exit 0 ;;
    esac
    if [ ! -f "${ARQ}" ]; then
        BASE="${CFGDIR}/${LIB}/${LIB}.opt"
        [ -f "${BASE}" ] || BASE="${COREOPTS}"
        grep "^${PREFIXO}" "${BASE}" 2>/dev/null | grep -v "^${K}[[:space:]]*=" | tr -d '\r' > "${ARQ}"
        registrar "${ARQ}"
    fi
    definir "${ARQ}" "${K}" "${V}"
fi

log "${NOME} -> ${TITULO} (${JOGADORES} jogadores, ${MODO}): ${ARQ}"
exit 0
