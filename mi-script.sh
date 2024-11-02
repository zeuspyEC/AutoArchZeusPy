#!/usr/bin/env bash

# Variables de colores
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Función para centrar texto
format_center() {
  local text="$1"
  local width=$(tput cols)
  local padding=$((($width - ${#text}) / 2))
  printf "%*s%s%*s\n" $padding "" "$text" $padding ""
}

# Función para mostrar el banner
display_banner() {
  clear
  format_center "${BLUE}███████╗███████╗██╗   ██╗███████╗██████╗ ██╗   ██╗███████╗ ██████╗${NC}"
  format_center "${BLUE}╚══███╔╝██╔════╝██║   ██║██╔════╝██╔══██╗╚██╗ ██╔╝██╔════╝██╔════╝${NC}"
  format_center "${BLUE}  ███╔╝ █████╗  ██║   ██║███████╗██████╔╝ ╚████╔╝ █████╗  ██║     ${NC}"
  format_center "${BLUE} ███╔╝  ██╔══╝  ██║   ██║╚════██║██╔═══╝   ╚██╔╝  ██╔══╝  ██║     ${NC}"
  format_center "${BLUE}███████╗███████╗╚██████╔╝███████║██║        ██║   ███████╗╚██████╗${NC}"
  format_center "${BLUE}╚══════╝╚══════╝ ╚═════╝ ╚══════╝╚═╝        ╚═╝   ╚══════╝ ╚═════╝${NC}"
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
  if ping -c 1 archlinux.org &> /dev/null; then
    dialog --backtitle "Instalador de Arch Linux" \
           --title "Conexión a Internet" \
           --msgbox "La conexión a Internet está activa." \
           5 40
  else
    dialog --backtitle "Instalador de Arch Linux" \
           --title "Error de conexión" \
           --msgbox "No se pudo establecer una conexión a Internet. Verifica tu conexión e inténtalo de nuevo." \
           6 60
    
    if dialog --backtitle "Instalador de Arch Linux" \
              --title "Reintentar conexión" \
              --yesno "¿Deseas reintentar la conexión a Internet?" \
              7 60; then
      check_internet_connection
    else
      echo "La instalación no puede continuar sin una conexión a Internet."
      exit 1
    fi
  fi
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
  partitions=$(lsblk -n -o NAME,SIZE,TYPE -p | awk '/part|lvm/ {print $1, $2, $3}')
  echo "$partitions"
}

# Función para seleccionar la partición de instalación
select_installation_partition() {
  partitions=$(get_partitions)
  partition_list=""
  
  while IFS= read -r partition; do
    partition_list+="$partition \"\" "
  done <<< "$partitions"

  selected_partition=$(dialog --clear --stdout --backtitle "Instalador de Arch Linux" \
                              --title "Selección de partición" \
                              --menu "Selecciona la partición donde deseas instalar Arch Linux:" \
                              20 60 10 \
                              $partition_list)
                              
  case $? in
    0)
      ;;
    1)
      if dialog --clear --backtitle "Instalador de Arch Linux" \
                --title "Cancelar instalación" \
                --yesno "¿Estás seguro de que deseas cancelar la instalación?" \
                7 60; then
        echo "Instalación cancelada."
        exit 0
      else
        select_installation_partition
      fi
      ;;
    255)
      echo "Ocurrió un error inesperado."
      exit 1
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
main() {
  display_banner
  welcome
  
  select_language
  set_keyboard_layout
  check_internet_connection
  
  detect_windows_installation
  
  select_installation_partition
  partition_disk
  configure_swap
  
  mount_partitions
  install_base_system
  generate_fstab
  
  configure_timezone
  configure_language
  configure_hostname
  
  install_bootloader
  
  create_user
  install_desktop_environment
  install_additional_packages
  
  dialog --clear --backtitle "Instalador de Arch Linux" \
         --title "Instalación completada" \
         --msgbox "La instalación de Arch Linux se ha completado exitosamente. Puedes reiniciar tu sistema ahora." \
         8 60

  umount -R /mnt
  reboot
}

main
