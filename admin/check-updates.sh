#!/bin/bash

# Script de vérification des mises à jour pour Kubuntu
# Auteur: NDXDev NDXDev@gmail.com
# Date: $(date +"%Y-%m-%d")

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Fonction pour afficher les messages avec couleurs
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Fonction pour afficher un titre de section
print_section() {
    local title=$1
    echo
    print_message $BOLD "╔════════════════════════════════════════════════════════════════════════════════╗"
    printf "${BOLD}║ %-78s ║${NC}\n" "$title"
    print_message $BOLD "╚════════════════════════════════════════════════════════════════════════════════╝"
}

# Fonction pour vérifier la connexion internet
check_internet() {
    print_message $BLUE "Vérification de la connexion internet..."
    if ! ping -c 1 google.com &> /dev/null; then
        print_message $RED "Erreur: Pas de connexion internet détectée!"
        exit 1
    fi
    print_message $GREEN "✓ Connexion internet OK"
}

# Fonction pour mettre à jour la liste des paquets
update_package_list() {
    print_message $BLUE "Mise à jour de la liste des paquets..."
    sudo apt update &> /dev/null
    if [ $? -eq 0 ]; then
        print_message $GREEN "✓ Liste des paquets mise à jour"
    else
        print_message $RED "✗ Erreur lors de la mise à jour de la liste des paquets"
        exit 1
    fi
}

# Fonction pour vérifier les mises à jour APT
check_apt_updates() {
    print_section "📦 MISES À JOUR APT DISPONIBLES"

    # Obtenir la liste des paquets à mettre à jour
    upgradable=$(apt list --upgradable 2>/dev/null | tail -n +2)
    count=$(echo "$upgradable" | wc -l)

    if [ -z "$upgradable" ] || [ "$count" -eq 0 ]; then
        print_message $GREEN "✓ Aucune mise à jour APT disponible"
        return 0
    fi

    print_message $YELLOW "📊 Nombre de paquets à mettre à jour: $count"
    echo

    # Afficher les détails des paquets
    print_message $CYAN "Détails des mises à jour:"
    echo "$upgradable" | while IFS= read -r line; do
        if [ -n "$line" ]; then
            package=$(echo "$line" | cut -d'/' -f1)
            version_info=$(echo "$line" | cut -d' ' -f2-)

            # Obtenir la version actuelle
            current_version=$(dpkg -l | grep "^ii  $package " | awk '{print $3}' 2>/dev/null)

            # Obtenir la description du paquet
            description=$(apt-cache show "$package" 2>/dev/null | grep "^Description:" | head -1 | cut -d':' -f2- | sed 's/^ *//')

            printf "  ${BLUE}%-30s${NC} %s\n" "$package" "$version_info"
            if [ -n "$current_version" ]; then
                printf "    ${YELLOW}Version actuelle:${NC} %s\n" "$current_version"
            fi
            if [ -n "$description" ]; then
                printf "    ${CYAN}Description:${NC} %s\n" "$description"
            fi
            echo
        fi
    done

    # Calculer la taille totale des téléchargements
    size_info=$(apt list --upgradable -qq 2>/dev/null | xargs apt-cache show 2>/dev/null | grep "^Size:" | awk '{sum+=$2} END {print sum}')
    if [ -n "$size_info" ] && [ "$size_info" -gt 0 ]; then
        size_mb=$((size_info / 1024 / 1024))
        print_message $MAGENTA "💾 Taille estimée des téléchargements: ${size_mb} MB"
    fi
}

# Fonction pour vérifier les mises à jour de sécurité
check_security_updates() {
    print_section "🔒 MISES À JOUR DE SÉCURITÉ"

    security_updates=$(apt list --upgradable 2>/dev/null | grep -i security | tail -n +2)

    if [ -z "$security_updates" ]; then
        print_message $GREEN "✓ Aucune mise à jour de sécurité en attente"
        return 0
    fi

    count=$(echo "$security_updates" | wc -l)
    print_message $RED "⚠️  $count mise(s) à jour de sécurité disponible(s)"
    echo

    echo "$security_updates" | while IFS= read -r line; do
        if [ -n "$line" ]; then
            package=$(echo "$line" | cut -d'/' -f1)
            version_info=$(echo "$line" | cut -d' ' -f2-)
            printf "  ${RED}%-30s${NC} %s\n" "$package" "$version_info"
        fi
    done
}

