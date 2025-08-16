#!/usr/bin/env python3
import subprocess
import os
from tabulate import tabulate

def get_wifi_networks():
    """Obtiene las redes WiFi configuradas y sus contraseñas"""
    networks = []
    current_network = None
    
    try:
        # Primero obtener la red actualmente conectada
        try:
            current_result = subprocess.run(
                ['nmcli', '-t', '-f', 'active,ssid', 'dev', 'wifi'],
                capture_output=True,
                text=True,
                check=True
            )
            for line in current_result.stdout.strip().split('\n'):
                if line.startswith('yes:'):
                    current_network = line.split(':')[1]
                    break
        except:
            pass
        
        # Obtener lista de TODAS las conexiones (no solo WiFi visibles en nmcli connection show)
        result = subprocess.run(
            ['nmcli', '-t', '-f', 'NAME,TYPE', 'connection', 'show'],
            capture_output=True,
            text=True,
            check=True
        )
        
        for line in result.stdout.strip().split('\n'):
            if ':' in line:
                parts = line.split(':')
                name = parts[0]
                conn_type = parts[1] if len(parts) > 1 else ""
                
                # Procesar conexiones WiFi y 802-11-wireless
                if 'wifi' in conn_type.lower() or 'wireless' in conn_type.lower() or '802-11' in conn_type:
                    # Obtener la contraseña de esta red
                    try:
                        pwd_result = subprocess.run(
                            ['nmcli', '--show-secrets', '-f', '802-11-wireless-security.psk', 'connection', 'show', name],
                            capture_output=True,
                            text=True,
                            check=True
                        )
                        
                        password = "Sin contraseña"
                        for pwd_line in pwd_result.stdout.split('\n'):
                            if pwd_line and ':' in pwd_line:
                                pwd_value = pwd_line.split(':')[-1].strip()
                                if pwd_value and pwd_value != '--':
                                    password = pwd_value
                                    break
                        
                        # Si no encontramos psk, buscar wep-key o password
                        if password == "Sin contraseña":
                            pwd_result2 = subprocess.run(
                                ['nmcli', '--show-secrets', 'connection', 'show', name],
                                capture_output=True,
                                text=True,
                                check=True
                            )
                            for pwd_line in pwd_result2.stdout.split('\n'):
                                if 'password:' in pwd_line.lower() or 'wep-key' in pwd_line.lower():
                                    pwd_value = pwd_line.split(':')[-1].strip()
                                    if pwd_value and pwd_value != '--':
                                        password = pwd_value
                                        break
                        
                        is_current = " ⭐" if name == current_network else ""
                        networks.append([name + is_current, password])
                    except subprocess.CalledProcessError:
                        networks.append([name, "Error al obtener"])
        
        # También mostrar redes disponibles (escaneadas)
        print("\n=== REDES WiFi GUARDADAS ===\n")
        if networks:
            print(tabulate(networks, headers=['SSID (Nombre de Red)', 'Clave'], tablefmt='grid'))
        else:
            print("No hay redes WiFi guardadas.")
        
        # Escanear redes disponibles
        print("\n=== REDES WiFi DISPONIBLES ===\n")
        try:
            scan_result = subprocess.run(
                ['nmcli', 'device', 'wifi', 'list'],
                capture_output=True,
                text=True,
                check=True
            )
            
            available_networks = []
            lines = scan_result.stdout.strip().split('\n')[1:]  # Saltar encabezado
            
            for line in lines:
                parts = line.split()
                if len(parts) >= 2:
                    # El SSID puede tener espacios, está después del primer campo (IN-USE)
                    ssid = ' '.join(parts[1:2]) if len(parts) > 1 else "Sin nombre"
                    signal = parts[-3] if len(parts) > 3 else "?"
                    available_networks.append([ssid, signal])
            
            if available_networks:
                print(tabulate(available_networks, headers=['SSID', 'Señal'], tablefmt='grid'))
            else:
                print("No se encontraron redes disponibles.")
                
        except subprocess.CalledProcessError as e:
            print(f"Error al escanear redes: {e}")
            
    except subprocess.CalledProcessError as e:
        print(f"Error: {e}")
        print("Asegúrate de tener NetworkManager instalado y en ejecución.")
    except Exception as e:
        print(f"Error inesperado: {e}")

if __name__ == "__main__":
    print("Obteniendo información de redes WiFi...")
    print("Nota: Se requieren permisos de sudo para ver las contraseñas guardadas.\n")
    get_wifi_networks()