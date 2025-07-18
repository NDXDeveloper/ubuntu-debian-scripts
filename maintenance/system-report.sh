#!/bin/bash

# Script de rapport système complet pour Ubuntu/Debian
# Auteur: NDXDev NDXDev@gmail.com
# Version: 1.0
# Date: 2025-07-18

# Configuration
REPORT_DIR="/tmp/system_reports"
REPORT_NAME="system_report_$(hostname)_$(date +%Y%m%d_%H%M%S)"
OUTPUT_FORMAT="html"
INCLUDE_PERFORMANCE=true
INCLUDE_SOFTWARE=true
INCLUDE_LOGS=false
VERBOSE_MODE=false
COMPRESS_REPORT=false

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
REPORT_FILE=""
START_TIME=$(date +%s)
SECTIONS_COMPLETED=0
TOTAL_SECTIONS=12

# Fonction pour afficher les messages avec couleurs
print_message() {
    local level=$1
    local message=$2

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
}

# Fonction pour afficher la progression
show_progress() {
    local current=$1
    local total=$2
    local percentage=$((current * 100 / total))
    local bar_length=30
    local filled_length=$((percentage * bar_length / 100))

    printf "\r${CYAN}Progression: ["
    printf "%*s" $filled_length | tr ' ' '█'
    printf "%*s" $((bar_length - filled_length)) | tr ' ' '░'
    printf "] %d%% (%d/%d)${NC}" $percentage $current $total
}

# Fonction pour initialiser le rapport
init_report() {
    # Créer le répertoire de sortie
    mkdir -p "$REPORT_DIR"

    # Gérer le nom du fichier correctement
    if [[ "$REPORT_NAME" =~ ^/ ]] || [[ "$REPORT_NAME" =~ ^~ ]]; then
        # Si le nom contient un chemin complet, l'utiliser tel quel
        REPORT_FILE=$(realpath "$REPORT_NAME" 2>/dev/null || echo "$REPORT_NAME")

        # Créer le répertoire parent si nécessaire
        local parent_dir=$(dirname "$REPORT_FILE")
        mkdir -p "$parent_dir"
    else
        # Sinon, utiliser le répertoire de sortie + nom
        case $OUTPUT_FORMAT in
            "html")
                REPORT_FILE="$REPORT_DIR/$REPORT_NAME.html"
                ;;
            "text"|"txt")
                REPORT_FILE="$REPORT_DIR/$REPORT_NAME.txt"
                ;;
            "json")
                REPORT_FILE="$REPORT_DIR/$REPORT_NAME.json"
                ;;
        esac
    fi

    # Ajouter l'extension si manquante
    case $OUTPUT_FORMAT in
        "html")
            [[ "$REPORT_FILE" =~ \.html$ ]] || REPORT_FILE="${REPORT_FILE}.html"
            init_html_report
            ;;
        "text"|"txt")
            [[ "$REPORT_FILE" =~ \.(txt|text)$ ]] || REPORT_FILE="${REPORT_FILE}.txt"
            init_text_report
            ;;
        "json")
            [[ "$REPORT_FILE" =~ \.json$ ]] || REPORT_FILE="${REPORT_FILE}.json"
            init_json_report
            ;;
        *)
            print_message "ERROR" "Format de sortie non supporté: $OUTPUT_FORMAT"
            exit 1
            ;;
    esac

    print_message "INFO" "Rapport initialisé: $REPORT_FILE"
}

