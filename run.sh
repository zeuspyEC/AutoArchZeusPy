#!/usr/bin/env bash

# ==============================================================================
# ZeuspyEC Arch Linux Installer
# Version: 3.0.2
# Autor: ZeuspyEC
# GitHub: https://github.com/zeuspyEC
# ==============================================================================

# Habilitar modo estricto
set -euo pipefail
IFS=$'\n\t'

set +e  # No terminar en errores
trap 'error_handler $? $LINENO $BASH_LINENO "$BASH_COMMAND" $(printf "::%s" ${FUNCNAME[@]:-})' ERR

# Colores y estilos mejorados
declare -gr RESET="\033[0m"
declare -gr BOLD="\033[1m"
declare -gr DIM="\033[2m"
declare -gr ITALIC="\033[3m"
declare -gr UNDERLINE="\033[4m"
declare -gr BLINK="\033[5m"
declare -gr REVERSE="\033[7m"
declare -gr HIDDEN="\033[8m"

# Colores normales
declare -gr BLACK="\033[0;30m"
declare -gr RED="\033[0;31m"
declare -gr GREEN="\033[0;32m"
declare -gr YELLOW="\033[0;33m"
declare -gr BLUE="\033[0;34m"
declare -gr PURPLE="\033[0;35m"
declare -gr CYAN="\033[0;36m"
declare -gr WHITE="\033[0;37m"

# Colores brillantes
declare -gr BRIGHT_BLACK="\033[0;90m"
declare -gr BRIGHT_RED="\033[0;91m"
declare -gr BRIGHT_GREEN="\033[0;92m"
declare -gr BRIGHT_YELLOW="\033[0;93m"
declare -gr BRIGHT_BLUE="\033[0;94m"
declare -gr BRIGHT_PURPLE="\033[0;95m"
declare -gr BRIGHT_CYAN="\033[0;96m"
declare -gr BRIGHT_WHITE="\033[0;97m"

# Variables de estilo
declare -gr ERROR="${BOLD}${RED}"
declare -gr SUCCESS="${BOLD}${GREEN}"
declare -gr WARNING="${BOLD}${YELLOW}"
declare -gr INFO="${BOLD}${CYAN}"
declare -gr HEADER="${BOLD}${PURPLE}"
declare -gr ACCENT="${BOLD}${BLUE}"

# Variables globales
declare -g SCRIPT_VERSION="3.0.2"
declare -g BOOT_MODE=""
declare -g TARGET_DISK=""
declare -g HOSTNAME=""
declare -g USERNAME=""
declare -g TIMEZONE=""
declare -g THEME_SELECTED=""

# Archivos de log
declare -g LOG_FILE="/tmp/zeuspyec_installer.log"
declare -g ERROR_LOG="/tmp/zeuspyec_installer_error.log"
declare -g DEBUG_LOG="/tmp/zeuspyec_installer_debug.log"

# Paquetes base requeridos
declare -g BASE_PACKAGES=(
    "base"
    "base-devel"
    "linux"
    "linux-firmware"
    "networkmanager"
    "grub"
    "efibootmgr"
    "sudo"
    "vim"
    "git"
)

# Paquetes para BSPWM
declare -g BSPWM_PACKAGES=(
    "bspwm"
    "sxhkd"
    "polybar"
    "picom"
    "nitrogen"
    "rofi"
    "alacritty"
    "dunst"
    "brightnessctl"
    "network-manager-applet"
    "pulseaudio"
    "pavucontrol"
    "firefox"
    "thunar"
    "lxappearance"
    "neofetch"
)

display_banner() {
    clear
    echo -e "${BLUE}"
    cat << "EOF" 
 ▒███████▒▓█████  █    ██   ██████  ██▓███   ▓██   ██▓▓█████  ▄████▄  
▒ ▒ ▒ ▄▀░▓█   ▀  ██  ▓██▒▒██    ▒ ▓██░  ██▒  ▒██  ██▒▓█   ▀ ▒██▀ ▀█  
░ ▒ ▄▀▒░ ▒███   ▓██  ▒██░░ ▓██▄   ▓██░ ██▓▒   ▒██ ██░▒███   ▒▓█    ▄ 
  ▄▀▒   ░▒▓█  ▄ ▓▓█  ░██░  ▒   ██▒▒██▄█▓▒ ▒   ░ ▐██▓░▒▓█  ▄ ▒▓▓▄ ▄██▒
▒███████▒░▒████▒▒▒█████▓ ▒██████▒▒▒██▒ ░  ░   ░ ██▒▓░░▒████▒▒ ▓███▀ ░
░▒▒ ▓░▒░▒░░ ▒░ ░░▒▓▒ ▒ ▒ ▒ ▒▓▒ ▒ ░▒▓▒░ ░  ░    ██▒▒▒ ░░ ▒░ ░░ ░▒ ▒  ░
░░▒ ▒ ░ ▒ ░ ░  ░░░▒░ ░ ░ ░ ░▒  ░ ░░▒ ░      ▓██ ░▒░  ░ ░  ░  ░  ▒   
░ ░ ░ ░ ░   ░    ░░░ ░ ░ ░  ░  ░  ░░        ▒ ▒ ░░     ░   ░        
  ░ ░       ░  ░   ░           ░            ░ ░        ░  ░ ░      
░                                           ░ ░                     
EOF
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${PURPLE}      Arch Linux Installer ${BRIGHT_CYAN}v${SCRIPT_VERSION}${RESET}"
    echo -e "${BRIGHT_BLUE}      https://github.com/zeuspyEC${RESET}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${RESET}\n"
sleep 3
}
show_main_menu() {
    clear
    display_banner
    
    echo -e "\n${CYAN}Seleccione el tipo de instalación:${RESET}\n"
    echo -e "  ${CYAN}1)${RESET} ${GREEN}Instalación guiada${RESET}"
    echo -e "  ${CYAN}2)${RESET} ${YELLOW}Instalación automática${RESET}"
    echo -e "  ${CYAN}3)${RESET} ${RED}Salir${RESET}\n"
    
    echo -ne "${YELLOW}Ingrese su elección (1-3):${RESET} "
    read -r choice
    
    case $choice in
    1)
        guided_installation
        ;;
    2)
        automatic_installation
        ;;
    3)
        log "INFO" "Instalación cancelada por el usuario"
        exit 0
        ;;
    *)
        echo -e "\n${RED}Opción inválida${RESET}"
        sleep 2
        show_main_menu
        ;;
esac
}
    automatic_installation() {
    # Detectar automáticamente el sistema operativo existente
    detect_existing_os

    # Detectar automáticamente el modo de arranque (BIOS o UEFI)
    if [[ -d "/sys/firmware/efi/efivars" ]]; then
        BOOT_MODE="UEFI"
    else
        BOOT_MODE="BIOS"
    fi

    # Seleccionar automáticamente un disco compatible sin archivos de Windows
    select_compatible_disk
}

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local function_name="${FUNCNAME[1]:-main}"
    local line_number="${BASH_LINENO[0]}"
    
    # Sanitizar mensaje
    message=$(echo "$message" | tr -cd '[:print:]\n')
    
    # Formato de log
    local log_entry="[$timestamp] [$level] [$function_name:$line_number] $message"
    
    case "$level" in
        "DEBUG")
            echo -e "${CYAN}$log_entry${RESET}" >> "$DEBUG_LOG"
            ;;
        "INFO")
            echo -e "${GREEN}$log_entry${RESET}" | tee -a "$LOG_FILE"
            ;;
        "SUCCESS")
            echo -e "${BRIGHT_GREEN}✔ $log_entry${RESET}" | tee -a "$LOG_FILE"
            ;;
        "WARN")
            echo -e "${YELLOW}⚠ $log_entry${RESET}" | tee -a "$LOG_FILE"
            ;;
        "ERROR")
            echo -e "${RED}✘ $log_entry${RESET}" | tee -a "$ERROR_LOG"
            print_system_info >> "$ERROR_LOG"
            ;;
    esac
}

# Función para mostrar progreso
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r${CYAN}[${BRIGHT_BLUE}"
    printf "%${filled}s" '' | tr ' ' '█'
    printf "${DIM}"
    printf "%${empty}s" '' | tr ' ' '░'
    printf "${RESET}${CYAN}]${RESET} ${BRIGHT_WHITE}%3d%%${RESET}" "$percent"
}

