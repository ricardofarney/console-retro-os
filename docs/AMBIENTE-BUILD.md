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