# Fonction pour initialiser le rapport HTML
init_html_report() {
    cat > "$REPORT_FILE" << 'EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Rapport Système</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 0 20px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            border-bottom: 3px solid #007acc;
            padding-bottom: 20px;
            margin-bottom: 30px;
        }
        .header h1 {
            color: #007acc;
            margin: 0;
            font-size: 2.5em;
        }
        .section {
            margin-bottom: 30px;
            border: 1px solid #ddd;
            border-radius: 8px;
            overflow: hidden;
        }
        .section-header {
            background: linear-gradient(135deg, #007acc, #0099ff);
            color: white;
            padding: 15px 20px;
            font-size: 1.3em;
            font-weight: bold;
        }
        .section-content {
            padding: 20px;
        }
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 15px;
            margin-bottom: 20px;
        }
        .info-item {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            border-left: 4px solid #007acc;
        }
        .info-label {
            font-weight: bold;
            color: #333;
            margin-bottom: 5px;
        }
        .info-value {
            color: #666;
            font-family: 'Courier New', monospace;
        }
        .table-container {
            overflow-x: auto;
            margin: 15px 0;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            background: white;
            border-radius: 5px;
            overflow: hidden;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }
        th, td {
            padding: 12px 15px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background: #007acc;
            color: white;
            font-weight: bold;
        }
        tr:hover {
            background: #f5f5f5;
        }
        .progress-bar {
            width: 100%;
            height: 20px;
            background: #e0e0e0;
            border-radius: 10px;
            overflow: hidden;
            margin: 5px 0;
        }
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #4CAF50, #45a049);
            transition: width 0.3s ease;
        }
        .status-ok { color: #4CAF50; font-weight: bold; }
        .status-warning { color: #ff9800; font-weight: bold; }
        .status-error { color: #f44336; font-weight: bold; }
        .footer {
            text-align: center;
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            color: #666;
        }
        @media print {
            body { background: white; }
            .container { box-shadow: none; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🖥️ Rapport Système</h1>
EOF

    echo "            <p>Généré le $(date '+%d/%m/%Y à %H:%M:%S')</p>" >> "$REPORT_FILE"
    echo "            <p>Hostname: <strong>$(hostname)</strong></p>" >> "$REPORT_FILE"
    echo "        </div>" >> "$REPORT_FILE"
}

# Fonction pour initialiser le rapport texte
init_text_report() {
    cat > "$REPORT_FILE" << EOF
════════════════════════════════════════════════════════════════════════════════
                              RAPPORT SYSTÈME COMPLET
════════════════════════════════════════════════════════════════════════════════

Date de génération: $(date '+%d/%m/%Y à %H:%M:%S')
Hostname: $(hostname)
Utilisateur: $USER

════════════════════════════════════════════════════════════════════════════════

EOF
}

# Fonction pour ajouter une section HTML
add_html_section() {
    local title="$1"
    local content="$2"

    cat >> "$REPORT_FILE" << EOF
        <div class="section">
            <div class="section-header">$title</div>
            <div class="section-content">
                $content
            </div>
        </div>
EOF
}

# Fonction pour ajouter une section texte
add_text_section() {
    local title="$1"
    local content="$2"

    cat >> "$REPORT_FILE" << EOF

$title
$(echo "$title" | sed 's/./=/g')

$content

EOF
}

# Fonction pour ajouter du contenu selon le format
add_section() {
    local title="$1"
    local content="$2"

    # Vérifier que le fichier de rapport existe
    if [ ! -f "$REPORT_FILE" ]; then
        print_message "ERROR" "Fichier de rapport non trouvé: $REPORT_FILE"
        return 1
    fi

    case $OUTPUT_FORMAT in
        "html")
            add_html_section "$title" "$content"
            ;;
        "text"|"txt")
            add_text_section "$title" "$content"
            ;;
    esac
}

# Fonction pour gérer l'expansion de ~
expand_path() {
    local path="$1"

    # Expansion de ~
    if [[ "$path" =~ ^~ ]]; then
        path="${path/#\~/$HOME}"
    fi

    echo "$path"
}

# Fonction pour collecter les informations système de base
collect_system_info() {
    print_message "PROGRESS" "Collecte des informations système..."

    local os_info=$(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")
    local kernel=$(uname -r)
    local architecture=$(uname -m)
    local uptime_info=$(uptime -p 2>/dev/null || uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')
    local hostname=$(hostname)
    local timezone=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "Unknown")
    local locale_info=$(locale | grep LANG | cut -d'=' -f2)

    local content=""
    case $OUTPUT_FORMAT in
        "html")
            content='
                <div class="info-grid">
                    <div class="info-item">
                        <div class="info-label">Système d'\''exploitation</div>
                        <div class="info-value">'$os_info'</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Noyau</div>
                        <div class="info-value">'$kernel'</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Architecture</div>
                        <div class="info-value">'$architecture'</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Nom d'\''hôte</div>
                        <div class="info-value">'$hostname'</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Temps de fonctionnement</div>
                        <div class="info-value">'$uptime_info'</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Fuseau horaire</div>
                        <div class="info-value">'$timezone'</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Locale</div>
                        <div class="info-value">'$locale_info'</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Date du rapport</div>
                        <div class="info-value">'"$(date '+%d/%m/%Y %H:%M:%S')"'</div>
                    </div>
                </div>'
            ;;
        "text"|"txt")
            content="Système d'exploitation: $os_info
Noyau: $kernel
Architecture: $architecture
Nom d'hôte: $hostname
Temps de fonctionnement: $uptime_info
Fuseau horaire: $timezone
Locale: $locale_info
Date du rapport: $(date '+%d/%m/%Y %H:%M:%S')"
            ;;
    esac

    add_section "📋 Informations Système" "$content"
    SECTIONS_COMPLETED=$((SECTIONS_COMPLETED + 1))
    show_progress $SECTIONS_COMPLETED $TOTAL_SECTIONS
}

# Fonction pour collecter les informations hardware
collect_hardware_info() {
    print_message "PROGRESS" "Collecte des informations matérielles..."

    # CPU Info
    local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | sed 's/^ *//')
    local cpu_cores=$(nproc)
    local cpu_threads=$(grep "processor" /proc/cpuinfo | wc -l)
    local cpu_freq=$(lscpu | grep "CPU MHz" | awk '{print $3}' | head -1)
    [ -z "$cpu_freq" ] && cpu_freq="N/A"

    # Memory Info
    local mem_info=$(free -h | grep "Mem:")
    local mem_total=$(echo "$mem_info" | awk '{print $2}')
    local mem_used=$(echo "$mem_info" | awk '{print $3}')
    local mem_available=$(echo "$mem_info" | awk '{print $7}')

    # Swap Info
    local swap_info=$(free -h | grep "Swap:")
    local swap_total=$(echo "$swap_info" | awk '{print $2}')
    local swap_used=$(echo "$swap_info" | awk '{print $3}')

    # GPU Info
    local gpu_info="N/A"
    if command -v lspci &> /dev/null; then
        gpu_info=$(lspci | grep -i vga | cut -d':' -f3 | sed 's/^ *//' | head -1)
        [ -z "$gpu_info" ] && gpu_info="N/A"
    fi

    # Motherboard info
    local motherboard="N/A"
    if [ -f /sys/devices/virtual/dmi/id/board_name ]; then
        local board_name=$(cat /sys/devices/virtual/dmi/id/board_name 2>/dev/null)
        local board_vendor=$(cat /sys/devices/virtual/dmi/id/board_vendor 2>/dev/null)
        if [ -n "$board_name" ] && [ -n "$board_vendor" ]; then
            motherboard="$board_vendor $board_name"
        fi
    fi

    local content=""
    case $OUTPUT_FORMAT in
        "html")
            content='
                <div class="info-grid">
                    <div class="info-item">
                        <div class="info-label">Processeur</div>
                        <div class="info-value">'$cpu_model'</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Cœurs / Threads</div>
                        <div class="info-value">'$cpu_cores' cœurs / '$cpu_threads' threads</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Fréquence CPU</div>
                        <div class="info-value">'$cpu_freq' MHz</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Mémoire totale</div>
                        <div class="info-value">'$mem_total'</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Mémoire utilisée</div>
                        <div class="info-value">'$mem_used'</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Mémoire disponible</div>
                        <div class="info-value">'$mem_available'</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Swap total</div>
                        <div class="info-value">'$swap_total'</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Carte graphique</div>
                        <div class="info-value">'$gpu_info'</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Carte mère</div>
                        <div class="info-value">'$motherboard'</div>
                    </div>
                </div>'
            ;;
        "text"|"txt")
            content="Processeur: $cpu_model
