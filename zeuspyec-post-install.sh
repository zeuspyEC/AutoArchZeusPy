#!/bin/bash

# Script de Post-Instalación ZeuspyEC (Independiente)
# Puede ejecutarse después de cualquier instalación básica de Arch Linux
# Para descargar: curl -O https://raw.githubusercontent.com/tu-usuario/AutoArchZeusPy/main/zeuspyec-post-install.sh

# Colores para output
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
WHITE="\033[0;37m"
RESET="\033[0m"

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                   POST-INSTALACIÓN ZEUSPYEC                     ║"
echo "║              Completando instalación del sistema                ║"
echo "║                Script independiente v1.0                        ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${RESET}\n"

# Función para configurar red automáticamente
configure_network() {
    echo -e "${CYAN}Configurando conexión de red...${RESET}"
    
    # Verificar si hay configuración guardada de instalación previa
    if [ -f ~/network_credentials.txt ]; then
        echo -e "${GREEN}✅ Archivo de credenciales encontrado${RESET}"
        
        # Leer archivo de credenciales (ignorar comentarios)
        while IFS='=' read -r key value; do
            [[ $key =~ ^#.*$ ]] && continue  # Ignorar comentarios
            [[ -z $key ]] && continue       # Ignorar líneas vacías
            declare "$key=$value"
        done < ~/network_credentials.txt
        
        if [ "$CONNECTION_TYPE" = "wifi" ] && [ -n "$WIFI_SSID" ] && [ -n "$WIFI_PASSWORD" ]; then
            echo -e "${CYAN}Configurando WiFi guardado: $WIFI_SSID${RESET}"
            
            # Iniciar NetworkManager si no está activo
            sudo systemctl start NetworkManager 2>/dev/null
            sleep 2
            
            # Conectar a WiFi usando nmcli
            if nmcli device wifi connect "$WIFI_SSID" password "$WIFI_PASSWORD" 2>/dev/null; then
                echo -e "${GREEN}✅ WiFi configurado correctamente${RESET}"
                return 0
            else
                echo -e "${YELLOW}⚠ Reintentando con método alternativo...${RESET}"
                # Método alternativo con iwctl
                if command -v iwctl >/dev/null 2>&1; then
                    iwctl station wlan0 connect "$WIFI_SSID" --passphrase "$WIFI_PASSWORD" 2>/dev/null && \
                    echo -e "${GREEN}✅ WiFi configurado con iwctl${RESET}" && return 0
                fi
            fi
            
        elif [ "$CONNECTION_TYPE" = "ethernet" ] && [ -n "$ETHERNET_INTERFACE" ]; then
            echo -e "${CYAN}Configurando Ethernet guardado: $ETHERNET_INTERFACE${RESET}"
            
            # Activar interface y obtener IP
            sudo ip link set "$ETHERNET_INTERFACE" up
            sudo dhcpcd "$ETHERNET_INTERFACE" 2>/dev/null &
            sleep 3
            
            if ping -c 1 archlinux.org >/dev/null 2>&1; then
                echo -e "${GREEN}✅ Ethernet configurado correctamente${RESET}"
                return 0
            fi
        fi
    else
        echo -e "${YELLOW}⚠ No se encontró archivo de credenciales previas${RESET}"
    fi
    
    # Configuración manual/automática
    echo -e "${YELLOW}Configurando red manualmente...${RESET}"
    
    # Preguntar tipo de conexión
    echo -e "\n${CYAN}Tipo de conexión:${RESET}"
    echo -e "  ${WHITE}1)${RESET} Ethernet (automático)"
    echo -e "  ${WHITE}2)${RESET} WiFi (manual)"
    echo -e "  ${WHITE}3)${RESET} Saltar configuración"
    echo -ne "\n${YELLOW}Seleccione opción (1-3):${RESET} "
    read -r network_choice
    
    case $network_choice in
        1)
            # Configurar ethernet automáticamente
            echo -e "${CYAN}Configurando ethernet...${RESET}"
            for interface in $(ip link show | grep -oE "en[a-zA-Z0-9]+" | head -1); do
                sudo ip link set "$interface" up 2>/dev/null
                sudo dhcpcd "$interface" 2>/dev/null &
                sleep 3
                if ping -c 1 archlinux.org >/dev/null 2>&1; then
                    echo -e "${GREEN}✅ Ethernet configurado${RESET}"
                    return 0
                fi
            done
            ;;
        2)
            # Configurar WiFi manualmente
            echo -e "${CYAN}Configurando WiFi...${RESET}"
            sudo systemctl start NetworkManager 2>/dev/null
            sleep 2
            
            echo -e "\n${CYAN}Redes WiFi disponibles:${RESET}"
            nmcli device wifi list 2>/dev/null | head -10
            
            echo -ne "\n${YELLOW}SSID de la red:${RESET} "
            read -r manual_ssid
            echo -ne "${YELLOW}Contraseña:${RESET} "
            read -rs manual_password
            echo
            
            if nmcli device wifi connect "$manual_ssid" password "$manual_password" 2>/dev/null; then
                echo -e "${GREEN}✅ WiFi configurado manualmente${RESET}"
                return 0
            fi
            ;;
        3)
            echo -e "${YELLOW}⚠ Configuración de red omitida${RESET}"
            return 1
            ;;
    esac
    
    return 1
}

