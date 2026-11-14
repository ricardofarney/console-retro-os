# Arcádia — gera as artes do tema (fundos, logotipos e cores por console).
# Uso (PowerShell no Windows):
#   powershell -ExecutionPolicy Bypass -File ferramentas\tema\gerar-arte.ps1
# Saída: temas\arcadia\arte, temas\arcadia\logos e temas\arcadia\cores (sobrescreve).
# Para mudar nome/cor de um console, edite a tabela $sistemas abaixo e rode de novo.

param([switch]$Previa)  # -Previa: gera só os ajustes da prévia no Windows (ferramentas\previa\ajustes-tema)
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

$raiz  = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$tema  = if ($Previa) { Join-Path $raiz 'ferramentas\previa\ajustes-tema' } else { Join-Path $raiz 'temas\arcadia' }
$arte  = Join-Path $tema 'arte'
$logos = Join-Path $tema 'logos'
$cores = Join-Path $tema 'cores'
$logosClaros = Join-Path $logos 'claro'
foreach ($d in $logos, $logosClaros, $cores) { New-Item -ItemType Directory -Force $d | Out-Null }
if (-not $Previa) { New-Item -ItemType Directory -Force $arte | Out-Null }

# id do sistema (pasta de roms / system.theme) ; nome exibido ; linha de baixo ; cor (RRGGBB)
$sistemas = @"
auto-lastplayed;Continuar jogando;de onde você parou;F2B33D
auto-favorites;Favoritos;seus jogos preferidos;FF5C7A
auto-allgames;Todos os jogos;biblioteca completa;8E9AAF
nes;NES;Nintendo;E4002B
famicom;Famicom;Nintendo;E4002B
fds;Famicom Disk;Nintendo;C8102E
snes;Super Nintendo;Nintendo;7B5CD6
sfc;Super Famicom;Nintendo;7B5CD6
n64;Nintendo 64;Nintendo;2E9E44
gb;Game Boy;Nintendo;8BAC0F
gbc;Game Boy Color;Nintendo;6A3FB5
gba;Game Boy Advance;Nintendo;4B3BC4
nds;Nintendo DS;Nintendo;B0B7C3
3ds;Nintendo 3DS;Nintendo;D12228
virtualboy;Virtual Boy;Nintendo;D50000
gamecube;GameCube;Nintendo;6A5ACD
wii;Wii;Nintendo;34BEED
gameandwatch;Game & Watch;Nintendo;C9A227
pokemini;Pokémon mini;Nintendo;F0C419
megadrive;Mega Drive;SEGA;1E88E5
genesis;Mega Drive;SEGA;1E88E5
mastersystem;Master System;SEGA;E53935
gamegear;Game Gear;SEGA;37474F
sg-1000;SG-1000;SEGA;C62828
segacd;Mega CD;SEGA;0D47A1
sega32x;Mega Drive 32X;SEGA;F4511E
saturn;Saturn;SEGA;546E7A
dreamcast;Dreamcast;SEGA;F57C00
naomi;NAOMI;SEGA;FF8F00
atomiswave;Atomiswave;Sammy;FF6F00
psx;PlayStation;Sony;8E8E93
ps2;PlayStation 2;Sony;1F3A93
psp;PSP;Sony;3A3A3C
pcengine;PC Engine;NEC;F57F17
pcenginecd;PC Engine CD;NEC;EF6C00
supergrafx;SuperGrafx;NEC;E65100
pcfx;PC-FX;NEC;BF360C
neogeo;Neo Geo;SNK;D4AF37
neocd;Neo Geo CD;SNK;C5A028
ngp;Neo Geo Pocket;SNK;5D4037
ngpc;Neo Geo Pocket Color;SNK;8D6E63
arcade;Fliperama;Arcade;FF3D7F
mame;Fliperama (MAME);Arcade;FF3D7F
fbneo;Fliperama (FBNeo);Arcade;E91E63
cps1;CPS-1;Capcom;1565C0
cps2;CPS-2;Capcom;283593
cps3;CPS-3;Capcom;4527A0
atari2600;Atari 2600;Atari;B8692E
atari5200;Atari 5200;Atari;A0522D
atari7800;Atari 7800;Atari;8D4A2B
atari800;Atari 8 bits;Atari;795548
atarist;Atari ST;Atari;6D4C41
lynx;Lynx;Atari;F9A825
jaguar;Jaguar;Atari;C62828
colecovision;ColecoVision;Coleco;455A64
intellivision;Intellivision;Mattel;8D6E63
vectrex;Vectrex;GCE;00BFA5
odyssey2;Odyssey²;Philips;9E9D24
o2em;Odyssey²;Philips;9E9D24
3do;3DO;Panasonic;B71C1C
cdi;CD-i;Philips;1565C0
wonderswan;WonderSwan;Bandai;78909C
wonderswancolor;WonderSwan Color;Bandai;00897B
wswan;WonderSwan;Bandai;78909C
wswanc;WonderSwan Color;Bandai;00897B
msx;MSX;ASCII;3949AB
msx2;MSX2;ASCII;303F9F
amiga;Amiga;Commodore;EF5350
amigacd32;Amiga CD32;Commodore;E53935
c64;Commodore 64;Commodore;7E57C2
amstradcpc;Amstrad CPC;Amstrad;26A69A
zxspectrum;ZX Spectrum;Sinclair;FF7043
zx81;ZX81;Sinclair;FF8A65
x68000;X68000;Sharp;607D8B
pc98;PC-98;NEC;5C6BC0
dos;MS-DOS;PC;43A047
pc;PC;Windows;1E88E5
scummvm;ScummVM;Aventuras;66BB6A
ports;Jogos Portados;PC;29B6F6
openbor;OpenBOR;Pancadaria;FF7043
pico8;PICO-8;Lexaloffle;FF004D
tic80;TIC-80;Fantasy console;1ABC9C
easyrpg;RPG Maker;EasyRPG;AB47BC
solarus;Solarus;Aventuras;26C6DA
moonlight;Moonlight;Streaming;5E35B1
kodi;Kodi;Mídia;17B2E7
"@