Cœurs / Threads: $cpu_cores cœurs / $cpu_threads threads
Fréquence CPU: $cpu_freq MHz
Mémoire totale: $mem_total
Mémoire utilisée: $mem_used
Mémoire disponible: $mem_available
Swap total: $swap_total
Carte graphique: $gpu_info
Carte mère: $motherboard"
            ;;
    esac

    add_section "🔧 Informations Matérielles" "$content"
    SECTIONS_COMPLETED=$((SECTIONS_COMPLETED + 1))
    show_progress $SECTIONS_COMPLETED $TOTAL_SECTIONS
}

# Fonction pour collecter les informations de stockage
collect_storage_info() {
    print_message "PROGRESS" "Collecte des informations de stockage..."

    local content=""
    case $OUTPUT_FORMAT in
        "html")
            content='<div class="table-container"><table>
                <tr><th>Point de montage</th><th>Système de fichiers</th><th>Taille</th><th>Utilisé</th><th>Disponible</th><th>Utilisation</th></tr>'

            # Utiliser un fichier temporaire pour éviter le problème du sous-shell
            local temp_file=$(mktemp)
            df -h | grep -E "^/dev|^tmpfs" > "$temp_file"

            while IFS= read -r line; do
                local filesystem=$(echo "$line" | awk '{print $1}')
                local size=$(echo "$line" | awk '{print $2}')
                local used=$(echo "$line" | awk '{print $3}')
                local available=$(echo "$line" | awk '{print $4}')
                local use_percent=$(echo "$line" | awk '{print $5}' | sed 's/%//')
                local mount_point=$(echo "$line" | awk '{print $6}')

                # Déterminer la couleur selon l'utilisation
                local status_class="status-ok"
                if [ "$use_percent" -gt 80 ]; then
                    status_class="status-error"
                elif [ "$use_percent" -gt 60 ]; then
                    status_class="status-warning"
                fi

                content+='<tr>
                    <td>'$mount_point'</td>
                    <td>'$filesystem'</td>
                    <td>'$size'</td>
                    <td>'$used'</td>
                    <td>'$available'</td>
                    <td class="'$status_class'">'$use_percent'%</td>
                </tr>'
            done < "$temp_file"
            rm -f "$temp_file"

            content+='</table></div>'

            # Ajouter les informations sur les disques
            if command -v lsblk &> /dev/null; then
                content+='<h4>🗄️ Disques et partitions</h4>
                <div class="table-container"><table>
                <tr><th>Nom</th><th>Taille</th><th>Type</th><th>Point de montage</th></tr>'

                local temp_file2=$(mktemp)
                lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | tail -n +2 > "$temp_file2"

                while IFS= read -r line; do
                    local name=$(echo "$line" | awk '{print $1}')
                    local size=$(echo "$line" | awk '{print $2}')
                    local type=$(echo "$line" | awk '{print $3}')
                    local mountpoint=$(echo "$line" | awk '{print $4}')

                    content+='<tr>
                        <td>'$name'</td>
                        <td>'$size'</td>
                        <td>'$type'</td>
                        <td>'${mountpoint:-"-"}'</td>
                    </tr>'
                done < "$temp_file2"
                rm -f "$temp_file2"

                content+='</table></div>'
            fi
            ;;
        "text"|"txt")
            content="Utilisation des disques:
$(df -h | grep -E "^/dev|^tmpfs")

Disques et partitions:"
            if command -v lsblk &> /dev/null; then
                content+="\n$(lsblk)"
            fi
            ;;
    esac

    add_section "💾 Informations de Stockage" "$content"
    SECTIONS_COMPLETED=$((SECTIONS_COMPLETED + 1))
    show_progress $SECTIONS_COMPLETED $TOTAL_SECTIONS
}

