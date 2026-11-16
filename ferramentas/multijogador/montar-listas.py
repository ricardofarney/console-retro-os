#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Arcádia — monta as listas de jogos de 3 ou mais jogadores que usam multitap.

Fontes (listas conhecidas da comunidade, guardadas em fontes\\):
  - Super Nintendo: Nintendo Wiki (nintendo.fandom.com), página "Super Multitap";
  - Mega Drive: Sega Retro (segaretro.org), páginas "Team Player" e "4 Way Play";
  - PlayStation: Wikipedia (en), página "PlayStation Multitap".

As fontes trazem só o título do jogo. Este script cruza cada título com as DATs
No-Intro/Redump guardadas em ferramentas\\roms\\dats (as mesmas do limpar-roms.py)
e grava em listas\\ uma linha por título oficial (com todas as regiões), no formato
que o gerador do aparelho (arcadia-multijogador.sh) lê:

    chave|Título oficial|jogadores|modo

  chave     título normalizado (minúsculas, sem parênteses/colchetes, sem "the",
            só letras e números) — o aparelho normaliza o nome do arquivo igual;
  jogadores número máximo de jogadores (ou "?" quando a fonte não informa);
  modo      snes: "multitap"; megadrive: "teamplayer" ou "4wayplay"; psx: "multitap".

Uso:
  python montar-listas.py                     monta listas\\ a partir de fontes\\ (sem internet)
  python montar-listas.py --atualizar-fontes  baixa as 4 páginas de novo e depois monta