# Función para imprimir información del sistema
print_system_info() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════╗${RESET}"
    echo -e "${PURPLE}║      Información del Sistema         ║${RESET}"
    echo -e "${PURPLE}╚══════════════════════════════════════╝${RESET}\n"
    
    # Kernel
    printf "${WHITE}%-12s${RESET} : %s\n" "Kernel" "$(uname -r)"
    
    # CPU
    local cpu_info
    cpu_info=$(grep "model name" /proc/cpuinfo | head -n1 | cut -d: -f2 | xargs)
    printf "${WHITE}%-12s${RESET} : %s\n" "CPU" "$cpu_info"
    
    # Memoria
    echo -e "\n${WHITE}Memoria:${RESET}"
    free -h | awk '
        NR==1 {printf "%-12s %-10s %-10s %-10s %-10s\n", $1, $2, $3, $4, $7}
        NR==2 {printf "%-12s %-10s %-10s %-10s %-10s\n", $1":", $2, $3, $4, $7}
    ' | sed 's/^/  /'
    
    # Disco
    echo -e "\n${WHITE}Disco:${RESET}"
    df -h | grep -E '^/dev|^Filesystem' | \
        awk '{printf "  %-20s %-10s %-10s %-10s %-10s %s\n", $1, $2, $3, $4, $5, $6}'
    
    # Red
    echo -e "\n${WHITE}Red:${RESET}"
    ip -br addr | awk '{printf "  %-10s %-15s %s\n", $1, $2, $3}'

    sleep 4
}

# Función para ejecutar comandos con logging
execute_with_log() {
    clear
    local command=("$@")
    local function_name="${FUNCNAME[1]:-main}"
    
    log "DEBUG" "Ejecutando: ${command[*]}"
    
    if output=$("${command[@]}" 2>&1); then
        log "SUCCESS" "Comando exitoso: ${command[*]}"
        log "DEBUG" "Salida: $output"
        echo "$output"
        return 0
    else
        local exit_code=$?
        log "ERROR" "Comando falló ($exit_code): ${command[*]}"
        log "ERROR" "Salida: $output"
        return $exit_code
    fi
    sleep 2
}

# Función de inicialización
init_script() {
    # Crear archivos de log
    : > "$LOG_FILE"
    : > "$ERROR_LOG"
    : > "$DEBUG_LOG"
    
    # Mostrar banner
    display_banner
    
    # Verificar root
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "Este script debe ejecutarse como root"
        exit 1
    fi
    
    # Mostrar información del sistema
    print_system_info
    
    # Verificar dependencias
    check_dependencies
    
    log "INFO" "Inicialización completada"
}

# ==============================================================================
# Funciones de Verificación del Sistema y Red
# ==============================================================================

