 
#!/bin/bash

# Script de nettoyage avancé du système Ubuntu/Debian
# Auteur: NDXDev NDXDev@gmail.com
# Version: 1.0
# Date: 2025-07-18

# Configuration
LOG_FILE="/var/log/system-deep-clean.log"
ENABLE_LOGGING=false
SAFE_MODE=true
DRY_RUN=false

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Variables pour les statistiques
TOTAL_FREED=0
FILES_REMOVED=0
PACKAGES_REMOVED=0

# Fonction pour afficher les messages avec couleurs et logging
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"

    # Logger dans le fichier si activé
    if [ "$ENABLE_LOGGING" = true ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${message}" >> "$LOG_FILE" 2>/dev/null
    fi
}

# Fonction pour convertir bytes en format lisible
bytes_to_human() {
    local bytes=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0

    while [ $bytes -gt 1024 ] && [ $unit -lt 4 ]; do
        bytes=$((bytes / 1024))
        unit=$((unit + 1))
    done

    echo "${bytes}${units[$unit]}"
}

# Fonction pour calculer la taille d'un dossier
get_directory_size() {
    local dir="$1"
    if [ -d "$dir" ]; then
        du -sb "$dir" 2>/dev/null | cut -f1
    else
        echo "0"
    fi
}

# Fonction pour calculer la taille de fichiers avec pattern
get_files_size() {
    local pattern="$1"
    find $pattern -type f -exec stat -c%s {} + 2>/dev/null | awk '{sum+=$1} END {print sum+0}'
}

# Fonction pour nettoyer avec confirmation
clean_with_confirmation() {
    local description="$1"
    local size="$2"
    local command="$3"

    if [ "$size" -eq 0 ]; then
        print_message $YELLOW "  ↳ Rien à nettoyer"
        return
    fi

    local human_size=$(bytes_to_human $size)

    if [ "$DRY_RUN" = true ]; then
        print_message $CYAN "  ↳ [DRY-RUN] Libèrerait: $human_size"
        return
    fi

    if [ "$SAFE_MODE" = true ]; then
        print_message $YELLOW "  ↳ Taille à libérer: $human_size"
        read -p "  ↳ Confirmer le nettoyage? (o/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[OoYy]$ ]]; then
            print_message $YELLOW "  ↳ Nettoyage ignoré"
            return
        fi
    fi

    print_message $BLUE "  ↳ Nettoyage en cours..."
    eval "$command"

    if [ $? -eq 0 ]; then
        print_message $GREEN "  ↳ Libéré: $human_size"
        TOTAL_FREED=$((TOTAL_FREED + size))
    else
        print_message $RED "  ↳ Erreur lors du nettoyage"
    fi
}

# Fonction pour nettoyer les paquets APT
clean_apt_packages() {
    print_message $MAGENTA "🗂️  NETTOYAGE DES PAQUETS APT"

    # Cache APT
    local apt_cache_size=$(get_directory_size "/var/cache/apt/archives")
    print_message $BLUE "📦 Cache APT:"
    clean_with_confirmation "Cache APT" "$apt_cache_size" "sudo apt autoclean && sudo apt clean"

    # Paquets orphelins
    print_message $BLUE "🔗 Paquets orphelins:"
    local orphans=$(deborphan 2>/dev/null | wc -l)
    if command -v deborphan &> /dev/null && [ "$orphans" -gt 0 ]; then
        if [ "$DRY_RUN" = false ]; then
            if [ "$SAFE_MODE" = false ] || { read -p "  ↳ Supprimer $orphans paquets orphelins? (o/N): " -n 1 -r; echo; [[ $REPLY =~ ^[OoYy]$ ]]; }; then
                sudo deborphan | xargs sudo apt-get -y remove --purge
                PACKAGES_REMOVED=$((PACKAGES_REMOVED + orphans))
                print_message $GREEN "  ↳ $orphans paquets orphelins supprimés"
            fi
        else
            print_message $CYAN "  ↳ [DRY-RUN] $orphans paquets orphelins à supprimer"
        fi
    else
        print_message $YELLOW "  ↳ deborphan non installé ou aucun paquet orphelin"
    fi

    # Paquets autoremove
    print_message $BLUE "🧹 Paquets auto-removable:"
    local autoremove_list=$(apt autoremove --dry-run 2>/dev/null | grep "^Remv" | wc -l)
    if [ "$autoremove_list" -gt 0 ]; then
        if [ "$DRY_RUN" = false ]; then
            if [ "$SAFE_MODE" = false ] || { read -p "  ↳ Supprimer $autoremove_list paquets auto-removable? (o/N): " -n 1 -r; echo; [[ $REPLY =~ ^[OoYy]$ ]]; }; then
                sudo apt autoremove -y
                PACKAGES_REMOVED=$((PACKAGES_REMOVED + autoremove_list))
                print_message $GREEN "  ↳ $autoremove_list paquets supprimés"
            fi
        else
            print_message $CYAN "  ↳ [DRY-RUN] $autoremove_list paquets à supprimer"
        fi
    else
        print_message $YELLOW "  ↳ Aucun paquet à supprimer"
    fi
}

