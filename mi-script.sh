#!/usr/bin/env bash
# Función para centrar texto
format_center() {
    log "DEBUG" "Formateando texto centrado: $1"
    if [ -z "$1" ]; then
        log "ERROR" "Texto vacío en format_center"
        return 1
    fi  
    local text="$1"
    local width=$(tput cols)
    local padding=$((($width - ${#text}) / 2))
    printf "%*s%s%*s\n" $padding "" "$text" $padding ""
}

# Función para mostrar el banner
display_banner() {
  clear
  local banner_text="${BLUE}███████╗███████╗██╗   ██╗███████╗██████╗ ██╗   ██╗███████╗ ██████╗${NC}"
  format_center "$banner_text"
  local banner_text="${BLUE}╚══███╔╝██╔════╝██║   ██║██╔════╝██╔══██╗╚██╗ ██╔╝██╔════╝██╔════╝${NC}"
  format_center "$banner_text" 
  local banner_text="${BLUE}  ███╔╝ █████╗  ██║   ██║███████╗██████╔╝ ╚████╔╝ █████╗  ██║     ${NC}"
  format_center "$banner_text"
  local banner_text="${BLUE} ███╔╝  ██╔══╝  ██║   ██║╚════██║██╔═══╝   ╚██╔╝  ██╔══╝  ██║     ${NC}"  
  format_center "$banner_text"
  local banner_text="${BLUE}███████╗███████╗╚██████╔╝███████║██║        ██║   ███████╗╚██████╗${NC}"
  format_center "$banner_text"
  local banner_text="${BLUE}╚══════╝╚══════╝ ╚═════╝ ╚══════╝╚═╝        ╚═╝   ╚══════╝ ╚═════╝${NC}"  
  format_center "$banner_text"
  echo
}

# Función de bienvenida
welcome() {
  clear
  display_banner
  
  dialog --backtitle "Instalador de Arch Linux" \
         --title "Bienvenido" \
         --msgbox "Bienvenido al instalador de Arch Linux. Este script te guiará a través del proceso de instalación." \
         10 60
  clear
}

# Habilitar modo estricto  
set -euo pipefail
IFS=$'\n\t'

# Variables globales
declare -g selected_partition=""
declare -g language=""
declare -g keyboard_layout=""
declare -g hostname=""
declare -g username=""  

# Configuración del sistema de logging
readonly LOG_FILE="/tmp/arch_installer.log"
readonly ERROR_LOG="/tmp/arch_installer_error.log" 
readonly DEBUG_LOG="/tmp/arch_installer_debug.log"

# Variables de colores
readonly RED='\033[0;31m'  
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly YELLOW='\033[1;33m'  
readonly NC='\033[0m'

# Inicializar archivos de log
: > "$LOG_FILE"
: > "$ERROR_LOG"  
: > "$DEBUG_LOG"

# Función de logging mejorada
log() {
    local level="$1"  
    shift
    local message="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')" 
    local line_number="${BASH_LINENO[0]}"
    local function_name="${FUNCNAME[1]:-main}"
    
    # Formato de log: [TIMESTAMP] [LEVEL] [FUNCTION:LINE] Message
    local log_message="[$timestamp] [$level] [$function_name:$line_number] $message"
    
    case "$level" in 
        "DEBUG")
            echo "$log_message" >> "$DEBUG_LOG"
            ;;
        "ERROR") 
            {
                echo "$log_message"
                echo "=== Sistema Info ==="
                echo "Kernel: $(uname -a)"  
                echo "Memoria: $(free -h)"
                echo "Disco: $(df -h)"
                echo "Procesos: $(ps aux | grep -i dialog)"
                echo "Variables: $(env)" 
                echo "==================="
            } >> "$ERROR_LOG"
            echo "$log_message" >> "$LOG_FILE"
            ;;
        *)  
            echo "$log_message" >> "$LOG_FILE"
            ;;
    esac
}

# Función para manejar errores
handle_error() {
    local line_number="$1"
    local error_message="$2" 
    local exit_code="${3:-1}"
    local function_name="${FUNCNAME[1]:-main}"
    
    log "ERROR" "Error en $function_name (línea $line_number): $error_message (Código: $exit_code)"
    
    {
        echo "=== Stack Trace ==="
        local frame=0  
        while caller $frame; do
            ((frame++))
        done
        echo "==================="
    } >> "$ERROR_LOG"
    
    if command -v dialog &> /dev/null; then
        dialog --clear \
               --colors \  
               --backtitle "Instalador de Arch Linux" \
               --title "Error" \
               --msgbox "\Z1Error:\Zn\n\n$error_message\n\nRevise el log en: $ERROR_LOG\n\nFunción: $function_name\nLínea: $line_number" \
               12 60 2>> "$ERROR_LOG"
    else 
        echo -e "${RED}Error en $function_name (línea $line_number): $error_message${NC}" >&2
    fi
} 

# Configurar trap para capturar errores
trap 'handle_error ${LINENO} "$BASH_COMMAND" $?' ERR

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

# Función para envolver comandos de dialog
dialog_wrapper() {
    local title="$1" 
    shift
    local args=("$@")
    
    log "DEBUG" "Iniciando dialog: $title con argumentos: ${args[*]}"
    
    local output
    if output=$(dialog --colors \
                      --no-collapse \
                      --backtitle "Instalador de Arch Linux" \ 
                      "${args[@]}" 2>&1); then
        log "INFO" "Dialog exitoso: $title" 
        log "DEBUG" "Salida: $output"
        echo "$output" 
        return 0
    else
        local exit_code=$?
        if [ $exit_code -eq 1 ]; then 
            log "WARN" "Usuario canceló el diálogo: $title"
        else
            log "ERROR" "Error en diálogo ($exit_code): $title" 
        fi
        log "DEBUG" "Salida: $output"
        return $exit_code
    fi
}

# Función para verificar requisitos del sistema
check_system_requirements() {
    log "INFO" "Verificando requisitos del sistema"
    
    # Verificar memoria
    local min_ram=1024  # 1GB en MB 
    local total_ram
    total_ram=$(free -m | awk '/^Mem:/{print $2}')
    
    if [[ "$total_ram" -lt "$min_ram" ]]; then
        log "ERROR" "Memoria RAM insuficiente: $total_ram MB < $min_ram MB"
        dialog_wrapper "Error" --title "Error" --msgbox "Memoria RAM insuficiente para la instalación.\nSe requiere al menos 1GB de RAM." 7 50
        return 1
    fi
    
    # Verificar arquitectura
    local arch
    arch=$(uname -m)
    
    if [[ "$arch" != "x86_64" && "$arch" != "i686" ]]; then
        log "ERROR" "Arquitectura no soportada: $arch"
        dialog_wrapper "Error" --title "Error" --msgbox "Arquitectura no soportada.\nSe requiere un sistema x86_64 o i686." 7 50
        return 1
    fi
    
    # Verificar modo de arranque (UEFI o BIOS)
    if [[ -d "/sys/firmware/efi/efivars" ]]; then
        log "INFO" "Sistema en modo UEFI"
        boot_mode="UEFI"
    else
        log "INFO" "Sistema en modo BIOS"
        boot_mode="BIOS"
    fi
    
    log "INFO" "Requisitos del sistema verificados correctamente"
    return 0  
}

# Función para verificar dependencias
check_dependencies() {
    log "INFO" "Verificando dependencias..."
    local deps=("dialog" "iwd" "ip" "arch-install-scripts" "parted" "genfstab" "arch-chroot")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        log "DEBUG" "Verificando dependencia: $dep"
        if ! command -v "$dep" &>/dev/null; then 
            log "WARN" "Dependencia faltante: $dep"
            missing_deps+=("$dep")
        else
            log "INFO" "Dependencia $dep ya está instalada"  
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "INFO" "Instalando dependencias faltantes: ${missing_deps[*]}"  
        if ! execute_with_log pacman -Sy --noconfirm "${missing_deps[@]}"; then
            log "WARN" "Fallo al instalar algunas dependencias"
            if ! dialog_wrapper "Continuar" --title "Advertencia" --yesno "Fallo al instalar algunas dependencias. ¿Desea continuar de todos modos?" 7 50; then
                log "ERROR" "El usuario decidió cancelar la instalación"
                return 1
            fi
        fi
    fi
    
    return 0
}
# Función para verificar conexión a Internet
check_internet_connection() {
    log "INFO" "Verificando conexión a Internet"
    
    local max_attempts=3
    local current_attempt=1
    
    while [[ $current_attempt -le $max_attempts ]]; do
        if execute_with_log ping -c 1 -W 5 8.8.8.8 &>/dev/null; then
            log "INFO" "Conexión a Internet verificada"
            dialog_wrapper "Éxito" --title "Conexión" --msgbox "Conexión a Internet establecida." 5 40
            return 0  
        fi
        
        log "WARN" "Intento $current_attempt de $max_attempts fallido"
        
        if [[ $current_attempt -lt $max_attempts ]]; then
            if ! dialog_wrapper "Reintento" --title "Error de conexión" --yesno "No se pudo establecer conexión a Internet.\n¿Desea intentar nuevamente?" 7 50; then
                break  
            fi
        fi
        
        ((current_attempt++))
    done
    
    log "ERROR" "No se pudo establecer conexión a Internet"  
    dialog_wrapper "Error" --title "Error" --msgbox "No se pudo establecer conexión a Internet.\nLa instalación no puede continuar." 7 50
    return 1
}

# Función para seleccionar idioma
select_language() { 
    log "INFO" "Seleccionando idioma"
    
    local languages=(
        "en_US.UTF-8" "Inglés (Estados Unidos)"
        "es_ES.UTF-8" "Español (España)"  
        "fr_FR.UTF-8" "Francés (Francia)"
        "de_DE.UTF-8" "Alemán (Alemania)"
    )
    
    while true; do
        language=$(dialog_wrapper "Idioma" \
            --title "Selección de idioma" \
            --menu "Seleccione el idioma para la instalación:" \
            10 50 4 \
            "${languages[@]}" \
            3>&1 1>&2 2>&3)
        
        exit_code=$?
        
        if [[ $exit_code -eq 0 && -n "$language" ]]; then
            log "INFO" "Idioma seleccionado: $language"
            return 0
        elif [[ $exit_code -eq 1 ]]; then
            log "WARN" "No se seleccionó ningún idioma"
            if ! dialog_wrapper "Reintentar" --title "Advertencia" --yesno "No se seleccionó ningún idioma. ¿Desea volver a intentarlo?" 7 50; then
                log "ERROR" "El usuario decidió cancelar la instalación"
                return 1
            fi
        else
            log "ERROR" "Ocurrió un error inesperado en la selección de idioma (código de salida: $exit_code)"
            if ! dialog_wrapper "Reintentar" --title "Error" --yesno "Ocurrió un error inesperado. ¿Desea volver a intentarlo?" 7 50; then
                log "ERROR" "El usuario decidió cancelar la instalación"
                return 1
            fi
        fi
    done
}
# Función para configurar disposición del teclado
set_keyboard_layout() {
    log "INFO" "Configurando disposición del teclado"
    
    local layouts=(
        "us" "Inglés (EE.UU.)"
        "es" "Español"
        "fr" "Francés"
        "de" "Alemán"  
    )
    
    keyboard_layout=$(dialog_wrapper "Teclado" \
        --title "Selección de disposición del teclado" \
        --menu "Seleccione la disposición del teclado:" \
        10 50 4 \
        "${layouts[@]}" \
        3>&1 1>&2 2>&3)
    
    if [[ $? -ne 0 || -z "$keyboard_layout" ]]; then
        log "ERROR" "No se seleccionó una disposición válida del teclado" 
        return 1
    fi
    
    if ! execute_with_log loadkeys "$keyboard_layout"; then
        log "ERROR" "Fallo al establecer la disposición del teclado"
        return 1
    fi
    
    log "INFO" "Disposición del teclado configurada: $keyboard_layout"
    return 0 
}

# Función para seleccionar partición de instalación
select_installation_partition() { log "INFO" "Seleccionando partición de instalación"

local partitions
partitions=$(get_partitions)

if [[ $? -ne 0 ]]; then
    log "ERROR" "Fallo al obtener lista de particiones"
    return 1
fi

selected_partition=$(dialog_wrapper "Partición" \
    --title "Selección de partición" \
    --menu "Seleccione la partición para la instalación:" \
    15 60 6 \
    $partitions \
    3>&1 1>&2 2>&3)

if [[ $? -ne 0 || -z "$selected_partition" ]]; then
    log "ERROR" "No se seleccionó una partición válida"
    return 1
fi

log "INFO" "Partición seleccionada: $selected_partition"
return 0
}
# Función para obtener particiones disponibles
get_partitions() { log "DEBUG" "Obteniendo lista de particiones" local partitions="" local count=0

while IFS= read -r line; do
    if [[ "$line" =~ /dev/ ]] && [[ "$line" =~ (part|lvm) ]]; then
        local device
        local size
        local type
        
        device="$(echo "$line" | awk '{print $1}')"
        size="$(echo "$line" | awk '{print $2}')"
        type="$(echo "$line" | awk '{print $3}')"
        
        partitions="${partitions} ${device} \"${size} - ${type}\" "
        ((count++))
    fi
done < <(lsblk -pn -o NAME,SIZE,TYPE)

if [[ $count -eq 0 ]]; then
    log "ERROR" "No se encontraron particiones disponibles"
    return 1
fi

echo "$partitions"
return 0
}

# Función para particionar el disco
partition_disk() {
    local device="$1"
    log "INFO" "Iniciando particionamiento de disco: $device"
    
    if dialog_wrapper "Particionamiento" --title "Particionamiento de disco" --yesno "¿Desea particionar automáticamente el disco $device?" 7 60; then
        log "INFO" "Particionamiento automático seleccionado"
        
        # Calcular tamaños
        local total_size
        local boot_size=512  # MB
        local swap_size
        local root_size
        
        total_size=$(blockdev --getsize64 "$device" | awk '{print int($1/1024/1024)}')  # En MB
        swap_size=$(free -m | awk '/^Mem:/ {print int($2)}')
        root_size=$((total_size - boot_size - swap_size))
        
        if [[ "$boot_mode" == "UEFI" ]]; then
            log "INFO" "Creando tabla de particiones GPT para UEFI"
            
            # Crear particiones para UEFI
            local commands=(
                "parted -s $device mklabel gpt"
                "parted -s $device mkpart ESP fat32 1MiB ${boot_size}MiB"
                "parted -s $device set 1 esp on"
                "parted -s $device mkpart primary ext4 ${boot_size}MiB $((boot_size + root_size))MiB"
                "parted -s $device mkpart primary linux-swap $((boot_size + root_size))MiB 100%"
            )
        else
            log "INFO" "Creando tabla de particiones MBR para BIOS"
            
            # Crear particiones para BIOS
            local commands=(
                "parted -s $device mklabel msdos"
                "parted -s $device mkpart primary ext4 1MiB $((boot_size + root_size))MiB"
                "parted -s $device set 1 boot on"
                "parted -s $device mkpart primary linux-swap $((boot_size + root_size))MiB 100%"
            )
        fi
        
        for cmd in "${commands[@]}"; do
            if ! execute_with_log $cmd; then
                log "ERROR" "Fallo al ejecutar: $cmd"
                return 1
            fi
        done
    else
        log "INFO" "Particionamiento manual seleccionado"
        
        if ! dialog_wrapper "Advertencia" --title "Advertencia" \
                --yesno "¡ADVERTENCIA!\n\nSe borrarán todos los datos en $device.\n¿Está seguro de continuar?" 10 50; then
            log "INFO" "Usuario canceló el particionamiento"
            return 1
        fi
        
        # Obtener particiones manualmente usando cfdisk
        if ! execute_with_log cfdisk "$device"; then
            log "ERROR" "Fallo al particionar manualmente el disco"
            return 1
        fi
    fi
    
    # Formatear particiones
    if [[ "$boot_mode" == "UEFI" ]]; then
        if ! execute_with_log mkfs.fat -F32 "${device}1"; then
            log "ERROR" "Fallo al formatear partición ESP"
            return 1
        fi
        
        if ! execute_with_log mkfs.ext4 -F "${device}2"; then
            log "ERROR" "Fallo al formatear partición root"
            return 1
        fi
        
        if ! execute_with_log mkswap "${device}3"; then
            log "ERROR" "Fallo al crear swap"
            return 1
        fi
        
        if ! execute_with_log swapon "${device}3"; then
            log "ERROR" "Fallo al activar swap"
            return 1
        fi
    else
        if ! execute_with_log mkfs.ext4 -F "${device}1"; then
            log "ERROR" "Fallo al formatear partición root"
            return 1
        fi
        
        if ! execute_with_log mkswap "${device}2"; then
            log "ERROR" "Fallo al crear swap"
            return 1
        fi
        
        if ! execute_with_log swapon "${device}2"; then
            log "ERROR" "Fallo al activar swap"
            return 1
        fi
    fi
    
    log "INFO" "Particionamiento completado exitosamente"
    return 0
}
# Función para montar particiones  
mount_partitions() {
    log "INFO" "Montando particiones"
    
    if [[ "$boot_mode" == "UEFI" ]]; then
        # Montar partición root
        if ! execute_with_log mount "${selected_partition}2" /mnt; then
            log "ERROR" "Fallo al montar partición root"
            return 1
        fi
        
        # Crear y montar partición ESP
        if ! execute_with_log mkdir -p /mnt/efi; then
            log "ERROR" "Fallo al crear directorio EFI"
            return 1
        fi
        
        if ! execute_with_log mount "${selected_partition}1" /mnt/efi; then
            log "ERROR" "Fallo al montar partición ESP"
            return 1
        fi
    else
        # Montar partición root
        if ! execute_with_log mount "${selected_partition}1" /mnt; then
            log "ERROR" "Fallo al montar partición root"
            return 1
        fi
        
        # Crear y montar partición boot para BIOS
        if ! execute_with_log mkdir -p /mnt/boot; then
            log "ERROR" "Fallo al crear directorio boot"
            return 1
        fi
        
        if ! execute_with_log mount "${selected_partition}1" /mnt/boot; then
            log "ERROR" "Fallo al montar partición boot"
            return 1
        fi
    fi
    
    # Verificar puntos de montaje
    if ! mountpoint -q /mnt; then
        log "ERROR" "La partición root no está montada correctamente"
        return 1
    fi
    
    if [[ "$boot_mode" == "UEFI" ]]; then
        if ! mountpoint -q /mnt/efi; then
            log "ERROR" "La partición ESP no está montada correctamente"
            return 1
        fi
    else
        if ! mountpoint -q /mnt/boot; then
            log "ERROR" "La partición boot no está montada correctamente"
            return 1
        fi
    fi
    
    log "INFO" "Particiones montadas correctamente"
    return 0
}

# Función para instalar sistema base
install_base_system() { log "INFO" "Instalando sistema base"

local base_packages=(
    "base"
    "base-devel" 
    "linux"
    "linux-firmware"
    "networkmanager"
    "vim"
    "nano"
    "grub"
    "efibootmgr"
    "sudo"  
)

if ! execute_with_log pacstrap /mnt "${base_packages[@]}"; then
    log "ERROR" "Fallo al instalar sistema base"
    return 1
fi

log "INFO" "Sistema base instalado correctamente" 
return 0
}
# Función para generar fstab
generate_fstab() { log "INFO" "Generando fstab"

if ! execute_with_log genfstab -U /mnt >> /mnt/etc/fstab; then
    log "ERROR" "Fallo al generar fstab"  
    return 1
fi

log "INFO" "Fstab generado correctamente"
return 0
}
# Función para configurar zona horaria
configure_timezone() { log "INFO" "Configurando zona horaria"

local timezones 
timezones=$(timedatectl list-timezones)

local timezone
timezone=$(dialog_wrapper "Zona horaria" \
    --title "Configuración de zona horaria" \
    --menu "Seleccione su zona horaria:" \
    20 60 10 \
    $(echo "$timezones" | while read -r zone; do echo "$zone" ""; done))

if [[ $? -eq 0 && -n "$timezone" ]]; then
    if ! execute_with_log arch-chroot /mnt ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime; then  
        log "ERROR" "Fallo al configurar zona horaria"
        return 1
    fi
    
    if ! execute_with_log arch-chroot /mnt hwclock --systohc; then
        log "ERROR" "Fallo al sincronizar reloj de hardware"
        return 1
    fi
else
    log "WARN" "No se seleccionó zona horaria" 
    return 1
fi

return 0
}
# Función para configurar idioma
configure_language() { log "INFO" "Configurando idioma del sistema"

if [[ -z "$language" ]]; then
    log "ERROR" "Variable de idioma no definida"
    return 1
fi

echo "$language UTF-8" > /mnt/etc/locale.gen

if ! execute_with_log arch-chroot /mnt locale-gen; then
    log "ERROR" "Fallo al generar locales"  
    return 1
fi

echo "LANG=$language" > /mnt/etc/locale.conf  
log "INFO" "Idioma configurado correctamente"
return 0
}
# Función para configurar hostname
configure_hostname() { log "INFO" "Configurando hostname"

local hostname 
hostname=$(dialog_wrapper "Hostname" \
    --title "Nombre del equipo" \
    --inputbox "Ingrese el nombre para este equipo:" \
    8 40)

if [[ $? -eq 0 && -n "$hostname" ]]; then
    echo "$hostname" > /mnt/etc/hostname
    
    # Configurar hosts
    {
        echo "127.0.0.1 localhost" 
        echo "::1       localhost"
        echo "127.0.1.1 $hostname.localdomain $hostname"
    } >> /mnt/etc/hosts
    
    log "INFO" "Hostname configurado correctamente"  
    return 0
else 
    log "ERROR" "No se proporcionó un hostname válido"
    return 1
fi
}
# Función para instalar y configurar bootloader
install_bootloader() { log "INFO" "Instalando bootloader"

local bootloader_packages=(
    "grub"
    "efibootmgr" 
    "os-prober"
    "ntfs-3g"
)

if ! execute_with_log arch-chroot /mnt pacman -S --noconfirm "${bootloader_packages[@]}"; then
    log "ERROR" "Fallo al instalar paquetes de bootloader"
    return 1 
fi

if ! execute_with_log arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB; then
    log "ERROR" "Fallo al instalar GRUB"
    return 1
fi

# Habilitar detección de otros sistemas operativos
sed -i 's/#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /mnt/etc/default/grub

if ! execute_with_log arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg; then
    log "ERROR" "Fallo al generar configuración de GRUB"
    return 1
fi

log "INFO" "Bootloader instalado correctamente"
return 0
}
# Función para crear usuario
create_user() { log "INFO" "Creando usuario"

local username
username=$(dialog_wrapper "Usuario" \
    --title "Creación de usuario" \
    --inputbox "Ingrese el nombre de usuario:" \
    8 40)

if [[ $? -eq 0 && -n "$username" ]]; then
    if ! execute_with_log arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$username"; then
        log "ERROR" "Fallo al crear usuario"
        return 1
    fi
    
    log "INFO" "Estableciendo contraseña para $username"
    if ! arch-chroot /mnt passwd "$username"; then
        log "ERROR" "Fallo al establecer contraseña"
        return 1
    fi
    
    # Configurar sudo
    echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/wheel
    chmod 440 /mnt/etc/sudoers.d/wheel
    
    log "INFO" "Usuario creado correctamente" 
    return 0
else
    log "ERROR" "No se proporcionó un nombre de usuario válido"
    return 1
fi
}
# Función para instalar entorno de escritorio
install_desktop_environment() { log "INFO" "Instalando entorno de escritorio"

local de
de=$(dialog_wrapper "Entorno de escritorio" \
    --title "Selección de entorno" \
    --menu "Seleccione el entorno de escritorio:" \
    15 60 4 \
    "gnome" "GNOME Desktop" \
    "kde" "KDE Plasma" \
    "xfce" "Xfce Desktop" \
    "none" "Sin entorno gráfico")

case "$de" in
    gnome)
        execute_with_log arch-chroot /mnt pacman -S --noconfirm gnome gnome-extra
        execute_with_log arch-chroot /mnt systemctl enable gdm
        ;;
    kde) 
        execute_with_log arch-chroot /mnt pacman -S --noconfirm plasma plasma-wayland-session kde-applications
        execute_with_log arch-chroot /mnt systemctl enable sddm
        ;;
    xfce)
        execute_with_log arch-chroot /mnt pacman -S --noconfirm xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
        execute_with_log arch-chroot /mnt systemctl enable lightdm
        ;;
    none)
        log "INFO" "No se instalará entorno de escritorio"
        return 0
        ;;
    *)
        log "ERROR" "Opción de entorno de escritorio no válida"
        return 1
        ;;
