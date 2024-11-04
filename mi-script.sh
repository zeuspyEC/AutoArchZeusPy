#!/usr/bin/env bash

# ==============================================================================
# ZeuspyEC Arch Linux Installer
# Versión: 3.0.1
# ==============================================================================

# Habilitar modo estricto
set -euo pipefail
IFS=$'\n\t'

# Variables de colores y estilos
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'  
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'  # No Color
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

# Archivos de log
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

# Función de logging mejorada
log() {
    local level="${1}"
    shift
    local message="${*}"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local function_name="${FUNCNAME[1]:-main}"
    local line_number="${BASH_LINENO[0]}"
    
    local log_entry="[${timestamp}] [${level}] [${function_name}:${line_number}] ${message}"
    
    case "${level}" in
        "DEBUG")
            echo -e "${CYAN}${log_entry}${NC}" >> "${DEBUG_LOG}"
            ;;
        "INFO") 
            echo -e "${GREEN}${log_entry}${NC}" | tee -a "${LOG_FILE}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}✔ ${log_entry}${NC}" | tee -a "${LOG_FILE}"
            ;;
        "WARN")
            echo -e "${YELLOW}⚠ ${log_entry}${NC}" | tee -a "${LOG_FILE}"
            ;;
        "ERROR")
            echo -e "${RED}✘ ${log_entry}${NC}" | tee -a "${ERROR_LOG}"
            print_system_info >> "${ERROR_LOG}"
            ;;
    esac
}

