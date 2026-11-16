#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
limpar-roms.py — limpeza e organização da pasta de ROMs do Arcádia.

Projeto pessoal Arcádia (EmuELEC). Só usa a biblioteca padrão do Python 3.

O que faz, por console (subpastas no padrão EmuELEC/RetroBat: nes, snes,
megadrive, gb, gbc, gba, psx, ...):
  a) identifica duplicados exatos (mesmo SHA1, inclusive dentro de .zip) e
     versões do mesmo jogo (nome normalizado + nome da DAT No-Intro/Redump
     encontrada pelo CRC32);
  b) mantém UMA versão por jogo: PT-BR > EUA/Mundo > Europa > (sem região) >
     Japão > outras > hacks; revisão mais nova; [!]; descarta Beta/Proto/Demo;
  c) MOVE os descartados para <roms>\\_removidos\\<console>\\ (nunca apaga);
  d) lista arquivos corrompidos (só move com --mover-corrompidos);
  e) baixa capas do libretro-thumbnails e atualiza o gamelist.xml
     preservando favoritos, descrições, contagem de jogadas etc.;
  f) gera relatório em <roms>\\_relatorios\\limpeza-AAAA-MM-DD_HHMM.md;
  g) --simular faz tudo menos mover/baixar/alterar (só gera o relatório).

Fontes locais (usadas PRIMEIRO, também no modo normal):
  - DATs guardadas no repositório: ferramentas\\roms\\dats\\<no-intro|redump>\\
    (<nome>.dat ou <nome>.zip com o .dat dentro);
  - cache de capas: ferramentas\\roms\\.cache\\capas\\<Sistema libretro>\\Named_Boxarts\\
    (montado por baixar-capas.py; outro local com --cache-capas).
  --offline não acessa a internet de jeito nenhum: só DATs locais e cache de
  capas (capa ausente no cache = "não encontrada").

Uso:
  python limpar-roms.py <pasta_roms> [--simular] [--offline] [--sem-capas]
                        [--sem-dat] [--mover-corrompidos] [--txt]
                        [--consoles nes,snes] [--cache-capas <pasta>]
  python limpar-roms.py --atualizar-dats      # só atualiza ferramentas\\roms\\dats\\
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import re
import shutil
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
import zipfile
import zlib
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path

VERSAO = "1.2"

# Brasil não tem horário de verão desde 2019: Brasília = UTC-3 fixo.
# (Evita depender do pacote tzdata, que não vem no Python do Windows.)
FUSO_BRASILIA = timezone(timedelta(hours=-3), "BRT")

PASTA_SCRIPT = Path(__file__).resolve().parent
CACHE_PADRAO = PASTA_SCRIPT / ".cache"
PASTA_DATS = PASTA_SCRIPT / "dats"                 # DATs versionadas no git
CACHE_CAPAS_PADRAO = CACHE_PADRAO / "capas"        # fora do git (.gitignore)

URL_DAT = "https://raw.githubusercontent.com/libretro/libretro-database/{ref}/metadat/{tipo}/{arquivo}.dat"
URL_COMMIT_DB = "https://api.github.com/repos/libretro/libretro-database/commits/master"
URL_CAPA = "https://thumbnails.libretro.com/{sistema}/Named_Boxarts/{nome}.png"
AGENTE_HTTP = "arcadia-limpar-roms/" + VERSAO
DIAS_VALIDADE_DAT = 30
LIMITE_DAT_TEXTO = 50 * 1024 * 1024   # acima disso a DAT é guardada em .zip

# DATs guardadas no repositório (consoles da paleta do Arcádia).
DATS_PALETA = [
    ("no-intro", "Atari - 2600"),
    ("no-intro", "Atari - 7800"),
    ("no-intro", "Nintendo - Nintendo Entertainment System"),
    ("no-intro", "Nintendo - Family Computer Disk System"),
    ("no-intro", "Nintendo - Super Nintendo Entertainment System"),
    ("no-intro", "Nintendo - Nintendo 64"),
    ("no-intro", "Nintendo - Game Boy"),
    ("no-intro", "Nintendo - Game Boy Color"),
    ("no-intro", "Nintendo - Game Boy Advance"),
    ("no-intro", "Sega - Master System - Mark III"),
    ("no-intro", "Sega - Mega Drive - Genesis"),
    ("no-intro", "Sega - 32X"),
    ("no-intro", "Sega - Game Gear"),
    ("no-intro", "NEC - PC Engine - TurboGrafx 16"),
    ("no-intro", "NEC - PC Engine SuperGrafx"),
    ("no-intro", "SNK - Neo Geo Pocket"),
    ("no-intro", "SNK - Neo Geo Pocket Color"),
    ("no-intro", "Bandai - WonderSwan"),
    ("no-intro", "Bandai - WonderSwan Color"),
    ("no-intro", "Microsoft - MSX"),
    ("no-intro", "Microsoft - MSX2"),
    ("redump", "Sega - Mega-CD - Sega CD"),
    ("redump", "Sony - PlayStation"),
    ("redump", "NEC - PC Engine CD - TurboGrafx-CD"),
]

# Número de jogadores (campo <players> do gamelist.xml):
#  1) dats\maxusers\<DAT>.dat — pasta metadat/maxusers do libretro-database (por CRC);
#  2) listas de multitap do Arcádia (ferramentas\multijogador\listas), que também
#     cobrem o PlayStation (não há maxusers de discos).
PASTA_MAXUSERS = PASTA_DATS / "maxusers"
PASTA_LISTAS_MJ = PASTA_SCRIPT.parent / "multijogador" / "listas"
DATS_SEM_MAXUSERS = {"Sega - Mega-CD - Sega CD", "Sony - PlayStation"}
LISTA_MJ_DA_DAT = {
    "Nintendo - Super Nintendo Entertainment System": "snes",
    "Sega - Mega Drive - Genesis": "megadrive",
    "Sony - PlayStation": "psx",
}

# Modo offline: quando True, qualquer tentativa de acesso à rede é bloqueada.
OFFLINE = False
ACESSOS_REDE: list[str] = []   # URLs acessadas nesta execução (vai para o relatório)

# --------------------------------------------------------------------------
# Mapeamento console -> DAT / nome libretro / extensões / checagem de cabeçalho
# --------------------------------------------------------------------------

EXT_DISCO = {"cue", "bin", "img", "iso", "chd", "m3u", "gdi", "cdi", "pbp",
             "ccd", "sub", "mdf", "mds", "ecm", "cso", "toc", "raw"}
EXT_COMPACTADOS = {"zip", "7z"}


@dataclass
class Sistema:
    tipo_dat: str | None          # "no-intro", "redump" ou None
    dat: str | None               # nome do arquivo .dat (sem extensão)
    libretro: str | None          # nome do sistema no libretro-thumbnails
    exts: set                     # extensões de jogo aceitas (sem ponto)
    cabecalho: str | None = None  # tipo de checagem de cabeçalho
    arcade: bool = False          # romsets de arcade: não agrupa versões


def _s(tipo, dat, exts, cab=None, libretro=None, arcade=False):
    return Sistema(tipo, dat, libretro or dat, set(exts.split()), cab, arcade)


_NES = _s("no-intro", "Nintendo - Nintendo Entertainment System", "nes unh unf", "nes")
_SNES = _s("no-intro", "Nintendo - Super Nintendo Entertainment System", "sfc smc fig swc bs", "snes")
_MD = _s("no-intro", "Sega - Mega Drive - Genesis", "md gen bin smd 68k sgd", "md")
_SMS = _s("no-intro", "Sega - Master System - Mark III", "sms bin")
_GG = _s("no-intro", "Sega - Game Gear", "gg bin")
_SEGACD = _s("redump", "Sega - Mega-CD - Sega CD", " ".join(EXT_DISCO))
_32X = _s("no-intro", "Sega - 32X", "32x bin md")
_PCE = _s("no-intro", "NEC - PC Engine - TurboGrafx 16", "pce bin")
_PCECD = _s("redump", "NEC - PC Engine CD - TurboGrafx-CD", " ".join(EXT_DISCO))
_LYNX = _s("no-intro", "Atari - Lynx", "lnx lyx o", "lnx")
_NEOCD = _s("redump", "SNK - Neo Geo CD", " ".join(EXT_DISCO))
_WS = _s("no-intro", "Bandai - WonderSwan", "ws")
_WSC = _s("no-intro", "Bandai - WonderSwan Color", "wsc")
_COLECO = _s("no-intro", "Coleco - ColecoVision", "col bin rom")
_SG = _s("no-intro", "Sega - SG-1000", "sg bin")
_O2 = _s("no-intro", "Magnavox - Odyssey2", "bin")
_JAG = _s("no-intro", "Atari - Jaguar", "j64 jag rom bin abs cof")
_AMIGA = _s("no-intro", "Commodore - Amiga", "adf ipf dms adz lha hdf")
_GC = _s("redump", "Nintendo - GameCube", "iso gcm rvz ciso gcz")