# Fonction pour nettoyer les paquets Snap
clean_snap_packages() {
    if ! command -v snap &> /dev/null; then
        return
    fi

    print_message $MAGENTA "📱 NETTOYAGE DES PAQUETS SNAP"

    # Anciennes versions Snap
    print_message $BLUE "🔄 Anciennes versions Snap:"
    local old_snaps=$(snap list --all | awk '/disabled/{print $1, $3}' | wc -l)

    if [ "$old_snaps" -gt 0 ]; then
        if [ "$DRY_RUN" = false ]; then
            if [ "$SAFE_MODE" = false ] || { read -p "  ↳ Supprimer $old_snaps anciennes versions? (o/N): " -n 1 -r; echo; [[ $REPLY =~ ^[OoYy]$ ]]; }; then
                snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do
                    sudo snap remove "$snapname" --revision="$revision"
                done
                print_message $GREEN "  ↳ Anciennes versions supprimées"
            fi
        else
            print_message $CYAN "  ↳ [DRY-RUN] $old_snaps anciennes versions à supprimer"
        fi
    else
        print_message $YELLOW "  ↳ Aucune ancienne version trouvée"
    fi
}

# Fonction pour nettoyer les logs système
clean_system_logs() {
    print_message $MAGENTA "📋 NETTOYAGE DES LOGS SYSTÈME"

    # Logs journald anciens (plus de 7 jours)
    print_message $BLUE "📰 Logs journald:"
    local journal_size=$(journalctl --disk-usage 2>/dev/null | grep -oP 'archived and \K[0-9.]+[KMGT]?B' | head -1)
    if [ -n "$journal_size" ]; then
        if [ "$DRY_RUN" = false ]; then
            if [ "$SAFE_MODE" = false ] || { read -p "  ↳ Nettoyer les logs > 7 jours? (o/N): " -n 1 -r; echo; [[ $REPLY =~ ^[OoYy]$ ]]; }; then
                sudo journalctl --vacuum-time=7d
                print_message $GREEN "  ↳ Logs anciens supprimés"
            fi
        else
            print_message $CYAN "  ↳ [DRY-RUN] Logs journald: $journal_size"
        fi
    else
        print_message $YELLOW "  ↳ Impossible de déterminer la taille des logs"
    fi

    # Logs rotatés anciens
    print_message $BLUE "🔄 Logs rotatés:"
    local old_logs_size=$(get_files_size "/var/log/*.log.* /var/log/*/*.log.*")
    clean_with_confirmation "Logs rotatés anciens" "$old_logs_size" "sudo find /var/log -name '*.log.*' -type f -mtime +30 -delete"

    # Logs de crash
    print_message $BLUE "💥 Rapports de crash:"
    local crash_size=$(get_directory_size "/var/crash")
    clean_with_confirmation "Rapports de crash" "$crash_size" "sudo rm -rf /var/crash/*"
}

# Fonction pour nettoyer les caches utilisateur
clean_user_caches() {
    print_message $MAGENTA "👤 NETTOYAGE DES CACHES UTILISATEUR"

    # Cache navigateurs
    print_message $BLUE "🌐 Caches navigateurs:"

    # Firefox
    local firefox_cache="$HOME/.cache/mozilla/firefox"
    if [ -d "$firefox_cache" ]; then
        local firefox_size=$(get_directory_size "$firefox_cache")
        clean_with_confirmation "Cache Firefox" "$firefox_size" "rm -rf '$firefox_cache'/*"
    fi

    # Chrome/Chromium
    local chrome_cache="$HOME/.cache/google-chrome"
    if [ -d "$chrome_cache" ]; then
        local chrome_size=$(get_directory_size "$chrome_cache")
        clean_with_confirmation "Cache Chrome" "$chrome_size" "rm -rf '$chrome_cache'/*"
    fi

    local chromium_cache="$HOME/.cache/chromium"
    if [ -d "$chromium_cache" ]; then
        local chromium_size=$(get_directory_size "$chromium_cache")
        clean_with_confirmation "Cache Chromium" "$chromium_size" "rm -rf '$chromium_cache'/*"
    fi

    # Cache général utilisateur
    print_message $BLUE "📁 Cache utilisateur général:"
    local user_cache_size=$(get_directory_size "$HOME/.cache")
    if [ "$user_cache_size" -gt 0 ]; then
        if [ "$DRY_RUN" = false ]; then
            if [ "$SAFE_MODE" = false ] || { read -p "  ↳ Nettoyer le cache utilisateur ($(bytes_to_human $user_cache_size))? (o/N): " -n 1 -r; echo; [[ $REPLY =~ ^[OoYy]$ ]]; }; then
                # Ne pas supprimer tout le cache, juste les fichiers anciens
                find "$HOME/.cache" -type f -atime +7 -delete 2>/dev/null
                print_message $GREEN "  ↳ Cache utilisateur nettoyé (fichiers > 7 jours)"
            fi
        else
            print_message $CYAN "  ↳ [DRY-RUN] Cache utilisateur: $(bytes_to_human $user_cache_size)"
        fi
    fi
}

