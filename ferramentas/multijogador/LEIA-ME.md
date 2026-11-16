# Multijogador do Arcádia (multitap automático)

Ferramentas e dados do multitap automático por jogo. A explicação completa está em [docs/MULTIJOGADOR.md](../../docs/MULTIJOGADOR.md).

| Arquivo | Para que serve |
|---|---|
| `arcadia-multijogador.sh` | **Gerador do aparelho.** Vai para `/usr/bin` da imagem (pacote `packages/sx05re/arcadia-multijogador`). O `emuelecRunEmu.sh` o chama antes de abrir o RetroArch: se o jogo está na lista, grava o override do RetroArch só para esse jogo. |
| `listas/snes.txt`, `listas/megadrive.txt`, `listas/psx.txt` | Jogos de 3 ou mais jogadores com multitap, com o título oficial (No-Intro/Redump). Vão para `/usr/share/arcadia/multijogador/` da imagem. **Geradas**: não editar à mão. |
| `fontes/` | Listas da comunidade, como foram baixadas (origem, revisão e data no cabeçalho de cada arquivo). |
| `apelidos.txt` | Título da fonte → título oficial, para os nomes que não batem com a DAT (ou vazio, para ignorar). |
| `montar-listas.py` | Monta `listas/` a partir de `fontes/` + `apelidos.txt` + as DATs de `ferramentas/roms/dats`. Grava `relatorio-montagem.md` com os títulos sem correspondência. |
| `testar-gerador.sh` | Teste do gerador no Ubuntu do WSL (18 casos); relatório em `imagens-compiladas\logs\teste-multijogador-*.md`. |
| `testar-retroarch.sh` | Prova no RetroArch (WSLg) de que o override é carregado e o núcleo aceita o multitap; `provar` grava `imagens-compiladas\logs\teste-retroarch-multijogador-*.md`. |

## Fontes

| Console | Fonte | Adaptador |
|---|---|---|
| Super Nintendo | [Nintendo Wiki — Super Multitap](https://nintendo.fandom.com/wiki/Super_Multitap) (lista com o número de jogadores) | Super Multitap |
| Mega Drive | [Sega Retro — Team Player](https://segaretro.org/Team_Player) e [4 Way Play](https://segaretro.org/4_Way_Play) | Team Player (Sega) ou 4 Way Play (EA) |
| PlayStation | [Wikipedia — PlayStation Multitap](https://en.wikipedia.org/wiki/PlayStation_Multitap) | Multitap |

As DATs No-Intro/Redump não têm o número de jogadores. A base `metadat/maxusers` do libretro-database tem, mas mistura jogos simultâneos com jogos de turnos (golfe, pinball, tabuleiro), não diz qual adaptador cada jogo usa e não cobre o PlayStation. Por isso as listas de multitap saem das fontes acima; a `maxusers` é usada só para o campo "jogadores" do `gamelist.xml` (`limpar-roms.py`).

## Atualizar as listas

```powershell
cd "D:\Adube Sistemas\Console de Jogo\console-retro-os\ferramentas\multijogador"
python montar-listas.py --atualizar-fontes
```

Sem `--atualizar-fontes`, monta de novo só com o que já está em `fontes/` (sem internet). Depois confira `relatorio-montagem.md`: título que não achou correspondência ganha uma linha em `apelidos.txt`. Rode `testar-gerador.sh`, faça o commit e recompile a imagem.

## Normalização dos nomes

O aparelho compara o **nome do arquivo** do jogo com a coluna `chave` das listas. As duas pontas normalizam igual:
1. tiram a extensão, tudo entre `( )` e `[ ]`;
2. passam para minúsculas e trocam `&` por `and`;
3. tiram o "the" do início e o ", The" do meio;
4. deixam só letras e números.

Assim `Super Bomberman 2 (USA).sfc`, `Super Bomberman 2 (E) [!].smc` e `super bomberman 2.sfc` caem todos em `superbomberman2`.
