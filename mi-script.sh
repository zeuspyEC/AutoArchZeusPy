#!/usr/bin/env bash

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

# Inicializar archivos de log con encoding UTF-8
: | iconv -f UTF-8 -t UTF-8 > "$LOG_FILE"
: | iconv -f UTF-8 -t UTF-8 > "$ERROR_LOG"
: | iconv -f UTF-8 -t UTF-8 > "$DEBUG_LOG"

# Función de logging mejorada con validación de caracteres
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local line_number="${BASH_LINENO[0]}"
    local function_name="${FUNCNAME[1]:-main}"
    
    # Sanitizar mensaje para evitar caracteres problemáticos
    message=$(echo "$message" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null || echo "$message")
    
    # Formato de log consistente
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
            {
                echo -e "${RED}$log_message${NC}"
                echo "=== Sistema Info ==="
                echo "Kernel: $(uname -a)"
                echo "Memoria: $(free -h)"
                echo "Disco: $(df -h)"
                echo "Procesos: $(ps aux)"
                echo "Variables: $(env)"
                echo "==================="
            } | tee -a "$ERROR_LOG"
            ;;
    esac
}

# Función para verificar dependencias con nombres corregidos
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
            echo -e "${YELLOW}Advertencia: Fallo al instalar algunas dependencias. ¿Desea continuar de todos modos? (s/n)${NC}"
            read -r choice
            case "$choice" in
                s|S)
                    log "INFO" "El usuario decidió continuar a pesar de las dependencias faltantes"
                    ;;
                *)
                    log "ERROR" "El usuario decidió cancelar la instalación"
                    echo -e "${RED}Instalación cancelada por el usuario.${NC}"
                    return 1
                    ;;
            esac
        fi
    fi
    
    return 0
}

# Función mejorada para ejecutar comandos
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
# Función para verificar requisitos del sistema con mejor manejo de errores
check_system_requirements() {
    log "INFO" "Verificando requisitos del sistema"
    
    # Verificar espacio en disco mínimo (20GB en bytes)
    local min_space=$((20 * 1024 * 1024 * 1024))
    local available_space
    available_space=$(df -B1 --output=avail / | tail -n1)
    
    if [[ "$available_space" -lt "$min_space" ]]; then
        log "ERROR" "Espacio insuficiente: $(numfmt --to=iec-i --suffix=B "$available_space") < 20GB"
        echo -e "${RED}Error: Se requieren al menos 20GB de espacio libre.${NC}"
        return 1
    fi
    
    # Verificar memoria
    local min_ram=1024  # 1GB en MB
    local total_ram
    total_ram=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    
    if [[ "$total_ram" -lt "$min_ram" ]]; then
        log "ERROR" "Memoria RAM insuficiente: $total_ram MB < $min_ram MB"
        echo -e "${RED}Error: Se requiere al menos 1GB de RAM.${NC}"
        return 1
    fi
    
    # Verificar arquitectura
    local arch
    arch=$(uname -m)
    
    if [[ "$arch" != "x86_64" ]]; then
        log "ERROR" "Arquitectura no soportada: $arch"
        echo -e "${RED}Error: Solo se soporta arquitectura x86_64.${NC}"
        return 1
    fi
    
    # Verificar modo de arranque
    if [[ -d "/sys/firmware/efi/efivars" ]]; then
        log "INFO" "Sistema en modo UEFI"
        boot_mode="UEFI"
    else
        log "INFO" "Sistema en modo BIOS"
        boot_mode="BIOS"
    fi
    
    # Verificar conexión a Internet
    if ! ping -c 1 -W 5 archlinux.org &>/dev/null; then
        log "ERROR" "No hay conexión a Internet"
        echo -e "${RED}Error: Se requiere conexión a Internet.${NC}"
        return 1
    }
    
    log "INFO" "Requisitos del sistema verificados correctamente"
    return 0
}

