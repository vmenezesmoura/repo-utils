import os
from .env_loader import load_env, EnvLoaderError
from .config import ORG_NAME

load_env(verbose=False)

__all__ = ["load_env", "EnvLoaderError", "ORG_NAME", "load_profile", "env"]

# variáveis base controladas
lista_en_vars = ["DROPBOX", "OUTPUT", "LOG"]


class _Env:
    def __init__(self):
        self._data: dict[str, str] = {}

    def load_profile(self, profile: str | None = None):
        # ---------------------------------------------
        # 1. base
        # ---------------------------------------------
        data: dict[str, str] = {}

        for key in lista_en_vars:
            value = os.getenv(key)
            if value is not None:
                data[key] = value

        # ---------------------------------------------
        # 2. profile (override + extras)
        # ---------------------------------------------
        if profile:
            profile = profile.upper()

            profile_vars = {
                key.replace(f"_{profile}", ""): value
                for key, value in os.environ.items()
                if key.endswith(f"_{profile}")
            }

            data.update(profile_vars)

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


def load_profile(profile: str | None = None):
    return env.load_profile(profile)


# 👇 carrega base por padrão
env.load_profile()