#!/usr/bin/env bash

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

# Inicializar archivos de log
: > "$LOG_FILE"
: > "$ERROR_LOG"
: > "$DEBUG_LOG"

# Función de logging mejorada
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local line_number="${BASH_LINENO[0]}"
    local function_name="${FUNCNAME[1]}"
    
    # Formato de log: [TIMESTAMP] [LEVEL] [FUNCTION:LINE] Message
    local log_message="[$timestamp] [$level] [$function_name:$line_number] $message"
    
    # Logging según nivel
    case "$level" in
        "DEBUG")
            echo "$log_message" >> "$DEBUG_LOG"
            ;;
        "ERROR")
            echo "$log_message" >> "$ERROR_LOG"
            echo "$log_message" >> "$LOG_FILE"
            # Capturar información del sistema en caso de error
            {
                echo "=== Sistema Info ==="
                echo "Kernel: $(uname -a)"
                echo "Memoria: $(free -h)"
                echo "Disco: $(df -h)"
                echo "Procesos: $(ps aux | grep -i dialog)"
                echo "Variables: $(env)"
                echo "==================="
            } >> "$ERROR_LOG"
            ;;
        *)
            echo "$log_message" >> "$LOG_FILE"
            ;;
    esac
}

# Función para manejar errores
handle_error() {
    local line_number=$1
    local error_message=$2
    local exit_code=$3
    local function_name="${FUNCNAME[1]}"
    
    log "ERROR" "Error en $function_name (línea $line_number): $error_message (Código: $exit_code)"
    
    # Capturar stack trace
    local frame=0
    echo "=== Stack Trace ===" >> "$ERROR_LOG"
    while caller $frame; do
        ((frame++))
    done >> "$ERROR_LOG"
    echo "=================" >> "$ERROR_LOG"
    
    # Mostrar error al usuario
    if command -v dialog &> /dev/null; then
        dialog --clear \
               --backtitle "Instalador de Arch Linux" \
               --title "Error" \
               --msgbox "Ocurrió un error inesperado.\nPor favor, revise el log en: $ERROR_LOG\nFunción: $function_name\nLínea: $line_number\nError: $error_message" \
               12 60 2>> "$ERROR_LOG"
    else
        echo -e "${RED}Error en $function_name (línea $line_number): $error_message${NC}"
    fi
}

# Configurar trap para capturar errores
set -E
trap 'handle_error ${LINENO} "$BASH_COMMAND" $?' ERR

# Función para envolver comandos con logging
execute_with_log() {
    local command="$*"
    local function_name="${FUNCNAME[1]}"
    
    log "DEBUG" "Ejecutando comando: $command"
    
    if output=$("$@" 2>&1); then
        log "INFO" "Comando exitoso: $command"
        log "DEBUG" "Salida: $output"
        return 0
    else
        local exit_code=$?
        log "ERROR" "Comando falló ($exit_code): $command"
        log "ERROR" "Salida: $output"
        return $exit_code
    fi
}

# Función para envolver comandos de dialog con logging
dialog_wrapper() {
    log "DEBUG" "Iniciando dialog con argumentos: $*"
    
    local output
    if output=$(dialog "$@" 2>&1); then
        log "INFO" "Dialog exitoso: $*"
        log "DEBUG" "Salida: $output"
        echo "$output"
        return 0
    else
        local exit_code=$?
        log "WARN" "Dialog cancelado o error ($exit_code)"
        log "DEBUG" "Salida: $output"
        return $exit_code
    fi
}

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
  local banner_text="${BLUE}}███████╗███████╗╚██████╔╝███████║██║        ██║   ███████╗╚██████╗${NC}"
  format_center "$banner_text"
  local banner_text="${BLUE}╚══════╝╚══════╝ ╚═════╝ ╚══════╝╚═╝        ╚═╝   ╚══════╝ ╚═════╝${NC}"
  format_center "$banner_text"
  echo
}

