#!/bin/bash
# Arcádia — teste do gerador de multitap (arcadia-multijogador.sh) fora do aparelho.
# Roda no Ubuntu do WSL com as listas e o script do repositório, numa pasta de teste
# (~/arcadia-teste-multijogador), e grava o relatório em imagens-compiladas\logs.
#
# Uso (PowerShell):
#   wsl -d Ubuntu-22.04 -- bash -c "tr -d '\r' < '/mnt/d/Adube Sistemas/Console de Jogo/console-retro-os/ferramentas/multijogador/testar-gerador.sh' | bash"

REPO="/mnt/d/Adube Sistemas/Console de Jogo/console-retro-os"
MJ="${REPO}/ferramentas/multijogador"
SAIDA="/mnt/d/Adube Sistemas/Console de Jogo/imagens-compiladas/logs"
T="${HOME}/arcadia-teste-multijogador"
DATA="$(TZ=America/Sao_Paulo date +%Y-%m-%d_%H%M)"
REL="${SAIDA}/teste-multijogador-${DATA}.md"

rm -rf "${T}"
mkdir -p "${T}/listas" "${T}/config" "${SAIDA}"
tr -d '\r' < "${MJ}/arcadia-multijogador.sh" > "${T}/arcadia-multijogador.sh"
for f in "${MJ}"/listas/*.txt; do tr -d '\r' < "${f}" > "${T}/listas/$(basename "${f}")"; done
tr -d '\r' < "${REPO}/packages/sx05re/emuelec/config/retroarch/retroarch-core-options.cfg" > "${T}/core-options.cfg"

export ARCADIA_MJ_LISTAS="${T}/listas" ARCADIA_MJ_CONFIG="${T}/config" \
       ARCADIA_MJ_COREOPTS="${T}/core-options.cfg" ARCADIA_MJ_LOG="${T}/ultimo.log"

OK=0; FALHA=0; LINHAS=""
conferir() {   # descrição, comando de teste
    if eval "${2}"; then OK=$((OK+1)); r="OK"; else FALHA=$((FALHA+1)); r="FALHOU"; fi
    LINHAS+="| ${1} | ${r} |"$'\n'
    echo "${r}: ${1}"
}
gerar() { bash "${T}/arcadia-multijogador.sh" "$@"; }
C="${T}/config"

# 1) Super Nintendo — Super Multitap na porta 2
gerar snes "/storage/roms/snes/Super Bomberman 2 (USA).sfc" snes9x_libretro
conferir "SNES: Super Bomberman 2 recebe Super Multitap (porta 2 = 257)" \
  "grep -qx 'input_libretro_device_p2 = \"257\"' \"${C}/Snes9x/Super Bomberman 2 (USA).cfg\""
conferir "SNES: override não mexe na porta 1" \
  "! grep -q 'input_libretro_device_p1' \"${C}/Snes9x/Super Bomberman 2 (USA).cfg\""
gerar snes "/storage/roms/snes/Super Mario World (USA).sfc" snes9x_libretro
conferir "SNES: Super Mario World (2 jogadores) não recebe nada" \
  "[ ! -e \"${C}/Snes9x/Super Mario World (USA).cfg\" ]"
gerar snes "/storage/roms/snes/Sporting News, The - Baseball (USA).sfc" snes9x_libretro
conferir "SNES: nome com ', The' é reconhecido (Sporting News Baseball)" \
  "[ -f \"${C}/Snes9x/Sporting News, The - Baseball (USA).cfg\" ]"
gerar sfc "/storage/roms/sfc/NBA Jam (U) [!].smc" snes9x2010_libretro
conferir "SNES: nome fora do padrão No-Intro ('NBA Jam (U) [!]') e núcleo snes9x2010" \
  "grep -q '257' \"${C}/Snes9x 2010/NBA Jam (U) [!].cfg\""
gerar snes "/storage/roms/snes/Super Bomberman 2 (USA).sfc" snes9x2002_libretro
conferir "SNES: núcleo sem suporte (snes9x2002) não recebe arquivo" \
  "[ ! -d \"${C}/Snes9x 2002\" ]"

# 2) Mega Drive — Team Player e 4 Way Play
gerar megadrive "/storage/roms/megadrive/NBA Jam (USA, Europe) (Rev 1).md" genesis_plus_gx_libretro
conferir "Mega Drive: NBA Jam recebe Team Player na porta 1 (1537)" \
  "grep -qx 'input_libretro_device_p1 = \"1537\"' \"${C}/Genesis Plus GX/NBA Jam (USA, Europe) (Rev 1).cfg\""
gerar genesis "/storage/roms/genesis/NHL '94 (USA, Europe).md" genesis_plus_gx_libretro
conferir "Mega Drive: NHL '94 recebe 4 Way Play nas duas portas (1025)" \
  "[ \"\$(grep -c '\"1025\"' \"${C}/Genesis Plus GX/NHL '94 (USA, Europe).cfg\")\" = 2 ]"
gerar megadrive "/storage/roms/megadrive/Sonic The Hedgehog 2 (World) (Rev A).md" genesis_plus_gx_libretro
conferir "Mega Drive: Sonic 2 (2 jogadores) não recebe nada" \
  "[ \"\$(ls \"${C}/Genesis Plus GX\" | grep -c Sonic)\" = 0 ]"
gerar megadrive "/storage/roms/megadrive/Gauntlet IV (USA, Europe) (August 1993).md" picodrive_libretro
conferir "Mega Drive (PicoDrive): Gauntlet IV recebe picodrive_input1 = team player" \
  "grep -qx 'picodrive_input1 = \"team player\"' \"${C}/PicoDrive/Gauntlet IV (USA, Europe) (August 1993).opt\""

# 3) PlayStation — multitap na porta 1, cópia das opções do núcleo
gerar psx "/storage/roms/psx/CTR - Crash Team Racing (USA).cue" pcsx_rearmed_32b_libretro
O="${C}/PCSX-ReARMed/CTR - Crash Team Racing (USA).opt"
conferir "PlayStation: Crash Team Racing recebe pcsx_rearmed_multitap = port 1" \
  "grep -qx 'pcsx_rearmed_multitap = \"port 1\"' \"${O}\""
conferir "PlayStation: o .opt do jogo mantém as opções de desempenho do Arcádia" \
  "grep -q 'pcsx_rearmed_gpu_thread_rendering = \"sync\"' \"${O}\" && grep -q 'pcsx_rearmed_frameskip_type = \"disabled\"' \"${O}\""
conferir "PlayStation: o .opt do jogo tem só opções do PCSX ReARMed" \
  "! grep -v '^pcsx_rearmed_' \"${O}\" | grep -q ."
gerar psx "/storage/roms/psx/Final Fantasy VII (USA) (Disc 1).cue" pcsx_rearmed_32b_libretro
conferir "PlayStation: Final Fantasy VII (1 jogador) não recebe nada" \
  "[ \"\$(ls \"${C}/PCSX-ReARMed\" | wc -l)\" = 1 ]"

# 4) Nintendo 64 e Arcade — 4 controles sem ajuste
gerar n64 "/storage/roms/n64/Mario Kart 64 (USA).z64" mupen64plus_next_libretro
gerar arcade "/storage/roms/arcade/tmnt.zip" mame2003_plus_libretro
conferir "Nintendo 64 e Arcade: nenhum arquivo criado (4 controles nativos)" \
  "[ ! -d \"${C}/Mupen64Plus-Next\" ] && [ ! -d \"${C}/MAME 2003-Plus\" ]"

# 5) Override feito pela pessoa é preservado
mkdir -p "${C}/Snes9x"
printf 'video_shader_enable = "true"\n' > "${C}/Snes9x/Secret of Mana (USA).cfg"
gerar snes "/storage/roms/snes/Secret of Mana (USA).sfc" snes9x_libretro
conferir "Override próprio da pessoa: mantém o conteúdo e só acrescenta o multitap" \
  "grep -q 'video_shader_enable' \"${C}/Snes9x/Secret of Mana (USA).cfg\" && grep -q '257' \"${C}/Snes9x/Secret of Mana (USA).cfg\""

# 6) Jogo que sai da lista: o arquivo criado pelo gerador é retirado
grep -v '^superbomberman2|' "${T}/listas/snes.txt" > "${T}/snes.tmp" && mv "${T}/snes.tmp" "${T}/listas/snes.txt"
gerar snes "/storage/roms/snes/Super Bomberman 2 (USA).sfc" snes9x_libretro
conferir "Jogo que saiu da lista: override gerado é retirado e sai do registro" \
  "[ ! -e \"${C}/Snes9x/Super Bomberman 2 (USA).cfg\" ] && ! grep -q 'Super Bomberman 2' \"${C}/.arcadia-multijogador\""
conferir "Override próprio da pessoa nunca entra no registro (não é apagado)" \
  "! grep -q 'Secret of Mana' \"${C}/.arcadia-multijogador\""

{
    echo "# Teste do gerador de multitap — $(TZ=America/Sao_Paulo date '+%d/%m/%Y %H:%M') (horário de Brasília)"
    echo
    echo "Script: \`ferramentas/multijogador/testar-gerador.sh\` (Ubuntu do WSL, listas e gerador do repositório)."
    echo
    echo "**${OK} OK, ${FALHA} falha(s).**"
    echo
    echo "| Item | Resultado |"
    echo "|---|---|"
    printf '%s' "${LINHAS}"
    echo
    echo "## Arquivos gerados"
    echo
    echo '```'
    (cd "${C}" && find . -type f | sort | while read -r f; do echo "== ${f}"; head -5 "${f}"; done)
    echo '```'
} > "${REL}"
echo "RESULTADO: ${OK} OK, ${FALHA} falha(s) — relatório em ${REL}"
[ "${FALHA}" = 0 ]