# Función para mostrar el banner
display_banner() {
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
    echo -e "${NC}"  
    echo -e "${GREEN}Version ${SCRIPT_VERSION} - By ZeuspyEC ~ https://github.com/zeuspyEC/${NC}\n"
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

# Función para verificar dependencias
check_dependencies() {
    log "INFO" "Verificando dependencias del sistema"
    
    local deps=(
        "parted"
        "mkfs.fat"
        "mkfs.ext4"
        "arch-chroot"
        "iwctl"
        "ping"
        "locale-gen"
    )
    
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if ((${#missing_deps[@]} > 0)); then
        echo -e "\n${ERROR}Faltan las siguientes dependencias:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo -e "${ERROR}• $dep${NC}"
        done
        echo ""
        return 1
    fi
    
    log "SUCCESS" "Todas las dependencias están instaladas"
    return 0
}

# Función para ejecutar comandos con logging
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

# Función de inicialización del script
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
# Funciones de Verificación del Sistema y Red
# ==============================================================================

check_system_requirements() {
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
    local arch
    arch=$(uname -m)
    echo -ne "\n${CYAN}Verificando arquitectura... ${NC}"
    if [[ "$arch" != "x86_64" ]]; then
        echo -e "${ERROR}✘${NC}"
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
    echo -ne "${CYAN}Verificando memoria RAM... ${NC}"
    local total_ram
    total_ram=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    
    if ((total_ram < min_ram)); then
        echo -e "${ERROR}✘${NC}"
        log "ERROR" "RAM insuficiente: ${total_ram}MB < ${min_ram}MB"
        return 1
    fi
    echo -e "${GREEN}✔ ${total_ram}MB${NC}"
    
    # Verificar espacio en disco
    if ! verify_disk_space "$min_disk"; then
        return 1
    fi
    
    log "SUCCESS" "Sistema cumple con los requisitos mínimos"
    return 0
}

check_network_connectivity() {
    log "INFO" "Verificando conectividad de red"
    
    # Comprobar interfaces de red
    echo -ne "${CYAN}Verificando interfaces de red... ${NC}"
    if ! ip link show &>/dev/null; then
        echo -e "${ERROR}✘${NC}"
        log "ERROR" "No se detectaron interfaces de red"
        return 1
    fi
    echo -e "${GREEN}✔${NC}"
    
    local test_hosts=("archlinux.org" "google.com" "cloudflare.com")
    local connected=false
    
    echo -e "\n${PURPLE}Probando conectividad:${NC}\n"
    
    # Probar conexión a hosts conocidos
    for host in "${test_hosts[@]}"; do
        echo -ne "${INFO}Probando conexión a $host... ${NC}"
        if ping -c 1 -W 5 "$host" &>/dev/null; then
            echo -e "${GREEN}✔${NC}"
            connected=true
            break
        else
            echo -e "${ERROR}✘${NC}"
        fi
    done
    
    # Si no hay conexión, intentar configurarla
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
        
    local option
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
    echo -e "\n${PURPLE}Interfaces Wi-Fi disponibles:${NC}\n"
    for i in "${!wireless_interfaces[@]}"; do
        echo -e "${PRIMARY}$((i+1)). ${wireless_interfaces[$i]}${NC}"
    done
    
    # Seleccionar interfaz
    echo -e "\n${YELLOW}Seleccione una interfaz (1-${#wireless_interfaces[@]}): ${NC}"
    local interface_number
    read -r interface_number
    
    if ! [[ "$interface_number" =~ ^[0-9]+$ ]] || \
       ((interface_number < 1 || interface_number > ${#wireless_interfaces[@]})); then
        log "ERROR" "Selección inválida"
        return 1
    fi
    
    local selected_interface=${wireless_interfaces[$((interface_number-1))]}
    
    # Escanear y mostrar redes
    log "INFO" "Escaneando redes disponibles..."
    iwctl station "$selected_interface" scan
    sleep 2
    
    echo -e "\n${PURPLE}Redes disponibles:${NC}\n"
    iwctl station "$selected_interface" get-networks
    
    # Solicitar datos de conexión
    echo -e "\n${YELLOW}Ingrese el nombre de la red (SSID): ${NC}"
    local ssid
    read -r ssid
    
    echo -e "${YELLOW}Ingrese la contraseña: ${NC}"
    local password
    read -rs password
    
    # Intentar conexión
    echo -e "\n${CYAN}Conectando a $ssid...${NC}"
    
    if iwctl station "$selected_interface" connect "$ssid" --passphrase "$password"; then
        sleep 3
        # Verificar conexión
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
    
    # Obtener interfaces ethernet
    local ethernet_interfaces
    ethernet_interfaces=($(ip -br addr show | grep -E "^[0-9]+: en|^[0-9]+: eth" | cut -d: -f2))
    
    if ((${#ethernet_interfaces[@]} == 0)); then
        log "ERROR" "No se detectaron interfaces ethernet"
        return 1
    fi
    
    echo -e "\n${PURPLE}Interfaces Ethernet disponibles:${NC}\n"
    
    # Intentar configurar cada interfaz
    for interface in "${ethernet_interfaces[@]}"; do
        interface=$(echo "$interface" | tr -d ' ')
        echo -ne "${CYAN}Configurando $interface... ${NC}"
        
        # Activar interfaz
        ip link set "$interface" up
        
        # Intentar DHCP
        if dhcpcd "$interface"; then
            sleep 3
            if ping -c 1 archlinux.org &>/dev/null; then
                echo -e "${GREEN}✔${NC}"
                log "SUCCESS" "Conexión ethernet establecida en $interface"
                return 0
            fi
        fi
        echo -e "${ERROR}✘${NC}"
    done
    
    log "ERROR" "No se pudo establecer conexión ethernet"
    return 1
}

# Función auxiliar para verificar paquetes de red
verify_network_tools() {
    local network_tools=(
        "dhcpcd"
        "iwd"
        "wpa_supplicant"
        "networkmanager"
    )
    
    for tool in "${network_tools[@]}"; do
        if ! pacman -Q "$tool" &>/dev/null; then
            log "WARN" "Herramienta de red $tool no está instalada"
            
            echo -e "${YELLOW}¿Desea instalar $tool? (s/N):${NC}"
            local response
            read -r response
            
            if [[ "$response" =~ ^[Ss]$ ]]; then
                if ! pacman -S --noconfirm "$tool"; then
                    log "ERROR" "No se pudo instalar $tool"
                    continue
                fi
            fi
        fi
    done
}

# Verificar servicios de red
verify_network_services() {
    local services=(
        "NetworkManager"
        "dhcpcd"
        "iwd"
    )
    
    for service in "${services[@]}"; do
        if systemctl is-enabled "$service" &>/dev/null; then
            log "INFO" "Servicio $service está habilitado"
        else
            log "WARN" "Servicio $service no está habilitado"
            
            echo -e "${YELLOW}¿Desea habilitar $service? (s/N):${NC}"
            local response
            read -r response
            
            if [[ "$response" =~ ^[Ss]$ ]]; then
                if ! systemctl enable --now "$service"; then
                    log "ERROR" "No se pudo habilitar $service"
                fi
            fi
        fi
    done
}

# ==============================================================================
# Funciones de Particionamiento
# ==============================================================================

prepare_disk() {
    log "INFO" "Preparando disco para instalación"
    
    # Listar discos disponibles con información detallada
    local available_disks
    available_disks=($(lsblk -dpno NAME,SIZE,TYPE,MODEL | grep disk || echo ""))
    
    if [[ -z "${available_disks[*]}" ]]; then
        log "ERROR" "No se encontraron discos disponibles"
        return 1
    }
    
    echo -e "\n${PURPLE}Discos disponibles:${NC}\n"
    printf '%s\n' "${available_disks[@]}" | nl
    
    # Análisis detallado de cada disco
    echo -e "\n${PURPLE}Análisis detallado de discos:${NC}\n"
    for disk in "${available_disks[@]}"; do
        local disk_name=$(echo "$disk" | cut -d' ' -f1)
        echo -e "${CYAN}=== Analizando $disk_name ===${NC}"
        
        # Mostrar información detallada
        echo -e "${WHITE}Información del disco:${NC}"
        fdisk -l "$disk_name" 2>/dev/null | grep -E "Disk|Device|Dispositivo" || true
        
        # Mostrar particiones actuales
        echo -e "\n${WHITE}Particiones actuales:${NC}"
        lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE "$disk_name"
        
        # Verificar sistemas operativos existentes
        if command -v os-prober &>/dev/null; then
            echo -e "\n${WHITE}Sistemas operativos detectados:${NC}"
            os-prober | grep "$disk_name" || echo "Ninguno detectado"
        fi
        echo -e "${CYAN}================================${NC}\n"
    done
    
    # Selección de disco
    while true; do
        echo -e "\n${YELLOW}Seleccione el número del disco para la instalación:${NC}"
        read -r disk_number
        
        if [[ $disk_number =~ ^[0-9]+$ ]] && \
           ((disk_number > 0 && disk_number <= ${#available_disks[@]})); then
            TARGET_DISK=$(echo "${available_disks[$((disk_number-1))]}" | cut -d' ' -f1)
            break
        fi
        log "WARN" "Selección inválida, intente nuevamente"
    done
    
    # Mostrar opciones de particionamiento
    echo -e "\n${PURPLE}Opciones de particionamiento:${NC}"
    select option in \
        "Usar disco completo (automático)" \
        "Gestionar particiones manualmente" \
        "Usar particiones existentes" \
        "Cancelar"; do
        case $option in
            "Usar disco completo (automático)")
                show_warning_message
                if [[ $? -eq 0 ]]; then
                    if [[ "$BOOT_MODE" == "UEFI" ]]; then
                        create_uefi_partitions
                    else
                        create_bios_partitions
                    fi
                fi
                break
                ;;
            "Gestionar particiones manualmente")
                manage_partitions_manually
                break
                ;;
            "Usar particiones existentes")
                use_existing_partitions
                break
                ;;
            "Cancelar")
                log "INFO" "Operación cancelada por el usuario"
                return 1
                ;;
        esac
    done
    
    # Verificar particionamiento
    verify_partitions
    return $?
}

manage_partitions_manually() {
    log "INFO" "Iniciando gestión manual de particiones"
    
    # Mostrar estado actual del disco
    echo -e "\n${CYAN}Estado actual del disco:${NC}"
    fdisk -l "$TARGET_DISK"
    
    # Ofrecer crear nueva tabla de particiones
    echo -e "\n${YELLOW}¿Desea crear una nueva tabla de particiones? (s/N):${NC}"
    read -r create_new
    
    if [[ "$create_new" =~ ^[Ss]$ ]]; then
        echo -e "\n${YELLOW}Seleccione el tipo de tabla de particiones:${NC}"
        select table in "GPT (recomendado para UEFI)" "MBR (para BIOS legacy)" "Cancelar"; do
            case $table in
                "GPT (recomendado para UEFI)")
                    if ! parted -s "$TARGET_DISK" mklabel gpt; then
                        log "ERROR" "Fallo al crear tabla GPT"
                        return 1
                    fi
                    break
                    ;;
                "MBR (para BIOS legacy)")
                    if ! parted -s "$TARGET_DISK" mklabel msdos; then
                        log "ERROR" "Fallo al crear tabla MBR"
                        return 1
                    fi
                    break
                    ;;
                "Cancelar")
                    return 1
                    ;;
            esac
        done
    fi
    
    # Lanzar herramienta de particionamiento
    echo -e "\n${CYAN}Iniciando herramienta de particionamiento...${NC}"
    echo -e "${YELLOW}Use cfdisk para crear las siguientes particiones:${NC}"
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        echo -e "- Partición EFI    (512MB, tipo EFI System)"
        echo -e "- Partición ROOT   (resto del espacio, tipo Linux filesystem)"
        echo -e "- Partición SWAP   (opcional, tipo Linux swap)"
    else
        echo -e "- Partición BOOT   (512MB, tipo Linux filesystem)"
        echo -e "- Partición ROOT   (resto del espacio, tipo Linux filesystem)"
        echo -e "- Partición SWAP   (opcional, tipo Linux swap)"
    fi
    
    read -p "Presione Enter para continuar..."
    if ! cfdisk "$TARGET_DISK"; then
        log "ERROR" "Error al ejecutar cfdisk"
        return 1
    fi
    
    # Mostrar particiones creadas
    echo -e "\n${CYAN}Particiones creadas:${NC}"
    lsblk "$TARGET_DISK"
    
    # Seleccionar particiones
    select_and_format_partitions
    return $?
}

select_and_format_partitions() {
    local root_part=""
    local boot_part=""
    local swap_part=""
    
    # Seleccionar particiones
    while [[ ! -b "$root_part" ]]; do
        echo -e "\n${YELLOW}Ingrese la partición para ROOT (ejemplo: ${TARGET_DISK}1):${NC}"
        read -r root_part
        if [[ ! -b "$root_part" ]]; then
            echo -e "${ERROR}Partición inválida${NC}"
        fi
    done
    
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        while [[ ! -b "$boot_part" ]]; do
            echo -e "${YELLOW}Ingrese la partición para EFI (ejemplo: ${TARGET_DISK}2):${NC}"
            read -r boot_part
            if [[ ! -b "$boot_part" ]]; then
                echo -e "${ERROR}Partición inválida${NC}"
            fi
        done
    else
        while [[ ! -b "$boot_part" ]]; do
            echo -e "${YELLOW}Ingrese la partición para BOOT (ejemplo: ${TARGET_DISK}2):${NC}"
            read -r boot_part
            if [[ ! -b "$boot_part" ]]; then
                echo -e "${ERROR}Partición inválida${NC}"
            fi
        done
    fi
    
    echo -e "${YELLOW}¿Desea configurar una partición SWAP? (s/N):${NC}"
    read -r use_swap
    if [[ "$use_swap" =~ ^[Ss]$ ]]; then
        while [[ ! -b "$swap_part" ]]; do
            echo -e "${YELLOW}Ingrese la partición para SWAP (ejemplo: ${TARGET_DISK}3):${NC}"
            read -r swap_part
            if [[ ! -b "$swap_part" ]]; then
                echo -e "${ERROR}Partición inválida${NC}"
            fi
        done
    fi
    
    # Formatear y montar particiones
    format_and_mount_partitions "$root_part" "$boot_part" "$swap_part"
    return $?
}

use_existing_partitions() {
    log "INFO" "Usando particiones existentes"
    
    # Mostrar particiones disponibles
    echo -e "\n${CYAN}Particiones disponibles:${NC}"
    lsblk "$TARGET_DISK" -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
    
    # Seleccionar y montar particiones existentes
    select_and_mount_existing_partitions
    return $?
}

select_and_mount_existing_partitions() {
    local root_part=""
    local boot_part=""
    local swap_part=""
    
    # Seleccionar partición ROOT
    while [[ ! -b "$root_part" ]]; do
        echo -e "\n${YELLOW}Ingrese la partición ROOT existente:${NC}"
        read -r root_part
        if [[ ! -b "$root_part" ]]; then
            echo -e "${ERROR}Partición inválida${NC}"
        fi
    done
    
    # Seleccionar partición BOOT/EFI
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        while [[ ! -b "$boot_part" ]]; do
            echo -e "${YELLOW}Ingrese la partición EFI existente:${NC}"
            read -r boot_part
            if [[ ! -b "$boot_part" ]]; then
                echo -e "${ERROR}Partición inválida${NC}"
            fi
        done
    else
        while [[ ! -b "$boot_part" ]]; do
            echo -e "${YELLOW}Ingrese la partición BOOT existente:${NC}"
            read -r boot_part
            if [[ ! -b "$boot_part" ]]; then
                echo -e "${ERROR}Partición inválida${NC}"
            fi
        done
    fi
    
    # Opcionalmente seleccionar SWAP
    echo -e "${YELLOW}¿Desea usar una partición SWAP existente? (s/N):${NC}"
    read -r use_swap
    if [[ "$use_swap" =~ ^[Ss]$ ]]; then
        while [[ ! -b "$swap_part" ]]; do
            echo -e "${YELLOW}Ingrese la partición SWAP existente:${NC}"
            read -r swap_part
            if [[ ! -b "$swap_part" ]]; then
                echo -e "${ERROR}Partición inválida${NC}"
            fi
        done
    fi
    
    # Preguntar si desea formatear las particiones
    echo -e "\n${YELLOW}¿Desea formatear las particiones? (s/N):${NC}"
    read -r should_format
    
    if [[ "$should_format" =~ ^[Ss]$ ]]; then
        format_and_mount_partitions "$root_part" "$boot_part" "$swap_part"
    else
        mount_existing_partitions "$root_part" "$boot_part" "$swap_part"
    fi
    return $?
}

mount_existing_partitions() {
    local root_part="$1"
    local boot_part="$2"
    local swap_part="$3"
    
    # Montar ROOT
    if ! mount "$root_part" /mnt; then
        log "ERROR" "Error al montar partición ROOT"
        return 1
    fi
    
    # Montar BOOT/EFI
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        mkdir -p /mnt/boot/efi
        if ! mount "$boot_part" /mnt/boot/efi; then
            log "ERROR" "Error al montar partición EFI"
            return 1
        fi
    else
        mkdir -p /mnt/boot
        if ! mount "$boot_part" /mnt/boot; then
            log "ERROR" "Error al montar partición BOOT"
            return 1
        fi
    fi
    
    # Activar SWAP si existe
    if [[ -n "$swap_part" ]]; then
        if ! swapon "$swap_part"; then
            log "ERROR" "Error al activar SWAP"
            return 1
        fi
    fi
    
    log "SUCCESS" "Particiones montadas correctamente"
    return 0
}

# ==============================================================================
# Funciones de Instalación Base y Configuración del Sistema
# ==============================================================================

# Paquetes requeridos para la instalación
declare -g REQUIRED_PACKAGES=(
    # Sistema base
    "base"
    "base-devel"
    "linux"
    "linux-firmware"
    
    # Red
    "networkmanager"
    "wpa_supplicant"
    "wireless_tools"
    "netctl"
    
    # Bootloader y utilidades
    "grub"
    "efibootmgr"
    "os-prober"
    
    # Herramientas básicas
    "sudo"
    "vim" 
    "nano"
    "git"
    "wget"
    "curl"
    
    # Utilidades del sistema
    "bash-completion"
    "man-db"
    "man-pages"
    "zip"
    "unzip"
    "htop"
)

install_base_system() {
    log "INFO" "Iniciando instalación del sistema base"
    
    # Actualizar mirrors antes de la instalación
    if ! update_mirrors; then
        log "WARN" "No se pudieron actualizar los mirrors, continuando con la lista predeterminada"
    fi
    
    # Instalar sistema base
    echo -e "\n${PURPLE}Instalando paquetes base:${NC}\n"
    local total_packages=${#REQUIRED_PACKAGES[@]}
    local current=0
    
    # Crear array de paquetes a instalar
    local packages_to_install=()
    for package in "${REQUIRED_PACKAGES[@]}"; do
        ((current++))
        echo -ne "${CYAN}Verificando $package... ${NC}"
        
        # Verificar si el paquete ya está instalado
        if pacman -Q "$package" &>/dev/null; then
            echo -e "${GREEN}✔ (ya instalado)${NC}"
        else
            echo -e "${YELLOW}➜ (pendiente)${NC}"
            packages_to_install+=("$package")
        fi
        
        show_progress "$current" "$total_packages"
        echo
    done
    
    # Instalar paquetes pendientes
    if ((${#packages_to_install[@]} > 0)); then
        echo -e "\n${CYAN}Instalando ${#packages_to_install[@]} paquetes...${NC}"
        if ! pacstrap /mnt "${packages_to_install[@]}"; then
            log "ERROR" "Fallo al instalar paquetes base"
            return 1
        fi
    else
        log "INFO" "Todos los paquetes base ya están instalados"
    fi
    
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
    
    # Respaldar mirrorlist actual
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
    
    # Instalar reflector si no está presente
    if ! command -v reflector &>/dev/null; then
        echo -e "${YELLOW}Instalando reflector...${NC}"
        if ! pacman -Sy --noconfirm reflector; then
            log "WARN" "No se pudo instalar reflector"
            return 1
        fi
    fi
    
    # Configurar mejores mirrors
    echo -e "${CYAN}Actualizando mirrors con reflector...${NC}"
    if ! reflector --latest 20 \
                  --protocol https \
                  --sort rate \
                  --country Spain,France,Germany,Italy \
                  --save /etc/pacman.d/mirrorlist; then
        log "WARN" "Fallo al actualizar mirrors con reflector"
        return 1
    fi
    
    # Actualizar base de datos de pacman
    if ! pacman -Sy; then
        log "WARN" "Fallo al actualizar base de datos de pacman"
        return 1
    fi
    
    log "SUCCESS" "Mirrors actualizados correctamente"
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
        "configure_pacman"
        "configure_services"
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

configure_pacman() {
    log "INFO" "Configurando pacman"
    
    # Habilitar repositorios
    local pacman_conf="/mnt/etc/pacman.conf"
    
    # Habilitar multilib
    sed -i "/\[multilib\]/,/Include/"'s/^#//' "$pacman_conf"
    
    # Habilitar parallel downloads
    sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/' "$pacman_conf"
    
    # Habilitar color
    sed -i 's/#Color/Color/' "$pacman_conf"
    
    # Actualizar base de datos
    arch-chroot /mnt pacman -Sy
    
    return 0
}

configure_services() {
    log "INFO" "Configurando servicios del sistema"
    
    local services=(
        "NetworkManager"
        "sshd"
        "fstrim.timer"
        "systemd-timesyncd"
    )
    
    for service in "${services[@]}"; do
        echo -ne "${CYAN}Habilitando $service... ${NC}"
        if arch-chroot /mnt systemctl enable "$service" &>/dev/null; then
            echo -e "${GREEN}✔${NC}"
        else
            echo -e "${ERROR}✘${NC}"
            log "WARN" "No se pudo habilitar $service"
        fi
    done
    
    return 0
}

configure_hostname() {
    log "INFO" "Configurando hostname"
    
    # Solicitar hostname
    while true; do
        echo -e "${YELLOW}Ingrese el hostname para el sistema: ${NC}"
        read -r HOSTNAME
        
        # Validar hostname
        if [[ "$HOSTNAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
            break
        else
            log "WARN" "Hostname inválido. Use solo letras, números y guiones"
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
    log "INFO" "Configurando zona horaria"
    
    # Lista de zonas horarias comunes
    local common_zones=(
        "America/Guayaquil"    # Ecuador
        "America/Lima"         # Perú
        "America/Bogota"       # Colombia
        "Europe/Madrid"        # España
    )
    
    # Mostrar zonas horarias comunes primero
    echo -e "${CYAN}Zonas horarias comunes:${NC}"
    select zone in "${common_zones[@]}" "Otra..."; do
        if [[ "$zone" == "Otra..." ]]; then
            # Mostrar todas las zonas disponibles
            local zones
            zones=($(find /usr/share/zoneinfo -type f -not -path '*/right/*' -not -path '*/posix/*' -printf '%P\n' | sort))
            
            select TIMEZONE in "${zones[@]}"; do
                if [[ -n "$TIMEZONE" ]]; then
                    break
                fi
                echo -e "${ERROR}Selección inválida${NC}"
            done
        else
            TIMEZONE="$zone"
        fi
        break
    done
    
    # Configurar zona horaria
    echo -ne "${CYAN}Configurando zona horaria $TIMEZONE... ${NC}"
    if ! arch-chroot /mnt bash -c "ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime"; then
        echo -e "${ERROR}✘${NC}"
        return 1
    fi
    
    # Sincronizar reloj hardware
    if ! arch-chroot /mnt hwclock --systohc; then
        echo -e "${ERROR}✘${NC}"
        return 1
    fi
    echo -e "${GREEN}✔${NC}"
    
    return 0
}

configure_locale() {
    log "INFO" "Configurando idioma del sistema"
    
    # Respaldar locale.gen existente
    cp /mnt/etc/locale.gen /mnt/etc/locale.gen.backup
    
    # Preparar locale.gen
    sed -i 's/#\(en_US.UTF-8\)/\1/' /mnt/etc/locale.gen
    sed -i 's/#\(es_ES.UTF-8\)/\1/' /mnt/etc/locale.gen
    
    # Generar locales
    if ! arch-chroot /mnt locale-gen; then
        log "ERROR" "Fallo al generar locales"
        return 1
    fi
    
    # Configurar idioma predeterminado
    echo "LANG=es_ES.UTF-8" > /mnt/etc/locale.conf
    
    # Configurar teclado
    echo "KEYMAP=es" > /mnt/etc/vconsole.conf
    
    return 0
}

configure_users() {
    log "INFO" "Configurando usuarios"
    
    # Configurar contraseña de root
    echo -e "\n${PURPLE}Configuración de contraseña root${NC}"
    while ! arch-chroot /mnt passwd; do
        echo -e "${ERROR}Error al configurar contraseña root. Intente nuevamente${NC}"
    done
    
    # Crear usuario normal
    while true; do
        echo -e "\n${YELLOW}Ingrese nombre para el nuevo usuario: ${NC}"
        read -r USERNAME
        
        if [[ "$USERNAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
            break
        else
            echo -e "${ERROR}Nombre de usuario inválido. Use letras minúsculas, números y guiones${NC}"
        fi
    done
    
    # Crear usuario y agregarlo a grupos
    if ! arch-chroot /mnt useradd -m -G wheel,audio,video,storage,optical -s /bin/bash "$USERNAME"; then
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
    log "INFO" "Configurando red"
    
    # Habilitar NetworkManager
    arch-chroot /mnt systemctl enable NetworkManager
    
    # Configurar resolv.conf
    echo "nameserver 1.1.1.1" > /mnt/etc/resolv.conf
    echo "nameserver 8.8.8.8" >> /mnt/etc/resolv.conf
    
    # Proteger resolv.conf
    chattr +i /mnt/etc/resolv.conf
    
    return 0
}

# ==============================================================================
# Funciones de Bootloader y Finalización
# ==============================================================================

configure_bootloader() {
    log "INFO" "Instalando y configurando bootloader"

    # Instalar paquetes adicionales necesarios
    local bootloader_packages=(
        "grub"
        "efibootmgr"
        "os-prober"
        "dosfstools"
        "mtools"
    )

    # Instalar paquetes del bootloader
    echo -e "${CYAN}Instalando paquetes necesarios para el bootloader...${NC}"
    for package in "${bootloader_packages[@]}"; do
        if ! arch-chroot /mnt pacman -S --noconfirm "$package"; then
            log "ERROR" "Fallo al instalar $package"
            return 1
        fi
    done

    # Configuración específica según el modo de arranque
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        configure_uefi_bootloader
    else
        configure_bios_bootloader
    fi

    # Verificar la instalación del bootloader
    verify_bootloader_installation
    return $?
}

configure_uefi_bootloader() {
    log "INFO" "Configurando bootloader UEFI"

    # Verificar punto de montaje EFI
    if ! mountpoint -q /mnt/boot/efi; then
        log "ERROR" "Punto de montaje EFI no encontrado"
        return 1
    fi

    # Instalar GRUB para UEFI
    echo -e "${CYAN}Instalando GRUB para UEFI...${NC}"
    if ! arch-chroot /mnt grub-install \
        --target=x86_64-efi \
        --efi-directory=/boot/efi \
        --bootloader-id=GRUB \
        --recheck; then
        log "ERROR" "Fallo al instalar GRUB (UEFI)"
        return 1
    fi

    # Configurar GRUB
    configure_grub_common
}

configure_bios_bootloader() {
    log "INFO" "Configurando bootloader BIOS"

    # Instalar GRUB para BIOS
    echo -e "${CYAN}Instalando GRUB para BIOS...${NC}"
    if ! arch-chroot /mnt grub-install \
        --target=i386-pc \
        --recheck \
        "$TARGET_DISK"; then
        log "ERROR" "Fallo al instalar GRUB (BIOS)"
        return 1
    fi

    # Configurar GRUB
    configure_grub_common
}

configure_grub_common() {
    log "INFO" "Configurando GRUB común"

    # Backup del archivo de configuración original
    if [[ -f /mnt/etc/default/grub ]]; then
        cp /mnt/etc/default/grub /mnt/etc/default/grub.backup
    fi

    # Configurar opciones de GRUB
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

    # Generar configuración de GRUB
    echo -e "${CYAN}Generando configuración de GRUB...${NC}"
    if ! arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg; then
        log "ERROR" "Fallo al generar configuración de GRUB"
        return 1
    fi

    return 0
}

verify_bootloader_installation() {
    log "INFO" "Verificando instalación del bootloader"

    # Verificar archivos esenciales de GRUB
    local essential_files=(
        "/mnt/boot/grub/grub.cfg"
        "/mnt/etc/default/grub"
    )

    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        essential_files+=(
            "/mnt/boot/efi/EFI/GRUB/grubx64.efi"
        )
    else
        essential_files+=(
            "/mnt/boot/grub/i386-pc/core.img"
        )
    fi

    local missing_files=0
    for file in "${essential_files[@]}"; do
        echo -ne "${CYAN}Verificando $file... ${NC}"
        if [[ -f "$file" ]]; then
            echo -e "${GREEN}✔${NC}"
        else
            echo -e "${ERROR}✘${NC}"
            ((missing_files++))
        fi
    done

    if ((missing_files > 0)); then
        log "ERROR" "Faltan archivos esenciales del bootloader"
        return 1
    fi

    log "SUCCESS" "Bootloader instalado correctamente"
    return 0
}

# Función para realizar la limpieza final
cleanup() {
    log "INFO" "Realizando limpieza final"

    # Desmontar particiones en orden inverso
    echo -e "\n${CYAN}Desmontando sistemas de archivos...${NC}"
    
    local mountpoints=(
        "/mnt/boot/efi"
        "/mnt/boot"
        "/mnt"
    )

    for point in "${mountpoints[@]}"; do
        if mountpoint -q "$point"; then
            echo -ne "${CYAN}Desmontando $point... ${NC}"
            if umount -R "$point"; then
                echo -e "${GREEN}✔${NC}"
            else
                echo -e "${ERROR}✘${NC}"
                log "WARN" "Fallo al desmontar $point"
            fi
        fi
    done

    # Desactivar swap
    echo -ne "${CYAN}Desactivando swap... ${NC}"
    if swapoff -a; then
        echo -e "${GREEN}✔${NC}"
    else
        echo -e "${ERROR}✘${NC}"
        log "WARN" "Fallo al desactivar swap"
    fi

    # Sincronizar sistema de archivos
    echo -ne "${CYAN}Sincronizando sistema de archivos... ${NC}"
    sync
    echo -e "${GREEN}✔${NC}"

    log "SUCCESS" "Limpieza completada"
}

# Función para generar informe final
generate_installation_report() {
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

    log "INFO" "Reporte de instalación generado en $report_file"
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
        "configure_bootloader"
        "generate_installation_report"
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

    # Mostrar instrucciones post-instalación
    echo -e "\n${YELLOW}Instrucciones post-instalación:${NC}"
    echo -e "1. El informe de instalación está disponible en /root/installation_report.txt"
    echo -e "2. Se recomienda reiniciar el sistema para usar la nueva instalación"
    echo -e "3. Después del reinicio, inicie sesión como usuario normal"
    echo -e "4. Use 'sudo' para tareas administrativas"

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

# Ejecutar el script principal
main "$@"
