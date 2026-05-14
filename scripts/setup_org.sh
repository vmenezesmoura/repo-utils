#!/usr/bin/env bash

# =============================
# Setup automático ambiente (genérico)
# =============================

set -e

echo ">> Iniciando setup..."

# =============================
# Variáveis dinâmicas
# =============================

REPO_NAME="$(basename "$PWD")"

# detectar organização via config.py
CONFIG_FILE="src/pathresolver_org/config.py"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo ">> ERRO: config.py não encontrado em:"
    echo "   $CONFIG_FILE"
    exit 1
fi

CURRENT_ORG=$(grep "ORG_NAME" "$CONFIG_FILE" | sed -E 's/.*=\s*"([^"]+)".*/\1/' | head -n1)

# se estiver genérico ou vazio
if [[ "$CURRENT_ORG" == "org" || -z "$CURRENT_ORG" ]]; then

    echo ""
    read -p "Informe o nome da organização: " INPUT_ORG

    if [[ -z "$INPUT_ORG" ]]; then
        echo ">> ERRO: organização inválida"
        exit 1
    fi

    sed -i.bak -E \
        "s|ORG_NAME.*=.*|ORG_NAME: str = \"$INPUT_ORG\"|" \
        "$CONFIG_FILE"

    ORG_NAME="$INPUT_ORG"

    echo ">> Organização configurada: $ORG_NAME"

else

    ORG_NAME="$CURRENT_ORG"

fi

echo ">> Organização       : $ORG_NAME"
echo ">> Repositório       : $REPO_NAME"

ENV_FILE="environment.yml"

if [[ ! -f "$ENV_FILE" ]]; then
    echo ">> ERRO: environment.yml não encontrado"
    exit 1
fi

# pegar nome do env
ENV_NAME=$(grep -E '^\s*name\s*:' "$ENV_FILE" | head -n1 | sed 's/.*:\s*//')

if [[ -z "$ENV_NAME" ]]; then
    echo ">> ERRO: não foi possível identificar o nome do ambiente"
    exit 1
fi

echo ">> Ambiente detectado: $ENV_NAME"

# =============================
# 1) Inicializar conda
# =============================

conda init bash >/dev/null 2>&1 || true

# carregar conda na sessão atual
if command -v conda >/dev/null 2>&1; then
    source "$(conda info --base)/etc/profile.d/conda.sh"
fi

# =============================
# 2) Criar ambiente
# =============================

if ! conda env list | grep -qE "^\s*$ENV_NAME\s"; then

    echo ">> Criando ambiente conda..."
    conda env create -f "$ENV_FILE"

else

    if [[ "$1" != "--recreate" ]]; then
        read -p "Ambiente existe. Recriar? (y/n): " CHOICE

        [[ "$CHOICE" =~ ^[yYsS]$ ]] && RECREATE=true || RECREATE=false

    else
        RECREATE=true
    fi

    if [[ "$RECREATE" = true ]]; then

        echo ">> Recriando ambiente..."

        conda deactivate 2>/dev/null || true
        conda env remove -n "$ENV_NAME" -y
        conda env create -f "$ENV_FILE"

    else
        echo ">> Mantendo ambiente existente."
    fi
fi

# =============================
# 3) Kernel Jupyter
# =============================

echo ">> Configurando kernel Jupyter..."

if command -v jupyter >/dev/null 2>&1; then

    if ! jupyter kernelspec list 2>/dev/null | grep -q "$ENV_NAME"; then

        echo ">> Instalando kernel..."

        conda run -n "$ENV_NAME" python -m ipykernel install \
            --user \
            --name "$ENV_NAME" \
            --display-name "Python ($ENV_NAME)"

    else
        echo ">> Kernel já existe"
    fi
fi

# =============================
# 4) PROFILE (~/.bashrc)
# =============================

PROFILE_PATH="$HOME/.bashrc"

touch "$PROFILE_PATH"

# =============================
# 5) Auto-ativação
# =============================

echo ">> Configurando auto-ativação..."

BLOCK=$(cat <<EOF

# >>> AUTO-CONDA ($REPO_NAME) >>>

AUTO_CONDA_REPO="$REPO_NAME"
AUTO_CONDA_ORG="$ORG_NAME"
AUTO_CONDA_ENV="$ENV_NAME"

# garantir conda
if [ -f "\$(conda info --base)/etc/profile.d/conda.sh" ]; then
    source "\$(conda info --base)/etc/profile.d/conda.sh"
fi

AUTO_CONDA_ACTIVATE() {

    CURRENT="\$PWD"

    if [[ "\$CURRENT" == *"/\$AUTO_CONDA_ORG/\$AUTO_CONDA_REPO" ]]; then

        if [[ "\$CONDA_DEFAULT_ENV" != "\$AUTO_CONDA_ENV" ]]; then
            conda activate "\$AUTO_CONDA_ENV"
        fi

    elif [[ "\$CURRENT" == *"/\$AUTO_CONDA_ORG/\$AUTO_CONDA_REPO/"* ]]; then

        if [[ "\$CONDA_DEFAULT_ENV" != "\$AUTO_CONDA_ENV" ]]; then
            conda activate "\$AUTO_CONDA_ENV"
        fi

    else

        if [[ "\$CONDA_DEFAULT_ENV" == "\$AUTO_CONDA_ENV" ]]; then
            conda deactivate
        fi
    fi
}

# hook no cd
cd() {
    builtin cd "\$@" || return
    AUTO_CONDA_ACTIVATE
}

# rodar ao abrir terminal
AUTO_CONDA_ACTIVATE

# <<< AUTO-CONDA ($REPO_NAME) <<<

EOF
)

# remover bloco antigo
sed -i '/# >>> AUTO-CONDA/,/# <<< AUTO-CONDA/d' "$PROFILE_PATH"

# adicionar novo
echo "$BLOCK" >> "$PROFILE_PATH"

# =============================
# FINAL
# =============================

echo ">> Setup concluído!"
echo ">> Execute: source ~/.bashrc ou abra um novo terminal"