# Función mejorada para verificar conexión a Internet
check_internet_connection() {
    log "INFO" "Verificando conexión a Internet"
    
    local mirrors=("archlinux.org" "google.com" "cloudflare.com")
    local max_attempts=3
    local success=false
    
    for mirror in "${mirrors[@]}"; do
        for ((attempt=1; attempt<=max_attempts; attempt++)); do
            log "DEBUG" "Intentando conectar a $mirror (intento $attempt/$max_attempts)"
            
            if ping -c 1 -W 5 "$mirror" &>/dev/null; then
                log "INFO" "Conexión exitosa a $mirror"
                success=true
                break 2
            fi
            
            log "WARN" "Fallo al conectar con $mirror"
            sleep 2
        done
    done
    
    if ! $success; then
        log "ERROR" "No se pudo establecer conexión a Internet"
        echo -e "${RED}Error: Verifique su conexión a Internet.${NC}"
        return 1
    fi
    
    return 0
}

# Función mejorada para seleccionar idioma
select_language() {
    log "INFO" "Seleccionando idioma"
    
    local languages=(
        "es_ES.UTF-8" "Español (España)"
        "en_US.UTF-8" "English (US)"
        "fr_FR.UTF-8" "Français"
        "de_DE.UTF-8" "Deutsch"
        "it_IT.UTF-8" "Italiano"
        "pt_BR.UTF-8" "Português (Brasil)"
    )
    
    while true; do
        echo -e "${BLUE}Seleccione el idioma para la instalación:${NC}"
        for ((i=0; i<${#languages[@]}; i+=2)); do
            echo "$((i/2+1)). ${languages[i+1]}"
        done
        
        read -r choice
        
        if [[ $choice =~ ^[0-9]+$ && $choice -ge 1 && $choice -le $((${#languages[@]}/2)) ]]; then
            language="${languages[((choice-1)*2)]}"
            log "INFO" "Idioma seleccionado: $language"
            return 0
        else
            log "WARN" "Selección de idioma inválida: $choice"
            echo -e "${YELLOW}Por favor, seleccione un número válido.${NC}"
        fi
    done
}

# Función mejorada para configurar el teclado
set_keyboard_layout() {
    log "INFO" "Configurando disposición del teclado"
    
    local layouts=(
        "es" "Español"
        "us" "English (US)"
        "fr" "Français"
        "de" "Deutsch"
        "it" "Italiano"
        "pt" "Português"
    )
    
    while true; do
        echo -e "${BLUE}Seleccione la disposición del teclado:${NC}"
        for ((i=0; i<${#layouts[@]}; i+=2)); do
            echo "$((i/2+1)). ${layouts[i+1]}"
        done
        
        read -r choice
        
        if [[ $choice =~ ^[0-9]+$ && $choice -ge 1 && $choice -le $((${#layouts[@]}/2)) ]]; then
            keyboard_layout="${layouts[((choice-1)*2)]}"
            if execute_with_log loadkeys "$keyboard_layout"; then
                log "INFO" "Disposición del teclado configurada: $keyboard_layout"
                return 0
            else
                log "ERROR" "Fallo al configurar el teclado: $keyboard_layout"
                echo -e "${RED}Error al configurar el teclado. Intente nuevamente.${NC}"
            fi
        else
            log "WARN" "Selección de teclado inválida: $choice"
            echo -e "${YELLOW}Por favor, seleccione un número válido.${NC}"
        fi
    done
}

# Función mejorada para seleccionar partición
select_installation_partition() {
    log "INFO" "Seleccionando partición de instalación"
    
    local partitions
    if ! partitions=$(lsblk -pln -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E "disk|part"); then
        log "ERROR" "No se pudieron obtener las particiones"
        return 1
    fi
    
    echo -e "${BLUE}Dispositivos disponibles:${NC}"
    echo "$partitions" | nl -w2 -s'. '
    
    while true; do
        echo -e "${BLUE}Seleccione el número del dispositivo para la instalación:${NC}"
        read -r choice
        
        if [[ $choice =~ ^[0-9]+$ ]]; then
            selected_partition=$(echo "$partitions" | sed -n "${choice}p" | awk '{print $1}')
            if [[ -n "$selected_partition" ]]; then
                # Verificar si el dispositivo está montado
                if mountpoint -q "$selected_partition"; then
                    log "WARN" "El dispositivo $selected_partition está montado"
                    echo -e "${YELLOW}¿Desea desmontarlo? (s/n)${NC}"
                    read -r unmount_choice
                    if [[ "$unmount_choice" =~ ^[Ss]$ ]]; then
                        if ! execute_with_log umount "$selected_partition"; then
                            log "ERROR" "No se pudo desmontar $selected_partition"
                            return 1
                        fi
                    else
                        continue
                    fi
                fi
                
                log "INFO" "Partición seleccionada: $selected_partition"
                return 0
            fi
        fi
        
        log "WARN" "Selección inválida: $choice"
        echo -e "${YELLOW}Por favor, seleccione un número válido.${NC}"
    done
}

# Función mejorada para particionar el disco
partition_disk() {
    local device="$1"
    log "INFO" "Iniciando particionamiento de disco: $device"
    
    # Verificar que el dispositivo existe
    if [[ ! -b "$device" ]]; then
        log "ERROR" "Dispositivo no encontrado: $device"
        return 1
    }
    
    # Backup de tabla de particiones
    local backup_file="/tmp/partition_backup_$(date +%Y%m%d_%H%M%S)"
    if ! execute_with_log sfdisk -d "$device" > "$backup_file"; then
        log "WARN" "No se pudo crear backup de la tabla de particiones"
    else
        log "INFO" "Backup de tabla de particiones creado: $backup_file"
    fi
    
    echo -e "${YELLOW}¡ADVERTENCIA! Se borrarán todos los datos en $device${NC}"
    echo -e "${BLUE}Seleccione el esquema de particionamiento:${NC}"
    echo "1. Automático (Recomendado)"
    echo "2. Manual (Avanzado)"
    
    read -r choice
    
    case "$choice" in
        1)
            log "INFO" "Particionamiento automático seleccionado"
            
            # Calcular tamaños
            local total_size
            local efi_size=512  # MB
            local swap_size
            local root_size
            
            total_size=$(blockdev --getsize64 "$device" | awk '{print int($1/1024/1024)}')  # MB
            swap_size=$(free -m | awk '/^Mem:/ {print int($2)}')
            root_size=$((total_size - efi_size - swap_size))
            
            if [[ "$boot_mode" == "UEFI" ]]; then
                log "INFO" "Creando esquema GPT para UEFI"
                
                # Crear particiones
                if ! execute_with_log parted -s "$device" \
                    mklabel gpt \
                    mkpart ESP fat32 1MiB "${efi_size}MiB" \
                    set 1 esp on \
                    mkpart primary ext4 "${efi_size}MiB" "$((efi_size + root_size))MiB" \
                    mkpart primary linux-swap "$((efi_size + root_size))MiB" 100%; then
                    log "ERROR" "Fallo en particionamiento automático UEFI"
                    return 1
                fi
                
                # Formatear particiones
                log "INFO" "Formateando particiones UEFI"
                if ! execute_with_log mkfs.fat -F32 "${device}1" && \
                   ! execute_with_log mkfs.ext4 -F "${device}2" && \
                   ! execute_with_log mkswap "${device}3" && \
                   ! execute_with_log swapon "${device}3"; then
                    log "ERROR" "Fallo al formatear particiones UEFI"
                    return 1
                fi
            else
                log "INFO" "Creando esquema MBR para BIOS"
                
                # Crear particiones
                if ! execute_with_log parted -s "$device" \
                    mklabel msdos \
                    mkpart primary ext4 1MiB "$((root_size))MiB" \
                    set 1 boot on \
                    mkpart primary linux-swap "$((root_size))MiB" 100%; then
                    log "ERROR" "Fallo en particionamiento automático BIOS"
                    return 1
                fi
                
                # Formatear particiones
                log "INFO" "Formateando particiones BIOS"
                if ! execute_with_log mkfs.ext4 -F "${device}1" && \
                   ! execute_with_log mkswap "${device}2" && \
                   ! execute_with_log swapon "${device}2"; then
                    log "ERROR" "Fallo al formatear particiones BIOS"
                    return 1
                fi
            fi
            ;;
            
        2)
            log "INFO" "Particionamiento manual seleccionado"
            if ! execute_with_log cfdisk "$device"; then
                log "ERROR" "Fallo en particionamiento manual"
                return 1
            fi
            ;;
            
        *)
            log "ERROR" "Opción inválida: $choice"
            return 1
            ;;
    esac
    
    log "INFO" "Particionamiento completado exitosamente"
    return 0
}

# Función para generar fstab
generate_fstab() {
    log "INFO" "Generando fstab"
    
    # Crear backup del fstab existente si existe
    if [[ -f /mnt/etc/fstab ]]; then
        cp /mnt/etc/fstab "/mnt/etc/fstab.backup-$(date +%Y%m%d)"
    fi
    
    if ! execute_with_log genfstab -U /mnt > /mnt/etc/fstab; then
        log "ERROR" "Fallo al generar fstab"
        return 1
    fi
    
    # Verificar el contenido del fstab
    if ! grep -q "/mnt" /mnt/etc/fstab; then
        log "ERROR" "fstab generado no contiene punto de montaje root"
        return 1
    fi
    
    log "INFO" "fstab generado correctamente"
    return 0
}

# Función mejorada para instalar el sistema base
install_base_system() {
    log "INFO" "Instalando sistema base"
    
    local base_packages=(
        base
        base-devel
        linux
        linux-firmware
        networkmanager
        vim
        nano
        sudo
        grub
        efibootmgr
        dosfstools
        os-prober
        mtools
        intel-ucode
        amd-ucode
    )
    
    # Verificar espacio disponible
    local required_space=$((5 * 1024 * 1024))  # 5GB en KB
    local available_space
    available_space=$(df -k /mnt | awk 'NR==2 {print $4}')
    
    if [[ "$available_space" -lt "$required_space" ]]; then
        log "ERROR" "Espacio insuficiente para la instalación base"
        return 1
    fi
    
    # Actualizar lista de mirrors
    if ! execute_with_log reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist; then
        log "WARN" "Fallo al actualizar mirrors, continuando con los predeterminados"
    fi
    
    # Instalar paquetes base
    if ! execute_with_log pacstrap /mnt "${base_packages[@]}"; then
        log "ERROR" "Fallo al instalar sistema base"
        return 1
    fi
    
    log "INFO" "Instalación de base correctamente"
    return 0
}

# Verificar instalación de paquetes críticos
    for pkg in base linux; do
        if ! arch-chroot /mnt pacman -Qi "$pkg" &>/dev/null; then
            log "ERROR" "Paquete crítico no instalado: $pkg"
            return 1
        fi
    done
    
    log "INFO" "Sistema base instalado correctamente"
    return 0
}

# Función mejorada para configurar zona horaria
configure_timezone() {
    log "INFO" "Configurando zona horaria"
    
    # Mostrar regiones disponibles
    local regions
    regions=$(find /usr/share/zoneinfo -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort)
    
    echo -e "${BLUE}Seleccione la región:${NC}"
    echo "$regions" | nl -w2 -s'. '
    
    read -r region_choice
    
    local selected_region
    selected_region=$(echo "$regions" | sed -n "${region_choice}p")
    
    if [[ -z "$selected_region" ]]; then
        log "ERROR" "Región inválida seleccionada"
        return 1
    fi
    
    # Mostrar ciudades de la región seleccionada
    local cities
    cities=$(find "/usr/share/zoneinfo/$selected_region" -type f -printf "%f\n" | sort)
    
    echo -e "${BLUE}Seleccione la ciudad:${NC}"
    echo "$cities" | nl -w2 -s'. '
    
    read -r city_choice
    
    local selected_city
    selected_city=$(echo "$cities" | sed -n "${city_choice}p")
    
    if [[ -z "$selected_city" ]]; then
        log "ERROR" "Ciudad inválida seleccionada"
        return 1
    fi
    
    local timezone="$selected_region/$selected_city"
    
    # Configurar zona horaria
    if ! execute_with_log arch-chroot /mnt ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime; then
        log "ERROR" "Fallo al establecer zona horaria"
        return 1
    fi
    
    # Sincronizar reloj hardware
    if ! execute_with_log arch-chroot /mnt hwclock --systohc; then
        log "ERROR" "Fallo al sincronizar reloj hardware"
        return 1
    fi
    
    log "INFO" "Zona horaria configurada: $timezone"
    return 0
}

# Función mejorada para configurar idioma
configure_language() {
    log "INFO" "Configurando idioma del sistema"
    
    if [[ -z "$language" ]]; then
        log "ERROR" "Variable de idioma no definida"
        return 1
    fi
    
    # Hacer backup del locale.gen
    if [[ -f /mnt/etc/locale.gen ]]; then
        cp /mnt/etc/locale.gen "/mnt/etc/locale.gen.backup-$(date +%Y%m%d)"
    fi
    
    # Configurar locale.gen
    echo "$language UTF-8" > /mnt/etc/locale.gen
    
    # Generar locales
    if ! execute_with_log arch-chroot /mnt locale-gen; then
        log "ERROR" "Fallo al generar locales"
        return 1
    fi
    
    # Configurar idioma predeterminado
    echo "LANG=$language" > /mnt/etc/locale.conf
    
    # Configurar disposición del teclado para consola
    if [[ -n "$keyboard_layout" ]]; then
        echo "KEYMAP=$keyboard_layout" > /mnt/etc/vconsole.conf
    fi
    
    log "INFO" "Idioma configurado correctamente"
    return 0
}

# Función mejorada para configurar hostname
configure_hostname() {
    log "INFO" "Configurando hostname"
    
    while true; do
        echo -e "${BLUE}Ingrese el nombre para este equipo (solo letras, números y guiones):${NC}"
        read -r hostname
        
        # Validar hostname
        if [[ "$hostname" =~ ^[a-zA-Z0-9-]+$ ]]; then
            break
        else
            log "WARN" "Hostname inválido: $hostname"
            echo -e "${YELLOW}El hostname solo puede contener letras, números y guiones.${NC}"
        fi
    done
    
    # Configurar hostname
    echo "$hostname" > /mnt/etc/hostname
    
    # Configurar hosts
    cat > /mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain $hostname
EOF
    
    log "INFO" "Hostname configurado: $hostname"
    return 0
}

# Función mejorada para instalar y configurar bootloader
install_bootloader() {
    log "INFO" "Instalando bootloader"
    
    local bootloader_packages=(
        grub
        efibootmgr
        os-prober
        dosfstools
    )
    
    # Instalar paquetes del bootloader
    if ! execute_with_log arch-chroot /mnt pacman -S --noconfirm "${bootloader_packages[@]}"; then
        log "ERROR" "Fallo al instalar paquetes del bootloader"
        return 1
    fi
    
    # Configurar GRUB según el modo de arranque
    if [[ "$boot_mode" == "UEFI" ]]; then
        # Crear directorio EFI si no existe
        if ! execute_with_log arch-chroot /mnt mkdir -p /boot/efi; then
            log "ERROR" "Fallo al crear directorio EFI"
            return 1
        fi
        
        # Instalar GRUB para UEFI
        if ! execute_with_log arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB; then
            log "ERROR" "Fallo al instalar GRUB para UEFI"
            return 1
        fi
    else
        # Instalar GRUB para BIOS
        if ! execute_with_log arch-chroot /mnt grub-install --target=i386-pc "$selected_partition"; then
            log "ERROR" "Fallo al instalar GRUB para BIOS"
            return 1
        fi
    fi
    
    # Configurar GRUB para detectar otros sistemas operativos
    sed -i 's/#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /mnt/etc/default/grub
    
    # Generar configuración de GRUB
    if ! execute_with_log arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg; then
        log "ERROR" "Fallo al generar configuración de GRUB"
        return 1
    fi
    
    log "INFO" "Bootloader instalado correctamente"
    return 0
}

# Función mejorada para crear usuario
create_user() {
    log "INFO" "Creando usuario"
    
    while true; do
        echo -e "${BLUE}Ingrese el nombre de usuario (solo minúsculas, sin espacios):${NC}"
        read -r username
        
        if [[ "$username" =~ ^[a-z][a-z0-9-]*$ ]]; then
            break
        else
            log "WARN" "Nombre de usuario inválido: $username"
            echo -e "${YELLOW}El nombre de usuario debe comenzar con una letra minúscula y solo puede contener letras minúsculas, números y guiones.${NC}"
        fi
    done
    
    # Crear usuario
    if ! execute_with_log arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$username"; then
        log "ERROR" "Fallo al crear usuario"
        return 1
    fi
    
    # Configurar contraseña del usuario
    echo -e "${BLUE}Establezca la contraseña para $username:${NC}"
    if ! arch-chroot /mnt passwd "$username"; then
        log "ERROR" "Fallo al establecer contraseña de usuario"
        return 1
    fi
    
    # Configurar sudo
    if ! echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/wheel; then
        log "ERROR" "Fallo al configurar sudo"
        return 1
    fi
    chmod 440 /mnt/etc/sudoers.d/wheel
    
    log "INFO" "Usuario creado correctamente: $username"
    return 0
}

# Función mejorada para instalar entorno de escritorio
install_desktop_environment() {
    log "INFO" "Instalando entorno de escritorio"
    
    local de_options=(
        "GNOME" "gnome gnome-extra gdm"
        "KDE Plasma" "plasma plasma-wayland-session kde-applications sddm"
        "Xfce" "xfce4 xfce4-goodies lightdm lightdm-gtk-greeter"
        "Ninguno" ""
    )
    
    echo -e "${BLUE}Seleccione el entorno de escritorio:${NC}"
    for ((i=0; i<${#de_options[@]}; i+=2)); do
        echo "$((i/2+1)). ${de_options[i]}"
    done
    
    read -r choice
    
    if [[ $choice =~ ^[0-9]+$ && $choice -ge 1 && $choice -le $((${#de_options[@]}/2)) ]]; then
        local packages="${de_options[((choice-1)*2+1)]}"
        
        if [[ -n "$packages" ]]; then
            log "INFO" "Instalando ${de_options[((choice-1)*2)]}"
            
            # Instalar paquetes del entorno de escritorio
            if ! execute_with_log arch-chroot /mnt pacman -S --noconfirm $packages; then
                log "ERROR" "Fallo al instalar entorno de escritorio"
                return 1
            fi
            
            # Habilitar gestor de inicio de sesión
            case "$choice" in
                1) service="gdm" ;;
                2) service="sddm" ;;
                3) service="lightdm" ;;
            esac
            
            if [[ -n "$service" ]]; then
                if ! execute_with_log arch-chroot /mnt systemctl enable "$service"; then
                    log "ERROR" "Fallo al habilitar servicio $service"
                    return 1
                fi
            fi
        else
            log "INFO" "No se instalará entorno de escritorio"
        fi
        
        return 0
    else
        log "ERROR" "Opción inválida: $choice"
        return 1
    fi
}

# Función mejorada de limpieza
cleanup() {
    log "INFO" "Realizando limpieza final"
    
    # Desmontar sistemas de archivo en orden inverso
    local mount_points
    mount_points=$(mount | grep /mnt | awk '{print $3}' | sort -r)
    
    for point in $mount_points; do
        if ! execute_with_log umount "$point"; then
            log "WARN" "Fallo al desmontar $point"
        fi
    done
    
    # Desactivar swap
    if ! execute_with_log swapoff -a; then
        log "WARN" "Fallo al desactivar swap"
    fi
    
    # Eliminar archivos temporales
    rm -f /tmp/arch_installer_*
    
    log "INFO" "Limpieza completada"
}

# Función principal mejorada
main() {
    local start_time
    start_time=$(date +%s)
    
    log "INFO" "Iniciando instalación de Arch Linux"
    
    # Verificar permisos de root
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "Este script debe ejecutarse como root"
        echo -e "${RED}Error: Este script debe ejecutarse como root.${NC}"
        exit 1
    fi
    
    # Ejecutar pasos de instalación
    local steps=(
        "check_system_requirements"
        "check_dependencies"
        "select_language"
        "set_keyboard_layout"
        "check_internet_connection"
        "select_installation_partition"
        "partition_disk"
        "mount_partitions"
        "install_base_system"
        "generate_fstab"
        "configure_timezone"
        "configure_language"
        "configure_hostname"
        "install_bootloader"
        "create_user"
        "install_desktop_environment"
    )
    
    for step in "${steps[@]}"; do
        echo -e "${BLUE}Ejecutando: ${step//_/ }${NC}"
        if ! "$step" "$selected_partition"; then
            log "ERROR" "Fallo en paso: $step"
            cleanup
            exit 1
        fi
    done
    
    # Calcular tiempo total
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "INFO" "Instalación completada en $duration segundos"
    
    # Preguntar por reinicio
    echo -e "${GREEN}¡Instalación completada exitosamente!${NC}"
    echo -e "${BLUE}¿Desea reiniciar el sistema ahora? (s/n)${NC}"
    read -r reboot_choice
    
    cleanup
    
    if [[ "$reboot_choice" =~ ^[Ss]$ ]]; then
        log "INFO" "Reiniciando sistema"
        execute_with_log reboot
    else
        log "INFO" "Reinicio pospuesto"
        echo -e "${YELLOW}Recuerde reiniciar el sistema cuando esté listo.${NC}"
    fi
}

# Configurar trap para limpieza
trap cleanup EXIT INT TERM

# Iniciar instalación
main "$@"
