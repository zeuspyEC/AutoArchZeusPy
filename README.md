# AutoArchZ
This is a autoinstall for Arch users... Can use for UEFI and BIOS.

## Installation
1. Update the system packages:
```
pacman -Sy
```
2. Install `curl`:
```
pacman -S curl
```
3. Download and run the `run.sh` script:
```
curl -L https://raw.githubusercontent.com/zeuspyEC/AutoArchZeusPy/main/run.sh -o run.sh
```
4. Use dos2unix to convert file `run.py` to Unix format
```
pacman -S dos2unix
dos2unix run.sh
```
5. Run and enjoy
```
chmod +x run.sh
./run.sh
```

The script will handle the automated installation of Arch Linux on your system.

## Features
- Compatible with UEFI and BIOS systems
- Automated installation of Arch Linux
- Simplifies the installation process for new users

## Contribution
If you find any issues or have suggestions for improvements, please create an issue or submit a pull request on the GitHub repository:
https://github.com/zeuspyEC/AutoArchZeusPy


### Métodos de Detección (en orden de prioridad):
1. **`/sys/firmware/efi/efivars`** - Más confiable
2. **`efibootmgr`** - Verificación secundaria
3. **`dmesg | grep "EFI v"`** - Logs del kernel
4. **`dmidecode -t bios`** - Información del BIOS
5. **Tabla de particiones existente** - GPT = UEFI, MBR = BIOS
6. **Partición EFI montada** - `/boot/efi` o `/efi`

### Validación Automática:
- Si detecta UEFI pero falta `/sys/firmware/efi` → Error y confirmación
- Si detecta BIOS pero existe `/sys/firmware/efi/efivars` → Cambia a UEFI
- Fallback seguro: Si no puede determinar → BIOS Legacy

---

## ⚡ FLUJO PARA SISTEMA UEFI

### 1. **Detección**
```bash
detect_boot_mode() → BOOT_MODE="UEFI"
validate_boot_mode_detection() → Confirma UEFI
```

### 2. **Esquema de Particionamiento**
- **Automático**: GPT (no hay opción de elegir)
- Mensaje: `"Modo UEFI detectado - usando esquema GPT"`

### 3. **Creación de Particiones** (`create_gpt_partitions`)
```bash
parted -s $DISK mklabel gpt

# Partición 1: EFI
mkpart "EFI" fat32 1MiB 300MiB
set 1 esp on

# Partición 2: ROOT  
mkpart "ROOT" ext4 300MiB -4GiB

# Partición 3: SWAP
mkpart "SWAP" linux-swap -4GiB 100%
```

### 4. **Formateo**
```bash
mkfs.fat -F32 /dev/sdX1    # EFI - FAT32
mkfs.ext4 /dev/sdX2        # ROOT - EXT4
mkswap /dev/sdX3           # SWAP
swapon /dev/sdX3
```

### 5. **Montaje**
```bash
mount /dev/sdX2 /mnt               # ROOT
mkdir -p /mnt/boot/efi
mount /dev/sdX1 /mnt/boot/efi      # EFI
```

### 6. **Instalación Base**
```bash
pacstrap /mnt base base-devel linux linux-firmware
pacstrap /mnt efibootmgr grub networkmanager
```

### 7. **Configuración GRUB**
```bash
arch-chroot /mnt grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot/efi \
    --bootloader-id=GRUB \
    --recheck

arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
```

### 8. **Verificación Final**
- Verifica `/mnt/boot/efi/EFI/GRUB/grubx64.efi` existe
- Verifica entradas EFI con `efibootmgr -v`

---

## 🖥️ FLUJO PARA SISTEMA BIOS LEGACY

### 1. **Detección**
```bash
detect_boot_mode() → BOOT_MODE="BIOS"  
validate_boot_mode_detection() → Confirma BIOS
```

### 2. **Esquema de Particionamiento**
- **Automático**: MBR/DOS (no hay opción de elegir)
- Mensaje: `"Modo BIOS Legacy detectado - usando esquema MBR"`

### 3. **Creación de Particiones** (`create_mbr_partitions`)
```bash
parted -s $DISK mklabel msdos

# Partición 1: BOOT
mkpart primary ext4 1MiB 512MiB
set 1 boot on

# Partición 2: ROOT
mkpart primary ext4 512MiB -4GiB  

# Partición 3: SWAP
mkpart primary linux-swap -4GiB 100%
```

### 4. **Formateo**
```bash
mkfs.ext4 /dev/sdX1        # BOOT - EXT4
mkfs.ext4 /dev/sdX2        # ROOT - EXT4
mkswap /dev/sdX3           # SWAP
swapon /dev/sdX3
```

