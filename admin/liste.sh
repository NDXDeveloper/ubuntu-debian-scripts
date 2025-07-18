#!/bin/bash

# Script de gestion et listage des scripts personnels
# Auteur: NDXDev@gmail.com
# Usage: ./list-scripts.sh [--detailed] [--run SCRIPT] [--help]

# Configuration
SCRIPTS_DIR="$HOME/scripts"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# Variables pour options
DETAILED=false
RUN_SCRIPT=""
SHOW_HELP=false

# Fonction d'affichage avec couleurs
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Fonction d'aide
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Gestionnaire et listage des scripts personnels"
    echo
    echo "Options:"
    echo "  -h, --help              Afficher cette aide"
    echo "  -d, --detailed          Affichage détaillé avec descriptions"
    echo "  -r, --run SCRIPT        Exécuter un script interactivement"
    echo "  -i, --info SCRIPT       Informations détaillées sur un script"
    echo "  -e, --edit SCRIPT       Éditer un script"
    echo "  --check                 Vérifier l'intégrité des scripts"
    echo "  --stats                 Statistiques des scripts"
    echo
    echo "Exemples:"
    echo "  $0                      # Liste simple"
    echo "  $0 -d                   # Liste détaillée"
    echo "  $0 -r update-debian     # Exécuter update-debian.sh"
    echo "  $0 -i backup-config     # Infos sur backup-config.sh"
}

# Fonction pour extraire la description d'un script
get_script_description() {
    local script_file=$1

    if [ ! -f "$script_file" ]; then
        echo "Script non trouvé"
        return
    fi

    # Chercher les commentaires de description en début de fichier
    local description=$(head -10 "$script_file" | grep -E "^#.*[Ss]cript|^#.*[Dd]escription|^#.*[Aa]uteur" | head -1 | sed 's/^# *//')

    if [ -z "$description" ]; then
        # Chercher dans les 20 premières lignes un commentaire explicatif
        description=$(head -20 "$script_file" | grep -E "^#.*[Pp]our|^#.*[Gg]estion|^#.*[Mm]onitor|^#.*[Nn]ettoyage|^#.*[Ss]auvegarde|^#.*[Aa]udit" | head -1 | sed 's/^# *//')
    fi

    if [ -z "$description" ]; then
        echo "Aucune description disponible"
    else
        echo "$description"
    fi
}

# Fonction pour obtenir la taille d'un fichier
get_file_size() {
    local file=$1
    if [ -f "$file" ]; then
        local size=$(stat -c%s "$file")
        if [ $size -lt 1024 ]; then
            echo "${size}B"
        elif [ $size -lt 1048576 ]; then
            echo "$((size/1024))KB"
        else
            echo "$((size/1048576))MB"
        fi
    else
        echo "N/A"
    fi
}

# Fonction pour obtenir la date de modification
get_modification_date() {
    local file=$1
    if [ -f "$file" ]; then
        stat -c %y "$file" | cut -d' ' -f1
    else
        echo "N/A"
    fi
}

# Fonction pour vérifier si un script est exécutable
is_executable() {
    local file=$1
    if [ -x "$file" ]; then
        echo "✓"
    else
        echo "✗"
    fi
}

# Fonction pour compter les lignes de code
count_lines() {
    local file=$1
    if [ -f "$file" ]; then
        wc -l < "$file"
    else
        echo "0"
    fi
}

