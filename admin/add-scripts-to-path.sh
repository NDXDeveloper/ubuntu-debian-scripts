#!/bin/bash

# Script pour ajouter un dossier scripts au PATH
# Auteur: NDXDev NDXDev@gmail.com
# Version: 1.0
# Date: 2025-07-18

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration par défaut
DEFAULT_SCRIPTS_DIR="$HOME/scripts"
SCRIPTS_DIR=""
SHELL_CONFIG=""

# Fonction pour afficher les messages avec couleurs
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Fonction pour détecter le shell et le fichier de configuration
detect_shell() {
    local current_shell=$(basename "$SHELL")

    print_message $BLUE "Shell détecté: $current_shell"

    case $current_shell in
        bash)
            if [ -f "$HOME/.bashrc" ]; then
                SHELL_CONFIG="$HOME/.bashrc"
            elif [ -f "$HOME/.bash_profile" ]; then
                SHELL_CONFIG="$HOME/.bash_profile"
            else
                SHELL_CONFIG="$HOME/.bashrc"
            fi
            ;;
        zsh)
            SHELL_CONFIG="$HOME/.zshrc"
            ;;
        fish)
            SHELL_CONFIG="$HOME/.config/fish/config.fish"
            ;;
        *)
            SHELL_CONFIG="$HOME/.profile"
            ;;
    esac

    print_message $BLUE "Fichier de configuration: $SHELL_CONFIG"
}

# Fonction pour vérifier si le dossier existe
check_scripts_directory() {
    if [ ! -d "$SCRIPTS_DIR" ]; then
        print_message $YELLOW "Le dossier $SCRIPTS_DIR n'existe pas."
        read -p "Voulez-vous le créer? (O/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            print_message $RED "Opération annulée"
            exit 1
        else
            mkdir -p "$SCRIPTS_DIR"
            print_message $GREEN "Dossier créé: $SCRIPTS_DIR"
        fi
    else
        print_message $GREEN "Le dossier $SCRIPTS_DIR existe déjà"
    fi
}

# Fonction pour vérifier si le PATH contient déjà le dossier
check_path_exists() {
    if echo "$PATH" | grep -q "$SCRIPTS_DIR"; then
        print_message $YELLOW "Le dossier $SCRIPTS_DIR est déjà dans votre PATH"
        return 0
    else
        return 1
    fi
}

# Fonction pour vérifier si l'export existe déjà dans le fichier de config
check_export_exists() {
    if [ -f "$SHELL_CONFIG" ] && grep -q "export PATH.*$SCRIPTS_DIR" "$SHELL_CONFIG"; then
        print_message $YELLOW "L'export PATH pour $SCRIPTS_DIR existe déjà dans $SHELL_CONFIG"
        return 0
    else
        return 1
    fi
}

# Fonction pour ajouter le PATH selon le shell
add_to_path() {
    local current_shell=$(basename "$SHELL")

    # Créer le fichier de config s'il n'existe pas
    if [ ! -f "$SHELL_CONFIG" ]; then
        touch "$SHELL_CONFIG"
        print_message $BLUE "Fichier de configuration créé: $SHELL_CONFIG"
    fi

    # Ajouter une ligne vide si le fichier n'est pas vide
    if [ -s "$SHELL_CONFIG" ]; then
        echo "" >> "$SHELL_CONFIG"
    fi

    # Ajouter le commentaire et l'export selon le shell
    case $current_shell in
        fish)
            echo "# Ajout du dossier scripts au PATH" >> "$SHELL_CONFIG"
            echo "set -gx PATH \"$SCRIPTS_DIR\" \$PATH" >> "$SHELL_CONFIG"
            ;;
        *)
            echo "# Ajout du dossier scripts au PATH" >> "$SHELL_CONFIG"
            echo "export PATH=\"$SCRIPTS_DIR:\$PATH\"" >> "$SHELL_CONFIG"
            ;;
    esac

    print_message $GREEN "PATH ajouté à $SHELL_CONFIG"
}

# Fonction pour recharger la configuration
reload_config() {
    local current_shell=$(basename "$SHELL")

    print_message $BLUE "Rechargement de la configuration..."

    case $current_shell in
        bash)
            source "$SHELL_CONFIG"
            ;;
        zsh)
            source "$SHELL_CONFIG"
            ;;
        fish)
            # Fish recharge automatiquement, mais on peut forcer
            fish -c "source $SHELL_CONFIG" 2>/dev/null || true
            ;;
        *)
            source "$SHELL_CONFIG"
            ;;
    esac

    print_message $GREEN "Configuration rechargée"
}