# Fonction pour collecter les informations réseau
collect_network_info() {
    print_message "PROGRESS" "Collecte des informations réseau..."

    local content=""
    case $OUTPUT_FORMAT in
        "html")
            content='<div class="table-container"><table>
                <tr><th>Interface</th><th>État</th><th>Adresse IP</th><th>Type</th></tr>'

            # Obtenir la liste des interfaces
            local temp_file=$(mktemp)
            ip addr show | grep -E "^[0-9]+:" | awk '{print $2}' | sed 's/:$//' > "$temp_file"

            while IFS= read -r interface; do
                local state="DOWN"
                local ip="N/A"
                local type="Unknown"

                # Obtenir l'état et l'IP
                local interface_info=$(ip addr show "$interface" 2>/dev/null)
                if echo "$interface_info" | grep -q "state UP"; then
                    state="UP"
                fi

                # Obtenir l'adresse IP
                local ip_line=$(echo "$interface_info" | grep "inet " | head -1)
                if [ -n "$ip_line" ]; then
                    ip=$(echo "$ip_line" | awk '{print $2}' | cut -d'/' -f1)
                fi

                # Déterminer le type
                if [[ "$interface" =~ ^eth|^enp ]]; then
                    type="Ethernet"
                elif [[ "$interface" =~ ^wlan|^wlp|^wlx ]]; then
                    type="WiFi"
                elif [[ "$interface" =~ ^lo ]]; then
                    type="Loopback"
                elif [[ "$interface" =~ ^docker|^br ]]; then
                    type="Bridge"
                fi

                local status_class="status-error"
                [ "$state" = "UP" ] && status_class="status-ok"

                content+='<tr>
                    <td>'$interface'</td>
                    <td class="'$status_class'">'$state'</td>
                    <td>'$ip'</td>
                    <td>'$type'</td>
                </tr>'
            done < "$temp_file"
            rm -f "$temp_file"

            content+='</table></div>'

            # Route par défaut
            local default_route=$(ip route show default 2>/dev/null | head -1)
            if [ -n "$default_route" ]; then
                local gateway=$(echo "$default_route" | awk '{print $3}')
                local interface=$(echo "$default_route" | awk '{print $5}')
                content+='<h4>🌐 Route par défaut</h4>
                <div class="info-item">
                    <div class="info-label">Passerelle</div>
                    <div class="info-value">'$gateway' via '$interface'</div>
                </div>'
            fi
            ;;
        "text"|"txt")
            content="Interfaces réseau:
$(ip addr show | grep -E "^[0-9]+:|inet " | sed 's/^    /  /')

Route par défaut:
$(ip route show default)"
            ;;
    esac

    add_section "🌐 Informations Réseau" "$content"
    SECTIONS_COMPLETED=$((SECTIONS_COMPLETED + 1))
    show_progress $SECTIONS_COMPLETED $TOTAL_SECTIONS
}

# Fonction pour collecter les informations sur les services
collect_services_info() {
    print_message "PROGRESS" "Collecte des informations sur les services..."

    local content=""
    case $OUTPUT_FORMAT in
        "html")
            content='<div class="table-container"><table>
                <tr><th>Service</th><th>État</th><th>Activé</th><th>Description</th></tr>'

            # Services importants à vérifier
            local important_services=("ssh" "apache2" "nginx" "mysql" "postgresql" "docker" "fail2ban" "ufw" "cron" "rsyslog")

            for service in "${important_services[@]}"; do
                if systemctl list-units --all | grep -q "${service}.service"; then
                    local status=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
                    local enabled=$(systemctl is-enabled "$service" 2>/dev/null || echo "disabled")
                    local description=$(systemctl show "$service" --property=Description --value 2>/dev/null || echo "N/A")

                    local status_class="status-error"
                    [ "$status" = "active" ] && status_class="status-ok"
                    [ "$status" = "inactive" ] && status_class="status-warning"

                    local enabled_class="status-error"
                    [ "$enabled" = "enabled" ] && enabled_class="status-ok"

                    content+='<tr>
                        <td>'$service'</td>
                        <td class="'$status_class'">'$status'</td>
                        <td class="'$enabled_class'">'$enabled'</td>
                        <td>'$description'</td>
                    </tr>'
                fi
            done

            content+='</table></div>'

            # Services en échec
            local failed_services=$(systemctl list-units --failed --no-pager --no-legend 2>/dev/null | wc -l)
            content+='<h4>⚠️ État général</h4>
            <div class="info-item">
                <div class="info-label">Services en échec</div>
                <div class="info-value">'$failed_services'</div>
            </div>'
            ;;
        "text"|"txt")
            content="Services actifs (échantillon):
$(systemctl list-units --type=service --state=active --no-pager --no-legend | head -10)

Services en échec:
$(systemctl list-units --failed --no-pager --no-legend)"
            ;;
    esac

    add_section "⚙️ Services Système" "$content"
    SECTIONS_COMPLETED=$((SECTIONS_COMPLETED + 1))
    show_progress $SECTIONS_COMPLETED $TOTAL_SECTIONS
}