### 5. **Montaje**
```bash
mount /dev/sdX2 /mnt        # ROOT
mkdir -p /mnt/boot
mount /dev/sdX1 /mnt/boot   # BOOT
```

### 6. **Instalación Base**
```bash
pacstrap /mnt base base-devel linux linux-firmware
pacstrap /mnt grub networkmanager
```

### 7. **Configuración GRUB**
```bash
arch-chroot /mnt grub-install \
    --target=i386-pc \
    --recheck \
    /dev/sdX

arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
```

### 8. **Verificación Final**
- Verifica `/mnt/boot/grub` existe
- Verifica MBR instalado en disco

---

## 📊 TABLA COMPARATIVA

| Aspecto | UEFI | BIOS Legacy |
|---------|------|-------------|
| **Detección** | `/sys/firmware/efi/efivars` existe | No existe `/sys/firmware/efi/efivars` |
| **Tabla Particiones** | GPT (obligatorio) | MBR/DOS (obligatorio) |
| **Partición Boot** | `/boot/efi` (FAT32, 300MB) | `/boot` (EXT4, 512MB) |
| **Flag Boot** | `esp on` en partición EFI | `boot on` en partición BOOT |
| **GRUB Target** | `x86_64-efi` | `i386-pc` |
| **GRUB Install** | En partición EFI | En MBR del disco |
| **Directorio GRUB** | `/boot/efi/EFI/GRUB/` | `/boot/grub/` |
| **Verificación** | `efibootmgr -v` | Sector de arranque MBR |

---

## 🔄 FLUJO DE DECISIÓN AUTOMÁTICO

```
INICIO
   ↓
[Detectar Modo de Arranque]
   ↓
¿Existe /sys/firmware/efi/efivars?
   ├─ SÍ → UEFI
   │   ├─ Tabla: GPT
   │   ├─ Particiones: EFI + ROOT + SWAP
   │   ├─ Montaje: /mnt/boot/efi
   │   └─ GRUB: x86_64-efi
   │
   └─ NO → BIOS
       ├─ Tabla: MBR
       ├─ Particiones: BOOT + ROOT + SWAP
       ├─ Montaje: /mnt/boot
       └─ GRUB: i386-pc
```

---

## ✅ VALIDACIONES IMPLEMENTADAS

### Durante la Detección:
- ✓ Múltiples métodos de detección con fallback
- ✓ Validación cruzada de consistencia
- ✓ Logging detallado de cada método usado

### Durante el Particionado:
- ✓ No permite elegir esquema incorrecto
- ✓ Tamaños automáticos según RAM disponible
- ✓ Verificación de particiones creadas

### Durante el Montaje:
- ✓ Función unificada `mount_partitions()`
- ✓ Verificación de puntos de montaje
- ✓ Creación automática de directorios

### Durante GRUB:
- ✓ Parámetros específicos según modo
- ✓ Verificación de archivos instalados
- ✓ Configuración automática

---

## 🛠️ COMANDOS DE VERIFICACIÓN MANUAL

### Para verificar el modo actual:
```bash
# Método 1
[ -d /sys/firmware/efi/efivars ] && echo "UEFI" || echo "BIOS"

# Método 2  
efibootmgr && echo "UEFI" || echo "BIOS"

# Método 3
dmesg | grep -E "EFI|BIOS"
```

### Para verificar la tabla de particiones:
```bash
# Ver tipo de tabla
parted /dev/sdX print | grep "Partition Table"

# GPT = UEFI típicamente
# msdos = BIOS típicamente
```

---

## 📝 NOTAS IMPORTANTES

1. **El script NO permite**:
   - Usar MBR con UEFI
   - Usar GPT con BIOS (aunque técnicamente es posible)
   - Elegir manualmente el esquema (es automático)

2. **Fallback de seguridad**:
   - Si no puede detectar → asume BIOS
   - Si hay inconsistencia → pregunta al usuario

3. **Logs generados**:
   - `/tmp/zeuspyec_installer.log` - Log general
   - `/tmp/zeuspyec_installer_error.log` - Errores
   - `/tmp/zeuspyec_installer_debug.log` - Debug detallado

4. **Recuperación ante errores**:
   - Función `repair_mount_points()` si falla el montaje
   - Retry automático en comandos críticos
   - Validación antes de continuar

Este flujo garantiza que:
- **UEFI siempre use GPT + partición EFI**
- **BIOS siempre use MBR + partición BOOT**
- **No hay configuraciones mixtas o incorrectas**

## License
This project is distributed under the MIT License. Check the `LICENSE` file for more information.