# Fonction de listage simple
list_scripts_simple() {
    print_message $BOLD "📁 Scripts disponibles dans $SCRIPTS_DIR"
    echo

    if [ ! -d "$SCRIPTS_DIR" ]; then
        print_message $RED "❌ Répertoire $SCRIPTS_DIR non trouvé"
        return 1
    fi

    local script_count=0

    # Header du tableau
    printf "${CYAN}%-25s %-12s %-12s %-8s${NC}\n" "NOM" "TAILLE" "MODIFIÉ" "EXEC"
    print_message $CYAN "────────────────────────────────────────────────────────────"

    # Lister tous les fichiers .sh
    for script in "$SCRIPTS_DIR"/*.sh; do
        if [ -f "$script" ]; then
            local basename=$(basename "$script")
            local size=$(get_file_size "$script")
            local mod_date=$(get_modification_date "$script")
            local executable=$(is_executable "$script")

            # Couleur selon l'état exécutable
            if [ "$executable" = "✓" ]; then
                printf "${GREEN}%-25s${NC} %-12s %-12s %-8s\n" "$basename" "$size" "$mod_date" "$executable"
            else
                printf "${YELLOW}%-25s${NC} %-12s %-12s ${RED}%-8s${NC}\n" "$basename" "$size" "$mod_date" "$executable"
            fi

            script_count=$((script_count + 1))
        fi
    done

    echo
    print_message $BLUE "📊 Total: $script_count scripts trouvés"

    if [ $script_count -eq 0 ]; then
        print_message $YELLOW "💡 Aucun script .sh trouvé dans $SCRIPTS_DIR"
        print_message $CYAN "   Créez vos scripts avec: nano $SCRIPTS_DIR/mon-script.sh"
    fi
}

# Fonction de listage détaillé
list_scripts_detailed() {
    print_message $BOLD "📁 Scripts détaillés dans $SCRIPTS_DIR"
    echo

    if [ ! -d "$SCRIPTS_DIR" ]; then
        print_message $RED "❌ Répertoire $SCRIPTS_DIR non trouvé"
        return 1
    fi

    local script_count=0

    for script in "$SCRIPTS_DIR"/*.sh; do
        if [ -f "$script" ]; then
            local basename=$(basename "$script" .sh)
            local size=$(get_file_size "$script")
            local mod_date=$(get_modification_date "$script")
            local executable=$(is_executable "$script")
            local lines=$(count_lines "$script")
            local description=$(get_script_description "$script")

            # Affichage avec style
            print_message $BOLD "🔧 $basename"
            echo "   📄 Fichier: $(basename "$script")"
            echo "   📊 Taille: $size ($lines lignes)"
            echo "   📅 Modifié: $mod_date"
            echo -n "   🔑 Exécutable: "
            if [ "$executable" = "✓" ]; then
                print_message $GREEN "$executable"
            else
                print_message $RED "$executable (chmod +x requis)"
            fi
            echo "   📝 Description: $description"

            # Tenter d'extraire l'usage si disponible
            local usage=$(grep -E "^# Usage:" "$script" | head -1 | sed 's/^# Usage: *//')
            if [ -n "$usage" ]; then
                echo "   💡 Usage: $usage"
            fi

            echo
            script_count=$((script_count + 1))
        fi
    done

    print_message $BLUE "📊 Total: $script_count scripts analysés"
}

# Fonction pour afficher les informations d'un script spécifique
show_script_info() {
    local script_name=$1
    local script_file="$SCRIPTS_DIR/${script_name}.sh"

    # Permettre avec ou sans extension
    if [ ! -f "$script_file" ]; then
        script_file="$SCRIPTS_DIR/${script_name}"
    fi

    if [ ! -f "$script_file" ]; then
        print_message $RED "❌ Script '$script_name' non trouvé dans $SCRIPTS_DIR"
        return 1
    fi

    local basename=$(basename "$script_file")
    local size=$(get_file_size "$script_file")
    local mod_date=$(get_modification_date "$script_file")
    local executable=$(is_executable "$script_file")
    local lines=$(count_lines "$script_file")
    local description=$(get_script_description "$script_file")

    print_message $BOLD "📋 Informations détaillées: $basename"
    echo
    print_message $CYAN "📁 Chemin complet: $script_file"
    print_message $CYAN "📊 Taille: $size"
    print_message $CYAN "📏 Lignes de code: $lines"
    print_message $CYAN "📅 Dernière modification: $mod_date"

    echo -n "🔑 Exécutable: "
    if [ "$executable" = "✓" ]; then
        print_message $GREEN "Oui"
    else
        print_message $RED "Non (chmod +x requis)"
    fi

    print_message $CYAN "📝 Description: $description"

    # Permissions détaillées
    local perms=$(stat -c %A "$script_file")
    print_message $CYAN "🔐 Permissions: $perms"

    # Chercher les options disponibles
    echo
    print_message $BLUE "💡 Options disponibles:"
    grep -E "^\s*-[a-zA-Z].*\)" "$script_file" | head -10 | while read option; do
        echo "   $option"
    done

    # Afficher l'aide si disponible
    if grep -q "\-\-help\|show_help" "$script_file"; then
        echo
        print_message $GREEN "ℹ️  Aide disponible avec: $basename --help"
    fi
}