# Función de bienvenida
welcome() {
  dialog --backtitle "Instalador de Arch Linux" \
         --title "Bienvenido" \
         --msgbox "Bienvenido al instalador de Arch Linux. Este script te guiará a través del proceso de instalación." \
         10 60
}

# Función para seleccionar el idioma
select_language() {
  language_options=("es_ES.UTF-8" "Español"
                    "en_US.UTF-8" "Inglés"
                    "fr_FR.UTF-8" "Francés"
                    "ru_RU.UTF-8" "Ruso")

  language=$(dialog --clear --stdout --backtitle "Instalador de Arch Linux" \
                    --title "Selección de idioma" \
                    --menu "Selecciona el idioma de instalación:" \
                    10 40 4 \
                    "${language_options[@]}")

  case $? in
    0)
      echo "$language UTF-8" > /etc/locale.gen
      locale-gen &> /dev/null
      echo "LANG=$language" > /etc/locale.conf
      export LANG=$language
      ;;
    1)
      echo "Cancelado."
      exit 0
      ;;
    255)
      echo "Ocurrió un error inesperado."
      exit 1
      ;;
  esac
}

# Función para configurar el teclado
set_keyboard_layout() {
  keyboard_options=("es" "Español"
                    "us" "Inglés (EE. UU.)"
                    "fr" "Francés"
                    "ru" "Ruso")

  keyboard_layout=$(dialog --clear --stdout --backtitle "Instalador de Arch Linux" \
                           --title "Configuración de teclado" \
                           --menu "Selecciona la distribución de teclado:" \
                           10 40 4 \
                           "${keyboard_options[@]}")

  case $? in
    0)
      loadkeys $keyboard_layout
      ;;
    1)
      echo "Cancelado."
      ;;
    255)
      echo "Ocurrió un error inesperado."
      ;;
  esac
}

# Función para verificar la conexión a Internet
check_internet_connection() {
    log "INFO" "Iniciando verificación de conexión a internet"
    
    # Verificar si ya hay conexión
    if ping -c1 8.8.8.8 >/dev/null 2>&1; then
        log "INFO" "Conexión a internet detectada"
        dialog --clear \
               --backtitle "Instalador de Arch Linux" \
               --title "Conexión a Internet" \
               --msgbox "La conexión a Internet está activa." \
               6 50 2>> "$ERROR_LOG"
        return 0
    fi
    
    log "WARN" "No hay conexión a internet. Verificando interfaces de red..."
    
    # Verificar interfaces de red
    local wireless_interface=$(ip link | grep -E '^[0-9]+: w' | cut -d: -f2 | awk '{print $1}' | head -n1)
    log "INFO" "Interfaz wireless detectada: $wireless_interface"
    
    if [ -z "$wireless_interface" ]; then
        log "ERROR" "No se detectó ninguna interfaz wireless"
        dialog --clear \
               --backtitle "Instalador de Arch Linux" \
               --title "Error" \
               --msgbox "No se detectó ninguna interfaz de red wireless." \
               6 50 2>> "$ERROR_LOG"
        return 1
    fi
    
    # Configurar red wireless
    local configure_wifi
    configure_wifi=$(dialog --clear \
                           --stdout \
                           --backtitle "Instalador de Arch Linux" \
                           --title "Configuración de red" \
                           --yesno "¿Desea configurar la red WiFi?" \
                           6 50 2>> "$ERROR_LOG")
    
    if [ $? -eq 0 ]; then
        log "INFO" "Usuario eligió configurar WiFi"
        
        # Activar interfaz
        log "INFO" "Activando interfaz $wireless_interface"
        ip link set "$wireless_interface" up
        sleep 2
        
        # Escanear redes
        log "INFO" "Escaneando redes disponibles"
        iwctl station "$wireless_interface" scan
        sleep 2
        
        # Obtener SSID
        local ssid
        ssid=$(dialog --clear \
                     --stdout \
                     --backtitle "Instalador de Arch Linux" \
                     --title "Configuración WiFi" \
                     --inputbox "Ingrese el nombre de la red (SSID):" \
                     8 50 2>> "$ERROR_LOG")
        
        if [ $? -eq 0 ] && [ -n "$ssid" ]; then
            log "INFO" "SSID ingresado: $ssid"
            
            # Obtener contraseña
            local password
            password=$(dialog --clear \
                            --stdout \
                            --backtitle "Instalador de Arch Linux" \
                            --title "Configuración WiFi" \
                            --passwordbox "Ingrese la contraseña de la red:" \
                            8 50 2>> "$ERROR_LOG")
            
            if [ $? -eq 0 ]; then
                log "INFO" "Intentando conexión a $ssid"
                
                # Intentar conexión
                iwctl --passphrase "$password" station "$wireless_interface" connect "$ssid" 2>> "$ERROR_LOG"
                sleep 5
                
                if ping -c1 8.8.8.8 >/dev/null 2>&1; then
                    log "INFO" "Conexión exitosa a $ssid"
                    dialog --clear \
                           --backtitle "Instalador de Arch Linux" \
                           --title "Conexión exitosa" \
                           --msgbox "Conexión a Internet establecida correctamente." \
                           6 50 2>> "$ERROR_LOG"
                    return 0
                else
                    log "ERROR" "No se pudo establecer conexión después de conectar a $ssid"
                fi
            else
                log "WARN" "Usuario canceló la entrada de contraseña"
            fi
        else
            log "WARN" "Usuario canceló la entrada de SSID"
        fi
    else
        log "WARN" "Usuario eligió no configurar WiFi"
    fi
    
    log "ERROR" "No se pudo establecer conexión a internet"
    dialog --clear \
           --backtitle "Instalador de Arch Linux" \
           --title "Error" \
           --msgbox "No se pudo establecer una conexión a Internet. La instalación no puede continuar." \
           7 60 2>> "$ERROR_LOG"
    return 1
}

