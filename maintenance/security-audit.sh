#!/bin/bash

# Script d'audit de sécurité basique pour Ubuntu/Debian
# Auteur: NDXDev NDXDev@gmail.com
# Version: 1.0
# Date: 2025-07-18

# Configuration
REPORT_FILE="/tmp/security_audit_$(date +%Y%m%d_%H%M%S).txt"
ENABLE_LOGGING=false
LOG_FILE="/var/log/security-audit.log"
VERBOSE_MODE=false
QUICK_MODE=false

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

# Icônes et indicateurs
CHECK="✅"
WARNING="⚠️"
CRITICAL="🚨"
INFO="ℹ️"
SECURE="🔒"
INSECURE="🔓"

# Compteurs pour le résumé
TOTAL_CHECKS=0
SECURITY_ISSUES=0
WARNINGS=0
CRITICAL_ISSUES=0

# Fonction pour afficher les messages avec couleurs et logging
print_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        "INFO")
            echo -e "${BLUE}${INFO} ${message}${NC}"
            ;;
        "OK")
            echo -e "${GREEN}${CHECK} ${message}${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}${WARNING} ${message}${NC}"
            WARNINGS=$((WARNINGS + 1))
            ;;
        "CRITICAL")
            echo -e "${RED}${CRITICAL} ${message}${NC}"
            CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
            ;;
        "SECURE")
            echo -e "${GREEN}${SECURE} ${message}${NC}"
            ;;
        "INSECURE")
            echo -e "${RED}${INSECURE} ${message}${NC}"
            SECURITY_ISSUES=$((SECURITY_ISSUES + 1))
            ;;
        *)
            echo -e "${message}"
            ;;
    esac

    # Logger dans le fichier si activé
    if [ "$ENABLE_LOGGING" = true ]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null
    fi

    # Ajouter au rapport
    echo "[$timestamp] [$level] $message" >> "$REPORT_FILE"
}

# Fonction pour afficher les en-têtes de section
print_section_header() {
    local title="$1"
    echo
    print_message "" "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    print_message "" "${BOLD}${CYAN}  $title${NC}"
    print_message "" "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
}

# Fonction pour vérifier les ports ouverts
check_open_ports() {
    print_section_header "ANALYSE DES PORTS OUVERTS"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    print_message "INFO" "Analyse des ports TCP ouverts..."

    # Vérifier si netstat est disponible
    if ! command -v netstat &> /dev/null && ! command -v ss &> /dev/null; then
        print_message "WARNING" "netstat et ss non disponibles. Installation recommandée: sudo apt install net-tools"
        return
    fi

    # Utiliser ss si disponible, sinon netstat
    local listen_ports
    if command -v ss &> /dev/null; then
        listen_ports=$(ss -tuln 2>/dev/null)
    else
        listen_ports=$(netstat -tuln 2>/dev/null)
    fi

    # Analyser les ports ouverts
    echo "$listen_ports" | grep LISTEN | while read line; do
        local port=$(echo "$line" | awk '{print $5}' | sed 's/.*://')
        local protocol=$(echo "$line" | awk '{print $1}')

        if [[ "$port" =~ ^[0-9]+$ ]]; then
            # Vérifier les ports suspects
            case $port in
                22) print_message "OK" "Port SSH ($port/$protocol) - Service légitime" ;;
                80|443) print_message "OK" "Port Web ($port/$protocol) - Service légitime" ;;
                21) print_message "WARNING" "Port FTP ($port/$protocol) - Protocole non sécurisé détecté" ;;
                23) print_message "CRITICAL" "Port Telnet ($port/$protocol) - Protocole très dangereux!" ;;
                135|139|445) print_message "WARNING" "Port Windows SMB ($port/$protocol) - Vérifier si nécessaire" ;;
                1433|3306|5432) print_message "INFO" "Port Base de données ($port/$protocol) - Vérifier l'exposition" ;;
                3389) print_message "WARNING" "Port RDP ($port/$protocol) - Accès distant Windows" ;;
                5900) print_message "WARNING" "Port VNC ($port/$protocol) - Accès distant non sécurisé" ;;
                *)
                    if [ "$port" -lt 1024 ]; then
                        print_message "INFO" "Port privilégié ouvert: $port/$protocol"
                    elif [ "$VERBOSE_MODE" = true ]; then
                        print_message "INFO" "Port ouvert: $port/$protocol"
                    fi
                    ;;
            esac
        fi
    done

    # Résumé des ports
    local total_open=$(echo "$listen_ports" | grep -c LISTEN)
    print_message "INFO" "Total des ports en écoute: $total_open"

    # Vérifier les connexions externes
    print_message "INFO" "Vérification des connexions externes actives..."
    local external_connections
    if command -v ss &> /dev/null; then
        external_connections=$(ss -tuln | grep -v "127.0.0.1\|::1\|0.0.0.0" | grep LISTEN | wc -l)
    else
        external_connections=$(netstat -tuln | grep -v "127.0.0.1\|::1\|0.0.0.0" | grep LISTEN | wc -l)
    fi

    if [ "$external_connections" -gt 0 ]; then
        print_message "WARNING" "$external_connections ports accessibles depuis l'extérieur"
    else
        print_message "SECURE" "Aucun port accessible depuis l'extérieur"
    fi
}

