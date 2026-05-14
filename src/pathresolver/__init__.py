import os
from .env_loader import load_env, EnvLoaderError

load_env(verbose=False)

__all__ = ["load_env", "EnvLoaderError", "load_profile", "env"]


class _Env:
    def __init__(self):
        self._data: dict[str, str] = {}

    def load_profile(self):
        # ---------------------------------------------
        # Carrega todas as variáveis de ambiente
        # ---------------------------------------------
        data: dict[str, str] = {}

        for key, value in os.environ.items():
            data[key] = value

        self._data = data
        return data

    def __getattr__(self, name: str) -> str:
        if name in self._data:
            return self._data[name]

        raise AttributeError(f"Variável '{name}' não encontrada no env")

    def __repr__(self):
        return f"<Env keys={list(self._data.keys())}>"


# instância única
env = _Env()


def load_profile():
    return env.load_profile()


# 👇 carrega todas as variáveis por padrão
env.load_profile()