 
#!/bin/bash

# Script de sauvegarde automatisée pour Ubuntu/Debian
# Auteur: NDXDev NDXDev@gmail.com
# Version: 1.0
# Date: 2025-07-18

# Configuration par défaut
SOURCE_DIR="$HOME"
BACKUP_BASE_DIR="/backup"
BACKUP_NAME="backup_$(hostname)_$(date +%Y%m%d_%H%M%S)"
RETENTION_DAYS=30
COMPRESSION_LEVEL=6
ENCRYPTION_ENABLED=false
ENCRYPTION_PASSWORD=""
CLOUD_ENABLED=false
CLOUD_TYPE=""
CLOUD_DESTINATION=""
LOG_FILE="$HOME/.local/share/backup-manager.log"  # ← CORRIGÉ : répertoire utilisateur
VERBOSE_MODE=false
DRY_RUN=false
INCREMENTAL=false
EXCLUDE_FILE=""

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Variables globales
START_TIME=$(date +%s)
TOTAL_SIZE=0
BACKUP_FILE=""
TEMP_DIR=""

# Fonction pour initialiser le logging
init_logging() {
    # Créer le répertoire de logs s'il n'existe pas
    local log_dir=$(dirname "$LOG_FILE")
    mkdir -p "$log_dir" 2>/dev/null

    # Tester l'écriture dans le fichier de log
    if ! echo "[$(date '+%Y-%m-%d %H:%M:%S')] Test logging" >> "$LOG_FILE" 2>/dev/null; then
        # Fallback vers un fichier temporaire
        LOG_FILE="/tmp/backup-manager-$USER.log"
        print_message "WARNING" "Impossible d'écrire dans le log principal, utilisation de: $LOG_FILE"
    fi
}

# Fonction pour afficher les messages avec couleurs et logging
print_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        "INFO")
            echo -e "${BLUE}ℹ️  ${message}${NC}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}✅ ${message}${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  ${message}${NC}"
            ;;
        "ERROR")
            echo -e "${RED}❌ ${message}${NC}"
            ;;
        "PROGRESS")
            echo -e "${CYAN}🔄 ${message}${NC}"
            ;;
        *)
            echo -e "${message}"
            ;;
    esac

    # Logger dans le fichier seulement si possible
    if [ -n "$LOG_FILE" ]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null
    fi
}

# Fonction pour nettoyer en cas d'interruption
cleanup() {
    print_message "WARNING" "Interruption détectée, nettoyage en cours..."

    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        print_message "INFO" "Répertoire temporaire supprimé"
    fi

    if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ] && [ ! -s "$BACKUP_FILE" ]; then
        rm -f "$BACKUP_FILE"
        print_message "INFO" "Fichier de sauvegarde incomplet supprimé"
    fi

    print_message "ERROR" "Sauvegarde interrompue"
    exit 1
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