# Función mejorada para verificar dependencias
check_dependencies() {
    log "INFO" "Verificando dependencias..."
    local deps=("dialog" "iwd" "ip" "arch-install-scripts" "parted")
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
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log "INFO" "Instalando dependencias faltantes: ${missing_deps[*]}"
        if ! pacman -Sy --noconfirm "${missing_deps[@]}" 2>>$ERROR_LOG; then
            log "ERROR" "Fallo al instalar dependencias"
            dialog --clear \
                   --backtitle "Instalador de Arch Linux" \
                   --title "Error" \
                   --msgbox "No se pudieron instalar las dependencias necesarias. Verifica tu conexión a Internet y vuelve a intentarlo." \
                   8 60
            return 1
        fi
    fi
    
    log "INFO" "Todas las dependencias están instaladas"
    return 0
}

# Función para detectar si existe una instalación de Windows
detect_windows_installation() {
  if [ -d "/sys/firmware/efi/efivars" ]; then
    windows_installed=$(fdisk -l | grep -i microsoft | wc -l)
    if [ $windows_installed -gt 0 ]; then
      dialog --backtitle "Instalador de Arch Linux" \
             --title "Instalación de Windows detectada" \
             --msgbox "Se ha detectado una instalación de Windows en tu sistema. El instalador realizará una configuración de dual boot." \
             8 60
      return 0
    fi
  fi
  return 1
}

# Función para obtener la lista de particiones
get_partitions() {
    log "DEBUG" "Obteniendo lista de particiones"
    local partitions=""
    local count=0
    
    while IFS= read -r line; do
        if [[ $line =~ /dev/ ]] && [[ $line =~ part|lvm ]]; then
            local device=$(echo "$line" | awk '{print $1}')
            local size=$(echo "$line" | awk '{print $2}')
            local type=$(echo "$line" | awk '{print $3}')
            partitions="$partitions $device \"$size - $type\" "
            ((count++))
        fi
    done < <(lsblk -pn -o NAME,SIZE,TYPE)
    
    if [ $count -eq 0 ]; then
        log "ERROR" "No se encontraron particiones disponibles"
        return 1
    }
    
    echo "$partitions"
    log "DEBUG" "Particiones encontradas: $partitions"
    return 0
}

