#!/usr/bin/env bash

# ==============================================================================
# ZeuspyEC Arch Linux Installer
# Versión: 3.0.1
# ==============================================================================

# Habilitar modo estricto
set -euo pipefail
IFS=$'\n\t'

# Configuración inicial de locale
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

# Definición de colores
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'  
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'  # No Color

# Variables de colores para funciones
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

# Función de logging corregida
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

# Sistema de logging más simple para debugging
debug_log() {
    echo "[DEBUG] $*" >> "${DEBUG_LOG}"
}

error_log() {
    echo "[ERROR] $*" >> "${ERROR_LOG}"
}

info_log() {
    echo "[INFO] $*" >> "${LOG_FILE}"
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

# Función para verificar y generar locales
setup_initial_locale() {
    log "INFO" "Configurando locale inicial"
    
    # Verificar si existe el directorio de locales
    if [[ ! -d "/usr/share/locale" ]]; then
        mkdir -p /usr/share/locale
    fi
    
    # Asegurarse de que el locale C.UTF-8 esté disponible
    if ! locale -a | grep -q "C.UTF-8"; then
        echo "C.UTF-8 UTF-8" > /etc/locale.gen
        locale-gen
    fi
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

# Función de inicialización
init_script() {
    # Configurar locale inicial
    setup_initial_locale
    
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
        "locale-gen"  # Añadir locale-gen a las dependencias
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
        
        # Intentar instalar dependencias faltantes
        if command -v pacman >/dev/null 2>&1; then
            echo -e "${YELLOW}Intentando instalar dependencias faltantes...${NC}"
            pacman -Sy --noconfirm glibc
        fi
        
        return 1
    fi
    
    log "SUCCESS" "Todas las dependencias están instaladas"
    return 0
}
check_system_requirements() {
    log "INFO" "Verificando requisitos del sistema"
    
    # Detectar si es VM
    local virt_type
    virt_type=$(systemd-detect-virt 2>/dev/null || echo "physical")
    
    # Ajustar requisitos según el tipo de sistema
    local min_ram
    local min_disk
    
    if [ "$virt_type" = "physical" ]; then
        min_ram=2048  # 2GB para sistemas físicos
        min_disk=20   # 20GB para sistemas físicos
    else
        min_ram=512   # 512MB para VMs  
        min_disk=15   # 15GB para VMs
    fi
    
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

# Función modificada para verificar y listar todas las particiones disponibles
verify_disk_space() {
    log "INFO" "Analizando dispositivos de almacenamiento"
    
    echo -e "\n${PURPLE}== Dispositivos de Almacenamiento Disponibles ==${NC}"
    
    # Obtener lista completa de dispositivos y particiones
    local devices
    mapfile -t devices < <(lsblk -pno NAME,SIZE,TYPE,MOUNTPOINT,MODEL | grep -E 'disk|part')
    
    if [[ ${#devices[@]} -eq 0 ]]; then
        log "ERROR" "No se encontraron dispositivos de almacenamiento"
        return 1
    }
    
    # Mostrar todos los dispositivos y sus particiones
    echo -e "\n${CYAN}Discos y Particiones:${NC}"
    local index=1
    declare -A device_map
    
    for device in "${devices[@]}"; do
        local name size type mountpoint model
        read -r name size type mountpoint model <<< "$device"
        
        if [[ $type == "disk" ]]; then
            echo -e "\n${GREEN}$index) Disco: $name${NC}"
            echo -e "   Tamaño: $size"
            echo -e "   Modelo: $model"
            device_map[$index]="$name"
            ((index++))
        else
            echo -e "   ├─ Partición: $name"
            echo -e "   │  Tamaño: $size"
            [[ -n $mountpoint ]] && echo -e "   │  Montado en: $mountpoint"
        fi
    done
    
    # Permitir al usuario seleccionar el dispositivo
    while true; do
        echo -e "\n${YELLOW}Seleccione el número del disco a utilizar (1-$((index-1))): ${NC}"
        read -r selection
        
        if [[ -n "${device_map[$selection]}" ]]; then
            TARGET_DISK="${device_map[$selection]}"
            break
        fi
        echo -e "${RED}Selección inválida${NC}"
    done
    
    # Mostrar información detallada del disco seleccionado
    echo -e "\n${PURPLE}Información detallada del disco seleccionado:${NC}"
    fdisk -l "$TARGET_DISK"
    
    # Verificar si hay sistemas operativos instalados
    if command -v os-prober &>/dev/null; then
        echo -e "\n${YELLOW}Sistemas operativos detectados:${NC}"
        os-prober | grep "$TARGET_DISK" || echo "Ninguno detectado"
    fi
    
    # Preguntar al usuario cómo desea proceder
    echo -e "\n${YELLOW}¿Cómo desea proceder?${NC}"
    select option in "Usar disco completo" "Gestionar particiones manualmente" "Cancelar"; do
        case $option in
            "Usar disco completo")
                show_warning_message
                return $?
                ;;
            "Gestionar particiones manualmente")
                manage_partitions_manually
                return $?
                ;;
            "Cancelar")
                log "INFO" "Operación cancelada por el usuario"
                return 1
                ;;
        esac
    done
}

manage_partitions_manually() {
    log "INFO" "Iniciando gestión manual de particiones"
    
    # Mostrar particiones actuales
    echo -e "\n${CYAN}Particiones actuales:${NC}"
    fdisk -l "$TARGET_DISK"
    
    # Preguntar si desea crear nueva tabla de particiones
    echo -e "\n${YELLOW}¿Desea crear una nueva tabla de particiones? (s/N):${NC}"
    read -r create_new
    
    if [[ "$create_new" =~ ^[Ss]$ ]]; then
        echo -e "\n${YELLOW}Seleccione el tipo de tabla de particiones:${NC}"
        select table in "GPT (UEFI)" "MBR (BIOS)" "Cancelar"; do
            case $table in
                "GPT (UEFI)")
                    parted -s "$TARGET_DISK" mklabel gpt
                    break
                    ;;
                "MBR (BIOS)")
                    parted -s "$TARGET_DISK" mklabel msdos
                    break
                    ;;
                "Cancelar")
                    return 1
                    ;;
            esac
        done
    fi
    
    # Lanzar cfdisk para particionamiento interactivo
    if ! cfdisk "$TARGET_DISK"; then
        log "ERROR" "Error al ejecutar cfdisk"
        return 1
    fi
    
    # Listar particiones creadas
    echo -e "\n${CYAN}Particiones creadas:${NC}"
    lsblk "$TARGET_DISK"
    
    # Seleccionar particiones para la instalación
    local root_part=""
    local boot_part=""
    local swap_part=""
    
    echo -e "\n${YELLOW}Ingrese la partición para ROOT (ejemplo: ${TARGET_DISK}1):${NC}"
    read -r root_part
    
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        echo -e "${YELLOW}Ingrese la partición para EFI (ejemplo: ${TARGET_DISK}2):${NC}"
        read -r boot_part
    else
        echo -e "${YELLOW}Ingrese la partición para BOOT (ejemplo: ${TARGET_DISK}2):${NC}"
        read -r boot_part
    fi
    
    echo -e "${YELLOW}Ingrese la partición para SWAP (ejemplo: ${TARGET_DISK}3) o presione Enter para omitir:${NC}"
    read -r swap_part
    
    # Formatear y montar particiones
    if ! format_and_mount_partitions "$root_part" "$boot_part" "$swap_part"; then
        log "ERROR" "Error al formatear y montar particiones"
        return 1
    fi
    
    return 0
}
format_and_mount_partitions() {
    local root_part="$1"
    local boot_part="$2"
    local swap_part="$3"
    
    # Formatear ROOT
    echo -e "\n${CYAN}Formateando partición ROOT...${NC}"
    if ! mkfs.ext4 -F "$root_part"; then
        log "ERROR" "Error al formatear partición ROOT"
        return 1
    fi
    
    # Montar ROOT
    if ! mount "$root_part" /mnt; then
        log "ERROR" "Error al montar partición ROOT"
        return 1
    fi
    
    # Manejar partición BOOT/EFI
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        echo -e "${CYAN}Formateando partición EFI...${NC}"
        if ! mkfs.fat -F32 "$boot_part"; then
            log "ERROR" "Error al formatear partición EFI"
            return 1
        fi
        # Crear y montar directorio EFI
        mkdir -p /mnt/boot/efi
        if ! mount "$boot_part" /mnt/boot/efi; then
            log "ERROR" "Error al montar partición EFI"
            return 1
        fi
    else
        echo -e "${CYAN}Formateando partición BOOT...${NC}"
        if ! mkfs.ext4 -F "$boot_part"; then
            log "ERROR" "Error al formatear partición BOOT"
            return 1
        fi
        # Crear y montar directorio BOOT
        mkdir -p /mnt/boot
        if ! mount "$boot_part" /mnt/boot; then
            log "ERROR" "Error al montar partición BOOT"
            return 1
        fi
    fi
    
    # Configurar SWAP si se especificó
    if [[ -n "$swap_part" ]]; then
        echo -e "${CYAN}Configurando SWAP...${NC}"
        if ! mkswap "$swap_part" || ! swapon "$swap_part"; then
            log "ERROR" "Error al configurar SWAP"
            return 1
        fi
    fi
    
    log "SUCCESS" "Particiones formateadas y montadas correctamente"
    return 0
}

