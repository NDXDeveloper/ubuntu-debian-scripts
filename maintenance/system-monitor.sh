#!/bin/bash

# Script de monitoring système en temps réel Ubuntu/Debian
# Auteur: NDXDev NDXDev@gmail.com
# Version: 1.1
# Date: 2025-07-18

# Configuration des seuils d'alerte
CPU_ALERT_THRESHOLD=80
RAM_ALERT_THRESHOLD=85
DISK_ALERT_THRESHOLD=90
TEMP_ALERT_THRESHOLD=75
LOAD_ALERT_THRESHOLD=1.5  # Multiplicateur du nombre de cœurs

# Configuration d'affichage
REFRESH_INTERVAL=2
SHOW_PROCESSES=10
LOG_ALERTS=false
ALERT_LOG="/var/log/system-monitor-alerts.log"

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

# Caractères pour les barres de progression
BLOCK_FULL="█"
BLOCK_EMPTY="░"

# Variables globales
PREVIOUS_NET_RX=0
PREVIOUS_NET_TX=0
ALERT_HISTORY=()

# Fonction pour effacer l'écran et repositionner le curseur
clear_screen() {
    clear
    tput cup 0 0
}

# Fonction pour cacher/montrer le curseur
hide_cursor() { tput civis; }
show_cursor() { tput cnorm; }

# Fonction pour gérer l'arrêt propre
cleanup() {
    show_cursor
    tput sgr0
    echo
    echo "Monitoring arrêté."
    exit 0
}

# Fonction pour créer une barre de progression
create_progress_bar() {
    local percentage=$1
    local width=${2:-20}
    local color=$3

    # S'assurer que percentage est un nombre valide
    if ! [[ "$percentage" =~ ^[0-9]+$ ]]; then
        percentage=0
    fi

    # Limiter entre 0 et 100
    [ "$percentage" -gt 100 ] && percentage=100
    [ "$percentage" -lt 0 ] && percentage=0

    local filled=$((percentage * width / 100))
    local empty=$((width - filled))

    printf "${color}"
    for ((i=0; i<filled; i++)); do printf "$BLOCK_FULL"; done
    printf "${NC}"
    for ((i=0; i<empty; i++)); do printf "$BLOCK_EMPTY"; done
}

# Fonction pour obtenir le CPU usage
get_cpu_usage() {
    # Méthode simple avec vmstat
    local cpu_idle=$(vmstat 1 2 | tail -1 | awk '{print $15}')
    if [[ "$cpu_idle" =~ ^[0-9]+$ ]]; then
        echo $((100 - cpu_idle))
    else
        # Fallback avec top
        top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' | cut -d'.' -f1
    fi
}