# Función para seleccionar la partición de instalación
# Función mejorada para seleccionar la partición
select_installation_partition() {
    log "INFO" "Iniciando selección de partición"
    
    local partition_list=$(get_partitions)
    if [ $? -ne 0 ]; then
        log "ERROR" "No hay particiones disponibles para la instalación"
        dialog --clear \
               --backtitle "Instalador de Arch Linux" \
               --title "Error" \
               --msgbox "No se encontraron particiones disponibles para la instalación." \
               7 60
        return 1
    }
    
    log "DEBUG" "Lista de particiones: $partition_list"
    
    selected_partition=$(dialog --clear \
                               --stdout \
                               --backtitle "Instalador de Arch Linux" \
                               --title "Selección de partición" \
                               --menu "Selecciona la partición donde deseas instalar Arch Linux:" \
                               20 60 10 \
                               $partition_list 2>>$ERROR_LOG)
    
    local dialog_status=$?
    log "DEBUG" "Estado de dialog: $dialog_status"
    
    case $dialog_status in
        0)
            log "INFO" "Partición seleccionada: $selected_partition"
            export selected_partition
            return 0
            ;;
        1)
            log "INFO" "Usuario canceló la selección"
            if dialog --clear \
                     --backtitle "Instalador de Arch Linux" \
                     --title "Cancelar instalación" \
                     --yesno "¿Estás seguro de que deseas cancelar la instalación?" \
                     7 60; then
                log "INFO" "Instalación cancelada por el usuario"
                echo "Instalación cancelada."
                exit 0
            else
                log "INFO" "Reiniciando selección de partición"
                select_installation_partition
            fi
            ;;
        *)
            log "ERROR" "Error inesperado en dialog (código: $dialog_status)"
            dialog --clear \
                   --backtitle "Instalador de Arch Linux" \
                   --title "Error" \
                   --msgbox "Ocurrió un error al seleccionar la partición. Por favor, inténtalo de nuevo." \
                   7 60
            return 1
            ;;
    esac
}

# Función para particionar el disco
partition_disk() {
  dialog --clear --backtitle "Instalador de Arch Linux" \
         --title "Particionado del disco" \
         --msgbox "Se procederá a particionar el disco seleccionado. Se crearán las siguientes particiones:\n\n- Partición de arranque (512MB)\n- Partición raíz (100GB)\n- Partición de intercambio (tamaño de la RAM)" \
         10 60
         
  boot_partition_size=512M
  swap_partition_size=$(free -m | awk '/^Mem:/ {print $2}')M
  
  parted -s $selected_partition mklabel gpt
  parted -s $selected_partition mkpart primary ext4 1 $boot_partition_size
  parted -s $selected_partition set 1 boot on
  parted -s $selected_partition mkpart primary ext4 $boot_partition_size 100G
  parted -s $selected_partition mkpart primary linux-swap 100G 100%
  
  mkfs.ext4 "${selected_partition}1"
  mkfs.ext4 "${selected_partition}2"
  mkswap "${selected_partition}3"
  swapon "${selected_partition}3"
}

# Función para configurar partición de intercambio (swap)
configure_swap() {
  swap_size=$(dialog --clear --stdout --backtitle "Instalador de Arch Linux" \
                     --title "Configuración de swap" \
                     --inputbox "Ingresa el tamaño de la partición de intercambio (swap) en GB (0 para omitir):" \
                     8 60)

  if [ -z "$swap_size" ]; then
    echo "Tamaño de swap no válido. Se omitirá la creación de la partición de intercambio."
    return 1
  fi

  if [ $swap_size -gt 0 ]; then
    parted -s $selected_partition mkpart primary linux-swap 100% $((100 - $swap_size))%
    mkswap "${selected_partition}3"
    swapon "${selected_partition}3"
  fi
}

# Función para montar las particiones
mount_partitions() {
  mount "${selected_partition}2" /mnt
  mkdir /mnt/boot
  mount "${selected_partition}1" /mnt/boot
}

# Función para instalar el sistema base
install_base_system() {
  pacstrap /mnt base base-devel linux linux-firmware
}