check_network_connectivity() {
log "INFO" "Verificando conectividad de red"

local test_hosts=("archlinux.org" "google.com" "cloudflare.com")
local connected=false

echo -e "\n${PURPLE}Probando conectividad:${NC}\n"

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
# Funciones de Particionamiento
# ==============================================================================

prepare_disk() {
    log "INFO" "Preparando disco para instalación"
    
    # Listar discos disponibles con información detallada
    local available_disks
    available_disks=($(lsblk -dpno NAME,SIZE,TYPE,MODEL | grep disk))
    
    echo -e "\n${PURPLE}Discos disponibles:${NC}\n"
    printf '%s\n' "${available_disks[@]}" | nl
    
    # Buscar particiones existentes y sistemas operativos
    echo -e "\n${PURPLE}Sistemas operativos detectados:${NC}\n"
    for disk in "${available_disks[@]}"; do
        local disk_name=$(echo "$disk" | cut -d' ' -f1)
        echo -e "${CYAN}Analizando $disk_name:${NC}"
        fdisk -l "$disk_name" 2>/dev/null || true
        if command -v os-prober &>/dev/null; then
            os-prober | grep "$disk_name" || true
        fi
    done
    
    # Seleccionar disco
    while true; do
        echo -e "\n${YELLOW}Seleccione el número del disco para la instalación:${NC}"
        read -r disk_number
        
        if [[ $disk_number =~ ^[0-9]+$ ]] && \
           [[ $disk_number -le ${#available_disks[@]} ]] && \
           [[ $disk_number -gt 0 ]]; then
            TARGET_DISK=$(echo "${available_disks[$((disk_number-1))]}" | cut -d' ' -f1)
            break
        fi
        
        log "WARN" "Selección inválida"
    done
    
    # Buscar espacio libre
    local free_space
    free_space=$(parted "$TARGET_DISK" print free | grep "Free Space" | tail -n1)
    
    if [[ -n "$free_space" ]]; then
        echo -e "\n${GREEN}Se encontró espacio libre en $TARGET_DISK:${NC}"
        echo "$free_space"
        
        echo -e "${YELLOW}¿Desea usar este espacio libre para la instalación? (s/N):${NC}"
        read -r use_free_space
        
        if [[ "$use_free_space" =~ ^[Ss]$ ]]; then
            # Usar espacio libre existente
            local start_sector=$(echo "$free_space" | awk '{print $1}')
            local end_sector=$(echo "$free_space" | awk '{print $2}')
            create_partitions_in_free_space "$TARGET_DISK" "$start_sector" "$end_sector"
            return $?
        fi
    fi
    
    # Si no hay espacio libre o el usuario no quiere usarlo
    echo -e "\n${ERROR}¡ADVERTENCIA!${NC}"
    echo -e "${ERROR}Se borrarán todos los datos en $TARGET_DISK${NC}"
    echo -e "${YELLOW}¿Está seguro que desea continuar? (s/N):${NC}"
    read -r confirm
    
    if [[ ! $confirm =~ ^[Ss]$ ]]; then
        log "INFO" "Operación cancelada por el usuario"
        return 1
    fi
    
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        create_uefi_partitions
    else
        create_bios_partitions
    fi
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

    # Crear tabla de particiones GPT
    if ! parted -s "$TARGET_DISK" mklabel gpt; then
        log "ERROR" "Fallo al crear tabla GPT"
        return 1
    fi

    # Crear particiones
    if ! parted -s "$TARGET_DISK" \
        mkpart "EFI" fat32 1MiB "${efi_size}MiB" \
        set 1 esp on \
        mkpart "ROOT" ext4 "${efi_size}MiB" "$((efi_size + root_size))MiB" \
        mkpart "SWAP" linux-swap "$((efi_size + root_size))MiB" 100%; then
        log "ERROR" "Fallo al crear particiones UEFI"
        return 1
    fi

    # Esperar a que el kernel detecte las nuevas particiones
    sleep 2

    # Obtener nombres de las particiones
    local efi_part="${TARGET_DISK}1"
    local root_part="${TARGET_DISK}2"
    local swap_part="${TARGET_DISK}3"

    # Formatear particiones
    if ! mkfs.fat -F32 "$efi_part"; then
        log "ERROR" "Fallo al formatear partición EFI"
        return 1
    fi

    if ! mkfs.ext4 -F "$root_part"; then
        log "ERROR" "Fallo al formatear partición ROOT"
        return 1
    fi

    if ! mkswap "$swap_part"; then
        log "ERROR" "Fallo al formatear partición SWAP"
        return 1
    fi
    if ! swapon "$swap_part"; then
        log "ERROR" "Fallo al activar SWAP"
        return 1
    fi

    # Montar particiones
    if ! mount "$root_part" /mnt; then
        log "ERROR" "Fallo al montar partición ROOT"
        return 1
    fi

    if ! mkdir -p /mnt/boot/efi; then
        log "ERROR" "Fallo al crear directorio EFI"
        return 1
    fi
    if ! mount "$efi_part" /mnt/boot/efi; then
        log "ERROR" "Fallo al montar partición EFI"
        return 1
    fi

    log "SUCCESS" "Particionamiento UEFI completado exitosamente"
    return 0
}

# Función para crear particiones en espacio libre
create_partitions_in_free_space() {
    local disk="$1"
    local start="$2"
    local end="$3"
    
    log "INFO" "Creando particiones en espacio libre: $start - $end"
    
    # Calcular tamaños
    local total_space=$(($end - $start))
    local swap_size=$(free -m | awk '/^Mem:/ {print int($2)}')
    local min_space=15360  # 15GB en MB
    
    if [[ "$total_space" -lt "$min_space" ]]; then
        log "ERROR" "Espacio libre insuficiente"
        return 1
    fi
    
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        # Crear particiones UEFI en espacio libre
        parted -s "$disk" mkpart ESP fat32 "$start" "$((start + 512))MiB" set 1 esp on
        parted -s "$disk" mkpart primary ext4 "$((start + 512))MiB" "$((end - swap_size))MiB"
        parted -s "$disk" mkpart primary linux-swap "$((end - swap_size))MiB" "$end"
    else
        # Crear particiones BIOS en espacio libre
        parted -s "$disk" mkpart primary ext4 "$start" "$((end - swap_size))MiB"
        parted -s "$disk" mkpart primary linux-swap "$((end - swap_size))MiB" "$end"
    fi
    
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
    
    # Crear tabla MBR
    if ! parted -s "$TARGET_DISK" mklabel msdos; then
        log "ERROR" "Fallo al crear tabla MBR"
        return 1
    fi
    
    # Crear particiones
    if ! parted -s "$TARGET_DISK" \
        mkpart primary ext4 1MiB "${boot_size}MiB" \
        set 1 boot on \
        mkpart primary ext4 "${boot_size}MiB" "$((boot_size + root_size))MiB" \
        mkpart primary linux-swap "$((boot_size + root_size))MiB" 100%; then
        log "ERROR" "Fallo al crear particiones BIOS"
        return 1
    fi
    
    # Formatear particiones
    local boot_part="${TARGET_DISK}1"
    local root_part="${TARGET_DISK}2"
    local swap_part="${TARGET_DISK}3"
    
    if ! mkfs.ext4 -F "$boot_part" || \
       ! mkfs.ext4 -F "$root_part" || \
       ! mkswap "$swap_part" || \
       ! swapon "$swap_part"; then
        log "ERROR" "Fallo al formatear particiones"
        return 1
    fi
    
    # Montar particiones
    if ! mount "$root_part" /mnt; then
        log "ERROR" "Fallo al montar partición ROOT"
        return 1
    fi
    if ! mkdir -p /mnt/boot; then
        log "ERROR" "Fallo al crear directorio BOOT"
        return 1
    fi
    if ! mount "$boot_part" /mnt/boot; then
        log "ERROR" "Fallo al montar partición BOOT"
        return 1
    fi
    
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

# Respaldar el mirrorlist actual
if ! cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup; then
    log "ERROR" "Fallo al respaldar el mirrorlist actual"
    return 1
fi

# Intentar usar reflector para optimizar los mirrors
if command -v reflector &>/dev/null; then
    if ! reflector --latest 20 \
                  --protocol https \
                  --sort rate \
                  --save /etc/pacman.d/mirrorlist; then
        log "WARN" "Fallo al actualizar los mirrors con reflector, usando lista por defecto"
    else
        log "SUCCESS" "Mirrorlist actualizado correctamente"
        return 0
    fi
else
    log "WARN" "reflector no está instalado, usando mirrors por defecto"
fi

return 1
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

    # Respaldar locale.gen existente
    cp /mnt/etc/locale.gen /mnt/etc/locale.gen.backup
    
    # Asegurarse de que el directorio existe
    mkdir -p /mnt/usr/share/locale
    
    # Habilitar locales necesarios
    echo "en_US.UTF-8 UTF-8" > /mnt/etc/locale.gen
    echo "es_ES.UTF-8 UTF-8" >> /mnt/etc/locale.gen
    
    # Generar locales dentro del chroot
    if ! arch-chroot /mnt locale-gen; then
        echo -e "${ERROR}✘${NC}"
        log "ERROR" "Fallo al generar locales"
        return 1
    fi
    
    # Configurar idioma predeterminado
    echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
    echo "LC_ALL=en_US.UTF-8" >> /mnt/etc/locale.conf
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
    # Instalar GRUB para UEFI
    if ! arch-chroot /mnt grub-install --target=x86_64-efi \
                                     --efi-directory=/boot/efi \
                                     --bootloader-id=GRUB; then
        log "ERROR" "Fallo al instalar GRUB (UEFI)"
        return 1
    fi
else
    # Instalar GRUB para BIOS
    if ! arch-chroot /mnt grub-install --target=i386-pc "$TARGET_DISK"; then
        log "ERROR" "Fallo al instalar GRUB (BIOS)"
        return 1
    fi
fi

# Configurar GRUB
sed -i 's/#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /mnt/etc/default/grub

# Generar configuración de GRUB
if ! arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg; then
    log "ERROR" "Fallo al generar configuración de GRUB"
    return 1
fi

log "SUCCESS" "Bootloader GRUB configurado correctamente"
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
