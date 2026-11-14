# Arcádia — copia os documentos oficiais do repositório para a pasta docs\ da raiz do projeto.
# Uso: powershell -ExecutionPolicy Bypass -File "D:\Adube Sistemas\Console de Jogo\console-retro-os\ferramentas\copiar-docs.ps1"
$origem  = 'D:\Adube Sistemas\Console de Jogo\console-retro-os\docs'
$destino = 'D:\Adube Sistemas\Console de Jogo\docs'
New-Item -ItemType Directory -Force $destino | Out-Null
# /XO: não sobrescreve cópias mais novas; arquivos só da cópia são mantidos (nada é apagado)
robocopy $origem $destino /E /XO /NJH /NJS /NP | Out-Null
Get-ChildItem $destino -Recurse -File | Select-Object @{n="Arquivo";e={$_.FullName.Substring($destino.Length + 1)}}, LastWriteTime