if ($Previa) {
  # itens que só existem no RetroBat (não vão para o aparelho)
  $sistemas = 'retrobat;Configurações;RetroBat (só na prévia);8E9AAF'
}

function Cor([string]$hex, [int]$alfa = 255) {
  [System.Drawing.Color]::FromArgb($alfa, [Convert]::ToInt32($hex.Substring(0,2),16), [Convert]::ToInt32($hex.Substring(2,2),16), [Convert]::ToInt32($hex.Substring(4,2),16))
}
function Salvar($bmp, $arquivo) { $bmp.Save($arquivo, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose() }

if (-not $Previa) {
# ---------- Fundo (gradiente escuro com vinheta) ----------
$bmp = New-Object System.Drawing.Bitmap 1920, 1080
$g = [System.Drawing.Graphics]::FromImage($bmp)
$ret = New-Object System.Drawing.Rectangle 0, 0, 1920, 1080
$grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush $ret, (Cor '1A1C33'), (Cor '090A14'), 90
$g.FillRectangle($grad, $ret)
$caminho = New-Object System.Drawing.Drawing2D.GraphicsPath
$caminho.AddEllipse(-480, -300, 2880, 1680)
$vinheta = New-Object System.Drawing.Drawing2D.PathGradientBrush $caminho
$vinheta.CenterColor = [System.Drawing.Color]::FromArgb(0, 0, 0, 0)
$vinheta.SurroundColors = @([System.Drawing.Color]::FromArgb(150, 0, 0, 0))
$g.FillRectangle($vinheta, $ret)
$g.Dispose(); Salvar $bmp (Join-Path $arte 'fundo.png')

# ---------- Brilho (branco radial, tingido pela cor do console) ----------
$bmp = New-Object System.Drawing.Bitmap 1920, 1080
$g = [System.Drawing.Graphics]::FromImage($bmp)
$caminho = New-Object System.Drawing.Drawing2D.GraphicsPath
$caminho.AddEllipse(260, 190, 1400, 700)
$radial = New-Object System.Drawing.Drawing2D.PathGradientBrush $caminho
$radial.CenterColor = [System.Drawing.Color]::FromArgb(150, 255, 255, 255)
$radial.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 255, 255, 255))
$g.FillEllipse($radial, 260, 190, 1400, 700)
$g.Dispose(); Salvar $bmp (Join-Path $arte 'brilho.png')

# ---------- Faixa superior (branco que some para a direita) ----------
$bmp = New-Object System.Drawing.Bitmap 1920, 140
$g = [System.Drawing.Graphics]::FromImage($bmp)
$ret = New-Object System.Drawing.Rectangle 0, 0, 1920, 140
$grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush $ret, ([System.Drawing.Color]::FromArgb(235,255,255,255)), ([System.Drawing.Color]::FromArgb(40,255,255,255)), 0
$g.FillRectangle($grad, $ret)
$g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255,255,255,255))), 0, 132, 1920, 8)
$g.Dispose(); Salvar $bmp (Join-Path $arte 'faixa.png')