# Fonction pour collecter les informations logicielles
collect_software_info() {
    if [ "$INCLUDE_SOFTWARE" = false ]; then
        SECTIONS_COMPLETED=$((SECTIONS_COMPLETED + 1))
        show_progress $SECTIONS_COMPLETED $TOTAL_SECTIONS
        return
    fi

    print_message "PROGRESS" "Collecte des informations logicielles..."

    local content=""
    case $OUTPUT_FORMAT in
        "html")
            content='<h4>📦 Gestionnaires de paquets</h4>
            <div class="info-grid">'

            # APT packages
            local apt_count=$(dpkg -l | grep "^ii" | wc -l 2>/dev/null || echo "0")
            content+='<div class="info-item">
                <div class="info-label">Paquets APT installés</div>
                <div class="info-value">'$apt_count'</div>
            </div>'

            # Snap packages
            local snap_count="0"
            if command -v snap &> /dev/null; then
                snap_count=$(snap list 2>/dev/null | tail -n +2 | wc -l || echo "0")
            fi
            content+='<div class="info-item">
                <div class="info-label">Paquets Snap installés</div>
                <div class="info-value">'$snap_count'</div>
            </div>'

            # Flatpak packages
            local flatpak_count="0"
            if command -v flatpak &> /dev/null; then
                flatpak_count=$(flatpak list 2>/dev/null | wc -l || echo "0")
            fi
            content+='<div class="info-item">
                <div class="info-label">Paquets Flatpak installés</div>
                <div class="info-value">'$flatpak_count'</div>
            </div>'

            content+='</div>

            <h4>🔧 Outils de développement</h4>
            <div class="table-container"><table>
            <tr><th>Outil</th><th>Version</th><th>Chemin</th></tr>'

            # Outils de développement populaires
            local dev_tools=("gcc" "python3" "node" "npm" "git" "docker" "java" "php")

            for tool in "${dev_tools[@]}"; do
                if command -v "$tool" &> /dev/null; then
                    local version="N/A"
                    local path=$(which "$tool")

                    case $tool in
                        "gcc") version=$(gcc --version 2>/dev/null | head -1 | awk '{print $4}') ;;
                        "python3") version=$(python3 --version 2>/dev/null | awk '{print $2}') ;;
                        "node") version=$(node --version 2>/dev/null) ;;
                        "npm") version=$(npm --version 2>/dev/null) ;;
                        "git") version=$(git --version 2>/dev/null | awk '{print $3}') ;;
                        "docker") version=$(docker --version 2>/dev/null | awk '{print $3}' | sed 's/,//') ;;
                        "java") version=$(java -version 2>&1 | head -1 | awk -F'"' '{print $2}') ;;
                        "php") version=$(php --version 2>/dev/null | head -1 | awk '{print $2}') ;;
                    esac

                    content+='<tr>
                        <td>'$tool'</td>
                        <td>'$version'</td>
                        <td>'$path'</td>
                    </tr>'
                fi
            done

            content+='</table></div>'
            ;;
        "text"|"txt")
            local apt_count=$(dpkg -l | grep "^ii" | wc -l 2>/dev/null || echo "0")
            content="Paquets installés:
            - APT: $apt_count paquets"

            if command -v snap &> /dev/null; then
                local snap_count=$(snap list 2>/dev/null | tail -n +2 | wc -l || echo "0")
                content+="\n- Snap: $snap_count paquets"
            fi

            if command -v flatpak &> /dev/null; then
                local flatpak_count=$(flatpak list 2>/dev/null | wc -l || echo "0")
                content+="\n- Flatpak: $flatpak_count paquets"
            fi

            content+="\n\nOutils de développement installés:"
            local dev_tools=("gcc" "python3" "node" "npm" "git" "docker" "java" "php")
            for tool in "${dev_tools[@]}"; do
                if command -v "$tool" &> /dev/null; then
                    local version="N/A"
                    case $tool in
                        "gcc") version=$(gcc --version 2>/dev/null | head -1 | awk '{print $4}') ;;
                        "python3") version=$(python3 --version 2>/dev/null | awk '{print $2}') ;;
                        "node") version=$(node --version 2>/dev/null) ;;
                        "npm") version=$(npm --version 2>/dev/null) ;;
                        "git") version=$(git --version 2>/dev/null | awk '{print $3}') ;;
                        "docker") version=$(docker --version 2>/dev/null | awk '{print $3}' | sed 's/,//') ;;
                        "java") version=$(java -version 2>&1 | head -1 | awk -F'"' '{print $2}') ;;
                        "php") version=$(php --version 2>/dev/null | head -1 | awk '{print $2}') ;;
                    esac
                    content+="\n- $tool: $version"
                fi
            done
            ;;
    esac

    add_section "📦 Logiciels Installés" "$content"
    SECTIONS_COMPLETED=$((SECTIONS_COMPLETED + 1))
    show_progress $SECTIONS_COMPLETED $TOTAL_SECTIONS
}