# Fonction pour vérifier les permissions de fichiers sensibles
check_file_permissions() {
    print_section_header "VÉRIFICATION DES PERMISSIONS DE FICHIERS"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    # Fichiers critiques à vérifier
    local critical_files=(
        "/etc/passwd:644"
        "/etc/shadow:640"
        "/etc/group:644"
        "/etc/gshadow:640"
        "/etc/sudoers:440"
        "/etc/ssh/sshd_config:644"
        "/root:700"
        "/etc/crontab:644"
    )

    print_message "INFO" "Vérification des permissions des fichiers critiques..."

    for file_perm in "${critical_files[@]}"; do
        local file=$(echo "$file_perm" | cut -d':' -f1)
        local expected_perm=$(echo "$file_perm" | cut -d':' -f2)

        if [ -e "$file" ]; then
            local actual_perm=$(stat -c "%a" "$file" 2>/dev/null)
            if [ "$actual_perm" = "$expected_perm" ]; then
                print_message "SECURE" "$file: permissions correctes ($actual_perm)"
            else
                print_message "WARNING" "$file: permissions incorrectes ($actual_perm, attendu: $expected_perm)"
            fi
        else
            print_message "INFO" "$file: fichier non trouvé (normal sur certains systèmes)"
        fi
    done

    # Vérifier les fichiers world-writable
    print_message "INFO" "Recherche de fichiers modifiables par tous (world-writable)..."
    local world_writable=$(find /etc /usr /bin /sbin -type f -perm -002 2>/dev/null | head -10)

    if [ -n "$world_writable" ]; then
        print_message "CRITICAL" "Fichiers world-writable trouvés dans les répertoires système:"
        echo "$world_writable" | while read file; do
            print_message "CRITICAL" "  $file"
        done
    else
        print_message "SECURE" "Aucun fichier world-writable trouvé dans les répertoires système"
    fi

    # Vérifier les fichiers SUID/SGID suspects
    print_message "INFO" "Vérification des fichiers SUID/SGID..."
    local suid_files=$(find /usr /bin /sbin -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null)
    local suid_count=$(echo "$suid_files" | grep -c .)

    if [ "$suid_count" -gt 20 ]; then
        print_message "WARNING" "Nombre élevé de fichiers SUID/SGID: $suid_count"
    else
        print_message "OK" "Nombre raisonnable de fichiers SUID/SGID: $suid_count"
    fi

    # Fichiers SUID suspects
    local suspicious_suid=("nmap" "tcpdump" "wireshark" "john" "hashcat")
    for tool in "${suspicious_suid[@]}"; do
        if echo "$suid_files" | grep -q "$tool"; then
            print_message "WARNING" "Outil de sécurité avec permissions SUID: $tool"
        fi
    done
}

