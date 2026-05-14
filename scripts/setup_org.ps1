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

$repoName = Split-Path (Get-Location) -Leaf

# detectar organização via config.py
$configFile = "src/pathresolver_org/config.py"

if (!(Test-Path $configFile)) {
    Write-Host ">> ERRO: config.py não encontrado em:" -ForegroundColor Red
    Write-Host "   $configFile"
    exit 1
}

$currentOrg = (
    Select-String -Path $configFile -Pattern 'ORG_NAME' |
    Select-Object -First 1
).Line -replace '.*=\s*"(.*)".*', '$1'

# se estiver genérico ou vazio
if ($currentOrg -eq "org" -or -not $currentOrg) {

    Write-Host ""
    $inputOrg = Read-Host "Informe o nome da organização"

    if (-not $inputOrg) {
        Write-Host ">> ERRO: organização inválida" -ForegroundColor Red
        exit 1
    }

    $content = Get-Content $configFile -Raw

    $content = $content -replace `
        'ORG_NAME.*=.*', `
        "ORG_NAME: str = `"$inputOrg`""

    Set-Content $configFile $content

    $orgName = $inputOrg

    Write-Host ">> Organização configurada: $orgName" -ForegroundColor Green

}
else {

    $orgName = $currentOrg

}

Write-Host ">> Organização       : $orgName" -ForegroundColor Cyan
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

    # caminhos comuns do Anaconda
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
        Write-Host ">> Anaconda encontrado em:" -ForegroundColor Yellow
        Write-Host "   $foundPath"

        Write-Host ""
        Write-Host ">> Você precisa adicionar ao PATH:"
        Write-Host "   $foundPath"
        Write-Host "   $foundPath\Scripts"
        Write-Host "   $foundPath\Library\bin"

        Write-Host ""
        Write-Host ">> Depois reinicie o terminal e rode novamente."
    }
    else {
        Write-Host ">> ERRO: Anaconda não encontrado no sistema." -ForegroundColor Red
        Write-Host ""
        Write-Host ">> Instale o Anaconda:"
        Write-Host "   https://www.anaconda.com/download/success"
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
# 5) Auto-ativação
# =============================

Write-Host ">> Configurando auto-ativação..."

$block = @"
# >>> AUTO-CONDA ($repoName) >>>

`$AUTO_CONDA_REPO   = "$repoName"
`$AUTO_CONDA_ORG    = "$orgName"
`$AUTO_CONDA_ENV    = "$envName"

# garante conda no PowerShell
`$condaHook = "`$env:USERPROFILE\anaconda3\shell\condabin\conda-hook.ps1"

if (Test-Path `$condaHook) {
    & `$condaHook
}

function Set-CondaEnvByFolder {
    `$current = Get-Location

    `$currentFolder = Split-Path `$current -Leaf
    `$parentFolder  = Split-Path (Split-Path `$current) -Leaf

    if (`$parentFolder -eq `$AUTO_CONDA_ORG -and `$currentFolder -eq `$AUTO_CONDA_REPO) {
        if (`$env:CONDA_DEFAULT_ENV -ne `$AUTO_CONDA_ENV) {
            conda activate `$AUTO_CONDA_ENV
        }
    }
    elseif (`$current.Path.Contains("\`$AUTO_CONDA_ORG\`$AUTO_CONDA_REPO\")) {
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
Write-Host ">> Reinicie o terminal (PowerShell) para que as alterações tenham efeito." -ForegroundColor Yellow