# Fonction pour vérifier les mises à jour Snap
check_snap_updates() {
    print_section "📱 MISES À JOUR SNAP DISPONIBLES"

    if ! command -v snap &> /dev/null; then
        print_message $YELLOW "⚠️  Snap n'est pas installé"
        return 0
    fi

    # Obtenir la liste des snaps à mettre à jour
    snap_list=$(snap refresh --list 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$snap_list" ]; then
        print_message $GREEN "✓ Aucune mise à jour Snap disponible"
        return 0
    fi

    count=$(echo "$snap_list" | wc -l)
    print_message $YELLOW "📊 Nombre de snaps à mettre à jour: $count"
    echo

    print_message $CYAN "Liste des snaps à mettre à jour:"
    echo "$snap_list" | while IFS= read -r line; do
        if [ -n "$line" ]; then
            printf "  ${BLUE}%s${NC}\n" "$line"
        fi
    done
}

# Fonction pour vérifier les mises à jour Flatpak
check_flatpak_updates() {
    print_section "📦 MISES À JOUR FLATPAK DISPONIBLES"

    if ! command -v flatpak &> /dev/null; then
        print_message $YELLOW "⚠️  Flatpak n'est pas installé"
        return 0
    fi

    # Obtenir la liste des applications Flatpak à mettre à jour
    flatpak_updates=$(flatpak remote-ls --updates 2>/dev/null)

    if [ -z "$flatpak_updates" ]; then
        print_message $GREEN "✓ Aucune mise à jour Flatpak disponible"
        return 0
    fi

    count=$(echo "$flatpak_updates" | wc -l)
    print_message $YELLOW "📊 Nombre d'applications Flatpak à mettre à jour: $count"
    echo

    print_message $CYAN "Applications Flatpak à mettre à jour:"
    echo "$flatpak_updates" | while IFS= read -r line; do
        if [ -n "$line" ]; then
            app_id=$(echo "$line" | awk '{print $1}')
            version=$(echo "$line" | awk '{print $2}')
            remote=$(echo "$line" | awk '{print $3}')

            # Obtenir le nom de l'application
            app_name=$(flatpak info "$app_id" 2>/dev/null | grep "^Name:" | cut -d':' -f2- | sed 's/^ *//')

            printf "  ${BLUE}%-40s${NC} %s (%s)\n" "${app_name:-$app_id}" "$version" "$remote"
        fi
    done
}

# Fonction pour vérifier si un redémarrage est nécessaire
check_reboot_required() {
    print_section "🔄 VÉRIFICATION DU REDÉMARRAGE"

    if [ -f /var/run/reboot-required ]; then
        print_message $RED "⚠️  REDÉMARRAGE NÉCESSAIRE"

        if [ -f /var/run/reboot-required.pkgs ]; then
            print_message $YELLOW "Paquets ayant nécessité le redémarrage:"
            while IFS= read -r pkg; do
                printf "  ${YELLOW}• %s${NC}\n" "$pkg"
            done < /var/run/reboot-required.pkgs
        fi
    else
        print_message $GREEN "✓ Aucun redémarrage nécessaire actuellement"
    fi
}

# Fonction pour vérifier les services à redémarrer
check_services_restart() {
    print_section "🔧 SERVICES À REDÉMARRER"

    if command -v needrestart &> /dev/null; then
        services=$(needrestart -l 2>/dev/null | grep "^NEEDRESTART-SVC:" | cut -d':' -f2-)

        if [ -n "$services" ]; then
            count=$(echo "$services" | wc -l)
            print_message $YELLOW "⚠️  $count service(s) nécessite(nt) un redémarrage:"
            echo "$services" | while IFS= read -r service; do
                if [ -n "$service" ]; then
                    printf "  ${YELLOW}• %s${NC}\n" "$service"
                fi
            done
        else
            print_message $GREEN "✓ Aucun service ne nécessite de redémarrage"
        fi
    else
        print_message $BLUE "ℹ️  needrestart n'est pas installé (optionnel)"
    fi
}

# Fonction pour afficher un résumé
show_summary() {
    print_section "📋 RÉSUMÉ DES MISES À JOUR"

    # Compter les mises à jour APT
    apt_count=0
    apt_upgradable=$(apt list --upgradable 2>/dev/null | tail -n +2)
    if [ -n "$apt_upgradable" ]; then
        apt_count=$(echo "$apt_upgradable" | wc -l)
    fi

    # Compter les mises à jour de sécurité
    security_count=0
    if [ -n "$apt_upgradable" ]; then
        security_updates=$(echo "$apt_upgradable" | grep -i security)
        if [ -n "$security_updates" ]; then
            security_count=$(echo "$security_updates" | wc -l)
        fi
    fi

    # Compter les mises à jour Snap
    snap_count=0
    if command -v snap &> /dev/null; then
        snap_updates=$(snap refresh --list 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$snap_updates" ]; then
            snap_count=$(echo "$snap_updates" | wc -l)
        fi
    fi

    # Compter les mises à jour Flatpak
    flatpak_count=0
    if command -v flatpak &> /dev/null; then
        flatpak_updates=$(flatpak remote-ls --updates 2>/dev/null)
        if [ -n "$flatpak_updates" ]; then
            flatpak_count=$(echo "$flatpak_updates" | wc -l)
        fi
    fi

    # Afficher le résumé
    total=$((apt_count + snap_count + flatpak_count))

    printf "  ${BLUE}%-30s${NC} %d\n" "Paquets APT:" "$apt_count"
    printf "  ${RED}%-30s${NC} %d\n" "Mises à jour de sécurité:" "$security_count"
    printf "  ${BLUE}%-30s${NC} %d\n" "Applications Snap:" "$snap_count"
    printf "  ${BLUE}%-30s${NC} %d\n" "Applications Flatpak:" "$flatpak_count"
    echo
    printf "  ${BOLD}${YELLOW}%-30s${NC} %d\n" "TOTAL:" "$total"

    if [ "$total" -eq 0 ]; then
        echo
        print_message $GREEN "🎉 Votre système est à jour!"
    else
        echo
        print_message $YELLOW "💡 Pour mettre à jour, vous pouvez utiliser le script de mise à jour automatique"
    fi
}

# Fonction pour afficher l'aide
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Script de vérification des mises à jour pour Kubuntu"
    echo
    echo "Options:"
    echo "  -h, --help      Afficher cette aide"
    echo "  -q, --quiet     Mode silencieux (moins de détails)"
    echo "  --no-snap       Ignorer les mises à jour Snap"
    echo "  --no-flatpak    Ignorer les mises à jour Flatpak"
    echo "  --security-only Afficher uniquement les mises à jour de sécurité"
    echo "  --summary-only  Afficher uniquement le résumé"
    echo
    echo "Exemples:"
    echo "  $0              # Vérification complète"
    echo "  $0 --quiet      # Mode silencieux"
    echo "  $0 --security-only # Uniquement les mises à jour de sécurité"
}

# Variables pour les options
QUIET_MODE=false
CHECK_SNAP=true
CHECK_FLATPAK=true
SECURITY_ONLY=false
SUMMARY_ONLY=false

# Analyse des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -q|--quiet)
            QUIET_MODE=true
            shift
            ;;
        --no-snap)
            CHECK_SNAP=false
            shift
            ;;
        --no-flatpak)
            CHECK_FLATPAK=false
            shift
            ;;
        --security-only)
            SECURITY_ONLY=true
            shift
            ;;
        --summary-only)
            SUMMARY_ONLY=true
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
    print_message $GREEN "🔍 VÉRIFICATION DES MISES À JOUR KUBUNTU"
    print_message $BLUE "Démarrage: $(date)"
    echo

    # Vérifications préliminaires
    check_internet
    update_package_list

    if [ "$SUMMARY_ONLY" = true ]; then
        show_summary
    elif [ "$SECURITY_ONLY" = true ]; then
        check_security_updates
    else
        # Vérifications complètes
        check_apt_updates
        check_security_updates

        if [ "$CHECK_SNAP" = true ]; then
            check_snap_updates
        fi

        if [ "$CHECK_FLATPAK" = true ]; then
            check_flatpak_updates
        fi

        check_reboot_required
        check_services_restart
        show_summary
    fi

    echo
    print_message $GREEN "✅ VÉRIFICATION TERMINÉE"
    print_message $BLUE "Fin: $(date)"
}

# Exécution du script principal
main
