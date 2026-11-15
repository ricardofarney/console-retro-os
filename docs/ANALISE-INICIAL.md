# Análise inicial — Console de Jogos Retrô (`console-retro-os`)

- **Data:** 14/11/2026, 12:51 (horário de Brasília)
- **Aparelho alvo:** KINHANK Super Console X2 Pro — Amlogic **S905X2** (família **g12a**), 2 GB de RAM, Wi-Fi, Bluetooth 5.0; o sistema de jogos roda pelo **cartão microSD**
- **Uso:** pessoal/doméstico — todos os emuladores do EmuELEC são mantidos, inclusive os de licença não comercial
- **Base analisada:** fork de [EmuELEC/EmuELEC](https://github.com/EmuELEC/EmuELEC), branch `dev` (último commit do upstream: `d4c7b2f143`, 15/10/2026)
- **Escopo:** somente leitura. Nenhum código foi alterado nesta etapa.

> Esta versão substitui a análise anterior (feita para o S905X3 com foco comercial), que continua no histórico do Git (commit `df42c96`).

---

## Sumário

1. [Ambiente de compilação](#1-ambiente-de-compilação)
2. [Como compilar a imagem para o S905X2 e qual DTB usar](#2-como-compilar-a-imagem-para-o-s905x2-e-qual-dtb-usar)
3. [Onde fica cada peça e como alterar](#3-onde-fica-cada-peça-e-como-alterar)
4. [Backup completo do cartão original no Windows](#4-backup-completo-do-cartão-original-no-windows)
5. [Migrar a pasta roms do cartão original](#5-migrar-a-pasta-roms-do-cartão-original)
6. [Plano da Fase 1](#6-plano-da-fase-1)
7. [Pendências e riscos](#7-pendências-e-riscos)

---

## 1. Ambiente de compilação

### 1.1 Resultado da verificação neste PC (14/11/2026)

| Item | Situação |
|---|---|
| Processador | AMD Ryzen 7 5700X — 8 núcleos / 16 threads ✅ |
| Memória RAM | 32 GB ✅ |
| Disco `D:` | 436 GB livres ✅ (o build precisa de 150–250 GB) |
| Disco `C:` | 505 GB livres ✅ |
| WSL | WSL 2.7.11 instalado, **nenhuma distribuição Linux** ❌ |
| Virtualização | **desligada** ❌ — o Windows informa "virtualização não habilitada" (`HCS_E_HYPERV_NOT_INSTALLED`); o firmware (BIOS) reporta virtualização desativada |
| Docker | Docker Desktop instalado, mas o motor **não sobe** ❌ (depende da mesma virtualização) |

**Conclusão:** o PC tem hardware de sobra; o único bloqueio é a virtualização. Enquanto ela estiver desligada, nem WSL2 nem Docker funcionam.

### 1.2 O que precisa ser feito (com administrador)

1. **Ligar a virtualização na BIOS/UEFI** (não é um comando): reiniciar o PC, entrar no setup (geralmente tecla `Del` ou `F2`) e ativar **SVM Mode** (AMD-V), normalmente em *Advanced → CPU Configuration*. Salvar e reiniciar.
2. **Habilitar a "Plataforma de Máquina Virtual" do Windows** — no PowerShell **como administrador**:

   ```powershell
   wsl.exe --install --no-distribution
   ```

   Depois, reiniciar o Windows.
3. **Instalar o Ubuntu 22.04 com o disco dentro da pasta do projeto** (não exige administrador; o Claude Code faz):

   ```powershell
   wsl --install -d Ubuntu-22.04 --location "D:\Adube Sistemas\Console de Jogo\wsl\Ubuntu-22.04"
   ```

4. Limitar os recursos do WSL criando `%UserProfile%\.wslconfig`:

   ```ini
   [wsl2]
   memory=24GB
   swap=32GB
   processors=14
   ```

### 1.3 Estimativa de tempo e onde compilar

- **Primeiro build no PC (Ryzen 7 5700X, 32 GB, SSD):** estimativa de **6 a 10 horas**, mais o download de 20–40 GB de código-fonte (depende da internet). Os pacotes mais demorados são MAME, Dolphin, RetroArch, o kernel e o toolchain.
- **Builds seguintes:** de **10 a 60 minutos**, porque só os pacotes alterados são recompilados (e o ccache acelera).
- **Recomendação: compilar no seu PC.** Ele é forte o suficiente, não tem custo por hora e guarda o cache entre builds (o que mais economiza tempo). Um servidor Linux na nuvem (16 vCPUs, 32–64 GB de RAM, 250 GB de SSD) só compensa se não for possível ligar a virtualização na BIOS: o primeiro build levaria um tempo parecido, e a máquina teria de ficar ligada (e paga) para manter o cache.

### 1.4 Cuidados no WSL

- Compilar **dentro do Linux** (área de compilação `~/arcadia-build`, sincronizada a partir do repositório da pasta do projeto — ver [AMBIENTE-BUILD.md](AMBIENTE-BUILD.md)), nunca em `/mnt/d/...`: o NTFS montado é lento, não diferencia maiúsculas/minúsculas e não guarda permissões Unix.
- A cópia em `D:\Adube Sistemas\Console de Jogo\console-retro-os` foi clonada pelo Git do Windows com `core.autocrlf=true`, então os scripts estão com finais de linha CRLF. **Ela serve para documentação e edição, não para compilar.** O build usa um clone separado dentro do WSL.

---

## 2. Como compilar a imagem para o S905X2 e qual DTB usar

### 2.1 DEVICE correto

O S905X2 (g12a) é atendido pelo device **`Amlogic-ng`** do projeto `Amlogic-ce` ([projects/Amlogic-ce/devices/Amlogic-ng/options](../projects/Amlogic-ce/devices/Amlogic-ng/options): kernel `amlogic-4.9`, `TARGET_CPU="cortex-a53"`). O `Amlogic-ng` também recebe os núcleos mais pesados (`LIBRETRO_S922X_CORES`), que o próprio código comenta como destinados a "S922x, **S905x2** e A311D" ([packages/sx05re/emuelec/package.mk](../packages/sx05re/emuelec/package.mk), linhas 19–22).

### 2.2 Dependências (Ubuntu 22.04)

```bash
sudo apt update
sudo apt install gcc make git unzip wget xz-utils libsdl2-dev libsdl2-mixer-dev libfreeimage-dev libfreetype6-dev libcurl4-openssl-dev rapidjson-dev libasound2-dev libgl1-mesa-dev build-essential libboost-all-dev cmake fonts-droid-fallback libvlc-dev libvlccore-dev vlc-bin texinfo premake4 golang libssl-dev curl patchelf xmlstarlet default-jre xsltproc libvpx-dev rdfind tzdata xfonts-utils lzop
```

### 2.3 Comando exato de build

```bash
git clone "/mnt/d/Adube Sistemas/Console de Jogo/console-retro-os" ~/arcadia-build
cd ~/arcadia-build
git checkout dev
PROJECT=Amlogic-ce DEVICE=Amlogic-ng ARCH=aarch64 DISTRO=EmuELEC make image
```

Na prática, use o script [ferramentas/wsl/compilar.ps1](../ferramentas/wsl/compilar.ps1), que faz a sincronização, o build e a cópia das imagens para `D:\Adube Sistemas\Console de Jogo\imagens-compiladas` (ver [AMBIENTE-BUILD.md](AMBIENTE-BUILD.md)).

Resultado em `target/` (copiado para `imagens-compiladas\`):

- `Arcadia-Amlogic-ng.aarch64-<versão>-Generic.img.gz` → gravar no microSD (balenaEtcher ou Rufus);
- `Arcadia-Amlogic-ng.aarch64-<versão>.tar` → pacote de atualização.

Recompilar só um pacote: `PROJECT=Amlogic-ce DEVICE=Amlogic-ng ARCH=aarch64 DISTRO=EmuELEC ./scripts/clean <pacote>` e, em seguida, o mesmo `make image`.

Alternativa via Docker (depois de ligar a virtualização): `docker build --pull -t console-retro-build tools/docker/jammy` e `docker run --rm -v "$PWD":/build -w /build -e PROJECT=Amlogic-ce -e DEVICE=Amlogic-ng -e ARCH=aarch64 -e DISTRO=EmuELEC -it console-retro-build make image` (ver [tools/docker/README.md](../tools/docker/README.md)).

### 2.4 DTB do Super Console X2 Pro

O DTB ("device tree") diz ao kernel como é a placa. Ele fica na partição de boot do cartão (`EMUELEC`, FAT32) com o nome **`dtb.img`**.

- **Candidato:** `g12a_s905x2_2g.dtb` (S905X2 com 2 GB de RAM e Ethernet 100 Mbit). Se a Ethernet do aparelho for gigabit, `g12a_s905x2_2g_1gbit.dtb`. Os genéricos vêm do kernel do CoreELEC, na pasta `device_trees/` da partição de boot da imagem gerada; o arquivo [projects/Amlogic-ce/devices/Amlogic-ng/bootloader/dtb.conf](../projects/Amlogic-ce/devices/Amlogic-ng/bootloader/dtb.conf) só lista variantes de outras marcas (Beelink).
- **Forma mais segura (recomendada):** o cartão original do X2 Pro já tem um `dtb.img` que funciona. Antes de qualquer coisa, copiar esse arquivo (seção 4.1), calcular o hash e comparar com os DTBs de `device_trees/` da nossa imagem para descobrir qual é. Na nossa imagem, usar exatamente esse arquivo como `dtb.img`.
- Quando o DTB estiver confirmado, ele será fixado no build para que todo cartão novo já saia pronto.

---

## 3. Onde fica cada peça e como alterar

Regra geral do EmuELEC: tudo o que vem na imagem fica em `/usr/config/...` (somente leitura) e é **copiado para `/storage/...` no primeiro boot**. Mudar um padrão no código só vale para **cartões novos**; num cartão já em uso, vale o arquivo em `/storage`.

### 3.1 EmulationStation e temas

| O quê | Onde |
|---|---|
| Receita do ES | [packages/sx05re/emuelec-emulationstation/package.mk](../packages/sx05re/emuelec-emulationstation/package.mk) — código-fonte externo: [EmuELEC/emuelec-emulationstation](https://github.com/EmuELEC/emuelec-emulationstation), branch `EmuELEC`, fixado no commit `3de652c6` |
| Configuração padrão | [packages/sx05re/emuelec-emulationstation/config/es_settings.cfg](../packages/sx05re/emuelec-emulationstation/config/es_settings.cfg) — `ThemeSet=Crystal`, `FavoritesFirst=true` |
| Sistemas e emuladores | [config/es_systems.json](../packages/sx05re/emuelec-emulationstation/config/es_systems.json) e [generate_es_systems.py](../packages/sx05re/emuelec-emulationstation/generate_es_systems.py) |
| Temas | [themes/Crystal/package.mk](../packages/sx05re/emuelec-emulationstation/themes/Crystal/package.mk) (padrão, fonte `github.com/dm2912/Crystal`) e [themes/es-theme-EmuELEC-carbon/package.mk](../packages/sx05re/emuelec-emulationstation/themes/es-theme-EmuELEC-carbon/package.mk) |
| Temas no aparelho | sistema: `/usr/config/emulationstation/themes/`; usuário: `/storage/.config/emulationstation/themes/` (ou a pasta `themes` na partição EEROMS) |

**Como alterar o tema:** criar um repositório próprio do tema (ex.: fork do Crystal ou do Carbon — permitido em uso pessoal), criar `packages/sx05re/emuelec-emulationstation/themes/<nosso-tema>/package.mk` apontando para ele, incluí-lo em `PKG_DEPENDS_TARGET` do ES e trocar `ThemeSet` no `es_settings.cfg`.

### 3.2 Idioma padrão — português do Brasil

- [packages/sx05re/emuelec/config/emuelec/configs/emuelec.conf](../packages/sx05re/emuelec/config/emuelec/configs/emuelec.conf), linha 154: `system.language=en_US` → **`system.language=pt_BR`**. O ES mapeia `system.language` para a configuração interna `Language` (`es-core/src/SystemConf.cpp`), e o [setsettings.sh](../packages/sx05re/emuelec/bin/setsettings.sh) (linha 80 em diante) usa o mesmo valor para o idioma do RetroArch.
- A tradução `pt_BR` do ES já existe (`locale/lang/pt_BR` no repositório do ES).
- Linha 157 do mesmo arquivo: `system.timezone=America/Mexico_City` → **`system.timezone=America/Sao_Paulo`** (horário de Brasília).
- Num aparelho já em uso: *Menu → Configurações do sistema → Idioma*, ou editar `/storage/.config/emuelec/configs/emuelec.conf`.

### 3.3 Salvamento e carregamento automático (RetroArch)

Como funciona hoje:

1. O `retroarch.cfg` base é gerado em [packages/sx05re/libretro_base/retroarch/package.mk](../packages/sx05re/libretro_base/retroarch/package.mk) (linhas ~101–160, série de `sed`), vai para `/usr/config/retroarch/retroarch.cfg` e é copiado para `/storage/.config/retroarch/retroarch.cfg`.
2. **A cada jogo iniciado**, o [setsettings.sh](../packages/sx05re/emuelec/bin/setsettings.sh) reescreve as opções:
   - linhas 116–126: `savestate_directory = /storage/roms/savestates/<sistema>`;
   - linhas 141–142 (`default_settings`): **`savestate_auto_save = "false"` e `savestate_auto_load = "false"`**;
   - linhas 195–215: se o autosave estiver ligado para aquele jogo, grava `"true"` nos dois.
3. O ES decide o "ligado" em `FileData::getCurrentGameSetting("autosave")`, nesta ordem: configuração do jogo → `<sistema>.autosave` → **`global.autosave`** (do `emuelec.conf`). Só repassa para sistemas com suporte a save state (`SaveStateRepository::isEnabled`).

Por isso, **editar só o `retroarch.cfg` não adianta**: o `setsettings.sh` sobrescreve o valor a cada jogo.

**Como ligar em todos os sistemas por padrão:**

1. `emuelec.conf` (linhas 193–194): trocar `#global.autosave=0` por **`global.autosave=1`**;
2. no `setsettings.sh`, função `default_settings` (linhas 141–142): trocar os dois padrões para `"true"`, para cobrir também os sistemas para os quais o ES não envia a opção;
3. opcional, recomendado: incluir `autosave_interval = "10"` no `retroarch.cfg` base para gravar o save de bateria (`.srm`) a cada 10 s, protegendo contra desligamento na tomada.

Onde ficam os arquivos: save states em `/storage/roms/savestates/<sistema>/`; saves de bateria (`.srm`) ao lado da ROM, em `/storage/roms/<sistema>/` (o `savefile_directory` fica comentado). Emuladores **standalone** (PPSSPP, Flycast SA, DuckStation SA, Mupen64Plus SA, Dolphin, AdvanceMAME…) não usam essas opções do RetroArch.

### 3.4 Favoritos

- Cada jogo favorito fica marcado no **`gamelist.xml`** do sistema (`<favorite>true</favorite>`), junto com `lastplayed` (último jogo) e `playcount`.
- Caminho (`SystemData::getGamelistPath` no fonte do ES): primeiro `/storage/roms/<sistema>/gamelist.xml`; se não existir, `~/.emulationstation/gamelists/<sistema>/gamelist.xml`.
- A coleção automática **`favorites`** junta os favoritos de todos os sistemas. `FavoritesFirst=true` já está ligado no `es_settings.cfg` (favoritos no topo de cada lista).

### 3.5 Coleção "jogados recentemente" (base da linha "Continuar jogando")

- O ES tem a coleção automática **`recent`** ("last played", ordenada por `lastplayed`) — definida em `es-app/src/CollectionSystemManager.cpp`.
- Quais coleções aparecem é controlado pela configuração **`CollectionSystemsAuto`**. Padrão do ES (`es-core/src/Settings.cpp`, linha 301): `"all,favorites"` — ou seja, **`recent` vem desligada**.
- **Como ligar:** acrescentar ao `es_settings.cfg` padrão:

  ```xml
  <string name="CollectionSystemsAuto" value="recent,favorites,all" />
  ```

- **Como chamar de "Continuar jogando":** a pasta `recent` do tema pode mostrar um logotipo/texto "Continuar jogando" (sem mexer no código do ES). Para trocar o nome no código, basta alterar a tradução de "last played" no `pt_BR` do ES (exige fork do ES).

### 3.6 Mecanismo de atualização

| Etapa | Arquivo | Detalhe |
|---|---|---|
| Consulta de versão | [packages/sx05re/emuelec/bin/updatecheck.sh](../packages/sx05re/emuelec/bin/updatecheck.sh), linha 8 | `UPDINFO="https://raw.githubusercontent.com/EmuELEC/emuelec.github.io/master/settings/EE_update"` — arquivo de texto; cada linha tem a versão no primeiro campo (separado por `;`) e o canal (`stable`/`beta`) |
| Download | linhas 9–10 e 112–124 | estável: `https://github.com/EmuELEC/EmuELEC/releases/download/v<versão>/EmuELEC-Amlogic-ng.aarch64-<versão>.tar`; beta: repositório `EmuELEC-tests` |
| Comparação | linhas 135–171 | versão do servidor × `/usr/config/EE_VERSION` |
| Baixar e conferir | [packages/sx05re/emuelec/bin/batocera/emuelec-upgrade](../packages/sx05re/emuelec/bin/batocera/emuelec-upgrade) | grava em `/storage/.update` (montado sobre `/storage/roms/.update`); confere `.sha256` só se existir |
| Aplicar | [packages/sysutils/busybox/scripts/init](../packages/sysutils/busybox/scripts/init) | no boot seguinte, troca `KERNEL`/`SYSTEM` na partição de boot; não mexe em `/storage` |
| Configuração | `emuelec.conf`, linhas 159–163 | `updates.enabled=1`, `updates.type=stable` |

**Como trocar pelo nosso servidor** (sugestão simples: GitHub do próprio fork):

1. No `updatecheck.sh`: `UPDINFO="https://raw.githubusercontent.com/ricardofarney/console-retro-os/<branch>/atualizacao/EE_update"` e `UPDURL="https://github.com/ricardofarney/console-retro-os/releases/download/v"` (e `TEST_UPDURL` para o canal beta).
2. Criar o arquivo `atualizacao/EE_update` no mesmo formato.
3. A cada versão, publicar uma release `v<versão>` com o `.tar` e o `.sha256`, usando o nome que o script espera (`EmuELEC-Amlogic-ng.aarch64-<versão>.tar`, ou ajustar `UFILE` na linha 112).

⚠️ **Atenção:** a opção "atualização forçada" (`updatecheck.sh forceupdate`) chama `emuelec-utils clearconfig EMUS` ([emuelec-utils](../packages/sx05re/emuelec/bin/emuelec-utils), linhas 131–140), que faz backup em `/storage/roms/backup/` e depois **apaga quase todo o `/storage`**, menos `roms`, temas e alguns caches. Nas nossas versões, essa limpeza deve ser removida (ver Fase 1, etapa 6).

### 3.7 Usuário e senha do acesso de rede

| Acesso | Padrão | Onde está | Como trocar |
|---|---|---|---|
| **SSH** | usuário `root`, senha **`emuelec`**; ligado por padrão (`ee_ssh.enabled=1`, `emuelec.conf` linha 3) | `ROOT_PASSWORD="emuelec"` em [distributions/EmuELEC/options](../distributions/EmuELEC/options), linha 20 | **No build:** trocar `ROOT_PASSWORD`. **No aparelho:** entrar por SSH e rodar `passwd`; a nova senha fica em `/storage/.cache/shadow` e é preservada nas atualizações ([usercache-setup](../packages/sysutils/systemd/scripts/usercache-setup)). Para desligar o SSH: `ee_ssh.enabled=0` |
| **Samba** (pastas de rede `\\EMUELEC\ROMS` etc.) | **sem senha** (`SAMBA_SECURE="false"`; usuário/senha de reserva `coreelec`/`coreelec`); convidado = `root` | [packages/network/samba/default.d/samba.conf](../packages/network/samba/default.d/samba.conf) e compartilhamentos em [packages/network/samba/config/smb.conf](../packages/network/samba/config/smb.conf) | **No build:** `SAMBA_SECURE="true"`, `SAMBA_USERNAME`, `SAMBA_PASSWORD`. **No aparelho:** editar `/storage/.cache/services/samba.conf` com os mesmos campos e reiniciar |
| Nome na rede | `EMUELEC` | `system.hostname` no `emuelec.conf` (linha 118) | trocar o valor (ex.: `CONSOLE-RETRO`) |

---

## 4. Backup completo do cartão original no Windows

Fazer **antes de qualquer alteração**, e guardar o cartão original intacto (os testes devem ser feitos num microSD novo).

### 4.1 Preparação

1. Desligar o aparelho, retirar o microSD e colocá-lo num leitor USB no PC. Se o adaptador tiver trava de gravação, deixe-a em **LOCK**.
2. ⚠️ O Windows não lê partições Linux (ext4) e pode oferecer **"Formatar o disco"** — clique sempre em **Cancelar**.
3. Na partição FAT32 que aparece (rótulo `EMUELEC`), **copiar todos os arquivos** para `D:\Adube Sistemas\Console de Jogo\backups\cartao-original\boot\` — principalmente `dtb.img` (o DTB que funciona no X2 Pro) e o arquivo `ee_fstype`, se existir (indica o formato da partição de roms).

### 4.2 Imagem inteira do cartão

**Opção A — Win32 Disk Imager** (gratuito):

1. Executar como administrador.
2. Em *Device*, escolher a letra do cartão (confira o tamanho!).
3. Em *Image File*, informar `D:\Adube Sistemas\Console de Jogo\backups\cartao-original\x2pro-original-AAAA-MM-DD.img`.
4. **Desmarcar** "Read Only Allocated Partitions" (para copiar o cartão inteiro) e marcar o hash **SHA256**.
5. Clicar em **Read** e aguardar (cartão de 64 GB → arquivo de 64 GB; pode levar de 30 a 60 minutos).
6. Ao final, clicar em **Verify Only** para conferir a imagem com o cartão.

**Opção B — Rufus:** selecionar o cartão e usar o botão de salvar ao lado da lista de dispositivos ("salvar como imagem VHD/VHDX").

Depois: compactar com 7-Zip (as áreas vazias encolhem bastante) e guardar uma segunda cópia em outro disco. Para restaurar: Win32 Disk Imager → selecionar o `.img` → **Write** num cartão do mesmo tamanho ou maior.

---

## 5. Migrar a pasta roms do cartão original

### 5.1 Como as roms ficam guardadas

Em cartões maiores que 8 GB, o EmuELEC cria no primeiro boot uma **terceira partição chamada `EEROMS`** ([packages/sysutils/busybox/scripts/fs-resize](../packages/sysutils/busybox/scripts/fs-resize), linhas 61–140) e a monta diretamente como `/storage/roms` ([init](../packages/sysutils/busybox/scripts/init), linhas 715–751). O formato é definido pelo arquivo `ee_fstype` da partição de boot: **FAT32 (padrão)**, exFAT, NTFS ou ext4. Ou seja, na raiz da `EEROMS` estão diretamente as pastas `nes/`, `snes/`, `psx/`, `bios/`, `savestates/`… (o EmuELEC cria mais de 130 pastas — ver [emuelec-dirs.conf](../packages/sx05re/emuelec/tmpfiles.d/emuelec-dirs.conf)).

### 5.2 Copiar do cartão original

- **Se a `EEROMS` for FAT32, exFAT ou NTFS** (o Windows mostra a unidade): copiar **todo o conteúdo** para `D:\Adube Sistemas\Console de Jogo\backups\roms-original\`, incluindo arquivos ocultos. Ex. no PowerShell: `robocopy E:\ "D:\Adube Sistemas\Console de Jogo\backups\roms-original" /E /COPY:DAT /R:1 /W:1` (trocar `E:` pela letra da unidade).
- **Se for ext4** (o Windows não mostra): copiar pela rede com o aparelho ligado, pelo compartilhamento `\\EMUELEC\ROMS`, ou ler o cartão com uma ferramenta somente leitura de ext4 (ex.: DiskInternals Linux Reader). Com o WSL2 funcionando, também dá para usar `wsl --mount`.

Junto com as roms vêm: `bios/`, os saves `.srm` (ao lado das roms), `savestates/`, os `gamelist.xml` (favoritos e "último jogado") e as pastas de imagens/vídeos do scraper.

### 5.3 Colocar no nosso sistema

1. Gravar a nossa imagem num **microSD novo** (nunca no original).
2. Ligar o aparelho uma vez e esperar o primeiro boot terminar: ele cria a partição `EEROMS` com a estrutura padrão de pastas.
3. Desligar, colocar o cartão no PC e copiar as pastas do backup para a `EEROMS`, **mantendo os mesmos nomes** (`robocopy "D:\...\roms-original" F:\ /E`).
4. Conferir nomes de pastas que mudaram entre a versão do EmuELEC do cartão original e a nossa (comparar com o `emuelec-dirs.conf`); renomear o que for diferente.
5. Ligar o aparelho; se faltar algum jogo, usar *Menu → Atualizar listas de jogos*.

---

## 6. Plano da Fase 1

Objetivo: tema próprio em português, salvamento automático ligado de fábrica, linha "Continuar jogando" e favoritos na tela inicial.

| # | Etapa | O que muda | Como validar |
|---|---|---|---|
| 0 | **Preparar o ambiente** | Ligar SVM na BIOS e a Plataforma de Máquina Virtual (seção 1.2); instalar o Ubuntu 22.04 no WSL; clonar o fork no WSL | `wsl -l -v` mostra o Ubuntu rodando em WSL2 |
| 1 | **Backup do cartão original** | Seção 4 (imagem inteira + `dtb.img`) e seção 5.2 (roms) | Imagem verificada com SHA256; roms copiadas |
| 2 | **Build original sem alterações** | `make image` (seção 2.3); usar o `dtb.img` do cartão original | Aparelho liga com o nosso build: vídeo, som, controles, Wi-Fi e Bluetooth funcionando |
| 3 | **Português e fuso de Brasília** | `emuelec.conf`: `system.language=pt_BR`, `system.timezone=America/Sao_Paulo`; `es_settings.cfg`: `Language=pt_BR` | Menus em português e hora certa no primeiro boot |
| 4 | **Salvamento automático de fábrica** | `emuelec.conf`: `global.autosave=1`; `setsettings.sh` linhas 141–142 → `"true"`; `retroarch.cfg` base: `autosave_interval = "10"` | Jogar, sair e reabrir → volta no mesmo ponto; existe o `.state.auto` em `/storage/roms/savestates/<sistema>/` |
| 5 | **Tema próprio + "Continuar jogando" + favoritos** | Repositório do nosso tema (fork do Crystal ou Carbon), traduzido, com identidade visual própria e telas `recent` ("Continuar jogando") e `favorites` ("Favoritos"); novo `package.mk` do tema; `es_settings.cfg`: `ThemeSet=<nosso-tema>` e `CollectionSystemsAuto=recent,favorites,all`, com "Continuar jogando" e "Favoritos" como primeiros itens da tela inicial | Tela inicial abre em "Continuar jogando", seguida de "Favoritos"; ao jogar algo, ele aparece no topo de "Continuar jogando" |
| 6 | **Proteção de saves e favoritos** | Remover a limpeza `clearconfig EMUS` da atualização forçada; garantir `gamelist.xml` sempre em `/storage/roms/<sistema>/` | Atualizar uma versão para outra sem perder saves nem favoritos |
| 7 | **Atualização pelo nosso servidor** (opcional na Fase 1) | URLs do `updatecheck.sh` apontando para o GitHub do fork (seção 3.6) | O menu "Atualizar" encontra e instala a nossa release |
| 8 | **Migrar roms e testar no dia a dia** | Seção 5.3 | Jogos, saves e favoritos do cartão original funcionando no nosso sistema |

Evolução prevista para depois da Fase 1: uma linha horizontal de verdade na tela inicial, com os últimos jogos e a miniatura do save (exige fork do código do ES).

---

## 7. Pendências e riscos

- **Bloqueio atual:** virtualização desligada — sem ela não há build (seção 1.2).
- **DTB:** confirmar com o `dtb.img` do cartão original antes do primeiro teste; DTB errado pode deixar o aparelho sem vídeo, Wi-Fi ou Bluetooth (sem danificar nada — basta trocar o arquivo).
- **2 GB de RAM:** sistemas pesados (GameCube/Wii, Saturn, PSP, N64 em alguns jogos) podem rodar mal no S905X2; isso é limitação do hardware, não do build.
- **Segurança da rede doméstica:** SSH com senha conhecida (`emuelec`) e Samba sem senha — trocar ao menos a senha root (seção 3.7).
- **Wi-Fi e Bluetooth do X2 Pro:** o chip exato precisa ser confirmado no aparelho; a lista `ADDITIONAL_DRIVERS` em [distributions/EmuELEC/options](../distributions/EmuELEC/options) já inclui os drivers mais comuns em TV boxes Amlogic.
- **Dependências externas:** o ES e os temas vêm de repositórios de terceiros fixados por commit; para personalizações maiores, eles precisarão de fork próprio.
- **Limitações desta análise:** nenhuma compilação nem teste no aparelho foi feito; os nomes dos DTBs genéricos do S905X2 precisam ser confirmados na pasta `device_trees/` do primeiro build.
