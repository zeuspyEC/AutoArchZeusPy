#!/bin/bash

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Función para centrar texto
format_center_literals() {
  local text="$1"
  local width=$(tput cols)
  local padding=$((($width - ${#text}) / 2))
  printf "%*s%s%*s\n" $padding "" "$text" $padding ""
}

# Banner "ZeusPyEC"
display_banner() {
  local banner=(
    "${BLUE} ▒███████▒▓█████  █    ██   ██████  ██▓███ ▓██   ██▓▓█████  ▄████▄${NC}"
    "${BLUE}▒ ▒ ▒ ▄▀░▓█   ▀  ██  ▓██▒▒██    ▒ ▓██░  ██▒▒██  ██▒▓█   ▀ ▒██▀ ▀█${NC}"
    "${BLUE}░ ▒ ▄▀▒░ ▒███   ▓██  ▒██░░ ▓██▄   ▓██░ ██▓▒ ▒██ ██░▒███   ▒▓█    ▄${NC}"
    "${BLUE}  ▄▀▒   ░▒▓█  ▄ ▓▓█  ░██░  ▒   ██▒▒██▄█▓▒ ▒ ░ ▐██▓░▒▓█  ▄ ▒▓▓▄ ▄██▒${NC}"
    "${BLUE}▒███████▒░▒████▒▒▒█████▓ ▒██████▒▒▒██▒ ░  ░ ░ ██▒▓░░▒████▒▒ ▓███▀ ░${NC}"
    "${BLUE}░▒▒ ▓░▒░▒░░ ▒░ ░░▒▓▒ ▒ ▒ ▒ ▒▓▒ ▒ ░▒▓▒░ ░  ░  ██▒▒▒ ░░ ▒░ ░░ ░▒ ▒  ░${NC}"
    "${BLUE}░░▒ ▒ ░ ▒ ░ ░  ░░░▒░ ░ ░ ░ ░▒  ░ ░░▒ ░     ▓██ ░▒░  ░ ░  ░  ░  ▒${NC}"
    "${BLUE}░ ░ ░ ░ ░   ░    ░░░ ░ ░ ░  ░  ░  ░░       ▒ ▒ ░░     ░   ░${NC}"
    "${BLUE}  ░ ░       ░  ░   ░           ░           ░ ░        ░  ░░ ░${NC}"
    "${BLUE}░                                         ░ ░             ░ ░${NC}"
  )

  clear
  for line in "${banner[@]}"; do
    format_center_literals "$line"
    sleep 0.05
  done
  echo
}

# Función para mostrar el progreso de la instalación
show_progress() {
  local current_step="$1"
  local total_steps="$2"
  local step_name="$3"

  local progress_width=50
  local progress=$((current_step * progress_width / total_steps))
  local remaining=$((progress_width - progress))

  printf "${CYAN}["
  printf "${GREEN}%*s${NC}" "$progress" | tr ' ' '='
  printf "${CYAN}%*s${NC}" "$remaining" | tr ' ' ' '
  printf "${CYAN}]${NC} ${BLUE}%s${NC} ${CYAN}(%d/%d)${NC}\r" "$step_name" "$current_step" "$total_steps"
}

# Función para obtener la lista de particiones
get_partitions() {
  local partitions=""

  # Obtener particiones utilizando lsblk
  partitions=$(lsblk -n -o NAME,SIZE,TYPE -p | awk '/part|lvm/ {print $1, $2, $3}')

  if [ -z "$partitions" ]; then
    # Obtener particiones utilizando fdisk
    partitions=$(fdisk -l 2>/dev/null | grep -E '^/dev/[[:alnum:]]+[[:digit:]]' | awk '{print $1, $3, $4}')
  fi

  if [ -z "$partitions" ]; then
    # Obtener particiones utilizando parted
    partitions=$(parted -l 2>/dev/null | grep -E '^/dev/[[:alnum:]]+[[:digit:]]' | awk '{print $1, $3, $4}')
  fi

  if [ -z "$partitions" ]; then
    # Obtener particiones utilizando df
    partitions=$(df -h | awk '$1 ~ /^\/dev\// {print $1, $2, "partition"}')
  fi

  if [ -z "$partitions" ]; then
    # Obtener particiones utilizando mount
    partitions=$(mount | awk '$1 ~ /^\/dev\// {print $1, $3, "partition"}')
  fi

  echo "$partitions"
}

# Función para seleccionar la partición de instalación
select_installation_partition() {
  local partitions=$(get_partitions)

  echo -e "${CYAN}Información de particiones:${NC}"
  echo -e "${partitions}\n"

  echo -e "${CYAN}Ejemplo de formato para ingresar la partición:${NC}"
  echo -e "${GREEN}/dev/sda1${NC}"

  read -p "Ingrese la partición donde desea instalar Arch Linux (o presione Enter para utilizar la primera partición disponible): " selected_partition

  if [ -z "$selected_partition" ]; then
    selected_partition=$(echo "$partitions" | head -n 1 | awk '{print $1}')
    echo -e "${GREEN}Se utilizará la primera partición disponible: ${BLUE}$selected_partition${NC}"
  else
    if ! echo "$partitions" | grep -q "$selected_partition"; then
      echo -e "${RED}La partición ingresada no es válida. Saliendo del instalador.${NC}"
      exit 1
    fi
  fi
}

# Función para detectar el modo de arranque (UEFI o BIOS)
detect_boot_mode() {
  if [ -d "/sys/firmware/efi/efivars" ]; then
    echo -e "${GREEN}Modo de arranque:${NC} ${BLUE}UEFI${NC}"
    boot_mode="uefi"
  else
    echo -e "${GREEN}Modo de arranque:${NC} ${BLUE}BIOS${NC}"
    boot_mode="bios"
  fi
}

# Función para detectar si existe una instalación de Windows
detect_windows_installation() {
  if [ -d "/mnt/windows" ]; then
    windows_installed=true
    echo -e "${GREEN}Se detectó una instalación de Windows.${NC}"
  else
    windows_installed=false
    echo -e "${GREEN}No se encontró una instalación de Windows.${NC}"
  fi
}

# Función para particionar el disco (UEFI)
partition_disk_uefi() {
  parted -s "$selected_partition" mklabel gpt
  parted -s "$selected_partition" mkpart primary fat32 1 512M
  parted -s "$selected_partition" set 1 esp on
  parted -s "$selected_partition" mkpart primary ext4 512M 100%
  mkfs.fat -F32 "${selected_partition}1"
  mkfs.ext4 "${selected_partition}2"
}

# Función para particionar el disco (BIOS)
partition_disk_bios() {
  parted -s "$selected_partition" mklabel msdos
  parted -s "$selected_partition" mkpart primary ext4 1 512M
  parted -s "$selected_partition" set 1 boot on
  parted -s "$selected_partition" mkpart primary ext4 512M 100%
  mkfs.ext4 "${selected_partition}1"
  mkfs.ext4 "${selected_partition}2"
}

# Función para montar particiones (UEFI)
mount_partitions_uefi() {
  mount "${selected_partition}2" /mnt
  mkdir -p /mnt/boot/efi
  mount "${selected_partition}1" /mnt/boot/efi
}

# Función para montar particiones (BIOS)
mount_partitions_bios() {
  mount "${selected_partition}2" /mnt
  mkdir -p /mnt/boot
  mount "${selected_partition}1" /mnt/boot
}

# Función para instalar el sistema base
install_base_system() {
  pacstrap /mnt base base-devel linux linux-firmware
}

# Función para generar fstab
generate_fstab() {
  genfstab -U /mnt >> /mnt/etc/fstab
}

# Función para configurar el sistema
configure_system() {
  arch-chroot /mnt /bin/bash <<EOF
  ln -sf /usr/share/zoneinfo/America/Guayaquil /etc/localtime
  hwclock --systohc
  echo "es_EC.UTF-8 UTF-8" >> /etc/locale.gen
  locale-gen
  echo "LANG=es_EC.UTF-8" > /etc/locale.conf
  echo "arch" > /etc/hostname
  echo "127.0.0.1 localhost" >> /etc/hosts
  echo "::1 localhost" >> /etc/hosts
  echo "127.0.1.1 arch.localdomain arch" >> /etc/hosts
  mkinitcpio -P
  passwd
EOF
}

# Función para instalar y configurar GRUB (UEFI)
install_grub_uefi() {
  arch-chroot /mnt /bin/bash <<EOF
  pacman -S --noconfirm grub efibootmgr
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
  grub-mkconfig -o /boot/grub/grub.cfg
EOF
}

# Función para instalar y configurar GRUB (BIOS)
install_grub_bios() {
  arch-chroot /mnt /bin/bash <<EOF
  pacman -S --noconfirm grub
  grub-install "$selected_partition"
  grub-mkconfig -o /boot/grub/grub.cfg
EOF
}

# Función para configurar dual boot con Windows (UEFI)
configure_dual_boot_uefi() {
  if [ "$windows_installed" = true ]; then
    arch-chroot /mnt /bin/bash <<EOF
    pacman -S --noconfirm os-prober ntfs-3g
    os-prober
    grub-mkconfig -o /boot/grub/grub.cfg
EOF
  fi
}

# Función para configurar dual boot con Windows (BIOS)
configure_dual_boot_bios() {
  if [ "$windows_installed" = true ]; then
    arch-chroot /mnt /bin/bash <<EOF
    pacman -S --noconfirm os-prober ntfs-3g
    os-prober
    grub-mkconfig -o /boot/grub/grub.cfg
EOF
  fi
}

# Función para instalar y configurar el gestor de ventanas
install_window_manager() {
  arch-chroot /mnt /bin/bash <<EOF
  pacman -S --noconfirm xorg-server xorg-xinit bspwm sxhkd
  echo "exec bspwm" > ~/.xinitrc
EOF
}

# Función principal
main() {
  display_banner

  detect_boot_mode
  detect_windows_installation

  printf "\n${CYAN}----------------------------------------------------------------------${NC}\n"
  echo -e "${BLUE}~~1. Selección de partición${NC}"
  echo -e "${CYAN}----------------------------------------------------------------------${NC}\n"
  sleep 2

  select_installation_partition

  printf "\n${CYAN}----------------------------------------------------------------------${NC}\n"
  echo -e "${BLUE}~~2. Particionado y formateo${NC}"
  echo -e "${CYAN}----------------------------------------------------------------------${NC}\n"
  sleep 2

  if [ "$boot_mode" == "uefi" ]; then
    partition_disk_uefi
    mount_partitions_uefi
  else
    partition_disk_bios
    mount_partitions_bios
  fi

  printf "\n${CYAN}----------------------------------------------------------------------${NC}\n"
  echo -e "${BLUE}~~3. Instalación del sistema base${NC}"
  echo -e "${CYAN}----------------------------------------------------------------------${NC}\n"
  sleep 2

  install_base_system
  generate_fstab
  configure_system

  printf "\n${CYAN}----------------------------------------------------------------------${NC}\n"
  echo -e "${BLUE}~~4. Instalación y configuración de GRUB${NC}"
  echo -e "${CYAN}----------------------------------------------------------------------${NC}\n"
  sleep 2

  if [ "$boot_mode" == "uefi" ]; then
    install_grub_uefi
    configure_dual_boot_uefi
  else
    install_grub_bios
    configure_dual_boot_bios
  fi

  printf "\n${CYAN}----------------------------------------------------------------------${NC}\n"
  echo -e "${BLUE}~~5. Instalación y configuración del gestor de ventanas${NC}"
  echo -e "${CYAN}----------------------------------------------------------------------${NC}\n"
  sleep 2

  install_window_manager

  echo -e "\n${GREEN}Instalación completada. Reinicie el sistema.${NC}"
}

# Ejecutar script
main