SISTEMAS: dict[str, Sistema] = {
    "nes": _NES, "famicom": _NES,
    "fds": _s("no-intro", "Nintendo - Family Computer Disk System", "fds", "fds"),
    "snes": _SNES, "sfc": _SNES, "superfamicom": _SNES, "snesna": _SNES,
    "satellaview": _s("no-intro", "Nintendo - Satellaview", "bs sfc smc"),
    "sufami": _s("no-intro", "Nintendo - Sufami Turbo", "st sfc smc"),
    "n64": _s("no-intro", "Nintendo - Nintendo 64", "n64 z64 v64", "n64"),
    "n64dd": _s("no-intro", "Nintendo - Nintendo 64DD", "ndd"),
    "gb": _s("no-intro", "Nintendo - Game Boy", "gb sgb", "gb"),
    "gbc": _s("no-intro", "Nintendo - Game Boy Color", "gbc gb", "gb"),
    "gba": _s("no-intro", "Nintendo - Game Boy Advance", "gba", "gba"),
    "nds": _s("no-intro", "Nintendo - Nintendo DS", "nds"),
    "virtualboy": _s("no-intro", "Nintendo - Virtual Boy", "vb vboy"),
    "pokemini": _s("no-intro", "Nintendo - Pokemon Mini", "min"),
    "megadrive": _MD, "genesis": _MD, "md": _MD, "megadrive-japan": _MD,
    "mastersystem": _SMS, "sms": _SMS,
    "gamegear": _GG, "gg": _GG,
    "sg1000": _SG, "sg-1000": _SG,
    "sega32x": _32X, "32x": _32X,
    "segacd": _SEGACD, "megacd": _SEGACD,
    "pico": _s("no-intro", "Sega - PICO", "md bin"),
    "saturn": _s("redump", "Sega - Saturn", " ".join(EXT_DISCO)),
    "dreamcast": _s("redump", "Sega - Dreamcast", " ".join(EXT_DISCO)),
    "psx": _s("redump", "Sony - PlayStation", " ".join(EXT_DISCO)),
    "ps2": _s("redump", "Sony - PlayStation 2", " ".join(EXT_DISCO | {"gz"})),
    "psp": _s("redump", "Sony - PlayStation Portable", "iso cso pbp chd"),
    "pcengine": _PCE, "tg16": _PCE, "turbografx16": _PCE,
    "pcenginecd": _PCECD, "tg16cd": _PCECD, "tgcd": _PCECD,
    "supergrafx": _s("no-intro", "NEC - PC Engine SuperGrafx", "sgx pce"),
    "pcfx": _s("redump", "NEC - PC-FX", " ".join(EXT_DISCO)),
    "neogeo": _s(None, None, "zip 7z", libretro="SNK - Neo Geo", arcade=True),
    "neogeocd": _NEOCD, "neocd": _NEOCD,
    "ngp": _s("no-intro", "SNK - Neo Geo Pocket", "ngp"),
    "ngpc": _s("no-intro", "SNK - Neo Geo Pocket Color", "ngc ngpc"),
    "atari2600": _s("no-intro", "Atari - 2600", "a26 bin"),
    "atari5200": _s("no-intro", "Atari - 5200", "a52 bin car"),
    "atari7800": _s("no-intro", "Atari - 7800", "a78 bin", "a78"),
    "atari800": _s("no-intro", "Atari - 8-bit Family", "xex atr atx car rom bin"),
    "atarilynx": _LYNX, "lynx": _LYNX,
    "jaguar": _JAG, "atarijaguar": _JAG,
    "atarist": _s("no-intro", "Atari - ST", "st msa stx dim ipf"),
    "wonderswan": _WS, "wswan": _WS,
    "wonderswancolor": _WSC, "wswanc": _WSC,
    "colecovision": _COLECO, "coleco": _COLECO,
    "intellivision": _s("no-intro", "Mattel - Intellivision", "int bin rom"),
    "vectrex": _s("no-intro", "GCE - Vectrex", "vec bin"),
    "odyssey2": _O2, "o2em": _O2,
    "videopac": _s("no-intro", "Philips - Videopac+", "bin"),
    "channelf": _s("no-intro", "Fairchild - Channel F", "chf bin"),
    "msx": _s("no-intro", "Microsoft - MSX", "rom mx1 mx2 dsk cas"),
    "msx1": _s("no-intro", "Microsoft - MSX", "rom mx1 mx2 dsk cas"),
    "msx2": _s("no-intro", "Microsoft - MSX2", "rom mx2 dsk cas"),
    "c64": _s("no-intro", "Commodore - 64", "d64 t64 prg crt tap g64"),
    "amiga": _AMIGA, "amiga500": _AMIGA, "amiga1200": _AMIGA, "amiga4000": _AMIGA,
    "amigacd32": _s("redump", "Commodore - CD32", " ".join(EXT_DISCO)),
    "amigacdtv": _s("redump", "Commodore - CDTV", " ".join(EXT_DISCO)),
    "3do": _s("redump", "The 3DO Company - 3DO", " ".join(EXT_DISCO)),
    "gamecube": _GC, "gc": _GC,
    "wii": _s("redump", "Nintendo - Wii", "iso wbfs rvz ciso gcz"),
    "cdi": _s("redump", "Philips - CD-i", " ".join(EXT_DISCO)),
    "arduboy": _s("no-intro", "Arduboy Inc - Arduboy", "hex arduboy"),
    "supervision": _s("no-intro", "Watara - Supervision", "sv bin"),
    "gamecom": _s("no-intro", "Tiger - Game.com", "tgc bin"),
    "arcadia": _s("no-intro", "Emerson - Arcadia 2001", "bin"),
    "scv": _s("no-intro", "Epoch - Super Cassette Vision", "bin rom 0"),
    "gamate": _s(None, None, "bin", libretro="Bit Corporation - Gamate"),
}

# Pastas dentro de um console que nunca contêm jogos.
PASTAS_MIDIA = {"images", "videos", "manuals", "media", "downloaded_images",
                "downloaded_videos", "downloaded_media", "marquees", "snap",
                "snaps", "boxart", "boxarts", "screenshots", "titles",
                "thumbnails", "wheel", "wheels", "fanart", "maps", "bezels",
                "music", "saves", "states", "covers", "box2dfront", "box3d"}

# --------------------------------------------------------------------------
# Utilidades
# --------------------------------------------------------------------------


def agora() -> datetime:
    return datetime.now(FUSO_BRASILIA)


def tamanho_legivel(n: int) -> str:
    """Formata bytes no padrão brasileiro (vírgula decimal)."""
    unidades = ["B", "KB", "MB", "GB", "TB"]
    v = float(n)
    for u in unidades:
        if v < 1024 or u == unidades[-1]:
            if u == "B":
                return f"{int(v)} B"
            return f"{v:.1f} {u}".replace(".", ",")
        v /= 1024
    return f"{n} B"


def ext_de(p: Path | str) -> str:
    return str(p).rsplit(".", 1)[-1].lower() if "." in str(p) else ""


def norm_rel(caminho: str) -> str:
    """Normaliza um <path> do gamelist para comparação (Windows: sem caixa)."""
    c = caminho.strip().replace("\\", "/")
    while c.startswith("./"):
        c = c[2:]
    return c.casefold()


def log(msg: str = "") -> None:
    print(msg, flush=True)


# --------------------------------------------------------------------------
# Nomes: tags, normalização e classificação de versões
# --------------------------------------------------------------------------

RE_TAG = re.compile(r"\(([^()]*)\)|\[([^\[\]]*)\]")
RE_DISCO = re.compile(r"[\(\[]\s*(?:disc|disk|cd|disco|side|lado)\s*([0-9a-z]+)(?:\s*(?:of|de)\s*\d+)?\s*[\)\]]", re.I)

REG_EUA = {"usa", "u", "us", "world", "w", "canada", "america", "north america"}
REG_EUR = {"europe", "e", "eu", "eur", "germany", "g", "france", "f", "spain", "s",
           "italy", "i", "uk", "united kingdom", "netherlands", "sweden",
           "scandinavia", "australia", "a", "nordic", "greece", "finland",
           "denmark", "norway", "portugal", "belgium", "switzerland", "austria",
           "poland", "russia", "croatia", "ireland"}
REG_JAP = {"japan", "j", "jp", "jpn"}
REG_BR = {"brazil", "brasil", "b", "br"}
REG_OUTRAS = {"korea", "k", "china", "c", "asia", "taiwan", "hong kong", "hk", "india"}

# Ordem de região (menor = melhor). PT-BR é tratado à parte (critério 1).
RANK_EUA, RANK_EUR, RANK_SEM, RANK_JAP, RANK_OUTRA = 1, 2, 3, 4, 5
ROTULO_RANK = {0: "PT-BR", RANK_EUA: "EUA/Mundo", RANK_EUR: "Europa",
               RANK_SEM: "sem região", RANK_JAP: "Japão", RANK_OUTRA: "outra região"}

RE_PTBR = [
    re.compile(r"\bpt[-_ ]?br\b", re.I),
    re.compile(r"\bbr[-_ ]?pt\b", re.I),
    re.compile(r"\[\s*t\s*[+\-]?\s*(por|bra|ptbr|pt-br|br)\b", re.I),
    re.compile(r"\btraduzid[oa]s?\b", re.I),
    re.compile(r"\btradu[cç](ao|ão)\b", re.I),
    re.compile(r"\bportugu[eê]s\b", re.I),
]
RE_TRAD_OUTRA = re.compile(r"\[\s*t\s*[+\-]?\s*(?!por|bra|pt|br)[a-z]{2,}", re.I)
RE_HACK = [
    re.compile(r"\bhack(ed)?\b", re.I),
    re.compile(r"\[h[0-9a-z]*\]", re.I),          # GoodTools [h], [h1], [hM04]
    re.compile(r"\[t\d*\]", re.I),                 # trainer
    re.compile(r"\((translated|traduc|traduit|tradotto)[^)]*\)", re.I),
]
RE_RUIM = re.compile(r"\[(b|o)\d*[^\]]*\]", re.I)  # bad dump / overdump
RE_VERIFICADO = re.compile(r"\[!\]")
RE_ALT = re.compile(r"\[a\d*\]|\(\s*alt[^)]*\)", re.I)
PRE_LANC = ("beta", "proto", "demo", "sample", "kiosk", "preview", "promo",
            "pirate", "alpha", "trial", "debug", "pre-release", "prerelease")


RE_MARCA_PT = re.compile(r"\b(pt[-_ ]?br|br[-_ ]?pt|traduzid[oa]s?|tradu[cç](?:ao|ão)|portugu[eê]s)\b", re.I)


def tags_de(nome: str) -> list[str]:
    return [(a or b).strip() for a, b in RE_TAG.findall(nome)]


def titulo_limpo(nome: str) -> str:
    """Nome sem tags entre parênteses/colchetes (para exibição)."""
    t = re.sub(r"\s*(\([^()]*\)|\[[^\[\]]*\])", "", nome)
    t = re.sub(r"\s+", " ", t).strip(" -_.")
    return t or nome


def chave_jogo(nome: str) -> str:
    """Chave de agrupamento: título normalizado + número do disco (se houver)."""
    t = titulo_limpo(nome)
    # Marcas de tradução escritas fora de tags ("Jogo PTBR", "Jogo - Português")
    t = RE_MARCA_PT.sub(" ", t).strip(" -_.") or t
    t = unicodedata.normalize("NFKD", t)
    t = "".join(c for c in t if not unicodedata.combining(c)).lower()
    t = t.replace("&", " and ")
    # "Legend of Zelda, The" -> "the legend of zelda"
    m = re.match(r"^(.*),\s*(the|a|an|o|os|as|el|la|los|las|le|les|der|die|das)$", t)
    if m:
        t = f"{m.group(2)} {m.group(1)}"
    t = re.sub(r"[^a-z0-9]+", " ", t).strip()
    d = RE_DISCO.search(nome)
    if d:
        t += f" #disco{d.group(1).lower()}"
    return t