# Fonction pour exécuter un script interactivement
run_script_interactive() {
    local script_name=$1
    local script_file="$SCRIPTS_DIR/${script_name}.sh"

    # Permettre avec ou sans extension
    if [ ! -f "$script_file" ]; then
        script_file="$SCRIPTS_DIR/${script_name}"
    fi

    if [ ! -f "$script_file" ]; then
        print_message $RED "❌ Script '$script_name' non trouvé"
        return 1
    fi

    if [ ! -x "$script_file" ]; then
        print_message $YELLOW "⚠️  Script non exécutable. Correction automatique..."
        chmod +x "$script_file"
        print_message $GREEN "✓ Permissions corrigées"
    fi

    print_message $BOLD "🚀 Exécution de: $(basename "$script_file")"
    echo

    # Proposer les options courantes
    echo "Options rapides:"
    echo "  1) Exécution normale"
    echo "  2) Aide (--help)"
    echo "  3) Mode simulation (--dry-run)"
    echo "  4) Mode détaillé (-v ou --verbose)"
    echo "  5) Commande personnalisée"
    echo

    read -p "Choisissez une option (1-5): " choice

    case $choice in
        1)
            print_message $BLUE "Exécution normale..."
            "$script_file"
            ;;
        2)
            print_message $BLUE "Affichage de l'aide..."
            "$script_file" --help
            ;;
        3)
            print_message $BLUE "Mode simulation..."
            "$script_file" --dry-run
            ;;
        4)
            print_message $BLUE "Mode détaillé..."
            "$script_file" -v
            ;;
        5)
            read -p "Entrez les arguments: " custom_args
            print_message $BLUE "Exécution avec: $custom_args"
            "$script_file" $custom_args
            ;;
        *)
            print_message $YELLOW "Option invalide, exécution normale"
            "$script_file"
            ;;
    esac
}

# Fonction d'édition de script
edit_script() {
    local script_name=$1
    local script_file="$SCRIPTS_DIR/${script_name}.sh"

    # Permettre avec ou sans extension
    if [ ! -f "$script_file" ]; then
        script_file="$SCRIPTS_DIR/${script_name}"
    fi

    if [ ! -f "$script_file" ]; then
        print_message $RED "❌ Script '$script_name' non trouvé"
        return 1
    fi

    print_message $BLUE "📝 Édition de: $(basename "$script_file")"

    # Détecter l'éditeur disponible
    if command -v nano >/dev/null; then
        nano "$script_file"
    elif command -v vim >/dev/null; then
        vim "$script_file"
    else
        print_message $RED "❌ Aucun éditeur trouvé (nano, vim)"
        return 1
    fi

    print_message $GREEN "✓ Édition terminée"
}