"""
from __future__ import annotations

import argparse
import html
import json
import re
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

VERSAO = "1.0"
FUSO_BRASILIA = timezone(timedelta(hours=-3), "BRT")
AQUI = Path(__file__).resolve().parent
PASTA_FONTES = AQUI / "fontes"
PASTA_LISTAS = AQUI / "listas"
ARQ_APELIDOS = AQUI / "apelidos.txt"
PASTA_DATS = AQUI.parent / "roms" / "dats"
AGENTE = "arcadia-multijogador/" + VERSAO

# console -> (DAT, arquivos de fonte com o modo de cada um)
CONSOLES = {
    "snes": ("no-intro/Nintendo - Super Nintendo Entertainment System.dat",
             [("snes-super-multitap.txt", "multitap")]),
    # Team Player primeiro: jogo que aceita os dois adaptadores fica com o Team Player
    "megadrive": ("no-intro/Sega - Mega Drive - Genesis.dat",
                  [("megadrive-team-player.txt", "teamplayer"), ("megadrive-4-way-play.txt", "4wayplay")]),
    "psx": ("redump/Sony - PlayStation.dat",
            [("psx-multitap.txt", "multitap")]),
}

FONTES_WEB = {
    "snes-super-multitap.txt": ("https://nintendo.fandom.com/api.php", "Super_Multitap",
                                "https://nintendo.fandom.com/wiki/Super_Multitap"),
    "megadrive-team-player.txt": ("https://segaretro.org/api.php", "Team_Player",
                                  "https://segaretro.org/Team_Player"),
    "megadrive-4-way-play.txt": ("https://segaretro.org/api.php", "4_Way_Play",
                                 "https://segaretro.org/4_Way_Play"),
    "psx-multitap.txt": ("https://en.wikipedia.org/w/api.php", "PlayStation_Multitap",
                         "https://en.wikipedia.org/wiki/PlayStation_Multitap"),
}


# ---------------------------------------------------------------------------
# Normalização (igual à do aparelho: ferramentas/multijogador/arcadia-multijogador.sh)
# ---------------------------------------------------------------------------
def chave(titulo: str) -> str:
    t = re.sub(r"\([^)]*\)", "", titulo)
    t = re.sub(r"\[[^\]]*\]", "", t)
    t = t.lower().replace("&", "and")
    t = re.sub(r"^\s*the\s+", "", t)
    t = re.sub(r",\s*the(\s|-|$)", r"\1", t)     # "Sporting News, The - Baseball"
    return re.sub(r"[^a-z0-9]", "", t)


def titulo_base(nome_dat: str) -> str:
    """'NBA Jam (USA) (Rev 1)' -> 'NBA Jam'."""
    return re.sub(r"\s*[\(\[].*$", "", nome_dat).strip()


def agora() -> str:
    return datetime.now(FUSO_BRASILIA).strftime("%d/%m/%Y %H:%M")


# ---------------------------------------------------------------------------
# Download das fontes
# ---------------------------------------------------------------------------
def api_parse(api: str, pagina: str, prop: str) -> tuple[str, int]:
    url = f"{api}?action=parse&page={pagina}&prop={prop}|revid&format=json&formatversion=2&redirects=1"
    req = urllib.request.Request(url, headers={"User-Agent": AGENTE})
    with urllib.request.urlopen(req, timeout=60) as r:
        d = json.load(r)
    if "parse" not in d:
        raise RuntimeError(f"{pagina}: {d.get('error', {}).get('info', 'resposta inesperada')}")
    return d["parse"][prop], d["parse"].get("revid", 0)


def _limpa_html(s: str) -> str:
    s = re.sub(r"<sup.*?</sup>", "", s, flags=re.S)
    return html.unescape(re.sub(r"<[^>]+>", "", s)).strip()


def extrair_nintendo_wiki(texto: str) -> list[tuple[str, str, str]]:
    """Itens '<título> - <n> players' da lista de jogos do Super Multitap."""
    jogos = []
    for item in re.findall(r"<li>(.*?)</li>", texto, re.S):
        t = _limpa_html(item)
        m = re.match(r"^(.*?)\s*-\s*(\d+|unknown)\s+players?\b(.*)$", t, re.I)
        if not m:
            continue                      # adaptadores de outras marcas, não são jogos
        nome, qtd, resto = m.group(1).strip(), m.group(2), m.group(3).strip(" ()")
        if "romhack" in t.lower():
            continue                      # só funciona com ROM modificada
        if "bomberman gb" in nome.lower():
            continue                      # Game Boy (Super Game Boy), não é jogo de SNES
        jogos.append((nome, qtd if qtd.isdigit() else "?", resto))
    return jogos


def extrair_sega_retro(texto: str) -> list[tuple[str, str, str]]:
    """Só a seção 'Mega Drive' da lista de compatibilidade."""
    partes = re.split(r"<h[23][^>]*>", texto)
    for parte in partes:
        cab = _limpa_html(parte[:400]).split("\n")[0]
        if cab.startswith("Mega Drive"):
            jogos = []
            for item in re.findall(r"<li>(.*?)</li>", parte, re.S):
                nome = re.sub(r"\s*\(\d{4}\)\s*$", "", _limpa_html(item))
                jogos.append((nome, "?", ""))
            return jogos
    raise RuntimeError("seção 'Mega Drive' não encontrada")


def extrair_wikipedia_psx(texto: str) -> list[tuple[str, str, str]]:
    ini = texto.find("=== PlayStation ===")
    fim = texto.find("===PlayStation 2===")
    if ini < 0 or fim < 0:
        raise RuntimeError("seção PlayStation não encontrada")
    jogos, qtd = [], "?"
    for linha in texto[ini:fim].splitlines():
        m = re.match(r"^'''\s*1\s*[-–]\s*(\d+)\s+Players?\s*'''", linha.strip(), re.I)
        if m:
            qtd = m.group(1)
            continue
        if not linha.startswith("*"):
            continue
        s = re.sub(r"<ref[^>]*/>|<ref.*?</ref>", "", linha[1:], flags=re.S).strip()
        link = re.match(r"^\[\[([^\]|]+)(?:\|([^\]]+))?\]\](.*)$", s)
        if link:
            nome = (link.group(2) or re.sub(r"\s*\([^)]*\)\s*$", "", link.group(1))) + link.group(3)
        else:
            nome = s
        nome = re.sub(r"\{\{.*?\}\}", "", nome).replace("''", "").strip()
        if nome:
            jogos.append((nome, qtd, ""))
    return jogos


def atualizar_fontes() -> None:
    PASTA_FONTES.mkdir(exist_ok=True)
    for arq, (api, pagina, url_humana) in FONTES_WEB.items():
        prop = "wikitext" if "wikipedia" in api else "text"
        texto, revid = api_parse(api, pagina, prop)
        if arq.startswith("snes"):
            jogos = extrair_nintendo_wiki(texto)
        elif arq.startswith("megadrive"):
            jogos = extrair_sega_retro(texto)
        else:
            jogos = extrair_wikipedia_psx(texto)
        cab = (f"# Arcádia — fonte da lista multijogador ({arq})\n"
               f"# Origem: {url_humana} (revisão {revid})\n"
               f"# Baixada em: {agora()} (horário de Brasília) por montar-listas.py {VERSAO}\n"
               f"# Formato: título<TAB>jogadores (? = a fonte não informa)<TAB>observação\n")
        corpo = "".join(f"{n}\t{q}\t{o}\n" for n, q, o in jogos)
        (PASTA_FONTES / arq).write_text(cab + corpo, encoding="utf-8", newline="\n")
        print(f"fonte {arq}: {len(jogos)} jogos (revisão {revid})")


# ---------------------------------------------------------------------------
# Montagem das listas
# ---------------------------------------------------------------------------
def ler_fonte(arq: str) -> list[tuple[str, str]]:
    jogos = []
    for linha in (PASTA_FONTES / arq).read_text(encoding="utf-8").splitlines():
        if not linha.strip() or linha.startswith("#"):
            continue
        partes = linha.split("\t")
        jogos.append((partes[0], partes[1] if len(partes) > 1 else "?"))
    return jogos


def ler_apelidos() -> dict[str, dict[str, list[str]]]:
    """console|título da fonte|título oficial[;título oficial...] (vazio = ignorar)."""
    res: dict[str, dict[str, list[str]]] = {}
    if not ARQ_APELIDOS.exists():
        return res
    for linha in ARQ_APELIDOS.read_text(encoding="utf-8").splitlines():
        if not linha.strip() or linha.startswith("#"):
            continue
        console, fonte, oficial = (linha.split("|") + ["", ""])[:3]
        res.setdefault(console.strip(), {})[chave(fonte)] = [o.strip() for o in oficial.split(";") if o.strip()]
    return res


def titulos_dat(caminho: Path) -> dict[str, set[str]]:
    """chave -> títulos-base oficiais (sem região) da DAT."""
    res: dict[str, set[str]] = {}
    for m in re.finditer(r'^\s*name\s+"(.*)"\s*$', caminho.read_text(encoding="utf-8", errors="replace"), re.M):
        base = titulo_base(m.group(1))
        res.setdefault(chave(base), set()).add(base)
    return res


def montar() -> int:
    apelidos = ler_apelidos()
    PASTA_LISTAS.mkdir(exist_ok=True)
    total_faltando = 0
    relatorio = [f"# Relatório de montagem — {agora()} (horário de Brasília)\n"]
    for console, (dat_rel, fontes) in CONSOLES.items():
        dat = titulos_dat(PASTA_DATS / dat_rel)
        linhas: dict[str, tuple[str, str, str]] = {}
        faltando = []
        for arq, modo in fontes:
            for nome, qtd in ler_fonte(arq):
                k = chave(nome)
                alvos = apelidos.get(console, {}).get(k)
                if alvos is not None and not alvos:
                    continue                  # marcado para ignorar
                oficiais = []
                for alvo in (alvos or [nome]):
                    oficiais.extend(sorted(dat.get(chave(alvo), [])))
                if not oficiais:
                    faltando.append(nome)
                    continue
                for oficial in oficiais:
                    ko = chave(oficial)
                    if ko in linhas:          # já veio de uma fonte anterior (Team Player > 4 Way Play)
                        _, q0, m0 = linhas[ko]
                        if q0 == "?" and qtd != "?":
                            linhas[ko] = (oficial, qtd, m0)
                        continue
                    linhas[ko] = (oficial, qtd, modo)
        cab = (f"# Arcádia — jogos de {console} com multitap (3 ou mais jogadores)\n"
               f"# Gerado por ferramentas/multijogador/montar-listas.py {VERSAO} em {agora()} (horário de Brasília)\n"
               f"# Fontes: {', '.join(a for a, _ in fontes)} + DAT {dat_rel}\n"
               f"# Formato: chave|título oficial|jogadores|modo\n")
        corpo = "".join(f"{k}|{t}|{q}|{m}\n" for k, (t, q, m) in sorted(linhas.items()))
        (PASTA_LISTAS / f"{console}.txt").write_text(cab + corpo, encoding="utf-8", newline="\n")
        print(f"{console}: {len(linhas)} títulos na lista; {len(faltando)} da fonte sem título na DAT")
        relatorio.append(f"\n## {console}: {len(linhas)} títulos; sem correspondência na DAT: {len(faltando)}\n")
        relatorio.extend(f"- {n}\n" for n in faltando)
        total_faltando += len(faltando)
    (AQUI / "relatorio-montagem.md").write_text("".join(relatorio), encoding="utf-8", newline="\n")
    return total_faltando


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description="Monta as listas de jogos com multitap do Arcádia.")
    ap.add_argument("--atualizar-fontes", action="store_true", help="baixa de novo as 4 páginas de origem")
    args = ap.parse_args()
    if args.atualizar_fontes:
        atualizar_fontes()
    faltando = montar()
    print(f"Listas gravadas em {PASTA_LISTAS}. Títulos sem correspondência: {faltando} (ver relatorio-montagem.md)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