# Fonction pour obtenir les informations système
get_system_info() {
    # CPU
    local cpu_usage=$(get_cpu_usage)
    [ -z "$cpu_usage" ] && cpu_usage=0

    local load_avg=$(cat /proc/loadavg | cut -d' ' -f1)
    local cpu_cores=$(nproc)
    local cpu_freq=$(lscpu | grep "CPU MHz" | awk '{print int($3)}' 2>/dev/null)
    [ -z "$cpu_freq" ] && cpu_freq="N/A"

    # Mémoire
    local mem_info=$(free -m)
    local mem_total=$(echo "$mem_info" | grep "Mem:" | awk '{print $2}')
    local mem_used=$(echo "$mem_info" | grep "Mem:" | awk '{print $3}')
    local mem_percentage=$((mem_used * 100 / mem_total))

    # Swap
    local swap_total=$(echo "$mem_info" | grep "Swap:" | awk '{print $2}')
    local swap_used=$(echo "$mem_info" | grep "Swap:" | awk '{print $3}')
    local swap_percentage=0
    if [ "$swap_total" -gt 0 ]; then
        swap_percentage=$((swap_used * 100 / swap_total))
    fi

    # Disque
    local disk_info=$(df -h / | tail -1)
    local disk_used=$(echo "$disk_info" | awk '{print $3}')
    local disk_total=$(echo "$disk_info" | awk '{print $2}')
    local disk_percentage=$(echo "$disk_info" | awk '{print $5}' | sed 's/%//')
    local disk_available=$(echo "$disk_info" | awk '{print $4}')

    # Température
    local temperature="N/A"
    if command -v sensors &> /dev/null; then
        temperature=$(sensors 2>/dev/null | grep -i core | head -1 | awk '{print $3}' | sed 's/[+°C]//g' | cut -d'.' -f1)
    fi
    if [ -z "$temperature" ] || [ "$temperature" = "N/A" ]; then
        if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
            temperature=$(($(cat /sys/class/thermal/thermal_zone0/temp) / 1000))
        fi
    fi
    [ -z "$temperature" ] && temperature="N/A"

    # Réseau
    local net_interface=$(ip route | grep default | awk '{print $5}' | head -1)
    local net_rx=0
    local net_tx=0

    if [ -n "$net_interface" ] && [ -f "/sys/class/net/$net_interface/statistics/rx_bytes" ]; then
        local rx_bytes=$(cat /sys/class/net/$net_interface/statistics/rx_bytes)
        local tx_bytes=$(cat /sys/class/net/$net_interface/statistics/tx_bytes)

        if [ "$PREVIOUS_NET_RX" -ne 0 ]; then
            net_rx=$(((rx_bytes - PREVIOUS_NET_RX) / REFRESH_INTERVAL))
            net_tx=$(((tx_bytes - PREVIOUS_NET_TX) / REFRESH_INTERVAL))
        fi

        PREVIOUS_NET_RX=$rx_bytes
        PREVIOUS_NET_TX=$tx_bytes
    else
        net_interface="N/A"
    fi

    # Retourner toutes les valeurs
    echo "$cpu_usage|$load_avg|$cpu_cores|$cpu_freq|$mem_used|$mem_total|$mem_percentage|$swap_used|$swap_total|$swap_percentage|$disk_used|$disk_total|$disk_percentage|$disk_available|$temperature|$net_interface|$net_rx|$net_tx"
}

# Fonction pour convertir bytes en format lisible
bytes_to_human() {
    local bytes=$1
    if [ "$bytes" -lt 1024 ]; then
        echo "${bytes}B/s"
    elif [ "$bytes" -lt 1048576 ]; then
        echo "$((bytes / 1024))KB/s"
    elif [ "$bytes" -lt 1073741824 ]; then
        echo "$((bytes / 1048576))MB/s"
    else
        echo "$((bytes / 1073741824))GB/s"
    fi
}