# ---------- Branco liso (painéis tingidos) ----------
$bmp = New-Object System.Drawing.Bitmap 8, 8
$g = [System.Drawing.Graphics]::FromImage($bmp); $g.Clear([System.Drawing.Color]::White); $g.Dispose()
Salvar $bmp (Join-Path $arte 'branco.png')

}  # fim das artes de base

# ---------- Logotipos e cores por console ----------
$fonteNome = New-Object System.Drawing.Font 'Segoe UI', 64, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$fonteSub  = New-Object System.Drawing.Font 'Segoe UI', 30, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$centro = New-Object System.Drawing.StringFormat
$centro.Alignment = [System.Drawing.StringAlignment]::Center
$centro.LineAlignment = [System.Drawing.StringAlignment]::Center
$centro.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter
$utf8 = New-Object System.Text.UTF8Encoding $false
$total = 0

foreach ($linha in ($sistemas -split "`r?`n" | Where-Object { $_.Trim() })) {
  $id, $nome, $sub, $hex = $linha.Split(';')
  $nomeTexto = $nome
  $rgb = Cor $hex

  $bmp = New-Object System.Drawing.Bitmap 900, 300
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $g.Clear([System.Drawing.Color]::Transparent)

  # tamanho do nome se ajusta para caber
  $tam = 64
  do {
    $f = New-Object System.Drawing.Font 'Segoe UI', $tam, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $medida = $g.MeasureString($nomeTexto, $f)
    if ($medida.Width -gt 860) { $tam -= 4 }
  } while ($medida.Width -gt 860 -and $tam -gt 30)

  $sombra = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(140, 0, 0, 0))
  $g.DrawString($nomeTexto, $f, $sombra, (New-Object System.Drawing.RectangleF 4, 34, 900, 150), $centro)
  $g.DrawString($nomeTexto, $f, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF 0, 30, 900, 150), $centro)

  # barra e linha de baixo na cor do console
  $larg = [Math]::Min(820, [Math]::Max(240, $medida.Width * 0.6))
  $g.FillRectangle((New-Object System.Drawing.SolidBrush $rgb), [int]((900 - $larg) / 2), 186, [int]$larg, 8)
  $g.DrawString($sub.ToUpper(), $fonteSub, (New-Object System.Drawing.SolidBrush $rgb), (New-Object System.Drawing.RectangleF 0, 200, 900, 70), $centro)
  $g.Dispose(); Salvar $bmp (Join-Path $logos "$id.png")

  # versão clara (tudo branco, enquadrada) para a faixa colorida das listas de jogos
  $bmp = New-Object System.Drawing.Bitmap 900, 200
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $g.Clear([System.Drawing.Color]::Transparent)
  $esq = New-Object System.Drawing.StringFormat
  $esq.Alignment = [System.Drawing.StringAlignment]::Near
  $esq.LineAlignment = [System.Drawing.StringAlignment]::Center
  $g.DrawString($nomeTexto, $f, $sombra, (New-Object System.Drawing.RectangleF 4, 8, 900, 120), $esq)
  $g.DrawString($nomeTexto, $f, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF 0, 4, 900, 120), $esq)
  $g.DrawString($sub.ToUpper(), $fonteSub, (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(215,255,255,255))), (New-Object System.Drawing.RectangleF 6, 122, 900, 60), $esq)
  $g.Dispose(); Salvar $bmp (Join-Path $logosClaros "$id.png")

  # texto selecionado escuro em cores claras, branco em cores escuras
  $lum = 0.299 * $rgb.R + 0.587 * $rgb.G + 0.114 * $rgb.B
  $corSel = if ($lum -gt 150) { '0B0C18' } else { 'FFFFFF' }

  $xml = @"
<?xml version="1.0" encoding="UTF-8"?>
<!-- Gerado por ferramentas/tema/gerar-arte.ps1 — $nome ($sub) -->
<theme>
  <formatVersion>7</formatVersion>
  <view name="system">
    <image name="brilho"><color>${hex}A0</color></image>
  </view>
  <view name="basic,detailed,video">
    <image name="faixa"><color>${hex}FF</color></image>
    <textlist name="gamelist">
      <selectorColor>${hex}FF</selectorColor>
      <selectedColor>${corSel}FF</selectedColor>
      <secondaryColor>${hex}FF</secondaryColor>
      <scrollbarColor>${hex}80</scrollbarColor>
    </textlist>
  </view>
</theme>
"@
  [System.IO.File]::WriteAllText((Join-Path $cores "$id.xml"), $xml, $utf8)
  $total++
}

Write-Host "Artes geradas: fundo, brilho, faixa, branco + $total logotipos e arquivos de cor."