@dataclass
class Classe:
    ptbr: bool = False
    hack: bool = False
    prelanc: bool = False
    regiao: int = RANK_SEM
    rev: tuple = (0, 0, 0)
    verificado: bool = False
    alt: bool = False
    ruim: bool = False

    def rotulo(self) -> str:
        partes = ["PT-BR" if self.ptbr else ROTULO_RANK[self.regiao]]
        if self.hack:
            partes.append("hack")
        if self.prelanc:
            partes.append("pré-lançamento")
        if self.ruim:
            partes.append("dump ruim")
        if self.verificado:
            partes.append("[!]")
        rev, vnum, prg = self.rev
        if rev:
            partes.append(f"Rev {rev}")
        if vnum:
            v = [vnum // 1000 ** (3 - i) % 1000 for i in range(4)]
            while len(v) > 2 and v[-1] == 0:
                v.pop()
            partes.append("v" + ".".join(str(x) for x in v))
        if prg:
            partes.append(f"PRG{prg}")
        return ", ".join(partes)


def _revisao(texto_tags: str) -> tuple:
    rev = 0
    m = re.search(r"\brev\s*([0-9]+|[a-z])\b", texto_tags, re.I)
    if m:
        g = m.group(1)
        rev = int(g) if g.isdigit() else ord(g.lower()) - 96
    vnum = 0
    m = re.search(r"\bv\s?(\d+(?:\.\d+){0,3})", texto_tags, re.I)
    if m:
        partes = [int(x) for x in m.group(1).split(".")][:4]
        for i, p in enumerate(partes):
            vnum += min(p, 999) * (1000 ** (3 - i))
    prg = 0
    m = re.search(r"\bprg\s?(\d+)", texto_tags, re.I)
    if m:
        prg = int(m.group(1))
    return (rev, vnum, prg)


def classificar(nome_arquivo: str, nome_dat: str | None) -> Classe:
    """Classifica a versão pelo nome do arquivo; se o arquivo não tiver tags,
    usa as tags do nome da DAT (região, revisão, status)."""
    base = nome_arquivo
    if not tags_de(nome_arquivo) and nome_dat:
        base = nome_dat
    c = Classe()
    tags = tags_de(base)
    texto_tags = " ".join(tags)
    c.ptbr = any(r.search(nome_arquivo) for r in RE_PTBR)
    c.hack = bool(any(r.search(base) for r in RE_HACK) or RE_TRAD_OUTRA.search(base))
    c.ruim = bool(RE_RUIM.search(base))
    c.verificado = bool(RE_VERIFICADO.search(base))
    c.alt = bool(RE_ALT.search(base))
    c.rev = _revisao(texto_tags)
    melhor = None
    for paren, colchete in RE_TAG.findall(base):
        if colchete:
            # Colchetes ([!], [b1], [h], [T-Por]...) não indicam região.
            if colchete.strip().lower().startswith(PRE_LANC):
                c.prelanc = True
            continue
        for tok in [t.strip() for t in paren.split(",")]:
            low = tok.lower()
            if low.startswith(PRE_LANC):
                c.prelanc = True
            rk = None
            if low in REG_BR:
                c.ptbr = True
            elif low in REG_EUA:
                rk = RANK_EUA
            elif low in REG_EUR:
                rk = RANK_EUR
            elif low in REG_JAP:
                rk = RANK_JAP
            elif low in REG_OUTRAS:
                rk = RANK_OUTRA
            elif re.fullmatch(r"[JUEBKCGFSIA]{2,4}", tok) and set(tok) & set("JUE"):  # GoodTools: (JUE), (UE)
                letras = set(tok)
                if "B" in letras:
                    c.ptbr = True
                rk = (RANK_EUA if "U" in letras else RANK_EUR if letras & set("EGFSIA")
                      else RANK_JAP if "J" in letras else RANK_OUTRA)
            if rk is not None:
                melhor = rk if melhor is None else min(melhor, rk)
    if "[p" in base.lower() and re.search(r"\[p\d*\]", base, re.I):
        c.prelanc = True                                      # GoodTools pirata
    c.regiao = melhor if melhor is not None else RANK_SEM
    if c.ptbr:
        c.hack = bool(re.search(r"\bhack(ed)?\b", base, re.I))  # tradução PT não conta como hack
    return c


def ordem(u: "Unidade") -> tuple:
    """Chave de ordenação (menor = melhor versão)."""
    return ordem_de(u.classe, u.nome)


def ordem_de(c: Classe, nome: str) -> tuple:
    return (1 if c.ruim else 0,
            0 if c.ptbr else 1,
            1 if c.hack else 0,
            1 if c.prelanc else 0,
            0 if c.ptbr else c.regiao,
            -c.rev[0], -c.rev[1], -c.rev[2],
            0 if c.verificado else 1,
            1 if c.alt else 0,
            len(nome), nome.casefold())


CRITERIOS = [
    (0, "dump sem marca de 'ruim' ([b]/[o]) preferido"),
    (1, "tradução PT-BR tem prioridade"),
    (2, "versão original preferida a hack/tradução não-PT"),
    (3, "versão final preferida a Beta/Proto/Demo/Pirata"),
    (4, None),  # região: texto montado dinamicamente
    (5, "revisão mais nova"), (6, "versão mais nova"), (7, "revisão PRG mais nova"),
    (8, "dump verificado [!] preferido"),
    (9, "versão principal preferida a alternativa [a]"),
    (10, "desempate: nome mais curto"), (11, "desempate: ordem alfabética"),
]


def explicar(perdedor: "Unidade", vencedor: "Unidade") -> str:
    a, b = ordem(perdedor), ordem(vencedor)
    for i, txt in CRITERIOS:
        if a[i] != b[i]:
            if i == 4:
                return (f"região {ROTULO_RANK[vencedor.classe.regiao]} preferida a "
                        f"{ROTULO_RANK[perdedor.classe.regiao]}")
            return txt
    return "versões equivalentes (mantida a primeira)"


# --------------------------------------------------------------------------
# DATs (No-Intro / Redump do libretro-database)
# --------------------------------------------------------------------------

RE_DAT_GAME_NAME = re.compile(r'^\s*name\s+"(.*)"\s*$')
RE_DAT_ROM = re.compile(r'rom\s*\(\s*name\s+"(.+?)"\s+size\s+(\d+)\s+crc\s+([0-9A-Fa-f]{8})')


class IndiceDat:
    def __init__(self, nome: str):
        self.nome = nome
        self.por_crc: dict[tuple, tuple] = {}     # (tamanho, CRC) -> (jogo, rom_sem_ext)
        self.por_titulo: dict[str, list] = {}     # chave_jogo -> [(jogo, rom_sem_ext)]

    @classmethod
    def carregar(cls, caminho: Path, nome: str) -> "IndiceDat":
        """Lê uma DAT clrmamepro em texto (.dat) ou compactada (.zip com o .dat)."""
        if ext_de(caminho) == "zip":
            with zipfile.ZipFile(caminho) as z:
                membros = [i for i in z.infolist() if i.filename.lower().endswith(".dat")]
                if not membros:
                    raise RuntimeError("o .zip não contém nenhum .dat")
                with z.open(membros[0]) as bruto:
                    return cls._ler(io.TextIOWrapper(bruto, encoding="utf-8", errors="replace"), nome)
        with open(caminho, encoding="utf-8", errors="replace") as f:
            return cls._ler(f, nome)

    @classmethod
    def _ler(cls, f, nome: str) -> "IndiceDat":
        idx = cls(nome)
        jogo = None
        for linha in f:
            s = linha.strip()
            if s.startswith("game (") or s == "game (":
                jogo = None
                continue
            if jogo is None:
                m = RE_DAT_GAME_NAME.match(linha)
                if m:
                    jogo = m.group(1)
                    continue
            m = RE_DAT_ROM.search(linha)
            if m and jogo:
                rom = m.group(1)
                rom_stem = rom.rsplit(".", 1)[0] if "." in rom else rom
                chave = (int(m.group(2)), m.group(3).upper())
                idx.por_crc.setdefault(chave, (jogo, rom_stem))
                lst = idx.por_titulo.setdefault(chave_jogo(jogo), [])
                if (jogo, rom_stem) not in lst:
                    lst.append((jogo, rom_stem))
        return idx


def dat_local(pasta: Path, tipo: str, nome: str) -> Path | None:
    """DAT guardada no repositório: dats\\<tipo>\\<nome>.dat|.zip (ou direto em dats\\)."""
    for base in (pasta / tipo, pasta):
        for ext in (".dat", ".zip"):
            p = base / f"{nome}{ext}"
            if p.is_file():
                return p
    return None


class GerenciadorDats:
    """Ordem de busca: 1) dats\\ do repositório; 2) cache .cache\\dats\\ (baixadas
    antes); 3) download do libretro-database (nunca no modo offline)."""

    def __init__(self, pasta_cache: Path, ativo: bool, forcar: bool,
                 offline: bool = False, pasta_local: Path = PASTA_DATS):
        self.pasta = pasta_cache / "dats"
        self.local = pasta_local
        self.ativo = ativo
        self.forcar = forcar
        self.offline = offline
        self.indices: dict[str, IndiceDat | None] = {}
        self.origens: dict[str, str] = {}
        self.avisos: list[str] = []

    def obter(self, sis: Sistema) -> IndiceDat | None:
        if not self.ativo or not sis.dat or not sis.tipo_dat:
            return None
        if sis.dat in self.indices:
            return self.indices[sis.dat]
        local = dat_local(self.local, sis.tipo_dat, sis.dat)
        if local:
            return self._carregar(sis, local, "repositório: " + local.relative_to(self.local.parent).as_posix())
        arq = self.pasta / f"{sis.dat}.dat"
        if self.offline:
            if arq.exists():
                return self._carregar(sis, arq, "cache local: .cache/dats/" + arq.name)
            msg = f"Sem DAT local para '{sis.dat}' (modo offline: não baixada)"
            self.avisos.append(msg)
            log("  AVISO: " + msg)
            self.indices[sis.dat] = None
            return None
        velho = (not arq.exists()) or self.forcar or \
            (time.time() - arq.stat().st_mtime > DIAS_VALIDADE_DAT * 86400)
        origem = "cache local: .cache/dats/" + arq.name
        if velho:
            url = URL_DAT.format(ref="master", tipo=sis.tipo_dat, arquivo=urllib.parse.quote(sis.dat))
            origem = "baixada agora do libretro-database → .cache/dats/" + arq.name
            log(f"  baixando DAT {sis.tipo_dat}/{sis.dat}.dat ...")
            try:
                self.pasta.mkdir(parents=True, exist_ok=True)
                dados = http_get(url, timeout=60)
                if dados is None or b"clrmamepro" not in dados[:200]:
                    raise RuntimeError("resposta inesperada")
                tmp = arq.with_suffix(".dat.part")
                tmp.write_bytes(dados)
                os.replace(tmp, arq)
            except Exception as e:  # noqa: BLE001
                msg = f"Não foi possível baixar a DAT '{sis.dat}': {e}"
                origem = "cache local antigo: .cache/dats/" + arq.name
                if arq.exists():
                    msg += " (usando a cópia antiga do cache)"
                self.avisos.append(msg)
                log("  AVISO: " + msg)
        if not arq.exists():
            self.indices[sis.dat] = None
            return None
        return self._carregar(sis, arq, origem)

    def _carregar(self, sis: Sistema, arq: Path, origem: str) -> IndiceDat | None:
        try:
            idx = IndiceDat.carregar(arq, sis.dat)
            self.origens[sis.dat] = origem
        except Exception as e:  # noqa: BLE001
            self.avisos.append(f"DAT '{sis.dat}' ilegível ({arq}): {e}")
            idx = None
        self.indices[sis.dat] = idx
        return idx


def chave_mj(titulo: str) -> str:
    """Mesma normalização de ferramentas\\multijogador (montar-listas.py e o aparelho)."""
    t = re.sub(r"\([^)]*\)", "", titulo)
    t = re.sub(r"\[[^\]]*\]", "", t)
    t = t.lower().replace("&", "and")
    t = re.sub(r"^\s*the\s+", "", t)
    t = re.sub(r",\s*the(\s|-|$)", r"\1", t)
    return re.sub(r"[^a-z0-9]", "", t)


class IndiceJogadores:
    """Quantos jogadores cada jogo aceita: maxusers do libretro-database (por CRC e
    por nome) + listas de multitap do Arcádia (por título normalizado)."""

    def __init__(self):
        self.por_crc: dict[str, int] = {}
        self.por_nome: dict[str, int] = {}
        self.por_chave: dict[str, int] = {}
        self.origens: list[str] = []

    @classmethod
    def carregar(cls, sis: Sistema) -> "IndiceJogadores | None":
        if not sis.dat:
            return None
        idx = cls()
        arq = PASTA_MAXUSERS / f"{sis.dat}.dat"
        if arq.is_file():
            jogo = None
            for linha in arq.read_text(encoding="utf-8", errors="replace").splitlines():
                m = re.match(r'\s*comment\s+"(.*)"\s*$', linha)
                if m:
                    jogo = m.group(1)
                    continue
                m = re.match(r"\s*users\s+(\d+)", linha)
                if m and jogo:
                    idx.por_nome[jogo] = int(m.group(1))
                    idx.por_chave.setdefault(chave_mj(jogo), int(m.group(1)))
                    continue
                m = re.search(r"crc\s+([0-9A-Fa-f]{8})", linha)
                if m and jogo and jogo in idx.por_nome:
                    idx.por_crc[m.group(1).upper()] = idx.por_nome[jogo]
            idx.origens.append("dats/maxusers/" + arq.name)
        lista = LISTA_MJ_DA_DAT.get(sis.dat)
        arq_mj = PASTA_LISTAS_MJ / f"{lista}.txt" if lista else None
        if arq_mj and arq_mj.is_file():
            for linha in arq_mj.read_text(encoding="utf-8").splitlines():
                if linha.startswith("#") or "|" not in linha:
                    continue
                k, _, qtd, _ = (linha.split("|") + ["", "", ""])[:4]
                if qtd.isdigit():
                    # a lista de multitap tem prioridade: é o máximo com o adaptador
                    idx.por_chave[k] = max(int(qtd), idx.por_chave.get(k, 0))
            idx.origens.append("multijogador/listas/" + arq_mj.name)
        return idx if idx.origens else None

    def jogadores(self, u: "Unidade") -> int | None:
        k = chave_mj(u.dat_jogo or u.stem)
        lista = self.por_chave.get(k) if k else None
        base = None
        for _, crc in u.crcs:
            if crc in self.por_crc:
                base = self.por_crc[crc]
                break
        if base is None and u.dat_jogo:
            base = self.por_nome.get(u.dat_jogo)
        if base is None:
            base = lista
        elif lista:
            base = max(base, lista)
        return base


def texto_jogadores(n: int) -> str:
    """Formato do <players> do EmulationStation: "1" ou "1-4"."""
    return "1" if n <= 1 else f"1-{n}"


def atualizar_dats_repositorio(pasta: Path = PASTA_DATS) -> int:
    """Baixa de novo as DATs da paleta para ferramentas\\roms\\dats\\ (versionadas
    no git), todas do MESMO commit do libretro-database, e grava VERSAO.txt.
    DAT com mais de 50 MB é guardada como .zip. Retorna a quantidade de erros."""
    if OFFLINE:
        log("ERRO: --atualizar-dats precisa de internet (não combina com --offline).")
        return 1
    log("Atualizando DATs do repositório (libretro-database) ...")
    try:
        info = json.loads(http_get(URL_COMMIT_DB, timeout=60) or b"{}")
        ref = info["sha"]
        data_commit = info["commit"]["committer"]["date"]
    except Exception as e:  # noqa: BLE001
        log(f"  AVISO: não foi possível descobrir o commit atual ({e}); usando 'master'")
        ref, data_commit = "master", "?"
    erros = 0
    linhas = []
    for tipo, nome in DATS_PALETA:
        url = URL_DAT.format(ref=ref, tipo=tipo, arquivo=urllib.parse.quote(nome))
        destino_dir = pasta / tipo
        try:
            dados = http_get(url, timeout=120)
            if dados is None or b"clrmamepro" not in dados[:300]:
                raise RuntimeError("resposta inesperada (não é DAT clrmamepro)")
            destino_dir.mkdir(parents=True, exist_ok=True)
            txt, zp = destino_dir / f"{nome}.dat", destino_dir / f"{nome}.zip"
            if len(dados) > LIMITE_DAT_TEXTO:
                tmp = zp.with_suffix(".zip.part")
                with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
                    z.writestr(f"{nome}.dat", dados)
                os.replace(tmp, zp)
                if txt.exists():
                    txt.unlink()          # substituída pelo .zip (é só um índice, não um jogo)
                final = zp
            else:
                tmp = txt.with_suffix(".dat.part")
                tmp.write_bytes(dados)
                os.replace(tmp, txt)
                if zp.exists():
                    zp.unlink()
                final = txt
            linhas.append(f"{tipo}/{final.name}\t{final.stat().st_size}")
            log(f"  ok  {tipo}/{final.name} ({tamanho_legivel(final.stat().st_size)})")
        except Exception as e:  # noqa: BLE001
            erros += 1
            linhas.append(f"{tipo}/{nome}.dat\tERRO: {e}")
            log(f"  ERRO {tipo}/{nome}: {e}")
    # número de jogadores (metadat/maxusers do mesmo commit)
    for _, nome in DATS_PALETA:
        if nome in DATS_SEM_MAXUSERS:
            continue
        url = URL_DAT.format(ref=ref, tipo="maxusers", arquivo=urllib.parse.quote(nome))
        try:
            dados = http_get(url, timeout=120)
            if dados is None or b"clrmamepro" not in dados[:300]:
                raise RuntimeError("resposta inesperada (não é DAT clrmamepro)")
            (pasta / "maxusers").mkdir(parents=True, exist_ok=True)
            destino = pasta / "maxusers" / f"{nome}.dat"
            tmp = destino.with_suffix(".dat.part")
            tmp.write_bytes(dados)
            os.replace(tmp, destino)
            linhas.append(f"maxusers/{destino.name}\t{destino.stat().st_size}")
            log(f"  ok  maxusers/{destino.name} ({tamanho_legivel(destino.stat().st_size)})")
        except Exception as e:  # noqa: BLE001
            erros += 1
            linhas.append(f"maxusers/{nome}.dat\tERRO: {e}")
            log(f"  ERRO maxusers/{nome}: {e}")
    (pasta / "VERSAO.txt").write_text(
        "Origem: https://github.com/libretro/libretro-database (pasta metadat/)\n"
        f"Commit: {ref} ({data_commit})\n"
        f"Atualizado em: {agora().strftime('%d/%m/%Y %H:%M')} (horário de Brasília)\n"
        "Arquivos (tamanho em bytes):\n" + "\n".join(linhas) + "\n",
        encoding="utf-8")
    log(f"DATs atualizadas: {len(linhas) - erros} ok, {erros} erro(s). Versão em {pasta / 'VERSAO.txt'}")
    return erros


# --------------------------------------------------------------------------
# HTTP
# --------------------------------------------------------------------------

class AcessoRedeBloqueado(RuntimeError):
    pass


def _req(url: str, metodo: str = "GET") -> urllib.request.Request:
    if OFFLINE:
        raise AcessoRedeBloqueado(f"modo offline: acesso à rede bloqueado ({url})")
    ACESSOS_REDE.append(url)
    return urllib.request.Request(url, method=metodo, headers={"User-Agent": AGENTE_HTTP})


def http_get(url: str, timeout: int = 30) -> bytes | None:
    """Retorna o conteúdo ou None se 404. Outras falhas levantam exceção."""
    try:
        with urllib.request.urlopen(_req(url), timeout=timeout) as r:
            return r.read()
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise


def http_existe(url: str, timeout: int = 20) -> bool:
    try:
        with urllib.request.urlopen(_req(url, "HEAD"), timeout=timeout) as r:
            return r.status == 200
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return False
        raise


# --------------------------------------------------------------------------
# Unidades (um "jogo" = 1 arquivo, ou conjunto .m3u/.cue/.bin/.gdi)
# --------------------------------------------------------------------------

@dataclass
class Unidade:
    console: str
    raiz: Path                      # pasta do console
    principal: Path
    membros: list = field(default_factory=list)
    dados: list = field(default_factory=list)   # arquivos com conteúdo (p/ hash)
    tamanho: int = 0
    problemas: list = field(default_factory=list)
    identidade: tuple | None = None
    crcs: list = field(default_factory=list)     # [(tamanho, CRC)] p/ DAT
    dat_jogo: str | None = None
    dat_rom: str | None = None
    classe: Classe = field(default_factory=Classe)
    chaves: set = field(default_factory=set)
    destino: Path | None = None
    motivo: str = ""
    ficou: "Unidade | None" = None
    sem_hash: bool = False

    @property
    def nome(self) -> str:
        return self.principal.name

    @property
    def stem(self) -> str:
        return self.principal.stem

    def rel(self, p: Path | None = None) -> str:
        return (p or self.principal).relative_to(self.raiz).as_posix()


def listar_arquivos(raiz: Path, sis: Sistema) -> tuple[list[Path], int]:
    """Arquivos de jogo do console (recursivo, ignorando pastas de mídia)."""
    aceitas = sis.exts | EXT_COMPACTADOS
    achados, ignorados = [], 0
    for pasta, subpastas, arquivos in os.walk(raiz):
        subpastas[:] = sorted(d for d in subpastas
                              if d.lower() not in PASTAS_MIDIA and not d.startswith((".", "_")))
        for nome in sorted(arquivos):
            if nome.lower().startswith("gamelist.xml") or nome.startswith("."):
                continue
            if ext_de(nome) in aceitas:
                achados.append(Path(pasta) / nome)
            else:
                ignorados += 1
    return achados, ignorados


def _mapa_pasta(pasta: Path, cache: dict) -> dict:
    """Mapa nome-minúsculo -> Path real (busca sem diferenciar maiúsculas)."""
    if pasta not in cache:
        try:
            cache[pasta] = {p.name.casefold(): p for p in pasta.iterdir()}
        except OSError:
            cache[pasta] = {}
    return cache[pasta]


def _resolver(base: Path, ref: str, cache: dict) -> Path | None:
    ref = ref.strip().strip('"').replace("\\", "/")
    alvo = (base / ref)
    try:
        alvo = Path(os.path.normpath(alvo))
    except Exception:  # noqa: BLE001
        return None
    m = _mapa_pasta(alvo.parent, cache)
    return m.get(alvo.name.casefold())


def _ler_texto(p: Path) -> str:
    try:
        return p.read_bytes()[:1_000_000].decode("utf-8", errors="replace")
    except OSError:
        return ""


def referencias(p: Path, cache: dict) -> tuple[list[Path], list[str]]:
    """Arquivos referenciados por .m3u/.cue/.gdi/.ccd/.mds e os ausentes."""
    e = ext_de(p)
    achados, faltando = [], []
    refs: list[str] = []
    if e == "cue":
        for linha in _ler_texto(p).splitlines():
            m = re.match(r'\s*FILE\s+(?:"([^"]+)"|(\S+))', linha, re.I)
            if m:
                refs.append(m.group(1) or m.group(2))
    elif e == "gdi":
        for linha in _ler_texto(p).splitlines()[1:]:
            m = re.match(r'\s*\d+\s+\d+\s+\d+\s+\d+\s+(?:"([^"]+)"|(\S+))', linha)
            if m:
                refs.append(m.group(1) or m.group(2))
    elif e == "m3u":
        for linha in _ler_texto(p).splitlines():
            s = linha.strip()
            if s and not s.startswith("#"):
                refs.append(s)
    elif e in ("ccd", "mds"):
        irmaos = ["img", "sub"] if e == "ccd" else ["mdf"]
        for x in irmaos:
            alvo = _resolver(p.parent, f"{p.stem}.{x}", cache)
            if alvo:
                achados.append(alvo)
            elif x != "sub":
                faltando.append(f"{p.stem}.{x}")
        return achados, faltando
    for r in refs:
        alvo = _resolver(p.parent, r, cache)
        if alvo and alvo.is_file():
            achados.append(alvo)
        else:
            faltando.append(r)
    return achados, faltando


def montar_unidades(console: str, raiz: Path, arquivos: list[Path]) -> list[Unidade]:
    cache: dict = {}
    filhos: dict[str, list[Path]] = {}
    faltas: dict[str, list[str]] = {}
    referenciado: set[str] = set()
    for a in arquivos:
        if ext_de(a) in ("m3u", "cue", "gdi", "ccd", "mds"):
            achados, faltando = referencias(a, cache)
            k = os.path.normcase(str(a))
            filhos[k] = achados
            faltas[k] = faltando
            for f in achados:
                referenciado.add(os.path.normcase(str(f)))

    def coletar(p: Path, vistos: set) -> list[Path]:
        k = os.path.normcase(str(p))
        if k in vistos:
            return []
        vistos.add(k)
        res = [p]
        for f in filhos.get(k, []):
            res.extend(coletar(f, vistos))
        return res

    unidades = []
    for a in arquivos:
        k = os.path.normcase(str(a))
        if k in referenciado:
            continue  # faz parte de outra unidade (.bin de um .cue etc.)
        membros = coletar(a, set())
        u = Unidade(console=console, raiz=raiz, principal=a, membros=membros)
        for m in membros:
            km = os.path.normcase(str(m))
            for falta in faltas.get(km, []):
                u.problemas.append(f"{m.name} aponta para arquivo inexistente: {falta}")
        u.dados = [m for m in membros if ext_de(m) not in ("m3u", "cue", "gdi", "ccd", "mds", "toc")]
        if not u.dados and ext_de(a) in ("m3u", "cue", "gdi") and not u.problemas:
            u.problemas.append(f"{a.name} não referencia nenhum arquivo de dados")
        tam = 0
        for m in membros:
            try:
                tam += m.stat().st_size
            except OSError:
                pass
        u.tamanho = tam
        unidades.append(u)
    return unidades


# --------------------------------------------------------------------------
# Verificação de integridade, cabeçalho e hashes
# --------------------------------------------------------------------------

LOGO_GB = bytes.fromhex(
    "CEED6666CC0D000B03730083000C000D0008111F8889000EDCCC6EE6DDDDD999"
    "BBBB67636E0EECCCDDDC999FBBB9333E")
MAGIC_N64 = {b"\x80\x37\x12\x40", b"\x37\x80\x40\x12", b"\x40\x12\x37\x80"}


def tam_cabecalho_copiadora(sis: Sistema, ext: str, inicio: bytes, tamanho: int) -> int:
    """Bytes de cabeçalho a pular para casar com a versão sem cabeçalho da DAT."""
    if inicio[:4] == b"NES\x1a":
        return 16
    if inicio[:4] == b"FDS\x1a":
        return 16
    if inicio[1:10] == b"ATARI7800":
        return 128
    if inicio[:4] == b"LYNX":
        return 64
    if sis.cabecalho == "snes" and tamanho % 1024 == 512:
        return 512
    return 0


def _desintercalar_smd(dados: bytes) -> bytes:
    bloco = dados[512:512 + 16384]
    if len(bloco) < 16384:
        return b""
    saida = bytearray(16384)
    saida[1::2] = bloco[:8192]
    saida[0::2] = bloco[8192:]
    return bytes(saida)


def checar_cabecalho(sis: Sistema, ext: str, d: bytes, tamanho: int) -> str | None:
    """Retorna descrição do problema ou None se o cabeçalho parece válido."""
    tipo = sis.cabecalho
    if tipo == "nes" and ext == "nes":
        if d[:4] != b"NES\x1a":
            return "cabeçalho NES inválido (não começa com 'NES\\x1a')"
    elif tipo == "fds" and ext == "fds":
        if d[:4] != b"FDS\x1a" and d[:15] != b"\x01*NINTENDO-HVC*":
            return "cabeçalho FDS inválido"
    elif tipo == "gb" and ext in ("gb", "gbc", "sgb"):
        if len(d) < 0x150:
            return "arquivo pequeno demais para um cartucho Game Boy"
        if d[0x104:0x134] != LOGO_GB:
            return "logo da Nintendo ausente/errado no cabeçalho Game Boy (0x104)"
        x = 0
        for b in d[0x134:0x14D]:
            x = (x - b - 1) & 0xFF
        if x != d[0x14D]:
            return f"checksum do cabeçalho Game Boy inválido (esperado {x:02X}, achado {d[0x14D]:02X})"
    elif tipo == "gba" and ext == "gba":
        if len(d) < 0xC0:
            return "arquivo pequeno demais para um cartucho GBA"
        if d[4:8] != b"\x24\xFF\xAE\x51" or d[0xB2] != 0x96:
            return "logo/valor fixo do cabeçalho GBA ausente"
        chk = (-(sum(d[0xA0:0xBD])) - 0x19) & 0xFF
        if chk != d[0xBD]:
            return f"checksum do cabeçalho GBA inválido (esperado {chk:02X}, achado {d[0xBD]:02X})"
    elif tipo == "md" and ext in ("md", "gen", "bin", "smd", "sgd"):
        if b"SEGA" in d[0x100:0x110]:
            return None
        smd = ext == "smd" or (tamanho % 16384 == 512 and len(d) > 10 and d[8] == 0xAA and d[9] == 0xBB)
        if smd and b"SEGA" in _desintercalar_smd(d)[0x100:0x110]:
            return None
        return "cabeçalho Mega Drive sem 'SEGA' em 0x100 (nem formato .smd válido)"
    elif tipo == "n64" and ext in ("n64", "z64", "v64"):
        if d[:4] not in MAGIC_N64:
            return "cabeçalho Nintendo 64 inválido"
    elif tipo == "a78" and ext == "a78":
        if d[1:10] != b"ATARI7800":
            return "cabeçalho Atari 7800 (.a78) inválido"
    elif tipo == "lnx" and ext == "lnx":
        if d[:4] != b"LYNX":
            return "cabeçalho Atari Lynx (.lnx) inválido"
    return None


def _hash_fluxo(f, tamanho: int, sis: Sistema, ext: str, com_hash: bool):
    """Lê um fluxo: devolve (início, crc, crc_sem_cabecalho, pular, sha1)."""
    inicio = f.read(0x10000)
    if not com_hash:
        return inicio, None, None, 0, None
    pular = tam_cabecalho_copiadora(sis, ext, inicio, tamanho)
    sha = hashlib.sha1(inicio)
    crc = zlib.crc32(inicio)
    crc2 = zlib.crc32(inicio[pular:]) if pular else 0
    while True:
        bloco = f.read(1 << 20)
        if not bloco:
            break
        sha.update(bloco)
        crc = zlib.crc32(bloco, crc)
        if pular:
            crc2 = zlib.crc32(bloco, crc2)
    return inicio, crc, (crc2 if pular else None), pular, sha.hexdigest()


def verificar_unidade(u: Unidade, sis: Sistema, limite_hash: int) -> None:
    """Checa integridade e calcula hashes (identidade e CRCs para a DAT)."""
    ids = []
    for m in u.membros:
        try:
            if m.stat().st_size == 0:
                u.problemas.append(f"{m.name}: arquivo com tamanho zero")
        except OSError as e:
            u.problemas.append(f"{m.name}: não foi possível ler ({e})")
    if u.problemas:
        return
    for m in u.dados:
        e = ext_de(m)
        tam = m.stat().st_size
        try:
            if e == "zip":
                ids.extend(_verificar_zip(u, m, sis, limite_hash))
            elif e == "7z":
                with open(m, "rb") as f:
                    if f.read(6) != b"7z\xbc\xaf\x27\x1c":
                        u.problemas.append(f"{m.name}: não é um arquivo 7z válido (assinatura errada)")
                u.sem_hash = True   # sem biblioteca 7z na biblioteca padrão
            else:
                com_hash = tam <= limite_hash
                with open(m, "rb") as f:
                    ini, crc, crc2, pular, sha = _hash_fluxo(f, tam, sis, e, com_hash)
                prob = checar_cabecalho(sis, e, ini, tam)
                if e == "chd" and ini[:8] != b"MComprHD":
                    prob = "arquivo .chd sem assinatura 'MComprHD'"
                if e == "pbp" and ini[:4] != b"\x00PBP":
                    prob = "arquivo .pbp sem assinatura PBP"
                if prob:
                    u.problemas.append(f"{m.name}: {prob}")
                if sha:
                    ids.append((tam, sha))
                    u.crcs.append((tam, f"{crc:08X}"))
                    if crc2 is not None:
                        u.crcs.append((tam - pular, f"{crc2:08X}"))
                else:
                    u.sem_hash = True
        except OSError as ex:
            u.problemas.append(f"{m.name}: erro de leitura ({ex})")
    if ids and not u.sem_hash and not u.problemas:
        u.identidade = tuple(sorted(ids))


def _verificar_zip(u: Unidade, m: Path, sis: Sistema, limite_hash: int) -> list:
    ids = []
    if not zipfile.is_zipfile(m):
        u.problemas.append(f"{m.name}: .zip inválido (não abre como zip)")
        return ids
    try:
        with zipfile.ZipFile(m) as z:
            ruim = z.testzip()
            if ruim is not None:
                u.problemas.append(f"{m.name}: .zip corrompido (CRC errado em '{ruim}')")
                return ids
            infos = [i for i in z.infolist() if not i.is_dir()]
            if not infos:
                u.problemas.append(f"{m.name}: .zip vazio")
                return ids
            if sis.arcade:
                # romset de arcade: identidade = lista de CRCs internos
                ids.append(("zip", tuple(sorted((i.file_size, i.CRC) for i in infos))))
                return ids
            for i in infos:
                e = ext_de(i.filename)
                com_hash = i.file_size <= limite_hash
                with z.open(i) as f:
                    ini, crc, crc2, pular, sha = _hash_fluxo(f, i.file_size, sis, e, com_hash)
                if e in sis.exts:
                    prob = checar_cabecalho(sis, e, ini, i.file_size)
                    if prob:
                        u.problemas.append(f"{m.name} -> {i.filename}: {prob}")
                if sha:
                    ids.append((i.file_size, sha))
                    u.crcs.append((i.file_size, f"{crc:08X}"))
                    if crc2 is not None:
                        u.crcs.append((i.file_size - pular, f"{crc2:08X}"))
                else:
                    u.sem_hash = True
    except (zipfile.BadZipFile, zipfile.LargeZipFile, NotImplementedError, RuntimeError, OSError, EOFError) as ex:
        u.problemas.append(f"{m.name}: .zip corrompido ({ex})")
    return ids


# --------------------------------------------------------------------------
# Movimentação
# --------------------------------------------------------------------------

def planejar_destino(u: Unidade, base: Path, reservados: set) -> Path:
    """Escolhe a pasta/nome de destino sem sobrescrever nada.
    Retorna o diretório-base efetivo (para multi-arquivo) ou o caminho final
    do arquivo (unidade de 1 arquivo)."""
    rels = [m.relative_to(u.raiz) for m in u.membros]

    def livre(destinos):
        return all(not d.exists() and os.path.normcase(str(d)) not in reservados for d in destinos)

    if len(rels) == 1:
        alvo = base / rels[0]
        n = 2
        while not livre([alvo]):
            alvo = base / rels[0].parent / f"{rels[0].stem}__{n}{rels[0].suffix}"
            n += 1
        reservados.add(os.path.normcase(str(alvo)))
        return alvo
    # Vários arquivos (.cue/.bin/.m3u): mantêm nomes e estrutura relativa; em
    # colisão, a unidade inteira vai para uma subpasta numerada (_2, _3...).
    b = base
    n = 2
    while not livre([b / r for r in rels]):
        b = base / f"_{n}"
        n += 1
    for r in rels:
        reservados.add(os.path.normcase(str(b / r)))
    return b


def mover_unidade(u: Unidade, destino: Path) -> list[str]:
    erros = []
    if len(u.membros) == 1:
        pares = [(u.membros[0], destino)]
    else:
        pares = [(m, destino / m.relative_to(u.raiz)) for m in u.membros]
    for orig, dst in pares:
        try:
            if dst.exists():
                erros.append(f"destino já existe, não movido: {dst}")
                continue
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(orig), str(dst))
        except OSError as e:
            erros.append(f"falha ao mover {orig.name}: {e}")
    return erros


