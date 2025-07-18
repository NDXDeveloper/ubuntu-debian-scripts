#!/bin/bash

# Script de mise à jour automatique pour Ubuntu / Debian
# Auteur: NDXDev NDXDev@gmail.com
# Version: 1.0
# Date: 2025-07-18

# Configuration du logging
LOG_FILE="/var/log/updates.log"
ENABLE_LOGGING=false
MAX_LOG_SIZE_MB=10  # Taille maximale du fichier de log en MB
MAX_LOG_LINES=1000  # Nombre maximum de lignes dans le log

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Fonction pour gérer la rotation des logs
rotate_log() {
    if [ ! -f "$LOG_FILE" ]; then
        return 0
    fi

    # Vérification de la taille du fichier (en MB)
    log_size=$(du -m "$LOG_FILE" 2>/dev/null | cut -f1)

    if [ "$log_size" -gt "$MAX_LOG_SIZE_MB" ]; then
        print_message $BLUE "Rotation du fichier de log (taille: ${log_size}MB > ${MAX_LOG_SIZE_MB}MB)"

        # Garder seulement les dernières lignes
        tail -n "$MAX_LOG_LINES" "$LOG_FILE" > "${LOG_FILE}.tmp" 2>/dev/null
        mv "${LOG_FILE}.tmp" "$LOG_FILE" 2>/dev/null

        echo "[$(date '+%Y-%m-%d %H:%M:%S')] === LOG ROTATED (taille excessive) ===" >> "$LOG_FILE"
        print_message $GREEN "Rotation effectuée: gardé les $MAX_LOG_LINES dernières lignes"
    fi
}

# Fonction pour nettoyer les logs
clean_logs() {
    if [ -f "$LOG_FILE" ]; then
        print_message $BLUE "Suppression du fichier de log: $LOG_FILE"
        sudo rm -f "$LOG_FILE"
        print_message $GREEN "Fichier de log supprimé"
    else
        print_message $YELLOW "Aucun fichier de log à supprimer"
    fi
}

# Fonction pour afficher les stats des logs
show_log_stats() {
    if [ -f "$LOG_FILE" ]; then
        log_size=$(du -h "$LOG_FILE" 2>/dev/null | cut -f1)
        log_lines=$(wc -l < "$LOG_FILE" 2>/dev/null)
        log_date=$(stat -c %y "$LOG_FILE" 2>/dev/null | cut -d' ' -f1)

        print_message $BLUE "=== STATISTIQUES DU FICHIER DE LOG ==="
        print_message $BLUE "Fichier: $LOG_FILE"
        print_message $BLUE "Taille: $log_size"
        print_message $BLUE "Lignes: $log_lines"
        print_message $BLUE "Dernière modification: $log_date"

        if [ "$log_lines" -gt 0 ]; then
            print_message $BLUE "Première entrée:"
            head -n 1 "$LOG_FILE" 2>/dev/null
            print_message $BLUE "Dernière entrée:"
            tail -n 1 "$LOG_FILE" 2>/dev/null
        fi
    else
        print_message $YELLOW "Aucun fichier de log trouvé"
    fi
}

# Fonction pour vérifier l'espace disque disponible
check_disk_space() {
    print_message $BLUE "Vérification de l'espace disque..."

    # Vérification de l'espace sur la partition racine
    available=$(df / | awk 'NR==2 {print $4}')
    available_mb=$((available / 1024))

    print_message $BLUE "Espace disponible: ${available_mb} MB"

    if [ $available -lt 1000000 ]; then  # < 1GB (1000000 KB)
        print_message $YELLOW "⚠️  Attention: Espace disque faible (< 1GB disponible)"
        print_message $YELLOW "Il est recommandé d'avoir au moins 1GB d'espace libre"

        # Demander confirmation si espace très faible
        if [ $available -lt 500000 ]; then  # < 500MB
            print_message $RED "⚠️  CRITIQUE: Moins de 500MB disponible!"
            read -p "Voulez-vous continuer malgré tout? (o/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[OoYy]$ ]]; then
                print_message $RED "Mise à jour annulée par l'utilisateur"
                exit 1
            fi
        fi
    else
        print_message $GREEN "Espace disque suffisant"
    fi
}

# Fonction pour initialiser le logging
init_logging() {
    if [ "$ENABLE_LOGGING" = true ]; then
        # Rotation du log si nécessaire avant d'écrire
        rotate_log

        # Créer le fichier de log s'il n'existe pas et vérifier les permissions
        if ! touch "$LOG_FILE" 2>/dev/null; then
            print_message $YELLOW "Impossible d'écrire dans $LOG_FILE, logging désactivé"
            ENABLE_LOGGING=false
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] === DÉBUT DU SCRIPT DE MISE À JOUR ===" >> "$LOG_FILE"
            print_message $GREEN "Logging activé: $LOG_FILE"
        fi
    fi
}