# Fonction pour nettoyer les fichiers temporaires
clean_temp_files() {
    print_message $MAGENTA "🗑️  NETTOYAGE DES FICHIERS TEMPORAIRES"

    # /tmp
    print_message $BLUE "📂 Dossier /tmp:"
    local tmp_size=$(get_directory_size "/tmp")
    clean_with_confirmation "Fichiers temporaires /tmp" "$tmp_size" "sudo find /tmp -type f -atime +1 -delete && sudo find /tmp -type d -empty -delete"

    # /var/tmp
    print_message $BLUE "📂 Dossier /var/tmp:"
    local var_tmp_size=$(get_directory_size "/var/tmp")
    clean_with_confirmation "Fichiers temporaires /var/tmp" "$var_tmp_size" "sudo find /var/tmp -type f -atime +7 -delete"

    # Thumbnails
    print_message $BLUE "🖼️  Miniatures:"
    local thumbnails_size=$(get_directory_size "$HOME/.thumbnails")
    clean_with_confirmation "Miniatures" "$thumbnails_size" "rm -rf '$HOME/.thumbnails'/* '$HOME/.cache/thumbnails'/*"

    # Trash
    print_message $BLUE "🗑️  Corbeille:"
    local trash_size=$(get_directory_size "$HOME/.local/share/Trash")
    clean_with_confirmation "Corbeille" "$trash_size" "rm -rf '$HOME/.local/share/Trash'/*"
}

# Fonction pour nettoyer les applications spécifiques
clean_applications() {
    print_message $MAGENTA "🎮 NETTOYAGE D'APPLICATIONS SPÉCIFIQUES"

    # Docker (si installé)
    if command -v docker &> /dev/null; then
        print_message $BLUE "🐳 Docker:"
        if [ "$DRY_RUN" = false ]; then
            if [ "$SAFE_MODE" = false ] || { read -p "  ↳ Nettoyer les images/containers Docker inutilisés? (o/N): " -n 1 -r; echo; [[ $REPLY =~ ^[OoYy]$ ]]; }; then
                docker system prune -f
                print_message $GREEN "  ↳ Docker nettoyé"
            fi
        else
            print_message $CYAN "  ↳ [DRY-RUN] Docker system prune disponible"
        fi
    fi

    # Flatpak
    if command -v flatpak &> /dev/null; then
        print_message $BLUE "📦 Flatpak:"
        if [ "$DRY_RUN" = false ]; then
            if [ "$SAFE_MODE" = false ] || { read -p "  ↳ Nettoyer les données Flatpak inutilisées? (o/N): " -n 1 -r; echo; [[ $REPLY =~ ^[OoYy]$ ]]; }; then
                flatpak uninstall --unused -y
                print_message $GREEN "  ↳ Flatpak nettoyé"
            fi
        else
            print_message $CYAN "  ↳ [DRY-RUN] Flatpak cleanup disponible"
        fi
    fi
}

# Fonction pour nettoyer les fichiers de configuration orphelins
clean_config_files() {
    print_message $MAGENTA "⚙️  NETTOYAGE CONFIGURATIONS ORPHELINES"

    # Configurations de paquets supprimés
    print_message $BLUE "📝 Configurations de paquets supprimés:"
    local config_packages=$(dpkg -l | grep '^rc' | wc -l)

    if [ "$config_packages" -gt 0 ]; then
        if [ "$DRY_RUN" = false ]; then
            if [ "$SAFE_MODE" = false ] || { read -p "  ↳ Purger $config_packages configurations orphelines? (o/N): " -n 1 -r; echo; [[ $REPLY =~ ^[OoYy]$ ]]; }; then
                dpkg -l | grep '^rc' | awk '{print $2}' | xargs sudo dpkg --purge
                print_message $GREEN "  ↳ $config_packages configurations purgées"
            fi
        else
            print_message $CYAN "  ↳ [DRY-RUN] $config_packages configurations à purger"
        fi
    else
        print_message $YELLOW "  ↳ Aucune configuration orpheline trouvée"
    fi
}

