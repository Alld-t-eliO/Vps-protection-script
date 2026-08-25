# Automatisation Mac vers VPS

Les commandes sont lancées depuis le Mac, à la racine du projet.

```bash
cp .vps.env.example .vps.env
chmod 600 .vps.env
```

Renseignez `VPS_HOST` dans `.vps.env`. Le script suppose que l'authentification SSH par clé
fonctionne déjà ; il n'accepte pas de mot de passe en mode interactif pendant une automatisation.

```bash
./scripts/vps check
./scripts/vps deploy
./scripts/vps status
./scripts/vps logs
./scripts/vps restart
./scripts/vps backup-pull
```

Le déploiement ne transfère jamais `.env`, `data/`, les environnements virtuels ou les
sauvegardes locales. Le fichier `.env` de production reste uniquement sur le VPS.
