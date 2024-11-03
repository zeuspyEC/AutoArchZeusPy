#!/usr/bin/env bash

# ==============================================================================
# Instalador Mejorado de Arch Linux
# Versión: 2.0
# ==============================================================================

# Habilitar modo estricto
set -euo pipefail
IFS=$'\n\t'

# Variables globales y constantes
declare -g SCRIPT_VERSION="2.0"
declare -g selected_partition=""
declare -g language=""
declare -g keyboard_layout=""
declare -g hostname=""
declare -g username=""
declare -g boot_mode=""
declare -g TARGET_DISK=""
declare -g REQUIRED_PACKAGES=(
    "base"
    "base-devel"
    "linux"
    "linux-firmware"
    "networkmanager"
    "grub"
    "efibootmgr"
)

# Configuración del sistema de logging
LOG_FILE="/tmp/arch_installer.log"
ERROR_LOG="/tmp/arch_installer_error.log"
DEBUG_LOG="/tmp/arch_installer_debug.log"

# Variables de colores
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Crear archivos de log vacíos
: > "$LOG_FILE"
: > "$ERROR_LOG"
: > "$DEBUG_LOG"

# Función para imprimir información del sistema
print_system_info() {
    {
        echo "=== Sistema Info ==="
        echo "Kernel: $(uname -a)"
        echo "CPU: $(grep "model name" /proc/cpuinfo | head -n1)"
        echo "Memoria: $(free -h)"
        echo "Disco: $(df -h)"
        echo "Network: $(ip addr)"
        echo "==================="
    } 2>/dev/null || true
}

# Función de logging
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local line_number="${BASH_LINENO[0]}"
    local function_name="${FUNCNAME[1]:-main}"
    
    # Sanitizar mensaje
    message=$(echo "$message" | tr -cd '[:print:]\n')
    
    # Formato de log
    local log_message="[$timestamp] [$level] [$function_name:$line_number] $message"
    
    case "$level" in
        "DEBUG")
            echo -e "${CYAN}$log_message${NC}" >> "$DEBUG_LOG"
            ;;
        "INFO")
            echo -e "${GREEN}$log_message${NC}" | tee -a "$LOG_FILE"
            ;;
        "WARN")
            echo -e "${YELLOW}$log_message${NC}" | tee -a "$LOG_FILE"
            ;;
        "ERROR")
            echo -e "${RED}$log_message${NC}" | tee -a "$ERROR_LOG"
            print_system_info >> "$ERROR_LOG"
            ;;
    esac
}