# Fonction pour vérifier si l'utilisateur est root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_message $RED "Ce script ne doit pas être exécuté en tant que root!"
        print_message $YELLOW "Utilisez sudo quand nécessaire."
        exit 1
    fi
}

# Fonction pour vérifier la connexion internet
check_internet() {
    print_message $BLUE "Vérification de la connexion internet..."
    if ! ping -c 1 google.com &> /dev/null; then
        print_message $RED "Erreur: Pas de connexion internet détectée!"
        exit 1
    fi
    print_message $GREEN "Connexion internet OK"
}

# Fonction pour créer un point de restauration (snapshot)
create_snapshot() {
    if command -v timeshift &> /dev/null; then
        print_message $BLUE "Création d'un snapshot avec Timeshift..."
        sudo timeshift --create --comments "Avant mise à jour $(date +"%Y-%m-%d %H:%M")" --scripted
        if [ $? -eq 0 ]; then
            print_message $GREEN "Snapshot créé avec succès"
        else
            print_message $YELLOW "Attention: Échec de la création du snapshot"
        fi
    else
        print_message $YELLOW "Timeshift n'est pas installé. Aucun snapshot créé."
    fi
}

# Fonction principale de mise à jour
update_system() {
    print_message $BLUE "=== DÉBUT DE LA MISE À JOUR DU SYSTÈME ==="

    # Mise à jour de la liste des paquets
    print_message $BLUE "Mise à jour de la liste des paquets..."
    sudo apt update
    if [ $? -ne 0 ]; then
        print_message $RED "Erreur lors de la mise à jour de la liste des paquets"
        exit 1
    fi

    # Affichage des paquets à mettre à jour
    upgradable=$(apt list --upgradable 2>/dev/null | wc -l)
    if [ $upgradable -gt 1 ]; then
        print_message $YELLOW "Nombre de paquets à mettre à jour: $((upgradable-1))"
        print_message $BLUE "Liste des paquets à mettre à jour:"
        apt list --upgradable 2>/dev/null | tail -n +2
        echo
    else
        print_message $GREEN "Aucun paquet à mettre à jour"
        return 0
    fi

    # Mise à jour des paquets (upgrade ou dist-upgrade selon l'option)
    if [ "$USE_DIST_UPGRADE" = true ]; then
        print_message $BLUE "Installation des mises à jour (dist-upgrade)..."
        print_message $YELLOW "Attention: dist-upgrade peut installer/supprimer des paquets"
        sudo apt dist-upgrade -y
    else
        print_message $BLUE "Installation des mises à jour (upgrade)..."
        sudo apt upgrade -y
    fi

    if [ $? -ne 0 ]; then
        print_message $RED "Erreur lors de la mise à jour des paquets"
        exit 1
    fi

    # Nettoyage des paquets obsolètes
    print_message $BLUE "Suppression des paquets obsolètes..."
    sudo apt autoremove -y

    # Nettoyage du cache
    print_message $BLUE "Nettoyage du cache des paquets..."
    sudo apt autoclean

    print_message $GREEN "=== MISE À JOUR TERMINÉE ==="
}

# Fonction pour mettre à jour les paquets Snap
update_snap() {
    if command -v snap &> /dev/null; then
        print_message $BLUE "Mise à jour des paquets Snap..."
        sudo snap refresh
        if [ $? -eq 0 ]; then
            print_message $GREEN "Paquets Snap mis à jour"
        else
            print_message $YELLOW "Erreur lors de la mise à jour des paquets Snap"
        fi
    else
        print_message $YELLOW "Snap n'est pas installé"
    fi
}

# Fonction pour mettre à jour les paquets Flatpak
update_flatpak() {
    if command -v flatpak &> /dev/null; then
        print_message $BLUE "Mise à jour des paquets Flatpak..."
        flatpak update -y
        if [ $? -eq 0 ]; then
            print_message $GREEN "Paquets Flatpak mis à jour"
        else
            print_message $YELLOW "Erreur lors de la mise à jour des paquets Flatpak"
        fi
    else
        print_message $YELLOW "Flatpak n'est pas installé"
    fi
}

