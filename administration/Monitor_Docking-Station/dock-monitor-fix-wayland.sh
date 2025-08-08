#!/bin/bash

# Wayland-Version des dock-monitor-fix.sh Scripts
# Für Dell WD19TB Thunderbolt Dock unter Wayland

set -e

LOG_FILE="/tmp/dock-monitor-wayland-fix.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"
}

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Dell WD19TB Monitor Fix Script (Wayland) ===${NC}"
log "Wayland Script gestartet"

check_wayland() {
    if [ "$XDG_SESSION_TYPE" != "wayland" ]; then
        echo -e "${RED}❌ Dieses Script ist für Wayland-Sessions gedacht${NC}"
        echo "Aktuelle Session: $XDG_SESSION_TYPE"
        echo "Verwende das X11-Script für X11-Sessions"
        exit 1
    fi
    echo -e "${GREEN}✅ Wayland-Session erkannt${NC}"
}

show_wayland_status() {
    echo -e "\n${YELLOW}=== Wayland Display Status ===${NC}"
    
    # Wayland-spezifische Display-Information
    echo "Session Type: $XDG_SESSION_TYPE"
    echo "Wayland Display: $WAYLAND_DISPLAY"
    
    # Versuche wlr-randr falls verfügbar
    if command -v wlr-randr >/dev/null 2>&1; then
        echo -e "\nwlr-randr Ausgabe:"
        wlr-randr
    else
        echo "wlr-randr nicht installiert - installiere mit: sudo zypper install wlr-randr"
    fi
    
    # KDE spezifisch
    if [ "$XDG_CURRENT_DESKTOP" = "KDE" ]; then
        echo -e "\nKDE Wayland Display Info:"
        if command -v kscreen-doctor >/dev/null 2>&1; then
            kscreen-doctor -o
        else
            echo "kscreen-doctor nicht verfügbar"
        fi
    fi
    
    # Thunderbolt Status (gleich wie X11)
    echo -e "\nThunderbolt Status:"
    ls -la /sys/bus/thunderbolt/devices/ 2>/dev/null || echo "Keine Thunderbolt-Geräte"
}

wayland_monitor_fix() {
    echo -e "\n${YELLOW}=== Wayland Monitor Fix ===${NC}"
    
    # Thunderbolt Reauthorization (gleich wie X11)
    if [ -f /sys/bus/thunderbolt/devices/0-1/authorized ]; then
        echo "Thunderbolt Reauthorization..."
        echo 0 | sudo tee /sys/bus/thunderbolt/devices/0-1/authorized > /dev/null
        sleep 1
        echo 1 | sudo tee /sys/bus/thunderbolt/devices/0-1/authorized > /dev/null
        sleep 2
    fi
    
    # Wayland-spezifische Display-Aktivierung
    if command -v wlr-randr >/dev/null 2>&1; then
        echo "Aktiviere Displays mit wlr-randr..."
        wlr-randr --output DP-1 --on 2>/dev/null || echo "DP-1 nicht verfügbar"
        wlr-randr --output DP-2 --on 2>/dev/null || echo "DP-2 nicht verfügbar" 
        wlr-randr --output DP-1-3 --on 2>/dev/null || echo "DP-1-3 nicht verfügbar"
    fi
    
    # KDE Wayland
    if [ "$XDG_CURRENT_DESKTOP" = "KDE" ] && command -v kscreen-doctor >/dev/null 2>&1; then
        echo "KDE Wayland Display-Aktivierung..."
        kscreen-doctor --outputs
    fi
}

case "${1:-}" in
    "status")
        check_wayland
        show_wayland_status
        ;;
    "fix")
        check_wayland
        wayland_monitor_fix
        ;;
    *)
        echo "Usage: $0 {status|fix}"
        echo "Wayland-Version des dock-monitor-fix Scripts"
        exit 1
        ;;
esac