# Fonction pour afficher le résumé
show_summary() {
    print_message $CYAN "═══════════════════════════════════════════"
    print_message $CYAN "                RÉSUMÉ DU NETTOYAGE"
    print_message $CYAN "═══════════════════════════════════════════"

    if [ "$DRY_RUN" = true ]; then
        print_message $YELLOW "Mode simulation - Aucune modification effectuée"
    else
        print_message $GREEN "✅ Espace libéré total: $(bytes_to_human $TOTAL_FREED)"
        print_message $GREEN "📁 Fichiers supprimés: $FILES_REMOVED"
        print_message $GREEN "📦 Paquets supprimés: $PACKAGES_REMOVED"
    fi

    print_message $BLUE "🕒 Terminé: $(date)"
    print_message $CYAN "═══════════════════════════════════════════"
}

# Fonction pour afficher l'aide
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Script de nettoyage avancé du système Ubuntu/Debian"
    echo
    echo "Options:"
    echo "  -h, --help          Afficher cette aide"
    echo "  -l, --log           Activer le logging"
    echo "  -y, --yes           Mode automatique (pas de confirmation)"
    echo "  -n, --dry-run       Mode simulation (aucune modification)"
    echo "  --safe              Mode sécurisé avec confirmations (défaut)"
    echo "  --aggressive        Mode agressif sans confirmations"
    echo
    echo "Catégories de nettoyage:"
    echo "  --apt-only          Nettoyer uniquement les paquets APT"
    echo "  --logs-only         Nettoyer uniquement les logs"
    echo "  --cache-only        Nettoyer uniquement les caches"
    echo "  --temp-only         Nettoyer uniquement les fichiers temporaires"
    echo
    echo "Exemples:"
    echo "  $0                  # Nettoyage interactif complet"
    echo "  $0 -n               # Simulation sans modifications"
    echo "  $0 -y --aggressive  # Nettoyage automatique complet"
    echo "  $0 --cache-only     # Nettoyer seulement les caches"
}

# Variables pour les options
CATEGORIES_ONLY=""

# Analyse des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -l|--log)
            ENABLE_LOGGING=true
            shift
            ;;
        -y|--yes)
            SAFE_MODE=false
            shift
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --safe)
            SAFE_MODE=true
            shift
            ;;
        --aggressive)
            SAFE_MODE=false
            shift
            ;;
        --apt-only)
            CATEGORIES_ONLY="apt"
            shift
            ;;
        --logs-only)
            CATEGORIES_ONLY="logs"
            shift
            ;;
        --cache-only)
            CATEGORIES_ONLY="cache"
            shift
            ;;
        --temp-only)
            CATEGORIES_ONLY="temp"
            shift
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
    print_message $CYAN "═══════════════════════════════════════════"
    print_message $CYAN "        NETTOYAGE AVANCÉ DU SYSTÈME"
    print_message $CYAN "═══════════════════════════════════════════"
    print_message $BLUE "🕒 Début: $(date)"

    if [ "$DRY_RUN" = true ]; then
        print_message $YELLOW "⚠️  MODE SIMULATION - Aucune modification ne sera effectuée"
    fi

    if [ "$SAFE_MODE" = true ]; then
        print_message $GREEN "🛡️  Mode sécurisé activé - Confirmations requises"
    else
        print_message $YELLOW "⚡ Mode automatique - Nettoyage sans confirmation"
    fi

    echo

    # Logging
    if [ "$ENABLE_LOGGING" = true ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] === DÉBUT DU NETTOYAGE SYSTÈME ===" >> "$LOG_FILE"
        print_message $GREEN "📝 Logging activé: $LOG_FILE"
        echo
    fi

    # Exécution selon les catégories
    case $CATEGORIES_ONLY in
        "apt")
            clean_apt_packages
            ;;
        "logs")
            clean_system_logs
            ;;
        "cache")
            clean_user_caches
            ;;
        "temp")
            clean_temp_files
            ;;
        *)
            # Nettoyage complet
            clean_apt_packages
            echo
            clean_snap_packages
            echo
            clean_system_logs
            echo
            clean_user_caches
            echo
            clean_temp_files
            echo
            clean_applications
            echo
            clean_config_files
            ;;
    esac

    echo
    show_summary

    # Log de fin
    if [ "$ENABLE_LOGGING" = true ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] === FIN DU NETTOYAGE ($(bytes_to_human $TOTAL_FREED) libérés) ===" >> "$LOG_FILE"
    fi
}

# Vérification des permissions
if [[ $EUID -eq 0 ]]; then
    print_message $RED "Ce script ne doit pas être exécuté en tant que root!"
    print_message $YELLOW "Il utilisera sudo quand nécessaire."
    exit 1
fi

# Exécution du script principal
main
