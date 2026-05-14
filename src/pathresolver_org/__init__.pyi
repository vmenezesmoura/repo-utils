from typing import Any, Dict

class Env:
    DROPBOX: str
    OUTPUT: str
    LOG: str

    def load_profile(self, profile: str | None = ...) -> Dict[str, str]: ...
    def __getattr__(self, name: str) -> Any: ...

env: Env

def load_profile(profile: str | None = ...) -> Dict[str, str]: ...