from pathlib import Path
import os
from dotenv import load_dotenv
from typing import Optional


# =========================================================
# Exceção customizada
# =========================================================
class EnvLoaderError(Exception):
    """Erro relacionado ao carregamento automático do arquivo .env"""
    pass


# =========================================================
# Cache interno (evita recarregar o .env várias vezes)
# =========================================================
_LOADED: bool = False
_LOADED_PATH: Optional[Path] = None


# =========================================================
# Localização do repositório
# =========================================================
def find_repo_root(start_path: Path) -> Path:
    """
    Sobe na árvore de diretórios até encontrar a pasta do projeto,
    definida como a pasta que contém pyproject.toml.
    """
    for parent in [start_path] + list(start_path.parents):
        if (parent / "pyproject.toml").exists():
            return parent

    raise EnvLoaderError(
        "Não foi possível encontrar o repositório (pyproject.toml não encontrado)."
    )


def validate_repo(repo_root: Path) -> None:
    """
    Garante que o diretório identificado realmente é um repositório válido,
    verificando a presença do pyproject.toml.
    """
    if not (repo_root / "pyproject.toml").exists():
        raise EnvLoaderError(
            f"O diretório {repo_root} não parece ser um repositório válido "
            f"(pyproject.toml não encontrado)."
        )


# =========================================================
# Resolução do caminho do .env
# =========================================================
def resolve_env_path(repo_root: Path, env_name: str) -> Path:
    """
    Resolve o caminho do .env.

    Prioridade:
    1) Variável de ambiente ENV_PATH (override manual)
    2) Caminho padrão dentro do repositório
    """
    custom_env = os.getenv("ENV_PATH")

    if custom_env:
        return Path(custom_env)

    return repo_root / env_name


# =========================================================
# Função principal
# =========================================================
def load_env(
    env_name: str = ".env",
    verbose: bool = True
) -> Path:
    """
    Carrega automaticamente o arquivo .env com:

    - Detecção automática do repositório (pelo pyproject.toml)
    - Validação da estrutura
    - Suporte a override via ENV_PATH
    - Cache (carrega apenas uma vez por sessão)

    Retorna:
        Path do .env carregado
    """

    global _LOADED, _LOADED_PATH

    # -----------------------------------------------------
    # Cache: evita recarregar
    # -----------------------------------------------------
    if _LOADED:
        assert _LOADED_PATH is not None
        return _LOADED_PATH

    cwd = Path.cwd()

    # -----------------------------------------------------
    # Validações de contexto
    # -----------------------------------------------------
    repo_root = find_repo_root(cwd)
    validate_repo(repo_root)

    # Adicionar src ao sys.path para permitir importações
    import sys
    src_path = str(repo_root / 'src')
    if src_path not in sys.path:
        sys.path.insert(0, src_path)

    # -----------------------------------------------------
    # Resolve caminho do .env
    # -----------------------------------------------------
    env_path = resolve_env_path(repo_root, env_name)

    if not env_path.exists():
        raise EnvLoaderError(f".env não encontrado em: {env_path}")

    # -----------------------------------------------------
    # Carrega variáveis de ambiente
    # -----------------------------------------------------
    load_dotenv(env_path)

    if verbose:
        print(f">> .env carregado de: {env_path}")

    # -----------------------------------------------------
    # Atualiza cache
    # -----------------------------------------------------
    _LOADED = True
    _LOADED_PATH = env_path

    return env_path