check_dependencies() {
    clear
    log "INFO" "Verificando dependencias del sistema"
    
    local deps=(
        "parted"
        "mkfs.fat"
        "mkfs.ext4"
        "arch-chroot"
        "iwctl"
        "ping"
        "reflector"
        "git"
        "curl"
        "wget"
    )
    
    local missing_deps=()
    local install_attempts=0
    local max_attempts=3
    
    while ((install_attempts < max_attempts)); do
        missing_deps=()
        
        # Verificar cada dependencia
        for dep in "${deps[@]}"; do
            echo -ne "${CYAN}Verificando $dep... ${RESET}"
            if ! command -v "$dep" >/dev/null 2>&1; then
                echo -e "${YELLOW}➜ Faltante${RESET}"
                missing_deps+=("$dep")
            else
                echo -e "${GREEN}✔${RESET}"
            fi
        done
        
        # Si no hay dependencias faltantes, salir del bucle
        if ((${#missing_deps[@]} == 0)); then
            log "SUCCESS" "Todas las dependencias están instaladas"
            return 0
        fi
        
        # Intentar instalar dependencias faltantes
        echo -e "\n${YELLOW}Instalando dependencias faltantes...${RESET}"
        
        # Mapeo de comandos a paquetes
        declare -A pkg_map=(
            ["mkfs.fat"]="dosfstools"
            ["mkfs.ext4"]="e2fsprogs"
            ["arch-chroot"]="arch-install-scripts"
            ["iwctl"]="iwd"
        )
        
        # Actualizar base de datos de pacman
        pacman -Sy --noconfirm
        
        for dep in "${missing_deps[@]}"; do
            local pkg="${pkg_map[$dep]:-$dep}"
            echo -ne "${CYAN}Instalando $pkg... ${RESET}"
            if pacman -S --noconfirm "$pkg"; then
                echo -e "${GREEN}✔${RESET}"
            else
                echo -e "${RED}✘${RESET}"
            fi
        done
        
        ((install_attempts++))
        
        if ((install_attempts < max_attempts)); then
            echo -e "\n${YELLOW}Reintentando verificación de dependencias...${RESET}"
            sleep 2
        fi
    done
    
    # Si llegamos aquí, no se pudieron instalar todas las dependencias
    if ((${#missing_deps[@]} > 0)); then
        echo -e "\n${RED}No se pudieron instalar las siguientes dependencias:${RESET}"
        printf '%s\n' "${missing_deps[@]}" | sed 's/^/  • /'
        
        echo -e "\n${YELLOW}¿Desea continuar de todos modos? (s/N):${RESET} "
        read -r response
        if [[ "$response" =~ ^[Ss]$ ]]; then
            log "WARN" "Continuando sin todas las dependencias"
            return 0
        else
            log "ERROR" "Instalación cancelada por dependencias faltantes"
            return 1
        fi
    fi
    
    return 0

    sleep 3
}

install_package() {
    clear
    local package="$1"
    local max_attempts=3
    local attempt=0
    
    while ((attempt < max_attempts)); do
        echo -ne "${CYAN}Instalando $package... ${RESET}"
        if pacman -S --noconfirm "$package" &>/dev/null; then
            echo -e "${GREEN}✔${RESET}"
            return 0
        else
            echo -e "${RED}✘${RESET}"
            ((attempt++))
            
            if ((attempt < max_attempts)); then
                echo -e "${YELLOW}Reintentando ($attempt/$max_attempts)...${RESET}"
                sleep 2
            fi
        fi
    done
    
    echo -e "${YELLOW}¿Desea continuar sin $package? (s/N):${RESET} "
    read -r response
    [[ "$response" =~ ^[Ss]$ ]] && return 0 || return 1

    sleep 3
}

check_system_requirements() {
    clear
    log "INFO" "Verificando requisitos del sistema"
    
    # Detectar si es VM o sistema físico
    local virt_type
    virt_type=$(systemd-detect-virt 2>/dev/null || echo "physical")
    
    # Ajustar requisitos según el tipo de sistema
    local min_ram
    local min_disk
    
    if [ "$virt_type" = "physical" ]; then
        min_ram=2048  # 2GB para sistemas físicos
        min_disk=20   # 20GB para sistemas físicos
        log "INFO" "Detectado sistema físico"
    else
        min_ram=512   # 512MB para VMs  
        min_disk=15   # 15GB para VMs
        log "INFO" "Detectado sistema virtual: $virt_type"
    fi
    
    # Verificar arquitectura
    echo -e "\n${CYAN}╔══════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║      Verificación del Sistema         ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${RESET}\n"
    
    local arch
    arch=$(uname -m)
    echo -ne "${WHITE}Arquitectura:${RESET} "
    if [[ "$arch" != "x86_64" ]]; then
        echo -e "${RED}✘ No soportada ($arch)${RESET}"
        return 1
    fi
    echo -e "${GREEN}✔ x86_64${RESET}"
    
    # Verificar modo de arranque
    echo -ne "${WHITE}Modo de arranque:${RESET} "
    if [[ -d "/sys/firmware/efi/efivars" ]]; then
        BOOT_MODE="UEFI"
        echo -e "${GREEN}✔ UEFI${RESET}"
    else
        BOOT_MODE="BIOS"
        echo -e "${YELLOW}➜ BIOS Legacy${RESET}"
    fi
    
    # Verificar memoria
    echo -ne "${WHITE}Memoria RAM:${RESET} "
    local total_ram
    total_ram=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    
    if ((total_ram < min_ram)); then
        echo -e "${RED}✘ Insuficiente (${total_ram}MB < ${min_ram}MB)${RESET}"
        return 1
    fi
    echo -e "${GREEN}✔ ${total_ram}MB${RESET}"
    
    # Verificar espacio en disco
    verify_disk_space "$min_disk"
    
    log "SUCCESS" "Sistema cumple con los requisitos mínimos"
    return 0

    sleep 3
}

verify_disk_space() {
    clear
    local min_disk=$1
    echo -ne "${WHITE}Espacio en disco:${RESET} "
    
    local total_space
    total_space=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
    
    if ((total_space < min_disk)); then
        echo -e "${RED}✘ Insuficiente (${total_space}GB < ${min_disk}GB)${RESET}"
        return 1
    fi
    echo -e "${GREEN}✔ ${total_space}GB${RESET}"
    return 0
    sleep 2
}

configure_mirrorlist() {
    clear
    log "INFO" "Configurando mirrors optimizados"
    
    # Backup del mirrorlist actual
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
    
    echo -e "${CYAN}Actualizando lista de mirrors...${RESET}"
    
    # Escribir nuevo mirrorlist personalizado
    cat > /etc/pacman.d/mirrorlist << 'EOF'
################################################################################
# Arch Linux mirrorlist optimizado por ZeuspyEC
################################################################################
Server = https://mirror.osbeck.com/archlinux/$repo/os/$arch
Server = https://de.arch.mirror.kescher.at/$repo/os/$arch
Server = https://arch.mirror.constant.com/$repo/os/$arch
Server = https://archlinux.thaller.ws/$repo/os/$arch
Server = https://phinau.de/arch/$repo/os/$arch
Server = https://mirror.cyberbits.asia/archlinux/$repo/os/$arch
Server = https://mirror.pseudoform.org/$repo/os/$arch
Server = https://mirror.pkgbuild.com/$repo/os/$arch
Server = https://archlinux.uk.mirror.allworldit.com/archlinux/$repo/os/$arch
Server = https://america.mirror.pkgbuild.com/$repo/os/$arch
Server = https://mirror.theash.xyz/arch/$repo/os/$arch
Server = https://mirror.telepoint.bg/archlinux/$repo/os/$arch
Server = https://archlinux.mailtunnel.eu/$repo/os/$arch
Server = https://mirror.f4st.host/archlinux/$repo/os/$arch
Server = https://mirror.lty.me/archlinux/$repo/os/$arch
Server = https://mirror.chaoticum.net/arch/$repo/os/$arch
Server = https://archmirror.it/repos/$repo/os/$arch
Server = https://ftp.halifax.rwth-aachen.de/archlinux/$repo/os/$arch
Server = https://arch.jensgutermuth.de/$repo/os/$arch
Server = https://pkg.adfinis.com/archlinux/$repo/os/$arch
EOF
    
    log "SUCCESS" "Mirrors configurados exitosamente"
}

check_network_connectivity() {
    log "INFO" "Verificando conectividad de red"
    
    echo -e "\n${CYAN}╔══════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║      Verificación de Red              ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${RESET}\n"
    
    # Comprobar interfaces de red
    echo -ne "${WHITE}Interfaces de red:${RESET} "
    if ! ip link show &>/dev/null; then
        echo -e "${RED}✘ No detectadas${RESET}"
        return 1
    fi
    echo -e "${GREEN}✔ Detectadas${RESET}"
    
    local test_hosts=("archlinux.org" "google.com" "cloudflare.com")
    local connected=false
    
    echo -e "\n${WHITE}Probando conectividad:${RESET}"
    
    for host in "${test_hosts[@]}"; do
        echo -ne "  • $host... "
        if ping -c 1 -W 5 "$host" &>/dev/null; then
            echo -e "${GREEN}✔${RESET}"
            connected=true
            break
        else
            echo -e "${RED}✘${RESET}"
        fi
    done
    
    if ! $connected; then
        log "WARN" "Sin conexión a Internet. Intentando configurar..."
        setup_network_connection
        return $?
    fi
    
    log "SUCCESS" "Conectividad de red verificada"
    return 0

    sleep 3
}

setup_network_connection() {
    clear
    log "INFO" "Configurando conexión de red"
    
    echo -e "\n${CYAN}╔══════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║      Configuración de Red             ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${RESET}\n"
    
    PS3=$'\n'"${YELLOW}Seleccione tipo de conexión (1-3):${RESET} "
    select connection_type in "WiFi" "Ethernet" "Cancelar"; do
        case $connection_type in
            "WiFi")
                setup_wifi_connection
                break
                ;;
            "Ethernet")
                setup_ethernet_connection
                break
                ;;
            "Cancelar")
                return 1
                ;;
            *)
                echo -e "${RED}Opción inválida${RESET}"
                ;;
        esac
    done
}

setup_wifi_connection() {
    log "INFO" "Configurando conexión WiFi"
    
    # Verificar soporte wifi
    if ! command -v iwctl &>/dev/null; then
        log "ERROR" "iwd no está instalado"
        return 1
    fi
    
    # Obtener interfaces wireless
    local wireless_interfaces
    wireless_interfaces=($(iwctl device list 2>/dev/null | grep -oE "wlan[0-9]"))
    
    if ((${#wireless_interfaces[@]} == 0)); then
        log "ERROR" "No se detectaron interfaces wireless"
        return 1
    fi
    
    # Mostrar interfaces disponibles
    echo -e "\n${WHITE}Interfaces WiFi disponibles:${RESET}"
    local i=1
    for interface in "${wireless_interfaces[@]}"; do
        echo -e "  ${CYAN}$i)${RESET} $interface"
        ((i++))
    done
    
    echo -ne "\n${YELLOW}Seleccione interfaz (1-${#wireless_interfaces[@]}):${RESET} "
    read -r interface_number
    
    if ! [[ "$interface_number" =~ ^[0-9]+$ ]] || \
       ((interface_number < 1 || interface_number > ${#wireless_interfaces[@]})); then
        log "ERROR" "Selección inválida"
        return 1
    fi
    
    local selected_interface=${wireless_interfaces[$((interface_number-1))]}
    
    # Escanear redes
    echo -e "\n${CYAN}Escaneando redes disponibles...${RESET}"
    iwctl station "$selected_interface" scan
    sleep 2
    
    # Mostrar redes
    echo -e "\n${WHITE}Redes disponibles:${RESET}"
    iwctl station "$selected_interface" get-networks
    
    # Solicitar datos de conexión
    echo -ne "\n${YELLOW}SSID de la red:${RESET} "
    read -r ssid
    
    echo -ne "${YELLOW}Contraseña:${RESET} "
    read -rs password
    echo
    
    # Intentar conexión
    echo -e "\n${CYAN}Conectando a $ssid...${RESET}"
    
    if iwctl station "$selected_interface" connect "$ssid" --passphrase "$password"; then
        sleep 3
        if ping -c 1 archlinux.org &>/dev/null; then
            log "SUCCESS" "Conexión WiFi establecida"
            return 0
        fi
    fi
    
    log "ERROR" "No se pudo establecer la conexión WiFi"
    return 1

    sleep 3
}

setup_ethernet_connection() {
    clear
    log "INFO" "Configurando conexión Ethernet"
    
    local ethernet_interfaces
    ethernet_interfaces=($(ip link show | grep -E "^[0-9]+: en|^[0-9]+: eth" | cut -d: -f2))
    
    if ((${#ethernet_interfaces[@]} == 0)); then
        log "ERROR" "No se detectaron interfaces Ethernet"
        return 1
    fi
    
    echo -e "\n${WHITE}Configurando interfaces Ethernet:${RESET}"
    
    for interface in "${ethernet_interfaces[@]}"; do
        interface=$(echo "$interface" | tr -d ' ')
        echo -ne "  • $interface... "
        
        ip link set "$interface" up
        if dhcpcd "$interface" &>/dev/null; then
            sleep 3
            if ping -c 1 archlinux.org &>/dev/null; then
                echo -e "${GREEN}✔${RESET}"
                log "SUCCESS" "Conexión Ethernet establecida en $interface"
                return 0
            fi
        fi
        echo -e "${RED}✘${RESET}"
    done
    
    log "ERROR" "No se pudo establecer conexión Ethernet"
    return 1
    sleep 3
}

# ==============================================================================
# Funciones de Particionamiento y Formateo
# ==============================================================================
repair_mount_points() {
    clear
    local root_part="$1"
    local boot_part="$2"
    
    log "INFO" "Intentando reparar puntos de montaje"
    
    # Desmontar todo primero
    umount -R /mnt 2>/dev/null
    
    # Recrear estructura de directorios
    rm -rf /mnt/*
    mkdir -p /mnt
    
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        mkdir -p /mnt/boot/efi
    else
        mkdir -p /mnt/boot
    fi
    
    # Intentar montar de nuevo
    if ! mount "$root_part" /mnt; then
        log "ERROR" "No se pudo montar ROOT en /mnt"
        return 1
    fi
    
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        if ! mount "$boot_part" /mnt/boot/efi; then
            log "ERROR" "No se pudo montar EFI en /mnt/boot/efi"
            return 1
        fi
    else
        if ! mount "$boot_part" /mnt/boot; then
            log "ERROR" "No se pudo montar BOOT en /mnt/boot"
            return 1
        fi
    fi
    
    return 0
    sleep 3
}

prepare_disk() {
    clear
    log "INFO" "Iniciando preparación del disco"
    
    # Verificar si hay sistemas operativos instalados
    detect_existing_os
    
    # Listar discos disponibles
    local available_disks
    mapfile -t available_disks < <(lsblk -dpno NAME,SIZE,MODEL | grep -E "^/dev/(sd|nvme|vd)")
    
    if [[ ${#available_disks[@]} -eq 0 ]]; then
        log "ERROR" "No se encontraron discos disponibles"
        return 1
    fi
    
    echo -e "\n${CYAN}╔════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║         Discos Disponibles             ║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${RESET}\n"
    
    # Mostrar discos con información detallada
    local i=1
    for disk in "${available_disks[@]}"; do
        echo -e "${CYAN}$i)${RESET} $disk"
        ((i++))
    done
    
    # Seleccionar disco
    while true; do
        echo -ne "\n${YELLOW}Seleccione el disco para la instalación (1-${#available_disks[@]}):${RESET} "
        read -r disk_number
        
        if [[ $disk_number =~ ^[0-9]+$ ]] && ((disk_number > 0 && disk_number <= ${#available_disks[@]})); then
            TARGET_DISK=$(echo "${available_disks[$((disk_number-1))]}" | cut -d' ' -f1)
            break
        fi
        echo -e "${RED}Selección inválida${RESET}"
    done
    
    # Verificar si el disco está en uso
    if is_disk_mounted "$TARGET_DISK"; then
        log "WARN" "El disco $TARGET_DISK tiene particiones montadas"
        echo -e "${YELLOW}¿Desea intentar desmontar las particiones? (s/N):${RESET} "
        read -r response
        if [[ "$response" =~ ^[Ss]$ ]]; then
            unmount_all "$TARGET_DISK"
        else
            return 1
        fi
    fi
    
    # Seleccionar esquema de particionamiento
    local partition_scheme
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        partition_scheme="gpt"
        echo -e "\n${CYAN}Modo UEFI detectado - usando esquema GPT${RESET}"
    else
        echo -e "\n${YELLOW}Seleccione esquema de particionamiento:${RESET}"
        select scheme in "MBR (BIOS Legacy)" "GPT (Avanzado)" "Cancelar"; do
            case $scheme in
                "MBR (BIOS Legacy)")
                    partition_scheme="mbr"
                    break
                    ;;
                "GPT (Avanzado)")
                    partition_scheme="gpt"
                    break
                    ;;
                "Cancelar")
                    return 1
                    ;;
            esac
        done
    fi
    
    # Mostrar advertencia
    show_warning_message || return 1
    
    # Crear esquema de partición
    if [[ "$partition_scheme" == "gpt" ]]; then
        create_gpt_partitions
    else
        create_mbr_partitions
    fi
    
    # Verificar particiones y puntos de montaje
    if ! verify_partitions; then
        log "WARN" "Problemas con los puntos de montaje, intentando reparar..."
        if ! repair_mount_points "$root_part" "$boot_part"; then
            log "ERROR" "No se pudieron reparar los puntos de montaje"
            return 1
        fi
    fi
    
    return 0

    sleepm 4
}

show_warning_message() {
    clear
    echo -e "\n${RED}╔═══════════════════════════ ADVERTENCIA ═══════════════════════════╗${RESET}"
    echo -e "${RED}║  ¡ATENCIÓN! Se borrarán TODOS los datos en el disco seleccionado  ║${RESET}"
    echo -e "${RED}║  Esta operación no se puede deshacer                              ║${RESET}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════════╝${RESET}"
    
    echo -ne "\n${YELLOW}¿Está seguro que desea continuar? (s/N):${RESET} "
    read -r response
    [[ "$response" =~ ^[Ss]$ ]] && return 0 || return 1

    sleep 2
}

# Función para crear particiones GPT
create_gpt_partitions() {
    clear
    log "INFO" "Creando particiones GPT"
    
    # Calcular tamaños
    local disk_size
    disk_size=$(blockdev --getsize64 "$TARGET_DISK" | awk '{print int($1/1024/1024)}')  # MB
    local efi_size=512
    local swap_size
    swap_size=$(free -m | awk '/^Mem:/ {print int($2)}')
    local root_size=$((disk_size - efi_size - swap_size))
    
    # Crear tabla GPT
    if ! retry_command parted -s "$TARGET_DISK" mklabel gpt; then
        log "ERROR" "Fallo al crear tabla GPT"
        return 1
    fi
    
    echo -e "\n${CYAN}Creando particiones...${RESET}"
    
    # Crear particiones con retry
    retry_command parted -s "$TARGET_DISK" \
        mkpart "EFI" fat32 1MiB "${efi_size}MiB" \
        set 1 esp on \
        mkpart "ROOT" ext4 "${efi_size}MiB" "$((efi_size + root_size))MiB" \
        mkpart "SWAP" linux-swap "$((efi_size + root_size))MiB" 100%
    
    sleep 2  # Esperar a que el kernel detecte las nuevas particiones
    
    # Formatear particiones
    local efi_part="${TARGET_DISK}1"
    local root_part="${TARGET_DISK}2"
    local swap_part="${TARGET_DISK}3"
    
    echo -e "${CYAN}Formateando particiones...${RESET}"
    
    # Formatear EFI
    echo -ne "  EFI (${efi_part})... "
    if retry_command mkfs.fat -F32 "$efi_part"; then
        echo -e "${GREEN}✔${RESET}"
    else
        echo -e "${RED}✘${RESET}"
        return 1
    fi
    
    # Formatear ROOT
    echo -ne "  ROOT (${root_part})... "
    if retry_command mkfs.ext4 -F "$root_part"; then
        echo -e "${GREEN}✔${RESET}"
    else
        echo -e "${RED}✘${RESET}"
        return 1
    fi
    
    # Formatear SWAP
    echo -ne "  SWAP (${swap_part})... "
    if retry_command mkswap "$swap_part" && retry_command swapon "$swap_part"; then
        echo -e "${GREEN}✔${RESET}"
    else
        echo -e "${RED}✘${RESET}"
        return 1
    fi
    
    # Montar particiones
    mount_partitions "$root_part" "$efi_part" || return 1
    
    return 0

    sleep 3
}

# Función para crear particiones MBR
create_mbr_partitions() {
    clear
    log "INFO" "Creando particiones MBR"
    
    # Calcular tamaños
    local disk_size
    disk_size=$(blockdev --getsize64 "$TARGET_DISK" | awk '{print int($1/1024/1024)}')  # MB
    local boot_size=512
    local swap_size
    swap_size=$(free -m | awk '/^Mem:/ {print int($2)}')
    local root_size=$((disk_size - boot_size - swap_size))
    
    # Crear tabla MBR
    if ! retry_command parted -s "$TARGET_DISK" mklabel msdos; then
        log "ERROR" "Fallo al crear tabla MBR"
        return 1
    fi
    
    echo -e "\n${CYAN}Creando particiones...${RESET}"
    
    # Crear particiones con retry
    retry_command parted -s "$TARGET_DISK" \
        mkpart primary ext4 1MiB "${boot_size}MiB" \
        set 1 boot on \
        mkpart primary ext4 "${boot_size}MiB" "$((boot_size + root_size))MiB" \
        mkpart primary linux-swap "$((boot_size + root_size))MiB" 100%
    
    sleep 2  # Esperar a que el kernel detecte las nuevas particiones
    
    # Formatear particiones
    local boot_part="${TARGET_DISK}1"
    local root_part="${TARGET_DISK}2"
    local swap_part="${TARGET_DISK}3"
    
    echo -e "${CYAN}Formateando particiones...${RESET}"
    
    # Formatear BOOT
    echo -ne "  BOOT (${boot_part})... "
    if retry_command mkfs.ext4 -F "$boot_part"; then
        echo -e "${GREEN}✔${RESET}"
    else
        echo -e "${RED}✘${RESET}"
        return 1
    fi
    
    # Formatear ROOT
    echo -ne "  ROOT (${root_part})... "
    if retry_command mkfs.ext4 -F "$root_part"; then
        echo -e "${GREEN}✔${RESET}"
    else
        echo -e "${RED}✘${RESET}"
        return 1
    fi
    
    # Formatear SWAP
    echo -ne "  SWAP (${swap_part})... "
    if retry_command mkswap "$swap_part" && retry_command swapon "$swap_part"; then
        echo -e "${GREEN}✔${RESET}"
    else
        echo -e "${RED}✘${RESET}"
        return 1
    fi
    
    # Montar particiones
    mount_partitions "$root_part" "$boot_part" || return 1
    
    return 0
    sleep 4
}

# Función para montar particiones de forma segura
mount_partitions() {
    clear
    local root_part="$1"
    local boot_part="$2"
    
    echo -e "\n${CYAN}Montando particiones...${RESET}"
    
    # Montar ROOT
    echo -ne "  Montando ROOT... "
    if retry_command mount "$root_part" /mnt; then
        echo -e "${GREEN}✔${RESET}"
    else
        echo -e "${RED}✘${RESET}"
        return 1
    fi
    
    # Montar BOOT/EFI
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        echo -ne "  Montando EFI... "
        mkdir -p /mnt/boot/efi
        if retry_command mount "$boot_part" /mnt/boot/efi; then
            echo -e "${GREEN}✔${RESET}"
        else
            echo -e "${RED}✘${RESET}"
            return 1
        fi
    else
        echo -ne "  Montando BOOT... "
        mkdir -p /mnt/boot
        if retry_command mount "$boot_part" /mnt/boot; then
            echo -e "${GREEN}✔${RESET}"
        else
            echo -e "${RED}✘${RESET}"
            return 1
        fi
    fi
    
    return 0
    sleep 3
}

# Función para montar particiones de forma segura
mount_partitions() {    
    clear
    local root_part="$1"
    local boot_part="$2"
    
    echo -e "\n${CYAN}Montando particiones...${RESET}"
    
    # Montar ROOT
    echo -ne "  Montando ROOT... "
    if retry_command mount "$root_part" /mnt; then
        echo -e "${GREEN}✔${RESET}"
    else
        echo -e "${RED}✘${RESET}"
        return 1
    fi
    
    # Montar BOOT/EFI
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        echo -ne "  Montando EFI... "
        mkdir -p /mnt/boot/efi
        if retry_command mount "$boot_part" /mnt/boot/efi; then
            echo -e "${GREEN}✔${RESET}"
        else
            echo -e "${RED}✘${RESET}"
            return 1
        fi
    else
        echo -ne "  Montando BOOT... "
        mkdir -p /mnt/boot
        if retry_command mount "$boot_part" /mnt/boot; then
            echo -e "${GREEN}✔${RESET}"
        else
            echo -e "${RED}✘${RESET}"
            return 1
        fi
    fi
    
    return 0
    sleep 4
}
# Función para verificar si un disco está montado
is_disk_mounted() {
    local disk="$1"
    lsblk -no MOUNTPOINT "$disk" | grep -q .
    return $?
}

# Función para desmontar todas las particiones de un disco
unmount_all() {
    clear
    local disk="$1"
    local partitions
    
    mapfile -t partitions < <(lsblk -nlo NAME,MOUNTPOINT "$disk" | awk '$2 != "" {print $1}')
    
    for part in "${partitions[@]}"; do
        echo -ne "${CYAN}Desmontando /dev/$part... ${RESET}"
        if umount "/dev/$part" 2>/dev/null; then
            echo -e "${GREEN}✔${RESET}"
        else
            echo -e "${RED}✘${RESET}"
            return 1
        fi
    done
    
    return 0
    sleep 3
}
format_and_mount_partitions() {
    clear
    local root_part="$1"
    local boot_part="$2"
    local swap_part="$3"
    
    echo -e "\n${CYAN}╔══════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║      Formato de Particiones         ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${RESET}\n"
    
    # Formatear ROOT
    echo -ne "${WHITE}Formateando ROOT (${root_part})...${RESET} "
    if ! mkfs.ext4 -F "$root_part"; then
        echo -e "${RED}✘${RESET}"
        log "ERROR" "Error al formatear partición ROOT"
        return 1
    fi
    echo -e "${GREEN}✔${RESET}"
    
    # Formatear BOOT/EFI
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        echo -ne "${WHITE}Formateando EFI (${boot_part})...${RESET} "
        if ! mkfs.fat -F32 "$boot_part"; then
            echo -e "${RED}✘${RESET}"
            log "ERROR" "Error al formatear partición EFI"
            return 1
        fi
    else
        echo -ne "${WHITE}Formateando BOOT (${boot_part})...${RESET} "
        if ! mkfs.ext4 -F "$boot_part"; then
            echo -e "${RED}✘${RESET}"
            log "ERROR" "Error al formatear partición BOOT"
            return 1
        fi
    fi
    echo -e "${GREEN}✔${RESET}"
    
    # Formatear SWAP si existe
    if [[ -n "$swap_part" ]]; then
        echo -ne "${WHITE}Formateando SWAP (${swap_part})...${RESET} "
        if ! mkswap "$swap_part" || ! swapon "$swap_part"; then
            echo -e "${RED}✘${RESET}"
            log "ERROR" "Error al formatear/activar SWAP"
            return 1
        fi
        echo -e "${GREEN}✔${RESET}"
    fi
    
    # Montar particiones
    echo -e "\n${CYAN}Montando particiones...${RESET}"
    
    echo -ne "${WHITE}Montando ROOT...${RESET} "
    if ! mount "$root_part" /mnt; then
        echo -e "${RED}✘${RESET}"
        log "ERROR" "Error al montar partición ROOT"
        return 1
    fi
    echo -e "${GREEN}✔${RESET}"
    
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        echo -ne "${WHITE}Montando EFI...${RESET} "
        mkdir -p /mnt/boot/efi
        if ! mount "$boot_part" /mnt/boot/efi; then
            echo -e "${RED}✘${RESET}"
            log "ERROR" "Error al montar partición EFI"
            return 1
        fi
    else
        echo -ne "${WHITE}Montando BOOT...${RESET} "
        mkdir -p /mnt/boot
        if ! mount "$boot_part" /mnt/boot; then
            echo -e "${RED}✘${RESET}"
            log "ERROR" "Error al montar partición BOOT"
            return 1
        fi
    fi
    echo -e "${GREEN}✔${RESET}"
    
    log "SUCCESS" "Particiones formateadas y montadas correctamente"
    return 0
    sleep 3
}

verify_partitions() {
    clear
    log "INFO" "Verificando particiones"
    
    echo -e "\n${CYAN}╔══════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║      Verificación de Particiones     ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${RESET}\n"

    # Esperar a que el sistema de archivos se estabilice
    sleep 2
    
    # Verificar que el punto de montaje /mnt existe
    if [[ ! -d "/mnt" ]]; then
        mkdir -p /mnt
        log "WARN" "Creado directorio /mnt"
    fi
    
    # Verificar puntos de montaje
    local mount_points=()
    local required_dirs=()
    
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        mount_points=("/mnt" "/mnt/boot/efi")
        required_dirs=("/mnt/boot" "/mnt/boot/efi")
    else
        mount_points=("/mnt" "/mnt/boot")
        required_dirs=("/mnt/boot")
    fi
    
    # Crear directorios necesarios si no existen
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log "WARN" "Creado directorio $dir"
        fi
    done
    
    local all_mounted=true
    for point in "${mount_points[@]}"; do
        echo -ne "${WHITE}Verificando $point...${RESET} "
        if ! mountpoint -q "$point" 2>/dev/null; then
            echo -e "${YELLOW}✘ No montado${RESET}"
            all_mounted=false
            
            # Intentar recuperar el montaje
            local part_uuid=$(findmnt -n -o SOURCE "$point" 2>/dev/null)
            if [[ -n "$part_uuid" ]]; then
                echo -ne "${YELLOW}Intentando montar nuevamente...${RESET} "
                if mount "$part_uuid" "$point" 2>/dev/null; then
                    echo -e "${GREEN}✔${RESET}"
                    all_mounted=true
                else
                    echo -e "${RED}✘${RESET}"
                fi
            fi
        else
            echo -e "${GREEN}✔${RESET}"
        fi
    done
    
    if ! $all_mounted; then
        echo -e "\n${YELLOW}ADVERTENCIA: No todos los puntos de montaje están configurados${RESET}"
        echo -e "¿Desea continuar de todos modos? (s/N): "
        read -r response
        if [[ ! "$response" =~ ^[Ss]$ ]]; then
            log "ERROR" "Instalación cancelada por el usuario"
            return 1
        fi
        log "WARN" "Continuando sin todos los puntos de montaje"
    fi
    
    # Mostrar estructura final
    echo -e "\n${WHITE}Estructura final de particiones:${RESET}"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E '^|/mnt' | sed 's/^/  /'
    sleep 2
    log "SUCCESS" "Verificación de particiones completada"
    return 0
    sleep 3
}

# ==============================================================================
# Funciones de Instalación Base
# ==============================================================================

# Función para manejar errores
handle_error() {
    log "ERROR" "$1"
    return 1
}

install_base_system() {
    clear
    log "INFO" "Iniciando instalación del sistema base"
    
    echo -e "\n${CYAN}╔════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║      Instalación del Sistema Base      ║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${RESET}\n"
    
    # Array de funciones de instalación
    local install_steps=(
        "install_essential_packages"
        "generate_fstab"
        "configure_system_base"
        "configure_bootloader"
    )
    
    # Ejecutar pasos de instalación
    local total_steps=${#install_steps[@]}
    local current=0
    
    for step in "${install_steps[@]}"; do
        ((current++))
        echo -e "\n${WHITE}[$current/$total_steps] Ejecutando: ${step//_/ }${RESET}"
        if ! $step; then
            handle_error "Fallo en: $step"
            return 1
        fi
        show_progress "$current" "$total_steps"
    done
    
    return 0
    sleep 3
}

install_essential_packages() {
    clear
    log "INFO" "Instalando paquetes esenciales"
    
    # Verificar conexión antes de instalar
    if ! ping -c 1 archlinux.org &>/dev/null; then
        log "ERROR" "Sin conexión a Internet"
        return 1
    fi
    
    # Actualizar base de datos de pacman
    echo -e "${CYAN}Actualizando base de datos de pacman...${RESET}"
    if ! pacman -Sy; then
        log "ERROR" "Fallo al actualizar base de datos de pacman"
        return 1
    fi
    
    # Lista completa de paquetes
    local packages=(
        # Sistema base
        "${BASE_PACKAGES[@]}"
        
        # Utilidades básicas
        "bash-completion"
        "man-db"
        "man-pages"
        "texinfo"
        "nano"
        "vim"
        "wget"
        "curl"
        
        # Red
        "networkmanager"
        "network-manager-applet"
        "wpa_supplicant"
        "dialog"
        "dhcpcd"
        
        # Audio
        "pulseaudio"
        "pulseaudio-alsa"
        "alsa-utils"
        
        # Otros
        "reflector"
        "git"
        "zip"
        "unzip"
        "htop"
    )
    
    echo -e "\n${WHITE}Paquetes a instalar:${RESET}"
    printf '%s\n' "${packages[@]}" | column | sed 's/^/  /'
    
    # Instalar paquetes
    echo -e "\n${CYAN}Instalando paquetes...${RESET}"
    if ! pacstrap /mnt "${packages[@]}"; then
        log "ERROR" "Fallo al instalar paquetes base"
        return 1
    fi
    
    log "SUCCESS" "Paquetes base instalados correctamente"
    return 0
    sleep 3
}

generate_fstab() {
    clear
    log "INFO" "Generando fstab"
    
    echo -ne "${CYAN}Generando /etc/fstab...${RESET} "
    
    if ! genfstab -U /mnt >> /mnt/etc/fstab; then
        echo -e "${RED}✘${RESET}"
        log "ERROR" "Fallo al generar fstab"
        return 1
    fi
    echo -e "${GREEN}✔${RESET}"
    
    # Verificar fstab
    echo -ne "${CYAN}Verificando fstab...${RESET} "
    if ! grep -q "UUID" /mnt/etc/fstab; then
        echo -e "${RED}✘${RESET}"
        log "ERROR" "fstab generado incorrectamente"
        return 1
    fi
    echo -e "${GREEN}✔${RESET}"
    
    # Mostrar fstab generado
    echo -e "\n${WHITE}Contenido de fstab:${RESET}"
    cat /mnt/etc/fstab | sed 's/^/  /'
    
    log "SUCCESS" "fstab generado correctamente"
    return 0
    sleep 2
}

configure_system_base() {
    clear
    log "INFO" "Configurando sistema base"

    # Configuración del hostname y hosts
    echo -e "\n${WHITE}Configuración del hostname:${RESET}"
    while true; do
        echo -ne "${YELLOW}Ingrese el hostname para el sistema:${RESET} "
        read -r HOSTNAME
        if [[ "$HOSTNAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
            break
        else
            echo -e "${RED}Hostname inválido. Use solo letras, números y guiones${RESET}"
        fi
    done
    echo "$HOSTNAME" > /mnt/etc/hostname
    cat > /mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF

    # Configuración de zona horaria
    echo -e "\n${WHITE}Configuración de zona horaria:${RESET}"
    local zones=("America/Guayaquil" "America/Lima" "America/Bogota" "Europe/Madrid" "Otra")
    PS3=$'\n'"${YELLOW}Seleccione zona horaria:${RESET} "
    select zone in "${zones[@]}"; do
        case $zone in
            "Otra")
                mapfile -t all_zones < <(find /usr/share/zoneinfo -type f -not -path '*/posix/*' -not -path '*/right/*' | sed 's|/usr/share/zoneinfo/||')
                PS3=$'\n'"${YELLOW}Seleccione zona horaria:${RESET} "
                select TIMEZONE in "${all_zones[@]}"; do
                    [[ -n "$TIMEZONE" ]] && break 2
                done
                ;;
            *)
                TIMEZONE="$zone"
                break
                ;;
        esac
    done
    arch-chroot /mnt ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    arch-chroot /mnt hwclock --systohc

    # Configuración de locale
    echo -e "\n${WHITE}Configurando locale...${RESET}"
    sed -i 's/#\(en_US.UTF-8\)/\1/; s/#\(es_ES.UTF-8\)/\1/' /mnt/etc/locale.gen
    arch-chroot /mnt locale-gen
    echo "LANG=es_ES.UTF-8" > /mnt/etc/locale.conf
    echo "KEYMAP=es" > /mnt/etc/vconsole.conf

    # Configuración de usuarios
    echo -e "\n${WHITE}Configuración de usuarios:${RESET}"
    echo -e "\n${CYAN}Configurando contraseña de root${RESET}"
    while ! arch-chroot /mnt passwd; do
        echo -e "${RED}Error al configurar contraseña. Intente nuevamente${RESET}"
    done

    while true; do
        echo -ne "\n${YELLOW}Ingrese nombre para el nuevo usuario:${RESET} "
        read -r USERNAME
        if [[ "$USERNAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
            break
        else
            echo -e "${RED}Nombre inválido. Use letras minúsculas, números y guiones${RESET}"
        fi
    done
    arch-chroot /mnt useradd -m -G wheel,audio,video,storage,optical -s /bin/bash "$USERNAME"
    echo -e "\n${CYAN}Configurando contraseña para $USERNAME${RESET}"
    while ! arch-chroot /mnt passwd "$USERNAME"; do
        echo -e "${RED}Error al configurar contraseña. Intente nuevamente${RESET}"
    done
    echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/wheel
    chmod 440 /mnt/etc/sudoers.d/wheel

    # Habilitar servicios básicos
    echo -e "\n${WHITE}Habilitando servicios...${RESET}"
    local services=("NetworkManager" "fstrim.timer" "systemd-timesyncd")
    for service in "${services[@]}"; do
        echo -ne "${CYAN}Habilitando $service...${RESET} "
        if arch-chroot /mnt systemctl enable "$service" &>/dev/null; then
            echo -e "${GREEN}✔${RESET}"
        else
            echo -e "${RED}✘${RESET}"
            log "WARN" "No se pudo habilitar $service"
        fi
    done

    log "SUCCESS" "Sistema base configurado correctamente"
    return 0
}

configure_bootloader() {
    log "INFO" "Configurando bootloader"
    
    echo -e "\n${CYAN}╔════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║      Configuración del Bootloader      ║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${RESET}\n"
    
    # Instalar paquetes necesarios
    local bootloader_packages=(
        "grub"
        "efibootmgr"
        "os-prober"
        "dosfstools"
        "mtools"
    )
    
    echo -e "${CYAN}Instalando paquetes del bootloader...${RESET}"
    if ! arch-chroot /mnt pacman -S --noconfirm "${bootloader_packages[@]}"; then
        log "ERROR" "Fallo al instalar paquetes del bootloader"
        return 1
    fi
    
    # Instalar GRUB según el modo de arranque
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        echo -e "\n${CYAN}Instalando GRUB para UEFI...${RESET}"
        if ! arch-chroot /mnt grub-install \
            --target=x86_64-efi \
            --efi-directory=/boot/efi \
            --bootloader-id=GRUB \
            --recheck; then
            log "ERROR" "Fallo al instalar GRUB (UEFI)"
            return 1
        fi
    else
        echo -e "\n${CYAN}Instalando GRUB para BIOS...${RESET}"
        if ! arch-chroot /mnt grub-install \
            --target=i386-pc \
            --recheck \
            "$TARGET_DISK"; then
            log "ERROR" "Fallo al instalar GRUB (BIOS)"
            return 1
        fi
    fi
    
    # Configurar GRUB
    echo -e "\n${CYAN}Configurando GRUB...${RESET}"
    
    # Backup de la configuración original
    if [[ -f /mnt/etc/default/grub ]]; then
        cp /mnt/etc/default/grub /mnt/etc/default/grub.backup
    fi
    
    # Configuración personalizada de GRUB
    cat > /mnt/etc/default/grub <<EOF
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Arch Linux"
GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3 audit=0"
GRUB_CMDLINE_LINUX=""
GRUB_PRELOAD_MODULES="part_gpt part_msdos"
GRUB_TIMEOUT_STYLE=menu
GRUB_TERMINAL_INPUT=console
GRUB_GFXMODE=auto
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_DISABLE_OS_PROBER=false
EOF
    
    # Generar configuración
    echo -e "${CYAN}Generando configuración de GRUB...${RESET}"
    if ! arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg; then
        log "ERROR" "Fallo al generar configuración de GRUB"
        return 1
    fi
    
    # Verificar instalación
    local essential_files=(
        "/mnt/boot/grub/grub.cfg"
        "/mnt/etc/default/grub"
    )
    
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        essential_files+=("/mnt/boot/efi/EFI/GRUB/grubx64.efi")
    else
        essential_files+=("/mnt/boot/grub/i386-pc/core.img")
    fi
    
    echo -e "\n${CYAN}Verificando archivos del bootloader...${RESET}"
    local missing_files=0
    for file in "${essential_files[@]}"; do
        echo -ne "${WHITE}Verificando $file...${RESET} "
        if [[ -f "$file" ]]; then
            echo -e "${GREEN}✔${RESET}"
        else
            echo -e "${RED}✘${RESET}"
            ((missing_files++))
        fi
    done
    
    if ((missing_files > 0)); then
        log "ERROR" "Faltan archivos esenciales del bootloader"
        return 1
    fi
    
    log "SUCCESS" "Bootloader instalado y configurado correctamente"
    return 0
    sleep 3
}

# ==============================================================================
# Funciones de Post-instalación y Temas
# ==============================================================================
install_desktop_environment() {
    clear
    log "INFO" "Instalando entorno de escritorio"
    
    echo -e "\n${CYAN}╔════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║ Selección de Entorno de Escritorio     ║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${RESET}\n"
    
    local environments=(
        "GNOME"
        "XFCE"
        "Qtile"
        "BSPWM"
        "Hyprland"
    )
    
    PS3=$'\n'"${YELLOW}Seleccione entorno de escritorio:${RESET} "
    select env in "${environments[@]}"; do
        case $env in
            "GNOME"|"XFCE"|"Qtile"|"BSPWM"|"Hyprland")
                install_packages_for "$env"
                configure_display_manager
                break
                ;;
            *)
                echo -e "\n${RED}Opción inválida${RESET}"
                ;;
        esac
    done
    
    log "SUCCESS" "Entorno de escritorio instalado correctamente"
    return 0
    sleep 3
}

install_packages_for() {
    clear
    local env=$1
    local packages=()
    
    case $env in
        "GNOME")
            packages=(
                gnome
                gnome-extra
                gdm
            )
            ;;
        "XFCE")
            packages=(
                xfce4
                xfce4-goodies
                lightdm
                lightdm-gtk-greeter
            )
            ;;
        "Qtile")
            packages=(
                qtile
                xorg-server
                xorg-xinit
                lightdm
                lightdm-gtk-greeter
            )
            ;;
        "BSPWM")
            packages=(
                bspwm
                sxhkd
                xorg-server
                xorg-xinit
                lightdm
                lightdm-gtk-greeter
            )
            ;;
        "Hyprland")
            packages=(
                hyprland
                xorg-xwayland
                sddm
            )
            ;;
    esac
    
    echo -e "\n${CYAN}Instalando paquetes para $env...${RESET}"
    if ! arch-chroot /mnt pacman -S --noconfirm "${packages[@]}"; then
        log "ERROR" "Fallo al instalar paquetes para $env"
        return 1
    fi
    
    return 0
    sleep 3
}

configure_display_manager() {
    clear
    log "INFO" "Configurando display manager"
    
    local display_manager
    
    if [[ "$env" == "GNOME" ]]; then
        display_manager="gdm"
    elif [[ "$env" == "Hyprland" ]]; then
        display_manager="sddm"
    else
        display_manager="lightdm"
    fi
    
    echo -e "\n${CYAN}Habilitando $display_manager...${RESET}"
    if ! arch-chroot /mnt systemctl enable "$display_manager"; then
        log "ERROR" "Fallo al habilitar $display_manager"
        return 1
    fi
    
    log "SUCCESS" "Display manager configurado correctamente"
    return 0
    sleep 2
}

configure_zeuspy_theme() {
    clear
    log "INFO" "Configurando tema personalizado ZeuspyEC"
    
    echo -e "\n${CYAN}╔════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║      Instalación Tema ZeuspyEC         ║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${RESET}\n"
    
    # Instalar paquetes base para BSPWM
    local bspwm_packages=(
        # WM y componentes básicos
        "bspwm"
        "sxhkd"
        "polybar"
        "picom"
        "dunst"
        "rofi"
        "nitrogen"
        
        # Terminal y utilidades
        "alacritty"
        "ranger"
        "neofetch"
        "htop"
        "feh"
        "maim"
        "xclip"
        
        # Fuentes
        "ttf-dejavu"
        "ttf-liberation"
        "noto-fonts"
        "ttf-hack"
        "ttf-font-awesome"
        
        # Tema y GTK
        "lxappearance"
        "gtk-engine-murrine"
        "arc-gtk-theme"
        "papirus-icon-theme"
        
        # Multimedia
        "brightnessctl"
        "pulseaudio"
        "pavucontrol"
        "pamixer"
        
        # Desarrollo
        "base-devel"
        "git"
        "wget"
        "curl"
        
        # Utilidades del sistema
        "networkmanager"
        "network-manager-applet"
        "bluez"
        "bluez-utils"
        "udiskie"
        "ntfs-3g"
        "gvfs"
    )
    
    echo -e "${WHITE}Instalando paquetes necesarios...${RESET}"
    # Mostrar paquetes a instalar
    printf '%s\n' "${bspwm_packages[@]}" | column | sed 's/^/  /'
    
    if ! arch-chroot /mnt pacman -S --noconfirm "${bspwm_packages[@]}"; then
        log "ERROR" "Fallo al instalar paquetes necesarios"
        return 1
    fi
    
    # Crear estructura de directorios
    echo -e "\n${CYAN}Creando estructura de directorios...${RESET}"
    arch-chroot /mnt mkdir -p "/home/$USERNAME/.config"/{bspwm,sxhkd,polybar,picom,dunst,rofi,alacritty}
    
    # Descargar e instalar tema gh0stzk
    echo -e "\n${CYAN}Descargando tema gh0stzk...${RESET}"
    arch-chroot /mnt bash -c "cd /home/$USERNAME && \
        curl -O https://raw.githubusercontent.com/gh0stzk/dotfiles/master/RiceInstaller && \
        chmod +x RiceInstaller && \
        chown $USERNAME:$USERNAME RiceInstaller && \
        su - $USERNAME -c './RiceInstaller'"
    
    # Configurar autostart de BSPWM
    echo -e "\n${CYAN}Configurando inicio automático...${RESET}"
    cat > "/mnt/home/$USERNAME/.xinitrc" <<EOF
#!/bin/sh
exec bspwm
EOF
    
    # Configurar archivo .bash_profile
    cat > "/mnt/home/$USERNAME/.bash_profile" <<EOF
if [[ ! \$DISPLAY && \$XDG_VTNR -eq 1 ]]; then
    exec startx
fi
EOF
    
    # Ajustar permisos
    arch-chroot /mnt chown -R "$USERNAME:$USERNAME" "/home/$USERNAME"
    arch-chroot /mnt chmod +x "/home/$USERNAME/.xinitrc"
    
    # Habilitar servicios necesarios
    echo -e "\n${CYAN}Habilitando servicios...${RESET}"
    local services=(
        "NetworkManager"
        "bluetooth"
        "sshd"
        "fstrim.timer"
    )
    
    for service in "${services[@]}"; do
        echo -ne "${WHITE}Habilitando $service...${RESET} "
        if arch-chroot /mnt systemctl enable "$service" &>/dev/null; then
            echo -e "${GREEN}✔${RESET}"
        else
            echo -e "${RED}✘${RESET}"
        fi
    done
    
    log "SUCCESS" "Tema ZeuspyEC instalado correctamente"
    return 0
}

generate_installation_report() {
    log "INFO" "Generando reporte de instalación"
    
    local report_file="/mnt/root/installation_report.txt"
    
    {
        echo "=== Reporte de Instalación ZeuspyEC ==="
        echo "Fecha: $(date)"
        echo "Versión del instalador: $SCRIPT_VERSION"
        echo ""
        echo "Información del Sistema:"
        echo "- Hostname: $HOSTNAME"
        echo "- Usuario: $USERNAME"
        echo "- Zona horaria: $TIMEZONE"
        echo "- Modo de arranque: $BOOT_MODE"
        echo "- Disco utilizado: $TARGET_DISK"
        echo ""
        echo "Particiones:"
        lsblk "$TARGET_DISK" -o NAME,SIZE,TYPE,MOUNTPOINT
        echo ""
        echo "Paquetes instalados:"
        arch-chroot /mnt pacman -Q
        echo ""
        echo "Servicios habilitados:"
        arch-chroot /mnt systemctl list-unit-files --state=enabled
        echo ""
        echo "=== Fin del Reporte ==="
    } > "$report_file"
    
    log "SUCCESS" "Reporte generado en $report_file"
    sleep 3
}

cleanup() {
    log "INFO" "Realizando limpieza final"
    
    echo -e "\n${CYAN}╔════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║      Limpieza del Sistema              ║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${RESET}\n"
    
    # Desmontar particiones en orden inverso
    local mountpoints=(
        "/mnt/boot/efi"
        "/mnt/boot"
        "/mnt"
    )
    
    for point in "${mountpoints[@]}"; do
        if mountpoint -q "$point"; then
            echo -ne "${WHITE}Desmontando $point...${RESET} "
            if umount -R "$point"; then
                echo -e "${GREEN}✔${RESET}"
            else
                echo -e "${RED}✘${RESET}"
                log "WARN" "Fallo al desmontar $point"
            fi
        fi
    done
    
    # Desactivar swap
    echo -ne "${WHITE}Desactivando swap...${RESET} "
    if swapoff -a; then
        echo -e "${GREEN}✔${RESET}"
    else
        echo -e "${RED}✘${RESET}"
        log "WARN" "Fallo al desactivar swap"
    fi
    
    # Sincronizar sistema de archivos
    echo -ne "${WHITE}Sincronizando sistema de archivos...${RESET} "
    sync
    echo -e "${GREEN}✔${RESET}"
}

show_post_install_message() {
    echo -e "\n${CYAN}╔════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║      Instalación Completada            ║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${RESET}\n"
    
    echo -e "${GREEN}¡Instalación completada exitosamente!${RESET}\n"
    echo -e "${WHITE}Información importante:${RESET}"
    echo -e "  • Hostname: ${CYAN}$HOSTNAME${RESET}"
    echo -e "  • Usuario: ${CYAN}$USERNAME${RESET}"
    echo -e "  • Zona horaria: ${CYAN}$TIMEZONE${RESET}"
    echo -e "  • Tema instalado: ${CYAN}ZeuspyEC BSPWM${RESET}"
    
    echo -e "\n${WHITE}Próximos pasos:${RESET}"
    echo -e "  1. El reporte de instalación está en ${CYAN}/root/installation_report.txt${RESET}"
    echo -e "  2. Reinicia el sistema con ${CYAN}reboot${RESET}"
    echo -e "  3. Retira el medio de instalación"
    echo -e "  4. Inicia sesión como ${CYAN}$USERNAME${RESET}"
    echo -e "  5. Usa ${CYAN}startx${RESET} para iniciar el entorno gráfico"
    
    echo -e "\n${WHITE}Atajos de teclado importantes:${RESET}"
    echo -e "  • ${CYAN}Win + Enter${RESET}: Abrir terminal"
    echo -e "  • ${CYAN}Win + W${RESET}: Cerrar ventana"
    echo -e "  • ${CYAN}Win + Space${RESET}: Menú de aplicaciones"
    echo -e "  • ${CYAN}Win + Alt + R${RESET}: Reiniciar BSPWM"
    echo -e "  • ${CYAN}Win + Alt + Q${RESET}: Cerrar sesión"
    
    # Preguntar por reinicio
    echo -e "\n${YELLOW}¿Desea reiniciar el sistema ahora? (s/N):${RESET} "
    read -r reboot_choice
    
    if [[ "$reboot_choice" =~ ^[Ss]$ ]]; then
        log "INFO" "Reiniciando sistema"
        cleanup
        reboot
    else
        log "INFO" "Reinicio pospuesto"
        cleanup
        echo -e "${YELLOW}Recuerde reiniciar el sistema cuando esté listo${RESET}"
    fi
}

# Función principal final
finalize_installation() {
    log "INFO" "Finalizando instalación"
    
    local final_steps=(
        "configure_zeuspy_theme"
        "generate_installation_report"
    )
    
    # Ejecutar pasos finales
    for step in "${final_steps[@]}"; do
        if ! $step; then
            log "ERROR" "Fallo en paso final: $step"
            return 1
        fi
    done
    
    show_post_install_message
    return 0
}

# Función para detectar sistemas operativos existentes
detect_existing_os() {
    log "INFO" "Detectando otros sistemas operativos"
    
    echo -e "\n${CYAN}╔════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║      Sistemas Operativos Detectados    ║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${RESET}\n"
    
    # Instalar os-prober si no está presente
    if ! command -v os-prober &>/dev/null; then
        retry_command pacman -Sy --noconfirm os-prober
    fi
    
    echo -e "\n${CYAN}Analizando discos en busca de sistemas operativos...${RESET}\n"
    
    local found_os=false
    local disks
    mapfile -t disks < <(lsblk -dpno NAME)
    
    for disk in "${disks[@]}"; do
        local partitions
        mapfile -t partitions < <(lsblk -pnlo NAME "$disk" | grep -v "^$disk$")
        
        for part in "${partitions[@]}"; do
            # Crear punto de montaje temporal
            local tmp_mount="/tmp/os_detect_${part//\//_}"
            mkdir -p "$tmp_mount"
            
            # Intentar montar la partición
            if mount "$part" "$tmp_mount" 2>/dev/null; then
                # Buscar Windows
                if [[ -d "$tmp_mount/Windows" ]]; then
                    echo -e "${GREEN}✔${RESET} Windows detectado en $part"
                    found_os=true
                fi
                
                # Buscar Linux
                if [[ -f "$tmp_mount/etc/os-release" ]]; then
                    local os_name
                    os_name=$(grep "^NAME=" "$tmp_mount/etc/os-release" | cut -d'"' -f2)
                    echo -e "${GREEN}✔${RESET} $os_name detectado en $part"
                    found_os=true
                fi
                
                umount "$tmp_mount"
            fi
            rmdir "$tmp_mount"
        done
    done
    
    if $found_os; then
        echo -e "\n${YELLOW}¡ADVERTENCIA! Se encontraron otros sistemas operativos${RESET}"
        echo -e "${YELLOW}Se configurará el sistema para dual boot${RESET}"
        sleep 2
    fi
}

error_handler() {
    local exit_code=$1
    local line_no=$2
    local bash_lineno=$3
    local last_command=$4
    local func_trace=$5
    
    echo -e "\n${RED}╔════════════════════════════════════════╗${RESET}"
    echo -e "${RED}║            Error Detectado             ║${RESET}"
    echo -e "${RED}╚════════════════════════════════════════╝${RESET}\n"
    
    echo -e "${WHITE}Código de error:${RESET} $exit_code"
    echo -e "${WHITE}Línea:${RESET} $line_no"
    echo -e "${WHITE}Comando:${RESET} $last_command"
    echo -e "${WHITE}Traza de función:${RESET} ${func_trace#::}"
    
    echo -e "\n${YELLOW}¿Desea intentar continuar? (s/N):${RESET} "
    read -r response
    
    if [[ "$response" =~ ^[Ss]$ ]]; then
        log "WARN" "Continuando después del error..."
        return 0
    else
        log "ERROR" "Instalación cancelada por el usuario"
        cleanup
        exit 1
    fi
}

# Función para reintentar comandos
retry_command() {
    local max_attempts=3
    local delay=2
    local attempt=1
    local command=("$@")
    
    while ((attempt <= max_attempts)); do
        if "${command[@]}"; then
            return 0
        else
            if ((attempt == max_attempts)); then
                echo -e "\n${YELLOW}¿Desea reintentar '$*'? (s/N):${RESET} "
                read -r response
                if [[ "$response" =~ ^[Ss]$ ]]; then
                    max_attempts=$((max_attempts + 1))
                else
                    return 1
                fi
            fi
            echo -e "${YELLOW}Intento $attempt de $max_attempts falló. Reintentando en $delay segundos...${RESET}"
            sleep $delay
            ((attempt++))
        fi
    done
    
    return 1
}

# Función para inicializar el script
init_script() {
    display_banner
    echo -e "${HEADER}Inicializando el instalador ZeusPy...${RESET}"
    sleep 1
}

# Pasos de instalación simulados
check_system_requirements() { display_banner; echo "Verificando requisitos del sistema..."; sleep 1; return 0; }
check_network_connectivity() { display_banner; echo "Verificando conectividad de red..."; sleep 1; return 0; }
detect_existing_os() { display_banner; echo "Detectando sistemas operativos existentes..."; sleep 1; return 0; }
prepare_disk() { display_banner; echo "Preparando el disco..."; sleep 1; return 0; }
install_base_system() { display_banner; echo "Instalando sistema base..."; sleep 1; return 0; }
configure_system_base() { display_banner; echo "Configurando el sistema base..."; sleep 1; return 0; }
configure_bootloader() { display_banner; echo "Configurando el gestor de arranque..."; sleep 1; return 0; }
configure_zeuspy_theme() { display_banner; echo "Aplicando tema ZeusPy..."; sleep 1; return 0; }
generate_installation_report() { display_banner; echo "Generando informe de instalación..."; sleep 1; return 0; }

# Función principal
main() {
    # Iniciar contador de tiempo
    local start_time
    start_time=$(date +%s)
    
    # Inicializar script
    init_script

    # Mostrar menú principal
    show_main_menu
    
    # Pasos de instalación
    local installation_steps=(
        "check_system_requirements"
        "check_network_connectivity"
        "detect_existing_os"  
        "prepare_disk"
        "install_base_system"
        "configure_system_base"
        "configure_bootloader"
        "configure_zeuspy_theme"
        "generate_installation_report"
    )
    # Ejecutar pasos de instalación
    local total_steps=${#installation_steps[@]}
    local current=0
    
    for step in "${installation_steps[@]}"; do
        ((current++))
        echo -e "\n${HEADER}[$current/$total_steps] ${step//_/ }${RESET}"
        if ! $step; then
            echo -e "${ERROR}Instalación fallida en: $step${RESET}"
            cleanup
            exit 1
        fi
        show_progress "$current" "$total_steps"
    done
    
    # Calcular tiempo de instalación
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    # Mostrar resumen y finalizar
    show_post_install_message
    
    return 0
}

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
    echo -e "${ERROR}Este script debe ejecutarse como root${RESET}"
    exit 1
fi

# Ejecutar instalador
main "$@"