# Verificar privilegios sudo
if ! sudo -n true 2>/dev/null; then
    echo -e "${YELLOW}Este script requiere privilegios sudo${RESET}"
    echo -e "${WHITE}Por favor, ingrese su contraseña:${RESET}"
    sudo true
fi

# Configurar red
configure_network
if ! ping -c 3 archlinux.org >/dev/null 2>&1; then
    echo -e "${RED}❌ Sin conexión a internet.${RESET}"
    echo -e "${YELLOW}Configure manualmente la red y ejecute el script de nuevo.${RESET}"
    echo -e "\n${WHITE}Comandos útiles:${RESET}"
    echo -e "  • ${CYAN}nmcli device wifi list${RESET} - Ver redes WiFi"
    echo -e "  • ${CYAN}nmcli device wifi connect 'RED' password 'CLAVE'${RESET} - Conectar WiFi"
    echo -e "  • ${CYAN}sudo dhcpcd enp0s3${RESET} - Configurar ethernet"
    exit 1
fi
echo -e "${GREEN}✅ Conexión verificada${RESET}\n"

# Actualizar sistema
echo -e "${CYAN}Actualizando sistema...${RESET}"
sudo pacman -Syu --noconfirm

# Instalar paquetes esenciales
echo -e "\n${CYAN}Instalando paquetes esenciales...${RESET}"
ESSENTIAL_PACKAGES=(
    "base-devel"
    "git"
    "wget"
    "curl"
    "vim"
    "htop"
    "neofetch"
    "python"
    "python-pip"
    "bash-completion"
    "man-db"
    "zip"
    "unzip"
)

for package in "${ESSENTIAL_PACKAGES[@]}"; do
    echo -ne "${WHITE}Instalando $package...${RESET} "
    if sudo pacman -S --noconfirm "$package" >/dev/null 2>&1; then
        echo -e "${GREEN}✅${RESET}"
    else
        echo -e "${RED}❌${RESET}"
    fi
done

# Preguntar por BSPWM
echo -e "\n${YELLOW}¿Instalar entorno gráfico BSPWM? [S/n]:${RESET} "
read -r install_bspwm
if [[ ! "$install_bspwm" =~ ^[Nn]$ ]]; then
    echo -e "${CYAN}Instalando entorno BSPWM...${RESET}"
    
    BSPWM_PACKAGES=(
        "xorg" "xorg-xinit"
        "bspwm" "sxhkd"
        "polybar" "picom"
        "rofi" "nitrogen"
        "alacritty" "firefox"
        "thunar" "lxappearance"
        "pulseaudio" "pavucontrol"
    )
    
    for package in "${BSPWM_PACKAGES[@]}"; do
        echo -ne "${WHITE}Instalando $package...${RESET} "
        if sudo pacman -S --noconfirm "$package" >/dev/null 2>&1; then
            echo -e "${GREEN}✅${RESET}"
        else
            echo -e "${RED}❌${RESET}"
        fi
    done
    
    # Instalar tema
    echo -e "\n${CYAN}¿Instalar tema gh0stzk? [S/n]:${RESET} "
    read -r install_theme
    if [[ ! "$install_theme" =~ ^[Nn]$ ]]; then
        cd ~ && \
        curl -O https://raw.githubusercontent.com/gh0stzk/dotfiles/master/RiceInstaller && \
        chmod +x RiceInstaller && \
        echo -e "${GREEN}✅ Tema descargado. Ejecute: ./RiceInstaller${RESET}"
    fi
fi

# Configurar servicios
echo -e "\n${CYAN}Configurando servicios...${RESET}"
sudo systemctl enable NetworkManager
sudo systemctl enable bluetooth 2>/dev/null

echo -e "\n${GREEN}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                  ✅ POST-INSTALACIÓN COMPLETADA                  ║"
echo "║                                                                  ║"
echo "║  🎯 PRÓXIMOS PASOS:                                              ║"
echo "║  • Reiniciar el sistema                                          ║"
echo "║  • Si instaló BSPWM: ./RiceInstaller (para el tema)             ║"
echo "║  • Configurar aplicaciones adicionales                          ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

echo -e "${YELLOW}¿Reiniciar ahora? [S/n]:${RESET} "
read -r reboot_now
if [[ ! "$reboot_now" =~ ^[Nn]$ ]]; then
    sudo reboot
fi