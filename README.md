# 🚀 AutoArchZeusPy - Instalador Automático de Arch Linux

> **Instalador inteligente y minimalista para Arch Linux con soporte completo UEFI/BIOS y configuración automática de red**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/shell-bash-green.svg)](https://www.gnu.org/software/bash/)
[![Arch Linux](https://img.shields.io/badge/OS-Arch%20Linux-blue.svg)](https://archlinux.org/)

---

## 🎯 Características Principales

### ✨ **Instalación Inteligente**
- 🔍 **Detección automática** UEFI/BIOS con 6 métodos de verificación
- 🚀 **Instalación minimalista** - Solo paquetes esenciales durante instalación
- 📦 **Post-instalación inteligente** - Paquetes adicionales después del primer arranque
- 📶 **Configuración automática de red** - Detecta y reutiliza credenciales WiFi del modo live

### 🛡️ **Confiabilidad**
- ✅ UEFI → GPT (automático) | BIOS → MBR (automático)
- 🔄 Retry automático en comandos críticos
- 📝 Logging detallado con archivos de log
- 🛠️ Recuperación ante errores de red

### 🎨 **Facilidad de Uso**
- ⌨️ **Enter = Sí** en todas las confirmaciones
- 🔧 **Sin configuración manual** de particiones
- 🏠 **Scripts listos** en el home del usuario
- 📱 **Interfaz intuitiva** con colores y barras de progreso

---

## ⚡ Instalación Rápida

### 🔥 **Método 1: Instalación Completa (Recomendado)**

```bash
# Desde el modo live de Arch Linux
pacman -Sy curl dos2unix
curl -L https://raw.githubusercontent.com/zeuspyEC/AutoArchZeusPy/main/run.sh -o run.sh
dos2unix run.sh
chmod +x run.sh
./run.sh
```

### 📦 **Método 2: Solo Post-Instalación**

```bash
# En sistema Arch ya instalado
curl -O https://raw.githubusercontent.com/zeuspyEC/AutoArchZeusPy/main/zeuspyec-post-install.sh
chmod +x zeuspyec-post-install.sh
./zeuspyec-post-install.sh
```

---

## 🔄 Flujo de Instalación

```
🔥 Modo Live → 📶 WiFi Activo → 📋 Script Detecta Credenciales
     ↓                ↓                      ↓
💾 Instalación → 📁 Crear Scripts → 🔄 Primer Arranque
   Mínima         Post-Install        ↓
     ↓               ↓             🚀 ./post-install.sh
🎨 Sistema Base → 🌐 Red Auto → 🎨 Sistema Completo
```

### 📊 **Instalación en 2 Fases**

| Fase | Contenido | Tiempo | Paquetes |
|------|-----------|--------|----------|
| **Instalación Base** | Sistema funcional mínimo | ~5-10 min | 8 esenciales |
| **Post-Instalación** | Entorno gráfico + extras | ~15-20 min | 30+ adicionales |

---

## 📶 Sistema de Red Automático

### 🧠 **¡La Magia del Script!**

**NO necesitas configurar WiFi manualmente**. El script detecta automáticamente la red que ya estás usando en el modo live:

```bash
# 🔍 Lo que hace automáticamente:
1. 📡 Detecta la red WiFi activa (nmcli/iwctl)
2. 🔑 Obtiene SSID y contraseña (cuando es posible)
3. 💾 Guarda todo en network_credentials.txt
4. 📋 Copia el archivo al sistema instalado
5. 🚀 En el primer arranque: reconecta automáticamente
```

### 📄 **Archivo de Credenciales (Creado Automáticamente)**

```txt
# network_credentials.txt
CONNECTION_TYPE=wifi
WIFI_SSID=MiRedWiFi
WIFI_PASSWORD=miClaveSecreta123
WIFI_INTERFACE=wlan0
INSTALL_DATE=2025-01-15 14:30:45
```

### 🔧 **Métodos de Detección Soportados**

- 🌐 **nmcli**: NetworkManager (método principal)
- 📡 **iwctl**: iwd (método alternativo)
- 🔌 **dhcpcd**: Ethernet automático
- 🛠️ **Manual**: Solo si falla la detección automática

---

## 🎨 Scripts Creados Automáticamente

### 📁 **En `/home/usuario/` encontrarás:**

| Script | Función | Comando |
|--------|---------|---------|
| `post-install.sh` | Instalación completa con red automática | `./post-install.sh` |
| `zeuspyec-post-install.sh` | Script independiente (funciona sin instalador) | `./zeuspyec-post-install.sh` |
| `wifi_networks.py` | Ver redes WiFi guardadas con contraseñas | `./wifi_networks.py` |
| `network_credentials.txt` | Credenciales de la instalación | *datos de red* |

### 🚀 **Contenido del Post-Install**

```bash
# 📦 Paquetes Esenciales
base-devel git wget curl vim htop neofetch python bash-completion

# 🎨 Entorno BSPWM (Opcional)
xorg bspwm sxhkd polybar picom rofi nitrogen alacritty firefox

# 🎯 Tema gh0stzk (Opcional)  
RiceInstaller automático con todos los temas

# 🔧 Servicios
NetworkManager bluetooth fstrim.timer
```

### 💡 **Gestión WiFi Post-Instalación**

```bash
# 📶 Ver todas las redes WiFi guardadas (con contraseñas)
./wifi_networks.py

# 🔍 Conectar a nueva red
nmcli device wifi connect "NOMBRE_RED" password "CONTRASEÑA"

# 📋 Ver redes disponibles
nmcli device wifi list

# 🔧 Estado de NetworkManager
nmcli device status
```

---

## 🔧 Soporte UEFI/BIOS

### 🎯 **Detección Automática Robusta**

El script usa **6 métodos de detección** en orden de prioridad:

```bash
1. /sys/firmware/efi/efivars     # Más confiable
2. efibootmgr                    # Verificación EFI
3. dmesg | grep "EFI"           # Logs del kernel  
4. dmidecode -t bios            # Info del BIOS
5. Tabla de particiones         # GPT = UEFI, MBR = BIOS
6. Partición EFI montada        # /boot/efi existe
```

### ⚙️ **Configuración Automática por Modo**

| Aspecto | 🖥️ UEFI | 💻 BIOS Legacy |
|---------|----------|---------------|
| **Detección** | `/sys/firmware/efi/efivars` existe | No existe efivars |
| **Particiones** | GPT (automático) | MBR (automático) |
| **Boot** | `/boot/efi` (FAT32, 300MB) | `/boot` (EXT4, 512MB) |
| **GRUB** | `x86_64-efi` | `i386-pc` |
| **Montaje** | `/mnt/boot/efi` | `/mnt/boot` |

### 🔄 **Flujo de Decisión**

```
Inicio → Detección Modo
    ↓
¿UEFI detectado?
├─ ✅ SÍ: GPT + EFI + x86_64-efi + /boot/efi
└─ ❌ NO:  MBR + BOOT + i386-pc + /boot
    ↓
Validación cruzada → Instalación automática
```

---

## 📋 Paquetes por Fase

### **Fase 1: Instalación Base (Modo Live)**
```bash
ESSENTIAL_PACKAGES=(
    "base"           # Sistema base
    "linux"          # Kernel
    "linux-firmware" # Firmware
    "networkmanager" # Red
    "grub"           # Bootloader
    "efibootmgr"     # UEFI (si aplica)
    "sudo"           # Privilegios
    "nano"           # Editor básico
)
```

### **Fase 2: Post-Instalación (Primer Arranque)**
```bash
ADDITIONAL_PACKAGES=(
    "base-devel" "git" "wget" "curl" "vim" 
    "htop" "neofetch" "python" "bash-completion"
    "man-db" "zip" "unzip" "reflector"
)

BSPWM_PACKAGES=(
    "xorg" "bspwm" "sxhkd" "polybar" "picom"
    "rofi" "nitrogen" "alacritty" "firefox" "thunar"
)
```

---

## 🛠️ Comandos Útiles

### 🔍 **Verificación del Sistema**

```bash
# Ver modo actual
[ -d /sys/firmware/efi/efivars ] && echo "UEFI" || echo "BIOS"

# Ver particiones
lsblk -f

# Estado de red
nmcli device status
nmcli connection show

# Logs de instalación
tail -f /tmp/zeuspyec_installer.log
```

### 🚨 **Solución de Problemas**

```bash
# Error de red durante instalación
sudo systemctl restart NetworkManager
nmcli device wifi connect "RED" password "CLAVE"

# Reiniciar post-instalación
./zeuspyec-post-install.sh

# Ver credenciales guardadas
cat ~/network_credentials.txt

# Mostrar redes WiFi con contraseñas
./wifi_networks.py
```

---

## 🎯 Ventajas del Sistema

### ✅ **Por Qué AutoArchZeusPy**

- 🚀 **Más Rápido**: Instalación base en 5-10 minutos
- 🧠 **Más Inteligente**: Detecta automáticamente UEFI/BIOS y red
- 🛡️ **Más Seguro**: Validaciones robustas y logging detallado
- 📶 **Más Conveniente**: Reutiliza credenciales WiFi del modo live
- 🎨 **Más Completo**: Entorno gráfico listo con un comando

### 📈 **Comparación con Instalación Manual**

| Tarea | Manual | AutoArchZeusPy |
|-------|--------|----------------|
| Particionado | 15+ comandos complejos | Automático según modo |
| Detección UEFI/BIOS | Verificación manual | 6 métodos automáticos |
| Configuración Red | Repetir setup cada vez | Reutiliza del modo live |
| Instalación GRUB | Múltiples pasos según modo | Un comando automático |
| Post-instalación | Todo manual | Scripts inteligentes |
| Configuración WiFi | nmcli/iwctl manual | Detección automática |

---

## 🔄 Casos de Uso

### 🏠 **Uso Personal**
```bash
# Usuario quiere instalar Arch rápidamente
./run.sh
# → Sistema base + post-install listo en 30 minutos
```

### 🎓 **Uso Educativo**
```bash
# Estudiante necesita entorno de desarrollo
./zeuspyec-post-install.sh
# → Python, git, vim, htop instalados automáticamente
```

### 🖥️ **Servidor/VirtualBox**
```bash
# Ethernet detectado automáticamente
# → Sin configuración WiFi manual
# → Instalación completamente automática
```

---

## 🤝 Contribución

¿Encontraste un bug o tienes una mejora? ¡Contribuye!

```bash
# 🍴 Fork del repositorio
git clone https://github.com/zeuspyEC/AutoArchZeusPy.git

# 🔧 Crea tu branch
git checkout -b feature/mejora-increible

# 💾 Commit
git commit -m "Add: funcionalidad increíble"

# 📤 Push
git push origin feature/mejora-increible

# 🎯 Pull Request
```

### 📧 **Contacto**
- 🐛 **Issues**: [GitHub Issues](https://github.com/zeuspyEC/AutoArchZeusPy/issues)
- 💬 **Discusiones**: [GitHub Discussions](https://github.com/zeuspyEC/AutoArchZeusPy/discussions)

---

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Consulta el archivo `LICENSE` para más detalles.

---

## ⭐ ¡Dale una estrella!

Si AutoArchZeusPy simplificó tu instalación de Arch Linux, ¡no olvides darle una ⭐ al repositorio!

---

> **💡 Tip Pro**: Si ya tienes WiFi funcionando en el modo live, el script detectará automáticamente las credenciales. No necesitas configurar nada manualmente.

---

**Desarrollado con ❤️ para la comunidad de Arch Linux**