# --------------------------------------------------------------------------
# Capas (libretro-thumbnails)
# --------------------------------------------------------------------------

def nome_thumb(nome: str) -> str:
    return re.sub(r'[&*/:`<>?\\|"]', "_", nome)


def candidatos_capa(u: Unidade, dat: IndiceDat | None) -> list[str]:
    cands: list[str] = []
    for c in (u.dat_jogo, u.dat_rom, u.stem):
        if c and c not in cands:
            cands.append(c)
    if dat:
        # Outras versões do mesmo jogo na DAT (ex.: v1.0.1, Remix), melhores primeiro.
        irmaos = []
        for k in u.chaves:
            for jogo, rom in dat.por_titulo.get(k, []):
                irmaos.append((jogo, rom))
        def _ord(par):
            return ordem_de(classificar(par[0], None), par[0])
        for jogo, rom in sorted(set(irmaos), key=_ord)[:4]:
            for c in (jogo, rom):
                if c not in cands:
                    cands.append(c)
    return cands[:10]


def caminho_longo(p: Path) -> Path:
    """No Windows, caminhos com mais de ~260 caracteres só abrem com o prefixo
    \\\\?\\ (alguns nomes de capas do libretro-thumbnails são enormes)."""
    s = str(p)
    if os.name == "nt" and len(s) >= 240 and not s.startswith("\\\\?\\"):
        return Path("\\\\?\\" + os.path.abspath(s))
    return p