# Fonction pour collecter les informations de performance
collect_performance_info() {
    if [ "$INCLUDE_PERFORMANCE" = false ]; then
        SECTIONS_COMPLETED=$((SECTIONS_COMPLETED + 1))
        show_progress $SECTIONS_COMPLETED $TOTAL_SECTIONS
        return
    fi

    print_message "PROGRESS" "Collecte des informations de performance..."

    # CPU Usage - arrondi à 1 décimale
    local cpu_usage=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$3+$4+$5)} END {printf "%.1f", usage}')
    [ -z "$cpu_usage" ] && cpu_usage="0.0"

    local load_avg=$(cat /proc/loadavg | cut -d' ' -f1-3)

    # Memory usage
    local mem_info=$(free | grep "Mem:")
    local mem_total=$(echo "$mem_info" | awk '{print $2}')
    local mem_used=$(echo "$mem_info" | awk '{print $3}')
    local mem_percentage=$((mem_used * 100 / mem_total))

    # Disk I/O
    local disk_io="N/A"
    if command -v iostat &> /dev/null; then
        disk_io=$(iostat -d 1 2 | tail -n +4 | tail -1 | awk '{print "R: " $3 " KB/s, W: " $4 " KB/s"}')
    fi

    # Top processes - méthode corrigée
    local top_processes_cpu=""
    local top_processes_mem=""

    local temp_file_cpu=$(mktemp)
    local temp_file_mem=$(mktemp)

    ps aux --sort=-%cpu | head -6 | tail -5 > "$temp_file_cpu"
    ps aux --sort=-%mem | head -6 | tail -5 > "$temp_file_mem"

    local content=""
    case $OUTPUT_FORMAT in
        "html")
            content='<h4>📊 Métriques en temps réel</h4>
            <div class="info-grid">
                <div class="info-item">
                    <div class="info-label">Utilisation CPU</div>
                    <div class="info-value">'$cpu_usage'%</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Charge système (1m, 5m, 15m)</div>
                    <div class="info-value">'$load_avg'</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Utilisation mémoire</div>
                    <div class="info-value">'$mem_percentage'%</div>
                </div>
                <div class="info-item">
                    <div class="info-label">E/S disque</div>
                    <div class="info-value">'$disk_io'</div>
                </div>
            </div>

            <h4>🔥 Top 5 processus (CPU)</h4>
            <div class="table-container"><table>
            <tr><th>Utilisateur</th><th>PID</th><th>CPU%</th><th>MEM%</th><th>Commande</th></tr>'

            while IFS= read -r line; do
                local user=$(echo "$line" | awk '{print $1}')
                local pid=$(echo "$line" | awk '{print $2}')
                local cpu=$(echo "$line" | awk '{print $3}')
                local mem=$(echo "$line" | awk '{print $4}')
                local command=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ $//')

                content+='<tr>
                    <td>'$user'</td>
                    <td>'$pid'</td>
                    <td>'$cpu'%</td>
                    <td>'$mem'%</td>
                    <td>'"${command:0:50}"'</td>
                </tr>'
            done < "$temp_file_cpu"

            content+='</table></div>

            <h4>🧠 Top 5 processus (Mémoire)</h4>
            <div class="table-container"><table>
            <tr><th>Utilisateur</th><th>PID</th><th>CPU%</th><th>MEM%</th><th>Commande</th></tr>'

            while IFS= read -r line; do
                local user=$(echo "$line" | awk '{print $1}')
                local pid=$(echo "$line" | awk '{print $2}')
                local cpu=$(echo "$line" | awk '{print $3}')
                local mem=$(echo "$line" | awk '{print $4}')
                local command=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ $//')

                content+='<tr>
                    <td>'$user'</td>
                    <td>'$pid'</td>
                    <td>'$cpu'%</td>
                    <td>'$mem'%</td>
                    <td>'"${command:0:50}"'</td>
                </tr>'
            done < "$temp_file_mem"

            content+='</table></div>'
            ;;
        "text"|"txt")
            content="Métriques de performance:
- Utilisation CPU: $cpu_usage%
- Charge système: $load_avg
- Utilisation mémoire: $mem_percentage%
- E/S disque: $disk_io

Top 5 processus (CPU):
$(cat "$temp_file_cpu")

Top 5 processus (Mémoire):
$(cat "$temp_file_mem")"
            ;;
    esac

    rm -f "$temp_file_cpu" "$temp_file_mem"

    add_section "⚡ Performances Système" "$content"
    SECTIONS_COMPLETED=$((SECTIONS_COMPLETED + 1))
    show_progress $SECTIONS_COMPLETED $TOTAL_SECTIONS
}

# Fonction pour collecter les informations de sécurité
collect_security_info() {
    print_message "PROGRESS" "Collecte des informations de sécurité..."

    # Firewall status
    local ufw_status="N/A"
    if command -v ufw &> /dev/null; then
        ufw_status=$(sudo ufw status 2>/dev/null | head -1 | awk '{print $2}' || echo "Permission denied")
    fi

    # SSH status
    local ssh_status="N/A"
    if systemctl is-active ssh &> /dev/null || systemctl is-active sshd &> /dev/null; then
        ssh_status="Actif"
    else
        ssh_status="Inactif"
    fi

    # Open ports
    local open_ports="N/A"
    if command -v ss &> /dev/null; then
        open_ports=$(ss -tuln | grep LISTEN | wc -l)
    elif command -v netstat &> /dev/null; then
        open_ports=$(netstat -tuln | grep LISTEN | wc -l)
    fi

    # Failed login attempts - CORRIGÉ
    local failed_logins="0"
    if [ -f "/var/log/auth.log" ]; then
        failed_logins=$(grep "$(date '+%b %d')" /var/log/auth.log 2>/dev/null | grep -c "Failed password" || echo "0")
        failed_logins=$(echo "$failed_logins" | tr -d '\n' | head -1)  # Prendre seulement la première ligne
    fi

    # Updates available - CORRIGÉ
    local updates_available="0"
    local security_updates="0"
    if command -v apt &> /dev/null; then
        updates_available=$(apt list --upgradable 2>/dev/null | grep -c upgradable || echo "0")
        updates_available=$(echo "$updates_available" | tr -d '\n' | head -1)

        security_updates=$(apt list --upgradable 2>/dev/null | grep -ci security || echo "0")
        security_updates=$(echo "$security_updates" | tr -d '\n' | head -1)
    fi

    local content=""
    case $OUTPUT_FORMAT in
        "html")
            content='<div class="info-grid">
                <div class="info-item">
                    <div class="info-label">Statut UFW</div>
                    <div class="info-value">'$ufw_status'</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Service SSH</div>
                    <div class="info-value">'$ssh_status'</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Ports ouverts</div>
                    <div class="info-value">'$open_ports'</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Échecs de connexion (aujourd'\''hui)</div>
                    <div class="info-value">'$failed_logins'</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Mises à jour disponibles</div>
                    <div class="info-value">'$updates_available'</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Mises à jour de sécurité</div>
                    <div class="info-value">'$security_updates'</div>
                </div>
            </div>'
            ;;
        "text"|"txt")
            content="Informations de sécurité:
