# Arcádia — gera as artes do tema v0.2 (estilo "colorido por console", ver docs/DESIGN.md).
# Uso (PowerShell no Windows):
#   powershell -ExecutionPolicy Bypass -File ferramentas\tema\gerar-arte.ps1           # tema completo
#   powershell -ExecutionPolicy Bypass -File ferramentas\tema\gerar-arte.ps1 -Previa   # só os ajustes da prévia (RetroBat)
# Saída: temas\arcadia\{arte,logos,cores} e as telas de abertura em
#        packages\sx05re\emuelec\config\splash (usadas pelo EmuELEC antes do EmulationStation abrir).
# Para mudar nome/cor de um console, edite a tabela $sistemas e rode de novo.
param([switch]$Previa)
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

$raiz   = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$tema   = if ($Previa) { Join-Path $raiz 'ferramentas\previa\ajustes-tema' } else { Join-Path $raiz 'temas\arcadia' }
$arte   = Join-Path $tema 'arte'
$logos  = Join-Path $tema 'logos'
$claros = Join-Path $logos 'claro'
$cores  = Join-Path $tema 'cores'
$splashEE = Join-Path $raiz 'packages\sx05re\emuelec\config\splash'
foreach ($d in $logos, $claros, $cores) { New-Item -ItemType Directory -Force $d | Out-Null }
if (-not $Previa) { New-Item -ItemType Directory -Force $arte | Out-Null }

# ---------------- Cores base (docs/DESIGN.md) ----------------
$FUNDO = 'F4F1EA'; $TEXTO = '2C2C2A'; $TEXTO2 = '5F5E5A'; $OUTROS = '888780'

# id (pasta de roms / system.theme) ; nome exibido ; fabricante ; cor (vazio = demais consoles #888780)
$sistemas = @"
auto-lastplayed;Continuar jogando;de onde você parou;2C2C2A
auto-favorites;Favoritos;seus jogos preferidos;C9A227
auto-allgames;Todos os jogos;biblioteca completa;888780
atari2600;Atari 2600;Atari;D85A30
atari7800;Atari 7800;Atari;993C1D
nes;NES;Nintendo;A32D2D
famicom;Famicom;Nintendo;A32D2D
fds;Famicom Disk System;Nintendo;A32D2D
snes;Super Nintendo;Nintendo;534AB7
sfc;Super Famicom;Nintendo;534AB7
n64;Nintendo 64;Nintendo;0F6E56
gb;Game Boy;Nintendo;3B6D11
gbc;Game Boy Color;Nintendo;639922
gba;Game Boy Advance;Nintendo;3C3489
mastersystem;Master System;SEGA;378ADD
megadrive;Mega Drive;SEGA;185FA5
genesis;Mega Drive;SEGA;185FA5
segacd;Sega CD;SEGA;0C447C
megacd;Sega CD;SEGA;0C447C
sega32x;Sega 32X;SEGA;0C447C
gamegear;Game Gear;SEGA;1D9E75
psx;PlayStation;Sony;5F5E5A
pcengine;PC Engine;NEC;BA7517
pcenginecd;PC Engine CD;NEC;BA7517
supergrafx;SuperGrafx;NEC;BA7517
neogeo;Neo Geo;SNK;854F0B
neocd;Neo Geo CD;SNK;854F0B
neogeocd;Neo Geo CD;SNK;854F0B
arcade;Arcade;Fliperama;993556
mame;Arcade (MAME);Fliperama;993556
fbneo;Arcade (FBNeo);Fliperama;993556
cps1;CPS-1;Capcom;993556
cps2;CPS-2;Capcom;993556
cps3;CPS-3;Capcom;993556
ngp;Neo Geo Pocket;SNK;D4537E
ngpc;Neo Geo Pocket Color;SNK;D4537E
wonderswan;WonderSwan;Bandai;444441
wonderswancolor;WonderSwan Color;Bandai;444441
wswan;WonderSwan;Bandai;444441
wswanc;WonderSwan Color;Bandai;444441
msx;MSX;ASCII;E24B4A
msx2;MSX2;ASCII;E24B4A
nds;Nintendo DS;Nintendo;
3ds;Nintendo 3DS;Nintendo;
virtualboy;Virtual Boy;Nintendo;
gamecube;GameCube;Nintendo;
wii;Wii;Nintendo;
gameandwatch;Game & Watch;Nintendo;
pokemini;Pokémon mini;Nintendo;
sg-1000;SG-1000;SEGA;
saturn;Saturn;SEGA;
dreamcast;Dreamcast;SEGA;
naomi;NAOMI;SEGA;
atomiswave;Atomiswave;Sammy;
ps2;PlayStation 2;Sony;
psp;PSP;Sony;
pcfx;PC-FX;NEC;
atari5200;Atari 5200;Atari;
atari800;Atari 8 bits;Atari;
atarist;Atari ST;Atari;
lynx;Lynx;Atari;
jaguar;Jaguar;Atari;
colecovision;ColecoVision;Coleco;
intellivision;Intellivision;Mattel;
vectrex;Vectrex;GCE;
odyssey2;Odyssey²;Philips;
o2em;Odyssey²;Philips;
3do;3DO;Panasonic;
cdi;CD-i;Philips;
amiga;Amiga;Commodore;
amigacd32;Amiga CD32;Commodore;
c64;Commodore 64;Commodore;
amstradcpc;Amstrad CPC;Amstrad;
zxspectrum;ZX Spectrum;Sinclair;
zx81;ZX81;Sinclair;
x68000;X68000;Sharp;
pc98;PC-98;NEC;
dos;MS-DOS;PC;
pc;PC;Windows;
scummvm;ScummVM;Aventuras;
ports;Jogos portados;PC;
openbor;OpenBOR;Pancadaria;
pico8;PICO-8;Lexaloffle;
tic80;TIC-80;Fantasy console;
easyrpg;RPG Maker;EasyRPG;
solarus;Solarus;Aventuras;
moonlight;Moonlight;Streaming;
kodi;Kodi;Mídia;
"@
if ($Previa) { $sistemas = 'retrobat;Configurações;RetroBat (só na prévia);' }