class CacheCapas:
    """Cache local: <pasta>\\<Sistema libretro>\\Named_Boxarts\\<nome>.png
    (montado por baixar-capas.py). Busca sem diferenciar maiúsculas; aceita
    também os 'links simbólicos em texto' que o git grava no Windows."""

    def __init__(self, pasta: Path):
        self.pasta = pasta
        self._indices: dict[str, dict[str, Path]] = {}
        self._por_chave: dict[str, dict[str, list[str]]] = {}

    def indice(self, sistema: str) -> dict[str, Path]:
        if sistema not in self._indices:
            d = self.pasta / sistema / "Named_Boxarts"
            idx: dict[str, Path] = {}
            try:
                for p in d.iterdir():
                    if p.suffix.lower() == ".png":
                        idx[p.stem.casefold()] = p
            except OSError:
                pass
            self._indices[sistema] = idx
        return self._indices[sistema]

    def disponivel(self, sistema: str) -> bool:
        return bool(self.indice(sistema))

    def quantidade(self, sistema: str) -> int:
        return len(self.indice(sistema))

    def achar(self, sistema: str, nome: str) -> Path | None:
        """Arquivo PNG real para o nome (já com nome_thumb aplicado), ou None."""
        p = self.indice(sistema).get(nome_thumb(nome).casefold())
        for _ in range(3):                      # segue até 3 'links em texto'
            if p is None:
                return None
            p = caminho_longo(p)
            try:
                with open(p, "rb") as f:
                    ini = f.read(512)
            except OSError:
                return None
            if ini.startswith(b"\x89PNG"):
                return p
            alvo = ini.decode("utf-8", errors="replace").strip()
            if not alvo or "\n" in alvo or len(alvo) > 400:
                return None
            p = caminho_longo(Path(os.path.normpath(p.parent / alvo)))
            if not p.is_file():
                return None
        return None

    def por_titulo(self, sistema: str, chaves: set) -> list[str]:
        """Nomes de capas do cache cujo título normalizado bate com o do jogo
        (útil para hacks/traduções e arquivos sem DAT); melhores versões primeiro."""
        if sistema not in self._por_chave:
            m: dict[str, list[str]] = {}
            for p in self.indice(sistema).values():
                m.setdefault(chave_jogo(p.stem), []).append(p.stem)
            self._por_chave[sistema] = m
        achados = set()
        for k in chaves:
            achados.update(self._por_chave[sistema].get(k, []))
        return sorted(achados, key=lambda n: ordem_de(classificar(n, None), n))


