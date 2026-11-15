# DATs No-Intro / Redump do Arcádia

Esta pasta guarda, **dentro do repositório**, as DATs usadas pela ferramenta `ferramentas\roms\limpar-roms.py` para reconhecer as ROMs pelo CRC32 (nome oficial, região, revisão). Com elas a ferramenta funciona **sem internet** (`--offline`) e, no modo normal, não precisa baixar nada para os consoles da paleta.

## Origem

- Repositório: [libretro/libretro-database](https://github.com/libretro/libretro-database), pastas `metadat/no-intro/` (cartuchos) e `metadat/redump/` (discos). São cópias das DATs públicas do [No-Intro](https://no-intro.org) e do [Redump](http://redump.org) no formato clrmamepro, mantidas pelo projeto libretro.
- Versão guardada: commit `b2e5eaa256eb30c6301ed42a8eab3ba2afd74b8a` (15/11/2026 00:42 UTC), baixada em **15/11/2026 01:24 (horário de Brasília)**. O registro exato (commit, data e tamanho de cada arquivo) fica em `VERSAO.txt`, que a ferramenta regrava a cada atualização.
- Formato: texto (`.dat`). Todas as DATs atuais têm menos de 4 MB (total ≈ 13 MB). Se alguma passar de 50 MB numa atualização futura, a ferramenta a grava como `<nome>.zip` (com o `.dat` dentro) e lê o `.zip` direto.

## Conteúdo

| Console (paleta) | Arquivo | Tamanho | Jogos |
|---|---|---|---|
| Atari 2600 | `no-intro/Atari - 2600.dat` | 184,6 KB | 901 |
| Atari 7800 | `no-intro/Atari - 7800.dat` | 75,8 KB | 337 |
| NES / Famicom | `no-intro/Nintendo - Nintendo Entertainment System.dat` | 3,1 MB | 13.296 |
| Famicom Disk System | `no-intro/Nintendo - Family Computer Disk System.dat` | 181,6 KB | 680 |
| Super Nintendo | `no-intro/Nintendo - Super Nintendo Entertainment System.dat` | 860,1 KB | 3.746 |
| Nintendo 64 | `no-intro/Nintendo - Nintendo 64.dat` | 584,3 KB | 2.263 |
| Game Boy | `no-intro/Nintendo - Game Boy.dat` | 518,6 KB | 2.144 |
| Game Boy Color | `no-intro/Nintendo - Game Boy Color.dat` | 660,2 KB | 2.446 |
| Game Boy Advance | `no-intro/Nintendo - Game Boy Advance.dat` | 997,3 KB | 3.509 |
| Master System | `no-intro/Sega - Master System - Mark III.dat` | 254,1 KB | 1.057 |
| Mega Drive / Genesis | `no-intro/Sega - Mega Drive - Genesis.dat` | 766,9 KB | 2.800 |
| Sega 32X | `no-intro/Sega - 32X.dat` | 20,3 KB | 74 |
| Game Gear | `no-intro/Sega - Game Gear.dat` | 140,5 KB | 607 |
| PC Engine / TurboGrafx-16 | `no-intro/NEC - PC Engine - TurboGrafx 16.dat` | 109,4 KB | 491 |
| PC Engine SuperGrafx | `no-intro/NEC - PC Engine SuperGrafx.dat` | 1,4 KB | 5 |
| Neo Geo Pocket | `no-intro/SNK - Neo Geo Pocket.dat` | 3,0 KB | 9 |
| Neo Geo Pocket Color | `no-intro/SNK - Neo Geo Pocket Color.dat` | 29,7 KB | 106 |
| WonderSwan | `no-intro/Bandai - WonderSwan.dat` | 53,5 KB | 219 |
| WonderSwan Color | `no-intro/Bandai - WonderSwan Color.dat` | 57,7 KB | 229 |
| MSX | `no-intro/Microsoft - MSX.dat` | 183,7 KB | 899 |
| MSX2 | `no-intro/Microsoft - MSX2.dat` | 42,9 KB | 195 |
| Sega CD / Mega-CD | `redump/Sega - Mega-CD - Sega CD.dat` | 146,8 KB | 534 |
| PlayStation | `redump/Sony - PlayStation.dat` | 3,8 MB | 13.459 |
| PC Engine CD / TurboGrafx-CD | `redump/NEC - PC Engine CD - TurboGrafx-CD.dat` | 137,7 KB | 502 |
| **Total** | 24 arquivos | **≈ 13 MB** | |

**Arcade e Neo Geo (MAME / FinalBurn Neo) não usam No-Intro nem Redump**: os romsets de arcade são definidos pelas DATs do próprio emulador (versão exata do MAME ou do FBNeo que o EmuELEC usa), e um romset só funciona com a versão do emulador para a qual foi montado. Por isso não há DAT de arcade aqui — a ferramenta trata `neogeo`/arcade só verificando a integridade dos `.zip` e nunca agrupa versões (clones dependem dos pais). Para validar romsets de arcade use o ClrMamePro/RomVault com a DAT do emulador correspondente.

## Como a ferramenta usa

Ordem de busca da DAT de um console:

1. `ferramentas\roms\dats\<no-intro|redump>\<nome>.dat` (ou `.zip`) — **esta pasta**;
2. `ferramentas\roms\.cache\dats\<nome>.dat` — DATs baixadas antes para consoles que não estão aqui (fora do git);
3. download do libretro-database para o cache (só no modo normal; **nunca** com `--offline`).

## Como atualizar

```powershell
cd "D:\Adube Sistemas\Console de Jogo\console-retro-os\ferramentas\roms"
python limpar-roms.py --atualizar-dats
```

Isso baixa de novo as 24 DATs acima, todas do mesmo commit do libretro-database, substitui os arquivos desta pasta e regrava `VERSAO.txt`. Depois confira com `git diff --stat ferramentas/roms/dats` e faça o commit. Para acrescentar um console, inclua-o na lista `DATS_PALETA` no começo de `limpar-roms.py` (nome exatamente como em `metadat/no-intro` ou `metadat/redump`).

`--atualizar-dats` também pode vir junto com uma pasta de ROMs (`python limpar-roms.py "E:\roms" --atualizar-dats`): atualiza e em seguida faz a limpeza. Não combina com `--offline`.
