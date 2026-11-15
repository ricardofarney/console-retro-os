#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
baixar-capas.py — monta o cache LOCAL de capas (Named_Boxarts) do Arcádia.

Projeto pessoal Arcádia (EmuELEC). Só biblioteca padrão do Python 3 + git.

Para cada console da paleta do projeto, baixa SÓ a pasta Named_Boxarts do
repositório GitHub libretro-thumbnails/<Sistema_com_underscores>, sem
histórico:

    git clone --depth 1 --filter=blob:none --sparse <repo> <tmp>
    git sparse-checkout set Named_Boxarts

Depois:
  - os links simbólicos do repositório (nomes alternativos que apontam para
    outra capa) viram hard links/cópias da capa de verdade (no Windows o git
    os grava como arquivos de texto com o caminho do alvo);
  - a pasta .git é removida (as imagens ficariam duplicadas dentro dela);
  - o resultado vai para <cache>\\<Nome do sistema libretro>\\Named_Boxarts\\
    com um ORIGEM.txt (commit, data, quantidade, tamanho).

Uso:
  python baixar-capas.py --estimar                 # só mostra o tamanho
  python baixar-capas.py                           # baixa o que falta
  python baixar-capas.py --sistemas "Sega - 32X"   # só alguns
  python baixar-capas.py --atualizar               # baixa de novo (substitui)
  python baixar-capas.py --resumo                  # mede o cache (sem internet)
  python baixar-capas.py --cache-capas E:\\capas    # outro destino

Se a estimativa total passar do teto (--teto-gb, padrão 25), baixa primeiro
os consoles mais comuns, na ordem da lista, até o teto, e registra o resto.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import stat
import subprocess
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from pathlib import Path

FUSO_BRASILIA = timezone(timedelta(hours=-3), "BRT")
PASTA_SCRIPT = Path(__file__).resolve().parent
CACHE_CAPAS_PADRAO = PASTA_SCRIPT / ".cache" / "capas"
ORG = "libretro-thumbnails"

# Ordem = prioridade (os mais comuns primeiro). Nomes exatamente como no
# libretro-thumbnails (com espaços); o repositório troca espaço por "_".
SISTEMAS_PALETA = [
    "Nintendo - Nintendo Entertainment System",
    "Nintendo - Super Nintendo Entertainment System",
    "Sega - Mega Drive - Genesis",
    "Sega - Master System - Mark III",
    "Nintendo - Game Boy",
    "Nintendo - Game Boy Color",
    "Nintendo - Game Boy Advance",
    "Sony - PlayStation",
    "Nintendo - Nintendo 64",
    "Sega - Game Gear",
    "NEC - PC Engine - TurboGrafx 16",
    "Atari - 2600",
    # demais consoles da paleta
    "Atari - 7800",
    "Nintendo - Family Computer Disk System",
    "Sega - Mega-CD - Sega CD",
    "Sega - 32X",
    "NEC - PC Engine CD - TurboGrafx-CD",
    "NEC - PC Engine SuperGrafx",
    "SNK - Neo Geo Pocket",
    "SNK - Neo Geo Pocket Color",
    "Bandai - WonderSwan",
    "Bandai - WonderSwan Color",
    "Microsoft - MSX",
    "Microsoft - MSX2",
]


def agora() -> str:
    return datetime.now(FUSO_BRASILIA).strftime("%d/%m/%Y %H:%M:%S")


def gb(n: int) -> str:
    return f"{n / 1024 ** 3:.2f} GB".replace(".", ",")


def mb(n: int) -> str:
    return f"{n / 1024 ** 2:.1f} MB".replace(".", ",")


class Log:
    def __init__(self, arquivo: Path):
        self.arquivo = arquivo
        arquivo.parent.mkdir(parents=True, exist_ok=True)

    def __call__(self, msg: str) -> None:
        linha = f"[{agora()}] {msg}"
        print(linha, flush=True)
        with open(self.arquivo, "a", encoding="utf-8") as f:
            f.write(linha + "\n")