- Statut UFW: $ufw_status
- Service SSH: $ssh_status
- Ports ouverts: $open_ports
- Échecs de connexion (aujourd'hui): $failed_logins
- Mises à jour disponibles: $updates_available
- Mises à jour de sécurité: $security_updates"
            ;;
    esac

    add_section "🔒 Sécurité" "$content"
    SECTIONS_COMPLETED=$((SECTIONS_COMPLETED + 1))
    show_progress $SECTIONS_COMPLETED $TOTAL_SECTIONS
}

# Fonction pour collecter les informations sur les utilisateurs
collect_users_info() {
    print_message "PROGRESS" "Collecte des informations utilisateurs..."

    # Utilisateurs avec shell
    local users_with_shell=$(grep -E '/bin/(bash|sh|zsh|fish)$' /etc/passwd | cut -d: -f1)
    local total_users=$(echo "$users_with_shell" | wc -l)

    # Utilisateurs connectés
    local logged_users=$(who | wc -l)

    # Dernières connexions
    local temp_last=$(mktemp)
    last -n 5 | head -5 > "$temp_last"

    local content=""
    case $OUTPUT_FORMAT in
        "html")
            content='<h4>👥 Résumé</h4>
            <div class="info-grid">
                <div class="info-item">
                    <div class="info-label">Utilisateurs avec shell</div>
                    <div class="info-value">'$total_users'</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Utilisateurs connectés</div>
                    <div class="info-value">'$logged_users'</div>
                </div>
            </div>

            <h4>🔑 Utilisateurs avec shell</h4>
            <div class="table-container"><table>
            <tr><th>Utilisateur</th><th>UID</th><th>Shell</th><th>Répertoire</th></tr>'

            # Fichier temporaire pour utilisateurs
            local temp_users=$(mktemp)
            echo "$users_with_shell" > "$temp_users"

            while IFS= read -r user; do
                if [ -n "$user" ]; then
                    local user_info=$(getent passwd "$user" 2>/dev/null)
                    if [ -n "$user_info" ]; then
                        local uid=$(echo "$user_info" | cut -d: -f3)
                        local shell=$(echo "$user_info" | cut -d: -f7)
                        local home=$(echo "$user_info" | cut -d: -f6)

                        content+='<tr>
                            <td>'$user'</td>
                            <td>'$uid'</td>
                            <td>'$shell'</td>
                            <td>'$home'</td>
                        </tr>'
                    fi
                fi
            done < "$temp_users"
            rm -f "$temp_users"

            content+='</table></div>

            <h4>📅 Dernières connexions</h4>
            <div class="table-container"><table>
            <tr><th>Utilisateur</th><th>Terminal</th><th>IP/Host</th><th>Date</th></tr>'

            while IFS= read -r line; do
                if [[ "$line" =~ ^[a-zA-Z] ]] && [[ ! "$line" =~ ^wtmp ]]; then
                    local user=$(echo "$line" | awk '{print $1}')
                    local tty=$(echo "$line" | awk '{print $2}')
                    local host=$(echo "$line" | awk '{print $3}')
                    local date=$(echo "$line" | awk '{for(i=4;i<=7;i++) printf "%s ", $i; print ""}' | sed 's/ $//')

                    content+='<tr>
                        <td>'$user'</td>
                        <td>'$tty'</td>
                        <td>'$host'</td>
                        <td>'$date'</td>
                    </tr>'
                fi
            done < "$temp_last"

            content+='</table></div>'
            ;;
        "text"|"txt")
            content="Utilisateurs:
- Avec shell: $total_users
- Connectés: $logged_users

Utilisateurs avec shell:
$users_with_shell

Dernières connexions:
$(cat "$temp_last")"
            ;;
    esac

    rm -f "$temp_last"

    add_section "👤 Utilisateurs" "$content"
    SECTIONS_COMPLETED=$((SECTIONS_COMPLETED + 1))
    show_progress $SECTIONS_COMPLETED $TOTAL_SECTIONS
}

