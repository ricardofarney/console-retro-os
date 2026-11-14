# Projeto — Console de Jogos Retrô

## Resumo

Sistema de jogos retrô próprio, baseado no [EmuELEC](https://github.com/EmuELEC/EmuELEC), para o aparelho **KINHANK Super Console X2 Pro**:

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
- Cópia no Windows: `D:\Adube Sistemas\Console de Jogo\console-retro-os` (documentação e edição); o build é feito num clone dentro do WSL2 (ver [ANALISE-INICIAL.md](ANALISE-INICIAL.md#14-cuidados-no-wsl))

### Fase 1 (objetivos)

1. Tema próprio em português do Brasil.
2. Salvamento e carregamento automático ligados de fábrica em todos os sistemas.
3. Linha "Continuar jogando" (coleção de jogados recentemente) na tela inicial.
4. Favoritos na tela inicial.

Detalhes técnicos e plano em etapas: [ANALISE-INICIAL.md](ANALISE-INICIAL.md).

## Regras do projeto

1. **Idioma:** responder e escrever tudo em **português do Brasil** — mensagens, documentos, comentários e mensagens de commit.
2. **Horário:** usar o **horário de Brasília** (America/Sao_Paulo) em datas, registros e no fuso padrão do sistema.
3. **Commits e pushes:** o **Claude Code faz todos os commits e pushes**; não pedir ao usuário para fazê-los.
4. **Instalações que exigem administrador:** informar o comando exato e **aguardar confirmação** antes de executar.
5. **Emuladores:** manter todos (uso pessoal), sem remover núcleos por causa de licença.
6. **Pasta do projeto:** tudo do projeto fica dentro de `D:\Adube Sistemas\Console de Jogo\` (repositório, backups do cartão, disco do WSL).
7. **Cartão original:** nunca gravar por cima do microSD original do aparelho; fazer backup completo antes e testar sempre num cartão novo.
