# Ubuntu Debian Scripts Collection

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%20|%2022.04%20|%2024.04-orange.svg)](https://ubuntu.com/)
[![Debian](https://img.shields.io/badge/Debian-11%20|%2012-red.svg)](https://debian.org/)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

Une collection de scripts utiles pour l'administration, la configuration et la maintenance des systèmes Ubuntu et Debian.

## 🚀 Fonctionnalités

- **Installation automatisée** : Scripts de post-installation et configuration d'environnement
- **Maintenance système** : Nettoyage, mises à jour et optimisation
- **Configuration serveur** : Nginx, Apache, bases de données, firewall
- **Utilitaires** : Monitoring, sauvegarde, analyse de logs
- **Scripts de développement** : Configuration d'environnements de développement

## 📋 Prérequis

- Ubuntu 20.04+ ou Debian 11+
- Bash 4.0+
- Droits sudo pour certains scripts

## 🛠️ Installation

```bash
# Cloner le repository
git clone https://github.com/NDXDeveloper/ubuntu-debian-scripts.git
cd ubuntu-debian-scripts

# Rendre les scripts exécutables
chmod +x **/*.sh

# Ou utiliser le script d'installation
./install.sh
```

## 📁 Structure du projet

```
ubuntu-debian-scripts/
├── 📂 installation/          # Scripts d'installation et configuration initiale
│   ├── post-install.sh       # Post-installation Ubuntu/Debian
│   ├── dev-environment.sh    # Configuration environnement de développement
│   └── server-setup.sh       # Configuration serveur de base
├── 📂 maintenance/           # Scripts de maintenance système
│   ├── system-cleanup.sh     # Nettoyage système automatique
│   ├── backup-scripts.sh     # Scripts de sauvegarde
│   └── security-updates.sh   # Mises à jour de sécurité
├── 📂 configuration/         # Scripts de configuration
│   ├── 📂 dotfiles/          # Fichiers de configuration
│   ├── nginx-config.sh       # Configuration Nginx
│   └── firewall-setup.sh     # Configuration UFW/iptables
├── 📂 utilities/             # Utilitaires divers
│   ├── monitoring.sh         # Monitoring système
│   └── log-analyzer.sh       # Analyse de logs
└── 📂 docs/                  # Documentation
    └── usage-examples.md     # Exemples d'utilisation
```

## 🎯 Utilisation rapide

### Script de post-installation
```bash
./installation/post-install.sh
```

### Nettoyage système
```bash
./maintenance/system-cleanup.sh
```

### Configuration serveur web
```bash
./configuration/nginx-config.sh
```

## 📖 Documentation

Chaque script contient une documentation intégrée accessible via :
```bash
./script-name.sh --help
```

Pour plus de détails, consultez le dossier [docs/](docs/) ou la documentation spécifique de chaque script.

## 🧪 Tests

Les scripts sont testés sur :
- Ubuntu 20.04 LTS (Focal Fossa)
- Ubuntu 22.04 LTS (Jammy Jellyfish)
- Ubuntu 24.04 LTS (Noble Numbat)
- Debian 11 (Bullseye)
- Debian 12 (Bookworm)

## 🤝 Contribution

Les contributions sont les bienvenues ! Veuillez :

1. Fork le projet
2. Créer une branche pour votre fonctionnalité (`git checkout -b feature/nouvelle-fonctionnalite`)
3. Commiter vos changements (`git commit -am 'Ajouter nouvelle fonctionnalité'`)
4. Pusher la branche (`git push origin feature/nouvelle-fonctionnalite`)
5. Ouvrir une Pull Request

### Guidelines de contribution

- Testez vos scripts sur au moins 2 distributions
- Ajoutez une documentation claire
- Respectez les conventions de nommage
- Incluez la gestion d'erreurs appropriée


## 📄 License

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 👨‍💻 Auteur

**Nicolas DEOUX**
- Email : NDXDev@gmail.com
- GitHub : [@NDXDeveloper](https://github.com/NDXDeveloper)

## 🙏 Remerciements

- La communauté Ubuntu/Debian pour les ressources et la documentation
- Tous les contributeurs qui ont aidé à améliorer ces scripts

## ⚠️ Avertissement

Ces scripts modifient la configuration système. Utilisez-les avec prudence et toujours dans un environnement de test d'abord. L'auteur n'est pas responsable des dommages potentiels causés par l'utilisation de ces scripts.

---