# Fonction pour logger les alertes
log_alert() {
    local message="$1"
    if [ "$LOG_ALERTS" = true ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALERT: $message" >> "$ALERT_LOG"
    fi
    ALERT_HISTORY+=("$(date '+%H:%M:%S'): $message")

    # Garder seulement les 5 dernières alertes
    if [ ${#ALERT_HISTORY[@]} -gt 5 ]; then
        ALERT_HISTORY=("${ALERT_HISTORY[@]:1}")
    fi
}

# Fonction pour vérifier les seuils
check_alerts() {
    local data="$1"
    local cpu_usage=$(echo "$data" | cut -d'|' -f1)
    local load_avg=$(echo "$data" | cut -d'|' -f2)
    local cpu_cores=$(echo "$data" | cut -d'|' -f3)
    local mem_percentage=$(echo "$data" | cut -d'|' -f7)
    local disk_percentage=$(echo "$data" | cut -d'|' -f13)
    local temperature=$(echo "$data" | cut -d'|' -f15)

    # Alerte CPU
    if [ "$cpu_usage" -gt "$CPU_ALERT_THRESHOLD" ]; then
        log_alert "CPU élevé: ${cpu_usage}% (seuil: ${CPU_ALERT_THRESHOLD}%)"
    fi

    # Alerte RAM
    if [ "$mem_percentage" -gt "$RAM_ALERT_THRESHOLD" ]; then
        log_alert "RAM élevée: ${mem_percentage}% (seuil: ${RAM_ALERT_THRESHOLD}%)"
    fi

    # Alerte disque
    if [ "$disk_percentage" -gt "$DISK_ALERT_THRESHOLD" ]; then
        log_alert "Disque plein: ${disk_percentage}% (seuil: ${DISK_ALERT_THRESHOLD}%)"
    fi

    # Alerte température
    if [ "$temperature" != "N/A" ] && [ "$temperature" -gt "$TEMP_ALERT_THRESHOLD" ]; then
        log_alert "Température élevée: ${temperature}°C (seuil: ${TEMP_ALERT_THRESHOLD}°C)"
    fi

    # Alerte charge système
    if command -v bc &> /dev/null; then
        local max_load=$(echo "$cpu_cores * $LOAD_ALERT_THRESHOLD" | bc -l)
        local load_check=$(echo "$load_avg > $max_load" | bc -l 2>/dev/null)
        if [ "$load_check" = "1" ]; then
            log_alert "Charge système élevée: $load_avg (seuil: $max_load pour $cpu_cores cœurs)"
        fi
    fi
}

# Fonction pour obtenir les top processus
get_top_processes() {
    ps aux --sort=-%cpu | head -n $((SHOW_PROCESSES + 1)) | tail -n $SHOW_PROCESSES | awk '{printf "%-12s %6s %6s %s\n", $1, $3, $4, $11}'
}

# Fonction pour afficher l'en-tête
display_header() {
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    local uptime_info=$(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')

    printf "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}\n"
    printf "${BOLD}${CYAN}║${NC}${BOLD}                           MONITORING SYSTÈME EN TEMPS RÉEL                    ${CYAN}║${NC}\n"
    printf "${BOLD}${CYAN}║${NC}  Heure: %-20s | Uptime: %-25s ${CYAN}║${NC}\n" "$current_time" "$uptime_info"
    printf "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}\n\n"
}

# Fonction principale d'affichage
display_metrics() {
    local data=$(get_system_info)

    # Extraction des données
    local cpu_usage=$(echo "$data" | cut -d'|' -f1)
    local load_avg=$(echo "$data" | cut -d'|' -f2)
    local cpu_cores=$(echo "$data" | cut -d'|' -f3)
    local cpu_freq=$(echo "$data" | cut -d'|' -f4)
    local mem_used=$(echo "$data" | cut -d'|' -f5)
    local mem_total=$(echo "$data" | cut -d'|' -f6)
    local mem_percentage=$(echo "$data" | cut -d'|' -f7)
    local swap_used=$(echo "$data" | cut -d'|' -f8)
    local swap_total=$(echo "$data" | cut -d'|' -f9)
    local swap_percentage=$(echo "$data" | cut -d'|' -f10)
    local disk_used=$(echo "$data" | cut -d'|' -f11)
    local disk_total=$(echo "$data" | cut -d'|' -f12)
    local disk_percentage=$(echo "$data" | cut -d'|' -f13)
    local disk_available=$(echo "$data" | cut -d'|' -f14)
    local temperature=$(echo "$data" | cut -d'|' -f15)
    local net_interface=$(echo "$data" | cut -d'|' -f16)
    local net_rx=$(echo "$data" | cut -d'|' -f17)
    local net_tx=$(echo "$data" | cut -d'|' -f18)

    # Vérifier les alertes
    check_alerts "$data"

    # Déterminer les couleurs
    local cpu_color=$GREEN
    [ "$cpu_usage" -gt $((CPU_ALERT_THRESHOLD - 20)) ] && cpu_color=$YELLOW
    [ "$cpu_usage" -gt "$CPU_ALERT_THRESHOLD" ] && cpu_color=$RED

    local mem_color=$GREEN
    [ "$mem_percentage" -gt $((RAM_ALERT_THRESHOLD - 15)) ] && mem_color=$YELLOW
    [ "$mem_percentage" -gt "$RAM_ALERT_THRESHOLD" ] && mem_color=$RED

    local disk_color=$GREEN
    [ "$disk_percentage" -gt $((DISK_ALERT_THRESHOLD - 10)) ] && disk_color=$YELLOW
    [ "$disk_percentage" -gt "$DISK_ALERT_THRESHOLD" ] && disk_color=$RED

    local temp_color=$GREEN
    if [ "$temperature" != "N/A" ]; then
        [ "$temperature" -gt $((TEMP_ALERT_THRESHOLD - 15)) ] && temp_color=$YELLOW
        [ "$temperature" -gt "$TEMP_ALERT_THRESHOLD" ] && temp_color=$RED
    fi

    # Affichage CPU
    printf "${BOLD}${BLUE}┌─ CPU ────────────────────────────────────────────────────────────────────────┐${NC}\n"
    printf "${BOLD}${BLUE}│${NC} Usage: ${cpu_color}%6s%%${NC} " "$cpu_usage"
    create_progress_bar "$cpu_usage" 20 "$cpu_color"
    printf "  Load: ${CYAN}%-6s${NC} Cores: ${CYAN}%-2s${NC} Freq: ${CYAN}%-4s${NC}MHz ${BOLD}${BLUE}│${NC}\n" "$load_avg" "$cpu_cores" "$cpu_freq"

    # Affichage RAM
    printf "${BOLD}${BLUE}├─ MÉMOIRE ───────────────────────────────────────────────────────────────────┤${NC}\n"
    printf "${BOLD}${BLUE}│${NC} RAM: ${mem_color}%6s${NC}/${CYAN}%-6s${NC} MB (${mem_color}%3s%%${NC}) " "$mem_used" "$mem_total" "$mem_percentage"
    create_progress_bar "$mem_percentage" 15 "$mem_color"
    printf "                    ${BOLD}${BLUE}│${NC}\n"

    if [ "$swap_total" -gt 0 ]; then
        local swap_color=$GREEN
        [ "$swap_percentage" -gt 50 ] && swap_color=$YELLOW
        [ "$swap_percentage" -gt 80 ] && swap_color=$RED

        printf "${BOLD}${BLUE}│${NC} Swap: ${swap_color}%5s${NC}/${CYAN}%-6s${NC} MB (${swap_color}%3s%%${NC}) " "$swap_used" "$swap_total" "$swap_percentage"
        create_progress_bar "$swap_percentage" 15 "$swap_color"
        printf "                    ${BOLD}${BLUE}│${NC}\n"
    fi

    # Affichage Disque
    printf "${BOLD}${BLUE}├─ DISQUE ────────────────────────────────────────────────────────────────────┤${NC}\n"
    printf "${BOLD}${BLUE}│${NC} Utilisé: ${disk_color}%-6s${NC}/${CYAN}%-6s${NC} (${disk_color}%3s%%${NC}) " "$disk_used" "$disk_total" "$disk_percentage"
    create_progress_bar "$disk_percentage" 15 "$disk_color"
    printf " Libre: ${GREEN}%-6s${NC}    ${BOLD}${BLUE}│${NC}\n" "$disk_available"

    # Affichage Système
    printf "${BOLD}${BLUE}├─ SYSTÈME ───────────────────────────────────────────────────────────────────┤${NC}\n"
    if [ "$temperature" != "N/A" ]; then
        printf "${BOLD}${BLUE}│${NC} Température: ${temp_color}%-4s${NC}°C" "$temperature"
    else
        printf "${BOLD}${BLUE}│${NC} Température: ${YELLOW}%-8s${NC}" "N/A"
    fi

    printf "  Interface: ${CYAN}%-8s${NC}  ↓${GREEN}%-12s${NC} ↑${RED}%-12s${NC} ${BOLD}${BLUE}│${NC}\n" \
           "$net_interface" "$(bytes_to_human $net_rx)" "$(bytes_to_human $net_tx)"

    printf "${BOLD}${BLUE}└──────────────────────────────────────────────────────────────────────────────┘${NC}\n\n"
}

# Fonction pour afficher les processus
display_top_processes() {
    printf "${BOLD}${MAGENTA}┌─ TOP PROCESSUS (CPU) ────────────────────────────────────────────────────────┐${NC}\n"
    printf "${BOLD}${MAGENTA}│${NC} ${BOLD}%-12s %6s %6s %s${NC}${BOLD}${MAGENTA}│${NC}\n" "UTILISATEUR" "CPU%" "RAM%" "COMMANDE"
    printf "${BOLD}${MAGENTA}├──────────────────────────────────────────────────────────────────────────────┤${NC}\n"

    get_top_processes | while read line; do
        printf "${BOLD}${MAGENTA}│${NC} ${line} ${BOLD}${MAGENTA}│${NC}\n"
    done

    printf "${BOLD}${MAGENTA}└──────────────────────────────────────────────────────────────────────────────┘${NC}\n\n"
}

# Fonction pour afficher les alertes
display_alerts() {
    if [ ${#ALERT_HISTORY[@]} -gt 0 ]; then
        printf "${BOLD}${RED}┌─ ALERTES RÉCENTES ───────────────────────────────────────────────────────────┐${NC}\n"
        for alert in "${ALERT_HISTORY[@]}"; do
            printf "${BOLD}${RED}│${NC} ⚠️  ${alert} ${BOLD}${RED}│${NC}\n"
        done
        printf "${BOLD}${RED}└──────────────────────────────────────────────────────────────────────────────┘${NC}\n\n"
    fi
}

# Fonction pour afficher les contrôles
display_controls() {
    printf "${BOLD}${WHITE}┌─ CONTRÔLES ──────────────────────────────────────────────────────────────────┐${NC}\n"
    printf "${BOLD}${WHITE}│${NC} ${CYAN}[q]${NC} Quitter  ${CYAN}[p]${NC} Pause  ${CYAN}[r]${NC} Reset alertes  ${CYAN}[s]${NC} Sauvegarder état    ${BOLD}${WHITE}│${NC}\n"
    printf "${BOLD}${WHITE}│${NC} Intervalle: ${YELLOW}${REFRESH_INTERVAL}s${NC}  Seuils: CPU:${RED}${CPU_ALERT_THRESHOLD}%%${NC} RAM:${RED}${RAM_ALERT_THRESHOLD}%%${NC} Disque:${RED}${DISK_ALERT_THRESHOLD}%%${NC} Temp:${RED}${TEMP_ALERT_THRESHOLD}°C${NC}  ${BOLD}${WHITE}│${NC}\n"
    printf "${BOLD}${WHITE}└──────────────────────────────────────────────────────────────────────────────┘${NC}\n"
}

# Boucle principale
monitor_loop() {
    hide_cursor

    while true; do
        clear_screen

        display_header
        display_metrics
        display_top_processes
        display_alerts
        display_controls

        # Lecture non-bloquante
        read -t $REFRESH_INTERVAL -n 1 key
        case $key in
            q|Q) cleanup ;;
            p|P) read -p "Appuyez sur Entrée pour continuer..." -r ;;
            r|R) ALERT_HISTORY=() ;;
            s|S)
                echo "État sauvegardé dans /tmp/system_state_$(date +%Y%m%d_%H%M%S).txt"
                sleep 1
                ;;
        esac
    done
}

# Fonction d'aide
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Monitoring système en temps réel pour Ubuntu/Debian"
    echo
    echo "Options:"
    echo "  -h, --help              Afficher cette aide"
    echo "  -i, --interval SECONDS  Intervalle de rafraîchissement (défaut: 2s)"
    echo "  -p, --processes N       Nombre de processus à afficher (défaut: 10)"
    echo "  -l, --log-alerts        Activer la journalisation des alertes"
    echo "  --cpu-threshold N       Seuil d'alerte CPU en % (défaut: 80)"
    echo "  --ram-threshold N       Seuil d'alerte RAM en % (défaut: 85)"
    echo "  --disk-threshold N      Seuil d'alerte disque en % (défaut: 90)"
    echo "  --temp-threshold N      Seuil d'alerte température en °C (défaut: 75)"
    echo
    echo "Contrôles pendant l'exécution:"
    echo "  q : Quitter"
    echo "  p : Pause"
    echo "  r : Reset des alertes"
    echo "  s : Sauvegarder l'état système"
}

# Analyse des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) show_help; exit 0 ;;
        -i|--interval) REFRESH_INTERVAL="$2"; shift 2 ;;
        -p|--processes) SHOW_PROCESSES="$2"; shift 2 ;;
        -l|--log-alerts) LOG_ALERTS=true; shift ;;
        --cpu-threshold) CPU_ALERT_THRESHOLD="$2"; shift 2 ;;
        --ram-threshold) RAM_ALERT_THRESHOLD="$2"; shift 2 ;;
        --disk-threshold) DISK_ALERT_THRESHOLD="$2"; shift 2 ;;
        --temp-threshold) TEMP_ALERT_THRESHOLD="$2"; shift 2 ;;
        *) echo "Option inconnue: $1"; show_help; exit 1 ;;
    esac
done

# Configuration du signal de sortie
trap cleanup SIGINT SIGTERM

# Démarrage
echo "Démarrage du monitoring système..."
echo "Appuyez sur Ctrl+C ou 'q' pour quitter"
sleep 2

monitor_loop
