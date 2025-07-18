#!/bin/bash

# Script pour lister les applications
# Auteur: NDXDev NDXDev@gmail.com
# Date: $(date +"%Y-%m-%d")

# Couleurs ANSI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Fonction pour afficher un séparateur coloré
print_separator() {
    echo -e "${CYAN}$(printf '=%.0s' {1..60})${NC}"
}

# Fonction pour compter les applications
count_apps() {
    local count=$1
    if [ $count -eq 0 ]; then
        echo -e "${RED}Aucune application trouvée${NC}"
    elif [ $count -eq 1 ]; then
        echo -e "${GREEN}1 application trouvée${NC}"
    else
        echo -e "${GREEN}$count applications trouvées${NC}"
    fi
}

# En-tête du script
clear
echo -e "${BOLD}${WHITE}"
echo "  ╔═══════════════════════════════════════════════════════╗"
echo "  ║           LISTE DES APPLICATIONS INSTALLÉES           ║"
echo "  ║                  Flatpak & Snap                       ║"
echo "  ╚═══════════════════════════════════════════════════════╝"
echo -e "${NC}"

print_separator

# === FLATPAK ===
echo -e "\n${BOLD}${PURPLE}📦 APPLICATIONS FLATPAK${NC}"
print_separator

if command -v flatpak &> /dev/null; then
    flatpak_list=$(flatpak list --app --columns=name,application,version 2>/dev/null)
    if [ -n "$flatpak_list" ]; then
        flatpak_count=$(echo "$flatpak_list" | wc -l)
        count_apps $flatpak_count
        echo ""
        echo -e "${YELLOW}${BOLD}Nom de l'application${NC} ${WHITE}|${NC} ${BLUE}${BOLD}ID de l'application${NC} ${WHITE}|${NC} ${GREEN}${BOLD}Version${NC}"
        echo -e "${WHITE}$(printf '─%.0s' {1..60})${NC}"
        echo "$flatpak_list" | while IFS=$'\t' read -r name app_id version; do
            echo -e "${YELLOW}$name${NC} ${WHITE}|${NC} ${BLUE}$app_id${NC} ${WHITE}|${NC} ${GREEN}$version${NC}"
        done
    else
        count_apps 0
    fi
else
    echo -e "${RED}❌ Flatpak n'est pas installé sur ce système${NC}"
fi

echo ""
print_separator

# === SNAP ===
echo -e "\n${BOLD}${CYAN}📱 APPLICATIONS SNAP${NC}"
print_separator

if command -v snap &> /dev/null; then
    # Vérifier si on peut accéder aux snaps (permissions)
    snap_list=$(snap list 2>/dev/null | tail -n +2)
    if [ -n "$snap_list" ]; then
        snap_count=$(echo "$snap_list" | wc -l)
        count_apps $snap_count
        echo ""
        echo -e "${YELLOW}${BOLD}Nom${NC} ${WHITE}|${NC} ${GREEN}${BOLD}Version${NC} ${WHITE}|${NC} ${PURPLE}${BOLD}Révision${NC} ${WHITE}|${NC} ${BLUE}${BOLD}Éditeur${NC}"
        echo -e "${WHITE}$(printf '─%.0s' {1..70})${NC}"
        echo "$snap_list" | while read -r name version rev tracking publisher notes; do
            # Nettoyer le nom de l'éditeur (retirer les caractères spéciaux)
            clean_publisher=$(echo "$publisher" | sed 's/\*//g')
            echo -e "${YELLOW}$name${NC} ${WHITE}|${NC} ${GREEN}$version${NC} ${WHITE}|${NC} ${PURPLE}$rev${NC} ${WHITE}|${NC} ${BLUE}$clean_publisher${NC}"
        done
    else
        count_apps 0
    fi
else
    echo -e "${RED}❌ Snap n'est pas installé sur ce système${NC}"
fi

echo ""
print_separator

# Résumé final
echo -e "\n${BOLD}${WHITE}📊 RÉSUMÉ${NC}"
total_flatpak=0
total_snap=0

if command -v flatpak &> /dev/null; then
    total_flatpak=$(flatpak list --app 2>/dev/null | wc -l)
fi

if command -v snap &> /dev/null; then
    total_snap=$(snap list 2>/dev/null | tail -n +2 | wc -l)
fi

total_apps=$((total_flatpak + total_snap))

echo -e "${PURPLE}• Flatpak: ${BOLD}$total_flatpak${NC}${PURPLE} applications${NC}"
echo -e "${CYAN}• Snap: ${BOLD}$total_snap${NC}${CYAN} applications${NC}"
echo -e "${WHITE}• Total: ${BOLD}$total_apps${NC}${WHITE} applications installées${NC}"

print_separator
echo -e "${GREEN}✅ Analyse terminée !${NC}\n"