# Función para ejecutar comandos con logging
execute_with_log() {
    local command=("$@")
    local function_name="${FUNCNAME[1]:-main}"
    
    log "DEBUG" "Ejecutando comando: ${command[*]}"
    
    if output=$("${command[@]}" 2>&1); then
        log "INFO" "Comando exitoso: ${command[*]}"
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

# Función para verificar requisitos del sistema
check_system_requirements() {
    log "INFO" "Verificando requisitos del sistema"
    
    # Verificar espacio en disco
    local min_space=$((20 * 1024 * 1024 * 1024))
    local available_space
    available_space=$(df -B1 --output=avail / | tail -n1)
    
    if [[ "$available_space" -lt "$min_space" ]]; then
        log "ERROR" "Espacio insuficiente: $(numfmt --to=iec-i --suffix=B "$available_space") < 20GB"
        return 1
    fi
    
    # Verificar memoria
    local min_ram=1024
    local total_ram
    total_ram=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    
    if [[ "$total_ram" -lt "$min_ram" ]]; then
        log "ERROR" "RAM insuficiente: ${total_ram}MB < ${min_ram}MB"
        return 1
    fi
    
    # Verificar arquitectura
    local arch
    arch=$(uname -m)
    
    if [[ "$arch" != "x86_64" ]]; then
        log "ERROR" "Arquitectura no soportada: $arch"
        return 1
    fi
    
    # Verificar modo de arranque
    if [[ -d "/sys/firmware/efi/efivars" ]]; then
        boot_mode="UEFI"
        log "INFO" "Sistema en modo UEFI"
    else
        boot_mode="BIOS"
        log "INFO" "Sistema en modo BIOS"
    fi
    
    # Verificar conexión a Internet
    if ! ping -c 1 -W 5 archlinux.org &>/dev/null; then
        log "ERROR" "No hay conexión a Internet"
        echo -e "${RED}Error: Se requiere conexión a Internet.${NC}"
        return 1
    fi
    
    log "INFO" "Requisitos del sistema verificados correctamente"
    return 0
}

check_network_connectivity() {
    log "INFO" "Verificando conectividad de red"
    
    local test_hosts=("archlinux.org" "google.com" "cloudflare.com")
    local connected=false
    
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 5 "$host" &>/dev/null; then
            connected=true
            log "INFO" "Conexión exitosa a $host"
            break
        fi
    done
    
    if ! $connected; then
        log "WARN" "No hay conexión a Internet"
        setup_network_connection
        return $?
    fi
    
    return 0
}

setup_network_connection() {
    log "INFO" "Configurando conexión de red"
    
    # Detectar interfaces de red
    local wireless_interfaces
    wireless_interfaces=($(iwctl device list 2>/dev/null | grep -oE "wlan[0-9]"))
    
    if [[ ${#wireless_interfaces[@]} -eq 0 ]]; then
        log "WARN" "No se detectaron interfaces wireless"
        setup_ethernet_connection
        return $?
    fi
    
    # Intentar conexión wireless
    for interface in "${wireless_interfaces[@]}"; do
        log "INFO" "Intentando conectar usando $interface"
        
        # Escanear redes
        iwctl station "$interface" scan
        
        # Mostrar redes disponibles
        iwctl station "$interface" get-networks
        
        # Solicitar datos de conexión
        echo -e "${BLUE}Ingrese el nombre de la red (SSID):${NC}"
        read -r ssid
        
        echo -e "${BLUE}Ingrese la contraseña:${NC}"
        read -rs password
        
        if iwctl station "$interface" connect "$ssid" --passphrase "$password"; then
            sleep 3
            if ping -c 1 archlinux.org &>/dev/null; then
                log "INFO" "Conexión establecida exitosamente"
                return 0
            fi
        fi
        
        log "WARN" "Fallo al conectar con $interface"
    done
    
    log "ERROR" "No se pudo establecer conexión wireless"
    return 1
}

setup_ethernet_connection() {
    log "INFO" "Configurando conexión ethernet"
    
    local ethernet_interfaces
    ethernet_interfaces=($(ip link show | grep -E "^[0-9]+: en" | cut -d: -f2))
    
    for interface in "${ethernet_interfaces[@]}"; do
        interface=$(echo "$interface" | tr -d ' ')
        log "INFO" "Intentando configurar $interface"
        
        ip link set "$interface" up
        if dhcpcd "$interface"; then
            sleep 3
            if ping -c 1 archlinux.org &>/dev/null; then
                log "INFO" "Conexión ethernet establecida"
                return 0
            fi
        fi
    done
    
    log "ERROR" "No se pudo establecer conexión ethernet"
    return 1
}

# ==============================================================================
# Funciones de Particionamiento
# ==============================================================================

prepare_disk() {
    log "INFO" "Preparando disco para instalación"
    
    # Listar discos disponibles
    local available_disks
    available_disks=($(lsblk -dpno NAME,SIZE,TYPE | grep disk))
    
    echo -e "${BLUE}Discos disponibles:${NC}"
    printf '%s\n' "${available_disks[@]}" | nl
    
    # Seleccionar disco
    while true; do
        echo -e "${BLUE}Seleccione el número del disco para la instalación:${NC}"
        read -r disk_number
        
        if [[ $disk_number =~ ^[0-9]+$ ]] && \
           [[ $disk_number -le ${#available_disks[@]} ]] && \
           [[ $disk_number -gt 0 ]]; then
            TARGET_DISK=$(echo "${available_disks[$((disk_number-1))]}" | cut -d' ' -f1)
            break
        fi
        
        log "WARN" "Selección inválida"
    done
    
    # Confirmar selección
    echo -e "${RED}¡ADVERTENCIA! Se borrarán todos los datos en $TARGET_DISK${NC}"
    echo -e "${BLUE}¿Está seguro? (s/N):${NC}"
    read -r confirm
    
    if [[ ! $confirm =~ ^[Ss]$ ]]; then
        log "INFO" "Operación cancelada por el usuario"
        return 1
    fi
    
    # Crear esquema de particiones según modo de arranque
    if [[ "$BOOT_MODE" == "UEFI" ]]; then
        create_uefi_partitions
    else
        create_bios_partitions
    fi
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
    
    # Crear tabla GPT
    if ! parted -s "$TARGET_DISK" mklabel gpt; then
        log "ERROR" "Fallo al crear tabla GPT"
        return 1
    fi
    
    # Crear particiones
    if ! parted -s "$TARGET_DISK" \
        mkpart ESP fat32 1MiB "${efi_size}MiB" \
        set 1 esp on \
        mkpart primary ext4 "${efi_size}MiB" "$((efi_size + root_size))MiB" \
        mkpart primary linux-swap "$((efi_size + root_size))MiB" 100%; then
        log "ERROR" "Fallo al crear particiones UEFI"
        return 1
    fi
    
    # Formatear particiones
    local efi_part="${TARGET_DISK}1"
    local root_part="${TARGET_DISK}2"
    local swap_part="${TARGET_DISK}3"
    
    if ! mkfs.fat -F32 "$efi_part" && \
       ! mkfs.ext4 -F "$root_part" && \
       ! mkswap "$swap_part" && \
       ! swapon "$swap_part"; then
        log "ERROR" "Fallo al formatear particiones"
        return 1
    fi
    
    # Montar particiones
    mount "$root_part" /mnt
    mkdir -p /mnt/boot/efi
    mount "$efi_part" /mnt/boot/efi
    
    log "INFO" "Particionamiento UEFI completado"
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
    
    if ! mkfs.ext4 -F "$boot_part" && \
       ! mkfs.ext4 -F "$root_part" && \
       ! mkswap "$swap_part" && \
       ! swapon "$swap_part"; then
        log "ERROR" "Fallo al formatear particiones"
        return 1
    fi
    
    # Montar particiones
    mount "$root_part" /mnt
    mkdir -p /mnt/boot
    mount "$boot_part" /mnt/boot
    
    log "INFO" "Particionamiento BIOS completado"
    return 0
}

# ==============================================================================
# Funciones de Instalación Base
# ==============================================================================

install_base_system() {
    log "INFO" "Instalando sistema base"
    
    # Actualizar mirrors
    if ! update_mirrors; then
        log "WARN" "Fallo al actualizar mirrors, continuando con los predeterminados"
    fi
    
    # Instalar paquetes base
    if ! pacstrap /mnt "${REQUIRED_PACKAGES[@]}"; then
        log "ERROR" "Fallo al instalar sistema base"
        return 1
    fi
    
    # Generar fstab
    if ! genfstab -U /mnt >> /mnt/etc/fstab; then
        log "ERROR" "Fallo al generar fstab"
        return 1
    fi
    
    # Verificar fstab generado
    if ! grep -q "UUID" /mnt/etc/fstab; then
        log "ERROR" "fstab generado incorrectamente"
        return 1
    fi
    
    log "INFO" "Sistema base instalado correctamente"
    return 0
}

update_mirrors() {
    log "INFO" "Actualizando lista de mirrors"
    
    # Backup del mirrorlist actual
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
    
    # Intentar usar reflector para optimizar mirrors
    if command -v reflector &>/dev/null; then
        if ! reflector --latest 20 \
                      --protocol https \
                      --sort rate \
                      --save /etc/pacman.d/mirrorlist; then
            log "WARN" "Fallo al actualizar mirrors con reflector"
            return 1
        fi
    else
        log "WARN" "reflector no está instalado, usando mirrors por defecto"
        return 1
    fi
    
    return 0
}

# ==============================================================================
# Funciones de Configuración del Sistema
# ==============================================================================

configure_system() {
    log "INFO" "Iniciando configuración del sistema"
    
    # Array de funciones de configuración
    local config_functions=(
        "configure_hostname"
        "configure_timezone"
        "configure_locale"
        "configure_users"
        "configure_network"
        "configure_bootloader"
    )
    
    # Ejecutar cada función de configuración
    for func in "${config_functions[@]}"; do
        log "INFO" "Ejecutando $func"
        if ! $func; then
            log "ERROR" "Fallo en $func"
            return 1
        fi
    done
    
    return 0
}

configure_hostname() {
    log "INFO" "Configurando hostname"
    
    # Solicitar hostname
    while true; do
        echo -e "${BLUE}Ingrese el hostname para el sistema:${NC}"
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
    
    return 0
}

configure_timezone() {
    log "INFO" "Configurando zona horaria"
    
    # Listar zonas horarias disponibles
    local zones
    zones=($(find /usr/share/zoneinfo -type f -not -path '*/right/*' -not -path '*/posix/*' -printf '%P\n' | sort))
    
    echo -e "${BLUE}Zonas horarias disponibles:${NC}"
    printf '%s\n' "${zones[@]}" | nl
    
    # Seleccionar zona horaria
    while true; do
        echo -e "${BLUE}Seleccione el número de la zona horaria:${NC}"
        read -r zone_number
        
        if [[ $zone_number =~ ^[0-9]+$ ]] && \
           [[ $zone_number -le ${#zones[@]} ]] && \
           [[ $zone_number -gt 0 ]]; then
            TIMEZONE="${zones[$((zone_number-1))]}"
            break
        fi
        
        log "WARN" "Selección inválida"
    done
    
    # Configurar zona horaria
    arch-chroot /mnt ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    arch-chroot /mnt hwclock --systohc
    
    return 0
}

configure_locale() {
    log "INFO" "Configurando idioma del sistema"
    
    # Preparar locale.gen
    sed -i 's/#\(en_US.UTF-8\)/\1/' /mnt/etc/locale.gen
    sed -i 's/#\(es_ES.UTF-8\)/\1/' /mnt/etc/locale.gen
    
    # Generar locales
    if ! arch-chroot /mnt locale-gen; then
        log "ERROR" "Fallo al generar locales"
        return 1
    fi
    
    # Configurar idioma por defecto
    echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
    
    # Configurar teclado
    echo "KEYMAP=es" > /mnt/etc/vconsole.conf
    
    return 0
}

configure_users() {
    log "INFO" "Configurando usuarios"
    
    # Configurar contraseña de root
    echo -e "${BLUE}Ingrese contraseña para root:${NC}"
    if ! arch-chroot /mnt passwd; then
        log "ERROR" "Fallo al configurar contraseña de root"
        return 1
    fi
    
    # Crear usuario normal
    while true; do
        echo -e "${BLUE}Ingrese nombre para el nuevo usuario:${NC}"
        read -r USERNAME
        
        if [[ "$USERNAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
            break
        else
            log "WARN" "Nombre de usuario inválido. Use letras minúsculas, números y guiones"
        fi
    done
    
    # Crear usuario y agregarlo a grupos
    if ! arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$USERNAME"; then
        log "ERROR" "Fallo al crear usuario"
        return 1
    fi
    
    # Configurar contraseña del usuario
    echo -e "${BLUE}Ingrese contraseña para $USERNAME:${NC}"
    if ! arch-chroot /mnt passwd "$USERNAME"; then
        log "ERROR" "Fallo al configurar contraseña de usuario"
        return 1
    fi
    
    # Configurar sudo
    echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/wheel
    chmod 440 /mnt/etc/sudoers.d/wheel
    
    return 0
}

configure_network() {
    log "INFO" "Configurando red"
    
    # Habilitar NetworkManager
    if ! arch-chroot /mnt systemctl enable NetworkManager; then
        log "ERROR" "Fallo al habilitar NetworkManager"
        return 1
    fi
    
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
    
    # Generar configuración
    if ! arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg; then
        log "ERROR" "Fallo al generar configuración de GRUB"
        return 1
    fi
    
    return 0
}

# ==============================================================================
# Función Principal
# ==============================================================================

main() {
    local start_time
    start_time=$(date +%s)
    
    log "INFO" "Iniciando instalación de Arch Linux (v$SCRIPT_VERSION)"
    
    # Verificar root
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "Este script debe ejecutarse como root"
        exit 1
    fi
    
    # Pasos de instalación
    local installation_steps=(
        "check_system_requirements"
        "check_network_connectivity"
        "prepare_disk"
        "install_base_system"
        "configure_system"
    )
    
    # Ejecutar pasos de instalación
    for step in "${installation_steps[@]}"; do
        log "INFO" "Ejecutando: ${step//_/ }"
        if ! $step; then
            log "ERROR" "Instalación fallida en: $step"
            cleanup
            exit 1
        fi
    done
    
    # Calcular tiempo de instalación
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "INFO" "Instalación completada en $duration segundos"
    
    # Preguntar por reinicio
    echo -e "${GREEN}¡Instalación completada exitosamente!${NC}"
    echo -e "${BLUE}¿Desea reiniciar el sistema ahora? (s/N)${NC}"
    read -r reboot_choice
    
    if [[ "$reboot_choice" =~ ^[Ss]$ ]]; then
        log "INFO" "Reiniciando sistema"
        cleanup
        reboot
    else
        log "INFO" "Reinicio pospuesto"
        cleanup
        echo -e "${YELLOW}Recuerde reiniciar el sistema cuando esté listo${NC}"
    fi
}

cleanup() {
    log "INFO" "Realizando limpieza"
    
    # Desmontar particiones en orden inverso
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
    
    log "INFO" "Limpieza completada"
}

# Iniciar instalación
main "$@"
