#!/bin/bash

# Dell WD19TB Thunderbolt Dock - Monitor Detection Fix Script
# Autor: Für Dell XPS 9550 mit WD19TB Dock
# Datum: 6. August 2025

set -e

LOG_FILE="/tmp/dock-monitor-fix.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Logging-Funktion
log() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"
}

# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Dell WD19TB Monitor Fix Script ===${NC}"
log "Script gestartet"

# Funktion: Aktuellen Status anzeigen
show_status() {
    echo -e "\n${YELLOW}=== Aktueller Status ===${NC}"
    
    echo "Thunderbolt Geräte:"
    ls -la /sys/bus/thunderbolt/devices/ 2>/dev/null || echo "Keine Thunderbolt-Geräte gefunden"
    
    echo -e "\nThunderbolt Authorization:"
    if [ -f /sys/bus/thunderbolt/devices/0-1/authorized ]; then
        auth_status=$(cat /sys/bus/thunderbolt/devices/0-1/authorized)
        echo "0-1 authorized: $auth_status"
        log "Thunderbolt 0-1 authorized: $auth_status"
    else
        echo "Thunderbolt-Gerät 0-1 nicht gefunden"
        log "Thunderbolt-Gerät 0-1 nicht gefunden"
    fi
    
    echo -e "\nDP-Port Status:"
    for port in /sys/class/drm/card1-DP-*; do
        if [ -d "$port" ]; then
            port_name=$(basename "$port")
            if [ -f "$port/status" ]; then
                status=$(cat "$port/status" 2>/dev/null || echo "unbekannt")
                echo "$port_name: $status"
                log "DP-Port $port_name Status: $status"
            else
                echo "$port_name: keine Status-Datei"
                log "DP-Port $port_name: keine Status-Datei"
            fi
        fi
    done
    
    echo -e "\nXrandr Ausgabe:"
    xrandr | grep -E "(connected|disconnected)" | head -10
}

# Funktion: DP-Ports neu scannen
rescan_dp_ports() {
    echo -e "\n${YELLOW}=== DP-Ports neu scannen ===${NC}"
    log "Starte DP-Port Rescan"
    
    # Moderne Methode: DRM-Subsystem neu scannen
    echo "Trigger DRM Hotplug-Events..."
    if [ -f /sys/class/drm/card1/device/rescan ]; then
        echo 1 | sudo tee /sys/class/drm/card1/device/rescan > /dev/null 2>&1 || echo "Rescan nicht unterstützt"
        log "DRM Rescan ausgeführt"
    fi
    
    # Alternative: Kernel-Module für Hotplug-Detection
    echo "Trigger Kernel Hotplug-Detection..."
    echo 1 | sudo tee /sys/bus/pci/rescan > /dev/null 2>&1 || echo "PCI Rescan nicht verfügbar"
    
    # Für jeden DP-Port versuchen wir den detect-Trigger
    for port in /sys/class/drm/card1-DP-*; do
        if [ -d "$port" ]; then
            port_name=$(basename "$port")
            echo "Trigger Detection für $port_name..."
            
            # Versuche verschiedene Methoden
            if [ -f "$port/status" ] && [ -w "$port/status" ]; then
                # Status-Datei ist beschreibbar - triggere Hotplug
                current_status=$(cat "$port/status" 2>/dev/null || echo "unknown")
                echo "Aktueller Status: $current_status"
                
                # Force disconnect und reconnect
                echo "disconnected" | sudo tee "$port/status" > /dev/null 2>&1 && echo "$port_name disconnect getriggert" || echo "$port_name disconnect fehlgeschlagen"
                sleep 1
                echo "connected" | sudo tee "$port/status" > /dev/null 2>&1 && echo "$port_name connect getriggert" || echo "$port_name connect fehlgeschlagen"
                
                log "DP-Port $port_name Status-Toggle ausgeführt"
            elif [ -f "$port/detect" ]; then
                echo 1 | sudo tee "$port/detect" > /dev/null 2>&1 && echo "$port_name detect getriggert" || echo "$port_name detect fehlgeschlagen"
                log "DP-Port $port_name detect getriggert"
            elif [ -f "$port/force" ]; then
                echo "on" | sudo tee "$port/force" > /dev/null 2>&1 && echo "$port_name force aktiviert" || echo "$port_name force fehlgeschlagen"
                log "DP-Port $port_name force aktiviert"
            else
                echo "$port_name: keine detect/force/writable status Datei gefunden"
                log "DP-Port $port_name: keine detect/force/writable status Datei"
            fi
        fi
    done
    
    sleep 2
    echo "Führe xrandr --auto aus..."
    xrandr --auto
    log "xrandr --auto ausgeführt"
}