# Fonction pour analyser les utilisateurs système
check_system_users() {
    print_section_header "ANALYSE DES UTILISATEURS SYSTÈME"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    print_message "INFO" "Analyse des comptes utilisateurs..."

    # Utilisateurs avec UID 0 (root)
    local root_users=$(awk -F: '$3 == 0 {print $1}' /etc/passwd)
    local root_count=$(echo "$root_users" | grep -c .)

    if [ "$root_count" -eq 1 ] && [ "$root_users" = "root" ]; then
        print_message "SECURE" "Un seul compte root détecté"
    else
        print_message "CRITICAL" "Comptes avec privilèges root détectés:"
        echo "$root_users" | while read user; do
            print_message "CRITICAL" "  $user (UID=0)"
        done
    fi

    # Utilisateurs avec shell valide
    local users_with_shell=$(grep -E '/bin/(bash|sh|zsh|fish|dash)$' /etc/passwd | cut -d: -f1)
    print_message "INFO" "Utilisateurs avec shell de connexion:"
    echo "$users_with_shell" | while read user; do
        local last_login=$(last -1 "$user" 2>/dev/null | head -1)
        if echo "$last_login" | grep -q "never logged in"; then
            print_message "INFO" "  $user (jamais connecté)"
        else
            print_message "INFO" "  $user (dernière connexion: $(echo "$last_login" | awk '{print $3, $4, $5}'))"
        fi
    done

    # Comptes avec mots de passe vides
    local empty_passwords=$(awk -F: '$2 == "" {print $1}' /etc/shadow 2>/dev/null)
    if [ -n "$empty_passwords" ]; then
        print_message "CRITICAL" "Comptes sans mot de passe détectés:"
        echo "$empty_passwords" | while read user; do
            print_message "CRITICAL" "  $user"
        done
    else
        print_message "SECURE" "Aucun compte sans mot de passe détecté"
    fi

    # Vérifier les groupes sudo/admin
    print_message "INFO" "Utilisateurs avec privilèges sudo:"
    local sudo_users=$(getent group sudo 2>/dev/null | cut -d: -f4)
    local admin_users=$(getent group admin 2>/dev/null | cut -d: -f4)

    if [ -n "$sudo_users" ]; then
        echo "$sudo_users" | tr ',' '\n' | while read user; do
            [ -n "$user" ] && print_message "INFO" "  $user (groupe sudo)"
        done
    fi

    if [ -n "$admin_users" ]; then
        echo "$admin_users" | tr ',' '\n' | while read user; do
            [ -n "$user" ] && print_message "INFO" "  $user (groupe admin)"
        done
    fi

    # Comptes système suspects
    local system_users=$(awk -F: '$3 < 1000 && $3 > 0 && $7 != "/usr/sbin/nologin" && $7 != "/bin/false" {print $1 ":" $7}' /etc/passwd)
    if [ -n "$system_users" ]; then
        print_message "WARNING" "Comptes système avec shell de connexion:"
        echo "$system_users" | while read user_shell; do
            print_message "WARNING" "  $user_shell"
        done
    fi
}

# Fonction pour vérifier les services suspects
check_suspicious_services() {
    print_section_header "ANALYSE DES SERVICES ACTIFS"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    print_message "INFO" "Vérification des services actifs..."

    # Services suspects connus
    local suspicious_services=(
        "telnet" "ftp" "rsh" "rlogin" "tftp" "finger" "talk" "ntalk"
        "xinetd" "inetd" "portmap" "rpcbind" "ypbind" "ypserv"
    )

    # Vérifier les services systemd
    if command -v systemctl &> /dev/null; then
        local active_services=$(systemctl list-units --type=service --state=active --no-pager --no-legend | awk '{print $1}')

        for service in "${suspicious_services[@]}"; do
            if echo "$active_services" | grep -q "^${service}\.service"; then
                print_message "WARNING" "Service potentiellement dangereux actif: $service"
            fi
        done

        # Services inconnus ou suspects
        local total_services=$(echo "$active_services" | wc -l)
        print_message "INFO" "Total des services actifs: $total_services"

        # Vérifier les services en échec
        local failed_services=$(systemctl list-units --type=service --state=failed --no-pager --no-legend | wc -l)
        if [ "$failed_services" -gt 0 ]; then
            print_message "WARNING" "$failed_services services en échec"
        else
            print_message "OK" "Aucun service en échec"
        fi
    fi

    # Vérifier les processus en cours
    print_message "INFO" "Processus suspects en cours d'exécution..."
    local suspicious_processes=("nc" "netcat" "ncat" "nmap" "tcpdump" "wireshark")

    for process in "${suspicious_processes[@]}"; do
        if pgrep "$process" &>/dev/null; then
            print_message "WARNING" "Processus de sécurité/réseau détecté: $process"
        fi
    done

    # Processus avec privilèges élevés
    local root_processes=$(ps aux | awk '$1 == "root" && $11 !~ /^\[/ {print $11}' | sort | uniq -c | sort -nr | head -10)
    print_message "INFO" "Top 10 des processus root les plus fréquents:"
    echo "$root_processes" | while read count process; do
        print_message "INFO" "  $count × $process"
    done
}

