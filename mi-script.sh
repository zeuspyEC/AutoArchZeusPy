#!/usr/bin/env bash

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# ==============================================================================
# ZeuspyEC Arch Linux Installer
# Versión: 3.0.1
# ==============================================================================

# Habilitar modo estricto
set -euo pipefail
IFS=$'\n\t'

# Definición de colores (versión simple y probada)
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'  # No Color

# Variables de color adicionales que faltan
ERROR="${RED}"
SUCCESS="${GREEN}"
WARNING="${YELLOW}"
INFO="${CYAN}"
HEADER="${PURPLE}"
INPUT="${YELLOW}"
PRIMARY="${BLUE}"
BOLD='\033[1m'
# Variables globales
declare -g SCRIPT_VERSION="3.0.1"
declare -g BOOT_MODE=""
declare -g TARGET_DISK=""
declare -g HOSTNAME=""
declare -g USERNAME=""
declare -g TIMEZONE=""

# Archivos de log mejorados
declare -g LOG_FILE="/tmp/zeuspyec_installer.log"
declare -g ERROR_LOG="/tmp/zeuspyec_installer_error.log"
declare -g DEBUG_LOG="/tmp/zeuspyec_installer_debug.log"

# Paquetes requeridos
declare -g REQUIRED_PACKAGES=(
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

# Función para mostrar el banner de ZeuspyEC
display_banner() {
    echo -e "${BLUE}"  # Cambiamos BANNER por BLUE ya que es el que definimos
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
    echo -e "${NC}"
    echo -e "${GREEN}Version ${SCRIPT_VERSION} - By ZeuspyEC ~ https://github.com/zeuspyEC/${NC}\n"
}

# Función de logging mejorada
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local function_name="${FUNCNAME[1]:-main}"
    local line_number="${BASH_LINENO[0]}"
    
    # Formato de log mejorado
    local log_entry="[$timestamp] [$level] [$function_name:$line_number] $message"
    
    case "$level" in
        "DEBUG")
            echo -e "${CYAN}$log_entry${NC}" >> "$DEBUG_LOG"
            ;;
        "INFO")
            echo -e "${GREEN}$log_entry${NC}" | tee -a "$LOG_FILE"
            ;;
        "SUCCESS")
            echo -e "${GREEN}✔ $log_entry${NC}" | tee -a "$LOG_FILE"
            ;;
        "WARN")
            echo -e "${YELLOW}⚠ $log_entry${NC}" | tee -a "$LOG_FILE"
            ;;
        "ERROR")
            echo -e "${RED}✘ $log_entry${NC}" | tee -a "$ERROR_LOG"
            print_system_info >> "$ERROR_LOG"
            ;;
    esac
}

# Función para mostrar información del sistema
print_system_info() {
    echo -e "${PURPLE}╔══════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║      Información del Sistema         ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════╝${NC}"
    
    # Kernel
    printf "${WHITE}%-12s${NC} : %s\n" "Kernel" "$(uname -r)"
    
    # CPU
    local cpu_info
    cpu_info=$(grep "model name" /proc/cpuinfo | head -n1 | cut -d: -f2 | xargs)
    printf "${WHITE}%-12s${NC} : %s\n" "CPU" "$cpu_info"
    
    # Memoria
    echo -e "\n${WHITE}Memoria:${NC}"
    free -h | awk '
        NR==1 {printf "%-12s %-10s %-10s %-10s %-10s\n", $1, $2, $3, $4, $7}
        NR==2 {printf "%-12s %-10s %-10s %-10s %-10s\n", $1":", $2, $3, $4, $7}
    ' | sed 's/^/  /'
    
    # Disco
    echo -e "\n${WHITE}Disco:${NC}"
    df -h | grep -E '^/dev|^Filesystem' | \
        awk '{printf "  %-20s %-10s %-10s %-10s %-10s %s\n", $1, $2, $3, $4, $5, $6}'
    
    # Red
    echo -e "\n${WHITE}Red:${NC}"
    ip -br addr | awk '{printf "  %-10s %-15s %s\n", $1, $2, $3}'
    
    echo -e "\n${PURPLE}══════════════════════════════════════${NC}\n"
}