# Funktion: Thunderbolt neu autorisieren
reauthorize_thunderbolt() {
    echo -e "\n${YELLOW}=== Thunderbolt neu autorisieren ===${NC}"
    log "Starte Thunderbolt Reauthorization"
    
    if [ -f /sys/bus/thunderbolt/devices/0-1/authorized ]; then
        echo "Deautorisiere Thunderbolt-Gerät..."
        echo 0 | sudo tee /sys/bus/thunderbolt/devices/0-1/authorized > /dev/null
        sleep 1
        
        echo "Autorisiere Thunderbolt-Gerät neu..."
        echo 1 | sudo tee /sys/bus/thunderbolt/devices/0-1/authorized > /dev/null
        sleep 2
        log "Thunderbolt-Gerät neu autorisiert"
        
        echo "Versuche Monitor-Aktivierung..."
        # Versuche alle verfügbaren DP-Ports (inkl. MST)
        xrandr --output DP-1 --auto 2>/dev/null || echo "DP-1 nicht verfügbar"
        xrandr --output DP-2 --auto 2>/dev/null || echo "DP-2 nicht verfügbar"
        xrandr --output DP-1-3 --auto 2>/dev/null || echo "DP-1-3 nicht verfügbar"
        log "Monitor-Aktivierung für DP-1, DP-2 und DP-1-3 versucht"
    else
        echo -e "${RED}Thunderbolt-Gerät 0-1 nicht gefunden${NC}"
        log "ERROR: Thunderbolt-Gerät 0-1 nicht gefunden"
    fi
}

# Funktion: Vollständiger Fix-Versuch
full_fix() {
    echo -e "\n${YELLOW}=== Vollständiger Fix-Versuch ===${NC}"
    log "Starte vollständigen Fix"
    
    # Schritt 1: DP-Ports rescannen
    rescan_dp_ports
    
    # Schritt 2: Status prüfen
    sleep 2
    connected_monitors=$(xrandr | grep -c " connected" || echo "0")
    echo "Verbundene Monitore: $connected_monitors"
    
    if [ "$connected_monitors" -gt 1 ]; then
        echo -e "${GREEN}✅ Monitor erfolgreich erkannt!${NC}"
        log "SUCCESS: Monitor erkannt nach DP-Rescan"
        return 0
    fi
    
    # Schritt 3: Thunderbolt neu autorisieren
    echo "Monitor noch nicht erkannt, versuche Thunderbolt-Reauthorization..."
    reauthorize_thunderbolt
    
    # Schritt 4: Finaler Status check
    sleep 3
    connected_monitors=$(xrandr | grep -c " connected" || echo "0")
    echo "Verbundene Monitore nach Thunderbolt-Fix: $connected_monitors"
    
    if [ "$connected_monitors" -gt 1 ]; then
        echo -e "${GREEN}✅ Monitor erfolgreich erkannt nach Thunderbolt-Fix!${NC}"
        log "SUCCESS: Monitor erkannt nach Thunderbolt-Fix"
    else
        echo -e "${RED}❌ Monitor konnte nicht automatisch erkannt werden${NC}"
        echo "Versuchen Sie:"
        echo "1. Dock physisch ab- und wieder anstecken"
        echo "2. sudo modprobe -r i915 && sudo modprobe i915"
        log "FAILED: Monitor konnte nicht automatisch erkannt werden"
    fi
}

# Hauptmenü
case "${1:-}" in
    "status")
        show_status
        ;;
    "rescan")
        rescan_dp_ports
        ;;
    "reauth")
        reauthorize_thunderbolt
        ;;
    "fix")
        full_fix
        ;;
    *)
        echo "Usage: $0 {status|rescan|reauth|fix}"
        echo ""
        echo "Commands:"
        echo "  status  - Zeigt aktuellen Status an"
        echo "  rescan  - Scannt DP-Ports neu"
        echo "  reauth  - Autorisiert Thunderbolt neu"
        echo "  fix     - Führt vollständigen Fix-Versuch durch"
        echo ""
        echo "Beispiel: $0 status"
        exit 1
        ;;
esac

log "Script beendet"
