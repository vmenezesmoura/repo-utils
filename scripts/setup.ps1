# =============================
# Setup automático ambiente (genérico)
# =============================

param(
    [switch]$RecreateEnv
)

Write-Host ">> Iniciando setup..." -ForegroundColor Cyan

# =============================
# Variáveis dinâmicas
# =============================

$projectRoot = (Get-Location).Path
$repoName = Split-Path $projectRoot -Leaf

Write-Host ">> Repositório       : $repoName" -ForegroundColor Cyan

# pegar nome do env no environment.yml
$envFile = "environment.yml"

if (!(Test-Path $envFile)) {
    Write-Host ">> ERRO: environment.yml não encontrado" -ForegroundColor Red
    exit 1
}

$envName = (Select-String -Path $envFile -Pattern "^\s*name\s*:" |
    Select-Object -First 1).Line -replace "^\s*name\s*:\s*", ""

if (-not $envName) {
    Write-Host ">> ERRO: não foi possível identificar o nome do ambiente no environment.yml" -ForegroundColor Red
    exit 1
}

Write-Host ">> Ambiente detectado: $envName"

# =============================
# CHECK 0: PowerShell Core (pwsh)
# =============================

if ($PSVersionTable.PSEdition -ne "Core") {
    Write-Host ">> ERRO: Este script deve ser executado no PowerShell 7 (pwsh)." -ForegroundColor Red
    Write-Host ">> Você está usando Windows PowerShell (antigo)." -ForegroundColor Yellow
    Write-Host ""
    Write-Host ">> Abra o terminal 'pwsh' e execute novamente."
    Write-Host ">> Exemplo:"
    Write-Host "   pwsh ./setup.ps1"
    exit 1
}

# =============================
# CHECK 1: Conda disponível
# =============================

$condaCmd = Get-Command conda -ErrorAction SilentlyContinue

if (-not $condaCmd) {

    Write-Host ">> Conda não encontrado no PATH." -ForegroundColor Yellow

    $possiblePaths = @(
        "`$env:USERPROFILE\anaconda3",
        "C:\ProgramData\anaconda3"
    )

    $foundPath = $null

    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $foundPath = $path
            break
        }
    }

    if ($foundPath) {
        Write-Host ">> Anaconda encontrado em:"
        Write-Host "   $foundPath"

        Write-Host ""
        Write-Host ">> Adicione ao PATH:"
        Write-Host "   $foundPath"
        Write-Host "   $foundPath\Scripts"
        Write-Host "   $foundPath\Library\bin"
    }
    else {
        Write-Host ">> ERRO: Anaconda não encontrado no sistema." -ForegroundColor Red
        Write-Host ">> Instale: https://www.anaconda.com/download/success"
    }

    exit 1
}
else {
    Write-Host ">> Conda detectado: OK"
}

# =============================
# 1) Inicializar conda
# =============================
conda init powershell | Out-Null

# =============================
# 2) Criar ambiente
# =============================

$envExists = conda env list | Select-String "^\s*$envName\s"

if (-not $envExists) {
    Write-Host ">> Criando ambiente conda..."
    conda env create -f $envFile
}
else {
    if (-not $RecreateEnv) {
        $choice = Read-Host "Ambiente existe. Recriar? (y/n)"
        $RecreateEnv = $choice -match '^(y|Y|s|S)$'
    }

    if ($RecreateEnv) {
        Write-Host ">> Recriando ambiente..."
        conda deactivate 2>$null
        conda env remove -n $envName -y
        conda env create -f $envFile
    }
    else {
        Write-Host ">> Mantendo ambiente existente."
    }
}

# =============================
# 3) Kernel Jupyter
# =============================

Write-Host ">> Configurando kernel Jupyter..."

$kernelName = $envName
$kernelDisplay = "Python ($envName)"

if (Get-Command jupyter -ErrorAction SilentlyContinue) {
    $kernels = jupyter kernelspec list 2>$null

    if ($kernels -notmatch $kernelName) {
        Write-Host ">> Instalando kernel..."
        conda run -n $envName python -m ipykernel install `
            --user `
            --name $kernelName `
            --display-name $kernelDisplay
    }
    else {
        Write-Host ">> Kernel já existe"
    }
}

# =============================
# 4) PROFILE
# =============================

$profilePath = $PROFILE.CurrentUserCurrentHost

if (!(Test-Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
    Write-Host ">> Profile criado em $profilePath"
}

# =============================
# 5) Auto-ativação (NOVA LÓGICA)
# =============================

Write-Host ">> Configurando auto-ativação..."

$block = @"
# >>> AUTO-CONDA ($repoName) >>>

`$AUTO_CONDA_ROOT = "$projectRoot"
`$AUTO_CONDA_ENV  = "$envName"

# garante conda no PowerShell
`$condaHook = "`$env:USERPROFILE\anaconda3\shell\condabin\conda-hook.ps1"

if (Test-Path `$condaHook) {
    & `$condaHook
}

function Set-CondaEnvByFolder {
    `$current = (Get-Location).Path

    if (`$current.StartsWith(`$AUTO_CONDA_ROOT)) {
        if (`$env:CONDA_DEFAULT_ENV -ne `$AUTO_CONDA_ENV) {
            conda activate `$AUTO_CONDA_ENV
        }
    }
    else {
        if (`$env:CONDA_DEFAULT_ENV -eq `$AUTO_CONDA_ENV) {
            conda deactivate
        }
    }
}

# intercepta cd
function global:Set-Location {
    param([string]`$Path)

    Microsoft.PowerShell.Management\Set-Location `$Path
    Set-CondaEnvByFolder
}

# roda ao abrir terminal
Set-CondaEnvByFolder

# <<< AUTO-CONDA ($repoName) <<<
"@

# remover bloco antigo
$content = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
$content = $content -replace "(?s)# >>> AUTO-CONDA.*?# <<< AUTO-CONDA.*?<<<", ""

Set-Content $profilePath ($content + "`n" + $block)

# =============================
# 6) Recarregar
# =============================

Write-Host ">> Recarregando PROFILE..."
. $profilePath

# =============================
# 7) Validação
# =============================

if (Get-Command Set-CondaEnvByFolder -ErrorAction SilentlyContinue) {
    Write-Host ">> Auto-ativação funcionando!" -ForegroundColor Green
}
else {
    Write-Host ">> ERRO: Profile não carregou corretamente" -ForegroundColor Red
}

Write-Host ">> Setup concluído!" -ForegroundColor Green
Write-Host ">> Reinicie o terminal para aplicar tudo." -ForegroundColor Yellow