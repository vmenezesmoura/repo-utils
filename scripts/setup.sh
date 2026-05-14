#!/usr/bin/env bash

# =============================
# Setup automático ambiente (genérico)
# =============================

set -e

RECREATE_ENV=false

if [[ "$1" == "--recreate-env" ]]; then
    RECREATE_ENV=true
fi

echo ">> Iniciando setup..."

# =============================
# Variáveis dinâmicas
# =============================

PROJECT_ROOT="$(pwd)"
REPO_NAME="$(basename "$PROJECT_ROOT")"

echo ">> Repositório       : $REPO_NAME"

ENV_FILE="environment.yml"

if [[ ! -f "$ENV_FILE" ]]; then
    echo ">> ERRO: environment.yml não encontrado"
    exit 1
fi

ENV_NAME=$(grep -E '^\s*name\s*:' "$ENV_FILE" | head -n1 | sed -E 's/^\s*name\s*:\s*//')

if [[ -z "$ENV_NAME" ]]; then
    echo ">> ERRO: não foi possível identificar o nome do ambiente"
    exit 1
fi

echo ">> Ambiente detectado: $ENV_NAME"

# =============================
# CHECK 1: Conda disponível
# =============================

if ! command -v conda >/dev/null 2>&1; then
    echo ">> ERRO: Conda não encontrado no PATH"
    echo ">> Instale Miniconda ou Anaconda"
    exit 1
fi

echo ">> Conda detectado: OK"

# =============================
# Inicializar conda
# =============================

CONDA_BASE=$(conda info --base)
source "$CONDA_BASE/etc/profile.d/conda.sh"

# =============================
# Criar ambiente
# =============================

if ! conda env list | awk '{print $1}' | grep -qx "$ENV_NAME"; then

    echo ">> Criando ambiente conda..."
    conda env create -f "$ENV_FILE"

else

    if [[ "$RECREATE_ENV" == false ]]; then
        read -rp "Ambiente existe. Recriar? (y/n): " choice

        if [[ "$choice" =~ ^([yY]|[sS])$ ]]; then
            RECREATE_ENV=true
        fi
    fi

    if [[ "$RECREATE_ENV" == true ]]; then
        echo ">> Recriando ambiente..."

        conda deactivate || true
        conda env remove -n "$ENV_NAME" -y
        conda env create -f "$ENV_FILE"

    else
        echo ">> Mantendo ambiente existente."
    fi
fi

# =============================
# Kernel Jupyter
# =============================

echo ">> Configurando kernel Jupyter..."

KERNEL_NAME="$ENV_NAME"
KERNEL_DISPLAY="Python ($ENV_NAME)"

if command -v jupyter >/dev/null 2>&1; then

    if ! jupyter kernelspec list 2>/dev/null | grep -q "$KERNEL_NAME"; then

        echo ">> Instalando kernel..."

        conda run -n "$ENV_NAME" python -m ipykernel install \
            --user \
            --name "$KERNEL_NAME" \
            --display-name "$KERNEL_DISPLAY"

    else
        echo ">> Kernel já existe"
    fi
fi

# =============================
# PROFILE
# =============================

PROFILE_FILE="$HOME/.bashrc"

if [[ "$SHELL" == *"zsh"* ]]; then
    PROFILE_FILE="$HOME/.zshrc"
fi

touch "$PROFILE_FILE"

# =============================
# Auto-ativação
# =============================

echo ">> Configurando auto-ativação..."

BLOCK=$(cat <<EOF

# >>> AUTO-CONDA ($REPO_NAME) >>>

AUTO_CONDA_ROOT="$PROJECT_ROOT"
AUTO_CONDA_ENV="$ENV_NAME"

function set_conda_env_by_folder() {

    local current="\$(pwd)"

    if [[ "\$current" == "\$AUTO_CONDA_ROOT"* ]]; then

        if [[ "\$CONDA_DEFAULT_ENV" != "\$AUTO_CONDA_ENV" ]]; then
            conda activate "\$AUTO_CONDA_ENV"
        fi

    else

        if [[ "\$CONDA_DEFAULT_ENV" == "\$AUTO_CONDA_ENV" ]]; then
            conda deactivate
        fi
    fi
}

function cd() {
    builtin cd "\$@" || return
    set_conda_env_by_folder
}

set_conda_env_by_folder

# <<< AUTO-CONDA ($REPO_NAME) <<<

EOF
)

# remover bloco antigo
sed -i.bak '/# >>> AUTO-CONDA/,/# <<< AUTO-CONDA/d' "$PROFILE_FILE"

echo "$BLOCK" >> "$PROFILE_FILE"

# =============================
# Recarregar profile
# =============================

echo ">> Recarregando profile..."

# shellcheck source=/dev/null
source "$PROFILE_FILE"

# =============================
# Validação
# =============================

if declare -f set_conda_env_by_folder >/dev/null; then
    echo ">> Auto-ativação funcionando!"
else
    echo ">> ERRO: auto-ativação falhou"
fi

echo ">> Setup concluído!"
echo ">> Reinicie o terminal para garantir aplicação completa."