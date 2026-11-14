# Prévia do Arcádia no Windows (RetroBat)

> **Situação em 14/11/2026:** aguardando confirmação do usuário para baixar o RetroBat e os jogos de teste. Este documento será completado depois da instalação, com as diferenças entre o tema original e o ajuste da prévia.

## Objetivo

Ver e testar o visual do Arcádia no computador antes de o aparelho chegar, usando o [RetroBat](https://www.retrobat.org) — frontend gratuito para Windows baseado no EmulationStation da linha Batocera, a mesma base do EmulationStation do EmuELEC.

## O que será instalado

| Item | Origem | Tamanho | Destino |
|---|---|---|---|
| RetroBat v8.3.1.1 estável (64 bits), `RetroBat-v8.3.1.1-stable-win64-setup.exe` (publicado em 17/10/2026) | <https://www.retrobat.org/repo/releases/> (site oficial) | 2,01 GB (2.012.257.306 bytes) | `D:\Adube Sistemas\Console de Jogo\arcadia-preview` |
| Nova the Squirrel (NES) — GPL-3.0 | [GitHub NovaSquirrel/NovaTheSquirrel](https://github.com/NovaSquirrel/NovaTheSquirrel/releases/tag/v1.0.6a) | 256 KB | `roms\nes` |
| Thwaite (NES) — GPL-3.0 | [GitHub pinobatch/thwaite-nes](https://github.com/pinobatch/thwaite-nes/releases/tag/v0.04) | 24 KB | `roms\nes` |
| Miniplanets (Mega Drive) — zlib | [GitHub sikthehedgehog/miniplanets](https://github.com/sikthehedgehog/miniplanets) | 512 KB | `roms\megadrive` |
| µCity (Game Boy Color) — GPL-3.0 | [GitHub AntonioND/ucity](https://github.com/AntonioND/ucity/releases/tag/v1.3) | 128 KB | `roms\gbc` |

## Planejado

1. Instalar o RetroBat em `arcadia-preview` (instalador oficial).
2. Copiar `temas/arcadia` para a pasta de temas do RetroBat e ativá-lo; se algo não funcionar no EmulationStation do RetroBat, criar um ajuste só para a prévia (sem alterar o tema original) e listar as diferenças aqui.
3. Configurar: idioma português do Brasil, salvamento e carregamento automático (`savestate_auto_save` / `savestate_auto_load`) no RetroArch e tela cheia.
4. Colocar os 4 jogos de teste nas pastas certas.
5. Criar o atalho "Arcádia (prévia)" na Área de Trabalho.