# Función para generar el archivo fstab
generate_fstab() {
  genfstab -U /mnt >> /mnt/etc/fstab
}

# Función para configurar la zona horaria
configure_timezone() {
  timezones=$(timedatectl list-timezones)
  timezone=$(dialog --clear --stdout --backtitle "Instalador de Arch Linux" \
                    --title "Configuración de zona horaria" \
                    --menu "Selecciona la zona horaria:" \
                    20 60 10 \
                    $(echo "$timezones" | while read -r line; do echo "$line" ""; done))

  if [ -n "$timezone" ]; then
    arch-chroot /mnt /bin/bash -c "ln -sf /usr/share/zoneinfo/$timezone /etc/localtime"
    arch-chroot /mnt /bin/bash -c "hwclock --systohc"
  else
    echo "No se seleccionó una zona horaria válida. Se utilizará la zona horaria predeterminada."
  fi
}

# Función para configurar el idioma del sistema
configure_language() {
  echo "$language UTF-8" > /mnt/etc/locale.gen
  arch-chroot /mnt /bin/bash -c "locale-gen"
  echo "LANG=$language" > /mnt/etc/locale.conf
}

# Función para configurar el nombre del host
configure_hostname() {
  hostname=$(dialog --clear --stdout --backtitle "Instalador de Arch Linux" \
                    --title "Nombre del equipo" \
                    --inputbox "Ingresa el nombre del equipo:" \
                    8 40)
                    
  if [ -n "$hostname" ]; then
    echo $hostname > /mnt/etc/hostname
    echo "127.0.0.1 localhost" >> /mnt/etc/hosts
    echo "::1 localhost" >> /mnt/etc/hosts
    echo "127.0.1.1 $hostname.localdomain $hostname" >> /mnt/etc/hosts
  else
    echo "No se proporcionó un nombre de equipo válido. Se utilizará el nombre predeterminado 'arch'."
    echo "arch" > /mnt/etc/hostname
  fi
}

# Función para instalar y configurar el gestor de arranque
install_bootloader() {
  if detect_windows_installation; then
    arch-chroot /mnt /bin/bash -c "pacman -S grub efibootmgr os-prober ntfs-3g --noconfirm"
    arch-chroot /mnt /bin/bash -c "grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB"
    arch-chroot /mnt /bin/bash -c "os-prober"
    arch-chroot /mnt /bin/bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
  else
    arch-chroot /mnt /bin/bash -c "pacman -S grub efibootmgr --noconfirm"
    arch-chroot /mnt /bin/bash -c "grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB"
    arch-chroot /mnt /bin/bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
  fi
}

# Función para crear un usuario
create_user() {
  username=$(dialog --clear --stdout --backtitle "Instalador de Arch Linux" \
                    --title "Creación de usuario" \
                    --inputbox "Ingresa el nombre de usuario:" \
                    8 40)

  if [ -n "$username" ]; then
    arch-chroot /mnt /bin/bash -c "useradd -m -G wheel -s /bin/bash $username"
    arch-chroot /mnt /bin/bash -c "passwd $username"
    arch-chroot /mnt /bin/bash -c "echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers"
  else
    echo "No se proporcionó un nombre de usuario válido. No se creará un usuario adicional."
  fi
}

# Función para instalar y configurar el entorno de escritorio
install_desktop_environment() {
  desktop_envs=("gnome" "GNOME"
                "kde" "KDE Plasma"
                "xfce" "Xfce"
                "none" "Ninguno")

  desktop_env=$(dialog --clear --stdout --backtitle "Instalador de Arch Linux" \
                       --title "Entorno de escritorio" \
                       --menu "Selecciona el entorno de escritorio a instalar:" \
                       12 60 4 \
                       "${desktop_envs[@]}")

  case $desktop_env in
    gnome)
      arch-chroot /mnt /bin/bash -c "pacman -S gnome gnome-extra --noconfirm"
      arch-chroot /mnt /bin/bash -c "systemctl enable gdm"
      ;;
    kde)
      arch-chroot /mnt /bin/bash -c "pacman -S plasma plasma-wayland-session kde-applications --noconfirm"
      arch-chroot /mnt /bin/bash -c "systemctl enable sddm"
      ;;
    xfce)
      arch-chroot /mnt /bin/bash -c "pacman -S xfce4 xfce4-goodies --noconfirm"
      arch-chroot /mnt /bin/bash -c "systemctl enable lightdm"
      ;;
    none)
      echo "No se instalará ningún entorno de escritorio."
      ;;
    *)
      echo "Opción de entorno de escritorio no válida. No se instalará ningún entorno de escritorio."
      ;;
  esac
}