# Ordem dos quadradinhos da abertura (paleta do DESIGN.md)
$paleta = 'D85A30','993C1D','A32D2D','534AB7','0F6E56','3B6D11','639922','3C3489','378ADD','185FA5','0C447C','1D9E75','5F5E5A','BA7517','854F0B','993556','D4537E','444441','E24B4A','888780'

# ---------------- Utilidades ----------------
function Cor([string]$hex, [int]$alfa = 255) {
  [System.Drawing.Color]::FromArgb($alfa, [Convert]::ToInt32($hex.Substring(0,2),16), [Convert]::ToInt32($hex.Substring(2,2),16), [Convert]::ToInt32($hex.Substring(4,2),16))
}
function Clarear([string]$hex, [double]$quanto) {   # mistura com branco (0..1)
  $c = Cor $hex
  $r = [int]($c.R + (255 - $c.R) * $quanto); $g = [int]($c.G + (255 - $c.G) * $quanto); $b = [int]($c.B + (255 - $c.B) * $quanto)
  '{0:X2}{1:X2}{2:X2}' -f $r, $g, $b
}
function Escurecer([string]$hex, [double]$quanto) {
  $c = Cor $hex
  '{0:X2}{1:X2}{2:X2}' -f [int]($c.R * (1 - $quanto)), [int]($c.G * (1 - $quanto)), [int]($c.B * (1 - $quanto))
}
function Arredondado([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $r * 2
  $p.AddArc($x, $y, $d, $d, 180, 90); $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90); $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $p.CloseFigure(); $p
}
function NovaTela([int]$w, [int]$h) {
  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  @($bmp, $g)
}
function Salvar($bmp, $g, $arquivo) { $g.Dispose(); $bmp.Save($arquivo, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose() }
function Fonte([float]$px, [string]$estilo = 'Bold') {
  New-Object System.Drawing.Font 'Segoe UI', $px, ([System.Drawing.FontStyle]::$estilo), ([System.Drawing.GraphicsUnit]::Pixel)
}
function Ajustar($g, [string]$texto, [float]$px, [float]$largura, [string]$estilo = 'Bold') {
  do { $f = Fonte $px $estilo; $m = $g.MeasureString($texto, $f); if ($m.Width -gt $largura) { $px -= 2 } } while ($m.Width -gt $largura -and $px -gt 16)
  $f
}
$utf8 = New-Object System.Text.UTF8Encoding $false

# ---------------- Tela de abertura (EmuELEC e EmulationStation) ----------------
function Abertura([int]$w, [int]$h, [string]$arquivo, [string]$legenda, [double]$progresso, [bool]$comBarra) {
  $t = NovaTela $w $h; $bmp = $t[0]; $g = $t[1]
  $g.Clear((Cor $FUNDO))
  $esc = $h / 1080.0
  # fileira de quadradinhos
  $lado = [int](46 * $esc); $vao = [int](14 * $esc); $n = $paleta.Count
  $total = $n * $lado + ($n - 1) * $vao
  $x0 = ($w - $total) / 2; $yq = $h * 0.33
  for ($i = 0; $i -lt $n; $i++) {
    $g.FillPath((New-Object System.Drawing.SolidBrush (Cor $paleta[$i])), (Arredondado ($x0 + $i * ($lado + $vao)) $yq $lado $lado ($lado * 0.24)))
  }
  # nome e slogan
  $centro = New-Object System.Drawing.StringFormat; $centro.Alignment = 'Center'; $centro.LineAlignment = 'Center'
  $g.DrawString('Arcádia', (Fonte (190 * $esc) 'Bold'), (New-Object System.Drawing.SolidBrush (Cor $TEXTO)), (New-Object System.Drawing.RectangleF 0, ($h * 0.40), $w, (230 * $esc)), $centro)
  $g.DrawString($legenda, (Fonte (46 * $esc) 'Regular'), (New-Object System.Drawing.SolidBrush (Cor $TEXTO2)), (New-Object System.Drawing.RectangleF 0, ($h * 0.61), $w, (70 * $esc)), $centro)
  if ($comBarra) {
    $bw = $w * 0.36; $bh = [Math]::Max(8, 12 * $esc); $bx = ($w - $bw) / 2; $by = $h * 0.80
    $g.FillPath((New-Object System.Drawing.SolidBrush (Cor 'E2DED3')), (Arredondado $bx $by $bw $bh ($bh / 2)))
    if ($progresso -gt 0) { $g.FillPath((New-Object System.Drawing.SolidBrush (Cor $TEXTO)), (Arredondado $bx $by ([Math]::Max($bh, $bw * $progresso)) $bh ($bh / 2))) }
  }
  Salvar $bmp $g $arquivo
}

if (-not $Previa) {
  # fundo branco (tingido pelo tema) e sombra dos cards
  $t = NovaTela 8 8; $t[1].Clear([System.Drawing.Color]::White); Salvar $t[0] $t[1] (Join-Path $arte 'branco.png')
  $t = NovaTela 640 400; $g = $t[1]; $g.Clear([System.Drawing.Color]::Transparent)
  for ($i = 14; $i -ge 1; $i--) { $g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(6, 0, 0, 0))), (Arredondado (20 - $i) (24 - $i) (600 + 2 * $i) (360 + 2 * $i) (40 + $i))) }
  Salvar $t[0] $t[1] (Join-Path $arte 'sombra.png')

  # abertura do EmulationStation (sem barra: a barra real é desenhada pelo ES via splash.xml)
  Abertura 1920 1080 (Join-Path $arte 'abertura.png') 'seus clássicos, de onde você parou' 0 $false
  # telas do EmuELEC (show_splash.sh): início e carregamento de jogo, 1920x1080 e 1280x1024 ("std")
  Abertura 1920 1080 (Join-Path $splashEE 'splash-1080.png') 'seus clássicos, de onde você parou' 0.35 $true
  Abertura 1280 1024 (Join-Path $splashEE 'splash-std.png') 'seus clássicos, de onde você parou' 0.35 $true
  Abertura 1920 1080 (Join-Path $splashEE 'loading-game.png') 'carregando o jogo…' 0.7 $true
  Abertura 1280 1024 (Join-Path $splashEE 'loading-game-std.png') 'carregando o jogo…' 0.7 $true
}

