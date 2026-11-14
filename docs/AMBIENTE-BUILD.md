# Ambiente de build — WSL2 no PC de desenvolvimento

Montado em 14/11/2026 (horário de Brasília). Scripts em [ferramentas/wsl/](../ferramentas/wsl).

## O que foi feito

| Passo | Como | Quem |
|---|---|---|
| Virtualização | BIOS ASUS TUF GAMING B550M-PLUS WIFI II: *Advanced → CPU Configuration → SVM Mode = Enabled* | usuário |
| Plataforma de Máquina Virtual | `wsl.exe --install --no-distribution` (PowerShell como administrador) + reinício | usuário |
| Ubuntu 22.04 (WSL2) | `wsl --install -d Ubuntu-22.04 --location "D:\Adube Sistemas\Console de Jogo\wsl\Ubuntu-22.04" --no-launch` | Claude Code |
| Limites do WSL | `%UserProfile%\.wslconfig`: 24 GB de RAM, 14 CPUs, swap de 32 GB em `D:\Adube Sistemas\Console de Jogo\wsl\swap.vhdx` | Claude Code |
| Usuário e dependências | [preparar-wsl.sh](../ferramentas/wsl/preparar-wsl.sh): usuário `console` (sem senha, `sudo` liberado; definir senha com `sudo passwd console`), `systemd`, fuso America/Sao_Paulo, locales en_US/pt_BR e todos os pacotes de build | Claude Code |
| Clone para compilar | `~/console-retro-os` dentro do Ubuntu (finais de linha LF); `upstream` com push desativado | Claude Code |

Observação: o WSL avisa *"Falha ao configurar a rede (networkingMode Nat), voltando para networkingMode VirtioProxy"*. A internet funciona normalmente nesse modo (testado com GitHub); o aviso pode ser ignorado.

## Como compilar

No PowerShell normal (sem administrador):

```powershell
Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','"D:\Adube Sistemas\Console de Jogo\wsl\compilar.ps1"'
```

- [compilar.ps1](../ferramentas/wsl/compilar.ps1) roda o build num processo próprio (continua mesmo fechando o terminal ou o Claude) e **impede o Windows de suspender** até terminar.
- [compilar.sh](../ferramentas/wsl/compilar.sh) atualiza o clone (`git pull`), executa `PROJECT=Amlogic-ce DEVICE=Amlogic-ng ARCH=aarch64 DISTRO=EmuELEC make image` e:
  - grava o log em `~/build-logs/build-AAAA-MM-DD_HHMM.log`;
  - grava a situação em `~/build-logs/status.txt` (`EM ANDAMENTO`, `OK` ou `FALHOU`), copiada ao final para `D:\Adube Sistemas\Console de Jogo\wsl\status.txt`;
  - em caso de sucesso, copia `.img.gz`, `.tar` e `.sha256` para `D:\Adube Sistemas\Console de Jogo\builds\`.

As cópias usadas pelo `compilar.ps1` ficam em `D:\Adube Sistemas\Console de Jogo\wsl\`; as deste diretório `ferramentas/wsl/` são a versão de referência.

## Acompanhar o build

```powershell
wsl -d Ubuntu-22.04 -- cat /home/console/build-logs/status.txt
```

```powershell
wsl -d Ubuntu-22.04 -- bash -c 'tail -n 3 $(ls -t ~/build-logs/build-*.log | head -1)'
```

A linha `[NNN/689] [DONE] build <pacote>` mostra o avanço (689 etapas no primeiro build de 14/11/2026).

## Espaço em disco

O disco virtual do Ubuntu (`D:\Adube Sistemas\Console de Jogo\wsl\Ubuntu-22.04\ext4.vhdx`) cresce conforme o uso — espere 150–250 GB após o primeiro build. Ele não encolhe sozinho ao apagar arquivos; para recuperar espaço: `wsl --shutdown` e compactar o VHDX (`Optimize-VHD` ou `diskpart` → `compact vdisk`).