# Fonction pour vérifier la configuration SSH
check_ssh_security() {
    print_section_header "CONFIGURATION SSH"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    if [ ! -f "/etc/ssh/sshd_config" ]; then
        print_message "INFO" "SSH non configuré ou non installé"
        return
    fi

    print_message "INFO" "Analyse de la configuration SSH..."

    # Paramètres SSH à vérifier
    local ssh_config="/etc/ssh/sshd_config"

    # Root login
    local root_login=$(grep "^PermitRootLogin" "$ssh_config" | awk '{print $2}')
    case "$root_login" in
        "no") print_message "SECURE" "Connexion root SSH désactivée" ;;
        "yes") print_message "CRITICAL" "Connexion root SSH autorisée!" ;;
        "prohibit-password") print_message "OK" "Connexion root SSH par clé uniquement" ;;
        *) print_message "WARNING" "Configuration PermitRootLogin non définie explicitement" ;;
    esac

    # Password authentication
    local password_auth=$(grep "^PasswordAuthentication" "$ssh_config" | awk '{print $2}')
    if [ "$password_auth" = "no" ]; then
        print_message "SECURE" "Authentification par mot de passe SSH désactivée"
    else
        print_message "WARNING" "Authentification par mot de passe SSH activée"
    fi

    # Empty passwords
    local empty_passwords=$(grep "^PermitEmptyPasswords" "$ssh_config" | awk '{print $2}')
    if [ "$empty_passwords" = "no" ]; then
        print_message "SECURE" "Mots de passe vides SSH interdits"
    else
        print_message "CRITICAL" "Mots de passe vides SSH autorisés!"
    fi

    # Protocol version
    local protocol=$(grep "^Protocol" "$ssh_config" | awk '{print $2}')
    if [ "$protocol" = "2" ] || [ -z "$protocol" ]; then
        print_message "SECURE" "Protocole SSH v2 utilisé"
    else
        print_message "CRITICAL" "Protocole SSH obsolète détecté: $protocol"
    fi

    # Port SSH
    local ssh_port=$(grep "^Port" "$ssh_config" | awk '{print $2}')
    if [ "$ssh_port" = "22" ] || [ -z "$ssh_port" ]; then
        print_message "WARNING" "Port SSH standard (22) utilisé - changement recommandé"
    else
        print_message "OK" "Port SSH non-standard configuré: $ssh_port"
    fi
}

# Fonction pour vérifier les tâches cron suspectes
check_cron_jobs() {
    print_section_header "TÂCHES CRON ET PLANIFIÉES"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    print_message "INFO" "Vérification des tâches cron..."

    # Crontab système
    if [ -f "/etc/crontab" ]; then
        local cron_entries=$(grep -v "^#\|^$" /etc/crontab | wc -l)
        print_message "INFO" "Tâches dans /etc/crontab: $cron_entries"
    fi

    # Cron directories
    local cron_dirs=("/etc/cron.d" "/etc/cron.daily" "/etc/cron.hourly" "/etc/cron.weekly" "/etc/cron.monthly")

    for dir in "${cron_dirs[@]}"; do
        if [ -d "$dir" ]; then
            local file_count=$(ls -1 "$dir" 2>/dev/null | wc -l)
            print_message "INFO" "Scripts dans $dir: $file_count"

            # Vérifier les permissions
            local world_writable=$(find "$dir" -type f -perm -002 2>/dev/null)
            if [ -n "$world_writable" ]; then
                print_message "CRITICAL" "Scripts cron world-writable dans $dir:"
                echo "$world_writable" | while read file; do
                    print_message "CRITICAL" "  $file"
                done
            fi
        fi
    done

    # Crontabs utilisateurs
    local user_crons=$(cut -d: -f1 /etc/passwd | while read user; do
        if crontab -l -u "$user" 2>/dev/null | grep -q .; then
            echo "$user"
        fi
    done)

    if [ -n "$user_crons" ]; then
        print_message "INFO" "Utilisateurs avec crontab:"
        echo "$user_crons" | while read user; do
            local cron_count=$(crontab -l -u "$user" 2>/dev/null | grep -v "^#\|^$" | wc -l)
            print_message "INFO" "  $user ($cron_count tâches)"
        done
    else
        print_message "INFO" "Aucune crontab utilisateur trouvée"
    fi
}