# Fonction pour collecter les logs système
collect_logs_info() {
    if [ "$INCLUDE_LOGS" = false ]; then
        SECTIONS_COMPLETED=$((SECTIONS_COMPLETED + 1))
        show_progress $SECTIONS_COMPLETED $TOTAL_SECTIONS
        return
    fi

    print_message "PROGRESS" "Collecte des informations de logs..."

    # Erreurs récentes dans syslog
    local recent_errors=""
    if [ -f "/var/log/syslog" ]; then
        recent_errors=$(grep "$(date '+%b %d')" /var/log/syslog 2>/dev/null | grep -i error | tail -5)
    fi

    # Taille des logs
    local log_sizes=""
    if [ -d "/var/log" ]; then
        log_sizes=$(du -sh /var/log/* 2>/dev/null | sort -hr | head -10)
    fi

    local content=""
    case $OUTPUT_FORMAT in
        "html")
            content='<h4>📋 Taille des fichiers de log</h4>
            <div class="table-container"><table>
            <tr><th>Fichier</th><th>Taille</th></tr>'

            echo "$log_sizes" | while read line; do
                local size=$(echo "$line" | awk '{print $1}')
                local file=$(echo "$line" | awk '{print $2}')

                content+='<tr>
                    <td>'$(basename "$file")'</td>
                    <td>'$size'</td>
                </tr>'
            done

            content+='</table></div>'

            if [ -n "$recent_errors" ]; then
                content+='<h4>⚠️ Erreurs récentes</h4>
                <div style="background: #f8f8f8; padding: 15px; border-radius: 5px; font-family: monospace; font-size: 0.9em; overflow-x: auto;">'"$recent_errors"'</div>'
            fi
            ;;
        "text"|"txt")
            content="Taille des fichiers de log:
$log_sizes"

            if [ -n "$recent_errors" ]; then
                content+="\n\nErreurs récentes dans syslog:
$recent_errors"
            fi
            ;;
    esac

    add_section "📜 Logs Système" "$content"
    SECTIONS_COMPLETED=$((SECTIONS_COMPLETED + 1))
    show_progress $SECTIONS_COMPLETED $TOTAL_SECTIONS
}

# Fonction pour finaliser le rapport
finalize_report() {
    print_message "PROGRESS" "Finalisation du rapport..."

    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))

    case $OUTPUT_FORMAT in
        "html")
            cat >> "$REPORT_FILE" << EOF
        <div class="footer">
            <p><strong>Rapport généré en ${duration} secondes</strong></p>
            <p>Système: $(uname -sr) | Script: system-report.sh v1.0</p>
            <p>© $(date +%Y) - Rapport système automatisé</p>
        </div>
    </div>
</body>
</html>
EOF
            ;;
        "text"|"txt")
            cat >> "$REPORT_FILE" << EOF

════════════════════════════════════════════════════════════════════════════════
                                   FIN DU RAPPORT
════════════════════════════════════════════════════════════════════════════════

Rapport généré en: ${duration} secondes
Système: $(uname -sr)
Script: system-report.sh v1.0

EOF
            ;;
    esac

    # Compression si demandée
    if [ "$COMPRESS_REPORT" = true ]; then
        local compressed_file="${REPORT_FILE}.gz"
        gzip "$REPORT_FILE"
        REPORT_FILE="$compressed_file"
        print_message "SUCCESS" "Rapport compressé: $compressed_file"
    fi

    SECTIONS_COMPLETED=$((SECTIONS_COMPLETED + 1))
    show_progress $SECTIONS_COMPLETED $TOTAL_SECTIONS
    echo
}

# Fonction d'aide
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Génère un rapport système complet pour Ubuntu/Debian"
    echo
    echo "Options:"
    echo "  -h, --help              Afficher cette aide"
    echo "  -f, --format FORMAT     Format de sortie: html, text, json (défaut: html)"
    echo "  -o, --output DIR        Répertoire de sortie (défaut: /tmp/system_reports)"
    echo "  -n, --name NAME         Nom du rapport (défaut: auto-généré)"
    echo "  -v, --verbose           Mode verbeux"
    echo "  -c, --compress          Compresser le rapport final"
    echo "  --no-performance        Exclure les informations de performance"
    echo "  --no-software           Exclure les informations logicielles"
    echo "  --include-logs          Inclure l'analyse des logs"
    echo
    echo "Exemples:"
    echo "  $0                      # Rapport HTML standard"
    echo "  $0 -f text -c           # Rapport texte compressé"
    echo "  $0 --include-logs -v    # Rapport complet avec logs"
    echo "  $0 -o /home/user/reports # Répertoire personnalisé"
}

# Analyse des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -o|--output)
            REPORT_DIR=$(expand_path "$2")
            shift 2
            ;;
        -n|--name)
            REPORT_NAME=$(expand_path "$2")
            shift 2
            ;;
        -v|--verbose)
            VERBOSE_MODE=true
            shift
            ;;
        -c|--compress)
            COMPRESS_REPORT=true
            shift
            ;;
        --no-performance)
            INCLUDE_PERFORMANCE=false
            TOTAL_SECTIONS=$((TOTAL_SECTIONS - 1))
            shift
            ;;
        --no-software)
            INCLUDE_SOFTWARE=false
            TOTAL_SECTIONS=$((TOTAL_SECTIONS - 1))
            shift
            ;;
        --include-logs)
            INCLUDE_LOGS=true
            shift
            ;;
        *)
            echo "Option inconnue: $1"
            show_help
            exit 1
            ;;
    esac
done

# Fonction principale
main() {
    echo
    print_message "INFO" "🖥️  Génération du rapport système complet"
    print_message "INFO" "Format: $OUTPUT_FORMAT | Répertoire: $REPORT_DIR"
    echo

    # Initialiser le rapport
    init_report

    # Collecter toutes les informations
    collect_system_info
    collect_hardware_info
    collect_storage_info
    collect_network_info
    collect_services_info
    collect_software_info
    collect_performance_info
    collect_security_info
    collect_users_info
    collect_logs_info

    # Finaliser
    finalize_report

    echo
    print_message "SUCCESS" "Rapport généré avec succès!"
    print_message "INFO" "📄 Fichier: $REPORT_FILE"

    # Ouvrir le rapport si format HTML
    if [ "$OUTPUT_FORMAT" = "html" ] && command -v xdg-open &> /dev/null; then
        print_message "INFO" "💡 Voulez-vous ouvrir le rapport? (xdg-open)"
        read -p "Ouvrir maintenant? (o/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[OoYy]$ ]]; then
            xdg-open "$REPORT_FILE" &
        fi
    fi

    # Statistiques finales
    local file_size=$(du -h "$REPORT_FILE" | cut -f1)
    print_message "SUCCESS" "✨ Rapport terminé - Taille: $file_size"
}

# Vérification des dépendances
missing_tools=()
for tool in lscpu free df ip systemctl; do
    if ! command -v "$tool" &> /dev/null; then
        missing_tools+=("$tool")
    fi
done

if [ ${#missing_tools[@]} -gt 0 ]; then
    print_message "WARNING" "Outils manquants: ${missing_tools[*]}"
    print_message "INFO" "Le rapport sera généré avec les informations disponibles"
fi

# Exécution
main
