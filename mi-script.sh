#!/bin/bash

# Función para centrar texto
format_center_literals() {
  local text="$1"
  local width=$(tput cols)
  local padding=$((($width - ${#text}) / 2))
  printf "%*s%s%*s\n" $padding "" "$text" $padding ""
}

# Banner "ZeusPy"
display_banner() {
  local banner=(
    " ▒███████▒▓█████  █    ██   ██████  ██▓███  ▓██   ██▓"
    "▒ ▒ ▒ ▄▀░▓█   ▀  ██  ▓██▒▒██    ▒ ▓██░  ██▒ ▒██  ██▒"
    "░ ▒ ▄▀▒░ ▒███   ▓██  ▒██░░ ▓██▄   ▓██░ ██▓▒  ▒██ ██░"
    "  ▄▀▒   ░▒▓█  ▄ ▓▓█  ░██░  ▒   ██▒▒██▄█▓▒ ▒  ░ ▐██▓░"
    "▒███████▒░▒████▒▒▒█████▓ ▒██████▒▒▒██▒ ░  ░  ░ ██▒▓░"
    "░▒▒ ▓░▒░▒░░ ▒░ ░░▒▓▒ ▒ ▒ ▒ ▒▓▒ ▒ ░▒▓▒░ ░  ░   ██▒▒▒ "
    "░░▒ ▒ ░ ▒ ░ ░  ░░░▒░ ░ ░ ░ ░▒  ░ ░░▒ ░     ▓██ ░▒░ "
    "░ ░ ░ ░ ░   ░    ░░░ ░ ░ ░  ░  ░  ░░       ▒ ▒ ░░  "
    "  ░ ░       ░  ░   ░           ░           ░ ░     "
    "░                                         ░ ░     "
  )

  clear
  echo -e "\033[34m"
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

  printf "["
  printf "%*s" "$progress" | tr ' ' '='
  printf "%*s" "$remaining" | tr ' ' ' '
  printf "] %s (%d/%d)\r" "$step_name" "$current_step" "$total_steps"
}

# Función para obtener la lista de particiones
get_partitions() {
  local partitions=$(lsblk -n -o NAME,SIZE,TYPE -p | awk '/part|lvm/ {print $1, $2, $3}')

  if [ -z "$partitions" ]; then
    partitions=$(fdisk -l | grep -E '^/dev/[[:alnum:]]+[[:digit:]]' | awk '{print $1, $3, $4}')
  fi

  if [ -z "$partitions" ]; then
    partitions=$(parted -l | grep -E '^/dev/[[:alnum:]]+[[:digit:]]' | awk '{print $1, $3, $4}')
  fi

  echo "$partitions"
}

# Función para seleccionar la partición de instalación
select_installation_partition() {
  local partitions=$(get_partitions)

  partition_list=()
  while IFS= read -r line; do
    partition_list+=("$line")
  done <<< "$partitions"

  partition_options=()
  for partition in "${partition_list[@]}"; do
    partition_options+=("$partition" "")
  done

  selected_partition=$(whiptail --title "Selección de Partición" --menu "Seleccione la partición donde desea instalar Arch Linux:" 20 78 10 "${partition_options[@]}" 3>&1 1>&2 2>&3)

  if [ $? -eq 0 ]; then
    echo "Partición seleccionada: $selected_partition"
  else
    echo "No se seleccionó ninguna partición. Saliendo del instalador."
    exit 1
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

  select_installation_partition

  if [ "$boot_mode" == "uefi" ]; then
    partition_disk_uefi
    mount_partitions_uefi
  else
    partition_disk_bios
    mount_partitions_bios
  fi

  install_base_system
  generate_fstab
  configure_system

  if [ "$boot_mode" == "uefi" ]; then
    install_grub_uefi
    configure_dual_boot_uefi
  else
    install_grub_bios
    configure_dual_boot_bios
  fi

  install_window_manager

  echo "Instalación completada. Reinicie el sistema."
}

# Ejecutar script
main