def buscar_capa(sistema_libretro: str, candidatos: list[str], destino: Path,
                simular: bool, pasta_tmp: Path, cache: "CacheCapas | None" = None,
                offline: bool = False, extras_cache: list[str] | None = None) -> tuple[str, str | None, str]:
    """Retorna (status, nome_usado, origem). status: baixada | disponivel |
    nao_encontrada | erro:...; origem: 'cache' | 'internet' | ''.
    Procura PRIMEIRO no cache local; só vai à internet se não achar e não
    estiver no modo offline."""
    if cache is not None:
        for nome in candidatos + [n for n in (extras_cache or []) if n not in candidatos]:
            achado = cache.achar(sistema_libretro, nome)
            if not achado:
                continue
            if simular:
                return "disponivel", nome, "cache"
            try:
                pasta_tmp.mkdir(parents=True, exist_ok=True)
                tmp = pasta_tmp / f"capa-{os.getpid()}-{abs(hash((str(destino), nome)))}.png"
                shutil.copyfile(achado, tmp)
                destino.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(tmp), str(destino))
                return "baixada", nome, "cache"
            except OSError as e:
                return f"erro: {e}", None, "cache"
    if offline:
        return "nao_encontrada", None, ""
    st, nome = _buscar_capa_internet(sistema_libretro, candidatos, destino, simular, pasta_tmp)
    return st, nome, ("internet" if nome else "")


def _buscar_capa_internet(sistema_libretro: str, candidatos: list[str], destino: Path,
                          simular: bool, pasta_tmp: Path) -> tuple[str, str | None]:
    for nome in candidatos:
        url = URL_CAPA.format(sistema=urllib.parse.quote(sistema_libretro),
                              nome=urllib.parse.quote(nome_thumb(nome)))
        try:
            if simular:
                if http_existe(url):
                    return "disponivel", nome
                continue
            dados = http_get(url)
            if dados is None:
                continue
            if not dados.startswith(b"\x89PNG"):
                continue
            pasta_tmp.mkdir(parents=True, exist_ok=True)
            tmp = pasta_tmp / f"capa-{os.getpid()}-{abs(hash((str(destino), nome)))}.png"
            tmp.write_bytes(dados)
            destino.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(tmp), str(destino))
            return "baixada", nome
        except Exception as e:  # noqa: BLE001
            return f"erro: {e}", None
    return "nao_encontrada", None


# --------------------------------------------------------------------------
# gamelist.xml (EmulationStation)
# --------------------------------------------------------------------------

def ler_xml(caminho: Path) -> ET.ElementTree | None:
    if not caminho.exists():
        return None
    parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    return ET.parse(caminho, parser=parser)


def escrever_xml(arvore: ET.ElementTree, caminho: Path) -> None:
    raiz = arvore.getroot()
    ET.indent(raiz, space="\t")
    texto = '<?xml version="1.0" encoding="UTF-8"?>\n' + ET.tostring(raiz, encoding="unicode") + "\n"
    # Mantém o fim de linha do original (LF por padrão, como no EmuELEC/Linux).
    fim = "\n"
    try:
        if caminho.exists() and b"\r\n" in caminho.read_bytes()[:4096]:
            fim = "\r\n"
    except OSError:
        pass
    tmp = caminho.with_name(caminho.name + ".novo")
    with open(tmp, "w", encoding="utf-8", newline=fim) as f:
        f.write(texto)
    os.replace(tmp, caminho)


def texto_filho(el: ET.Element, tag: str) -> str | None:
    f = el.find(tag)
    return f.text if f is not None and f.text else None


def definir_filho(el: ET.Element, tag: str, valor: str, depois_de: tuple = ()) -> None:
    f = el.find(tag)
    if f is None:
        f = ET.Element(tag)
        pos = len(el)
        for i, c in enumerate(list(el)):
            if c.tag in depois_de:
                pos = i + 1
        el.insert(pos, f)
    f.text = valor


@dataclass
class ResultadoGamelist:
    adicionadas: int = 0
    removidas: int = 0
    imagens: int = 0
    nomes: int = 0
    jogadores: int = 0
    backup: str | None = None
    alterado: bool = False
    erro: str | None = None


def atualizar_gamelist(raiz_console: Path, mantidas: list[Unidade], saidas: list[tuple[Unidade, str]],
                       capas: dict, pasta_removidos: Path, simular: bool, carimbo: str,
                       jogadores: "IndiceJogadores | None" = None) -> ResultadoGamelist:
    res = ResultadoGamelist()
    arq = raiz_console / "gamelist.xml"
    try:
        arvore = ler_xml(arq)
    except ET.ParseError as e:
        res.erro = f"gamelist.xml inválido, não alterado ({e})"
        return res
    if arvore is None:
        arvore = ET.ElementTree(ET.Element("gameList"))
    raiz = arvore.getroot()
    entradas = {}
    for g in raiz.findall("game"):
        p = texto_filho(g, "path")
        if p:
            entradas.setdefault(norm_rel(p), g)

    # 1) Remove entradas de jogos que saíram (movidos para _removidos)
    removidas: list[tuple[ET.Element, str]] = []
    for u, motivo in saidas:
        for m in u.membros:
            g = entradas.pop(norm_rel(u.rel(m)), None)
            if g is not None and g in list(raiz):
                raiz.remove(g)
                removidas.append((g, motivo))
    res.removidas = len(removidas)

    # 2) Acrescenta o que falta nos jogos que ficaram (sem mexer no que existe)
    for u in mantidas:
        g = None
        for m in u.membros:
            g = entradas.get(norm_rel(u.rel(m)))
            if g is not None:
                break
        if g is None:
            g = ET.SubElement(raiz, "game")
            ET.SubElement(g, "path").text = "./" + u.rel()
            ET.SubElement(g, "name").text = titulo_limpo(u.stem)
            entradas[norm_rel(u.rel())] = g
            res.adicionadas += 1
        elif not texto_filho(g, "name"):
            definir_filho(g, "name", titulo_limpo(u.stem), ("path",))
            res.nomes += 1
        capa = capas.get(id(u))
        if capa:
            img_atual = texto_filho(g, "image")
            existe = bool(img_atual) and (raiz_console / norm_rel_original(img_atual)).exists()
            if not existe and img_atual != capa:
                definir_filho(g, "image", capa, ("path", "name", "desc"))
                res.imagens += 1
        # quantos podem jogar (ficha do jogo); não troca um valor que já exista
        if jogadores and not texto_filho(g, "players"):
            n = jogadores.jogadores(u)
            if n:
                definir_filho(g, "players", texto_jogadores(n),
                              ("path", "name", "desc", "image", "rating", "releasedate",
                               "developer", "publisher", "genre"))
                res.jogadores += 1

    res.alterado = bool(res.adicionadas or res.removidas or res.imagens or res.nomes or res.jogadores)
    if not res.alterado or simular:
        return res

    if arq.exists():
        bak = arq.with_name(f"gamelist.xml.bak-{carimbo}")
        n = 2
        while bak.exists():
            bak = arq.with_name(f"gamelist.xml.bak-{carimbo}-{n}")
            n += 1
        shutil.copy2(arq, bak)
        res.backup = bak.name
    escrever_xml(arvore, arq)

    if removidas:
        pasta_removidos.mkdir(parents=True, exist_ok=True)
        arq_rem = pasta_removidos / "gamelist-removidos.xml"
        try:
            arv_rem = ler_xml(arq_rem) or ET.ElementTree(ET.Element("gameList"))
        except ET.ParseError:
            arv_rem = ET.ElementTree(ET.Element("gameList"))
        rr = arv_rem.getroot()
        for g, motivo in removidas:
            rr.append(ET.Comment(f" removido em {carimbo} (Brasília): {motivo.replace('--', '-')} "))
            rr.append(g)
        escrever_xml(arv_rem, arq_rem)
    return res


def norm_rel_original(caminho: str) -> str:
    c = caminho.strip().replace("\\", "/")
    while c.startswith("./"):
        c = c[2:]
    return c


# --------------------------------------------------------------------------
# Processamento de um console
# --------------------------------------------------------------------------

@dataclass
class ResultadoConsole:
    console: str
    sistema: Sistema
    antes_qtd: int = 0
    antes_tam: int = 0
    depois_qtd: int = 0
    depois_tam: int = 0
    ignorados: int = 0
    movidos: list = field(default_factory=list)       # Unidade
    corrompidos: list = field(default_factory=list)   # Unidade
    capas_baixadas: list = field(default_factory=list)   # (arquivo, nome)
    capas_existentes: int = 0
    capas_nao: list = field(default_factory=list)        # arquivo
    capas_erro: list = field(default_factory=list)       # (arquivo, erro)
    capas_cache: int = 0                                 # vindas do cache local
    capas_internet: int = 0                              # vindas da internet
    dat_usada: str | None = None
    dat_origem: str | None = None
    dat_casados: int = 0
    gamelist: ResultadoGamelist | None = None
    erros: list = field(default_factory=list)