esac

log "INFO" "Entorno de escritorio instalado correctamente"
return 0
}
# Función de limpieza
cleanup() { log "INFO" "Realizando limpieza"

if mountpoint -q /mnt/boot; then
    execute_with_log umount /mnt/boot
fi

if mountpoint -q /mnt; then
    execute_with_log umount -R /mnt  
fi

execute_with_log swapoff -a

log "INFO" "Limpieza completada"
}

# Función principal
main() { 
   local start_time
   start_time=$(date +%s)
   
   log "INFO" "Iniciando instalación de Arch Linux"
   
   # Verificar root
   if [[ $EUID -ne 0 ]]; then
       log "ERROR" "Este script debe ejecutarse como root"  
       exit 1
   fi
   
   # Mostrar banner y bienvenida
   welcome
   
   # Verificar requisitos  
   check_system_requirements || exit 1
   check_dependencies || exit 1
   
   # Configuración básica
   select_language || exit 1  
   set_keyboard_layout || exit 1
   check_internet_connection || exit 1
   
   # Preparación del disco
   select_installation_partition || exit 1
   partition_disk "$selected_partition" || exit 1
   mount_partitions || exit 1  
   
   # Instalación base
   install_base_system || exit 1
   generate_fstab || exit 1
   
   # Configuración del sistema
   configure_timezone || exit 1
   configure_language || exit 1
   configure_hostname || exit 1
   install_bootloader || exit 1
   create_user || exit 1
   install_desktop_environment || exit 1
   
   # Finalización
   local end_time
   end_time=$(date +%s)
   local duration=$((end_time - start_time))
   
   log "INFO" "Instalación completada en $duration segundos"
   
   dialog_wrapper "Finalizado" \
       --title "Instalación completada" \
       --msgbox "La instalación de Arch Linux se ha completado exitosamente.\n\nTiempo total: $duration segundos\n\nPresione OK para reiniciar." \
       10 60
   
   cleanup
   execute_with_log reboot
}

# Configurar trap para limpieza en caso de error
trap cleanup EXIT

# Iniciar instalación
main "$@"

