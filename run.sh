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

# Función para limpiar espacios en blanco de una cadena
trim() {
    local var="$1"
    # Eliminar espacios al inicio y al final
    var="${var#"${var%%[![:space:]]*}"}"   # Eliminar espacios al inicio
    var="${var%"${var##*[![:space:]]}"}"   # Eliminar espacios al final
    echo "$var"
}
# Paquetes mínimos esenciales para arrancar el sistema
declare -g ESSENTIAL_PACKAGES=(
    "base"
    "linux"
    "linux-firmware"
    "networkmanager"
    "grub"
    "efibootmgr"
    "sudo"
    "nano"
)

# Paquetes adicionales (se instalarán post-instalación)
declare -g ADDITIONAL_PACKAGES=(
    "base-devel"
    "vim"
    "git"
    "wget"
    "curl"
    "htop"
    "neofetch"
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

# Banner mejorado
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
}

# Función de logging mejorada
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

# Función robusta para detectar el modo de arranque (UEFI/BIOS)
detect_boot_mode() {
    local boot_detected=""
    local detection_methods=()
    
    log "INFO" "Detectando modo de arranque del sistema..."
    
    # Método 1: Verificar directorio EFI vars (más confiable)
    if [[ -d "/sys/firmware/efi/efivars" ]]; then
        detection_methods+=("efivars:UEFI")
        boot_detected="UEFI"
        log "DEBUG" "Método efivars: UEFI detectado"
    else
        detection_methods+=("efivars:BIOS")
        log "DEBUG" "Método efivars: BIOS detectado"
    fi
    
    # Método 2: Verificar con efibootmgr
    if command -v efibootmgr &>/dev/null; then
        if efibootmgr &>/dev/null; then
            detection_methods+=("efibootmgr:UEFI")
            if [[ -z "$boot_detected" ]]; then
                boot_detected="UEFI"
            fi
            log "DEBUG" "Método efibootmgr: UEFI detectado"
        else
            detection_methods+=("efibootmgr:BIOS")
            if [[ -z "$boot_detected" ]]; then
                boot_detected="BIOS"
            fi
            log "DEBUG" "Método efibootmgr: BIOS detectado"
        fi
    fi
    
    # Método 3: Verificar con dmesg
    if dmesg | grep -q "EFI v"; then
        detection_methods+=("dmesg:UEFI")
        if [[ -z "$boot_detected" ]]; then
            boot_detected="UEFI"
        fi
        log "DEBUG" "Método dmesg: UEFI detectado"
    elif dmesg | grep -q "BIOS"; then
        detection_methods+=("dmesg:BIOS")
        if [[ -z "$boot_detected" ]]; then
            boot_detected="BIOS"
        fi
        log "DEBUG" "Método dmesg: BIOS detectado"
    fi
    
    # Método 4: Verificar con dmidecode (requiere root)
    if [[ $EUID -eq 0 ]] && command -v dmidecode &>/dev/null; then
        local bios_info
        bios_info=$(dmidecode -t bios 2>/dev/null | grep -i "UEFI")
        if [[ -n "$bios_info" ]]; then
            detection_methods+=("dmidecode:UEFI")
            if [[ -z "$boot_detected" ]]; then
                boot_detected="UEFI"
            fi
            log "DEBUG" "Método dmidecode: UEFI detectado"
        else
            detection_methods+=("dmidecode:BIOS")
            if [[ -z "$boot_detected" ]]; then
                boot_detected="BIOS"
            fi
            log "DEBUG" "Método dmidecode: BIOS detectado"
        fi
    fi
    
    # Método 5: Verificar tabla de particiones del disco actual
    if command -v parted &>/dev/null && [[ -n "${TARGET_DISK:-}" ]]; then
        local partition_table
        partition_table=$(parted -s "$TARGET_DISK" print 2>/dev/null | grep "Partition Table" | awk '{print $3}')
        if [[ "$partition_table" == "gpt" ]]; then
            detection_methods+=("partition:GPT->UEFI")
            log "DEBUG" "Tabla de particiones GPT detectada (típico de UEFI)"
        elif [[ "$partition_table" == "msdos" ]]; then
            detection_methods+=("partition:MBR->BIOS")
            log "DEBUG" "Tabla de particiones MBR detectada (típico de BIOS)"
        fi
    fi
    
    # Método 6: Verificar si existe partición EFI montada
    if mount | grep -q "/boot/efi\|/efi"; then
        detection_methods+=("mount:UEFI")
        if [[ -z "$boot_detected" ]]; then
            boot_detected="UEFI"
        fi
        log "DEBUG" "Partición EFI montada detectada"
    fi
    
    # Determinar el modo final
    if [[ -z "$boot_detected" ]]; then
        # Si no se pudo detectar, asumir BIOS por seguridad
        BOOT_MODE="BIOS"
        log "WARN" "No se pudo determinar el modo de arranque con certeza, asumiendo BIOS"
    else
        BOOT_MODE="$boot_detected"
        log "SUCCESS" "Modo de arranque detectado: $BOOT_MODE"
    fi
    
    # Registrar todos los métodos de detección usados
    log "DEBUG" "Métodos de detección utilizados: ${detection_methods[*]}"
    
    # Validar que el modo detectado sea consistente con el sistema
    validate_boot_mode_detection
    
    return 0
}

# Función para validar que la detección es correcta
validate_boot_mode_detection() {
    log "INFO" "Validando detección del modo de arranque..."
    
    local validation_passed=true
    local warnings=()
    
    # Si detectamos UEFI, verificar que podemos trabajar con él
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        # Verificar que existe el directorio EFI
        if [[ ! -d "/sys/firmware/efi" ]]; then
            warnings+=("Modo UEFI detectado pero falta /sys/firmware/efi")
            validation_passed=false
        fi
        
        # Verificar que efibootmgr funciona
        if command -v efibootmgr &>/dev/null; then
            if ! efibootmgr &>/dev/null; then
                warnings+=("efibootmgr no funciona correctamente en modo UEFI")
            fi
        fi
        
        # Información adicional para UEFI
        log "INFO" "Sistema UEFI confirmado - Se usará esquema GPT"
        log "INFO" "Particiones requeridas: EFI (FAT32), ROOT (ext4), SWAP"
        
    else  # BIOS
        # Verificar que NO existe el directorio EFI vars
        if [[ -d "/sys/firmware/efi/efivars" ]]; then
            warnings+=("Directorio EFI existe pero se detectó BIOS - verificando...")
            # Hacer una segunda verificación
            if ls /sys/firmware/efi/efivars/ 2>/dev/null | grep -q .; then
                log "ERROR" "Inconsistencia: EFI vars presentes pero modo BIOS detectado"
                log "WARN" "Cambiando a modo UEFI por seguridad"
                BOOT_MODE="UEFI"
                validation_passed=true
            fi
        fi
        
        # Información adicional para BIOS
        log "INFO" "Sistema BIOS Legacy confirmado - Se usará esquema MBR"
        log "INFO" "Particiones requeridas: BOOT (ext4), ROOT (ext4), SWAP"
    fi
    
    # Mostrar advertencias si las hay
    if [[ ${#warnings[@]} -gt 0 ]]; then
        for warning in "${warnings[@]}"; do
            log "WARN" "$warning"
        done
    fi
    
    if [[ "$validation_passed" == false ]]; then
        log "ERROR" "La validación del modo de arranque falló"
        echo -e "${YELLOW}⚠ Advertencia: Detección del modo de arranque inconsistente${RESET}"
        echo -e "${YELLOW}Por favor, verifique su configuración de BIOS/UEFI${RESET}"
        read -p "¿Desea continuar de todos modos? [S/n]: " -r
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            exit 1
        fi
    fi
    
    return 0
}

check_dependencies() {
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
        
        echo -e "\n${YELLOW}¿Desea continuar de todos modos? [S/n]:${RESET} "
        read -r response
        if [[ ! "$response" =~ ^[Nn]$ ]]; then
            log "WARN" "Continuando sin todas las dependencias"
            return 0
        else
            log "ERROR" "Instalación cancelada por dependencias faltantes"
            return 1
        fi
    fi
    
    return 0
}

install_package() {
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
    
    echo -e "${YELLOW}¿Desea continuar sin $package? [S/n]:${RESET} "
    read -r response
    [[ ! "$response" =~ ^[Nn]$ ]] && return 0 || return 1
}

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
    
    # Verificar modo de arranque con múltiples métodos
    echo -ne "${WHITE}Modo de arranque:${RESET} "
    detect_boot_mode
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        echo -e "${GREEN}✔ UEFI${RESET}"
    else
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
}

verify_disk_space() {
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
}

configure_mirrorlist() {
    log "INFO" "Configurando mirrors optimizados"
    
    # Backup del mirrorlist actual
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
    
    echo -e "${CYAN}Actualizando lista de mirrors...${RESET}"
    
    # Escribir nuevo mirrorlist personalizado
    cat > /etc/pacman.d/mirrorlist << 'EOF'
##############################################################
##################
######################### Arch Linux mirrorlist generated by Zeus
#########################
##############################################################
##################
# Mirrorlist optimizada y confiable
# Last Check: 2021-12-26 17:43:40 UTC
Server = https://mirror.osbeck.com/archlinux/$repo/os/$arch
Server = https://arch.mirror.constant.com/$repo/os/$arch
Server = https://mirror.luzea.de/archlinux/$repo/os/$arch
Server = https://mirror.pseudoform.org/$repo/os/$arch
Server = https://mirror.cspacehostings.com/archlinux/$repo/os/$arch
Server = https://archlinux.thaller.ws/$repo/os/$arch
Server = https://mirror.telepoint.bg/archlinux/$repo/os/$arch
Server = https://mirror.f4st.host/archlinux/$repo/os/$arch
Server = https://phinau.de/arch/$repo/os/$arch
Server = https://archmirror.it/repos/$repo/os/$arch
Server = https://mirror.cyberbits.asia/archlinux/$repo/os/$arch
Server = https://archlinux-br.com.br/archlinux/$repo/os/$arch
Server = https://ftp.halifax.rwth-aachen.de/archlinux/$repo/os/$arch
Server = https://mirrors.neusoft.edu.cn/archlinux/$repo/os/$arch
Server = https://mirror.pkgbuild.com/$repo/os/$arch
Server = https://archlinux.uk.mirror.allworldit.com/archlinux/$repo/os/$arch
Server = https://archlinux.za.mirror.allworldit.com/archlinux/$repo/os/$arch
Server = https://mirror.theash.xyz/arch/$repo/os/$arch
Server = https://archlinux.mailtunnel.eu/$repo/os/$arch
Server = https://mirror.lty.me/archlinux/$repo/os/$arch
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
}

setup_network_connection() {
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

detect_current_wifi_connection() {
    log "INFO" "Detectando conexión WiFi activa"
    
    # Variables para guardar información
    local current_ssid=""
    local current_interface=""
    local wifi_password=""
    
    echo -e "${CYAN}Buscando conexión WiFi activa...${RESET}"
    
    # MÉTODO 1: Detectar con iwctl (más confiable en LiveCD)
    if command -v iwctl &>/dev/null; then
        echo -e "${CYAN}Detectando con iwctl...${RESET}"
        
        # Obtener todas las interfaces wireless
        local wireless_interfaces
        wireless_interfaces=($(iwctl device list 2>/dev/null | grep -E "wlan[0-9]+|wlp[0-9]s[0-9]+" -o))
        
        for interface in "${wireless_interfaces[@]}"; do
            # Verificar estado de la interfaz
            local station_info
            station_info=$(iwctl station "$interface" show 2>/dev/null)
            
            if echo "$station_info" | grep -q "State.*connected"; then
                # CORRECCIÓN COMPLETA: Capturar SSID completo y limpiar SOLO espacios del inicio/final
                current_ssid=$(echo "$station_info" | grep "Connected network" | sed 's/.*Connected network[[:space:]]*//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                current_interface="$interface"
                
                if [ -n "$current_ssid" ]; then
                    echo -e "${GREEN}✅ WiFi detectado via iwctl:${RESET}"
                    echo -e "  Interface: ${CYAN}$current_interface${RESET}"
                    echo -e "  SSID: ${CYAN}'$current_ssid'${RESET}"
                    
                    # DEBUG - Ver exactamente qué se capturó
                    echo -e "${YELLOW}DEBUG - SSID capturado: [${current_ssid}]${RESET}"
                    echo -e "${YELLOW}DEBUG - Longitud: $(echo -n "$current_ssid" | wc -c) caracteres${RESET}"
                    
                    # Solicitar contraseña al usuario
                    echo -e "\n${YELLOW}⚠ Necesitamos la contraseña para guardarla${RESET}"
                    echo -ne "${YELLOW}Ingrese la contraseña de '$current_ssid':${RESET} "
                    read -rs wifi_password
                    echo
                    
                    # Validar que se ingresó una contraseña
                    if [ -z "$wifi_password" ]; then
                        echo -e "${RED}No se ingresó contraseña, reintentando...${RESET}"
                        echo -ne "${YELLOW}Por favor, ingrese la contraseña (es importante):${RESET} "
                        read -rs wifi_password
                        echo
                    fi
                    
                    # Guardar credenciales inmediatamente
                    save_network_credentials "wifi" "$current_ssid" "$wifi_password" "$current_interface"
                    return 0
                fi
            fi
        done
    fi
    
    # MÉTODO 2: NetworkManager (si está disponible)
    if command -v nmcli &>/dev/null; then
        echo -e "${CYAN}Detectando con NetworkManager...${RESET}"
        
        # Verificar si NetworkManager está activo
        if systemctl is-active NetworkManager &>/dev/null; then
            # Obtener SSID activo - CORREGIDO para capturar SSID completo y limpiar espacios
            current_ssid=$(nmcli -t -f active,ssid dev wifi | grep '^yes:' | sed 's/^yes://' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            if [ -n "$current_ssid" ]; then
                echo -e "${GREEN}✅ WiFi detectado via NetworkManager:${RESET}"
                echo -e "  SSID: ${CYAN}'$current_ssid'${RESET}"
                
                # DEBUG
                echo -e "${YELLOW}DEBUG - SSID capturado: [${current_ssid}]${RESET}"
                echo -e "${YELLOW}DEBUG - Longitud: $(echo -n "$current_ssid" | wc -c) caracteres${RESET}"
                
                # Obtener interfaz
                current_interface=$(nmcli -t -f device,state dev | grep ':connected' | head -1 | cut -d':' -f1)
                
                # Intentar obtener contraseña de NetworkManager
                wifi_password=$(nmcli --show-secrets -f 802-11-wireless-security.psk connection show "$current_ssid" 2>/dev/null | grep "psk:" | sed 's/.*psk://' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                
                # Si no se pudo obtener, pedirla al usuario
                if [ -z "$wifi_password" ] || [ "$wifi_password" = "--" ]; then
                    echo -e "\n${YELLOW}⚠ No se pudo obtener la contraseña automáticamente${RESET}"
                    echo -ne "${YELLOW}Ingrese la contraseña de '$current_ssid':${RESET} "
                    read -rs wifi_password
                    echo
                else
                    echo -e "${GREEN}✅ Contraseña obtenida de NetworkManager${RESET}"
                fi
                
                # Guardar credenciales
                save_network_credentials "wifi" "$current_ssid" "$wifi_password" "$current_interface"
                return 0
            fi
        fi
    fi
    
    # MÉTODO 3: Verificar conectividad y pedir datos manualmente
    if ping -c 1 archlinux.org &>/dev/null; then
        echo -e "${GREEN}✅ Hay conexión a Internet activa${RESET}"
        echo -e "${YELLOW}Pero no se pudo detectar los detalles de la red${RESET}"
        
        # Pedir información manualmente
        echo -e "\n${CYAN}Por favor, ingrese los datos de su conexión WiFi actual:${RESET}"
        echo -ne "${YELLOW}SSID (nombre completo de la red WiFi):${RESET} "
        read -r current_ssid
        # Limpiar espacios del input manual SOLO al inicio y final
        current_ssid=$(echo "$current_ssid" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # DEBUG
        echo -e "${YELLOW}DEBUG - SSID ingresado: [${current_ssid}]${RESET}"
        echo -e "${YELLOW}DEBUG - Longitud: $(echo -n "$current_ssid" | wc -c) caracteres${RESET}"
        
        echo -ne "${YELLOW}Contraseña:${RESET} "
        read -rs wifi_password
        echo
        
        # Detectar interfaz wireless
        current_interface=$(ip link show | grep -E "wlan[0-9]+|wlp[0-9]s[0-9]+" -o | head -1)
        if [ -z "$current_interface" ]; then
            current_interface="wlan0"  # Default
        fi
        
        # Guardar credenciales
        save_network_credentials "wifi" "$current_ssid" "$wifi_password" "$current_interface"
        return 0
    fi
    
    log "WARN" "No se detectó conexión WiFi activa"
    return 1
}

# Nueva función para guardar credenciales de forma consistente
save_network_credentials() {
    local conn_type="$1"
    local ssid="$2"
    local password="$3"
    local interface="$4"
    
    mkdir -p /tmp/zeuspyec_install
    
    # IMPORTANTE: Usar comillas para manejar espacios
    cat > /tmp/zeuspyec_install/network_credentials.txt <<EOF
CONNECTION_TYPE=$conn_type
WIFI_SSID="$ssid"
WIFI_PASSWORD="$password"
WIFI_INTERFACE=$interface
INSTALL_DATE=$(date '+%Y-%m-%d %H:%M:%S')
EOF

    # Verificar que se guardó correctamente
    if [ -f /tmp/zeuspyec_install/network_credentials.txt ]; then
        echo -e "${GREEN}✅ Credenciales guardadas exitosamente${RESET}"
        echo -e "${CYAN}Archivo: /tmp/zeuspyec_install/network_credentials.txt${RESET}"
        
        # Mostrar resumen (sin contraseña)
        echo -e "\n${WHITE}Resumen de configuración guardada:${RESET}"
        echo -e "  Tipo: ${CYAN}$conn_type${RESET}"
        echo -e "  SSID: ${CYAN}$ssid${RESET}"
        echo -e "  Interface: ${CYAN}$interface${RESET}"
        echo -e "  Contraseña: ${CYAN}[GUARDADA]${RESET}"
        
        log "SUCCESS" "Credenciales WiFi guardadas correctamente"
    else
        log "ERROR" "No se pudieron guardar las credenciales"
        echo -e "${RED}✘ Error al guardar credenciales${RESET}"
    fi
}

setup_wifi_connection() {
    # Primero intentar detectar conexión WiFi activa
    if detect_current_wifi_connection; then
        echo -e "${GREEN}✅ Usando conexión WiFi existente${RESET}"
        return 0
    fi
    
    # Si no hay conexión activa, proceder con configuración manual
    log "INFO" "Configurando nueva conexión WiFi"
    
    # Verificar soporte wifi
    if ! command -v iwctl &>/dev/null; then
        log "ERROR" "iwd no está instalado"
        return 1
    fi
    
    # Obtener interfaces wireless
    local wireless_interfaces
    wireless_interfaces=($(iwctl device list 2>/dev/null | grep -oE "wlan[0-9]+"))
    
    if ((${#wireless_interfaces[@]} == 0)); then
        log "ERROR" "No se detectaron interfaces wireless"
        return 1
    fi
    
    # Usar primera interfaz disponible
    local selected_interface=${wireless_interfaces[0]}
    echo -e "${WHITE}Usando interfaz WiFi: $selected_interface${RESET}"
    
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
            
            # Guardar credenciales WiFi para post-instalación
            mkdir -p /tmp/zeuspyec_install
            cat > /tmp/zeuspyec_install/network_credentials.txt <<EOF
# Configuración de Red ZeuspyEC
# Este archivo contiene las credenciales de red usadas durante la instalación
# Generado automáticamente el $(date)

CONNECTION_TYPE=wifi
WIFI_SSID=$ssid
WIFI_PASSWORD=$password
WIFI_INTERFACE=$selected_interface
INSTALL_DATE=$(date '+%Y-%m-%d %H:%M:%S')
EOF
            log "INFO" "Credenciales WiFi guardadas en network_credentials.txt"
            return 0
        fi
    fi
    
    log "ERROR" "No se pudo establecer la conexión WiFi"
    return 1
}

# Función para configuración automática de red
configure_network_automatic() {
    log "DEBUG" "Intentando configuración automática de red"
    
    # Verificar si estamos en un LiveCD
    if [[ -f /etc/arch-release ]]; then
        # En LiveCD de Arch, usar dhcpcd para ethernet
        echo -ne "  • Configurando Ethernet automático... "
        if dhcpcd &>/dev/null; then
            echo -e "${GREEN}✔${RESET}"
            return 0
        else
            echo -e "${YELLOW}⚠${RESET}"
        fi
        
        # Intentar NetworkManager si existe
        if systemctl is-active NetworkManager &>/dev/null; then
            echo -ne "  • Reiniciando NetworkManager... "
            systemctl restart NetworkManager &>/dev/null && sleep 2
            echo -e "${GREEN}✔${RESET}"
        fi
        
        # Si hay WiFi disponible, intentar conectar
        if command -v iwctl &>/dev/null; then
            echo -ne "  • Escaneando WiFi... "
            # Activar device si está desactivado
            for device in wlan0 wlp*; do
                if [[ -e /sys/class/net/$device ]]; then
                    iwctl station "$device" scan &>/dev/null || true
                    sleep 2
                    echo -e "${GREEN}✔${RESET}"
                    break
                fi
            done
        fi
    fi
    
    return 1
}

setup_ethernet_connection() {
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
                
                # Guardar configuración ethernet para post-instalación
                mkdir -p /tmp/zeuspyec_install
                cat > /tmp/zeuspyec_install/network_credentials.txt <<EOF
# Configuración de Red ZeuspyEC
# Este archivo contiene las credenciales de red usadas durante la instalación
# Generado automáticamente el $(date)

CONNECTION_TYPE=ethernet
ETHERNET_INTERFACE=$interface
INSTALL_DATE=$(date '+%Y-%m-%d %H:%M:%S')
EOF
                log "INFO" "Configuración Ethernet guardada en network_credentials.txt"
                return 0
            fi
        fi
        echo -e "${RED}✘${RESET}"
    done
    
    log "ERROR" "No se pudo establecer conexión Ethernet"
    return 1
}

# ==============================================================================
# Funciones de Particionamiento y Formateo
# ==============================================================================
repair_mount_points() {
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
}

prepare_disk() {
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
        echo -e "${YELLOW}¿Desea intentar desmontar las particiones? [S/n]:${RESET} "
        read -r response
        if [[ ! "$response" =~ ^[Nn]$ ]]; then
            unmount_all "$TARGET_DISK"
        else
            return 1
        fi
    fi
    
    # Seleccionar esquema de particionamiento según el modo de arranque
    # UEFI siempre usa GPT, BIOS siempre usa MBR
    local partition_scheme
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        partition_scheme="gpt"
        echo -e "\n${CYAN}Modo UEFI detectado - usando esquema GPT${RESET}"
    else
        partition_scheme="mbr"
        echo -e "\n${CYAN}Modo BIOS Legacy detectado - usando esquema MBR${RESET}"
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
}

show_warning_message() {
    echo -e "\n${RED}╔═══════════════════════════ ADVERTENCIA ═══════════════════════════╗${RESET}"
    echo -e "${RED}║  ¡ATENCIÓN! Se borrarán TODOS los datos en el disco seleccionado  ║${RESET}"
    echo -e "${RED}║  Esta operación no se puede deshacer                              ║${RESET}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════════╝${RESET}"
    
    echo -ne "\n${YELLOW}¿Está seguro que desea continuar? [S/n]:${RESET} "
    read -r response
    [[ ! "$response" =~ ^[Nn]$ ]] && return 0 || return 1
}

# Función para crear particiones GPT
create_gpt_partitions() {
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
}

# Función para crear particiones MBR
create_mbr_partitions() {
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
}

# Función unificada para montar particiones (evita duplicados)
mount_partitions() {
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
    
    # Montar BOOT/EFI según el modo de arranque detectado
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        echo -ne "  Montando partición EFI (UEFI)... "
        mkdir -p /mnt/boot/efi
        if retry_command mount "$boot_part" /mnt/boot/efi; then
            echo -e "${GREEN}✔${RESET}"
        else
            echo -e "${RED}✘${RESET}"
            return 1
        fi
    else
        echo -ne "  Montando partición BOOT (BIOS)... "
        mkdir -p /mnt/boot
        if retry_command mount "$boot_part" /mnt/boot; then
            echo -e "${GREEN}✔${RESET}"
        else
            echo -e "${RED}✘${RESET}"
            return 1
        fi
    fi
    
    return 0
}
# Función para verificar si un disco está montado
is_disk_mounted() {
    local disk="$1"
    lsblk -no MOUNTPOINT "$disk" | grep -q .
    return $?
}

# Función para desmontar todas las particiones de un disco
unmount_all() {
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
}
format_and_mount_partitions() {
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
    
    # Montar particiones usando la función unificada
    if ! mount_partitions "$root_part" "$boot_part"; then
        log "ERROR" "Error al montar las particiones"
        return 1
    fi
    
    log "SUCCESS" "Particiones formateadas y montadas correctamente"
    return 0
}

verify_partitions() {
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
        echo -e "¿Desea continuar de todos modos? [S/n]: "
        read -r response
        if [[ "$response" =~ ^[Nn]$ ]]; then
            log "ERROR" "Instalación cancelada por el usuario"
            return 1
        fi
        log "WARN" "Continuando sin todos los puntos de montaje"
    fi
    
    # Mostrar estructura final
    echo -e "\n${WHITE}Estructura final de particiones:${RESET}"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E '^|/mnt' | sed 's/^/  /'
    
    log "SUCCESS" "Verificación de particiones completada"
    return 0
}

# ==============================================================================
# Funciones de Instalación Base
# ==============================================================================

install_base_system() {
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
            log "ERROR" "Fallo en: $step"
            return 1
        fi
        show_progress "$current" "$total_steps"
    done
    
    return 0
}

install_essential_packages() {
    log "INFO" "Instalando paquetes esenciales"
    
    # VERIFICAR CREDENCIALES PRIMERO
    if [[ ! -f /tmp/zeuspyec_install/network_credentials.txt ]]; then
        echo -e "${YELLOW}⚠ No hay credenciales guardadas, intentando detectar...${RESET}"
        detect_current_wifi_connection
    fi
    # PRIMERO: Configurar mirrors si no se ha hecho
    if [[ ! -f /etc/pacman.d/mirrorlist.backup ]]; then
        configure_mirrorlist
    fi
    
    # Verificar y asegurar conexión de red
    echo -e "${CYAN}Verificando conexión de red...${RESET}"
    local max_retries=5  # Aumentar reintentos
    local retry_count=0
    
    while ((retry_count < max_retries)); do
        if ping -c 2 -W 5 archlinux.org &>/dev/null; then
            echo -e "${GREEN}✓ Conexión verificada${RESET}"
            break
        else
            ((retry_count++))
            echo -e "${YELLOW}⚠ Sin conexión, intento $retry_count de $max_retries${RESET}"
            
            if ((retry_count < max_retries)); then
                echo -e "${CYAN}Reintentando configuración de red...${RESET}"
                
                # Intentar reconectar con credenciales guardadas
                if [[ -f /tmp/zeuspyec_install/network_credentials.txt ]]; then
                    # Leer el archivo correctamente, evitando ejecutar comandos accidentalmente
                    eval "$(grep -E '^(CONNECTION_TYPE|WIFI_SSID|WIFI_PASSWORD|WIFI_INTERFACE)=' /tmp/zeuspyec_install/network_credentials.txt)"
                    
                    # Limpiar espacios adicionales del SSID
                    WIFI_SSID=$(echo "$WIFI_SSID" | sed 's/^"//;s/"$//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    
                    if [[ "$CONNECTION_TYPE" == "wifi" ]] && [[ -n "$WIFI_SSID" ]] && [[ -n "$WIFI_PASSWORD" ]]; then
                        echo -e "${CYAN}Reconectando a WiFi: '$WIFI_SSID'${RESET}"
                        
                        # IMPORTANTE: Comillas dobles para manejar espacios internos
                        if command -v iwctl &>/dev/null; then
                            iwctl station "${WIFI_INTERFACE:-wlan0}" disconnect 2>/dev/null
                            sleep 2
                            iwctl station "${WIFI_INTERFACE:-wlan0}" connect "$WIFI_SSID" --passphrase "$WIFI_PASSWORD" 2>/dev/null
                            sleep 5
                        fi
                        
                        # NetworkManager también con comillas
                        if ! ping -c 1 archlinux.org &>/dev/null && command -v nmcli &>/dev/null; then
                            systemctl restart NetworkManager 2>/dev/null
                            sleep 3
                            nmcli device wifi connect "$WIFI_SSID" password "$WIFI_PASSWORD" 2>/dev/null
                            sleep 5
                        fi
                    fi
                fi
            else
                log "ERROR" "Sin conexión a Internet después de $max_retries intentos"
                echo -e "${RED}✘ Configure manualmente la conexión de red${RESET}"
                return 1
            fi
        fi
    done
    
    # Actualizar base de datos de pacman con reintentos
    echo -e "${CYAN}Actualizando base de datos de pacman...${RESET}"
    local pacman_retry=0
    while ((pacman_retry < 3)); do
        if pacman -Sy --noconfirm; then
            break
        else
            ((pacman_retry++))
            echo -e "${YELLOW}Reintentando actualización de pacman ($pacman_retry/3)...${RESET}"
            sleep 3
        fi
    done
}
    
generate_fstab() {
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
}

configure_system_base() {
    log "INFO" "Configurando sistema base"
    
    # Configurar hostname
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
    
    # Configurar hosts
    cat > /mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF
    
    # Configurar zona horaria
    echo -e "\n${WHITE}Configuración de zona horaria:${RESET}"
    local zones=(
        "America/Guayaquil"    # Ecuador
        "America/Lima"         # Perú
        "America/Bogota"       # Colombia
        "Europe/Madrid"        # España
        "Otra"
    )
    
    PS3=$'\n'"${YELLOW}Seleccione zona horaria:${RESET} "
    select zone in "${zones[@]}"; do
        case $zone in
            "Otra")
                # Mostrar todas las zonas disponibles
                local all_zones
                mapfile -t all_zones < <(find /usr/share/zoneinfo -type f -not -path '*/posix/*' -not -path '*/right/*' | sed 's|/usr/share/zoneinfo/||')
                
                PS3=$'\n'"${YELLOW}Seleccione zona horaria:${RESET} "
                select TIMEZONE in "${all_zones[@]}"; do
                    if [[ -n "$TIMEZONE" ]]; then
                        break 2
                    fi
                done
                ;;
            *)
                TIMEZONE="$zone"
                break
                ;;
        esac
    done
    
    # Configurar zona horaria
    arch-chroot /mnt ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    arch-chroot /mnt hwclock --systohc
    
    # Configurar locale
    echo -e "\n${WHITE}Configurando locale...${RESET}"
    sed -i 's/#\(en_US.UTF-8\)/\1/' /mnt/etc/locale.gen
    sed -i 's/#\(es_ES.UTF-8\)/\1/' /mnt/etc/locale.gen
    
    arch-chroot /mnt locale-gen
    echo "LANG=es_ES.UTF-8" > /mnt/etc/locale.conf
    echo "KEYMAP=es" > /mnt/etc/vconsole.conf
    
    # Configurar usuarios
    echo -e "\n${WHITE}Configuración de usuarios:${RESET}"
    
    # Root password
    echo -e "\n${CYAN}Configurando contraseña de root${RESET}"
    while ! arch-chroot /mnt passwd; do
        echo -e "${RED}Error al configurar contraseña. Intente nuevamente${RESET}"
    done
    
    # Usuario normal
    while true; do
        echo -ne "\n${YELLOW}Ingrese nombre para el nuevo usuario:${RESET} "
        read -r USERNAME
        
        if [[ "$USERNAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
            break
        else
            echo -e "${RED}Nombre inválido. Use letras minúsculas, números y guiones${RESET}"
        fi
    done
    
    # Crear usuario y grupos
    arch-chroot /mnt useradd -m -G wheel,audio,video,storage,optical -s /bin/bash "$USERNAME"
    
    echo -e "\n${CYAN}Configurando contraseña para $USERNAME${RESET}"
    while ! arch-chroot /mnt passwd "$USERNAME"; do
        echo -e "${RED}Error al configurar contraseña. Intente nuevamente${RESET}"
    done
    
    # Configurar sudo
    echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/wheel
    chmod 440 /mnt/etc/sudoers.d/wheel
    
    # Habilitar servicios básicos
    echo -e "\n${WHITE}Habilitando servicios...${RESET}"
    local services=(
        "NetworkManager"
        "fstrim.timer"
        "systemd-timesyncd"
    )
    
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
}

# ==============================================================================
# Funciones de Post-instalación y Temas
# ==============================================================================

configure_zeuspy_theme() {
    log "INFO" "Configurando tema personalizado ZeuspyEC"
    
    echo -e "\n${CYAN}╔════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║      Instalación Tema ZeuspyEC         ║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${RESET}\n"
    
    echo -e "${INFO}🚀 Instalación Mínima: Tema ZeuspyEC${RESET}"
    echo -e "${YELLOW}Los paquetes del entorno gráfico se instalarán después del primer arranque${RESET}"
    echo -e "${YELLOW}mediante el script post-install.sh${RESET}"
    
    # Configurar inicio básico del sistema
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
    
    # Crear scripts post-instalación
    echo -e "\n${CYAN}Creando scripts post-instalación...${RESET}"
    create_post_install_script
    create_standalone_post_install
    
    log "SUCCESS" "Tema ZeuspyEC instalado correctamente"
    return 0
}

create_post_install_script() {
    log "INFO" "Creando script post-instalación"
    
    # Crear script de post-instalación en el home del usuario
    cat > "/mnt/home/$USERNAME/post-install.sh" <<'EOF'
#!/bin/bash

# Script de Post-Instalación ZeuspyEC
# Instala paquetes adicionales y configuraciones después del primer arranque

# Colores para output
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
WHITE="\033[0;37m"
RESET="\033[0m"

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                   POST-INSTALACIÓN ZEUSPYEC                     ║"
echo "║              Completando instalación del sistema                ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${RESET}\n"

# Configurar red automáticamente
configure_network() {
    echo -e "${CYAN}Configurando conexión de red...${RESET}"
    
    # Verificar si hay configuración guardada
    if [ -f ~/network_credentials.txt ]; then
        # Leer archivo de credenciales (ignorar comentarios)
        while IFS='=' read -r key value; do
            [[ $key =~ ^#.*$ ]] && continue  # Ignorar comentarios
            [[ -z $key ]] && continue       # Ignorar líneas vacías
            declare "$key=$value"
        done < ~/network_credentials.txt
        
        if [ "$CONNECTION_TYPE" = "wifi" ] && [ -n "$WIFI_SSID" ] && [ -n "$WIFI_PASSWORD" ]; then
            echo -e "${CYAN}Configurando WiFi: $WIFI_SSID${RESET}"
            
            # Iniciar NetworkManager si no está activo
            sudo systemctl start NetworkManager 2>/dev/null
            sleep 2
            
            # Conectar a WiFi usando nmcli
            if nmcli device wifi connect "$WIFI_SSID" password "$WIFI_PASSWORD" 2>/dev/null; then
                echo -e "${GREEN}✅ WiFi configurado correctamente${RESET}"
                return 0
            else
                echo -e "${YELLOW}⚠ Intentando método alternativo...${RESET}"
                # Método alternativo con iwctl
                if command -v iwctl >/dev/null 2>&1; then
                    iwctl station wlan0 connect "$WIFI_SSID" --passphrase "$WIFI_PASSWORD" 2>/dev/null && \
                    echo -e "${GREEN}✅ WiFi configurado con iwctl${RESET}" && return 0
                fi
            fi
            
        elif [ "$CONNECTION_TYPE" = "ethernet" ] && [ -n "$ETHERNET_INTERFACE" ]; then
            echo -e "${CYAN}Configurando Ethernet: $ETHERNET_INTERFACE${RESET}"
            
            # Activar interface y obtener IP
            sudo ip link set "$ETHERNET_INTERFACE" up
            sudo dhcpcd "$ETHERNET_INTERFACE" 2>/dev/null &
            sleep 3
            
            if ping -c 1 archlinux.org >/dev/null 2>&1; then
                echo -e "${GREEN}✅ Ethernet configurado correctamente${RESET}"
                return 0
            fi
        fi
    fi
    
    # Si no hay configuración o falló, usar configuración automática
    echo -e "${YELLOW}Intentando configuración automática...${RESET}"
    
    # Intentar ethernet primero
    for interface in $(ip link show | grep -oE "en[a-zA-Z0-9]+" | head -1); do
        sudo ip link set "$interface" up 2>/dev/null
        sudo dhcpcd "$interface" 2>/dev/null &
        sleep 3
        if ping -c 1 archlinux.org >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Ethernet automático configurado${RESET}"
            return 0
        fi
    done
    
    # Si ethernet falla, mostrar redes WiFi disponibles
    echo -e "${CYAN}Redes WiFi disponibles:${RESET}"
    if command -v nmcli >/dev/null 2>&1; then
        sudo systemctl start NetworkManager 2>/dev/null
        sleep 2
        nmcli device wifi list 2>/dev/null | head -10
        
        echo -e "\n${YELLOW}Para conectar manualmente use:${RESET}"
        echo -e "${WHITE}nmcli device wifi connect 'NOMBRE_RED' password 'CONTRASEÑA'${RESET}"
    fi
    
    return 1
}

# Configurar red y verificar conexión
configure_network
if ! ping -c 3 archlinux.org >/dev/null 2>&1; then
    echo -e "${RED}❌ Sin conexión a internet.${RESET}"
    echo -e "${YELLOW}Configure manualmente la red y ejecute el script de nuevo.${RESET}"
    echo -e "${WHITE}Comandos útiles:${RESET}"
    echo -e "  • ${CYAN}nmcli device wifi list${RESET} - Ver redes disponibles"
    echo -e "  • ${CYAN}nmcli device wifi connect 'RED' password 'CLAVE'${RESET} - Conectar WiFi"
    echo -e "  • ${CYAN}sudo dhcpcd enp0s3${RESET} - Configurar ethernet (cambiar interfaz)"
    exit 1
fi
echo -e "${GREEN}✅ Conexión verificada${RESET}\n"

# Actualizar sistema
echo -e "${CYAN}Actualizando sistema...${RESET}"
sudo pacman -Syu --noconfirm

# Instalar paquetes adicionales
echo -e "\n${CYAN}Instalando paquetes adicionales...${RESET}"
ADDITIONAL_PACKAGES=(
    "base-devel"
    "vim"
    "git"
    "wget"
    "curl"
    "htop"
    "neofetch"
    "bash-completion"
    "man-db"
    "man-pages"
    "zip"
    "unzip"
    "reflector"
    "python"
    "python-pip"
)

for package in "${ADDITIONAL_PACKAGES[@]}"; do
    echo -ne "${WHITE}Instalando $package...${RESET} "
    if sudo pacman -S --noconfirm "$package" >/dev/null 2>&1; then
        echo -e "${GREEN}✅${RESET}"
    else
        echo -e "${RED}❌${RESET}"
    fi
done

# Instalar módulo tabulate para el script de redes WiFi
echo -e "\n${CYAN}Instalando módulo Python para gestión WiFi...${RESET}"
if command -v pip >/dev/null 2>&1; then
    pip install tabulate --break-system-packages 2>/dev/null || \
    pip install --user tabulate 2>/dev/null && \
    echo -e "${GREEN}✅ Módulo tabulate instalado${RESET}" || \
    echo -e "${YELLOW}⚠ No se pudo instalar tabulate (opcional)${RESET}"
fi

# Hacer ejecutable el script WiFi
if [ -f ~/wifi_networks.py ]; then
    chmod +x ~/wifi_networks.py
    echo -e "${GREEN}✅ Script wifi_networks.py configurado${RESET}"
fi

# Instalar paquetes BSPWM (opcional)
echo -e "\n${YELLOW}¿Desea instalar el entorno BSPWM completo? [S/n]:${RESET} "
read -r install_bspwm
if [[ ! "$install_bspwm" =~ ^[Nn]$ ]]; then
    echo -e "${CYAN}Instalando entorno BSPWM...${RESET}"
    
    BSPWM_PACKAGES=(
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
    )
    
    for package in "${BSPWM_PACKAGES[@]}"; do
        echo -ne "${WHITE}Instalando $package...${RESET} "
        if sudo pacman -S --noconfirm "$package" >/dev/null 2>&1; then
            echo -e "${GREEN}✅${RESET}"
        else
            echo -e "${RED}❌${RESET}"
        fi
    done
    
    # Instalar tema gh0stzk
    echo -e "\n${CYAN}Instalando tema gh0stzk...${RESET}"
    cd ~ && \
    curl -O https://raw.githubusercontent.com/gh0stzk/dotfiles/master/RiceInstaller && \
    chmod +x RiceInstaller && \
    ./RiceInstaller
fi

# Servicios adicionales
echo -e "\n${CYAN}Habilitando servicios adicionales...${RESET}"
ADDITIONAL_SERVICES=(
    "bluetooth"
    "sshd"
    "fstrim.timer"
)

for service in "${ADDITIONAL_SERVICES[@]}"; do
    echo -ne "${WHITE}Habilitando $service...${RESET} "
    if sudo systemctl enable "$service" >/dev/null 2>&1; then
        echo -e "${GREEN}✅${RESET}"
    else
        echo -e "${RED}❌${RESET}"
    fi
done

# Configuración adicional de red
echo -e "\n${CYAN}Configurando NetworkManager permanentemente...${RESET}"
sudo systemctl enable NetworkManager

echo -e "\n${GREEN}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                  ✅ POST-INSTALACIÓN COMPLETADA                  ║"
echo "║                                                                  ║"
echo "║  El sistema está completamente configurado y listo para usar.   ║"
echo "║                                                                  ║"
echo "║  📶 GESTIÓN DE REDES WiFi:                                       ║"
echo "║  • ./wifi_networks.py - Ver y obtener claves WiFi guardadas     ║"
echo "║  • nmcli device wifi list - Listar redes disponibles            ║"
echo "║  • nmcli device wifi connect 'RED' password 'CLAVE' - Conectar  ║"
echo "║                                                                  ║"
echo "║  Para ejecutar este script nuevamente: ./post-install.sh        ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# Auto-eliminar script después de uso exitoso
echo -e "${YELLOW}¿Desea eliminar este script? [S/n]:${RESET} "
read -r delete_script
if [[ ! "$delete_script" =~ ^[Nn]$ ]]; then
    rm -f "$0"
    echo -e "${GREEN}Script eliminado.${RESET}"
fi
EOF
    
    # Hacer ejecutable el script
    chmod +x "/mnt/home/$USERNAME/post-install.sh"
    
    # Cambiar propietario
    arch-chroot /mnt chown "$USERNAME:$USERNAME" "/home/$USERNAME/post-install.sh"
    
    # Crear mensaje de bienvenida
    cat > "/mnt/home/$USERNAME/.bashrc_post_install" <<EOF

# Mensaje de post-instalación (se elimina después del primer uso)
if [ -f ~/post-install.sh ]; then
    echo -e "\033[0;33m"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                     ⚡ INSTALACIÓN BÁSICA                        ║"
    echo "║                                                                  ║"
    echo "║  Para completar la instalación ejecuta: ./post-install.sh       ║"
    echo "║                                                                  ║"
    echo "║  Esto instalará paquetes adicionales y el entorno BSPWM         ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "\033[0m"
fi
EOF
    
    # Añadir al .bashrc principal
    echo "" >> "/mnt/home/$USERNAME/.bashrc"
    echo "# Post-instalación" >> "/mnt/home/$USERNAME/.bashrc"
    echo "source ~/.bashrc_post_install 2>/dev/null" >> "/mnt/home/$USERNAME/.bashrc"
    
    arch-chroot /mnt chown "$USERNAME:$USERNAME" "/home/$USERNAME/.bashrc_post_install"
    
    # Copiar configuración de red si existe
    if [ -f /tmp/zeuspyec_install/network_credentials.txt ]; then
        cp /tmp/zeuspyec_install/network_credentials.txt "/mnt/home/$USERNAME/network_credentials.txt"
        arch-chroot /mnt chown "$USERNAME:$USERNAME" "/home/$USERNAME/network_credentials.txt"
        log "INFO" "Archivo network_credentials.txt copiado al sistema instalado"
    fi
    
    # Copiar el script wifi_networks.py si existe
    if [ -f wifi_networks.py ]; then
        cp wifi_networks.py "/mnt/home/$USERNAME/wifi_networks.py"
        chmod +x "/mnt/home/$USERNAME/wifi_networks.py"
        arch-chroot /mnt chown "$USERNAME:$USERNAME" "/home/$USERNAME/wifi_networks.py"
        log "INFO" "Script wifi_networks.py copiado al sistema"
    fi
    
    log "SUCCESS" "Script post-instalación creado en /home/$USERNAME/post-install.sh"
}

create_standalone_post_install() {
    log "INFO" "Creando script post-instalación independiente"
    
    # Crear script independiente que se puede usar desde GitHub
    cat > "/mnt/home/$USERNAME/zeuspyec-post-install.sh" <<'SCRIPT_EOF'
#!/bin/bash

# Script de Post-Instalación ZeuspyEC (Independiente)
# Puede ejecutarse después de cualquier instalación básica de Arch Linux
# Para descargar: curl -O https://raw.githubusercontent.com/tu-usuario/repo/main/zeuspyec-post-install.sh

# Colores para output
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
WHITE="\033[0;37m"
RESET="\033[0m"

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                   POST-INSTALACIÓN ZEUSPYEC                     ║"
echo "║              Completando instalación del sistema                ║"
echo "║                Script independiente v1.0                        ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${RESET}\n"

# Función para configurar red automáticamente
configure_network() {
    echo -e "${CYAN}Configurando conexión de red...${RESET}"
    
    # Verificar si hay configuración guardada de instalación previa
    if [ -f ~/network_credentials.txt ]; then
        echo -e "${GREEN}✅ Archivo de credenciales encontrado${RESET}"
        
        # Leer archivo de credenciales (ignorar comentarios)
        while IFS='=' read -r key value; do
            [[ $key =~ ^#.*$ ]] && continue  # Ignorar comentarios
            [[ -z $key ]] && continue       # Ignorar líneas vacías
            declare "$key=$value"
        done < ~/network_credentials.txt
        
        if [ "$CONNECTION_TYPE" = "wifi" ] && [ -n "$WIFI_SSID" ] && [ -n "$WIFI_PASSWORD" ]; then
            echo -e "${CYAN}Configurando WiFi guardado: $WIFI_SSID${RESET}"
            
            # Iniciar NetworkManager si no está activo
            sudo systemctl start NetworkManager 2>/dev/null
            sleep 2
            
            # Conectar a WiFi usando nmcli
            if nmcli device wifi connect "$WIFI_SSID" password "$WIFI_PASSWORD" 2>/dev/null; then
                echo -e "${GREEN}✅ WiFi configurado correctamente${RESET}"
                return 0
            else
                echo -e "${YELLOW}⚠ Reintentando con método alternativo...${RESET}"
                # Método alternativo con iwctl
                if command -v iwctl >/dev/null 2>&1; then
                    iwctl station wlan0 connect "$WIFI_SSID" --passphrase "$WIFI_PASSWORD" 2>/dev/null && \
                    echo -e "${GREEN}✅ WiFi configurado con iwctl${RESET}" && return 0
                fi
            fi
            
        elif [ "$CONNECTION_TYPE" = "ethernet" ] && [ -n "$ETHERNET_INTERFACE" ]; then
            echo -e "${CYAN}Configurando Ethernet guardado: $ETHERNET_INTERFACE${RESET}"
            
            # Activar interface y obtener IP
            sudo ip link set "$ETHERNET_INTERFACE" up
            sudo dhcpcd "$ETHERNET_INTERFACE" 2>/dev/null &
            sleep 3
            
            if ping -c 1 archlinux.org >/dev/null 2>&1; then
                echo -e "${GREEN}✅ Ethernet configurado correctamente${RESET}"
                return 0
            fi
        fi
    else
        echo -e "${YELLOW}⚠ No se encontró archivo de credenciales previas${RESET}"
    fi
    
    # Configuración manual/automática
    echo -e "${YELLOW}Configurando red manualmente...${RESET}"
    
    # Preguntar tipo de conexión
    echo -e "\n${CYAN}Tipo de conexión:${RESET}"
    echo -e "  ${WHITE}1)${RESET} Ethernet (automático)"
    echo -e "  ${WHITE}2)${RESET} WiFi (manual)"
    echo -e "  ${WHITE}3)${RESET} Saltar configuración"
    echo -ne "\n${YELLOW}Seleccione opción (1-3):${RESET} "
    read -r network_choice
    
    case $network_choice in
        1)
            # Configurar ethernet automáticamente
            echo -e "${CYAN}Configurando ethernet...${RESET}"
            for interface in $(ip link show | grep -oE "en[a-zA-Z0-9]+" | head -1); do
                sudo ip link set "$interface" up 2>/dev/null
                sudo dhcpcd "$interface" 2>/dev/null &
                sleep 3
                if ping -c 1 archlinux.org >/dev/null 2>&1; then
                    echo -e "${GREEN}✅ Ethernet configurado${RESET}"
                    return 0
                fi
            done
            ;;
        2)
            # Configurar WiFi manualmente
            echo -e "${CYAN}Configurando WiFi...${RESET}"
            sudo systemctl start NetworkManager 2>/dev/null
            sleep 2
            
            echo -e "\n${CYAN}Redes WiFi disponibles:${RESET}"
            nmcli device wifi list 2>/dev/null | head -10
            
            echo -ne "\n${YELLOW}SSID de la red:${RESET} "
            read -r manual_ssid
            echo -ne "${YELLOW}Contraseña:${RESET} "
            read -rs manual_password
            echo
            
            if nmcli device wifi connect "$manual_ssid" password "$manual_password" 2>/dev/null; then
                echo -e "${GREEN}✅ WiFi configurado manualmente${RESET}"
                return 0
            fi
            ;;
        3)
            echo -e "${YELLOW}⚠ Configuración de red omitida${RESET}"
            return 1
            ;;
    esac
    
    return 1
}

# Verificar privilegios sudo
if ! sudo -n true 2>/dev/null; then
    echo -e "${YELLOW}Este script requiere privilegios sudo${RESET}"
    echo -e "${WHITE}Por favor, ingrese su contraseña:${RESET}"
    sudo true
fi

# Configurar red
configure_network
if ! ping -c 3 archlinux.org >/dev/null 2>&1; then
    echo -e "${RED}❌ Sin conexión a internet.${RESET}"
    echo -e "${YELLOW}Configure manualmente la red y ejecute el script de nuevo.${RESET}"
    echo -e "\n${WHITE}Comandos útiles:${RESET}"
    echo -e "  • ${CYAN}nmcli device wifi list${RESET} - Ver redes WiFi"
    echo -e "  • ${CYAN}nmcli device wifi connect 'RED' password 'CLAVE'${RESET} - Conectar WiFi"
    echo -e "  • ${CYAN}sudo dhcpcd enp0s3${RESET} - Configurar ethernet"
    exit 1
fi
echo -e "${GREEN}✅ Conexión verificada${RESET}\n"

# Actualizar sistema
echo -e "${CYAN}Actualizando sistema...${RESET}"
sudo pacman -Syu --noconfirm

# Instalar paquetes esenciales
echo -e "\n${CYAN}Instalando paquetes esenciales...${RESET}"
ESSENTIAL_PACKAGES=(
    "base-devel"
    "git"
    "wget"
    "curl"
    "vim"
    "htop"
    "neofetch"
    "python"
    "python-pip"
    "bash-completion"
    "man-db"
    "zip"
    "unzip"
)

for package in "${ESSENTIAL_PACKAGES[@]}"; do
    echo -ne "${WHITE}Instalando $package...${RESET} "
    if sudo pacman -S --noconfirm "$package" >/dev/null 2>&1; then
        echo -e "${GREEN}✅${RESET}"
    else
        echo -e "${RED}❌${RESET}"
    fi
done

# Preguntar por BSPWM
echo -e "\n${YELLOW}¿Instalar entorno gráfico BSPWM? [S/n]:${RESET} "
read -r install_bspwm
if [[ ! "$install_bspwm" =~ ^[Nn]$ ]]; then
    echo -e "${CYAN}Instalando entorno BSPWM...${RESET}"
    
    BSPWM_PACKAGES=(
        "xorg" "xorg-xinit"
        "bspwm" "sxhkd"
        "polybar" "picom"
        "rofi" "nitrogen"
        "alacritty" "firefox"
        "thunar" "lxappearance"
        "pulseaudio" "pavucontrol"
    )
    
    for package in "${BSPWM_PACKAGES[@]}"; do
        echo -ne "${WHITE}Instalando $package...${RESET} "
        if sudo pacman -S --noconfirm "$package" >/dev/null 2>&1; then
            echo -e "${GREEN}✅${RESET}"
        else
            echo -e "${RED}❌${RESET}"
        fi
    done
    
    # Instalar tema
    echo -e "\n${CYAN}¿Instalar tema gh0stzk? [S/n]:${RESET} "
    read -r install_theme
    if [[ ! "$install_theme" =~ ^[Nn]$ ]]; then
        cd ~ && \
        curl -O https://raw.githubusercontent.com/gh0stzk/dotfiles/master/RiceInstaller && \
        chmod +x RiceInstaller && \
        echo -e "${GREEN}✅ Tema descargado. Ejecute: ./RiceInstaller${RESET}"
    fi
fi

# Configurar servicios
echo -e "\n${CYAN}Configurando servicios...${RESET}"
sudo systemctl enable NetworkManager
sudo systemctl enable bluetooth 2>/dev/null

echo -e "\n${GREEN}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                  ✅ POST-INSTALACIÓN COMPLETADA                  ║"
echo "║                                                                  ║"
echo "║  🎯 PRÓXIMOS PASOS:                                              ║"
echo "║  • Reiniciar el sistema                                          ║"
echo "║  • Si instaló BSPWM: ./RiceInstaller (para el tema)             ║"
echo "║  • Configurar aplicaciones adicionales                          ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

echo -e "${YELLOW}¿Reiniciar ahora? [S/n]:${RESET} "
read -r reboot_now
if [[ ! "$reboot_now" =~ ^[Nn]$ ]]; then
    sudo reboot
fi
SCRIPT_EOF

    # Hacer ejecutable el script independiente
    chmod +x "/mnt/home/$USERNAME/zeuspyec-post-install.sh"
    arch-chroot /mnt chown "$USERNAME:$USERNAME" "/home/$USERNAME/zeuspyec-post-install.sh"
    
    log "SUCCESS" "Script independiente creado: zeuspyec-post-install.sh"
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
    echo -e "\n${YELLOW}¿Desea reiniciar el sistema ahora? [S/n]:${RESET} "
    read -r reboot_choice
    
    if [[ ! "$reboot_choice" =~ ^[Nn]$ ]]; then
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

# ==============================================================================
# Función Principal
# ==============================================================================

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
    
    echo -e "\n${YELLOW}¿Desea intentar continuar? [S/n]:${RESET} "
    read -r response
    
    if [[ ! "$response" =~ ^[Nn]$ ]]; then
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
                echo -e "\n${YELLOW}¿Desea reintentar '$*'? [S/n]:${RESET} "
                read -r response
                if [[ ! "$response" =~ ^[Nn]$ ]]; then
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

main() {
    # Iniciar contador de tiempo
    local start_time
    start_time=$(date +%s)
    
    # Inicializar script
    init_script
    
    # Pasos de instalación
    local installation_steps=(
        "check_system_requirements"
        "check_network_connectivity"
        "configure_mirrorlist"  # <-- AÑADE ESTA LÍNEA
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