def repo_de(sistema: str) -> str:
    return sistema.replace(" ", "_")


# --------------------------------------------------------------------------
# Estimativa (API do GitHub: gh, se existir; senão HTTP sem autenticação)
# --------------------------------------------------------------------------

def _api(caminho: str):
    if shutil.which("gh"):
        r = subprocess.run(["gh", "api", caminho], capture_output=True, text=True,
                           encoding="utf-8", timeout=120)
        if r.returncode == 0:
            return json.loads(r.stdout)
    req = urllib.request.Request("https://api.github.com/" + caminho,
                                 headers={"User-Agent": "arcadia-baixar-capas",
                                          "Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))


def estimar(sistema: str) -> tuple[int, int]:
    """(quantidade de arquivos, bytes) da pasta Named_Boxarts no GitHub."""
    repo = repo_de(sistema)
    raiz = _api(f"repos/{ORG}/{repo}/git/trees/HEAD")
    sha = next((t["sha"] for t in raiz["tree"] if t["path"] == "Named_Boxarts"), None)
    if not sha:
        return 0, 0
    arv = _api(f"repos/{ORG}/{repo}/git/trees/{sha}")
    blobs = [t for t in arv["tree"] if t["type"] == "blob"]
    return len(blobs), sum(t.get("size", 0) for t in blobs)


# --------------------------------------------------------------------------
# Download
# --------------------------------------------------------------------------

def _git(args: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess:
    base = ["git", "-c", "core.symlinks=false", "-c", "core.longpaths=true",
            "-c", "core.autocrlf=false"]
    return subprocess.run(base + args, cwd=cwd, capture_output=True, text=True,
                          encoding="utf-8", errors="replace", timeout=6 * 3600)


def _rmtree(p: Path) -> None:
    def _forcar(func, caminho, _exc):
        try:
            os.chmod(caminho, stat.S_IWRITE)
            func(caminho)
        except OSError:
            pass
    if p.exists():
        # \\?\ = permite apagar nomes com mais de 260 caracteres no Windows
        alvo = "\\\\?\\" + os.path.abspath(p) if os.name == "nt" else str(p)
        shutil.rmtree(alvo, onerror=_forcar)


def resolver_links(tmp: Path) -> tuple[int, int]:
    """Troca os 'links simbólicos em texto' por hard link/cópia do alvo.
    Retorna (resolvidos, quebrados)."""
    r = _git(["ls-files", "-s", "--", "Named_Boxarts"], cwd=tmp)
    links = []
    for linha in r.stdout.splitlines():
        meta, _, caminho = linha.partition("\t")
        if meta.startswith("120000"):
            links.append(caminho)
    ok = quebrados = 0
    for rel in links:
        arq = Path("\\\\?\\" + os.path.abspath(tmp / rel)) if os.name == "nt" else tmp / rel
        try:
            alvo_txt = arq.read_text(encoding="utf-8", errors="replace").strip()
        except OSError:
            quebrados += 1
            continue
        alvo = Path(os.path.normpath(arq.parent / alvo_txt))
        if not alvo.is_file() or alvo.stat().st_size < 64:
            quebrados += 1
            continue
        arq.unlink()
        try:
            os.link(alvo, arq)
        except OSError:
            shutil.copy2(alvo, arq)
        ok += 1
    return ok, quebrados


def baixar(sistema: str, cache: Path, atualizar: bool, log: Log) -> dict:
    destino = cache / sistema
    res = {"sistema": sistema, "status": "", "arquivos": 0, "bytes": 0}
    if (destino / "Named_Boxarts").is_dir() and not atualizar:
        res["status"] = "já existia"
        res["arquivos"], res["bytes"] = medir(destino / "Named_Boxarts")
        log(f"{sistema}: já existe no cache ({res['arquivos']} capas, {gb(res['bytes'])}) — pulado")
        return res
    tmp = cache / f"_baixando-{repo_de(sistema)}"
    _rmtree(tmp)
    url = f"https://github.com/{ORG}/{repo_de(sistema)}.git"
    log(f"{sistema}: clonando {url} (sparse, só Named_Boxarts) ...")
    r = _git(["clone", "-q", "--depth", "1", "--filter=blob:none", "--sparse", url, str(tmp)])
    if r.returncode != 0:
        res["status"] = "erro no clone: " + r.stderr.strip()[-300:]
        log(f"{sistema}: ERRO {res['status']}")
        _rmtree(tmp)
        return res
    r = _git(["sparse-checkout", "set", "Named_Boxarts"], cwd=tmp)
    if r.returncode != 0 or not (tmp / "Named_Boxarts").is_dir():
        res["status"] = "erro no sparse-checkout: " + r.stderr.strip()[-300:]
        log(f"{sistema}: ERRO {res['status']}")
        _rmtree(tmp)
        return res
    avisos_checkout = [l for l in r.stderr.splitlines() if l.strip()]
    commit = _git(["log", "-1", "--format=%H %cI"], cwd=tmp).stdout.strip()
    links_ok, links_ruins = resolver_links(tmp)
    _rmtree(tmp / ".git")
    for extra in tmp.iterdir():                 # só a pasta Named_Boxarts fica
        if extra.name != "Named_Boxarts":
            _rmtree(extra) if extra.is_dir() else extra.unlink()
    n, b = medir(tmp / "Named_Boxarts")
    (tmp / "ORIGEM.txt").write_text(
        f"Sistema: {sistema}\n"
        f"Origem: {url} (pasta Named_Boxarts)\n"
        f"Commit: {commit}\n"
        f"Baixado em: {agora()} (horário de Brasília)\n"
        f"Capas: {n} ({gb(b)})\n"
        f"Links simbólicos convertidos em cópia/hard link: {links_ok} (quebrados: {links_ruins})\n"
        + (f"Avisos do git: {' | '.join(avisos_checkout)[:2000]}\n" if avisos_checkout else ""),
        encoding="utf-8")
    if destino.exists():
        antigo = cache / f"_antigo-{repo_de(sistema)}"
        _rmtree(antigo)
        os.replace(destino, antigo)
        os.replace(tmp, destino)
        _rmtree(antigo)
    else:
        os.replace(tmp, destino)
    res.update(status="baixado", arquivos=n, bytes=b, commit=commit)
    log(f"{sistema}: OK — {n} capas, {gb(b)}; links convertidos {links_ok}, quebrados {links_ruins}")
    return res


def medir(pasta: Path) -> tuple[int, int]:
    n = b = 0
    vistos = set()
    base = Path("\\\\?\\" + os.path.abspath(pasta)) if os.name == "nt" else pasta
    for p in base.iterdir():                    # \\?\ = aceita nomes > 260 caracteres
        if p.is_file():
            st = p.stat()
            n += 1
            chave = (st.st_dev, st.st_ino)
            if chave in vistos and st.st_nlink > 1:
                continue                        # hard link: não conta duas vezes
            vistos.add(chave)
            b += st.st_size
    return n, b


def resumo(cache: Path, log: Log) -> int:
    """Mede o cache local (quantidade de capas e tamanho por sistema) e grava
    <cache>\\RESUMO.txt. Não acessa a internet."""
    linhas, tot_n, tot_b = [], 0, 0
    for s in SISTEMAS_PALETA + sorted(d.name for d in cache.iterdir()
                                      if d.is_dir() and d.name not in SISTEMAS_PALETA
                                      and (d / "Named_Boxarts").is_dir()):
        d = cache / s / "Named_Boxarts"
        if d.is_dir():
            n, b = medir(d)
            tot_n += n
            tot_b += b
            linhas.append(f"{s}\t{n}\t{b}\t{gb(b)}")
        else:
            linhas.append(f"{s}\t0\t0\tNÃO BAIXADO")
    texto = (f"Cache de capas (Named_Boxarts) — medido em {agora()} (horário de Brasília)\n"
             f"Pasta: {cache}\n"
             "Sistema\tCapas\tBytes\tTamanho\n" + "\n".join(linhas) +
             f"\nTOTAL\t{tot_n}\t{tot_b}\t{gb(tot_b)}\n")
    (cache / "RESUMO.txt").write_text(texto, encoding="utf-8")
    for l in texto.splitlines():
        log(l)
    return 0


def main(argv=None) -> int:
    try:
        sys.stdout.reconfigure(errors="replace")  # type: ignore[attr-defined]
    except Exception:  # noqa: BLE001
        pass
    ap = argparse.ArgumentParser(prog="baixar-capas.py",
                                 description="Arcádia — cache local de capas (Named_Boxarts do libretro-thumbnails).")
    ap.add_argument("--cache-capas", default=str(CACHE_CAPAS_PADRAO), help="pasta do cache de capas")
    ap.add_argument("--sistemas", default="", help="só estes sistemas libretro (separados por vírgula)")
    ap.add_argument("--estimar", action="store_true", help="só estima o tamanho (não baixa)")
    ap.add_argument("--resumo", action="store_true",
                    help="só mede o cache local (sem internet) e grava RESUMO.txt")
    ap.add_argument("--teto-gb", type=float, default=25.0, help="teto total em GB (padrão 25)")
    ap.add_argument("--atualizar", action="store_true", help="baixa de novo mesmo se já existir")
    ap.add_argument("--paralelo", type=int, default=3, help="downloads simultâneos (padrão 3)")
    args = ap.parse_args(argv)

    cache = Path(args.cache_capas).resolve()
    cache.mkdir(parents=True, exist_ok=True)
    log = Log(cache / "baixar-capas.log")
    sistemas = SISTEMAS_PALETA
    if args.sistemas:
        pedidos = [s.strip() for s in args.sistemas.split(",") if s.strip()]
        sistemas = [s for s in pedidos]

    if args.resumo:
        return resumo(cache, log)

    log(f"Estimando tamanho de {len(sistemas)} sistema(s) pela API do GitHub ...")
    est = {}
    for s in sistemas:
        try:
            est[s] = estimar(s)
        except Exception as e:  # noqa: BLE001
            est[s] = (0, 0)
            log(f"  {s}: não foi possível estimar ({e})")
        log(f"  {s}: {est[s][0]} capas, {gb(est[s][1])}")
    total = sum(b for _, b in est.values())
    log(f"Estimativa total: {gb(total)} (teto {args.teto_gb:g} GB)")

    escolhidos, fora = [], []
    acumulado = 0
    teto = args.teto_gb * 1024 ** 3
    for s in sistemas:                          # ordem = prioridade
        if acumulado + est[s][1] <= teto:
            escolhidos.append(s)
            acumulado += est[s][1]
        else:
            fora.append(s)
    if fora:
        log("Fora do teto (não baixados): " + "; ".join(f"{s} ({gb(est[s][1])})" for s in fora))
    if args.estimar:
        return 0

    def _seguro(s: str) -> dict:
        try:
            return baixar(s, cache, args.atualizar, log)
        except Exception as e:  # noqa: BLE001 — um sistema com erro não derruba os outros
            log(f"{s}: ERRO inesperado: {e!r}")
            return {"sistema": s, "status": f"erro inesperado: {e!r}", "arquivos": 0, "bytes": 0}

    with ThreadPoolExecutor(max_workers=max(1, args.paralelo)) as ex:
        resultados = list(ex.map(_seguro, escolhidos))
    ok = [r for r in resultados if r["status"] in ("baixado", "já existia")]
    erros = [r for r in resultados if r not in ok]
    log(f"Concluído: {len(ok)} sistema(s) no cache, {gb(sum(r['bytes'] for r in ok))}; erros: {len(erros)}")
    for r in erros:
        log(f"  ERRO {r['sistema']}: {r['status']}")
    return 1 if erros else 0


if __name__ == "__main__":
    sys.exit(main())
