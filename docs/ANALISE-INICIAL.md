# Análise inicial — Console de Jogos Retrô (`console-retro-os`)

- **Data:** 14/11/2026, 12:24 (horário de Brasília)
- **Base analisada:** fork de [EmuELEC/EmuELEC](https://github.com/EmuELEC/EmuELEC), branch `dev`, commit `d4c7b2f143` (15/10/2026 — "Added geartowns libretro core…")
- **Alvo:** aparelhos Amlogic S905X3 (ex.: Super Console X3 Plus) → `PROJECT=Amlogic-ce DEVICE=Amlogic-ng ARCH=aarch64`
- **Escopo:** somente leitura. Nenhum código foi alterado nesta etapa.

> ⚠️ **Aviso mais importante deste relatório.** O próprio [README do EmuELEC](../README.md#license) diz que a distribuição, **como está**, *não pode ser vendida, empacotada ou incluída em produtos comerciais — citando expressamente TV boxes* — porque contém núcleos com licença não comercial. A marca, os logotipos e as imagens do EmuELEC também não podem ir para produto comercial sem permissão. Ou seja: antes de vender qualquer aparelho com este sistema, é **obrigatório** (1) remover todos os itens marcados 🔴 na seção 3, (2) remover toda a marca EmuELEC (nome, logos, splash, tema Carbon) e (3) cumprir as obrigações da GPL (publicar o código-fonte correspondente a cada versão distribuída). Este documento é uma análise técnica e não substitui revisão jurídica.

---

## Sumário

1. [Como compilar a imagem para S905X3 (Amlogic-ng)](#1-como-compilar-a-imagem-para-s905x3-amlogic-ng)
2. [Onde fica cada peça do sistema](#2-onde-fica-cada-peça-do-sistema)
3. [Núcleos e emuladores incluídos e suas licenças](#3-núcleos-e-emuladores-incluídos-e-suas-licenças)
4. [Plano proposto em etapas](#4-plano-proposto-em-etapas)
5. [Riscos e pendências](#5-riscos-e-pendências)

---

## 1. Como compilar a imagem para S905X3 (Amlogic-ng)

### 1.1 Qual DEVICE usar

Em [projects/Amlogic-ce/devices/](../projects/Amlogic-ce/devices) existem `Amlogic-ng`, `Amlogic-ng-dv`, `Amlogic-no` e `Amlogic-old`. O S905X3 (SM1) é atendido pelo **`Amlogic-ng`**: kernel `amlogic-4.9`, `TARGET_CPU="cortex-a53"` (o Cortex-A55 do S905X3 roda código A53; o mesmo device cobre o S922X com `cortex-a73.cortex-a53`), u-boot e imagem Android (`kernel.img`) — ver [projects/Amlogic-ce/devices/Amlogic-ng/options](../projects/Amlogic-ce/devices/Amlogic-ng/options). O `Amlogic-ng` também recebe os núcleos "pesados" da lista `LIBRETRO_S922X_CORES`, o `dolphinSA` e o `mame` atual (ver [packages/sx05re/emuelec/package.mk](../packages/sx05re/emuelec/package.mk), linhas 19–22 e 56–71).

### 1.2 O que é necessário no computador

| Item | Mínimo | Recomendado |
|---|---|---|
| Sistema | Linux x86_64 (Debian/Ubuntu) **ou** Windows 10/11 com WSL2 | Ubuntu 22.04 LTS (nativo ou WSL2) |
| CPU | 4 núcleos | 8 a 16 núcleos (a 1ª compilação leva várias horas; o `mame` é o pacote mais demorado) |
| Memória RAM | 8 GB + swap | 16 a 32 GB (o link do MAME com LTO consome muita memória) |
| Disco livre | 150 GB | 250 GB em SSD (fontes + `build.*` + ccache) |
| Internet | estável | as fontes de centenas de pacotes são baixadas na 1ª compilação |

Pacotes (lista do README, para Debian/Ubuntu):

```bash
sudo apt install gcc make git unzip wget xz-utils libsdl2-dev libsdl2-mixer-dev libfreeimage-dev libfreetype6-dev libcurl4-openssl-dev rapidjson-dev libasound2-dev libgl1-mesa-dev build-essential libboost-all-dev cmake fonts-droid-fallback libvlc-dev libvlccore-dev vlc-bin texinfo premake4 golang libssl-dev curl patchelf xmlstarlet default-jre xsltproc libvpx-dev rdfind tzdata xfonts-utils lzop
```

### 1.3 Windows com WSL2 — cuidados obrigatórios

1. Instalar: `wsl --install -d Ubuntu-22.04` (PowerShell como administrador).
2. **Compilar dentro do sistema de arquivos do Linux** (ex.: `~/console-retro-os`), **nunca** em `/mnt/d/...`. O NTFS montado no WSL é lento, não diferencia maiúsculas/minúsculas e não guarda permissões Unix — o build quebra ou fica dezenas de vezes mais lento.
3. Neste computador o Git do Windows está com `core.autocrlf=true` (definido em `C:\Program Files\Git\etc\gitconfig`). Portanto a cópia em `D:\ADUBE SISTEMAS\console-retro-os` tem finais de linha CRLF nos scripts e **não serve para compilar**. Use-a para documentação/edição e faça um clone separado dentro do WSL.
4. Dar memória suficiente ao WSL criando `%UserProfile%\.wslconfig`:

   ```ini
   [wsl2]
   memory=24GB
   swap=32GB
   processors=12
   ```

### 1.4 Passo a passo (Linux ou WSL2)

```bash
git clone https://github.com/ricardofarney/console-retro-os.git ~/console-retro-os
cd ~/console-retro-os
git checkout dev
git remote add upstream https://github.com/EmuELEC/EmuELEC.git
PROJECT=Amlogic-ce DEVICE=Amlogic-ng ARCH=aarch64 DISTRO=EmuELEC make image
```

Resultado em `target/`:

- `EmuELEC-Amlogic-ng.aarch64-<versão>.img.gz` → gravar no cartão SD/pendrive (balenaEtcher, Rufus etc.);
- `EmuELEC-Amlogic-ng.aarch64-<versão>.tar` → pacote de **atualização** (é o arquivo que o mecanismo de update baixa — ver seção 2.4).

Comandos úteis no dia a dia (mesmas variáveis de ambiente na frente):

- recompilar só um pacote: `PROJECT=Amlogic-ce DEVICE=Amlogic-ng ARCH=aarch64 DISTRO=EmuELEC ./scripts/clean <pacote>` e depois `make image`;
- chaves de API do ScreenScraper/RetroAchievements: opcionais, lidas de `api_keys.txt` (ver comentário em [packages/sx05re/emuelec-emulationstation/package.mk](../packages/sx05re/emuelec-emulationstation/package.mk)).

**Alternativa com Docker** (isola as dependências): existem Dockerfiles em [tools/docker/](../tools/docker) (`jammy` = Ubuntu 22.04):

```bash
docker build --pull -t console-retro-build tools/docker/jammy
docker run --rm -v "$PWD":/build -w /build -e PROJECT=Amlogic-ce -e DEVICE=Amlogic-ng -e ARCH=aarch64 -e DISTRO=EmuELEC -it console-retro-build make image
```

O repositório não possui workflow de CI (`.github/workflows` não existe); a compilação automatizada terá de ser criada por nós (ver Etapa 4).

### 1.5 No aparelho

Após gravar a imagem, é preciso escolher o **DTB** do S905X3 na partição de boot (copiar o arquivo `sm1_s905x3_*.dtb` adequado — variantes 2 GB/4 GB e Ethernet 100M/1 Gbit — para a raiz como `dtb.img`). Para o produto final, o DTB correto do nosso modelo de placa deve ser fixado na imagem para o cliente não precisar fazer isso.

---

## 2. Onde fica cada peça do sistema

### 2.1 EmulationStation (interface) e temas

| O quê | Onde |
|---|---|
| Receita de compilação | [packages/sx05re/emuelec-emulationstation/package.mk](../packages/sx05re/emuelec-emulationstation/package.mk) |
| Código-fonte do ES | **repositório externo** [EmuELEC/emuelec-emulationstation](https://github.com/EmuELEC/emuelec-emulationstation), branch `EmuELEC`, fixado no commit `3de652c6…` (derivado do Batocera-EmulationStation) |
| Configuração padrão | [config/es_settings.cfg](../packages/sx05re/emuelec-emulationstation/config/es_settings.cfg) — tema padrão `Crystal`, `FavoritesFirst=true` |
| Sistemas e emuladores por sistema | [config/es_systems.json](../packages/sx05re/emuelec-emulationstation/config/es_systems.json) + gerador [generate_es_systems.py](../packages/sx05re/emuelec-emulationstation/generate_es_systems.py) |
| Recursos por emulador (menus de opções) | [config/es_features.cfg](../packages/sx05re/emuelec-emulationstation/config/es_features.cfg) |
| Temas incluídos | [themes/Crystal/package.mk](../packages/sx05re/emuelec-emulationstation/themes/Crystal/package.mk) (fonte: `github.com/dm2912/Crystal`, **padrão**) e [themes/es-theme-EmuELEC-carbon/package.mk](../packages/sx05re/emuelec-emulationstation/themes/es-theme-EmuELEC-carbon/package.mk) |
| Temas no aparelho | sistema (somente leitura): `/usr/config/emulationstation/themes/`; usuário: `/storage/.config/emulationstation/themes/` |
| Traduções | dentro do repositório do ES em `locale/lang/` — **já existe `pt_BR`** |
| Idioma padrão | `system.language=en_US` em [packages/sx05re/emuelec/config/emuelec/configs/emuelec.conf](../packages/sx05re/emuelec/config/emuelec/configs/emuelec.conf) (linha 154) |

Observação: no momento só o `Crystal` é dependência do pacote do ES (`PKG_DEPENDS_TARGET+=" Crystal"`); o Carbon tem receita, mas não está ligado ao build.

### 2.2 RetroArch — salvamento e carregamento automático de save state

A configuração é montada em **três camadas**:

1. **Arquivo base gerado na compilação** — [packages/sx05re/libretro_base/retroarch/package.mk](../packages/sx05re/libretro_base/retroarch/package.mk), linhas ~101–160: uma série de `sed`/`echo` sobre o `retroarch.cfg` do upstream define diretórios (`savestate_directory=/storage/roms/savestates`, `system_directory=/storage/roms/bios`, `screenshot_directory=…`), driver de vídeo/áudio/entrada, `savestate_thumbnail_enable=true` etc. Esse arquivo vai para `/usr/config/retroarch/retroarch.cfg` e é copiado para `/storage/.config/retroarch/retroarch.cfg` no primeiro boot.
2. **Configurações do usuário** — [emuelec.conf](../packages/sx05re/emuelec/config/emuelec/configs/emuelec.conf), linhas 193–194:

   ```ini
   ## Set autosave/load savestate for all emulators (0,1)
   #global.autosave=0
   ```

   Também aceita valor por sistema (`snes.autosave=1`, por exemplo), definido pelo menu do ES.
3. **Aplicação a cada jogo iniciado** — o ES repassa `-autosave <valor>` ao [emuelecRunEmu.sh](../packages/sx05re/emuelec/bin/emuelecRunEmu.sh) (linhas 492–497), que chama [setsettings.sh](../packages/sx05re/emuelec/bin/setsettings.sh):
   - linhas 116–126: força `savestate_directory = /storage/roms/savestates/<sistema>` e desliga a ordenação por pasta;
   - linhas 141–142 (`default_settings`): **padrão `savestate_auto_save = "false"` e `savestate_auto_load = "false"`**;
   - linhas 195–215 (`autosave`/`snapshot`): se o autosave estiver ligado, grava `true` nos dois; integra-se ao gerenciador de "snapshots" (slots) do ES.

**Saves de bateria (SRAM, `.srm`)**: `savefile_directory` fica comentado na linha 115 do `package.mk` do RetroArch, então o RetroArch grava o `.srm` **ao lado da ROM**, em `/storage/roms/<sistema>/`. Os save states ficam em `/storage/roms/savestates/<sistema>/`.

**Conclusão:** para ligar o salvamento/carregamento automático por padrão basta, em princípio, descomentar e trocar para `global.autosave=1` no `emuelec.conf` — a confirmar em teste no aparelho (o ES precisa repassar o argumento). Emuladores standalone (PPSSPP, Flycast SA, DuckStation SA, Mupen64Plus SA, Dolphin…) **não** usam essa chave; cada um tem seu próprio mecanismo.

### 2.3 Sistema de favoritos (e base para "Continuar jogando")

- Favoritos, data do último jogo (`lastplayed`) e contagem (`playcount`) são metadados de cada jogo no **`gamelist.xml`** do sistema (`<favorite>true</favorite>`).
- Caminho do `gamelist.xml` (função `SystemData::getGamelistPath` no fonte do ES): primeiro `/storage/roms/<sistema>/gamelist.xml`; se não existir, `~/.emulationstation/gamelists/<sistema>/gamelist.xml`.
- Coleções automáticas (arquivo `es-app/src/CollectionSystemManager.cpp` do ES): `favorites` ("favoritos") e **`recent` ("last played", ordenada por `lastplayed`)** — esta última é a base natural da linha **"Continuar jogando"**. Coleções personalizadas ficam em `~/.emulationstation/collections/*.cfg`.
- `FavoritesFirst=true` já vem ligado no `es_settings.cfg`.

### 2.4 Mecanismo de atualização

| Etapa | Arquivo | Detalhe |
|---|---|---|
| Verificar se há versão nova | [packages/sx05re/emuelec/bin/updatecheck.sh](../packages/sx05re/emuelec/bin/updatecheck.sh) | linha 8 `UPDINFO="https://raw.githubusercontent.com/EmuELEC/emuelec.github.io/master/settings/EE_update"` — arquivo de texto com uma linha por canal (`<versão>;…` contendo `stable` ou `beta`) |
| Endereço do pacote | mesmo arquivo, linhas 9–10 e 112–124 | `UPDURL="https://github.com/EmuELEC/EmuELEC/releases/download/v"` (estável) e `TEST_UPDURL=".../EmuELEC-tests/releases/download/v"` (beta); arquivo `EmuELEC-<device>.aarch64-<versão>.tar` |
| Comparação de versão | linhas 135–171 | compara `/usr/config/EE_VERSION` com a versão do servidor |
| Download | [packages/sx05re/emuelec/bin/batocera/emuelec-upgrade](../packages/sx05re/emuelec/bin/batocera/emuelec-upgrade) (chamado pelo menu "Atualizar" do ES) | baixa para `/storage/.update/` (que o init monta sobre `/storage/roms/.update`); confere `.sha256` **somente se existir** |
| Aplicação | [packages/sysutils/busybox/scripts/init](../packages/sysutils/busybox/scripts/init) (initramfs), linhas ~328–400 e ~740–850 | no próximo boot, verifica compatibilidade de projeto/arquitetura e grava `KERNEL`/`SYSTEM` na partição de boot; `/storage` não é tocado |
| Configuração do usuário | `emuelec.conf`, linhas 159–163 | `updates.enabled=1`, `updates.type=stable` |

**Como trocar pelo nosso servidor:** alterar `UPDINFO`, `UPDURL` e `TEST_UPDURL` no `updatecheck.sh` para endereços HTTPS nossos (pode ser o GitHub Releases do próprio fork ou um armazenamento como S3/Cloudflare R2), publicar um arquivo no mesmo formato do `EE_update` e, para cada versão, o `.tar` e o `.sha256`. O prefixo `EmuELEC-` do nome do arquivo vem de `DISTRONAME` e deve ser ajustado junto com a troca de marca.

**Problemas encontrados:**

1. **Sem assinatura digital.** O `.sha256` vem do mesmo servidor do `.tar` e é opcional — protege contra download corrompido, não contra arquivo adulterado.
2. **A "atualização forçada" apaga dados do usuário.** Em `updatecheck.sh forceupdate`, a função `forced_update` (linha 81) chama `emuelec-utils clearconfig EMUS`, que ([emuelec-utils](../packages/sx05re/emuelec/bin/emuelec-utils), linhas 131–140) faz um backup em `/storage/roms/backup/ee_backup_config.tar.gz` e depois **apaga todo o `/storage` exceto** temas, `.update`, `download`, `roms` e o cache do Bluetooth. Perdem-se configurações do ES e do RetroArch, coleções personalizadas e quaisquer `gamelist.xml` (favoritos) que estejam em `~/.emulationstation/gamelists/`. A atualização normal pelo menu não chama essa limpeza.

---

## 3. Núcleos e emuladores incluídos e suas licenças

### 3.1 Como a lista foi montada

- **Incluídos na imagem Amlogic-ng** = `LIBRETRO_CORES` de [distributions/EmuELEC/options](../distributions/EmuELEC/options) (linhas 274–386) + `PKG_EMUS` e `PKG_EXPERIMENTAL` de [packages/sx05re/emuelec/package.mk](../packages/sx05re/emuelec/package.mk) + `LIBRETRO_S922X_CORES` + extras de aarch64 (`swanstation`, núcleos `lib32-*`) + `dolphinSA` e `mame`. Em aarch64 são **removidos** `quicknes`, `parallel-n64` e `pcsx_rearmed` (substituídos pelas versões `lib32-`).
- Licença: campo `PKG_LICENSE` de cada `package.mk` e, nos casos ambíguos ou suspeitos, o arquivo de licença do repositório de origem consultado em 14/11/2026.
- **O campo `PKG_LICENSE` tem erros.** Exemplos confirmados: `cannonball` diz GPLv3, mas a licença real proíbe uso comercial; `picodrivesa` diz GPL2, mas o PicoDrive proíbe uso comercial; `PPSSPPSDL` diz "MAME", mas o PPSSPP é GPL-2.0+; `same_cdi` diz "MAME", mas o upstream é GPL (MAME moderno). Antes de qualquer lançamento, cada item deve ser reconferido.

Legenda: ✅ permite uso comercial (respeitando GPL/MIT/BSD etc.) · 🔴 **proíbe uso comercial** · 🟡 atenção (licença indefinida, conteúdo/ROM embutido protegido ou exigência específica).

### 3.2 Itens que PROÍBEM uso comercial (remover) e alternativas liberadas

| Núcleo/emulador | Sistema | Licença | Alternativa liberada |
|---|---|---|---|
| `snes9x`, `snes9x2002`, `snes9x2005_plus`, `snes9x2010` | Super Nintendo | Não comercial (licença Snes9x) | **Mesen-S** (GPLv3, já incluído) e **supafaust** (GPLv2, já incluído); bsnes/bsnes_hd (GPLv3) para jogos exigentes — validar desempenho no S905X3 |
| `genesis-plus-gx`, `genesis-plus-gx-wide`, `genesis_plus_gx_cart_special` | Mega Drive, Master System, Game Gear, Sega CD | Não comercial | **clownmdemu** (AGPLv3, já incluído — Mega Drive e Mega CD); **BlastEm** (GPLv3, núcleo libretro existe, não está no repo); **Gearsystem** (GPLv3, já incluído) para Master System/Game Gear |
| `picodrive` | Mega Drive, 32X, Sega Pico | Não comercial ("Redistributions may not be sold…") | Mega Drive: clownmdemu/BlastEm. 32X e Pico: **sem alternativa livre conhecida** → remover esses sistemas |
| `fbneo`, `fbalpha2012`, `fbneoSA` (experimental) | Arcade (CPS1/2/3, Neo Geo etc.) | Não comercial | **MAME atual** (GPL-2.0+, já incluído); **mame2016** (GPL, no repo, mais leve); **Geolith** (BSD-3, já incluído) para Neo Geo |
| `mame2003-plus`, `mame2010` | Arcade | Licença MAME antiga (não comercial) | **mame2016** ou **MAME atual** (GPL-2.0+) |
| `advancemame` | Arcade | Código do MAME 0.106 sob licença MAME antiga | MAME atual |
| `fmsx-libretro` | MSX | Proprietária ("não pode alterar nem copiar sem contatar o autor") | **blueMSX** (GPLv2, já incluído) e **openMSX** (GPL, já incluído) |
| `opera` | 3DO | LGPL com nota FreeDO: "uso comercial estritamente proibido sem aprovação" | **sem alternativa livre conhecida** → remover 3DO |
| `cannonball` | Motor do OutRun | Não comercial (+ marca SEGA) | Nenhuma → remover |
| `amiarcadia` | Emerson Arcadia 2001 | Não comercial | MAME atual (driver Arcadia) ou remover |
| `mu` | Palm OS | CC BY-NC 3.0 | Nenhuma → remover |
| `dinothawr` | Jogo | Não comercial | Remover (jogos livres como `mrboom`, `2048`, `xrick`* podem ocupar o lugar) |
| `bigpemu` | Atari Jaguar | Proprietária (freeware) — redistribuição comercial exige permissão do autor | **Virtual Jaguar** (GPLv3, já incluído) |
| `biginstinct` | Killer Instinct | Proprietária (freeware) | MAME atual |
| `dreamm` | Jogos LucasArts/SCUMM | Proprietária (freeware) | **ScummVM** (GPL, já incluído) |

\* ver observação sobre `xrick` na tabela 3.3.

Também fora da área de núcleos, mas com restrição: **marca EmuELEC** (logos, splash, nome) e **tema `es-theme-EmuELEC-carbon`** (derivado do tema Carbon, distribuído como CC BY-NC-SA) — não podem ir para produto comercial. O tema **Crystal** não tem licença declarada (GitHub: NOASSERTION) — trate como não liberado. Ambos serão substituídos pelo nosso tema (Etapa 2).

### 3.3 Lista completa dos incluídos na imagem Amlogic-ng

#### Núcleos libretro (`LIBRETRO_CORES`)

| Núcleo | Sistema principal | Licença | Situação |
|---|---|---|---|
| 2048 | Jogo 2048 | GPLv3 | ✅ |
| 81 | Sinclair ZX81 | GPLv3 | 🟡 ROM do ZX81 embutida (Amstrad autoriza distribuir com emuladores; confirmar uso comercial) |
| a5200 | Atari 5200 | GPLv2 | ✅ (BIOS não incluída) |
| amiarcadia | Emerson Arcadia 2001 | Não comercial | 🔴 |
| applewin | Apple II | GPL-2.0+ | ✅ |
| arduous | Arduboy | GPL-3.0+ | ✅ |
| atari800 | Atari 8 bits | GPL | ✅ |
| azahar | Nintendo 3DS | GPLv2+ | ✅ |
| b2 | BBC Micro | GPLv3 | ✅ |
| beetle-lynx | Atari Lynx | GPLv2 | ✅ |
| beetle-ngp | Neo Geo Pocket | GPLv2 | ✅ |
| beetle-pce | PC Engine | GPLv2 | ✅ |
| beetle-pcfx | PC-FX | GPLv2 | ✅ |
| beetle-supergrafx | SuperGrafx | GPLv2 | ✅ |
| beetle-vb | Virtual Boy | GPLv2 | ✅ |
| beetle-wswan | WonderSwan | GPLv2 | ✅ |
| bk | Elektronika BK | NTP (permissiva) | ✅ |
| bluemsx | MSX/ColecoVision | GPLv2 | ✅ |
| cannonball | OutRun | Não comercial | 🔴 |
| cap32 | Amstrad CPC | GPLv2 | 🟡 ROMs do CPC embutidas (mesma situação do ZX81) |
| clownmdemu | Mega Drive / Mega CD | AGPLv3 | ✅ (AGPL: fornecer o fonte) |
| daphne | LaserDisc | GPLv2+ | ✅ |
| dice | Arcade discreto | GPLv3 | ✅ |
| dinothawr | Jogo | Não comercial | 🔴 |
| dosbox-svn | MS-DOS | GPLv2 | ✅ |
| easyrpg | RPG Maker 2000/2003 | GPLv3 | ✅ |
| emuscv | Epoch Super Cassette Vision | GPL-3.0+ | ✅ |
| ep128emu | Enterprise 128 | GPL-2.0 | ✅ |
| exa-rs | EXA (jogo) | MIT | ✅ |
| fake_08 | PICO-8 | MIT | ✅ |
| fbalpha2012 | Arcade | Não comercial | 🔴 |
| fbneo | Arcade | Não comercial | 🔴 |
| fceumm | NES | GPLv2 | ✅ |
| fceumm-mod | NES | GPLv2 | ✅ |
| flycast | Dreamcast/Naomi | GPLv2 | ✅ |
| freechaf | Fairchild Channel F | GPLv3 | ✅ |
| freeintv | Intellivision | GPLv3 | ✅ |
| fuse-libretro | ZX Spectrum | GPLv3 | 🟡 ROMs do Spectrum embutidas (ver ZX81) |
| gambatte | Game Boy / Color | GPLv2 | ✅ |
| gearboy | Game Boy / Color | GPLv3 | ✅ |
| gearcoleco | ColecoVision | GPLv3 | ✅ |
| geargrafx | PC Engine | GPLv3 | ✅ |
| gearlynx | Atari Lynx | GPLv3 | ✅ |
| gearsystem | Master System / Game Gear / SG-1000 | GPLv3 | ✅ |
| geartowns | FM Towns | GPLv3 | ✅ |
| genesis-plus-gx | Mega Drive / SMS / GG / Sega CD | Não comercial | 🔴 |
| genesis_plus_gx_cart_special | Mega Drive | Não comercial | 🔴 |
| genesis-plus-gx-wide | Mega Drive (widescreen) | Não comercial | 🔴 |
| geolith | Neo Geo AES/MVS | BSD-3 | ✅ |
| gme | Música de videogame | GPLv3 | ✅ |
| gp32emu | GamePark 32 | LGPL | ✅ |
| gpsp | Game Boy Advance | GPLv2 | ✅ |
| gw-libretro | Game & Watch | Zlib | 🟡 núcleo livre, mas as simulações usam arte/ROM da Nintendo |
| handy | Atari Lynx | Zlib | ✅ |
| hatari | Atari ST | GPLv2 | ✅ (usar EmuTOS, livre) |
| jaxe | CHIP-8 | MIT | ✅ |
| jollycv | ColecoVision | BSD-3 | ✅ |
| lowresnx | LowRes NX | Zlib | ✅ |
| m2000 | Philips P2000 | GPLv3 | ✅ |
| mame2003-plus | Arcade | MAME antiga (não comercial) | 🔴 |
| mame2010 | Arcade | MAME antiga (não comercial) | 🔴 |
| meowpc98 | NEC PC-98 | MIT (GitHub) / "Unknown" no package.mk | 🟡 confirmar |
| mgba | Game Boy Advance | MPL-2.0 | ✅ |
| minivmac | Macintosh | GPL-2.0 | ✅ (ROM do Mac não incluída) |
| mojozork | Z-machine | Zlib | ✅ |
| mrboom | Jogo Mr. Boom | GPLv3 | ✅ |
| mu | Palm OS | CC BY-NC 3.0 | 🔴 |
| mupen64plus | Nintendo 64 | GPLv2 | ✅ |
| native32emu | Native32 | BSD-3 | ✅ |
| neocd_libretro | Neo Geo CD | LGPLv3 | ✅ |
| nestopia | NES | GPLv2 | ✅ |
| numero | TI-83 | GPLv2 | ✅ |
| nxengine | Cave Story | GPLv3 | 🟡 motor livre; os dados do Cave Story são freeware da Pixel (não comercial) |
| o2em | Odyssey² | Artistic License | ✅ |
| opera | 3DO | LGPL + nota FreeDO (proíbe comercial) | 🔴 |
| pd777 | Epoch Cassette Vision | MIT | ✅ |
| picodrive | Mega Drive / 32X / Pico | Não comercial | 🔴 |
| pocketcdg | Karaokê CD+G | MIT | ✅ |
| pokemini | Pokémon Mini | GPLv3 | ✅ |
| prboom | Doom | GPLv2 | ✅ (só com WADs livres, ex. Freedoom) |
| prosystem | Atari 7800 | GPLv2 | ✅ |
| puae | Amiga | GPL | ✅ (Kickstart não incluído; AROS é alternativa livre) |
| puae2021 | Amiga | GPL | ✅ |
| pzretro | PuzzleScript | MIT | ✅ |
| px68k | Sharp X68000 | GPL-2.0 (GitHub) / "Unknown" no package.mk | 🟡 confirmar origem do código Keropi |
| reminiscence | Flashback | GPLv3 | ✅ (dados do jogo não incluídos) |
| sameboy | Game Boy / Color | MIT | ✅ |
| sameduck | Mega Duck | MIT | ✅ |
| scummvm | Aventuras point-and-click | GPL | ✅ |
| snes9x | Super Nintendo | Não comercial | 🔴 |
| snes9x2002 | Super Nintendo | Não comercial | 🔴 |
| snes9x2005_plus | Super Nintendo | Não comercial | 🔴 |
| snes9x2010 | Super Nintendo | Não comercial | 🔴 |
| spring | Spring RTS | MIT | 🟡 confirmar |
| stella | Atari 2600 | GPLv2 | ✅ |
| supafaust | Super Nintendo | GPLv2 | ✅ |
| tgbdual | Game Boy (link) | GPLv2 | ✅ |
| theodore | Thomson MO/TO | GPL-3.0 | ✅ |
| tic-80 | TIC-80 | MIT | ✅ |
| tyrquake | Quake | GPLv2 | ✅ (dados do jogo não incluídos) |
| xrick | Rick Dangerous | GPLv3 | 🟡 o pacote de dados contém arte original (Core Design) |
| uae4arm | Amiga | GPL | ✅ |
| uzem | Uzebox | MIT | ✅ |
| vba-next | Game Boy Advance | GPLv2 | ✅ |
| vbam | Game Boy Advance | GPLv2 | ✅ |
| vecx | Vectrex | GPLv2/LGPLv2.1 | 🟡 BIOS do Vectrex embutida (liberada pelo detentor só para uso não comercial) |
| vice | Commodore 64/128/VIC-20/PET | GPLv2 | 🟡 ROMs da Commodore embutidas (direitos da Cloanto) |
| vircon32 | Vircon32 | BSD-3 | ✅ |
| virtualxt | IBM PC/XT | zlib (a confirmar; "?" no package.mk) | 🟡 |
| wasm4 | WASM-4 | ISC | ✅ |
| yabasanshiro | Sega Saturn | GPLv2 | ✅ |

#### Emuladores standalone e núcleos adicionais (`PKG_EMUS`)

| Pacote | Sistema | Licença | Situação |
|---|---|---|---|
| desmume | Nintendo DS | GPLv2 | ✅ |
| melonds | Nintendo DS | GPLv3 | ✅ |
| advancemame | Arcade | MAME antiga | 🔴 |
| PPSSPPSDL | PSP | GPL-2.0+ (package.mk diz "MAME" — erro) | ✅ |
| amiberry / amiberry-lite | Amiga | GPLv3 | ✅ |
| hatarisa | Atari ST | GPL | ✅ |
| openbor | Beat 'em up (motor) | BSD-3 | ✅ |
| dosbox-staging | MS-DOS | GPLv2 | ✅ |
| mupen64plus-nx / mupen64plus-nx-alt | Nintendo 64 | GPLv2 | ✅ |
| scummvmsa | ScummVM | GPL | ✅ |
| stellasa | Atari 2600 | GPL2 | ✅ |
| solarus | Motor Solarus | GPLv3 | ✅ (jogos/assets têm licenças próprias) |
| dosbox-pure | MS-DOS | GPLv2 | ✅ |
| ecwolf | Wolfenstein 3D | GPLv2 | 🟡 verificar arquivos com licença id Software |
| potator | Watara Supervision | Unlicense | ✅ |
| freej2me | Java ME | GPLv3 (+ ASM, BSD) | ✅ |
| duckstation | PlayStation | GPLv3 **na versão fixada** (commit de 21/07/2022) | 🟡 **nunca** atualizar para versões a partir de set/2024, que passaram a CC BY-NC-ND |
| flycastsa | Dreamcast | GPLv2 | ✅ |
| fmsx-libretro | MSX | Proprietária/não comercial | 🔴 |
| jzintv | Intellivision | "FOSS" no package.mk | 🟡 confirmar (GPL-2.0 nas versões recentes) |
| mupen64plussa (+ plugins) | Nintendo 64 | GPLv2 | ✅ |
| xroar | Dragon/CoCo | GPL-3.0+ | ✅ |
| x16 | Commander X16 | BSD-2 | ✅ |
| simcoupe | SAM Coupé | GPL | ✅ |
| ti99sim | TI-99/4A | GPL-3.0 | ✅ |
| oricutron | Oric | GPL-2.0 | 🟡 ROMs do Oric embutidas |
| eka2l1 | Symbian/N-Gage | GPL | ✅ |
| bigpemu | Atari Jaguar | Proprietária | 🔴 |
| biginstinct | Killer Instinct | Proprietária | 🔴 |
| memu | Memotech MTX | GPL | ✅ |
| ruffle | Flash | MIT/Apache-2.0 | ✅ |
| tsugaru | FM Towns | BSD-3 | ✅ |
| openmsx / openmsx-ld | MSX | GPL | ✅ (usa C-BIOS livre) |
| touchhle | iPhone OS | MPL-2.0 | ✅ |
| dreamm | LucasArts | Proprietária | 🔴 |
| basilisk2 | Macintosh 68k | GPL-2.0+ | ✅ |

#### Experimentais (`PKG_EXPERIMENTAL`, também entram na imagem)

| Pacote | Sistema | Licença | Situação |
|---|---|---|---|
| nestopiaCV | NES | GPLv2 | ✅ |
| quasi88 | NEC PC-8801 | BSD-3 | ✅ |
| xmil | Sharp X1 | "Unknown" (repositório de origem não encontrado) | 🟡 remover até esclarecer |
| np2kai | NEC PC-98 | MIT | ✅ |
| hypseus-singe | LaserDisc | GPL-3 | ✅ |
| yabasanshiroSA_1_11 / yabasanshiroSA_1_5 | Sega Saturn | GPLv2 | ✅ |
| fbneoSA | Arcade | Personalizada (não comercial) | 🔴 |
| same_cdi | Philips CD-i | GPL (MAME moderno; package.mk diz "MAME") | ✅ |
| ikemen-go | M.U.G.E.N | MIT | ✅ |

#### Exclusivos de aarch64 / Amlogic-ng

| Pacote | Sistema | Licença | Situação |
|---|---|---|---|
| beetle-saturn | Sega Saturn | GPLv2 | ✅ |
| mesen | NES | GPLv3 | ✅ |
| mesen-s | SNES/GB | GPLv3 | ✅ |
| virtualjaguar | Atari Jaguar | GPLv3 | ✅ |
| swanstation | PlayStation | GPLv3 | ✅ |
| dolphinSA | GameCube/Wii | GPLv2+ | ✅ |
| mame | Arcade (MAME atual) | GPL-2.0+ | ✅ |
| lib32-flycast, lib32-mupen64plus, lib32-pcsx_rearmed, lib32-parallel-n64, lib32-uae4arm | versões 32 bits | GPLv2/GPL | ✅ |
| lib32-bennugd-monolithic | Motor BennuGD | zlib | ✅ |
| lib32-droidports | Jogos Android | GPLv3 | 🟡 executa binários de jogos proprietários |
| lib32-box86 | Tradutor x86 | MIT | ✅ |

**Componentes principais:** RetroArch (GPLv3) ✅ · EmulationStation (base MIT, fork Batocera) ✅ · CoreELEC/LibreELEC (GPLv2+) ✅ · drivers e firmwares Amlogic/Wi-Fi (binários proprietários, redistribuíveis — conferir os termos de cada um).

### 3.4 No repositório, mas fora da imagem padrão

Não entram no build do Amlogic-ng hoje, mas é preciso cuidado caso alguém os habilite:

- **Núcleos não comerciais:** `duckstation-lr` (binário pronto, CC BY-NC-ND), `fbalpha`, `imame4all`, `mame2000`, `mame2003`, `mame2003-midway`, `mame2003-xtreme`, `snes9x2005`, `picodrivesa`.
- **Ports** ([packages/sx05re/emuelec-ports](../packages/sx05re/emuelec-ports/package.mk), pacote não ligado à imagem): `VVVVVV` (licença própria, proíbe uso comercial), `devilutionX`, `falloutce1` e `falloutce2` (Sustainable Use License — só uso não comercial), `sonic2013`, `soniccd`, `sonicmania` (licença da decompilação proíbe uso comercial), `eduke` (licença BUILD, não comercial), `shovelknight`, `celeste`, `tmntsr`, `ccleste`, `supermariowar` (dependem de dados ou de marcas de terceiros). Livres: `supertux`, `supertuxkart`, `opentyrian`, `sdlpop`, `chocolate-doom`, `gzdoom`/`lzdoom`, `fheroes2`, `cdogs-sdl`, `bstone`, `augustus`, `abuse`, `hurrican`, `xash3d` (motores — os dados dos jogos à parte).

---

## 4. Plano proposto em etapas

### Etapa 0 — Base de trabalho (≈ 1 semana)

1. Montar o ambiente (WSL2 Ubuntu 22.04 ou Docker), compilar a imagem original **sem alterações** e testar no Super Console X3 Plus (vídeo, áudio HDMI, controles, Wi-Fi/Bluetooth, DTB correto).
2. Criar a branch de produto (ex.: `produto`) a partir de `dev`; trazer o upstream periodicamente com `git fetch upstream && git merge upstream/dev`.
3. Decidir o nome comercial e trocar a marca: `DISTRONAME`, `GREETING*`, `DISTRO_BOOTLABEL` em [distributions/EmuELEC/options](../distributions/EmuELEC/options) (ou criar `distributions/<NossoNome>/`), splash em `packages/sx05re/emuelec/config/splash`, textos "EmuELEC" nos scripts. Trocar também a senha root padrão (`ROOT_PASSWORD="emuelec"`) e avaliar desligar SSH/Samba por padrão.
4. Revisão jurídica da lista da seção 3 (incluindo os itens 🟡).

### Etapa 1 — Limpeza de licenças (≈ 1–2 semanas)

1. Remover os itens 🔴 de `LIBRETRO_CORES` (distributions/…/options) e de `PKG_EMUS`/`PKG_EXPERIMENTAL` ([packages/sx05re/emuelec/package.mk](../packages/sx05re/emuelec/package.mk)).
2. Atualizar [es_systems.json](../packages/sx05re/emuelec-emulationstation/config/es_systems.json)/[generate_es_systems.py](../packages/sx05re/emuelec-emulationstation/generate_es_systems.py) para que o emulador **padrão** de cada sistema seja um liberado (SNES → Mesen-S/supafaust; Mega Drive → clownmdemu; Master System/GG → Gearsystem; Arcade → MAME/mame2016; Neo Geo → Geolith; MSX → blueMSX).
3. Remover sistemas sem alternativa (3DO, 32X, Pico, Palm, OutRun).
4. Matriz de desempenho no S905X3 (FPS e áudio) dos núcleos substitutos, principalmente SNES e arcade, que ficam mais pesados que os originais.
5. Gerar automaticamente um arquivo `LICENCAS.md`/tela "Sobre" com a licença de cada componente e o link do código-fonte (obrigação da GPL).

### Etapa 2 — Tema próprio em português com "Continuar jogando" (≈ 2–4 semanas)

1. **Português por padrão:** `system.language=pt_BR` no `emuelec.conf`; revisar a tradução `pt_BR` do ES (completar strings faltantes) e traduzir os textos dos scripts EmuELEC exibidos na tela (ex.: mensagens do `updatecheck.sh`).
2. **Tema próprio:** novo pacote `packages/sx05re/emuelec-emulationstation/themes/<nosso-tema>/` com arte 100% nossa (ou licenciada), compatível com o formato de temas do Batocera-ES; definir `ThemeSet` no `es_settings.cfg`; remover Crystal e Carbon da imagem.
3. **"Continuar jogando" — fase A (sem mexer no código do ES):** ativar por padrão a coleção automática `recent` ("últimos jogados", ordenada por `lastplayed`), exibi-la como **primeiro item** da tela inicial com o rótulo "Continuar jogando" no tema e usar a miniatura do save state como imagem.
4. **"Continuar jogando" — fase B (fork do ES):** fazer fork de `EmuELEC/emuelec-emulationstation` e apontar o `package.mk` para ele; implementar uma linha horizontal na tela inicial com os N últimos jogos **que têm save state automático** e retomar direto do ponto salvo ao apertar A.

### Etapa 3 — Salvamento automático ligado por padrão (≈ 1 semana)

1. No `emuelec.conf`: `global.autosave=1` (salva ao sair e carrega ao entrar).
2. Testar o fluxo completo ES → `emuelecRunEmu.sh` → `setsettings.sh` e confirmar que o arquivo `.state.auto` é gravado ao sair pelo atalho e carregado ao reabrir.
3. Desligar por sistema onde o save state não é confiável (ex.: `dos.autosave=0`, `scummvm.autosave=0`, arcade com MAME, se necessário).
4. Proteger saves de bateria contra desligamento na tomada (comum em TV box): definir `autosave_interval` (ex.: 10 s) no `retroarch.cfg` base, para gravar o `.srm` periodicamente.
5. Emuladores standalone (PPSSPP, Flycast SA, DuckStation SA, Mupen64Plus SA, Dolphin): configurar o salvamento automático de cada um, ou aceitar que só os núcleos RetroArch tenham "Continuar jogando" na primeira versão.

### Etapa 4 — Atualização pelo nosso servidor (≈ 1–2 semanas)

1. Trocar `UPDINFO`, `UPDURL` e `TEST_UPDURL` no [updatecheck.sh](../packages/sx05re/emuelec/bin/updatecheck.sh) para HTTPS nosso (ex.: GitHub Releases do fork para começar; depois CDN/armazenamento próprio). Ajustar o prefixo do arquivo (`UFILE`) à nova marca.
2. Publicar, por canal (`stable`/`beta`), um arquivo no formato do `EE_update` com `<versão>;…`.
3. **Assinatura digital:** gerar `.tar` + `.sha256` + `.sig` (ex.: minisign/Ed25519) e verificar a assinatura com uma chave pública gravada na imagem **antes** de liberar o reboot no `emuelec-upgrade`; recusar a atualização se a verificação falhar.
4. Pipeline de build e publicação (GitHub Actions com runner próprio ou máquina dedicada; o build é grande demais para os runners gratuitos).
5. Manter a checagem de compatibilidade de projeto/arquitetura do init.

### Etapa 5 — Proteção de saves e favoritos nas atualizações (≈ 1–2 semanas)

1. **Centralizar os dados do usuário** em `/storage/roms` (que nenhuma rotina apaga): `.srm` já fica lá; save states em `/storage/roms/savestates`; garantir que os `gamelist.xml` (favoritos/últimos jogados) sejam sempre gravados em `/storage/roms/<sistema>/` e mover as coleções personalizadas para lá (ou incluí-las no backup).
2. **Remover ou reescrever a limpeza da atualização forçada** (`forced_update` → `clearconfig EMUS`): a atualização nunca deve apagar `/storage`.
3. **Backup automático antes de cada atualização** (reaproveitar `ee_backup backup` do `emuelec-utils`), guardando os 3 últimos com data, e opção "Restaurar backup" no menu.
4. **Migração em vez de sobrescrita:** script de pós-atualização, por versão, que mescla novas opções padrão nos arquivos do usuário (`retroarch.cfg`, `emuelec.conf`, `es_settings.cfg`) sem perder as escolhas existentes.
5. **Teste automatizado de regressão:** aparelho com saves, states e favoritos conhecidos → atualizar N → N+1 → comparar hashes dos arquivos e conferir a lista de favoritos.

### Etapa 6 — Testes e lançamento

Canal beta interno (`updates.type=beta`), testes de campo com alguns aparelhos e, depois, a versão estável. Cada versão distribuída deve ter a tag correspondente publicada no fork (código-fonte GPL).

---

## 5. Riscos e pendências

- **Licenciamento:** a remoção dos 🔴 é obrigatória para venda; os 🟡 precisam de decisão jurídica (ROMs de sistema embutidas: vice, fuse, 81, cap32, vecx, oricutron; dados de jogos: nxengine, xrick, gw-libretro).
- **ROMs e BIOS comerciais:** nunca incluir jogos ou BIOS protegidos na imagem nem no cartão vendido.
- **Marcas registradas:** nomes e logotipos de consoles (Nintendo, SEGA, Sony…) no tema podem gerar problema de marca — avaliar nomes genéricos/descritivos.
- **Obrigações da GPL:** publicar o código-fonte exato de cada versão (o fork público no GitHub atende, desde que as tags acompanhem as versões vendidas), manter avisos de copyright e oferecer o fonte aos compradores.
- **Desempenho:** os substitutos de Snes9x/FBNeo/Genesis Plus GX são mais pesados; validar no S905X3 antes de fechar a lista.
- **Dependências externas:** o ES e os temas vêm de repositórios de terceiros fixados por commit; para controlar o produto, eles precisarão de fork próprio.
- **Segurança:** senha root padrão `emuelec`, SSH/Samba ligados e atualização sem assinatura — corrigir antes do lançamento.
- **Limitações desta análise:** nenhuma compilação nem teste em aparelho foi feito nesta etapa; licenças conferidas pelos `package.mk` e pelos arquivos de licença dos repositórios de origem em 14/11/2026 — podem mudar em versões futuras dos núcleos.