# Fonction pour vérifier les prérequis
check_prerequisites() {
    print_message "INFO" "Vérification des prérequis..."

    # Créer le répertoire de sauvegarde pour vérifier l'espace
    if [ ! -d "$BACKUP_BASE_DIR" ]; then
        mkdir -p "$BACKUP_BASE_DIR" 2>/dev/null
        if [ $? -ne 0 ]; then
            print_message "ERROR" "Impossible de créer le répertoire de sauvegarde: $BACKUP_BASE_DIR"
            print_message "INFO" "Essayez avec sudo ou changez le répertoire de destination"
            exit 1
        fi
    fi

    # Vérifier l'espace disque - CORRIGÉ
    local available_space=$(df "$BACKUP_BASE_DIR" 2>/dev/null | tail -1 | awk '{print $4}' || echo "0")
    local source_size=$(du -sk "$SOURCE_DIR" 2>/dev/null | cut -f1 || echo "0")

    # Estimation plus réaliste : avec compression, on a besoin de 1.2x la taille source
    local estimated_backup_size=$((source_size + source_size / 5))  # +20% pour être sûr

    print_message "INFO" "Espace disponible: $(bytes_to_human $((available_space * 1024)))"
    print_message "INFO" "Taille source: $(bytes_to_human $((source_size * 1024)))"
    print_message "INFO" "Taille estimée backup: $(bytes_to_human $((estimated_backup_size * 1024)))"

    if [ "$available_space" -lt "$estimated_backup_size" ]; then
        print_message "WARNING" "Espace disque potentiellement insuffisant"
        print_message "INFO" "Recommandation: libérez de l'espace ou changez de destination"

        if [ "$DRY_RUN" = false ]; then
            read -p "Continuer malgré tout? (o/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[OoYy]$ ]]; then
                print_message "ERROR" "Sauvegarde annulée par l'utilisateur"
                exit 1
            fi
        fi
    else
        print_message "SUCCESS" "Espace disque suffisant"
    fi

    # Vérifier les outils requis
    local missing_tools=()

    [ "$COMPRESSION_LEVEL" -gt 0 ] && ! command -v tar &> /dev/null && missing_tools+=("tar")
    [ "$ENCRYPTION_ENABLED" = true ] && ! command -v gpg &> /dev/null && missing_tools+=("gpg")
    [ "$CLOUD_ENABLED" = true ] && [ "$CLOUD_TYPE" = "rsync" ] && ! command -v rsync &> /dev/null && missing_tools+=("rsync")
    [ "$CLOUD_ENABLED" = true ] && [ "$CLOUD_TYPE" = "rclone" ] && ! command -v rclone &> /dev/null && missing_tools+=("rclone")

    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_message "ERROR" "Outils manquants: ${missing_tools[*]}"
        print_message "INFO" "Installation recommandée: sudo apt install ${missing_tools[*]}"
        exit 1
    fi

    print_message "SUCCESS" "Prérequis vérifiés"
}