# Fonction pour vérifier les logs de sécurité
check_security_logs() {
    print_section_header "ANALYSE DES LOGS DE SÉCURITÉ"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    print_message "INFO" "Analyse des tentatives de connexion récentes..."

    # Tentatives de connexion échouées (dernières 24h)
    if [ -f "/var/log/auth.log" ]; then
        local failed_ssh=$(grep "$(date --date='1 day ago' '+%b %d')\|$(date '+%b %d')" /var/log/auth.log 2>/dev/null | grep -c "Failed password")
        if [ "$failed_ssh" -gt 10 ]; then
            print_message "WARNING" "Nombreuses tentatives SSH échouées (24h): $failed_ssh"
        elif [ "$failed_ssh" -gt 0 ]; then
            print_message "INFO" "Tentatives SSH échouées (24h): $failed_ssh"
        else
            print_message "OK" "Aucune tentative SSH échouée récente"
        fi

        # IPs suspectes
        local suspicious_ips=$(grep "$(date '+%b %d')" /var/log/auth.log 2>/dev/null | grep "Failed password" | awk '{print $11}' | sort | uniq -c | sort -nr | head -5)
        if [ -n "$suspicious_ips" ]; then
            print_message "WARNING" "Top 5 des IPs avec échecs SSH aujourd'hui:"
            echo "$suspicious_ips" | while read count ip; do
                print_message "WARNING" "  $ip: $count tentatives"
            done
        fi
    else
        print_message "INFO" "Fichier auth.log non trouvé"
    fi

    # Connexions root réussies
    if [ -f "/var/log/auth.log" ]; then
        local root_logins=$(grep "$(date '+%b %d')" /var/log/auth.log 2>/dev/null | grep -c "Accepted.*root")
        if [ "$root_logins" -gt 0 ]; then
            print_message "WARNING" "Connexions root réussies aujourd'hui: $root_logins"
        else
            print_message "OK" "Aucune connexion root directe aujourd'hui"
        fi
    fi
}

# Fonction pour vérifier les mises à jour de sécurité
check_security_updates() {
    print_section_header "MISES À JOUR DE SÉCURITÉ"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    print_message "INFO" "Vérification des mises à jour de sécurité disponibles..."

    # Mettre à jour la liste des paquets
    if [ "$QUICK_MODE" = false ]; then
        print_message "INFO" "Mise à jour de la liste des paquets..."
        apt update -qq 2>/dev/null
    fi

    # Vérifier les mises à jour de sécurité
    local security_updates=$(apt list --upgradable 2>/dev/null | grep -i security | wc -l)
    local total_updates=$(apt list --upgradable 2>/dev/null | grep -c upgradable)

    if [ "$security_updates" -gt 0 ]; then
        print_message "CRITICAL" "$security_updates mises à jour de sécurité disponibles!"
        print_message "INFO" "Total des mises à jour: $total_updates"
    elif [ "$total_updates" -gt 0 ]; then
        print_message "WARNING" "$total_updates mises à jour disponibles (aucune critique)"
    else
        print_message "SECURE" "Système à jour"
    fi

    # Vérifier la configuration d'auto-update
    if [ -f "/etc/apt/apt.conf.d/20auto-upgrades" ]; then
        local auto_update=$(grep "APT::Periodic::Unattended-Upgrade" /etc/apt/apt.conf.d/20auto-upgrades | grep -o '"[0-9]*"' | tr -d '"')
        if [ "$auto_update" = "1" ]; then
            print_message "SECURE" "Mises à jour automatiques activées"
        else
            print_message "WARNING" "Mises à jour automatiques désactivées"
        fi
    else
        print_message "WARNING" "Configuration auto-update non trouvée"
    fi
}

