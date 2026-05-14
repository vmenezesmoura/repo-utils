from pathresolver_org import env

env.load_profile("tu") # string sufixo dentro de .env para múltiplas áreas de fluxo (exemplo: FIG_TU vai abrir para o perfil TU como a variável FIG)

print(env.REPO)