# Función para instalar paquetes adicionales
install_additional_packages() {
  additional_packages=("vim" "Editor de texto Vim" off
                       "nano" "Editor de texto Nano" off
                       "openssh" "Servidor SSH" off
                       "networkmanager" "Administrador de redes" off
                       "bash-completion" "Autocompletado de Bash" off)

  selected_packages=$(dialog --clear --stdout --backtitle "Instalador de Arch Linux" \
                              --title "Paquetes adicionales" \
                              --checklist "Selecciona los paquetes adicionales a instalar:" \
                              15 60 5 \
                              "${additional_packages[@]}")

  if [ -n "$selected_packages" ]; then
    for package in $selected_packages; do
      arch-chroot /mnt /bin/bash -c "pacman -S $package --noconfirm"
    done
  else
    echo "No se seleccionaron paquetes adicionales para instalar."
  fi
}

# Función principal
# Función principal
main() {
    log "INFO" "Iniciando el instalador de Arch Linux"
    # Limpiar logs anteriores
    : > "$LOG_FILE"
    : > "$ERROR_LOG"
    
    # Verificar si es root
    if [ "$EUID" -ne 0 ]; then
        log "ERROR" "El script debe ejecutarse como root"
        echo "Este script debe ejecutarse como root"
        exit 1
    fi  # <-- Aquí estaba el error, era } en lugar de fi
    
    # Verificar y preparar el sistema
    if ! check_dependencies; then
        log "ERROR" "Fallo en la verificación de dependencias"
        exit 1
    fi  # <-- Aquí también era } en lugar de fi
    
    display_banner
    welcome
    
    if ! select_language; then
        log "ERROR" "Fallo en la selección de idioma"
        exit 1
    fi
    
    if ! set_keyboard_layout; then
        log "ERROR" "Fallo en la configuración del teclado"
        exit 1
    fi
    
    if ! check_internet_connection; then
        log "ERROR" "Fallo en la verificación de conexión a Internet"
        exit 1
    fi

    if ! detect_windows_installation; then
        log "ERROR" "Fallo en la verificación si hay otro SO como windows"
        exit 1
    fi
    
    if ! select_installation_partition; then
        log "ERROR" "Fallo al seleccionar la partición para la instalación"
        exit 1
    fi

    if ! partition_disk; then
        log "ERROR" "Fallo al realizar la partición para la instalación"
        exit 1
    fi

    if ! configure_swap; then
        log "ERROR" "Fallo al configurar la particion SWAP"
        exit 1
    fi

    if ! mount_partitions; then
        log "ERROR" "Fallo al montar las particiones"
        exit 1
    fi

    if ! install_base_system; then
        log "ERROR" "Fallo al realizar la base del sistema"
        exit 1
    fi

    if ! generate_fstab; then
        log "ERROR" "fallo al generar la particion de fstab"
        exit 1
    fi
    
    configure_timezone
    configure_language
    configure_hostname
    
    install_bootloader
    
    create_user
    install_desktop_environment
    install_additional_packages
        
    log "INFO" "Instalación completada exitosamente"
    
    dialog --clear --backtitle "Instalador de Arch Linux" \
           --title "Instalación completada" \
           --msgbox "La instalación de Arch Linux se ha completado exitosamente. Puedes reiniciar tu sistema ahora." \
           8 60

    umount -R /mnt
    reboot
}

main "$@"