def processar_console(console: str, raiz: Path, sis: Sistema, args, dats: GerenciadorDats,
                      pasta_roms: Path, carimbo: str,
                      cache_capas: "CacheCapas | None" = None) -> ResultadoConsole | None:
    arquivos, ignorados = listar_arquivos(raiz, sis)
    if not arquivos:
        return None
    r = ResultadoConsole(console=console, sistema=sis, ignorados=ignorados)
    log(f"\n[{console}] {len(arquivos)} arquivo(s) de jogo")
    unidades = montar_unidades(console, raiz, arquivos)
    r.antes_qtd = len(unidades)
    r.antes_tam = sum(u.tamanho for u in unidades)

    limite = args.limite_hash_mb * 1024 * 1024
    for u in unidades:
        verificar_unidade(u, sis, limite)

    dat = dats.obter(sis)
    if dat:
        r.dat_usada = f"{sis.tipo_dat}/{sis.dat}.dat"
        r.dat_origem = dats.origens.get(sis.dat)
    for u in unidades:
        if dat:
            for c in u.crcs:
                achado = dat.por_crc.get(c)
                if achado:
                    u.dat_jogo, u.dat_rom = achado
                    r.dat_casados += 1
                    break
        u.classe = classificar(u.stem, u.dat_jogo)
        u.chaves = {chave_jogo(u.stem)}
        if u.dat_jogo:
            u.chaves.add(chave_jogo(u.dat_jogo))

    corrompidos = [u for u in unidades if u.problemas]
    boas = [u for u in unidades if not u.problemas]
    r.corrompidos = corrompidos

    saem: list[Unidade] = []
    # Fase 1: duplicados exatos (mesmo conteúdo, nome diferente)
    por_id: dict[tuple, list[Unidade]] = {}
    for u in boas:
        if u.identidade:
            por_id.setdefault(u.identidade, []).append(u)
    for grupo in por_id.values():
        if len(grupo) < 2:
            continue
        grupo.sort(key=ordem)
        for u in grupo[1:]:
            u.ficou = grupo[0]
            u.motivo = "duplicado exato (conteúdo idêntico, SHA1 igual)"
            saem.append(u)
    restantes = [u for u in boas if u not in saem]

    # Fase 2: versões do mesmo jogo (união por chave de nome e nome da DAT)
    if not sis.arcade:
        pai: dict[str, str] = {}

        def achar(x):
            while pai.setdefault(x, x) != x:
                pai[x] = pai[pai[x]]
                x = pai[x]
            return x
        for u in restantes:
            ks = [k for k in u.chaves if k]
            for k in ks[1:]:
                pai[achar(k)] = achar(ks[0])
        grupos: dict[str, list[Unidade]] = {}
        for u in restantes:
            k = next(iter(u.chaves))
            grupos.setdefault(achar(k), []).append(u)
        for grupo in grupos.values():
            if len(grupo) < 2:
                continue
            grupo.sort(key=ordem)
            for u in grupo[1:]:
                u.ficou = grupo[0]
                u.motivo = f"outra versão do mesmo jogo ({u.classe.rotulo()}) — {explicar(u, grupo[0])}"
                saem.append(u)

    # Corrompidos: só movidos com --mover-corrompidos
    mover_corr = corrompidos if args.mover_corrompidos else []

    base_rem = pasta_roms / "_removidos" / console
    reservados: set = set()
    for u in saem:
        u.destino = planejar_destino(u, base_rem, reservados)
    for u in mover_corr:
        u.destino = planejar_destino(u, base_rem / "corrompidos", reservados)
        u.motivo = "corrompido: " + "; ".join(u.problemas)

    if not args.simular:
        for u in saem + mover_corr:
            r.erros.extend(mover_unidade(u, u.destino))
    r.movidos = saem

    saidas = set(id(u) for u in saem + mover_corr)
    mantidas = [u for u in unidades if id(u) not in saidas]
    r.depois_qtd = len(mantidas)
    r.depois_tam = sum(u.tamanho for u in mantidas)

    # Capas
    capas: dict[int, str] = {}
    pasta_img = raiz / "images"
    if not args.sem_capas:
        tarefas = []
        gl_imagens = _imagens_no_gamelist(raiz)
        for u in mantidas:
            if u.problemas:
                continue
            destino = pasta_img / f"{u.stem}.png"
            existente = _capa_existente(raiz, u, gl_imagens)
            if existente:
                r.capas_existentes += 1
                capas[id(u)] = existente
                continue
            if not sis.libretro:
                r.capas_nao.append(u.rel())
                continue
            extras = cache_capas.por_titulo(sis.libretro, u.chaves)[:6] if cache_capas else []
            tarefas.append((u, destino, candidatos_capa(u, dat), extras))
        if tarefas:
            tem_cache = bool(cache_capas and cache_capas.disponivel(sis.libretro))
            onde = ("no cache local" + ("" if args.offline else " e, se faltar, no libretro-thumbnails")
                    if tem_cache else ("(cache local vazio para este sistema)" if args.offline
                                       else "no libretro-thumbnails (sem cache local deste sistema)"))
            log(f"  procurando {len(tarefas)} capa(s) {onde} ...")
            tmp = Path(args.cache) / "tmp"
            with ThreadPoolExecutor(max_workers=8) as ex:
                futuros = [(u, destino, ex.submit(buscar_capa, sis.libretro, cands, destino, args.simular, tmp,
                                                  cache_capas, args.offline, extras))
                           for u, destino, cands, extras in tarefas]
                for u, destino, fut in futuros:
                    status, nome, origem = fut.result()
                    if status in ("baixada", "disponivel"):
                        r.capas_baixadas.append((u.rel(), nome, origem))
                        if origem == "cache":
                            r.capas_cache += 1
                        else:
                            r.capas_internet += 1
                        capas[id(u)] = "./images/" + destino.name   # na simulação só conta
                    elif status == "nao_encontrada":
                        r.capas_nao.append(u.rel())
                    else:
                        r.capas_erro.append((u.rel(), status))

    # gamelist.xml
    saidas_motivo = [(u, u.motivo) for u in saem + mover_corr]
    try:
        idx_jog = None if getattr(args, "sem_dat", False) else IndiceJogadores.carregar(sis)
        r.gamelist = atualizar_gamelist(raiz, [u for u in mantidas if not u.problemas], saidas_motivo,
                                        capas, base_rem, args.simular, carimbo, idx_jog)
    except Exception as e:  # noqa: BLE001
        r.gamelist = ResultadoGamelist(erro=f"erro ao atualizar gamelist.xml: {e}")
    if r.gamelist.erro:
        r.erros.append(r.gamelist.erro)

    log(f"  jogos: {r.antes_qtd} -> {r.depois_qtd} | movidos: {len(r.movidos)}"
        f"{' (simulado)' if args.simular else ''} | corrompidos: {len(r.corrompidos)}"
        f" | capas novas: {len(r.capas_baixadas)} (cache local {r.capas_cache}, internet {r.capas_internet})"
        f" | sem capa: {len(r.capas_nao)}")
    return r


def _imagens_no_gamelist(raiz: Path) -> dict:
    """path normalizado -> caminho da imagem existente no gamelist atual."""
    res = {}
    try:
        arv = ler_xml(raiz / "gamelist.xml")
    except ET.ParseError:
        return res
    if arv is None:
        return res
    for g in arv.getroot().findall("game"):
        p, img = texto_filho(g, "path"), texto_filho(g, "image")
        if p and img and (raiz / norm_rel_original(img)).exists():
            res[norm_rel(p)] = img
    return res


def _capa_existente(raiz: Path, u: Unidade, gl_imagens: dict) -> str | None:
    for m in u.membros:
        img = gl_imagens.get(norm_rel(u.rel(m)))
        if img:
            return img
    for sufixo in ("", "-image", "-thumb", "-boxart"):
        p = raiz / "images" / f"{u.stem}{sufixo}.png"
        if p.exists():
            return "./images/" + p.name
    return None


# --------------------------------------------------------------------------
# Relatório
# --------------------------------------------------------------------------