# Fonction de vérification d'intégrité
check_scripts_integrity() {
    print_message $BOLD "🔍 Vérification de l'intégrité des scripts"
    echo

    local total=0
    local executable=0
    local issues=0

    for script in "$SCRIPTS_DIR"/*.sh; do
        if [ -f "$script" ]; then
            total=$((total + 1))
            local basename=$(basename "$script")

            # Vérifier l'exécutabilité
            if [ -x "$script" ]; then
                executable=$((executable + 1))
                print_message $GREEN "✓ $basename"
            else
                print_message $YELLOW "⚠ $basename (non exécutable)"
                issues=$((issues + 1))
            fi

            # Vérifier la syntaxe bash
            if ! bash -n "$script" 2>/dev/null; then
                print_message $RED "✗ $basename (erreur de syntaxe)"
                issues=$((issues + 1))
            fi
        fi
    done

    echo
    print_message $BLUE "📊 Résumé:"
    print_message $CYAN "   Scripts totaux: $total"
    print_message $GREEN "   Exécutables: $executable"
    print_message $YELLOW "   Problèmes: $issues"

    if [ $issues -eq 0 ]; then
        print_message $GREEN "🎉 Tous les scripts sont en bon état!"
    else
        print_message $YELLOW "💡 Corrigez les permissions avec: chmod +x ~/scripts/*.sh"
    fi
}

# Fonction de statistiques
show_statistics() {
    print_message $BOLD "📈 Statistiques des scripts"
    echo

    if [ ! -d "$SCRIPTS_DIR" ]; then
        print_message $RED "❌ Répertoire non trouvé"
        return 1
    fi

    local total_scripts=0
    local total_lines=0
    local total_size=0
    local executable_count=0

    for script in "$SCRIPTS_DIR"/*.sh; do
        if [ -f "$script" ]; then
            total_scripts=$((total_scripts + 1))
            total_lines=$((total_lines + $(count_lines "$script")))

            local size=$(stat -c%s "$script")
            total_size=$((total_size + size))

            if [ -x "$script" ]; then
                executable_count=$((executable_count + 1))
            fi
        fi
    done

    print_message $CYAN "📊 Nombre de scripts: $total_scripts"
    print_message $CYAN "📏 Total lignes de code: $total_lines"
    print_message $CYAN "💾 Taille totale: $(( total_size / 1024 )) KB"
    print_message $CYAN "🔑 Scripts exécutables: $executable_count/$total_scripts"

    if [ $total_scripts -gt 0 ]; then
        local avg_lines=$((total_lines / total_scripts))
        print_message $CYAN "📊 Moyenne lignes/script: $avg_lines"
    fi

    echo
    print_message $BLUE "🏆 Script le plus volumineux:"
    find "$SCRIPTS_DIR" -name "*.sh" -exec wc -l {} \; | sort -nr | head -1 | while read lines file; do
        print_message $GREEN "   $(basename "$file"): $lines lignes"
    done
}

# Analyse des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--detailed)
            DETAILED=true
            shift
            ;;
        -r|--run)
            RUN_SCRIPT="$2"
            shift 2
            ;;
        -i|--info)
            show_script_info "$2"
            exit 0
            ;;
        -e|--edit)
            edit_script "$2"
            exit 0
            ;;
        --check)
            check_scripts_integrity
            exit 0
            ;;
        --stats)
            show_statistics
            exit 0
            ;;
        *)
            print_message $RED "Option inconnue: $1"
            show_help
            exit 1
            ;;
    esac
done

# Fonction principale
main() {
    # Header avec style
    print_message $PURPLE "╔══════════════════════════════════════════════════════════════╗"
    print_message $PURPLE "║                    🛠️  GESTIONNAIRE DE SCRIPTS               ║"
    print_message $PURPLE "╚══════════════════════════════════════════════════════════════╝"
    echo

    # Vérifier que le répertoire scripts existe
    if [ ! -d "$SCRIPTS_DIR" ]; then
        print_message $YELLOW "📁 Répertoire $SCRIPTS_DIR non trouvé"
        print_message $CYAN "💡 Création automatique..."
        mkdir -p "$SCRIPTS_DIR"
        print_message $GREEN "✓ Répertoire créé"
        echo
    fi

    # Exécution selon les options
    if [ -n "$RUN_SCRIPT" ]; then
        run_script_interactive "$RUN_SCRIPT"
    elif [ "$DETAILED" = true ]; then
        list_scripts_detailed
    else
        list_scripts_simple
    fi

    echo
    print_message $CYAN "💡 Utilisez --help pour voir toutes les options disponibles"
}

# Point d'entrée
main "$@"