# Fonction pour vérifier les redémarrages nécessaires
check_reboot() {
    if [ -f /var/run/reboot-required ]; then
        print_message $YELLOW "=== REDÉMARRAGE NÉCESSAIRE ==="
        print_message $YELLOW "Un redémarrage est requis pour finaliser les mises à jour."
        if [ -f /var/run/reboot-required.pkgs ]; then
            print_message $BLUE "Paquets concernés:"
            cat /var/run/reboot-required.pkgs
        fi
        echo
        read -p "Voulez-vous redémarrer maintenant? (o/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[OoYy]$ ]]; then
            print_message $BLUE "Redémarrage en cours..."
            sudo reboot
        else
            print_message $YELLOW "N'oubliez pas de redémarrer plus tard!"
        fi
    else
        print_message $GREEN "Aucun redémarrage nécessaire"
    fi
}

# Fonction pour afficher l'aide
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help        Afficher cette aide"
    echo "  -s, --snapshot    Créer un snapshot avant la mise à jour"
    echo "  -l, --log         Activer le logging dans $LOG_FILE"
    echo "  --log-stats       Afficher les statistiques du fichier de log"
    echo "  --clean-logs      Supprimer le fichier de log"
    echo "  --no-snap         Ne pas mettre à jour les paquets Snap"
    echo "  --no-flatpak      Ne pas mettre à jour les paquets Flatpak"
    echo "  --no-reboot       Ne pas proposer de redémarrage"
    echo "  --dist-upgrade    Utiliser dist-upgrade au lieu d'upgrade"
    echo "                    (peut installer/supprimer des paquets)"
    echo
    echo "Gestion des logs:"
    echo "  - Rotation automatique si > ${MAX_LOG_SIZE_MB}MB"
    echo "  - Conservation des ${MAX_LOG_LINES} dernières lignes lors de la rotation"
    echo "  - Utiliser --clean-logs pour supprimer manuellement"
    echo
    echo "Différence entre upgrade et dist-upgrade:"
    echo "  upgrade       : Met à jour les paquets sans installer/supprimer"
    echo "  dist-upgrade  : Met à jour avec gestion intelligente des dépendances"
    echo "                  (peut installer/supprimer des paquets si nécessaire)"
    echo
    echo "Exemples:"
    echo "  $0 -s             # Mise à jour avec création de snapshot"
    echo "  $0 --dist-upgrade # Utiliser dist-upgrade pour les mises à jour"
    echo "  $0 -sl            # Snapshot + logging activé"
    echo "  $0 --log-stats    # Voir les statistiques des logs"
    echo "  $0 --clean-logs   # Nettoyer les fichiers de log"
}

# Variables pour les options
CREATE_SNAPSHOT=false
UPDATE_SNAP=true
UPDATE_FLATPAK=true
CHECK_REBOOT_NEEDED=true
USE_DIST_UPGRADE=false

# Analyse des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -s|--snapshot)
            CREATE_SNAPSHOT=true
            shift
            ;;
        -l|--log)
            ENABLE_LOGGING=true
            shift
            ;;
        --log-stats)
            show_log_stats
            exit 0
            ;;
        --clean-logs)
            clean_logs
            exit 0
            ;;
        --no-snap)
            UPDATE_SNAP=false
            shift
            ;;
        --no-flatpak)
            UPDATE_FLATPAK=false
            shift
            ;;
        --no-reboot)
            CHECK_REBOOT_NEEDED=false
            shift
            ;;
        --dist-upgrade)
            USE_DIST_UPGRADE=true
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
    print_message $GREEN "=== SCRIPT DE MISE À JOUR KUBUNTU ==="
    print_message $BLUE "Démarrage: $(date)"

    # Affichage du mode de mise à jour
    if [ "$USE_DIST_UPGRADE" = true ]; then
        print_message $YELLOW "Mode: dist-upgrade (gestion avancée des dépendances)"
    else
        print_message $BLUE "Mode: upgrade (mise à jour standard)"
    fi
    echo

    # Vérifications préliminaires
    check_root
    check_internet

    # Initialiser le logging
    init_logging

    # Vérifier l'espace disque
    check_disk_space
    echo

    # Création du snapshot si demandé
    if [ "$CREATE_SNAPSHOT" = true ]; then
        create_snapshot
        echo
    fi

    # Mise à jour du système
    update_system
    echo

    # Mise à jour des paquets Snap
    if [ "$UPDATE_SNAP" = true ]; then
        update_snap
        echo
    fi

    # Mise à jour des paquets Flatpak
    if [ "$UPDATE_FLATPAK" = true ]; then
        update_flatpak
        echo
    fi

    # Vérification du redémarrage
    if [ "$CHECK_REBOOT_NEEDED" = true ]; then
        check_reboot
    fi

    print_message $GREEN "=== SCRIPT TERMINÉ ==="
    print_message $BLUE "Fin: $(date)"

    # Log de fin si activé
    if [ "$ENABLE_LOGGING" = true ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] === FIN DU SCRIPT ===" >> "$LOG_FILE"
    fi
}

# Exécution du script principal
main