def gerar_relatorio(resultados: list[ResultadoConsole], ignoradas: list[str], args, pasta_roms: Path,
                    inicio: datetime, dats: GerenciadorDats, cache_capas: "CacheCapas | None" = None) -> str:
    L = []
    sim = args.simular
    L.append(f"# Relatório de limpeza de ROMs — Arcádia{' (SIMULAÇÃO)' if sim else ''}")
    L.append("")
    L.append(f"- **Data/hora (Brasília):** {inicio.strftime('%d/%m/%Y %H:%M')}")
    L.append(f"- **Pasta:** `{pasta_roms}`")
    modo = "SIMULAÇÃO — nada foi movido, baixado ou alterado" if sim else "REAL — arquivos movidos/baixados"
    if args.offline:
        modo += " — OFFLINE (sem acesso à internet)"
    L.append(f"- **Modo:** {modo}")
    opcoes = [o for o, v in (("--offline", args.offline), ("--sem-capas", args.sem_capas),
                             ("--sem-dat", args.sem_dat),
                             ("--mover-corrompidos", args.mover_corrompidos)) if v]
    L.append(f"- **Opções:** {' '.join(opcoes) if opcoes else '(padrão)'}")
    L.append(f"- **Ferramenta:** limpar-roms.py v{VERSAO}")
    L.append(f"- **DATs locais:** `{PASTA_DATS}`")
    if not args.sem_capas:
        L.append(f"- **Cache de capas:** `{cache_capas.pasta if cache_capas else '—'}`")
    L.append(f"- **Acessos à internet nesta execução:** {len(ACESSOS_REDE)}"
             + (" (bloqueados pelo modo offline)" if args.offline else ""))
    L.append("")
    verbo = "seriam movidos" if sim else "movidos"

    tot_a = sum(r.antes_qtd for r in resultados)
    tot_d = sum(r.depois_qtd for r in resultados)
    tam_a = sum(r.antes_tam for r in resultados)
    tam_d = sum(r.depois_tam for r in resultados)
    tot_mov = sum(len(r.movidos) for r in resultados)
    tot_cor = sum(len(r.corrompidos) for r in resultados)
    tot_capa = sum(len(r.capas_baixadas) for r in resultados)
    tot_nao = sum(len(r.capas_nao) for r in resultados)
    tot_exist = sum(r.capas_existentes for r in resultados)

    L.append("## Resumo geral")
    L.append("")
    L.append(f"| Item | Valor |")
    L.append(f"|---|---|")
    L.append(f"| Consoles com jogos | {len(resultados)} |")
    L.append(f"| Jogos antes | {tot_a} ({tamanho_legivel(tam_a)}) |")
    L.append(f"| Jogos depois | {tot_d} ({tamanho_legivel(tam_d)}) |")
    L.append(f"| Duplicados/versões {verbo} | {tot_mov} ({tamanho_legivel(sum(u.tamanho for r in resultados for u in r.movidos))}) |")
    L.append(f"| Corrompidos encontrados | {tot_cor}{' (movidos)' if args.mover_corrompidos and not sim else ' (não movidos)'} |")
    L.append(f"| Capas {'disponíveis' if sim else 'novas (copiadas/baixadas)'} | {tot_capa} "
             f"(cache local: {sum(r.capas_cache for r in resultados)}; "
             f"internet: {sum(r.capas_internet for r in resultados)}) |")
    L.append(f"| Capas já existentes | {tot_exist} |")
    L.append(f"| Jogos sem capa {'no cache local' if args.offline else 'no libretro-thumbnails'} | {tot_nao} |")
    L.append("")
    L.append("| Console | Antes | Depois | Movidos | Corrompidos | Capas novas | Sem capa | DAT (casados) |")
    L.append("|---|---|---|---|---|---|---|---|")
    for r in resultados:
        dat = f"{r.dat_casados}/{r.antes_qtd}" if r.dat_usada else "—"
        L.append(f"| {r.console} | {r.antes_qtd} ({tamanho_legivel(r.antes_tam)}) | "
                 f"{r.depois_qtd} ({tamanho_legivel(r.depois_tam)}) | {len(r.movidos)} | "
                 f"{len(r.corrompidos)} | {len(r.capas_baixadas)} | {len(r.capas_nao)} | {dat} |")
    L.append("")
    if dats.avisos:
        L.append("**Avisos sobre DATs:**")
        for a in dats.avisos:
            L.append(f"- {a}")
        L.append("")

    for r in resultados:
        L.append(f"## {r.console}")
        L.append("")
        L.append(f"- Antes: **{r.antes_qtd}** jogo(s), {tamanho_legivel(r.antes_tam)}")
        L.append(f"- Depois: **{r.depois_qtd}** jogo(s), {tamanho_legivel(r.depois_tam)}")
        if r.dat_usada:
            L.append(f"- DAT: `{r.dat_usada}` — {r.dat_casados} jogo(s) reconhecido(s) pelo CRC32"
                     + (f" (origem: {r.dat_origem})" if r.dat_origem else ""))
        elif r.sistema.dat:
            L.append("- DAT: não usada")
        if r.ignorados:
            L.append(f"- Arquivos que não são jogos (ignorados): {r.ignorados}")
        L.append("")
        if r.movidos:
            L.append(f"### Movidos ({verbo} para `_removidos\\{r.console}\\`)")
            L.append("")
            L.append("| Arquivo | Motivo | Versão que ficou | Destino |")
            L.append("|---|---|---|---|")
            for u in r.movidos:
                extra = f" (+{len(u.membros) - 1} arquivo(s) junto)" if len(u.membros) > 1 else ""
                dst = "?"
                if u.destino:
                    final = u.destino if len(u.membros) == 1 else u.destino / u.rel()
                    dst = final.relative_to(pasta_roms)
                L.append(f"| {_md(u.rel())}{extra} | {_md(u.motivo)} | {_md(u.ficou.rel()) if u.ficou else '—'} | `{dst}` |")
            L.append("")
        if r.corrompidos:
            acao = "movidos para `_removidos\\%s\\corrompidos\\`" % r.console if args.mover_corrompidos else "NÃO movidos"
            L.append(f"### Corrompidos / não abrem ({acao})")
            L.append("")
            for u in r.corrompidos:
                L.append(f"- **{_md(u.rel())}** — {_md('; '.join(u.problemas))}")
            L.append("")
        if not args.sem_capas:
            L.append("### Capas")
            L.append("")
            if r.capas_baixadas:
                L.append(f"{'Disponíveis (seriam copiadas/baixadas)' if sim else 'Copiadas/baixadas'}:")
                for arq, nome, origem in r.capas_baixadas:
                    L.append(f"- {_md(arq)} ← `{nome}` ({'cache local' if origem == 'cache' else 'internet'})")
            if r.capas_existentes:
                L.append(f"- Já tinham capa: {r.capas_existentes}")
            if r.capas_nao:
                L.append(("Não encontradas no cache local (modo offline; não é erro):" if args.offline
                          else "Não encontradas no cache local nem no libretro-thumbnails (não é erro):"))
                for arq in r.capas_nao:
                    L.append(f"- {_md(arq)}")
            for arq, err in r.capas_erro:
                L.append(f"- Falha ao obter a capa de {_md(arq)}: {_md(err)}")
            L.append("")
        g = r.gamelist
        if g:
            L.append("### gamelist.xml")
            L.append("")
            if g.erro:
                L.append(f"- ERRO: {g.erro}")
            elif not g.alterado:
                L.append("- Sem alterações necessárias.")
            else:
                pref = "Seriam " if sim else ""
                L.append(f"- {pref}entradas adicionadas: {g.adicionadas}; removidas (guardadas em "
                         f"`_removidos\\{r.console}\\gamelist-removidos.xml`): {g.removidas}; "
                         f"imagens preenchidas: {g.imagens}; nomes preenchidos: {g.nomes}; "
                         f"jogadores preenchidos: {g.jogadores}")
                if g.backup:
                    L.append(f"- Backup do original: `{r.console}\\{g.backup}`")
                L.append("- Dados existentes (favoritos, descrições, contadores) preservados.")
            L.append("")
        if r.erros:
            L.append("### Erros")
            L.append("")
            for e in r.erros:
                L.append(f"- {_md(e)}")
            L.append("")

    if ignoradas:
        L.append("## Pastas ignoradas")
        L.append("")
        L.append("Pastas com arquivos, mas sem mapeamento de console nesta ferramenta "
                 "(ports, motores de jogo, sistemas sem DAT etc.) — não foram tocadas:")
        L.append("")
        L.append(", ".join(f"`{p}`" for p in ignoradas))
        L.append("")
    fim = agora()
    L.append("---")
    L.append(f"Gerado em {fim.strftime('%d/%m/%Y %H:%M:%S')} (horário de Brasília).")
    return "\n".join(L) + "\n"


def _md(s: str) -> str:
    return str(s).replace("|", "\\|")


def md_para_txt(md: str) -> str:
    t = re.sub(r"\*\*(.+?)\*\*", r"\1", md)
    t = t.replace("`", "")
    t = re.sub(r"^#+\s*", "", t, flags=re.M)
    t = re.sub(r"^\|[-|]+\|$\n", "", t, flags=re.M)
    return t


# --------------------------------------------------------------------------
# Principal
# --------------------------------------------------------------------------

def main(argv=None) -> int:
    try:
        sys.stdout.reconfigure(errors="replace")  # type: ignore[attr-defined]
    except Exception:  # noqa: BLE001
        pass
    ap = argparse.ArgumentParser(
        prog="limpar-roms.py",
        description="Arcádia — remove duplicados/versões repetidas de ROMs (movendo para _removidos), "
                    "lista corrompidos, baixa capas do libretro-thumbnails e atualiza o gamelist.xml.")
    ap.add_argument("pasta_roms", nargs="?",
                    help="pasta 'roms' com subpastas por console (nes, snes, megadrive...)")
    ap.add_argument("--simular", action="store_true", help="não move, não baixa e não altera nada; só gera o relatório")
    ap.add_argument("--sem-capas", action="store_true", help="não procura/baixa capas")
    ap.add_argument("--sem-dat", action="store_true", help="não usa DATs No-Intro/Redump (só nomes e hashes locais)")
    ap.add_argument("--mover-corrompidos", action="store_true",
                    help="move os corrompidos para _removidos\\<console>\\corrompidos\\")
    ap.add_argument("--txt", action="store_true", help="gera também o relatório em .txt")
    ap.add_argument("--consoles", default="", help="processa só estes consoles (ex.: nes,snes,gba)")
    ap.add_argument("--limite-hash-mb", type=int, default=1024,
                    help="não calcula hash de arquivos maiores que isso (padrão: 1024 MB)")
    ap.add_argument("--offline", action="store_true",
                    help="não acessa a internet: usa só ferramentas\\roms\\dats\\ e o cache local de capas")
    ap.add_argument("--cache-capas", default=str(CACHE_CAPAS_PADRAO),
                    help="pasta do cache local de capas (padrão: ferramentas\\roms\\.cache\\capas)")
    ap.add_argument("--atualizar-dats", action="store_true",
                    help="baixa de novo as DATs da paleta para ferramentas\\roms\\dats\\ (e ignora o "
                         "prazo do cache das demais); pode ser usada sem pasta de ROMs")
    ap.add_argument("--cache", default=str(CACHE_PADRAO), help=argparse.SUPPRESS)
    args = ap.parse_args(argv)

    global OFFLINE
    OFFLINE = bool(args.offline)
    if args.atualizar_dats:
        if args.offline:
            log("ERRO: --atualizar-dats precisa de internet; não use junto com --offline.")
            return 2
        erros = atualizar_dats_repositorio()
        if not args.pasta_roms:
            return 1 if erros else 0
    if not args.pasta_roms:
        ap.error("informe a pasta de ROMs (ou use só --atualizar-dats)")

    pasta_roms = Path(args.pasta_roms).resolve()
    if not pasta_roms.is_dir():
        log(f"ERRO: pasta não encontrada: {pasta_roms}")
        return 2
    inicio = agora()
    carimbo = inicio.strftime("%Y%m%d-%H%M")
    log(f"Arcádia — limpar-roms v{VERSAO} — {inicio.strftime('%d/%m/%Y %H:%M')} (Brasília)")
    log(f"Pasta: {pasta_roms}")
    if args.simular:
        log("MODO SIMULAÇÃO: nada será movido, baixado ou alterado.")
    if args.offline:
        log("MODO OFFLINE: nenhuma conexão com a internet será feita (só DATs locais e cache de capas).")
    cache_capas = None if args.sem_capas else CacheCapas(Path(args.cache_capas).resolve())
    if cache_capas:
        n_sis = 0
        if cache_capas.pasta.is_dir():
            n_sis = sum(1 for d in cache_capas.pasta.glob("*/Named_Boxarts") if d.is_dir())
        log(f"Cache de capas: {cache_capas.pasta} ({n_sis} sistema(s))")

    filtro = {c.strip().lower() for c in args.consoles.split(",") if c.strip()}
    dats = GerenciadorDats(Path(args.cache), not args.sem_dat, args.atualizar_dats, args.offline)
    resultados: list[ResultadoConsole] = []
    ignoradas: list[str] = []
    for pasta in sorted(pasta_roms.iterdir(), key=lambda p: p.name.lower()):
        if not pasta.is_dir() or pasta.name.startswith(("_", ".")):
            continue   # _removidos, _relatorios e ocultas nunca são consoles
        nome = pasta.name.lower()
        if filtro and nome not in filtro:
            continue
        sis = SISTEMAS.get(nome)
        if sis is None:
            if any(f.is_file() and not f.name.lower().endswith((".txt", ".xml"))
                   for f in pasta.iterdir()):
                ignoradas.append(pasta.name)
            continue
        try:
            r = processar_console(pasta.name, pasta, sis, args, dats, pasta_roms, carimbo, cache_capas)
        except Exception as e:  # noqa: BLE001
            log(f"  ERRO no console {pasta.name}: {e}")
            continue
        if r:
            resultados.append(r)

    md = gerar_relatorio(resultados, ignoradas, args, pasta_roms, inicio, dats, cache_capas)
    pasta_rel = pasta_roms / "_relatorios"
    pasta_rel.mkdir(parents=True, exist_ok=True)
    base = f"limpeza-{inicio.strftime('%Y-%m-%d_%H%M')}{'-simulacao' if args.simular else ''}"
    arq = pasta_rel / f"{base}.md"
    n = 2
    while arq.exists():
        arq = pasta_rel / f"{base}-{n}.md"
        n += 1
    arq.write_text(md, encoding="utf-8")
    if args.txt:
        arq.with_suffix(".txt").write_text(md_para_txt(md), encoding="utf-8")
    log("")
    log(f"Consoles com jogos: {len(resultados)} | movidos: {sum(len(r.movidos) for r in resultados)}"
        f"{' (simulado)' if args.simular else ''} | corrompidos: {sum(len(r.corrompidos) for r in resultados)}")
    if ignoradas:
        log(f"Pastas ignoradas (sem mapeamento): {', '.join(ignoradas)}")
    log(f"Acessos à internet nesta execução: {len(ACESSOS_REDE)}"
        + (" (modo offline)" if args.offline else ""))
    log(f"Relatório: {arq}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