# Fonction pour créer le fichier d'exclusion par défaut
create_default_excludes() {
    TEMP_DIR=$(mktemp -d)
    EXCLUDE_FILE="$TEMP_DIR/backup_exclude.txt"

    cat > "$EXCLUDE_FILE" << 'EOF'
# Fichiers et dossiers à exclure de la sauvegarde
**/.cache/*
**/.thumbnails/*
**/.local/share/Trash/*
**/.mozilla/firefox/*/Cache/*
**/.config/google-chrome/*/Cache/*
**/.config/chromium/*/Cache/*
**/Downloads/temp/*
**/*.tmp
**/*.temp
**/.gvfs
**/lost+found
**/proc/*
**/sys/*
**/dev/*
**/mnt/*
**/media/*
**/.Trash-*
**/node_modules/*
**/__pycache__/*
**/.pytest_cache/*
**/.vscode/extensions/*
**/snap/*/common/.cache/*
EOF

    # Ajouter les exclusions personnalisées si spécifiées
    if [ -n "$EXCLUDE_FILE_CUSTOM" ] && [ -f "$EXCLUDE_FILE_CUSTOM" ]; then
        echo "# Exclusions personnalisées" >> "$EXCLUDE_FILE"
        cat "$EXCLUDE_FILE_CUSTOM" >> "$EXCLUDE_FILE"
    fi

    print_message "INFO" "Fichier d'exclusion créé: $EXCLUDE_FILE"
}

# Fonction pour effectuer la sauvegarde
perform_backup() {
    print_message "PROGRESS" "Début de la sauvegarde..."
    print_message "INFO" "Source: $SOURCE_DIR"
    print_message "INFO" "Destination: $BACKUP_BASE_DIR"

    # Créer le répertoire de sauvegarde
    mkdir -p "$BACKUP_BASE_DIR"

    # Déterminer le nom du fichier de sauvegarde
    if [ "$COMPRESSION_LEVEL" -gt 0 ]; then
        BACKUP_FILE="$BACKUP_BASE_DIR/${BACKUP_NAME}.tar.gz"
    else
        BACKUP_FILE="$BACKUP_BASE_DIR/${BACKUP_NAME}.tar"
    fi

    if [ "$ENCRYPTION_ENABLED" = true ]; then
        BACKUP_FILE="${BACKUP_FILE}.gpg"
    fi

    print_message "INFO" "Fichier de sauvegarde: $(basename "$BACKUP_FILE")"

    if [ "$DRY_RUN" = true ]; then
        print_message "INFO" "Mode simulation - aucun fichier ne sera créé"
        return 0
    fi

    # Créer les exclusions par défaut
    create_default_excludes

    # Construire la commande tar
    local tar_cmd="tar"
    local tar_options="-cf"

    if [ "$COMPRESSION_LEVEL" -gt 0 ]; then
        tar_options="-czf"
        export GZIP="-$COMPRESSION_LEVEL"
    fi

    if [ "$VERBOSE_MODE" = true ]; then
        tar_options="${tar_options}v"
    fi

    # Ajouter les exclusions
    local exclude_options=""
    if [ -f "$EXCLUDE_FILE" ]; then
        exclude_options="--exclude-from=$EXCLUDE_FILE"
    fi

    # Effectuer la sauvegarde
    local backup_start=$(date +%s)

    if [ "$ENCRYPTION_ENABLED" = true ]; then
        print_message "PROGRESS" "Sauvegarde avec compression et chiffrement..."

        if [ -n "$ENCRYPTION_PASSWORD" ]; then
            echo "$ENCRYPTION_PASSWORD" | $tar_cmd $tar_options - $exclude_options -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")" | \
            gpg --batch --yes --passphrase-fd 0 --symmetric --cipher-algo AES256 --output "$BACKUP_FILE"
        else
            $tar_cmd $tar_options - $exclude_options -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")" | \
            gpg --symmetric --cipher-algo AES256 --output "$BACKUP_FILE"
        fi
    else
        print_message "PROGRESS" "Sauvegarde avec compression..."
        $tar_cmd $tar_options "$BACKUP_FILE" $exclude_options -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"
    fi

    local backup_status=$?
    local backup_end=$(date +%s)
    local backup_duration=$((backup_end - backup_start))

    if [ $backup_status -eq 0 ]; then
        if [ -f "$BACKUP_FILE" ]; then
            TOTAL_SIZE=$(stat -c%s "$BACKUP_FILE" 2>/dev/null || echo "0")
            print_message "SUCCESS" "Sauvegarde créée avec succès"
            print_message "INFO" "Taille: $(bytes_to_human $TOTAL_SIZE)"
            print_message "INFO" "Durée: ${backup_duration}s"
        else
            print_message "ERROR" "Fichier de sauvegarde non trouvé"
            return 1
        fi
    else
        print_message "ERROR" "Échec de la sauvegarde (code: $backup_status)"
        return 1
    fi
}

# Fonction pour la rotation des sauvegardes
rotate_backups() {
    if [ "$DRY_RUN" = true ]; then
        print_message "INFO" "Mode simulation - pas de rotation"
        return 0
    fi

    print_message "PROGRESS" "Rotation des sauvegardes anciennes..."

    local deleted_count=0
    local deleted_size=0

    find "$BACKUP_BASE_DIR" -name "backup_$(hostname)_*" -type f -mtime +$RETENTION_DAYS | while read old_backup; do
        if [ -f "$old_backup" ]; then
            local file_size=$(stat -c%s "$old_backup" 2>/dev/null || echo "0")
            rm -f "$old_backup"

            if [ $? -eq 0 ]; then
                deleted_count=$((deleted_count + 1))
                deleted_size=$((deleted_size + file_size))
                print_message "INFO" "Supprimé: $(basename "$old_backup")"
            fi
        fi
    done

    if [ $deleted_count -gt 0 ]; then
        print_message "SUCCESS" "$deleted_count anciennes sauvegardes supprimées ($(bytes_to_human $deleted_size) libérés)"
    else
        print_message "INFO" "Aucune ancienne sauvegarde à supprimer"
    fi
}

# Fonction pour la synchronisation cloud
sync_to_cloud() {
    if [ "$CLOUD_ENABLED" = false ] || [ "$DRY_RUN" = true ]; then
        return 0
    fi

    print_message "PROGRESS" "Synchronisation vers le cloud ($CLOUD_TYPE)..."

    case $CLOUD_TYPE in
        "rsync")
            rsync -avz --progress "$BACKUP_FILE" "$CLOUD_DESTINATION"
            ;;
        "rclone")
            rclone copy "$BACKUP_FILE" "$CLOUD_DESTINATION" --progress
            ;;
        *)
            print_message "ERROR" "Type de cloud non supporté: $CLOUD_TYPE"
            return 1
            ;;
    esac

    if [ $? -eq 0 ]; then
        print_message "SUCCESS" "Synchronisation cloud réussie"
    else
        print_message "ERROR" "Échec de la synchronisation cloud"
        return 1
    fi
}

# Fonction pour vérifier l'intégrité
verify_backup() {
    if [ "$DRY_RUN" = true ] || [ ! -f "$BACKUP_FILE" ]; then
        return 0
    fi

    print_message "PROGRESS" "Vérification de l'intégrité..."

    if [ "$ENCRYPTION_ENABLED" = true ]; then
        print_message "INFO" "Vérification de l'archive chiffrée..."
        if [ -n "$ENCRYPTION_PASSWORD" ]; then
            echo "$ENCRYPTION_PASSWORD" | gpg --batch --yes --passphrase-fd 0 --decrypt "$BACKUP_FILE" | tar -tzf - > /dev/null
        else
            gpg --decrypt "$BACKUP_FILE" | tar -tzf - > /dev/null
        fi
    else
        print_message "INFO" "Vérification de l'archive..."
        tar -tzf "$BACKUP_FILE" > /dev/null
    fi

    if [ $? -eq 0 ]; then
        print_message "SUCCESS" "Archive vérifiée et intègre"
    else
        print_message "ERROR" "Archive corrompue ou mot de passe incorrect"
        return 1
    fi
}

# Fonction pour lister les sauvegardes existantes
list_backups() {
    print_message "INFO" "Sauvegardes existantes:"

    if [ ! -d "$BACKUP_BASE_DIR" ]; then
        print_message "WARNING" "Répertoire de sauvegarde non trouvé: $BACKUP_BASE_DIR"
        return
    fi

    local backup_files=$(find "$BACKUP_BASE_DIR" -name "backup_$(hostname)_*" -type f 2>/dev/null | sort)

    if [ -z "$backup_files" ]; then
        print_message "INFO" "Aucune sauvegarde trouvée"
        return
    fi

    echo
    printf "%-25s %-10s %-15s %s\n" "NOM" "TAILLE" "DATE" "ÂGE"
    echo "--------------------------------------------------------------------------------"

    echo "$backup_files" | while read backup_file; do
        local name=$(basename "$backup_file")
        local size=$(stat -c%s "$backup_file" 2>/dev/null || echo "0")
        local date=$(stat -c%y "$backup_file" 2>/dev/null | cut -d' ' -f1 || echo "N/A")
        local age=$(find "$backup_file" -mtime +0 -printf "%M jours\n" 2>/dev/null | head -1 || echo "N/A")

        printf "%-25s %-10s %-15s %s\n" "${name:0:24}" "$(bytes_to_human $size)" "$date" "$age"
    done
    echo
}

# Fonction pour restaurer une sauvegarde
restore_backup() {
    local backup_to_restore="$1"
    local restore_destination="$2"

    if [ -z "$backup_to_restore" ]; then
        print_message "ERROR" "Fichier de sauvegarde non spécifié"
        return 1
    fi

    if [ ! -f "$backup_to_restore" ]; then
        print_message "ERROR" "Fichier de sauvegarde non trouvé: $backup_to_restore"
        return 1
    fi

    if [ -z "$restore_destination" ]; then
        restore_destination="$(pwd)/restore_$(date +%Y%m%d_%H%M%S)"
    fi

    print_message "INFO" "Restauration depuis: $backup_to_restore"
    print_message "INFO" "Destination: $restore_destination"

    mkdir -p "$restore_destination"

    if [ "$ENCRYPTION_ENABLED" = true ] || [[ "$backup_to_restore" =~ \.gpg$ ]]; then
        print_message "PROGRESS" "Restauration de l'archive chiffrée..."
        if [ -n "$ENCRYPTION_PASSWORD" ]; then
            echo "$ENCRYPTION_PASSWORD" | gpg --batch --yes --passphrase-fd 0 --decrypt "$backup_to_restore" | \
            tar -xzf - -C "$restore_destination"
        else
            gpg --decrypt "$backup_to_restore" | tar -xzf - -C "$restore_destination"
        fi
    else
        print_message "PROGRESS" "Restauration de l'archive..."
        tar -xzf "$backup_to_restore" -C "$restore_destination"
    fi

    if [ $? -eq 0 ]; then
        print_message "SUCCESS" "Restauration réussie dans: $restore_destination"
    else
        print_message "ERROR" "Échec de la restauration"
        return 1
    fi
}

# Fonction pour générer le rapport final
generate_report() {
    local end_time=$(date +%s)
    local total_duration=$((end_time - START_TIME))

    print_message "" ""
    print_message "" "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    print_message "" "${BOLD}${CYAN}                               RAPPORT DE SAUVEGARDE${NC}"
    print_message "" "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    print_message "INFO" "Heure de début: $(date -d "@$START_TIME" '+%Y-%m-%d %H:%M:%S')"
    print_message "INFO" "Heure de fin: $(date '+%Y-%m-%d %H:%M:%S')"
    print_message "INFO" "Durée totale: ${total_duration}s"

    if [ -f "$BACKUP_FILE" ]; then
        print_message "SUCCESS" "Fichier créé: $(basename "$BACKUP_FILE")"
        print_message "SUCCESS" "Taille finale: $(bytes_to_human $TOTAL_SIZE)"

        if [ "$ENCRYPTION_ENABLED" = true ]; then
            print_message "INFO" "Archive chiffrée avec AES256"
        fi

        if [ "$CLOUD_ENABLED" = true ]; then
            print_message "INFO" "Synchronisée vers: $CLOUD_TYPE"
        fi
    fi

    print_message "INFO" "Logs disponibles: $LOG_FILE"
    print_message "" "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
}

# Fonction d'aide
show_help() {
    echo "Usage: $0 [OPTIONS] [ACTION]"
    echo
    echo "Gestionnaire de sauvegarde automatisée pour Ubuntu/Debian"
    echo
    echo "Actions:"
    echo "  backup                  Effectuer une sauvegarde (défaut)"
    echo "  list                    Lister les sauvegardes existantes"
    echo "  restore FILE [DEST]     Restaurer une sauvegarde"
    echo
    echo "Options de base:"
    echo "  -h, --help              Afficher cette aide"
    echo "  -s, --source DIR        Répertoire source (défaut: $HOME)"
    echo "  -d, --destination DIR   Répertoire de destination (défaut: /backup)"
    echo "  -n, --name NAME         Nom de la sauvegarde (défaut: auto-généré)"
    echo "  -v, --verbose           Mode verbeux"
    echo "  --dry-run               Mode simulation"
    echo
    echo "Options de compression:"
    echo "  -c, --compression LEVEL Niveau de compression 0-9 (défaut: 6)"
    echo "  --no-compression        Désactiver la compression"
    echo
    echo "Options de chiffrement:"
    echo "  -e, --encrypt           Activer le chiffrement"
    echo "  -p, --password PASS     Mot de passe de chiffrement"
    echo
    echo "Options de rotation:"
    echo "  -r, --retention DAYS    Rétention en jours (défaut: 30)"
    echo "  --no-rotation           Désactiver la rotation"
    echo
    echo "Options cloud:"
    echo "  --cloud-rsync DEST      Synchroniser avec rsync"
    echo "  --cloud-rclone DEST     Synchroniser avec rclone"
    echo
    echo "Options avancées:"
    echo "  --exclude-file FILE     Fichier d'exclusions personnalisé"
    echo "  --incremental           Sauvegarde incrémentale (TODO)"
    echo "  --verify                Vérifier l'intégrité après sauvegarde"
    echo
    echo "Exemples:"
    echo "  $0                                    # Sauvegarde standard"
    echo "  $0 -e -p 'monmotdepasse'             # Avec chiffrement"
    echo "  $0 --cloud-rsync user@server:/backup # Avec synchronisation"
    echo "  $0 list                               # Lister les sauvegardes"
    echo "  $0 restore backup.tar.gz /tmp/restore # Restaurer"
}

# Variables pour les options
ACTION="backup"
VERIFY_AFTER_BACKUP=false
NO_ROTATION=false
EXCLUDE_FILE_CUSTOM=""

# Analyse des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -s|--source)
            SOURCE_DIR="$2"
            shift 2
            ;;
        -d|--destination)
            BACKUP_BASE_DIR="$2"
            shift 2
            ;;
        -n|--name)
            BACKUP_NAME="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE_MODE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -c|--compression)
            COMPRESSION_LEVEL="$2"
            shift 2
            ;;
        --no-compression)
            COMPRESSION_LEVEL=0
            shift
            ;;
        -e|--encrypt)
            ENCRYPTION_ENABLED=true
            shift
            ;;
        -p|--password)
            ENCRYPTION_PASSWORD="$2"
            ENCRYPTION_ENABLED=true
            shift 2
            ;;
        -r|--retention)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        --no-rotation)
            NO_ROTATION=true
            shift
            ;;
        --cloud-rsync)
            CLOUD_ENABLED=true
            CLOUD_TYPE="rsync"
            CLOUD_DESTINATION="$2"
            shift 2
            ;;
        --cloud-rclone)
            CLOUD_ENABLED=true
            CLOUD_TYPE="rclone"
            CLOUD_DESTINATION="$2"
            shift 2
            ;;
        --exclude-file)
            EXCLUDE_FILE_CUSTOM="$2"
            shift 2
            ;;
        --incremental)
            INCREMENTAL=true
            print_message "WARNING" "Sauvegarde incrémentale non encore implémentée"
            shift
            ;;
        --verify)
            VERIFY_AFTER_BACKUP=true
            shift
            ;;
        backup|list|restore)
            ACTION="$1"
            shift
            ;;
        *)
            if [ "$ACTION" = "restore" ] && [ -z "$RESTORE_FILE" ]; then
                RESTORE_FILE="$1"
            elif [ "$ACTION" = "restore" ] && [ -z "$RESTORE_DEST" ]; then
                RESTORE_DEST="$1"
            else
                echo "Option inconnue: $1"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Fonction principale
main() {
    # Initialiser le logging AVANT tout
    init_logging

    # Configuration du signal de sortie
    trap cleanup SIGINT SIGTERM

    # En-tête
    print_message "" "${BOLD}${MAGENTA}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    print_message "" "${BOLD}${MAGENTA}║                              GESTIONNAIRE DE SAUVEGARDE                      ║${NC}"
    print_message "" "${BOLD}${MAGENTA}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    print_message "" ""

    # Logging de début
    if [ -n "$LOG_FILE" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] === DÉBUT SAUVEGARDE ===" >> "$LOG_FILE" 2>/dev/null
        print_message "INFO" "Logs enregistrés dans: $LOG_FILE"
    fi

    case $ACTION in
        "backup")
            check_prerequisites
            perform_backup

            if [ $? -eq 0 ]; then
                [ "$NO_ROTATION" = false ] && rotate_backups
                [ "$VERIFY_AFTER_BACKUP" = true ] && verify_backup
                sync_to_cloud
                generate_report
            fi
            ;;
        "list")
            list_backups
            ;;
        "restore")
            if [ -z "$RESTORE_FILE" ]; then
                print_message "ERROR" "Fichier de sauvegarde à restaurer non spécifié"
                show_help
                exit 1
            fi
            restore_backup "$RESTORE_FILE" "$RESTORE_DEST"
            ;;
        *)
            print_message "ERROR" "Action inconnue: $ACTION"
            show_help
            exit 1
            ;;
    esac

    # Nettoyage
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Vérifications préliminaires
if [[ $EUID -eq 0 ]]; then
    print_message "WARNING" "Script exécuté en tant que root. Vérifiez les permissions."
fi

# Exécution du script principal
main