# Función para formatear tamaños
format_size() {
    local size=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    while (( size > 1024 && unit < ${#units[@]} - 1 )); do
        size=$(( size / 1024 ))
        (( unit++ ))
    done
    
    printf "%d %s" "$size" "${units[$unit]}"
}

# Función mejorada para ejecutar comandos con logging
execute_with_log() {
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
}

# Función para mostrar menús interactivos
show_menu() {
    local title="$1"
    shift
    local options=("$@")
    
    echo -e "\n${PURPLE}${BOLD}$title${NC}"
    echo -e "${PURPLE}$(printf '%*s' "${#title}" '' | tr ' ' '═')${NC}\n"
    
    for i in "${!options[@]}"; do
        echo -e "${PRIMARY}$((i+1)). ${CYAN}${options[$i]}${NC}"
    done
    
    echo -e "\n${YELLOW}Seleccione una opción (1-${#options[@]}): ${NC}"
}

# Función para mostrar progreso
show_progress() {
    local current="$1"
    local total="$2"
    local width=50
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r${CYAN}[${NC}"
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "${CYAN}] %3d%%${NC}" "$percent"
}

# Inicialización del script
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
    
    # Verificar dependencias
    check_dependencies
    
    # Mostrar información inicial
    log "INFO" "Iniciando ZeuspyEC Arch Linux Installer v${SCRIPT_VERSION}"
    print_system_info
}

# ==============================================================================
# Funciones de Verificación y Preparación del Sistema
# ==============================================================================

check_dependencies() {
    log "INFO" "Verificando dependencias del sistema"
    
    local deps=(
        "parted"
        "mkfs.fat"
        "mkfs.ext4"
        "arch-chroot"
        "iwctl"
        "ping"
    )
    
    local missing_deps=()
    
    echo -e "\n${PURPLE}Verificando dependencias requeridas:${NC}\n"
    
    for dep in "${deps[@]}"; do
        echo -ne "${CYAN}Verificando $dep... ${NC}"
        if command -v "$dep" >/dev/null 2>&1; then
            echo -e "${GREEN}✔${NC}"
        else
            echo -e "${ERROR}✘${NC}"
            missing_deps+=("$dep")
        fi
    done
    
    if ((${#missing_deps[@]} > 0)); then
        log "ERROR" "Faltan las siguientes dependencias: ${missing_deps[*]}"
        return 1
    fi
    
    log "SUCCESS" "Todas las dependencias están instaladas"
    return 0
}

check_system_requirements() {
    log "INFO" "Verificando requisitos del sistema"
    
    # Verificar arquitectura
    local arch
    arch=$(uname -m)
    echo -ne "\n${CYAN}Verificando arquitectura... ${NC}"
    if [[ "$arch" != "x86_64" ]]; then
        echo -e "${COLORS}✘${NC}"
        log "ERROR" "Arquitectura no soportada: $arch"
        return 1
    fi
    echo -e "${GREEN}✔${NC}"
    
    # Verificar modo de arranque
    echo -ne "${CYAN}Verificando modo de arranque... ${NC}"
    if [[ -d "/sys/firmware/efi/efivars" ]]; then
        BOOT_MODE="UEFI"
        echo -e "${GREEN}UEFI${NC}"
    else
        BOOT_MODE="BIOS"
        echo -e "${GREEN}BIOS${NC}"
    fi
    
    # Verificar memoria
    local min_ram=512  # 512MB mínimo
    local total_ram
    total_ram=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    
    echo -ne "${CYAN}Verificando memoria RAM... ${NC}"
    if ((total_ram < min_ram)); then
        echo -e "${ERROR}✘${NC}"
        log "ERROR" "RAM insuficiente: ${total_ram}MB < ${min_ram}MB"
        return 1
    fi
    echo -e "${GREEN}✔ ${total_ram}MB${NC}"
    
    # Verificar espacio en disco
    verify_disk_space
    
    return 0
}

verify_disk_space() {
    log "INFO" "Verificando espacio en disco disponible"
    
    local min_space=$((15 * 1024 * 1024 * 1024)) # 15GB en bytes
    local disk_list
    disk_list=$(lsblk -dpno NAME,SIZE,TYPE,MODEL | grep disk)
    
    echo -e "\n${PURPLE}Discos disponibles:${NC}\n"
    
    if [[ -z "$disk_list" ]]; then
        log "ERROR" "No se encontraron discos disponibles"
        return 1
    fi
    
    # Mostrar información de discos disponibles
    local disk_count=0
    local valid_disks=()
    while IFS= read -r disk_info; do
        ((disk_count++))
        local disk_name=$(echo "$disk_info" | awk '{print $1}')
        local disk_size=$(blockdev --getsize64 "$disk_name" 2>/dev/null)
        local disk_model=$(echo "$disk_info" | awk '{$1=$2=$3=""; print $0}' | xargs)
        
        if ((disk_size >= min_space)); then
            echo -e "${GREEN}$disk_count. $disk_name - $(numfmt --to=iec --suffix=B "$size") - $disk_model${NC}"
            valid_disks+=("$disk_name")
        else
            echo -e "${ERROR}$disk_count. $disk_name - $(numfmt --to=iec --suffix=B "$size") - $disk_model (Espacio insuficiente)${NC}"
        fi
    done <<< "$disk_list"
    
    if ((${#valid_disks[@]} == 0)); then
        log "ERROR" "No se encontró ningún disco con suficiente espacio (mínimo 15GB)"
        return 1
    fi
    
    return 0
}

check_network_connectivity() {
    log "INFO" "Verificando conectividad de red"
    
    local test_hosts=("archlinux.org" "google.com" "cloudflare.com")
    local connected=false
    
    echo -e "\n${PURPLE}Probando conectividad:${NC}\n"
    
    for host in "${test_hosts[@]}"; do
        echo -ne "${INFO]}Probando conexión a $host... ${NC}"
        if ping -c 1 -W 5 "$host" &>/dev/null; then
            echo -e "${GREEN}✔${NC}"
            connected=true
            break
        else
            echo -e "${ERROR}✘${NC}"
        fi
    done
    
    if ! $connected; then
        log "WARN" "No hay conexión a Internet. Intentando configurar red..."
        setup_network_connection
        return $?
    fi
    
    log "SUCCESS" "Conectividad de red verificada"
    return 0
}

setup_network_connection() {
    log "INFO" "Configurando conexión de red"
    
    show_menu "Tipo de Conexión" \
        "Conexión Wi-Fi" \
        "Conexión Ethernet" \
        "Salir"
    
    read -r option
    
    case $option in
        1) setup_wifi_connection ;;
        2) setup_ethernet_connection ;;
        3) return 1 ;;
        *) log "ERROR" "Opción inválida"; return 1 ;;
    esac
}

setup_wifi_connection() {
    log "INFO" "Configurando conexión Wi-Fi"
    
    local wireless_interfaces
    wireless_interfaces=($(iwctl device list 2>/dev/null | grep -oE "wlan[0-9]"))
    
    if ((${#wireless_interfaces[@]} == 0)); then
        log "ERROR" "No se detectaron interfaces wireless"
        return 1
    fi
    
    echo -e "\n${PURPLE}Interfaces Wi-Fi disponibles:${NC}\n"
    for i in "${!wireless_interfaces[@]}"; do
        echo -e "${PRIMARY}$((i+1)). ${wireless_interfaces[$i]}${NC}"
    done
    
    echo -e "\n${YELLOW}Seleccione una interfaz (1-${#wireless_interfaces[@]}): ${NC}"
    read -r interface_number
    
    if ! [[ "$interface_number" =~ ^[0-9]+$ ]] || \
       ((interface_number < 1 || interface_number > ${#wireless_interfaces[@]})); then
        log "ERROR" "Selección inválida"
        return 1
    fi
    
    local selected_interface=${wireless_interfaces[$((interface_number-1))]}
    
    # Escanear redes
    log "INFO" "Escaneando redes disponibles..."
    iwctl station "$selected_interface" scan
    sleep 2
    
    # Mostrar redes
    echo -e "\n${PURPLE}Redes disponibles:${NC}\n"
    iwctl station "$selected_interface" get-networks
    
    # Solicitar datos de conexión
    echo -e "\n${YELLOW}Ingrese el nombre de la red (SSID): ${NC}"
    read -r ssid
    
    echo -e "${YELLOW}Ingrese la contraseña: ${NC}"
    read -rs password
    
    echo -e "\n${CYAN}Conectando a $ssid...${NC}"
    
    if iwctl station "$selected_interface" connect "$ssid" --passphrase "$password"; then
        sleep 3
        if ping -c 1 archlinux.org &>/dev/null; then
            log "SUCCESS" "Conexión Wi-Fi establecida exitosamente"
            return 0
        fi
    fi
    
    log "ERROR" "No se pudo establecer la conexión Wi-Fi"
    return 1
}

setup_ethernet_connection() {
    log "INFO" "Configurando conexión ethernet"
    
    local ethernet_interfaces
    ethernet_interfaces=($(ip -br addr show | grep -E "^[0-9]+: en|^[0-9]+: eth" | cut -d: -f2))
    
    if ((${#ethernet_interfaces[@]} == 0)); then
        log "ERROR" "No se detectaron interfaces ethernet"
        return 1
    fi
    
    echo -e "\n${PURPLE}Interfaces Ethernet disponibles:${NC}\n"
    
    for interface in "${ethernet_interfaces[@]}"; do
        interface=$(echo "$interface" | tr -d ' ')
        echo -ne "${CYAN}Configurando $interface... ${NC}"
        
        ip link set "$interface" up
        if dhcpcd "$interface"; then
            sleep 3
            if ping -c 1 archlinux.org &>/dev/null; then
                echo -e "${GREEN}✔${NC}"
                log "SUCCESS" "Conexión ethernet establecida"
                return 0
            fi
        fi
        echo -e "${ERROR}✘${NC}"
    done
    
    log "ERROR" "No se pudo establecer conexión ethernet"
    return 1
}

# ==============================================================================
# Funciones de Particionamiento e Instalación
# ==============================================================================

prepare_disk() {
    log "INFO" "Preparando disco para instalación"
    
    # Seleccionar disco
    select_installation_disk
    
    # Verificar si hay sistemas operativos existentes
    check_existing_os
    
    # Mostrar advertencia de borrado
    show_warning_message
    
    # Crear particiones según el modo de arranque
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        create_uefi_partitions
    else
        create_bios_partitions
    fi
    
    # Verificar particiones creadas
    verify_partitions
    
    return 0
}

select_installation_disk() {
    local disk_list
    disk_list=$(lsblk -o NAME,SIZE,TYPE,MOUNTPOINT --noheadings | grep disk)
    
    echo -e "\n${PURPLE}Discos disponibles para instalación:${NC}\n"
    
    local disk_array=()
    while IFS= read -r disk_info; do
        disk_array+=("$disk_info")
        local number=$((${#disk_array[@]}))
        echo -e "${PRIMARY}$number. ${CYAN}$disk_info${NC}"
    done <<< "$disk_list"
    
    while true; do
        echo -e "\n${YELLOW}Seleccione el disco para la instalación (1-${#disk_array[@]}): ${NC}"
        read -r selection
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && ((selection > 0 && selection <= ${#disk_array[@]})); then
            TARGET_DISK=$(echo "${disk_array[$((selection-1))]}" | awk '{print $1}')
            break
        fi
        echo -e "${ERROR}Selección inválida${NC}"
    done
    
    log "INFO" "Disco seleccionado: $TARGET_DISK"
}

check_existing_os() {
    echo -e "\n${PURPLE}Verificando sistemas operativos existentes:${NC}\n"
    
    if command -v os-prober &>/dev/null; then
        local existing_os
        existing_os=$(os-prober | grep "$TARGET_DISK" || true)
        
        if [[ -n "$existing_os" ]]; then
            echo -e "${WARNING}¡Se encontraron los siguientes sistemas operativos!${NC}"
            echo -e "$existing_os" | while IFS= read -r os; do
                echo -e "${WARNING}► $os${NC}"
            done
        else
            echo -e "${CYAN}No se encontraron otros sistemas operativos${NC}"
        fi
    fi
}

show_warning_message() {
    echo -e "\n${ERROR}¡ADVERTENCIA!${NC}"
    echo -e "${ERROR}Esta operación eliminará TODOS los datos en $TARGET_DISK${NC}"
    echo -e "${ERROR}Esta acción NO se puede deshacer${NC}\n"
    
    while true; do
        echo -e "${YELLOW}¿Está seguro que desea continuar? (si/NO): ${NC}"
        read -r response
        
        case "$response" in
            [Ss][Ii]) break ;;
            [Nn][Oo]|"") log "INFO" "Operación cancelada por el usuario"; exit 1 ;;
            *) echo -e "${ERROR}Por favor responda 'si' o 'no'${NC}" ;;
        esac
    done
}

create_uefi_partitions() {
    log "INFO" "Creando particiones UEFI"
    
    # Calcular tamaños
    local disk_size
    disk_size=$(blockdev --getsize64 "$TARGET_DISK" | awk '{print int($1/1024/1024)}')  # MB
    local efi_size=512
    local swap_size
    swap_size=$(free -m | awk '/^Mem:/ {print int($2)}')
    local root_size=$((disk_size - efi_size - swap_size))
    
    echo -e "\n${PURPLE}Esquema de particionamiento:${NC}"
    echo -e "${CYAN}• Partición EFI: ${efi_size}MB${NC}"
    echo -e "${CYAN}• Partición ROOT: ${root_size}MB${NC}"
    echo -e "${CYAN}• Partición SWAP: ${swap_size}MB${NC}\n"
    
    # Crear tabla GPT
    log "INFO" "Creando tabla de particiones GPT"
    if ! parted -s "$TARGET_DISK" mklabel gpt; then
        log "ERROR" "Fallo al crear tabla GPT"
        return 1
    fi
    
    # Crear particiones con barra de progreso
    echo -ne "${CYAN}Creando particiones...${NC}"
    
    # EFI
    if ! parted -s "$TARGET_DISK" \
        mkpart "EFI" fat32 1MiB "${efi_size}MiB" \
        set 1 esp on; then
        echo -e "${ERROR}✘${NC}"
        log "ERROR" "Fallo al crear partición EFI"
        return 1
    fi
    show_progress 1 3
    
    # ROOT
    if ! parted -s "$TARGET_DISK" \
        mkpart "ROOT" ext4 "${efi_size}MiB" "$((efi_size + root_size))MiB"; then
        echo -e "${ERROR}✘${NC}"
        log "ERROR" "Fallo al crear partición ROOT"
        return 1
    fi
    show_progress 2 3
    
    # SWAP
    if ! parted -s "$TARGET_DISK" \
        mkpart "SWAP" linux-swap "$((efi_size + root_size))MiB" 100%; then
        echo -e "${ERROR}✘${NC}"
        log "ERROR" "Fallo al crear partición SWAP"
        return 1
    fi
    show_progress 3 3
    echo -e "${GREEN}✔${NC}"
    
    # Esperar a que el kernel detecte las nuevas particiones
    sleep 2
    
    # Obtener nombres de las particiones
    local efi_part="${TARGET_DISK}1"
    local root_part="${TARGET_DISK}2"
    local swap_part="${TARGET_DISK}3"
    
    # Formatear particiones
    echo -e "\n${PURPLE}Formateando particiones:${NC}"
    
    echo -ne "${CYAN}Formateando partición EFI... ${NC}"
    if ! mkfs.fat -F32 "$efi_part"; then
        echo -e "${ERROR}✘${NC}"
        log "ERROR" "Fallo al formatear partición EFI"
        return 1
    fi
    echo -e "${GREEN}✔${NC}"
    
    echo -ne "${CYAN}Formateando partición ROOT... ${NC}"
    if ! mkfs.ext4 -F "$root_part"; then
        echo -e "${ERROR}✘${NC}"
        log "ERROR" "Fallo al formatear partición ROOT"
        return 1
    fi
    echo -e "${GREEN}✔${NC}"
    
    echo -ne "${CYAN}Formateando partición SWAP... ${NC}"
    if ! mkswap "$swap_part"; then
        echo -e "${ERROR}✘${NC}"
        log "ERROR" "Fallo al formatear partición SWAP"
        return 1
    fi
    if ! swapon "$swap_part"; then
        echo -e "${ERROR}✘${NC}"
        log "ERROR" "Fallo al activar SWAP"
        return 1
    fi
    echo -e "${GREEN}✔${NC}"
    
    # Montar particiones
    echo -e "\n${PURPLE}Montando particiones:${NC}"
    
    echo -ne "${CYAN}Montando partición ROOT... ${NC}"
    if ! mount "$root_part" /mnt; then
        echo -e "${ERROR}✘${NC}"
        log "ERROR" "Fallo al montar partición ROOT"
        return 1
    fi
    echo -e "${GREEN}✔${NC}"
    
    echo -ne "${CYAN}Creando y montando directorio EFI... ${NC}"
    if ! mkdir -p /mnt/boot/efi; then
        echo -e "${ERROR}✘${NC}"
        log "ERROR" "Fallo al crear directorio EFI"
        return 1
    fi
    if ! mount "$efi_part" /mnt/boot/efi; then
        echo -e "${ERROR}✘${NC}"
        log "ERROR" "Fallo al montar partición EFI"
        return 1
    fi
    echo -e "${GREEN}✔${NC}"
    
    log "SUCCESS" "Particionamiento UEFI completado exitosamente"
    return 0
}

create_bios_partitions() {
    log "INFO" "Creando particiones BIOS"
    
    # Calcular tamaños
    local disk_size
    disk_size=$(blockdev --getsize64 "$TARGET_DISK" | awk '{print int($1/1024/1024)}')  # MB
    local boot_size=512
    local swap_size
    swap_size=$(free -m | awk '/^Mem:/ {print int($2)}')
    local root_size=$((disk_size - boot_size - swap_size))
    
    echo -e "\n${PURPLE}Esquema de particionamiento:${NC}"
    echo -e "${CYAN}• Partición BOOT: ${boot_size}MB${NC}"
    echo -e "${CYAN}• Partición ROOT: ${root_size}MB${NC}"
    echo -e "${CYAN}• Partición SWAP: ${swap_size}MB${NC}\n"
    
    # Crear tabla MBR
    log "INFO" "Creando tabla de particiones MBR"
    if ! parted -s "$TARGET_DISK" mklabel msdos; then
        log "ERROR" "Fallo al crear tabla MBR"
        return 1
    fi
    
    # Crear particiones con barra de progreso
    echo -ne "${CYAN}Creando particiones...${NC}"
    
    # BOOT
    if ! parted -s "$TARGET_DISK" \
        mkpart primary ext4 1MiB "${boot_size}MiB" \
        set 1 boot on; then
        echo -e "${ERROR}✘${NC}"
        log "ERROR" "Fallo al crear partición BOOT"
        return 1
    fi
    show_progress 1 3
    
    # ROOT
    if ! parted -s "$TARGET_DISK" \
        mkpart primary ext4 "${boot_size}MiB" "$((boot_size + root_size))MiB"; then
        echo -e "${ERROR}✘${NC}"
        log "ERROR" "Fallo al crear partición ROOT"
        return 1
    fi
    show_progress 2 3
    
    # SWAP
    if ! parted -s "$TARGET_DISK" \
        mkpart primary linux-swap "$((boot_size + root_size))MiB" 100%; then
        echo -e "${ERROR}✘${NC}"
        log "ERROR" "Fallo al crear partición SWAP"
        return 1
    fi
    show_progress 3 3
    echo -e "${GREEN}✔${NC}"
    
    # Esperar a que el kernel detecte las nuevas particiones
    sleep 2
    
    # Obtener nombres de las particiones
    local boot_part="${TARGET_DISK}1"
    local root_part="${TARGET_DISK}2"
    local swap_part="${TARGET_DISK}3"
    
    # Formatear particiones
    echo -e "\n${PURPLE}Formateando particiones:${NC}"
    
    echo -ne "${CYAN}Formateando partición BOOT... ${NC}"
    if ! mkfs.ext4 -F "$boot_part"; then
        echo -e "${ERROR}✘${NC}"
        log "ERROR" "Fallo al formatear partición BOOT"
        return 1
    fi
    echo -e "${GREEN}✔${NC}"
    
    echo -ne "${CYAN}Formateando partición ROOT... ${NC}"
    if ! mkfs.ext4 -F "$root_part"; then
        echo -e "${ERROR}✘${NC}"
        log "ERROR" "Fallo al formatear partición ROOT"
        return 1
    fi
    echo -e "${GREEN}✔${NC}"
    
    echo -ne "${CYAN}Formateando partición SWAP... ${NC}"
    if ! mkswap "$swap_part"; then
        echo -e "${ERROR}✘${NC}"
        log "ERROR" "Fallo al formatear partición SWAP"
        return 1
    fi
    if ! swapon "$swap_part"; then
        echo -e "${ERROR}✘${NC}"
        log "ERROR" "Fallo al activar SWAP"
        return 1
    fi
    echo -e "${GREEN}✔${NC}"
    
    # Montar particiones
    echo -e "\n${PURPLE}Montando particiones:${NC}"
    
    echo -ne "${CYAN}Montando partición ROOT... ${NC}"
    if ! mount "$root_part" /mnt; then
        echo -e "${ERROR}✘${NC}"
        log "ERROR" "Fallo al montar partición ROOT"
        return 1
    fi
    echo -e "${GREEN}✔${NC}"
    
    echo -ne "${CYAN}Creando y montando directorio BOOT... ${NC}"
    if ! mkdir -p /mnt/boot; then
        echo -e "${ERROR}✘${NC}"
        log "ERROR" "Fallo al crear directorio BOOT"
        return 1
    fi
    if ! mount "$boot_part" /mnt/boot; then
        echo -e "${ERROR}✘${NC}"
        log "ERROR" "Fallo al montar partición BOOT"
        return 1
    fi
    echo -e "${GREEN}✔${NC}"
    
    log "SUCCESS" "Particionamiento BIOS completado exitosamente"
    return 0
}

verify_partitions() {
    log "INFO" "Verificando particiones creadas"
    
    echo -e "\n${PURPLE}Particiones creadas:${NC}\n"
    lsblk "$TARGET_DISK" -o NAME,SIZE,TYPE,MOUNTPOINT
    
    # Verificar puntos de montaje
    if ! mountpoint -q /mnt; then
        log "ERROR" "Punto de montaje ROOT no está montado correctamente"
        return 1
    fi
    
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        if ! mountpoint -q /mnt/boot/efi; then
            log "ERROR" "Punto de montaje EFI no está montado correctamente"
            return 1
        fi
    else
        if ! mountpoint -q /mnt/boot; then
            log "ERROR" "Punto de montaje BOOT no está montado correctamente"
            return 1
        fi
    fi
    
    # Verificar swap
    if ! swapon --show | grep -q "$TARGET_DISK"; then
        log "ERROR" "SWAP no está activado correctamente"
        return 1
    fi
    
    log "SUCCESS" "Verificación de particiones completada"
    return 0
}

# ==============================================================================
# Funciones de Instalación Base y Configuración del Sistema
# ==============================================================================

install_base_system() {
    log "INFO" "Iniciando instalación del sistema base"
    
    # Actualizar mirrors
    update_mirrors
    
    # Instalar sistema base
    echo -e "\n${PURPLE}Instalando paquetes base:${NC}\n"
    local total_packages=${#REQUIRED_PACKAGES[@]}
    local current=0
    
    for package in "${REQUIRED_PACKAGES[@]}"; do
        ((current++))
        echo -ne "${CYAN}Instalando $package... ${NC}"
        if pacstrap /mnt "$package" &>/dev/null; then
            echo -e "${GREEN}✔${NC}"
        else
            echo -e "${ERROR}✘${NC}"
            log "ERROR" "Fallo al instalar $package"
            return 1
        fi
        show_progress "$current" "$total_packages"
        echo
    done
    
    # Generar fstab
    echo -ne "\n${CYAN}Generando fstab... ${NC}"
    if ! genfstab -U /mnt >> /mnt/etc/fstab; then
        echo -e "${ERROR}✘${NC}"
        log "ERROR" "Fallo al generar fstab"
        return 1
    fi
    echo -e "${GREEN}✔${NC}"
    
    # Verificar fstab
    if ! grep -q "UUID" /mnt/etc/fstab; then
        log "ERROR" "fstab generado incorrectamente"
        return 1
    fi
    
    log "SUCCESS" "Sistema base instalado correctamente"
    return 0
}

update_mirrors() {
    log "INFO" "Actualizando lista de mirrors"
    
    echo -ne "${CYAN}Respaldando mirrorlist actual... ${NC}"
    if ! cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup; then
        echo -e "${ERROR}✘${NC}"
        log "ERROR" "Fallo al respaldar mirrorlist"
        return 1
    fi
    echo -e "${GREEN}✔${NC}"
    
    if command -v reflector &>/dev/null; then
        echo -ne "${CYAN}Optimizando mirrors con reflector... ${NC}"
        if reflector --latest 20 \
                    --protocol https \
                    --sort rate \
                    --save /etc/pacman.d/mirrorlist &>/dev/null; then
            echo -e "${GREEN}✔${NC}"
        else
            echo -e "${ERROR}✘${NC}"
            log "WARN" "Fallo al optimizar mirrors, usando lista por defecto"
        fi
    else
        log "WARN" "reflector no está instalado, usando mirrors por defecto"
    fi
    
    return 0
}

configure_system() {
    log "INFO" "Iniciando configuración del sistema"
    
    local config_functions=(
        "configure_hostname"
        "configure_timezone"
        "configure_locale"
        "configure_users"
        "configure_network"
        "configure_bootloader"
    )
    
    local total_steps=${#config_functions[@]}
    local current=0
    
    for func in "${config_functions[@]}"; do
        ((current++))
        echo -e "\n${PURPLE}[${current}/${total_steps}] Ejecutando: ${func//_/ }${NC}"
        if ! $func; then
            log "ERROR" "Fallo en $func"
            return 1
        fi
        show_progress "$current" "$total_steps"
        echo
    done
    
    log "SUCCESS" "Configuración del sistema completada"
    return 0
}

configure_hostname() {
    echo -e "${YELLOW}Ingrese el hostname para el sistema: ${NC}"
    while true; do
        read -r HOSTNAME
        
        if [[ "$HOSTNAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
            break
        else
            echo -e "${ERROR}Hostname inválido. Use solo letras, números y guiones${NC}"
            echo -e "${YELLOW}Intente nuevamente: ${NC}"
        fi
    done
    
    # Configurar hostname
    echo "$HOSTNAME" > /mnt/etc/hostname
    
    # Configurar hosts
    cat > /mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF
    
    log "SUCCESS" "Hostname configurado: $HOSTNAME"
    return 0
}

configure_timezone() {
    local zones
    zones=($(find /usr/share/zoneinfo -type f -not -path '*/right/*' -not -path '*/posix/*' -printf '%P\n' | sort))
    
    echo -e "\n${PURPLE}Zonas horarias disponibles:${NC}\n"
    
    select TIMEZONE in "${zones[@]}"; do
        if [[ -n "$TIMEZONE" ]]; then
            break
        fi
        echo -e "${ERROR}Selección inválida${NC}"
    done
    
    echo -ne "${CYAN}Configurando zona horaria $TIMEZONE... ${NC}"
    if ! arch-chroot /mnt ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime; then
        echo -e "${ERROR}✘${NC}"
        return 1
    fi
    
    if ! arch-chroot /mnt hwclock --systohc; then
        echo -e "${ERROR}✘${NC}"
        return 1
    fi
    echo -e "${GREEN}✔${NC}"
    
    return 0
}

configure_locale() {
    echo -ne "${CYAN}Configurando locales... ${NC}"
    
    # Habilitar locales necesarios
    sed -i 's/#\(en_US.UTF-8\)/\1/' /mnt/etc/locale.gen
    sed -i 's/#\(es_ES.UTF-8\)/\1/' /mnt/etc/locale.gen
    
    # Generar locales
    if ! arch-chroot /mnt locale-gen; then
        echo -e "${ERROR}✘${NC}"
        return 1
    fi
    
    # Configurar idioma predeterminado
    echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
    echo "KEYMAP=es" > /mnt/etc/vconsole.conf
    
    echo -e "${GREEN}✔${NC}"
    return 0
}

configure_users() {
    # Configurar root
    echo -e "\n${PURPLE}Configuración de contraseña root${NC}"
    while ! arch-chroot /mnt passwd; do
        echo -e "${ERROR}Error al configurar contraseña root. Intente nuevamente${NC}"
    done
    
    # Crear usuario normal
    echo -e "\n${PURPLE}Creación de usuario normal${NC}"
    echo -e "${YELLOW}Ingrese nombre para el nuevo usuario: ${NC}"
    while true; do
        read -r USERNAME
        
        if [[ "$USERNAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
            break
        else
            echo -e "${ERROR}Nombre de usuario inválido. Use letras minúsculas, números y guiones${NC}"
            echo -e "${YELLOW}Intente nuevamente: ${NC}"
        fi
    done
    
    # Crear usuario y agregar a grupos
    if ! arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$USERNAME"; then
        log "ERROR" "Fallo al crear usuario"
        return 1
    fi
    
    # Configurar contraseña del usuario
    echo -e "\n${PURPLE}Configuración de contraseña para $USERNAME${NC}"
    while ! arch-chroot /mnt passwd "$USERNAME"; do
        echo -e "${ERROR}Error al configurar contraseña. Intente nuevamente${NC}"
    done
    
    # Configurar sudo
    echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/wheel
    chmod 440 /mnt/etc/sudoers.d/wheel
    
    log "SUCCESS" "Usuarios configurados correctamente"
    return 0
}

configure_network() {
    echo -ne "${CYAN}Habilitando NetworkManager... ${NC}"
    if ! arch-chroot /mnt systemctl enable NetworkManager; then
        echo -e "${ERROR}✘${NC}"
        return 1
    fi
    echo -e "${GREEN}✔${NC}"
    return 0
}

configure_bootloader() {
    log "INFO" "Instalando y configurando bootloader"
    
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        echo -ne "${CYAN}Instalando GRUB para UEFI... ${NC}"
        if ! arch-chroot /mnt grub-install --target=x86_64-efi \
                                         --efi-directory=/boot/efi \
                                         --bootloader-id=GRUB; then
            echo -e "${ERROR}✘${NC}"
            return 1
        fi
    else
        echo -ne "${CYAN}Instalando GRUB para BIOS... ${NC}"
        if ! arch-chroot /mnt grub-install --target=i386-pc "$TARGET_DISK"; then
            echo -e "${ERROR}✘${NC}"
            return 1
        fi
    fi
    echo -e "${GREEN}✔${NC}"
    
    # Configurar GRUB
    sed -i 's/#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /mnt/etc/default/grub
    
    echo -ne "${CYAN}Generando configuración de GRUB... ${NC}"
    if ! arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg; then
        echo -e "${ERROR}✘${NC}"
        return 1
    fi
    echo -e "${GREEN}✔${NC}"
    
    return 0
}

cleanup() {
    log "INFO" "Realizando limpieza final"
    
    echo -ne "${CYAN}Desmontando particiones... ${NC}"
    
    # Desmontar en orden inverso
    if mountpoint -q /mnt/boot/efi; then
        umount -R /mnt/boot/efi
    fi
    if mountpoint -q /mnt/boot; then
        umount -R /mnt/boot
    fi
    if mountpoint -q /mnt; then
        umount -R /mnt
    fi
    
    # Desactivar swap
    swapoff -a
    
    echo -e "${GREEN}✔${NC}"
    log "SUCCESS" "Limpieza completada"
}

# Función principal mejorada
main() {
    local start_time
    start_time=$(date +%s)
    
    # Inicializar script
    init_script
    
    # Pasos de instalación
    local installation_steps=(
        "check_system_requirements"
        "check_network_connectivity"
        "prepare_disk"
        "install_base_system"
        "configure_system"
    )
    
    # Ejecutar pasos de instalación con progreso
    local total_steps=${#installation_steps[@]}
    local current=0
    
    for step in "${installation_steps[@]}"; do
        ((current++))
        echo -e "\n${HEADER}[${current}/${total_steps}] ${step//_/ }${NC}"
        if ! $step; then
            log "ERROR" "Instalación fallida en: $step"
            cleanup
            exit 1
        fi
        show_progress "$current" "$total_steps"
        echo
    done
    
    # Calcular tiempo de instalación
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    # Mostrar resumen de instalación
    echo -e "\n${PURPLE}Resumen de la Instalación${NC}"
    echo -e "${GREEN}✔ Instalación completada exitosamente${NC}"
    echo -e "${CYAN}• Tiempo total: ${minutes}m ${seconds}s${NC}"
    echo -e "${CYAN}• Hostname: $HOSTNAME${NC}"
    echo -e "${CYAN}• Usuario: $USERNAME${NC}"
    echo -e "${CYAN}• Zona horaria: $TIMEZONE${NC}"
    
    # Preguntar por reinicio
    echo -e "\n${YELLOW}¿Desea reiniciar el sistema ahora? (si/NO): ${NC}"
    read -r reboot_choice
    
    if [[ "$reboot_choice" =~ ^[Ss][Ii]$ ]]; then
        log "INFO" "Reiniciando sistema"
        cleanup
        reboot
    else
        log "INFO" "Reinicio pospuesto"
        cleanup
        echo -e "${WARNING}Recuerde reiniciar el sistema cuando esté listo${NC}"
    fi
}

# Iniciar instalación solo si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
    echo -e "${ERROR}Este script debe ejecutarse como root${NC}"
    exit 1
fi

main "$@"