# Fonction pour générer le résumé final
generate_summary() {
    print_section_header "RÉSUMÉ DE L'AUDIT DE SÉCURITÉ"

    local risk_level="FAIBLE"
    local color=$GREEN

    if [ "$CRITICAL_ISSUES" -gt 0 ]; then
        risk_level="CRITIQUE"
        color=$RED
    elif [ "$SECURITY_ISSUES" -gt 5 ] || [ "$WARNINGS" -gt 10 ]; then
        risk_level="ÉLEVÉ"
        color=$RED
    elif [ "$SECURITY_ISSUES" -gt 2 ] || [ "$WARNINGS" -gt 5 ]; then
        risk_level="MOYEN"
        color=$YELLOW
    fi

    print_message "" "${BOLD}${WHITE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    print_message "" "${BOLD}  AUDIT TERMINÉ: $(date)${NC}"
    print_message "" "${BOLD}${WHITE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    print_message "" "${BOLD}  Contrôles effectués: ${CYAN}$TOTAL_CHECKS${NC}"
    print_message "" "${BOLD}  Problèmes critiques: ${RED}$CRITICAL_ISSUES${NC}"
    print_message "" "${BOLD}  Problèmes de sécurité: ${RED}$SECURITY_ISSUES${NC}"
    print_message "" "${BOLD}  Avertissements: ${YELLOW}$WARNINGS${NC}"
    print_message "" "${BOLD}  Niveau de risque: ${color}$risk_level${NC}"
    print_message "" "${BOLD}${WHITE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    print_message "" "${BOLD}  Rapport sauvegardé: ${CYAN}$REPORT_FILE${NC}"
    print_message "" "${BOLD}${WHITE}═══════════════════════════════════════════════════════════════════════════════${NC}"

    # Recommandations
    if [ "$CRITICAL_ISSUES" -gt 0 ] || [ "$SECURITY_ISSUES" -gt 0 ]; then
        print_message "" ""
        print_message "WARNING" "RECOMMANDATIONS URGENTES:"
        print_message "WARNING" "1. Examinez le rapport détaillé: $REPORT_FILE"
        print_message "WARNING" "2. Corrigez les problèmes critiques immédiatement"
        print_message "WARNING" "3. Effectuez les mises à jour de sécurité"
        print_message "WARNING" "4. Renforcez la configuration SSH"
        print_message "WARNING" "5. Surveillez les logs de sécurité régulièrement"
    fi
}

# Fonction d'aide
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Script d'audit de sécurité basique pour Ubuntu/Debian"
    echo
    echo "Options:"
    echo "  -h, --help        Afficher cette aide"
    echo "  -v, --verbose     Mode verbeux (plus de détails)"
    echo "  -q, --quick       Mode rapide (pas de mise à jour apt)"
    echo "  -l, --log         Activer le logging"
    echo "  -o, --output FILE Fichier de rapport personnalisé"
    echo "  --ports-only      Vérifier uniquement les ports"
    echo "  --files-only      Vérifier uniquement les permissions"
    echo "  --users-only      Vérifier uniquement les utilisateurs"
    echo "  --services-only   Vérifier uniquement les services"
    echo
    echo "Exemples:"
    echo "  $0                # Audit complet"
    echo "  $0 -v -l          # Audit verbeux avec logging"
    echo "  $0 --quick        # Audit rapide"
    echo "  $0 --ports-only   # Vérifier uniquement les ports"
    echo "  $0 -o /tmp/audit.txt # Rapport personnalisé"
}

# Variables pour les options
AUDIT_CATEGORY=""