# ---------------- Cards, logotipos claros e cores por console ----------------
$total = 0
foreach ($linha in ($sistemas -split "`r?`n" | Where-Object { $_.Trim() })) {
  $id, $nome, $fab, $hex = $linha.Split(';')
  if (-not $hex) { $hex = $OUTROS }
  $claro = Clarear $hex 0.88
  $escuro = Escurecer $hex 0.18

  # card 640x400 (cantos arredondados), nome embaixo à esquerda
  $t = NovaTela 640 400; $bmp = $t[0]; $g = $t[1]; $g.Clear([System.Drawing.Color]::Transparent)
  $forma = Arredondado 0 0 640 400 40
  $grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Rectangle 0, 0, 640, 400), (Cor $hex), (Cor $escuro), 60
  $g.FillPath($grad, $forma)
  # detalhe: círculo translúcido no canto
  $g.SetClip($forma); $g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(28, 255, 255, 255))), 380, -120, 380, 380); $g.ResetClip()
  $esq = New-Object System.Drawing.StringFormat; $esq.Alignment = 'Near'; $esq.LineAlignment = 'Far'
  $fNome = Ajustar $g $nome 66 580
  $g.DrawString($nome, $fNome, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF 34, 150, 590, 216), $esq)
  $sup = New-Object System.Drawing.StringFormat; $sup.Alignment = 'Near'; $sup.LineAlignment = 'Near'
  $g.DrawString($fab.ToUpper(), (Fonte 24 'Bold'), (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(200, 255, 255, 255))), (New-Object System.Drawing.RectangleF 36, 30, 560, 40), $sup)
  Salvar $bmp $g (Join-Path $logos "$id.png")

  # logotipo claro (texto branco) para a faixa das listas
  $t = NovaTela 900 200; $bmp = $t[0]; $g = $t[1]; $g.Clear([System.Drawing.Color]::Transparent)
  $meio = New-Object System.Drawing.StringFormat; $meio.Alignment = 'Near'; $meio.LineAlignment = 'Center'
  $g.DrawString($nome, (Ajustar $g $nome 76 880), [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF 0, 0, 900, 130), $meio)
  $g.DrawString($fab.ToUpper(), (Fonte 30 'Bold'), (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(215, 255, 255, 255))), (New-Object System.Drawing.RectangleF 4, 128, 900, 60), $meio)
  Salvar $bmp $g (Join-Path $claros "$id.png")

  # cores do console nas telas internas
  $xml = @"
<?xml version="1.0" encoding="UTF-8"?>
<!-- Gerado por ferramentas/tema/gerar-arte.ps1 — $nome ($fab), cor $hex, fundo $claro -->
<theme>
  <formatVersion>7</formatVersion>
  <view name="basic,detailed,video">
    <image name="background"><color>${claro}FF</color></image>
    <image name="faixa"><color>${hex}FF</color></image>
    <textlist name="gamelist">
      <selectorColor>${hex}FF</selectorColor>
      <selectedColor>FFFFFFFF</selectedColor>
      <secondaryColor>${hex}FF</secondaryColor>
      <scrollbarColor>${hex}60</scrollbarColor>
    </textlist>
  </view>
  <view name="detailed,video">
    <image name="painel"><color>FFFFFFD8</color></image>
  </view>
</theme>
"@
  [System.IO.File]::WriteAllText((Join-Path $cores "$id.xml"), $xml, $utf8)
  $total++
}
Write-Host "Arcádia v0.2: $total consoles (cards, logotipos claros e cores)$(if (-not $Previa) { ' + fundo, sombra e 5 telas de abertura' })."
