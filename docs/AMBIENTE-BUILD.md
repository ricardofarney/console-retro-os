# Ambiente de build — WSL2 no PC de desenvolvimento

Montado em 14/11/2026 (horário de Brasília). Scripts em [ferramentas/wsl/](../ferramentas/wsl). O fluxo geral do projeto está resumido em [PROJETO.md](PROJETO.md#fluxo-de-compilação).

## O que foi feito

| Passo | Como | Quem |
|---|---|---|
| Virtualização | BIOS ASUS TUF GAMING B550M-PLUS WIFI II: *Advanced → CPU Configuration → SVM Mode = Enabled* | usuário |
| Plataforma de Máquina Virtual | `wsl.exe --install --no-distribution` (PowerShell como administrador) + reinício | usuário |
| Ubuntu 22.04 (WSL2) | `wsl --install -d Ubuntu-22.04 --location "D:\Adube Sistemas\Console de Jogo\wsl\Ubuntu-22.04" --no-launch` | Claude Code |
| Limites do WSL | `%UserProfile%\.wslconfig`: 24 GB de RAM, 14 CPUs, swap de 32 GB em `D:\Adube Sistemas\Console de Jogo\wsl\swap.vhdx` | Claude Code |
| Usuário e dependências | [preparar-wsl.sh](../ferramentas/wsl/preparar-wsl.sh): usuário `console` (sem senha, `sudo` liberado; definir senha com `sudo passwd console`), `systemd`, fuso America/Sao_Paulo, locales en_US/pt_BR e todos os pacotes de build | Claude Code |
| Área de compilação | `~/arcadia-build` dentro do Ubuntu, com `origin` apontando para o repositório da pasta do projeto | Claude Code |

Observações:

- O WSL avisa *"Falha ao configurar a rede (networkingMode Nat), voltando para networkingMode VirtioProxy"*. A internet funciona normalmente nesse modo (testado com GitHub); o aviso pode ser ignorado.
- Com `systemd` ligado, o Ubuntu não consegue executar programas do Windows (`.exe`). Por isso, a verificação de alterações não commitadas é feita pelo `compilar.ps1`, no Windows.

## Fluxo

```
D:\Adube Sistemas\Console de Jogo\console-retro-os   (repositório oficial — editar e commitar aqui)
        │  git fetch + reset (somente commits da branch dev)
        ▼
~/arcadia-build   (Ubuntu/WSL — apenas área de compilação; não editar)
        │  make image
        ▼
D:\Adube Sistemas\Console de Jogo\imagens-compiladas   (.img.gz, .tar, .sha256 + logs\)
```

- Alterações **não commitadas** não entram no build (o script avisa no log).
- O cache de compilação fica em `~/.ccache-arcadia`, fora da pasta de build, para acelerar os próximos builds mesmo após limpezas.

## Como compilar

No PowerShell normal (sem administrador):

```powershell
Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','"D:\Adube Sistemas\Console de Jogo\console-retro-os\ferramentas\wsl\compilar.ps1"'
```

- [compilar.ps1](../ferramentas/wsl/compilar.ps1) roda o build num processo próprio (continua mesmo fechando o terminal ou o Claude), **impede o Windows de suspender** até terminar e avisa o build se houver alterações não commitadas.
- [compilar.sh](../ferramentas/wsl/compilar.sh) sincroniza `~/arcadia-build` com o repositório do projeto, **baixa antes as fontes de todos os pacotes** (`tools/download-tool --all`; se algum link estiver quebrado, para e lista todos em `imagens-compiladas\logs\fontes-com-falha.txt`), executa `PROJECT=Amlogic-ce DEVICE=Amlogic-ng ARCH=aarch64 DISTRO=EmuELEC make image` e:
  - grava o log em `~/arcadia-logs/build-AAAA-MM-DD_HHMM.log`;
  - grava a situação (`EM ANDAMENTO`, `OK` ou `FALHOU`) em `~/arcadia-logs/status.txt`;
  - copia log e situação para `D:\Adube Sistemas\Console de Jogo\imagens-compiladas\logs\`;
  - em caso de sucesso, copia `.img.gz`, `.tar` e `.sha256` para `D:\Adube Sistemas\Console de Jogo\imagens-compiladas\`.

## Acompanhar o build

Situação (também em `imagens-compiladas\logs\status.txt`):

```powershell
wsl -d Ubuntu-22.04 -- cat /home/console/arcadia-logs/status.txt
```

Últimas linhas do log:

```powershell
wsl -d Ubuntu-22.04 -- bash -c 'tail -n 3 $(ls -t ~/arcadia-logs/build-*.log | head -1)'
```

A linha `[NNN/689] [DONE] build <pacote>` mostra o avanço (689 etapas no primeiro build).

## Espaço em disco

O disco virtual do Ubuntu (`D:\Adube Sistemas\Console de Jogo\wsl\Ubuntu-22.04\ext4.vhdx`) cresce conforme o uso — espere 150–250 GB após o primeiro build. Ele não encolhe sozinho ao apagar arquivos; para recuperar espaço: `wsl --shutdown` e compactar o VHDX (`Optimize-VHD` ou `diskpart` → `compact vdisk`).

## Correções necessárias para o build funcionar (14/11/2026)

O EmuELEC de 15/10/2026 tinha links de código-fonte quebrados. Cada fonte trocada foi conferida (mesmo SHA-256, ou versão oficial equivalente quando o arquivo original sumiu de todos os espelhos).

| Pacote | Problema | Correção | Commit |
|---|---|---|---|
| `xz` 5.4.1 | `tukaani.org` responde 403; espelhos CoreELEC/LibreELEC não têm | GitHub oficial `tukaani-project/xz` (mesmo SHA-256) | `e4c25a6` |
| `u-boot-tools` 2016.03 | `ftp.denx.de` fora do ar (FTP, HTTP e HTTPS) | espelho do OpenWrt (mesmo SHA-256) | `6d111ae` |
| `ecwolf` | submódulos SDL/SDL_mixer/SDL_net no Bitbucket (removido; o git ficava **horas** parado pedindo senha) | `compilar.sh` redireciona `bitbucket.org/ecwolf/` → `github.com/ECWolfEngine/` e define `GIT_TERMINAL_PROMPT=0` | `6d111ae` |
| `evtest` 1.35 | `repo.or.cz` passou a exigir verificação anti-robô (entregava HTML) | GitLab oficial do freedesktop.org (mesma versão; novo SHA-256 e `PKG_SOURCE_DIR`) | `4152e6a` |
| `portaudio` (dependência do `hatarisa`) | fork `zhang-ray/portaudio` apagado; o commit não existe no projeto oficial | PortAudio oficial **v19.7.0** | `4152e6a` |
| `soundfont-generaluser` 1.471 | link do Dropbox só funciona com `?dl=1` | `?dl=1` + `PKG_SOURCE_NAME` fixo (mesmo SHA-256) | `4152e6a` |
| `xroar` 1.11 | versão retirada do site oficial e de todos os espelhos | atualizado para **1.12.1** (oficial mais próxima) | `4152e6a` |
| `dosbox-pure` | o projeto reescreveu o histórico: o commit fixado `fe0bdab` saiu da branch `main` e o clone falhava (descoberto na etapa 528/690) | baixado como arquivo do próprio commit no GitHub, com SHA-256 fixo; as outras 80 fontes git foram conferidas (todas íntegras) | `c865c88` |
| `yabasanshiroSA_1_5` | a branch `pi4` foi apagada e a `main` divergiu do commit fixado (descoberto na etapa 579/690); o código depende do submódulo `ext/eigen` | código baixado como arquivo do commit (SHA-256 fixo) + pacote auxiliar `eigen-yabasanshiro` com o submódulo no commit exato, juntados por `PKG_DEPENDS_UNPACK`; todas as branches fixadas dos outros pacotes conferidas no GitHub (existem) | ver histórico |

Melhorias no fluxo, nascidas dessas falhas:

- o `compilar.sh` baixa **todas** as fontes antes de compilar (`tools/download-tool --all`) e lista de uma vez os pacotes com falha em `imagens-compiladas\logs\fontes-com-falha.txt`;
- `GNU parallel` instalado no Ubuntu (downloads em paralelo);
- a área de compilação guarda os downloads entre builds (`~/arcadia-build/sources`, 32 GB em 14/11/2026).

Outras regras do build do Arcádia (detalhes em [CONFIGURACAO-DE-FABRICA.md](CONFIGURACAO-DE-FABRICA.md) e [ATUALIZACOES.md](ATUALIZACOES.md)):

- nome da imagem: `Arcadia-Amlogic-ng.aarch64-<versão>` (`CUSTOM_IMAGE_NAME`, versão em `packages/sx05re/emuelec/config/EE_VERSION`);
- senhas do root e do Samba lidas de `docs/SENHAS-LOCAIS.md` (fora do Git) pelo `compilar.ps1`; `busybox` e `samba` recompilam quando mudam;
- o EmulationStation vem do fork `ricardofarney/arcadia-emulationstation` ([FUNCOES-ARCADIA.md](FUNCOES-ARCADIA.md)).

## Resultado do build final (14/11/2026, 22:17)

Build do commit `ae97c2b` concluído com sucesso em 201 minutos (depois das correções acima). Arquivos em `D:\Adube Sistemas\Console de Jogo\imagens-compiladas\`:

| Arquivo | Uso | SHA-256 |
|---|---|---|
| `Arcadia-Amlogic-ng.aarch64-1.0.0-Generic.img.gz` (1,3 GB) | **gravar no cartão do X2 Pro** (TV boxes) | `687c6bb8…2e73fe0f` (substituída pela de 15/11, abaixo) |
| `Arcadia-Amlogic-ng.aarch64-1.0.0.tar` (1,4 GB) | atualização pelo menu | `ecf4522c…17e860c0` |
| `…-Odroid_N2`, `-Odroid_N2L`, `-Odroid_C4`, `-Odroid_HC4`, `-LePotato`, `-LaFrite`, `-Radxa_Zero`, `-Radxa_Zero2` `.img.gz` | placas de desenvolvimento (geradas automaticamente pelo EmuELEC; **não usadas**). Todas apagadas de `imagens-compiladas` em 15/11/2026, com OK do usuário; o `compilar.sh` agora copia só a Generic e o `.tar` da versão compilada | — |

Conferido dentro da imagem (sistema extraído do `.tar`): versão `1.0.0`; `ThemeSet=arcadia`, `CollectionSystemsAuto=recent,favorites,all`, `ShowSaveStates=true`; `pt_BR`, `America/Sao_Paulo`, `ARCADIA`, `global.autosave=1`; tema `arcadia` com a grade; `arcadia-dados.sh`; `updatecheck.sh` apontando para o fork; Samba com usuário `arcadia` e senha definida; senha do root = a de `docs/SENHAS-LOCAIS.md` (a padrão `emuelec` não funciona); EmulationStation aarch64 do fork com as traduções novas; tela de abertura nova (1920×1080).

**Rebuild de 15/11/2026 02:35** (commit `02a38bdd`, 2 min, incremental), só a imagem Generic: `…-1.0.0-Generic.img.gz` SHA-256 `a235bba02762d56aaf600dc205cbf80c6ec5e9f56f361f7e394dbfef2a396634`; `…-1.0.0.tar` `fe357ed988310ac714d8abb61631c75ea1c063a5530ab9ae310f4e06e241b165`. `verificar-imagem.sh`: 14 OK.

**Desde 15/11/2026 o build gera só a imagem `Generic`:** `SUBDEVICES=""` em `projects/Amlogic-ce/devices/Amlogic-ng/options` (as u-boots das placas não são mais compiladas) e `scripts/image` passou a gerar a `Generic` no Amlogic-ce mesmo sem subdevices. O caminho de montagem da `Generic` é o mesmo de antes (`SUBDEVICE=Generic`, sem u-boot de placa; `dtb.img` escolhido no cartão), por isso o nome do arquivo continua `…-Generic.img.gz`.
