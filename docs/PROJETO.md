# Projeto Arcádia — Console de Jogos Retrô

## Resumo

**Arcádia** é um sistema de jogos retrô próprio, baseado no [EmuELEC](https://github.com/EmuELEC/EmuELEC), para o aparelho **KINHANK Super Console X2 Pro**:

| Item | Detalhe |
|---|---|
| Processador | Amlogic **S905X2** (família g12a) |
| Memória | 2 GB de RAM |
| Conectividade | Wi-Fi e Bluetooth 5.0 |
| Onde o sistema roda | **cartão microSD** (o Android interno do aparelho não é alterado) |
| Build | `PROJECT=Amlogic-ce DEVICE=Amlogic-ng ARCH=aarch64 DISTRO=EmuELEC make image` |
| Uso | **pessoal/doméstico** — todos os emuladores do EmuELEC são mantidos, inclusive os de licença não comercial |

### Repositório

- Fork: <https://github.com/ricardofarney/console-retro-os> (branch de trabalho: `dev`)
- `origin` → fork; `upstream` → EmuELEC original (somente leitura, para puxar atualizações: `git fetch upstream && git merge upstream/dev`)

## Regras permanentes

1. **Pasta do projeto:** TODOS os arquivos e pastas do projeto ficam dentro de `D:\Adube Sistemas\Console de Jogo`; qualquer pasta nova é criada lá dentro. Exceções inevitáveis, documentadas:
   - a área de compilação `~/arcadia-build` (e `~/arcadia-logs`, `~/.ccache-arcadia`) dentro do Ubuntu/WSL — mas o disco virtual do Ubuntu fica em `D:\Adube Sistemas\Console de Jogo\wsl\`;
   - o arquivo de configuração do WSL `%UserProfile%\.wslconfig` (o Windows só o lê nesse lugar);
   - o atalho "Arcádia (prévia)" na Área de Trabalho, pedido pelo usuário.
2. **Idioma:** tudo em **português do Brasil** — mensagens, documentos, comentários e mensagens de commit.
3. **Horário:** **horário de Brasília** (America/Sao_Paulo) em datas, registros e no fuso padrão do sistema.
4. **Commits e pushes:** o **Claude Code faz todos os commits e pushes**; não pedir ao usuário.
5. **Administrador:** instalações que exigem administrador só depois de mostrar o comando exato e receber confirmação.
6. **Apagar:** nada é apagado sem antes mostrar ao usuário o que será apagado.
7. **Emuladores:** manter todos (uso pessoal), sem remover núcleos por causa de licença.
8. **Cartão original:** nunca gravar por cima do microSD original do aparelho; fazer backup completo antes e testar sempre num cartão novo.
9. **Tarefas:** se houver uma tarefa anterior em andamento, terminá-la antes de começar a próxima.

## Pastas

```
D:\Adube Sistemas\Console de Jogo\
├── console-retro-os\          repositório do sistema (fork do EmuELEC) — fonte oficial de tudo
│   ├── docs\                  documentos oficiais (este arquivo, análise, ambiente, prévia)
│   ├── temas\arcadia\         tema Arcádia do EmulationStation
│   └── ferramentas\           scripts (build no WSL, geração de artes, prévia, cópia de docs)
├── arcadia-emulationstation\  fork do EmulationStation (criado só quando for necessário)
├── arcadia-preview\           prévia no Windows com RetroBat
├── imagens-compiladas\        imagens prontas para gravar no cartão (.img.gz, .tar, .sha256)
│   └── logs\                  log e situação de cada build
├── backups\                   backup do cartão original do aparelho (imagem inteira, dtb.img, roms)
├── docs\                      CÓPIAS dos documentos e relatórios (atualizadas por ferramentas\copiar-docs.ps1)
└── wsl\                       disco virtual do Ubuntu 22.04 (WSL2) e arquivo de swap
```

A versão oficial dos documentos é sempre a de `console-retro-os\docs\`; a pasta `docs\` da raiz é só uma cópia para consulta rápida.

## Fluxo de compilação

O build do EmuELEC precisa rodar no sistema de arquivos do Linux para funcionar e ter bom desempenho. Por isso:

```
1. Editar e commitar em  D:\Adube Sistemas\Console de Jogo\console-retro-os   (branch dev)
2. Iniciar o build:      ferramentas\wsl\compilar.ps1
       │  o Ubuntu sincroniza ~/arcadia-build a partir do repositório da pasta do projeto
       │  (git fetch + reset — somente commits; alterações não commitadas geram aviso no log)
       ▼
3. ~/arcadia-build       área de compilação temporária no WSL (não editar nada aqui)
       │  make image
       ▼
4. D:\Adube Sistemas\Console de Jogo\imagens-compiladas   (.img.gz, .tar, .sha256 e logs\)
```

Comando para iniciar (PowerShell normal):

```powershell
Start-Process powershell -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','"D:\Adube Sistemas\Console de Jogo\console-retro-os\ferramentas\wsl\compilar.ps1"'
```

Situação do build: `D:\Adube Sistemas\Console de Jogo\imagens-compiladas\logs\status.txt`. Detalhes em [AMBIENTE-BUILD.md](AMBIENTE-BUILD.md).

## Fase 1 (objetivos)

1. Tema próprio em português do Brasil — primeira versão em [temas/arcadia](../temas/arcadia).
2. Salvamento e carregamento automático ligados de fábrica em todos os sistemas.
3. Linha "Continuar jogando" (coleção de jogados recentemente) na tela inicial.
4. Favoritos na tela inicial.

Prévia do visual no Windows (RetroBat): [PREVIA-WINDOWS.md](PREVIA-WINDOWS.md). Detalhes técnicos e plano em etapas: [ANALISE-INICIAL.md](ANALISE-INICIAL.md).