# Analyse des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE_MODE=true
            shift
            ;;
        -q|--quick)
            QUICK_MODE=true
            shift
            ;;
        -l|--log)
            ENABLE_LOGGING=true
            shift
            ;;
        -o|--output)
            REPORT_FILE="$2"
            shift 2
            ;;
        --ports-only)
            AUDIT_CATEGORY="ports"
            shift
            ;;
        --files-only)
            AUDIT_CATEGORY="files"
            shift
            ;;
        --users-only)
            AUDIT_CATEGORY="users"
            shift
            ;;
        --services-only)
            AUDIT_CATEGORY="services"
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
    # En-tête
    echo
    print_message "" "${BOLD}${MAGENTA}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    print_message "" "${BOLD}${MAGENTA}║                            AUDIT DE SÉCURITÉ SYSTÈME                         ║${NC}"
    print_message "" "${BOLD}${MAGENTA}║                             Ubuntu/Debian Security Audit                     ║${NC}"
    print_message "" "${BOLD}${MAGENTA}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    print_message "" ""
    print_message "INFO" "Début de l'audit: $(date)"
    print_message "INFO" "Hostname: $(hostname)"
    print_message "INFO" "OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")"
    print_message "INFO" "Kernel: $(uname -r)"
    print_message "INFO" "Architecture: $(uname -m)"

    # Logging
    if [ "$ENABLE_LOGGING" = true ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] === DÉBUT AUDIT SÉCURITÉ ===" >> "$LOG_FILE"
        print_message "INFO" "Logging activé: $LOG_FILE"
    fi

    # Initialiser le rapport
    {
        echo "════════════════════════════════════════════════════════════════════════════════"
        echo "                           RAPPORT D'AUDIT DE SÉCURITÉ"
        echo "════════════════════════════════════════════════════════════════════════════════"
        echo "Date: $(date)"
        echo "Hostname: $(hostname)"
        echo "OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")"
        echo "Kernel: $(uname -r)"
        echo "Architecture: $(uname -m)"
        echo "════════════════════════════════════════════════════════════════════════════════"
        echo
    } > "$REPORT_FILE"

    # Vérifications selon la catégorie
    case $AUDIT_CATEGORY in
        "ports")
            check_open_ports
            ;;
        "files")
            check_file_permissions
            ;;
        "users")
            check_system_users
            ;;
        "services")
            check_suspicious_services
            ;;
        *)
            # Audit complet
            check_open_ports
            check_file_permissions
            check_system_users
            check_suspicious_services
            check_ssh_security
            check_cron_jobs
            check_security_logs
            check_security_updates
            ;;
    esac

    # Résumé final
    generate_summary

    # Log de fin
    if [ "$ENABLE_LOGGING" = true ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] === FIN AUDIT (Issues: $SECURITY_ISSUES, Warnings: $WARNINGS, Critical: $CRITICAL_ISSUES) ===" >> "$LOG_FILE"
    fi

    # Recommandations finales
    echo
    print_message "INFO" "Pour améliorer la sécurité:"
    print_message "INFO" "• Consultez le rapport détaillé: $REPORT_FILE"
    print_message "INFO" "• Configurez un firewall (ufw enable)"
    print_message "INFO" "• Activez les mises à jour automatiques"
    print_message "INFO" "• Surveillez les logs régulièrement"
    print_message "INFO" "• Effectuez des audits périodiques"

    # Code de sortie selon le niveau de risque
    if [ "$CRITICAL_ISSUES" -gt 0 ]; then
        exit 2  # Erreur critique
    elif [ "$SECURITY_ISSUES" -gt 0 ]; then
        exit 1  # Avertissement
    else
        exit 0  # OK
    fi
}

# Vérifications préliminaires
if [[ $EUID -eq 0 ]]; then
    print_message "WARNING" "Script exécuté en tant que root. Certaines vérifications peuvent être biaisées."
fi

# Vérifier les dépendances
missing_tools=()
for tool in ss netstat systemctl lsb_release; do
    if ! command -v "$tool" &> /dev/null; then
        missing_tools+=("$tool")
    fi
done

if [ ${#missing_tools[@]} -gt 0 ]; then
    print_message "WARNING" "Outils manquants (fonctionnalités limitées): ${missing_tools[*]}"
    print_message "INFO" "Installation recommandée: sudo apt install net-tools lsb-release"
fi

# Exécution du script principal
main