# Fonction pour afficher le résumé
show_summary() {
    print_message $CYAN "=== RÉSUMÉ ==="
    print_message $BLUE "Dossier ajouté: $SCRIPTS_DIR"
    print_message $BLUE "Fichier modifié: $SHELL_CONFIG"
    print_message $BLUE "Shell: $(basename "$SHELL")"
    echo
    print_message $GREEN "✅ Le dossier $SCRIPTS_DIR est maintenant dans votre PATH"
    print_message $YELLOW "📝 Conseil: Placez vos scripts dans ce dossier et rendez-les exécutables avec 'chmod +x'"
    echo
    print_message $BLUE "Pour vérifier, utilisez: echo \$PATH"
}

# Fonction pour afficher l'aide
show_help() {
    echo "Usage: $0 [OPTIONS] [DOSSIER]"
    echo
    echo "Ce script ajoute un dossier scripts à votre variable PATH"
    echo
    echo "Arguments:"
    echo "  DOSSIER           Dossier à ajouter au PATH (défaut: ~/scripts)"
    echo
    echo "Options:"
    echo "  -h, --help        Afficher cette aide"
    echo "  -c, --check       Vérifier seulement si le dossier est dans PATH"
    echo "  -f, --force       Forcer l'ajout même si déjà présent"
    echo
    echo "Exemples:"
    echo "  $0                           # Ajouter ~/scripts au PATH"
    echo "  $0 ~/bin                     # Ajouter ~/bin au PATH"
    echo "  $0 /usr/local/scripts        # Ajouter un dossier système"
    echo "  $0 --check ~/scripts         # Vérifier si ~/scripts est dans PATH"
}

# Variables pour les options
CHECK_ONLY=false
FORCE_ADD=false

# Analyse des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--check)
            CHECK_ONLY=true
            shift
            ;;
        -f|--force)
            FORCE_ADD=true
            shift
            ;;
        -*)
            print_message $RED "Option inconnue: $1"
            show_help
            exit 1
            ;;
        *)
            SCRIPTS_DIR="$1"
            shift
            ;;
    esac
done

# Utiliser le dossier par défaut si aucun n'est spécifié
if [ -z "$SCRIPTS_DIR" ]; then
    SCRIPTS_DIR="$DEFAULT_SCRIPTS_DIR"
fi

# Convertir le chemin relatif en chemin absolu
SCRIPTS_DIR=$(realpath "$SCRIPTS_DIR" 2>/dev/null || echo "$SCRIPTS_DIR")

# Fonction principale
main() {
    print_message $GREEN "=== AJOUT DU DOSSIER SCRIPTS AU PATH ==="
    print_message $BLUE "Dossier cible: $SCRIPTS_DIR"
    echo

    # Détecter le shell et le fichier de configuration
    detect_shell
    echo

    # Mode vérification seulement
    if [ "$CHECK_ONLY" = true ]; then
        if check_path_exists; then
            print_message $GREEN "✅ Le dossier est dans votre PATH actuel"
        else
            print_message $RED "❌ Le dossier n'est pas dans votre PATH actuel"
        fi

        if check_export_exists; then
            print_message $GREEN "✅ L'export existe dans $SHELL_CONFIG"
        else
            print_message $RED "❌ Aucun export trouvé dans $SHELL_CONFIG"
        fi
        exit 0
    fi

    # Vérifier si le dossier existe
    check_scripts_directory
    echo

    # Vérifier si déjà dans PATH
    if check_path_exists && [ "$FORCE_ADD" = false ]; then
        print_message $GREEN "Le dossier est déjà dans votre PATH. Rien à faire!"
        exit 0
    fi

    # Vérifier si l'export existe déjà
    if check_export_exists && [ "$FORCE_ADD" = false ]; then
        print_message $YELLOW "L'export existe déjà. Redémarrez votre terminal ou utilisez --force"
        exit 0
    fi

    # Ajouter au PATH
    print_message $BLUE "Ajout du dossier au PATH..."
    add_to_path
    echo

    # Recharger la configuration
    reload_config
    echo

    # Afficher le résumé
    show_summary
}

# Exécution du script principal
main
