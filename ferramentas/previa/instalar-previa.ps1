# Arcádia — prepara/atualiza a prévia no Windows (RetroBat em arcadia-preview).
# Uso: powershell -ExecutionPolicy Bypass -File "D:\Adube Sistemas\Console de Jogo\console-retro-os\ferramentas\previa\instalar-previa.ps1"
# Pode ser rodado de novo sempre que o tema mudar (feche o RetroBat antes).
$ErrorActionPreference = 'Stop'
$repo  = 'D:\Adube Sistemas\Console de Jogo\console-retro-os'
$rb    = 'D:\Adube Sistemas\Console de Jogo\arcadia-preview'
$es    = "$rb\emulationstation\.emulationstation"
$temaRB = "$es\themes\arcadia"

if (Get-Process emulationstation, retrobat -ErrorAction SilentlyContinue) { throw 'Feche o RetroBat antes de atualizar a prévia.' }

# 1) Tema original + ajustes só da prévia (por cima, sem alterar o original do repositório)
robocopy "$repo\temas\arcadia" $temaRB /E /NFL /NDL /NJH /NJS /NP | Out-Null
robocopy "$repo\ferramentas\previa\ajustes-tema" $temaRB /E /NFL /NDL /NJH /NJS /NP | Out-Null

# 2) Configurações do EmulationStation do RetroBat
[xml]$x = Get-Content "$es\es_settings.cfg" -Encoding UTF8
function Definir($tipo, $nome, $valor) {
  $n = $x.config.SelectSingleNode("*[@name='$nome']")
  if (-not $n) { $n = $x.CreateElement($tipo); $n.SetAttribute('name', $nome); [void]$x.config.AppendChild($n) }
  $n.SetAttribute('value', $valor)
}
Definir 'string' 'ThemeSet' 'arcadia'                         # tema ativo
Definir 'string' 'Language' 'pt_BR'                           # português do Brasil
Definir 'string' 'global.autosave' '1'                        # savestate_auto_save/auto_load no RetroArch
Definir 'string' 'CollectionSystemsAuto' 'recent,favorites,all' # Continuar jogando, Favoritos, Todos os jogos
Definir 'string' 'GamelistViewStyle' 'detailed'
Definir 'bool'   'FavoritesFirst' 'true'
Definir 'string' 'StartupSystem' 'nes'                       # abre direto nos consoles (DESIGN.md); no aparelho, o primeiro console favorito
Definir 'bool'   'audio.bgmusic' 'false'                     # sem música de fundo na prévia
Definir 'bool'   'ShowSaveStates' 'true'                     # ao abrir jogo com save: escolher continuar ou começar do início
Definir 'bool'   'StartupOnGameList' 'false'
$x.Save("$es\es_settings.cfg")

# 3) retrobat.ini: tela cheia, sem vídeo de abertura e sem trocar o idioma automaticamente
$ini = "$rb\retrobat.ini"
if (-not (Test-Path $ini)) {
  @"
; Arcadia (previa) - gerado por ferramentas\previa\instalar-previa.ps1
[RetroBat]
LanguageDetection=0

[SplashScreen]
EnableIntro=0

[EmulationStation]
Fullscreen=1
FullscreenBorderless=1
"@ | Set-Content -Path $ini -Encoding ASCII
}

# 4) Jogos de teste (homebrew de distribuição liberada) e fichas em português
$jogos = "$rb\_jogos-teste"
foreach ($s in 'nes', 'megadrive', 'gbc') {
  Copy-Item "$jogos\$s\*" "$rb\roms\$s\" -Force
  $ficha = "$repo\ferramentas\previa\gamelists\$s.xml"
  if (-not (Test-Path "$rb\roms\$s\gamelist.xml")) { Copy-Item $ficha "$rb\roms\$s\gamelist.xml" }  # não sobrescreve progresso
}
Write-Host 'Prévia atualizada.'
