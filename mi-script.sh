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
  language=$(dialog --stdout \
                    --backtitle "Instalador de Arch Linux" \
                    --title "Selección de idioma" \
                    --menu "Selecciona el idioma de instalación:" \
                    10 40 4 \
                    "es_ES.UTF-8" "Español" \
                    "en_US.UTF-8" "Inglés" \
                    "fr_FR.UTF-8" "Francés"
                    "ru_RU.UTF-8" "Ruso")
                    
  echo "$language UTF-8" > /etc/locale.gen
  locale-gen
  echo "LANG=$language" > /etc/locale.conf
  export LANG=$language
}

# Función para configurar el teclado
set_keyboard_layout() {
  keyboard_layout=$(dialog --stdout \
                           --backtitle "Instalador de Arch Linux" \
                           --title "Configuración de teclado" \
                           --menu "Selecciona la distribución de teclado:" \
                           10 40 4 \
                           "es" "Español" \
                           "us" "Inglés (EE. UU.)" \
                           "fr" "Francés"
                           "ru" "Ruso")
                           
  loadkeys $keyboard_layout
}

# Función para verificar la conexión a Internet
check_internet_connection() {
  if ping -c 1 archlinux.org >/dev/null 2>&1; then
    dialog --backtitle "Instalador de Arch Linux" \
           --title "Conexión a Internet" \
           --msgbox "La conexión a Internet está activa." \
           5 40
  else
    dialog --backtitle "Instalador de Arch Linux" \
           --title "Error de conexión" \
           --msgbox "No se pudo establecer una conexión a Internet. Verifica tu conexión e inténtalo de nuevo." \
           6 60
    exit 1
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

  selected_partition=$(dialog --stdout \
                              --backtitle "Instalador de Arch Linux" \
                              --title "Selección de partición" \
                              --menu "Selecciona la partición donde deseas instalar Arch Linux:" \
                              20 60 10 \
                              $partition_list)
                              
  if [ -z "$selected_partition" ]; then
    dialog --backtitle "Instalador de Arch Linux" \
           --title "Cancelar instalación" \
           --yesno "¿Estás seguro de que deseas cancelar la instalación?" \
           7 60
    
    if [ $? -eq 0 ]; then
      clear
      exit 0
    else
      select_installation_partition
    fi
  fi
}

# Función para particionar el disco
partition_disk() {
  dialog --backtitle "Instalador de Arch Linux" \
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
  timezone=$(curl -s http://ip-api.com/line?fields=timezone)
  arch-chroot /mnt /bin/bash -c "ln -sf /usr/share/zoneinfo/$timezone /etc/localtime"
  arch-chroot /mnt /bin/bash -c "hwclock --systohc"
}

# Función para configurar el idioma del sistema
configure_language() {
  echo "$language UTF-8" > /mnt/etc/locale.gen
  arch-chroot /mnt /bin/bash -c "locale-gen"
  echo "LANG=$language" > /mnt/etc/locale.conf
}

# Función para configurar el nombre del host
configure_hostname() {
  hostname=$(dialog --stdout \
                    --backtitle "Instalador de Arch Linux" \
                    --title "Nombre del equipo" \
                    --inputbox "Ingresa el nombre del equipo:" \
                    8 40)
                    
  echo $hostname > /mnt/etc/hostname
  echo "127.0.0.1 localhost" >> /mnt/etc/hosts
  echo "::1 localhost" >> /mnt/etc/hosts
  echo "127.0.1.1 $hostname.localdomain $hostname" >> /mnt/etc/hosts
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
  username=$(dialog --stdout \
                    --backtitle "Instalador de Arch Linux" \
                    --title "Creación de usuario" \
                    --inputbox "Ingresa el nombre de usuario:" \
                    8 40)

  arch-chroot /mnt /bin/bash -c "useradd -m -G wheel -s /bin/bash $username"
  arch-chroot /mnt /bin/bash -c "passwd $username"
  arch-chroot /mnt /bin/bash -c "echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers"
}

# Función para instalar y configurar el entorno de escritorio
install_desktop_environment() {
  desktop_env=$(dialog --stdout \
                       --backtitle "Instalador de Arch Linux" \
                       --title "Entorno de escritorio" \
                       --menu "Selecciona el entorno de escritorio a instalar:" \
                       12 60 4 \
                       "gnome" "GNOME" \
                       "kde" "KDE Plasma" \
                       "xfce" "Xfce" \
                       "none" "Ninguno")

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
  esac
}

# Función para instalar paquetes adicionales
install_additional_packages() {
  additional_packages=$(dialog --stdout \
                                --backtitle "Instalador de Arch Linux" \
                                --title "Paquetes adicionales" \
                                --checklist "Selecciona los paquetes adicionales a instalar:" \
                                15 60 5 \
                                "vim" "Editor de texto Vim" off \
                                "nano" "Editor de texto Nano" off \
                                "openssh" "Servidor SSH" off \
                                "networkmanager" "Administrador de redes" off \
                                "bash-completion" "Autocompletado de Bash" off)
                                
  for package in $additional_packages; do
    arch-chroot /mnt /bin/bash -c "pacman -S $package --noconfirm"  
  done
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
  
  dialog --backtitle "Instalador de Arch Linux" \
         --title "Instalación completada" \
         --msgbox "La instalación de Arch Linux se ha completado exitosamente. Puedes reiniciar tu sistema ahora." \
         8 60
         
  umount -R /mnt
  reboot
}

main
